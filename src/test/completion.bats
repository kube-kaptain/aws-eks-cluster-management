#!/usr/bin/env bats
# Test bash completion for the cluster command

COMPLETION_SCRIPT="$(cd "${BATS_TEST_DIRNAME}/../docker" && pwd)/cluster-completion.bash"
WORK_DIR="$(cd "${BATS_TEST_DIRNAME}/../../target" && pwd)/completion"

setup() {
  rm -rf "${WORK_DIR}"
  mkdir -p "${WORK_DIR}/bin"

  create_stub() {
    local name="$1"
    printf '#!/usr/bin/env bash\necho stub\n' > "${WORK_DIR}/bin/${name}"
    chmod +x "${WORK_DIR}/bin/${name}"
  }

  # Top-level routers
  create_stub "cluster-create"
  create_stub "cluster-list"
  create_stub "cluster-delete"
  create_stub "cluster-upgrade"

  # Leaves with no matching router (full remainder at top level)
  create_stub "cluster-credentials-setup"
  create_stub "cluster-credentials-encrypt"

  # Second-level leaves under list
  create_stub "cluster-list-clusters"
  create_stub "cluster-list-nodes"
  create_stub "cluster-list-nodegroups"
  create_stub "cluster-list-nodes-for-nodegroup"
  create_stub "cluster-list-nodes-for-old-nodegroups"
  create_stub "cluster-list-nodes-for-new-nodegroups"
  create_stub "cluster-list-addon-versions"

  # Second-level leaves under create
  create_stub "cluster-create-cluster"
  create_stub "cluster-create-nodegroup"
  create_stub "cluster-create-nodegroups"

  # Second-level under upgrade (no short router for "fast")
  create_stub "cluster-upgrade-controlplane"
  create_stub "cluster-upgrade-addon"
  create_stub "cluster-upgrade-addons"
  create_stub "cluster-upgrade-fast-end-to-end-automatic"

  export CLUSTER_SCRIPT_DIR="${WORK_DIR}/bin"

  # Source the completion script — provides _cluster_completions and COMPREPLY
  source "${COMPLETION_SCRIPT}"
}

# Helper: simulate completion and return sorted COMPREPLY
# Usage: complete_at "cluster" "list" ""
#   Args represent COMP_WORDS; last arg is the current word being typed
complete_at() {
  COMP_WORDS=("$@")
  COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 ))
  local cur="${COMP_WORDS[COMP_CWORD]}"
  _cluster_completions "cluster" "${cur}"
  # Sort for deterministic comparison
  IFS=$'\n' COMPREPLY=($(printf '%s\n' "${COMPREPLY[@]}" | sort)); unset IFS
}

# --- Top level: cluster <tab> ---

@test "top level: shows routers and full remainders, not expanded leaves" {
  complete_at "cluster" ""
  # Should include the 4 routers
  [[ " ${COMPREPLY[*]} " == *" create "* ]]
  [[ " ${COMPREPLY[*]} " == *" list "* ]]
  [[ " ${COMPREPLY[*]} " == *" delete "* ]]
  [[ " ${COMPREPLY[*]} " == *" upgrade "* ]]
  # Should include credentials-setup and credentials-encrypt (no cluster-credentials router)
  [[ " ${COMPREPLY[*]} " == *" credentials-setup "* ]]
  [[ " ${COMPREPLY[*]} " == *" credentials-encrypt "* ]]
  # Should NOT include expanded leaves like list-clusters
  [[ " ${COMPREPLY[*]} " != *" list-clusters "* ]]
  [[ " ${COMPREPLY[*]} " != *" create-cluster "* ]]
  [[ " ${COMPREPLY[*]} " != *" upgrade-controlplane "* ]]
}

