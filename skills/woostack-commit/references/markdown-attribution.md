# Markdown attribution

Load this reference only after the backend resolver selects Markdown and step 2 has ruled out the verified `change/*` artifact-neutral path.

## Invariant checks

When the staged changes touch `.woostack/specs/*.md`, `.woostack/plans/*.md`, or `.woostack/fixes/*.md`, run the cheap feature-state invariant checks on every affected spec/fix so the `/woostack-status` board stays honest. The affected set is every directly touched spec/fix plus the spec named by each touched plan's `source:` frontmatter or `**Source:**` line (a `[[specs/<basename>]]` wikilink, or the legacy `.woostack/specs/<file>.md` path). These are **advisory**: print any violation as a single non-blocking line in the commit report and continue. Never abort, stage differently, or change the commit because of them.

For each affected spec/fix, check:

- **1:1 plan** — exactly one plan resolves to it (for specs). (For fixes under `fixes/`, they are self-contained plans and this check is skipped).
- **`branch:` present** — the active lifecycle artifact frontmatter (`spec` before planning, `plan` after planning, `fix` for fixes) is non-empty and not the literal `unknown`.
- **`status:` in the enum** — spec frontmatter uses `draft|hardened|approved|abandoned`; plan frontmatter uses `planning|ready|executing|in-review|done|abandoned`; fix frontmatter uses the full fix lifecycle.

The phase enum and the join contracts are defined once in [`../../woostack-status/references/conventions.md`](../../woostack-status/references/conventions.md) — do not restate them here. If the `woostack-status` skill is not installed, skip this check silently.

## PR trailer

End the body with the exact `Spec: .woostack/specs/<file>.md` or `Spec: .woostack/fixes/<file>.md` **trailer line** naming the spec/fix this PR's increments trace to — the spec/fix whose `branch:` matches the current branch, or the spec/fix under active work. The `/woostack-status` board enumerates a spec/fix's increment PRs by searching this exact trailer (`gh pr list --search "Spec: <path>"`); the contract is defined in [`../../woostack-status/references/conventions.md`](../../woostack-status/references/conventions.md). Omit the trailer only when the Markdown change traces to no spec/fix (for example a repo-meta or tooling edit).
