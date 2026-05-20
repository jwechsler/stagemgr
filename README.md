# Stagemgr

Open-source ticketing platform for live performance venues — box office,
reserved seating, season passes, memberships, donations, Stripe checkout,
and reporting. Built on Rails 6, MySQL, and Redis; served by Phusion
Passenger + Nginx in Docker.

## Quickstart

```bash
git clone git@github.com:jwechsler/stagemgr.git
cd stagemgr
cp .env.example .env
docker compose up -d
docker compose exec stagemgr bundle exec rake setup:wizard
```

Then open <http://localhost:8080> and sign in with the admin credentials
the wizard prompted you for.

## Full installation

See **[docs/INSTALL.md](docs/INSTALL.md)** for:

- 5-minute Docker quickstart
- Native install (macOS / Linux) for app development
- Configuration reference for every `.env` variable
- Going-to-production guide (Stripe live keys, Postmark, HTTPS, backups,
  systemd worker unit)
- Troubleshooting and operations cheatsheet

## Repository layout

- `app/`, `config/`, `db/`, `lib/` — Rails application
- `docker/` — Dockerfile + Nginx configs (`nginx.conf` default,
  `nginx.foundation.conf` for the `--profile frontend` mode)
- `bin/docker-entrypoint` — boots the stagemgr container (bundle, yarn,
  webpacker, db:prepare, Resque worker + scheduler, Passenger)
- `lib/tasks/setup.rake` — `setup:wizard` and friends
- `.env.example` — every environment variable the app reads
- `docs/` — installation, runbooks, feature announcements, mkdocs site

## Getting help

- Open an issue at <https://github.com/jwechsler/stagemgr/issues>
- For commercial support inquiries, contact the maintainer via GitHub
