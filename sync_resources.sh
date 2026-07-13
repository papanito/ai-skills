#!/usr/bin/env bash

#
# Usage: ./sync_resources.sh [tool_name | custom_path] [-c] [-a]
#   -c: Cleanup only - remove links for disabled resources and uninstall disabled plugins
#   -a: All cleanup - remove all links and uninstall all plugins regardless of enabled status
# Usage: ./sync_resources.sh [tool_name | custom_path]
#
# This script synchronizes resources from the local repository to target tool configurations.
# It handles:
#   - Symlinking task agents (agents/*.md files)
#   - Symlinking local skills (skills/*/ folders with SKILL.md)
#   - Symlinking AGENTS.md
#   - Installing external plugins via harness-specific commands
#   - Installing external skills via npx when configured with npx-package
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
#   - Resources: Cloned to external_resources/ with skills/, agents/, plugins/ subfolders
#   - Standalone plugins: Installed via harness-specific commands (never downloaded)
#   - npx-package resources: Installed via `npx <package>` (never cloned or symlinked)

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

# Function to extract resource fields from YAML
# Output: name|source|enabled|npx_package|npx_command|skills|agents|plugins (pipe-separated)
parse_resources() {
  local file="$1"
  yq '.resources[] | .name + "|" + .source + "|" + (.enabled | tostring) + "|" + (.["npx-package"] // "") + "|" + (.["npx-command"] // "") + "|" + ((.skills // []) | join(",")) + "|" + ((.agents // []) | join(",")) + "|" + ((.plugins // []) | join(","))' "$file" | tr -d '"'
}

# Function to extract plugin fields from YAML
# Output: name source enabled (space-separated)
parse_plugins() {
  local file="$1"
  yq '.plugins[] | .name + " " + .source + " " + (.enabled | . | tostring)' "$file" | tr -d '"'
}

