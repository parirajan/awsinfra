variable "parent_image_arn" {
  description = "Base image ARN used in prod pipeline (e.g. AL2023 hardened)."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Image Builder instances in prod."
  type        = string
}

variable "security_group_ids" {
  description = "Security groups for Image Builder instances in prod."
  type        = list(string)
}

variable "instance_profile_name" {
  description = "Instance profile used by Image Builder in prod."
  type        = string
}

variable "log_bucket_name" {
  description = "S3 bucket for Image Builder logs in prod."
  type        = string
}

variable "share_with_account_ids" {
  description = "Accounts to share AMIs with (DR, tooling, etc.)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags for prod Image Builder resources."
  type        = map(string)
  default     = {
    Environment = "prod"
    Owner       = "platform-team"
  }
}
