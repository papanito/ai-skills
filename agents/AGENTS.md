# Working Path Discipline (non-negotiable)

Edit ONLY in version-controlled source — never in symlink targets or runtime dirs:

| Artifact | Edit in | Not in |
| :--- | :--- | :--- |
| Skills, task agents, `AGENTS.md`, `link_resources.sh` | `ai-skills/` repo | `~/<agent dir>/agent/` (symlinks) |
| Dotfiles (nvim, home-manager, omp config) | `~/.local/share/chezmoi/` | `~` (chezmoi target) |

# Branches (non-negotiable)

- **Create a branch only when the user asks for one.** Never cut a branch because you judge the work "needs" isolation — keep working on the branch you were given, even when it already carries unrelated commits.
- **In doubt, ask.** If you think a new branch is warranted (unrelated change, risky work, mixed concerns), stop and ask the user where the work should live. The decision is theirs, never yours.
- **This also covers worktrees**, since a worktree always implies a branch. Only create one when the user asks for it.

# Pushing (non-negotiable)

- **Never push unless the user asks.** Commit locally and report the branch tip plus unpushed commits; the push is a separate, explicit instruction. Feature branches, default branches, tags, and release branches are all the same.
- **Every push is a one-time authorization.** A previous "push it", an earlier push of the same branch, or the fact that a workflow "normally pushes" never covers the next one. No standing push permission exists — ask again for each push.
- **This covers remote mutation of every kind:** `git push`, `--tags`, `--force-with-lease`, `--delete`, and the equivalent `glab`/`gh`/API calls.

# Repository Push Policy (non-negotiable)

Where `main` is writable depends on the forge group, not on the size of the change:

| Repository | `main` | How work lands |
| :--- | :--- | :--- |
| personal — `papanito/*` and `playground/*` on gitlab.com and github.com | direct push allowed | small fixes commit straight to `main`; large changes (new feature, refactor, several commits, a release) get a `papanito/<topic>` branch and a merge request |
| shared — `wyssmann/*` and its subgroups (`terraform`, `ansible`, `kubernetes`, `jenkins`, `documents`, `projects`, `infrastructure`) | protected | always a `papanito/<topic>` branch plus a merge request; never push to `main`, never force-push it |
| `wyssmann/infrastructure/tf-gitlab` (local checkout `tf-scm`) | direct push allowed | the single shared-repo exception: it defines the rules that protect the others, so it must stay directly writable |

- **The forge enforces this.** A direct push to a protected `main` is rejected — do not route around it with a force push, the API, or by removing the protection.
- **A branch on a shared repository is mandatory, not agent initiative.** Creating `papanito/<topic>` there follows the rule; the *Branches* rule above only forbids branches nobody asked for.
- **Fast-forward only.** GitLab uses `merge_method = ff`, GitHub allows rebase merges only. Never enable merge commits or squash merges.
- **Label every MR/PR you open** with at least `release` or `maintenance::release`.

# Merge Requests (non-negotiable)

- **Never open an MR/PR of your own initiative.** Finishing a task means the work is committed and pushed on its branch — not that an MR exists. Create an MR/PR only when the user explicitly asks for one.
- **Never merge an MR/PR — not even when the user asks you to.** The merge is the user's action, always. On such a request, stop at the handover: report the MR/PR URL and its pipeline/review state, and say plainly that merging is the user's step. Never run `glab mr merge`, `gh pr merge`, the forge API, or the web UI for it.
- **Never approve, enable auto-merge, or set merge-when-pipeline-succeeds**, and never push straight to a protected/default branch to route around a merge.
- **Release MRs are no exception.** A release ends at the pushed tag, the published Release, and — only if explicitly requested — the MR/PR. It never ends with a merge.

# Commit Scopes (non-negotiable)

