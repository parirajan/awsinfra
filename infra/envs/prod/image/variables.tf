variable "share_with_account_ids" {
  type        = list(string)
  description = "Accounts to share AMIs with."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Common tags for rtgs Image Builder."
  default = {
    Environment = "rtgs"
    Owner       = "platform"
  }
}
