variable "tags" {
  type        = map(string)
  description = "Common tags for rtgs environment."
  default = {
    Environment = "rtgs"
    Owner       = "platform"
  }
}
