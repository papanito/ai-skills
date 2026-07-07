# AGENTS — Skill Orchestration Controller

Agent orchestration for a multi-discipline engineering, DevOps, and compliance workspace.

## How This Workspace Works

- `skills/` — Self-contained skill protocols (`SKILL.md` with frontmatter + protocols + guardrails). **Skills are the primary interface. When in doubt, invoke the skill.** omp auto-matches tasks against skill `description` fields — no manual routing table needed.
- `agents/AGENTS.md` — This file. Enforces execution discipline and conventions. Linked systemwide (e.g. `~/.omp/agent/AGENTS.md`), not project-level.
- `standards/technical_standards.md` — Cross-cutting standards all skills inherit.

## Working Path Discipline (non-negotiable)

Edit ONLY in version-controlled source — never in symlink targets or runtime dirs:

| Artifact | Edit in | Not in |
| :--- | :--- | :--- |
| Skills, task agents, `AGENTS.md`, `link_resources.sh` | `ai-skills/` repo | `~/.omp/agent/` (symlinks) |
| Dotfiles (nvim, home-manager, omp config) | `~/.local/share/chezmoi/` | `~/.config/` (chezmoi target) |

Editing a symlink target silently breaks it or gets overwritten on next apply. **Always edit the source.**

## Task Agent Pinning

Three skills spawn task agents instead of loading inline. Pin models as follows:

| Skill | Agent | Model |
| :--- | :--- | :--- |
| `loop-orchestration-engineer` | `loop-orchestration` | `openrouter/anthropic/claude-sonnet-4.5` |
| `spec-driven-initiation-engineer` | `spec-driven` | `openrouter/anthropic/claude-sonnet-4.5` |
| `expert-in-swiss-laws` | `swiss-law` | `google/gemini-2.5-pro` |

For light lookups, read the skill directly without spawning.

## Execution Discipline

1. **Route first.** Match by skill `description` (omp does this automatically). No skill fits? Answer as generalist.
2. **One skill per domain.** Run each independently, merge at synthesis.
3. **Honor pre-flight checks.** If a skill mandates STOP-and-ask, enforce it.
4. **Shared standards.** All skills inherit `standards/technical_standards.md`.
5. **Honesty over fluency.** Surface "I don't know / Verification Required." Never fabricate.
6. **Producer ≠ verifier.** Never self-certify — route final checks to a fresh context.
7. **Commit on completion.** Follow `standards/technical_standards.md` (§3): detect hooks, match commit format (commitlint → existing pattern → Conventional Commits), stage only task files, never `--no-verify`.

## Orchestration Modes

- **`spec-driven-initiation-engineer`** — runs *before* execution: real-goal interview, small specs, verified decisions, done-rules.
- **`loop-orchestration-engineer`** — runs *after* a task proves repeatable: 4-Condition Test, Orchestration Skill, Loop Training Mode toggle.

Lifecycle: **spec-driven initiation → manual execution → loop orchestration**.
