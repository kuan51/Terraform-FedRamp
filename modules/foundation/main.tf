# Layer 0 resources: the security and platform resource groups, the Log Analytics
# workspace and its Sentinel onboarding, the Key Vault, the operations action group, the
# subscription budget, and the Activity Log export.
#
# Everything downstream depends on this layer's outputs. It changes rarely.

locals {
  # Tags every caller gets whether they asked for them or not. Compliance tagging that a
  # module call site can forget is compliance tagging that will eventually be forgotten.
  tags = merge(var.tags, {
    managed-by = "terraform"
    layer      = "0-foundation"
  })
}

resource "azurerm_resource_group" "security" {
  name     = "${var.environment}-security"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "platform" {
  name     = "${var.environment}-platform"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------------------
# Log Analytics + Sentinel -- the single workspace every log source in the estate lands in.
# ---------------------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.environment}-security-workspace"
  location            = var.location
  resource_group_name = azurerm_resource_group.security.name

  sku               = "PerGB2018"
  retention_in_days = var.workspace_retention_days
  daily_quota_gb    = var.workspace_daily_quota_gb

  tags = local.tags
}

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  workspace_id = azurerm_log_analytics_workspace.this.id
}

# ---------------------------------------------------------------------------------------
# Key Vault. RBAC authorization rather than access policies so vault access is governed by
# the same Entra role assignments as everything else, and lands in the same audit trail.
# ---------------------------------------------------------------------------------------

resource "azurerm_key_vault" "this" {
  name                = "${var.name_prefix}-${var.environment}-kv"
  location            = var.location
  resource_group_name = azurerm_resource_group.security.name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  tags = local.tags
}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "to-workspace"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "AuditEvent"
  }
}

# ---------------------------------------------------------------------------------------
# Operations notifications and cost control.
# ---------------------------------------------------------------------------------------

resource "azurerm_monitor_action_group" "ops" {
  name                = "${var.environment}-ops"
  resource_group_name = azurerm_resource_group.security.name
  short_name          = "ops"

  dynamic "email_receiver" {
    for_each = var.action_group_emails
    content {
      name          = "email-${email_receiver.key}"
      email_address = email_receiver.value
    }
  }

  tags = local.tags
}

resource "azurerm_consumption_budget_subscription" "this" {
  count = var.budget.enabled ? 1 : 0

  name            = "${var.environment}-ceiling"
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = var.budget.ceiling
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget.start_date
  }

  # Early warning well before the ceiling, then a forecast alarm at it. A budget that only
  # alerts at 100% actual tells you about an overrun you have already paid for.
  notification {
    enabled        = true
    threshold      = floor(var.budget.tripwire / var.budget.ceiling * 100)
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget.contacts
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = var.budget.contacts
  }
}

# ---------------------------------------------------------------------------------------
# Activity Log -- every control-plane action in the subscription, into the workspace.
# One of the five log sources the audit trail depends on.
# ---------------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "activity-to-workspace"
  target_resource_id         = "/subscriptions/${var.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "Policy"
  }

  enabled_log {
    category = "Alert"
  }
}
