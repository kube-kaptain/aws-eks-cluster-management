#!/usr/bin/env bats
# Integration tests for old-nodegroups and new-nodegroups scripts
#
# All 15 scripts that compare live nodegroups against cluster.yaml
# use the same yq expression with 2>/dev/null || true. These tests
# mock eksctl, kubectl, and sub-scripts to verify correct selection.
#
# Setup:
#   cluster.yaml defines: ng-new-1, ng-new-2
#   eksctl returns live:   ng-new-1, ng-new-2, ng-old-1
#
# Expected:
#   old-nodegroups scripts operate on ng-old-1 only
#   new-nodegroups scripts operate on ng-new-1 and ng-new-2 only

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)"

setup() {
  export CLUSTER_CONFIG="${BATS_TEST_TMPDIR}/cluster.yaml"
  export CLUSTER_SCRIPT_DIR="${BATS_TEST_TMPDIR}/scripts"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
  export ACTION_LOG="${BATS_TEST_TMPDIR}/actions.log"

  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  mkdir -p "${CLUSTER_SCRIPT_DIR}"

  : > "${ACTION_LOG}"

  # cluster.yaml with two managed nodegroups
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
managedNodeGroups:
  - name: ng-new-1
    instanceType: m5.large
  - name: ng-new-2
    instanceType: m5.large
YAML

  # Mock eksctl: returns the two configured plus one old
  cat > "${BATS_TEST_TMPDIR}/bin/eksctl" <<'MOCK'
#!/usr/bin/env bash
cat <<'YAML'
- Name: ng-new-1
  Status: ACTIVE
  DesiredCapacity: 3
  MinSize: 2
  MaxSize: 5
- Name: ng-new-2
  Status: ACTIVE
  DesiredCapacity: 2
  MinSize: 1
  MaxSize: 4
- Name: ng-old-1
  Status: ACTIVE
  DesiredCapacity: 3
  MinSize: 3
  MaxSize: 3
YAML
MOCK
  chmod +x "${BATS_TEST_TMPDIR}/bin/eksctl"

  # Mock kubectl: returns a node name per nodegroup
  cat > "${BATS_TEST_TMPDIR}/bin/kubectl" <<MOCK
#!/usr/bin/env bash
echo "kubectl \$*" >> "${ACTION_LOG}"
echo "ip-10-0-1-1.ec2.internal   Ready   <none>   5d   v1.31.0"
MOCK
  chmod +x "${BATS_TEST_TMPDIR}/bin/kubectl"

  # Mock sub-scripts that record calls
  for cmd in cluster-cordon-nodegroup cluster-uncordon-nodegroup \
             cluster-drain-nodegroup cluster-delete-nodegroup \
             cluster-locksize-nodegroup cluster-unlocksize-nodegroup; do
    cat > "${CLUSTER_SCRIPT_DIR}/${cmd}" <<MOCK
#!/usr/bin/env bash
echo "${cmd} \$*" >> "${ACTION_LOG}"
MOCK
    chmod +x "${CLUSTER_SCRIPT_DIR}/${cmd}"
  done
}

# ====================================================================
# Guards: bail when no nodegroup keys or empty nodegroup arrays
# ====================================================================

@test "cluster-delete-old-nodegroups: bails when no nodegroup keys" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
YAML

  run bash "${SCRIPTS_DIR}/cluster-delete-old-nodegroups"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Neither type of nodegroup key found in ${CLUSTER_CONFIG}, cannot determine what to keep."* ]]
  [[ "${output}" == *"Skipping deletion to avoid removing all nodegroups."* ]]
  ! grep -q "cluster-delete-nodegroup" "${ACTION_LOG}"
}

@test "cluster-delete-old-nodegroups: bails when nodegroup arrays are empty" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
managedNodeGroups: []
YAML

  run bash "${SCRIPTS_DIR}/cluster-delete-old-nodegroups"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"No nodegroups defined in ${CLUSTER_CONFIG}, cannot determine what to keep."* ]]
  [[ "${output}" == *"Skipping deletion to avoid removing all nodegroups."* ]]
  ! grep -q "cluster-delete-nodegroup" "${ACTION_LOG}"
}

@test "cluster-delete-new-nodegroups: bails when no nodegroup keys" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
YAML

  run bash "${SCRIPTS_DIR}/cluster-delete-new-nodegroups"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Neither type of nodegroup key found in ${CLUSTER_CONFIG}, cannot determine what to keep."* ]]
  [[ "${output}" == *"Skipping deletion to avoid removing all nodegroups."* ]]
  ! grep -q "cluster-delete-nodegroup" "${ACTION_LOG}"
}

@test "cluster-delete-new-nodegroups: bails when nodegroup arrays are empty" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
managedNodeGroups: []
YAML

  run bash "${SCRIPTS_DIR}/cluster-delete-new-nodegroups"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"No nodegroups defined in ${CLUSTER_CONFIG}, cannot determine what to keep."* ]]
  [[ "${output}" == *"Skipping deletion to avoid removing all nodegroups."* ]]
  ! grep -q "cluster-delete-nodegroup" "${ACTION_LOG}"
}

