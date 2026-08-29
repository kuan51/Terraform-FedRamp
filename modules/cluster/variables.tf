variable "environment" {
  description = "Environment name. Resource names in this module are computed from it, so a second environment cannot collide with the first."
  type        = string
}

variable "location" {
  description = "Azure region, read from layer 0 so the cluster cannot drift from the rest of the estate."
  type        = string
}

variable "resource_group_name" {
  description = "Platform resource group the cluster and registry are created in."
  type        = string
}

variable "name_prefix" {
  description = "Short prefix for globally-unique names. The container registry allows alphanumerics only."
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant ID for the cluster's Entra-backed RBAC."
  type        = string
}

variable "workspace_id" {
  description = "Log Analytics workspace that cluster diagnostics and the monitoring agent send to."
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault the cluster's secrets provider identity is granted read access to."
  type        = string
}

variable "subnet_id" {
  description = "Subnet the node pool is placed in."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet the container registry private endpoint is placed in."
  type        = string
}

variable "acr_private_dns_zone_id" {
  description = "Private DNS zone for privatelink.azurecr.io, so in-cluster registry lookups resolve to the private address."
  type        = string
}

variable "dns_zone_id" {
  description = "Public DNS zone the certificate issuer identity is granted DNS Zone Contributor on, so it can solve DNS-01 challenges."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for the cluster."
  type        = string
}

variable "sku_tier" {
  description = "AKS control plane tier. Free carries no uptime SLA; Standard does, at roughly 73 USD/month. A cost gate -- see DECISIONS for the accepted availability deviation."
  type        = string

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be one of Free, Standard, or Premium."
  }
}

variable "availability_zones" {
  description = "Zones the system node pool spreads across. Length must equal system_pool.node_count -- nodes cannot occupy more zones than there are nodes, and a longer zone list leaves the posture undefined."
  type        = list(string)
}

variable "system_pool" {
  description = "System node pool sizing."
  type = object({
    vm_size    = string
    node_count = number
  })
}

variable "api_server_authorized_ip_ranges" {
  description = "CIDRs permitted to reach the Kubernetes API server. An empty list leaves the API server reachable from any address, which is a finding -- populate before any real apply."
  type        = list(string)
}

variable "admin_group_object_ids" {
  description = "Entra group object IDs granted cluster-admin. Local accounts are disabled, so an empty list means nobody can administer the cluster -- populate before any real apply."
  type        = list(string)
}

variable "defender_containers_enabled" {
  description = "Whether to enable Microsoft Defender for Containers on the cluster. Bills per vCPU; its image scan findings are the evidence story."
  type        = bool
}

variable "tags" {
  description = "Base tags from the environment config."
  type        = map(string)
}
