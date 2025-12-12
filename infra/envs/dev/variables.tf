variable "generic_tags" {
  type = map(string)
}

variable "generic_tag_notes" {
  type = string
}

# Primary VPC (us-east-1)
variable "vpc1_base_name" { type = string }
variable "vpc1_cidr"      { type = string }

variable "vpc1_private_subnet_a" { type = string }
variable "vpc1_private_subnet_b" { type = string }
variable "vpc1_private_subnet_c" { type = string }

variable "vpc1_public_subnet_a" { type = string }
variable "vpc1_public_subnet_b" { type = string }
variable "vpc1_public_subnet_c" { type = string }

# Secondary VPC (us-west-2)
variable "vpc2_base_name" { type = string }
variable "vpc2_cidr"      { type = string }

variable "vpc2_private_subnet_a" { type = string }
variable "vpc2_private_subnet_b" { type = string }
variable "vpc2_private_subnet_c" { type = string }

variable "vpc2_public_subnet_a" { type = string }
variable "vpc2_public_subnet_b" { type = string }
variable "vpc2_public_subnet_c" { type = string }

