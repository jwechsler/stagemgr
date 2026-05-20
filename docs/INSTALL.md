# Stagemgr Installation Instructions

Stagemgr is an open-source ticketing platform for live performance venues. It handles box-office sales, reserved seating, season passes, memberships, donations, payment processing through Stripe, and reporting. It runs on Rails 6 with a MySQL backend and Redis-backed background jobs. The Docker image ships with Phusion Passenger + Nginx as the application server — the same stack used in production, so RAILS_ENV is the only thing that distinguishes dev from prod. Puma stays in the Gemfile for ad-hoc `rails server` use on native installs. This document walks a fresh GitHub clone all the way from `git clone` to a working installation — first as a 5-minute Docker quickstart, then as a real production deployment.

***

## Prerequisites

For the **Docker** path (recommended for first-time users):

* Docker Desktop 4.x or newer (or Docker Engine + Compose v2 on Linux)

* \~4 GB of free RAM

* Ports `8080`, `3306`, and `6379` available on localhost

* Git, and a GitHub account if you want to push customizations

For the **native** path (recommended for development on the application itself):

* Ruby 3.2.2 (use `asdf`, `rbenv`, or `rvm`)

* Node.js 18 LTS (use `nvm`)

* MySQL 8.x running locally

* Redis 7.x running locally

* Build tooling: `libvips`, `mysql-client`, `openssl`, plus a C compiler

On macOS the native path needs extra build-tool setup (libvips and mysql-client headers via Homebrew). Use Docker unless you are actively modifying Stagemgr itself.

***

## Quickstart with Docker

The whole sequence is four commands and a one-time interactive wizard. The container stack (Passenger + Nginx + MySQL + Redis) is the same one that runs in production — switching environments is a matter of flipping RAILS_ENV.

```bash
git clone git@github.com:jwechsler/stagemgr.git
cd stagemgr
cp .env.example .env
docker compose up -d
docker compose exec stagemgr bundle exec rake setup:wizard
```

The wizard asks for:

* An admin email and password (this becomes your first user)

* A theater name and primary venue name

* Stripe test keys (optional — leave blank to skip payment configuration for now)

* Whether to create sample demo data (recommended for first run)

When it finishes, open <http://localhost:8080> in a browser and sign in with the credentials you just chose. You should see the theater dashboard with a sample production already scheduled.

To shut everything down: `docker compose down`. To wipe the database and start over: `docker compose down -v`.

***

## Native install (macOS / Linux)

### 1. Install runtime dependencies

**macOS (Homebrew):**

```bash
brew install mysql@8.0 redis vips libxml2 libxslt openssl@3
brew services start mysql@8.0
brew services start redis
```

**Ubuntu / Debian:**

```bash
sudo apt-get install -y mysql-server-8.0 redis-server \
  libvips libxml2-dev libxslt1-dev libmysqlclient-dev \
  build-essential
```

### 2. Install Ruby 3.2.2 and Node 18

```bash
asdf install ruby 3.2.2 && asdf local ruby 3.2.2
nvm install 18 && nvm use 18
gem install bundler:2.4.10
npm install -g yarn
```

### 3. Clone, configure, and bootstrap

```bash
git clone git@github.com:jwechsler/stagemgr.git
cd stagemgr
cp .env.example .env
# Edit .env — set DATABASE_USER, DATABASE_PASSWORD, and any Stripe test keys
bundle install
yarn install
bundle exec rake setup:wizard
```

### 4. Run it

In one terminal:

```bash
bundle exec rails server -p 8080
```

In another:

```bash
bundle exec rake resque:work QUEUE=*
```

Browse to <http://localhost:8080>.

***

## Configuration reference

All configuration is read from environment variables, typically via a `.env` file at the repo root. The `.env.example` shipped with the repo lists every variable; this section explains what each one does.

### Required

| Variable            | Description                       | Example                                                               |
| :------------------ | :-------------------------------- | :-------------------------------------------------------------------- |
| `DATABASE_USER`     | MySQL user for the Rails database | `stagemgr`                                                            |
| `DATABASE_PASSWORD` | MySQL password                    | (your value)                                                          |
| `DATABASE_HOST`     | Hostname of MySQL server          | `mysql` (Docker) / `127.0.0.1` (native)                               |
| `DATABASE_NAME`     | Database name                     | `stagemgr_development`                                                |
| `REDIS_URL`         | Redis connection URL              | `redis://redis:6379/0` (Docker) / `redis://127.0.0.1:6379/0` (native) |
| `SECRET_KEY_BASE`   | Rails session signing key         | Generate with `bin/rails secret`                                      |

### Stripe (payment processing)

| Variable                 | Description                                 |
| :----------------------- | :------------------------------------------ |
| `STRIPE_PUBLISHABLE_KEY` | Public key, prefix `pk_test_` or `pk_live_` |
| `STRIPE_SECRET_KEY`      | Secret key, prefix `sk_test_` or `sk_live_` |
| `STRIPE_SIGNING_SECRET`  | Webhook signing secret, prefix `whsec_`     |

Without these, the storefront still loads but checkout will fail. For testing, use Stripe's test keys and test card `4242 4242 4242 4242` with any future expiry and any CVC.

### Email (optional, recommended)

| Variable                | Description               |
| :---------------------- | :------------------------ |
| `POSTMARK_API_TOKEN`    | Postmark server API token |
| `POSTMARK_DEFAULT_FROM` | Verified sender address   |

