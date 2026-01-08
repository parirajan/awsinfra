locals {
  name_prefix = "rtgs-image"
}

# Remote state: network (for subnet/SGs)
data "terraform_remote_state" "rtgs_network" {
  backend = "s3"
  config = {
    bucket = "pjtfstatebackend"
    key    = "rtgs/network/terraform.tfstate"
    region = "us-east-1"
  }
}

# Remote state: KMS logs (not strictly needed here but available)
data "terraform_remote_state" "kms_logs" {
  backend = "s3"
  config = {
    bucket = "pjtfstatebackend"
    key    = "rtgs/kms-logs/terraform.tfstate"
    region = "us-east-1"
  }
}

# Remote state: S3 logs (used by Image Builder infra config)
data "terraform_remote_state" "s3_logs" {
  backend = "s3"
  config = {
    bucket = "pjtfstatebackend"
    key    = "rtgs/s3-logs/terraform.tfstate"
    region = "us-east-1"
  }
}

# IAM for Image Builder EC2 instances
module "imagebuilder_iam" {
  source               = "../../../modules/imagebuilder_iam"
  role_name            = "rtgs-imagebuilder-ec2-role"
  instance_profile_name = "rtgs-imagebuilder-ec2-profile"
}

# Base image: Amazon Linux 2023
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

module "image_builder" {
  source = "../../../modules/image_builder"

  name             = local.name_prefix
  parent_image_arn = data.aws_ami.al2023.arn

  root_volume_size = 40
  instance_types   = ["t3.large"]

  subnet_id          = data.terraform_remote_state.rtgs_network.outputs.primary_public_subnet_ids[0]
  security_group_ids = [data.terraform_remote_state.rtgs_network.outputs.imagebuilder_sg_id]

  ssh_key_name          = null
  instance_profile_name = module.imagebuilder_iam.instance_profile_name

  log_bucket_name       = data.terraform_remote_state.s3_logs.outputs.logs_bucket_name
  share_with_account_ids = var.share_with_account_ids

  schedule_cron            = "cron(0 5 ? * SAT *)"
  schedule_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
  enabled                  = true

  tags = var.tags
}
