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
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.31"
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
