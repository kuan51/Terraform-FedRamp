# Terraform-FedRamp

Terraform for a secured, FedRAMP-oriented cloud platform on Azure: an open-balena
command-and-control backend for a fleet of medical devices, built as a reference
implementation with the control evidence a FedRAMP submission would need.

Built for a cybersecurity course project. The medical device is an abstraction — the
infrastructure, the controls, and the evidence are real.

## What this is

An IoT device-management platform on AKS, deployed and hardened with Terraform, with the
logging, identity, and policy controls needed to argue a FedRAMP Moderate posture.

The interesting part is not that open-balena runs. It is that open-balena ships
docker-compose only, has no vendor-maintained Kubernetes packaging, and was never hardened
for a regulated environment — so every control here had to be added deliberately and can be
pointed at individually.

## Honest framing

Three things a reviewer would ask about, answered up front rather than buried:

**The hosting is genuinely inheritable.** Azure Commercial holds a FedRAMP High P-ATO
covering all US public regions, so the controls marked inherited in the CRM have a real
authorized source. This matters more than it sounds: FedRAMP is explicit that a system
hosted on a non-authorized IaaS has *no* inheritance relationship at all.

**The categorization is deliberately conservative.** This is built to Moderate. A real
combat-casualty-care C2 system would categorize **High on availability** — loss of
availability during casualty care risks loss of life — and would fall under the DoD Cloud
Computing SRG rather than plain FedRAMP. See
[docs/compliance/categorization.md](docs/compliance/categorization.md).

**The demo defaults are weaker than the posture.** The cost gates default to a free-tier
control plane with no uptime SLA and a single availability zone, which does not meet the
availability posture the categorization implies. That is deliberate, priced, and recorded in
[D-005](docs/decisions/DECISIONS.md). The code is production-shaped; the defaults are
demo-shaped.

## Status

Layers 0 through 2 are written and validate clean. Nothing has been applied — there is no
Azure subscription yet, by design: the configuration is deploy-ready so that purchase day is
a one-line edit rather than a build.

| Layer | State |
|---|---|
| `0-foundation` | Written, validates |
| `1-network` | Written, validates |
| `2-cluster` | Written, validates |
| `3-governance` | Not yet built |
| `4-identity` | Not yet built |
| `5-workload` | Not yet built |

## Layout

```
bin/tf.ps1          Entrypoint: resolves layers, wires backends, gates applies
environments/       Single source of environment values, including cost gates
layers/{N}-{name}/  Terraform roots, independent state, thin wiring
modules/{name}/     One module per layer; all the logic
docs/decisions/     DECISIONS.md (why, append-only) and RUNLOG.md (what happened)
docs/compliance/    Categorization, boundary, inheritance, CRM
docs/operations/    Runbooks for everything that cannot be automated
```

[CONVENTIONS.md](CONVENTIONS.md) is the current-state reference for naming, state, module
interfaces, and the cross-layer output contracts.

## Usage

```powershell
bin/tf.ps1 foundation validate
bin/tf.ps1 foundation plan
bin/tf.ps1 network apply
bin/tf.ps1 network output dns_zone_nameservers
```

`apply` and `destroy` require typing `{layer}/{environment}` to confirm.

### Before the first real deploy

1. Set `subscription` in `environments/production.yaml`.
2. Populate `cluster.admin_group_object_ids` — local accounts are disabled, so an empty list
   means nobody can administer the cluster.
3. Populate `cluster.api_server_authorized_ip_ranges` — an empty list leaves the API server
   reachable from any address.
4. Run [the state-bootstrap runbook](docs/operations/runbooks/state-bootstrap.md).
5. Apply layers 0 and 1, then complete
   [DNS delegation](docs/operations/runbooks/dns-delegation.md) before going further.

## Verification

```bash
terraform fmt -recursive -check
terraform -chdir=layers/0-foundation init -backend=false && terraform -chdir=layers/0-foundation validate
```

CI runs `fmt`, `validate`, `tflint` and `checkov` on every push.

What that gate does **not** cover: cross-layer remote-state contracts, the
Entra-authenticated backend, and whether open-balena actually runs — see
[D-010](docs/decisions/DECISIONS.md) for why each one is out of reach.
[RUNLOG.md](docs/decisions/RUNLOG.md) records what has actually been run.
