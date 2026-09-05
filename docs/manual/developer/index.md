# Developer Overview

!!! info "Who this section is for"
    Whoever installs, configures, deploys or extends Stagemgr. The rest of the
    manual is written for the people using it -- box office staff, house
    management, administrators.

## What is running

A Stagemgr install is five processes and two data stores.

```text
        browser
           │
        Nginx ──────────────► static files (optionally a separately built marketing site)
           │
      Passenger ──► Rails ──┬──► MySQL 8          orders, productions, patrons
           │                └──► Redis            Resque queues, Rack::Attack counters
           │
   Resque worker  ──────────┘    email, reports, imports, house counts
   Resque scheduler ────────┘    config/schedule.yml -- recurring jobs
```

The Docker stack in `docker-compose.yml` runs all of that in one container
(Passenger + Nginx + a runit-supervised worker and scheduler) plus a `mysql` and
a `redis` container. Theater Wit's production is the same shape on bare metal:
Passenger under Apache, workers started by `script/resque-worker`.

Nginx serves the app one of two ways, chosen at container boot:

| Mode | When | Result |
|---|---|---|
| **Standalone** | the default | Rails owns `/` |
| **Foundation** | a marketing-site build is mounted at `/var/www/foundation-dist` | static files at `/`, Rails under `/tickets` |

## Where configuration comes from

Four sources, each with a different job:

| Source | Holds | Notes |
|---|---|---|
| `config/server.yml` | Everything non-secret about this deployment: host names, mount point, business rules, email addresses, house facts, the site theme | Gitignored; created from the tracked `config/server.yml.example` |
| Environment (`.env`, Passenger `SetEnv`, Compose) | Database and Redis connection, secrets, feature switches | Gitignored; `.env` is read by dotenv in development and test only |
| Encrypted credentials | The same secrets, when the process environment is awkward to populate | `config/credentials/<env>.yml.enc` (or `config/credentials.yml.enc`) |
| The database | The house's name, theaters, venues, seat maps, productions | Maintained through the admin UI |

Secrets are read through one accessor, `AppSecrets`, which checks the
environment first (ignoring blank values), then credentials. See
[Credentials & secrets](credentials.md).

## Which page do I want?

| I want to… | Go to |
|---|---|
| Get an install running for the first time | [Installation](installation.md) |
| Understand a `.env` variable or a `server.yml` key | [Configuration](configuration.md) |
| Decide where a Stripe or Postmark key should live | [Credentials & secrets](credentials.md) |
| Replace "your theater" with my theater's own copy | [Site theming](theming.md) |
| Ship a change to a production box | [Deployment](deployment.md) |
| Work out why something will not boot | [Troubleshooting](troubleshooting.md) |

## First stop when something is wrong

```sh
bundle exec rake setup:doctor
```

`setup:doctor` boots the app and reports on `config/server.yml`, the site theme,
the public layout, the credentials store, where each secret resolves from, the
database and Redis connections and the MyEmma group names. It exits non-zero if
anything is broken, which is what makes it usable as a deploy gate as well as a
diagnostic. It never prints a secret's value -- only its source.

## A note on terminology

The customer-facing pages -- the calendar, the order form, the confirmation page
-- are the **public order pages**. They are not called a "storefront": in Chicago
theater, and in Theater Wit's own copy, a "storefront theater" is a small
resident company, and the collision is confusing in exactly the files where both
senses appear.
