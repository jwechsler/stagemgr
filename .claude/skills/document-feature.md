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

1. Navigate to the login page and log in with credentials from memory (jeremy@theaterwit.org / devtest)
2. Navigate to the feature pages
3. Capture screenshots at key interaction points:
   - Empty/initial state of the page
   - Populated state with data filled in
   - Dropdown/autocomplete showing options
   - Results/output pages
   - Individual sections of complex pages (use element-level screenshots with `ref`)
4. Save screenshots to `docs/manual/assets/images/screenshots/[feature-name]-[description].png`
5. Use descriptive filenames like `analysis-selection-empty.png`, `analysis-results-full.png`

Reference screenshots in markdown: `![Alt text](../assets/images/screenshots/filename.png)`

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
- [ ] `docs/mkdocs.yml` — nav updated
- [ ] `docs/manual/index.md` — quick reference and organization list updated
- [ ] `docs/manual/reference/permissions-matrix.md` — permissions added (if applicable)
- [ ] Site builds without errors
