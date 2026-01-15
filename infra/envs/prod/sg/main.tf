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

  name   = "rtgs-utility-ec2-ssm-sg"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  # No ingress rules for pure Session Manager access
  ingress_rules = []

  # Dynamic egress rules: here only HTTPS out
  egress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  tags = var.tags
}
