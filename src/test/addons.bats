#!/usr/bin/env bats
# Integration tests for cluster-delete-addons
#
# Mocks eksctl and cluster-delete-addon to verify correct addon
# selection, empty-config guards, and confirmation behaviour.

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)"

setup() {
  export CLUSTER_CONFIG="${BATS_TEST_TMPDIR}/cluster.yaml"
  export CLUSTER_SCRIPT_DIR="${BATS_TEST_TMPDIR}/scripts"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"

  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  mkdir -p "${CLUSTER_SCRIPT_DIR}"

  # Real cluster.yaml with 5 addons
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
  - name: aws-ebs-csi-driver
    version: latest
  - name: eks-pod-identity-agent
    version: latest
YAML

  # Mock eksctl: "get addons" for delete tests; record full "create addon" args
  export CREATED_LOG="${BATS_TEST_TMPDIR}/created.log"
  export EKSCTL_LOG="${BATS_TEST_TMPDIR}/eksctl.log"
  cat > "${BATS_TEST_TMPDIR}/bin/eksctl" <<MOCK
#!/usr/bin/env bash
if [[ "\$1" == "get" ]]; then
  cat <<'YAML'
- Name: vpc-cni
  Status: ACTIVE
  Version: v1.19.2-eksbuild.1
- Name: coredns
  Status: ACTIVE
  Version: v1.11.4-eksbuild.2
- Name: kube-proxy
  Status: ACTIVE
  Version: v1.31.4-eksbuild.1
- Name: aws-ebs-csi-driver
  Status: ACTIVE
  Version: v1.38.1-eksbuild.2
- Name: eks-pod-identity-agent
  Status: ACTIVE
  Version: v1.3.5-eksbuild.2
- Name: some-old-addon
  Status: ACTIVE
  Version: v0.1.0
YAML
elif [[ "\$1" == "create" ]]; then
  echo "\$*" >> "${EKSCTL_LOG}"
fi
MOCK
  chmod +x "${BATS_TEST_TMPDIR}/bin/eksctl"

  # Mock cluster-delete-addon: record what gets deleted
  export DELETED_LOG="${BATS_TEST_TMPDIR}/deleted.log"
  cat > "${CLUSTER_SCRIPT_DIR}/cluster-delete-addon" <<MOCK
#!/usr/bin/env bash
echo "\$1" >> "${DELETED_LOG}"
echo "Deleted addon \$1"
MOCK
  chmod +x "${CLUSTER_SCRIPT_DIR}/cluster-delete-addon"

  # Mock cluster-create-addon: record delegated create calls (used by plural tests)
  export FORCE_LOG="${BATS_TEST_TMPDIR}/force.log"
  cat > "${CLUSTER_SCRIPT_DIR}/cluster-create-addon" <<MOCK
#!/usr/bin/env bash
echo "\$1" >> "${CREATED_LOG}"
for a in "\$@"; do [[ "\$a" == "--force" ]] && echo "\$1" >> "${FORCE_LOG}"; done
echo "Addon \$1 created"
MOCK
  chmod +x "${CLUSTER_SCRIPT_DIR}/cluster-create-addon"
}

# ====================================================================
# Correctness with --yes
# ====================================================================

@test "cluster-delete-addons: should only delete addons NOT in cluster.yaml" {
  run bash "${SCRIPTS_DIR}/cluster-delete-addons" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"

  # Script should succeed
  [[ "${status}" -eq 0 ]]

  # Should have deleted only the one extra addon
  [[ -f "${DELETED_LOG}" ]]
  deleted=$(cat "${DELETED_LOG}")
  echo "DELETED: ${deleted}"
  [[ $(echo "${deleted}" | wc -l) -eq 1 ]]
  echo "${deleted}" | grep -qx "some-old-addon"
}

@test "cluster-delete-addons: should NOT delete any configured addons" {
  run bash "${SCRIPTS_DIR}/cluster-delete-addons" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"

  if [[ -f "${DELETED_LOG}" ]]; then
    deleted=$(cat "${DELETED_LOG}")
    echo "DELETED: ${deleted}"
    # None of the configured addons should appear in the delete log
    ! echo "${deleted}" | grep -qx "vpc-cni"
    ! echo "${deleted}" | grep -qx "coredns"
    ! echo "${deleted}" | grep -qx "kube-proxy"
    ! echo "${deleted}" | grep -qx "aws-ebs-csi-driver"
    ! echo "${deleted}" | grep -qx "eks-pod-identity-agent"
  fi
}

# ====================================================================
# Empty-config guards
# ====================================================================

@test "cluster-delete-addons: bails when addons key not found" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
YAML

  run bash "${SCRIPTS_DIR}/cluster-delete-addons"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Addons key not found in ${CLUSTER_CONFIG}, cannot determine what to keep."* ]]
  [[ "${output}" == *"Skipping deletion to avoid removing all addons."* ]]
  [[ ! -f "${DELETED_LOG}" ]]
}

@test "cluster-delete-addons: bails when addons array is empty" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
addons: []
YAML

  run bash "${SCRIPTS_DIR}/cluster-delete-addons"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"No addons defined in ${CLUSTER_CONFIG}, cannot determine what to keep."* ]]
  [[ "${output}" == *"Skipping deletion to avoid removing all addons."* ]]
  [[ ! -f "${DELETED_LOG}" ]]
}

# ====================================================================
# Confirmation behaviour
# ====================================================================

