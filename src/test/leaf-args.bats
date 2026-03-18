#!/usr/bin/env bats
# Test argument handling for all leaf scripts
#
# Verifies that every script correctly rejects wrong argument counts
# and unknown flags. Arg checks happen before env requirements in all
# scripts, so these tests need no mocking or environment setup.

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)"

setup() {
  # Some scripts check CLUSTER_SCRIPT_DIR before parsing args
  export CLUSTER_SCRIPT_DIR="${SCRIPTS_DIR}"
}

# ====================================================================
# No-arg scripts: must reject any arguments
# ====================================================================

# --- list ---

@test "cluster-list-clusters: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-clusters" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-nodes: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-nodes" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-addons: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-addons" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-all: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-all" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-stacks: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-stacks" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-version: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-version" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-all-addons-all-versions: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-all-addons-all-versions" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-all-addons-raw-json: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-all-addons-raw-json" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-old-nodes-not-cordoned: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-old-nodes-not-cordoned" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-old-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-old-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-new-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-new-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-nodes-for-old-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-nodes-for-old-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-nodes-for-new-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-nodes-for-new-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-access-entries: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-access-entries" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-insights: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-insights" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-all-pods: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-all-pods" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-all-unstable-pods: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-all-unstable-pods" bogus
  [[ "${status}" -eq 1 ]]
}

@test "k-get-all-pods: rejects args" {
  run bash "${SCRIPTS_DIR}/k-get-all-pods" bogus
  [[ "${status}" -eq 1 ]]
}

@test "k-get-all-unstable-pods: rejects args" {
  run bash "${SCRIPTS_DIR}/k-get-all-unstable-pods" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-all-stable-pods: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-list-all-stable-pods" bogus
  [[ "${status}" -eq 1 ]]
}

@test "k-get-all-stable-pods: rejects args" {
  run bash "${SCRIPTS_DIR}/k-get-all-stable-pods" bogus
  [[ "${status}" -eq 1 ]]
}

# --- insights ---

@test "cluster-refresh-insights: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-refresh-insights" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-poll-insights-refresh: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-poll-insights-refresh" bogus
  [[ "${status}" -eq 1 ]]
}

# --- delete ---

@test "cluster-delete-cluster: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-delete-cluster" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-delete-old-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-delete-old-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-delete-addons: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-delete-addons" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-delete-access-entries: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-delete-access-entries" bogus
  [[ "${status}" -eq 1 ]]
}

# --- cordon/uncordon/locksize/unlocksize old-nodegroups ---

@test "cluster-cordon-old-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-cordon-old-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-uncordon-old-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-uncordon-old-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-locksize-old-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-locksize-old-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-unlocksize-old-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-unlocksize-old-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

# --- cordon/uncordon/delete/drain/locksize/unlocksize new-nodegroups ---

@test "cluster-cordon-new-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-cordon-new-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-uncordon-new-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-uncordon-new-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-delete-new-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-delete-new-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-locksize-new-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-locksize-new-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-unlocksize-new-nodegroups: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-unlocksize-new-nodegroups" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-drain-new-nodegroups: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-drain-new-nodegroups" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# --- other flag scripts (--dry-run) ---

@test "cluster-upgrade-cluster-auto-mode: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-upgrade-cluster-auto-mode" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-upgrade-cluster-endpoints: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-upgrade-cluster-endpoints" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-upgrade-cluster-logging: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-upgrade-cluster-logging" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-upgrade-yaml-reconciliation: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-upgrade-yaml-reconciliation" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-upgrade-cluster-access: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-upgrade-cluster-access" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# --- other no-arg scripts ---

@test "cluster-upgrade-fast-end-to-end-automatic: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-upgrade-fast-end-to-end-automatic" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-upgrade-prepare-for-migration: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-upgrade-prepare-for-migration" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-upgrade-fast-nodegroups-only-automatic: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-upgrade-fast-nodegroups-only-automatic" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-upgrade-prepare-nodegroups-only: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-upgrade-prepare-nodegroups-only" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-describe-stacks: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-describe-stacks" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-document-creation: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-document-creation" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-document-maintenance: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-document-maintenance" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-document-nodegroups-only: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-document-nodegroups-only" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-document-deletion: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-document-deletion" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-welcome: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-welcome" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-setup-credentials: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-setup-credentials" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-validate-image: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-validate-image" bogus
  [[ "${status}" -eq 1 ]]
}

@test "cluster-create-access-entries: rejects args" {
  run bash "${SCRIPTS_DIR}/cluster-create-access-entries" bogus
  [[ "${status}" -eq 1 ]]
}

# ====================================================================
# Single positional arg scripts: no args and too many args
# ====================================================================

# --- cordon ---

@test "cluster-cordon-node: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-cordon-node"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-cordon-node: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-cordon-node" one two
  [[ "${status}" -eq 1 ]]
}

@test "cluster-cordon-nodegroup: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-cordon-nodegroup"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-cordon-nodegroup: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-cordon-nodegroup" one two
  [[ "${status}" -eq 1 ]]
}

# --- uncordon ---

