terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      # no configuration_aliases needed; everything uses caller's provider
    }
  }
}

locals {
  name_prefix = var.base_name
}

# IAM role and instance profile for Image Builder infrastructure
resource "aws_iam_role" "imagebuilder_instance_role" {
  name               = "${local.name_prefix}-ib-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ib_instance_ssm" {
  role       = aws_iam_role.imagebuilder_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "imagebuilder_instance_profile" {
  name = "${local.name_prefix}-ib-instance-profile"
  role = aws_iam_role.imagebuilder_instance_role.name
}

# Service role for Image Builder itself
resource "aws_iam_role" "imagebuilder_service_role" {
  name               = "${local.name_prefix}-ib-service-role"
  assume_role_policy = data.aws_iam_policy_document.imagebuilder_assume.json
}

data "aws_iam_policy_document" "imagebuilder_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["imagebuilder.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ib_service_policy" {
  role       = aws_iam_role.imagebuilder_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

############################
# NGINX component
############################

# Simple component to install & enable nginx
resource "aws_imagebuilder_component" "nginx" {
  name        = "${local.name_prefix}-nginx-component"
  platform    = "Linux"
  version     = "1.0.0"
  description = "Install and enable NGINX"

  data = <<-DOC
    name: InstallNginx
    description: Install and enable NGINX
    schemaVersion: 1.0
    phases:
      - name: build
        steps:
          - name: InstallNginx
            action: ExecuteBash
            inputs:
              commands:
                - |
                  if command -v yum >/dev/null 2>&1; then
                    yum update -y
                    yum install -y nginx
                  elif command -v apt-get >/dev/null 2>&1; then
                    apt-get update -y
                    apt-get install -y nginx
                  fi
                  systemctl enable nginx || true
                  systemctl start nginx || true
  DOC
}

############################
# Image recipe
############################

resource "aws_imagebuilder_image_recipe" "nginx_recipe" {
  name         = "${local.name_prefix}-nginx-recipe"
  version      = "1.0.0"
  parent_image = var.parent_image   # can be ARN or AMI ID
  description  = "AMIs with NGINX installed"

  component {
    component_arn = aws_imagebuilder_component.nginx.arn
  }

  block_device_mapping {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 16
      volume_type = "gp3"
    }
  }
}

############################
# Infrastructure configuration
############################

resource "aws_imagebuilder_infrastructure_configuration" "nginx_infra" {
  name                  = "${local.name_prefix}-nginx-infra"
  instance_types        = [var.instance_type]
  subnet_id             = var.subnet_id
  security_group_ids    = var.security_group_ids
  instance_profile_name = aws_iam_instance_profile.imagebuilder_instance_profile.name
  terminate_instance_on_failure = true

  tags = var.tags
}

############################
# Distribution configuration
############################

resource "aws_imagebuilder_distribution_configuration" "nginx_dist" {
  name = "${local.name_prefix}-nginx-dist"

  # Primary region (same region as provider)
  distribution {
    region = data.aws_region.current.name

    ami_distribution_configuration {
      name = "${local.name_prefix}-nginx-ami-{{ imagebuilder:buildDate }}"
      ami_tags = merge(var.tags, {
        Name = "${local.name_prefix}-nginx-ami"
      })
    }
  }

  # Secondary region (hard-coded us-west-2 here)
  distribution {
    region = "us-west-2"

    ami_distribution_configuration {
      name = "${local.name_prefix}-nginx-ami-{{ imagebuilder:buildDate }}"
      ami_tags = merge(var.tags, {
        Name = "${local.name_prefix}-nginx-ami"
      })
    }
  }
}

data "aws_region" "current" {}

############################
# Image (On-demand build)
############################

resource "aws_imagebuilder_image" "nginx_image" {
  image_recipe_arn              = aws_imagebuilder_image_recipe.nginx_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.nginx_infra.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.nginx_dist.arn

  tags = var.tags
}
