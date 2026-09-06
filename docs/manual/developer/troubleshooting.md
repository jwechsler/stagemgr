# Troubleshooting

Start here:

```sh
bundle exec rake setup:doctor
# in Docker:
docker compose exec -u app stagemgr bundle exec rake setup:doctor
```

It checks `config/server.yml`, the site theme, the public layout, the
credentials store, where every secret resolves from, the database and Redis
connections, and the MyEmma group names -- and exits non-zero if anything is
broken. Most of the entries below are things it will tell you first.

## Secrets

### A blank ENV variable shadowed a working credential

**The story worth knowing.** On 29 August 2026 Theater Wit's transactional email
401'd for a day. The cause was a single line in `.env`:

```ini
POSTMARK_API_TOKEN=
```

`Mail::Postmark` seeds its settings from `ENV['POSTMARK_API_TOKEN']` and then
picks `settings[:api_token] || settings[:api_key]`. An empty string is truthy in
Ruby, so the blank line beat a perfectly good credential and every send failed
authentication -- while the credential sat there, correct, the whole time.

The fix is now structural: `AppSecrets` normalizes every layer with
`to_s.strip.presence`, so a blank value is never a value and falls through to
credentials. But:

!!! danger "Delete the line, do not empty it"
    A blank line shadows nothing today and will shadow a real secret the moment
    someone types a character into it. `setup:doctor` warns about every blank
    variable it finds -- five in a `.env` copied straight from the template,
    four once `SECRET_KEY_BASE` has been generated --
    and that warning is there to be acted on, not lived with.

Diagnose in a console:

```ruby
AppSecrets.source(:postmark_api_token)      # :env, :credentials, :server_yml or :none
AppSecrets.blank_env?(:postmark_api_token)  # true means: delete that line
```

### `RequiredSecrets::Missing` on a production boot

The message names every absent secret, the environment variable and credentials
path for each, and what you lose while it is missing. Fix them, or -- only for a
build or maintenance process that never serves a request:

```sh
SKIP_REQUIRED_SECRETS_CHECK=1 …
```

