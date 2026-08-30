variable "environment" {
  description = "Environment name. Resource names in this module are computed from it, so a second environment cannot collide with the first."
  type        = string
}

variable "location" {
  description = "Azure region. Read from layer 0's output so the network cannot drift to a different region than the foundation."
  type        = string
}

variable "resource_group_name" {
  description = "Platform resource group the network resources are created in."
  type        = string
}

variable "vnet_cidr" {
  description = "Address space for the virtual network."
  type        = string
}

variable "subnet_cidrs" {
  description = "Subnet address prefixes, keyed by purpose. Must be inside vnet_cidr."
  type = object({
    aks_nodes         = string
    private_endpoints = string
  })
}

variable "dns_zone_name" {
  description = "Public DNS zone to create. Its assigned nameservers are exported so the delegation runbook has something concrete to read."
  type        = string
}

variable "nat_gateway_enabled" {
  description = "Whether to create a NAT gateway for deterministic egress. A cost gate, roughly 32 USD/month plus data processing. Off in the demo posture."
  type        = bool
}

variable "workspace_id" {
  description = "Log Analytics workspace that network diagnostics are sent to."
  type        = string
}

variable "tags" {
  description = "Base tags from the environment config."
  type        = map(string)
}
