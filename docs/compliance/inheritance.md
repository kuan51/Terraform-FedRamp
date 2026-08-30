# Control Inheritance

Status: seed document. Names the leveraged authorized service and what may legitimately be
claimed as inherited from it.

## Leveraged authorized service

**Microsoft Azure Commercial**, holding a FedRAMP High Provisional Authorization to Operate.

Scope constraint that matters operationally: **all US public Azure regions are in scope; no
region outside the United States is.** Deploying this system to a non-US region would not
degrade the inheritance — it would eliminate it, silently, with nothing in the configuration
looking wrong.

That is why later Terraform layers read the region from `0-foundation`'s output rather than
from the environment config file. A config edit cannot strand part of the estate outside the
authorization boundary without also moving the foundation.

## Why leveraging an authorized CSP is not optional

FedRAMP guidance is explicit on this point: controls can only be inherited from a
pre-existing FedRAMP authorization, and where a system is hosted on an IaaS or PaaS that is
not FedRAMP authorized, **there is no leveraging or inheritance relationship at all.**

This is the single decision that determines how much of the SSP is inheritable. On a
non-authorized host, every physical, environmental, and infrastructure control becomes
customer-responsible with no authorized source to point at — the CRM has zero inheritable
rows and the package is not credible. See [D-001](../decisions/DECISIONS.md) for the
alternatives considered.

## What is inherited

Broadly, the controls Azure implements at the infrastructure layer and the customer cannot
reach:

- **PE** — physical and environmental protection, in its entirety. Datacenter access,
  power, fire suppression, temperature control.
- **MA** — controlled maintenance of the underlying infrastructure.
- **MP** — media protection and sanitization for physical storage.
- **PS** — personnel screening for Microsoft datacenter and operations staff.
- Portions of **SC** and **SI** relating to the hypervisor, host operating system, and
  physical network fabric.

For each of these, the SSP marks the control inherited and names Azure Commercial with its
FedRAMP identifier and authorization date. Per FedRAMP guidance, the SSP does **not** need
to describe how Azure implemented the control — that detail lives in the leveraged system's
authorization package.

## What is shared

Controls where Azure provides a capability and this system must configure it correctly.
Inheriting the capability is not the same as implementing the control:

- **AC** — Azure provides Entra ID; this system configures RBAC, disables local cluster
  accounts, and restricts API server access.
- **AU** — Azure provides Log Analytics and diagnostic settings; this system decides what is
  collected, for how long, and reviews it.
- **SC** — Azure provides network primitives; this system configures segmentation, private
  endpoints, and network policy.
- **CM** — Azure provides Policy; this system chooses and assigns the initiative.

## What is entirely customer responsibility

Everything above the platform: the workload, its configuration, its images, its secrets, its
network policy, and every organizational control — policies, procedures, training, incident
response, and contingency planning.

## Known gap

Marking a control inherited is a claim that requires the leveraged package to actually cover
it for the specific services in use. Not every Azure service is in FedRAMP scope, and service
scope changes over time. Before this document is cited as final, each service used by this
system should be checked against the current Azure FedRAMP audit scope listing rather than
assumed in scope because Azure as a whole is authorized.
