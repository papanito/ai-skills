# Technical Standards

## Common Technical Standards

### 1. Security Best Practices

* **Sensitive Data:** Use `sensitive = true` for all secret variables.
* **Hardcoding:** NEVER hardcode credentials, keys, or sensitive configuration in code.
* **Least Privilege:** Apply the principle of least privilege in all infrastructure and automation configurations.

### 2. Knowledge Sources (Mandatory)

When providing code or advice, rely only on trustworthy sources in this priority order:

1. **Primary Source (Official Documentation/Registry):** Always prioritize the official vendor documentation/registry over community blogs or forum posts.
2. **Community Standards:** Use reputable, well-maintained community projects for patterns and modularity standards.
3. **Architectural Philosophy:** Prefer explicit configuration over implicit behavior; maintainable abstractions over "clever" code.

### 3. Git Commit Discipline (Mandatory)

After finishing a task, if the workspace is a git repository (`.git/` exists), commit the changes.

#### Pre-commit Hooks

* **Pre-commit installed?** Check for `.pre-commit-config.yaml` and `.git/hooks/pre-commit`. If both exist, hooks are already active — do NOT disable them. If `.pre-commit-config.yaml` exists but `.git/hooks/pre-commit` is missing, run `pre-commit install` and `pre-commit install --hook-type commit-msg` to enable both the pre-commit and commit-msg hooks.
* If pre-commit hooks fail, fix the reported issues and re-stage — **never bypass hooks with `--no-verify`**.

#### Commit Message Format

Determine the format in this order:

1. **Check for a commitlint config first.** Look for `.commitlintrc*`, `commitlint.config.*`, a `commitlint` key in `package.json`, OR a `commitlint` hook in `.pre-commit-config.yaml`. If found, follow its rules exactly — including the scope syntax (parentheses vs square brackets), scope enum, type enum, subject case, and length limits. The commit-msg hook enforces this on commit. **If no scope from the config's `scope-enum` fits the change, use a scopeless type** (e.g. `docs:` or `chore:`) rather than forcing a mismatched scope.
2. **No commitlint config? Follow the existing pattern.** Inspect `git log --oneline` for the established convention and match it (type, scope, tense, casing).
3. **Default fallback — Conventional Commits.** If neither a config nor prior history exists, use `type(scope): subject` with a lowercase imperative subject under 72 characters. Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `style`, `perf`, `build`, `ci`. Only add a scope when one genuinely fits the change.

#### Commit Message Style (always apply)

Regardless of which format is used, every commit message MUST follow these rules:

* **Separate subject from body with a blank line.** The first line is the subject; after a blank line, the body follows.
* **Limit the subject line to 50 characters.** This ensures readability and forces concise summarization. If you can't summarize it, you may be committing too many changes at once — strive for atomic commits.
* **Capitalize the subject line.** The first word of the subject starts with a capital letter.
* **Do not end the subject line with a period.** Trailing punctuation is unnecessary and wastes the 50-char budget.
* **Use the imperative mood in the subject line.** A properly formed subject completes the sentence: "If applied, this commit will \_\_\_." (e.g. "Add pre-commit hooks" not "Added pre-commit hooks").
* **Wrap the body at 72 characters.** Git never wraps text automatically — wrap manually.
* **Use the body to explain what and why, not how.** The code shows how. The body should inform someone reading the log in 6 months what changed and why. Focus on the "why" — the diff usually reveals the "what".

#### Staging and Verification

* **Stage only files changed by this task** — do not bulk-add unrelated working-tree changes. Use `git add` on the specific files you created or modified.
* **Verify before committing.** Run `git status` to confirm only intended files are staged, then commit.
* **Never amend or force-push** unless explicitly asked.
