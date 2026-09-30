# Purge Files From Git History

Removes files that should never have been published (screenshots with real patron data, a committed secret) from every commit on GitHub, not just the current tree. Written for the September 2026 screenshot leak; the blob list for that case is in the [appendix](#appendix-september-2026-screenshot-blobs).

A history rewrite changes the SHA of every commit after the first affected one. For the 2026 case that is 532 commits back to `20f710913` (2026-04-06). Plan it like a deploy.

**Fix the current tree first.** Replace or delete the files on master through a normal PR (for the screenshots, #45 and #46), redeploy the manual, and only then rewrite history. The rewrite below removes *old versions*; it leaves today's files alone.

## What a rewrite does and doesn't reach

| Place | Cleaned by this runbook? |
|---|---|
| Branches on GitHub (`refs/heads/*`) | Yes -- force-pushed |
| `gh-pages` (live manual) | Yes -- squashed separately (step 1) |
| Pull request refs (`refs/pull/N/head`), PR pages, "Files changed" | **No** -- GitHub makes these read-only. Old commits stay viewable by SHA until GitHub Support purges them (step 8) |
| Forks and other people's clones | No -- ask them to delete and re-clone |
| The production box's checkout | Yes, but by hand (step 7) |
| Your local clones and worktrees | Yes, by hand (step 6) |
| Search engines, the Wayback Machine | No -- request removal separately if the data was indexed |

If the leak is a **secret** (API key, password), rotate it first. A rewrite never makes a leaked secret safe again.

## Before you start

- [ ] Weekday daytime, no deploy in progress, and nobody (or no agent) has unpushed work. Anything unpushed on the old history will have to be rebased by hand.
- [ ] Every release is merged and deployed, so the production box is sitting on a commit that exists on master.
- [ ] Open PRs listed: `gh pr list --state open`. Their branches are rewritten together with master, so they stay mergeable, but note any the user or an agent is actively pushing to.
- [ ] Forks checked: `gh api repos/jwechsler/stagemgr/forks --jq '.[].full_name'` (none in 2026).
- [ ] `git filter-repo` installed: `brew install git-filter-repo`.
- [ ] Optional cleanup: delete merged, finished remote branches first, so fewer branches get rewritten:
  ```sh
  git branch -r --merged origin/master | grep -v -E 'master|gh-pages'
  git push origin --delete <branch> ...
  ```

## 1. Squash `gh-pages`

The manual's branch is build output, so its history has no value. Replace it with one commit holding the current site. The CNAME file must be in that tree, or GitHub drops the custom domain.

```sh
cd ~/dev/wit/stagemgr
/Users/jeremyw/dev/wit/bin/push-docs.sh              # deploy the fixed images first
git fetch origin gh-pages
TREE=$(git rev-parse origin/gh-pages^{tree})
git ls-tree "$TREE" | grep CNAME                     # must print a CNAME line
C=$(git commit-tree "$TREE" -m "Deployed manual (history squashed)")
git push --force origin "${C}:refs/heads/gh-pages"   # braces: zsh reads $C:r as a modifier
git branch -f gh-pages "$C"                          # mkdocs gh-deploy builds on the local branch
```

Check it:

```sh
git fetch origin && git log --oneline origin/gh-pages | wc -l   # 1
curl -s -o /dev/null -w "%{http_code}\n" https://stagemgr.theaterwit.org/   # 200
gh api repos/jwechsler/stagemgr/pages --jq .cname                # stagemgr.theaterwit.org
```

If the domain comes back null, see the CNAME recovery in `.claude/commands/push-docs.md`.

Done for the 2026 case on 2026-09-29.

## 2. Build the blob list

Strip **blob IDs**, not paths. Stripping a path would also delete today's clean file of the same name.

Every past version of the screenshots that is not the current version:

```sh
cd ~/dev/wit/stagemgr && git fetch origin
DIR=docs/manual/assets/images/screenshots
git ls-tree -r origin/master "$DIR" | awk '{print $3}' | sort -u > /tmp/current.txt
git log --all --raw --no-abbrev --format= -- "$DIR/*.png" \
  | awk '{print $4, $6}' | grep -v '^0000000' | sort -u > /tmp/allpairs.txt
awk 'NR==FNR{c[$1]=1;next} !($1 in c)' /tmp/current.txt /tmp/allpairs.txt > /tmp/old.txt
awk '{print $1}' /tmp/old.txt > ~/strip-ids.txt
wc -l ~/strip-ids.txt
```

For a different kind of file, change `DIR` and the glob. For one specific file, list its versions with `git log --all --raw --no-abbrev --format= -- path/to/file`.

Removing every superseded version (not only the ones known to leak) saves auditing each old image, and nothing needs old screenshots. Compare the list with the appendix before continuing: a new ID means a screenshot changed after this runbook was written.

## 3. Rewrite a fresh mirror

`filter-repo` refuses to run in a working clone, and should: work in a throwaway mirror.

```sh
mkdir -p ~/purge && cd ~/purge
git clone --mirror git@github.com:jwechsler/stagemgr.git stagemgr.git
cd stagemgr.git

# Keep a pre-rewrite backup (for rollback and for step 8's SHA lookup).
# It contains the leaked data: local only, deleted in step 9.
git bundle create ~/purge/backup.bundle --all

# Record the before state
git rev-parse master master^{tree} > ~/purge/before.txt
git for-each-ref --format='%(refname) %(objectname)' refs/heads > ~/purge/heads-before.txt

git filter-repo --strip-blobs-with-ids ~/strip-ids.txt
```

`filter-repo` also rewrites abbreviated commit SHAs inside commit messages (for example "Reverts 436d32d2b"), so references between commits keep working. It removes the `origin` remote; step 5 adds it back.

## 4. Verify before pushing anything

Run all of these. Stop if any fails.

```sh
cd ~/purge/stagemgr.git

# a) master's current files are byte-identical: the tree hash must not change
test "$(git rev-parse master^{tree})" = "$(sed -n 2p ~/purge/before.txt)" && echo "tree OK"

# b) no stripped blob is reachable from any branch
git rev-list --objects --branches | awk '{print $1}' | sort -u > /tmp/reachable.txt
comm -12 /tmp/reachable.txt <(sort -u ~/strip-ids.txt) | wc -l     # 0

# c) same set of branches as before
git for-each-ref refs/heads | wc -l
wc -l < ~/purge/heads-before.txt

# d) history length unchanged (a commit that only added a stripped file becomes empty and is dropped, which is fine)
git rev-list --count master
```

Also skim `git log --oneline -5 master` and check that the commit messages look right.

## 5. Force-push the branches

Push branches only. `refs/pull/*` is read-only on GitHub and would reject the whole push.

```sh
cd ~/purge/stagemgr.git
git remote add origin git@github.com:jwechsler/stagemgr.git
git push --force origin 'refs/heads/*:refs/heads/*'
git push --force --tags origin        # only if there are tags (none in 2026)
```

Check branch protection first: `gh api repos/jwechsler/stagemgr/branches/master/protection` (a 404 means none). If master is protected against force-pushes, turn that off for this push and back on afterwards.

**Rollback**, if the push went wrong: `git clone ~/purge/backup.bundle restore && cd restore && git push --force origin 'refs/heads/*:refs/heads/*'`. That republishes the leaked blobs, so only use it to recover lost work, then redo the rewrite.

Check GitHub: `git ls-remote --heads origin` matches `git for-each-ref refs/heads` in the mirror, and open PRs still show their diffs.

## 6. Re-sync local clones and worktrees

Every local checkout still holds the old history. Re-cloning is simplest. To keep the main dev checkout and its uncommitted work:

```sh
cd ~/dev/wit/stagemgr
git worktree list                     # finish or remove worktrees first
git worktree remove <path>            # for each finished one
git fetch origin --prune
git switch master
git reset origin/master               # mixed reset: working-tree edits stay; the tree is identical, so the diff is only your edits
git status                            # should show only your uncommitted changes
```

Local-only branches still point at old commits. Rebase any you need onto the new history, `git rebase --onto origin/master <old-base> <branch>`, and delete the rest. Then drop the old objects:

```sh
git reflog expire --expire=now --all
git gc --prune=now
```

Tell anyone else with a clone (and any running Claude session or agent worktree) to re-clone.

## 7. Production box

`bin/deploy` runs `git pull --ff-only`, which fails on rewritten history. Before the **next** deploy, on the production box:

```sh
cd ~/stagemgr
git status                        # must be clean apart from ignored config; stop and investigate if not
git fetch origin
git reset --hard origin/master
git log -1 --oneline              # the rewritten master
```

The files on disk don't change (same tree), so the running app is unaffected and there is nothing to restart. Run it in the same session as the rewrite, so the next deploy can't fail at a bad moment.

## 8. Ask GitHub to purge what we can't reach

PR refs and cached views keep the old commits viewable at `github.com/jwechsler/stagemgr/commit/<old sha>` and in each PR's "Files changed". Only GitHub Support can remove them.

1. Collect the old commit SHAs that added or changed the files, from the pre-rewrite backup:
   ```sh
   git clone -q ~/purge/backup.bundle /tmp/old-history && cd /tmp/old-history
   git log --all --format='%H %s' -- docs/manual/assets/images/screenshots/<file>.png
   ```
2. List the PRs that contain those commits: `gh pr list --state all --search <sha>`.
3. Open a request at https://support.github.com/contact (choose "Remove sensitive data"). Include the repo, the old commit SHAs, the PR numbers, and say the history has already been rewritten and force-pushed.

GitHub's guide: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository

## 9. Clean up and note it

- [ ] Once GitHub Support has confirmed the purge, delete `~/purge`, `/tmp/old-history` and `~/strip-ids.txt`. The backup bundle holds the leaked data.
- [ ] Old SHAs in PR descriptions, GitHub comments, OmniFocus notes and Claude memory no longer resolve. The SHAs in commit messages were rewritten in step 3; nothing else was.
- [ ] Add a line to the rails upgrade plan or changelog if it cites commit SHAs from before the rewrite.

## Preventing it

Manual screenshots come from a production copy of the database. The `document-feature` skill (`.claude/skills/document-feature/SKILL.md`, "Scrub Sensitive Data") now requires replacing patron, payment and IP details with placeholders in the page before every capture, and checking each PNG afterwards.

## Appendix: September 2026 screenshot blobs

All 33 superseded versions under `docs/manual/assets/images/screenshots/` as of 2026-09-29. **Leaked** marks the nine pre-scrub versions known to show real patron or payment data. The rest are older versions of screenshots that are clean today; they weren't audited individually and are removed anyway.

| Blob | File | |
|---|---|---|
| `cb6f4983e480ae38dd9a326b2364c61dbbe0f5fb` | customers-list.png | Leaked |
| `2e1ca2561d06533ef7338b278ba726fd6fe807d3` | dashboard.png | Leaked |
| `6e3aa8c64e5802441221d6e498824e046db411d6` | memberships-list.png | Leaked |
| `99225757c5efc292a1c9fd8bb89f4088d637824b` | passes-menu-memberships.png | Leaked |
| `71f16c15fb8573884cf6d8cbaffbc8f612750e75` | resource-pull-sheet-output.png | Leaked |
| `f9b926012e66f7e3f891da41dcfea958fd6483db` | ticket-revenue-results-special-offer-usage.png | Leaked |
| `1c778158256aeceb7a53c31aa1eef6de880e6efa` | ticketing-donation-form.png | Leaked |
| `681a5a785a0a8775ac880a44706982135ccf1c11` | ticketing-order-detail.png | Leaked |
| `735ef9e5c863aa82e25622f0f39e8e1254b2fae8` | ticketing-order-list.png | Leaked |
| `35f191962c731dde1175ed55b456c86cce99f7a6` | analysis-results-full.png | |
| `647ce5954180eeea0d4191768fb2e6840380db99` | analysis-revenue-projection.png | |
| `e89db8ef6d73c407d0b02ba54628241874653f78` | festivals-flex-pass-restriction.png | |
| `362dd806ec1639ef1a5535fc32a1402458caea84` | imports-overview.png | |
| `99981c9347e824971a735602360d3c7d1097e463` | offers-flex-pass-form.png | |
| `ce30fea07e8f0404eeb1da38a3181eafc3647556` | offers-flex-pass-form.png | |
| `0e8ed5742cdf4585441b27668a3228f87ee66c8a` | offers-flex-pass-list.png | |
| `c5121ebaa8e16f474e3215b3c48c8c92e304f20d` | offers-membership-form.png | |
| `34e384bf1223f89ea66992256c2e99080b1ea41a` | offers-membership-list.png | |
| `6d659dcbca9cf47d8b23ac6d05bb521bccd68e36` | offers-membership-list.png | |
| `cc5a593c397e12e48d1fd06d784a488e5843c847` | offers-special-offers-list.png | |
| `226ebee90ea723b42642a6d2521e54d70cf30174` | productions-ticket-class-form.png | |
| `471a9a93c50f2cf5a5bad716320730136f452598` | productions-ticket-class-form.png | |
| `949698b8c36da2df5d0d92926a5a52db8364e97d` | productions-ticket-class-form.png | |
| `4693444da7687474f9c6ae6602ceee2561f76c18` | productions-ticket-classes-list.png | |
| `8956512ddcffb912895a8e0ae847f66895a02090` | productions-ticket-classes-list.png | |
| `f605f3463b98c899f5580e02a6902a0eef79d1a6` | reports-membership-usage-offer.png | |
| `ee87af04bdd8fd2efaf05cb8dda9efbfff3081b6` | setup-theater-form.png | |
| `5ab926f781887a1dc361524ee0a8b8a522ced71f` | ticket-revenue-analysis-selection-empty.png | |
| `f8c76355e4d3110f6f50f422fdeb2a3348f3cd77` | ticket-revenue-analysis-selection-with-comparison.png | |
| `cabb096ebe5e56b4ae7f2ede0bb5e0bd407f8db2` | ticket-revenue-results-chart.png | |
| `657faa017db52229c520af28a2c64393beac26ab` | ticket-revenue-results-comparison.png | |
| `b5e87a50f935165633bd3cac9536930e438e2615` | ticket-revenue-results-dynamic-lift.png | |
| `ca269a41246a16751ce610f8d218bea81bf20b11` | ticket-revenue-results-summary-table.png | |

State on 2026-09-29: step 1 done (gh-pages squashed, live manual serving the scrubbed images); steps 2–9 not yet run.
