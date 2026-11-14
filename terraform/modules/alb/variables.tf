variable "cluster_name" {
  description = "EKS cluster name the controller will target"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL (no scheme) of the cluster's IAM OIDC provider"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to pass to the controller explicitly, instead of letting it auto-discover via EC2 instance metadata (IMDS calls from pod network namespaces time out against this VPC's default hop limit and leave the controller crash-looping)"
  type        = string
}

variable "region" {
  description = "AWS region, passed explicitly for the same reason as vpc_id -- the controller's cloud config init resolves both via IMDS otherwise"
  type        = string
}
