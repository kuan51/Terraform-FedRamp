# Passthrough of the module contract. Layers 2 and 5 read these -- and nothing else.

output "vnet_id" {
  description = "Virtual network resource ID."
  value       = module.network.vnet_id
}

output "subnet_ids" {
  description = "Map of subnet resource IDs keyed by purpose."
  value       = module.network.subnet_ids
}

output "dns_zone_name" {
  description = "Name of the public DNS zone."
  value       = module.network.dns_zone_name
}

output "dns_zone_id" {
  description = "Public DNS zone resource ID."
  value       = module.network.dns_zone_id
}

output "dns_zone_nameservers" {
  description = "The NS records to add at the registrar to complete delegation. Read this after apply; it is the input to the dns-delegation runbook."
  value       = module.network.dns_zone_nameservers
}

output "private_dns_zone_ids" {
  description = "Map of private DNS zone resource IDs keyed by purpose."
  value       = module.network.private_dns_zone_ids
}
