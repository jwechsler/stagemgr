---
name: document-feature
description: Create user documentation for a Stagemgr feature with screenshots
user_invocable: true
---

# Document a Stagemgr Feature

Create complete user documentation for a feature in the Stagemgr user manual, including screenshots captured from the running application.

## Instructions

When the user asks to document a feature (e.g., `/document-feature Analysis` or `/document-feature Seat Maps`), follow these steps:

### 1. Understand the Feature

- Read the relevant controller, views, and model files to understand what the feature does
- Check `app/models/ability.rb` to determine which roles have access
- Identify the key user workflows, inputs, and outputs

### 2. Study Existing Documentation Style

Read these files to match the established conventions:
- `docs/manual/index.md` — overall structure and quick reference format
- `docs/mkdocs.yml` — navigation structure
- Any existing section doc (e.g., `docs/manual/reports/reports-overview.md`) for style: admonitions (`!!! info`, `!!! warning`, `!!! tip`, `!!! note`), tables, heading hierarchy

### 3. Create Documentation Files

Create markdown files in `docs/manual/[section-name]/`:

- **Overview page** (`[section]-overview.md`): Access info (admonition), navigation path, what the feature does, setup/workflow instructions, tips
- **Detail pages** for each sub-feature: Detailed field tables, how-it-works explanations, related pages

Style conventions:
- Use `!!! info "Access"` admonition at the top showing which roles can use the feature
- Use `**Navigation:** Menu > Submenu` to show how to get there
- Use `---` horizontal rule after the navigation line
- Use tables for field descriptions and permission matrices
- Use `!!! warning` for important caveats
- Use `!!! tip` for usage advice
- Use `--` (not `-`) for em dashes in descriptions

### 4. Capture Screenshots

Use the Playwright MCP tools to capture screenshots from the running application at `http://localhost:8080/tickets/`:

1. Navigate to the login page and log in with the local dev admin credentials (kept outside the repo; see the Dev Login memory note)
2. Navigate to the feature pages
3. **Before every capture, replace sensitive data with placeholders** (see "Scrub Sensitive Data" below). Never save a screenshot that has not been scrubbed.
4. Capture screenshots at key interaction points:
   - Empty/initial state of the page
   - Populated state with data filled in
   - Dropdown/autocomplete showing options
   - Results/output pages
   - Individual sections of complex pages (use element-level screenshots with `ref`)
5. Save screenshots to `docs/manual/assets/images/screenshots/[feature-name]-[description].png`
6. Use descriptive filenames like `analysis-selection-empty.png`, `analysis-results-full.png`

Reference screenshots in markdown: `![Alt text](../assets/images/screenshots/filename.png)`

#### Scrub Sensitive Data

The dev database is a copy of production, so every page shows real patrons, and the manual is published publicly (stagemgr.theaterwit.org, public GitHub repo). **Always** replace personal and financial information with placeholder data in the page before capturing. Run JavaScript in the page after it loads and before the screenshot, and don't just blur or crop afterwards.

Overwrite values **by their position on the page** (the Buyer box, a table column by its header, a list row) rather than reading the real values out and matching them. That way no real data passes through the conversation or the script.

| Kind of data | Placeholder |
|---|---|
| Patron / customer / member name | Pat Patron (use Sam Sample, Alex Example for a second or third person) |
| Street address | 123 Main Street |
| City, state, ZIP | Chicago, IL 60613 |
| Email (text and `mailto:` links) | patron@example.com |
| Phone | 312-555-0100 |
| Card last four digits / card number | 4242 (e.g. "Visa ending in 4242") |
| Stripe / gateway references (`pi_…`, `ch_…`, `cus_…`, `sub_…`) | `pi_3EXAMPLE00000000000000` (same prefix, EXAMPLE body) |
| IP address (e.g. the change history's `ip_address is …`) | 192.0.2.10 |
| Staff email or login in audits and change history | boxoffice@example.com |
| Donor or member notes and free-text order notes that mention a person | Replace with neutral text, or leave out of the shot |

Production, performance, ticket class and venue names, prices, dates, and order and ID numbers are fine to leave as they are.

After saving, **open every PNG with the Read tool and check it** for any real name, address, email, phone, card digits, gateway reference or IP address. Look in dropdowns, autocompletes, datatables, change history and page titles too. Retake the shot if anything slipped through. Mention in your report that the screenshots were scrubbed.

### 5. Update Cross-References

- **`docs/mkdocs.yml`**: Add the new section to the `nav:` list in the appropriate position
- **`docs/manual/index.md`**: Add to both the Quick Reference table and the Manual Organization list
- **`docs/manual/reference/permissions-matrix.md`**: Add a permissions table for the feature if it has role-based access

### 6. Build and Verify

```bash
cd /Users/jeremyw/dev/wit/stagemgr/docs && source manual/.venv/bin/activate && mkdocs build
```

The mkdocs dev server may already be running at http://127.0.0.1:8001. If not:

```bash
cd /Users/jeremyw/dev/wit/stagemgr/docs && source manual/.venv/bin/activate && mkdocs serve -a 127.0.0.1:8001
```

Tell the user the docs are ready for review at that URL.

### 7. File Checklist

Before finishing, verify all of these exist/are updated:
- [ ] `docs/manual/[section]/[overview].md` — main documentation
- [ ] `docs/manual/[section]/[detail-pages].md` — sub-feature docs (if applicable)
- [ ] `docs/manual/assets/images/screenshots/` — screenshots captured
- [ ] Every screenshot scrubbed of personal and financial data, and each PNG opened and checked
- [ ] `docs/mkdocs.yml` — nav updated
- [ ] `docs/manual/index.md` — quick reference and organization list updated
- [ ] `docs/manual/reference/permissions-matrix.md` — permissions added (if applicable)
- [ ] Site builds without errors
