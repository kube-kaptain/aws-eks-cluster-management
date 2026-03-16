#!/usr/bin/env bats
# Integration test for cluster-delete-addons
#
# Mocks eksctl and cluster-delete-addon to prove the script
# incorrectly deletes configured addons.

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

  # Mock eksctl: returns the same 5 addons plus one extra
  cat > "${BATS_TEST_TMPDIR}/bin/eksctl" <<'MOCK'
#!/usr/bin/env bash
# Only handle "get addons --cluster ... -o yaml"
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
}

@test "cluster-delete-addons: should only delete addons NOT in cluster.yaml" {
  run bash "${SCRIPTS_DIR}/cluster-delete-addons"
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
  run bash "${SCRIPTS_DIR}/cluster-delete-addons"
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
