output "ami_id" {
  value = aws_ami_from_instance.built.id
}

output "builder_instance_id" {
  value = aws_instance.builder.id
}

output "base_ami_id" {
  value = aws_instance.builder.ami
}
