#!/usr/bin/env bash

#
# install.sh — AI Skills installer
#
# Usage: ./install.sh [tool_name | custom_path] [-c] [-a] [-h]
#   (no args)  Sync all enabled resources to all known tool targets
#   tool_name  Sync to a specific tool (claude, gemini, copilot, pi, omp, goose)
#   path       Sync to a custom path
#   -c         Cleanup: remove links + uninstall disabled npx skills
#   -a         Cleanup all: remove links + uninstall ALL npx skills (enabled or not)
#   -h         Show this help
#
# What it does:
#   1. Symlinks local task agents (agents/*.md) and AGENTS.md into tool config dirs
#   2. Symlinks local skills (skills/*/ with SKILL.md) listed in ai-skills-resources.yml
#   3. For resources with npx-package: runs "npx skills add <package> -y -g" (if not already installed)
#   4. For resources with command: executes the custom command string as-is
#   5. For disabled resources: prints the command you would need to run manually
#   6. Clones + symlinks external git repos that have no npx-package or command
#   7. Reports plugin install commands (harness-specific, never auto-installed)
#
# Config file: ai-skills-resources.yml (repo root, or ~/.config/ override)
#
set -e

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC_AGENTS_MD="$REPO_ROOT/agents/AGENTS.md"
SRC_TASK_AGENTS="$REPO_ROOT/agents"
SRC_SKILLS="$REPO_ROOT/skills"

# Config: prefer ~/.config/ override, fall back to repo copy
if [ -f "$HOME/.config/ai-skills-resources.yml" ]; then
  CONFIG_FILE="$HOME/.config/ai-skills-resources.yml"
else
  CONFIG_FILE="$REPO_ROOT/ai-skills-resources.yml"
fi

# Tool target dirs
declare -A TOOLS
TOOLS=(
  ["claude"]="$HOME/.config/Claude"
  ["gemini"]="$HOME/.config/gemini"
  ["copilot"]="$HOME/.config/github-copilot"
  ["pi"]="$HOME/.config/pi"
  ["omp"]="$HOME/.omp/agent"
  ["goose"]="$HOME/.config/goose"
)

# ── YAML parsing ───────────────────────────────────────────────────────────

# Output per resource: name|source|enabled|npx_package|command|skills|agents|plugins
parse_resources() {
  yq '.resources[] | .name + "|" + .source + "|" + (.enabled | tostring) + "|" + (.["npx-package"] // "") + "|" + (.["command"] // "") + "|" + ((.skills // []) | join(",")) + "|" + ((.agents // []) | join(",")) + "|" + ((.plugins // []) | join(","))' "$CONFIG_FILE" | tr -d '"'
}

parse_plugins() {
  yq '.plugins[] | .name + " " + .source + " " + (.enabled | tostring)' "$CONFIG_FILE" | tr -d '"'
}

parse_local_skills() {
  yq '.local | (.enabled | tostring) + "|" + ((.skills // []) | join(","))' "$CONFIG_FILE" | tr -d '"'
}

# ── Helpers ─────────────────────────────────────────────────────────────────

# Check if a skill package is already installed via `npx skills`
is_npx_skill_installed() {
  local pkg="$1"
  # Extract repo name from owner/repo shorthand (e.g. "shadcn/improve" -> "improve")
  local skill_name="${pkg#*/}"
  # `npx skills list` outputs installed skill names; grep for exact match
  npx skills list 2>/dev/null | grep -qx "$skill_name"
}

# ── Install functions ──────────────────────────────────────────────────────

# Install a resource via npx skills add, or execute a custom command.
# Skips disabled resources (prints the command instead).
install_resource() {
  local name="$1"
  local enabled="$2"
  local npx_package="$3"
  local command_str="$4"

  local install_cmd=""

  # Build the command
  if [ -n "$command_str" ]; then
    install_cmd="$command_str"
  elif [ -n "$npx_package" ]; then
    install_cmd="npx skills add $npx_package -y -g"
  else
    return  # no install method configured
  fi

  # Disabled: print the command, don't execute
  if [ "$enabled" != "true" ]; then
    echo "  [disabled] $name — to install, run:"
    echo "    $install_cmd"
    return
  fi

  # Enabled: check if already installed (only for npx-package, not custom commands)
  if [ -n "$npx_package" ]; then
    if is_npx_skill_installed "$npx_package"; then
      echo "  Already installed: $name"
      return
    fi
  fi

  # Execute
  echo "  Installing: $name"
  echo "    $install_cmd"
  if eval "$install_cmd" 2>&1; then
    echo "  ✓ $name"
  else
    echo "  ✗ $name (exit $?)" >&2
  fi
}

