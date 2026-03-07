#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# cluster-completion.bash - Bash completion for the cluster router/impl pattern
#
# Scans CLUSTER_SCRIPT_DIR for scripts matching the cluster-* naming convention
# and provides tab completion that understands the routing hierarchy.
#
# At the top level, only short segments (router names) are offered to keep
# the list manageable.  At deeper levels, when a script exists for the short
# segment, both the short and the full remainder are offered so that longer
# leaf names are discoverable alongside the router.
# When no script exists for the first segment, only the full remainder is shown
# to avoid offering non-existent intermediate commands.
#
# Example:
#   cluster <tab>             → list, create, delete, setup-credentials, upgrade
#   cluster list <tab>        → all, clusters, nodes, nodes-for-nodegroup, ...
#   cluster list no<tab>      → nodes, nodes-for-nodegroup, nodegroups, ...
#   cluster setup<tab>        → setup-credentials (no cluster-setup script exists)

CLUSTER_SCRIPT_DIR="${CLUSTER_SCRIPT_DIR:-/kd/bin}"

_cluster_completions() {
  local cmd="${1}"
  local cur="${2}"

  # Build prefix from command name + all completed args joined with hyphens
  # e.g., "cluster" with args ["list"] → prefix "cluster-list"
  local prefix="${cmd}"
  local i
  for ((i = 1; i < COMP_CWORD; i++)); do
    prefix="${prefix}-${COMP_WORDS[i]}"
  done

  # Find all files matching prefix-* and extract completions
  local completions=()
  local seen=()
  local file segment
  for file in "${CLUSTER_SCRIPT_DIR}/${prefix}-"*; do
    [[ -e "${file}" ]] || continue
    file="$(basename "${file}")"
    # Strip the prefix and leading hyphen to get the remainder
    local remainder="${file#"${prefix}-"}"
    # Extract first segment (up to next hyphen, or the whole thing)
    segment="${remainder%%-*}"

    # Build list of candidates to add
    local candidates=()

    if [[ "${segment}" == "${remainder}" ]]; then
      # Single segment, no ambiguity
      candidates+=("${remainder}")
    elif [[ -x "${CLUSTER_SCRIPT_DIR}/${prefix}-${segment}" ]]; then
      # Script exists for short segment
      if [[ ${COMP_CWORD} -ge 2 ]]; then
        # Deeper levels — offer both short and full so longer leaves
        # are discoverable alongside the router
        candidates+=("${segment}" "${remainder}")
      else
        # Top level — just offer the short segment to keep it clean
        candidates+=("${segment}")
      fi
    else
      # No script for short segment — only offer the full remainder
      candidates+=("${remainder}")
    fi

    # Deduplicate and add
    local candidate
    for candidate in "${candidates[@]}"; do
      local already=false
      local s
      for s in "${seen[@]+"${seen[@]}"}"; do
        if [[ "${s}" == "${candidate}" ]]; then
          already=true
          break
        fi
      done
      if [[ "${already}" == "false" ]]; then
        seen+=("${candidate}")
        completions+=("${candidate}")
      fi
    done
  done

  COMPREPLY=($(compgen -W "${completions[*]}" -- "${cur}" 2>/dev/null)) || true
}

complete -F _cluster_completions cluster