# Function to extract local skills from YAML
# Output: enabled|skills (pipe-separated)
parse_local_skills() {
  local file="$1"
  yq '.local | (.enabled | . | tostring) + "|" + ((.skills // []) | join(","))' "$file" | tr -d '"'
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

# Function to report an npx-based skill install command
# Handles both npx-package (direct package) and npx-command (custom command)
install_npx_skills() {
  local name="$1"
  local npx_package="$2"
  local npx_command="$3"
  local tool_name="$4"

  local install_cmd=""

  if [ -n "$npx_command" ]; then
    install_cmd="$npx_command"
    echo "  NPX command install (from $name): $install_cmd"
  elif [ -n "$npx_package" ]; then
    install_cmd="npx $npx_package"
    echo "  NPX package install (from $name): $install_cmd"
  else
    echo "  Skipping NPX install for $name: neither npx-package nor npx-command is set."
    return
  fi

  case "$tool_name" in
  claude|copilot|omp)
    echo "    For $tool_name, run: $install_cmd"
    ;;
  *)
    echo "    Run manually: $install_cmd"
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
  mkdir -p "$target_dir/plugins"

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

  # 3. Clone external resources to external_resources/ directory
  if [ -f "$EXTERNAL_RESOURCES" ]; then
    echo "Cloning external resources..."
    while IFS='|' read -r name source enabled npx_package npx_command skills agents plugins; do
      [ -z "$name" ] && continue
      [ "$enabled" != "true" ] && continue

      # Skip cloning when an npx package OR command is configured; the resource will be installed via npx
      if [ -n "$npx_package" ] || [ -n "$npx_command" ]; then
        echo "  Skipping clone for $name (npx-package: '$npx_package', npx-command: '$npx_command')"
        continue
      fi
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
    done < <(parse_resources "$EXTERNAL_RESOURCES")
  fi

  # 4. Symlink skills and agents, install plugins from external_resources
  if [ -d "$REPO_ROOT/external_resources" ] && [ -f "$EXTERNAL_RESOURCES" ]; then
    while IFS='|' read -r name source enabled npx_package npx_command skills agents plugins; do
      [ -z "$name" ] && continue
      [ "$enabled" != "true" ] && continue

      # When an npx package OR command is configured, skip local symlinking and report install command
      if [ -n "$npx_package" ] || [ -n "$npx_command" ]; then
        if [ -n "$npx_command" ]; then
          install_npx_skills "$name" "" "$npx_command" "$tool_name"
        else
          install_npx_skills "$name" "$npx_package" "" "$tool_name"
        fi
        continue
      fi

      dest="$REPO_ROOT/external_resources/$name"
      [ -d "$dest" ] || continue

      # Process skills — only symlink skills explicitly listed in the YAML
      if [ -n "$skills" ]; then
        IFS=',' read -ra skill_names <<<"$skills"
        for skill_name in "${skill_names[@]}"; do
          [ -z "$skill_name" ] && continue

          # Try multiple path layouts:
          # 1. $dest/skills/$skill_name/SKILL.md (standard layout)
          # 2. $dest/$skill_name/SKILL.md (flat layout — skills at repo root)
          # 3. $dest/SKILL.md (root-level skill — skill name matches repo name)
          # 4. Nested: search for $skill_name/SKILL.md under $dest/skills/*/ (e.g. skills/engineering/ask-matt)
          skill_dest=""
          if [ -f "$dest/skills/$skill_name/SKILL.md" ]; then
            skill_dest="$dest/skills/$skill_name"
          elif [ -f "$dest/$skill_name/SKILL.md" ]; then
            skill_dest="$dest/$skill_name"
          elif [ "$skill_name" = "$name" ] && [ -f "$dest/SKILL.md" ]; then
            skill_dest="$dest"
          else
            # Nested layout: find SKILL.md in $dest/skills/**/$skill_name/
            nested_path=$(find "$dest/skills" -type f -name "SKILL.md" -path "*/$skill_name/SKILL.md" 2>/dev/null | head -1)
            if [ -n "$nested_path" ]; then
              skill_dest=$(dirname "$nested_path")
            fi
          fi

          if [ -n "$skill_dest" ]; then
            ln -sfn "$skill_dest" "$target_dir/skills/$skill_name"
            echo "  Linked skill (from $name): $skill_name"
          fi
        done
      fi

      # Process agents (only if explicitly listed)
      if [ -n "$agents" ]; then
        IFS=',' read -ra agent_names <<<"$agents"
        for agent_name in "${agent_names[@]}"; do
          [ -z "$agent_name" ] && continue
          agent_dest="$dest/agents/$agent_name"

          # Check if agent file exists
          if [ -f "$agent_dest" ]; then
            ln -sfn "$agent_dest" "$target_dir/agents/$agent_name"
            echo "  Linked agent (from $name): $agent_name"
          fi
        done
      fi

      # Process plugins — install via harness-specific commands (never symlinked)
      # Same logic as standalone plugins: pass plugin name as source to install_plugin
      if [ -n "$plugins" ]; then
        IFS=',' read -ra plugin_names <<<"$plugins"
        for plugin_name in "${plugin_names[@]}"; do
          [ -z "$plugin_name" ] && continue
          echo "  Installing plugin (from $name): $plugin_name for harness: ${tool_name:-custom}"
          install_plugin "$plugin_name" "$plugin_name" "$target_dir" "$tool_name"
        done
      fi
    done < <(parse_resources "$EXTERNAL_RESOURCES")
  fi

  # 5. Symlink local skills (only those listed in local: section of YAML)
  if [ -f "$EXTERNAL_RESOURCES" ]; then
    IFS='|' read -r local_enabled local_skills < <(parse_local_skills "$EXTERNAL_RESOURCES")
    if [ "$local_enabled" = "true" ] && [ -n "$local_skills" ]; then
      IFS=',' read -ra skill_names <<<"$local_skills"
      for skill_name in "${skill_names[@]}"; do
        [ -z "$skill_name" ] && continue
        skill_dir="$SRC_SKILLS/$skill_name"

        if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
          ln -sfn "$skill_dir" "$target_dir/skills/$skill_name"
          echo "  Linked skill: $skill_name"
        fi
      done
    fi
  fi

  # 6. Install Standalone Plugins (report install commands only, no download)
  if [ -f "$EXTERNAL_RESOURCES" ]; then
    echo "Processing standalone plugins..."
    while read -r name source enabled; do
      [ -z "$name" ] && continue
      [ "$enabled" != "true" ] && continue
      echo "  Installing plugin: $name (source: $source) for harness: ${tool_name:-custom}"
      install_plugin "$name" "$source" "$target_dir" "$tool_name"
    done < <(parse_plugins "$EXTERNAL_RESOURCES")
  fi

  echo "Successfully synced resources to $target_dir"
}

