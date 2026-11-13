variable "name" {
  description = "Name prefix for VPC resources"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_suffixes" {
  description = "Single-letter AZ suffixes to spread subnets across, appended to the region"
  type        = list(string)
  default     = ["a", "b"]
}
