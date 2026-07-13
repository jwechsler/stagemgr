# Data Retention & Archival Strategy

*Internal engineering/ops document — not part of the mkdocs user manual.*
*Adopted July 2026. Review the Tier 2 trigger metrics annually.*

## Why this document exists

The database carries order history back to 2010, and the concern was that
order growth would eventually make the primary database a performance
barrier. Investigation (July 2026) reframed the problem: **order data is not
the bloat, and order volume is flat.**

### What the database actually holds (July 2026 measurement)

| Table | Rows / size | Reality |
|---|---|---|
| `sessions` | 3.86M / **1.29GB** | Dead. Session store is `cookie_store` (`config/initializers/session_store.rb`); newest row Nov 2022. |
| `audits` | 1.74M / **0.56GB** | 94% Order audits back to 2011, growing ~55K rows/year. Shown on admin order pages (`app/views/admin/orders/_audit_show.html.haml`). |
| `order_tasks` | 526K / **0.26GB** | 126MB of it is `result` — exception backtraces written on task failure (`app/models/order_tasks/outreach_task.rb`); nothing reads them back. |
| Order graph (orders, line_items, payments, addresses, seat_assignments, …) | **~300MB total** | Orders are flat at ~12–20K/year since 2011 → ~20MB/year growth. |

~88% of the 2.4GB database was operational cruft. At flat growth, the core
order graph would take **decades** to reach a size MySQL finds challenging.
Payments store only thin gateway references (`transaction_id`,
`confirmation_code`, last-four) — there are no fat gateway payloads to thin
from old orders.

### Retention requirements (owner decision, July 2026)

- Order-level financial detail and donation data must remain retrievable for
  **~7 years**. Nothing in any tier *deletes* financial data — orders are only
  ever moved to an archive that stays queryable, so this is satisfied with
  margin.
- Audit-trail rows may be pruned from the live DB once safely exported
  (archive-then-prune); dumps are retained with backups for ≥ 7 years.

## The strategy: three tiers

### Tier 0 — Reclaim the 88% (implemented July 2026)

1. **Drop `sessions`** — `db/migrate/20260712150000_drop_sessions_table.rb`.
   `DROP TABLE` returns the 1.29GB to the filesystem immediately
   (file-per-table InnoDB). Prod precondition: verify
   `SELECT MAX(updated_at) FROM sessions` is stale there too, and take a final
   dump (`mysqldump --single-transaction --no-tablespaces <db> sessions | gzip`).
2. **Archive then prune old audits** — a two-job pipeline, gated on explicit
   configuration:
   - **The gate:** both stages are inert until `archive_directory` is set in
     `config/server.yml` (see `server.yml.example`). The directory **must be
     covered by the server's backup regime** — the exported files are the
     long-term record. Leaving it blank disables the pipeline; the operator
     has to name an archival location for any audit deletion to happen.
   - `ArchiveOldAudits` (monthly, `schedule.yml`) exports audit rows older
     than **3 years** and newer than the current archive marker to a gzipped
     NDJSON file (`audits_through_<date>_<stamp>.ndjson.gz`) in
     `archive_directory`. It writes to a `.tmp` file, re-reads it, and
     verifies the row count against the database **before** renaming it into
     place and advancing the marker. Any mismatch raises: the marker stays
     put and the failure lands in the Resque failed queue.
   - `PruneOldAudits` (weekly) deletes audit rows older than the retention
     window in 5,000-row batches with pauses — but only up to
     `min(3.years.ago, archive marker)`, so **nothing is ever deleted that
     isn't in a verified archive file**.
   - Trade-off: orders older than the cutoff show no "changes" panel in
     admin (the partial degrades gracefully when a record has no audits).
3. **Thin `order_tasks.result`** — `PruneOrderTaskResults` (weekly) nulls the
   stored failure backtraces on tasks older than 6 months. No archive needed —
   they are stack traces with no value after the fact.
4. **One-time space reclamation** — after the first big prunes, run in a
   maintenance window:
   `OPTIMIZE TABLE audits, order_tasks;`
   InnoDB rebuilds online but briefly locks at start/end and temporarily needs
   ~2× the table's disk space. Do **not** schedule this recurring — freed
   pages are reused; a one-time rebuild after the initial bulk prune is
   enough.

Expected result: DB shrinks from ~2.4GB to ~0.5GB.

### Tier 1 — Make the primary DB scale (indexes and query rewrites implemented July 2026)