@test "cluster-uncordon-node: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-uncordon-node"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-uncordon-node: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-uncordon-node" one two
  [[ "${status}" -eq 1 ]]
}

@test "cluster-uncordon-nodegroup: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-uncordon-nodegroup"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-uncordon-nodegroup: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-uncordon-nodegroup" one two
  [[ "${status}" -eq 1 ]]
}

# --- delete ---

@test "cluster-delete-nodegroup: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-delete-nodegroup"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-delete-nodegroup: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-delete-nodegroup" one two
  [[ "${status}" -eq 1 ]]
}

@test "cluster-delete-nodegroup: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-delete-nodegroup" mygroup --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown flag"* ]]
}

@test "cluster-delete-addon: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-delete-addon"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-delete-addon: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-delete-addon" one two
  [[ "${status}" -eq 1 ]]
}

@test "cluster-delete-access-entry: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-delete-access-entry"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-delete-access-entry: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-delete-access-entry" one two
  [[ "${status}" -eq 1 ]]
}

# --- locksize ---

@test "cluster-locksize-nodegroup: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-locksize-nodegroup"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-locksize-nodegroup: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-locksize-nodegroup" one two
  [[ "${status}" -eq 1 ]]
}

# --- unlocksize ---

@test "cluster-unlocksize-nodegroup: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-unlocksize-nodegroup"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-unlocksize-nodegroup: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-unlocksize-nodegroup" one two
  [[ "${status}" -eq 1 ]]
}

# --- list with single arg ---

@test "cluster-list-nodegroup-size: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-list-nodegroup-size"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-list-nodegroup-size: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-list-nodegroup-size" one two
  [[ "${status}" -eq 1 ]]
}

@test "cluster-list-nodes-for-nodegroup: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-list-nodes-for-nodegroup"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-list-nodes-for-nodegroup: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-list-nodes-for-nodegroup" one two
  [[ "${status}" -eq 1 ]]
}

# ====================================================================
# Two positional arg scripts: no args, one arg, three args
# ====================================================================

@test "cluster-set-nodegroup-min: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-set-nodegroup-min"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-set-nodegroup-min: one arg exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-set-nodegroup-min" ng-main
  [[ "${status}" -eq 1 ]]
}

@test "cluster-set-nodegroup-min: three args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-set-nodegroup-min" ng-main 3 extra
  [[ "${status}" -eq 1 ]]
}

@test "cluster-set-nodegroup-max: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-set-nodegroup-max"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-set-nodegroup-max: one arg exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-set-nodegroup-max" ng-main
  [[ "${status}" -eq 1 ]]
}

@test "cluster-set-nodegroup-max: three args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-set-nodegroup-max" ng-main 3 extra
  [[ "${status}" -eq 1 ]]
}

@test "cluster-set-nodegroup-desired: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-set-nodegroup-desired"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-set-nodegroup-desired: one arg exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-set-nodegroup-desired" ng-main
  [[ "${status}" -eq 1 ]]
}

@test "cluster-set-nodegroup-desired: three args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-set-nodegroup-desired" ng-main 3 extra
  [[ "${status}" -eq 1 ]]
}

# ====================================================================
# Flag scripts: unknown flags must be rejected
# ====================================================================

@test "cluster-create-cluster: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-create-cluster" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-create-addons: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-create-addons" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-create-addon: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-create-addon" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-create-addon: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-create-addon"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-create-addon: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-create-addon" one two
  [[ "${status}" -eq 1 ]]
}

@test "cluster-create-nodegroup: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-create-nodegroup" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-create-nodegroup: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-create-nodegroup"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-create-nodegroup: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-create-nodegroup" one two
  [[ "${status}" -eq 1 ]]
}

@test "cluster-create-nodegroups: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-create-nodegroups" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-upgrade-controlplane: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-upgrade-controlplane" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-upgrade-addons: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-upgrade-addons" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-upgrade-addon: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-upgrade-addon" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-drain-node: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-drain-node" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-drain-nodegroup: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-drain-nodegroup" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-drain-old-nodegroups: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-drain-old-nodegroups" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

@test "cluster-bootstrap-cilium: rejects unknown flag" {
  run bash "${SCRIPTS_DIR}/cluster-bootstrap-cilium" --bogus
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown"* ]]
}

# ====================================================================
# Drain scripts: no args (require node/nodegroup name)
# ====================================================================

@test "cluster-drain-node: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-drain-node"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-drain-nodegroup: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-drain-nodegroup"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

# ====================================================================
# Upgrade addon: requires addon name
# ====================================================================

@test "cluster-upgrade-addon: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-upgrade-addon"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

# ====================================================================
# Create access entry: requires principal ARN (extra args pass through)
# ====================================================================

@test "cluster-create-access-entry: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-create-access-entry"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

# ====================================================================
# Describe insight: requires insight ID
# ====================================================================

@test "cluster-describe-insight: no args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-describe-insight"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "cluster-describe-insight: too many args exits 1" {
  run bash "${SCRIPTS_DIR}/cluster-describe-insight" one two
  [[ "${status}" -eq 1 ]]
}
