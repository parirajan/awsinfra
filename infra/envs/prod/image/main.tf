locals {
  name_prefix = "myapp-prod-image"
}


# Remote state from your VPC stack
data "terraform_remote_state" "rtgs_network" {
  backend = "s3"

  config = {
    bucket = "pjtfstatebackend"                       # existing tf-state bucket
    key    = "network/rtgs/terraform.tfstate"        # adjust to your network state path
    region = "us-east-1"
  }
}

# 1) S3 bucket for Image Builder logs (NEW bucket – or comment this out if you already have one)
resource "aws_s3_bucket" "imagebuilder_logs" {
  bucket = "pjtf-imagebuilder-logs-rtgs-us-east-1"   # must be globally unique
}

resource "aws_s3_bucket_versioning" "imagebuilder_logs" {
  bucket = aws_s3_bucket.imagebuilder_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "imagebuilder_logs" {
  bucket = aws_s3_bucket.imagebuilder_logs.id
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }
}

# 2) Instance profile for Image Builder (NEW – skip if you already have one)

resource "aws_iam_role" "imagebuilder_instance_role" {
  name = "rtgs-imagebuilder-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach the AWS-managed policies recommended for Image Builder
resource "aws_iam_role_policy_attachment" "imagebuilder_core" {
  role       = aws_iam_role.imagebuilder_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

resource "aws_iam_role_policy_attachment" "imagebuilder_ssm" {
  role       = aws_iam_role.imagebuilder_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "imagebuilder_instance_profile" {
  name = "rtgs-imagebuilder-ec2-profile"
  role = aws_iam_role.imagebuilder_instance_role.name
}

# 3) Base AMI – Amazon Linux 2023 in us-east-1 (pin to your choice)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]   # adjust to arm64 if needed
  }
}

locals {
  name_prefix = "rtgs-image"
}

module "image_builder" {
  source = "../../../modules/image_builder"

  name             = local.name_prefix
  parent_image_arn = data.aws_ami.al2023.arn      # <‑ base image

  root_volume_size = 40
  instance_types   = ["t3.large"]

  # from VPC remote state
  subnet_id          = data.terraform_remote_state.rtgs_network.outputs.primary_public_subnet_ids[0]
  security_group_ids = [aws_security_group.image_builder_sg.id]  # or from remote state: data.terraform_remote_state...outputs.imagebuilder_sg_ids

  ssh_key_name          = null

  # Instance profile – NEW or existing
  instance_profile_name = aws_iam_instance_profile.imagebuilder_instance_profile.name
  # if you already have one, replace with the literal name, e.g.
  # instance_profile_name = "existing-imagebuilder-profile"

  # Logs bucket – NEW bucket above (or existing one)
  log_bucket_name = aws_s3_bucket.imagebuilder_logs.bucket
  # if using an existing bucket instead, just set:
  # log_bucket_name = "pjtf-imagebuilder-logs-rtgs-us-east-1"

  share_with_account_ids = var.share_with_account_ids

  schedule_cron            = "cron(0 5 ? * SAT *)"
  schedule_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
  enabled                  = true

  tags = var.tags
}



module "image_builder" {
  source = "../../modules/image_builder"

  name                   = local.name_prefix
  parent_image_arn       = var.parent_image_arn
  root_volume_size       = 40
  instance_types         = ["t3.large"]
  subnet_id              = var.subnet_id
  security_group_ids     = var.security_group_ids
  ssh_key_name           = null
  instance_profile_name  = var.instance_profile_name
  log_bucket_name        = var.log_bucket_name
  share_with_account_ids = var.share_with_account_ids

  schedule_cron              = "cron(0 5 ? * SAT *)" # weekly Saturday builds
  schedule_start_condition   = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
  enabled                    = true

  tags = var.tags
}
