#!/usr/bin/env bats
# Test document scripts produce expected output

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)"
WORK_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)/${OUTPUT_SUB_PATH:-kaptain-out}/documents"

setup() {
  rm -rf "${WORK_DIR}"
  mkdir -p "${WORK_DIR}"
}

@test "cluster-document-creation contains cluster create" {
  run bash "${SCRIPTS_DIR}/cluster-document-creation"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"cluster create"* ]]
}

@test "cluster-document-creation produces non-empty output" {
  run bash "${SCRIPTS_DIR}/cluster-document-creation"
  [[ "${status}" -eq 0 ]]
  [[ -n "${output}" ]]
}

@test "cluster-document-maintenance contains cluster upgrade" {
  run bash "${SCRIPTS_DIR}/cluster-document-maintenance"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"cluster upgrade"* ]]
}

@test "cluster-document-maintenance produces non-empty output" {
  run bash "${SCRIPTS_DIR}/cluster-document-maintenance"
  [[ "${status}" -eq 0 ]]
  [[ -n "${output}" ]]
}

@test "cluster-document-deletion contains cluster delete" {
  run bash "${SCRIPTS_DIR}/cluster-document-deletion"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"cluster delete"* ]]
}

@test "cluster-document-deletion produces non-empty output" {
  run bash "${SCRIPTS_DIR}/cluster-document-deletion"
  [[ "${status}" -eq 0 ]]
  [[ -n "${output}" ]]
}
