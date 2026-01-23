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

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "poccloudbeta1"
    key    = "anchorbank/network/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "ec2_ssm" {
  backend = "s3"
  config = {
    bucket = "poccloudbeta1"
    key    = "anchorbank/ec2-ssm/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "dns" {
  backend = "s3"
  config = {
    bucket = "poccloudbeta1"
    key    = "anchorbank/dns/terraform.tfstate"
    region = var.region
  }
}

module "nlb_utility" {
  source = "../../../modules/nlb-ec2-ssm"

  name   = "anchorbank-utility"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  public_subnet_ids = data.terraform_remote_state.network.outputs.public_subnet_ids

  listener_port = var.listener_port
  target_port   = var.target_port

  instance_ids = data.terraform_remote_state.ec2_ssm.outputs.instance_ids

  route53_zone_id      = data.terraform_remote_state.dns.outputs.public_zone_id
  dns_name             = var.dns_name
  allowed_client_cidrs = var.allowed_client_cidrs
  tags                 = var.tags
}
