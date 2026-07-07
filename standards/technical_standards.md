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

#### Pre-commit Hooks

* **Pre-commit installed?** Check for `.pre-commit-config.yaml` and `.git/hooks/pre-commit`. If both exist, hooks are active — do NOT disable them. If the config exists but the hook is missing, run `pre-commit install` and `pre-commit install --hook-type commit-msg`.
* If hooks fail, fix the issues and re-stage — **never bypass with `--no-verify`**.

#### Commit Message Format

Determine the format in this order:

1. **Check for a commitlint config first.** Look for `.commitlintrc*`, `commitlint.config.*`, a `commitlint` key in `package.json`, or a `commitlint` hook in `.pre-commit-config.yaml`. If found, follow its rules exactly (type enum, subject case, length limits).
2. **No commitlint config? Follow the existing pattern.** Inspect `git log --oneline` and match the convention (type, tense, casing).
3. **Default fallback — Conventional Commits.** Use `type: subject` with a capitalized imperative subject under 50 chars. Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `style`, `perf`, `build`, `ci`.

> **This project does NOT use scopes.** Never add a scope in parentheses or square brackets (e.g. ~~`feat[agent]:`~~ or ~~`fix(ui):`~~). Use scopeless types only: `type: subject`. If a commitlint `scope-enum` is present, prefer a scopeless type (`chore:`, `docs:`) over forcing a mismatched scope.

#### Commit Message Style (always apply)

* **Separate subject from body with a blank line.** First line is the subject; body follows after a blank line.
* **Subject line ≤ 50 characters.** If you can't summarize it, you may be committing too much at once — strive for atomic commits.
* **Capitalize the subject.** First word starts with a capital letter.
* **No trailing period.** Punctuation wastes the 50-char budget.
* **Imperative mood.** The subject completes the sentence: "If applied, this commit will \_\_\_." (e.g. "Add hooks" not "Added hooks").
* **Wrap the body at 72 characters.** Git doesn't wrap automatically.
* **Explain what and why, not how.** The code shows how. The body informs someone reading the log in 6 months. Focus on "why" — the diff reveals "what".

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

### 4. Documentation Naming (Mandatory)

README files always start with `README`:

* **Every repo MUST have a `README.md`** at the repository root. When creating a new repo, always write a `README.md` describing its purpose, structure, and usage. No exceptions.
* **Script-level:** `<script_name>.README.md` (e.g. `sync_resources.README.md`).
* **Directory-level:** `README.md` inside the directory it documents.
* **Never** `readme.md`, `Readme.md`, or any other case variation.
