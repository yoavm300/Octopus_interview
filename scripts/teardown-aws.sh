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

# --wait matters here, not just for tidiness: the Ingress object carries a
# finalizer the ALB controller uses to deprovision the real AWS load
# balancer, and without --wait helm returns as soon as the k8s objects are
# marked for deletion, before that finalizer actually clears. The very next
# step destroys the controller itself, so without this, the real ALB (plus
# its security groups and ENIs) is orphaned -- nothing is left running
# that could ever finish deleting it, and it silently blocks the VPC
# destroy later in this same run. Found live: had to delete the orphaned
# ALB and its two controller-created security groups by hand before a
# stuck destroy could proceed.
helm uninstall apples --kube-context "${CLUSTER_NAME}" --ignore-not-found --wait --timeout 3m
terraform -chdir=terraform destroy -auto-approve -var="region=${AWS_REGION}"
