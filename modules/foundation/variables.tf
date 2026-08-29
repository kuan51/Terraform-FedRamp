variable "environment" {
  description = "Environment name. Resource names in this module are computed from it, so a second environment cannot collide with the first."
  type        = string
}

variable "location" {
  description = "Azure region for all foundation resources. Must be a US region to stay in scope for Azure Commercial's FedRAMP High P-ATO."
  type        = string
}

variable "subscription_id" {
  description = "Subscription the budget and Activity Log diagnostic setting are scoped to."
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant ID, used for the Key Vault's directory association."
  type        = string
}

variable "name_prefix" {
  description = "Short prefix for globally-unique resource names (Key Vault). Azure limits these to 24 characters with no hyphens."
  type        = string
}

variable "workspace_retention_days" {
  description = "Interactive retention for the Log Analytics workspace, in days."
  type        = number
}

variable "workspace_daily_quota_gb" {
  description = "Hard daily ingestion cap in GB. Once reached, ingestion stops and audit data is dropped -- an accepted AU-4/AU-5 gap recorded in DECISIONS. -1 disables the cap."
  type        = number
}

variable "action_group_emails" {
  description = "Email addresses notified by the operations action group."
  type        = list(string)
}

variable "budget" {
  description = "Subscription budget. `tripwire` is the early-warning threshold and must be below `ceiling`."
  type = object({
    enabled    = bool
    ceiling    = number
    tripwire   = number
    start_date = string
    contacts   = list(string)
  })

  validation {
    condition     = var.budget.tripwire < var.budget.ceiling
    error_message = "budget.tripwire must be below budget.ceiling, otherwise the early warning fires at or after the limit it is meant to precede."
  }
}

variable "tags" {
  description = "Base tags from the environment config. The module adds its own on top so no caller can omit them."
  type        = map(string)
}
