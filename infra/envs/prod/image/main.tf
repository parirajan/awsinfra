locals {
  name_prefix = "myapp-prod-image"
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
