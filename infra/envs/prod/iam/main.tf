locals {
  ec2_assume_role = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

module "ec2_ssm_iam" {
  source = "../modules/iam"

  role_name               = var.role_name
  assume_role_policy_json = local.ec2_assume_role

  instance_profile_name   = var.instance_profile_name
  create_instance_profile = true

  managed_policy_arns = var.managed_policy_arns
  inline_policies     = var.inline_policies
  tags                = var.tags
}
