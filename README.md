# AI Skills Repository

This repository serves as a centralized, tool-agnostic library of AI Agent profiles and Skill protocols.

## Objective

To decouple agent and skill definitions from specific coding tool configurations, allowing them to be easily linked into the local environments used by Claude, Gemini, Copilot, Pi, and others.

## Directory Structure

```text
ai-skills/
├── agents/
│   ├── AGENTS.md                              # Systemwide traffic-controller file
│   └── gitlab-repo-management.md              # Task agent (pinned model + skill delegation)
├── skills/
│   ├── expert-in-swiss-laws/
│   │   └── SKILL.md
│   ├── lazyvim-expert/
│   │   └── SKILL.md
│   ├── loop-orchestration-engineer/
│   │   └── SKILL.md
│   ├── nixos-linux-specialist/
│   │   └── SKILL.md
│   ├── packer-imaging-expert/
│   │   └── SKILL.md
│   ├── spec-driven-initiation-engineer/
│   │   └── SKILL.md
│   └── terraform-platform-engineer/
│       └── SKILL.md
├── standards/
│   └── technical_standards.md                 # Shared technical standards
├── catalog.yml                               # Catalog: local items, resources, plugins, profiles
├── .markdownlint-cli2.jsonc                   # Markdown linting config (MD013 disabled)
├── .pre-commit-config.yaml                    # Pre-commit hooks (commitlint, trailing whitespace, etc.)
└── README.md
```

## AGENTS.md — Global vs. Local

`AGENTS.md` is the traffic-controller file that omp injects into the system prompt at session start. It routes incoming requests to the appropriate skill and enforces shared execution discipline.

| Scope | Location | Purpose |
| :--- | :--- | :--- |
| **Global (systemwide)** | `~/.omp/agent/AGENTS.md` | Loaded in every omp session, regardless of which project you're in. This is where the skill-routing controller lives — it's linked from `agents/AGENTS.md` in this repo. |
| **Local (project-level)** | `<repo>/AGENTS.md` | Project-specific notes, conventions, and gotchas. Walked from `cwd` upward to the repo root. omp concatenates global + all ancestor local files (most general first). |

This repo intentionally does **not** place an `AGENTS.md` at its own root. The `agents/AGENTS.md` file here is meant to be linked **systemwide** (into `~/.omp/agent/AGENTS.md` for omp and `~/.config/opencode/AGENTS.md` for OpenCode), not consumed as a project-level file.

You can add a **project-level** `AGENTS.md` to any working repo independently — it will stack on top of the global one. For example:

```text
~/.omp/agent/AGENTS.md     ← global (linked from this repo) — routing table, execution discipline
~/Workspaces/my-app/AGENTS.md  ← project-local — "we use Bun, routes live in src/routes/, don't touch bun.lock"
```

