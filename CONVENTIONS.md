# Repository conventions

How this repository is laid out, how its pieces talk to each other, and the rules that keep
those two things stable.

This file is descriptive: it says what is true today. The reasoning behind any particular
rule, and what was rejected to arrive at it, belongs in
[docs/decisions/DECISIONS.md](docs/decisions/DECISIONS.md) — which is append-only, and is the
place to look when a rule seems arbitrary.

---

## Layout

Three directories carry everything:

- `layers/` — Terraform roots. Six of them, numbered in the order they are applied.
- `modules/` — the resources themselves. One module per layer.
- `docs/` — decisions, compliance material, and runbooks.

### Layers

A layer is one Terraform root directory with its own state file. Nothing is shared between
them except explicitly declared outputs.

| Layer | What it owns | Credential it needs |
|---|---|---|
| `0-foundation` | Resource groups, Log Analytics workspace with Sentinel, Key Vault, action group, budget, Activity Log export | Subscription Owner |
| `1-network` | VNet, subnets, NSGs, public DNS zone, private DNS zones, optional NAT gateway | Subscription Owner |
| `2-cluster` | AKS, container registry with private endpoint, workload identity, role assignments | Subscription Owner |
| `3-governance` | FedRAMP Moderate policy initiative, AKS admission control, Defender plans | Subscription Owner |
| `4-identity` | Entra ID sign-in and audit log export (tenant scope) | **Entra administrator** |
| `5-workload` | open-balena, network policies, ingress, certificates | Subscription Owner |

Two of the boundaries are load-bearing rather than cosmetic.

`4-identity` is split out because of the credential column, not the resource column. It is
the only layer needing a directory role, and isolating it means a missing Entra permission
fails one small root instead of stalling an apply halfway through a large one.

`3-governance` precedes `5-workload` so that policy is already enforcing before there is a
workload to enforce it against. Applying them the other way round means either a window where
the workload runs unconstrained, or writing exceptions under pressure to unbreak a
half-deployed system.

### What a layer root contains

Roots are wiring. They load configuration, read whatever upstream layers export, and call
exactly one module — nothing else. Aim to stay under 80 lines; a root that wants a second
module call or a resource of its own is a sign the module is drawn wrong.

```
layers/{N}-{name}/
  main.tf                 configuration, upstream state, the single module call
  variables.tf            environment name only
  outputs.tf              re-exports selected module outputs
  providers.tf
  versions.tf             version constraints and an empty backend block
  .terraform.lock.hcl     under version control
  envs/{env}/backend.hcl
```

### What a module contains

```
modules/{name}/
  main.tf                 resources
  variables.tf            inputs
  outputs.tf              outputs
  versions.tf             version constraints
  {concern}.tf            split main.tf here once it passes roughly 200 lines
```

There is no shared-components directory, and adding one before there is a second caller would
be guessing at a future that may not arrive. Something used once lives inline in the module
that uses it; extract it when a second caller actually shows up, and let the two real call
sites determine the interface.

---

## Interfaces

Inputs and outputs both carry a `description` and a `type`. An input without a description
turns every call site into a guess about intent, and an input without a type turns a
misconfiguration into a confusing apply-time error rather than an immediate one.

Beyond that:

- Prefer `object({})` for anything structured, so related fields travel together.
- Flag secrets with `sensitive = true`.
- Push constraints into `validation` blocks when a variable can check itself — the budget
  variable rejects a tripwire at or above its ceiling, because an early warning that fires
  after the limit is not an early warning.
- Use `lifecycle.precondition` for constraints spanning several inputs, which a `validation`
  block cannot see. `modules/cluster` uses one to require the node count be a whole multiple
  of the zone count, since AKS assigns nodes to zones in rotation and any other ratio loads
  them unevenly.
- Return collections as maps rather than as a series of near-identical outputs:
  `subnet_ids = { aks_nodes = "...", private_endpoints = "..." }`.

### Version constraints

Roots pin, modules do not. A root declares a narrow range (`~> 4.40`); a module declares only
a floor (`>= 4.0`). Pinning inside a module hands that module's opinion to every consumer,
and two modules with different opinions cannot then be used together.

### What layers may read from each other

```
0-foundation outputs --> terraform_remote_state in 1, 2, 3, 4, 5 --> module inputs
```

`terraform validate` compares arguments against a provider schema. It does not reach into
another layer's state, so it cannot tell whether an output being read actually exists.
A layer consuming something never exported still validates, still passes CI, and fails only
at apply.

The tables below exist because of that blind spot. They are the review artifact that replaces
a check the tooling cannot perform, so they are meant to be **complete** — a read that is not
listed is a bug in one table or the other.

| Layer | Publishes |
|---|---|
| `0-foundation` | `workspace_id`, `key_vault_id`, `action_group_id`, `resource_group_names`, `location` |
| `1-network` | `vnet_id`, `subnet_ids`, `dns_zone_name`, `dns_zone_id`, `dns_zone_nameservers`, `private_dns_zone_ids` |
| `2-cluster` | `cluster_id`, `cluster_name`, `oidc_issuer_url`, `acr_login_server`, `cert_manager_identity` |

