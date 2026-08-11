# utf8mb4 Conversion Runbook

One-time production procedure for the two migrations that move the database off latin1:

- `db/migrate/20260725120000_shrink_address_search_index_for_utf8mb4.rb`
- `db/migrate/20260725120100_convert_database_to_utf8mb4.rb`

## Why

28 tables were `latin1` and 10 were `utf8mb3`. The latin1 tables cannot store characters box office staff routinely paste from Word, Google Docs and e-mail, so MySQL rejected the write instead of coercing it:

```
Mysql2::Error: Incorrect string value: '\xEF\xBB\xBFBla...'
  for column 'special_feature_display_markdown' at row 1
```

After the conversion the whole database is `utf8mb4` / `utf8mb4_0900_ai_ci`.

## Conventions

Commands use the Docker Compose layout from staging. On the production host set these once per shell:

```bash
export COMPOSE='docker compose -f /path/to/site/docker-compose.yml'
alias mysql-prod="$COMPOSE exec -T mysql mysql stagemgr_production"
alias rails-runner="$COMPOSE exec -T stagemgr bash -c 'cd /var/www/stagemgr && bundle exec rails runner'"
alias rails-db="$COMPOSE exec -T stagemgr bash -c 'cd /var/www/stagemgr && bundle exec rails db:migrate'"
```

## Read this first: the rebuild is not online

`CONVERT TO CHARACTER SET` changes column byte widths, so InnoDB refuses to do it in place:

```
ERROR 1846: ALGORITHM=INPLACE is not supported. Reason: Cannot change column type INPLACE.
```

It rebuilds each table under `ALGORITHM=COPY`, holding a lock that **blocks writes to that table** for the duration. Plan for one of:

- **A maintenance window** with the site in a holding page. Simplest, and fine if the tables are small enough — time it on a staging copy first.
- **`gh-ost` or `pt-online-schema-change`** for the large tables, then let the migration handle the rest. The migration is safe to re-run and skips anything already converted, so tables you convert out of band are simply passed over.

Largest tables by string-column count, i.e. the ones worth timing:

| table | string columns |
|---|---|
| `addresses` | 23 |
| `orders` | 13 |
| `audits` | 9 |
| `payments` | 7 |

Get real numbers before choosing:

```bash
mysql-prod -e "SELECT TABLE_NAME, TABLE_ROWS,
  ROUND((DATA_LENGTH+INDEX_LENGTH)/1024/1024) AS mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE'
ORDER BY DATA_LENGTH+INDEX_LENGTH DESC LIMIT 10;"
```

## Behaviour changes to know about

### Collation is more accent-insensitive than latin1 was

`latin1_swedish_ci` already folded most Western accents but treated the Swedish vowels and sharp s as distinct letters. `utf8mb4_0900_ai_ci` folds everything:

| pair | latin1_swedish_ci | utf8mb4_0900_ai_ci |
|---|---|---|
| `cafe` / `café` | equal | equal |
| `n` / `ñ` | equal | equal |
| `a` / `ä` | **different** | equal |
| `o` / `ö` | **different** | equal |
| `a` / `å` | **different** | equal |
| `ss` / `ß` | **different** | equal |

Consequences: patron uniqueness checks and lookups match more broadly (generally an improvement for box office search), and `ORDER BY name` output shifts for those characters.

A unique index whose rows differ only by one of those characters would make the conversion fail with `ERROR 1062: Duplicate entry`. The only unique string index on a latin1 table is `orders.uuid`, which is hex, so there is nothing to collide. Confirm before converting anyway:

```bash
mysql-prod -e "SELECT uuid, COUNT(*) FROM orders
  GROUP BY CONVERT(uuid USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
  HAVING COUNT(*) > 1;"
```

**Expected:** empty result.

### TEXT columns become MEDIUMTEXT

MySQL widens 23 `TEXT` columns to `MEDIUMTEXT` during the conversion. This is documented behaviour: `TEXT` holds 65,535 *bytes*, so under a 4-byte charset the type has to grow to still hold as many *characters* as before. Forcing them back to `TEXT` would risk truncating existing long values. No `varchar` widths change.

### MySQL 8 only

