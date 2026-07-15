#!/usr/bin/env bash
set -euo pipefail

# ─── install.sh — AI Skills Resource Installer ────────────────────────────────
# Installs and synchronizes resources from this repo to target tool configs.
#
# Usage:
#   ./install.sh                # Sync all enabled resources to all known tools
#   ./install.sh omp            # Sync to a specific tool
#   ./install.sh /path/to/dir  # Sync to a custom path
#   ./install.sh -c            # Cleanup: remove links + uninstall npx skills
#   ./install.sh -a            # Cleanup all: remove links + uninstall ALL npx skills
#   ./install.sh -h            # Show help

# ─── Config ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_CONFIG="${SCRIPT_DIR}/ai-skills-resources.yml"
USER_CONFIG="${HOME}/.config/ai-skills-resources.yml"

# Prefer user override, fall back to repo copy
CONFIG_FILE="${USER_CONFIG}"
if [ ! -f "${CONFIG_FILE}" ]; then
  CONFIG_FILE="${REPO_CONFIG}"
fi

# Known tool config directories
declare -A TOOL_DIRS=(
  [claude]="${HOME}/.config/Claude"
  [gemini]="${HOME}/.config/gemini"
  [copilot]="${HOME}/.config/github-copilot"
  [pi]="${HOME}/.config/pi"
  [omp]="${HOME}/.omp/agent"
  [goose]="${HOME}/.config/goose"
)

# ─── Helpers ───────────────────────────────────────────────────────────────────

_usage() {
  cat <<'EOF'
Usage: install.sh [tool_name | custom_path] [-c] [-a] [-h]

Options:
  -c    Cleanup: remove links + uninstall disabled npx skills
  -a    Cleanup all: remove links + uninstall ALL npx skills
  -h    Show this help message

Tools: claude, gemini, copilot, pi, omp, goose
EOF
}

_log() { echo "[install] $*"; }
_skip() { echo "[skip] $*"; }

# ─── YAML Parsing (yq required) ───────────────────────────────────────────────

_require_yq() {
  if ! command -v yq &>/dev/null; then
    echo "ERROR: yq is required (https://github.com/mikefarah/yq)" >&2
    exit 1
  fi
}

_get_local_enabled() { yq '.local.enabled // false' "${CONFIG_FILE}"; }
_get_local_skills()  { yq '.local.skills[]' "${CONFIG_FILE}"; }
_get_resource_count() { yq '.resources | length' "${CONFIG_FILE}"; }
_get_plugin_count()   { yq '.plugins | length' "${CONFIG_FILE}"; }

_get_resource_field() {
  local idx="$1" field="$2"
  yq ".resources[${idx}].${field}" "${CONFIG_FILE}"
}

_get_plugin_field() {
  local idx="$1" field="$2"
  yq ".plugins[${idx}].${field}" "${CONFIG_FILE}"
}

# ─── Already-Installed Check ───────────────────────────────────────────────────

_is_npx_skill_installed() {
  local npx_package="$1"
  local skill_name
  skill_name="$(basename "${npx_package}")"
  # Check common install locations
  for dir in \
    "${HOME}/.claude/skills/${skill_name}" \
    "${HOME}/.config/Claude/skills/${skill_name}" \
    "${HOME}/.omp/agent/skills/${skill_name}" \
    "${HOME}/config/gemini/skills/${skill_name}" \
    "${HOME}/.config/github-copilot/skills/${skill_name}" \
    "${HOME}/.config/pi/skills/${skill_name}" \
    "${HOME}/.config/goose/skills/${skill_name}"; do
    [ -d "${dir}" ] && return 0
  done
  return 1
}

_is_command_skill_installed() {
  # For command-type resources, we can't reliably detect installation,
  # so we always run the command. The command itself should be idempotent.
  return 1
}

# ─── Symlink Helper ───────────────────────────────────────────────────────────

_link() {
  local src="$1" dst="$2"
  if [ -L "${dst}" ]; then
    local current
    current="$(readlink "${dst}")"
    [ "${current}" = "${src}" ] && return 0
    rm "${dst}"
  elif [ -e "${dst}" ]; then
    _skip "Exists (not a symlink): ${dst}"
    return 0
  fi
  ln -s "${src}" "${dst}"
  _log "Linked: ${dst} → ${src}"
}

# ─── Process a Single Resource ─────────────────────────────────────────────────