| Layer | Consumes |
|---|---|
| `1-network` | from `0`: `location`, `resource_group_names.platform`, `workspace_id` |
| `2-cluster` | from `0`: `location`, `resource_group_names.platform`, `workspace_id`, `key_vault_id`<br>from `1`: `subnet_ids.aks_nodes`, `subnet_ids.private_endpoints`, `private_dns_zone_ids.acr`, `dns_zone_id` |

`dns_zone_name` and `vnet_id` are published but not yet consumed — `5-workload` will need
both. They are forward-looking, not dead.

**Region is read from layer 0, never from the environment file.** Downstream layers take
`location` out of the foundation's outputs. Only US regions fall inside Azure Commercial's
FedRAMP authorization, so a stray edit that moved half the estate elsewhere would break
inheritance while leaving every file looking perfectly reasonable. Sourcing it from an
already-applied layer makes that edit impossible rather than merely discouraged.

---

## Naming

Azure resources take the form `{environment}-{purpose}`, and the environment half is
**computed, never typed**. Every module takes an `environment` input and builds its names from
it, so only the `{purpose}` half is written down: `-vnet`, `-aks-nodes-nsg`, `-ceiling`.

Resources needing a globally unique name pick up `name_prefix` from the environment file as
well — `{prefix}-{environment}-kv`, `{prefix}{environment}acr`. Registry names permit letters
and digits only, which is why that one carries no separators. Both stay inside the
24-character ceiling.

Typing an environment into a resource name is a bug twice over: it makes a second environment
collide with the first, and it turns the rule above into a description of something the code
does not actually do. One exception, forced by the platform: an action group's `short_name` is
capped at twelve characters, too short to hold a long environment name, so it carries the
purpose alone.

Inside Terraform, identifiers are `snake_case` and say what the thing is. A resource that is
the only one of its kind in a module is called `this`, which keeps
`azurerm_virtual_network.this` from becoming `azurerm_virtual_network.virtual_network`.

---

## Configuration

`environments/{env}.yaml` holds every value that varies by environment, and layer roots read
it with `yamldecode()`. A literal typed directly into a `module` block is a bug: it puts a
second source of truth next to the first one, and the two will disagree eventually.

Cost switches live here too, each annotated with what it costs. The Terraform is shaped like
production; the defaults are shaped like a demo. Where a default is deliberately weaker than
the posture this system claims — and one is — the comment says so and cites the decision
record, so nobody discovers it by surprise during a review.

### Addressing

| Range | Use |
|---|---|
| `10.50.0.0/16` | Virtual network |
| `10.50.0.0/22` | AKS nodes |
| `10.50.4.0/24` | Private endpoints |
| `172.20.0.0/16` | Kubernetes services — internal to the cluster, and chosen outside the VNet range so the two can never overlap |

---

## State and access to it

Each layer keeps its state in its own blob container, keyed `{env}.tfstate`. Workspaces are
not used.

| Layer | Container |
|---|---|
| `0-foundation` | `tfstate-foundation` |
| `1-network` | `tfstate-network` |
| `2-cluster` | `tfstate-cluster` |

### Identity, not keys

The storage account has shared key access turned off, and every backend authenticates through
Entra with `use_azuread_auth = true`. A storage key identifies nobody: two people using the
same key produce byte-identical log entries, so the record of a state change cannot answer
who made it. Since being able to answer that is most of why this project exists, keys are
not an option here.

Permission is granted to an Entra group rather than to people, and scoped to individual
containers rather than the whole account. Membership of that group is then the thing to
review during an access audit, and removing someone is a single change in one place.

Credentials reach Terraform through environment variables only. Passing them on the command
line or committing them to a file leaves copies behind in the `.terraform` directory and
inside saved plans.

### Backend settings are literal

These settings are checked in per layer under `envs/{env}/`, and the wrapper script hands the
file to `init`. Deriving the container and key from the layer name instead would be fewer
characters and strictly worse to audit: reading a derivation tells you the pattern, whereas
reading a literal tells you the destination.

### The state account is not managed here

The resource group, storage account, and containers are created by
[the bootstrap runbook](docs/operations/runbooks/state-bootstrap.md) and belong to no state
file. This is unavoidable: Terraform would have to write its state somewhere in order to
create the place it writes state.

Do not bring them under management later. A layer that owns the storage holding its own state
cannot be destroyed — removing the storage is a step in an operation that needs the storage
to still be there.

---

## Tooling

`bin/tf.ps1` is how Terraform gets run here. It maps a layer name to its directory, supplies
the committed backend settings on `init`, and requires `apply` and `destroy` to be confirmed
by typing `{layer}/{environment}`.

```powershell
bin/tf.ps1 foundation plan
bin/tf.ps1 network apply
bin/tf.ps1 network output dns_zone_nameservers
```

The confirmation prompt is not about protecting the operator from Terraform. It exists so
that modifying an authorization boundary requires a moment of intent, and typing the target
back is the least intrusive way to require one.

---

## Writing things down

Comments should carry the reason. The resource block already states what is being created;
repeating that in prose adds a line to maintain and tells the reader nothing. What is worth
recording is the constraint that shaped the code — the reason it looks unusual, and therefore
the reason someone should not tidy it back into a defect six months from now.

Where a choice had real alternatives, put the argument in `DECISIONS.md` — four sentences of
prose at most — and leave the code comment pointing at it. Reasoning duplicated in both places
will fall out of step.