# ====================================================================
# Old-nodegroups: should ONLY operate on ng-old-1
# ====================================================================

@test "cluster-cordon-old-nodegroups: only cordons old nodegroups" {
  run bash "${SCRIPTS_DIR}/cluster-cordon-old-nodegroups"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "cluster-cordon-nodegroup" "${ACTION_LOG}") -eq 1 ]]
  grep -q "cluster-cordon-nodegroup ng-old-1" "${ACTION_LOG}"
  ! grep -q "ng-new-1" "${ACTION_LOG}"
  ! grep -q "ng-new-2" "${ACTION_LOG}"
}

@test "cluster-uncordon-old-nodegroups: only uncordons old nodegroups" {
  run bash "${SCRIPTS_DIR}/cluster-uncordon-old-nodegroups"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "cluster-uncordon-nodegroup" "${ACTION_LOG}") -eq 1 ]]
  grep -q "cluster-uncordon-nodegroup ng-old-1" "${ACTION_LOG}"
  ! grep -q "ng-new-1" "${ACTION_LOG}"
  ! grep -q "ng-new-2" "${ACTION_LOG}"
}

@test "cluster-delete-old-nodegroups: only deletes old nodegroups" {
  run bash "${SCRIPTS_DIR}/cluster-delete-old-nodegroups" --yes
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "cluster-delete-nodegroup" "${ACTION_LOG}") -eq 1 ]]
  grep -q "cluster-delete-nodegroup ng-old-1" "${ACTION_LOG}"
  ! grep -q "ng-new-1" "${ACTION_LOG}"
  ! grep -q "ng-new-2" "${ACTION_LOG}"
}

@test "cluster-drain-old-nodegroups: only drains old nodegroups" {
  run bash "${SCRIPTS_DIR}/cluster-drain-old-nodegroups"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "cluster-drain-nodegroup" "${ACTION_LOG}") -eq 1 ]]
  grep -q "cluster-drain-nodegroup ng-old-1" "${ACTION_LOG}"
  ! grep -q "ng-new-1" "${ACTION_LOG}"
  ! grep -q "ng-new-2" "${ACTION_LOG}"
}

@test "cluster-locksize-old-nodegroups: only locksizes old nodegroups" {
  run bash "${SCRIPTS_DIR}/cluster-locksize-old-nodegroups"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "cluster-locksize-nodegroup" "${ACTION_LOG}") -eq 1 ]]
  grep -q "cluster-locksize-nodegroup ng-old-1" "${ACTION_LOG}"
  ! grep -q "ng-new-1" "${ACTION_LOG}"
  ! grep -q "ng-new-2" "${ACTION_LOG}"
}

@test "cluster-unlocksize-old-nodegroups: only unlocksizes old nodegroups" {
  run bash "${SCRIPTS_DIR}/cluster-unlocksize-old-nodegroups"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "cluster-unlocksize-nodegroup" "${ACTION_LOG}") -eq 1 ]]
  grep -q "cluster-unlocksize-nodegroup ng-old-1" "${ACTION_LOG}"
  ! grep -q "ng-new-1" "${ACTION_LOG}"
  ! grep -q "ng-new-2" "${ACTION_LOG}"
}

@test "cluster-list-nodes-for-old-nodegroups: only lists old nodegroup nodes" {
  run bash "${SCRIPTS_DIR}/cluster-list-nodes-for-old-nodegroups"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "kubectl" "${ACTION_LOG}") -eq 1 ]]
  grep -q "ng-old-1" "${ACTION_LOG}"
  ! grep -q "ng-new-1" "${ACTION_LOG}"
  ! grep -q "ng-new-2" "${ACTION_LOG}"
}

@test "cluster-list-old-nodes-not-cordoned: only checks old nodegroup nodes" {
  run bash "${SCRIPTS_DIR}/cluster-list-old-nodes-not-cordoned"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "kubectl" "${ACTION_LOG}") -eq 1 ]]
  grep -q "ng-old-1" "${ACTION_LOG}"
  ! grep -q "ng-new-1" "${ACTION_LOG}"
  ! grep -q "ng-new-2" "${ACTION_LOG}"
}

# ====================================================================
# New-nodegroups: should ONLY operate on ng-new-1 and ng-new-2
# ====================================================================

@test "cluster-cordon-new-nodegroups: only cordons new nodegroups" {
  run bash "${SCRIPTS_DIR}/cluster-cordon-new-nodegroups"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "cluster-cordon-nodegroup" "${ACTION_LOG}") -eq 2 ]]
  grep -q "cluster-cordon-nodegroup ng-new-1" "${ACTION_LOG}"
  grep -q "cluster-cordon-nodegroup ng-new-2" "${ACTION_LOG}"
  ! grep -q "ng-old-1" "${ACTION_LOG}"
}

