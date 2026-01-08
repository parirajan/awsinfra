output "logs_kms_key_arn" {
  value       = module.kms_logs.key_arn
  description = "CMK ARN for Image Builder logs."
}
