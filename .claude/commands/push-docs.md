---
description: Rebuild the Stagemgr user manual with mkdocs and deploy it to GitHub Pages (stagemgr.theaterwit.org)
---

Rebuild the Stagemgr user manual with mkdocs and deploy it to GitHub Pages.

## Procedure

Run from anywhere:

```bash
/Users/jeremyw/dev/wit/bin/push-docs.sh
```

The script verifies `docs/manual/CNAME` exists, activates the project venv, and runs `mkdocs gh-deploy --force` — which builds the site and force-pushes it to the `gh-pages` branch of `jwechsler/stagemgr`.

## Where the manual is served

- **Live URL: https://stagemgr.theaterwit.org/** — a GitHub Pages custom domain (DNS CNAME to `jwechsler.github.io`).
- Also reachable at https://jwechsler.github.io/stagemgr/.
- The old rsync-to-`theaterwit.org:/Users/jeremyw/site6/static/stagemgr/` flow was retired 2026-07-10.

## CNAME requirement (critical)

`mkdocs gh-deploy --force` replaces the **entire** `gh-pages` branch. GitHub stores the custom-domain binding as a `CNAME` file on that branch — if a deploy omits it, GitHub **unsets the custom domain** and every `stagemgr.theaterwit.org` URL 404s (this happened 2026-07-12).

- `docs/manual/CNAME` (containing `stagemgr.theaterwit.org`) is copied by mkdocs into the site root, so every deploy preserves the domain. Never delete this file.
- If the domain gets unset anyway, restore it with:

```bash
gh api -X PUT repos/jwechsler/stagemgr/pages -f cname=stagemgr.theaterwit.org
```

then re-enable HTTPS enforcement once the certificate is provisioned:

```bash
gh api -X PUT repos/jwechsler/stagemgr/pages -F https_enforced=true
```

## Venv recovery

If the build fails with `bad interpreter` or `mkdocs not found`, the project-local venv at `docs/manual/.venv` is broken (commonly because the Homebrew Python it was built against was uninstalled). Rebuild it before retrying:

```bash
rm -rf docs/manual/.venv && \
  python3.12 -m venv docs/manual/.venv && \
  docs/manual/.venv/bin/pip install --quiet --upgrade pip && \
  docs/manual/.venv/bin/pip install --quiet mkdocs==1.6.1 'mkdocs-material==9.7.6'
```

Substitute `python3.13` or `python3.14` if available — the pinned package versions stay mkdocs 1.6.1 and mkdocs-material 9.7.6 regardless of Python minor version.

## What to verify after deploying

1. The build prints `Documentation built in <N> seconds` with no errors and the push shows `gh-pages -> gh-pages`.
2. `curl -s -o /dev/null -w "%{http_code}" https://stagemgr.theaterwit.org/` returns 200 (may take a minute after the push).
3. If a screenshot or markdown was just changed, confirm the changed page on the live site reflects it.
4. `gh api repos/jwechsler/stagemgr/pages --jq .cname` returns `stagemgr.theaterwit.org` — if null, follow the CNAME recovery steps above.

## Background

- Source: `docs/manual/` (markdown) + `docs/mkdocs.yml` (config and nav; `site_url` is `https://stagemgr.theaterwit.org/`)
- Build output: `docs/site/` (local working copy; the deployed copy lives on `gh-pages`)
- `docs/_site/` is a stale legacy build path from before April 2026; ignore it.
