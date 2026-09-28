# Rails Upgrade: Recommendation, Risk Assessment and Plan

*Prepared 2026-09-28 against `master` at Rails 6.1.7.10 / Ruby 3.2.2.*

## 1. Recommendation

**Upgrade to Rails 8.1 (and Ruby 3.4) in three production releases:
cleanup on 6.1, then 6.1 → 7.2, then 7.2 → 8.1.** Every intermediate minor
version (7.0, 7.1, 8.0) is still stepped through on the branch and in CI so its
deprecation warnings get used, but it isn't deployed. See §4.

Do not stop at Rails 7. Per the Rails maintenance policy (security fixes for two
years after a minor's first release):

| Version | Released | Security support ends | Status today |
|---|---|---|---|
| 6.1 (current) | Dec 2020 | Oct 2024 | **Unsupported for ~2 years** |
| 7.0 / 7.1 | Dec 2021 / Oct 2023 | Apr 2025 / Oct 2025 | Unsupported |
| 7.2 | Aug 2024 | Aug 2026 | **Already unsupported** |
| 8.0 | Nov 2024 | Nov 2026 | ~2 months left |
| 8.1 | Oct 2025 | Oct 2027 | Supported (8.1.4, Sept 2026) |

Rails 7.2 — the natural "Rails 7" stopping point — went out of security support
last month, so a "Rails 7" upgrade would land on an unpatched framework. Rails
8.1 is the only target that buys meaningful runway, and the incremental cost of
7.2 → 8.1 is small for this codebase (about two days; see §4).

Ruby 3.2 also reached end-of-life in March 2026, and the newest releases of
several gems already require Ruby ≥ 3.3. Go to **3.3 early** (it runs today's
Rails 6.1 app fine — the audit booted it on 3.3.6) and **3.4 at the end**.

What we are *not* recommending: the Rails 8 "Solid" defaults (Solid Queue,
Solid Cache, Solid Cable), Kamal, or Thruster. They are new-app defaults, not
requirements. Resque + Redis, Passenger and the macOS host all keep working on
Rails 8.1; replacing them would add risk without being on the upgrade's
critical path.

### Why this is tractable

The codebase is in better shape than a typical 6.1 app:

- Zeitwerk is already the autoloader; `zeitwerk:check` passes.
- None of the classic landmines: no `update_attributes`, `before_filter`,
  `render :text`, `redirect_to :back`, positional `serialize`,
  `attr_accessible`, `require_dependency`, or `.js.erb` templates.
- Cookies already use the JSON serializer; ActiveStorage already uses vips.
- CI already runs RSpec (214 spec files) and Cucumber (25 features) against
  MySQL 8 and Redis on every push.
- Most blockers are gem pins with a released fix, or unused gems to delete.

Estimated effort: **~8–12 focused dev-days** of code and verification, which at
part-time pace (one developer + Claude) is roughly **6–8 calendar weeks**. That
means three release windows (plus optional separate windows for the asset-pipeline
change and each Ruby bump), with small follow-up deploys that flip framework defaults.

## 2. Current state (audit summary)

**Stack:** Rails 6.1.7.10, Ruby 3.2.2, `config.load_defaults 6.0` (with a
partially applied `new_framework_defaults_6_1.rb`), MySQL 8 (utf8mb4_0900),
Redis via Resque 2.6, Sprockets 4 + Webpacker 5 (webpack 4), Passenger on a
macOS 13 host, deployed by `bin/deploy` (git pull → bundle → yarn → migrate →
doctor → precompile → restart).

### Gem blockers

| Gem | Locked | Problem | Fix |
|---|---|---|---|
| authlogic | 6.4.3 | AR `< 7.2` | 6.5.0 (to 8.0), then 6.6.0 (7.2–8.1) |
| exception_notification | 4.5.0 | actionmailer `< 8` | 4.6.0 now, 5.0.x on 7.1+ |
| cucumber-rails | 2.5.1 (pinned) | railties `< 8` | 3.1.1, later 4.1.0 |
| rspec-rails | 5.1.2 (pinned `< 6`) | supports ≤ 7.0 | 6.1 → 7.1 → 8.0 per hop |
| resque-web | 0.0.12 (2017) | pulls twitter-bootstrap-rails `< 8`, sassc-rails, less | **Remove — unused.** The `/admin/resque` dashboard is `Resque::Server` from the resque gem itself (`config/routes.rb:37`) |
| sqlite3 | 1.6.9 (pinned) | Rails 8 needs ≥ 2.1 | **Remove — unused** (every env is mysql2); also ends the lockfile platform churn |
| webpacker | 5.4.4 | retired upstream; webpack 4 needs `--openssl-legacy-provider` on Node 22 | Replace with jsbundling-rails (esbuild) |

**Unused, delete:** activerecord-session_store (sessions are `:cookie_store`),
i18n-js, uglifier, jquery-timepicker-rails
(vendored/npm copy is what's loaded — verify), coffee-rails (after converting 5
small `.coffee` files), and the dev-group fossils wirble, bond, what_methods,
map_by_method, single_test, rbx-require-relative. Also `config/spring.rb`,
`config/initializers/footnotes.rb`, `config/resque_web.rb`, and the
`config.whiny_nils` lines.

**Bump opportunistically:** draper 4.0.6, simple_form 5.4, responders 3.2,
activeresource 6.2 (tktprint models), activestorage-validator 0.7/0.8,
resque 2.7 + resque-scheduler 4.11 + resque-retry 1.9, mysql2 0.5.7, chartkick
5.2, jquery-ui-rails 8, loosen the `nio4r`/`ffi` pins.

**Keep but watch (unmaintained, no Rails upper bound):**
rails-jquery-autocomplete, cocoon, ajax-datatables-rails, decent_exposure (3 controllers),
validates_formatting_of (2 uses), ri_cal (1 use), resque-lock-timeout
(0.4.1 is the only version compatible with resque 2/3), my_emma (git; deps are
unconstrained activemodel + httparty — fine).

**Deliberately out of scope:** money 7 / money-rails 2+ (breaking changes of its
own), redis 5 (forces replacing fakeredis with mock_redis), resque 3, stripe
beyond 11.x (capped by stripe-ruby-mock). Each is its own later project.

### Code blockers, by the version where they bite

| Where | Item | Severity | Location |
|---|---|---|---|
| 7.0 | Initializers autoload reloadable constants (the one deprecation warning today: `EmailValidator`) — becomes a `NameError` | Blocker | `config/initializers/monkey_patches.rb:2` requires every `lib/*.rb`; `lib/not_email_validator.rb`; `config/initializers/site_theme.rb` |
| 7.0 defaults | `redirect_to referer` raises `UnsafeRedirectError` for foreign referers once `raise_on_open_redirects` is on — inside the global exception handler | Must-fix | `app/controllers/application_controller.rb:126` |
| 7.0 defaults | `key_generator_hash_digest_class = SHA256` logs everyone out unless a SHA1 cookie rotator is added | Must-fix | `config/initializers/session_store.rb` |
| 7.0 → 7.1 | 43 `to_s(:format)` calls: deprecated in 7.0, **silently ignored** in 7.1 (dates print in the wrong format — tickets, reports, emails) | Must-fix | e.g. `app/helpers/admin/reports_helper.rb:17`, `app/models/week_select.rb:5`, `app/decorators/performance_decorator.rb` |
| 7.1 | `Time#to_s` stops honoring `Time::DATE_FORMATS[:default]`; implicit time interpolation changes format | Must-fix | `config/environment.rb`; e.g. `app/views/current_user/accounts/show.html.haml:23,29` |
| 7.1 | `legacy_connection_handling` config removed — boot failure | Blocker | `config/initializers/new_framework_defaults_6_1.rb:45` |
| 7.1 | `config.fixture_path` → `fixture_paths` (dir doesn't exist; delete the line) | Must-fix | `spec/rails_helper.rb:37` |
| 7.1 | `Hash#deep_merge` override drops block support that ActiveSupport 7.1 relies on | Medium | `config/initializers/hash_extensions.rb` |
| 7.2 | `Rails.application.secrets` removed; the shim silently returns false | Must-fix | `lib/required_secrets.rb:143`, `config/secrets.yml`, `spec/lib/required_secrets_spec.rb:71` |
| 7.2 → 8.0 | Keyword `enum admission:` deprecated then removed | Blocker in 8.0 | `app/models/concerns/ticket_admission.rb:18` |
| any | 4 bare `.deliver` calls → `deliver_now` | Cleanup | `flex_pass_order.rb:52`, `send_membership_reminders.rb:9`, `send_flex_pass_reminders.rb:9`, `notification_task.rb:12` |
| eager load | `app/models/admin/report_request.rb` defines the wrong constant (dead code); `lib/extensions/my_emma_patches.rb` ignore rule points at the wrong path | Cleanup | `config/application.rb:31` |
| 7.2 | 18 `ActiveRecord::Base.connection` uses soft-deprecated (still work) | Deprecation | e.g. `app/services/audience_analysis.rb`, `app/models/reports/*_usage_report.rb` |

### Frontend

Two JS systems are in use. Sprockets does nearly everything (jQuery, jQuery UI,
DataTables + yadcf, Foundation 6.9 from `node_modules`, cocoon, chartkick,
tagify, 39 views with inline scripts relying on Sprockets-defined globals).
Webpacker serves exactly **one** real pack, `seat_map_editor` (Konva + 10 local
ES modules); the `application` pack is empty but still loaded by the main
layout.

**Target:** keep Sprockets (fully supported on Rails 8), replace Webpacker with
**jsbundling-rails + esbuild** for the seat-map editor only. This removes
webpack 4, Babel, ~950 yarn lockfile entries and the Node OpenSSL workaround,
with near-zero change to the rest of the UI. Propshaft/importmap are *not*
recommended now: the jQuery-plugin load order, SCSS, and inline globals make
that a large, separate frontend project.

### Site theming

`sites/<slug>/views` shadowing uses only public API (`prepend_view_path` via
`on_load` hooks), so risk is low. Rails 7.1's `ActionView::PathRegistry` caches
resolvers per path, which makes the comment in `lib/site_theme.rb` inaccurate
but doesn't break behavior. Verify dev reloading under `sites/` and the
symlinked `ext_site_wrapper` layout after the 7.1 hop.

## 3. Risk assessment

Likelihood/impact are for this codebase specifically.

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R0 | **Not upgrading.** Rails 6.1 has had no security patches since Oct 2024, on a system that takes card payments and stores patron PII. Ruby 3.2 and macOS 13 are also out of support. Each month widens the gap and more gems drop 6.1. | Certain (ongoing) | High | This plan. |
| R1 | **Silent date/time format regressions** (`to_s(:fmt)`, `Time` default format) in tickets, confirmations, reports and exports. No exception, just wrong output. | High if unmitigated | High (customer-facing) | Sweep all 43 calls to `to_formatted_s` *before* 7.1; set `config.active_support.deprecation = :raise` in test; add spec assertions on rendered dates in mailer/ticket views; grep implicit time interpolation in views. |
| R2 | **Mass logout / session loss** when flipping the 7.0 cookie digest default. | High if unmitigated | Medium (staff mid-order, patrons mid-checkout lose carts) | Add SHA1→SHA256 cookie rotator in the same deploy; flip in a quiet window; remove the rotator one release later. |
| R3 | **Authentication breakage** from the authlogic bump (staff box office and patron logins). | Medium | High | Bump authlogic in an isolated PR; run the session/login specs and cucumber login features; manual check of staff login, patron login, password reset. |
| R4 | **Payment path regressions** (Stripe PaymentIntents via ActiveMerchant, stripe_event webhooks, refunds/exchanges). No Rails dependency in the gateway gems, but controllers/callbacks around them change. | Low | Very high | Keep stripe/activemerchant versions fixed during the upgrade; per-hop manual checklist in Stripe test mode: card purchase, 3DS, refund, exchange with differential, webhook receipt. |
| R5 | **Asset build fails on the production box** (webpacker→esbuild swap; sass-embedded's Dart binary needs macOS ≥ 14 above 1.98; native gems on a Ruby bump). CI never runs `assets:precompile`, so this would first appear at deploy. | Medium | High (deploy aborts; site stays on old code if deploy is ordered right) | Add `assets:precompile` to CI now; do a dry-run precompile on the production box (in a separate checkout) before each deploy that touches assets or Ruby; keep the `< 1.98` cap. |
| R6 | **Production host is macOS 13** (Apple no longer patching it). Future gem/Ruby/Node releases increasingly assume newer OS and toolchains. | Medium (grows over time) | Medium–High | Not a blocker for this plan, but budget an OS upgrade to macOS 14+ (or a Linux move) alongside or after Release 3. |
| R7 | **Autoload/eager-load surprises in production.** `app/models/**/` subdirectories are added as autoload roots, which are not eager loaded; one file defines the wrong constant. A class that loads fine lazily in dev can fail under eager load. | Medium | Medium | Fix the two bad files in Release 1; add a CI step that eager loads with `config.eager_load = true` (`bin/rails zeitwerk:check` plus a full eager load); consider `config.autoload_lib` in 7.1. |
| R8 | **Unmaintained gems break quietly** (rails-jquery-autocomplete, cocoon, ajax-datatables-rails, decent_exposure, resque-lock-timeout, ri_cal). | Medium | Low–Medium (admin UX) | Per-hop smoke list covers autocomplete (addresses, ticket orders), DataTables admin grids, cocoon nested forms, calendar export. Replace any that break rather than patching. |
| R9 | **Monkey patches interacting with new framework code** (`Hash#deep_merge`, `validates_credit_card` reopening `ActiveRecord::Validations`, HWIA `to_yaml` used by audited). | Medium | Medium | Delete `hash_extensions.rb` (equivalent to ActiveSupport); keep the others under spec coverage; re-run audited specs every hop. |
| R10 | **Test coverage gaps.** Cucumber `@javascript` scenarios don't run in CI; the legacy `test/` dir (65 files) is never run; no precompile or eager-load check. Green CI can overstate safety for JS-heavy admin pages (seat maps, order entry, reseating). | High | Medium | Release 1a adds precompile + eager-load checks to CI and a written manual smoke checklist; run `@javascript` features locally (Docker has Firefox + geckodriver) before each deploy. |
| R11 | **Mixed-version Resque jobs at cutover.** Jobs enqueued by old code run on new workers. | Low (arguments are plain IDs/strings) | Low–Medium | Pause the scheduler, let queues drain, deploy, restart workers (`bin/deploy` already restarts them). |
| R12 | **Rollback difficulty**, which is larger per release because Releases 2 and 3 each span several Rails versions. | Low | Medium | Rails upgrades here need no data migrations; `db/schema.rb` only changes its version header. Each release deploys with `load_defaults` held back, so until defaults are flipped, rollback is redeploying the previous release (`git revert` + `bin/deploy`). Flip the cookie digest last within 7.0's defaults, because rolling back past it logs users out. Keep ActiveStorage migrations (if `rails app:update` generates any) in a separate, forward-compatible deploy. |
| R13 | **Passenger / Rack compatibility.** Rails 7.1+ allows Rack 3; old Passenger versions don't support Rack 3. | Low–Medium | High (site down) | Pin `rack ~> 2.2` through the upgrade (Rails 8.x still permits it; Sinatra 3 in `Resque::Server` also wants Rack 2); move to Rack 3 only after confirming the Passenger version. |
| R14 | **Framework defaults flipped wholesale** cause subtle behavior changes (e.g. `has_many_inversing`, `button_to` generating `<button>`, belongs_to strictness already on). | Medium | Medium | Releases deploy with defaults held back; `new_framework_defaults_X_Y.rb` settings are then flipped in small groups, each its own CI run and small deploy, before bumping `load_defaults`. |
| R15 | **Long-lived upgrade branches diverge** from `master` while ticketing work continues, and a multi-version release is harder to bisect in production. | Medium | Medium | Everything version-independent ships in Release 1 on 6.1, so the upgrade branches stay short. Keep one commit per minor version (bisectable), merge `master` into the branch weekly, and limit branch life to 3–4 weeks. |

**Overall:** moderate, well-contained risk. The two highest-impact risks, R1
(date formats) and R4 (payments), are both preventable with targeted checks,
and R1 is neutralized in Release 1 before any Rails version changes.
The risk of *not* upgrading (R0) is the largest on the table.

## 4. Plan

### Release structure

The work ships in **three production releases**. Every Rails minor version is
still passed through, but in CI and development, not in production:

| Release | Production moves | Stepped through on the branch | Windows |
|---|---|---|---|
| **1** | Rails 6.1 (cleanup), Ruby 3.3, esbuild | — | 1–2 (1c may ship separately) |
| **2** | 6.1 → **7.2** | 7.0, 7.1 | 1, plus small defaults-flip deploys |
| **3** | 7.2 → **8.1**, then Ruby 3.4 | 8.0 | 1, plus small defaults-flip deploys |

Why each minor is still stepped through: Rails deprecates in one minor version
and removes in the next, so each intermediate version supplies warnings that
point at the exact lines to fix. Skipping a version turns those warnings into
crashes, or silent changes. The 7.1 `to_s(:format)` behavior is the worst example
here. Why the intermediate versions aren't deployed: 7.0, 7.1 and 8.0 are out
of (or nearly out of) security support, so running them in production adds
maintenance windows and soak time without adding safety.

**The key technique: upgrade the framework and flip its defaults separately.**
Each release deploys the new Rails with `config.load_defaults` held at the
*previous* release's value, and `new_framework_defaults_X_Y.rb` files left fully
commented out. The code runs on the new framework, while behavior-changing
defaults stay as they were. The defaults then get flipped in small follow-up
deploys, a few settings at a time. That keeps each release's behavior change
small, and it keeps rollback clean: until a default like the cookie digest is
flipped, redeploying the previous release is a pure code rollback.

Not everything is behind `load_defaults`. Removals (such as `legacy_connection_handling`,
`Rails.application.secrets`, and keyword `enum`) and some behavior changes
(`to_s(:format)`, `Time#to_s`) happen as soon as the version changes. That is what
the per-version commits on the branch are for.

**Branch discipline.** Releases 2 and 3 each live on a branch (`rails-7.2`,
`rails-8.1`) with one commit (or small PR) per minor version. Each commit is
green in CI with deprecations raising before the next one starts. Merge `master` into the
branch at least weekly so ticketing work doesn't diverge. Target no more than
3–4 weeks of branch life per release. Everything that can land on 6.1 lands
in Release 1, which keeps the upgrade branches short.

**Every production deploy** (releases and defaults flips alike) happens in a
short planned window: a weekday daytime with no on-sale, opening or show that
night. Beforehand, pause resque-scheduler, drain the queues, and take a MySQL
dump and a `storage/` snapshot. Then run `bin/deploy` and the manual smoke
checklist (§5). Soak each release for about a week before starting to flip its
defaults.

---

### Release 1: Stabilize on Rails 6.1 · ~3.5 days

Most of the upgrade's real risk is independent of the Rails version, so it
ships first, on the framework that's already running in production.

**1a. Safety net (~1 day)**

*Done on `rails-upgrade/release-1a`.*

1. CI runs `bundle exec rails assets:precompile` with `RAILS_ENV=production`,
   as `bin/deploy` does, so production's asset config is what gets built. It needs
   only a dummy `SECRET_KEY_BASE` (`RequiredSecrets` exempts rake) and the Redis
   service (the Resque initializer connects at boot); no database. It runs as the
   last step so compiled `public/assets` and `public/packs` can't shadow sources
   in RSpec or Cucumber.
2. CI runs `bin/rails zeitwerk:check`, then
   `Rails.autoloaders.each { |l| l.eager_load(force: true) }`. `zeitwerk:check`
   (and `eager_load!`) skip the `app/models/**/` autoload roots; `force: true` is
   what loads them. That load failed on both bad files, so the two fixes moved up
   from 1b.3: `app/models/admin/report_request.rb` is deleted (nothing
   referenced it), and the ignore rule now points at
   `lib/extensions/my_emma_patches.rb`.
3. **Moved to 1b.** `deprecation = :raise` in test waits until the
   EmailValidator initializer fix (1b.2) removes the one existing warning.
4. Manual smoke checklist: `docs/runbooks/upgrade-smoke-checklist.md`.
5. The lint workflow reads `.ruby-version` (no `ruby-version:` input).
6. Production logs deprecations (`config.active_support.deprecation = :log`,
   was `:notify` with no subscriber), so each release's warnings reach
   `log/production.log`.

**1b. Cleanup (~1.5 days)**

*Done on `rails-upgrade/release-1b` (items 1–7 below). Items 8 and 9 moved to
their own windows.*

1. Removed the unused gems: resque-web, sqlite3 (the lockfile platform churn
   is gone), activerecord-session_store, i18n-js, uglifier,
   jquery-timepicker-rails (the timepicker CSS is a vendored copy in
   `app/assets/stylesheets`; the JS call is commented out) and the dev
   fossils. resque-web also took twitter-bootstrap-rails, less,
   font-awesome-sass and sass-rails/sassc out of the bundle; the production
   `application-*.css`/`.js` digests are unchanged (Font Awesome 4.7 still
   comes from font-awesome-rails). `sprockets-rails` is now explicit.
   Deleted `config/resque_web.rb`, `config/spring.rb`, the footnotes
   initializer and the `whiny_nils` lines. **Kept decent_exposure**: three
   controllers use `expose` (the audit's "0 calls" was wrong).
2. Initializer autoloading: `monkey_patches.rb` now requires only the two
   autoloader-ignored files that reopen gem/framework constants
   (`validates_credit_card`, `my_emma_patches`); the rest of `lib/`
   autoloads. `lib/site_theme.rb` is ignored by the main autoloader and
   required once by its initializer. The `EmailValidator` deprecation is gone.
   (`lib/not_email_validator.rb` and `app/lib/email_validator.rb` look
   unused: `Order` resolves `not_email:` to `EmailValidatable::NotEmailValidator`.)
3. Deleted `hash_extensions.rb` (same recursion as ActiveSupport's
   `deep_merge`, minus block support; its only callers, the environment
   files, run before initializers anyway) and the legacy `test/` directory.
   One file there was live: factory_bot_rails loads `test/factories.rb` by
   default, so it moved verbatim to `spec/factories/general.rb`. The dev
   `/rails/mailers` previews went with it.
4. `.deliver` → `.deliver_now` (4 sites).
5. Dates and times (R1):
   - All 43 `to_s(:fmt)` calls (every receiver a Date/Time) are
     `to_formatted_s(:fmt)`.
   - Every bare `Time#to_s` that relied on `Time::DATE_FORMATS[:default]` now
     calls `to_formatted_s(:default)`: report "generated … on" lines, login
     times on the account page and user datatable, the report/import file
     lists, and the daily box office receipts report, whose day *grouping*
     keys on that string.
   - **Detector** (`spec/support/bare_time_to_s_detector.rb`, loaded by RSpec
     and `features/support/bare_time_to_s.rb`): fails either suite if app
     code reaches `Time`/`DateTime`/`TimeWithZone#to_s` with no format,
     including interpolation, CSV, `join` and ERB/HAML output.
     `BARE_TIME_TO_S=report` lists sites without failing. **Delete it once on
     Rails 7.1+**, where `to_s` no longer reads `:default`. RSpec found none
     (controller specs don't render views); Cucumber found three; the rest
     came from a grep.
   - Literal-format specs pin the ticket confirmation's date/time,
     `PerformanceDecorator#performance_time`/`order_link` and the report
     cell/CSV output.
6. The global exception handler follows a referer only when it is on this
   host and is not the failing path (`redirect_back`), otherwise `root_path`,
   so a foreign referer can't raise `UnsafeRedirectError` once
   `raise_on_open_redirects` is on.
7. Bumped rspec-rails 5.1.2 → 6.1.5, cucumber-rails 2.5.1 → 3.1.1 (cucumber
   7.1 → 9.2; `AfterConfiguration` became `BeforeAll`) and
   exception_notification 4.5.0 → 4.6.0. **authlogic 6.5 is deferred** to
   the 1b.8 window, see below.
8. `config.active_support.deprecation = :raise` in test (moved here from 1a).
   Fixed the two remaining app deprecations: `CreditCardPayment#refund!`
   left a transaction block with `return` (6.1 commits, 7.0 would roll back
   the reconciled refund; it now uses `next`). The Simple Form
   `wrapper_options` warning came from the simple-form-datepicker gem's
   `DatepickerInput`, not from `app/inputs/datepicker_input.rb`, which Zeitwerk
   never loaded because the gem had already defined the constant. The gem's
   class now lives in that file with the new signature, and the gem is gone.

**Moved to their own windows:**

- **Framework defaults** (was 1b.8): `load_defaults 6.1` and deleting
  `new_framework_defaults_6_1.rb`. **Finding:** authlogic 6.4.3 loads
  `ActiveRecord::Base` during `Bundler.require`, before the initializers run,
  so the two `config.active_record` lines in `new_framework_defaults_6_1.rb`
  (`has_many_inversing = true`, `legacy_connection_handling = false`) have
  **never taken effect**. Production runs with `has_many_inversing` false and
  legacy connection handling on. authlogic 6.5.0 (allows AR ≥ 5.2, < 8.1)
  loads lazily, which silently turns both on. That changes behaviour: with
  inversing on, `spec/models/orders/ticket_exchange_spec.rb` sees a duplicate
  in-memory payment. So bump authlogic in the same window as the defaults
  flip, decide `has_many_inversing` deliberately (and fix whatever code
  depends on it being off), and run the login/session specs and features.
  Then check staff login, patron login and password reset by hand.
- **Ruby 3.3** (was 1b.9): unchanged, still a separate window.

**1c. Replace Webpacker (~1 day)**

1. Add jsbundling-rails with esbuild. Build `seat_map_editor` to
   `app/assets/builds`, served by Sprockets.
2. Remove the empty `application` pack and its `javascript_pack_tag`. Switch
   `admin/seat_maps/editor.html.haml:60` to `javascript_include_tag`.
3. Delete webpacker, `config/webpack/`, `webpacker.yml`, `babel.config.js`,
   `postcss.config.js`, `bin/webpack*` and the unused npm packages.
4. Convert the 5 CoffeeScript files to JS and drop coffee-rails.
5. Update `bin/deploy`, `bin/docker-entrypoint` and the docs (the `troubleshooting.md`
   Node/OpenSSL note).
6. Dry-run `assets:precompile` on the production box before deploying.

**Deploy.** One window, or two if you'd rather ship 1c on its own, since it's
the only step that changes the production asset build. It is reasonable to
deploy Ruby 3.3 in its own window as well, because it touches the production host's
toolchain.

---

### Release 2: Rails 6.1 → 7.2 · ~3.5 days + defaults flips

On branch `rails-7.2`, one commit per step. `load_defaults` stays at `6.1`
throughout. `app:update` generates `new_framework_defaults_7_0.rb`, `_7_1.rb` and `_7_2.rb`;
leave them fully commented out.

**2a. → 7.0**

1. Bump `rails ~> 7.0.0`. Run `bin/rails app:update` and review each diff by hand;
   don't accept overwrites of `config/environments/*` blindly.
2. Pin `rack ~> 2.2` (see R13).
3. Convert the enum to `enum :admission, ADMISSIONS, prefix: true`.
4. Fix every new deprecation until CI is green.

**2b. → 7.1**

1. Bump `rails ~> 7.1.0`, run `app:update`, and bump rspec-rails to 7.1 and
   exception_notification to 5.
2. Remove the removed `legacy_connection_handling` setting if anything still
   sets it, and remove the `fixture_path` line in `spec/rails_helper.rb`.
3. Confirm the date-format sweep with rendered output (mailers, tickets,
   reports), and audit implicit `Time#to_s`.
4. Adopt `config.autoload_lib(ignore: %w[tasks templates])`, reconciling it with the
   existing `autoload_paths` and ignore list.
5. Verify site-theme reloading and the `ext_site_wrapper` symlink.

**2c. → 7.2**

1. Bump `rails ~> 7.2.0` and run `app:update`. Bump authlogic to 6.6, activeresource to 6.2,
   responders to 3.2 and simple_form to 5.4.
2. Remove `config/secrets.yml` and the `Rails.application.secrets` shim in
   `lib/required_secrets.rb` (`SECRET_KEY_BASE` is read natively), and update its spec.
3. Replace `ActiveRecord::Base.connection` with `with_connection` or
   `lease_connection` where it's easy, such as the reports that toggle `sql_mode`.

**Release 2 deploy.** Before the window, run the `@javascript` Cucumber features
locally and do a full pass of §5 against the branch in Docker. Deploy with
`load_defaults 6.1`. Rollback is a pure code redeploy of Release 1.

**Defaults flips (after about a week's soak).** These are small deploys, each a few settings,
walking through `new_framework_defaults_7_0.rb` → `_7_1.rb` → `_7_2.rb`:

- `raise_on_open_redirects`. This is safe because 1b already fixed the referer
  redirect.
- `button_to_generates_button_tag`. Check `admin/analysis_helper.rb:148`.
- The rest of each file in small groups.
- **Last in 7.0's file: `key_generator_hash_digest_class`.** Add the SHA1→SHA256
  cookie rotator *in the same deploy* so nobody is logged out (R2). Flip it last
  because a code rollback past this deploy would sign everyone out. Remove the
  rotator one or two releases later.
- When a file is fully enabled, delete it and bump `load_defaults` (7.0, then
  7.1, then 7.2).

---

### Release 3: Rails 7.2 → 8.1 · ~2 days + defaults flips

On branch `rails-8.1`. `load_defaults` stays at `7.2`.

**3a. → 8.0**

1. Bump `rails ~> 8.0.0` and run `app:update`. Bump rspec-rails to 8 and cucumber-rails to 4.
2. Confirm that nothing still pulls a `< 8` constraint
   (`bundle exec gem dependency`).
3. Fix new deprecations until CI is green.

**3b. → 8.1**

1. Bump `rails ~> 8.1.0`, run `app:update` and fix the deprecations.

**Release 3 deploy.** This is the same pre-flight as Release 2. Deploy with `load_defaults 7.2`,
then flip the 8.0 and 8.1 defaults in small deploys and bump `load_defaults`
to 8.1.

**3c. Ruby 3.4.** Ship it in its own window after Release 3 has soaked, then
apply any remaining YJIT and GC tuning.

---

### Follow-ups (separate projects, not blocking)

- Host OS: macOS 14+ (lifts the sass-embedded cap) or a Linux host.
- money 7 / money-rails 2+, redis 5 + mock_redis, resque 3, and the Stripe gem beyond
  11.x (replace stripe-ruby-mock or bump it).
- Rack 3, once the Passenger version supports it.
- The optimizations in §6.

## 5. Per-release smoke checklist

The working checklist, with routes and what to look for, is
[`docs/runbooks/upgrade-smoke-checklist.md`](runbooks/upgrade-smoke-checklist.md).
Summary:

Public: browse productions → select performance → GA purchase → reserved-seat
purchase with seat picker → Stripe test card + 3DS → confirmation email renders
with correct dates/times → patron login and account page → flex pass and
membership purchase → donation.

Box office/admin: staff login → order entry and payment → exchange with price
differential → refund → reseating → seat map editor (Konva pack) →
DataTables grids with filters → address autocomplete → cocoon nested forms →
reports and CSV exports (spot-check date columns) → house counts →
`/admin/resque` (Resque::Server behind basic auth) → iCal export → membership
card render.

Ops: `rake setup:doctor`, the Resque workers and scheduler running, the Stripe
webhook arriving, exception mail delivered, and no new deprecation warnings in
`log/production.log` (also check `log/test.log` from the release branch's suite run).

## 6. Benefits of upgrading

### Security and maintainability
- Security patches again (Rails 8.1 until ~Oct 2027; Ruby 3.4 until ~Mar 2028),
  which matters for a payment-taking system handling patron PII.
- Removes ~15 dead or abandoned gems and the whole webpack 4/Babel toolchain;
  a smaller dependency surface, faster `bundle`/`yarn install` and deploys.
- Unblocks current versions of the rest of the ecosystem (rspec-rails 8,
  exception_notification 5, active_storage_validations, and others) and future hires'
  familiarity.

### Performance (mostly free)
- **YJIT** (Ruby 3.3+/3.4): typically a 15–30% speedup for Rails request
  throughput. It helps the ERB/HAML-heavy admin pages and report generation.
- Rails 7.1+ ships faster ActiveRecord query building, per-request memory
  improvements, and a much faster `assets:precompile` once esbuild replaces
  webpack 4.
- **`load_async`** (7.0+): the analysis dashboards and house-management
  reports that issue several independent queries per page can run them in
  parallel.

### Codebase optimizations the upgrade enables
- **Reports and exports:** `ActiveRecord::Base.with_connection` for the
  `SET sql_mode` toggles in `MembershipUsageReport`/`FlexPassUsageReport`
  (scoped, leak-free). `in_order_of` (7.0) replaces hand-rolled `ORDER BY FIELD(...)` SQL such as
  `app/datatables/membership_datatable.rb:4`.
- **N+1 detection:** `strict_loading` (6.1+, improved in 7.x) on the
  order/line-item/seat-assignment graph during checkout and exports. It turns
  silent N+1s into test failures you can fix with `includes`.
- **Data hygiene:** `normalizes` (7.1) for email/phone on `Address`/`User`
  can take over parts of `Address#regularize!` (`before_validation`) and makes
  duplicate-matching queries normalize their inputs the same way.
- **PII protection:** Active Record Encryption (7.0) for sensitive patron
  fields, with deterministic mode where you need lookups.
- **Tokens:** `generates_token_for` (7.1) for signed, expiring links
  (password resets, ticket/claim links, email unsubscribes) without token columns.
- **Rate limiting:** controller `rate_limit` (8.0) for login and checkout,
  complementing or simplifying parts of `rack-attack`.
- **Parameters:** `params.expect` (8.0) to tighten the 18 `params.permit!`
  admin actions incrementally.
- **Error reporting:** the `Rails.error` reporter (7.0+) gives one hook for
  exception_notification plus the scattered `rescue` blocks in reports and
  jobs.
- **Health check:** the built-in `/up` endpoint (7.1) gives `bin/deploy` a proper
  smoke target instead of curling the login page.
- **Authentication, longer term:** Rails 8's `has_secure_password` +
  `authenticate_by` + authentication generator could eventually replace
  authlogic + scrypt. Not needed for the upgrade, but it removes a gem that
  historically lags Rails releases.
- **Background jobs, longer term:** ActiveJob continuations/`perform_all_later`
  exist, but Resque works fine. Don't migrate ~60 job classes as part of this.

## 7. Open questions (answer before the relevant phase)

1. **Passenger:** version, and whether it runs under Apache or Nginx (docs
   disagree). This decides when Rack 3 is safe (R13). *(Before Release 2.)*
2. **Ruby on the box:** install method (rbenv/rvm/asdf/Homebrew) and CPU
   architecture (Apple Silicon or Intel). *(Before the Release 1 Ruby bump.)*
3. **Node/yarn on the box:** versions and install method. *(Before Release 1c.)*
4. **MySQL and Redis on the box:** exact versions. MySQL 8.0 went EOL in April 2026;
   8.4 LTS is the forward path (independent of Rails).
5. **Process supervision:** anything restarting Resque workers and the scheduler
   after a reboot (launchd, monit), or only the `nohup` scripts?
6. **macOS upgrade path:** can the box move to macOS 14+ (it lifts the
   sass-embedded cap), and is there a plan for when macOS 13 tools stop
   building?
7. **Backups:** how `storage/` (ActiveStorage, local disk) and MySQL are backed up
   today, for pre-deploy snapshots.
8. **Legacy layouts:** are the facebook/orders/none/performances layouts (which
   reference missing formtastic CSS) still reachable? Delete them if not.
