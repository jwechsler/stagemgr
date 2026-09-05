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
| `STAGEMGR_SUB_URI` | Sub-path the app is mounted at, e.g. `/tickets`. Compose passes it through as `RAILS_RELATIVE_URL_ROOT`; it must agree with `server.yml`'s `sub_uri` |
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
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | ActiveStorage on S3 (uncomment the matching block in `config/storage.yml`). Blank means local disk |
| `PAYPAL_LOGIN`, `PAYPAL_PASSWORD`, `PAYPAL_SIGNATURE`, `PAYPAL_PEM_FILE`, `PAYPAL_EXPRESS_LOGIN`, `PAYPAL_EXPRESS_PASSWORD` | Legacy PayPal gateways only |

!!! note "Development runs MyEmma read-only"
    `config/environments/development.rb` calls `MyEmma.read_only!` after setting
    credentials: reads work, writes are logged and skipped, whatever account the
    credentials point at.

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
| `addresses.box_office` | Default From: for patron mail, and `TheaterInfo#box_office_email` |
| `addresses.online_errors` | Online order processing errors |
| `addresses.flex_pass_notifications` | Flex pass activity |
| `addresses.membership_notifications` | Membership activity |
| `addresses.supervisor_notifications` | High-priority system notices |
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
| `root_url` (`server.yml`) | Read by nothing -- only `secure_root_url` is. Still present in the example's environment blocks; do not rely on it |
| `resque_admin_password` (`server.yml`) | Now a deprecated fallback that warns at boot; use `RESQUE_ADMIN_PASSWORD` or the credential |
| `STRIPE_PUBLISHABLE_KEY` | Read by nothing; never prompted for |
| `config.external_site_root` (`development.rb`) | Pointed at a developer's home directory and was read by nothing |