@test "cluster-delete-addons: shows list and proceeds when confirmed" {
  run bash -c "echo 'yes' | bash '${SCRIPTS_DIR}/cluster-delete-addons'"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Will delete the following 1 addon(s) not defined in cluster.yaml:"* ]]
  [[ "${output}" == *"some-old-addon"* ]]
  [[ "${output}" == *"Deleted 1 extra addon(s)."* ]]
  [[ -f "${DELETED_LOG}" ]]
  grep -qx "some-old-addon" "${DELETED_LOG}"
}

@test "cluster-delete-addons: aborts when confirmation denied" {
  run bash -c "echo 'no' | bash '${SCRIPTS_DIR}/cluster-delete-addons'"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Will delete the following 1 addon(s) not defined in cluster.yaml:"* ]]
  [[ "${output}" == *"Aborted."* ]]
  [[ ! -f "${DELETED_LOG}" ]]
}

# ====================================================================
# cluster-create-addons: parallel creation
# ====================================================================

@test "cluster-create-addons: creates all configured addons" {
  run bash "${SCRIPTS_DIR}/cluster-create-addons"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ -f "${CREATED_LOG}" ]]
  created=$(sort "${CREATED_LOG}")
  echo "CREATED: ${created}"
  [[ $(echo "${created}" | wc -l | tr -d ' ') -eq 5 ]]
  echo "${created}" | grep -qx "vpc-cni"
  echo "${created}" | grep -qx "coredns"
  echo "${created}" | grep -qx "kube-proxy"
  echo "${created}" | grep -qx "aws-ebs-csi-driver"
  echo "${created}" | grep -qx "eks-pod-identity-agent"
}

@test "cluster-create-addons: reports success message" {
  run bash "${SCRIPTS_DIR}/cluster-create-addons"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"All 5 addon(s) created successfully."* ]]
}

@test "cluster-create-addons: exits 0 when no addons defined" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
YAML

  run bash "${SCRIPTS_DIR}/cluster-create-addons"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"No addons defined"* ]]
  [[ ! -f "${CREATED_LOG}" ]]
}

@test "cluster-create-addons: passes --force through to the singular" {
  run bash "${SCRIPTS_DIR}/cluster-create-addons" --force
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ -f "${FORCE_LOG}" ]]
  [[ $(wc -l < "${FORCE_LOG}" | tr -d ' ') -eq 5 ]]
}

# ====================================================================
# cluster-create-addon: single addon via --cluster/--name
# ====================================================================

@test "cluster-create-addon: uses --cluster and --name, not -f" {
  run bash "${SCRIPTS_DIR}/cluster-create-addon" vpc-cni
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ -f "${EKSCTL_LOG}" ]]
  args=$(< "${EKSCTL_LOG}")
  echo "ARGS: ${args}"
  [[ "${args}" == *"--cluster test-cluster"* ]]
  [[ "${args}" == *"--name vpc-cni"* ]]
  [[ "${args}" != *"-f "* ]]
}

@test "cluster-create-addon: omits --version when version is latest" {
  run bash "${SCRIPTS_DIR}/cluster-create-addon" vpc-cni
  [[ "${status}" -eq 0 ]]
  [[ "$(< "${EKSCTL_LOG}")" != *"--version"* ]]
}

@test "cluster-create-addon: passes --version when pinned (not latest)" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
addons:
  - name: vpc-cni
    version: v1.19.2-eksbuild.1
YAML
  run bash "${SCRIPTS_DIR}/cluster-create-addon" vpc-cni
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "$(< "${EKSCTL_LOG}")" == *"--version v1.19.2-eksbuild.1"* ]]
}

@test "cluster-create-addon: passes --service-account-role-arn when present" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
addons:
  - name: aws-ebs-csi-driver
    version: latest
    serviceAccountRoleARN: arn:aws:iam::123456789012:role/ebs-csi
YAML
  run bash "${SCRIPTS_DIR}/cluster-create-addon" aws-ebs-csi-driver
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "$(< "${EKSCTL_LOG}")" == *"--service-account-role-arn arn:aws:iam::123456789012:role/ebs-csi"* ]]
}

@test "cluster-create-addon: omits --service-account-role-arn when absent" {
  run bash "${SCRIPTS_DIR}/cluster-create-addon" vpc-cni
  [[ "${status}" -eq 0 ]]
  [[ "$(< "${EKSCTL_LOG}")" != *"--service-account-role-arn"* ]]
}

@test "cluster-create-addon: passes --force through" {
  run bash "${SCRIPTS_DIR}/cluster-create-addon" vpc-cni --force
  [[ "${status}" -eq 0 ]]
  [[ "$(< "${EKSCTL_LOG}")" == *"--force"* ]]
}

@test "cluster-create-addon: fails when addon not in cluster.yaml" {
  run bash "${SCRIPTS_DIR}/cluster-create-addon" not-a-real-addon
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"not-a-real-addon"* ]]
  [[ "${output}" == *"not found"* ]]
  [[ "${output}" == *"vpc-cni"* ]]
  [[ ! -f "${EKSCTL_LOG}" ]]
}

@test "cluster-create-addon: fails when addon defines an unsupported field" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
addons:
  - name: vpc-cni
    version: latest
    configurationValues: '{"env":{"FOO":"bar"}}'
YAML
  run bash "${SCRIPTS_DIR}/cluster-create-addon" vpc-cni
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"configurationValues"* ]]
  [[ ! -f "${EKSCTL_LOG}" ]]
}
