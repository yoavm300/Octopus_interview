#!/usr/bin/env bash
# Bonus path: provisions the AWS infra with Terraform, then deploys the same
# Helm chart used locally onto the resulting EKS cluster. Not required to
# pass the exercise; the graded path is scripts/provision-local.sh.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

AWS_REGION="${AWS_REGION:-us-east-1}"
MONGO_PASSWORD="${MONGO_PASSWORD:?Set MONGO_PASSWORD env var}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:?Set TF_STATE_BUCKET env var (terraform/bootstrap output: tfstate_bucket)}"
TF_LOCK_TABLE="${TF_LOCK_TABLE:?Set TF_LOCK_TABLE env var (terraform/bootstrap output: tfstate_lock_table)}"

echo "==> Applying Terraform (AWS infra)"
terraform -chdir=terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="dynamodb_table=${TF_LOCK_TABLE}" \
  -backend-config="region=${AWS_REGION}"
terraform -chdir=terraform apply -auto-approve -var="region=${AWS_REGION}"

CLUSTER_NAME=$(terraform -chdir=terraform output -raw eks_cluster_name)
ECR_REPO=$(terraform -chdir=terraform output -raw ecr_repository_url)

echo "==> Configuring kubectl for EKS (context: ${CLUSTER_NAME})"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --alias "${CLUSTER_NAME}"

echo "==> Building and pushing app image to ECR"
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REPO%/*}"
docker build -t "${ECR_REPO}:latest" app/
docker push "${ECR_REPO}:latest"

echo "==> Deploying with Helm (context: ${CLUSTER_NAME})"
helm upgrade --install apples helm/apples-app \
  --kube-context "${CLUSTER_NAME}" \
  -f helm/apples-app/values.yaml \
  -f helm/apples-app/values-aws.yaml \
  --set image.repository="${ECR_REPO}" \
  --set image.tag=latest \
  --set mongo.credentials.password="${MONGO_PASSWORD}" \
  --wait --timeout 5m

echo "==> Done."
