variable "name_prefix" {
  type    = string
  default = "ssm-ami"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where builder SG is created."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where builder instance is launched."
}

variable "base_ami_id" {
  type        = string
  default     = null
  description = "Optional base AMI override. If null, latest Amazon Linux 2023 x86_64 is used."
}

# Option A: Inline commands executed via SSM
variable "ssm_commands" {
  type        = list(string)
  default     = []
  description = "Shell commands to execute via AWS-RunShellScript."
}

# Option B: Pull installer script from S3 and run it
variable "s3_script_bucket" {
  type        = string
  default     = null
  description = "S3 bucket containing installer script (optional)."
}

variable "s3_script_key" {
  type        = string
  default     = null
  description = "S3 key for installer script (optional)."
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "snapshot_without_reboot" {
  type    = bool
  default = true
}
