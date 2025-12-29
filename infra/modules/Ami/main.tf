data "aws_region" "current" {}

data "aws_ami" "al2023" {
  count       = var.base_ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  base_ami = coalesce(var.base_ami_id, one(data.aws_ami.al2023[*].id))

  using_s3_script = var.s3_script_bucket != null && var.s3_script_key != null

  effective_commands = length(var.ssm_commands) > 0 ? var.ssm_commands : (
    local.using_s3_script ? [
      "set -euo pipefail",
      "dnf -y update",
      "dnf -y install awscli",
      "aws s3 cp s3://${var.s3_script_bucket}/${var.s3_script_key} /tmp/installer.sh",
      "chmod +x /tmp/installer.sh",
      "/tmp/installer.sh"
    ] : [
      "echo 'ERROR: Provide either ssm_commands or s3_script_bucket+s3_script_key'",
      "exit 1"
    ]
  )
}

resource "aws_security_group" "builder" {
  name        = "${var.name_prefix}-builder-sg"
  description = "SSM-only builder SG (egress only)"
  vpc_id      = var.vpc_id

  # No ingress needed for SSM-only builds
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-builder-sg" })
}

resource "aws_iam_role" "builder" {
  name = "${var.name_prefix}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role      = aws_iam_role.builder.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "s3_read_script" {
  count = local.using_s3_script ? 1 : 0

  name = "${var.name_prefix}-s3-read-script"
  role = aws_iam_role.builder.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject"],
        Resource = "arn:aws:s3:::${var.s3_script_bucket}/${var.s3_script_key}"
      },
      {
        Effect   = "Allow",
        Action   = ["s3:ListBucket"],
        Resource = "arn:aws:s3:::${var.s3_script_bucket}",
        Condition = {
          StringLike = {
            "s3:prefix" = [var.s3_script_key]
          }
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "builder" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.builder.name
}

resource "aws_instance" "builder" {
  ami                    = local.base_ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.builder.id]

  iam_instance_profile = aws_iam_instance_profile.builder.name

  # Bootstrap SSM agent (AL2023 typically already has it, but safe)
  user_data = <<-EOF
    #!/bin/bash
    set -e
    dnf -y install amazon-ssm-agent || true
    systemctl enable amazon-ssm-agent || true
    systemctl restart amazon-ssm-agent || true
  EOF

  tags = merge(var.tags, { Name = "${var.name_prefix}-builder" })
}

resource "null_resource" "wait_for_ssm" {
  depends_on = [aws_instance.builder]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    environment = {
      AWS_REGION  = data.aws_region.current.name
      INSTANCE_ID = aws_instance.builder.id
    }
    command = <<-EOT
      set -euo pipefail
      echo "Waiting for SSM Online: $INSTANCE_ID"
      for i in {1..60}; do
        status=$(aws ssm describe-instance-information \
          --filters Key=InstanceIds,Values="$INSTANCE_ID" \
          --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || true)

        if [[ "$status" == "Online" ]]; then
          echo "SSM is Online"
          exit 0
        fi

        sleep 10
      done
      echo "ERROR: Timed out waiting for SSM Online"
      exit 1
    EOT
  }
}

resource "null_resource" "run_ssm_commands" {
  depends_on = [null_resource.wait_for_ssm]

  triggers = {
    instance_id = aws_instance.builder.id
    commands    = sha256(jsonencode(local.effective_commands))
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    environment = {
      AWS_REGION  = data.aws_region.current.name
      INSTANCE_ID = aws_instance.builder.id
      COMMANDS    = jsonencode(local.effective_commands)
    }
    command = <<-EOT
      set -euo pipefail

      echo "Sending SSM command to $INSTANCE_ID"
      cmd_id=$(aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --comment "AMI build via Terraform+SSM" \
        --parameters commands="$COMMANDS" \
        --query 'Command.CommandId' --output text)

      echo "CommandId: $cmd_id - waiting..."
      aws ssm wait command-executed --command-id "$cmd_id" --instance-id "$INSTANCE_ID"

      status=$(aws ssm get-command-invocation \
        --command-id "$cmd_id" --instance-id "$INSTANCE_ID" \
        --query 'Status' --output text)

      if [[ "$status" != "Success" ]]; then
        echo "ERROR: SSM command failed with status=$status"
        aws ssm get-command-invocation \
          --command-id "$cmd_id" --instance-id "$INSTANCE_ID" \
          --query 'StandardErrorContent' --output text || true
        exit 1
      fi

      echo "SSM command succeeded."
    EOT
  }
}

resource "aws_ami_from_instance" "built" {
  name                    = "${var.name_prefix}-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  source_instance_id      = aws_instance.builder.id
  snapshot_without_reboot = var.snapshot_without_reboot

  tags = merge(var.tags, { Name = "${var.name_prefix}-ami" })

  depends_on = [null_resource.run_ssm_commands]
}
