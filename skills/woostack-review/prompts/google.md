# Google (Antigravity CLI) — Multi-Angle Orchestration

You are reviewing a pull request using Antigravity CLI (`agy`). Antigravity orchestrates subagents **dynamically**: the orchestrator instantiates one subagent per task on demand, each with its own isolated context window, runs them in parallel, and collects only their final results — the same pattern Claude Code's `Task` tool uses. There is no static `@generalist` definition to register; describe each subagent's brief inline when you dispatch it. Dispatch one subagent per angle in a single turn to maximize parallelism.

The shared header above lists prefetched artifacts, the findings schema, the blocking criteria, and the do-NOT-flag list. **Apply them verbatim.** Per-angle prompt bodies live at `$WOO_REVIEW_ACTION_PATH/prompts/angles/<angle>.md`.

**Host identifier:** default `antigravity-cli` (substitute into the credits line `<host>` placeholder per `_orchestrator-header.md`). If invoked from another Google host, use that host's canonical slug instead.

## Model selection

Antigravity CLI runs Gemini models — by default `gemini-3-5-flash` (Antigravity's own default). Dynamically spawned subagents inherit the orchestrator session's model, so the `tier:` frontmatter on each angle prompt is **effectively informational**: there is no documented static per-subagent model override. The legacy `~/.gemini/settings.json` `agents.overrides` path is gone — under Antigravity subagents are orchestrated on demand, not pre-configured, and per-run config lives under `.agents/`. Default every angle subagent to the session's model.

Google's 3.5 line currently ships only `gemini-3-5-flash`, so tier routing is a no-op until a larger 3.5-line model appears.

**Per-repo override / FORCE_TIER:** run-model resolution is driven by `load-prompt.sh` before this phase. Honor the following precedence:
- `FORCE_TIER` from Review Context (`fast`/`deep`) if present
- `inputs.model` (explicit)
- `models.google.<run_tier>` and flat `models.<run_tier>` in `$OUTDIR/config.json`
- default `gemini-3-5-flash`

Revisit subagent routing when larger Google models ship or Antigravity exposes per-subagent model selection; until then, treat this as a single-session host.

---

## IMPORTANT: MODE-BASED EXECUTION

Check the `Execution mode` in the Review Context above.

### MODE: review
You are running as a parallel worker for a specific angle.
- The `Target angle` in Review Context is the only angle you must audit.
- Do NOT post inline comments.
- Do NOT update the PR body or title.
- Do NOT manage labels.
- Do NOT spawn further subagents for other angles.
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
Perform all phases (1 through 4) as the main orchestrator.

---

**OUTDIR handoff.** `$OUTDIR` defaults to a per-project `/tmp/pr-review-<hash>` (derived from the repo's git toplevel by `scripts/resolve-outdir.sh`) so concurrent reviews of different repos on one machine never share a tree. Resolve it ONCE in the orchestrator — `source "$WOO_REVIEW_ACTION_PATH/scripts/resolve-outdir.sh"` sets and exports `OUTDIR` — then export `OUTDIR` to **every** sub-agent you spawn. Sub-agents prefer the inherited `$OUTDIR`; if it is unset they re-derive via the same helper. Never fall back to a bare `/tmp/pr-review`.

## Phase 1 — Context + summary (single subagent; full mode only)

Spawn one subagent with this brief:

- Read `$OUTDIR/diff.txt`, `$OUTDIR/meta.json`, and `$OUTDIR/angles.txt`.
- Produce a 1–2 sentence summary, a bullet list of changes, files grouped by category, optional manual test plan. All destined for the **Review body** in Phase 4 — never written to PR title or description.
- Return: summary, bullets, files-by-category, test plan, enabled angles list.

Do NOT call `gh pr edit`. The PR title and description are immutable for this action.

## Phase 2 — Parallel angle audits (one subagent per enabled angle, × chunk if chunked)

Read `$OUTDIR/angles.txt`. Check `$OUTDIR/chunks.txt`:

- **Unchunked** (file absent): dispatch **one subagent per enabled angle in the same turn** so Antigravity orchestrates them in parallel. Each subagent gets its own isolated context window — the same tool-call shape as Claude Code's `Task` fan-out — so rely on the isolation for token economy.
- **Chunked** (file present, issue #14): dispatch **one subagent per `(angle, chunk_id)` pair**, again in the same turn. Pass the chunk id explicitly in the subagent brief and tell it to read `$OUTDIR/diff.chunk-<id>.txt` and write `$OUTDIR/findings.<angle>.chunk-<id>.json`.

Use **plain/general-purpose/default** Antigravity subagents for every angle worker. Do not spawn a
`woostack-review` skill-scoped worker and do not attach or resolve `@woostack-review`,
`skill://woostack-review`, or the orchestrator `SKILL.md` into the worker context; the brief below is
self-contained.

Each subagent receives this brief:

```
You are the <angle> reviewer for this PR. Read:
  - $WOO_REVIEW_ACTION_PATH/prompts/_worker-header.md   (worker contract)
  - $WOO_REVIEW_ACTION_PATH/prompts/angles/<angle>.md   (your scope)
  - $OUTDIR/diff.txt (or diff.chunk-<id>.txt when chunked)
  - $OUTDIR/meta.json

For `react` first run `npx -y react-doctor@$REACT_DOCTOR_VERSION --diff $BASE_REF --offline`.

Write findings as a JSON array to $OUTDIR/findings.<angle>.json
(or .<angle>.<chunk_id>.json when chunked) per the schema in _worker-header.md.
The file MUST start with `[` and end with `]` — no preamble, no commentary,
no markdown fences. Before writing each finding's `line` field, validate it
via `bash $WOO_REVIEW_ACTION_PATH/scripts/resolve-diff-line.sh --file <p>
--line <N>` and drop the finding when the helper prints `null`.

Write `[]` to your findings path FIRST so a crash leaves an empty array,
not a missing file. Replace with the final array before EXIT.

EXIT when done. Do NOT post comments, edit the PR, or touch other angles.
```

After every subagent has finished, run `bash $WOO_REVIEW_ACTION_PATH/scripts/merge-findings.sh` — it concatenates every `findings.<angle>*.json` into `raw_findings.json` and applies within-angle dedup so duplicates across chunks collapse before adjudication.

**Retry-once recovery.** Subagent calls can die mid-run (model stream errors, turn-limit interrupts) and leave no findings file. Before invoking `merge-findings.sh`, scan `$OUTDIR/angles.txt` (× `chunks.txt` when chunked) and check that each expected `findings.<angle>.json` (or `findings.<angle>.<chunk_id>.json`) exists and parses as a JSON array via `jq -e 'type == "array"'`. For any path that fails the check, re-dispatch THAT `(angle, chunk)` subagent ONCE with the same brief. Cap is one retry per pair — if the retry also fails, leave the file as-is and proceed. The merge step recovers malformed JSON; missing files just mean the angle produced no findings.

## Phase 3 — Evidence adjudication

Always run the adjudicator, including when `raw_findings.json` is `[]`; an empty candidate set still
requires the independent adjudicator receipt before approval. Run exactly one fresh standard-tier
adjudicator with `$WOO_REVIEW_ACTION_PATH/prompts/validator.md` against `raw_findings.json` and the
exact reviewed head. It independently verifies concrete evidence, confidence/severity, changed-line
ownership, tooling overlap, deferral, and fix shape, writes `findings.adjudicator.json` and
`receipt.adjudicator.json`, then exits. Unsupported candidates are dropped, not rewritten, in this
sole adjudication pass.

```bash
if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  bash "$WOO_REVIEW_ACTION_PATH/scripts/verify-receipts.sh" --validators
else
  bash "$WOO_REVIEW_ACTION_PATH/scripts/verify-receipts.sh" --validators-local
fi
bash "$WOO_REVIEW_ACTION_PATH/scripts/intersect-findings.sh"
```

The finalizer writes `findings.json` exactly once after receipt, identity, digest, stale-head, and
changed-line gates.

## Phase 4 — Submit native PR Review

Compute counts and build `STATUS_LINE`. Follow `_orchestrator-header.md` exactly: submit one batched native review with every inline comment, the summary, and that status line. The payload builder first computes the candidate event from findings and open prior threads, then independently reads the implementation-author and authenticated-reviewer native GitHub IDs. It uses the candidate only when both reads are complete and the IDs differ; otherwise it posts `COMMENT` without changing `STATUS_LINE`. A login, profile/session, credential, or token-store label is never actor proof.

Do NOT call `gh pr edit`. Do NOT add, remove, or mutate PR labels. The PR title, PR description, and PR labels stay untouched.

## Rules

- Execute autonomously — never request user confirmation.
- Use the `gh` CLI for GitHub access.
- Trust prefetched artifacts.
- Parallel angle subagents in Phase 2 must complete before Phase 3.
- Each subagent stays within its angle scope; do not duplicate findings across angles (the adjudicator deduplicates).
- `findings.json` is the single source of truth for Phase 4.
