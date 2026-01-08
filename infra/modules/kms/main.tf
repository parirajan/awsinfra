resource "aws_kms_key" "this" {
  description         = var.description
  enable_key_rotation = true
  tags                = var.tags
}

resource "aws_kms_alias" "this" {
  name          = var.alias_name  # e.g. "alias/rtgs-imagebuilder-logs"
  target_key_id = aws_kms_key.this.key_id
}
