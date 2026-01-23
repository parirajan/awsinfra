variable "name" {
  description = "Base name for NLB resources"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs where NLB ENIs live"
  type        = list(string)
}

variable "listener_port" {
  description = "Port exposed on the NLB"
  type        = number
  default     = 22
}

variable "target_port" {
  description = "Port on EC2 instances"
  type        = number
  default     = 22
}

variable "instance_ids" {
  description = "EC2 instance IDs (targets in private subnets)"
  type        = list(string)
}

variable "route53_zone_id" {
  description = "Hosted zone ID for NLB DNS record"
  type        = string
}

variable "dns_name" {
  description = "Record name (e.g. utility.anchorbank.com)"
  type        = string
}

variable "allowed_client_cidrs" {
  description = "CIDRs allowed to hit the NLB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
