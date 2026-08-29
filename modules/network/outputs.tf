# Cross-layer contract. Layers 2 and 5 read these -- and nothing else.

output "vnet_id" {
  description = "Virtual network resource ID."
  value       = azurerm_virtual_network.this.id
}

output "subnet_ids" {
  description = "Map of subnet resource IDs keyed by purpose."
  value = {
    aks_nodes         = azurerm_subnet.aks_nodes.id
    private_endpoints = azurerm_subnet.private_endpoints.id
  }
}

output "dns_zone_name" {
  description = "Name of the public DNS zone, for ingress hostnames and cert-manager."
  value       = azurerm_dns_zone.this.name
}

output "dns_zone_id" {
  description = "Public DNS zone resource ID, for the DNS Zone Contributor assignment cert-manager needs to solve DNS-01 challenges."
  value       = azurerm_dns_zone.this.id
}

output "dns_zone_nameservers" {
  description = "Nameservers Azure assigned to the public zone. These are the NS records the delegation runbook adds at the registrar; they do not exist until this layer has applied."
  value       = azurerm_dns_zone.this.name_servers
}

output "private_dns_zone_ids" {
  description = "Map of private DNS zone resource IDs keyed by purpose, for private endpoint DNS zone groups."
  value       = { for k, z in azurerm_private_dns_zone.this : k => z.id }
}
