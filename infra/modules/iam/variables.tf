variable "role_name" {
  description = "Name of the IAM role to create"
  type        = string
}

variable "assume_role_policy_json" {
  description = "JSON trust policy document for the role"
  type        = string
}

variable "managed_policy_arns" {
  description = "List of AWS or customer-managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "Map of inline policy_name => JSON policy document"
  type        = map(string)
  default     = {}
}

variable "create_instance_profile" {
  description = "Whether to create an instance profile for this role"
  type        = bool
  default     = true
}

variable "instance_profile_name" {
  description = "Instance profile name (required if create_instance_profile = true)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
