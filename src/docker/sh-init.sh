# Kaptain sh init - sourced via ENV for interactive sh/dash sessions

# Set cluster-aware prompt (defined in Dockerfile)
export PS1="${KAPTAIN_PS1}"

${CLUSTER_SCRIPT_DIR}/cluster-welcome
