output "ssm_sg_id" {
  value       = module.ssm_sg.id
  description = "Security group ID for SSM-managed EC2"
}
