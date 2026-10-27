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
   - Stage only the touched version files and `release-notes/v<next>.md`.
   - Commit: `chore[release]: v<next>`.
     Do NOT reference an issue in this commit.
   - Tag: `git tag -a v<next> -m "Release v<next>"`.
   - Push the current branch and the tag together:
     `git push origin HEAD --follow-tags`.

7. **Open the MR/PR and publish the Release**
   - Source branch = current branch, target = the default branch detected in
     step 1.
   - Title: `Release v<next>`; description = the END-CUSTOMER release notes
     from step 5 (the changelog stays in the repo, not the MR body).
   - GitLab: `glab mr create --title "Release v<next>" --description "$(cat release-notes/v<next>.md)" --label "maintenance::release"` — never invent labels beyond the project's existing set; drop the label flag if unsure.
   - GitHub: `gh pr create --title "Release v<next>" --body-file release-notes/v<next>.md`.
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
- NEVER rewrite or move existing tags; releases are strictly additive.
- NEVER bypass commit hooks (`--no-verify`) except `npm version`'s internal
  tag/commit, which is disabled above.
- If `npm test` / build scripts exist and take < 2 minutes, run them once
  before tagging; on failure, stop and report — do not tag a broken tree.
- All commands MUST run against the actual repo state; never fabricate
  versions, dates, or changelog entries.

## Done When

- [ ] Version bumped everywhere it appears and committed
- [ ] No manual CHANGELOG edits were made — the pipeline's git-cliff job
      regenerates it on the tag
- [ ] Annotated tag `v<next>` created and pushed
- [ ] End-customer release notes exist at `release-notes/v<next>.md`,
      written in customer language (no commit subjects pasted verbatim)
- [ ] MR/PR opened with those release notes as description, URL reported
- [ ] A Release published on the tag carrying the same notes
