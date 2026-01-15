output "ec2_role_name" {
  description = "IAM role name for EC2/SSM"
  value       = module.ec2_ssm_iam.role_name
}

output "ec2_role_arn" {
  description = "IAM role ARN for EC2/SSM"
  value       = module.ec2_ssm_iam.role_arn
}

output "ec2_instance_profile_name" {
  description = "Instance profile name for EC2/SSM"
  value       = module.ec2_ssm_iam.instance_profile_name
}

output "ec2_instance_profile_arn" {
  description = "Instance profile ARN for EC2/SSM"
  value       = module.ec2_ssm_iam.instance_profile_arn
}
