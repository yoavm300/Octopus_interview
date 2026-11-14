terraform {
  required_version = ">= 1.5.0"

  # Partial config: bucket/dynamodb_table/region are supplied via
  # -backend-config at init time (see scripts/provision-aws.sh and
  # scripts/teardown-aws.sh), not hardcoded here, since the bucket name is
  # generated per-bootstrap (see terraform/bootstrap). A real backend is
  # required for the AWS path: state from a GitHub Actions apply run must
  # still be visible to the teardown run that undoes it, which happens on a
  # different, stateless runner.
  backend "s3" {
    key     = "apples-demo/terraform.tfstate"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# helm provider v3 moved from blocks to attributes (Plugin Framework
# migration) -- kubernetes/exec are now object-typed attributes, not
# blocks, so this intentionally differs in syntax from provider "kubernetes"
# above, which is unaffected since that provider hasn't made the same move.
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}
