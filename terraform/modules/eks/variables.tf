variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_subnet_ids" {
  description = "Subnets for the EKS control plane (public + private)"
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Subnets for the managed node group (private only)"
  type        = list(string)
}

variable "kubernetes_version" {
  # 1.31 was in EKS's EXTENDED_SUPPORT tier (its standard support window
  # ended 2025-11-26, extended support itself ends 2026-11-26 -- about to
  # lapse entirely) and bills an hourly surcharge on top of the regular
  # control-plane cost. 1.36 is comfortably inside STANDARD_SUPPORT
  # (through 2027-08-02) without being the bleeding-edge newest (1.37,
  # released weeks ago as of this writing) just for its own sake.
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.36"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used to encrypt EKS secrets"
  type        = string
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public cluster endpoint. Left open by default so this demo cluster is reachable without a VPN/bastion; narrow this for anything longer-lived."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_principal_arns" {
  description = "IAM user/role ARNs to grant cluster-admin access via EKS access entries, in addition to the principal that applied Terraform (which gets cluster-creator access automatically). Lets an operator kubectl into the cluster for debugging without needing to assume the CI deploy role."
  type        = list(string)
  default     = []
}
