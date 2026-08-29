# Layer 1 resources: the virtual network and its subnets, network security groups, the
# public DNS zone for the delegated subdomain, private DNS zones for private endpoints,
# and optional NAT gateway egress.

locals {
  tags = merge(var.tags, {
    managed-by = "terraform"
    layer      = "1-network"
  })

  # Private DNS zones required for private endpoints to resolve to private addresses.
  # Without these the endpoint exists but clients still resolve the public name.
  private_dns_zones = {
    acr       = "privatelink.azurecr.io"
    key_vault = "privatelink.vaultcore.azure.net"
  }

  # Keyed the same as the NSGs above, so the association resource can look up the right
  # subnet for each NSG by for_each key.
  subnet_ids = {
    aks_nodes         = azurerm_subnet.aks_nodes.id
    private_endpoints = azurerm_subnet.private_endpoints.id
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.environment}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]

  tags = local.tags
}

resource "azurerm_subnet" "aks_nodes" {
  name                 = "aks-nodes"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_cidrs.aks_nodes]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "private-endpoints"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_cidrs.private_endpoints]

  # Evaluate network policies on this subnet so NSG rules actually apply to private
  # endpoint traffic rather than being silently bypassed.
  private_endpoint_network_policies = "Enabled"
}

# ---------------------------------------------------------------------------------------
# Network security groups.
#
# Azure default rules already deny inbound from the internet. These rules state that intent
# explicitly rather than relying on a default, so the posture is reviewable in the
# configuration instead of only in the portal.
# ---------------------------------------------------------------------------------------

resource "azurerm_network_security_group" "this" {
  for_each = toset(["aks_nodes", "private_endpoints"])

  name                = "${var.environment}-${replace(each.key, "_", "-")}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-vnet-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "deny-internet-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = local.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = azurerm_network_security_group.this

  subnet_id                 = local.subnet_ids[each.key]
  network_security_group_id = each.value.id
}

resource "azurerm_monitor_diagnostic_setting" "aks_nodes_nsg" {
  name                       = "to-workspace"
  target_resource_id         = azurerm_network_security_group.this["aks_nodes"].id
  log_analytics_workspace_id = var.workspace_id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

# ---------------------------------------------------------------------------------------
# DNS.
#
# The public zone is the delegated subdomain only. The registrar zone stays where it is;
# delegation adds four NS records there and nothing else. Azure assigns those nameservers
# at creation, so they do not exist until this layer has applied. That is why the
# delegation is a manual gate between phase 1 and phase 2 rather than an automatic step.
# ---------------------------------------------------------------------------------------

resource "azurerm_dns_zone" "this" {
  name                = var.dns_zone_name
  resource_group_name = var.resource_group_name

  tags = local.tags
}

resource "azurerm_private_dns_zone" "this" {
  for_each = local.private_dns_zones

  name                = each.value
  resource_group_name = var.resource_group_name

  tags = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.private_dns_zones

  name                  = "${each.key}-to-vnet"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  virtual_network_id    = azurerm_virtual_network.this.id

  tags = local.tags
}

# ---------------------------------------------------------------------------------------
# Egress. Cost-gated: a NAT gateway gives deterministic, allow-listable outbound addresses,
# which is what a production posture wants. The demo posture goes without.
# ---------------------------------------------------------------------------------------

resource "azurerm_public_ip" "nat" {
  count = var.nat_gateway_enabled ? 1 : 0

  name                = "${var.environment}-nat-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.tags
}

resource "azurerm_nat_gateway" "this" {
  count = var.nat_gateway_enabled ? 1 : 0

  name                = "${var.environment}-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"

  tags = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count = var.nat_gateway_enabled ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "aks_nodes" {
  count = var.nat_gateway_enabled ? 1 : 0

  subnet_id      = azurerm_subnet.aks_nodes.id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}
