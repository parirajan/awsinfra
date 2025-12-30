terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "my-tf-state-bucket"                 # update to your bucket
    key            = "network/prod-ami-nginx.tfstate"    # separate state key
    region         = "us-east-1"
    dynamodb_table = "terraform_state_lock"              # or remove if using S3 native locking
    encrypt        = true
  }
}

# Providers match prod VPC env (primary = us-east-1, secondary = us-west-2)
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}

# Read required outputs from prod VPC remote state
data "terraform_remote_state" "prod_network" {
  backend = "s3"

  config = {
    bucket         = "my-tf-state-bucket"                 # SAME bucket as prod VPC
    key            = "network/prod-multi-region-vpcs.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform_state_lock"
  }
}

locals {
  generic_tags = {
    Owner       = "platform-team"
    Environment = "prod"
    Component   = "nginx-ami"
  }
}

# SG for the temporary AMI-builder instance
resource "aws_security_group" "nginx_builder_sg" {
  provider = aws.primary
  name     = "prod-nginx-builder-sg"
  vpc_id   = data.terraform_remote_state.prod_network.outputs.primary_vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # tighten in real use
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.generic_tags
}

module "nginx_ami" {
  source = "../../../modules/ami-nginx"

  providers = {
    aws      = aws.primary   # build AMI in us-east-1
    aws.west = aws.secondary # copy AMI to us-west-2
  }

  base_name          = "prod"
  instance_type      = "t3.micro"
  subnet_id          = data.terraform_remote_state.prod_network.outputs.primary_public_subnet_ids[0]
  security_group_ids = [aws_security_group.nginx_builder_sg.id]

  # Base AMI in us-east-1 – replace with what you prefer
  source_ami_id = "ami-0c02fb55956c7d316"
}

output "nginx_ami_east" {
  value       = module.nginx_ami.ami_id_east
  description = "NGINX AMI ID in us-east-1 (prod)"
}

output "nginx_ami_west" {
  value       = module.nginx_ami.ami_id_west
  description = "NGINX AMI ID in us-west-2 (prod)"
}
