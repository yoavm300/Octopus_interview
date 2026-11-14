#!/usr/bin/env bash
# Provisions the full architecture on a local kind cluster. Idempotent: safe to
# re-run against an existing cluster/release.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

CLUSTER_NAME="${CLUSTER_NAME:-apples-local}"
CONTEXT="kind-${CLUSTER_NAME}"
IMAGE_TAG="${IMAGE_TAG:-local}"
IMAGE_NAME="apples-app:${IMAGE_TAG}"

echo "==> Building app image"
docker build -t "${IMAGE_NAME}" app/

echo "==> Creating kind cluster (${CLUSTER_NAME}) if it doesn't exist"
if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --name "${CLUSTER_NAME}"
fi

echo "==> Loading app image into kind"
kind load docker-image "${IMAGE_NAME}" --name "${CLUSTER_NAME}"

# Generated, not hardcoded in values-local.yaml -- and persisted locally
# (gitignored) rather than re-generated on every run: Mongo only honors
# MONGO_INITDB_ROOT_PASSWORD on a truly empty data directory, so a fresh
# random value on each re-run against an *existing* cluster would stop
# matching what Mongo actually initialized with on the first run, breaking
# auth. teardown-local.sh removes this file, so a fresh cluster always
# gets a fresh password alongside its fresh (empty) Mongo volume.
PASSWORD_FILE="$(dirname "${BASH_SOURCE[0]}")/../.local-mongo-password"
if [ ! -f "${PASSWORD_FILE}" ]; then
  openssl rand -base64 24 > "${PASSWORD_FILE}"
fi
MONGO_PASSWORD=$(cat "${PASSWORD_FILE}")

echo "==> Deploying with Helm (context: ${CONTEXT})"
helm upgrade --install apples helm/apples-app \
  --kube-context "${CONTEXT}" \
  -f helm/apples-app/values.yaml \
  -f helm/apples-app/values-local.yaml \
  --set image.repository=apples-app \
  --set image.tag="${IMAGE_TAG}" \
  --set mongo.credentials.password="${MONGO_PASSWORD}" \
  --wait --timeout 3m

echo "==> Done. Run scripts/check.sh to verify."
