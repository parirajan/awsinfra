output "nlb_arn" {
  value = aws_lb.this.arn
}

output "nlb_dns_name" {
  value = aws_lb.this.dns_name
}

output "nlb_sg_id" {
  value = aws_security_group.nlb.id
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "dns_record_name" {
  value = aws_route53_record.dns.fqdn
}
