#!/usr/bin/env bats
# Integration tests for k-* kubectl wrapper scripts
#
# Tests the yq processing in k-get-all-unstable-pods and k-get-all-stable-pods
# with mocked kubectl returning canned pod YAML. Also tests namespace
# shortcuts pass the correct namespace to kubectl.
#
# Pod data:
#   stable-app       Running, 1/1 ready, 0 restarts   → stable only
#   crashing-app     Running, 0/1 ready, 5 restarts    → unstable (not ready + restarts)
#   pending-app      Pending, no containerStatuses      → unstable (not Running)
#   completed-job    Succeeded, 0/1 ready, 0 restarts   → neither (excluded by both)
#   multi-restart-app Running, 2/2 ready, 3+2 restarts  → unstable (restarts sum)
#   multi-error-app  Failed, 0/3 ready, 3 reasons       → unstable (one STATUS field only)
#   initialising-app Pending, 0/2 ready, 2 reasons      → unstable (one STATUS field only)
#   no-timestamp-app Pending, no creationTimestamp      → unstable (age unparseable)

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)"

setup() {
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
  mkdir -p "${BATS_TEST_TMPDIR}/bin"

  # Mock date: avoids GNU date -d requirement on macOS. Rejects anything that is
  # not an RFC 3339 timestamp, exactly as GNU date does, so that tests exercise
  # the unparseable age path rather than silently accepting garbage.
  cat > "${BATS_TEST_TMPDIR}/bin/date" <<'MOCK'
#!/usr/bin/env bash
if [[ $# -eq 1 && "$1" == "+%s" ]]; then
  echo "1710720000"
elif [[ "$1" == "-d" ]]; then
  if [[ "$2" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    echo "1710633600"
  else
    echo "date: invalid date '$2'" >&2
    exit 1
  fi
fi
MOCK
  chmod +x "${BATS_TEST_TMPDIR}/bin/date"

  # Pod YAML returned by mock kubectl
  cat > "${BATS_TEST_TMPDIR}/pods.yaml" <<'YAML'
apiVersion: v1
kind: PodList
items:
  - metadata:
      namespace: default
      name: stable-app
      creationTimestamp: "2025-03-10T00:00:00Z"
    status:
      phase: Running
      containerStatuses:
        - name: main
          ready: true
          restartCount: 0
          state:
            running:
              startedAt: "2025-03-10T00:00:00Z"
  - metadata:
      namespace: default
      name: crashing-app
      creationTimestamp: "2025-03-10T00:00:00Z"
    status:
      phase: Running
      containerStatuses:
        - name: main
          ready: false
          restartCount: 5
          state:
            waiting:
              reason: CrashLoopBackOff
  - metadata:
      namespace: kube-system
      name: pending-app
      creationTimestamp: "2025-03-10T00:00:00Z"
    status:
      phase: Pending
  - metadata:
      namespace: default
      name: completed-job
      creationTimestamp: "2025-03-10T00:00:00Z"
    status:
      phase: Succeeded
      containerStatuses:
        - name: main
          ready: false
          restartCount: 0
          state:
            terminated:
              reason: Completed
  - metadata:
      namespace: default
      name: multi-restart-app
      creationTimestamp: "2025-03-10T00:00:00Z"
    status:
      phase: Running
      containerStatuses:
        - name: app
          ready: true
          restartCount: 3
          state:
            running:
              startedAt: "2025-03-10T00:00:00Z"
        - name: sidecar
          ready: true
          restartCount: 2
          state:
            running:
              startedAt: "2025-03-10T00:00:00Z"
  - metadata:
      namespace: batch
      name: multi-error-app
      creationTimestamp: "2025-03-10T00:00:00Z"
    status:
      phase: Failed
      containerStatuses:
        - name: main
          ready: false
          restartCount: 0
          state:
            terminated:
              reason: Error
        - name: sidecar
          ready: false
          restartCount: 0
          state:
            terminated:
              reason: Error
        - name: shipper
          ready: false
          restartCount: 0
          state:
            terminated:
              reason: Error
  - metadata:
      namespace: logging
      name: initialising-app
      creationTimestamp: "2025-03-10T00:00:00Z"
    status:
      phase: Pending
      containerStatuses:
        - name: main
          ready: false
          restartCount: 0
          state:
            waiting:
              reason: PodInitializing
        - name: sidecar
          ready: false
          restartCount: 0
          state:
            waiting:
              reason: ContainerCreating
  - metadata:
      namespace: default
      name: no-timestamp-app
    status:
      phase: Pending
YAML

  # Mock kubectl: returns pod YAML for get pods, echoes args for everything else
  cat > "${BATS_TEST_TMPDIR}/bin/kubectl" <<MOCK
#!/usr/bin/env bash
if [[ "\$*" == *"--all-namespaces -o yaml"* ]]; then
  cat "${BATS_TEST_TMPDIR}/pods.yaml"
else
  echo "kubectl \$*"
fi
MOCK
  chmod +x "${BATS_TEST_TMPDIR}/bin/kubectl"
}

# ====================================================================
# k-get-all-unstable-pods
# ====================================================================

@test "k-get-all-unstable-pods: shows unstable pods" {
  run bash "${SCRIPTS_DIR}/k-get-all-unstable-pods"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"crashing-app"* ]]
  [[ "${output}" == *"pending-app"* ]]
  [[ "${output}" == *"multi-restart-app"* ]]
}

@test "k-get-all-unstable-pods: excludes stable and completed pods" {
  run bash "${SCRIPTS_DIR}/k-get-all-unstable-pods"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" != *"stable-app"* ]]
  [[ "${output}" != *"completed-job"* ]]
}

@test "k-get-all-unstable-pods: reports correct count" {
  run bash "${SCRIPTS_DIR}/k-get-all-unstable-pods"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"6 unstable pod(s) found."* ]]
}

