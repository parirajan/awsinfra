provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  backend "s3" {
    bucket = "pjtfstatebackend"
    key    = "rtgs/image/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1"
}

