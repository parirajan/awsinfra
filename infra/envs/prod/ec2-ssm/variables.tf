variable "region" {
  type    = string
  default = "us-east-1"
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
