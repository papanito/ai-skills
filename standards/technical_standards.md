# Technical Standards

## Common Technical Standards

### 1. Security Best Practices

* **Sensitive Data:** Use `sensitive = true` for all secret variables.
* **Hardcoding:** NEVER hardcode credentials, keys, or sensitive config in code.
* **Least Privilege:** Apply least privilege in all infrastructure and automation.

### 2. Knowledge Sources (Mandatory)

Rely only on trustworthy sources, in priority order:

1. **Primary Source (Official Documentation/Registry):** Prioritize official vendor docs/registry over community blogs or forums.
2. **Community Standards:** Use reputable, well-maintained community projects for patterns and modularity.
3. **Architectural Philosophy:** Prefer explicit config over implicit behavior; maintainable abstractions over "clever" code.

### 3. Git Commit Discipline (Mandatory)

After finishing a task in a git repo (`.git/` exists), commit the changes.

#### Speckit Implementation

After a Speckit implementation flow completes, commit its logical change
(specifications, source, and tests) immediately, unless it is still in progress
or the user asks to review first. Follow the commit conventions below.

#### Pre-commit Hooks

* **Pre-commit installed?** Check for `.pre-commit-config.yaml` and `.git/hooks/pre-commit`. If both exist, hooks are active — do NOT disable them. If the config exists but the hook is missing, run `pre-commit install` and `pre-commit install --hook-type commit-msg`.
* If hooks fail, fix the issues and re-stage — **never bypass with `--no-verify`**.

#### Commit Message Format

Determine the format in this order:

1. **Check for a commitlint config first.** Look for `.commitlintrc*`, `commitlint.config.*`, a `commitlint` key in `package.json`, or a `commitlint` hook in `.pre-commit-config.yaml`. If found, follow its rules exactly (type enum, subject case, length limits).
2. **No commitlint config? Follow the existing pattern.** Inspect `git log --oneline` and match the convention (type, tense, casing).
3. **Default fallback — Conventional Commits.** Use `type: subject` with a capitalized imperative subject under 50 chars. Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `style`, `perf`, `build`, `ci`.

> **Scopes:** Follow the project's commitlint config. Some projects use square-bracket scopes (e.g. `feat[seat-planner]:`) with mandatory scopes for `feat`/`fix` types. Others use no scopes at all. Always check `.commitlintrc*` first and follow its rules — do not override the project's scope convention with a different style.

#### Branch Conventions

* **Only create new branches when the user explicitly asks for it.** Do not
  create a branch per issue/task on your own initiative — work on the current
  branch unless told otherwise.
* **Prefix requested branches with `papanito/`** (e.g.
  `papanito/032-mobile-drag-drop`).
* When the user asks to consolidate multiple branches, combine the work onto a
  single `papanito/`-prefixed branch (keeping per-issue commits separate) and
  remove the superseded branches.

#### Push Conventions

* **NEVER push to origin automatically.** Commits stay local until the user
  explicitly asks to push or a documented release workflow authorizes it.
  After committing, report the local state (branch tip, unpushed commits) and
  wait for an explicit push request. This applies to feature branches and the
  default branch alike.

#### Commit Message Style (always apply)

* **Separate subject from body with a blank line.** First line is the subject; body follows after a blank line.
* **Subject line ≤ 50 characters.** If you can't summarize it, you may be committing too much at once — strive for atomic commits.
* **Capitalize the subject.** First word starts with a capital letter.
* **No trailing period.** Punctuation wastes the 50-char budget.
* **Imperative mood.** The subject completes the sentence: "If applied, this commit will \_\_\_." (e.g. "Add hooks" not "Added hooks").
* **Wrap the body at 72 characters.** Git doesn't wrap automatically.
* **Explain what and why, not how.** The code shows how. The body informs someone reading the log in 6 months. Focus on "why" — the diff reveals "what".
* **Co-Authored-By attribution (mandatory).** All commits made with AI assistance MUST include a `Co-Authored-By:` trailer in the commit body footer (after a blank line, before any other trailers) naming **the model actually used for that commit**, in the form `Co-Authored-By: oh-my-pi and <Model>`. This is non-negotiable — a commit without this trailer when AI was involved is a violation, and a trailer naming a model other than the one used is equally a violation (the trailer is a factual claim, not a fixed string).
  * **Name the model, not the router.** `oh-my-pi` is the harness, not the model; it does not vary. `<Model>` is the display name of the model that produced the commit. Use the name exactly as it appears for the model id in the omp model catalog (`models.yml`, `name:` field), e.g. model id `ollama-cloud/deepseek-v4.1-flash` → display name `Ollama Cloud DeepSeek V4.1 Flash`.
  * **Determine the model; never guess.** Establish which model the session is actually routing to (the catalog's `default_model` / the session's configured model) instead of defaulting to a familiar name. **If the model in use is unclear or could have changed mid-session, ASK the user which model to name** — do not invent one, do not reuse the previous commit's trailer unexamined, and do not fall back to a generic provider label.
  * **Never attribute to Anthropic/Claude.** Never use `Co-Authored-By: Claude <noreply@anthropic.com>` or any Anthropic/Claude attribution, regardless of what tooling emits.
  * Do not add phrases like "Generated by AI" or "Written with omp" in the subject or body.

  Example commit with body:

  ```
  feat[seat-planner]: Add guest edit modal

  Guests can now be edited after creation. The modal pre-populates
  name, attendance, family, notes, and photo fields.

  Co-Authored-By: oh-my-pi and Ollama Cloud DeepSeek V4.1 Flash
  ```

