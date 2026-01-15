name = "rtgs-utility-ec2-ssm-sg"

ingress_rules = []

egress_rules = [
  {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
]

tags = {
  Environment = "rtgs-dev"
  Owner       = "platform-team"
}
