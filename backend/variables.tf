variable "aws_region" {
  description = "Region where the S3 state bucket and KMS key will be created"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Logical environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket to hold Terraform remote state"
  type        = string
}

variable "bucket_versioning_enabled" {
  description = "Enable S3 versioning on the state bucket"
  type        = bool
  default     = true
}

variable "create_lock_table" {
  description = "Whether to create a DynamoDB table for state locking"
  type        = bool
  default     = true
}

variable "lock_table_name" {
  description = "Name of DynamoDB table used for Terraform state locking"
  type        = string
  default     = "terraform_state_lock"
}