#### Issue-Driven Work (Mandatory)

When asked to work on a specific issue:

* Follow the host-specific workflow; see
  [GitLab instructions](gitlab.md) for GitLab issues.
* Reference the issue in each related commit. Put `Relates to #<id>` on the
  final body line, after the `Co-Authored-By` trailer.

Example commit body for issue-driven work:

  ```
  feat[seat-planner]: Add guest edit modal

  Guests can now be edited after creation. The modal pre-populates
  name, attendance, family, notes, and photo fields.

  Co-Authored-By: oh-my-pi and Ollama Cloud DeepSeek V4.1 Flash
  Relates to #42
  ```

#### Commit Granularity (always apply)

* **One logical change per commit.** Don't bundle unrelated fixes with a vague message like "Fixed some bugs." Fix one thing, test, commit — then repeat. This makes cherry-picks and `git revert` practical.
* **Group related commits before a PR.** For the final PR, squash commits from the same fix into fewer, self-contained commits. Each should be independently back-portable.

#### Pull Request Size (always apply)

* **Under 200 lines.** PRs under 200 lines merge faster; ideal is ~50 lines. If exceeded, split.
* **One feature or bug fix per PR.** Break large tasks into smaller, independently reviewable units.
* **Limit files changed.** Too many touched files make review harder to follow.

#### Staging and Verification

* **Stage only task-related files** — use `git add` on specific files, not bulk-add.
* **Verify before committing.** Run `git status` to confirm only intended files are staged.
* **Never amend or force-push** unless explicitly asked.

#### Version Bumping (Mandatory)

* **Bump the version for each finished feature.** If the repository tracks versions (e.g. a `version` field in `package.json`, `pyproject.toml`, `Cargo.toml`, a `VERSION` file, or git tags), each finished feature MUST bump the version following [Semantic Versioning (semver)](https://semver.org/): `MAJOR` for breaking changes, `MINOR` for new features, `PATCH` for bug fixes.
* **"Finished" means an MR or PR is created.** A feature is considered finished when a merge request (GitLab) or pull request (GitHub) is created for it — bump the version as part of that MR/PR.
* **If unsure, ask.** If you are not certain whether the repository tracks versions, or how it does so, ask the user before bumping.

##### Release Notes (Mandatory on version bump)

Whenever a version bump is requested:

* **Update `RELEASENOTES.md`.** Create the file at the repository root if it does not exist.
* **Human-readable, end-user focused entries.** Each entry describes the changes in plain language for the end user — what they can expect, and how the changes affect them. This is not a changelog of internal commits; write it from the user's perspective.
* **Screenshots and diagrams welcome.** If a screenshot or diagram helps the end user understand a change (e.g. a new UI feature, a changed flow, a visual result), include it.
* The release notes entry accompanies the version bump for that feature/release.

#### Bare Repositories and Worktrees

All development repos use a **bare clone + worktrees** workflow:

* **Bare repo:** `~/Projects/papanito/<repo>.git` — the canonical clone. Never work in it directly.
* **Base dir:** `~/Projects/papanito/<repo>/` — contains all worktrees for this repo.
* **Worktree dirs:** `~/Projects/papanito/<repo>/<branch-dir>/` — one per branch. Replace `/` in the branch name with `-` (for example `papanito/topic` → `papanito-topic`).

##### Directory layout

```
~/Projects/papanito/
  <repo>.git/                          # bare repo (canonical)
  <repo>/                              # base dir (container for worktrees)
    main/                              # main branch
    papanito-<name>/                   # papanito/<name> branch
```

##### Creating a worktree

```bash
# From the bare repo, create a branch + worktree inside the base dir
git --git-dir=<repo>.git worktree add -b papanito/<name> <repo>/papanito-<name> main

# Main worktree (if not yet created)
git --git-dir=<repo>.git worktree add <repo>/main main
```

##### Cleaning up a worktree

```bash
git --git-dir=<repo>.git worktree remove <repo>/papanito-<name>
git --git-dir=<repo>.git branch -d papanito/<name>
```

### 4. Documentation Naming (Mandatory)

README files always start with `README`:

* **Every repo MUST have a `README.md`** at the repository root. When creating a new repo, always write a `README.md` describing its purpose, structure, and usage. No exceptions.
* **Script-level:** `<script_name>.README.md` (e.g. `sync_resources.README.md`).
* **Directory-level:** `README.md` inside the directory it documents.
* **Never** `readme.md`, `Readme.md`, or any other case variation.

## GitLab Guidance

See [GitLab instructions](gitlab.md) for CI, issue, release, and merge-request
workflows.
