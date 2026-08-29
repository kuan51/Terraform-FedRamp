# Layer 2 resources: the container registry and its private endpoint, the AKS cluster, the
# workload identity the certificate issuer uses, and the role assignments and diagnostic
# settings that tie them to the foundation.

locals {
  tags = merge(var.tags, {
    managed-by = "terraform"
    layer      = "2-cluster"
  })

  # Service CIDR is cluster-internal and deliberately outside the VNet range so the two
  # cannot collide as the network grows.
  service_cidr   = "172.20.0.0/16"
  dns_service_ip = "172.20.0.10"
}

# ---------------------------------------------------------------------------------------
# Container registry. Public network access is off and pulls traverse a private endpoint,
# so images never transit the internet and the registry is not an internet-facing asset in
# the boundary.
# ---------------------------------------------------------------------------------------

resource "azurerm_container_registry" "this" {
  name                = "${var.name_prefix}${var.environment}acr"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Premium"

  admin_enabled                 = false
  public_network_access_enabled = false

  tags = local.tags
}

resource "azurerm_private_endpoint" "acr" {
  name                = "${var.environment}-acr-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "acr"
    private_connection_resource_id = azurerm_container_registry.this.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr"
    private_dns_zone_ids = [var.acr_private_dns_zone_id]
  }

  tags = local.tags
}

resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "to-workspace"
  target_resource_id         = azurerm_container_registry.this.id
  log_analytics_workspace_id = var.workspace_id

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }
}

# ---------------------------------------------------------------------------------------
# The cluster.
#
# Entra-backed RBAC with local accounts disabled: there is no cluster-local credential to
# leak, and every kubectl action traces to a named directory identity. That is what makes
# kube-audit useful for triage rather than a log of anonymous "masterclient" calls.
# ---------------------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "this" {
  name                = "${var.environment}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.environment}-aks"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  role_based_access_control_enabled = true
  local_account_disabled            = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  azure_policy_enabled              = true

  default_node_pool {
    name           = "system"
    vm_size        = var.system_pool.vm_size
    node_count     = var.system_pool.node_count
    zones          = var.availability_zones
    vnet_subnet_id = var.subnet_id

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
    service_cidr   = local.service_cidr
    dns_service_ip = local.dns_service_ip
  }

  azure_active_directory_role_based_access_control {
    tenant_id              = var.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = true
  }

  # Omitted entirely when the list is empty: passing an empty list would be read as an
  # explicit configuration rather than "not configured", and the difference matters.
  dynamic "api_server_access_profile" {
    for_each = length(var.api_server_authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  oms_agent {
    log_analytics_workspace_id = var.workspace_id
  }

  dynamic "microsoft_defender" {
    for_each = var.defender_containers_enabled ? [1] : []
    content {
      log_analytics_workspace_id = var.workspace_id
    }
  }

  tags = local.tags

  lifecycle {
    # AKS distributes node_count round-robin across zones, so the constraint that actually
    # matters is even divisibility -- not merely "at least as many nodes as zones". Three
    # nodes over two zones survives the weaker check and still leaves one zone carrying
    # double the other, which is an availability posture nobody chose and nobody can state.
    # An empty zone list is a legitimate non-zonal cluster, and is short-circuited here
    # because the modulo would otherwise divide by zero and fail with an arithmetic error
    # instead of the message below.
    precondition {
      condition = (
        length(var.availability_zones) == 0 ||
        var.system_pool.node_count % length(var.availability_zones) == 0
      )
      error_message = "system_pool.node_count must be an exact multiple of the number of availability_zones. AKS spreads nodes round-robin across zones, so any other ratio distributes them unevenly and leaves the availability posture undefined."
    }
  }
}

# In-cluster actions, into the same workspace as everything else. kube-audit-admin is the
# lower-volume subset that excludes read-only events; both are kept because a hardening
# story needs to show denials, not just changes.
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "to-workspace"
  target_resource_id         = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id = var.workspace_id

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "guard"
  }
}

# ---------------------------------------------------------------------------------------
# Role assignments.
#
# Every one of these replaces a credential that would otherwise have to be stored. Nothing
# here issues a secret, so there is no secret to rotate, leak, or find in a manifest.
# ---------------------------------------------------------------------------------------

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "secrets_provider_key_vault" {
  scope                            = var.key_vault_id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].object_id
  skip_service_principal_aad_check = true
}

# ---------------------------------------------------------------------------------------
# Certificate issuer identity.
#
# Workload identity federated to the cert-manager service account, granted DNS Zone
# Contributor on the delegated zone so it can solve DNS-01 challenges for wildcard
# certificates. This is the reason the zone lives in Azure rather than at the registrar:
# no registrar API token has to exist as a long-lived in-cluster secret.
# ---------------------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "cert_manager" {
  name                = "${var.environment}-cert-manager"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = local.tags
}

resource "azurerm_federated_identity_credential" "cert_manager" {
  name                = "cert-manager"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.cert_manager.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject             = "system:serviceaccount:cert-manager:cert-manager"
}

resource "azurerm_role_assignment" "cert_manager_dns" {
  scope                = var.dns_zone_id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.cert_manager.principal_id
}
