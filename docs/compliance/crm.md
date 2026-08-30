# Control Implementation Summary / Customer Responsibility Matrix

Status: seed document. Records which controls this build currently implements and where the
implementation lives, so evidence can be traced to configuration rather than asserted.

This is not a complete CRM. It covers what layers 0 through 2 actually implement today.
Rows are added as layers land.

## Legend

- **Inherited** — implemented by Azure Commercial under its FedRAMP High P-ATO.
- **Shared** — Azure provides the capability; this system must configure it.
- **Customer** — entirely this system's responsibility.

## Implemented so far

| Control | Responsibility | Implementation | Where |
|---|---|---|---|
| AC-2 Account Management | Shared | State access granted to an Entra group, not individuals; group membership is the reviewable artifact | state-bootstrap runbook, [D-004](../decisions/DECISIONS.md) |
| AC-3 Access Enforcement | Shared | Entra RBAC on the cluster; Key Vault uses RBAC authorization rather than access policies; local cluster accounts disabled | `modules/cluster`, `modules/foundation` |
| AC-6 Least Privilege | Shared | Storage Blob Data Contributor scoped to the state container, not the account; AcrPull and Key Vault Secrets User scoped per-resource | state-bootstrap runbook, `modules/cluster` |
| AC-17 Remote Access | Shared | API server IP allow-list; no public network access on the registry | `modules/cluster` |
| AU-2 Event Logging | Shared | Log sources selected and enabled: Activity Log, Key Vault audit, NSG events, cluster `kube-audit` and `kube-audit-admin`. **Storage data-plane logging is runbook-applied, not Terraform-enforced** — see the gap below | `modules/foundation`, `modules/network`, `modules/cluster`, state-bootstrap runbook |
| AU-3 Content of Audit Records | Inherited + Shared | Azure record format; this system chooses categories that carry actor and operation | diagnostic settings across all modules |
| AU-4 Audit Storage Capacity | Customer | **Gap.** Daily ingestion cap drops records once reached | [D-006](../decisions/DECISIONS.md) |
| AU-5 Response to Audit Failure | Customer | **Gap.** Cap causes a silent stop rather than an alert | [D-006](../decisions/DECISIONS.md) |
| AU-6 Audit Review | Shared | Single workspace with Sentinel onboarded, so sources can be correlated in one query | `modules/foundation` |
| AU-12 Audit Generation | Shared | Diagnostic settings on every resource that emits them | all modules |
| CM-2 Baseline Configuration | Customer | Entire estate is declarative Terraform under version control | this repository |
| CM-3 Configuration Change Control | Customer | Gated apply requiring typed confirmation; CI on every push | `bin/tf.ps1`, `.github/workflows` |
| IA-2 Identification and Authentication | Shared | Entra-authenticated state access and cluster access; shared keys and local accounts disabled | [D-004](../decisions/DECISIONS.md), `modules/cluster` |
| IA-5 Authenticator Management | Shared | Workload identity and managed identities throughout; **no static credential is issued or stored** by this configuration | `modules/cluster` |
| SC-7 Boundary Protection | Shared | Subnet segmentation, NSGs with explicit deny, private endpoints, no public registry access | `modules/network`, `modules/cluster` |
| SC-8 Transmission Confidentiality | Shared | Private endpoints for internal traffic; TLS at ingress | `modules/network`, `modules/cluster` |
| SC-12/13 Cryptographic Key Management | Inherited + Shared | Key Vault with purge protection and soft delete; Azure-managed cryptography | `modules/foundation` |
| SI-4 System Monitoring | Shared | Monitoring agent and optional Defender for Containers, both reporting to the workspace | `modules/cluster` |

## Notable gaps recorded rather than hidden

**AU-4 / AU-5.** The Log Analytics daily quota is a hard cap. When reached, ingestion stops
and audit records are lost. A production posture would alert on approaching the quota instead
of dropping data at it. See [D-006](../decisions/DECISIONS.md).

**Availability controls (CP family).** The demo cost gates configure a free-tier control
plane with no uptime SLA and a single availability zone. This does not meet the availability
posture the categorization implies. See [D-005](../decisions/DECISIONS.md).

**One audit source is manual.** The storage data-plane diagnostic setting — the one that
makes a Terraform state write attributable to a named identity — is applied by part 2 of the
state-bootstrap runbook, not by Terraform. It cannot be otherwise: it targets the Log
Analytics workspace, which does not exist until layer 0 has applied, and the state account
itself is bootstrap infrastructure tracked in no state file.

The consequence is that this source is not self-healing. Rebuilding the state account
without running part 2 leaves the estate looking fully instrumented while the state audit
trail is silently absent. An assessor tests exactly this by asking what happens on a
rebuild. Until it can be enforced, the mitigation is that the runbook carries a verification
query and the rebuild path runs both parts.

**Empty allow-lists.** `api_server_authorized_ip_ranges` and `admin_group_object_ids` both
default to empty. Empty means "reachable from anywhere" and "administrable by nobody"
respectively. Both must be populated before any real apply; both are flagged in the
environment config and the README.

## Not yet addressed

The organizational control families — AT (training), IR (incident response), CP
(contingency planning), PL (planning), RA (risk assessment), and the policy-and-procedure
control in every family — are not infrastructure and are not implemented by this repository.
They belong to the policy work that accompanies it.
