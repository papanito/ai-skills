#!/usr/bin/env bash

# Usage: ./sync_resources.sh [tool_name | custom_path]

set -e

# Define source paths
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC_AGENTS_MD="$REPO_ROOT/agents/AGENTS.md"
SRC_TASK_AGENTS="$REPO_ROOT/agents"
SRC_SKILLS="$REPO_ROOT/skills"
EXTERNAL_RESOURCES="$REPO_ROOT/external_resources.yml"
EXTERNAL_DATA_DIR="$REPO_ROOT/.external_data"

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

# Function to extract name and url as tab-separated values from YAML
parse_yaml_section() {
  local section="$1"
  local file="$2"
  yq e ".$section[].name + \"\t\" + .$section[].url" "$file" | tr -d '"'
}

# Function to fetch external resource
fetch_external() {
  local name="$1"
  local url="$2"
  local dest="$3"

  if [ ! -d "$dest" ]; then
    echo "  Fetching $name from $url..."
    mkdir -p "$(dirname "$dest")"
    if [[ "$url" == *"github.com"* ]] || [[ "$url" == *"codeberg.org"* ]]; then
      git clone --depth 1 "$url" "$dest"
    else
      curl -L "$url" -o "$dest.zip" && unzip -q "$dest.zip" -d "$dest" && rm "$dest.zip"
    fi
  else
    echo "  $name already exists locally, updating..."
    if [ -d "$dest/.git" ]; then
      cd "$dest" && git pull --depth 1 && cd - > /dev/null
    fi
  fi
}

# Function to sync resources
sync_to_target() {
  local target_dir="$1"

  if [ ! -d "$target_dir" ]; then
    echo "Warning: Target directory $target_dir does not exist. Skipping."
    return
  fi

  echo "Syncing resources to $target_dir..."

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

  # 3. Symlink local skills
  for skill_dir in "$SRC_SKILLS"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_dir="${skill_dir%/}"
    if [ -f "$skill_dir/SKILL.md" ]; then
      name=$(basename "$skill_dir")
      ln -sfn "$skill_dir" "$target_dir/skills/$name"
      echo "  Linked skill: $name"
    fi
  done

  # 4. Sync External Skills
  if [ -f "$EXTERNAL_RESOURCES" ]; then
    echo "Processing external skills..."
    while IFS=$'\t' read -r name url; do
      [ -z "$name" ] && continue
      dest="$EXTERNAL_DATA_DIR/skills/$name"
      fetch_external "$name" "$url" "$dest"
      if [ -f "$dest/SKILL.md" ] || [ -d "$dest" ]; then
        ln -sfn "$dest" "$target_dir/skills/$name"
        echo "  Linked external skill: $name"
      fi
    done < <(parse_yaml_section "skills" "$EXTERNAL_RESOURCES")
  fi

  # 5. Sync External Plugins
  if [ -f "$EXTERNAL_RESOURCES" ]; then
    echo "Processing external plugins..."
    while IFS=$'\t' read -r name url; do
      [ -z "$name" ] && continue
      dest="$EXTERNAL_DATA_DIR/plugins/$name"
      fetch_external "$name" "$url" "$dest"
      if [[ "$target_dir" == *".omp/agent" ]]; then
        echo "  Plugin $name downloaded and available for OMP harness."
      fi
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
