# Working Path Discipline (non-negotiable)

Edit ONLY in version-controlled source — never in symlink targets or runtime dirs:

| Artifact | Edit in | Not in |
| :--- | :--- | :--- |
| Skills, task agents, `AGENTS.md`, `link_resources.sh` | `ai-skills/` repo | `~/<agent dir>/agent/` (symlinks) |
| Dotfiles (nvim, home-manager, omp config) | `~/.local/share/chezmoi/` | `~` (chezmoi target) |

# Routing contract

1. **Route first.** Match by skill `description`. No skill fits? Answer as generalist.
2. **One skill per domain.** Run each independently, merge at synthesis.
3. **Honor pre-flight checks.** If a skill mandates STOP-and-ask, enforce it.
4. **Shared standards.** All skills inherit `standards/technical_standards.md`.
5. **Honesty over fluency.** Surface "I don't know / Verification Required." Never fabricate.
6. **Producer ≠ verifier.** Never self-certify — route final checks to a fresh context.
7. **Commit on completion.** Follow `standards/technical_standards.md` (§3): detect hooks, match commit format (commitlint → existing pattern → Conventional Commits), stage only task files, never `--no-verify`.
8. **GitLab**: Follow `standards/gitlab.md`

# Conventions

- **Repository workflow:** All development repos use a **bare clone + worktrees** workflow. The bare repo lives at `~/Projects/papanito/<repo>.git` (canonical, never work in it directly). A base dir at `~/Projects/papanito/<repo>/` contains all worktrees — one subdir per branch, named after the branch with `/` replaced by `-` (e.g. `main/`, `feature-seat-planner/`, `papanito-experiment/`). Branch names are always prefixed with `feature/` or `papanito/`. See `standards/technical_standards.md` §3 for the full workflow.
- **Design templates (mandatory):** Always use the templates in `~/Projects/wyssmann.com/documents/design/templates` as the basis when starting, building, or restructuring frontend applications (e.g. `app-template` for web applications). Never invent a bespoke layout, styling scheme, or ad-hoc architecture from scratch — adopt the template's structure, shared shell components (`AppHeader`, `PrimaryNavBar`, `ViewBar`, `AppFooter`), Tailwind 4 `@theme` palette, typography rules, and EventCompass styleguide.

# RTK Command Guidance

- Prefer RTK wrappers for supported, high-output commands. RTK documents support for Git, Terraform, GitHub CLI (`gh`), AWS, Docker, Kubernetes, and common test/lint tools. Examples: `rtk git status`, `rtk git log`, `rtk git diff`, `rtk terraform plan`, `rtk gh pr view`, and `rtk kubectl get pods`. See the [official command coverage](https://github.com/rtk-ai/rtk#what-rtk-covers) for the current list.
- RTK's documented coverage does not currently list Azure CLI (`az`), Google Cloud CLI (`gcloud`), or GitLab CLI (`glab`). Use those native commands unless current RTK documentation confirms support; do not assume every CLI has an RTK filter.
- RTK only filters output; it does not make commands safer or authorize changes. Apply the usual review and approval rules to Terraform plans/applies and cloud or GitLab mutations.
- Use the native command if RTK is unavailable or unsupported. Use `rtk bypass <command>` only when full, unfiltered output is needed.
