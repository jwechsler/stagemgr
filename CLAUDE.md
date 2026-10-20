# STAGEMGR DEVELOPMENT GUIDE

## Project Overview
Stagemgr is a ticketing platform to sell tickets to end users for live events.  It supports multiple theatre venues, multiple producing companies and all necessary backend operations for box office service. 

## Stagemgr development

1. Stagemgr runs under Rails 6 and Ruby 3
2. The development environment runs in Docker. `stagemgr/docker-compose.yml` is the primary stack (app + mysql + redis); Theater Wit's workspace layers the Foundation marketing site on top of it from `../site/`.
3. Stagemgr has a dedicated git repository. Git commands MUST ALWAYS be executed from the stagemgr directory to reflect changes to stagemgr
4. RSpec tests can be run directly from the stagemgr directory without proxying through Docker:
   - Run all tests: `cd /Users/jeremyw/dev/wit/stagemgr && bundle exec rspec`
   - Run specific test file: `cd /Users/jeremyw/dev/wit/stagemgr && bundle exec rspec spec/models/orders/flex_pass_order_spec.rb`
   - Run specific test: `cd /Users/jeremyw/dev/wit/stagemgr && bundle exec rspec spec/models/orders/flex_pass_order_spec.rb:10`

## Setup, Configuration and Theming

Developer documentation lives in `docs/manual/developer/` (published to
stagemgr.theaterwit.org) and `README.md`. The essentials:

- **`rake setup:*`** (`lib/tasks/setup.rake`, implementation in `lib/tasks/setup/`)
  scaffolds and checks an install: `setup:config` copies `config/*.yml.example` →
  `config/*.yml` and `.env.example` → `.env` (never overwrites, no Rails boot);
  `setup:bootstrap` creates the DB and loads `db/schema.rb`; `setup:site[slug]`
  creates a theme; `setup:wizard` runs the whole first-run sequence;
  **`setup:doctor`** is the health check — run it first when something is wrong.
  `config:setup` is a deprecated alias for `setup:config`.
- **Secrets go through `AppSecrets`** (`lib/app_secrets.rb`), never bare `ENV[]`
  or `Rails.application.credentials`. Order: non-blank ENV → encrypted
  credentials → (deprecated, `resque_admin_password` only) `config/server.yml`.
  Blank ENV counts as absent. `lib/required_secrets.rb` aborts a production web
  or resque boot when a required secret is missing from both sources.
- **House copy lives in `sites/<slug>/views/`**, selected by `site_theme:` in
  `config/server.yml`; those files shadow the same paths under `app/views/` for
  pages and mail alike. Theater Wit's copy is `sites/theaterwit/`. Never put a
  specific theater's name, phone or address in `app/`, `lib/` or `config/`. See
  `sites/README.md`.
- **Plain facts** (phone, address, pickup window, social URLs, artistic
  director) are the `theater:` block of `config/server.yml`, read through
  `TheaterInfo` / the `theater_info` view helper. The house's *name* is not a
  key — it is `Theater.default_theater.name`.
- **The test environment reads the tracked `config/server.yml.example`**, not
  your gitignored `config/server.yml` (see `config/environments/test.rb`), and
  cucumber forces `RAILS_ENV=test` too. A key the specs need goes in that file's
  `test:` block, whose sentinel values (`555-BOX-OFFICE`, `Test Director`, …)
  are asserted by specs and features.

- **Format dates and times explicitly**: `time.to_formatted_s(:hour_min)`, never
  `to_s(:hour_min)`, and never a bare `Time#to_s` (including `"#{time}"`,
  `= time` in HAML, a Time in a CSV row). Rails 7.1 ignores both, so output
  would silently change. `spec/support/bare_time_to_s_detector.rb` fails RSpec
  and Cucumber on a bare call from app code (`BARE_TIME_TO_S=report` to list
  without failing). Deprecations raise in the test environment.

## Agent workflow
- The main session is the architect and orchestrator. It plans, splits work into small
  tasks, and reviews results. It does not write production code itself.
- Delegate each coding task to the `coder` subagent and each testing task to the
  `tester` subagent (`.claude/agents/`). Every handoff states the goal, the files in
  scope, and what "done" means.
- Coding always goes to Opus 5.5 (`coder`). Tasks the orchestrator judges
  low-complexity (lookups, sweeps, log or DB checks, running known specs) may go
  to an agent on `model: "sonnet"` instead.
- Evaluate every subagent report critically: read the actual diff, check it against
  the plan and these conventions, and send it back with specific fixes if it falls
  short. Work is not done until the tester reports green.
- Keep tasks small. If a subagent stops at its turn limit, narrow the task rather
  than just retrying it.

## Capacity gotcha
`Production#capacity` returns `seat_map.capacity` (live seat count) whenever a seat map is assigned, silently
overriding the stored column; read the manual value with `production.read_attribute(:capacity)`. Troubleshooting
helpers for inventory, orders, Resque, DB and capacity live in the `stagemgr-debugging` skill.
