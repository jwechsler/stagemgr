# Upgrade Smoke Checklist

Manual pass for every production deploy in the Rails upgrade ([plan](../rails-upgrade-plan.md), §4 and §5): each release, each defaults flip, the esbuild swap and each Ruby bump. CI covers specs, non-JS Cucumber, eager loading and a production `assets:precompile`; this covers what it can't see — JavaScript-heavy admin pages, payments, mail and the running processes.

Paths are relative to the app's mount point: `https://www.theaterwit.org/tickets/…` in production, `http://localhost:8080/tickets/…` in local Docker.

**Correct date output** (`config/environment.rb`): `Time`/`Date` default `09/28/2026`, `:date_time12` `09/28/2026 07:30PM`, `:show_date` `Monday, September 28`. The regression to look for is ISO output — `2026-09-28` or `2026-09-28 19:30:00 -0500` — where one of those used to be.

**Stripe items** are marked *(Stripe)*. Local dev uses `BogusGateway` and live Stripe price IDs, so refunds, 3DS and subscriptions can't run end to end locally. Verify them in Stripe test mode on staging, or against production with a real card you then refund.

## Before the window

- [ ] Weekday daytime, with no on-sale, opening or show that night.
- [ ] Asset or Ruby change? Dry-run the build on the production box in a separate checkout first, so a failure can't touch the live tree:
  ```sh
  git -C ~/stagemgr worktree add ~/stagemgr-dryrun <branch>
  cd ~/stagemgr-dryrun && cp ~/stagemgr/config/*.yml config/ \
    && bundle install && yarn install --frozen-lockfile \
    && RAILS_ENV=production bundle exec rails assets:precompile
  git -C ~/stagemgr worktree remove --force ~/stagemgr-dryrun
  ```
- [ ] Pause the scheduler so nothing new is enqueued: `script/scheduler stop` (`bin/deploy` starts it again).
- [ ] Drain the queues: `/admin/resque` Overview shows 0 pending, and no worker is mid-job.
- [ ] MySQL dump: `mysqldump --single-transaction --routines stagemgr_production | gzip > ~/backups/pre-deploy-$(date +%F).sql.gz`
- [ ] Snapshot ActiveStorage: `tar czf ~/backups/storage-$(date +%F).tgz -C ~/stagemgr storage`
- [ ] Run `bin/deploy`, then everything below.

## Public

- [ ] Browse productions (`/productions/now_playing`), open a show page, pick a performance.
- [ ] General-admission purchase through to confirmation.
- [ ] Reserved-seat purchase: the seat picker loads, seats hold and release, checkout completes.
- [ ] *(Stripe)* Card purchase, and a 3DS card (`4000 0027 6000 3184`) that completes the challenge.
- [ ] Confirmation email renders with the right performance date and time (formats above) and working links.
- [ ] Patron login (`/login`) and the account page (`/`).
- [ ] Flex pass purchase (`/flex_pass_offers/:id/orders/new`) and membership purchase (`/membership_offers`). *(Stripe)* for recurring memberships.
- [ ] Donation (`/donations/new`).

## Box office and admin

- [ ] Staff login; the dashboard at `/` shows house counts for upcoming performances.
- [ ] Order entry (`/admin/ticket_orders/new`): address autocomplete finds a patron, production/performance/ticket-class autocompletes fill, cocoon's "Add tickets" row works, cash and card payment forms both load.
- [ ] Exchange with a price differential ("Exchange Order" on the order, `/admin/ticket_orders/:id/exchange_ticket_orders/new`); the balance is charged or refunded.
- [ ] *(Stripe)* Refund (`/admin/ticket_orders/:id/refund_orders/new`).
- [ ] Reseating from an order's ticket table: move a seat, commit, and the seat map reflects it.
- [ ] Seat map editor (`/admin/venues/:venue_id/seat_maps/:id/editor`): the Konva canvas draws, and select/drag/save work.
- [ ] DataTables grids with filters and sorting: `/admin/orders`, `/admin/addresses`, `/admin/users`.
- [ ] Other cocoon nested forms: address tags, and service line items on an order.
- [ ] Reports (`/admin/reports`): run Weekly Box Office and one CSV export; the date columns use `MM/DD/YYYY`.
- [ ] Analysis dashboards (`/admin/analysis`) chart.
- [ ] `/admin/resque` asks for basic auth, then shows the queues and the Schedule tab.
- [ ] iCal: enqueue `GenerateCalendar` from the Schedule tab; `performance_schedule.ics` in `static_cache_dir` gets a fresh mtime and its `DTSTART`s end in `Z`.
- [ ] Membership card renders (`/admin/memberships/:id/id_card`), with correct text and fonts.

## Ops

- [ ] `RAILS_ENV=production bundle exec rake setup:doctor` is all green (`bin/deploy` runs it; read the output).
- [ ] `script/resque-worker status` shows three workers; `script/scheduler status` shows one scheduler and no orphans.
- [ ] *(Stripe)* The next webhook to `/stripecb` gets a 2xx (Stripe dashboard → Webhooks → recent deliveries).
- [ ] Exception mail arrives: `RAILS_ENV=production bin/rails runner 'ExceptionNotifier.notify_exception(RuntimeError.new("upgrade smoke test"))'`.
- [ ] Deprecations: production sets `deprecation = :notify` with no subscriber, so `log/production.log` never shows them. Check `grep -c DEPRECATION log/test.log` from a local suite run on the release branch instead.
- [ ] `log/production.log` has no new errors in the first hour: `grep -E 'FATAL|Error' log/production.log | tail`.
