terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  backend "s3" {
    bucket         = "mycompany-tf-state-prod"
    key            = "image-builder/prod.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks-prod"
    encrypt        = true
    kms_key_id     = "alias/terraform-state-key-prod"
  }
}

provider "aws" {
  region = "us-east-1"
}
