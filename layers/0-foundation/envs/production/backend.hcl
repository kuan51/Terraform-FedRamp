# State lives in a storage account created by the state-bootstrap runbook and tracked in
# NO state file -- state storage cannot be managed by the state it holds.
#
# use_azuread_auth is the point: shared access keys are disabled on this account, so every
# read and write of state is attributable to a named Entra identity. Credentials come from
# environment variables, never from this file.
resource_group_name  = "fedramp-tfstate"
storage_account_name = "fedrampprodtfstate"
container_name       = "tfstate-foundation"
key                  = "production.tfstate"
use_azuread_auth     = true
