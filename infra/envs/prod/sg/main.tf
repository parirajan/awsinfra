data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "pjtfstatebackend"
    key    = "rtgs/network/terraform.tfstate"
    region = "us-east-1"
  }
}

module "ssm_sg" {
  source = "../modules/sg"

  name          = var.name
  vpc_id        = data.terraform_remote_state.network.outputs.vpc_id
  ingress_rules = var.ingress_rules
  egress_rules  = var.egress_rules
  tags          = var.tags
}
