output "instance_profile_name" {
  description = "Name of the instance profile used by Image Builder instances."
  value       = aws_iam_instance_profile.instance.name
}

output "role_name" {
  description = "Name of the IAM role used by Image Builder instances."
  value       = aws_iam_role.instance.name
}
