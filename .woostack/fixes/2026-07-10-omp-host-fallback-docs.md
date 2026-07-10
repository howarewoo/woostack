---
type: fix
status: in-review
branch: fix/omp-host-fallback-docs
---

# Fix: document omp host-level fallback beneath tier routing

## 1. Root Cause

woostack's tier docs describe **static routing** (`models.<tier>` → generated
`.omp/agents/woostack-<tier>.md` defs) but say nothing about the **runtime failover layer**
omp runs underneath it. Grounded in the omp harness docs
(`omp://non-compaction-retry-policy.md`, `omp://models.md`, `omp://settings.md`): on a
usage-limit / rate-limit error omp first rotates sibling credentials for the same provider,
then applies per-model fallback chains (`retry.fallbackChains`, default-on
`retry.modelFallback`) as a **temporary** model switch announced via `retry_fallback_applied`
events and reverted on cooldown expiry (`retry.fallbackRevertPolicy: cooldown-expiry`).

Because no woostack doc states this, two concrete failure modes exist:

- **Misclassification risk.** `skills/woostack-execute/references/subagent-driver.md:134-137`
  commands "never pretend a tier ran" / "say so (degraded)". A host-applied temporary
  fallback mid-task superficially matches that forbidden pattern; a future reviewer or the
  driver doctrine itself can flag legitimate host-owned recovery as a silent tier violation
  (wisdom `autonomy-needs-structural-proof` makes this class of reading likely).
- **Overnight stall risk.** `skills/woostack-execute-overnight/SKILL.md` pre-flight (items
  1-3) checks review feasibility but gives no guidance that on omp, provider usage
  exhaustion mid-run is survivable **only if** a second credential or a fallback chain is
  configured — otherwise the run's tracks halt on retry failure with nobody watching.

Evidence: `skills/using-woostack/references/model-tiers.md:35-37` (omp bucket — routing
only), `subagent-driver.md:137` (omp branch — routing only),
`execute-overnight/SKILL.md:62-79` (pre-flight — no provider-resilience note),
`site/content/docs/configuration.mdx:124-170` (omp host section — routing only;
`concepts.mdx` has no omp host-taxonomy content, so it is out of scope).

## 2. Proposed Fix

Doc-only, four files, ~10 lines total. No config-contract change, no new key, no behavior
change, no management of omp host config (boundary stated explicitly).

1. **`skills/using-woostack/references/model-tiers.md`** — add a short **"Host-level
   fallback (omp)"** note after the omp bucket's "Cross-consumer coexistence" paragraph
   (≤3 lines: tier routing is static; usage-exhaustion failover is host-owned via omp
   `retry.fallbackChains` / credential rotation, temporary and self-reverting; woostack
   documents but never writes omp host config). **Constraint:** this file is inlined whole
   into review's CI orchestrator prompt (`load-prompt.sh:193`) — keep it terse, and add no
   table column (AC8 structural test pins the four-provider table).
2. **`skills/woostack-execute/references/subagent-driver.md`** — one sentence in the
   "Under omp (agent-by-tier)" paragraph: a host-applied **temporary** model fallback (omp
   retry events) is host-owned recovery, announced and reverted by the host — it is **not**
   the "silent tier claim" this doctrine forbids, and the driver does not re-report it.
3. **`skills/woostack-execute-overnight/SKILL.md`** — one advisory bullet in pre-flight
   (adjacent to item 3, review feasibility): under omp, check usage-exhaustion resilience
   (a second provider login or `retry.fallbackChains` covering the tier models) before an
   unattended run; without it, mid-run exhaustion halts the track. **Advisory only — adds
   no new refuse-to-start condition** (mid-run exhaustion already resolves through the
   existing blocker-and-halt path).
4. **`site/content/docs/configuration.mdx`** — one sentence in the omp host section
   (after the flat-tier/`thinkingLevel` paragraph, ~line 162): omp additionally provides
   host-level usage-limit fallback beneath these tiers, configured in omp's own settings,
   outside `.woostack/config.json`. MDX gotcha applies: backtick all code-ish tokens, no
   bare braces/angle brackets (`authored-mdx-escapes-jsx-and-table-pipes`).

## 3. Implementation Plan

- [x] **Step 1: Reproduce with failing grep assertions (red)**
  - Assert each phrase absent before the edit, one assertion per physical line
    (`grep-assertion-single-physical-line`):
    - `grep -c "Host-level fallback" skills/using-woostack/references/model-tiers.md` → 0
    - `grep -c "not the silent tier claim" skills/woostack-execute/references/subagent-driver.md` → 0
    - `grep -c "usage-exhaustion resilience" skills/woostack-execute-overnight/SKILL.md` → 0
    - `grep -c "host-level usage-limit fallback" site/content/docs/configuration.mdx` → 0
- [x] **Step 2: Apply the four doc edits (green)**
  - Edit the four files per §2; each asserted phrase lands unbroken on one physical line.
- [x] **Step 3: Verification**
  - The four grep assertions from Step 1 now return 1.
  - `model-tiers.md` four-provider table unchanged (no new column):
    `bash skills/woostack-init/scripts/tests/test-omp-lockstep.sh` passes (it asserts the
    table header line and the omp bucket phrases verbatim).
  - `pnpm -C site build` green (configuration.mdx is authored, tracked). Run in the fix
    worktree after a real `pnpm install` — Turbopack rejects a node_modules symlink that
    escapes the worktree root (`site-build-in-worktree-needs-real-node-modules`).
  - No new refusal condition in execute-overnight: the added bullet contains
    "advisory" phrasing and touches no `refused-to-start` / halt-policy text.

---

_Hardened 2026-07-10 — resolutions: (1) driver has **no re-report obligation** for a
host-applied fallback (it cannot observe omp retry events; the host announces and
transcripts record the concrete model); (2) the overnight bullet is **advisory**, adding no
refusal condition; (3) the note is **omp-scoped** (fallback is a host feature);
(4) lockstep joint pinned by `test-omp-lockstep.sh`; (5) grep tokens are ASCII;
(6) site build caveat recorded. No open questions remain._
