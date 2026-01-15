region = "us-east-1"

role_name             = "anchorbank-utility-ec2-ssm-role"
instance_profile_name = "anchorbank-utility-ec2-ssm-profile"

managed_policy_arns = [
  "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder",
  "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
]

# Optional inline policies (uncomment only if needed)
# inline_policies = {
#   "extra-logs-access" = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect   = "Allow"
#         Action   = ["s3:GetObject", "s3:PutObject"]
#         Resource = "arn:aws:s3:::anchorbank-logs-bucket/*"
#       }
#     ]
#   })
# }

tags = {
  Environment = "anchorbank-dev"
  Owner       = "platform-team"
}
