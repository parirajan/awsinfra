output "key_arn" {
  value       = aws_kms_key.this.arn
  description = "ARN of the CMK."
}

output "alias_arn" {
  value       = aws_kms_alias.this.arn
  description = "ARN of the CMK alias."
}
