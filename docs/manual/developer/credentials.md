# Credentials & Secrets

Every secret the application needs is read through one accessor,
`AppSecrets` (`lib/app_secrets.rb`). Nothing calls `ENV[…]` or
`Rails.application.credentials` directly any more, which is what makes the rules
below true everywhere at once.

## Resolution order

For each secret, in order:

1. **The environment variable** -- but only if it is **non-blank**.
2. **Encrypted credentials** -- whatever `Rails.application.credentials` points
   at for this environment.
3. **`config/server.yml`** -- deprecated, and only for `resque_admin_password`.
   Reading one warns, once per key per process.

Every layer passes through the same normalizer: the value is `to_s.strip`ped and
an empty result counts as absent. So

- a blank `POSTMARK_API_TOKEN=` line does **not** shadow a working credential --
  it is skipped, and the credential is used;
- the trailing newline that Docker secrets, systemd `EnvironmentFile` and shell
  heredocs habitually add never reaches an API client.

!!! danger "Blank still means: delete the line"
    A blank line shadows nothing *today*. It will shadow a real secret the
    moment someone types a character into it, and that is exactly how Theater
    Wit lost a day of transactional email (see
    [Troubleshooting](troubleshooting.md#a-blank-env-variable-shadowed-a-working-credential)).
    `setup:doctor` warns about every blank variable it finds; act on it.

!!! warning "The environment now wins"
    Before this mechanism existed, credentials beat the environment for Postmark
    and MyEmma. They no longer do. On an existing install, check the process
    environment for stale non-blank values before deploying -- see the
    [pre-deploy checklist](deployment.md#before-deploying-at-an-existing-install).

## The registry

| Secret | Environment variable | Credentials path |
|---|---|---|
| `secret_key_base` | `SECRET_KEY_BASE` | `secret_key_base` |
| `stripe_secret_key` | `STRIPE_SECRET_KEY` | `stripe.secret_key` |
| `stripe_signing_secret` | `STRIPE_SIGNING_SECRET` | `stripe.signing_secret` |
| `postmark_api_token` | `POSTMARK_API_TOKEN` | `postmark_api_token` |
| `my_emma_username` | `MY_EMMA_USERNAME` | `my_emma.username` |
| `my_emma_password` | `MY_EMMA_PASSWORD` | `my_emma.password` |
| `my_emma_account_id` | `MY_EMMA_ACCOUNT_ID` | `my_emma.account_id` |
| `paypal_login` | `PAYPAL_LOGIN` | `paypal.login` |
| `paypal_password` | `PAYPAL_PASSWORD` | `paypal.password` |
| `paypal_signature` | `PAYPAL_SIGNATURE` | `paypal.signature` |
| `paypal_pem_file` | `PAYPAL_PEM_FILE` | `paypal.pem_file` |
| `paypal_express_login` | `PAYPAL_EXPRESS_LOGIN` | `paypal_express.login` |
| `paypal_express_password` | `PAYPAL_EXPRESS_PASSWORD` | `paypal_express.password` |
| `resque_admin_password` | `RESQUE_ADMIN_PASSWORD` | `resque_admin_password` (also, deprecated, `server.yml`) |
| `aws_access_key_id` | `AWS_ACCESS_KEY_ID` | `aws.access_key_id` |
| `aws_secret_access_key` | `AWS_SECRET_ACCESS_KEY` | `aws.secret_access_key` |

A name that is not in the registry raises `AppSecrets::UnknownSecret` -- a typo
must never resolve quietly to `nil`.

### Asking where a secret came from

```ruby
AppSecrets.source(:postmark_api_token)   # => :env | :credentials | :server_yml | :none
AppSecrets.blank_env?(:postmark_api_token)
AppSecrets.report                        # every key, sources only -- never values
AppSecrets.credentials_status            # :ok | :no_key | :absent | :unavailable
```

`rake setup:doctor` prints the same report, and in development the boot log
carries a one-line `[AppSecrets] …=env postmark_api_token=credentials …` summary
plus a warning listing any variables that are set but blank.

## `.env` or encrypted credentials?

Both work everywhere. Pick per deployment, not per key.

| | `.env` / process environment | Encrypted credentials |
|---|---|---|
| **Setup effort** | Copy a template, fill in values | `bin/rails credentials:edit --environment <env>`, then get one key file onto the box |
| **Docker fit** | Native. Compose reads `.env`; `environment:` overrides it | Workable -- the `.enc` is in the bind mount, but the key still has to arrive separately |
| **Bare-metal Passenger fit** | Awkward: dotenv is not loaded in production, so every variable needs `SetEnv` or a systemd `EnvironmentFile`, and the Resque workers need the same environment | Native: one `config/master.key` on disk covers the web process, the workers and rake |
| **Versioned with the code** | No | Yes -- the `.enc` is committed, so a key added on a branch arrives with the deploy |
| **Per-environment** | By whatever populates the environment | Built in: `config/credentials/<env>.yml.enc` |
| **Reviewable in a diff** | Yes (the file is plaintext, and gitignored) | No -- the diff is ciphertext |
| **Footguns** | Blank lines; a `.env` with Docker hostnames breaking native commands; a stale value in the process environment silently winning | Losing the key file makes the payload unrecoverable; an `.enc` **with no key present reads as empty rather than raising** |
| **Recommended for** | Docker, CI, development | Bare-metal production (Theater Wit's own) |

### Editing credentials

Rails 6.1 prefers the per-environment pair when
`config/credentials/<env>.yml.enc` exists, and otherwise falls back to the
shared `config/credentials.yml.enc` + `config/master.key`. Both shapes are in
play here: development and test use per-environment files; Theater Wit's
production box uses the shared pair.

```sh
bin/rails credentials:edit --environment development   # config/credentials/development.yml.enc
bin/rails credentials:edit --environment production    # config/credentials/production.yml.enc
bin/rails credentials:edit                             # the shared config/credentials.yml.enc
```

`config/credentials/credentials.yml.example` lists every key the app
understands. It is **reference only** -- do not copy it into
`config/credentials/`. Credentials are encrypted; a plaintext `.yml` sitting
there is both ignored by Rails and a liability.

### Which key files exist, and which are secret

| File | Status |
|---|---|
| `config/master.key`, `config/credentials/production.key`, `config/credentials/development.key` | **Gitignored. Never commit.** Deliver out of band, or as `RAILS_MASTER_KEY` |
| `config/credentials/test.key` and `test.yml.enc` | **Intentionally committed.** The test credentials hold dummy values only (the suite uses StripeMock), so CI decrypts them with no repository secret |
| `config/credentials.yml.enc`, `config/credentials/*.yml.enc` | Committed ciphertext |

## Promoting a secret from development to production

=== "Docker in production"

    Put it in the process environment. Either extend `.env` on the host (Compose
    reads it) or, better, add it to `environment:` in your own override file so
    it is explicit:

    ```yaml
    services:
      stagemgr:
        environment:
          STRIPE_SECRET_KEY: ${STRIPE_SECRET_KEY:?set it in the deploy environment}
    ```

    Restart the container. `docker compose exec -u app stagemgr bundle exec rake setup:doctor`
    should show the key resolving from `env`.

=== "Bare metal, credentials"

    ```sh
    RAILS_ENV=production bin/rails credentials:edit --environment production
    ```

    Add the key, save, commit the resulting `.enc`, deploy, and make sure the
    box has either `config/credentials/production.key` on disk or
    `RAILS_MASTER_KEY` in the Passenger and worker environments. Then, on the
    box:

    ```sh
    RAILS_ENV=production bundle exec rake setup:doctor
    ```

=== "Bare metal, environment"

    Passenger `SetEnv` (Apache) or a systemd `EnvironmentFile` for the workers.
    Remember that **dotenv is not loaded in production**, so a `.env` on the
    production box is read by nothing.

## The production boot check

`lib/required_secrets.rb` refuses to serve production traffic with a required
secret missing, and says exactly what to do about it. It replaced a
commented-out `config.require_master_key`, which only ever covered the
credentials file.

**Required** (raises `RequiredSecrets::Missing` at boot):

| Secret | When |
|---|---|
| `secret_key_base` | Always |
| `stripe_secret_key` | `payment_processing.default_gateway` or `default_recurring_gateway` is `stripe` |
| `postmark_api_token` | `email.delivery_method` is `postmark` |

**Warn-only** (logged, boot continues), with what you lose while it is absent:

| Secret | Consequence |
|---|---|
| `stripe_signing_secret` | Stripe webhooks are unverified, so subscription renewals and refunds do not post back to the app |
| `resque_admin_password` | `/admin/resque` has no password: in production it is denied to everyone, elsewhere it is open to anyone who can reach it |

### Which processes enforce it

| Process | Enforces? |
|---|---|
| Passenger web boot | Yes -- Rake is not loaded there at all |
| `rake environment resque:work` / `resque:scheduler` | **Yes.** A worker without secrets is as broken as a web process: it delivers all the mail |
| Any other rake task (`assets:precompile`, `db:migrate`, `setup:*`) | No -- these are exactly what an operator runs on a box that is not configured yet |
| `rails console`, `rails runner` | No |
| Anything with `SKIP_REQUIRED_SECRETS_CHECK` set | No |

### Its most useful message

When the `.enc` file is present but no decryption key can be found,
`ActiveSupport::EncryptedConfiguration#read` swallows the error and returns an
empty hash -- so **every** credential reads as missing and the obvious advice
("add the credential") is advice you have already followed. Both
`RequiredSecrets` and `setup:doctor` detect that case specifically and say so:

```text
config/credentials/production.yml.enc exists but no decryption key was found
(the matching .key file next to it, config/master.key, or RAILS_MASTER_KEY) --
every credential reads as missing until the key is in place.
```

!!! warning "One thing the check cannot rescue"
    If `secret_key_base` itself is missing in production, Rails' own
    `validate_secret_key_base` raises before this check -- and before
    `setup:doctor` can print anything. You get Rails' terse message, not ours.
    The Docker entrypoint prints a hint pointing here when `setup:doctor` fails
    at that point; on bare metal, if production will not boot at all and the
    error mentions `secret_key_base`, start by setting `SECRET_KEY_BASE` or
    installing the credentials key.
