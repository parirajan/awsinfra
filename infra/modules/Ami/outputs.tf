output "ami_id_east" {
  value       = aws_ami_from_instance.nginx_ami_east.id
  description = "NGINX AMI ID in us-east-1"
}

output "ami_id_west" {
  value       = aws_ami_copy.nginx_ami_west.id
  description = "NGINX AMI ID in us-west-2"
}
