module "kms_logs" {
  source      = "../../../modules/kms_logs"
  description = "KMS key for Image Builder logs in rtgs"
  alias_name  = "alias/rtgs-imagebuilder-logs"
  tags        = var.tags
}
