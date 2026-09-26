# Site Theming

Stagemgr ships generic, unbranded copy. Making it sound like *your* house is
three mechanisms, in descending order of preference:

| Kind of string | Where it belongs | Example |
|---|---|---|
| A **fact** | the `theater:` block of `config/server.yml` | phone, street address, doors-open time, social URLs, ticket-pickup window |
| A **proper noun** | nothing to do -- it is already `TheaterInfo#name` | "Thank you for supporting *Palisade Theater*" |
| **Editorial copy** | a view override in a site theme | "…and the many storefront theaters that make our home so special" |

Reach for a theme only for the third. A fact is read on nearly every public page
and in nearly every email; a config key means one place to change a phone number
instead of a grep across a theme.

`sites/README.md` in the repository is the reference for theme authors and goes
into more detail than this page.

## The `theater:` block

Under `all:` in `config/server.yml`. Every key may be left blank -- the sentence
that would have used it is omitted rather than printed empty, so a house with no
phone number simply never shows a "call us" line.

| Key | Meaning | Blank falls back to |
|---|---|---|
| `phone` | Box office phone, printed on order pages and in mail | the sentence is omitted |
| `street_address` | Street line | -- |
| `city_state_zip` | City/state/postcode line | -- |
| `pickup_window_text` | How the box office describes when tickets can be collected, e.g. "ninety minutes before curtain" | the sentence is omitted |
| `doors_open_minutes_before` | Minutes before curtain the house opens (an integer, or a string of digits) | the sentence is omitted |
| `website_url` | Marketing site | the Default theater row's `url` from the admin form |
| `facebook_url`, `twitter_url`, `instagram_url` | Social links; each button appears only if its URL is set | the button is omitted |
| `logo_url` | **Absolute** URL of a logo for email -- email clients cannot fetch this app's assets | the Default theater's uploaded logo, then the house name as text |
| `mailing_list_blurb` | One sentence under the mailing-list opt-in checkbox | the sentence is omitted |
| `box_office_display_name` | How the box office signs itself | `"<house name> Box Office"` |
| `artistic_director_name` | Who signs follow-up mail | see below |
| `artistic_director_title` | Their title, printed under the name in the signature block | nothing -- the title line is omitted. (`server.yml.example` pre-fills `"Artistic Director"`; there is no fallback in the template) |
| `artistic_director_email` | Their address | see below |
| `signature_image_url` | **Absolute** URL of a signature image for the sign-off | no image, just the typed name |
| `stripe_billing_portal_url` | Stripe customer portal link for members managing their own subscription | the button is omitted |

The box office **email** address is deliberately not here: it is the existing
`email: addresses: box_office:` key, read by `TheaterInfo#box_office_email`.

!!! warning "The house's name is database-driven"
    It is the `name` of the **Default theater row**, not a config key and not a
    theme string. Renaming that row in the admin renames your house in every
    public page and every email at once. That is intended -- and it means a
    careless rename is a very visible edit. Before any theater row exists,
    `TheaterInfo#name` falls back to `app_name` from `server.yml`.

**"The Default theater row"** means `Theater.default_theater`: the theater whose
`theater_class` is `Default` (the other classes are Co-production, Resident
Company, Visiting Company and Guest Artist) and, if there is more than one, the
**oldest** -- it is `where(theater_class: 'Default').order(:id).first`. A second
Default row is therefore inert as far as the house name goes, which is why
`rake setup:theater` renames the existing one instead of adding another.

### Reading facts in a view

`ApplicationHelper#theater_info` builds one `TheaterInfo` per render, and
`ActionMailer` includes the same helper:

```haml
- if theater_info.phone.present?
  %p= "Questions? Call the box office at #{theater_info.phone}."
```

| Method | Returns |
|---|---|
| `name` | The house's proper name |
| Any key from the table above | That fact, or `nil` |
| `full_address` | `"1229 W Belmont, Chicago, IL 60657"`, or `nil` when neither half is set |
| `box_office_email` | From `email: addresses: box_office:` |
| `box_office_from` | An RFC-2822 From: header, e.g. `"Palisade Box Office" <boxoffice@palisade.example>`. Never `nil` |
| `artistic_director_from` | The same for the artistic director, falling back to `box_office_from` |
| `artistic_director?` | Both a name **and** an address are configured |
| `first_person?` | A name is configured |
| `default_theater` | The Default `Theater` row, or `nil` |

The two predicates ask different questions and are not interchangeable:

- **`first_person?`** decides *pronouns*. A name is enough to say "I hope you
  enjoyed the show" -- the letter is signed by whoever the house named, whether
  or not patrons can write back. Every pronoun in the mailer views is chosen by
  this one predicate, so a house cannot end up with a letter that says "I" in
  one paragraph and "we" in the next.
- **`artistic_director?`** is stricter, because it decides the From: header and
  whether to print an address to reply to. Neither works without both halves.

A mistyped fact name raises `KeyError` listing the known facts, rather than
returning `nil` and quietly dropping a sentence.

## Themes

A **site theme** is a directory of view overrides carrying one house's editorial
copy. Themes live in this repository on purpose: house copy is editorial, it
gets reviewed, and it should promote with a git branch like every other change.

```sh
bundle exec rake setup:site[myhouse]
```

That copies `sites/example/` to `sites/myhouse/` and inserts
`site_theme: myhouse` under `all:` in `config/server.yml`. What you get is
deliberately close to empty:

```text
sites/myhouse/
├── README.md            how to override something, and what not to
├── views/.keep          shadows app/views/, same relative paths
├── locales/en.yml       loaded last, so these keys win (all commented out)
└── images/.keep         source-of-truth artwork, NOT served
```

Then fill it in -- a populated theme looks like this:

