# woostack-doctor check catalog

Each check under `../scripts/checks/` emits one tab-delimited finding:
`severity⇥code⇥fixable⇥path⇥message`.

- `severity` is `error` for structural breakage or `warn` for hygiene/retirement guidance.
- `fixable` is `auto` for an approved local repair or `report` for judgment-only evidence.
- CI (`--check`) exits nonzero only when an `error` finding exists.

## Calling convention

Resolve the mode before deriving any path (`$1` is overloaded):

```text
bash checks/<name>.sh <WOO_ROOT>
bash checks/<name>.sh --fix <WOO_ROOT> <extra-args...>
```

The orchestrator exports `WOOSTACK_DOCTOR_LIVE=0` for ordinary runs. An explicit controller-owned
live run supplies one normalized, non-secret receipt through `--live-receipt`; static checks never
inspect credentials or invoke a provider, adapter, HTTP, GraphQL, or hard-coded tool name.


## Checks

| code | check | severity | fixable | `--fix` args |
|---|---|---|---|---|
| `orphan-worktree` (present) | unregistered directory under `.woostack/worktrees/` (may hold work) | warn | report | — |
| `orphan-worktree` (stale) | registered worktree whose directory is gone | warn | auto | `<root>` (`git worktree prune`) |
| `gitignore-drift` | shipped-template managed line missing from `.woostack/.gitignore` | warn | auto | `<root>` |
| `omp-session-name` | active managed session-naming asset drift | warn | auto | `<root>` |
| `config-policy` | malformed canonical policy or resolver failure | error | report | — |
| `retired-provider` | legacy provider selector/profile is present as opaque inactive data | warn | report | — |
| `retained-data` | historical local draft/manifest directory is present | warn | report | — |
| `github-live` | trusted receipt is missing, malformed, foreign, or lacks a fixed read-only capability | error | report | — |
| `retired-status-config` | legacy top-level `status.staleDays` is present | warn | report | — |

OMP agent selection is host-owned. Doctor checks and repairs only its managed session-naming
asset; it never inspects, creates, repairs, or removes project agent definitions. A present
unregistered worktree directory may hold work and remains report-only; only a stale worktree
registration whose directory is gone can be pruned.

Legacy provider settings and retained records are not active policy and are never migration input
for this engine. Their findings are actionable retirement guidance, not local-operation blockers.

## Canonical policy and live receipt

`config-policy` invokes the Init resolver and does not duplicate its schema. The resolver validates
only the optional top-level `github` object; `artifacts.provider`, `artifacts.linear`,
`artifacts.plane`, and older root provider settings remain opaque and inactive. Template presence
and repair apply only to the tracked base file.

The controller resolves an authorized GitHub capability for an explicit Project operation, preferring
native host tools when suitable and supporting host-authenticated `gh`. Its fixed semantic contract
is defined at
[`artifact-providers/github.md#doctor-live-receipt`](../../woostack-init/references/artifact-providers/github.md#doctor-live-receipt).
It contains canonical owner/repository and Status-option evidence, and these capabilities:
`projectRead`, `statusFieldRead`, `pagination`, and `independentReadBack`. It never derives
requirements from a receipt-declared list; unrelated write/dependency capabilities may be false.
Parent-issue and exact issue paths do not require a receipt.

## Adding a check

1. Add `checks/<name>.sh` with the calling convention above.
2. Emit a stable code and keep provider/retained findings report-only.
3. Add a focused test using the existing shell assertion helpers.
4. Add the row here. Do not add a provider migration or test-only conversion engine.
