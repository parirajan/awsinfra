variable "role_name" {
  type        = string
  description = "Name of the EC2 IAM role for Image Builder instances."
}

variable "instance_profile_name" {
  type        = string
  description = "Name of the EC2 instance profile for Image Builder."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to IAM resources where supported."
  default     = {}
}
