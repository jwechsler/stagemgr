# Configuration

Stagemgr reads its configuration from three places, and which one a setting
belongs in is not a matter of taste:

| Kind of setting | Where |
|---|---|
| Non-secret deployment settings -- host names, mount point, business rules, email addresses, house facts | `config/server.yml` |
| Connection details and secrets | the process environment (`.env` in development and test) or [encrypted credentials](credentials.md) |
| Anything the box office maintains -- theaters, venues, productions, users | the database, through the admin UI |

## Scaffolding the files

The real config files are gitignored; the repository tracks `.example`
templates. One task copies them:

```sh
bundle exec rake setup:config
```

It creates each `config/*.yml` from its `config/*.yml.example`, plus `.env` from
`.env.example`, and **never overwrites** a file that already exists. It does not
load Rails -- it cannot, since `config/database.yml` is one of the files it
produces. `bin/docker-entrypoint` runs it on every container start.

| Generated | Read by | Notes |
|---|---|---|
| `config/database.yml` | Active Record | Every value is environment-driven; the same file works native, in Docker and in CI |
| `config/server.yml` | `config/environments/{development,production}.rb` | The main deployment file, documented below |
| `config/ticket_print.yml` | `config.x.tktprint` | Ticket-printing service URL, per environment |
| `config/schedule.yml` | resque-scheduler | Already tracked, so `setup:config` leaves it alone |
| `config/membership_card_spec.yml` | `MembershipCards::Spec` | Member ID card geometry ([spec](membership-card-spec.md)); edit the copy to tune placement without touching the tracked example |
| `config/my_emma_credentials.yml` | **nothing** | A dead legacy file. MyEmma credentials come from `MY_EMMA_*` or credentials |
| `.env` | dotenv (development, test) and `docker compose` | |

### The rest of the `setup:` namespace

| Task | Boots Rails? | Does |
|---|---|---|
| `setup:config` | no | The scaffolding above |
| `setup:site[slug]` | no | Copies `sites/example/` to `sites/<slug>/` and inserts `site_theme: <slug>` under `all:` in `config/server.yml` ([Theming](theming.md)) |
| `setup:secret_key_base` | no | Generates `SECRET_KEY_BASE` in `.env` if it is blank or missing; never replaces an existing value |
| `setup:bootstrap` | yes | Creates this environment's database, loads `db/schema.rb`, applies pending migrations, seeds only when there are no users |
| `setup:admin` | yes | Creates or updates the first administrator (`ADMIN_EMAIL`/`ADMIN_PASSWORD` skip the prompts) |
| `setup:theater` | yes | Creates the first theater and venue and associates the administrator |
| `setup:payments` | yes | Prompts for Stripe keys and writes them to `.env` |
| `setup:demo_data` | yes | One sample production with performances, ticket classes and allocations |
| `setup:doctor` | yes | Health check; exits 1 on problems |
| `setup:wizard` | yes | All of the above, interactively, in order |

Every task is idempotent: re-running one reports what already exists instead of
failing.

!!! note "`config:setup` is deprecated"
    The old name still works and forwards to `setup:config`, printing a
    deprecation notice. Use `setup:config`.

!!! info "Why `setup:bootstrap` and not `db:prepare`"
    `db:prepare` only reaches for `db/schema.rb` when it hits `NoDatabaseError`.
    The Docker stack hands Rails a database MySQL has already created
    (`MYSQL_DATABASE`), so `db:prepare` sees an existing-but-empty database and
    replays every migration back to 2009 -- slow, fragile on MySQL 8, and it
    rewrites the committed `db/schema.rb` on the way out. `setup:bootstrap`
    loads the schema instead, and migrates only what is actually pending.

## `.env`

`.env` is gitignored and read by two different things: `docker compose`, and
dotenv-rails -- which is loaded in the **development and test groups only**. In
production the same variables must come from the process environment (Compose
`environment:`, Passenger `SetEnv`, a systemd `EnvironmentFile`).

