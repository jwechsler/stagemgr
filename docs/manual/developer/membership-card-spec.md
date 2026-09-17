# Membership card — rendering specification

How to produce one printed membership card. This document is the design
contract; `config/membership_card_spec.yml` holds the subset of its numbers the
renderer actually reads (card size, photo box and tone, the three text fields).
The tracked file is `config/membership_card_spec.yml.example`; `rake
setup:config` copies it into place with the other `config/*.yml` files, and
the live copy is gitignored so a house can tune placement locally.

!!! note "How stagemgr implements this"
    The renderer is `app/services/membership_cards/` (ruby-vips). It reads its
    numbers from `config/membership_card_spec.yml` rather than transcribing
    them; anything in this document that is not in that file (the artwork baked
    into each background, millimetre equivalents, font names) is design
    reference only. The artwork and fonts are **not** in the repository: each membership offer
    carries its own background, front overlay and two fonts as ActiveStorage
    attachments, uploaded on the offer's admin form (see
    [Membership Offers](../offers/membership-offers.md#member-id-card-artwork)).
    When an offer has no fonts the card falls back to Helvetica / Helvetica Bold.
    Staff print a card from the membership detail page
    ([Managing Memberships](../ticketing/managing-memberships.md#generating-a-member-id-card)).

!!! warning "Fonts are registered per process, before the first text call"
    Pango fixes its font list the first time libvips renders text in a process
    and never rebuilds it, so a font file registered afterwards is invisible until
    the process exits -- and libvips' own `fontfile:` option only ever honours the
    first file it is given per process. The renderer therefore runs each card in
    a fresh child process (`bin/render-membership-card`, spawned by
    `MembershipCards::RenderProcess`) that registers the offer's font files
    through `MembershipCards::FontRegistry` -- fontconfig on Linux, CoreText on
    macOS, both via FFI -- and only then draws. Never render card text in the
    Passenger or Resque process itself.

- **One card at a time.** No batch step and no file to import.
- **Everything tier-specific is already in the artwork.** The membership
  offer's coloured oval and its label are part of the background image, so
  nothing at render time branches on membership type.
- **Four things vary per card**: the photo, the name, the member number and the
  member-since year.

---

## What you are given

| File | What it is | Where stagemgr keeps it |
|---|---|---|
| `background_<offer>.png` | One per membership offer. The whole card except the four variable fields. Opaque, already the full card size. | `MembershipOffer#card_background` |
| `front.png` | RGBA. Must be composited **above** the photo. | `MembershipOffer#card_front_overlay` |
| `fonts/` | The two typefaces used for the variable text. | `MembershipOffer#card_name_font`, `#card_label_font` |
| `badge-spec.json` | Every number in this document, machine-readable. | `config/membership_card_spec.yml`, trimmed to the keys the renderer reads |

## What you produce

One PNG per card, at exactly the pixel size given below, tagged 300 dpi.

## What you must supply

| Input | Notes |
|---|---|
| which background | The card's membership offer selects one of the `background_<offer>.png` files. |
| name | One string. Shrinks and wraps to fit; two lines is the practical maximum. |
| member number | One string. Printed verbatim — no formatting is applied. |
| member since | One string. **The card prints a year alone**, so reduce a date to its year before passing it in. |
| photo | Optional. Without one the card still renders correctly, with the chalkboard showing through the photo panel. Square-ish, at least 400 px on the short side, face near the middle. |

Where those values come from in the application is outside this document.


---

## The card

| | |
|---|---|
| Standard | ISO CR-80 / ISO 7810 |
| Size | 85.6 x 53.98 mm |
| Raster | **1011 x 638 px** at 300 dpi |
| Origin | top-left corner of the card |
| Printer | Evolis Badgy100 — 1.35 mm unprinted on every edge; keep lettering 3.4 mm clear of the edge |

Every coordinate below is given in pixels at 300 dpi and in millimetres. Use whichever your tooling speaks; they describe the same point.

---

## Layer order

```
1.  background_<offer>.png   opaque, full card
2.  the photo                cover-scaled, centre-cropped, desaturated
3.  front.png                alpha composite
4.  the three text fields
```

---

## 1 — The background

Load the background for the card's membership offer and use it as the canvas. It is already 1011 x 638 px, so there is nothing to place and nothing to scale. A background that is not that size is stale and should be regenerated rather than resized.

| Offer | Label in the oval | Oval colour | Lettering | File |
|---|---|---|---|---|
| Single | Individual | `#7894A2` | `#0A0A0A` | `background_single.png` |
| Dual | Dual | `#C67851` | `#0A0A0A` | `background_dual.png` |
| Student | Student | `#B2934D` | `#0A0A0A` | `background_student.png` |

The offer's colour appears twice in the art: the oval at bottom left and the hairline seam beside the photo.

---

## 2 — The photo

| | px | mm |
|---|---|---|
| X | 664 | 56.20 |
| Y | 28 | 2.40 |
| Width | 319 | 27.00 |
| Height | 581 | 49.18 |

1. **Cover-scale**: multiply by the larger of `box_width / source_width` and `box_height / source_height`, so the box fills with no letterboxing.
2. **Centre-crop** to the box.
3. **Desaturate** with Rec.709 luma on non-linear sRGB values: `0.2126, 0.7152, 0.0722`.
4. **Tone**: one affine ramp per channel on 0..1 values, **`out = 1.0812 * in + -0.0306`**. (That is `contrast(1.06)` then `brightness(1.02)` collapsed into a single pass.)
5. **Composite** at the X/Y above.

The left quarter of this box is almost entirely darkened by the foreground layer, so a face wants to sit centred or slightly right of centre. Skip this step entirely when there is no photo.

---

## 3 — The foreground

Composite `front.png` at `+0+0` with ordinary source-over alpha. It is full card size and mostly transparent: it carries the scrim over the photo and the cream frame that masks the panel's rounded corners.

---

## 4 — The text

Three fields, all **left-aligned** and anchored on the **baseline**, not the top edge. The name and member number are `rgb(243, 239, 233)`; the since year is `rgb(178, 147, 77)`, the same gold as the MEMBER eyebrow, so it reads apart from the number beside it. Each field's `color` is in the YAML file.

### Member number and member since

Fixed size, no fitting. Draw each at its baseline.

| Field | X (px) | Baseline (px) | X (mm) | Baseline (mm) | Font | Size (px) | Tracking (px) |
|---|---|---|---|---|---|---|---|
| Member number | 66 | 486 | 5.60 | 41.13 | Sketchnote Square | 35 | 1.4 |
| Member since | 350 | 486 | 29.63 | 41.13 | Sketchnote Square | 35 | 1.4 |

!!! warning "The since field moved right"
    The original design placed the year at x 292 (24.76 mm) with a 177 px box for the
    member number. Real member codes (`TW-XXXXXX`, nine characters, occasionally ten)
    set in Sketchnote Square at 35 px run 230-240 px wide, which put the number 7 px
    from the year. The year now starts at x 350 (29.63 mm), leaving a gap of roughly
    45 px like the one the design intended. The **SINCE** label baked into each
    background sits directly above the year and must move with it: backgrounds
    exported before this change still carry the label at x 292 and need
    re-exporting.


Neither is fitted or truncated. A member number long enough to reach the since column is a data problem rather than a layout one.

### The name

The only field that has to think. Its box:

| | px | mm |
|---|---|---|
| X | 66 | 5.60 |
| Y | 228 | 19.32 |
| Width | 567 | 48.01 |
| Height | 128 | 10.80 |

Font `Sketchnote Text` weight 700, tracking zero. It starts at **85 px** and shrinks until the wrapped text fits:

```
size = 85

loop:
    lines = wrap(name, max_width = 567 - 2)
    if 0.98 * size * line_count <= 128 - 2:  break
    size = size - 1.1811

first baseline = 228 + 0.8452 * size
next baseline  = previous + 0.98 * size
```

`wrap` may break **after a space or after a hyphen**. A line's width is its shaped advance width plus `tracking x character count`.

The 2 px margin is not decoration. Without it, a name whose second line lands within a pixel of the box edge flips between two lines and three on consecutive steps, and the loop settles on an arbitrary one of them.

---

## Already in the background — do not draw these

Listed only so nothing gets added twice.

| | |
|---|---|
| The oval | The offer's colour, with its label already set in it |
| `MEMBER` | Gold, above the name |
| `MEMBER NO.` / `SINCE` | The labels above the two values |
| The gold rule | Hand-drawn, under the name |
| The seam | Hairline in the offer's colour, beside the photo |
| Logo, cream frame, chalkboard ground | |


---

## Fonts

| Use | File |
|---|---|
| The name | `fonts/Sketchnote Text Bold.otf` (`card_name_font`) |
| Member number, member since | `fonts/Sketchnote Square.otf` (`card_label_font`) |

Both carry real kerning — roughly 1,600 pairs in Sketchnote Text Bold and 770 in
Sketchnote Square — so **measure text with an engine that applies it**. Summing
per-character advance widths drifts wide on a long name and can push the
shrink-to-fit loop a whole step off.

Advance width scales linearly with point size, so measuring once at a reference
size and scaling is both accurate and much cheaper than measuring on every
iteration of the fit loop.


---

## Traps

Each of these cost time while the artwork was being built. None of them
announce themselves.

**Compositing the photo over the foreground instead of under it.** This is the
one that ruins the card. `front.png` carries the scrim that washes across the
headshot and the cream frame that masks the panel's rounded corners. Put the
photo on top and the right-hand third goes flat and the corners come out square.

**Greyscale conversion is not one operation.** The intended conversion is
Rec.709 luma applied to *non-linear* sRGB values. ImageMagick's
`-colorspace Gray` (linear-light luminance) and Pillow's `convert('L')`
(Rec.601) are both a different picture. In ImageMagick the right operator is
`-grayscale Rec709Luma`.

**Line breaks fall after hyphens**, not only after spaces. "Ellsworth-Vance" may
become "Ellsworth-" / "Vance". An implementation that breaks only on spaces
decides a long double-barrelled name fits on two lines when it does not, and
prints it a size too large.

**Letter-spacing is not kerning.** The tracking values below are CSS
letter-spacing: added after *every* character, the last one included.
ImageMagick's `-kerning` adds it *between* characters. Measure with tracking off
and add `tracking x character count` yourself, or the two disagree by one
tracking unit per string.

**`-gravity` leaks out of parentheses in ImageMagick.** A `-gravity center` used
to centre-crop the headshot is still in force afterwards, so every later offset
is measured from the middle of the card instead of the top-left. The symptom is
a card that renders cleanly with no photo and no text anywhere on it. Reset with
`-gravity none` before each composite and each text draw.


---

## How a background is made

Design-time only — nothing at render time does this. A background is a render of the card design with the four variable fields removed and one membership offer's colour and label applied. Adding or recolouring a tier produces a new file and changes nothing downstream.

The rules governing the generated elements, in case a tier is added:

**The oval** is a fully rounded rectangle — corner radius is half its height. It sits at the bottom left, sized to its own label rather than to a fixed width, with the label in caps, centred, on the offer's colour. About **48 mm** of label width is available.

**A label that does not fit is clipped, not overflowed.** The column crops the oval mid-word and it loses its right cap. A bounding-box check will not catch it — the text has to be compared against its own padding box.

**The lettering on the oval** is chosen by comparing WCAG contrast ratios against both brand inks and taking the better, not by testing luminance against a threshold. Every colour in use sits below any sensible threshold while still being far more readable with dark lettering on it.

**The seam** hairline beside the photo takes the same offer colour as the oval.

---

## Tolerance

The geometry above was validated by building the card two independent ways and measuring where each field landed. Worst disagreement was **3 px — 0.25 mm** — below what a 260 x 300 dpi dye-sub printer resolves, so that is a reasonable bar for a new implementation.

If a field lands further out than a couple of pixels, the usual causes are anchoring text on its top edge instead of its baseline, missing the hyphen break rule, or measuring text without kerning. A long name can legitimately land one shrink step apart between implementations when it falls exactly on a wrap boundary; that is expected.

---

## Print constraints

- The target printer leaves **1.35 mm unprinted on every edge**. The cream frame in the art is 2.4 mm, so that border disappears into it.
- Keep anything added at least **3.4 mm** from the card edge.
- Output PNGs are tagged 300 dpi. Print at 100%, never "fit to page".