- **Scopes use square brackets — never parentheses.** Write `feat[zsh]: Add completions`, **never** `feat(zsh): Add completions`. This applies to every repo, every type, and every commit you write.
- **Parenthesised scopes are always an error.** The shared commitlint preset (`papanito/git-hooks`) parses the header as `type[scope]: subject`; `type(scope): subject` fails the `commit-msg` hook. Do not "fix" that by dropping the hook — fix the message.
- **No scope is fine; the wrong bracket is not.** Follow the project's `.commitlintrc*` for whether a scope is mandatory (`feat`/`fix` often are). If a scope is present, it is `[...]`.

# Routing contract

1. **Route first.** Match by skill `description`. No skill fits? Answer as generalist.
2. **One skill per domain.** Run each independently, merge at synthesis.
3. **Honor pre-flight checks.** If a skill mandates STOP-and-ask, enforce it.
4. **Shared standards.** All skills inherit `standards/technical_standards.md`. Repositories live under the global directory layout in `standards/directory-hierarchy.md` (forges & organizations under `~/Projects/`) — resolve repo paths and worktree roots (`wt/`, worktrunk) against that hierarchy.
5. **Honesty over fluency.** Surface "I don't know / Verification Required." Never fabricate.
6. **Producer ≠ verifier.** Never self-certify — route final checks to a fresh context.
7. **Commit on completion.** Follow `standards/technical_standards.md` (§3): detect hooks, match commit format (commitlint → existing pattern → Conventional Commits), stage only task files, never `--no-verify`. **Scopes are square-bracketed (`type[scope]: subject`), never parenthesised** — see *Commit Scopes* above. Work ends with the commit **on the branch you were given** — never cut a branch of your own, never push unasked (one push per explicit request), MR/PR creation happens only on explicit request, and merging is never yours (see *Branches*, *Pushing* and *Merge Requests*).
8. **GitLab**: Follow `standards/gitlab.md`

# Conventions

- **Repository workflow:** All development repos use a **bare clone + worktrees** workflow. The bare repo lives at `~/Projects/papanito/<repo>.git` (canonical, never work in it directly). A base dir at `~/Projects/papanito/<repo>/` contains all worktrees — one subdir per branch, named after the branch with `/` replaced by `-` (e.g. `main/`, `feature-seat-planner/`, `papanito-experiment/`). Branch names are always prefixed with `feature/` or `papanito/`. See `standards/technical_standards.md` §3 for the full workflow.
- **GitLab CI runners:** Linux jobs always run on the homelab runner (`tags: [homelab]`); never leave them untagged or send them to `saas-linux-*`. Windows/macOS-only jobs keep their hosted platform tag. See `standards/gitlab.md` (CI Pipeline).
- **Design templates (mandatory):** Always use the templates in `~/Projects/wyssmann.com/documents/design/templates` as the basis when starting, building, or restructuring frontend applications (e.g. `app-template` for web applications). Never invent a bespoke layout, styling scheme, or ad-hoc architecture from scratch — adopt the template's structure, shared shell components (`AppHeader`, `PrimaryNavBar`, `ViewBar`, `AppFooter`), Tailwind 4 `@theme` palette, typography rules, and EventCompass styleguide.
- **Cross-repo spec work (shared design-system package):** Specs, plans and tasks for behaviour that lives in the shared `@wyssmann/design-system` package are written in the consuming repo's `.specify/` (e.g. `eventgenie`), but the implementation happens in `~/Projects/wyssmann.com/design-system` per that repo's `AGENTS.md` — including its own tests, which own the behaviour. The app consumes a package *release* (tag-driven CHANGELOG, GitLab group npm registry). **The dependency bump is pipeline-only:** the range in `package.json` is edited locally as a text change (no credential), while registry resolution (`npm install` with the group `NPM_TOKEN`) runs inside the repo's manual `lockfile` CI job; its `package-lock.json` artifact is downloaded and committed. Never run a registry install or resolve a lockfile on a workstation. When a cite in an issue/spec predates an element's move into the package, verify the current source there first.
