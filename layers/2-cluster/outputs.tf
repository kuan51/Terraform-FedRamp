# Passthrough of the module contract. Layer 5 reads these -- and nothing else.

output "cluster_id" {
  description = "AKS cluster resource ID."
  value       = module.cluster.cluster_id
}

output "cluster_name" {
  description = "AKS cluster name."
  value       = module.cluster.cluster_name
}

output "oidc_issuer_url" {
  description = "Cluster OIDC issuer URL."
  value       = module.cluster.oidc_issuer_url
}

output "acr_login_server" {
  description = "Container registry login server."
  value       = module.cluster.acr_login_server
}

output "cert_manager_identity" {
  description = "Client and principal IDs of the certificate issuer workload identity."
  value       = module.cluster.cert_manager_identity
}