> **Reference:** [omp context-files docs](https://omp.sh/docs/context-files)

## SKILL.md — One per Folder, Many per Workspace

Each skill is a self-contained Markdown playbook in its own subfolder. A workspace can have **multiple skills** — omp discovers all of them non-recursively under the `skills/` directory.

```text
skills/
├── nixos-linux-specialist/
│   └── SKILL.md          ← skill protocol (frontmatter + body)
├── lazyvim-expert/
│   └── SKILL.md
└── ...
```

### SKILL.md frontmatter

| Field | Required | Effect |
| :--- | :--- | :--- |
| `name` | no | Skill identifier; defaults to the directory name. Used for `/skill:<name>` and `skill://<name>`. |
| `description` | yes | The only text the model sees until the skill loads. Use specific verbs + nouns + scope so the model matches it to the right task. |
| `hide` | no | Keep the skill loadable via `skill://<name>` and `/skill:<name>` but omit it from the system prompt listing. |

### Discovery paths

| Scope | Path |
| :--- | :--- |
| **Global** | `~/.omp/agent/skills/<name>/SKILL.md` |
| **Project** | `.omp/skills/<name>/SKILL.md` |

Discovery is **non-recursive** — one skill per directory, directly under `skills/`. Sibling files inside a skill directory are addressable as `skill://<name>/path/to/file.md`.

> **Reference:** [omp skills docs](https://omp.sh/docs/skills)

## Task Agents — Per-Domain Model Assignment

Skills are passive content injected into the current session and run on whatever model that session uses — a `SKILL.md` cannot pin its own model. When a domain benefits from a different model (e.g. Swiss law needs a large-context, low-hallucination model for citation fidelity), wrap the skill in a **task agent**.

A task agent is a Markdown file under `agents/` (e.g. `agents/swiss-law.md`) with frontmatter that pins a `model` and `thinkingLevel`. The agent's system prompt points at `skill://<name>` so the skill remains the single source of knowledge — no duplication. At spawn time the model resolves as: caller `model` arg → agent frontmatter `model` → `modelRoles.task` → session default.

```text
agents/
├── AGENTS.md          ← traffic-controller (linked systemwide)
└── swiss-law.md       ← task agent: pins google/gemini-2.5-pro, loads skill://swiss-legal-expert
```

### Task-agent frontmatter

| Field | Required | Effect |
| :--- | :--- | :--- |
| `name` | yes | Agent identifier used at spawn (`task(agent: "swiss-law")`). |
| `description` | yes | Tells the main agent when to delegate here. |
| `model` | no | Pin a specific `provider/model-id`. Omit to inherit the session default. |
| `thinkingLevel` | no | `minimal` / `low` / `medium` / `high`. |
| `tools` | no | CSV or array of tool names; scope the agent to what it needs. |
| `spawns` | no | `""` = no sub-spawning; `*` = allow any. |

### Discovery path (omp only)

| Scope | Path |
| :--- | :--- |
| **Global (user)** | `~/.omp/agent/agents/<name>.md` |
| **Project** | `.omp/agents/<name>.md` |

`agentdotconf` symlinks each `agents/*.md` (except `AGENTS.md`) into the target agent’s agents directory. Task agents are an omp-specific feature; other tools ignore the `agents/` subdirectory without harm.

> **Reference:** [omp task-agent docs](https://omp.sh/docs/task-agent-discovery)

## Installation with agentdotconf

This repository is the catalog for [agentdotconf](https://gitlab.com/wyssmann/projects/agentdotconf).
`agentdotconf` clones the catalog, selects content by profile or tag, symlinks
local items into each agent, and merges MCP configuration.

### Usage

```bash
# First run
agentdotconf init --repo https://gitlab.com/papanito/ai-skills.git

# Profiles
agentdotconf profiles list
agentdotconf install --profile developer
agentdotconf install --profile platform-engineer

# Ad-hoc tags
agentdotconf install --tag developer

# Update and inspect
agentdotconf sync
agentdotconf status
agentdotconf uninstall --tag developer
```

### What it does

1. Symlinks local skills, agents, commands, prompts and rules into each target agent.
2. Merges MCP definitions into the agent’s JSON/TOML config.
3. Selects content by profile or tag.
4. Runs external `command` / `npx-package` resources only after confirmation.
5. Records links, merged entries and resources in `~/.config/agentdotconf/lock.yaml`.
6. `sync` stashes local catalog changes, pulls, and relinks.

### Supported agents

| Agent | Config root |
| :--- | :--- |
| **Claude Code** | `~/.claude` |
| **Cursor** | `~/.cursor` |
| **Codex** | `~/.codex` / `~/.agents` |
| **GitHub Copilot** | `~/.github` |
| **Gemini CLI** | `~/.gemini` |

See the agentdotconf catalog reference for exact per-kind paths.

## Catalog (`catalog.yml`)

The catalog manifest defines `local`, `resources`, `plugins` and `profiles`:

#### `local:` — Local skills from this repo

Local items from this repository. Only listed items with `enabled: true` are installed.

#### `resources:` — External resources

Each resource can have:

| Field | Description |
| :--- | :--- |
| `name` | Resource identifier |
| `source` | Git repository URL |
| `enabled` | `true` = install/sync; `false` = print command only |
| `npx-package` | GitHub `owner/repo` shorthand. Produces `npx skills add <package> -y -g`. Always uses `-y` (non-interactive) and `-g` (global). |
| `command` | Full custom command string for non-standard installs (e.g. CLI tools like codegraph, graphify). Takes priority over `npx-package`. Executed as-is. |
| `skills` | List of skill folders to symlink from the cloned repo (only for clone-based resources, not npx) |
| `agents` | List of agent files to symlink from the cloned repo |
| `tags` | Tags used by profiles and `--tag` selection |

**Install priority:** `command` > `npx-package` > clone+symlink

When `npx-package` or `command` is set, the resource is never cloned or symlinked — it's installed via the command.

#### `plugins:` — Standalone plugins

Plugins are reported with harness-specific install commands but never auto-installed. Add `tags` so profiles can select them.

### Working Path Discipline

All edits belong in this repo (the version-controlled source), never in the symlink targets. `agentdotconf sync` and `chezmoi apply` propagate from source to runtime — editing a symlink target silently breaks the link or gets overwritten on the next apply. Dotfiles follow the same rule: edit in the chezmoi working directory (`~/.local/share/chezmoi/`), not in `~/.config/` directly.

### Profiles

Profiles are defined in `catalog.yml` as named tag and MCP bundles:

```yaml
profiles:
  developer:
    description: Day-to-day development
    tags: [developer]
  platform-engineer:
    description: Platform and infrastructure work
    tags: [platform-engineer]
    mcp: [gitlab]
```

Use `agentdotconf install --profile developer`. `--tag` remains available for
ad-hoc selections. Unknown MCP ids, missing `extends` targets and inheritance
cycles fail validation.

### Local configuration

`agentdotconf` stores per-machine state at `~/.config/agentdotconf/config.yml`.
This repository is the catalog, not a machine profile. Point agentdotconf at it
with `agentdotconf init --repo ...`, set a default `profile: developer`, and run
`agentdotconf sync` to update.
