# Layer 1: Network
#
# The virtual network and subnets, network security groups, the public DNS zone for the
# delegated subdomain, private DNS zones, and optional NAT gateway egress.
#
# Applied with subscription Owner, after 0-foundation.
#
# GATE: after this layer applies, read the dns_zone_nameservers output and add those NS
# records at the registrar before attempting layer 5. Certificate issuance fails until the
# delegation has propagated. See docs/operations/runbooks/dns-delegation.md.

locals {
  config = yamldecode(file("${path.module}/../../environments/${var.environment}.yaml"))
}

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

module "network" {
  source = "../../modules/network"

  environment = var.environment

  # Region comes from the foundation rather than the config file so the network cannot be
  # built in a different region than the estate it belongs to.
  location            = data.terraform_remote_state.foundation.outputs.location
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_names.platform
  workspace_id        = data.terraform_remote_state.foundation.outputs.workspace_id

  vnet_cidr = local.config.network.vnet_cidr
  subnet_cidrs = {
    aks_nodes         = local.config.network.subnets.aks_nodes
    private_endpoints = local.config.network.subnets.private_endpoints
  }

  dns_zone_name       = local.config.dns.zone
  nat_gateway_enabled = local.config.cluster.nat_gateway_enabled

  tags = local.config.tags
}
