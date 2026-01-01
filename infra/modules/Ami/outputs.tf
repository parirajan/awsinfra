output "image_arn" {
  description = "ARN of the Image Builder image (latest build)"
  value       = aws_imagebuilder_image.nginx_image.arn
}

output "primary_region" {
  description = "Region where the image was built"
  value       = data.aws_region.current.name
}