@test "cluster-uncordon-new-nodegroups: only uncordons new nodegroups" {
  run bash "${SCRIPTS_DIR}/cluster-uncordon-new-nodegroups"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "cluster-uncordon-nodegroup" "${ACTION_LOG}") -eq 2 ]]
  grep -q "cluster-uncordon-nodegroup ng-new-1" "${ACTION_LOG}"
  grep -q "cluster-uncordon-nodegroup ng-new-2" "${ACTION_LOG}"
  ! grep -q "ng-old-1" "${ACTION_LOG}"
}

@test "cluster-delete-new-nodegroups: only deletes new nodegroups" {
  run bash "${SCRIPTS_DIR}/cluster-delete-new-nodegroups" --yes
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "cluster-delete-nodegroup" "${ACTION_LOG}") -eq 2 ]]
  grep -q "cluster-delete-nodegroup ng-new-1" "${ACTION_LOG}"
  grep -q "cluster-delete-nodegroup ng-new-2" "${ACTION_LOG}"
  ! grep -q "ng-old-1" "${ACTION_LOG}"
}

@test "cluster-drain-new-nodegroups: only drains new nodegroups" {
  run bash "${SCRIPTS_DIR}/cluster-drain-new-nodegroups"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "cluster-drain-nodegroup" "${ACTION_LOG}") -eq 2 ]]
  grep -q "cluster-drain-nodegroup ng-new-1" "${ACTION_LOG}"
  grep -q "cluster-drain-nodegroup ng-new-2" "${ACTION_LOG}"
  ! grep -q "ng-old-1" "${ACTION_LOG}"
}

@test "cluster-locksize-new-nodegroups: only locksizes new nodegroups" {
  run bash "${SCRIPTS_DIR}/cluster-locksize-new-nodegroups"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "cluster-locksize-nodegroup" "${ACTION_LOG}") -eq 2 ]]
  grep -q "cluster-locksize-nodegroup ng-new-1" "${ACTION_LOG}"
  grep -q "cluster-locksize-nodegroup ng-new-2" "${ACTION_LOG}"
  ! grep -q "ng-old-1" "${ACTION_LOG}"
}

@test "cluster-unlocksize-new-nodegroups: only unlocksizes new nodegroups" {
  run bash "${SCRIPTS_DIR}/cluster-unlocksize-new-nodegroups"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "cluster-unlocksize-nodegroup" "${ACTION_LOG}") -eq 2 ]]
  grep -q "cluster-unlocksize-nodegroup ng-new-1" "${ACTION_LOG}"
  grep -q "cluster-unlocksize-nodegroup ng-new-2" "${ACTION_LOG}"
  ! grep -q "ng-old-1" "${ACTION_LOG}"
}

@test "cluster-list-nodes-for-new-nodegroups: only lists new nodegroup nodes" {
  run bash "${SCRIPTS_DIR}/cluster-list-nodes-for-new-nodegroups"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ $(grep -c "kubectl" "${ACTION_LOG}") -eq 2 ]]
  grep -q "ng-new-1" "${ACTION_LOG}"
  grep -q "ng-new-2" "${ACTION_LOG}"
  ! grep -q "ng-old-1" "${ACTION_LOG}"
}

# ====================================================================
# Confirmation behaviour
# ====================================================================

@test "cluster-delete-old-nodegroups: shows list and proceeds when confirmed" {
  run bash -c "echo 'yes' | bash '${SCRIPTS_DIR}/cluster-delete-old-nodegroups'"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Will delete the following 1 old nodegroup(s) not defined in cluster.yaml:"* ]]
  [[ "${output}" == *"ng-old-1"* ]]
  [[ "${output}" == *"Deleted 1 old nodegroup(s)."* ]]
  grep -q "cluster-delete-nodegroup ng-old-1" "${ACTION_LOG}"
}

@test "cluster-delete-old-nodegroups: aborts when confirmation denied" {
  run bash -c "echo 'no' | bash '${SCRIPTS_DIR}/cluster-delete-old-nodegroups'"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Aborted."* ]]
  ! grep -q "cluster-delete-nodegroup" "${ACTION_LOG}"
}

@test "cluster-delete-new-nodegroups: shows list and proceeds when confirmed" {
  run bash -c "echo 'yes' | bash '${SCRIPTS_DIR}/cluster-delete-new-nodegroups'"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Will delete the following 2 new nodegroup(s) defined in cluster.yaml:"* ]]
  [[ "${output}" == *"ng-new-1"* ]]
  [[ "${output}" == *"ng-new-2"* ]]
  [[ "${output}" == *"Deleted 2 new nodegroup(s)."* ]]
  grep -q "cluster-delete-nodegroup ng-new-1" "${ACTION_LOG}"
  grep -q "cluster-delete-nodegroup ng-new-2" "${ACTION_LOG}"
}

@test "cluster-delete-new-nodegroups: aborts when confirmation denied" {
  run bash -c "echo 'no' | bash '${SCRIPTS_DIR}/cluster-delete-new-nodegroups'"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Aborted."* ]]
  ! grep -q "cluster-delete-nodegroup" "${ACTION_LOG}"
}
