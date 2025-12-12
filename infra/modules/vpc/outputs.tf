output "vpc_id" {
  value       = aws_vpc.vpc.id
  description = "VPC ID"
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value = [
    aws_subnet.public_subnet_a.id,
    aws_subnet.public_subnet_b.id,
    aws_subnet.public_subnet_c.id,
  ]
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value = [
    aws_subnet.private_subnet_a.id,
    aws_subnet.private_subnet_b.id,
    aws_subnet.private_subnet_c.id,
  ]
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public_route_table.id
}

output "private_route_table_ids" {
  description = "Private route table IDs"
  value = [
    aws_route_table.private_route_table_a.id,
    aws_route_table.private_route_table_b.id,
    aws_route_table.private_route_table_c.id,
  ]
}

