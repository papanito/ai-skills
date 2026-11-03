# Working Path Discipline (non-negotiable)

Edit ONLY in version-controlled source — never in symlink targets or runtime dirs:

| Artifact | Edit in | Not in |
| :--- | :--- | :--- |
| Skills, task agents, `AGENTS.md`, `link_resources.sh` | `ai-skills/` repo | `~/<agent dir>/agent/` (symlinks) |
| Dotfiles (nvim, home-manager, omp config) | `~/.local/share/chezmoi/` | `~` (chezmoi target) |

# AI Harness

## Routing contract

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
- **Git inspection:** Prefer RTK-wrapped commands for status, log, and diff (e.g. `rtk git status`, `rtk git log`, `rtk git diff`) over raw Git commands. Use `git` if RTK is unavailable or does not support the command.
