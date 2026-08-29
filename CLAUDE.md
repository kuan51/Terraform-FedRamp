# Working agreement

Read [CONVENTIONS.md](CONVENTIONS.md) before changing anything. It is the current-state
reference; this file is only the things that are easy to get wrong.

## The three documents

- `CONVENTIONS.md` — current state. Edit in place when a rule changes.
- `docs/decisions/DECISIONS.md` — why. **Append-only.** Never edit a past entry; reverse a
  decision by writing a new one that says "Supersedes D-00N". **Four sentences of prose or
  fewer per entry:** what was decided, why, and the strongest alternative rejected or gap
  accepted. A table is fine where numbers carry the argument.
- `docs/decisions/RUNLOG.md` — what actually happened. Log intent and verified result as
  separate entries, naming the exact command. A skipped check gets its own entry rather than
  a silent gap.

Both files were reset once, at the start of the repository, to drop accumulated narrative that
had stopped describing the platform. Decision numbers were preserved so existing references
still resolve. **That was a one-off.** From the 2026-08-29 entry onward both files accumulate;
do not clear either of them again.

## Things that will bite you

**Nothing here has ever been applied.** There is no Azure subscription yet. `terraform plan`
cannot run — it needs live credentials. The gate is `fmt`, `init -backend=false`, `validate`.
Do not claim a layer works because it validates; validate checks argument names against a
provider schema and nothing more.

**`validate` does not resolve `terraform_remote_state`.** A layer reading an output that does
not exist validates clean and passes CI. The contract table in CONVENTIONS.md is the only
thing standing in for that check — if you add a cross-layer read, update both sides of it.

**No value is hardcoded at a module call site.** Everything comes from
`environments/{env}.yaml`. If you find yourself typing a literal into a `module` block, the
value belongs in the YAML.

**Region comes from layer 0's output, not from the config file.** Later layers read
`data.terraform_remote_state.foundation.outputs.location`. This is deliberate: only US
regions are in scope for Azure Commercial's FedRAMP P-ATO, and a config edit that stranded
half the estate elsewhere would silently void the inheritance the whole project rests on.

**Empty lists in the config are unsafe defaults, not neutral ones.**
`api_server_authorized_ip_ranges: []` means the API server is reachable from anywhere.
`admin_group_object_ids: []` combined with `local_account_disabled = true` means nobody can
administer the cluster. Both must be populated before a real apply.

**Cost gates are deliberately weaker than the security posture.** The demo defaults do not
meet the availability posture the categorization implies. That is recorded in
[D-005](docs/decisions/DECISIONS.md). Do not "fix" it silently — either leave it and keep the
record, or change it and add a decision entry.

## Provenance

This repository takes its *structural* framework — numbered layers, one module per layer, a
single environment YAML, a gated entrypoint, a compliance-domain docs tree — from a separate
private project. Reusing that shape is intended. Reusing its content is not.

**Two separate checks, and passing one says nothing about the other.**

*Identifiers.* No subscription IDs, storage account names, workspace names, tool names,
decision-record numbers, CIDR allocations, email addresses, personal names, or domains from
that project. This check is mechanical and tends to pass.

*Wording.* No sentences from its documentation. This check is the one that fails, and it
fails quietly — a document can be free of every identifier and still be substantially
someone else's text.

**Measure it, do not assert it.** "I wrote this from an outline" is not evidence. Compare
n-grams against the source tree before making any provenance claim. Keep the comparison local — an automated version would
have to name the source project to run, which is the thing being kept out (D-011).

The practical defence is upstream of the check: when a document has an analogue in that
project, write it from the *rules*, reasoning each one out in your own words. Reworking their
sentences produces a paraphrase, and a paraphrase is still derived text.

## Commits

Conventional Commits (`type(scope): subject`). One imperative subject line, under 72
characters. Body explains what changed and why in prose, not a bullet list restating the
diff. Never commit to `master` directly; branch first.

Keep each commit green: `fmt` clean and every layer validating.
