# Layer 2: Cluster
#
# The container registry and its private endpoint, the AKS cluster, the certificate issuer
# workload identity, and the role assignments that replace stored credentials.
#
# Applied with subscription Owner, after 0-foundation and 1-network.

locals {
  config = yamldecode(file("${path.module}/../../environments/${var.environment}.yaml"))
}

data "azurerm_client_config" "current" {}

data "terraform_remote_state" "foundation" {
  backend = "azurerm"

  config = {
    resource_group_name  = local.config.state.resource_group
    storage_account_name = local.config.state.storage_account
    container_name       = "tfstate-foundation"
    key                  = "${var.environment}.tfstate"
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "network" {
  backend = "azurerm"

  config = {
    resource_group_name  = local.config.state.resource_group
    storage_account_name = local.config.state.storage_account
    container_name       = "tfstate-network"
    key                  = "${var.environment}.tfstate"
    use_azuread_auth     = true
  }
}

module "cluster" {
  source = "../../modules/cluster"

  environment         = var.environment
  location            = data.terraform_remote_state.foundation.outputs.location
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_names.platform
  workspace_id        = data.terraform_remote_state.foundation.outputs.workspace_id
  key_vault_id        = data.terraform_remote_state.foundation.outputs.key_vault_id

  subnet_id                  = data.terraform_remote_state.network.outputs.subnet_ids.aks_nodes
  private_endpoint_subnet_id = data.terraform_remote_state.network.outputs.subnet_ids.private_endpoints
  acr_private_dns_zone_id    = data.terraform_remote_state.network.outputs.private_dns_zone_ids.acr
  dns_zone_id                = data.terraform_remote_state.network.outputs.dns_zone_id

  name_prefix = local.config.name_prefix
  tenant_id   = data.azurerm_client_config.current.tenant_id

  kubernetes_version = local.config.cluster.kubernetes_version
  sku_tier           = local.config.cluster.sku_tier
  availability_zones = local.config.cluster.availability_zones
  system_pool = {
    vm_size    = local.config.cluster.system_pool.vm_size
    node_count = local.config.cluster.system_pool.node_count
  }

  api_server_authorized_ip_ranges = local.config.cluster.api_server_authorized_ip_ranges
  admin_group_object_ids          = local.config.cluster.admin_group_object_ids
  defender_containers_enabled     = local.config.defender.containers_enabled

  tags = local.config.tags
}