process_resource() {
  local idx="$1"
  local target_dir="$2"

  local res_name     res_source  res_enabled  res_npx_package  res_command
  local res_skills   res_agents

  res_name="$(_get_resource_field "${idx}" 'name')"
  res_source="$(_get_resource_field "${idx}" 'source')"
  res_enabled="$(_get_resource_field "${idx}" 'enabled')"
  res_npx_package="$(_get_resource_field "${idx}" 'npx-package')"
  res_command="$(_get_resource_field "${idx}" 'command')"
  res_skills="$(_get_resource_field "${idx}" 'skills[]' 2>/dev/null || true)"
  res_agents="$(_get_resource_field "${idx}" 'agents[]'  2>/dev/null || true)"

  # ── command: full custom install command (highest priority) ──
  if [ -n "${res_command}" ]; then
    if [ "${res_enabled}" = "false" ]; then
      echo "[DISABLED] Would run: ${res_command}"
      return 0
    fi
    if _is_command_skill_installed "${res_name}"; then
      _skip "${res_name}: already installed (command type, running anyway for idempotency)"
    fi
    echo "[command] ${res_name}: ${res_command}"
    eval "${res_command}"
    return $?
  fi

  # ── npx-package: npx skills add <owner/repo> -y -g ──
  if [ -n "${res_npx_package}" ]; then
    if [ "${res_enabled}" = "false" ]; then
      echo "[DISABLED] Would run: npx skills add ${res_npx_package} -y -g"
      return 0
    fi
    if _is_npx_skill_installed "${res_npx_package}"; then
      _skip "${res_name}: already installed (${res_npx_package})"
      return 0
    fi
    echo "[npx] ${res_name}: npx skills add ${res_npx_package} -y -g"
    npx skills add "${res_npx_package}" -y -g
    return $?
  fi

  # ── clone + symlink (fallback for resources without command or npx-package) ──
  if [ "${res_enabled}" = "false" ]; then
    echo "[DISABLED] ${res_name}: skipped (clone-based)"
    return 0
  fi

  local clone_dir="${SCRIPT_DIR}/.agents/${res_name}"

  if [ ! -d "${clone_dir}" ]; then
    _log "Cloning ${res_name} from ${res_source}..."
    git clone --depth 1 "${res_source}" "${clone_dir}"
  else
    _log "Updating ${res_name}..."
    git -C "${clone_dir}" pull --ff-only || true
  fi

  # Symlink skills
  if [ -n "${res_skills}" ]; then
    local skill_name
    for skill_name in ${res_skills}; do
      local skill_src="${clone_dir}/${skill_name}"
      if [ -d "${skill_src}" ]; then
        mkdir -p "${target_dir}/skills"
        _link "${skill_src}" "${target_dir}/skills/${skill_name}"
      else
        _skip "Skill dir not found: ${skill_src}"
      fi
    done
  fi

  # Symlink agents
  if [ -n "${res_agents}" ]; then
    local agent_file
    for agent_file in ${res_agents}; do
      local agent_src="${clone_dir}/${agent_file}"
      if [ -f "${agent_src}" ]; then
        mkdir -p "${target_dir}/agents"
        _link "${agent_src}" "${target_dir}/agents/$(basename "${agent_file}")"
      else
        _skip "Agent file not found: ${agent_src}"
      fi
    done
  fi
}

# ─── Process Local Skills ─────────────────────────────────────────────────────

process_local_skills() {
  local target_dir="$1"

  if [ "$(_get_local_enabled)" != "true" ]; then
    _skip "Local skills disabled in config"
    return 0
  fi

  local skill_name
  while IFS= read -r skill_name; do
    [ -z "${skill_name}" ] && continue
    local skill_src="${SCRIPT_DIR}/skills/${skill_name}"
    if [ -d "${skill_src}" ]; then
      mkdir -p "${target_dir}/skills"
      _link "${skill_src}" "${target_dir}/skills/${skill_name}"
    else
      _skip "Local skill not found: ${skill_src}"
    fi
  done < <(_get_local_skills)
}

# ─── Sync to Target ───────────────────────────────────────────────────────────

