#!/usr/bin/env bats
# Integration tests for cluster-{create,delete,upgrade,list}-pod-identit*
#
# Mocks aws CLI to verify plan computation, tag filter, flag handling,
# and the three-mode UX (default-prompt / --yes / --dry-run).

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)"

setup() {
  export CLUSTER_CONFIG="${BATS_TEST_TMPDIR}/cluster.yaml"
  export CLUSTER_SCRIPT_DIR="${BATS_TEST_TMPDIR}/scripts"
  export IAM_ROLE_POLICY_DIR="${BATS_TEST_TMPDIR}/iam"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"

  mkdir -p "${BATS_TEST_TMPDIR}/bin" "${CLUSTER_SCRIPT_DIR}" "${IAM_ROLE_POLICY_DIR}"

  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
iam:
  podIdentityAssociations:
    - namespace: kong-system
      serviceAccountName: kong-ingress
      roleARN: arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: kong
addons:
  - name: eks-pod-identity-agent
    version: latest
YAML

  cat > "${IAM_ROLE_POLICY_DIR}/kong.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::example-bucket/*"
  }]
}
JSON

  export AWS_LOG="${BATS_TEST_TMPDIR}/aws-calls.log"
  : > "${AWS_LOG}"

  # Default mock state: cluster has eks-pod-identity-agent addon
  # (so the Cilium controlplane-only check passes). Per-test setups
  # overwrite AWS_MOCK_STATE_FILE to add specific matchers; this default
  # is used when a test doesn't override.
  export AWS_MOCK_STATE_FILE="${BATS_TEST_TMPDIR}/aws-state.yaml"
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json:
    addons:
      - eks-pod-identity-agent
YAML

  cat > "${BATS_TEST_TMPDIR}/bin/aws" <<'MOCK'
#!/usr/bin/env bash
# AWS mock. See `AWS mock contract` in PodIdentityRuntimeScriptsPlan.md.
#
# - Records joined argv to ${AWS_LOG}.
# - Iterates matchers in ${AWS_MOCK_STATE_FILE} (a YAML list).
# - First matcher whose `match` field appears as a substring in joined
#   argv wins. Tests put specific matchers first.
# - Emits stdout_json (re-encoded as JSON) and stderr, exits with `exit`
#   (default 0). No match -> exit 0 with stdout `{}`.
echo "$*" >> "${AWS_LOG}"

state_file="${AWS_MOCK_STATE_FILE:-}"
if [[ -z "${state_file}" || ! -f "${state_file}" ]]; then
  echo "{}"
  exit 0
fi

argv_str="$*"
n=$(yq 'length' "${state_file}")
i=0
while [[ "$i" -lt "$n" ]]; do
  pattern=$(yq ".[$i].match" "${state_file}")
  if [[ "${argv_str}" == *"${pattern}"* ]]; then
    exit_code=$(yq ".[$i].exit // 0" "${state_file}")
    stderr_msg=$(yq ".[$i].stderr // \"\"" "${state_file}")
    has_stdout=$(yq ".[$i] | has(\"stdout_json\")" "${state_file}")
    if [[ -n "${stderr_msg}" && "${stderr_msg}" != "null" ]]; then
      echo "${stderr_msg}" >&2
    fi
    if [[ "${has_stdout}" == "true" ]]; then
      yq -o=json ".[$i].stdout_json" "${state_file}"
    else
      echo "{}"
    fi
    exit "${exit_code}"
  fi
  i=$((i+1))
done

# No matcher hit. Safe default for read calls.
echo "{}"
exit 0
MOCK
  chmod +x "${BATS_TEST_TMPDIR}/bin/aws"
}

# Helper: append matchers to AWS_MOCK_STATE_FILE. Tests call this to
# layer specific behaviour on top of the default (which already provides
# the eks-pod-identity-agent addon for the Cilium check).
add_aws_matcher() {
  cat >> "${AWS_MOCK_STATE_FILE}"
}

# ====================================================================
# Mock contract smoke tests
# ====================================================================

@test "pod-identity mock: setup directories and files exist" {
  [[ -d "${IAM_ROLE_POLICY_DIR}" ]] || return 1
  [[ -f "${CLUSTER_CONFIG}" ]] || return 1
  [[ -x "${BATS_TEST_TMPDIR}/bin/aws" ]] || return 1
  [[ -f "${AWS_MOCK_STATE_FILE}" ]] || return 1
}

@test "pod-identity mock: unknown call returns empty JSON, exits 0" {
  run aws sts get-caller-identity
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == "{}" ]] || return 1
  grep -q "sts get-caller-identity" "${AWS_LOG}"
}

@test "pod-identity mock: substring matcher returns canned stdout" {
  run aws eks list-addons --cluster-name test-cluster --output json
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"eks-pod-identity-agent"* ]] || return 1
}

@test "pod-identity mock: matcher exit code propagates" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "iam get-role --role-name missing-role"
  exit: 254
  stderr: "An error occurred (NoSuchEntity) when calling GetRole"
YAML
  run aws iam get-role --role-name missing-role
  [[ "${status}" -eq 254 ]] || return 1
  [[ "${stderr:-}" == *"NoSuchEntity"* ]] || [[ "${output}" == *"NoSuchEntity"* ]] || return 1
}

@test "pod-identity mock: more specific matcher beats general one when listed first" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "iam get-role --role-name special"
  stdout_json:
    Role:
      Arn: arn:aws:iam::123:role/special
- match: "iam get-role"
  stdout_json:
    Role:
      Arn: arn:aws:iam::123:role/generic
YAML
  run aws iam get-role --role-name special
  [[ "${output}" == *"role/special"* ]] || return 1
  run aws iam get-role --role-name other
  [[ "${output}" == *"role/generic"* ]] || return 1
}

