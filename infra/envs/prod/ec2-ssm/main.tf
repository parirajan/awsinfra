terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "ec2_ssm" {
  source = "./modules/ec2-ssm"

  name              = "rtgs-utility-ec2"
  instance_type     = "t3.micro"
  subnet_id         = subnet_id = data.terraform_remote_state.network.outputs.public_subnet_ids[0]
  security_group_id = var.security_group_id
  tags              = var.tags
}
