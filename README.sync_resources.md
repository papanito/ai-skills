# sync_resources.sh

## Overview

This script synchronizes resources from the local repository to target tool configurations. It handles:

- **Task Agents**: Symlinks `agents/*.md` files to target's `agents/` folder
- **Skills**: Symlinks all `skills/*/` subfolders (with `SKILL.md`) to target's `skills/` folder
- **AGENTS.md**: Symlinks `agents/AGENTS.md` to target's root as `AGENTS.md`
- **External Resources**: Clones enabled resources from `ai-skills-resources.yml`, symlinks their skills/agents, and reports plugin install commands
- **Standalone Plugins**: Reports install commands for harnesses that support plugins (no downloads)

## Usage

```bash
./sync_resources.sh [tool_name | custom_path]
```

### Examples

```bash
# Automatically check all known tools
./sync_resources.sh

# Target a specific tool
./sync_resources.sh omp

# Target a custom path
./sync_resources.sh /path/to/custom/config
```

## Target Tools

| Tool | Config Path |
| ------ | ------------- |
| `pi` | `~/.config/pi` |
| `omp` | `~/.omp/agent` |
| `claude` | `~/.config/Claude` |
| `gemini` | `~/.config/gemini` |
| `copilot` | `~/.config/github-copilot` |
| `goose` | `~/.config/goose` |

## External Resources (`ai-skills-resources.yml`)

This file defines external resources (skills, agents, plugins) and standalone plugins that will be synced into target harnesses.

### Resource Structure

```yaml
resources:
  - name: <resource-name>
    source: <git-url>
    enabled: true|false
    skills:
      - <skill-folder-name>      # optional, omit to auto-link all skills/ subfolders
    agents: []
    plugins:
      - <plugin-folder-name>      # from the resource's plugins/ directory
```

### Standalone Plugins Structure

```yaml
plugins:
  - name: <plugin-name>
    source: <git-url | npm-package | local-path | marketplace>
    enabled: true|false
```

### Skills

Each skill is a directory with `SKILL.md` that gets symlinked to the target's `skills/` folder.

| Field | Description | Example |
| ------- | ------------- | --------- |
| `name` | Resource name (must match directory name) | `anthropic-cybersecurity` |
| `source` | Git repository URL | `https://github.com/user/repo.git` |
| `enabled` | Whether to sync this resource | `true` |
| `skills` | Optional list of skill folder names to link | `[code-review, engineering]` |

### Plugins

Plugins are installed via harness-specific commands (never downloaded locally).

| Source Type | Format | Example | Install Command |
| ------------- | -------- | --------- | ----------------- |
| Git Repository | `github:user/repo` or full URL | `DietrichGebert/ponytail` or `https://github.com/user/repo.git` | `omp install github:user/repo` |
| Local Path | `./path/to/plugin` or `/absolute/path` | `./my-plugin` | `omp install ./my-plugin` |
| NPM Package | `@scope/package` or `package` | `@scope/plugin-foo` | `omp install @scope/plugin-foo` |
| Marketplace Plugin | `name@marketplace` | `code-review@claude-plugins-official` | `omp install code-review@claude-plugins-official` |

### Supported Harness Plugin Install Commands

| Harness | Command Format | Example |
| --------- | ---------------- | --------- |
| **omp** | `omp install <source>` | `omp install github:user/repo` |
| **pi** | `pi install <source>` | `pi install git:https://github.com/user/repo.git` |
| **claude** | Manual: `/plugin marketplace add <repo>` then `/plugin install <name>` | Print instructions |
| **gemini** | `gemini extensions install <url>` | `gemini extensions install <url>` |
| **hermes** | `hermes plugins install <owner/repo> --enable` | `hermes plugins install user/repo --enable` |
| **copilot** | `copilot plugin marketplace add <repo>` then `copilot plugin install <name>` | Print instructions |
| **codex** | `codex plugin marketplace add <repo>` then `/plugins` | Print instructions |
| **opencode** | Add to `opencode.json` | Print instructions |

## License

This script follows the project's license.
