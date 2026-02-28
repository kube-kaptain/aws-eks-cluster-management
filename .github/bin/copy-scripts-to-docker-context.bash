#!/usr/bin/env bash
set -euo pipefail

cp src/scripts/* "${DOCKER_CONTEXT_SUB_PATH_LINUX_AMD64}/scripts/"
cp src/scripts/* "${DOCKER_CONTEXT_SUB_PATH_LINUX_ARM64}/scripts/"