# Function to cleanup target
cleanup_target() {
  local target_dir="$1"
  local mode="$2"

  if [ ! -d "$target_dir" ]; then
    echo "Warning: Target directory $target_dir does not exist. Skipping."
    return
  fi

  echo "Cleaning up $target_dir (mode: $mode)..."

  # Remove all skills symlinks
  if [ -d "$target_dir/skills" ]; then
    for link in "$target_dir/skills"/*; do
      [ -L "$link" ] || continue
      link_name=$(basename "$link")
      echo "  Removed skill link: $link_name"
      rm "$link"
    done
  fi

  # Handle plugins based on mode
  if [ -f "$EXTERNAL_RESOURCES" ]; then
    echo "Processing plugins..."
    while read -r name source enabled; do
      [ -z "$name" ] && continue

      if [[ "$mode" == "cleanup" ]] && [[ "$enabled" == "true" ]]; then
        # Skip enabled plugins in cleanup mode
        continue
      fi

      # For cleanup-all or disabled plugins, report uninstallation
      echo "  Uninstall plugin: $name"
    done < <(parse_plugins "$EXTERNAL_RESOURCES")
  fi

  echo "  Cleanup complete in $target_dir"
}

# Parse command line arguments
MODE="sync"
TARGET=""
if [[ "${1:-}" == "-c" ]]; then
  MODE="cleanup"
  TARGET="${2:-}"
elif [[ "${1:-}" == "-a" ]]; then
  MODE="cleanup-all"
  TARGET="${2:-}"
elif [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [tool_name | custom_path] [-c] [-a]"
  echo "  -c: Cleanup only - remove links for disabled resources and uninstall disabled plugins"
  echo "  -a: All cleanup - remove all links and uninstall all plugins regardless of enabled status"
  exit 0
else
  TARGET="${1:-}"
fi

# Main logic
if [[ "$MODE" == "cleanup" ]] || [[ "$MODE" == "cleanup-all" ]]; then
  if [ -z "$TARGET" ]; then
    echo "No target specified. Automatically checking known tools..."
    for tool in "${!TOOLS[@]}"; do
      cleanup_target "${TOOLS[$tool]}" "$MODE"
    done
  elif [[ -v TOOLS["$TARGET"] ]]; then
    cleanup_target "${TOOLS[$TARGET]}" "$MODE"
  else
    if [[ ! "$TARGET" = /* && ! "$TARGET" = ./* && ! -d "$TARGET" ]]; then
      echo "Unknown tool '$TARGET'. Treating as custom path. Known tools: ${!TOOLS[*]}"
    fi
    cleanup_target "$TARGET" "$MODE"
  fi
else
  # Original sync logic
  if [ -z "$TARGET" ]; then
    echo "No target specified. Automatically checking known tools..."
    for tool in "${!TOOLS[@]}"; do
      sync_to_target "${TOOLS[$tool]}"
    done
  elif [[ -v TOOLS["$TARGET"] ]]; then
    sync_to_target "${TOOLS[$TARGET]}"
  else
    if [[ ! "$TARGET" = /* && ! "$TARGET" = ./* && ! -d "$TARGET" ]]; then
      echo "Unknown tool '$TARGET'. Treating as custom path. Known tools: ${!TOOLS[*]}"
    fi
    sync_to_target "$TARGET"
  fi
fi
