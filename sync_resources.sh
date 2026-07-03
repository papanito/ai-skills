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

# Function to extract name and url as space-separated values from YAML
parse_yaml_section() {
  local section="$1"
  local file="$2"
  yq e ".$section[] | .name + \" \" + .url" "$file" | tr -d '"'
}

fetch_external() {
  local name="$1"
  local url="$2"
  local dest="$3"

  # Handle local paths (starting with /, . or no protocol)
  if [[ "$url" == /* ]] || [[ "$url" == ./* ]] || [[ ! "$url" == *":"* ]]; then
    # Local path - copy instead of clone
    if [ -d "$url" ]; then
      echo "  Copying $name from local path $url..."
      mkdir -p "$(dirname "$dest")"
      rm -rf "$dest" 2>/dev/null || true
      cp -r "$url" "$dest"
    else
      echo "  Warning: Local path $url does not exist. Skipping."
      return 1
    fi
    return 0
  fi

  if [ ! -d "$dest" ]; then
    echo "  Fetching $name from $url..."
    mkdir -p "$(dirname "$dest")"
    if [[ "$url" == *"github.com"* ]] || [[ "$url" == *"codeberg.org"* ]]; then
      git clone --depth 1 "$url" "$dest"
    elif [[ "$url" == *"gitlab.com"* ]] || [[ "$url" == *"bitbucket.org"* ]]; then
      git clone --depth 1 "$url" "$dest"
    elif [[ "$url" == *"npm:"* ]] || [[ "$url" == *"npx:"* ]]; then
      # For pi, handle npm: prefix
      echo "  Warning: NPM-style URLs handled by harness CLI, not cloning."
      return 0
    else
      # Fallback: try git clone, then curl+unzip
      if git ls-remote "$url" >/dev/null 2>&1; then
        git clone --depth 1 "$url" "$dest"
      else
        curl -L "$url" -o "$dest.zip" && unzip -q "$dest.zip" -d "$dest" && rm "$dest.zip"
      fi
    fi
  else
    echo "  $name already exists locally, updating..."
    if [ -d "$dest/.git" ]; then
      cd "$dest" && git pull --depth 1 && cd - > /dev/null
    fi
  fi
}

# Function to install plugin for specific harness
install_plugin() {
  local name="$1"
  local url="$2"
  local target_dir="$3"
  local tool_name="$4"

  # Extract owner/repo from GitHub URL for command convenience
  local owner_repo=""
  if [[ "$url" == *"github.com"* ]]; then
    owner_repo=$(echo "$url" | sed -E 's|https?://github.com/([^/]+/[^/]+).*|\1|' | sed 's|\.git$||')
  elif [[ "$url" == *"gitlab.com"* ]]; then
    owner_repo=$(echo "$url" | sed -E 's|https?://gitlab.com/([^/]+/[^/]+).*|\1|' | sed 's|\.git$||')
  elif [[ "$url" == *"codeberg.org"* ]]; then
    owner_repo=$(echo "$url" | sed -E 's|https?://codeberg.org/([^/]+/[^/]+).*|\1|' | sed 's|\.git$||')
  else
    owner_repo=$(basename "$url" | sed 's|\.git$||')
  fi

  case "$tool_name" in
    pi)
      # pi uses: pi install git:<url>
      echo "  Plugin $name: pi install git:$url"
      ;;
    omp)
      # omp uses: omp plugin install github:user/repo or full git URL
      echo "  Plugin $name: omp plugin install $url"
      ;;
    claude)
      # Claude Code uses marketplace add + plugin install
      echo "  Plugin $name: Run these commands manually in Claude Code:"
      echo "    /plugin marketplace add $owner_repo"
      echo "    /plugin install ${owner_repo#*/}@ponytail"
      ;;
    gemini)
      # gemini uses: gemini extensions install <url>
      echo "  Plugin $name: gemini extensions install $url"
      ;;
    hermes)
      # hermes uses: hermes plugins install OWNER/REPO --enable
      echo "  Plugin $name: hermes plugins install $owner_repo --enable"
      ;;
    codex)
      # codex uses: codex plugin marketplace add OWNER/REPO
      echo "  Plugin $name: codex plugin marketplace add $owner_repo"
      echo "  Then run 'codex' and open /plugins to install."
      ;;
    copilot)
      # Copilot CLI uses: copilot plugin marketplace add OWNER/REPO
      echo "  Plugin $name: copilot plugin marketplace add $owner_repo"
      echo "  copilot plugin install ${owner_repo#*/}@ponytail"
      ;;
    opencode)
      # OpenCode uses: opencode.json plugin array
      echo "  Plugin $name: Add to opencode.json:"
      echo "    { \"plugin\": [\"@dietrichgebert/ponytail\"] }"
      ;;
    *)
      echo "  Plugin $name: Downloaded to $EXTERNAL_DATA_DIR/plugins/$name (harness does not support automatic install)"
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


  # 5. Install External Plugins (report install commands only, no download)
  if [ -f "$EXTERNAL_RESOURCES" ]; then
    echo "Processing external plugins..."
    while read -r name url; do
      [ -z "$name" ] && continue
      install_plugin "$name" "$url" "$target_dir" "$tool_name"
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
