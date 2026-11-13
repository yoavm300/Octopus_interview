#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-apples-local}"
CONTEXT="kind-${CLUSTER_NAME}"

helm uninstall apples --kube-context "${CONTEXT}" --ignore-not-found 2>/dev/null || true
kind delete cluster --name "${CLUSTER_NAME}"
