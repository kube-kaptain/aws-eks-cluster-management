#!/usr/bin/env bats
# Test k shortcut scripts reject missing/bad arguments

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)"
WORK_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)/${OUTPUT_SUB_PATH:-kaptain-out}/k-shortcuts"

setup() {
  rm -rf "${WORK_DIR}"
  mkdir -p "${WORK_DIR}/bin" "${WORK_DIR}/kd-work"

  # Create a mock kubectl
  cat > "${WORK_DIR}/bin/kubectl" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "get" && "$2" == "ns" ]]; then
  cat "${MOCK_NS_OUTPUT}"
  exit 0
fi
printf '%s\n' "$*"
MOCK
  chmod +x "${WORK_DIR}/bin/kubectl"

  # Create patched copies with testable cache dir
  sed "s|/kd/work|${WORK_DIR}/kd-work|g" "${SCRIPTS_DIR}/k-run-platform" > "${WORK_DIR}/bin/k-run-platform-test"
  chmod +x "${WORK_DIR}/bin/k-run-platform-test"

  sed "s|/kd/work|${WORK_DIR}/kd-work|g" "${SCRIPTS_DIR}/k-run-env" > "${WORK_DIR}/bin/k-run-env-test"
  chmod +x "${WORK_DIR}/bin/k-run-env-test"
}

@test "k: no args exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/k"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "k-system: no args exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/k-system"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "k-default: no args exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/k-default"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "k-node-lease: no args exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/k-node-lease"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "k-public: no args exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/k-public"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "k-run-platform: no args exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/k-run-platform"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "k-run-platform: finds single run-platform namespace" {
  echo "run-platform-myteam" > "${WORK_DIR}/ns-list"
  export MOCK_NS_OUTPUT="${WORK_DIR}/ns-list"
  export PATH="${WORK_DIR}/bin:${PATH}"
  run bash "${WORK_DIR}/bin/k-run-platform-test" get pods
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"-n run-platform-myteam get pods"* ]]
}

@test "k-run-platform: caches namespace on first lookup" {
  echo "run-platform-myteam" > "${WORK_DIR}/ns-list"
  export MOCK_NS_OUTPUT="${WORK_DIR}/ns-list"
  export PATH="${WORK_DIR}/bin:${PATH}"
  run bash "${WORK_DIR}/bin/k-run-platform-test" get pods
  [[ "${status}" -eq 0 ]]
  [[ -f "${WORK_DIR}/kd-work/run-platform-namespace" ]]
  [[ "$(cat "${WORK_DIR}/kd-work/run-platform-namespace")" == "run-platform-myteam" ]]
}

@test "k-run-platform: uses cached namespace" {
  echo "run-platform-cached" > "${WORK_DIR}/kd-work/run-platform-namespace"
  export PATH="${WORK_DIR}/bin:${PATH}"
  run bash "${WORK_DIR}/bin/k-run-platform-test" get pods
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"-n run-platform-cached get pods"* ]]
}

@test "k-run-platform: fails when no run-platform namespace found" {
  printf "default\nkube-system\n" > "${WORK_DIR}/ns-list"
  export MOCK_NS_OUTPUT="${WORK_DIR}/ns-list"
  export PATH="${WORK_DIR}/bin:${PATH}"
  run bash "${WORK_DIR}/bin/k-run-platform-test" get pods
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"No namespace starting with"* ]]
}

@test "k-run-platform: fails when multiple run-platform namespaces found" {
  printf "run-platform-team-a\nrun-platform-team-b\n" > "${WORK_DIR}/ns-list"
  export MOCK_NS_OUTPUT="${WORK_DIR}/ns-list"
  export PATH="${WORK_DIR}/bin:${PATH}"
  run bash "${WORK_DIR}/bin/k-run-platform-test" get pods
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Multiple run-platform namespaces"* ]]
}

@test "k-run-platform: ignores namespace containing but not starting with run-platform" {
  printf "default\nnot-run-platform-thing\nkube-system\n" > "${WORK_DIR}/ns-list"
  export MOCK_NS_OUTPUT="${WORK_DIR}/ns-list"
  export PATH="${WORK_DIR}/bin:${PATH}"
  run bash "${WORK_DIR}/bin/k-run-platform-test" get pods
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"No namespace starting with"* ]]
}

@test "k-run-env: no args exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/k-run-env"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "k-run-env: finds single run-env namespace" {
  printf "run-platform-myteam\nrun-staging-abc\n" > "${WORK_DIR}/ns-list"
  export MOCK_NS_OUTPUT="${WORK_DIR}/ns-list"
  export PATH="${WORK_DIR}/bin:${PATH}"
  run bash "${WORK_DIR}/bin/k-run-env-test" get pods
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"-n run-staging-abc get pods"* ]]
}

@test "k-run-env: caches namespace on first lookup" {
  printf "run-platform-myteam\nrun-staging-abc\n" > "${WORK_DIR}/ns-list"
  export MOCK_NS_OUTPUT="${WORK_DIR}/ns-list"
  export PATH="${WORK_DIR}/bin:${PATH}"
  run bash "${WORK_DIR}/bin/k-run-env-test" get pods
  [[ "${status}" -eq 0 ]]
  [[ -f "${WORK_DIR}/kd-work/run-env-namespace" ]]
  [[ "$(cat "${WORK_DIR}/kd-work/run-env-namespace")" == "run-staging-abc" ]]
}

@test "k-run-env: uses cached namespace" {
  echo "run-prod-cached" > "${WORK_DIR}/kd-work/run-env-namespace"
  export PATH="${WORK_DIR}/bin:${PATH}"
  run bash "${WORK_DIR}/bin/k-run-env-test" get pods
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"-n run-prod-cached get pods"* ]]
}

@test "k-run-env: fails when no run- namespace found excluding run-platform" {
  printf "default\nrun-platform-myteam\nkube-system\n" > "${WORK_DIR}/ns-list"
  export MOCK_NS_OUTPUT="${WORK_DIR}/ns-list"
  export PATH="${WORK_DIR}/bin:${PATH}"
  run bash "${WORK_DIR}/bin/k-run-env-test" get pods
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"No namespace"* ]]
}

@test "k-run-env: fails when multiple run-env namespaces found" {
  printf "run-staging-a\nrun-prod-b\nrun-platform-myteam\n" > "${WORK_DIR}/ns-list"
  export MOCK_NS_OUTPUT="${WORK_DIR}/ns-list"
  export PATH="${WORK_DIR}/bin:${PATH}"
  run bash "${WORK_DIR}/bin/k-run-env-test" get pods
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Multiple"* ]]
}

@test "k-run-env: excludes run-platform namespaces" {
  printf "run-platform-team-a\nrun-platform-team-b\nrun-staging-only\n" > "${WORK_DIR}/ns-list"
  export MOCK_NS_OUTPUT="${WORK_DIR}/ns-list"
  export PATH="${WORK_DIR}/bin:${PATH}"
  run bash "${WORK_DIR}/bin/k-run-env-test" get pods
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"-n run-staging-only get pods"* ]]
}

@test "k-exec-sh: no args exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/k-exec-sh"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "k-exec-sh: one arg exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/k-exec-sh" my-namespace
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "k-exec-sh: three args exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/k-exec-sh" my-namespace my-pod extra
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "k-exec-bash: no args exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/k-exec-bash"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "k-exec-bash: one arg exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/k-exec-bash" my-namespace
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "k-exec-bash: three args exits 1 with usage" {
  run bash "${SCRIPTS_DIR}/k-exec-bash" my-namespace my-pod extra
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}
