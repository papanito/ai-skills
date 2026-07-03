#!/usr/bin/env bash

# Usage: ./sync_resources.sh [tool_name | custom_path]
#
# This script synchronizes resources from the local repository to target tool configurations.
# It handles:
#   - Symlinking task agents (agents/*.md files)
#   - Symlinking local skills (skills/*/ folders with SKILL.md)
#   - Symlinking AGENTS.md
#   - Installing external plugins via harness-specific commands
#
# Target Tools:
#   - pi: ~/.config/pi
#   - omp: ~/.omp/agent
#   - claude: ~/.config/Claude
#   - gemini: ~/.config/gemini
#   - copilot: ~/.config/github-copilot
#   - goose: ~/.config/goose
#
# External Resources (from ai-skills-resources.yml):
#   - Skills: Cloned to external_resources/ and symlinked to target's skills/ directory
#   - Plugins: Installed via harness-specific commands (never downloaded)

set -e

# Define source paths
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC_AGENTS_MD="$REPO_ROOT/agents/AGENTS.md"
SRC_TASK_AGENTS="$REPO_ROOT/agents"
SRC_SKILLS="$REPO_ROOT/skills"

# External resources config - check ~/.config/ first for override
if [ -f "$HOME/.config/ai-skills-resources.yml" ]; then
  EXTERNAL_RESOURCES="$HOME/.config/ai-skills-resources.yml"
  echo "Using ai-skills-resources.yml from ~/.config/"
else
  EXTERNAL_RESOURCES="$REPO_ROOT/ai-skills-resources.yml"
fi

# Tool configuration mapping
declare -A TOOLS
TOOLS=(
  ["claude"]="$HOME/.config/Claude"
  ["gemini"]="$HOME/.config/gemini"
  ["copilot"]="$HOME/.config/github-copilot"
  ["pi"]="$HOME/.config/pi"
  ["omp"]="$HOME/.omp/agent"
  ["goose"]="$HOME/.config/goose"
)

# Function to extract name, source, and enabled as tab-separated values from YAML
parse_yaml_section() {
  local section="$1"
  local file="$2"
  yq ".$section[] | .name + \" \" + .source" "$file" | tr -d '"'
}

# Function to install plugin for specific harness
install_plugin() {
  local name="$1"
  local source="$2"
  local target_dir="$3"
  local tool_name="$4"

  # Extract owner/repo from Git URLs
  local owner_repo=""
  if [[ "$source" == *"github.com"* ]]; then
    owner_repo=$(echo "$source" | sed -E 's|https?://github.com/([^/]+/[^/]+).*|\1|' | sed 's|\.git$||')
  elif [[ "$source" == *"gitlab.com"* ]]; then
    owner_repo=$(echo "$source" | sed -E 's|https?://gitlab.com/([^/]+/[^/]+).*|\1|' | sed 's|\.git$||')
  elif [[ "$source" == *"codeberg.org"* ]]; then
    owner_repo=$(echo "$source" | sed -E 's|https?://codeberg.org/([^/]+/[^/]+).*|\1|' | sed 's|\.git$||')
  else
    owner_repo="$source"
  fi

  local plugin_name="${owner_repo#*/}"

  # Execute install command based on harness
  case "$tool_name" in
  pi)
    if [[ "$source" == *"github.com"* ]] || [[ "$source" == *"gitlab.com"* ]] || [[ "$source" == *"codeberg.org"* ]]; then
      echo "  Plugin $name: pi install git:$source"
    else
      echo "  Plugin $name: pi install $source"
    fi
    ;;
  omp)
    echo "  Plugin $name: omp install $source"
    ;;
  claude)
    echo "  Plugin $name: Run in Claude Code:"
    echo "    /plugin marketplace add $owner_repo"
    echo "    /plugin install $plugin_name"
    ;;
  gemini)
    echo "  Plugin $name: gemini extensions install $source"
    ;;
  hermes)
    echo "  Plugin $name: hermes plugins install $owner_repo --enable"
    ;;
  codex)
    echo "  Plugin $name: Run: codex plugin marketplace add $owner_repo"
    echo "  Then run 'codex' and open /plugins to install."
    ;;
  copilot)
    if [[ "$source" == *"github.com"* ]]; then
      echo "  Plugin $name: copilot plugin marketplace add $owner_repo"
      echo "  copilot plugin install $plugin_name"
    else
      echo "  Plugin $name: copilot plugin install $source"
    fi
    ;;
  opencode)
    echo "  Plugin $name: Add to opencode.json:"
    echo "    { \"plugin\": [\"@$owner_repo\"] }"
    ;;
  *)
    echo "  Plugin $name: Skipped (harness $tool_name does not support automatic install)"
    ;;
  esac
}

