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

# Each CI job is also a fresh runner for kubeconfig: there is no local
# context named after the cluster until this runs. Without it, helm's
# --kube-context below fails outright ("context ... does not exist") --
# which a previous version of this script silently swallowed via
# `|| true`, masking the fact that the app was never actually
# uninstalled by CI, ever, before terraform destroy tore down the ALB
# controller it depended on.
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --alias "${CLUSTER_NAME}"

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

# Retried, not one-shot: found live, more than once, that a handful of AWS
# resources lag behind their own API's view of reality right after a
# dependent resource is deleted -- a VPC-CNI secondary ENI or an EKS
# cluster security group left behind for a few seconds after the node
# group/cluster that owned it is already gone, blocking the subnet/VPC
# delete with a DependencyViolation that a bare `terraform destroy` never
# recovers from on its own. Re-running picks up exactly where the state
# left off, since whatever already got destroyed is simply gone from it.
for attempt in 1 2 3; do
  if terraform -chdir=terraform destroy -auto-approve -var="region=${AWS_REGION}"; then
    exit 0
  fi
  echo "==> destroy attempt ${attempt} failed, retrying in 30s (likely AWS eventual consistency on a dependent resource)" >&2
  sleep 30
done
exit 1
