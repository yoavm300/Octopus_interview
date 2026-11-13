variable "repository_name" {
  description = "Name of the ECR repository for the app image"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used to encrypt images"
  type        = string
}
