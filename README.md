# Stagemgr

Stagemgr is a ticketing platform for live performance venues: box-office and
public ticket sales, reserved seating, flex passes, memberships, donations,
Stripe checkout, and the reporting a box office actually runs on. It is a Rails
6 application on MySQL 8 with Redis-backed Resque jobs, served by Phusion
Passenger behind Nginx.

## Quickstart

Requires Docker Compose 2.24 or newer.

```sh
git clone git@github.com:jwechsler/stagemgr.git
cd stagemgr
cp .env.example .env
docker compose up -d --build
docker compose exec -u app stagemgr bundle exec rake setup:wizard
docker compose up -d          # pick up the SECRET_KEY_BASE the wizard wrote
```

The first boot builds the image and installs gems and JavaScript packages, so
give it several minutes -- `docker compose logs -f stagemgr` shows where it is.
The wizard then asks for an administrator login, a theater and venue name, an
optional site theme and optional Stripe test keys, and offers to create a sample
production.

When it finishes, open <http://localhost:8080/login> and sign in with the
administrator credentials you chose.

> **Do not skip the wizard on anything reachable.** The first boot seeds a
> placeholder administrator, `admin@yourtheater.com`, whose password is in this
> repository, and a Default theater row named `Theater 1` that would otherwise
> become your house's name in every email. `rake setup:admin` and
> `rake setup:theater` (both of which the wizard runs) replace them in place.

`docker compose down` stops the stack; `docker compose down -v` also destroys
the database.

## Documentation

The manual is published at <https://stagemgr.theaterwit.org/>. The developer
section lives in this repository under `docs/manual/developer/`:

| Page | Covers |
|---|---|
| [Developer overview](docs/manual/developer/index.md) | How the pieces fit together, and which page answers which question |
| [Installation](docs/manual/developer/installation.md) | Docker stack, native macOS/Linux install, the Theater Wit workspace |
| [Configuration](docs/manual/developer/configuration.md) | Every `.env` variable and every `config/server.yml` key |
| [Credentials & secrets](docs/manual/developer/credentials.md) | Resolution order, `.env` vs encrypted credentials, the production boot check |
| [Site theming](docs/manual/developer/theming.md) | Putting your house's copy and facts into the app |
| [Deployment](docs/manual/developer/deployment.md) | Bare-metal Passenger deploys, background workers, cron reports |
| [Troubleshooting](docs/manual/developer/troubleshooting.md) | The failures that cost someone a day |

The rest of the manual documents the application itself -- productions,
ticketing, house management, reports.

## Repository layout

| Path | Contents |
|---|---|
| `app/`, `config/`, `db/`, `lib/` | The Rails application |
| `sites/` | Site themes: one directory per house of editorial copy that overrides `app/views` ([sites/README.md](sites/README.md)) |
| `docker/` | Dockerfile, the two Nginx site configs, runit services for Resque, MySQL init scripts |
| `bin/docker-entrypoint` | What the container does on every start |
| `bin/deploy` | Bare-metal production deploy (git pull → gems → migrate → assets → restart → smoke check) |
| `script/resque-worker`, `script/scheduler` | Background job processes for a native or bare-metal install |
| `lib/tasks/setup.rake`, `lib/tasks/setup/` | `rake setup:config`, `setup:wizard`, `setup:doctor` and friends |
| `db/reports/` | Legacy shell + SQL reports mailed by cron |
| `spec/`, `features/` | RSpec and Cucumber suites |
| `docs/` | This manual (MkDocs), runbooks, feature announcements |

## Running the tests

```sh
bundle exec rspec
bundle exec cucumber
```

Both run in the `test` environment, which reads the tracked
`config/server.yml.example` rather than your own `config/server.yml` -- see
[Configuration](docs/manual/developer/configuration.md#the-test-environment-reads-the-example-file).
