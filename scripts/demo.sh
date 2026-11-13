#!/usr/bin/env bash
# Visual demonstration of the running architecture: containers, pods, services,
# and network topology, captured live against the local kind cluster.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-apples-local}"
CONTEXT="kind-${CLUSTER_NAME}"

echo "===== Docker containers (kind node + workload containers) ====="
docker ps --filter "name=${CLUSTER_NAME}" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo
echo "===== Kubernetes pods ====="
kubectl --context "${CONTEXT}" get pods -o wide

echo
echo "===== Kubernetes services (network topology) ====="
kubectl --context "${CONTEXT}" get svc -o wide

echo
echo "===== Kubernetes endpoints (service -> pod wiring) ====="
kubectl --context "${CONTEXT}" get endpoints

echo
echo "===== Docker network (kind) ====="
docker network inspect kind --format '{{json .IPAM.Config}}'

echo
echo "===== Helm release ====="
helm --kube-context "${CONTEXT}" list
