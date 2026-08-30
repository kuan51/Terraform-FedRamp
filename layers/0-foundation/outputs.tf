# Passthrough of the module's contract. Layers 1, 2, 3 and 5 read these via
# terraform_remote_state -- and nothing else.

output "workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = module.foundation.workspace_id
}

output "key_vault_id" {
  description = "Key Vault resource ID."
  value       = module.foundation.key_vault_id
}

output "action_group_id" {
  description = "Operations action group resource ID."
  value       = module.foundation.action_group_id
}

output "resource_group_names" {
  description = "Map of resource group names keyed by purpose."
  value       = module.foundation.resource_group_names
}

output "location" {
  description = "Region the foundation was built in."
  value       = module.foundation.location
}
