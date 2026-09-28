# Rails Upgrade: Recommendation, Risk Assessment and Plan

*Prepared 2026-09-28 against `master` at Rails 6.1.7.10 / Ruby 3.2.2.*

## 1. Recommendation

**Upgrade to Rails 8.1 (and Ruby 3.4), stepping through every minor version
(6.1 → 7.0 → 7.1 → 7.2 → 8.0 → 8.1), shipping each hop to production on its own.**

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
8.0 → 8.1 over 7.2 is small for this codebase (about two days; see §4).

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
part-time pace (one developer + Claude) is roughly **8–12 calendar weeks**,
with each hop deployed in a short, planned maintenance window.

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
decent_exposure (0 `expose` calls), i18n-js, uglifier, jquery-timepicker-rails
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
rails-jquery-autocomplete, cocoon, ajax-datatables-rails, simple-form-datepicker
(1 use), validates_formatting_of (2 uses), ri_cal (1 use), resque-lock-timeout
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
| R6 | **Production host is macOS 13** (Apple no longer patching it). Future gem/Ruby/Node releases increasingly assume newer OS and toolchains. | Medium (grows over time) | Medium–High | Not a blocker for this plan, but budget an OS upgrade to macOS 14+ (or a Linux move) alongside or after Phase 6. |
| R7 | **Autoload/eager-load surprises in production.** `app/models/**/` subdirectories are added as autoload roots, which are not eager loaded; one file defines the wrong constant. A class that loads fine lazily in dev can fail under eager load. | Medium | Medium | Fix the two bad files in Phase 1; add a CI step that eager loads with `config.eager_load = true` (`bin/rails zeitwerk:check` plus a full eager load); consider `config.autoload_lib` in 7.1. |
| R8 | **Unmaintained gems break quietly** (rails-jquery-autocomplete, cocoon, ajax-datatables-rails, decent_exposure removal, simple-form-datepicker, resque-lock-timeout, ri_cal). | Medium | Low–Medium (admin UX) | Per-hop smoke list covers autocomplete (addresses, ticket orders), DataTables admin grids, cocoon nested forms, calendar export. Replace any that break rather than patching. |
| R9 | **Monkey patches interacting with new framework code** (`Hash#deep_merge`, `validates_credit_card` reopening `ActiveRecord::Validations`, HWIA `to_yaml` used by audited). | Medium | Medium | Delete `hash_extensions.rb` (equivalent to ActiveSupport); keep the others under spec coverage; re-run audited specs every hop. |
| R10 | **Test coverage gaps.** Cucumber `@javascript` scenarios don't run in CI; the legacy `test/` dir (65 files) is never run; no precompile or eager-load check. Green CI can overstate safety for JS-heavy admin pages (seat maps, order entry, reseating). | High | Medium | Phase 0 adds precompile + eager-load checks to CI and a written manual smoke checklist; run `@javascript` features locally (Docker has Firefox + geckodriver) before each deploy. |
| R11 | **Mixed-version Resque jobs at cutover.** Jobs enqueued by old code run on new workers. | Low (arguments are plain IDs/strings) | Low–Medium | Pause the scheduler, let queues drain, deploy, restart workers (`bin/deploy` already restarts them). |
| R12 | **Rollback difficulty.** | Low | Medium | Rails upgrades here need no data migrations; `db/schema.rb` only changes its version header. Every hop is rollback-able by redeploying the previous commit (`git revert` + `bin/deploy`). Keep ActiveStorage migrations (if `rails app:update` generates any) in a separate, forward-compatible deploy. |
| R13 | **Passenger / Rack compatibility.** Rails 7.1+ allows Rack 3; old Passenger versions don't support Rack 3. | Low–Medium | High (site down) | Pin `rack ~> 2.2` through the upgrade (Rails 8.x still permits it; Sinatra 3 in `Resque::Server` also wants Rack 2); move to Rack 3 only after confirming the Passenger version. |
| R14 | **Framework defaults flipped wholesale** cause subtle behavior changes (e.g. `has_many_inversing`, `button_to` generating `<button>`, belongs_to strictness already on). | Medium | Medium | Flip `new_framework_defaults_X_Y.rb` settings one at a time or in small groups, each with a CI run, before bumping `load_defaults`. |

**Overall:** moderate, well-contained risk. The two highest-impact risks, R1
(date formats) and R4 (payments), are both preventable with targeted checks.
The risk of *not* upgrading (R0) is the largest on the table.

## 4. Plan

Principles: small PRs, green CI before each merge, each phase deployed to
production in a short planned window (a weekday daytime with no on-sale,
opening or show that night), soaked for about a week before the next hop.
Before each production deploy: pause resque-scheduler, drain the queues, take a
MySQL dump and a `storage/` snapshot, then run `bin/deploy`, then do the manual
smoke checklist (§5).

### Phase 0: Safety net (on 6.1) · ~1 day

1. Add `bundle exec rails assets:precompile` to `.github/workflows/test.yml`.
2. Add an eager-load job to CI (`RAILS_ENV=test bin/rails zeitwerk:check` plus a
   `Rails.application.eager_load!` run with all model subdirectories).
3. Set `config.active_support.deprecation = :raise` in `config/environments/test.rb`
   (after Phase 1 fixes the one existing warning).
4. Write the manual smoke checklist (§5) into `docs/runbooks/`.
5. Align the lint workflow's Ruby with `.ruby-version`.
6. Resolve the `sqlite3` lockfile platform churn by removing the gem (Phase 1).

### Phase 1: Clean up on 6.1 · ~1.5 days

1. Remove unused gems: resque-web, sqlite3, activerecord-session_store,
   decent_exposure, i18n-js, uglifier, the dev fossils; verify and remove
   jquery-timepicker-rails. Add `gem 'sprockets-rails'` explicitly.
