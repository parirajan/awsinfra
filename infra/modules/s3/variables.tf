variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket for logs."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used for SSE-KMS."
}

variable "tags" {
  type        = map(string)
  default     = {}
}
