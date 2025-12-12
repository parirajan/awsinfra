generic_tags = {
  Owner       = "platform-team"
  Environment = "prod"
}

generic_tag_notes = "multi-region prod vpc"

# Primary VPC (us-east-1)
vpc1_base_name = "core-prod-use1"
vpc1_cidr      = "10.10.0.0/16"

vpc1_private_subnet_a = "10.10.0.0/20"
vpc1_private_subnet_b = "10.10.16.0/20"
vpc1_private_subnet_c = "10.10.32.0/20"

vpc1_public_subnet_a  = "10.10.128.0/20"
vpc1_public_subnet_b  = "10.10.144.0/20"
vpc1_public_subnet_c  = "10.10.160.0/20"

# Secondary VPC (us-west-2)
vpc2_base_name = "core-prod-usw2"
vpc2_cidr      = "10.11.0.0/16"

vpc2_private_subnet_a = "10.11.0.0/20"
vpc2_private_subnet_b = "10.11.16.0/20"
vpc2_private_subnet_c = "10.11.32.0/20"

vpc2_public_subnet_a  = "10.11.128.0/20"
vpc2_public_subnet_b  = "10.11.144.0/20"
vpc2_public_subnet_c  = "10.11.160.0/20"

