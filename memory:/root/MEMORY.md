# Repository Restructuring for Reusable AI Agent/Skill Definitions

## Architecture Decision
Centralize agent and skill definitions in a single repo under `agents/` and `skills/` directories. Symlink them into each tool's config directory via `link_resources.sh`. This avoids duplication and keeps definitions tool-agnostic.

## Current Structure (verified 2026-07-02)
```
/
  agents/AGENT.md        # Single traffic-controller agent that routes to skills
  skills/<name>/SKILL.md # Each skill in its OWN subfolder containing SKILL.md
  standards/technical_standards.md
  link_resources.sh
```
- There is ONE agent file (`agents/AGENT.md`) — a skill-orchestration controller with a routing table mapping intents → `skills/<name>/SKILL.md`.
- Skills are NOT flat `.md` files. Each skill lives in `skills/<name>/SKILL.md`.
- The old per-skill `agents/<name>.md` files were duplicates of the skill protocols and have been removed.
- Two skills added from Austin Marchese YouTube screenshots: `loop-orchestration-engineer` (Loop Engineering: 4-Condition Test, Loop Training Mode, separate verifier, run memory) and `spec-driven-initiation-engineer` (Karpathy's Method: real-goal interview, small compartmentalized specs, explicit decision verification, second-AI final check).

## Tool Config Paths (Linux, $HOME-based)
| Tool | Config Directory |
|---|---|
| Claude | `~/.config/Claude` |
| Gemini | `~/.config/gemini` |
| Copilot | `~/.copilot` (not `.config/copilot`) — script uses `~/.config/github-copilot`; verify |
| Pi | `~/.config/pi` |
| Ohm-my-pi | `~/.config/ohm-my-pi` |
| Goose | `~/.config/goose` |
| Codex | `~/.config/codex` |
| Gemini-Antigravity | `~/.config/gemini-antigravity` |
| Cursor | `~/.config/Cursor` (note capital C) |

Within each tool config dir, agents go to `<config>/agents` and skills go to `<config>/skills`.

## link_resources.sh Script Structure
- Uses a bash associative array `TOOLS` mapping tool names to their config dirs.
- `SRC_AGENTS` and `SRC_SKILLS` point to `$REPO_ROOT/agents` and `$REPO_ROOT/skills`.
- `link_to_target()` checks if a target dir exists; skips with a warning if not (graceful degradation).
- Agents: symlinks each `agents/*.md` flat file into `<target>/agents/`.
- Skills: symlinks each `skills/<name>/` SUBFOLDER (not file) into `<target>/skills/<name>` using `ln -sfn` so the subfolder + its `SKILL.md` are visible as a unit.
- Removed stale flat-file skill symlinks before relinking when migrating to the subfolder layout.

## Known Pitfalls
- Stray duplicate closing parentheses after the TOOLS associative array definition caused a bash syntax error. Keep the array definition clean with a single closing paren.
- When migrating from flat skill files to `skills/<name>/SKILL.md` subfolders, stale symlinks in tool config dirs must be cleared first (`rm -rf <config>/skills/*`) or `ln -sfn` may nest symlinks incorrectly.

## Agent/Skill File Pattern (authoritative)
- ONE `agents/AGENT.md` traffic controller with a routing table and execution discipline.
- N skills, each at `skills/<name>/SKILL.md` with frontmatter (`name`, `description`) + protocols + output schema + guardrails.
- Do NOT duplicate skill protocol content into per-skill agent files.

## Key Principles
- Definitions are tool-agnostic; the repo is the single source of truth.
- Tools whose config dirs don't exist yet are silently skipped.
- Symlinks, not copies, ensure a single editing point.
- "Skills are the primary interface. When in doubt, invoke the skill." (from CLAUDE.md pattern shown in Austin Marchese's video)