# Working Path Discipline (non-negotiable)

Edit ONLY in version-controlled source — never in symlink targets or runtime dirs:

| Artifact | Edit in | Not in |
| :--- | :--- | :--- |
| Skills, task agents, `AGENTS.md`, `link_resources.sh` | `ai-skills/` repo | `~/.omp/agent/` (symlinks) |
| Dotfiles (nvim, home-manager, omp config) | `~/.local/share/chezmoi/` | `~` (chezmoi target) |

# AI Harness

oh-my-pi (omp) agent configuration: model catalog (`models.yml`) and routing/failover (`config.yml`). The chezmoi source is the single source of truth; the runtime copy lives at `~/.omp/agent/` (managed by omp itself — it rewrites `config.yml` in place, so it drifts).

- Edit model catalog and routing intent ONLY here (chezmoi source), never in `~/.omp/agent/`.
- After changing `models.yml`, copy it to `~/.omp/agent/models.yml` (omp does not modify it).
- After changing routing in `config.yml`, patch the live `~/.omp/agent/config.yml` surgically — never overwrite it, it accumulates omp-managed keys (`webSearchOrder`, `retry`, etc.).
- Priority order: **ollama-cloud → google → alibaba-token-plan → openrouter (free) → omniroute**.

## Routing contract (as of 2026-08)

1. **Route first.** Match by skill `description` (omp does this automatically). No skill fits? Answer as generalist.
2. **One skill per domain.** Run each independently, merge at synthesis.
3. **Honor pre-flight checks.** If a skill mandates STOP-and-ask, enforce it.
4. **Shared standards.** All skills inherit `standards/technical_standards.md`.
5. **Honesty over fluency.** Surface "I don't know / Verification Required." Never fabricate.
6. **Producer ≠ verifier.** Never self-certify — route final checks to a fresh context.
7. **Commit on completion.** Follow `standards/technical_standards.md` (§3): detect hooks, match commit format (commitlint → existing pattern → Conventional Commits), stage only task files, never `--no-verify`.

# Conventions

- **Repository workflow:** All development repos use a **bare clone + worktrees** workflow. The bare repo lives at `~/Projects/papanito/<repo>.git` (canonical, never work in it directly). A base dir at `~/Projects/papanito/<repo>/` contains all worktrees — one subdir per branch, named after the branch with `/` replaced by `-` (e.g. `main/`, `feature-seat-planner/`, `papanito-experiment/`). Branch names are always prefixed with `feature/` or `papanito/`. See `standards/technical_standards.md` §3 for the full workflow.

# Work Guidance

- **GitLab CI `script` items must be strings.** When writing `.gitlab-ci.yml` jobs, every `script:` entry MUST be a plain string (or a nested array of strings, max 10 levels deep) — never a YAML mapping/dict. A single quoted item like `- echo "key: value"` parses as a dict unless the whole item is quoted (`- 'echo "key: value"'`). After editing, validate with `python3 -c "import yaml; [print(n, [type(i).__name__ for i in (j.get('script') or []) if not isinstance(i, str)]) for n, j in yaml.safe_load(open('.gitlab-ci.yml')).items() if isinstance(j, dict)]"` — expect no output.
- **MANDATORY: Commit after Speckit implementation.** When `/speckit.implement` (or any Speckit implementation flow) completes successfully, commit the implementation changes immediately — this is a hard requirement, not optional. Do not leave implemented work uncommitted. Commit the whole logical change (spec artifacts, source, tests) with a conventional commit message (see Commit Conventions). If the feature belongs on a feature branch, ensure it is on that branch before committing. If a change is still a work-in-progress or the user explicitly wants to review before committing, say so and hold; otherwise commit right away.

# Branch Conventions

- **Only create new branches when the user explicitly asks for it.** Do not
  create a branch per issue/task on your own initiative — work on the current
  branch unless told otherwise.
- **Always prefix branch names with `papanito/`** (e.g.
  `papanito/032-mobile-drag-drop`). Push with
  `git push -u origin HEAD:papanito/<name>`.
- When the user asks to consolidate multiple branches, combine the work onto a
  single `papanito/`-prefixed branch (keeping per-issue commits separate) and
  remove the superseded branches.

# Push Conventions

- **NEVER push to origin automatically.** Commits stay local until the user
  explicitly asks to push, or the `/do-release-gitlab` command runs (which
  pushes its branch and tag as part of its own documented workflow).
  After committing, report the local state (branch tip, unpushed commits) and
  wait for an explicit push request. This applies to feature branches and the
  default branch alike.

# Commit Conventions

- Always reference the issue in a commit when working on issues: put the issue id at the bottom of the commit message **body**, not in the subject. Example:

  ```
  ci: Add staging deployment pipeline

  Add the GitLab CI pipeline that builds and deploys to staging.

  Closes #11
  ```

- Unless the target repo specifies otherwise, follow conventional commits (type: subject, sentence-case, ≤72 chars subject, always use []§).
- **Scope/topic**: use a short noun-phrase `type[scope]: subject` that matches the feature or branch topic. Choose the scope from the target repo's allowed list (e.g. its commitlint `scope-enum`, if present) rather than inventing a new one; if the repo has no allowed-scope list, derive the scope from the branch/feature name. When adding a feature that introduces a new scope, register it in the repo's scope list first so the commit validates.

# Merge Request Conventions

- **Add appropriate labels when creating an MR** (and when its scope changes). Map the change onto the target project's existing label set — list it with `glab api "projects/<owner>%2F<repo>/labels?per_page=100"`. Typical mapping: `type::feature` / `type::bug` / `type::maintenance` as the primary label, plus a specific one (`feature::addition`, `feature::enhancement`, `bug::functional`, `maintenance::pipelines`, `maintenance::release`, …) where one fits. Never invent labels; if nothing fits, leave labels off and say so rather than creating new ones unasked.
