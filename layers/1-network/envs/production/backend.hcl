# Shared access keys are disabled on this account, so use_azuread_auth is required rather
# than optional. Credentials come from environment variables, never from this file.
resource_group_name  = "fedramp-tfstate"
storage_account_name = "fedrampprodtfstate"
container_name       = "tfstate-network"
key                  = "production.tfstate"
use_azuread_auth     = true
