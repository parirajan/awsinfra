output "instance_id" {
  value = aws_instance.this.id
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "iam_role_name" {
  value = aws_iam_role.this.name
}
