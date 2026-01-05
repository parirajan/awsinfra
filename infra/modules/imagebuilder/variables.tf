variable "name" {
  description = "Logical name for the image pipeline (prefix for resources)."
  type        = string
}

variable "parent_image_arn" {
  description = "Base image ARN (AMI or managed Image Builder image)."
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 30
}

variable "instance_types" {
  description = "Instance types used for building images."
  type        = list(string)
  default     = ["t3.large"]
}

variable "subnet_id" {
  description = "Subnet ID where build instances will run."
  type        = string
}

variable "security_group_ids" {
  description = "Security group IDs for build instances."
  type        = list(string)
}

variable "ssh_key_name" {
  description = "Optional SSH key pair name for build instances."
  type        = string
  default     = null
}

variable "instance_profile_name" {
  description = "IAM instance profile name for Image Builder instances."
  type        = string
}

variable "log_bucket_name" {
  description = "S3 bucket for Image Builder logs."
  type        = string
}

variable "share_with_account_ids" {
  description = "AWS account IDs to share the resulting AMIs with."
  type        = list(string)
  default     = []
}

variable "schedule_cron" {
  description = "Cron expression for Image Builder pipeline schedule."
  type        = string
  default     = "cron(0 3 * * ? *)" # daily at 03:00 UTC
}

variable "schedule_start_condition" {
  description = "Pipeline execution start condition."
  type        = string
  default     = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
}

variable "enabled" {
  description = "Whether the image pipeline is enabled."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}
