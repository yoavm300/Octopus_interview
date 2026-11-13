#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME=$(terraform -chdir=terraform output -raw eks_cluster_name)

helm uninstall apples --kube-context "${CLUSTER_NAME}" --ignore-not-found 2>/dev/null || true
terraform -chdir=terraform destroy -auto-approve -var="region=${AWS_REGION}"
