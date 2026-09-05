# Example site theme

`rake setup:site[myhouse]` copies this directory to `sites/myhouse/` and points
`config/server.yml` at it. What you get is deliberately close to empty: a theme
with no files in it changes nothing, which is the right starting point.

Read `sites/README.md` first. It explains the override rule, and — more usefully
— explains which strings should never end up in a theme at all. Most of what
looks like house copy is a fact (phone, address, doors-open time), and facts
belong in the `theater:` block of `config/server.yml`, where there is one of
each instead of one per file that mentions it.

## How to override something

Copy the generic file into the theme, keeping its path, then edit the copy:

```sh
cp app/views/order_mailer/_transportation_instructions.html.haml \
   sites/myhouse/views/order_mailer/
```

An override **shadows the generic file completely** — yours is rendered and the
original is not. It is a replacement, not a patch, and it will not pick up later
fixes to the file you copied. So override the smallest file that contains the
words you want to change, and delete the override again if you stop needing it.

Any file under `app/views/` can be overridden this way. These are the ones
houses usually want:

| Copy from `app/views/` | Why |
|---|---|
| `shared/_house_thanks_line.html.haml` | One sentence, on donation and pass pages and in mail. The cheapest place in the app to sound like yourself. |
| `order_mailer/_transportation_instructions.html.haml` | Getting here: transit lines and the stop, which garage validates, where the accessible entrance is. The generic version prints your address and nothing else. |
| `order_mailer/_dining_recommendations.html.haml` | Where to eat first. Generic is empty — a ticketing system has no opinion about your neighbourhood. |
| `order_mailer/_refunds_and_exchanges.html.haml` | Your exchange policy in your own words. The generic version says only that tickets are non-refundable. |
| `order_mailer/_seating_policy.html.haml` | Latecomers, reserved vs general admission, house rules. |
| `order_mailer/donation_thank_you.html.erb` | The whole donation receipt. The generic letter is short and correct; replace it if you want to make a case for the money. |

`locales/en.yml` in this directory covers the one piece of house copy that is
not a view — the donation receipt's subject line. Everything else is a view.

## Delete what you do not use

An empty theme directory is fine and costs nothing. There is no file here you
are obliged to fill in.
