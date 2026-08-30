# Decisions

Append-only. Never edit a past entry, not even a status field — reverse a decision by writing
a new entry that says "Supersedes D-00N".

Keep each entry to **four sentences of prose or fewer**: what was decided, why, and the
strongest alternative rejected or gap accepted. A table is fine where numbers carry the
argument. Anything longer is elaboration, and elaboration belongs in the document the decision
governs.

Settled decisions are rolled into [CONVENTIONS.md](../../CONVENTIONS.md), which describes
current state. This file describes *why*.

---

## D-001 — Leveraged CSP: Azure Commercial

**Date:** 2026-08-27

Host on Azure Commercial in a US region: FedRAMP grants no inheritance relationship at all to a
system hosted on a non-authorized IaaS, and Azure Commercial holds a FedRAMP High P-ATO
covering every US public region, so the controls marked inherited in the CRM have a real
authorized source to point at. **Rejected: DigitalOcean**, the original target — its SOC 2,
CSA STAR and HIPAA attestations carry no FedRAMP authorization, which would have left every
control customer-responsible and the CRM with zero inheritable rows. **Rejected: Azure
Government**, a better fit for the modeled mission, because eligibility requires SAM/CAGE
registration or signed contract evidence this project cannot produce.

**Accepted gap.** Only US public regions are in P-ATO scope, and a region change silently voids
the inheritance the whole package rests on — which is why later layers read the region from
layer 0's output rather than from the config file.

---

## D-002 — Impact level Moderate, with the High argument recorded

**Date:** 2026-08-27

Build to the FedRAMP Moderate baseline, which is a workable control count for a project of this
size and duration. A FIPS 199 categorization of a real combat-casualty-care command-and-control
system would put **availability at High** — loss of availability during casualty care risks
loss of life — and confidentiality is arguably High as well, carrying both patient data and
force-position information. A production system of this description would also fall under the
DoD Cloud Computing SRG at IL4 or IL5 rather than plain FedRAMP.

**Accepted gap.** The control set built here is narrower than the modeled mission would
require, stated in the categorization document rather than left for a reviewer to notice.

---

## D-003 — Baseline revision: Rev5

**Date:** 2026-08-27

Target the FedRAMP Rev5 baselines, whose control set and SSP templates are publicly documented
and stable enough to work against without guessing. **Rejected: FedRAMP 20x**, the forward
path — its Class B and Class C pipelines open 2026-08-31 and FedRAMP stops accepting new Rev5
requests on 2027-06-11, so a project starting today could plausibly target it instead.

**Accepted gap.** This baseline has a published end date, and a submission started much later
would have to revisit the choice.

---

## D-004 — Entra-only state access

**Date:** 2026-08-27

Shared access keys are disabled on the state storage account, every backend sets
`use_azuread_auth = true`, and access is granted to an Entra group holding Storage Blob Data
Contributor scoped to the container rather than to individuals. Key-based access is
unattributable — anyone holding the key is indistinguishable from anyone else holding it, so a
state write cannot be traced to a person, and group membership instead becomes the reviewable
account-management artifact. **Rejected: shared-key auth**, simpler to bootstrap and needing no
directory role, because unattributable access cannot support AU-6 review and would make the
storage diagnostic logs decorative.

**Accepted costs.** Bootstrap now needs a directory role to create the group, and a
misconfigured RBAC assignment locks operators out of state entirely rather than degrading
gracefully — a sharper failure mode, deliberately chosen over a quieter one.

**Implements:** AU-2, AU-3, AU-6, AU-12, AC-2, AC-3, AC-6, IA-2.

---

## D-005 — Cost gates, and the accepted availability deviation

**Date:** 2026-08-27

Cost-driving settings are flags in `environments/production.yaml`, each carrying its price in a
comment: the code is production-shaped and the defaults are demo-shaped.

