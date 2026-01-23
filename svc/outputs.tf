output "nlb_dns_name" {
  value = module.nlb_utility.nlb_dns_name
}

output "dns_record_name" {
  value = module.nlb_utility.dns_record_name
}

output "nlb_sg_id" {
  value = module.nlb_utility.nlb_sg_id
}

output "target_group_arn" {
  value = module.nlb_utility.target_group_arn
}
