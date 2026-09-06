# Deployment

The reference production deployment is **bare metal**: a flat git checkout at
`~/stagemgr`, served by Phusion Passenger, with the Resque worker and scheduler
started as ordinary background processes. This page documents that path first,
because it is the one in daily use, and then what a container-based production
would need.

## The shape of a production box

| Piece | How |
|---|---|
| Web | Passenger, restarted by `touch tmp/restart.txt` |
| Static files | The web server serves `public/` directly -- `config.public_file_server.enabled` is off unless `RAILS_SERVE_STATIC_FILES` is set, and `config.assets.compile` is `false`, so assets must be precompiled at deploy time |
| Background jobs | `script/resque-worker start` -- three workers in production, split by queue |
| Recurring jobs | `script/scheduler start` (`config/schedule.yml`) |
| Configuration | `config/server.yml` on the box (gitignored) |
| Secrets | Encrypted credentials plus `config/master.key` on disk |
| Reports | `db/reports/*.sh` from cron |

## `bin/deploy`

```sh
ssh yourbox 'stagemgr/bin/deploy'
```

It runs the deploy sequence in a fixed order so no step can be forgotten:

1. `git checkout master` and `git pull --ff-only`
2. `bundle check || bundle install`
3. `yarn install --frozen-lockfile`
4. `rails db:migrate`
5. `rake setup:doctor` -- fails the deploy here, while the old code is still
   serving, if a required secret or config file is missing
6. `rails assets:precompile`
7. `touch tmp/restart.txt` (Passenger)
8. `script/resque-worker restart`
9. `script/scheduler stop || true` then `script/scheduler start`
10. A `curl` smoke check against `SMOKE_URL`

Every step is idempotent, so a failed deploy is retried by running the script
again. The smoke check doubles as the request that boots the new code under
Passenger, so a boot crash -- a missing gem, a missing secret -- fails the deploy
there instead of surfacing to the first customer. Each run appends a line to
`log/deploys.log`.

