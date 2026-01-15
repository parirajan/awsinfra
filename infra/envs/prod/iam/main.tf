terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "pjtfstatebackend"
    key            = "rtgs/iam-ec2-imagebuilder-ssm/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "pjtfstatebackend-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

locals {
  ec2_assume_role = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action   = "sts:AssumeRole"
    }]
  })
}

module "ec2_imagebuilder_ssm_iam" {
  source = "../modules/iam"

  role_name               = var.role_name
  assume_role_policy_json = local.ec2_assume_role

  instance_profile_name   = var.instance_profile_name
  create_instance_profile = true

  managed_policy_arns = var.managed_policy_arns
  inline_policies     = var.inline_policies
  tags                = var.tags
}

output "instance_profile_name" {
  value = module.ec2_imagebuilder_ssm_iam.instance_profile_name
}

output "role_name" {
  value = module.ec2_imagebuilder_ssm_iam.role_name
}
