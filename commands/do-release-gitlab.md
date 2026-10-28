---
description: Cut a release — bump the version according to SemVer, tag the repository, write a commit-derived CHANGELOG plus separate end-customer release notes, and open an MR/PR + Release.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). `$ARGUMENTS` may contain:
- A bump level: `major`, `minor`, or `patch` (e.g. `/do-release-gitlab minor`)
- An explicit target version (e.g. `/do-release-gitlab 2.4.0` — must start with a digit)
- Optional free-text notes to include in the release notes

If empty, auto-detect the bump level from the commits since the last tag (step 3).

## Skill Scope Guard

This command is **self-contained**. While executing it, do NOT invoke,
load, or follow ANY skill — including `antigravity-maintainer-batch-release`
(which targets `sickn33/agentic-awesome-skills`, an unrelated repository).
Every requirement for this flow is defined in this file and in the
repository's `AGENTS.md`. All steps operate only on the current checkout
and its origin remote.

## Goal

Produce a complete, traceable release with THREE distinct artifacts:

1. **CHANGELOG.md** — developer-facing, generated AUTOMATICALLY BY THE
   PIPELINE (git-cliff job on tag pipelines) from conventional commits.
   The `/do-release-gitlab` flow does NOT edit it manually.
2. **Release notes** — end-customer-facing prose: what is new or better for
   the USER, written in plain language, no commit types or internals.
3. The version bump carried by an annotated tag + MR/PR, with the release
   notes published on the tag itself (GitLab/GitHub Release).

## Workflow

1. **Preflight**
   - Verify the working tree is clean (`git status --porcelain`); abort with
     the offending paths listed if not.
   - **Branch gate (user directive 2026-08-28): NEVER work on `main` unless
     explicitly instructed to do so.** If the current branch is `main` (or
     the default branch), STOP and ask the user which branch to use — do not
     cut the release on `main` without explicit instruction. If no release
     branch exists, ask what to do (e.g. create `papanito/release-v<next>`)
     before proceeding.
   - Determine the default branch and remote host from
     `git remote show origin` (GitLab → use `glab`; GitHub → use `gh`;
     abort with a clear message when neither CLI is authenticated).
   - Find the latest tag: `git describe --tags --abbrev=0` (fall back to the
     initial commit when no tag exists).

2. **Collect history**
   - List every commit since the latest tag:
     `git log --no-merges --format='%h %s' <last-tag>..HEAD`
   - Parse Conventional Commit types from subjects (`feat`, `fix`, `perf`,
     `refactor`, `docs`, `ci`, `chore`). Breaking changes are commits whose
     body contains `BREAKING CHANGE:` or whose subject has a `!` before the
     colon.

3. **Decide the next version** (SemVer, MAJOR.MINOR.PATCH)
   - If `$ARGUMENTS` names an explicit version, validate it with a strict
     regex and use it.
   - Otherwise pick the level:
     - breaking change present OR `feat` removed public behavior → `MAJOR`
     - any `feat` commit → `MINOR`
     - otherwise (only fixes/chore/docs) → `PATCH`
   - Compute `next = last-tag version + level`. State the decision and the
     reasoning in one line before continuing.
   - If nothing releasable changed since the last tag (no commits), report
     that and stop.

4. **Bump the version**
   - Update `package.json` (`version` field) via
     `npm version <next> --no-git-tag-version --no-commit-hooks` so every
     manifest stays consistent. If additional files carry the version
     (search `grep -rn "<old-version>" --include='*.{json,toml,yml}'`
     excluding node_modules/dist), update them too and list what changed.
   - When the project has no `package.json`, ask where the canonical version
     lives instead of guessing.

