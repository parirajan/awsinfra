output "logs_bucket_name" {
  value       = module.s3_logs.bucket_name
  description = "Logs bucket name for Image Builder."
}