Two knobs: `SMOKE_URL` (defaults to Theater Wit's login page) and
`FORCE_DEPLOY=1`, which lifts the guard that refuses to run anywhere but
`$HOME/stagemgr` -- the development tree must never receive production rake
tasks.

!!! tip "The doctor is the deploy gate"
    `bin/deploy` runs `rake setup:doctor` after migrating and before
    precompiling, so a broken install fails *before* `touch tmp/restart.txt`
    rather than after. You can also run it by hand at any time:
    ```sh
    RAILS_ENV=production bundle exec rake setup:doctor
    ```
    `rake setup:doctor` is one of the tasks exempt from the production
    [required-secrets check](credentials.md#the-production-boot-check), so it
    can run on a box that is not configured yet and tell you what is wrong.

### Restricting the production bundle

Configure Bundler once on the box:

```sh
bundle config set --local without 'development test cucumber'
```

That writes `.bundle/config` in the app directory and persists across deploys.
Without it, any gem later added to the `:development`, `:test` or `:cucumber`
group has to be installed on the production box too or the app fails to boot
with `Bundler::GemNotFound`. The application itself is unaffected --
`config/application.rb` requires only the `:default` and `:production` groups
there.

It is also why **dotenv is not available in production**: it is a
development/test-group gem. A `.env` file on a bare-metal production box is read
by nothing.

Confirm with `bundle config` (the `without` list should show all three groups)
and `bundle check`.

### Background workers

```sh
script/resque-worker {start|stop|status|restart}
script/scheduler {start|stop}
```

In production `script/resque-worker start` launches three workers, each with its
own pidfile and log:

| Queues | Log |
|---|---|
| `notification,report,import,sync` | `log/resque.log` |
| `printing,batch_printing` | `log/printing_queue.log` |
| `default,maintenance` | `log/maintenance_queue.log` |

Outside production it starts a single worker on `QUEUE=*`, honouring whatever
`RAILS_ENV` you exported.

!!! warning "Workers need the secrets too"
    Workers boot through `rake environment resque:work`, and `resque:` tasks are
    the one rake prefix the [required-secrets check](credentials.md#which-processes-enforce-it)
    still enforces. A worker without secrets is as broken as a web process -- it
    delivers all the mail.

### Serving under a sub-path

Theater Wit serves the app at `/tickets` under a marketing site. Three things
must agree:

| Where | Value |
|---|---|
| `config/server.yml` | `sub_uri: "/tickets"` |
| The process environment | `RAILS_RELATIVE_URL_ROOT=/tickets` (Passenger sets this from `passenger_base_uri`; Compose passes `STAGEMGR_SUB_URI` through) |
| The web server | `passenger_base_uri /tickets`, as `docker/nginx.foundation.conf` does |

`sub_uri` is passed to ActionMailer as `:script_name` rather than being folded
into `:host`. Route helpers only know about the mount when the process exports
`RAILS_RELATIVE_URL_ROOT`, and the Resque worker that delivers most of the mail
has no such environment -- passing `:script_name` explicitly settles it for every
process, so the prefix appears exactly once whether mail is delivered from a
worker or inline from a web request.

### Credentials on the box

```sh
RAILS_ENV=production bin/rails credentials:edit --environment production
```

The box needs the matching key: `config/credentials/production.key` (or
`config/master.key` for the shared pair) on disk, or `RAILS_MASTER_KEY` in the
Passenger **and** worker environments. Both `.key` files are gitignored --
**never commit one**. See [Credentials & secrets](credentials.md).

## Standing up a new production box

Beyond the checklist below, a **brand-new** install has two placeholders to
clear. `setup:bootstrap` seeds an empty database, and `db/seeds.rb` creates:

| Placeholder | Why it matters |
|---|---|
| Administrator `admin@yourtheater.com` | Its password is published in this repository |
| Default theater row `Theater 1` | `Theater.default_theater.name` is the house name on every public page and in every email |

```sh
RAILS_ENV=production bundle exec rake setup:admin     # renames the placeholder account
RAILS_ENV=production bundle exec rake setup:theater   # renames the Default row
```

`setup:admin` rewrites the placeholder only while it is still the *only*
administrator; once a real one exists it creates a new account instead.
`setup:theater` always updates the existing Default row rather than adding a
second one -- a second Default row would be inert, because `default_theater` is
the oldest. Verify before opening the doors:

```sh
RAILS_ENV=production bundle exec rails runner \
  'puts User.where(is_administrator: true).pluck(:email).inspect, Theater.default_theater&.name'
```

Also set `sub_uri:` in `config/server.yml` to match how the web server actually
mounts the app -- blank when Rails owns `/`, `/tickets` when it does not. It is
folded into every mailed URL.

## Before deploying at an existing install

A checklist for the first deploy of a Stagemgr carrying site themes, the
`theater:` block and the `AppSecrets` accessor.

1. **Add the new `config/server.yml` keys** on the box (the file is gitignored,
   so nothing arrives with the deploy):
    - `site_theme:` -- your theme slug, if you have one
    - the whole `theater:` block ([Theming](theming.md#the-theater-block))
    - `my_emma: newsletter_group: / coupon_group:` -- set these explicitly if you
      rely on names other than `Newsletter` and `Flash Offers`
    - `email: addresses: exception_notifications:` -- otherwise crash reports
      fall back to `software_address`
2. **Confirm the Default theater row's `name`** is the house name you want in
   every email. It now drives all proper-noun copy.
3. **Check the process environment for stale secret variables.** The
   environment now beats credentials, which is a reversal for Postmark and
   MyEmma:
   ```sh
   env | grep -E 'POSTMARK|STRIPE|MY_EMMA|RESQUE_ADMIN|SECRET_KEY_BASE'
   ```
   Anything set must be non-blank **and** equal to the credential, or the winner
   changes at the next restart. Delete blank lines rather than emptying them.
4. **Set `REPORT_EMAIL`** (and optionally `REPORT_SUBJECT_TAG`) in the cron
   environment -- `db/reports/mail_*.sh` now abort without it rather than mailing
   a placeholder address.
5. **Run the doctor** and read every line:
   ```sh
   RAILS_ENV=production bundle exec rake setup:doctor
   ```
6. Only then deploy and restart.

## Reports from cron

`db/reports/mail_*.sh` build a text report with `mysql` and mail it with `mutt`
or `mailx`. They read:

| Variable | Default | Purpose |
|---|---|---|
| `REPORT_EMAIL` | none -- the script aborts | Recipient and envelope sender |
| `REPORT_SUBJECT_TAG` | `StageMgr` | Subject prefix, e.g. `[StageMgr] Unfulfilled Flexpasses` |
| `MY_CNF` | `$HOME/.my.cnf` | MySQL defaults file used by the HUD scripts in `db/reports/hud/` |

There is deliberately no default recipient: a report quietly mailed to a
placeholder address is worse than a cron job that fails loudly.

## Docker in production

The image can run with `RAILS_ENV=production` -- the entrypoint precompiles
assets, gates the boot on `rake setup:doctor` and defaults `DB_PREPARE_ON_BOOT`
to `false` -- but `docker/Dockerfile` describes itself as built for development
and CI, and the shipped `docker-compose.yml` is a development stack. Before
serving patrons from it, expect to supply at least:

- **Secrets from the deploy environment**, not from a bind-mounted `.env`
  (`environment:` in a production override file, or Docker/Swarm secrets read as
  files and exported).
- **TLS and a public reverse proxy** in front of the container. The image
  listens on plain HTTP on port 80 and `config.force_ssl` is commented out in
  `config/environments/production.rb`.
- **A published port that is not loopback-only**, deliberately
  (`STAGEMGR_BIND`), or a proxy on the same Docker network.
- **A managed database.** The `mysql` service here has a development password
  scheme and bakes its credentials into a local volume; production data wants a
  real MySQL with backups.
- **Log and asset handling.** `RAILS_LOG_TO_STDOUT=true` for a container log
  driver; a plan for `public/assets` and `public/packs`, which are precompiled
  into the bind mount at boot.
- **A migration step outside the container lifecycle**, since
  `DB_PREPARE_ON_BOOT` is off there by design.