# Uninstall a resource installed via npx skills
uninstall_resource() {
  local name="$1"
  local npx_package="$2"
  local command_str="$3"

  if [ -n "$npx_package" ]; then
    local skill_name="${npx_package#*/}"
    local remove_cmd="npx skills remove $skill_name"
    echo "  Uninstalling: $name"
    echo "    $remove_cmd"
    if eval "$remove_cmd" 2>&1; then
      echo "  ✓ uninstalled $name"
    else
      echo "  ✗ could not uninstall $name (exit $?)" >&2
    fi
  elif [ -n "$command_str" ]; then
    echo "  [manual] $name — uninstall command not known (installed via: $command_str)"
  fi
}

# ── Plugin install (report only) ───────────────────────────────────────────

install_plugin() {
  local name="$1"
  local source="$2"
  local tool_name="$3"

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

  case "$tool_name" in
  pi)
    echo "  Plugin $name: pi install git:$source"
    ;;
  omp)
    echo "  Plugin $name: omp install $source"
    ;;
  claude)
    echo "  Plugin $name: /plugin marketplace add $owner_repo && /plugin install $plugin_name"
    ;;
  copilot)
    echo "  Plugin $name: copilot plugin marketplace add $owner_repo && copilot plugin install $plugin_name"
    ;;
  *)
    echo "  Plugin $name: Skipped (harness '$tool_name' does not support automatic install)"
    ;;
  esac
}

# ── Sync ────────────────────────────────────────────────────────────────────

sync_to_target() {
  local target_dir="$1"
  local tool_name=""

  for name in "${!TOOLS[@]}"; do
    if [[ "${TOOLS[$name]}" == "$target_dir" ]]; then
      tool_name="$name"
      break
    fi
  done

  if [ ! -d "$target_dir" ]; then
    echo "Warning: $target_dir does not exist. Skipping."
    return
  fi

  echo "=== Syncing to $target_dir (tool: ${tool_name:-custom}) ==="

  # Clean broken symlinks
  find "$target_dir" -xtype l -delete 2>/dev/null

  mkdir -p "$target_dir/skills" "$target_dir/agents" "$target_dir/plugins"

  # 1. Symlink task agents
  for agent_file in "$SRC_TASK_AGENTS"/*.md; do
    [ -f "$agent_file" ] || continue
    name=$(basename "$agent_file")
    [ "$name" = "AGENTS.md" ] && continue
    ln -sf "$agent_file" "$target_dir/agents/$name"
    echo "  Linked agent: $name"
  done

  # 2. Symlink AGENTS.md
  if [ -f "$SRC_AGENTS_MD" ]; then
    ln -sf "$SRC_AGENTS_MD" "$target_dir/AGENTS.md"
    echo "  Linked: AGENTS.md"
  fi

  # 3. Process external resources
  if [ -f "$CONFIG_FILE" ]; then
    echo "--- External resources ---"
    while IFS='|' read -r name source enabled npx_package command_str skills agents plugins; do
      [ -z "$name" ] && continue

      # npx-package or command → install (or print if disabled)
      if [ -n "$npx_package" ] || [ -n "$command_str" ]; then
        install_resource "$name" "$enabled" "$npx_package" "$command_str"
        continue
      fi

      # No npx/command → clone + symlink (only if enabled)
      [ "$enabled" != "true" ] && continue
      dest="$REPO_ROOT/external_resources/$name"
      mkdir -p "$REPO_ROOT/external_resources"
      if [ ! -d "$dest" ]; then
        echo "  Cloning $name..."
        git clone --depth 1 "$source" "$dest" 2>/dev/null
      else
        if [ -d "$dest/.git" ]; then
          (cd "$dest" && git pull --ff-only --depth 1 2>/dev/null)
        fi
      fi
      [ -d "$dest" ] || continue

      # Symlink listed skills
      if [ -n "$skills" ]; then
        IFS=',' read -ra skill_names <<<"$skills"
        for skill_name in "${skill_names[@]}"; do
          [ -z "$skill_name" ] && continue
          skill_dest=""
          if [ -f "$dest/skills/$skill_name/SKILL.md" ]; then
            skill_dest="$dest/skills/$skill_name"
          elif [ -f "$dest/$skill_name/SKILL.md" ]; then
            skill_dest="$dest/$skill_name"
          elif [ "$skill_name" = "$name" ] && [ -f "$dest/SKILL.md" ]; then
            skill_dest="$dest"
          else
            nested=$(find "$dest/skills" -type f -name "SKILL.md" -path "*/$skill_name/SKILL.md" 2>/dev/null | head -1)
            [ -n "$nested" ] && skill_dest=$(dirname "$nested")
          fi
          if [ -n "$skill_dest" ]; then
            ln -sfn "$skill_dest" "$target_dir/skills/$skill_name"
            echo "  Linked skill (from $name): $skill_name"
          fi
        done
      fi

      # Symlink listed agents
      if [ -n "$agents" ]; then
        IFS=',' read -ra agent_names <<<"$agents"
        for agent_name in "${agent_names[@]}"; do
          [ -z "$agent_name" ] && continue
          [ -f "$dest/agents/$agent_name" ] && ln -sfn "$dest/agents/$agent_name" "$target_dir/agents/$agent_name" && echo "  Linked agent (from $name): $agent_name"
        done
      fi
    done < <(parse_resources)

    # 4. Symlink local skills
    echo "--- Local skills ---"
    IFS='|' read -r local_enabled local_skills < <(parse_local_skills)
    if [ "$local_enabled" = "true" ] && [ -n "$local_skills" ]; then
      IFS=',' read -ra skill_names <<<"$local_skills"
      for skill_name in "${skill_names[@]}"; do
        [ -z "$skill_name" ] && continue
        skill_dir="$SRC_SKILLS/$skill_name"
        if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
          ln -sfn "$skill_dir" "$target_dir/skills/$skill_name"
          echo "  Linked: $skill_name"
        fi
      done
    fi

    # 5. Plugins (report only)
    echo "--- Plugins ---"
    while read -r pname psource penabled; do
      [ -z "$pname" ] && continue
      [ "$penabled" != "true" ] && continue
      install_plugin "$pname" "$psource" "${tool_name:-custom}"
    done < <(parse_plugins)
  fi

  echo "=== Done: $target_dir ==="
}

