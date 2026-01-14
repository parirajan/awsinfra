terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "pjtfstatebackend"      # your TF state bucket
    key            = "rtgs/ec2-ssm/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "pjtfstatebackend-lock" # optional, if you use state locking
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}


data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "pjtfstatebackend"
    key    = "rtgs/network/terraform.tfstate"
    region = "us-east-1"
  }
}

