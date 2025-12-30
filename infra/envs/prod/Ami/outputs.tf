# envs/prod/ami/outputs.tf

output "nginx_ami_east" {
  value       = module.nginx_ami.ami_id_east
  description = "NGINX AMI ID in us-east-1 (prod)"
}

output "nginx_ami_west" {
  value       = module.nginx_ami.ami_id_west
  description = "NGINX AMI ID in us-west-2 (prod)"
}
