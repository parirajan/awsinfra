variable "tags" {
  type        = map(string)
  description = "Common tags for IAM resources in rtgs."
  default = {
    Environment = "rtgs"
    Owner       = "platform"
  }
}
