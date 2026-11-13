#!/usr/bin/env bash
# Verifies the running app returns the correct apple count.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-apples-local}"
CONTEXT="kind-${CLUSTER_NAME}"
LOCAL_PORT="${LOCAL_PORT:-18080}"

kubectl --context "${CONTEXT}" rollout status deployment/apples-apples-app --timeout=120s

kubectl --context "${CONTEXT}" port-forward svc/apples-apples-app "${LOCAL_PORT}:80" >/dev/null 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} 2>/dev/null || true' EXIT

sleep 3

RESPONSE=$(curl -sf "http://localhost:${LOCAL_PORT}/")
echo "${RESPONSE}"

if echo "${RESPONSE}" | grep -q "There are 5 apples"; then
  echo "PASS: apple count correct"
else
  echo "FAIL: apple count not found or incorrect"
  exit 1
fi
