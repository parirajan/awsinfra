# This module expects providers = { aws = aws.primary, aws.west = aws.secondary }

provider "aws" {
  alias = "west"
}

resource "aws_instance" "nginx_builder" {
  ami                    = var.source_ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    yum update -y || apt-get update -y
    yum install -y nginx || (apt-get install -y nginx)
    systemctl enable nginx || (systemctl enable nginx || true)
    systemctl start nginx || (systemctl start nginx || true)
  EOF

  tags = {
    Name = "${var.base_name}-nginx-builder"
  }
}

resource "aws_ami_from_instance" "nginx_ami_east" {
  name               = "${var.base_name}-nginx-ami"
  source_instance_id = aws_instance.nginx_builder.id

  tags = {
    Name = "${var.base_name}-nginx-ami"
  }

  depends_on = [aws_instance.nginx_builder]
}

resource "aws_ami_copy" "nginx_ami_west" {
  provider          = aws.west
  name              = "${var.base_name}-nginx-ami-copy"
  source_ami_id     = aws_ami_from_instance.nginx_ami_east.id
  source_ami_region = "us-east-1"

  tags = {
    Name = "${var.base_name}-nginx-ami-west"
  }
}
