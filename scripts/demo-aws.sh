#!/usr/bin/env bash
# Visual demonstration of the running architecture on the AWS path: nodes,
# pods, services, the real ALB, and a live curl through it. Assumes
# provision-aws.sh has already run and the cluster/app are still up.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME=$(terraform -chdir=terraform output -raw eks_cluster_name)

echo "===== EKS nodes ====="
kubectl --context "${CLUSTER_NAME}" get nodes -o wide

echo
echo "===== Kubernetes pods ====="
kubectl --context "${CLUSTER_NAME}" get pods -o wide

echo
echo "===== Kubernetes services ====="
kubectl --context "${CLUSTER_NAME}" get svc -o wide

echo
echo "===== Ingress (ALB) ====="
kubectl --context "${CLUSTER_NAME}" get ingress

echo
echo "===== VPC network topology ====="
VPC_ID=$(terraform -chdir=terraform output -raw vpc_id)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" \
  --query 'Subnets[].{id:SubnetId,az:AvailabilityZone,cidr:CidrBlock,public:MapPublicIpOnLaunch}' \
  --output table

echo
echo "===== Live request through the ALB ====="
ALB_HOST=$(kubectl --context "${CLUSTER_NAME}" get ingress apples-apples-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB: ${ALB_HOST}"
curl -sS -m 10 "http://${ALB_HOST}/"
echo
curl -sS -m 10 "http://${ALB_HOST}/readyz"
echo

echo
echo "===== Helm release ====="
helm --kube-context "${CLUSTER_NAME}" list
