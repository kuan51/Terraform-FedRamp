# Run Log

What actually happened, in order. Intent is logged as its own entry; the verified result is a
separate entry naming the exact command used, so any check here can be re-run later.

A skipped or missed check gets its own entry rather than a silent gap.

---

## 2026-08-29

**Intent.** Reset this file and `DECISIONS.md` to fresh versions at the start of the
repository, keeping the decisions the rest of the tree cites and dropping the accumulated
narrative. Decision numbering is preserved so existing `D-00N` references stay pointed at the
entries they were written against. From this entry forward the log is retained, not cleared.

**Verified — every decision reference in the tree resolves.** Each `D-00N` found anywhere in
the repository exists as a heading in the rewritten decision log.

```
$ grep -rhoE 'D-0[0-9]{2}' --include='*.md' --include='*.yaml' --include='*.yml' . | sort -u
$ grep -oE '^## D-0[0-9]{2}' docs/decisions/DECISIONS.md | sort -u
  -> every referenced number present; no reference to a dropped entry
```

**Verified — formatting is clean across the tree.**

```
$ terraform fmt -recursive -check
  (no output, exit 0)
```

**Verified — all three layers initialise and validate.** Run without a backend; there is no
Azure subscription, so `plan` remains out of reach.

```
$ terraform -chdir=layers/0-foundation init -backend=false && terraform -chdir=layers/0-foundation validate
  Success! The configuration is valid.
$ terraform -chdir=layers/1-network init -backend=false && terraform -chdir=layers/1-network validate
  Success! The configuration is valid.
$ terraform -chdir=layers/2-cluster init -backend=false && terraform -chdir=layers/2-cluster validate
  Success! The configuration is valid.
```

**Not verified, and not verifiable by this gate.** `plan` needs live credentials; the
Entra-authenticated backend is skipped entirely by `-backend=false`; the cross-layer
`terraform_remote_state` contracts are unresolved by `validate`; and nothing here says whether
open-balena runs. The contract table in [CONVENTIONS.md](../../CONVENTIONS.md) is the only
thing standing in for the third of those. See [D-010](DECISIONS.md).

**Verified — nothing was published.** The work is a single local commit on a branch with no
upstream.

```
$ git rev-list --count 7a98b44..HEAD   -> 1
$ git status -sb                       -> no upstream tracking branch
```

**Intent.** Collapse the two identical `azurerm_network_security_group` resources in
`modules/network` (`aks_nodes`, `private_endpoints` — same two rules, same tags) and their
matching `azurerm_subnet_network_security_group_association` resources into one `for_each`
each, following an overengineering audit. Resource names are unchanged; only the state
address moves from a fixed label to a `for_each` key, which is safe pre-apply.

**Verified — formatting is clean and all three layers still validate.**

```
$ terraform fmt -recursive -check -diff
  (no output, exit 0)
$ terraform -chdir=layers/0-foundation init -backend=false && terraform -chdir=layers/0-foundation validate
  Success! The configuration is valid.
$ terraform -chdir=layers/1-network init -backend=false && terraform -chdir=layers/1-network validate
  Success! The configuration is valid.
$ terraform -chdir=layers/2-cluster init -backend=false && terraform -chdir=layers/2-cluster validate
  Success! The configuration is valid.
```

**Intent.** Reconcile the 16 checkov failures from CI run 33280860432 on PR #1 (the gate is
`soft_fail: false`, so the branch cannot merge red). Fix in code what the posture actually
wants — the Key Vault network lockdown and its layer-2 private endpoint (D-013), ACR dedicated
data endpoints, zone redundancy and untagged-manifest retention, AKS
`automatic_upgrade_channel` and `max_pods` — and record the other nine as inline
`checkov:skip` entries, each with its reason at the resource (D-014). Add a
`kubernetes_version` validation, since the patch upgrade channel makes the major.minor format
load-bearing.

**Verified — formatting is clean and all three layers validate after the hardening.**

```
$ terraform fmt -recursive -check -diff
  (no output, exit 0)
$ terraform -chdir=layers/0-foundation init -backend=false && terraform -chdir=layers/0-foundation validate
  Success! The configuration is valid.
$ terraform -chdir=layers/1-network init -backend=false && terraform -chdir=layers/1-network validate
  Success! The configuration is valid.
$ terraform -chdir=layers/2-cluster init -backend=false && terraform -chdir=layers/2-cluster validate
  Success! The configuration is valid.
```

**Not verified locally — checkov.** checkov is not installed on this machine and installing it
is out of scope, so the scanner itself did not run here. The seven code-fixed checks were
instead verified against the check implementations at bridgecrewio/checkov master (commit
`2137e91a`) — each inspects exactly the argument the fix sets — and the inline skip placement
matches the comment parser's contract (a `checkov:skip=` line strictly inside the resource
block). The authoritative verdict is the CI run on this push.
