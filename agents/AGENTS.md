# AGENTS — Skill Orchestration Controller

Agent orchestration for a multi-discipline engineering, DevOps, and compliance workspace.


## Working Path Discipline (non-negotiable)

Edit ONLY in version-controlled source — never in symlink targets or runtime dirs:

| Artifact | Edit in | Not in |
| :--- | :--- | :--- |
| Skills, task agents, `AGENTS.md`, `link_resources.sh` | `ai-skills/` repo | `~/.omp/agent/` (symlinks) |
| Dotfiles (nvim, home-manager, omp config) | `~/.local/share/chezmoi/` | `~` (chezmoi target) |

Editing a symlink target silently breaks it or gets overwritten on next apply. **Always edit the source.**

## Execution Discipline

1. **Route first.** Match by skill `description` (omp does this automatically). No skill fits? Answer as generalist.
2. **One skill per domain.** Run each independently, merge at synthesis.
3. **Honor pre-flight checks.** If a skill mandates STOP-and-ask, enforce it.
4. **Shared standards.** All skills inherit `standards/technical_standards.md`.
5. **Honesty over fluency.** Surface "I don't know / Verification Required." Never fabricate.
6. **Producer ≠ verifier.** Never self-certify — route final checks to a fresh context.
7. **Commit on completion.** Follow `standards/technical_standards.md` (§3): detect hooks, match commit format (commitlint → existing pattern → Conventional Commits), stage only task files, never `--no-verify`.

## Conventions

- **Repository management:** Repos are managed via Terraform (`gitlab.com/wyssmann/tf-gitlab` → Terraform Cloud). When asked to create or modify a repo, read `agents/gitlab-repo-management.md` for the full workflow and mandatory creation interview.

## Orchestration Modes

- **`spec-driven-initiation-engineer`** — runs *before* execution: real-goal interview, small specs, verified decisions, done-rules.
- **`loop-orchestration-engineer`** — runs *after* a task proves repeatable: 4-Condition Test, Orchestration Skill, Loop Training Mode toggle.

Lifecycle: **spec-driven initiation → manual execution → loop orchestration**.