**Implemented:** `db/migrate/20260712150100_add_retention_and_reporting_indexes.rb`

- `orders (status)` and `orders (type, status)` — every terminal-state scope
  (`settled`, `finalized`, `attending`, …) filters on the previously
  unindexed `status`; report queries add the STI `type`.
- `payments (processed_on)` — date-ranged revenue/flex-pass/membership
  reports filter on it. Also drops `payments_oid_i`, an exact duplicate of
  `index_payments_on_order_id`.
- `order_tasks (status, execute_at)` — serves `OrderTask.run_pending`, which
  runs every 5 minutes.
- `addresses (email)`, `addresses (updated_at)` — email search in the admin
  address datatable; maintenance-job predicates.
- `job_metadata (job_name)` — looked up by name on every logged job run.

**Tier 1 follow-ups (implemented July 2026):**

- `app/models/resque_jobs/remove_unused_addresses.rb` — rewritten from
  `id NOT IN (SELECT address_id FROM orders)` plus per-address Ruby
  filtering (the single worst-scaling query in the app) to SQL anti-joins
  (`where.missing(:orders, :address_tags)`). A
  `JobMetadata` watermark (`unused_addresses_examined_through`) means each
  weekly run only examines addresses that became stale since the last run.
  The old `productions_attended` check was dropped: attendance derives from
  `orders.address_id`, so an address with no orders provably has none.
  Known trade-off: a tag deleted without saving its address won't re-enter
  the examination window; the address just survives.
- The `donations_dump` report was **removed as dead code** rather than
  batched. It had been broken since the Rails 2 era three ways over —
  `Order.all(include:, conditions:)` raises under Rails 6, its
  `donations_dump.html.haml` template does not exist, and it called an
  undefined `create_hash_from_order_fields`. Nothing linked to it; the
  surviving `donation_dump` / `donations_total` reports cover donation
  reporting. Action, private builder, and both routes deleted.
- `OrderTask.run_pending` full-scan fixed by a new weekly
  `CancelExhaustedOrderTasks` job (not a one-time fix — tasks keep
  exhausting): `Failed` tasks with `attempts >= OrderTask::MAX_ATTEMPTS`
  (12) are already terminal per `uncompleted?`, so marking them `Cancelled`
  is behaviorally neutral and restores selectivity of the
  `(status, execute_at)` index for the every-5-minutes poll. Failure text
  in `result` is left for `PruneOrderTaskResults`; admin retry
  (`OrderTask#retry`) works regardless of status.

### Tier 2 — Order archival architecture (designed; **gated, not built**)

**Trigger metrics — build Tier 2 only when ANY of these is true:**

- `orders` + `line_items` + `payments` combined exceed **2GB** (≈ 2045 at
  current growth), or
- the slow-query log shows order-graph queries with **p95 > 1s** that
  indexing can't fix, or
- backup/restore windows become operationally painful.

Re-check annually (table sizes via
`information_schema.tables` — one query, 30 seconds). Until a trigger fires,
Tier 0 + Tier 1 are the whole strategy. This is intentional honesty: at flat
sales volume, Tier 2 may never be needed.

