#!/usr/bin/env bats
# Test cluster-validate-image with mock cluster.yaml files

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)"
WORK_DIR="$(cd "${BATS_TEST_DIRNAME}/../../target" && pwd)/validate-image"

setup() {
  rm -rf "${WORK_DIR}"
  mkdir -p "${WORK_DIR}"
}

@test "validate-image fails when filename does not match cluster*.yaml" {
  cat > "${WORK_DIR}/bad-name.yaml" <<'YAML'
metadata:
  name: test-cluster
  region: us-east-1
YAML
  export CLUSTER_CONFIG="${WORK_DIR}/bad-name.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"cluster*.yaml"* ]]
}

@test "validate-image fails when cluster.yaml missing" {
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"not found"* ]]
}

@test "validate-image fails when cluster.yaml is empty" {
  touch "${WORK_DIR}/cluster.yaml"
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"empty"* ]]
}

@test "validate-image fails when cluster.yaml is not valid YAML" {
  printf '[invalid yaml: {{{' > "${WORK_DIR}/cluster.yaml"
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"not valid YAML"* ]]
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

@test "validate-image fails when addon version is not latest" {
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
  [[ "${output}" == *"must be 'latest'"* ]]
}

@test "validate-image fails when addon version not set" {
  cat > "${WORK_DIR}/cluster.yaml" <<'YAML'
metadata:
  name: test-cluster
  region: us-east-1
addons:
  - name: vpc-cni
YAML
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"version not set"* ]]
}

@test "validate-image passes with valid config" {
  cat > "${WORK_DIR}/cluster.yaml" <<'YAML'
metadata:
  name: test-cluster
  region: us-east-1
addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
YAML
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Validation passed"* ]]
}

@test "validate-image passes with no addons" {
  cat > "${WORK_DIR}/cluster.yaml" <<'YAML'
metadata:
  name: test-cluster
  region: us-east-1
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
    version: latest
YAML
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"WARN"* ]]
  [[ "${output}" == *"Validation passed"* ]]
}

@test "validate-image checks all 3 addons when 3 defined" {
  cat > "${WORK_DIR}/cluster.yaml" <<'YAML'
metadata:
  name: test-cluster
  region: us-east-1
addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: v1.2.3
  - name: kube-proxy
    version: latest
YAML
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"coredns"* ]]
  [[ "${output}" == *"must be 'latest'"* ]]
  [[ "${output}" == *"1 error(s)"* ]]
}

@test "validate-image reports multiple addon errors" {
  cat > "${WORK_DIR}/cluster.yaml" <<'YAML'
metadata:
  name: test-cluster
  region: us-east-1
addons:
  - name: vpc-cni
    version: v1.0.0
  - name: coredns
    version: v1.2.3
  - name: kube-proxy
    version: latest
YAML
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"vpc-cni"* ]]
  [[ "${output}" == *"coredns"* ]]
  [[ "${output}" == *"2 error(s)"* ]]
}

@test "validate-image rejects arguments" {
  cat > "${WORK_DIR}/cluster.yaml" <<'YAML'
metadata:
  name: test-cluster
  region: us-east-1
YAML
  export CLUSTER_CONFIG="${WORK_DIR}/cluster.yaml"
  run bash "${SCRIPTS_DIR}/cluster-validate-image" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"no arguments"* ]]
}