```text
sites/myhouse/
├── views/
│   ├── shared/_house_thanks_line.html.haml
│   └── order_mailer/_seating_policy.html.haml
├── locales/en.yml
└── images/signature.png
```

!!! note "Restart to activate it"
    `site_theme` is read while the environment file loads, so the process that
    ran `setup:site` is not using the theme yet -- `setup:doctor` will still say
    "site_theme not set". Restart (`docker compose restart stagemgr`) and the
    boot log says `[SiteTheme] 'myhouse' active`.

### The override rule

**Any file under `sites/<slug>/views/` shadows the same relative path under
`app/views/`** -- public pages, mailer templates and layouts alike, because the
theme directory is prepended to the view paths of both `ActionController::Base`
and `ActionMailer::Base` at boot.

To override a file, copy the generic one and edit the copy:

```sh
cp app/views/order_mailer/_seating_policy.html.haml \
   sites/myhouse/views/order_mailer/
```

Never edit `app/views/` for house copy -- the next house to install Stagemgr gets
whatever is there.

!!! tip "Keep overrides small"
    An override is a replacement, not a patch: your file renders, the generic
    one does not, and yours never receives later fixes to the file you copied.
    Override the smallest file that contains the words you want to change. If
    the string is buried in a large template, extract it into a partial in
    `app/views/` first and override that. `shared/_house_thanks_line` is the
    model.

`sites/example/` deliberately **ships no view files**: a blank override is worse
than no override, because it would render an empty section rather than the
generic one. A new theme starts empty and you add to it.

`sites/example/README.md` lists the files houses usually want to override --
transportation, dining, refunds, seating policy, amenities, the follow-up
letter's pride paragraph, the donation receipt.

### One override reaches further than you expect

`app/views/donation_orders/show.html.erb` renders `order_mailer/_signature`. So
a theme override of that mailer partial also restyles the **donation thank-you
web page**, not just the email. That is a feature -- one signature block, one
definition -- but it is worth knowing before you tune the partial for email
clients only.

### Admission-aware ticket emails

A ticket class's [admission](../productions/ticket-classes.md#admission-how-patrons-attend) (in person, virtual/streaming, or other) decides which parts of the confirmation, reminder and followup emails render. That decision is made in the **generic composing templates**, not in the partials themes usually override:

- The visit partials (`_transportation_instructions`, `_dining_recommendations`, `_seating_policy`, `_amenities`) are not rendered for an order with no in-person tickets. An override of them doesn't need any admission logic, and existing overrides keep working unchanged.
- The admission-specific wording lives in small leaf partials under `order_mailer/`, which are the override points:

| Partial | What it says |
|---|---|
| `_in_person_ticket_summary` | "We have N tickets reserved… waiting at the box office" (confirmation) and "Just a reminder, you have N tickets" (reminder, `reminder: true`) |
| `_virtual_ticket_summary` | The same for virtual tickets. Stream links belong in the ticket class's email annotation, not here. |
| `_followup_opening` | The first sentence of the producing-house followups, with an `in_person: false` variant that doesn't mention a visit |

!!! warning "Don't override the composing templates"
    `_performance_confirmation`, `_performance_reminder`, `_performance_info`, `standard_followup`, `first_time_followup` and `_tell_us_about_it` carry the admission branching. A theme that replaces one of them wholesale drops that logic, and streaming patrons would be told to pick up tickets at the box office. Override the leaf partials instead.

### Locales

`sites/<slug>/locales/*.yml` are appended last to `I18n.load_path`, so their
keys beat `config/locales/`. Today that carries exactly one string: the donation
receipt's subject line.

!!! note "A new locale file needs a restart"
    The load path is built at boot and I18n only watches files it already knows
    about. Editing a file that is already there is picked up on the next request
    in development; **adding** one is not.

### Slugs, and what stops the boot

A slug may contain lowercase letters, digits, hyphens and underscores. Anything
else raises at boot, which is what keeps `site_theme: ../../etc` from being a
path -- a malformed slug is always a typo or an attack, never a deployment that
should be allowed to serve generic pages.

A slug whose directory is simply **absent** only warns, and the app serves
generic copy. That asymmetry is deliberate: a production checkout that has never
had `sites/` deployed to it must keep booting.

A `sites/<slug>` that is itself a **symlink** still points wherever it points,
including outside the checkout. That is a file a developer created on purpose in
their own working tree, and it is not treated as an attack.

### Images

Themes serve no assets. `sites/<slug>/images/` keeps the artwork of record (a
signature, a logo) versioned alongside the copy that uses it -- nothing serves
it. Email clients cannot fetch anything from this application, so image URLs in
mail must be absolute and publicly reachable: set `theater: logo_url:` and
`theater: signature_image_url:` to URLs on your marketing site, or hard-code an
absolute URL in a theme partial.

## Testing a theme

The suite runs with **no theme active**, against the generic copy, so a broken
theme cannot mask a broken default. To exercise one:

```ruby
SiteTheme.with_theme('myhouse') do
  # views and locales installed for the duration of the block
end
```

`spec/mailers/theme_render_spec.rb` uses that to render every customer-facing
email under the `theaterwit` theme and assert its copy is intact. Add your own
house to it: a partial renamed under `app/views/` but not in your theme raises
only when that theme is active, so nothing else in the suite would catch it.

## The grep that keeps it honest

One house's name, phone number, street or people may appear **only** in:

- `sites/<slug>/**` -- that house's own theme
- `docs/**` -- documentation and examples
- test sentinels (`config/server.yml.example`'s `test:` block, specs, features)

Anything under `app/`, `lib/` or `config/` that names a specific theater is a
bug. Before merging a change to public pages or mail, grep for it:

```sh
git grep -nEi 'theaterwit|theater wit|975-8150|belmont' -- app lib config
```
