# Site themes

A **site theme** is a directory of view overrides carrying one house's editorial
copy. Stagemgr ships generic, unbranded copy in `app/views/`; a theme replaces
the handful of files where your house needs to speak in its own voice.

Themes live in this repository on purpose. House copy is editorial, it gets
reviewed, and it should promote with a git branch like every other change —
rather than being edited live in a database or dropped onto a server at deploy
time, where nobody can diff it.

## Creating one

```sh
bundle exec rake setup:site[myhouse]
```

That copies `sites/example/` to `sites/myhouse/` and adds `site_theme: myhouse`
under `all:` in `config/server.yml`. (Without the rake task: copy the directory
yourself and uncomment the `site_theme:` line in `config/server.yml`.) Restart
the app; the boot log says `[SiteTheme] 'myhouse' active`.

A slug may contain lowercase letters, digits, hyphens and underscores. Anything
else stops the boot — which is what keeps `site_theme: ../../etc` from being a
path. (A `sites/<slug>` that is itself a symlink still points wherever it
points; that is a file a developer created on purpose in their own checkout, and
it is not treated as an attack.) A slug whose directory does not exist only
warns, and the app serves generic copy — so a checkout that has never had
`sites/` deployed to it still starts.

## Layout

```
sites/myhouse/
├── README.md            notes for whoever edits this next
├── views/               shadows app/views/, same relative paths
│   ├── shared/_house_thanks_line.html.haml
│   └── order_mailer/…
├── locales/en.yml       loaded last, so these keys win
└── images/              source-of-truth artwork, NOT served (see below)
```

A new theme starts empty — `sites/example/` ships no views at all, because a
blank override is worse than no override (it would render an empty section
rather than the generic one). You add files to it by copying the generic ones,
as `sites/example/README.md` describes.

## The override rule

**Any file under `sites/<slug>/views/` shadows the same relative path under
`app/views/`.** `sites/myhouse/views/order_mailer/_seating_policy.html.haml`
replaces `app/views/order_mailer/_seating_policy.html.haml` everywhere it is
rendered. This works for public pages, mailer templates and layouts alike,
because the theme directory is prepended to the view paths of both
`ActionController::Base` and `ActionMailer::Base` at boot.

To override a file: copy the generic one, edit the copy, leave the original
alone. **Never edit `app/views/` for house copy** — the next house to install
Stagemgr gets whatever is there. An override is a replacement, not a patch: your
file renders and the generic one does not, so anything you leave out is simply
gone from the page.

`sites/<slug>/locales/*.yml` are appended last to `I18n.load_path`, so their
keys beat `config/locales/`. Today that mechanism carries exactly one string
(the donation receipt's subject line); everything else with a voice is a view.
The load path is built at boot, so **adding a locale file to a theme needs a
restart** — I18n only watches files it already knows about. Editing one that is
already there is picked up on the next request in development.

### Keep overrides small

An override never receives fixes made to the generic file. A whole-page
override silently misses every later improvement to that page. So prefer
overriding a small leaf partial — `shared/_house_thanks_line` is the model —
over a full template, and if the string you want to change is buried in a large
file, extract it into a partial in `app/views/` first and override that. Several
such partials are extracted later in this branch for exactly this reason.

## What goes where

Three tiers, in order of preference:

| Kind of string | Where it belongs | Example |
|---|---|---|
| A **fact** | the `theater:` block of `config/server.yml` | phone, street address, doors-open time, social URLs, ticket-pickup window |
| A **proper noun** | nothing — it is already `TheaterInfo#name` | "Thank you for supporting *Wilma Theater*" |
| **Editorial copy** | a theme view override | "…and the many storefront theaters that make our home so special" |

Reach for a theme override only for the third. Facts are read on nearly every
public page and in nearly every email, and a config key means one place to
change a phone number instead of a grep across a theme.

⚠️ **The house name is database-driven.** It is the `name` of the Default
theater row, not a config key or a theme string. Renaming that row in the admin
renames your house in every public page and every email at once. That is
intended — but it means a careless rename is a very visible edit.

## Images

Themes serve no assets. `sites/<slug>/images/` is a place to keep the artwork of
record (an artistic director's signature, a logo) so it is versioned with the
copy that uses it — nothing serves it.

Email clients cannot fetch anything from this application, so image URLs in mail
must be absolute and publicly reachable. Set them as facts
(`theater: logo_url:`, `theater: signature_image_url:`) pointing at your
marketing site, or hard-code the absolute URL in a theme partial.

## Testing a theme

The test suite runs with no theme active, against the generic copy, so a broken
theme cannot mask a broken default. To exercise a theme in a spec:

```ruby
SiteTheme.with_theme('myhouse') do
  # views and locales are installed for the duration of the block
end
```

A mailer smoke spec added later in this branch uses that to render every
customer-facing email under the `theaterwit` theme and assert its copy is
intact. Add your own house to it — a partial renamed under `app/views/` but not
in your theme raises only when that theme is active, so nothing else in the
suite would catch it.
