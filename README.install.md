# install.sh

## Overview

This script installs and synchronizes resources from the local repository to target tool configurations. It handles:

- **Task Agents**: Symlinks `agents/*.md` files to target's `agents/` folder
- **AGENTS.md**: Symlinks `agents/AGENTS.md` to target's root as `AGENTS.md`
- **Local Skills**: Symlinks `skills/*/` subfolders (with `SKILL.md`) listed under `local:` in the config
- **External Skills**: Installs via `npx skills add <owner/repo> -y -g` for resources with `npx-package`
- **Custom Commands**: Executes arbitrary install commands for resources with `command`
- **Disabled Resources**: Prints the command you would need to run manually
- **External Git Repos**: Clones + symlinks resources that have no `npx-package` or `command`
- **Standalone Plugins**: Reports install commands for harnesses that support plugins (no downloads)

## Usage

```bash
./install.sh [tool_name | custom_path] [-c] [-a] [-h]
```

### Examples

```bash
# Sync all enabled resources to all known tools
./install.sh

# Target a specific tool
./install.sh omp

# Target a custom path
./install.sh /path/to/custom/config

# Cleanup: remove links + uninstall disabled npx skills
./install.sh -c

# Cleanup all: remove links + uninstall ALL npx skills
./install.sh -a

# Show help
./install.sh -h
```

## Target Tools

| Tool | Config Path |
| ------ | ------------- |
| `claude` | `~/.config/Claude` |
| `gemini` | `~/.config/gemini` |
| `copilot` | `~/.config/github-copilot` |
| `pi` | `~/.config/pi` |
| `omp` | `~/.omp/agent` |
| `goose` | `~/.config/goose` |

## Config File (`ai-skills-resources.yml`)

The script checks `~/.config/ai-skills-resources.yml` first (override), falling back to the repo's copy.

### `local:` — Local skills from this repo

Skills from the `skills/` folder. Only skills listed here (and `enabled: true`) are symlinked.

```yaml
local:
  enabled: true
  skills:
    - expert-in-swiss-laws
    - lazyvim-expert
```

### `resources:` — External resources

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

**Install priority:** `command` > `npx-package` > clone+symlink

When `npx-package` or `command` is set, the resource is never cloned or symlinked — it's installed via the command.

```yaml
resources:
  - name: improve
    source: https://github.com/shadcn/improve.git
    enabled: true
    npx-package: "shadcn/improve"       # → npx skills add shadcn/improve -y -g
    skills: []
    agents: []

  - name: codegraph
    source: https://github.com/colbymchenry/codegraph.git
    enabled: true
    command: "npx @colbymchenry/codegraph install --yes --no-permissions"
    skills: []
    agents: []

  - name: codeberg-skill
    source: https://codeberg.org/CypherpunkSamurai/codeberg-skill.git
    enabled: false                        # → prints command, does not execute
    npx-package: "CypherpunkSamurai/codeberg-skill"
    skills: []
    agents: []
```

### `plugins:` — Standalone plugins

Plugins are reported with harness-specific install commands but never auto-installed.

```yaml
plugins:
  - name: ponytail
    source: https://github.com/DietrichGebert/ponytail
    enabled: true
```

### Supported Harness Plugin Install Commands

| Harness | Command Format |
| --------- | ---------------- |
| **omp** | `omp install <source>` |
| **pi** | `pi install git:<url>` |
| **claude** | `/plugin marketplace add <repo>` then `/plugin install <name>` |
| **gemini** | `gemini extensions install <url>` |
| **copilot** | `copilot plugin marketplace add <repo>` then `copilot plugin install <name>` |

## Cleanup (`-c` / `-a`)

| Flag | Behavior |
| :--- | :--- |
| `-c` | Remove all symlinks + uninstall **disabled** npx skills via `npx skills remove <name>` |
| `-a` | Remove all symlinks + uninstall **all** npx skills (enabled or not) |

## License

This script follows the project's license.