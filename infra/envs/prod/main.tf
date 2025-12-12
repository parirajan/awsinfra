module "vpc_primary" {
  source = "../../modules/vpc"

  providers = {
    aws = aws.primary
  }

  base_name = var.vpc1_base_name
  vpc_cidr  = var.vpc1_cidr

  private_subnet_a_cidr = var.vpc1_private_subnet_a
  private_subnet_b_cidr = var.vpc1_private_subnet_b
  private_subnet_c_cidr = var.vpc1_private_subnet_c

  public_subnet_a_cidr = var.vpc1_public_subnet_a
  public_subnet_b_cidr = var.vpc1_public_subnet_b
  public_subnet_c_cidr = var.vpc1_public_subnet_c

  generic_tags      = var.generic_tags
  generic_tag_notes = var.generic_tag_notes
}

module "vpc_secondary" {
  source = "../../modules/vpc"

  providers = {
    aws = aws.secondary
  }

  base_name = var.vpc2_base_name
  vpc_cidr  = var.vpc2_cidr

  private_subnet_a_cidr = var.vpc2_private_subnet_a
  private_subnet_b_cidr = var.vpc2_private_subnet_b
  private_subnet_c_cidr = var.vpc2_private_subnet_c

  public_subnet_a_cidr = var.vpc2_public_subnet_a
  public_subnet_b_cidr = var.vpc2_public_subnet_b
  public_subnet_c_cidr = var.vpc2_public_subnet_c

  generic_tags      = var.generic_tags
  generic_tag_notes = var.generic_tag_notes
}

# Cross-region VPC peering (dev east ↔ west only)
resource "aws_vpc_peering_connection" "primary_to_secondary" {
  provider    = aws.primary
  vpc_id      = module.vpc_primary.vpc_id
  peer_vpc_id = module.vpc_secondary.vpc_id
  peer_region = "us-west-2"
  auto_accept = false

  tags = merge(var.generic_tags, {
    Name = "dev-primary-to-secondary-peering"
  })
}

resource "aws_vpc_peering_connection_accepter" "secondary_accepts" {
  provider                  = aws.secondary
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
  auto_accept               = true

  tags = merge(var.generic_tags, {
    Name = "dev-secondary-accepts-primary"
  })
}

# Routes in primary VPC to reach secondary
resource "aws_route" "primary_private_to_secondary" {
  provider                  = aws.primary
  count                     = length(module.vpc_primary.private_route_table_ids)

  route_table_id            = module.vpc_primary.private_route_table_ids[count.index]
  destination_cidr_block    = var.vpc2_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
}

resource "aws_route" "primary_public_to_secondary" {
  provider                  = aws.primary
  route_table_id            = module.vpc_primary.public_route_table_id
  destination_cidr_block    = var.vpc2_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
}

# Routes in secondary VPC to reach primary
resource "aws_route" "secondary_private_to_primary" {
  provider                  = aws.secondary
  count                     = length(module.vpc_secondary.private_route_table_ids)

  route_table_id            = module.vpc_secondary.private_route_table_ids[count.index]
  destination_cidr_block    = var.vpc1_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.secondary_accepts.id
}

resource "aws_route" "secondary_public_to_primary" {
  provider                  = aws.secondary
  route_table_id            = module.vpc_secondary.public_route_table_id
  destination_cidr_block    = var.vpc1_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.secondary_accepts.id
}

output "primary_vpc_id"   { value = module.vpc_primary.vpc_id }
output "secondary_vpc_id" { value = module.vpc_secondary.vpc_id }
output "vpc_peering_id"   { value = aws_vpc_peering_connection.primary_to_secondary.id }

