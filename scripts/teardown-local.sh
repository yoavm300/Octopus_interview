#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-apples-local}"
CONTEXT="kind-${CLUSTER_NAME}"

helm uninstall apples --kube-context "${CONTEXT}" --ignore-not-found 2>/dev/null || true
kind delete cluster --name "${CLUSTER_NAME}"

# So the next provision-local.sh generates a fresh password alongside the
# fresh (empty) Mongo volume it'll create -- see provision-local.sh for why
# reusing a stale one would break auth.
rm -f "$(dirname "${BASH_SOURCE[0]}")/../.local-mongo-password"
