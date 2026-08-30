# Runbook: Bootstrap the Terraform state account

Creates the storage account that holds Terraform state, with shared access keys disabled so
every state read and write is attributable to a named Entra identity.

**Nothing created here is under Terraform management.** It cannot be: Terraform would need
somewhere to record state before it could build the place that record lives.

Resist bringing these resources into a layer later. Ownership would make that layer
impossible to tear down, since the teardown needs the storage it is trying to remove.

**Run this before applying layer 0.**

## Prerequisites

- Azure CLI, signed in (`az login`) to the target tenant.
- Owner on the subscription, to create role assignments.
- Permission to create an Entra security group.
- The subscription ID filled into `environments/production.yaml`.

## Part 1 — before layer 0

Set the values that match `environments/production.yaml` and the layers' `backend.hcl`
files. If you change any of these, change them in both places.

```bash
SUBSCRIPTION="<your-subscription-id>"
LOCATION="eastus2"
RG="fedramp-tfstate"
SA="fedrampprodtfstate"
GROUP="fedramp-terraform-state"

az account set --subscription "$SUBSCRIPTION"
az group create --name "$RG" --location "$LOCATION"
```

Create the account with key access off from the start. Creating it permissively and
tightening later leaves a window in which an unattributable key existed.

```bash
az storage account create \
  --name "$SA" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  --public-network-access Enabled
```

Blob versioning gives a recovery path for a corrupted state file that does not depend on
anyone having taken a backup:

```bash
az storage account blob-service-properties update \
  --account-name "$SA" \
  --resource-group "$RG" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30
```

Create one container per layer. `--auth-mode login` is required — there is no account key
to fall back on, which is the point.

```bash
for c in tfstate-foundation tfstate-network tfstate-cluster \
         tfstate-governance tfstate-identity tfstate-workload; do
  az storage container create \
    --name "$c" \
    --account-name "$SA" \
    --auth-mode login
done
```

Grant access to a **group**, never to individuals. Membership becomes the reviewable
account-management artifact, and revoking access is one membership change rather than a
role-assignment hunt.

```bash
GROUP_ID=$(az ad group create \
  --display-name "$GROUP" \
  --mail-nickname "$GROUP" \
  --query id -o tsv)

SA_ID=$(az storage account show --name "$SA" --resource-group "$RG" --query id -o tsv)

# Scoped to each container, not the account. Least privilege is the difference between
# "can read this layer's state" and "can read every layer's state".
for c in tfstate-foundation tfstate-network tfstate-cluster \
         tfstate-governance tfstate-identity tfstate-workload; do
  az role assignment create \
    --assignee-object-id "$GROUP_ID" \
    --assignee-principal-type Group \
    --role "Storage Blob Data Contributor" \
    --scope "$SA_ID/blobServices/default/containers/$c"
done
```

Add yourself to the group. Role assignments can take a few minutes to propagate.

```bash
az ad group member add --group "$GROUP_ID" --member-id "$(az ad signed-in-user show --query id -o tsv)"
```

### Verify part 1

Key access must be refused. This should **fail** — that failure is the control working:

```bash
az storage blob list --account-name "$SA" --container-name tfstate-foundation --auth-mode key
```

This should **succeed**:

```bash
az storage blob list --account-name "$SA" --container-name tfstate-foundation --auth-mode login
```

Then initialise layer 0. Terraform authenticates to the data plane with your Entra identity
because `use_azuread_auth = true` is set in the backend config:

```powershell
bin/tf.ps1 foundation init
```

## Part 2 — after layer 0

**The storage diagnostic settings cannot be created in part 1.** They send to the Log
Analytics workspace, and the workspace does not exist until layer 0 has applied. This is
inherent to bootstrapping and is the reason this runbook has two parts.

Come back here after `bin/tf.ps1 foundation apply` succeeds.

```bash
WORKSPACE_ID=$(terraform -chdir=layers/0-foundation output -raw workspace_id)
SA_ID=$(az storage account show --name "$SA" --resource-group "$RG" --query id -o tsv)

az monitor diagnostic-settings create \
  --name to-workspace \
  --resource "$SA_ID/blobServices/default" \
  --workspace "$WORKSPACE_ID" \
  --logs '[{"category":"StorageRead","enabled":true},
           {"category":"StorageWrite","enabled":true},
           {"category":"StorageDelete","enabled":true}]'
```

### Verify part 2

Run any Terraform operation, wait a few minutes for ingestion, then confirm the write is
attributable. In the workspace:

```kusto
StorageBlobLogs
| where TimeGenerated > ago(1h)
| where OperationName has "Write"
| project TimeGenerated, OperationName, Uri, RequesterObjectId, CallerIpAddress
```

`RequesterObjectId` should be your Entra object ID. **That field being populated is the
entire point of disabling shared keys** — with key auth it would be empty, and the audit
trail would show that state changed without showing who changed it.

## Known issue

`StorageDelete` has been reported as not appearing in `StorageBlobLogs` even with the
category enabled. Confirm it actually surfaces before citing deletion logging as evidence;
if it does not, record that as a gap rather than claiming coverage.

## Rollback

Only if the state account is empty and no layer has been applied:

```bash
az group delete --name "$RG" --yes
az ad group delete --group "$GROUP_ID"
```

If any layer has been applied, destroy those layers first. Deleting state while resources
exist orphans them — they keep billing and nothing knows they are there.
