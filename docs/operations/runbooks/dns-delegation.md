# Runbook: Delegate the DNS subdomain

Points the system's subdomain at the Azure DNS zone that `1-network` creates.

**This is a manual gate between layer 1 and layer 5.** It cannot be automated from this
repository and it cannot be done early: Azure assigns the zone's nameservers when the zone
is created, so they do not exist until `1-network` has applied.

Certificate issuance in layer 5 fails until this delegation has propagated.

## What this does and does not do

It adds NS records for **one subdomain** at the registrar. The apex, MX records, and
everything else stay exactly where they are, under the same control as before. Nothing is
transferred and nothing moves. Deleting the four NS records reverses it completely.

## Prerequisites

- `1-network` applied successfully.
- Access to DNS management for the parent domain at the registrar.

## Steps

**1. Read the nameservers Azure assigned.**

```powershell
bin/tf.ps1 network output dns_zone_nameservers
```

Four hostnames, of the form `ns1-NN.azure-dns.com.`, `ns2-NN.azure-dns.net.`,
`ns3-NN.azure-dns.org.`, `ns4-NN.azure-dns.info.`

**2. Add them at the registrar.**

In the parent zone, create an `NS` record for the subdomain label only — the label, not the
fully-qualified name. For `security.example.com` in the `example.com` zone, the record name
is `security`.

| Field | Value |
|---|---|
| Type | `NS` |
| Name | the subdomain label |
| Value | all four Azure nameservers, one per record or as a multi-value record |
| TTL | 3600 |

If the registrar proxies traffic by default (Cloudflare's orange cloud, for example), NS
records are not proxied — but confirm no conflicting `A` or `CNAME` record exists at the same
label. A leftover record there will shadow the delegation and the failure looks like a DNS
problem rather than a configuration one.

**3. Wait for propagation.** Usually minutes; allow up to the parent zone's TTL.

## Verify

Delegation is working when the parent zone returns the Azure nameservers:

```bash
dig NS security.example.com +short
```

Expect the four `azure-dns` hostnames. If you get `NXDOMAIN`, the record name is probably
fully-qualified where it should be just the label.

Confirm the Azure zone answers authoritatively:

```bash
dig SOA security.example.com @ns1-NN.azure-dns.com. +short
```

Do not proceed to layer 5 until both succeed. cert-manager solves DNS-01 by writing a TXT
record into the Azure zone and waiting for the public resolver to return it; if delegation is
incomplete, the record is written successfully and never becomes visible, and the failure
presents as a certificate that stays pending with no obvious cause.

## Why the zone is in Azure at all

Two reasons, recorded in [D-007](../../decisions/DECISIONS.md): it keeps the system's DNS
inside the authorization boundary, and it lets cert-manager solve DNS-01 challenges using
workload identity — so no registrar API token has to exist as a long-lived secret in the
cluster.

## Rollback

Delete the NS records at the registrar. The subdomain stops resolving; nothing else is
affected.
