terraform {
  required_version = ">= 1.6.0"
  # No backend block → local state for this bootstrap
}

provider "aws" {
  region = var.aws_region
}

#######################################
# KMS key for Terraform state
#######################################

resource "aws_kms_key" "tf_state" {
  description             = "KMS key for Terraform remote state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "${var.state_bucket_name}-kms"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "tf_state_alias" {
  name          = "alias/${var.state_bucket_name}-kms"
  target_key_id = aws_kms_key.tf_state.key_id
}

#######################################
# S3 bucket for Terraform state
#######################################

resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name        = "terraform-state"
    Environment = var.environment
  }
}

# Versioning (optional but recommended)
resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = var.bucket_versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "tf_state_public_block" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSE-KMS encryption (new-style resource, no deprecation warnings)
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_sse" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tf_state.arn
    }
  }
}

#######################################
# DynamoDB table for state locking
#######################################

resource "aws_dynamodb_table" "tf_lock" {
  count        = var.create_lock_table ? 1 : 0
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "terraform-locks"
    Environment = var.environment
  }
}