| | Production posture | Demo default |
|---|---|---|
| Control plane | `Standard` (uptime SLA, ~$73/mo) | `Free`, no SLA |
| Nodes | 3 across zones 1/2/3 | 2 in zone 1 |
| Egress | NAT gateway (~$32/mo + data) | none |

Those defaults **do not meet the availability posture** D-002 says a High categorization would
imply, and that is a deliberate, priced deviation reversible by a YAML edit. It is recorded
rather than fixed because a reviewer finds it in thirty seconds, and a documented deviation
with a price attached is a finding under control while an undocumented one is a finding the
assessor discovers.

---

## D-006 — Sentinel daily ingestion cap is an accepted AU-4/AU-5 gap

**Date:** 2026-08-27

`workspace.daily_quota_gb` is set to 1 GB in the demo posture, because Log Analytics ingestion
is the least predictable cost in the estate and the easiest way to burn a budget unnoticed.
Once the cap is reached ingestion stops and **audit records are dropped**, which is squarely
AU-4 (audit storage capacity) and AU-5 (response to audit processing failures) and exactly what
an assessor asks about. Acceptable for a demo and recorded here rather than left sitting
silently in a YAML file; raising or removing the cap is a one-line change.

**Accepted gap.** A production posture would pair the quota with an alert on approaching it
rather than a hard stop that discards evidence.

---

## D-007 — DNS: delegate a subdomain to Azure DNS

**Date:** 2026-08-27

Create an Azure DNS zone for the system subdomain in `1-network` and add its NS records once at
the registrar, which keeps the apex and every other record. This holds the system's DNS inside
the authorization boundary, and lets cert-manager solve DNS-01 wildcard challenges against
Azure DNS using workload identity, so **no registrar API token has to exist as a long-lived
in-cluster secret**. **Rejected: managing records at the registrar through its Terraform
provider**, which puts a third party in the boundary and requires storing exactly the
long-lived credential this design otherwise has none of.

**Operational consequence.** Azure assigns the zone's nameservers at creation, so they do not
exist until `1-network` has applied — delegation is a manual gate between phase 1 and phase 2,
and `1-network` exports `dns_zone_nameservers` for the runbook to read.

---

## D-008 — Guardrails apply before workload

**Date:** 2026-08-27

`3-governance` applies before `5-workload`. Admission control should already be enforcing when
open-balena lands, rather than being retrofitted around something already running. Retrofitting
means either a window where the workload runs unconstrained, or a scramble of exceptions
written under pressure to get a broken deployment healthy. Ordering it this way costs nothing
and makes the sequence itself part of the security story.

---

## D-009 — Vendor and pin the community Helm chart

**Date:** 2026-08-27

open-balena is deployed from a community Helm chart, vendored into the repository and pinned to
a specific commit. open-balena ships docker-compose only and has no vendor-maintained
Kubernetes packaging, so the community chart is the shortest path to a running system and
leaves this project's effort where it belongs, on hardening. An unpinned upstream chart would
be an unreviewed supply-chain dependency in a repository whose entire purpose is control
evidence; vendoring makes the deployed manifests reviewable and stops upstream behaviour
shifting underneath a compliance claim.

**Accepted risk.** Community charts are rarely written against restricted Pod Security, and
that can only surface at apply — the fallback is authoring manifests from the official
docker-compose.

---

## D-010 — Write deploy-ready code before the subscription exists

**Date:** 2026-08-27

Build the full configuration now and apply it when an Azure subscription is purchased, since
nothing about the design depends on the subscription existing yet. Writing it now makes
purchase day a one-line edit — `subscription` in `environments/production.yaml` — rather than a
build.

**Accepted gap.** `terraform plan` requires live credentials and cannot run, so the
verification gate is `fmt`, `init -backend=false`, `validate`, and static analysis. Three
things that gate provably does not cover: **cross-layer remote-state contracts**, mitigated
only by the contract table in CONVENTIONS.md; **the Entra-authenticated backend**, since
`-backend=false` skips backend configuration entirely; and **whether open-balena actually
runs**.

