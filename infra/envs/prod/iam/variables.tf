variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "role_name" {
  description = "Name of the IAM role for EC2/SSM"
  type        = string
}

variable "instance_profile_name" {
  description = "Instance profile name for EC2/SSM"
  type        = string
}

variable "managed_policy_arns" {
  description = "List of managed policy ARNs to attach to the role"
  type        = list(string)
}

variable "inline_policies" {
  description = "Optional inline policies (name => JSON)"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
