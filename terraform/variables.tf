variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster and related resources"
  type        = string
  default     = "apples-demo"
}

variable "admin_principal_arns" {
  description = "IAM user/role ARNs to grant cluster-admin access via EKS access entries, so an operator can kubectl into the cluster without assuming the CI deploy role. Empty by default."
  type        = list(string)
  default     = []
}
