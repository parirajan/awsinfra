output "imagebuilder_instance_profile_name" {
  description = "Instance profile name for Image Builder EC2 instances in rtgs."
  value       = module.imagebuilder_iam.instance_profile_name
}

output "imagebuilder_role_name" {
  description = "IAM role name for Image Builder EC2 instances in rtgs."
  value       = module.imagebuilder_iam.role_name
}
