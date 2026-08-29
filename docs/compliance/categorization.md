# Security Categorization (FIPS 199)

Status: seed document. Establishes the categorization this build targets and records the
argument against it.

## System description

A cloud-hosted command-and-control backend for a fleet of medical devices operated by
combat medics in a field environment. The platform manages device identity, configuration,
software delivery, and remote connectivity. It does not itself deliver care; it keeps the
devices that do reachable, current, and trustworthy.

## Categorization as built

| Objective | Level as built | Level a real system warrants |
|---|---|---|
| Confidentiality | Moderate | **High** |
| Integrity | Moderate | **High** |
| Availability | Moderate | **High** |

**Overall as built: Moderate.**

## Why the two columns differ

This is built to Moderate because that is a workable control count for a project of this
size. The honest categorization is higher, and pretending otherwise would be the kind of
thing an assessor finds immediately.

**Availability is the clearest.** FIPS 199 defines High impact as a severe or catastrophic
adverse effect. For a platform supporting combat casualty care, loss of availability does
not degrade a business process — it can contribute to loss of life. That is the textbook
definition of catastrophic.

**Confidentiality is arguably High** on two independent grounds. The platform is adjacent to
protected health information, and device telemetry from a deployed fleet is itself
operationally sensitive: device locations and activity patterns disclose force positions and
casualty rates.

**Integrity is arguably High** because the platform delivers software to medical devices.
An attacker who can push a modified image to the fleet has a path to affecting patient care
directly.

## What a real deployment would additionally require

A system of this description operated for the Department of Defense would fall under the
**DoD Cloud Computing Security Requirements Guide** at Impact Level 4 or 5, layered on top
of a FedRAMP baseline rather than instead of it. That implies Azure Government rather than
Azure Commercial, which brings personnel screening and US-person access requirements this
project cannot satisfy — see [D-001](../decisions/DECISIONS.md).

## Consequence for this build

The control set implemented here is narrower than the modeled mission would require, and the
demo cost gates are weaker still — a free-tier control plane with no uptime SLA and a single
availability zone does not meet a High availability posture. Both are recorded as accepted
deviations in [D-002](../decisions/DECISIONS.md) and [D-005](../decisions/DECISIONS.md)
rather than presented as adequate.

---

**To confirm before this document is cited as final:** the Moderate and High baseline control
counts should be read directly off the FedRAMP Rev5 baseline workbook. Second-hand figures
were deliberately left out of this document rather than repeated unverified.
