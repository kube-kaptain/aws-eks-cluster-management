#!/usr/bin/env bash
set -euo pipefail

DEPLOY_SCRIPTS_VERSION="1.0.10"
DEPLOY_SCRIPTS_URL="https://github.com/kube-kaptain/kaptain-deploy-scripts/releases/download/${DEPLOY_SCRIPTS_VERSION}/kaptain-deploy-scripts-${DEPLOY_SCRIPTS_VERSION}.zip"

mkdir -p "${OUTPUT_SUB_PATH}/copy-scripts"
curl -sLo "${OUTPUT_SUB_PATH}/copy-scripts/deployscripts.zip" "${DEPLOY_SCRIPTS_URL}"
unzip -o "${OUTPUT_SUB_PATH}/copy-scripts/deployscripts.zip" plugins/decryption-providers/decrypt-age -d "${OUTPUT_SUB_PATH}/copy-scripts"

mkdir -p "${DOCKER_CONTEXT_SUB_PATH_LINUX_AMD64}/scripts/"
cp src/scripts/* "${DOCKER_CONTEXT_SUB_PATH_LINUX_AMD64}/scripts/"
cp "${OUTPUT_SUB_PATH}/copy-scripts/plugins/decryption-providers/decrypt-age" "${DOCKER_CONTEXT_SUB_PATH_LINUX_AMD64}/scripts/"

mkdir -p "${DOCKER_CONTEXT_SUB_PATH_LINUX_ARM64}/scripts/"
cp src/scripts/* "${DOCKER_CONTEXT_SUB_PATH_LINUX_ARM64}/scripts/"
cp "${OUTPUT_SUB_PATH}/copy-scripts/plugins/decryption-providers/decrypt-age" "${DOCKER_CONTEXT_SUB_PATH_LINUX_ARM64}/scripts/"
