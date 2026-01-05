output "image_recipe_arn" {
  description = "ARN of the Image Builder recipe."
  value       = aws_imagebuilder_image_recipe.this.arn
}

output "infrastructure_configuration_arn" {
  description = "ARN of the Image Builder infrastructure configuration."
  value       = aws_imagebuilder_infrastructure_configuration.this.arn
}

output "distribution_configuration_arn" {
  description = "ARN of the Image Builder distribution configuration."
  value       = aws_imagebuilder_distribution_configuration.this.arn
}

output "pipeline_arn" {
  description = "ARN of the Image Builder image pipeline."
  value       = aws_imagebuilder_image_pipeline.this.arn
}
