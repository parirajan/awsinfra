output "image_builder_pipeline_arn" {
  description = "Image Builder pipeline ARN for prod."
  value       = module.image_builder.pipeline_arn
}

output "image_builder_recipe_arn" {
  description = "Image Builder recipe ARN for prod."
  value       = module.image_builder.image_recipe_arn
}