# ====================================================================
# cluster-list-pod-identities
# ====================================================================

@test "cluster-list-pod-identities: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-pod-identities" bogus
  [[ "${status}" -eq 1 ]] || return 1
}

@test "cluster-list-pod-identities: empty declared + empty live -> two table headers" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
YAML

  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations: []
- match: "resourcegroupstaggingapi get-resources"
  stdout_json:
    ResourceTagMappingList: []
YAML

  run bash "${SCRIPTS_DIR}/cluster-list-pod-identities"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"Pod Identity Associations for cluster 'test-cluster'"* ]] || return 1
  [[ "${output}" == *"KEY"*"STATUS"*"DECL"*"LIVE-ID"*"NS"*"SA"*"ROLE"* ]] || return 1
  [[ "${output}" == *"Pod Identity Roles for cluster 'test-cluster'"* ]] || return 1
  [[ "${output}" == *"NAME"*"STATUS"*"TYPE"*"DECL"*"TAG-KEY"*"REFS"*"POLICY"* ]] || return 1
}

@test "cluster-list-pod-identities: in-sync + foreign + external + orphan-role" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "iam list-role-tags --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Tags:
      - Key: kaptain.org/managed-by
        Value: test-cluster
      - Key: kaptain.org/association-key
        Value: kong

