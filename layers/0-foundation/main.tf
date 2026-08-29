# Layer 0: Foundation
#
# Resource groups, the Log Analytics workspace and Sentinel onboarding, the Key Vault, the
# operations action group, the subscription budget, and the Activity Log export.
#
# Applied with subscription Owner. Applied first; everything else reads its outputs.

locals {
  config = yamldecode(file("${path.module}/../../environments/${var.environment}.yaml"))
}

data "azurerm_client_config" "current" {}

module "foundation" {
  source = "../../modules/foundation"

  environment     = var.environment
  location        = local.config.region
  subscription_id = local.config.subscription
  tenant_id       = data.azurerm_client_config.current.tenant_id
  name_prefix     = local.config.name_prefix

  workspace_retention_days = local.config.workspace.retention_days
  workspace_daily_quota_gb = local.config.workspace.daily_quota_gb

  action_group_emails = local.config.budget.contacts
  budget              = local.config.budget

  tags = local.config.tags
}