`utf8mb4_0900_ai_ci` does not exist in MariaDB — MariaDB 10.11 cannot even load `db/schema.rb`. This was already true of the ten tables that used the collation before this change, but the conversion makes it total.

## Procedure

### 1. Back up

```bash
$COMPOSE exec -T mysql mysqldump --single-transaction --no-tablespaces \
  stagemgr_production | gzip > stagemgr_pre_utf8mb4.sql.gz
```

Keep this until the conversion has been in production for a full sales cycle. `down` on the conversion migration deliberately raises `IrreversibleMigration` — reverting to latin1 would silently destroy any character latin1 cannot represent, so **this dump is the only rollback path**.

### 2. Record the starting state

```bash
mysql-prod -e "SELECT TABLE_COLLATION, COUNT(*) FROM information_schema.TABLES
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE' GROUP BY TABLE_COLLATION;"
```

Save the output. You will diff against it in step 6.

### 3. Deploy the index change ahead of the rebuild

`ShrinkAddressSearchIndexForUtf8mb4` prefix-limits `index_address_search`, which otherwise blocks the conversion:

```
ERROR 1071: Specified key was too long; max key length is 3072 bytes
```

Four `varchar(255)` columns need 4080 bytes under utf8mb4. It only fits today because `addresses` is utf8mb3 (3060 bytes — twelve under the limit). Deploy and verify this on its own first:

```bash
mysql-prod -e "SHOW INDEX FROM addresses WHERE Key_name='index_address_search';"
```

**Expected:** four rows with `Sub_part` of 20, 100, 60, 100.

Confirm the duplicate-detection query still uses it:

```bash
mysql-prod -e "EXPLAIN SELECT * FROM addresses
  WHERE street_number='123' AND street='MAIN' AND city='CHICAGO' AND search_name='SMITH';"
```

**Expected:** `index_address_search` in `possible_keys`. On a populated table the planner may legitimately choose `index_addresses_on_search_name_and_email` instead; what matters is that all four columns remain usable (`FORCE INDEX (index_address_search)` should show `ref: const,const,const,const`).

### 4. Convert

In the maintenance window:

```bash
rails-db
```

The migration logs each table as it goes. If it dies partway through, **just run it again** — it filters on current collation, so completed tables are skipped.

### 5. Update the server's database.yml

`config/database.yml` is gitignored and generated outside the repo, so the deployed copy needs this by hand:

```yaml
production:
  adapter: mysql2
  encoding: utf8mb4
  collation: utf8mb4_0900_ai_ci
  # ...existing settings
```

Restart the app and workers afterward. Confirm the connection charset:

```bash
rails-runner 'puts ActiveRecord::Base.connection.select_value("SELECT @@character_set_client")'
```

**Expected:** `utf8mb4`

### 6. Verify

Every table converted:

```bash
mysql-prod -e "SELECT TABLE_COLLATION, COUNT(*) FROM information_schema.TABLES
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE' GROUP BY TABLE_COLLATION;"
```

**Expected:** a single `utf8mb4_0900_ai_ci` row. `schema_migrations` and `ar_internal_metadata` are skipped by design and may still show their old collation — that is fine, nothing joins them.

The previously failing column now accepts what it used to reject:

```bash
rails-runner 'p = Performance.last;
  p.update!(special_feature_email_markdown: "check 🎉 你好 “quoted” café");
  puts p.reload.special_feature_email_markdown'
```

**Expected:** the string back verbatim, emoji intact. Before the conversion this raised `ActiveRecord::StatementInvalid`.

Byte-order marks are still stripped on save — `TextSanitizable` handles that, and it must keep doing so. utf8mb4 accepts a BOM silently, so without the scrub an invisible character would lodge itself permanently in web copy and confirmation e-mails:

```bash
rails-runner 'p = Performance.last;
  p.update!(special_feature_email_markdown: "﻿Blackout Night");
  puts p.reload.special_feature_email_markdown.codepoints.first(3).inspect'
```

**Expected:** `[66, 108, 97]` (`Bla`), not `[65279, ...]`.

### 7. Watch for a day

```bash
$COMPOSE exec -T stagemgr bash -c "grep -iE 'Incorrect string value|Illegal mix of collations' \
  /var/www/stagemgr/log/production.log | tail -20"
```

**Expected:** nothing. Both error classes should be extinct — that is the point of the change.
