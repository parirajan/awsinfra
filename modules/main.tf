resource "aws_security_group" "nlb" {
  name        = "${var.name}-nlb-sg"
  description = "SG for public NLB"
  vpc_id      = var.vpc_id

  # Inbound from clients on listener port
  ingress {
    from_port   = var.listener_port
    to_port     = var.listener_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_client_cidrs
  }

  # Outbound to instances (allow all, stateful)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-nlb-sg"
  })
}

resource "aws_lb" "this" {
  name               = "${var.name}-nlb"
  load_balancer_type = "network"
  internal           = false
  subnets            = var.public_subnet_ids

  # NLB SG support requires recent AWS provider
  security_groups = [aws_security_group.nlb.id]

  enable_cross_zone_load_balancing = true

  tags = merge(var.tags, {
    Name = "${var.name}-nlb"
  })
}

resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = var.target_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  tags = merge(var.tags, {
    Name = "${var.name}-tg"
  })
}

resource "aws_lb_target_group_attachment" "this" {
  for_each         = toset(var.instance_ids)
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = each.value
  port             = var.target_port
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_route53_record" "dns" {
  zone_id = var.route53_zone_id
  name    = var.dns_name
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = false
  }
}
