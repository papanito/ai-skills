#!/usr/bin/env bash

#
# Usage: ./copy_agents_md.sh [target_path]
#   target_path: Optional path to copy AGENT.md into (must be a git repo)
#   If no target_path given, copies into the current working directory (if a git repo).
#

SOURCE_FILE="AGENTS.md"

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLONE_DIR="$REPO_ROOT/external_resources/agent0ai-dox"
SOURCE_REPO="https://github.com/agent0ai/dox.git"
TARGET_FILE="AGENTS.md"

# Clone or update the source repo
if [ -d "$CLONE_DIR/.git" ]; then
  echo "Updating agent0ai/dox..."
  git -C "$CLONE_DIR" pull --quiet
else
  echo "Cloning agent0ai/dox..."
  rm -rf "$CLONE_DIR"
  git clone --quiet "$SOURCE_REPO" "$CLONE_DIR"
fi

# Verify source file exists
if [ ! -f "$CLONE_DIR/$SOURCE_FILE" ]; then
  echo "Error: $SOURCE_FILE not found in agent0ai/dox"
  exit 1
fi

# Determine target directory
if [ -n "$1" ]; then
  TARGET_DIR="$1"
else
  TARGET_DIR="$(pwd)"
fi

# Check if target is a git repo
if [ ! -d "$TARGET_DIR/.git" ]; then
  echo "Error: $TARGET_DIR is not a git repository (no .git/ found)"
  echo "Usage: ./copy_agents_md.sh [target_path]"
  echo "  target_path must be a git repository"
  exit 1
fi

# Copy the file
echo "Copying $SOURCE_FILE → $TARGET_DIR/$TARGET_FILE"
cp "$CLONE_DIR/$SOURCE_FILE" "$TARGET_DIR/$TARGET_FILE"

echo "Done. Copied $SOURCE_FILE from agent0ai/dox to $TARGET_DIR/$TARGET_FILE"
echo ""
echo "To commit: cd $TARGET_DIR && git add $TARGET_FILE && git commit -m \"chore: Update AGENTS.md from agent0ai/dox\""