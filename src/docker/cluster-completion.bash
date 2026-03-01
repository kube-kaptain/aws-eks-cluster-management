#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# cluster-completion.bash - Bash completion for the cluster router/impl pattern
#
# Scans CLUSTER_SCRIPT_DIR for scripts matching the cluster-* naming convention
# and provides tab completion that understands the routing hierarchy.
#
# Example:
#   cluster <tab>        → list, create, delete, credentials, upgrade
#   cluster list <tab>   → all, clusters, nodes, nodegroups, addons, version
#   cluster list no<tab> → nodes, nodegroups
#

CLUSTER_SCRIPT_DIR="${CLUSTER_SCRIPT_DIR:-/kd/bin}"

_cluster_completions() {
  local cmd="${1}"
  local cur="${2}"
  local prev="${3}"

  # Build prefix from command name + all completed args joined with hyphens
  # e.g., "cluster" with args ["list"] → prefix "cluster-list"
  # e.g., "cluster" with args ["list", "node"] would not happen (list-node not typed yet)
  local prefix="${cmd}"
  local i
  for ((i = 1; i < COMP_CWORD; i++)); do
    prefix="${prefix}-${COMP_WORDS[i]}"
  done

  # Find all files matching prefix-* and extract the next segment
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