---

## D-011 — Provenance review stays manual

**Date:** 2026-08-27

The review that keeps content from the private source project out of this repository is run
locally by whoever is working on it, and is **not** automated in CI. An automated check has to
name the strings it searches for, and that list has to be committed — in a public repository
that publishes exactly the identifiers the review exists to keep out, so the automation would
be a more reliable way of doing the wrong thing. **Rejected: a CI grep step**, written and then
removed once this became obvious; its own first run flagged only two files, the workflow
carrying the pattern and the log entry quoting it.

**Accepted cost.** The review depends on a person remembering to run it, which is weaker than a
gate — mitigated by keeping the prohibition in `CLAUDE.md`, and by writing documents from the
rules rather than from someone else's sentences, which prevents the leak rather than catching
it afterwards.

---

## D-012 — The zone/node invariant is exact divisibility

**Date:** 2026-08-27

`modules/cluster` carries a `lifecycle.precondition` requiring `node_count` to be an exact
multiple of the configured zone count. AKS distributes `node_count` round-robin across zones,
so a weaker rule such as "at least as many nodes as zones" would permit three nodes across two
zones — one zone carrying double the other, an availability posture nobody chose and nobody can
state in an SSP. **Rejected: dropping the check**, since the demo posture is a single zone
where every ratio is even and the check never fires, which is exactly why it matters — the
production posture is the one nobody exercises before an audit.

**Kept in step.** The code, the `environments/production.yaml` comment, and CONVENTIONS.md all
state this same rule, because in a repository whose value is that its documentation matches its
configuration, a disagreement between them is worse than any one of them being wrong.

---

## D-013 — Key Vault data plane goes private

**Date:** 2026-08-29

Public network access on the Key Vault is disabled and its `network_acls` default to Deny, so
the data plane is reachable only through a private endpoint created in `2-cluster` (using the
`privatelink.vaultcore.azure.net` zone `1-network` already provisioned) — with one recorded
exception: `bypass = "AzureServices"` keeps Azure's trusted services able to reach the data
plane, an assessor-visible boundary exception accepted over the operational breakage
`bypass = "None"` invites. The vault is created in layer 0 before the VNet exists, so there is
a window across the phased first apply in which it cannot be reached — accepted, because
nothing writes a secret until the cluster layer is up. **Rejected: leaving public access on
with RBAC as the only boundary**, which kept an internet-reachable data plane inside the
FedRAMP boundary for no operational gain.

**Accepted cost.** Operators can manage secrets only from inside the VNet (or a future
peering/VPN); that is a runbook consequence, deliberately chosen.

---

## D-014 — The checkov gate is reconciled by fixing or recording, never soft-failing

**Date:** 2026-08-29

CI's checkov step (`soft_fail: false`) failed 16 checks on the initial scaffold: seven were
fixed in code (the D-013 vault lockdown, AKS `automatic_upgrade_channel` and `max_pods`, ACR
dedicated data endpoints, zone redundancy, and untagged-manifest retention) and nine remain as
inline `checkov:skip` entries, each carrying its reason at the resource it applies to. The
skips fall into three groups: cost-gated demo shape per D-005 (geo-replication, a dedicated
user node pool, ephemeral OS disks on B2s sizing), design choices this repository documents
(an authorized-IP API server rather than a private cluster, platform-managed disk keys), and
checks that cannot be satisfied or verified from here (the vault private-endpoint graph check
cannot cross layer roots, content trust is deprecated, quarantine is a preview needing an
approval workflow that does not exist, and encryption-at-host support is per-SKU and
unverifiable before a subscription exists). **Rejected: `soft_fail: true`**, which keeps
CI green by making the scanner advisory — a skip with a written reason is reviewable, while a
scanner nobody must read is decoration.