@test "top level: partial match filters correctly" {
  complete_at "cluster" "cr"
  [[ " ${COMPREPLY[*]} " == *" create "* ]]
  [[ " ${COMPREPLY[*]} " == *" credentials-setup "* ]]
  [[ " ${COMPREPLY[*]} " == *" credentials-encrypt "* ]]
  [[ " ${COMPREPLY[*]} " != *" list "* ]]
}

@test "top level: unique prefix completes to single match" {
  complete_at "cluster" "li"
  [[ ${#COMPREPLY[@]} -eq 1 ]]
  [[ "${COMPREPLY[0]}" == "list" ]]
}

# --- Second level: cluster list <tab> ---

@test "second level: shows both short and full when router exists for short" {
  complete_at "cluster" "list" ""
  # cluster-list-nodes exists as a script, so "nodes" appears
  [[ " ${COMPREPLY[*]} " == *" nodes "* ]]
  # The longer name should also appear
  [[ " ${COMPREPLY[*]} " == *" nodes-for-nodegroup "* ]]
  # Other single-segment leaves
  [[ " ${COMPREPLY[*]} " == *" clusters "* ]]
  [[ " ${COMPREPLY[*]} " == *" nodegroups "* ]]
}

@test "second level: full remainder shown when no router for short segment" {
  complete_at "cluster" "list" ""
  # "addon-versions" — no cluster-list-addon script exists
  [[ " ${COMPREPLY[*]} " == *" addon-versions "* ]]
  # Should NOT show bare "addon" since there's no cluster-list-addon
  [[ " ${COMPREPLY[*]} " != *" addon "* ]]
}

@test "second level: partial match filters to matching candidates" {
  complete_at "cluster" "list" "no"
  [[ " ${COMPREPLY[*]} " == *" nodes "* ]]
  [[ " ${COMPREPLY[*]} " == *" nodes-for-nodegroup "* ]]
  [[ " ${COMPREPLY[*]} " == *" nodegroups "* ]]
  [[ " ${COMPREPLY[*]} " != *" clusters "* ]]
}

@test "second level: upgrade shows both addon and addons plus full remainder" {
  complete_at "cluster" "upgrade" ""
  [[ " ${COMPREPLY[*]} " == *" controlplane "* ]]
  [[ " ${COMPREPLY[*]} " == *" addon "* ]]
  [[ " ${COMPREPLY[*]} " == *" addons "* ]]
  # fast-end-to-end-automatic — no cluster-upgrade-fast script
  [[ " ${COMPREPLY[*]} " == *" fast-end-to-end-automatic "* ]]
  # Should NOT show bare "fast"
  [[ " ${COMPREPLY[*]} " != *" fast "* ]]
}

# --- Edge cases ---

@test "no matches returns empty" {
  complete_at "cluster" "zzz"
  [[ ${#COMPREPLY[@]} -eq 0 ]]
}

@test "second level no matches returns empty" {
  complete_at "cluster" "list" "zzz"
  [[ ${#COMPREPLY[@]} -eq 0 ]]
}

@test "second level: nodes-for-* variants all discoverable alongside nodes" {
  complete_at "cluster" "list" "no"
  [[ " ${COMPREPLY[*]} " == *" nodes "* ]]
  [[ " ${COMPREPLY[*]} " == *" nodes-for-nodegroup "* ]]
  [[ " ${COMPREPLY[*]} " == *" nodes-for-old-nodegroups "* ]]
  [[ " ${COMPREPLY[*]} " == *" nodes-for-new-nodegroups "* ]]
  [[ " ${COMPREPLY[*]} " == *" nodegroups "* ]]
}

@test "deduplication: short segment not duplicated" {
  complete_at "cluster" "create" ""
  # "nodegroup" appears from cluster-create-nodegroup (single segment)
  # and also would be extracted from cluster-create-nodegroups
  # Both should be present, but nodegroup only once
  local count=0
  for item in "${COMPREPLY[@]}"; do
    [[ "${item}" == "nodegroup" ]] && count=$((count + 1))
  done
  [[ ${count} -eq 1 ]]
}
