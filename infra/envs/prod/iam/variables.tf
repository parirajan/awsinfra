variable "region" {
  type    = string
  default = "us-east-1"
}

variable "role_name" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "managed_policy_arns" {
  type = list(string)
}

variable "inline_policies" {
  type    = map(string)
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
