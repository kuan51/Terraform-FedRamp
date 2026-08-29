# Runbook: Cost control — stop, start, and tear down

The estate targets under $50/month while demonstrable. That number only holds if the cluster
is not running between sessions.

Planned as two runbooks; kept as one because "how do I stop paying for this" is a single
question and splitting it makes the answer harder to find under pressure.

## Where the money goes

| Item | Roughly | Controlled by |
|---|---|---|
| AKS control plane | $0 on Free tier | `cluster.sku_tier` |
| Node pool | The bulk of the bill | `cluster.system_pool`, and whether the cluster is running |
| Log Analytics ingestion | Per GB | `workspace.daily_quota_gb` |
| Defender for Containers | Per vCPU | `defender.containers_enabled` |
| NAT gateway | ~$32/mo + data | `cluster.nat_gateway_enabled` |
| Container registry (Premium) | Flat monthly | Required for private endpoints |

Node compute dominates, and it bills whether or not anything is deployed on it. Stopping the
cluster is the single highest-value action.

## Stop between sessions

Stopping deallocates the nodes and stops compute billing. Cluster configuration, workloads,
and persistent volumes survive.

```bash
ENV=production
az aks stop --name "$ENV-aks" --resource-group "$ENV-platform"
```

Restart before a demo. Allow several minutes, and expect pods to take longer than usual to
become ready on the first scheduling pass.

```bash
az aks start --name "$ENV-aks" --resource-group "$ENV-platform"
kubectl get nodes
kubectl get pods -A
```

**Do not leave a cluster stopped indefinitely.** Azure supports a stopped cluster for a
limited period; beyond it, behaviour is not guaranteed. If the project is paused for longer
than a few weeks, tear down instead.

## Check spend before it surprises you

```bash
az consumption usage list --start-date 2026-09-01 --end-date 2026-09-30 \
  --query "[].{name:instanceName, cost:pretaxCost}" -o table
```

The budget in layer 0 alerts at the tripwire and forecasts against the ceiling, but a budget
alert tells you after the fact. This tells you now.

## Tear down

Destroy in **reverse** apply order. Each layer's state depends on the ones below it; going
forwards leaves resources orphaned that nothing knows about and everything keeps billing.

```powershell
bin/tf.ps1 workload destroy
bin/tf.ps1 identity destroy
bin/tf.ps1 governance destroy
bin/tf.ps1 cluster destroy
bin/tf.ps1 network destroy
bin/tf.ps1 foundation destroy
```

Each requires typing `{layer}/production` to confirm.

### What survives, deliberately

**The Key Vault.** Purge protection is on, so it is soft-deleted and retained for 90 days
rather than removed. That is intentional — purge protection is a control, not an
inconvenience, and disabling it to make teardown tidier would be trading a real protection
for a cosmetic one. It blocks recreating a vault with the same name until the retention
period expires or the vault is purged explicitly.

**The state account.** Bootstrap infrastructure, tracked in no state file, so
`terraform destroy` does not touch it. Remove it manually only after every layer is
destroyed:

```bash
az group delete --name fedramp-tfstate --yes
```

**The DNS delegation.** The NS records at the registrar are not managed here. Delete them
separately or the subdomain will keep pointing at a zone that no longer exists.

### Verify teardown

```bash
az resource list --resource-group "$ENV-platform" -o table
az resource list --resource-group "$ENV-security" -o table
```

Both should be empty or the groups gone. Anything left is billing.
