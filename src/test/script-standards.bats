#!/usr/bin/env bats
# Static analysis of all scripts

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)"
WORK_DIR="$(cd "${BATS_TEST_DIRNAME}/../../target" && pwd)/script-standards"

setup() {
  rm -rf "${WORK_DIR}"
  mkdir -p "${WORK_DIR}"
}

@test "all scripts have bash shebang" {
  local failures=()
  for script in "${SCRIPTS_DIR}"/*; do
    first_line=$(head -n1 "${script}")
    if [[ "${first_line}" != "#!/usr/bin/env bash" ]]; then
      failures+=("$(basename "${script}")")
    fi
  done
  if [[ ${#failures[@]} -gt 0 ]]; then
    printf "Missing shebang: %s\n" "${failures[@]}" > "${WORK_DIR}/shebang-failures.txt"
    cat "${WORK_DIR}/shebang-failures.txt"
    return 1
  fi
}

@test "all scripts have SPDX license header" {
  local failures=()
  for script in "${SCRIPTS_DIR}"/*; do
    if ! grep -q "SPDX-License-Identifier:" "${script}"; then
      failures+=("$(basename "${script}")")
    fi
  done
  if [[ ${#failures[@]} -gt 0 ]]; then
    printf "Missing SPDX header: %s\n" "${failures[@]}" > "${WORK_DIR}/spdx-failures.txt"
    cat "${WORK_DIR}/spdx-failures.txt"
    return 1
  fi
}

@test "all scripts have copyright line" {
  local failures=()
  for script in "${SCRIPTS_DIR}"/*; do
    if ! grep -q "Copyright" "${script}"; then
      failures+=("$(basename "${script}")")
    fi
  done
  if [[ ${#failures[@]} -gt 0 ]]; then
    printf "Missing copyright: %s\n" "${failures[@]}" > "${WORK_DIR}/copyright-failures.txt"
    cat "${WORK_DIR}/copyright-failures.txt"
    return 1
  fi
}

@test "all scripts have set -euo pipefail" {
  local failures=()
  for script in "${SCRIPTS_DIR}"/*; do
    if ! grep -q "set -euo pipefail" "${script}"; then
      failures+=("$(basename "${script}")")
    fi
  done
  if [[ ${#failures[@]} -gt 0 ]]; then
    printf "Missing set -euo pipefail: %s\n" "${failures[@]}" > "${WORK_DIR}/pipefail-failures.txt"
    cat "${WORK_DIR}/pipefail-failures.txt"
    return 1
  fi
}

@test "all scripts are executable" {
  local failures=()
  for script in "${SCRIPTS_DIR}"/*; do
    if [[ ! -x "${script}" ]]; then
      failures+=("$(basename "${script}")")
    fi
  done
  if [[ ${#failures[@]} -gt 0 ]]; then
    printf "Not executable: %s\n" "${failures[@]}" > "${WORK_DIR}/executable-failures.txt"
    cat "${WORK_DIR}/executable-failures.txt"
    return 1
  fi
}

@test "no hardcoded /kd/eks/cluster.yaml paths" {
  local failures=()
  for script in "${SCRIPTS_DIR}"/*; do
    if grep -v '^\s*#' "${script}" | grep -q "/kd/eks/cluster.yaml"; then
      failures+=("$(basename "${script}")")
    fi
  done
  if [[ ${#failures[@]} -gt 0 ]]; then
    printf "Hardcoded path: %s\n" "${failures[@]}" > "${WORK_DIR}/hardcoded-path-failures.txt"
    cat "${WORK_DIR}/hardcoded-path-failures.txt"
    return 1
  fi
}

@test "no hardcoded /kd/bin paths" {
  local failures=()
  for script in "${SCRIPTS_DIR}"/*; do
    if grep -v '^\s*#' "${script}" | grep -q '"/kd/bin\|'"'"'/kd/bin'; then
      failures+=("$(basename "${script}")")
    fi
  done
  if [[ ${#failures[@]} -gt 0 ]]; then
    printf "Hardcoded /kd/bin: %s\n" "${failures[@]}" > "${WORK_DIR}/hardcoded-bin-failures.txt"
    cat "${WORK_DIR}/hardcoded-bin-failures.txt"
    return 1
  fi
}

@test "all files end with newline" {
  local failures=()
  for script in "${SCRIPTS_DIR}"/*; do
    if [[ -n "$(tail -c 1 "${script}")" ]]; then
      failures+=("$(basename "${script}")")
    fi
  done
  if [[ ${#failures[@]} -gt 0 ]]; then
    printf "No trailing newline: %s\n" "${failures[@]}" > "${WORK_DIR}/newline-failures.txt"
    cat "${WORK_DIR}/newline-failures.txt"
    return 1
  fi
}