See [Credentials](credentials.md#the-production-boot-check) for which secrets are
required under which configuration, and which processes enforce the check.

### Every credential reads as missing, but they are all there

The `.enc` file is present and no decryption key was found.
`ActiveSupport::EncryptedConfiguration#read` swallows that error and hands back
an empty hash, so *every* credential silently reads as `nil`. `setup:doctor` and
`RequiredSecrets` both call this out by name. Put the matching `.key` next to the
`.enc`, or `config/master.key`, or `RAILS_MASTER_KEY` in the environment -- of the
web process **and** the workers.

### `setup:doctor` says `secret_key_base` is BLANK right after the wizard

In Docker, `setup:wizard` wrote the generated key into `.env`, but Compose only
reads `.env` when it **creates** a container and dotenv never overwrites a
variable that is already set -- so the running container still holds the blank
value it started with. `docker compose restart` will not fix it;
`docker compose up -d` recreates the container with the new environment. The
same applies to any other value the wizard writes, such as the Stripe keys.

### Production will not boot and the error mentions `secret_key_base`

Rails' own `validate_secret_key_base` raises before any of this app's checks
run, so you get Rails' terse message rather than a useful one. Set
`SECRET_KEY_BASE` (see `.env.example`), or install encrypted credentials plus
their key, and restart. `bundle exec rails secret` generates a value;
`rake setup:secret_key_base` writes one into `.env`.

## Configuration

### `config/server.yml is missing`

The app cannot boot without it -- `config/environments/development.rb` and
`production.rb` read it directly.

```sh
bundle exec rake setup:config
```

Then fill in the deployment-specific values. It never overwrites an existing
file, so it is always safe to re-run.

### Every public page 500s

`server.yml`'s `ext_site_wrapper:` names a layout that does not resolve.
`setup:doctor` checks this with `lookup_context.exists?` and fails loudly.

- A self-contained install wants `ext_site_wrapper: standalone`.
- A Foundation-fronted install wants the externally supplied layout -- and the
  symlink that provides it. In Docker, the entrypoint creates it only when
  `/var/www/foundation-dist` is mounted, and **removes a stale one** when it is
  not: a dangling layout is worse than none.

### `site_theme` is set but nothing changed

First: **did you restart?** `site_theme` is read while the environment file
loads, so a theme created by `rake setup:site` is not active in any process that
was already running -- including the one that just created it, whose
`setup:doctor` will still say "site_theme not set".

`setup:doctor` reports whether `sites/<slug>/views` exists. A configured slug
whose directory is absent only warns and the app serves generic copy (so a
checkout without `sites/` still boots) -- look for `[SiteTheme]` in the boot log.
A *malformed* slug raises and stops the boot instead; that is deliberate.

Remember that a theme is a **shadow**, not a patch: if your override renders and
still says the wrong thing, you are probably editing a file that is no longer
the one being rendered. See [Theming](theming.md).

### A spec asserts a value my `config/server.yml` does not have

The test environment reads the **tracked `config/server.yml.example`**, not your
copy. Add the key to its `test:` block. See
[Configuration](configuration.md#the-test-environment-reads-the-example-file).

## Docker

### `docker compose` rejects `docker-compose.yml`

You are on Compose older than 2.24. The file uses the long-form `env_file:` with
`required: false`, and Theater Wit's workspace layers on it with `include:`.
Check with `docker compose version` and upgrade.

### Port already in use

Something already owns 8080, 3306 or 6379. Every published port is overridable:

```sh
STAGEMGR_PORT=18080 MYSQL_PORT=13306 REDIS_PORT=16379 docker compose up -d
```

Add `COMPOSE_PROJECT_NAME=…` to run a second stack alongside an existing one.

### `Access denied for user` after changing `.env`

The `mysql` image applies `MYSQL_ROOT_PASSWORD`, `MYSQL_USER` and
`MYSQL_PASSWORD` **only when the data volume is first initialized**. Changing
them afterwards has no effect. Either `docker compose down -v` (this destroys
the database) or `ALTER USER` by hand.

Two related traps: `DATABASE_USER` must not be `root` -- the image refuses to
start with `MYSQL_USER=root` -- and `MYSQL_ROOT_PASSWORD` is deliberately a
separate variable from `DATABASE_PASSWORD`.

### `Access denied … to database 'stagemgr_test'`

`docker/mysql-init/10-test-grants.sh` grants the application account everything
matching `stagemgr_test%`, but like everything in `/docker-entrypoint-initdb.d`
it runs **only on a fresh volume**. On an existing one, run it once by hand:

```sh
docker compose exec mysql \
  mysql -uroot -pchangeme-root \
    -e "GRANT ALL ON \`stagemgr\_test%\`.* TO 'stagemgr_dev'@'%';"
```

### An edit to the entrypoint or an Nginx config did nothing

`bin/docker-entrypoint`, `docker/nginx.conf`, `docker/nginx.foundation.conf` and
`docker/service/**` are baked into the image. `docker compose build`, or
`up -d --build`. Everything under `app/`, `config/`, `lib/` and `sites/` is
bind-mounted and live.

### Native commands cannot reach MySQL or Redis

```text
Redis::CannotConnectError: Error connecting to Redis on redis:6379
Mysql2::Error::ConnectionError: Unknown MySQL server host 'mysql'
```

Your `.env` carries the **Docker** hostnames. `.env.example`'s defaults are
native-friendly (`DATABASE_HOST=127.0.0.1`,
`REDIS_URL=redis://127.0.0.1:6379/0`) and Compose overrides both in
`environment:`, which beats `env_file:` -- so the loopback values are correct for
both paths and nothing needs to change when you switch.

As a one-off:

```sh
DATABASE_HOST=127.0.0.1 REDIS_URL=redis://127.0.0.1:6379/0 bundle exec rails routes
```

## Native installs

### `bundle install` fails building `mysql2`

Install MySQL and OpenSSL headers and point Bundler at them:

```sh
brew install mysql@8.0 openssl@3
bundle config build.mysql2 --with-ldflags="-L$(brew --prefix openssl@3)/lib" \
                           --with-cppflags="-I$(brew --prefix openssl@3)/include"
```

On Debian/Ubuntu: `sudo apt-get install default-libmysqlclient-dev`.

### The app will not boot: `libvips` not found

`ruby-vips` loads `libvips.so` at boot, so this is fatal rather than a
degraded-images situation. `brew install vips`, or
`sudo apt-get install libvips libvips-dev`. CI installs `libvips-dev` for the
same reason.

### `@javascript` Cucumber scenarios cannot start a browser

Selenium needs Firefox **and** a matching geckodriver on `PATH`. The Docker
image installs a real Firefox from Mozilla's APT repo and pins geckodriver
0.35.0 precisely so it never tries to download a browser at test time -- which
fails whenever Mozilla's FTP lags behind a freshly released patch version. On a
native install, install both yourself (`brew install --cask firefox` plus
`brew install geckodriver`).

### Webpacker compilation fails or assets are stale

The app pins Node **22** (`.nvmrc`, and the same version in the Dockerfile and
CI). Run `nvm use 22`, then:

```sh
yarn install
bundle exec rails webpacker:compile
```

The container does both on every start; if it fails there, it is reported and
the container stays up in development so you can exec in and fix it. (Every
entrypoint step behaves that way except `bundle install`, which is fatal in
every environment.)

## Runtime

### `/admin/resque` asks for a password and rejects everything

In production with no password configured, the dashboard is denied to
*everyone* -- it fails closed, because an open queue dashboard exposes job
arguments (order ids, email addresses) and offers a one-click "Clear failed
jobs". Set `RESQUE_ADMIN_PASSWORD` (or the `resque_admin_password` credential)
and restart. Outside production, an unconfigured dashboard is simply open.

### A deprecation warning about `resque_admin_password` at every boot

The password is still being read from `config/server.yml`. That fallback works
but is on its way out -- move the value to `RESQUE_ADMIN_PASSWORD` or to the
encrypted credentials and delete the key.

### Crash reports stopped arriving

`config/environments/production.rb` uses
`email.addresses.exception_notifications`, falling back to `software_address`.
With **neither** configured the middleware is left out of the stack entirely and
a `[ExceptionNotification]` warning is logged at boot: building a mail with no
recipients would raise from inside the middleware while it was handling the real
exception, replacing a useful 500 page with a confusing one.

### Mailing-list opt-ins reach nobody

`setup:doctor` resolves each configured MyEmma group name against the account --
but only when MyEmma is configured *and* writable, which keeps it off the
network in development (where `MyEmma.read_only!` is always applied) and in the
test suite. Three states are distinct and all intentional: the key **absent**
means the historical names `Newsletter`/`Flash Offers`; the key present but
**blank** means nobody is added to that group; a name that does not exist in the
account logs a warning and adds nobody. Group ids are cached for five minutes,
so a rename takes that long to take effect.

### Locked out of the admin account

Reset the password from a runner:

```sh
docker compose exec -u app stagemgr bundle exec rails runner \
  'u = User.find_by(email: "you@example.com"); u.password = "new-password"; u.save!'
```

Or re-run `rake setup:admin`, which updates the user when it already exists.