If unset, Rails falls back to `:test` delivery in development (no real mail sent).

### CRM (optional)

| Variable             | Description            |
| :------------------- | :--------------------- |
| `MY_EMMA_USERNAME`   | MyEmma API public key  |
| `MY_EMMA_PASSWORD`   | MyEmma API private key |
| `MY_EMMA_ACCOUNT_ID` | MyEmma account ID      |

Only relevant if your venue uses MyEmma for mailing lists.

***

## Going to production

The quickstart configuration is fine for evaluation but not for a public-facing box office. To deploy for a real venue:

### 1. Use real Stripe keys

Switch `STRIPE_*` to live keys (`pk_live_`, `sk_live_`). Configure a webhook endpoint at `https://yourdomain.com/stripe/webhook` in the Stripe dashboard and copy the signing secret into `STRIPE_SIGNING_SECRET`. Test with a small live transaction before going public.

### 2. Verified email sending

Set up Postmark (or another transactional provider). With Postmark:

* Verify your sending domain (SPF + DKIM records)

* Create a server, copy its server API token into `POSTMARK_API_TOKEN`

* Set `POSTMARK_DEFAULT_FROM` to a verified sender address

### 3. HTTPS

Stagemgr runs over plain HTTP behind a reverse proxy. A typical reverse-proxy config terminates TLS and forwards to the stagemgr container on port 8080. Use `certbot` for free certificates from Let's Encrypt:

```bash
sudo certbot --nginx -d tickets.yourtheater.org
```

Set `RAILS_FORCE_SSL=true` in `.env` so Rails issues secure cookies and redirects HTTP to HTTPS.

### 4. Background worker as a service

Resque runs the job queue. On a systemd-based host, create `/etc/systemd/system/stagemgr-worker.service`:

```ini
[Unit]
Description=Stagemgr Resque worker
After=redis.service mysql.service

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/stagemgr/current
EnvironmentFile=/var/www/stagemgr/current/.env
ExecStart=/usr/bin/env bundle exec rake resque:work QUEUE=*
Restart=always

[Install]
WantedBy=multi-user.target
```

Then `sudo systemctl enable --now stagemgr-worker`.

### 5. Database backups

Schedule nightly backups via cron:

```bash
0 2 * * * mysqldump -u stagemgr -p"$DATABASE_PASSWORD" stagemgr_production | gzip > /var/backups/stagemgr/$(date +\%Y\%m\%d).sql.gz
```

Keep at least 30 days. Test restores quarterly — an untested backup is not a backup.

### 6. Production Rails configuration

In your production `.env` — the `RAILS_LOG_TO_STDOUT` line below is the Docker-friendly default (logs go to the container stdout where the Docker daemon, systemd, or a log aggregator collects them). Drop it if you'd rather have Rails write `log/production.log` and rotate it yourself with logrotate.

```ini
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
```

Precompile assets at deploy time: `bundle exec rake assets:precompile`.

***

## Troubleshooting

**`bundle install`** **fails on macOS with mysql2 errors.**
Install via Homebrew and point Bundler at it:

```bash
brew install mysql@8.0 openssl@3
bundle config build.mysql2 --with-ldflags="-L$(brew --prefix openssl@3)/lib" \
                           --with-cppflags="-I$(brew --prefix openssl@3)/include"
```

**`yarn install`** **fails with a Node version error.**
Stagemgr requires Node 18. Older versions fail on Webpacker dependencies; newer versions need `--openssl-legacy-provider`. Run `nvm use 18` first.

**Docker compose says "port already in use".**
Something is already using 8080, 3306, or 6379. Either stop the conflicting service or override the host port in `docker-compose.yml` (e.g., `"8081:8080"`).

**Rails boots but Stripe checkout shows "no API key provided".**
Your `.env` either doesn't have `STRIPE_SECRET_KEY` set, or the container started before the file existed. Restart with `docker compose restart stagemgr`.

**`Resque::NoQueueError`** **in the dashboard.**
Resque didn't restart with the stagemgr container. Check `docker compose ps`; restart the stagemgr container to relaunch the worker: `docker compose restart stagemgr`.

**Can't log in even with the password I set in the wizard.**
Passwords are SCrypt-hashed; resetting requires console access:

```bash
docker compose exec stagemgr bundle exec rails runner \
  'u = User.find_by(email: "you@example.com"); u.password = u.password_confirmation = "newpass"; u.save!'
```

***

## Operations

### Common rake tasks

| Task                  | What it does                                 |
| :-------------------- | :------------------------------------------- |
| `setup:wizard`        | Interactive first-run setup                  |
| `setup:bootstrap`     | Non-interactive db prepare + seed            |
| `setup:demo_data`     | Create a sample production with performances |
| `resque:work QUEUE=*` | Run a background worker                      |
| `db:prepare`          | Create database + run migrations             |

### Useful URLs (default ports)

* `http://localhost:8080/` — Public storefront

* `http://localhost:8080/admin` — Admin / box office

* `http://localhost:8080/resque` — Background job dashboard (admin login required)

### Log locations

* Docker: `docker compose logs -f web`

* Native: `log/development.log` or `log/production.log`

***

## Getting help

* Open an issue at <https://github.com/jwechsler/stagemgr/issues>

* For commercial support inquiries, contact the maintainer through the GitHub profile
