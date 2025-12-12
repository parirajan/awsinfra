terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

##########################
# Core VPC
##########################

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "vpc"])
      Notes = var.generic_tag_notes
    }
  )
}

##########################
# Subnets (3 AZs)
##########################

# Private subnets
resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = "${data.aws_region.current.name}a"

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "private-subnet-a"])
      Notes = var.generic_tag_notes
    }
  )
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = "${data.aws_region.current.name}b"

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "private-subnet-b"])
      Notes = var.generic_tag_notes
    }
  )
}

resource "aws_subnet" "private_subnet_c" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_c_cidr
  availability_zone = "${data.aws_region.current.name}c"

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "private-subnet-c"])
      Notes = var.generic_tag_notes
    }
  )
}

# Public subnets
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = "${data.aws_region.current.name}a"
  map_public_ip_on_launch = true

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "public-subnet-a"])
      Notes = var.generic_tag_notes
    }
  )
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = "${data.aws_region.current.name}b"
  map_public_ip_on_launch = true

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "public-subnet-b"])
      Notes = var.generic_tag_notes
    }
  )
}

resource "aws_subnet" "public_subnet_c" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_c_cidr
  availability_zone       = "${data.aws_region.current.name}c"
  map_public_ip_on_launch = true

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "public-subnet-c"])
      Notes = var.generic_tag_notes
    }
  )
}

data "aws_region" "current" {}

##########################
# IGW + NAT (single NAT)
##########################

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "internet-gateway"])
      Notes = var.generic_tag_notes
    }
  )
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "public-route-table"])
      Notes = var.generic_tag_notes
    }
  )
}

resource "aws_route_table_association" "public_route_table_association_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_route_table_association_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_route_table_association_c" {
  subnet_id      = aws_subnet.public_subnet_c.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "nat-gateway-eip"])
      Notes = var.generic_tag_notes
    }
  )
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnet_a.id

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "nat-gateway"])
      Notes = var.generic_tag_notes
    }
  )

  depends_on = [aws_internet_gateway.internet_gateway]
}

##########################
# Private route tables (3)
##########################

resource "aws_route_table" "private_route_table_a" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "private-route-table-a"])
      Notes = var.generic_tag_notes
    }
  )
}

resource "aws_route_table_association" "private_route_table_association_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_route_table_a.id
}

resource "aws_route_table" "private_route_table_b" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "private-route-table-b"])
      Notes = var.generic_tag_notes
    }
  )
}

resource "aws_route_table_association" "private_route_table_association_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_route_table_b.id
}

resource "aws_route_table" "private_route_table_c" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "private-route-table-c"])
      Notes = var.generic_tag_notes
    }
  )
}

resource "aws_route_table_association" "private_route_table_association_c" {
  subnet_id      = aws_subnet.private_subnet_c.id
  route_table_id = aws_route_table.private_route_table_c.id
}

##########################
# S3 Gateway endpoint
##########################

resource "aws_vpc_endpoint" "s3_private_endpoint" {
  vpc_id          = aws_vpc.vpc.id
  service_name    = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  tags = merge(
    var.generic_tags,
    {
      Name  = join("-", [var.base_name, "s3-private-endpoint"])
      Notes = var.generic_tag_notes
    }
  )
}

resource "aws_vpc_endpoint_route_table_association" "s3_private_endpoint_vpc_association_a" {
  route_table_id  = aws_route_table.private_route_table_a.id
  vpc_endpoint_id = aws_vpc_endpoint.s3_private_endpoint.id
}

resource "aws_vpc_endpoint_route_table_association" "s3_private_endpoint_vpc_association_b" {
  route_table_id  = aws_route_table.private_route_table_b.id
  vpc_endpoint_id = aws_vpc_endpoint.s3_private_endpoint.id
}

resource "aws_vpc_endpoint_route_table_association" "s3_private_endpoint_vpc_association_c" {
  route_table_id  = aws_route_table.private_route_table_c.id
  vpc_endpoint_id = aws_vpc_endpoint.s3_private_endpoint.id
}

