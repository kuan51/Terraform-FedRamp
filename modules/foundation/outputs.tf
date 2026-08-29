# Cross-layer contract. This is the ENTIRE surface layers 1, 2, 3 and 5 may read -- and
# nothing else. `terraform validate` cannot check remote-state reads, so this list being
# exhaustive and stable is what stands in for that verification. Adding to it is a
# deliberate, visible edit.

output "workspace_id" {
  description = "Log Analytics workspace resource ID. Every diagnostic setting in the estate targets this."
  value       = azurerm_log_analytics_workspace.this.id
}

output "key_vault_id" {
  description = "Key Vault resource ID, for RBAC assignments and the cluster's CSI driver."
  value       = azurerm_key_vault.this.id
}

output "action_group_id" {
  description = "Operations action group resource ID, for alert rules in later layers."
  value       = azurerm_monitor_action_group.ops.id
}

output "resource_group_names" {
  description = "Map of resource group names keyed by purpose."
  value = {
    security = azurerm_resource_group.security.name
    platform = azurerm_resource_group.platform.name
  }
}

output "location" {
  description = "Region the foundation was built in, so later layers cannot drift to another."
  value       = azurerm_resource_group.platform.location
}
