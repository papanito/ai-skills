#!/usr/bin/env bash

# Usage: ./link_resources.sh [tool_name | custom_path]

set -e

# Define source paths
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC_AGENTS_MD="$REPO_ROOT/agents/AGENTS.md"
SRC_SKILLS="$REPO_ROOT/skills"

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

# Function to link resources
link_to_target() {
  local target_dir="$1"

  if [ ! -d "$target_dir" ]; then
    echo "Warning: Target directory $target_dir does not exist. Skipping."
    return
  fi

  echo "Linking resources to $target_dir..."

  # Create target skills subdirectory
  mkdir -p "$target_dir/skills"

  # Symlink AGENTS.md (single file at target root — omp discovers it there)
  if [ -f "$SRC_AGENTS_MD" ]; then
    ln -sf "$SRC_AGENTS_MD" "$target_dir/AGENTS.md"
    echo "  Linked: AGENTS.md"
  fi

  # Symlink skills (each skill lives in its own subfolder as SKILL.md)
  for skill_dir in "$SRC_SKILLS"/*/; do
    skill_dir="${skill_dir%/}"
    if [ -f "$skill_dir/SKILL.md" ]; then
      name=$(basename "$skill_dir")
      ln -sfn "$skill_dir" "$target_dir/skills/$name"
      echo "  Linked skill: $name"
    fi
  done

  echo "Successfully linked resources to $target_dir"
}

# Main logic
if [ -z "$1" ]; then
  # Automatic detection mode
  echo "No target specified. Automatically checking known tools..."
  for tool in "${!TOOLS[@]}"; do
    link_to_target "${TOOLS[$tool]}"
  done
elif [[ -v TOOLS["$1"] ]]; then
  # Specific tool mode
  link_to_target "${TOOLS[$1]}"
else
  # Custom path mode (also reached if tool name is unknown)
  if [[ ! "$1" = /* && ! "$1" = ./* && ! -d "$1" ]]; then
    echo "Unknown tool '$1'. Treating as custom path. Known tools: ${!TOOLS[*]}"
  fi
  link_to_target "$1"
fi
