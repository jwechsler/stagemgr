# Print flags on box office receipts

## Goal

When the box office hands out tickets, they should see at a glance that a patron needs special
attention, for example a major donor or someone who gave in the last six months. tktprint can now
print up to three small icons on the receipt, just right of the RECEIPT banner. stagemgr decides
which icons to request for each order.

tktprint holds **no business rules**. It only knows icon names. Which patrons get which icon is
stagemgr's job, and that is this story.

## What tktprint accepts (already shipped in tktprint, branch `feature/print-flags`)

- An optional top-level `flags` array in the order payload. Its values are icon names:

  | name        | icon                          |
  |-------------|-------------------------------|
  | `flag`      | pennant on a pole             |
  | `star`      | five-pointed star             |
  | `ticket`    | ticket with notched ends      |
  | `heart`     | heart                         |
  | `checkmark` | check mark                    |

- Up to **3** icons print, in the order sent. Extra or unknown names are logged in tktprint and
  skipped. They never cause an error.
- `POST /orders.json`: `flags` omitted or `[]` means no icons.
- `PUT /orders/:id/reprint.json`: `flags` sent replaces the stored flags. `[]` clears them.
  Omitting `flags` keeps what tktprint already has. stagemgr rebuilds the full payload on
  reprint, so it should always send `flags`, as `[]` when there are none.
- Icons appear on the **receipt only**, never on the patron's tickets.
- The set of names lives in tktprint's `config/flags.yml`. A new icon needs a tktprint change first.

## stagemgr changes

### 1. Payload

In `TicketOrder#build_tktprint_payload` (`app/models/concerns/tktprint_printable.rb`), add:

```ruby
flags: print_flags,
```

next to `patron_code`. The names are ASCII, so `PrinterTextSanitizer.sanitize_payload` leaves them
alone (it deep-transforms arrays of strings too).

### 2. Mapping rules to icons

The rules live in one place, `PRINT_FLAG_RULES` in the `PrintFlags` concern
(`app/models/concerns/print_flags.rb`), included in `TicketOrder`:

| order | icon (tktprint name) | rule |
|---|---|---|
| 1 | `star` | `address.vip?` |
| 2 | `flag` | `address.donor_tier_for_current_fiscal_year` is present and **not** in the configured excluded-tier list (Theater Wit excludes `"Up to $99.99"`) |
| 3 | `checkmark` | the order's `notes` are non-blank (including notes the app appends itself) |

The order of the rules is the order the icons print. `print_flags` returns the names as strings,
capped at 3 (`MAX_PRINT_FLAGS`).

The excluded tiers are the `littlegreenlight: donor_flag_excluded_tiers` key in `config/server.yml`, a
list of LGL tier labels copied exactly as the install's LGL names them (for example
`["Up to $99.99"]`). Unset means any current-year tier earns the flag. The check is
`Address#current_fy_flagged_donor?`.

Donor tiers come from LGL and always belong to the default theater, so the flag appears on every
receipt for that patron, whatever the show. That is intended: no theater scoping, no donation
order lookup, no dollar threshold. All three rules read stored columns, so `PrintBatchJob` makes
no extra queries and no LGL API calls.

### 3. Legend for staff

The receipt shows only icons. Add the legend (icon to meaning) to the box office documentation in
`docs/manual/` (house management or ticketing), and consider a small legend on the admin order page.

### 4. Relation to `patron_code`

`Address#customer_tag` already appends `A` (donor) and `M` (member) to `patron_code` on the stub.
Flags are the visual successor. Keep `patron_code` unchanged.

## Tests

Follow the existing payload specs in `spec/models/orders/ticket_order_*`
(`order.send(:build_tktprint_payload, 'BATCH-1', 1)`):

- the payload has `flags: []` for a patron who matches no rule
- each rule adds its icon name
- names come out in rule order and are capped at 3
- the reprint payload carries the same `flags`

## Also verify: the show time sent to tktprint

tktprint PR #3 changes how tktprint reads `performance_time`. It now prints the hour and minute
exactly as stagemgr sends them and ignores any offset. Before, tktprint shifted the time by its
container's zone. That container's "UTC" zone file had been overwritten by a mount of the host's
`/etc/localtime`, so a 7:00 PM show printed as 11:00 AM in docker.

**Risk:** if stagemgr ever sends a time already shifted to another zone, and the old tktprint
shift happened to undo it, the fix would make real tickets print the wrong time.

**What we know (supports wall-clock times):**

- stagemgr has `config.active_record.time_zone_aware_attributes = false` and
  `default_timezone = :local` (`config/application.rb:50-52`), so `performance.performance_time`
  is read as a plain wall-clock time and serialised with the stagemgr process's offset.
- tktprint's development log holds 81 payloads from stagemgr. Every `performance_time` is a
  normal show time with `+00:00`: `19:00` (72), `19:30` (32), `15:00` (8), `14:00` (8). None
  look pre-shifted. The `+00:00` most likely just reflects a stagemgr container running on UTC.

**To confirm before merging tktprint PR #3:**

- [ ] For one production performance with a known show time, look at the `performance_time`
  that tktprint receives (tktprint log `Parameters:` line). It should be the show's clock time,
  for example `T19:00:00` for a 7:00 PM show, whatever the offset.
- [ ] Print that order with tktprint PR #3 deployed and check that the ticket, stub and receipt
  show the right time.
- [ ] Check the production hosts' zones (`date` in the stagemgr and tktprint containers and on
  the host). tktprint's prod compose file used the same `/etc/localtime` mount, so on a host
  not running UTC, tickets may have been printing shifted times.
- [ ] Optional hardening in stagemgr: send `performance_time` as a plain `"HH:MM"` string
  (`performance.performance_time.strftime('%H:%M')`) so no offset is ever involved. tktprint
  accepts that form (the log shows a few `"19:00"` payloads) and keeps the wall-clock time.

## Rollout

Deploy tktprint first. Older tktprint versions silently drop an unknown `flags` parameter, so the
order of deploys can't break printing. It only affects whether icons appear.

Before relying on icons, do one test print on the real Boca. The icons are 1-bit BMPs sent inline
with each receipt (`<SPr,c><bmp><G n>`), which the virtual printer renders, but the real printer's
handling of rotated inline bitmaps has not been confirmed yet.
