# OpenRouter (OpenCode) — Multi-Angle Agentic Review

OpenCode runs an agentic shell. Use its subagent system if available (`@subagent`-style spawning); otherwise fall back to the sequential structure shown below. The output contract is identical to the other providers.

The shared header above lists prefetched artifacts, findings schema, blocking criteria, and the do-NOT-flag list. **Apply them verbatim.** Per-angle prompt bodies live at `$WOO_REVIEW_ACTION_PATH/prompts/angles/<angle>.md` in the bundled action repo.

**Host identifier:** default `opencode` (substitute into the credits line `<host>` placeholder per `_orchestrator-header.md`). When an OpenCode agent persona / subagent profile is identifiable (e.g. `mimo-v2.5`), append it in parentheses: `opencode (mimo-v2.5)`. Read the active profile from the OpenCode runtime when available; otherwise use the bare `opencode` slug.

**Provider / model accuracy.** This file's model table assumes OpenRouter + DeepSeek, but OpenCode can route to *any* provider/model (Anthropic, OpenAI, Google, local, …). For the credits line, follow `_orchestrator-header.md`'s precedence (`WOO_REVIEW_PROVIDER` / `WOO_REVIEW_MODEL` env vars > OpenCode runtime introspection > this file's default > `unknown`) and report what the adjudicator actually ran on. Do NOT hard-code `openrouter` / `deepseek-v4-pro` into the credits line unless that is genuinely the active route — if mimo-v2.5 is wired to `anthropic` + `claude-sonnet-4-6`, those are the correct values.

## Model selection

OpenCode + OpenRouter can route per-subagent if the OpenCode runtime supports it. When spawning each angle or adjudicator subagent, resolve an effective tier in order:
1. `FORCE_TIER` in Review Context (`fast`/`deep`) when present.
2. Otherwise the angle or adjudicator prompt's `tier:` frontmatter.

Then resolve that effective tier via the shared **Model Tiers** table (canonical at
[`../../using-woostack/references/model-tiers.md`](../../using-woostack/references/model-tiers.md),
inlined into `_orchestrator-header.md` above); the OpenRouter column is:

- `fast` → `openrouter/deepseek/deepseek-v4-flash`
- `standard` → `openrouter/deepseek/deepseek-v4-pro`
- `deep` → `openrouter/deepseek/deepseek-v4-pro` with `reasoning_effort: xhigh` (use `high` for a lower-cost reasoning pass)

OpenRouter exposes only two DeepSeek slugs — reasoning is a `reasoning_effort` parameter on the same `v4-pro` slug, not a separate model ID. DeepSeek V4 supersedes R1 — do not route to `deepseek-r1`. If the OpenCode build cannot route per-subagent or cannot pass `reasoning_effort`, fall back to a single model for the whole job and pin it to the resolved `run_model` from `load-prompt.sh`. `inputs.model` (action.yml) overrides the default tier but is itself overridden when `FORCE_TIER` is set.

**Per-repo override:** before applying the final model slug above, check `$OUTDIR/config.json` for `models.openrouter.<effective_tier>` and then flat `models.<effective_tier>`. The loader normalizes a scalar leaf to `{model, effort?}` and preserves a fallback leaf as an ordered array; select entry 0 before reading `.model` (`jq -r '((.models.openrouter.deep // .models.deep) | if type=="array" then .[0] else . end | if type=="object" then .model else . end) // empty' $OUTDIR/config.json`, etc.). Precedence: `FORCE_TIER` (if set) first, then `inputs.model`, then `models.openrouter.<effective_tier>` > `models.<effective_tier>` > table default.

---

## IMPORTANT: MODE-BASED EXECUTION

Check the `Execution mode` in the Review Context above.

### MODE: review
You are running as a parallel worker for a specific angle.
- The `Target angle` in Review Context is the only angle you must audit.
- Do NOT post inline comments.
- Do NOT update the PR body or title.
- Do NOT manage labels.
- Run ONLY Phase 2 below for your target angle.
- Write findings to `$OUTDIR/findings.<angle>.json` (default `$OUTDIR/findings.<angle>.json`) and then EXIT.
- The findings file MUST be a JSON array only — starts with `[`, ends with `]`, no preamble, no markdown fences, no commentary. See *Output Discipline* in `_worker-header.md`. Validate every `line` via `scripts/resolve-diff-line.sh` and drop findings the helper rejects.

### MODE: validate
You are running as the final controller.
- Read all `$OUTDIR/findings.<angle>.json` files from disk.
- Perform Phase 3 (Evidence Adjudication) below.
- Perform Phase 4 (Submit Native PR Review) below.
- Do NOT modify the PR title, PR description, or PR labels.
- Exit.

### MODE: full (or detect)
Perform all phases (1 through 4) sequentially.

---

**OUTDIR handoff.** `$OUTDIR` defaults to a per-project `/tmp/pr-review-<hash>` (derived from the repo's git toplevel by `scripts/resolve-outdir.sh`) so concurrent reviews of different repos on one machine never share a tree. Resolve it ONCE in the orchestrator — `source "$WOO_REVIEW_ACTION_PATH/scripts/resolve-outdir.sh"` sets and exports `OUTDIR` — then export `OUTDIR` to **every** sub-agent you spawn. Sub-agents prefer the inherited `$OUTDIR`; if it is unset they re-derive via the same helper. Never fall back to a bare `/tmp/pr-review`.

## Phase 1 — Read artifacts + draft summary

Read `$OUTDIR/diff.txt`, `$OUTDIR/meta.json`, `$OUTDIR/angles.txt`. Draft a 1–2 sentence summary, change bullets, files-by-category, optional manual test plan — all destined for the **Review body** in Phase 4. Do NOT call `gh pr edit`; the PR title and description must remain untouched.

## Phase 2 — Per-Angle Audit (chunk-aware)

If `$OUTDIR/chunks.txt` exists (issue #14), the unit of work is `(angle, chunk_id)` rather than plain angle: each agent reads `$OUTDIR/diff.chunk-<id>.txt` and writes findings to `$OUTDIR/findings.<angle>.<chunk_id>.json`. When `chunks.txt` is absent, the angle agent uses `diff.txt` and `findings.<angle>.json` as before.

For each angle in `$OUTDIR/angles.txt` (× each chunk when chunked):

- If the OpenCode runtime supports parallel subagents, spawn one subagent per `(angle, chunk_id)` (or per angle in the unchunked case) in parallel.
- Use a **plain/general-purpose/default** OpenCode subagent profile. Do not use `@woostack-review`,
  `skill://woostack-review`, or any `woostack-review` skill-scoped worker; the worker receives the
  angle prompt and prefetched artifacts directly.
- Otherwise run them sequentially in listed order.

Each angle agent:

1. Loads `$WOO_REVIEW_ACTION_PATH/prompts/angles/<angle>.md`.
2. Executes the angle prompt against its assigned diff. For `react` run `npx -y react-doctor@$REACT_DOCTOR_VERSION --diff $BASE_REF --offline`.
3. Writes findings to `$OUTDIR/findings.<angle>.json` (or `findings.<angle>.<chunk_id>.json` in chunked mode) — JSON array per the schema in `_worker-header.md`.

Stay within each angle's scope; do not let one angle flag issues that belong to another. `merge-findings.sh` (Phase 3) handles within-angle dedup across chunks.

**Retry-once recovery.** Subagents can die mid-run (stream errors, turn-limit interrupts) and leave no findings file. After Phase 2 reports done, before invoking `merge-findings.sh`, scan `$OUTDIR/angles.txt` (× `chunks.txt` when chunked) and check that each expected `findings.<angle>.json` (or `findings.<angle>.<chunk_id>.json`) exists and parses as a JSON array via `jq -e 'type == "array"'`. For any path that fails the check, re-spawn THAT `(angle, chunk)` subagent ONCE with the same brief and model slug. Cap is one retry total per pair — if the retry also fails, leave the file as-is and proceed to Phase 3. The merge step's recovery handles malformed JSON; missing files just mean the angle produced no findings.

## Phase 3 — Evidence adjudication

Merge angle arrays into `$OUTDIR/raw_findings.json`, then spawn exactly one fresh standard-tier
adjudicator with `$WOO_REVIEW_ACTION_PATH/prompts/validator.md`. A local runtime without fresh
isolation blocks. The adjudicator independently checks concrete evidence, confidence/severity,
changed-line ownership, tooling overlap, deferral, and fix shape; writes
`findings.adjudicator.json` and `receipt.adjudicator.json`; then exits. Unsupported candidates are
dropped, not rewritten, in this sole adjudication pass.

```bash
if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  bash "$WOO_REVIEW_ACTION_PATH/scripts/verify-receipts.sh" --validators
else
  bash "$WOO_REVIEW_ACTION_PATH/scripts/verify-receipts.sh" --validators-local
fi
bash "$WOO_REVIEW_ACTION_PATH/scripts/intersect-findings.sh"
```

This writes `findings.json` once after receipt, identity, digest, stale-head, and changed-line gates.

## Phase 4 — Submit Native PR Review

Compute counts and build `STATUS_LINE`. Follow `_orchestrator-header.md` exactly: submit one batched native review with every inline comment, the summary, and that status line. The payload builder first computes the candidate event from findings and open prior threads, then independently reads the implementation-author and authenticated-reviewer native GitHub IDs. It uses the candidate only when both reads are complete and the IDs differ; otherwise it posts `COMMENT` without changing `STATUS_LINE`. A login, profile/session, credential, or token-store label is never actor proof.

Do NOT call `gh pr edit`. Do NOT add, remove, or mutate PR labels. The PR title, PR description, and PR labels stay untouched.

## Rules

- Execute autonomously — never request user confirmation.
- Trust prefetched artifacts.
- `findings.json` is the single source of truth for posting.
- Parallel subagents in Phase 2 must complete before Phase 3.
