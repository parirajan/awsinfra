module "imagebuilder_iam" {
  source = "../../../modules/imagebuilder_iam"

  role_name             = "rtgs-imagebuilder-ec2-role"
  instance_profile_name = "rtgs-imagebuilder-ec2-profile"
  tags                  = var.tags
}
