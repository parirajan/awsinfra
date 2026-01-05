terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Optional: get account/region for tagging, ARNs, etc.
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Image Builder components (simplified)
resource "aws_imagebuilder_component" "base" {
  name       = "${var.name}-base-component"
  platform   = "Linux"
  version    = "1.0.0"
  description = "Base hardening / configuration component for ${var.name}"

  data = <<-DOC
    name: BaseConfig
    description: Base configuration
    schemaVersion: 1.0
    phases:
      - name: build
        steps:
          - name: example
            action: ExecuteBash
            inputs:
              commands:
                - echo "Base config step"
  DOC

  tags = merge(var.tags, {
    "imagebuilder:name" = var.name
  })
}

# Image recipe
resource "aws_imagebuilder_image_recipe" "this" {
  name         = "${var.name}-recipe"
  version      = "1.0.0"
  parent_image = var.parent_image_arn   # e.g. AL2023, Windows base, etc.
  description  = "Image recipe for ${var.name}"

  component {
    component_arn = aws_imagebuilder_component.base.arn
  }

  block_device_mapping {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tags = merge(var.tags, {
    "imagebuilder:name" = var.name
  })
}

# Infrastructure configuration
resource "aws_imagebuilder_infrastructure_configuration" "this" {
  name                  = "${var.name}-infra"
  instance_types        = var.instance_types
  subnet_id             = var.subnet_id
  security_group_ids    = var.security_group_ids
  key_pair              = var.ssh_key_name
  terminate_instance_on_failure = true
  instance_profile_name = var.instance_profile_name

  logging {
    s3_logs {
      s3_bucket_name = var.log_bucket_name
      s3_key_prefix  = "imagebuilder/${var.name}"
    }
  }

  tags = merge(var.tags, {
    "imagebuilder:name" = var.name
  })
}

# Distribution configuration (simple, single-region AMI)
resource "aws_imagebuilder_distribution_configuration" "this" {
  name = "${var.name}-dist"

  distribution {
    region = data.aws_region.current.name

    ami_distribution_configuration {
      name = "${var.name}-{{ imagebuilder:buildDate }}"
      description = "AMI from pipeline ${var.name}"
      launch_permission {
        user_ids = var.share_with_account_ids
      }
    }
  }

  tags = merge(var.tags, {
    "imagebuilder:name" = var.name
  })
}

# Image pipeline
resource "aws_imagebuilder_image_pipeline" "this" {
  name                             = "${var.name}-pipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.this.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.this.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.this.arn
  status                           = var.enabled ? "ENABLED" : "DISABLED"

  schedule {
    schedule_expression                      = var.schedule_cron
    pipeline_execution_start_condition       = var.schedule_start_condition
  }

  tags = merge(var.tags, {
    "imagebuilder:name" = var.name
  })
}
