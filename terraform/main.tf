resource "aws_kms_key" "this" {
  description         = "${var.cluster_name} encryption key (EKS secrets + ECR images)"
  enable_key_rotation = true
}

# Found live: EKS's documented "cluster creator gets implicit admin access"
# does not reliably apply once access_config is set explicitly (as the eks
# module does, to support admin_principal_arns) -- a real `deploy-aws.yml`
# apply failed with "Unauthorized" on every kubernetes/helm-provider
# resource because no access entry existed for the deploy role at all.
# Auto-detecting and always granting the actual caller removes any
# dependence on that undocumented behavior, for CI and local runs alike.
data "aws_caller_identity" "current" {}

locals {
  # EKS access entries need the underlying IAM role ARN, not an STS
  # assumed-role session ARN (what a CI job's assumed role reports as
  # caller identity) -- convert; a plain user/role ARN (e.g. a local
  # operator) passes through unchanged.
  caller_arn           = data.aws_caller_identity.current.arn
  caller_principal_arn = can(regex("^arn:aws:sts::[0-9]+:assumed-role/", local.caller_arn)) ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${split("/", local.caller_arn)[1]}" : local.caller_arn
}

module "vpc" {
  source = "./modules/vpc"

  name = var.cluster_name
}

module "ecr" {
  source = "./modules/ecr"

  repository_name = var.cluster_name
  kms_key_arn     = aws_kms_key.this.arn
}

module "eks" {
  source = "./modules/eks"

  cluster_name         = var.cluster_name
  cluster_subnet_ids   = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  node_subnet_ids      = module.vpc.private_subnet_ids
  kms_key_arn          = aws_kms_key.this.arn
  admin_principal_arns = distinct(concat(var.admin_principal_arns, [local.caller_principal_arn]))
}

module "alb" {
  source = "./modules/alb"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  vpc_id            = module.vpc.vpc_id
  region            = var.region

  # Forces module.alb's kubernetes/helm-provider resources to be destroyed
  # before module.eks's access entries -- without this, Terraform has no
  # dependency edge between them (module.alb never references the access
  # entry resources) and may destroy the destroying principal's own
  # cluster access mid-teardown, exactly as module.eks's own
  # kubernetes_storage_class.gp3 does via its explicit depends_on below.
  depends_on = [module.eks]
}
