terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.40"
    }
  }

  # Backend configuration is written down, not derived -- each layer commits its own
  # envs/{env}/backend.hcl and bin/tf.ps1 passes it with -backend-config. An explicit key
  # is auditable in a way a computed one is not.
  backend "azurerm" {}
}
