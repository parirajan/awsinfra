terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "my-tf-state-bucket"
    key            = "network/prod-multi-region-vpcs.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform_state_lock"
  }
}

provider "aws" {
  alias   = "primary"
  region  = "us-east-1"
}

provider "aws" {
  alias   = "secondary"
  region  = "us-west-2"
}

