# Kaptain bash init - sourced from ~/.bashrc
# Provides completion, prompt, and welcome message for interactive bash sessions

# Tab completion for cluster commands
source /usr/local/share/kaptain/cluster-completion.bash

# Set cluster-aware prompt (defined in Dockerfile)
export PS1="${KAPTAIN_PS1}"

${CLUSTER_SCRIPT_DIR}/cluster-welcome
