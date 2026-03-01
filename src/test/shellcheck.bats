#!/usr/bin/env bats
# Run shellcheck on all cluster scripts

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)"
WORK_DIR="$(cd "${BATS_TEST_DIRNAME}/../../target" && pwd)/shellcheck"

setup() {
  rm -rf "${WORK_DIR}"
  mkdir -p "${WORK_DIR}"
}

@test "all scripts pass shellcheck" {
  local failures=()
  for script in "${SCRIPTS_DIR}"/cluster*; do
    if ! shellcheck "${script}" > "${WORK_DIR}/$(basename "${script}").out" 2>&1; then
      failures+=("$(basename "${script}")")
    fi
  done
  if [[ ${#failures[@]} -gt 0 ]]; then
    echo "Shellcheck failures:"
    for f in "${failures[@]}"; do
      echo "--- ${f} ---"
      cat "${WORK_DIR}/${f}.out"
      echo ""
    done
    return 1
  fi
}