**Architecture (decided in advance so the design isn't relitigated):**
same-MySQL-server archive schema using Rails 6 multi-database support.

- `config/database.yml` converts to the three-tier format with an `archive`
  connection; an abstract `ArchiveRecord` base class (`connects_to database:
  { writing: :archive }`) hosts mirror models (`Archive::Order`, …).
- Archive stays **live-queryable** for reporting and admin lookups, gets its
  own backup cadence, and disappears from primary-DB working sets. (Archive
  tables inside the same schema were rejected — no isolation benefit; offline
  dumps were rejected as primary archive — no read path — but remain the
  belt-and-braces step before every archival delete.)

**Hard prerequisites before any raw order row is moved:**

1. **Rollup-first.** These reports recompute from raw orders and would
   silently produce wrong numbers for archived productions/patrons:
   - Per-production revenue rollup (frozen `RevenueCalculator` output) so
     `RoyaltyReport` / `SalesByPerformanceReport` keep working —
     `app/services/revenue_calculator.rb`.
   - Per-patron attendance/revenue rollup so the admin patron history
     (`app/views/admin/addresses/_order_history.html.haml`, the `Address`
     aggregates like `productions_attended` / `orders_processed`) and
     `AudienceAnalysis` "Ever" cohorts survive.
   - `rate_of_sales` already exists as a daily rollup, but
     `RateOfSalesJob.backfill_missing_days` recomputes from raw orders —
     guard it to never recompute days older than the archive horizon.
2. **Archive by production, not by date.** Move orders only when their
   production closed > 3 years ago. This dominates any refund horizon
   (refunds write offset payments onto the *original* order —
   `app/models/payments/credit_card_payment.rb` — so archived orders must be
   un-refundable by policy, and admin UI must not offer refund/exchange on
   them).
3. **Chain closure.** Exchanged/split orders link via `exchange_source_id` /
   `split_source_id`. Follow chains in both directions and archive a whole
   connected chain atomically or not at all — an active order must never
   reference a missing source.
4. **Co-archive the full graph.** line_items, payments, order_tasks (FK
   cascade on delete), plus seat_assignments and pledges (**no FK cascade —
   must be handled explicitly**), plus the order's `audits` rows. Pattern:
   copy to archive → verify counts → delete from primary, with a
   per-batch mysqldump first.
5. **Addresses never move.** They are the patron CRM; archived orders keep
   `address_id` as a cross-schema soft reference.
6. **Read path.** Admin order datatable and patron history get an "include
   archived" toggle that unions in `Archive::Order` results, rendered
   read-only.

Estimated effort when triggered: ~1 week for rollups (worth building earlier
if report speed ever matters), 1–2 weeks for the archive schema + mover job +
admin read path.

## Runbooks

### Enabling the audit archive/prune pipeline in production

1. Choose the archive directory — a path that your backup regime already
   covers (the exported `.ndjson.gz` files are the permanent record; retain
   ≥ 7 years). Set it in `config/server.yml`:

   ```yaml
   production:
     archive_directory: "/var/backups/stagemgr-archive"
   ```

   Until this is set, both `ArchiveOldAudits` and (transitively)
   `PruneOldAudits` do nothing.

2. **Recommended for the initial 15-year backlog:** take a supervised
   `mysqldump` first and set the marker by hand, so the first big export is
   in the most universally restorable format:

   ```bash
   mysqldump --single-transaction --no-tablespaces \
     --where="created_at < '2023-01-01'" \
     stagemgr_production audits | gzip > audits_pre2023.sql.gz
   ```

   Verify row counts against
   `SELECT COUNT(*) FROM audits WHERE created_at < '2023-01-01'`, test a
   restore into a scratch schema, store with backups, then record the marker
   from a Rails console — dated to the dump's `--where` boundary, not `now`:

   ```ruby
   JobMetadata.find_or_initialize_by(job_name: PruneOldAudits::ARCHIVE_MARKER)
              .update!(last_run_at: Time.zone.parse('2023-01-01'))
   ```

   Alternatively, skip this step: `ArchiveOldAudits`' first scheduled run
   will export the entire backlog itself (~1.5M rows, one large NDJSON
   file). Its verify-before-advance logic applies either way.

3. Steady state is unattended: `ArchiveOldAudits` runs monthly, exports the
   newly aged-out band, verifies, and advances the marker; `PruneOldAudits`
   runs weekly and deletes only what the marker covers. Supervise the first
   production runs (`Resque.enqueue(ArchiveOldAudits)`, then
   `Resque.enqueue(PruneOldAudits)`) and watch replication/lag if
   applicable.

4. Periodically confirm the archive directory is actually landing in
   backups — that's the one link in the chain no job can verify.

### Sessions final dump (before prod migration deploy)

```bash
mysql -e "SELECT MAX(updated_at), COUNT(*) FROM sessions" stagemgr_production
mysqldump --single-transaction --no-tablespaces stagemgr_production sessions | gzip > sessions_final.sql.gz
```

Then deploy and run `db/migrate/20260712150000_drop_sessions_table.rb`.
Restart Passenger after migrating (required after every migration).

### One-time OPTIMIZE (after first bulk prunes)

```sql
OPTIMIZE TABLE audits, order_tasks;
```

Maintenance window; check free disk ≥ current size of the largest table
being rebuilt.

## Annual review checklist

- [ ] Table sizes via `information_schema.tables` — any Tier 2 trigger hit?
- [ ] `ArchiveOldAudits` / `PruneOldAudits` / `PruneOrderTaskResults` running and logging sane counts?
- [ ] Archive marker (`JobMetadata.last_run(PruneOldAudits::ARCHIVE_MARKER)`) within ~4 months of the retention horizon?
- [ ] Archive directory still covered by the backup regime, and its files intact?
- [ ] Slow-query log: any order-graph query p95 > 1s?
