terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "pjtfstatebackend"
    key            = "rtgs/sg-ssm/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "pjtfstatebackend-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}
