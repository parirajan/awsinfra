data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "pjtfstatebackend"
    key    = "rtgs/network/terraform.tfstate"
    region = "us-east-1"
  }
}

