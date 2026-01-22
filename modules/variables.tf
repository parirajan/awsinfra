variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "listener_port" {
  type    = number
  default = 22  # or 443 / custom
}

variable "target_port" {
  type    = number
  default = 22
}

variable "instance_ids" {
  type = list(string)
}

variable "route53_zone_id" {
  description = "Hosted zone ID for DNS record"
  type        = string
}

variable "dns_name" {
  description = "DNS name to create (e.g. utility.anchorbank.internal)"
  type        = string
}
