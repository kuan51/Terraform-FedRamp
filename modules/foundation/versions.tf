terraform {
  # Modules declare a permissive floor only. Layer roots do the pinning -- a pin inside a
  # module makes it unusable alongside a root that pins differently.
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}