sync_to_target() {
  local target_dir="$1"
  mkdir -p "${target_dir}"

  _log "Syncing to ${target_dir}"

  # 1) Local skills
  process_local_skills "${target_dir}"

  # 2) Task agents
  local agents_src="${SCRIPT_DIR}/agents"
  if [ -d "${agents_src}" ]; then
    mkdir -p "${target_dir}/agents"
    for agent_file in "${agents_src}"/*.md; do
      [ -f "${agent_file}" ] || continue
      local basename
      basename="$(basename "${agent_file}")"
      [ "${basename}" = "AGENTS.md" ] && continue   # handled separately below
      _link "${agent_file}" "${target_dir}/agents/${basename}"
    done
  fi

  # 3) AGENTS.md
  if [ -f "${agents_src}/AGENTS.md" ]; then
    _link "${agents_src}/AGENTS.md" "${target_dir}/AGENTS.md"
  fi

  # 4) External resources
  local count
  count="$(_get_resource_count)"
  local i
  for (( i = 0; i < count; i++ )); do
    process_resource "${i}" "${target_dir}"
  done

  # 5) Report plugin install commands (never auto-installed)
  local plugin_count
  plugin_count="$(_get_plugin_count)"
  for (( i = 0; i < plugin_count; i++ )); do
    local p_name p_source p_enabled
    p_name="$(yq ".plugins[${i}].name" "${CONFIG_FILE}")"
    p_source="$(yq ".plugins[${i}].source" "${CONFIG_FILE}")"
    p_enabled="$(yq ".plugins[${i}].enabled" "${CONFIG_FILE}")"

    if [ "${p_enabled}" = "false" ]; then
      echo "[plugin] ${p_name}: disabled"
      continue
    fi

    echo "[plugin] ${p_name}: install manually for your harness — ${p_source}"
  done
}

# ─── Cleanup ───────────────────────────────────────────────────────────────────

cleanup_target() {
  local target_dir="$1"
  local uninstall_all="${2:-false}"

  _log "Cleaning up ${target_dir}"

  # Remove symlinks in skills/
  if [ -d "${target_dir}/skills" ]; then
    local link
    while IFS= read -r -d '' link; do
      [ -L "${link}" ] && rm "${link}" && _log "Removed: ${link}"
    done < <(find "${target_dir}/skills" -type l -print0 2>/dev/null)
    # Remove empty skill dirs
    find "${target_dir}/skills" -type d -empty -delete 2>/dev/null || true
  fi

  # Remove symlinks in agents/
  if [ -d "${target_dir}/agents" ]; then
    local link
    while IFS= read -r -d '' link; do
      [ -L "${link}" ] && rm "${link}" && _log "Removed: ${link}"
    done < <(find "${target_dir}/agents" -type l -print0 2>/dev/null)
    find "${target_dir}/agents" -type d -empty -delete 2>/dev/null || true
  fi

  # Remove AGENTS.md symlink
  if [ -L "${target_dir}/AGENTS.md" ]; then
    rm "${target_dir}/AGENTS.md"
    _log "Removed: ${target_dir}/AGENTS.md"
  fi

  # Uninstall npx skills
  local count
  count="$(_get_resource_count)"
  local i
  for (( i = 0; i < count; i++ )); do
    local res_enabled res_npx_package res_command res_name
    res_enabled="$(_get_resource_field "${i}" 'enabled')"
    res_npx_package="$(_get_resource_field "${i}" 'npx-package')"
    res_command="$(_get_resource_field "${i}" 'command')"
    res_name="$(_get_resource_field "${i}" 'name')"

    # Only uninstall npx-package resources (command resources manage their own lifecycle)
    [ -z "${res_npx_package}" ] && continue

    if [ "${uninstall_all}" = "true" ] || [ "${res_enabled}" = "false" ]; then
      echo "[uninstall] ${res_name}: npx skills remove ${res_npx_package}"
      npx skills remove "${res_npx_package}" || true
    fi
  done
}

# ─── Main ──────────────────────────────────────────────────────────────────────

main() {
  _require_yq

  local action="install"
  local target=""

  while [ $# -gt 0 ]; do
    case "$1" in
      -c) action="cleanup"   ; shift ;;
      -a) action="cleanup-all"; shift ;;
      -h) _usage; exit 0 ;;
      *)  target="$1"         ; shift ;;
    esac
  done

  case "${action}" in
    install)
      if [ -n "${target}" ]; then
        # Specific tool name or custom path
        if [ -n "${TOOL_DIRS[${target}]:-}" ]; then
          sync_to_target "${TOOL_DIRS[${target}]}"
        else
          sync_to_target "${target}"
        fi
      else
        # All known tools
        for tool in claude gemini copilot pi omp goose; do
          sync_to_target "${TOOL_DIRS[${tool}]}"
        done
      fi
      ;;
    cleanup)
      if [ -n "${target}" ]; then
        if [ -n "${TOOL_DIRS[${target}]:-}" ]; then
          cleanup_target "${TOOL_DIRS[${target}]}" false
        else
          cleanup_target "${target}" false
        fi
      else
        for tool in claude gemini copilot pi omp goose; do
          cleanup_target "${TOOL_DIRS[${tool}]}" false
        done
      fi
      ;;
    cleanup-all)
      if [ -n "${target}" ]; then
        if [ -n "${TOOL_DIRS[${target}]:-}" ]; then
          cleanup_target "${TOOL_DIRS[${target}]}" true
        else
          cleanup_target "${target}" true
        fi
      else
        for tool in claude gemini copilot pi omp goose; do
          cleanup_target "${TOOL_DIRS[${tool}]}" true
        done
      fi
      ;;
  esac
}

main "$@"