# Function to sync resources
sync_to_target() {
  local target_dir="$1"

  # Determine tool name from target_dir
  local tool_name=""
  for name in "${!TOOLS[@]}"; do
    if [[ "${TOOLS[$name]}" == "$target_dir" ]]; then
      tool_name="$name"
      break
    fi
  done

  if [ ! -d "$target_dir" ]; then
    echo "Warning: Target directory $target_dir does not exist. Skipping."
    return
  fi

  echo "Syncing resources to $target_dir (tool: ${tool_name:-custom})..."

  # Remove broken symlinks to ensure clean re-linking
  find "$target_dir" -xtype l -delete

  # Create target subdirectories
  mkdir -p "$target_dir/skills"
  mkdir -p "$target_dir/agents"

  # 1. Symlink local task-agent definitions
  for agent_file in "$SRC_TASK_AGENTS"/*.md; do
    [ -f "$agent_file" ] || continue
    name=$(basename "$agent_file")
    [ "$name" = "AGENTS.md" ] && continue
    ln -sf "$agent_file" "$target_dir/agents/$name"
    echo "  Linked task agent: $name"
  done

  # 2. Symlink AGENTS.md
  if [ -f "$SRC_AGENTS_MD" ]; then
    ln -sf "$SRC_AGENTS_MD" "$target_dir/AGENTS.md"
    echo "  Linked: AGENTS.md"
  fi

  # 3. Clone external skills to external_resources/ directory
  if [ -f "$EXTERNAL_RESOURCES" ]; then
    echo "Cloning external skills..."
    while IFS=$'\t' read -r name source enabled; do
      [ -z "$name" ] && continue
      [ "$enabled" != "true" ] && continue
      dest="$REPO_ROOT/external_resources/$name"
      mkdir -p "$REPO_ROOT/external_resources"
      # Check if already cloned
      if [ ! -d "$dest" ]; then
        echo "  Fetching $name from $source..."
        if [[ "$source" == *"github.com"* ]] || [[ "$source" == *"gitlab.com"* ]] || [[ "$source" == *"codeberg.org"* ]]; then
          git clone --depth 1 "$source" "$dest"
        else
          echo "  Warning: Source type not supported for cloning: $source"
        fi
      else
        echo "  $name already exists locally, updating..."
        if [ -d "$dest/.git" ]; then
          cd "$dest" && git pull --depth 1 && cd - >/dev/null
        fi
      fi
    done < <(parse_yaml_section "skills" "$EXTERNAL_RESOURCES")
  fi

  # 4. Symlink all skills subfolders
  # First, symlink local skills (skills in repo root with SKILL.md at root level)
  for skill_dir in "$SRC_SKILLS"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_dir="${skill_dir%/}"

    # Check if SKILL.md exists at root level (local skills)
    if [ -f "$skill_dir/SKILL.md" ]; then
      name=$(basename "$skill_dir")
      ln -sfn "$skill_dir" "$target_dir/skills/$name"
      echo "  Linked skill: $name"
    fi
  done

  # Then, handle external skills repos from external_resources/ that have skills/ subfolders
  EXTERNAL_SKILLS_DIR="$REPO_ROOT/external_resources"
  if [ -d "$EXTERNAL_SKILLS_DIR" ]; then
    for skill_dir in "$EXTERNAL_SKILLS_DIR"/*/; do
      [ -d "$skill_dir" ] || continue
      skill_dir="${skill_dir%/}"

      # Check if this is an external skill repo with skills/ subfolder
      if [ -d "$skill_dir/skills" ] && [ "$(find "$skill_dir/skills" -maxdepth 1 -type d | wc -l)" -gt 1 ]; then
        # Iterate through skills subfolder
        for sub_skill_dir in "$skill_dir/skills"/*/; do
          [ -d "$sub_skill_dir" ] || continue
          sub_skill_dir="${sub_skill_dir%/}"

          # Check if SKILL.md exists in subfolder
          if [ -f "$sub_skill_dir/SKILL.md" ]; then
            sub_name=$(basename "$sub_skill_dir")
            ln -sfn "$sub_skill_dir" "$target_dir/skills/$sub_name"
            echo "  Linked skill (from $skill_dir): $sub_name"
          fi
        done
      fi
    done
  fi

  # 5. Install External Plugins (report install commands only, no download)
  if [ -f "$EXTERNAL_RESOURCES" ]; then
    echo "Processing external plugins..."
    while IFS=$'\t' read -r name source enabled; do
      [ -z "$name" ] && continue
      [ "$enabled" != "true" ] && continue
      echo "  Installing plugin: $name (source: $source) for harness: ${tool_name:-custom}"
      install_plugin "$name" "$source" "$target_dir" "$tool_name"
    done < <(parse_yaml_section "plugins" "$EXTERNAL_RESOURCES")
  fi

  echo "Successfully synced resources to $target_dir"
}

# Main logic
if [ -z "$1" ]; then
  echo "No target specified. Automatically checking known tools..."
  for tool in "${!TOOLS[@]}"; do
    sync_to_target "${TOOLS[$tool]}"
  done
elif [[ -v TOOLS["$1"] ]]; then
  sync_to_target "${TOOLS[$1]}"
else
  if [[ ! "$1" = /* && ! "$1" = ./* && ! -d "$1" ]]; then
    echo "Unknown tool '$1'. Treating as custom path. Known tools: ${!TOOLS[*]}"
  fi
  sync_to_target "$1"
fi
