# AI Skills Repository

This repository serves as a centralized, tool-agnostic library of AI Agent profiles and Skill protocols.

## Objective

To decouple agent and skill definitions from specific coding tool configurations, allowing them to be easily linked into the local environments used by Claude, Gemini, Copilot, Pi, and others.

## Directory Structure

```text
  AGENTS.md           # Traffic-controller file (omp discovers this at repo root or ~/.omp/agent/)
  skills/             # Each skill in its own subfolder: skills/<name>/SKILL.md
    loop-orchestration-engineer/SKILL.md
    spec-driven-initiation-engineer/SKILL.md
    nixos-linux-specialist/SKILL.md
    lazyvim-expert/SKILL.md
    terraform-platform-engineer/SKILL.md
    packer-imaging-expert/SKILL.md
    github-ghec/SKILL.md
    expert-in-swiss-laws/SKILL.md
  standards/          # Shared technical standards
  link_resources.sh   # Symlinks AGENTS.md and skills/ into each tool's config dir
  README.md
```

## How to Use

Use the `./link_resources.sh` utility to symlink these resources into the configuration directories of your preferred coding tools.

```bash
./link_resources.sh /path/to/tool/configs
```

## Tool Configuration Mapping

To integrate these skills and agent definitions, symlink them to the appropriate directory for your specific tool.

| Tool | Description | Agent File Path | Skill Subdirectory Path |
| :--- | :--- | :--- | :--- |
| **Claude (Desktop)** | Anthropic's Claude Desktop | `~/.config/Claude/AGENTS.md` | `~/.config/Claude/skills` |
| **Gemini** | Google Gemini (CLI/SDK) | `~/.config/gemini/AGENTS.md` | `~/.config/gemini/skills` |
| **Copilot** | GitHub Copilot | `~/.config/github-copilot/AGENTS.md` | `~/.config/github-copilot/skills` |
| **Pi** | Inflection Pi integration | `~/.config/pi/AGENTS.md` | `~/.config/pi/skills` |
| **Ohm-my-pi** | Oh-My-Pi harness | `~/.omp/agent/AGENTS.md` | `~/.omp/agent/skills` |
| **Goose** | Block Labs Goose CLI | `~/.config/goose/AGENTS.md` | `~/.config/goose/skills` |
| **Custom Tools** | Generic automation | *&lt;custom_dir&gt;/AGENTS.md* | *&lt;custom_dir&gt;/skills* |

> **Note:** omp discovers `AGENTS.md` as a single file (not in a subdirectory). It also discovers `CLAUDE.md`, Codex `AGENTS.md`, and Cursor rules as neighbouring harness files. See [omp docs](https://omp.sh/docs/context-files) for details.
