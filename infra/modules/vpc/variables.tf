variable "base_name" {
  description = "Base name prefix for all resources in this VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

# 3 private subnets (one per AZ)
variable "private_subnet_a_cidr" { type = string }
variable "private_subnet_b_cidr" { type = string }
variable "private_subnet_c_cidr" { type = string }

# 3 public subnets (one per AZ)
variable "public_subnet_a_cidr" { type = string }
variable "public_subnet_b_cidr" { type = string }
variable "public_subnet_c_cidr" { type = string }

variable "generic_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "generic_tag_notes" {
  description = "Notes tag value"
  type        = string
  default     = ""
}

