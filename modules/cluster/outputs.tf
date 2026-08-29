# Cross-layer contract. Layer 5 reads these -- and nothing else.

output "cluster_id" {
  description = "AKS cluster resource ID."
  value       = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "AKS cluster name, for kubectl credential retrieval and the helm provider."
  value       = azurerm_kubernetes_cluster.this.name
}

output "oidc_issuer_url" {
  description = "Cluster OIDC issuer URL, for federating further workload identities in later layers."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "acr_login_server" {
  description = "Container registry login server, for image references in the workload chart."
  value       = azurerm_container_registry.this.login_server
}

output "cert_manager_identity" {
  description = "Client and principal IDs of the certificate issuer workload identity, for the cert-manager service account annotation."
  value = {
    client_id    = azurerm_user_assigned_identity.cert_manager.client_id
    principal_id = azurerm_user_assigned_identity.cert_manager.principal_id
  }
}
