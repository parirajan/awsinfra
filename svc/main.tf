data "terraform_remote_state" "ec2_ssm" {
  backend = "s3"
  config = {
    bucket = "your-state-bucket"
    key    = "anchorbank/ec2-ssm/terraform.tfstate"
    region = "us-east-1"
  }
}

module "nlb_utility" {
  source = "../../../modules/nlb-ec2-ssm"

  name        = "anchorbank-utility"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids  = data.terraform_remote_state.network.outputs.primary_private_subnet_ids

  listener_port = 22
  target_port   = 22

  instance_ids = data.terraform_remote_state.ec2_ssm.outputs.instance_ids

  route53_zone_id = data.terraform_remote_state.dns.outputs.private_zone_id
  dns_name        = "utility.anchorbank.internal"
}