# ── Cleanup ─────────────────────────────────────────────────────────────────

cleanup_target() {
  local target_dir="$1"
  local mode="$2"

  [ -d "$target_dir" ] || return

  echo "=== Cleanup $target_dir (mode: $mode) ==="

  # Remove symlinks
  find "$target_dir" -xtype l -delete 2>/dev/null
  for link in "$target_dir/skills"/*; do
    [ -L "$link" ] && rm "$link" && echo "  Removed skill: $(basename "$link")"
  done
  for link in "$target_dir/agents"/*; do
    [ -L "$link" ] && rm "$link" && echo "  Removed agent: $(basename "$link")"
  done
  [ -L "$target_dir/AGENTS.md" ] && rm "$target_dir/AGENTS.md" && echo "  Removed: AGENTS.md"

  # Uninstall npx skills
  if [ -f "$CONFIG_FILE" ]; then
    echo "--- Uninstalling skills ---"
    while IFS='|' read -r name source enabled npx_package command_str skills agents plugins; do
      [ -z "$name" ] && continue
      # -c: skip enabled; -a: uninstall all
      [[ "$mode" == "cleanup" && "$enabled" == "true" ]] && continue
      [ -n "$npx_package" ] || [ -n "$command_str" ] || continue
      uninstall_resource "$name" "$npx_package" "$command_str"
    done < <(parse_resources)
  fi

  echo "=== Cleanup done: $target_dir ==="
}

# ── Main ────────────────────────────────────────────────────────────────────

MODE="sync"
TARGET=""

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [tool_name | custom_path] [-c] [-a] [-h]"
  echo ""
  echo "  (no args)  Sync all enabled resources to all known tool targets"
  echo "  tool_name  Sync to a specific tool: ${!TOOLS[*]}"
  echo "  path       Sync to a custom path"
  echo "  -c         Cleanup: remove links + uninstall disabled npx skills"
  echo "  -a         Cleanup all: remove links + uninstall ALL npx skills"
  echo "  -h         Show this help"
  exit 0
fi

if [[ "${1:-}" == "-c" ]]; then
  MODE="cleanup"; TARGET="${2:-}"
elif [[ "${1:-}" == "-a" ]]; then
  MODE="cleanup-all"; TARGET="${2:-}"
else
  TARGET="${1:-}"
fi

if [[ "$MODE" == "cleanup" || "$MODE" == "cleanup-all" ]]; then
  if [ -z "$TARGET" ]; then
    for tool in "${!TOOLS[@]}"; do
      cleanup_target "${TOOLS[$tool]}" "$MODE"
    done
  elif [[ -v TOOLS["$TARGET"] ]]; then
    cleanup_target "${TOOLS[$TARGET]}" "$MODE"
  else
    cleanup_target "$TARGET" "$MODE"
  fi
else
  if [ -z "$TARGET" ]; then
    for tool in "${!TOOLS[@]}"; do
      sync_to_target "${TOOLS[$tool]}"
    done
  elif [[ -v TOOLS["$TARGET"] ]]; then
    sync_to_target "${TOOLS[$TARGET]}"
  else
    sync_to_target "$TARGET"
  fi
fi