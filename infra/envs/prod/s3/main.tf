data "terraform_remote_state" "kms_logs" {
  backend = "s3"

  config = {
    bucket = "pjtfstatebackend"
    key    = "rtgs/kms-logs/terraform.tfstate"
    region = "us-east-1"
  }
}

module "s3_logs" {
  source      = "../../../modules/s3_logs"
  bucket_name = "pjtf-imagebuilder-logs-rtgs-us-east-1"
  kms_key_arn = data.terraform_remote_state.kms_logs.outputs.logs_kms_key_arn
  tags        = var.tags
}
