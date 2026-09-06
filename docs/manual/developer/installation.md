# Installation

Two supported paths. Use Docker unless you have a reason not to: it is the same
Passenger + Nginx stack that runs in production, and it brings its own MySQL and
Redis.

- **[Docker](#docker)** -- one command to a running app; everything except the
  source tree is disposable.
- **[Native](#native-install-macos-linux)** -- Ruby, MySQL and Redis on your own
  machine. Faster test runs, more setup.

## Docker

### Prerequisites

- Docker Compose **2.24 or newer** (`docker compose version`). `docker-compose.yml`
  uses the long-form `env_file:` with `required: false`, which older versions
  reject.
- Typically around 4 GB of free RAM and a few GB of disk for the image.
- Free ports on loopback: 8080, 3306, 6379 -- all three are overridable, see
  [Ports](#ports-and-a-second-stack).

### First run

```sh
git clone git@github.com:jwechsler/stagemgr.git
cd stagemgr
cp .env.example .env
docker compose up -d --build
docker compose exec -u app stagemgr bundle exec rake setup:wizard
docker compose up -d          # pick up the SECRET_KEY_BASE the wizard wrote
```

Then open <http://localhost:8080/login> and sign in with the administrator
credentials you chose.

The first boot installs gems and JavaScript packages and loads the schema, so
give it several minutes; `docker compose logs -f stagemgr` shows where it is,
and it ends with `==> Boot complete (development)`.

`cp .env.example .env` is optional -- the entrypoint runs `rake setup:config`,
which creates `.env` and the `config/*.yml` files from their tracked `.example`
templates on the first boot. Copying it first only means Compose can read your
values on that same first boot.

!!! warning "Why the second `up -d`"
    `setup:wizard` writes a generated `SECRET_KEY_BASE` (and any Stripe keys you
    give it) into `.env`. Compose only reads `.env` when it **creates** a
    container, and dotenv never overwrites a variable that is already set -- so
    the running container still has the blank value it started with, and
    `docker compose restart` does not change that. `docker compose up -d`
    recreates the container with the new environment. Until you do,
    `setup:doctor` reports `secret_key_base: ENV[...] is present but BLANK` and
    sessions do not survive a restart.

!!! note "Always `-u app`"
    `docker compose exec` runs as **root** by default, and anything root writes
    into the bind mount (`log/`, `tmp/`, `public/packs`) is then owned by root
    on your host too. `-u app` runs as the same user Passenger and the Resque
    workers use. Gems resolve either way -- the image puts the app's RVM gemset
    on `PATH`, `GEM_HOME` and `GEM_PATH` for non-login shells, which is what
    `docker compose exec` uses.

### What the wizard asks

Each step is also a rake task of its own, and all of them are idempotent.

| Step | Prompt | Default | Skipped by |
|---|---|---|---|
| Session signing key | none | -- | -- |
| Database | none | -- | -- |
| Administrator account | email, then password (not echoed) | none -- a value is required | `ADMIN_EMAIL`, `ADMIN_PASSWORD` |
| Theater and venue | theater name, primary venue name | the existing Default theater / first venue, else `My Theater` / `Main Stage` | -- |
| Site theme | theme slug | blank -- press Enter to skip and use the generic copy | -- |
| Payment processing | "Configure Stripe keys now?", then the two keys | `Y` | answer `n` |
| Demo data | "Create sample demo data?" | `Y` | answer `n` |
| Health check | none -- runs `setup:doctor` | -- | -- |

Only the administrator step reads environment variables, so a scripted install
still has to feed the rest on stdin:

```sh
printf 'My House\nMain Stage\n\nn\ny\n' | docker compose exec -T -u app \
  -e ADMIN_EMAIL=you@example.org -e ADMIN_PASSWORD=a-real-password \
  stagemgr bundle exec rake setup:wizard
```

!!! danger "The seeded placeholders"
    `setup:bootstrap` seeds an empty database, and `db/seeds.rb` creates an
    administrator `admin@yourtheater.com` **whose password is published in this
    repository**, plus a Default theater row named `Theater 1` (which would
    otherwise become your house's name everywhere). The wizard replaces both:
    `setup:admin` renames the placeholder account while it is still the only
    administrator, and `setup:theater` renames the existing Default row rather
    than adding a second one. If you skip the wizard, run those two tasks --
    and check `User.where(is_administrator: true).pluck(:email)` before letting
    anyone reach the install.

### What the container does on every start

`bin/docker-entrypoint` is idempotent and overwrites nothing that already
exists:

1. Optionally renumbers the `app` user to match `HOST_UID`/`HOST_GID` (Linux
   bind mounts).
2. `bundle install`.
3. `rake setup:config` -- scaffolds `config/*.yml` and `.env` from the templates.
4. **Production only:** `rake setup:doctor`, and refuses to serve if it fails.
5. `yarn install` and `rails webpacker:compile` (plus `assets:precompile` in
   production).
6. `rake setup:bootstrap` -- create the database, load `db/schema.rb`, migrate,
   seed if there are no users. Controlled by `DB_PREPARE_ON_BOOT`.
7. Installs the Nginx site config: foundation mode if `/var/www/foundation-dist`
   is mounted, standalone otherwise.
8. `exec`s `/sbin/my_init`, which starts Nginx, Passenger and the runit-managed
   Resque worker and scheduler.

In development every step is guarded: a failure is reported and the container
stays up so you can exec in and fix it. In production every step is fatal. The
one exception is `bundle install`, which is fatal in every environment -- nothing
after it can run without gems, so continuing would replace one clear error with
a page of confusing ones.

!!! warning "Rebuild after editing the image's own files"
    `bin/docker-entrypoint`, `docker/nginx.conf`, `docker/nginx.foundation.conf`
    and `docker/service/**` are **baked into the image**, not bind-mounted.
    Changing one needs `docker compose build` (or `up -d --build`). Everything
    under `app/`, `config/`, `lib/` and `sites/` is live in the bind mount and
    needs no rebuild.

### Everyday commands

```sh
docker compose logs -f stagemgr                  # boot output, Passenger, workers
docker compose exec -u app stagemgr bash         # a shell as the app user
docker compose exec -u app stagemgr bundle exec rails c
docker compose exec -u app stagemgr bundle exec rake setup:doctor
docker compose exec -u app stagemgr bundle exec rspec spec/models/theater_info_spec.rb
docker compose restart stagemgr                  # re-runs the entrypoint, same environment
docker compose up -d                             # recreate after editing .env
docker compose down                              # stop; data survives
docker compose down -v                           # stop and destroy the databases
```

The Resque worker and scheduler run as runit services inside the container, so
they restart with it. `stop_grace_period: 30s` in `docker-compose.yml` gives a
running job time to finish before Docker escalates to `SIGKILL`.

### Ports and a second stack

Published ports bind to **127.0.0.1** by default. This is a development stack
with development credentials and it has no business being reachable from the
LAN; set `STAGEMGR_BIND=0.0.0.0` deliberately if you need it from another
device.

```sh
COMPOSE_PROJECT_NAME=smoke STAGEMGR_PORT=18080 MYSQL_PORT=13306 \
  REDIS_PORT=16379 docker compose up -d
```

### Two MySQL gotchas

!!! danger "Credentials are baked into the data volume"
    The `mysql` image applies `MYSQL_ROOT_PASSWORD`, `MYSQL_USER` and
    `MYSQL_PASSWORD` **the first time the volume initializes** and never again.
    Changing `DATABASE_USER`/`DATABASE_PASSWORD` in `.env` afterwards produces
    `Access denied` until you either `docker compose down -v` (which destroys
    the data) or `ALTER USER` by hand.

`DATABASE_USER` must not be `root`: the image refuses to start with
`MYSQL_USER=root`. `MYSQL_ROOT_PASSWORD` is deliberately a separate variable --
the application never needs root, and reusing one password widens the blast
radius of a leaked `.env`.

`docker/mysql-init/10-test-grants.sh` grants the application account every
database matching `stagemgr_test%`, so `rspec` and `cucumber` can create their
own databases (and a per-worktree `TEST_DATABASE_NAME` works). Like everything
in `/docker-entrypoint-initdb.d`, it runs **only on a fresh volume**. On a volume
that already exists, run the grant once by hand:

```sh
docker compose exec mysql \
  mysql -uroot -pchangeme-root \
    -e "GRANT ALL ON \`stagemgr\_test%\`.* TO 'stagemgr_dev'@'%';"
```

`changeme-root` is the default `MYSQL_ROOT_PASSWORD` from `docker-compose.yml`
(commented out in `.env.example`; set it there to change it), and `stagemgr_dev`
is the default `DATABASE_USER`. Substitute your own if you changed either --
and note the values are whatever the volume was **initialized** with, not
whatever `.env` says now.

### What lives where

- The checkout is bind-mounted at `/var/www/stagemgr`. `config/*.yml`, `.env`,
  encryption keys and `sites/<slug>/` are read straight out of your working
  tree; **nothing is baked into the image**.
- Gems live in the image's RVM gemset (`ruby-3.2.2@stagemgr`), backed by the
  `bundle-cache` named volume -- never in `vendor/bundle`, so the container never
  writes into the checkout.
- `node_modules` is a named volume too: it has to sit in-tree for
  yarn/webpacker resolution, but the builds are Linux ones and must not
  overwrite your host's.

On Linux, files the container writes into the bind mount (`log/`, `tmp/`,
`public/packs`) come back owned by uid 9999. Set `HOST_UID` and `HOST_GID` in
`.env` to your own `id -u`/`id -g` and the entrypoint renumbers its `app` user
to match. Unnecessary on Docker Desktop.

### Running the container in production mode

Set `RAILS_ENV=production` and the entrypoint precompiles assets and gates the
boot on `rake setup:doctor`; `DB_PREPARE_ON_BOOT` defaults to `false` there,
because schema changes belong to a deploy step rather than to a container
restart. The image is documented as a development and CI image -- read
[Deployment](deployment.md#docker-in-production) before relying on it to serve
patrons.

## Native install (macOS / Linux)

Best for working on the application itself: `rspec` and `cucumber` run directly
against your machine's MySQL and Redis with no container round-trip.

### 1. Runtime dependencies

A typical set; package names vary by distribution and release.

=== "macOS (Homebrew)"

    ```sh
    brew install mysql@8.0 redis vips libxml2 libxslt openssl@3
    brew services start mysql@8.0
    brew services start redis
    ```

=== "Ubuntu / Debian"

    ```sh
    sudo apt-get install -y mysql-server redis-server \
      libvips libvips-dev default-libmysqlclient-dev \
      libxml2-dev libxslt1-dev build-essential
    ```

`libvips` is not optional: `ruby-vips` loads `libvips.so` at boot, so the app
will not start without it.

### 2. Ruby and Node

Ruby **3.2.2** (`.ruby-version`) and Node **22** (`.nvmrc`), under whichever
version manager you use:

```sh
rbenv install 3.2.2 && rbenv local 3.2.2   # or asdf / rvm
nvm install 22 && nvm use 22
gem install bundler:2.4.10                 # the version in Gemfile.lock
npm install -g yarn
```

### 3. Clone and configure

```sh
git clone git@github.com:jwechsler/stagemgr.git
cd stagemgr
bundle install
yarn install
bundle exec rake setup:config     # config/*.yml and .env from the templates
```

`.env.example`'s defaults are native-friendly -- `DATABASE_HOST=127.0.0.1`,
`REDIS_URL=redis://127.0.0.1:6379/0`. Edit `.env` for your MySQL account.

In the `config/server.yml` this generates, leave `sub_uri:` **blank** unless the
app is genuinely mounted under a path: it is folded into every mailed URL, so a
stray `/tickets` sends patrons to a 404. Then:

```sh
bundle exec rake setup:wizard
```

!!! warning "Do not put Docker hostnames in `.env`"
    A `.env` carrying `DATABASE_HOST=mysql` or `REDIS_URL=redis://redis:6379/0`
    breaks every native `bin/rails` and `rake` command with
    `Redis::CannotConnectError` or a MySQL connection error. The Compose stack
    sets those two names itself, in `environment:`, which beats `env_file:` --
    so leave the loopback values in `.env` and both paths work. See
    [Troubleshooting](troubleshooting.md#native-commands-cannot-reach-mysql-or-redis).

### 4. Run it

Three processes:

```sh
bundle exec rails server -p 8080                    # Puma
bundle exec rake environment resque:work QUEUE='*'  # background jobs
bundle exec rake environment resque:scheduler       # recurring jobs
```

Browse to <http://localhost:8080/login>.

Puma stays in the `Gemfile` for exactly this -- `rails server` on a native
install. Passenger is what serves the app in Docker and in production.

## The Theater Wit workspace

Theater Wit develops Stagemgr alongside a separately built Foundation marketing
site, in a workspace of peer checkouts (`site/`, `stagemgr/`, `src/`, `dist/`,
`tktprint/`). Two things differ from a plain install:

- **Foundation mode.** `../dist` is mounted into the container at
  `/var/www/foundation-dist`. The entrypoint then installs
  `docker/nginx.foundation.conf` (static files at `/`, Rails under `/tickets`),
  waits up to 30 seconds for `layouts/ext_site_wrapper.html` to appear in that
  build, and symlinks it to
  `app/views/layouts/ext_site_wrapper.html.erb` -- Rails needs a handler
  extension on a layout and the Foundation build emits plain `.html`.
  `config/server.yml` must set `sub_uri: /tickets` and
  `ext_site_wrapper: ext_site_wrapper` to agree with it.
- **`site/`'s Compose file layers on top of this one.** `stagemgr`'s
  `docker-compose.yml` is the primary stack; the workspace adds the `foundation`
  service and Theater Wit's own mounts on top of it rather than defining a
  second copy of the app.

A standalone install wants none of it: no `foundation-dist` mount,
`ext_site_wrapper: standalone`, a blank `sub_uri:`, and Rails at `/`. If a foundation-mode symlink
is left behind from an earlier run, the entrypoint removes it -- a dangling
layout is worse than none, because every public page would 500.
