#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

AWS_REGION="${AWS_REGION:-us-east-1}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:?Set TF_STATE_BUCKET env var (terraform/bootstrap output: tfstate_bucket)}"
TF_LOCK_TABLE="${TF_LOCK_TABLE:?Set TF_LOCK_TABLE env var (terraform/bootstrap output: tfstate_lock_table)}"

# Each CI job runs on a fresh runner with no local .terraform cache, so init
# must run here too -- not just in provision-aws.sh -- or this script fails
# before it can even look up the cluster name, let alone destroy anything.
terraform -chdir=terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="dynamodb_table=${TF_LOCK_TABLE}" \
  -backend-config="region=${AWS_REGION}"

CLUSTER_NAME=$(terraform -chdir=terraform output -raw eks_cluster_name)

helm uninstall apples --kube-context "${CLUSTER_NAME}" --ignore-not-found 2>/dev/null || true
terraform -chdir=terraform destroy -auto-approve -var="region=${AWS_REGION}"
