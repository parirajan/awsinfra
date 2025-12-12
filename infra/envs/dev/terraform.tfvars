generic_tags = {
  Owner       = "platform-team"
  Environment = "dev"
}

generic_tag_notes = "multi-region dev vpc"

# Primary VPC (us-east-1)
vpc1_base_name = "core-dev-use1"
vpc1_cidr      = "10.0.0.0/16"

vpc1_private_subnet_a = "10.0.0.0/20"
vpc1_private_subnet_b = "10.0.16.0/20"
vpc1_private_subnet_c = "10.0.32.0/20"

vpc1_public_subnet_a  = "10.0.128.0/20"
vpc1_public_subnet_b  = "10.0.144.0/20"
vpc1_public_subnet_c  = "10.0.160.0/20"

# Secondary VPC (us-west-2)
vpc2_base_name = "core-dev-usw2"
vpc2_cidr      = "10.1.0.0/16"

vpc2_private_subnet_a = "10.1.0.0/20"
vpc2_private_subnet_b = "10.1.16.0/20"
vpc2_private_subnet_c = "10.1.32.0/20"

vpc2_public_subnet_a  = "10.1.128.0/20"
vpc2_public_subnet_b  = "10.1.144.0/20"
vpc2_public_subnet_c  = "10.1.160.0/20"

