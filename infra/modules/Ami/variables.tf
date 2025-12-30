variable "base_name" {
  description = "Base name for AMIs"
  type        = string
}

variable "instance_type" {
  description = "Instance type used to build NGINX AMI"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet ID in the VPC where the build instance runs"
  type        = string
}

variable "security_group_ids" {
  description = "Security groups for the build instance"
  type        = list(string)
  default     = []
}

variable "source_ami_id" {
  description = "Base AMI to start from in us-east-1 (e.g., Amazon Linux)"
  type        = string
}
