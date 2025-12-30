variable "base_name" {
  description = "Base name for the NGINX AMI"
  type        = string
  default     = "prod"
}

variable "instance_type" {
  description = "Instance type for building the AMI"
  type        = string
  default     = "t3.micro"
}

variable "source_ami_id" {
  description = "Base AMI ID in us-east-1 to install NGINX on"
  type        = string
  default     = "ami-0c02fb55956c7d316" # example Amazon Linux 2
}