# Several containers reporting a state reason used to emit one STATUS field per
# container, shifting every later column along and feeding the tail of the row
# to date, which aborted the whole listing under set -e.
@test "k-get-all-unstable-pods: shows one status for a pod with several failed containers" {
  run bash "${SCRIPTS_DIR}/k-get-all-unstable-pods"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"multi-error-app"* ]]
  [[ "${output}" != *"invalid date"* ]]
  [[ "${output}" =~ multi-error-app[[:space:]]+0/3[[:space:]]+Error[[:space:]]+0[[:space:]]+1d ]]
}

@test "k-get-all-unstable-pods: shows the first container status for a pod still initialising" {
  run bash "${SCRIPTS_DIR}/k-get-all-unstable-pods"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ initialising-app[[:space:]]+0/2[[:space:]]+PodInitializing[[:space:]]+0[[:space:]]+1d ]]
}

@test "k-get-all-unstable-pods: lists a pod whose age cannot be parsed" {
  run bash "${SCRIPTS_DIR}/k-get-all-unstable-pods"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ no-timestamp-app[[:space:]]+0/0[[:space:]]+Pending[[:space:]]+0[[:space:]]+unknown ]]
}

# ====================================================================
# k-get-all-stable-pods
# ====================================================================

@test "k-get-all-stable-pods: shows stable pods" {
  run bash "${SCRIPTS_DIR}/k-get-all-stable-pods"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"stable-app"* ]]
}

@test "k-get-all-stable-pods: excludes unstable and completed pods" {
  run bash "${SCRIPTS_DIR}/k-get-all-stable-pods"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" != *"crashing-app"* ]]
  [[ "${output}" != *"pending-app"* ]]
  [[ "${output}" != *"completed-job"* ]]
  [[ "${output}" != *"multi-restart-app"* ]]
}

@test "k-get-all-stable-pods: reports correct count" {
  run bash "${SCRIPTS_DIR}/k-get-all-stable-pods"
  echo "STATUS: ${status}"
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"1 stable pod(s) found."* ]]
}

# ====================================================================
# Namespace shortcuts: verify correct namespace passthrough
# ====================================================================

@test "k-system: passes args to kube-system namespace" {
  run bash "${SCRIPTS_DIR}/k-system" get pods
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "kubectl -n kube-system get pods" ]]
}

@test "k-default: passes args to default namespace" {
  run bash "${SCRIPTS_DIR}/k-default" get pods
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "kubectl -n default get pods" ]]
}

@test "k-node-lease: passes args to kube-node-lease namespace" {
  run bash "${SCRIPTS_DIR}/k-node-lease" get pods
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "kubectl -n kube-node-lease get pods" ]]
}

@test "k-public: passes args to kube-public namespace" {
  run bash "${SCRIPTS_DIR}/k-public" get pods
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "kubectl -n kube-public get pods" ]]
}

@test "k-exec-sh: execs into pod with sh" {
  run bash "${SCRIPTS_DIR}/k-exec-sh" my-ns my-pod
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "kubectl -n my-ns exec -it my-pod -- /bin/sh" ]]
}

@test "k-exec-bash: execs into pod with bash" {
  run bash "${SCRIPTS_DIR}/k-exec-bash" my-ns my-pod
  echo "OUTPUT: ${output}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "kubectl -n my-ns exec -it my-pod -- /bin/bash" ]]
}