5. **Release notes** (end-customer-facing) — a SEPARATE artifact, saved to
   `release-notes/v<next>.md`:
   - Audience: event organizers using the product. Plain language, benefit-
     oriented ("You can now drag guests directly between tables"), NOT
     "feat(planner): add drag pipeline".
   - Include ONLY what a customer can observe: new capabilities, visible
     improvements, fixed annoyances, breaking behavior they must adapt to.
     EXCLUDE chores, refactors, CI, dependency bumps, internal renames —
     unless they change something the customer notices.
   - Structure: one short intro line, then `### New`, `### Improved`,
     `### Fixed`, and (only if present) `### Please note` for breaking/
     behavioral changes. Bullets over prose; no commit hashes, no issue IDs,
     no jargon.
   - NEVER paste commit subjects verbatim; rewrite each entry from the
     user's perspective. User-supplied free-text notes lead the section.
   - If genuinely nothing changed for end customers, say so explicitly in
     one line instead of inventing content.
   - **Date frontmatter (required)**: the file MUST start with
     `---\ndate: <YYYY-MM-DD>\n---\n` where the date is the release creation
     date (today, matching the tag being created). The release notes page
     renders this date next to the version; without it the page falls back
     to the file's git/mtime date, which is wrong for backfilled files.

6. **Commit, tag, push**
   - **Verify locally BEFORE anything is staged.** In this checkout, run the
     project's own gates — at least `npm run build` and `npm test` when those
     scripts exist. Both MUST pass. A failure stops the release here: do not
     commit, do not tag, and report the failing suite. Record the exact result
     (test counts, build) in the final report. Running them only in CI, or
     trusting a previous run from another checkout, does not satisfy this.
   - Stage only the touched version files and `release-notes/v<next>.md`.
   - Commit: `chore[release]: Release v<next>` (the capitalised subject is what
     commitlint's sentence-case rule accepts; `v<next>` alone is rejected).
     Do NOT reference an issue in this commit.
   - Tag: `git tag -a v<next> -m "Release v<next>"`.
   - Push the current branch and the tag together:
     `git push origin HEAD --follow-tags`.

7. **Open the MR/PR and publish the Release**
   - Source branch = current branch, target = the default branch detected in
     step 1.
   - **The MR/PR MUST close every issue this release implements** (owner
     directive 2026-10-28). Collect the issue ids from the commits since the
     last tag — `Closes #N` and `Refs #N` in their bodies — de-duplicate them,
     and keep only those still OPEN on the tracker: an already-closed issue is
     not re-closed and must not be listed. Append the set to the MR/PR
     description as its own block, one directive per issue, because that is the
     pattern GitLab and GitHub act on at merge:

     ```
     ## Closes

     Closes #467
     Closes #504

     ## References

     Refs #526
     Refs #527
     ```

     Rules for the block:
       - Derive the ids from THIS release's commits, never from the tracker's
         open list: an unrelated open issue must not be closed by a release.
       - `Closes` means the release IMPLEMENTS the issue. An issue this work
         touches but cannot close yet — a follow-up, a partially addressed
         item, or a follow-up issue created during the work — MUST be listed as
         `Refs #N` in the same description. Both lists are mandatory when both
         exist; neither is ever dropped for brevity. An issue that is only
         unrelated context is neither closed nor referenced.
       - If no issue ids are found, state that in the response; never invent
         one.
       - The block belongs to the MR/PR description only. The release notes
         file and the published Release stay customer-facing prose — a
         `Closes` line there closes nothing and reads as noise.
   - Title: `Release v<next>`; description = the END-CUSTOMER release notes
     from step 5 followed by BOTH blocks above — the issues it closes and the
     issues it references (the changelog stays in the repo, not the MR body).
   - Compose the description into a temp file (notes + closing block) and pass
     that, so neither half is lost to shell quoting.
   - GitLab: `glab mr create --title "Release v<next>" --description "$(cat <composed file>)" --label "maintenance::release"` — never invent labels beyond the project's existing set; drop the label flag if unsure.
   - GitHub: `gh pr create --title "Release v<next>" --body-file <composed file>`.
   - Publish the release ON the tag so customers find the notes there too:
     GitLab: `glab release create v<next> --notes-file release-notes/v<next>.md`
     GitHub: `gh release create v<next> --title "v<next>" --notes-file release-notes/v<next>.md`
   - Print the resulting MR/PR and Release URLs.

## Guardrails

- NEVER work on `main` unless explicitly instructed to do so (user directive
  2026-08-28). If no branch exists for the task, ask the user what to do
  before proceeding. This applies to the release flow too: the release
  commit and tag must live on a non-default branch (e.g.
  `papanito/release-v<next>`) unless the user explicitly says otherwise.
- **A tag may be re-cut ONLY while its release is unreleased on the default
  branch** (owner directive 2026-10-28). The precondition is both: the release
  MR/PR is still unmerged, and the tag exists only on the release branch — never
  on the default branch, never on a merged release. Once merged, tags are
  immutable. The re-cut procedure is in *Re-cutting an unreleased version*.
- NEVER bypass commit hooks (`--no-verify`) except `npm version`'s internal
  tag/commit, which is disabled above.
- **The project's build and test suite MUST be run LOCALLY in this checkout
  before the release commit and tag, and MUST pass.** This is a precondition,
  not a best-effort check: a failing suite stops the release, and a tree whose
  tests were not run locally is never tagged. CI is an additional gate, not a
  substitute.
- All commands MUST run against the actual repo state; never fabricate
  versions, dates, or changelog entries.
- **A release MR/PR always closes the issues it implements** (owner directive
  2026-10-28). The ids come from the commits since the last tag, not from the
  tracker's open list; an already-closed or merely-referenced issue is never
  listed as `Closes`. Step 7 defines the block.

## Re-cutting an unreleased version

Permitted only under the precondition above (MR unmerged; tag not on the default
branch). A release whose tag already sits on `main` is never touched.

1. **Re-run the local gate.** Build and tests must pass in this checkout before
   anything is re-tagged. A re-cut is still a release.
2. **Rebuild the history you want to tag.** If the fix that prompted the re-cut
   landed after the release commit, re-order so the release commit is last (e.g.
   `git reset --mixed <feature-tip>`, commit the fix, update the notes, then
   commit `chore[release]: Release v<next>`). Force-push the release branch with
   `git push --force-with-lease origin HEAD` — never a bare `--force`.
3. **Withdraw the draft release and the tag.** The Release object goes first so
   no page is left pointing at a tag that no longer exists:
   `glab release delete v<next> --yes` (GitHub: `gh release delete v<next> --yes`),
   then `git push origin --delete v<next>` and `git tag -d v<next>`.
   If the project protects `v*` tags, git answers "Protected tags cannot be
   updated" — delete through the API instead
   (`glab api -X DELETE "projects/<id>/repository/tags/v<next>"`), push the
   re-created tag, and leave the protection in place. Never disable a tag
   protection rule to get a re-cut through.
4. **Re-create the annotated tag on the new head** and push it with the branch:
   `git tag -a v<next> -m "Release v<next>"` · `git push origin HEAD --follow-tags`.
5. **Re-publish the release and refresh the MR body** from the (possibly updated)
   `release-notes/v<next>.md`, so the tag page, the release and the MR all state
   the same notes. Update the MR description with `glab mr update <iid>
   --description "$(cat <notes without frontmatter>)"`.
6. **Report the re-cut**, naming what changed since the withdrawn tag.

## Done When

- [ ] Build and tests were run LOCALLY in this checkout and passed before the
      tag (the result is reported)
- [ ] Version bumped everywhere it appears and committed
- [ ] No manual CHANGELOG edits were made — the pipeline's git-cliff job
      regenerates it on the tag
- [ ] Annotated tag `v<next>` created and pushed
- [ ] End-customer release notes exist at `release-notes/v<next>.md`,
      written in customer language (no commit subjects pasted verbatim)
- [ ] MR/PR opened with those release notes as description **and a `Closes #N`
      line for every implemented issue that is still open**, URL reported
- [ ] A Release published on the tag carrying the same notes
