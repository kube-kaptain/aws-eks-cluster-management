#!/usr/bin/env bats
# Test router scripts behave consistently

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)"
WORK_DIR="$(cd "${BATS_TEST_DIRNAME}/../../target" && pwd)/routers"

setup() {
  rm -rf "${WORK_DIR}"
  mkdir -p "${WORK_DIR}/bin"

  # Create stub scripts for each router to discover
  create_stub() {
    local name="$1"
    echo '#!/usr/bin/env bash' > "${WORK_DIR}/bin/${name}"
    echo 'echo "stub"' >> "${WORK_DIR}/bin/${name}"
    chmod +x "${WORK_DIR}/bin/${name}"
  }

  # Top-level router stubs
  create_stub "cluster-create"
  create_stub "cluster-list"
  create_stub "cluster-delete"
  create_stub "cluster-set"

  # Sub-router stubs
  create_stub "cluster-create-cluster"
  create_stub "cluster-create-nodegroup"
  create_stub "cluster-create-nodegroups"
  create_stub "cluster-create-addons"
  create_stub "cluster-list-clusters"
  create_stub "cluster-list-nodes"
  create_stub "cluster-list-nodes-for-nodegroup"
  create_stub "cluster-list-nodes-for-old-nodegroups"
  create_stub "cluster-list-nodes-for-new-nodegroups"
  create_stub "cluster-delete-cluster"
  create_stub "cluster-delete-nodegroup"
  create_stub "cluster-delete-addon"
  create_stub "cluster-upgrade-controlplane"
  create_stub "cluster-upgrade-addon"
  create_stub "cluster-upgrade-addons"
  create_stub "cluster-upgrade-fast-end-to-end-automatic"
  create_stub "cluster-cordon-node"
  create_stub "cluster-cordon-nodegroup"
  create_stub "cluster-uncordon-node"
  create_stub "cluster-uncordon-nodegroup"
  create_stub "cluster-uncordon-old-nodegroups"
  create_stub "cluster-drain-node"
  create_stub "cluster-drain-nodegroup"
  create_stub "cluster-locksize-nodegroup"
  create_stub "cluster-locksize-old-nodegroups"
  create_stub "cluster-set-nodegroup-min"
  create_stub "cluster-set-nodegroup-max"
  create_stub "cluster-set-nodegroup-desired"
  create_stub "cluster-describe-stacks"
  create_stub "cluster-document-creation"
  create_stub "cluster-document-maintenance"
  create_stub "cluster-document-deletion"
  export CLUSTER_SCRIPT_DIR="${WORK_DIR}/bin"
}

# Helper to run a router script
run_router() {
  local router="$1"
  shift
  bash "${SCRIPTS_DIR}/${router}" "$@"
}

# --- Top-level router ---

@test "cluster: no args exits 1 with usage" {
  run run_router "cluster"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"sage"* ]]
}

@test "cluster: help exits 0 with usage" {
  run run_router "cluster" help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"sage"* ]]
}

@test "cluster: unknown verb exits 1 with error" {
  run run_router "cluster" nonexistent
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# --- create router ---

@test "cluster-create: no args exits 1 with usage" {
  run run_router "cluster-create"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-create: help exits 0 with usage" {
  run run_router "cluster-create" help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-create: unknown noun exits 1 with error" {
  run run_router "cluster-create" nonexistent
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# --- list router ---

@test "cluster-list: no args exits 1 with usage" {
  run run_router "cluster-list"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-list: help exits 0 with usage" {
  run run_router "cluster-list" help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-list: unknown noun exits 1 with error" {
  run run_router "cluster-list" nonexistent
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# --- delete router ---

@test "cluster-delete: no args exits 1 with usage" {
  run run_router "cluster-delete"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-delete: help exits 0 with usage" {
  run run_router "cluster-delete" help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-delete: unknown noun exits 1 with error" {
  run run_router "cluster-delete" nonexistent
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# --- upgrade router ---

@test "cluster-upgrade: no args exits 1 with usage" {
  run run_router "cluster-upgrade"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-upgrade: help exits 0 with usage" {
  run run_router "cluster-upgrade" help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-upgrade: unknown noun exits 1 with error" {
  run run_router "cluster-upgrade" nonexistent
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# --- cordon router ---

@test "cluster-cordon: no args exits 1 with usage" {
  run run_router "cluster-cordon"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-cordon: help exits 0 with usage" {
  run run_router "cluster-cordon" help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-cordon: unknown noun exits 1 with error" {
  run run_router "cluster-cordon" nonexistent
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# --- uncordon router ---

@test "cluster-uncordon: no args exits 1 with usage" {
  run run_router "cluster-uncordon"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-uncordon: help exits 0 with usage" {
  run run_router "cluster-uncordon" help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-uncordon: unknown noun exits 1 with error" {
  run run_router "cluster-uncordon" nonexistent
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# --- drain router ---

@test "cluster-drain: no args exits 1 with usage" {
  run run_router "cluster-drain"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-drain: help exits 0 with usage" {
  run run_router "cluster-drain" help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-drain: unknown noun exits 1 with error" {
  run run_router "cluster-drain" nonexistent
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# --- locksize router ---

@test "cluster-locksize: no args exits 1 with usage" {
  run run_router "cluster-locksize"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-locksize: help exits 0 with usage" {
  run run_router "cluster-locksize" help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-locksize: unknown noun exits 1 with error" {
  run run_router "cluster-locksize" nonexistent
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# --- set router ---

@test "cluster-set: no args exits 1 with usage" {
  run run_router "cluster-set"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-set: help exits 0 with usage" {
  run run_router "cluster-set" help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-set: unknown noun exits 1 with error" {
  run run_router "cluster-set" nonexistent
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# --- describe router ---

@test "cluster-describe: no args exits 1 with usage" {
  run run_router "cluster-describe"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-describe: help exits 0 with usage" {
  run run_router "cluster-describe" help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-describe: unknown noun exits 1 with error" {
  run run_router "cluster-describe" nonexistent
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# --- document router ---

@test "cluster-document: no args exits 1 with usage" {
  run run_router "cluster-document"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-document: help exits 0 with usage" {
  run run_router "cluster-document" help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "cluster-document: unknown noun exits 1 with error" {
  run run_router "cluster-document" nonexistent
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}
