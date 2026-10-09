# Branches and Releases

Stagemgr ships in batches. Work accumulates on a **release branch**, is tested
there, and is merged into `master` in one step when the batch is ready for
users. `master` is therefore always what production is running, or is about
to run, and `bin/deploy` only ever pulls `master`.

## The branches

| Branch | Holds | Lifetime |
|---|---|---|
| `master` | Released code. Moves only at a release or a hotfix. | Permanent |
| `release/YYYY-MM<letter>` | The next batch. Cut from `master`; every feature PR targets it. | Until released, then deleted |
| feature branches | One change each, branched from the release branch. | Until merged |
| hotfix branches | A fix that cannot wait for the batch, branched from `master`. | Until merged |

Release branches are named for the month they are opened and a letter for the
batch within that month: `release/2026-10f` is the sixth batch opened in
October 2026. The names sort in order, which `bin/worktree-setup` relies on to
pick the newest one as its default base.

There is no permanent integration branch. Each release branch starts equal to
`master` and is retired when it merges, so nothing can drift for longer than
one batch.

## Day to day

Branch from the release branch and open the PR against it:

```sh
bin/worktree-setup my-change            # base defaults to the newest release/* branch
gh pr create --base release/2026-10f
```

CI runs on every PR, on every push to a release branch, and on every push to
`master`. Small chores can be committed straight to the release branch, as
they used to be to `master`.

## Hotfixes

A hotfix is a change that must reach users before the batch does. Branch it
from `master`, open the PR against `master`, deploy once it merges, and then
**immediately merge `master` into the open release branch**:

```sh
git checkout release/2026-10f
git merge master
git push
```

Merge, do not cherry-pick: the release branch must always contain all of
`master`, or the release merge conflicts on the same lines later. A hotfix
that carries a migration will usually conflict on the version line of
`db/schema.rb`; keep the higher version.

## Releasing

1. Open the next release branch first, so that new work has somewhere to go:
   ```sh
   git branch release/2026-11a release/2026-10f && git push -u origin release/2026-11a
   ```
2. Retarget any PR still open against the old release branch to the new one.
   GitHub otherwise retargets them to `master` when the old branch is deleted.
3. Open a PR from the old release branch to `master`, let CI pass, and merge it
   with a **merge commit** (not a squash) so the individual PR merges stay in
   history.
4. Tag the merge on `master` and push the tag:
   ```sh
   git tag v2026.10f master && git push origin v2026.10f
   ```
5. Deploy from `master` ([Deployment](deployment.md)).
6. Delete the old release branch. Release notes for the batch are the diff
   between the previous tag and this one, or `gh pr list --base release/2026-10f --state merged`.

The new release branch was cut from the old one in step 1 rather than from
`master`, so it already contains the batch and nothing is lost if the release
slips a day.
