#!/usr/bin/env bash

# Usage: ./link_resources.sh [tool_name | custom_path]

set -e

# Define source directories
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC_AGENTS="$REPO_ROOT/agents"
SRC_SKILLS="$REPO_ROOT/skills"

# Tool configuration mapping
declare -A TOOLS
TOOLS=(
  ["claude"]="$HOME/.config/Claude"
  ["gemini"]="$HOME/.config/gemini"
  ["copilot"]="$HOME/.config/github-copilot"
  ["pi"]="$HOME/.config/pi"
  ["ohm-my-pi"]="$HOME/.config/ohm-my-pi"
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

  # Create target subdirectories
  mkdir -p "$target_dir/agents" "$target_dir/skills"

  # Symlink agents
  for agent in "$SRC_AGENTS"/*.md; do
    if [ -f "$agent" ]; then
      ln -sf "$agent" "$target_dir/agents/$(basename "$agent")"
      echo "  Linked agent: $(basename "$agent")"
    fi
  done

  # Symlink skills
  for skill in "$SRC_SKILLS"/*.md; do
    if [ -f "$skill" ]; then
      ln -sf "$skill" "$target_dir/skills/$(basename "$skill")"
      echo "  Linked skill: $(basename "$skill")"
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
  # Custom path mode
  link_to_target "$1"
fi
