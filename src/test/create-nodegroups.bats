#!/usr/bin/env bats
# Test cluster-create-nodegroup and cluster-create-nodegroups argument handling

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)"
WORK_DIR="$(cd "${BATS_TEST_DIRNAME}/../../target" && pwd)/create-nodegroups"

setup() {
  rm -rf "${WORK_DIR}"
  mkdir -p "${WORK_DIR}/bin"

  # Minimal cluster.yaml with a nodegroup
  cat > "${WORK_DIR}/cluster.yaml" << 'YAML'
metadata:
  name: test-cluster
  region: us-east-1
managedNodeGroups:
  - name: ng-main
    instanceType: t3.medium
YAML

  # Mock eksctl that records its arguments
  cat > "${WORK_DIR}/bin/eksctl" << SCRIPT
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${WORK_DIR}/eksctl-calls.log"
SCRIPT
  chmod +x "${WORK_DIR}/bin/eksctl"

  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  export PATH="${WORK_DIR}/bin:${PATH}"
}

# --- cluster-create-nodegroups ---

@test "create-nodegroups: runs eksctl without --dry-run by default" {
  run bash "${SCRIPTS_DIR}/cluster-create-nodegroups"
  [[ "${status}" -eq 0 ]]
  # Check eksctl was called without --dry-run
  log=$(cat "${WORK_DIR}/eksctl-calls.log")
  [[ "${log}" == *"create nodegroup"* ]]
  [[ "${log}" != *"--dry-run"* ]]
}

@test "create-nodegroups: passes --dry-run to eksctl" {
  run bash "${SCRIPTS_DIR}/cluster-create-nodegroups" --dry-run
  [[ "${status}" -eq 0 ]]
  log=$(cat "${WORK_DIR}/eksctl-calls.log")
  [[ "${log}" == *"--dry-run"* ]]
  [[ "${output}" == *"Dry run"* ]]
}

@test "create-nodegroups: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-create-nodegroups" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown flag"* ]]
}

# --- cluster-create-nodegroup ---

@test "create-nodegroup: no args exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/cluster-create-nodegroup"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "create-nodegroup: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-create-nodegroup" ng-main --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown flag"* ]]
}

@test "create-nodegroup: runs eksctl without --dry-run by default" {
  run bash "${SCRIPTS_DIR}/cluster-create-nodegroup" ng-main
  [[ "${status}" -eq 0 ]]
  log=$(cat "${WORK_DIR}/eksctl-calls.log")
  [[ "${log}" == *"create nodegroup"* ]]
  [[ "${log}" == *"--include=ng-main"* ]]
  [[ "${log}" != *"--dry-run"* ]]
}

@test "create-nodegroup: passes --dry-run to eksctl" {
  run bash "${SCRIPTS_DIR}/cluster-create-nodegroup" ng-main --dry-run
  [[ "${status}" -eq 0 ]]
  log=$(cat "${WORK_DIR}/eksctl-calls.log")
  [[ "${log}" == *"--dry-run"* ]]
  [[ "${log}" == *"--include=ng-main"* ]]
  [[ "${output}" == *"Dry run"* ]]
}

@test "create-nodegroup: rejects nonexistent nodegroup" {
  run bash "${SCRIPTS_DIR}/cluster-create-nodegroup" nonexistent
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"not found"* ]]
  [[ "${output}" == *"ng-main"* ]]
}

@test "create-nodegroup: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-create-nodegroup" ng-main extra
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Too many"* ]]
}