- match: "iam get-role-policy --role-name test-cluster-kong-system-kong-ingress --policy-name kaptain"
  stdout_json:
    PolicyDocument:
      Version: "2012-10-17"
      Statement:
        - Effect: Allow
          Action: s3:GetObject
          Resource: arn:aws:s3:::example-bucket/*

- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Role:
      Arn: arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress

- match: "iam list-role-tags --role-name other-cluster-role"
  stdout_json:
    Tags:
      - Key: kaptain.org/managed-by
        Value: other-cluster

- match: "iam get-role --role-name other-cluster-role"
  stdout_json:
    Role:
      Arn: arn:aws:iam::123:role/other-cluster-role

- match: "iam list-role-tags --role-name team-foo-app"
  stdout_json:
    Tags: []

- match: "iam get-role --role-name team-foo-app"
  stdout_json:
    Role:
      Arn: arn:aws:iam::123:role/team-foo-app

- match: "iam list-role-tags --role-name test-cluster-orphan"
  stdout_json:
    Tags:
      - Key: kaptain.org/managed-by
        Value: test-cluster
      - Key: kaptain.org/association-key
        Value: zombie

- match: "iam get-role --role-name test-cluster-orphan"
  stdout_json:
    Role:
      Arn: arn:aws:iam::123:role/test-cluster-orphan

- match: "--association-id a-pi-aaa"
  stdout_json:
    association:
      associationId: a-pi-aaa
      namespace: kong-system
      serviceAccount: kong-ingress
      roleArn: arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: kong

- match: "--association-id a-pi-bbb"
  stdout_json:
    association:
      associationId: a-pi-bbb
      namespace: kube-system
      serviceAccount: karpenter
      roleArn: arn:aws:iam::123:role/other-cluster-role
      tags:
        kaptain.org/managed-by: other-cluster

- match: "--association-id a-pi-ccc"
  stdout_json:
    association:
      associationId: a-pi-ccc
      namespace: default
      serviceAccount: some-sa
      roleArn: arn:aws:iam::123:role/team-foo-app
      tags: {}

- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - associationId: a-pi-aaa
      - associationId: a-pi-bbb
      - associationId: a-pi-ccc

- match: "resourcegroupstaggingapi get-resources"
  stdout_json:
    ResourceTagMappingList:
      - ResourceARN: arn:aws:iam::123:role/test-cluster-orphan
YAML

  run bash "${SCRIPTS_DIR}/cluster-list-pod-identities"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  # Declared kong association: in-sync, joined to a-pi-aaa, with live ns/sa
  [[ "${output}" == *"kong"*"in-sync"*"a-pi-aaa"*"kong-system"*"kong-ingress"* ]] || return 1
  # Foreign association (managed-by=other-cluster)
  [[ "${output}" == *"foreign"* ]] || return 1
  # External association (no kaptain tags at all)
  [[ "${output}" == *"a-pi-ccc"*"external"* ]] || return 1
  # Tag-searched ours-tagged role with no live association is an orphan role
  [[ "${output}" == *"test-cluster-orphan"*"orphan"* ]] || return 1
  # POLICY=match for the in-sync managed role
  [[ "${output}" == *"match"* ]] || return 1
}

@test "cluster-list-pod-identities: missing assoc + drift-policy with differs" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
iam:
  podIdentityAssociations:
    - namespace: kong-system
      serviceAccountName: kong-ingress
      roleARN: arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: kong
    - namespace: ns2
      serviceAccountName: sa2
      roleARN: arn:aws:iam::123:role/test-cluster-ns2-sa2
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: ghost
YAML
  cat > "${IAM_ROLE_POLICY_DIR}/ghost.json" <<'JSON'
{ "Version": "2012-10-17", "Statement": [] }
JSON

  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "iam list-role-tags --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Tags:
      - Key: kaptain.org/managed-by
        Value: test-cluster
      - Key: kaptain.org/association-key
        Value: kong

- match: "iam get-role-policy --role-name test-cluster-kong-system-kong-ingress --policy-name kaptain"
  stdout_json:
    PolicyDocument:
      Version: "2012-10-17"
      Statement:
        - Effect: Allow
          Action: s3:GetObject
          Resource: arn:aws:s3:::wrong-bucket/*

- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Role:
      Arn: arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress

- match: "iam get-role --role-name test-cluster-ns2-sa2"
  exit: 254
  stderr: "An error occurred (NoSuchEntity) when calling GetRole"

- match: "--association-id a-pi-aaa"
  stdout_json:
    association:
      associationId: a-pi-aaa
      namespace: kong-system
      serviceAccount: kong-ingress
      roleArn: arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: kong

- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - associationId: a-pi-aaa

- match: "resourcegroupstaggingapi get-resources"
  stdout_json:
    ResourceTagMappingList: []
YAML

  run bash "${SCRIPTS_DIR}/cluster-list-pod-identities"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  # Declared 'ghost' has no live association -> missing
  [[ "${output}" == *"ghost"*"missing"* ]] || return 1
  # Declared 'ghost' role not in IAM -> role row missing
  [[ "${output}" == *"test-cluster-ns2-sa2"*"missing"* ]] || return 1
  # Kong role policy in live differs from declared -> drift-policy / differs
  [[ "${output}" == *"drift-policy"* ]] || return 1
  [[ "${output}" == *"differs"* ]] || return 1
}

# ====================================================================
# cluster-create-pod-identity (singular)
# ====================================================================

@test "cluster-create-pod-identity: addon not declared -> graceful no-op" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
YAML
  run bash "${SCRIPTS_DIR}/cluster-create-pod-identity" kong --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"pod-identity-agent addon not declared in cluster.yaml"* ]] || return 1
  ! grep -E "(create-role|create-pod-identity-association)" "${AWS_LOG}"
}

@test "cluster-create-pod-identity: --dry-run prints plan and does not mutate" {
  cat >> "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  exit: 254
  stderr: "An error occurred (NoSuchEntity) when calling the GetRole operation"
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations: []
YAML

  run bash "${SCRIPTS_DIR}/cluster-create-pod-identity" kong --dry-run
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"Plan for pod-identity 'kong'"* ]] || return 1
  [[ "${output}" == *"create with trust on pods.eks.amazonaws.com"* ]] || return 1
  [[ "${output}" == *"Dry run complete"* ]] || return 1
  ! grep -E "(create-role|put-role-policy|create-pod-identity-association)" "${AWS_LOG}"
}

@test "cluster-create-pod-identity: --yes on fresh cluster executes the plan" {
  cat >> "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  exit: 254
  stderr: "An error occurred (NoSuchEntity) when calling the GetRole operation"
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations: []
YAML

  run bash "${SCRIPTS_DIR}/cluster-create-pod-identity" kong --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  grep -q "iam create-role" "${AWS_LOG}"
  grep -q "iam put-role-policy" "${AWS_LOG}"
  grep -q "eks create-pod-identity-association" "${AWS_LOG}"
}

@test "cluster-create-pod-identity: exact match no-ops" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json:
    addons:
      - eks-pod-identity-agent

- match: "iam list-role-tags --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Tags:
      - Key: kaptain.org/managed-by
        Value: test-cluster
      - Key: kaptain.org/association-key
        Value: kong

- match: "iam get-role-policy --role-name test-cluster-kong-system-kong-ingress --policy-name kaptain"
  stdout_json:
    PolicyDocument:
      Version: "2012-10-17"
      Statement:
        - Effect: Allow
          Action: s3:GetObject
          Resource: arn:aws:s3:::example-bucket/*

- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Role:
      Arn: arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress

- match: "--association-id a-pi-existing"
  stdout_json:
    association:
      associationId: a-pi-existing
      namespace: kong-system
      serviceAccount: kong-ingress
      roleArn: arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: kong

- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - associationId: a-pi-existing
        namespace: kong-system
        serviceAccount: kong-ingress
YAML

  run bash "${SCRIPTS_DIR}/cluster-create-pod-identity" kong --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"already in the desired state"* ]] || return 1
  ! grep -E "(create-role|put-role-policy|create-pod-identity-association)" "${AWS_LOG}"
}

@test "cluster-create-pod-identity: policy mismatch fails with directive to upgrade" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json:
    addons:
      - eks-pod-identity-agent

- match: "iam list-role-tags --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Tags:
      - Key: kaptain.org/managed-by
        Value: test-cluster
      - Key: kaptain.org/association-key
        Value: kong

- match: "iam get-role-policy --role-name test-cluster-kong-system-kong-ingress --policy-name kaptain"
  stdout_json:
    PolicyDocument:
      Version: "2012-10-17"
      Statement:
        - Effect: Allow
          Action: s3:GetObject
          Resource: arn:aws:s3:::wrong-bucket/*

- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Role:
      Arn: arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress

- match: "eks list-pod-identity-associations"
  stdout_json:
    associations: []
YAML

  run bash "${SCRIPTS_DIR}/cluster-create-pod-identity" kong --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -ne 0 ]] || return 1
  [[ "${output}${stderr:-}" == *"differs"* ]] || return 1
  [[ "${output}${stderr:-}" == *"cluster upgrade pod-identities"* ]] || return 1
}

@test "cluster-create-pod-identity: untagged role with our name -> refuses to touch" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json:
    addons:
      - eks-pod-identity-agent

- match: "iam list-role-tags --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Tags: []

- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Role:
      Arn: arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress

- match: "eks list-pod-identity-associations"
  stdout_json:
    associations: []
YAML

  run bash "${SCRIPTS_DIR}/cluster-create-pod-identity" kong --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -ne 0 ]] || return 1
  [[ "${output}${stderr:-}" == *"not tagged"* ]] || return 1
  [[ "${output}${stderr:-}" == *"managed-by"* ]] || return 1
  [[ "${output}${stderr:-}" == *"test-cluster"* ]] || return 1
}

# ====================================================================
# cluster-create-pod-identities (plural)
# ====================================================================

@test "cluster-create-pod-identities: --dry-run on fresh cluster prints combined plan, no mutation" {
  export CLUSTER_SCRIPT_DIR="${SCRIPTS_DIR}"
  cat >> "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  exit: 254
  stderr: "An error occurred (NoSuchEntity) when calling GetRole"
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations: []
YAML

  run bash "${SCRIPTS_DIR}/cluster-create-pod-identities" --dry-run
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"Combined plan:"* ]] || return 1
  [[ "${output}" == *"Plan for pod-identity 'kong'"* ]] || return 1
  [[ "${output}" == *"Dry run complete"* ]] || return 1
  ! grep -E "(create-role|create-pod-identity-association)" "${AWS_LOG}"
}

@test "cluster-create-pod-identities: all keys already match -> nothing to do" {
  export CLUSTER_SCRIPT_DIR="${SCRIPTS_DIR}"
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "iam list-role-tags --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Tags:
      - { Key: kaptain.org/managed-by, Value: test-cluster }
      - { Key: kaptain.org/association-key, Value: kong }
- match: "iam get-role-policy --role-name test-cluster-kong-system-kong-ingress --policy-name kaptain"
  stdout_json:
    PolicyDocument:
      Version: "2012-10-17"
      Statement:
        - { Effect: Allow, Action: s3:GetObject, Resource: "arn:aws:s3:::example-bucket/*" }
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  stdout_json: { Role: { Arn: "arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress" } }
- match: "--association-id a-pi-existing"
  stdout_json:
    association:
      associationId: a-pi-existing
      namespace: kong-system
      serviceAccount: kong-ingress
      roleArn: arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: kong
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - { associationId: a-pi-existing, namespace: kong-system, serviceAccount: kong-ingress }
YAML

  run bash "${SCRIPTS_DIR}/cluster-create-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"already in the desired state"* ]] || [[ "${output}" == *"Nothing to do"* ]] || return 1
  ! grep -E "(create-role|put-role-policy|create-pod-identity-association)" "${AWS_LOG}"
}

@test "cluster-create-pod-identities: collects per-key failures and exits non-zero" {
  export CLUSTER_SCRIPT_DIR="${SCRIPTS_DIR}"
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
iam:
  podIdentityAssociations:
    - namespace: kong-system
      serviceAccountName: kong-ingress
      roleARN: arn:aws:iam::123:role/test-cluster-kong-system-kong-ingress
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: kong
    - namespace: kube-system
      serviceAccountName: karpenter
      roleARN: arn:aws:iam::123:role/test-cluster-kube-system-karpenter
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: karpenter
addons:
  - name: eks-pod-identity-agent
    version: latest
YAML
  cat > "${IAM_ROLE_POLICY_DIR}/kong.json"      <<<'{"Version":"2012-10-17","Statement":[]}'
  cat > "${IAM_ROLE_POLICY_DIR}/karpenter.json" <<<'{"Version":"2012-10-17","Statement":[]}'

  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "iam list-role-tags --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Tags:
      - { Key: kaptain.org/managed-by, Value: test-cluster }
      - { Key: kaptain.org/association-key, Value: kong }
- match: "iam get-role-policy --role-name test-cluster-kong-system-kong-ingress --policy-name kaptain"
  stdout_json:
    PolicyDocument: { Version: "2012-10-17", Statement: [{ Effect: Allow, Action: "*", Resource: "*" }] }
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  stdout_json: { Role: { Arn: "arn:aws:iam::123:role/test-cluster-kong-system-kong-ingress" } }
- match: "iam get-role --role-name test-cluster-kube-system-karpenter"
  exit: 254
  stderr: "NoSuchEntity"
- match: "eks list-pod-identity-associations"
  stdout_json: { associations: [] }
YAML

  run bash "${SCRIPTS_DIR}/cluster-create-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -ne 0 ]] || return 1
  [[ "${output}${stderr:-}" == *"kong"* ]] || return 1
}

# ====================================================================
# cluster-delete-pod-identity (singular)
# ====================================================================

@test "cluster-delete-pod-identity: --dry-run plans full wipe, no mutation" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "--association-id a-pi-kong"
  stdout_json:
    association:
      associationId: a-pi-kong
      namespace: kong-system
      serviceAccount: kong-ingress
      roleArn: arn:aws:iam::123:role/test-cluster-kong-system-kong-ingress
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: kong
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - { associationId: a-pi-kong, namespace: kong-system, serviceAccount: kong-ingress }
- match: "iam list-role-tags --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Tags:
      - { Key: kaptain.org/managed-by, Value: test-cluster }
      - { Key: kaptain.org/association-key, Value: kong }
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  stdout_json: { Role: { Arn: "arn:aws:iam::123:role/test-cluster-kong-system-kong-ingress" } }
YAML

  run bash "${SCRIPTS_DIR}/cluster-delete-pod-identity" kong --dry-run
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"delete association a-pi-kong"* ]] || return 1
  [[ "${output}" == *"delete IAM role"* ]] || return 1
  ! grep -E "(delete-pod-identity-association|delete-role)" "${AWS_LOG}"
}

@test "cluster-delete-pod-identity: refuses to delete association tagged other-cluster" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "--association-id a-pi-kong"
  stdout_json:
    association:
      associationId: a-pi-kong
      namespace: kong-system
      serviceAccount: kong-ingress
      roleArn: arn:aws:iam::123:role/external-kong
      tags:
        kaptain.org/managed-by: other-cluster
        kaptain.org/association-key: kong
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - { associationId: a-pi-kong, namespace: kong-system, serviceAccount: kong-ingress }
YAML

  run bash "${SCRIPTS_DIR}/cluster-delete-pod-identity" kong --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"not found on cluster"* ]] || [[ "${output}" == *"Nothing to delete"* ]] || return 1
  ! grep -E "(delete-pod-identity-association|delete-role)" "${AWS_LOG}"
}

@test "cluster-delete-pod-identity: orphan role from failed prior run gets cleaned up" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "eks list-pod-identity-associations"
  stdout_json: { associations: [] }
- match: "iam list-role-tags --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Tags:
      - { Key: kaptain.org/managed-by, Value: test-cluster }
      - { Key: kaptain.org/association-key, Value: kong }
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  stdout_json: { Role: { Arn: "arn:aws:iam::123:role/test-cluster-kong-system-kong-ingress" } }
YAML

  run bash "${SCRIPTS_DIR}/cluster-delete-pod-identity" kong --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  ! grep -E "delete-pod-identity-association" "${AWS_LOG}"
  grep -q "iam delete-role-policy" "${AWS_LOG}"
  grep -q "iam delete-role" "${AWS_LOG}"
}

@test "cluster-delete-pod-identity: nothing matches by key -> no-op" {
  run bash "${SCRIPTS_DIR}/cluster-delete-pod-identity" nonexistent --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"not found on cluster"* ]] || [[ "${output}" == *"Nothing to delete"* ]] || return 1
}

@test "cluster-delete-pod-identity: orphan role found only by tag-search gets cleaned up" {
  # Cluster.yaml has no entry for 'kong' and no live association references it;
  # only the resourcegroupstaggingapi tag-search surfaces the orphan role.
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
addons:
  - name: eks-pod-identity-agent
    version: latest
YAML

  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "eks list-pod-identity-associations"
  stdout_json: { associations: [] }
- match: "resourcegroupstaggingapi get-resources"
  stdout_json:
    ResourceTagMappingList:
      - ResourceARN: "arn:aws:iam::123:role/test-cluster-orphan-kong-role"
- match: "iam get-role --role-name test-cluster-orphan-kong-role"
  stdout_json: { Role: { Arn: "arn:aws:iam::123:role/test-cluster-orphan-kong-role" } }
- match: "iam list-role-tags --role-name test-cluster-orphan-kong-role"
  stdout_json:
    Tags:
      - { Key: kaptain.org/managed-by, Value: test-cluster }
      - { Key: kaptain.org/association-key, Value: kong }
YAML

  run bash "${SCRIPTS_DIR}/cluster-delete-pod-identity" kong --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  ! grep -E "delete-pod-identity-association" "${AWS_LOG}"
  grep -q "iam delete-role-policy --role-name test-cluster-orphan-kong-role" "${AWS_LOG}"
  grep -q "iam delete-role --role-name test-cluster-orphan-kong-role" "${AWS_LOG}"
}

# ====================================================================
# cluster-delete-pod-identities (plural)
# ====================================================================

@test "cluster-delete-pod-identities: empty live state -> no drift" {
  export CLUSTER_SCRIPT_DIR="${SCRIPTS_DIR}"
  cat >> "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-pod-identity-associations"
  stdout_json: { associations: [] }
- match: "resourcegroupstaggingapi get-resources"
  stdout_json: { ResourceTagMappingList: [] }
YAML
  run bash "${SCRIPTS_DIR}/cluster-delete-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"No drift found"* ]] || return 1
}

@test "cluster-delete-pod-identities: refuses if iam.podIdentityAssociations section missing" {
  export CLUSTER_SCRIPT_DIR="${SCRIPTS_DIR}"
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
metadata: { name: test-cluster, region: eu-west-1 }
addons:
  - name: eks-pod-identity-agent
    version: latest
YAML
  run bash "${SCRIPTS_DIR}/cluster-delete-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"cannot determine what to keep"* ]] || return 1
  ! grep -E "(delete-pod-identity-association|delete-role)" "${AWS_LOG}"
}

@test "cluster-delete-pod-identities: refuses if iam.podIdentityAssociations empty" {
  export CLUSTER_SCRIPT_DIR="${SCRIPTS_DIR}"
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
metadata: { name: test-cluster, region: eu-west-1 }
iam:
  podIdentityAssociations: []
addons:
  - name: eks-pod-identity-agent
    version: latest
YAML
  run bash "${SCRIPTS_DIR}/cluster-delete-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"cannot determine what to keep"* ]] || return 1
  ! grep -E "(delete-pod-identity-association|delete-role)" "${AWS_LOG}"
}

@test "cluster-delete-pod-identities: deletes only ours-tagged, ignores other-cluster" {
  export CLUSTER_SCRIPT_DIR="${SCRIPTS_DIR}"
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "--association-id a-pi-ours"
  stdout_json:
    association:
      associationId: a-pi-ours
      namespace: ns
      serviceAccount: sa
      roleArn: arn:aws:iam::123:role/test-cluster-ns-sa
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: app
- match: "--association-id a-pi-other"
  stdout_json:
    association:
      associationId: a-pi-other
      namespace: ns2
      serviceAccount: sa2
      roleArn: arn:aws:iam::123:role/external
      tags:
        kaptain.org/managed-by: other-cluster
        kaptain.org/association-key: x
- match: "iam list-role-tags --role-name test-cluster-ns-sa"
  stdout_json:
    Tags:
      - { Key: kaptain.org/managed-by, Value: test-cluster }
      - { Key: kaptain.org/association-key, Value: app }
- match: "iam get-role --role-name test-cluster-ns-sa"
  stdout_json: { Role: { Arn: "arn:aws:iam::123:role/test-cluster-ns-sa" } }
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - { associationId: a-pi-ours, namespace: ns, serviceAccount: sa }
      - { associationId: a-pi-other, namespace: ns2, serviceAccount: sa2 }
YAML
  run bash "${SCRIPTS_DIR}/cluster-delete-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  grep -q "eks delete-pod-identity-association --cluster-name test-cluster --association-id a-pi-ours" "${AWS_LOG}"
  ! grep -E "(delete-pod-identity-association.*a-pi-other|delete-role.*external)" "${AWS_LOG}"
}

@test "cluster-delete-pod-identities: --dry-run lists deletions, no mutation" {
  export CLUSTER_SCRIPT_DIR="${SCRIPTS_DIR}"
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "--association-id a-pi-ours"
  stdout_json:
    association:
      associationId: a-pi-ours
      namespace: ns
      serviceAccount: sa
      roleArn: arn:aws:iam::123:role/external-role
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: app
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - { associationId: a-pi-ours, namespace: ns, serviceAccount: sa }
YAML
  run bash "${SCRIPTS_DIR}/cluster-delete-pod-identities" --dry-run
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"a-pi-ours"* ]] || return 1
  [[ "${output}" == *"Dry run complete"* ]] || return 1
  ! grep -E "(delete-pod-identity-association|delete-role)" "${AWS_LOG}"
}

@test "cluster-delete-pod-identities: unkeyed association is drift -> direct delete" {
  export CLUSTER_SCRIPT_DIR="${SCRIPTS_DIR}"
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "--association-id a-pi-partial"
  stdout_json:
    association:
      associationId: a-pi-partial
      namespace: ns
      serviceAccount: sa
      roleArn: arn:aws:iam::123:role/whatever
      tags:
        kaptain.org/managed-by: test-cluster
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - { associationId: a-pi-partial, namespace: ns, serviceAccount: sa }
- match: "resourcegroupstaggingapi get-resources"
  stdout_json: { ResourceTagMappingList: [] }
YAML
  run bash "${SCRIPTS_DIR}/cluster-delete-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"missing association-key"* ]] || return 1
  grep -q "eks delete-pod-identity-association --cluster-name test-cluster --association-id a-pi-partial" "${AWS_LOG}"
}

@test "cluster-delete-pod-identities: orphan role found by tag-search (no association) -> direct delete" {
  export CLUSTER_SCRIPT_DIR="${SCRIPTS_DIR}"
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "eks list-pod-identity-associations"
  stdout_json: { associations: [] }
- match: "iam list-role-tags --role-name test-cluster-orphan-unkeyed"
  stdout_json:
    Tags:
      - { Key: kaptain.org/managed-by, Value: test-cluster }
- match: "resourcegroupstaggingapi get-resources"
  stdout_json:
    ResourceTagMappingList:
      - ResourceARN: "arn:aws:iam::123:role/test-cluster-orphan-unkeyed"
YAML
  run bash "${SCRIPTS_DIR}/cluster-delete-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"IAM roles tagged managed-by but missing association-key"* ]] || return 1
  grep -q "iam delete-role-policy --role-name test-cluster-orphan-unkeyed --policy-name kaptain" "${AWS_LOG}"
  grep -q "iam delete-role --role-name test-cluster-orphan-unkeyed" "${AWS_LOG}"
}

@test "cluster-delete-pod-identities: declared key is kept, drift key is deleted" {
  export CLUSTER_SCRIPT_DIR="${SCRIPTS_DIR}"
  # cluster.yaml declares kong; live has kong (keep) + drift-key (delete).
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "--association-id a-pi-kong"
  stdout_json:
    association:
      associationId: a-pi-kong
      namespace: kong-system
      serviceAccount: kong-ingress
      roleArn: arn:aws:iam::123:role/test-cluster-kong-system-kong-ingress
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: kong
- match: "--association-id a-pi-drift"
  stdout_json:
    association:
      associationId: a-pi-drift
      namespace: ns
      serviceAccount: sa
      roleArn: arn:aws:iam::123:role/test-cluster-drifted
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: drifted
- match: "iam list-role-tags --role-name test-cluster-drifted"
  stdout_json:
    Tags:
      - { Key: kaptain.org/managed-by, Value: test-cluster }
      - { Key: kaptain.org/association-key, Value: drifted }
- match: "iam get-role --role-name test-cluster-drifted"
  stdout_json: { Role: { Arn: "arn:aws:iam::123:role/test-cluster-drifted" } }
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - { associationId: a-pi-kong, namespace: kong-system, serviceAccount: kong-ingress }
      - { associationId: a-pi-drift, namespace: ns, serviceAccount: sa }
- match: "resourcegroupstaggingapi get-resources"
  stdout_json: { ResourceTagMappingList: [] }
YAML
  run bash "${SCRIPTS_DIR}/cluster-delete-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  grep -q "eks delete-pod-identity-association --cluster-name test-cluster --association-id a-pi-drift" "${AWS_LOG}"
  ! grep -E "delete-pod-identity-association.*a-pi-kong" "${AWS_LOG}"
  ! grep -E "delete-role.*kong-system-kong-ingress" "${AWS_LOG}"
}

# ====================================================================
# cluster-upgrade-pod-identities (full reconcile)
# ====================================================================

@test "cluster-upgrade-pod-identities: addon not declared -> graceful no-op" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: test-cluster
  region: eu-west-1
YAML
  run bash "${SCRIPTS_DIR}/cluster-upgrade-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"pod-identity-agent addon not declared in cluster.yaml"* ]] || return 1
}

@test "cluster-upgrade-pod-identities: empty declared + empty cluster -> no-op" {
  cat > "${CLUSTER_CONFIG}" <<'YAML'
apiVersion: eksctl.io/v1alpha5
metadata: { name: test-cluster, region: eu-west-1 }
addons:
  - name: eks-pod-identity-agent
    version: latest
YAML
  cat >> "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-pod-identity-associations"
  stdout_json: { associations: [] }
YAML

  run bash "${SCRIPTS_DIR}/cluster-upgrade-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"Nothing to do"* ]] || [[ "${output}" == *"already in the desired state"* ]] || return 1
}

@test "cluster-upgrade-pod-identities: declared not in cluster -> Phase 1 + Phase 2 create" {
  cat >> "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  exit: 254
  stderr: "NoSuchEntity"
- match: "eks list-pod-identity-associations"
  stdout_json: { associations: [] }
YAML

  run bash "${SCRIPTS_DIR}/cluster-upgrade-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  grep -q "iam create-role" "${AWS_LOG}"
  grep -q "iam put-role-policy" "${AWS_LOG}"
  grep -q "eks create-pod-identity-association" "${AWS_LOG}"
  cr_line=$(grep -n "iam create-role" "${AWS_LOG}" | head -1 | cut -d: -f1)
  ca_line=$(grep -n "eks create-pod-identity-association" "${AWS_LOG}" | head -1 | cut -d: -f1)
  [[ "${cr_line}" -lt "${ca_line}" ]] || return 1
}

@test "cluster-upgrade-pod-identities: role policy drift -> atomic PutRolePolicy (no delete-role)" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "iam list-role-tags --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Tags:
      - { Key: kaptain.org/managed-by, Value: test-cluster }
      - { Key: kaptain.org/association-key, Value: kong }
- match: "iam get-role-policy --role-name test-cluster-kong-system-kong-ingress --policy-name kaptain"
  stdout_json:
    PolicyDocument:
      Version: "2012-10-17"
      Statement: [{ Effect: Allow, Action: "*", Resource: "*" }]
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  stdout_json: { Role: { Arn: "arn:aws:iam::123:role/test-cluster-kong-system-kong-ingress" } }
- match: "--association-id a-pi-kong"
  stdout_json:
    association:
      associationId: a-pi-kong
      namespace: kong-system
      serviceAccount: kong-ingress
      roleArn: arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: kong
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - { associationId: a-pi-kong, namespace: kong-system, serviceAccount: kong-ingress }
YAML

  run bash "${SCRIPTS_DIR}/cluster-upgrade-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  grep -q "iam put-role-policy" "${AWS_LOG}"
  ! grep -q "iam delete-role" "${AWS_LOG}"
  ! grep -q "iam create-role " "${AWS_LOG}"
}

@test "cluster-upgrade-pod-identities: Phase 2 drift -> delete-and-recreate association" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "iam list-role-tags --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Tags:
      - { Key: kaptain.org/managed-by, Value: test-cluster }
      - { Key: kaptain.org/association-key, Value: kong }
- match: "iam get-role-policy --role-name test-cluster-kong-system-kong-ingress --policy-name kaptain"
  stdout_json:
    PolicyDocument:
      Version: "2012-10-17"
      Statement:
        - { Effect: Allow, Action: s3:GetObject, Resource: "arn:aws:s3:::example-bucket/*" }
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  stdout_json: { Role: { Arn: "arn:aws:iam::123456789012:role/test-cluster-kong-system-kong-ingress" } }
- match: "--association-id a-pi-kong"
  stdout_json:
    association:
      associationId: a-pi-kong
      namespace: kong-system
      serviceAccount: kong-ingress
      roleArn: arn:aws:iam::123456789012:role/OLD-role-name
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: kong
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - { associationId: a-pi-kong, namespace: kong-system, serviceAccount: kong-ingress }
YAML

  run bash "${SCRIPTS_DIR}/cluster-upgrade-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  grep -q "eks delete-pod-identity-association --cluster-name test-cluster --association-id a-pi-kong" "${AWS_LOG}"
  grep -q "eks create-pod-identity-association --cluster-name test-cluster --namespace kong-system --service-account kong-ingress" "${AWS_LOG}"
  del_line=$(grep -n "eks delete-pod-identity-association" "${AWS_LOG}" | head -1 | cut -d: -f1)
  cre_line=$(grep -n "eks create-pod-identity-association" "${AWS_LOG}" | head -1 | cut -d: -f1)
  [[ "${del_line}" -lt "${cre_line}" ]] || return 1
}

@test "cluster-upgrade-pod-identities: Phase 3 deletes ours-tagged association no longer declared" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "iam list-role-tags --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Tags:
      - { Key: kaptain.org/managed-by, Value: test-cluster }
      - { Key: kaptain.org/association-key, Value: kong }
- match: "iam get-role-policy --role-name test-cluster-kong-system-kong-ingress --policy-name kaptain"
  stdout_json:
    PolicyDocument:
      Version: "2012-10-17"
      Statement: [{ Effect: Allow, Action: s3:GetObject, Resource: "arn:aws:s3:::example-bucket/*" }]
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  stdout_json: { Role: { Arn: "arn:aws:iam::123:role/test-cluster-kong-system-kong-ingress" } }
- match: "iam list-role-tags --role-name test-cluster-old-ns-old-sa"
  stdout_json:
    Tags:
      - { Key: kaptain.org/managed-by, Value: test-cluster }
      - { Key: kaptain.org/association-key, Value: old-app }
- match: "iam get-role --role-name test-cluster-old-ns-old-sa"
  stdout_json: { Role: { Arn: "arn:aws:iam::123:role/test-cluster-old-ns-old-sa" } }
- match: "--association-id a-pi-kong"
  stdout_json:
    association:
      associationId: a-pi-kong
      namespace: kong-system
      serviceAccount: kong-ingress
      roleArn: arn:aws:iam::123:role/test-cluster-kong-system-kong-ingress
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: kong
- match: "--association-id a-pi-old"
  stdout_json:
    association:
      associationId: a-pi-old
      namespace: old-ns
      serviceAccount: old-sa
      roleArn: arn:aws:iam::123:role/test-cluster-old-ns-old-sa
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: old-app
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - { associationId: a-pi-kong, namespace: kong-system, serviceAccount: kong-ingress }
      - { associationId: a-pi-old, namespace: old-ns, serviceAccount: old-sa }
YAML

  run bash "${SCRIPTS_DIR}/cluster-upgrade-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  grep -q "eks delete-pod-identity-association --cluster-name test-cluster --association-id a-pi-old" "${AWS_LOG}"
  grep -q "iam delete-role --role-name test-cluster-old-ns-old-sa" "${AWS_LOG}"
  ! grep -q "eks delete-pod-identity-association --cluster-name test-cluster --association-id a-pi-kong" "${AWS_LOG}"
  ! grep -q "iam delete-role --role-name test-cluster-kong-system-kong-ingress" "${AWS_LOG}"
}

@test "cluster-upgrade-pod-identities: Phase 3 ignores other-cluster-tagged assocations" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "--association-id a-pi-other"
  stdout_json:
    association:
      associationId: a-pi-other
      namespace: ns
      serviceAccount: sa
      roleArn: arn:aws:iam::123:role/other-cluster-role
      tags:
        kaptain.org/managed-by: other-cluster
        kaptain.org/association-key: other-key
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  exit: 254
  stderr: "NoSuchEntity"
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - { associationId: a-pi-other, namespace: ns, serviceAccount: sa }
YAML

  run bash "${SCRIPTS_DIR}/cluster-upgrade-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  ! grep -q "eks delete-pod-identity-association.*a-pi-other" "${AWS_LOG}"
}

@test "cluster-upgrade-pod-identities: Phase 3 partial-tag -> drift cleanup (delete)" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "--association-id a-pi-partial"
  stdout_json:
    association:
      associationId: a-pi-partial
      namespace: ns
      serviceAccount: sa
      roleArn: arn:aws:iam::123:role/something
      tags:
        kaptain.org/managed-by: test-cluster
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  exit: 254
  stderr: "NoSuchEntity"
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - { associationId: a-pi-partial, namespace: ns, serviceAccount: sa }
- match: "resourcegroupstaggingapi get-resources"
  stdout_json: { ResourceTagMappingList: [] }
YAML

  run bash "${SCRIPTS_DIR}/cluster-upgrade-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"partial-tagged"* ]] || return 1
  grep -q "eks delete-pod-identity-association --cluster-name test-cluster --association-id a-pi-partial" "${AWS_LOG}"
}

@test "cluster-upgrade-pod-identities: Phase 3 tag-search finds orphan role and deletes it" {
  cat > "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "eks list-addons"
  stdout_json: { addons: [eks-pod-identity-agent] }
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  stdout_json: { Role: { Arn: "arn:aws:iam::123:role/test-cluster-kong-system-kong-ingress" } }
- match: "iam list-role-tags --role-name test-cluster-kong-system-kong-ingress"
  stdout_json:
    Tags:
      - { Key: kaptain.org/managed-by, Value: test-cluster }
      - { Key: kaptain.org/association-key, Value: kong }
- match: "iam get-role-policy --role-name test-cluster-kong-system-kong-ingress --policy-name kaptain"
  stdout_json:
    PolicyDocument:
      Version: "2012-10-17"
      Statement:
        - { Effect: Allow, Action: "s3:GetObject", Resource: "arn:aws:s3:::example-bucket/*" }
- match: "eks list-pod-identity-associations"
  stdout_json:
    associations:
      - { associationId: a-pi-kong, namespace: kong-system, serviceAccount: kong-ingress }
- match: "--association-id a-pi-kong"
  stdout_json:
    association:
      associationId: a-pi-kong
      namespace: kong-system
      serviceAccount: kong-ingress
      roleArn: arn:aws:iam::123:role/test-cluster-kong-system-kong-ingress
      tags:
        kaptain.org/managed-by: test-cluster
        kaptain.org/association-key: kong
- match: "resourcegroupstaggingapi get-resources"
  stdout_json:
    ResourceTagMappingList:
      - ResourceARN: "arn:aws:iam::123:role/test-cluster-kong-system-kong-ingress"
      - ResourceARN: "arn:aws:iam::123:role/test-cluster-orphan-zombie"
YAML

  run bash "${SCRIPTS_DIR}/cluster-upgrade-pod-identities" --yes
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"orphan"* ]] || return 1
  grep -q "iam delete-role-policy --role-name test-cluster-orphan-zombie --policy-name kaptain" "${AWS_LOG}"
  grep -q "iam delete-role --role-name test-cluster-orphan-zombie" "${AWS_LOG}"
  ! grep -E "delete-role.*kong-system-kong-ingress" "${AWS_LOG}"
}

@test "cluster-upgrade-pod-identities: --dry-run lists all calls, executes none" {
  cat >> "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  exit: 254
  stderr: "NoSuchEntity"
- match: "eks list-pod-identity-associations"
  stdout_json: { associations: [] }
YAML
  run bash "${SCRIPTS_DIR}/cluster-upgrade-pod-identities" --dry-run
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"Dry run complete"* ]] || return 1
  ! grep -E "(create-role|put-role-policy|create-pod-identity-association|delete-role|delete-pod-identity-association)" "${AWS_LOG}"
}

@test "cluster-upgrade-pod-identities: default mode aborts on 'no'" {
  cat >> "${AWS_MOCK_STATE_FILE}" <<'YAML'
- match: "iam get-role --role-name test-cluster-kong-system-kong-ingress"
  exit: 254
  stderr: "NoSuchEntity"
- match: "eks list-pod-identity-associations"
  stdout_json: { associations: [] }
YAML
  run bash -c "echo no | '${SCRIPTS_DIR}/cluster-upgrade-pod-identities'"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]] || return 1
  [[ "${output}" == *"Aborted"* ]] || return 1
  ! grep -E "(create-role|create-pod-identity-association)" "${AWS_LOG}"
}
