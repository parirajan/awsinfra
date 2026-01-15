region = "us-east-1"

role_name             = "rtgs-utility-ec2-imagebuilder-ssm-role"
instance_profile_name = "rtgs-utility-ec2-imagebuilder-ssm-profile"

managed_policy_arns = [
  "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder",
  "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
]

inline_policies = {
  "extra-logs-access" = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "arn:aws:s3:::rtgs-logs-bucket/*"
      }
    ]
  })
}

tags = {
  Environment = "rtgs-dev"
  Owner       = "platform-team"
}
