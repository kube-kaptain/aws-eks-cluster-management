#!/usr/bin/env bats
# Test cluster-validate-image with mock cluster.yaml files

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)"
WORK_DIR="$(cd "${BATS_TEST_DIRNAME}/../../target" && pwd)/validate-image"

setup() {
  rm -rf "${WORK_DIR}"
  mkdir -p "${WORK_DIR}"
}

@test "validate-image fails when cluster.yaml missing" {
  export CLUSTER_CONFIG="${WORK_DIR}/nonexistent.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"not found"* ]]
}

@test "validate-image fails when metadata.name missing" {
  cat > "${WORK_DIR}/cluster.yaml" <<'YAML'
metadata:
  region: us-east-1
YAML
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"metadata.name"* ]]
}

@test "validate-image fails when metadata.region missing" {
  cat > "${WORK_DIR}/cluster.yaml" <<'YAML'
metadata:
  name: test-cluster
YAML
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"metadata.region"* ]]
}

@test "validate-image fails when addon has pinned version" {
  cat > "${WORK_DIR}/cluster.yaml" <<'YAML'
metadata:
  name: test-cluster
  region: us-east-1
addons:
  - name: vpc-cni
    version: v1.2.3
YAML
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"pinned version"* ]]
}

@test "validate-image passes with valid config" {
  cat > "${WORK_DIR}/cluster.yaml" <<'YAML'
metadata:
  name: test-cluster
  region: us-east-1
addons:
  - name: vpc-cni
  - name: coredns
YAML
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Validation passed"* ]]
}

@test "validate-image warns when age file missing but still passes" {
  cat > "${WORK_DIR}/cluster.yaml" <<'YAML'
metadata:
  name: test-cluster
  region: us-east-1
addons:
  - name: vpc-cni
YAML
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"WARN"* ]]
  [[ "${output}" == *"Validation passed"* ]]
}
