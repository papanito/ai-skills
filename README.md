# AI Skills Repository

This repository serves as a centralized, tool-agnostic library of AI Agent profiles and Skill protocols.

## Objective

To decouple agent and skill definitions from specific coding tool configurations, allowing them to be easily linked into the local environments used by Claude, Gemini, Copilot, Pi, and others.

## Directory Structure

```text
ai-skills/
├── agents/
│   └── AGENTS.md                              # Systemwide traffic-controller file
├── skills/
│   ├── expert-in-swiss-laws/
│   │   └── SKILL.md
│   ├── github-ghec/
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
├── link_resources.sh                          # Symlinks agents/AGENTS.md and skills/ into each tool's config dir
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

This repo intentionally does **not** place an `AGENTS.md` at its own root. The `agents/AGENTS.md` file here is meant to be linked **systemwide** (into `~/.omp/agent/AGENTS.md` and equivalent paths for other tools), not consumed as a project-level file.

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

## How to Use

Use the `./link_resources.sh` utility to symlink `agents/AGENTS.md` and `skills/` into the configuration directories of your preferred coding tools.

```bash
# Link into all known tools (auto-detect)
./link_resources.sh

# Link into a specific tool
./link_resources.sh ohm-my-pi

# Link into a custom path
./link_resources.sh /path/to/tool/config
```

## Tool Configuration Mapping

| Tool | Description | Agent File Path | Skill Subdirectory Path |
| :--- | :--- | :--- | :--- |
| **Claude (Desktop)** | Anthropic's Claude Desktop | `~/.config/Claude/AGENTS.md` | `~/.config/Claude/skills` |
| **Gemini** | Google Gemini (CLI/SDK) | `~/.config/gemini/AGENTS.md` | `~/.config/gemini/skills` |
| **Copilot** | GitHub Copilot | `~/.config/github-copilot/AGENTS.md` | `~/.config/github-copilot/skills` |
| **Pi** | Inflection Pi integration | `~/.config/pi/AGENTS.md` | `~/.config/pi/skills` |
| **Ohm-my-pi** | Oh-My-Pi harness | `~/.omp/agent/AGENTS.md` | `~/.omp/agent/skills` |
| **Goose** | Block Labs Goose CLI | `~/.config/goose/AGENTS.md` | `~/.config/goose/skills` |
| **Custom Tools** | Generic automation | *&lt;custom_dir&gt;/AGENTS.md* | *&lt;custom_dir&gt;/skills* |

> **Note:** omp discovers `AGENTS.md` as a single file (not in a subdirectory). It also discovers neighbouring harness files: `CLAUDE.md`, Codex `AGENTS.md`, Cursor rules, `.clinerules`, and Copilot instructions. Skills are discovered non-recursively under `skills/`. Run `omp -p '/extensions'` inside a session to see exactly what loaded and from where. See [omp docs](https://omp.sh/docs/context-files) and [omp skills docs](https://omp.sh/docs/skills) for details.
