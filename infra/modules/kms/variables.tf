variable "description" {
  type        = string
  description = "Description for the CMK."
}

variable "alias_name" {
  type        = string
  description = "KMS alias name (must start with alias/)."
}

variable "tags" {
  type        = map(string)
  default     = {}
}
