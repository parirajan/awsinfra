output "state_bucket_name" {
  description = "Name of the created S3 bucket for Terraform state"
  value       = aws_s3_bucket.tf_state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.tf_state.arn
}

output "kms_key_arn" {
  description = "KMS key ARN used for S3 state bucket encryption"
  value       = aws_kms_key.tf_state.arn
}

output "kms_key_alias" {
  description = "Alias for the KMS key used for state encryption"
  value       = aws_kms_alias.tf_state_alias.name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for state locking (if created)"
  value       = var.create_lock_table ? aws_dynamodb_table.tf_lock[0].name : null
}

