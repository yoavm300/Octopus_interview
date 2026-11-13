variable "region" {
  description = "AWS region (IAM is global, but the provider still needs one)"
  type        = string
  default     = "us-east-1"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the deploy role, as org/repo"
  type        = string
  default     = "yoavm300/Octopus_interview"
}

variable "role_name" {
  description = "Name of the IAM role GitHub Actions assumes via OIDC"
  type        = string
  default     = "github-actions-apples-deploy"
}
