# Authorization Boundary

Status: seed document. Defines what is inside the boundary, what is adjacent, and where
data crosses.

## Inside the boundary

Everything Terraform in this repository creates, within one Azure subscription in a US
region:

| Component | Layer | Notes |
|---|---|---|
| Resource groups | `0-foundation` | Security and platform |
| Log Analytics workspace + Sentinel | `0-foundation` | All audit data lands here |
| Key Vault | `0-foundation` | RBAC-authorized, no access policies |
| Virtual network, subnets, NSGs | `1-network` | `10.50.0.0/16` |
| Public DNS zone | `1-network` | Delegated subdomain only |
| Private DNS zones | `1-network` | Registry and Key Vault private resolution |
| AKS cluster | `2-cluster` | Entra RBAC, local accounts disabled |
| Container registry | `2-cluster` | Private endpoint, no public network access |
| Workload identities | `2-cluster` | Certificate issuer; no stored credentials |
| open-balena | `5-workload` | API, VPN, registry, S3, database |

## Adjacent, and explicitly outside

**The Azure platform itself.** Inherited under Azure Commercial's FedRAMP High P-ATO — see
[inheritance.md](inheritance.md). Inside the trust relationship, outside this boundary.

**Microsoft Entra ID.** The tenant is the identity provider for both operator access and
workload identity. It is a leveraged service, not a component this system builds.

**The domain registrar.** Holds the parent zone. Only the delegated subdomain's NS records
relate to this system; the apex and all other records are unrelated and out of scope. This
is the reason the system's own DNS was moved into Azure rather than managed at the registrar
— see [D-007](../decisions/DECISIONS.md).

**Managed devices.** Out of boundary by design. The device is an abstraction for this
project, and in a real deployment the endpoint would carry its own categorization and
authorization.

## Where data crosses the boundary

| Flow | Direction | Protection |
|---|---|---|
| Operator to Kubernetes API | Inbound | Entra-authenticated, local accounts disabled, API server IP allow-list |
| Operator to Terraform state | Inbound | Entra-authenticated, shared keys disabled, group-scoped RBAC |
| Device to open-balena API | Inbound | TLS at ingress |
| Device to open-balena VPN | Inbound | **Raw TCP through a load balancer, not HTTP ingress** |
| Cluster to container registry | Internal | Private endpoint; does not traverse the internet |
| Cluster to Key Vault | Internal | Private endpoint; workload identity, no stored secret |
| Diagnostics to workspace | Internal | Azure backbone |

## The VPN exposure, stated deliberately

open-balena's VPN component requires a raw TCP listener reachable from the internet. It
cannot sit behind HTTP ingress and cannot be fronted by a web application firewall, so the
usual layer-7 protections do not apply to it.

This is the single most exposed element of the system and it is load-bearing — without it,
devices cannot reach the platform. It is documented here rather than left for an assessor to
discover, and the compensating controls are: a dedicated load balancer with no other
services behind it, NSG restriction to the required port only, mutual authentication using
open-balena's own device certificates, and connection logging into the same workspace as
everything else.

## Trust domains

Two certificate authorities operate here and should not be confused:

- **Public TLS**, issued via cert-manager against the delegated Azure DNS zone using DNS-01.
  Protects operator- and browser-facing endpoints.
- **open-balena's own CA**, which issues device identities. Internal to the platform, not
  publicly trusted, and deliberately separate.

## Not yet defined

The boundary diagram itself, and the port-level detail for the VPN listener, are pending
layer 5. This document describes the intended boundary; it will need revisiting once the
workload is actually deployed and its real network surface is observable rather than
predicted.
