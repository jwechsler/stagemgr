---
name: peer-review
description: Interactive pre-commit peer review of uncommitted changes — walks through related blocks of code, checking DRY, clarity, Rails conventions, test coverage, and plan alignment, pausing for your questions after each block.
user_invocable: true
argument-hint: "[blank for uncommitted changes | 'branch' to review whole branch vs its release branch]"
---

# Peer Review

Run an interactive pre-commit peer review of Stagemgr code. An analysis
agent reads everything in full, groups changes into logical blocks, and you walk
through them together — one block at a time, with a pause for questions between
each.

**Input:** `$ARGUMENTS` (blank = uncommitted changes; `branch` = whole branch vs the current release branch)

---

## Phase 0 — Scope the changes

Run the commands below and capture their output:

```bash
git status --porcelain
git diff --stat
git diff --cached --stat
```

**If `$ARGUMENTS` is blank or empty** (default mode — uncommitted changes):
```bash
git diff
git diff --cached
```
Also read in full any files listed as `??` (untracked) in `git status --porcelain`
that are under `app/`, `lib/`, `spec/`, `features/`, `config/`, or `db/` —
git diff will not show them.

**If `$ARGUMENTS` is `branch`** (whole-branch mode), diff against the branch the
PR will target. That is the newest `release/YYYY-MM<letter>` branch (master is
production and only moves on a release merge or hotfix):
```bash
BASE=$(git for-each-ref --format='%(refname:short)' --sort=refname 'refs/remotes/origin/release' | tail -1)
git log "$BASE"..HEAD --oneline
git diff "$BASE"...HEAD
```
If the branch is a hotfix cut from master, use `origin/master` as `BASE` instead.

**If there is nothing to review** (no uncommitted changes and no untracked app
files) stop here and say: "Nothing to review — working tree is clean."

---

## Phase 1 — Gather plan context

Collect the intent behind the changes so the analyst can reconcile implementation
against goal. Read (do not quote in full — extract relevant sentences):

1. `.remember/today-$(date +%Y-%m-%d).md` and `.remember/recent.md` — look for
   entries tagged with the current git branch name.
2. Any `docs/release-notes/*.md` or `tmp/*.md` that mentions the current
   branch or the changed files.
3. The active plan file, if one exists under `~/.claude/plans/` and was created
   today (check mtimes with `ls -lt ~/.claude/plans/ | head -5`).

If after this you genuinely cannot determine what the change was intended to do,
ask the user: "In one sentence, what was the goal of this change?" before
proceeding.

---

## Phase 2 — Run the analysis

Invoke the **`peer-review-analyst`** agent. Provide it a self-contained briefing:

> **Briefing for peer-review-analyst**
>
> **Branch / scope:** [current branch], reviewing [uncommitted changes | whole branch vs <BASE>]
>
> **Changed files:**
> [list from Phase 0]
>
> **Diff:**
> [full diff output from Phase 0]
>
> **Plan context:**
> [relevant excerpts from Phase 1 — what this change was supposed to do]
>
> Please produce the structured block-by-block review as specified in your
> instructions.

Wait for the analyst to return its full structured output before proceeding.
The analyst inherits the session model.

---

## Phase 3 — Interactive walkthrough (the core of this skill)

**Present one block at a time.** Do not dump all blocks at once.

For each block in the analyst's output:

1. **Present the block** — show:
   - The block title and the files it covers
   - A brief quote or inline view of the key code (2–15 lines is usually right;
     use Read to fetch the exact lines if helpful)
   - The analyst's findings (HIGH / MEDIUM / LOW), each with the suggested fix
   - The coverage assessment
   - The discussion questions

2. **Pause.** End with: "Any questions on this block, or shall we move on?"

3. **Discuss.** Answer questions, clarify findings, work through any disagreements.
   If the user wants to fix something now, help them fix it before continuing.

4. **Advance only when the user signals readiness** (e.g. "next", "continue",
   "looks good", etc.).

Repeat for every block the analyst produced.

---

## Phase 4 — Fresh-eye re-evaluation

Present the analyst's **Fresh-eye re-evaluation** section:
- Plan alignment assessment
- Whether a simpler approach exists
- Any scope drift or architectural risk

Discuss and resolve any concerns before moving on.

---

## Phase 5 — Coverage check

Summarise the coverage gaps the analyst identified across all blocks.

**Important caveat to state explicitly:** SimpleCov runs with every `rspec`
invocation, but `coverage/` reflects only the last run, which is normally a
targeted one. Unless the analyst ran the relevant specs itself and read the
per-file results, what follows is reasoned coverage, not measured.

Offer to run the relevant specs:
"Shall I run `bundle exec rspec <spec files>` to confirm they're green?"

If the user says yes, run it:
```bash
bundle exec rspec <space-separated spec files from the analyst's coverage notes>
```

If Cucumber `features/` files were in scope, offer to run those too:
```bash
bundle exec cucumber <feature files>
```

Report pass/fail. If tests fail, pause — work through the failure before
proceeding to the wrap-up.

---

## Phase 6 — Wrap-up

Present the analyst's **Consolidated action list** (Must-fix / Should-fix /
Optional).

Give a clear **commit recommendation**:
- **Go** — no must-fix items, tests green
- **Go with caution** — only should-fix / optional items remain
- **No-go** — must-fix items unresolved or tests failing

Then offer:
1. "Shall I apply the must-fix changes now?" (if any remain)
2. "Shall I log this review summary to `.remember/today-<date>.md`?" (useful for
   the session handoff record)

Do **not** create a git commit — that stays the user's call.

---

## Notes

- This review is always interactive — never dump all blocks at once.
- This skill is complementary to `ecc:code-review` (which produces a static one-
  shot report). This one is for the conversational, peer-style review before you
  commit.
