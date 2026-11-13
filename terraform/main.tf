resource "aws_kms_key" "this" {
  description         = "${var.cluster_name} encryption key (EKS secrets + ECR images)"
  enable_key_rotation = true
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

  cluster_name       = var.cluster_name
  cluster_subnet_ids = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  node_subnet_ids    = module.vpc.private_subnet_ids
  kms_key_arn        = aws_kms_key.this.arn
}

module "alb" {
  source = "./modules/alb"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}