!!! danger "Delete blank lines, do not leave them"
    A variable set to the empty string is *ignored* by
    [`AppSecrets`](credentials.md) rather than shadowing a credential -- that is
    deliberate, and it is the fix for the outage described in
    [Troubleshooting](troubleshooting.md#a-blank-env-variable-shadowed-a-working-credential).
    But a blank line is still noise, and `setup:doctor` warns about every one it
    finds: five in a `.env` copied straight from the template, four once
    `setup:secret_key_base` (or the wizard) has filled in `SECRET_KEY_BASE`. If
    you are not using a key, delete the line.

### Database

| Variable | Default | Purpose |
|---|---|---|
| `DATABASE_USER` | `stagemgr_dev` | MySQL account. **Must not be `root`** -- the `mysql` image refuses to start with `MYSQL_USER=root` |
| `DATABASE_PASSWORD` | `password` | Its password |
| `DATABASE_HOST` | `127.0.0.1` | Compose overrides this to `mysql` |
| `DATABASE_PORT` | `3306` | |
| `DATABASE_NAME` | `stagemgr_dev` | Development/production database |
| `TEST_DATABASE_NAME` | `stagemgr_test` | RSpec and Cucumber. Give every concurrent checkout its own -- the suites truncate every table between examples |
| `DATABASE_POOL` | `5` | Active Record connection pool |
| `DATABASE_SOCKET` | -- | Connect over a Unix socket instead of TCP (a native Homebrew MySQL) |
| `MYSQL_ROOT_PASSWORD` | `changeme-root` | Compose only: the MySQL container's root password. Deliberately not `DATABASE_PASSWORD` |

In `production` the database name still defaults (`stagemgr_production`) but the
user and password do not: `config/database.yml.example` uses `ENV.fetch` without
a default there, so booting production against `stagemgr_dev`/`password` because
a variable was unset fails loudly instead.

### Redis

| Variable | Default | Purpose |
|---|---|---|
| `REDIS_URL` | `redis://127.0.0.1:6379/0` | Resque queues and Rack::Attack counters. Compose overrides it to `redis://redis:6379/0` |

### Rails

| Variable | Purpose |
|---|---|
| `RAILS_ENV` | `development`, `test` or `production` |
| `SECRET_KEY_BASE` | Session/cookie signing key. `rake setup:secret_key_base` fills it in; `bundle exec rails secret` generates one by hand |
| `RAILS_MASTER_KEY` | Alternative to shipping `config/master.key`/`config/credentials/<env>.key` as a file. See [Credentials](credentials.md) |
| `STAGEMGR_SUB_URI` | Sub-path the app is mounted at, e.g. `/tickets`. Compose passes it through as `RAILS_RELATIVE_URL_ROOT`. Optional: `server.yml`'s `sub_uri` fills the setting when the variable is absent or blank, and the two must agree when both are set |
| `RAILS_SERVE_STATIC_FILES` | Serve `public/` from Rails instead of from Nginx/Apache |
| `RAILS_LOG_TO_STDOUT` | Log to stdout for a container or journald log driver |
| `RAILS_MAX_THREADS`, `WEB_CONCURRENCY`, `PORT` | Puma only; the Docker image runs Passenger |
| `RAILS_RAISE_ERRORS` | Re-raise controller exceptions instead of rendering the friendly error page (`app/controllers/application_controller.rb`) |
| `BACKTRACE` | Unsilenced backtraces |
| `SKIP_REQUIRED_SECRETS_CHECK` | Let the production boot check pass with secrets missing. Only for a build or maintenance process that never serves a request |

### Secrets

Each of these is also readable from encrypted credentials -- see
[Credentials & secrets](credentials.md) for the full registry and the resolution
order.

| Variable | Needed when |
|---|---|
| `STRIPE_SECRET_KEY` | `payment_processing.default_gateway` (or `default_recurring_gateway`) is `stripe` |
| `STRIPE_SIGNING_SECRET` | You receive Stripe webhooks (`whsec_…`) |
| `POSTMARK_API_TOKEN` | `email.delivery_method` is `postmark` |
| `RESQUE_ADMIN_PASSWORD` | Always, in production -- see [the Resque dashboard](#the-resque-dashboard) |
| `MY_EMMA_USERNAME`, `MY_EMMA_PASSWORD`, `MY_EMMA_ACCOUNT_ID` | Using MyEmma mailing lists. All three are required together; with any of them absent the integration disables itself |
| `LGL_API_KEY` | Syncing customers with Little Green Light ([Little Green Light sync](#little-green-light-sync)). Optional: absent, the integration disables itself; it also needs `littlegreenlight.sync: enabled` |
| `LGL_USER`, `LGL_PASSWORD` | The LGL donor-tier report link (`littlegreenlight.donor_tier_report_url`) asks for a login. Optional: Basic auth is sent only when both LGL_USER and LGL_PASSWORD are set |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | ActiveStorage on S3 (uncomment the matching block in `config/storage.yml`). Blank means local disk |
| `PAYPAL_LOGIN`, `PAYPAL_PASSWORD`, `PAYPAL_SIGNATURE`, `PAYPAL_PEM_FILE`, `PAYPAL_EXPRESS_LOGIN`, `PAYPAL_EXPRESS_PASSWORD` | Legacy PayPal gateways only |

!!! note "Development runs MyEmma read-only"
    `config/environments/development.rb` calls `MyEmma.read_only!` after setting
    credentials: reads work, writes are logged and skipped, whatever account the
    credentials point at.

### Little Green Light sync

Stagemgr links each customer to a constituent in the default theater's LGL
account; see [Little Green Light Sync](../customers/lgl-sync.md) for what it
does. Sync runs only when `littlegreenlight.sync` is `enabled` or `readonly`
**and** `LGL_API_KEY` (or the `littlegreenlight.api_key` credential) is set.
Otherwise every LGL trigger, job and page button is a no-op, and the LGL Sync
admin page says why. The nightly donor-tier report download is the one
exception: it needs only `donor_tier_report_url` (below), not the API key or
the sync mode.

From LGL the integration reads constituents (by id, external id and email, and
the list of every constituent id), the constituents changed since the last
poll, and each linked constituent's gifts, which set the `LGL Lapsed` tag
(`LYBUNT` / `SYBUNT`) by fiscal year. The fiscal year starts on
`theater.fiscal_year_start_month` (see
[the `theater:` block](theming.md#the-theater-block); January when unset).

The API key is a secret ([above](#secrets)); the rest lives in the
`littlegreenlight:` section of `config/server.yml`:

```yaml
all:
  littlegreenlight:
    sync: readonly              # enabled | readonly | disabled
    writable_address_ids:       # optional, readonly only: 12, 34  or a YAML list
    web_url: https://youraccount.littlegreenlight.com
    donor_tier_report_url:      # optional: permanent link of the LGL donor-tier saved report
```

| Key | ENV override | Purpose |
|---|---|---|
| `sync` | `LGL_SYNC` | The sync mode, one of the three below. Case and surrounding spaces are ignored; any other word, or none, means `disabled` |
| `writable_address_ids` | `LGL_WRITABLE_ADDRESS_IDS` | Comma-separated (or YAML list) Stagemgr address ids that may still be written to LGL in `readonly` mode, for acceptance testing. Ignored in `enabled` mode |
| `web_url` | -- | Base URL of the LGL account, used to link an LGL ID to the constituent page. Blank shows the id as plain text |
| `donor_tier_report_url` | `LGL_DONOR_TIER_REPORT_URL` | Permanent link of the LGL saved report (CSV with `External constituent ID`, `TG Tier Last Fiscal`, `TG Tier This Fiscal`) that `LglDonorLevelsFetch` downloads nightly and imports as donor levels. Blank turns the nightly import off. Independent of `sync` and `LGL_API_KEY`; the import's owner and result-email recipient is the user whose email is `email.addresses.supervisor_notifications` |

A non-blank environment variable overrides the `server.yml` value; a blank one
counts as absent, the same rule as [AppSecrets](#secrets).

| `sync` | Reads from LGL, local tags and linking | Writes to LGL |
|---|---|---|
| `disabled` (or missing, or any other word) | Off | Off |
| `readonly` | On | Skipped and logged as `[LGL] read-only: skipped ...`, except for addresses in `writable_address_ids`. Stagemgr merges driven by LGL go to LGL Review unless both addresses are writable |
| `enabled` | On | On, for every address |

In development `enabled` is treated as `readonly` (with the allowlist), and
boot logs `[LGL] sync 'enabled' downgraded to readonly in development`, so a
copied config never writes to the live account from a developer's machine.
The test environment never syncs. The rules live in `Lgl.configure_from`,
called from each environment's `after_initialize`.

The LGL jobs run on the `maintenance` Resque queue (`LglDonorImport` runs on
`import`). In production `script/resque-worker` serves that queue from worker
#3 only (`default,maintenance`), so one process makes every LGL request in turn; every other environment runs a
single worker on `QUEUE=*`. `config/schedule.yml` (and its `.example`) schedules four of them:

| Job | Schedule | Does |
|---|---|---|
| `LglPollConstituents` | every 3 hours | Reads constituents changed since the last poll and reconciles LGL merges |
| `LglSweepConstituents` | nightly at 03:10 | Drops `LGL ID` tags whose constituent no longer exists and re-syncs those customers |
| `LglDonorLevelsFetch` | nightly at 05:30 | Downloads the donor-tier saved report and queues `LglDonorImport`. Runs only when `donor_tier_report_url` is set, whatever `sync` is |
| `LglGiftHistoryWalk` | Sundays at 02:00 | Reads every linked customer's gifts from LGL (one request each, about 1.1 seconds apart to stay under LGL's 300 requests per 5 minutes, so roughly an hour) and refreshes their `LGL Lapsed` tag. Only reads LGL. Gives up after 25 consecutive LGL errors. Linking a customer and **Re-sync with LGL** refresh that one customer straight away |

After the first deploy with a key, run the backfill **once** to link every
constituent whose External constituent ID already names a customer. It only
writes local tags, never LGL:

```sh
bundle exec rake lgl:backfill       # queue it on the maintenance queue
bundle exec rake lgl:backfill_now   # or run it inline and print the counts
```

#### Writing Stagemgr ids into LGL

Constituents whose External constituent ID is blank, their own LGL id, or a
customer that no longer exists can be linked by email, once, by a developer.
A constituent is linked only when exactly one customer has one of its emails,
the same last name (ignoring case) and no other LGL ID; constituents with
several matches, none, or no email are only counted. Run the dry run first: it
reads LGL, prints the counts by kind and outcome, and writes nothing. Then run
the real one, which queues one sync per match on the `maintenance` queue:

```sh
bundle exec rake lgl:link_by_email_dry_run   # counts only
bundle exec rake lgl:link_by_email           # queue the links
```

It only sets External Constituent IDs in LGL (and the customer's `LGL ID`
tag). It never copies a name, street, phone or email in either direction:
each linked customer is marked as changed after the write, so the next poll
does not treat LGL as the newer copy.

#### Bringing existing constituents over

`lgl:replicate` makes every constituent with such an External constituent ID
a customer: it links it by email, creates a new customer, or leaves it in LGL
Review, as the poll does for new constituents. Run the dry run first; it prints
one line per constituent and writes nothing. Optional LGL ids limit either run
to those constituents and run it inline; without ids the real run is queued on
the `maintenance` queue:

```sh
bundle exec rake "lgl:replicate_dry_run[123,456]"   # what it would do
bundle exec rake lgl:replicate                      # queue the run
```

With sync `enabled` it queues one sync per linked or created customer, three
seconds apart to stay under LGL's rate limit. With sync `readonly` the
customers are still created and linked locally, but no syncs are queued,
except an immediate one for each address in `writable_address_ids`: nothing
else could be written to LGL. The counts include how many were skipped, as
`sync_skipped_readonly`.

The first `LglPollConstituents` run after sync is enabled reads nothing: it
records the current time as its watermark and logs `[LGL] poll: first run;
starting from <time>`. Only LGL changes made after that moment are copied into
Stagemgr; earlier ones are not. A disabled install never starts the clock.

`setup:doctor` reports one LGL line naming the mode. `LGL sync is disabled
(littlegreenlight.sync)` and `LGL sync is readonly — writes skipped for ...`
(listing any writable ids, and saying when `enabled` was downgraded in
development) are both OK. It warns when `sync` is a word other than `enabled`,
`readonly` or `disabled`, and when sync is on but `LGL_API_KEY` is missing;
in `enabled` mode it makes one read to confirm the key and warns if LGL
rejects it.

### `docker compose`

| Variable | Default | Purpose |
|---|---|---|
| `STAGEMGR_PORT` | `8080` | Host port for the app |
| `STAGEMGR_BIND` | `127.0.0.1` | Interface the published ports bind to |
| `MYSQL_PORT` | `3306` | |
| `REDIS_PORT` | `6379` | |
| `HOST_UID`, `HOST_GID` | -- | Linux only: renumber the container's `app` user so bind-mounted files come back owned by you |
| `DB_PREPARE_ON_BOOT` | `true` in development, `false` in production | Run `setup:bootstrap` on container start. Accepts `true`/`1`/`yes`, any case |
| `RESQUE_QUEUES` | `*` | Queues the containerized worker consumes |

### First-run and CI

| Variable | Purpose |
|---|---|
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | Skip `setup:admin`'s interactive prompts (scripted installs) |
| `MAIL_DUMP_DIR` | `spec/mailers/theme_render_spec.rb` writes every rendered email body under this directory, for before/after diffing |

### Reports run from cron

`db/reports/*.sh` are plain shell + SQL, not Rails, and take their configuration
from the cron environment:

| Variable | Default | Purpose |
|---|---|---|
| `REPORT_EMAIL` | **none -- the scripts abort without it** | Recipient and envelope sender for `mail_*.sh` |
| `REPORT_SUBJECT_TAG` | `StageMgr` | Prefix in the subject line, e.g. `[StageMgr] Unfulfilled Flexpasses` |
| `MY_CNF` | `$HOME/.my.cnf` | MySQL defaults file the HUD count scripts (`db/reports/hud/*.sh`) authenticate with |

## `config/server.yml`

Copied from `config/server.yml.example`. Keys under `all:` apply to every
environment; an environment block (`development:`, `test:`, `production:`)
overrides them by deep merge.

### Identity and mount point

| Key | Meaning |
|---|---|
| `app_name` | Display name in page titles and as the fallback house name before a theater row exists |
| `host` | Host used to build absolute URLs (email links, calendar feeds) |
| `host_protocol` | `http` or `https` for those URLs |
| `sub_uri` | Mount point when the app is **not** served from `/`, e.g. `/tickets`. Passed to ActionMailer as `:script_name`, so mail sent from a worker gets the prefix exactly once. **Leave it blank on a standalone install** |
| `secure_root_url` | Absolute base for the links in the generated public calendar feed (`ResqueJobs::GenerateCalendar`) |
| `static_cache_dir` | Where that generated calendar is written |
| `ext_site_wrapper` | Layout for the public order pages. `standalone` for a self-contained install; the name of an externally supplied layout when a marketing site wraps the app |
| `site_theme` | Directory under `sites/` holding this house's editorial copy. Commented out = generic copy ([Theming](theming.md)) |

### Sales rules

| Key | Meaning |
|---|---|
| `order_expiration_in_minutes` | How long an unpaid order is held |
| `restrict_sales_due_to_time_at_minutes_before` | Stop public sales this many minutes before curtain (inventory routes to the box office) |
| `minutes_before_performance_close_to_third_party_sales` | The same cut-off for theater users |
| `restrict_sales_due_to_capacity_at` | Seats remaining at or below which self-service sales stop; also drives "Call box office" on the calendar |
| `max_ticket_dropdown` | Largest quantity a patron can pick in one order |
| `resourced_default_runtime_minutes` | Assumed running time when `productions.running_time` is blank |
| `calendar_display.warning_at`, `calendar_display.critical_at` | Calendar heatmap thresholds, as a percentage of seats remaining |
| `allowed_order_task_suppressions` | Which order tasks a payment type may suppress |

### Reports and storage

| Key | Meaning |
|---|---|
| `hud_export_directory` | Where the HUD export jobs write their text files |
| `archive_directory` | Destination for data-retention archives. **Blank disables the archive/prune pipeline** -- the jobs refuse to run rather than delete rows nothing exported. Must be covered by your backups |
| `max_report_date_range_days` | Widest date range a report may request |
| `report_timeout_seconds` | Report query timeout |
| `report_frequent_customer_at`, `report_frequent_customer_range_days` | "Frequent customer" threshold on the house management report |

### `theater:` -- facts about the house

Plain, non-editorial facts printed on public order pages and in email. Every one
may be left blank: the sentence that would have used it is omitted rather than
printed empty. Anything with a *voice* to it belongs in a
[site theme](theming.md) instead. The full key list, with fallbacks, is in
[Theming → the `theater:` block](theming.md#the-theater-block).

!!! warning "The house's name is not a key here"
    It is the `name` of the **Default theater row** in the database, so the one
    proper noun that appears in dozens of places has a single source the box
    office already maintains. Renaming that row renames the house everywhere.

### `my_emma:`

| Key | Meaning |
|---|---|
| `newsletter_group`, `coupon_group` | Names of the MyEmma groups a patron joins when they tick the mailing-list box |
| `create_production_groups`, `create_theater_groups` | Whether new productions/theaters get their own Emma groups |

The two group-name keys have three distinct states:

| State | Behaviour |
|---|---|
| Key **absent** from `server.yml` | The historical names `Newsletter` and `Flash Offers`, so a config predating these keys keeps behaving as it did |
| Key present but **blank** | Nobody is added to that group -- an explicit opt-out, not a lookup for `""` |
| Key present with a name | That group |

Group ids are resolved by name and cached for five minutes: the API resolves a
name by listing every group in the account, so a lookup per order is expensive --
but a permanent memo would go on serving the id of a group that has since been
renamed. When MyEmma is configured *and* writable, `setup:doctor` checks that
each configured name actually exists in the account and warns if it does not.

### `email:`

| Key | Meaning |
|---|---|
| `delivery_method` | `postmark`, `file` (writes to `tmp/mails` -- the development default, so a fresh install needs no mail credentials), `sendmail`, `test` |
| `addresses.box_office` | Default From: for patron mail, and `TheaterInfo#box_office_email`; also a recipient of the refunded-fulfilled-order alert |
| `addresses.flex_pass_notifications` | Flex pass activity |
| `addresses.membership_notifications` | Membership activity |
| `addresses.supervisor_notifications` | High-priority system notices, including the refunded-fulfilled-order alert (`NotificationMailer#refunded_fulfilled_item_alert`, queued as a `NotificationTask` by `Order#refund!`) |
| `addresses.wheelchair_conversion_notifications` | Seat accessibility conversions |
| `addresses.software_address` | System/administrative mail; the last-resort sender |
| `addresses.exception_notifications` | Crash reports from the exception notifier |

`exception_notifications` falls back to `software_address`. With **neither**
configured the exception-notification middleware is left out of the stack
entirely and a warning is logged: `EmailNotifier` would otherwise build a mail
with no recipients and raise from inside the middleware while it was handling
the real exception, replacing a useful 500 page with a confusing one.

### `payment_processing:`

| Key | Meaning |
|---|---|
| `default_gateway` | `stripe`, `paypal`, `bogus` (the development/test default) |
| `default_recurring_gateway` | Gateway for subscriptions |
| `additional_card_types` | Comma-separated extra card brands to accept |
| `test_credit_card`, `test_card_brand` | Values the non-production forms pre-fill |

`RequiredSecrets` reads these: a `stripe` gateway makes `STRIPE_SECRET_KEY`
mandatory in production, and `delivery_method: postmark` makes
`POSTMARK_API_TOKEN` mandatory. See [Credentials](credentials.md).

### The Resque dashboard

`config/routes.rb` mounts the Resque web UI at `/admin/resque` with no other
authentication in front of it. Its HTTP basic-auth password comes from
`RESQUE_ADMIN_PASSWORD` or the `resque_admin_password` credential:

| Situation | Result |
|---|---|
| A password is configured | Basic auth, compared with `secure_compare` |
| None, **in production** | Denied to everyone (fail closed). An open queue dashboard exposes job arguments -- order ids, email addresses -- and offers a one-click "Clear failed jobs" |
| None, outside production | Open to anyone who can reach it |

A `resque_admin_password:` still sitting in `config/server.yml` keeps working
but warns once at boot. It is the only key with that plaintext fallback left.

### The test environment reads the example file

`config/environments/test.rb` loads the **tracked `config/server.yml.example`**,
not the `config/server.yml` you copied it to, so every checkout and every CI run
tests against the same values instead of whatever a developer's gitignored copy
happens to say. Cucumber forces `RAILS_ENV=test` too, so it does the same.

That makes the `test:` block part of the test suite. Its values are deliberate
sentinels -- `555-BOX-OFFICE`, `PICKUPWINDOW.TEST`, `https://WEBSITE.TEST`,
`Test Theater Box Office`, `Test Director` -- obviously fake, so a spec cannot
pass against a developer's real config by accident. Specs and Cucumber features
assert them.

!!! warning "Adding a key the tests need"
    Add it to the `test:` block of `config/server.yml.example`, not to your own
    `config/server.yml`. `test.rb` also forces `ext_site_wrapper` to
    `standalone` regardless of what the file says.

## Keys that are gone

| Key | Why |
|---|---|
| `filestore_hash` (`server.yml`) | Read by nothing. Deleted from all three blocks of the example |
| `email.addresses.online_errors` (`server.yml`) | Added in 2011 and never read by any code; unhandled exceptions go to `exception_notifications`. Deleted from the example -- a value left in your own file is ignored |
| `root_url` (`server.yml`) | Read by nothing -- only `secure_root_url` is. Still present in the example's environment blocks; do not rely on it |
| `resque_admin_password` (`server.yml`) | Now a deprecated fallback that warns at boot; use `RESQUE_ADMIN_PASSWORD` or the credential |
| `STRIPE_PUBLISHABLE_KEY` | Read by nothing; never prompted for |
| `config.external_site_root` (`development.rb`) | Pointed at a developer's home directory and was read by nothing |
