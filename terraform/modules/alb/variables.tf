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