2. Fix initializer autoloading: move the boot-time `lib/` requires in
   `monkey_patches.rb` / `site_theme.rb` into `to_prepare` blocks, or into
   `autoload_once` / ignored paths.
3. Delete `app/models/admin/report_request.rb`; fix the `my_emma_patches` ignore
   path; delete `hash_extensions.rb`, `footnotes.rb`, `config/spring.rb`,
   `config/resque_web.rb`, `whiny_nils` lines; decide on the legacy `test/` dir
   (delete or port anything valuable).
4. `.deliver` → `.deliver_now` (4 sites).
5. `to_s(:fmt)` → `to_formatted_s(:fmt)` (43 sites; works on 6.1 through 8.x;
   rename to `to_fs` later if desired). Replace reliance on
   `Time::DATE_FORMATS[:default]` with explicit formatting.
6. `redirect_to referer` → `redirect_back(fallback_location: …)`.
7. Bump the gems that already support 6.1: rspec-rails 6.1, cucumber-rails 3.1,
   exception_notification 4.6, authlogic 6.5 (verify its Rails 6.1 floor; if it
   requires 7.0, move this to Phase 3).
8. Set `load_defaults 6.1` and delete `new_framework_defaults_6_1.rb` (remove the
   `legacy_connection_handling` line; it's the 6.1 default anyway).
9. **Ruby 3.3** (update `.ruby-version`, Dockerfile, production Ruby; add a
   `ruby` directive to the Gemfile). Enable YJIT
   (`RUBY_YJIT_ENABLE=1` in the Passenger environment).

### Phase 2: Replace Webpacker (on 6.1) · ~1 day

1. Add jsbundling-rails with esbuild; build `seat_map_editor` to
   `app/assets/builds`, served by Sprockets.
2. Remove the empty `application` pack and its `javascript_pack_tag`; switch
   `admin/seat_maps/editor.html.haml:60` to `javascript_include_tag`.
3. Delete webpacker, `config/webpack/`, `webpacker.yml`, `babel.config.js`,
   `postcss.config.js`, `bin/webpack*`, and unused npm packages.
4. Convert the 5 CoffeeScript files to JS; drop coffee-rails.
5. Update `bin/deploy`, `bin/docker-entrypoint`, docs (`troubleshooting.md`
   Node/OpenSSL note).
6. Dry-run `assets:precompile` on the production box before deploying.

### Phase 3: Rails 7.0 · ~1.5 days

1. Bump `rails ~> 7.0.0`; run `bin/rails app:update` and review each diff by hand
   (don't accept overwrites of `config/environments/*` blindly).
2. Pin `rack ~> 2.2`.
3. Add the SHA1→SHA256 cookie rotator, then flip
   `new_framework_defaults_7_0.rb` settings in small groups:
   `raise_on_open_redirects`, `button_to_generates_button_tag` (check
   `admin/analysis_helper.rb:148`), cache format, and so on.
4. Convert the enum to `enum :admission, ADMISSIONS, prefix: true`.
5. Fix all new deprecations (the test env raises on them now).
6. Deploy, soak, then `load_defaults 7.0`.

### Phase 4: Rails 7.1 · ~1 day

1. Bump `rails ~> 7.1.0`, `app:update`; rspec-rails 7.1; exception_notification 5.
2. Remove the `fixture_path` line; confirm the date-format sweep with rendered
   output (mailers, tickets, reports); audit implicit `Time#to_s`.
3. Adopt `config.autoload_lib(ignore: %w[tasks templates])`, reconciling with the
   existing `autoload_paths`/ignore list.
4. Verify site-theme reloading and the `ext_site_wrapper` symlink.
5. Flip 7.1 defaults, deploy, soak, `load_defaults 7.1`.

### Phase 5: Rails 7.2 · ~1 day

1. Bump `rails ~> 7.2.0`, `app:update`; authlogic 6.6; activeresource 6.2;
   responders 3.2; simple_form 5.4.
2. Remove `config/secrets.yml` and the `Rails.application.secrets` shim in
   `lib/required_secrets.rb` (`SECRET_KEY_BASE` is read natively); update its spec.
3. Replace `ActiveRecord::Base.connection` with `with_connection` /
   `lease_connection` where it's easy (reports toggling `sql_mode`).
4. Flip 7.2 defaults, deploy, soak, `load_defaults 7.2`.

### Phase 6: Rails 8.0 → 8.1 · ~2 days

1. Bump `rails ~> 8.0.0`, `app:update`; rspec-rails 8; cucumber-rails 4.
   Confirm nothing still pulls a `< 8` constraint (`bundle exec gem dependency`).
2. Flip 8.0 defaults, deploy, soak, `load_defaults 8.0`.
3. Repeat for `rails ~> 8.1.0`.
4. **Ruby 3.4**, then enable any remaining YJIT/GC tuning.

### Phase 7: Follow-ups (separate projects, not blocking)

- Host OS: macOS 14+ (lifts the sass-embedded cap) or a Linux host.
- money 7 / money-rails 2+, redis 5 + mock_redis, resque 3, Stripe gem beyond
  11.x (replace stripe-ruby-mock or bump it).
- Rack 3, once the Passenger version supports it.
- Optimizations from §6.

## 5. Per-deploy smoke checklist (draft)

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
webhook arriving, exception mail delivered, and `log/production.log` clear of
deprecation noise.

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
   disagree). This decides when Rack 3 is safe (R13). *(Before Phase 3.)*
2. **Ruby on the box:** install method (rbenv/rvm/asdf/Homebrew) and CPU
   architecture (Apple Silicon or Intel). *(Before the Phase 1 Ruby bump.)*
3. **Node/yarn on the box:** versions and install method. *(Before Phase 2.)*
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
