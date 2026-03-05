#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# cluster-completion.bash - Bash completion for the cluster router/impl pattern
#
# Scans CLUSTER_SCRIPT_DIR for scripts matching the cluster-* naming convention
# and provides tab completion that understands the routing hierarchy.
#
# When a segment has no router script, the completion expands through the full
# remaining path so the user doesn't stop at a non-existent intermediate command.
#
# Example:
#   cluster <tab>             → list, create, delete, setup-credentials, upgrade
#   cluster list <tab>        → all, clusters, nodes, nodegroups, addons, version
#   cluster list no<tab>      → nodes, nodegroups
#   cluster setup<tab>        → setup-credentials (no cluster-setup router exists)

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

    # If no router exists for this segment, use the full remainder
    # e.g., no cluster-setup router → offer setup-credentials not setup
    if [[ "${segment}" != "${remainder}" ]] && \
       [[ ! -x "${CLUSTER_SCRIPT_DIR}/${prefix}-${segment}" ]]; then
      segment="${remainder}"
    fi

    # Deduplicate
    local already=false
    local s
    for s in "${seen[@]+"${seen[@]}"}"; do
      if [[ "${s}" == "${segment}" ]]; then
        already=true
        break
      fi
    done
    if [[ "${already}" == "false" ]]; then
      seen+=("${segment}")
      completions+=("${segment}")
    fi
  done

  COMPREPLY=($(compgen -W "${completions[*]}" -- "${cur}"))
}

complete -F _cluster_completions cluster
