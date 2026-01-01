variable "base_name" {
  description = "Base name/prefix for the pipeline and AMIs"
  type        = string
}

variable "parent_image" {
  description = "Base image ARN or AMI ID (e.g., Amazon Linux 2/2023) in us-east-1"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID in the VPC where Image Builder will launch build instances (us-east-1)"
  type        = string
}

variable "security_group_ids" {
  description = "Security groups to attach to the build instances"
  type        = list(string)
}

variable "instance_type" {
  description = "Instance type for the build environment"
  type        = string
  default     = "t3.micro"
}

variable "tags" {
  description = "Common tags to apply to Image Builder resources and AMIs"
  type        = map(string)
  default     = {}
}
