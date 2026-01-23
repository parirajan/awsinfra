variable "region" {
  type    = string
  default = "us-east-1"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "listener_port" {
  type    = number
  default = 22
}

variable "target_port" {
  type    = number
  default = 22
}

variable "dns_name" {
  description = "Public DNS record for NLB"
  type        = string
  default     = "utility.anchorbank.com"
}

variable "allowed_client_cidrs" {
  description = "CIDRs that can reach the NLB"
  type        = list(string)
  default     = ["0.0.0.0/0"] # tighten to corp CIDR later
}
