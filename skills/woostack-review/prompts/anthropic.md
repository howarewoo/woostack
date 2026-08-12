# Anthropic (Claude Code) — Multi-Angle Orchestration

You are reviewing a pull request using Claude Code's `Task` tool. Every tool call must serve a clear purpose. Create a todo list before starting.

The shared header above lists prefetched artifacts, the findings schema, the blocking criteria, and the do-NOT-flag list. **Apply them verbatim.** Per-angle prompt bodies live at `$WOO_REVIEW_ACTION_PATH/prompts/angles/<angle>.md`.

**Host identifier:** default `claude-code` (substitute into the credits line `<host>` placeholder per `_orchestrator-header.md`). If this orchestrator was selected from a different Anthropic host (e.g. Cursor, Zed), use that host's canonical slug instead.

---

## IMPORTANT: MODE-BASED EXECUTION

Check the `Execution mode` in the Review Context above.

### MODE: review
You are running as a parallel worker for a specific angle.
- The `Target angle` in Review Context is the only angle you must audit.
- Do NOT post inline comments.
- Do NOT update the PR body or title.
- Do NOT manage labels.
- Do NOT launch subagents for other angles.
- Run ONLY the logic for your target angle (loading its prompt from `$WOO_REVIEW_ACTION_PATH/prompts/angles/<angle>.md`).
- Write your findings to `$OUTDIR/findings.<angle>.json` (default `$OUTDIR/findings.<angle>.json`) and then EXIT.
- The findings file MUST be a JSON array only — starts with `[`, ends with `]`, no preamble, no markdown fences, no commentary. See *Output Discipline* in `_worker-header.md`. Validate every `line` via `scripts/resolve-diff-line.sh` and drop findings the helper rejects.

### MODE: validate
You are running as the final controller.
- Read all `$OUTDIR/findings.<angle>.json` files from disk.
- Perform evidence adjudication (Step 3 below).
- Perform final delivery (Step 4 below): submit one batched native PR Review. The review `event` (APPROVE / COMMENT / REQUEST_CHANGES) is the blocking gate.
- Do NOT modify the PR title, PR description, or PR labels.
- Exit.

### MODE: full (or detect)
Perform all steps (1 through 4) as the main orchestrator.

---

## Model routing (token optimization)

Claude Code's `Task` tool supports per-subagent model routing. Resolve each spawned subagent model from:
1. `FORCE_TIER` in Review Context (`fast`/`deep`) when present.
2. Otherwise the angle prompt `tier:` frontmatter.
3. Then per-repo overrides and table defaults in `_orchestrator-header.md`.

Then resolve via the shared **Model Tiers** table — canonical at
[`../../using-woostack/references/model-tiers.md`](../../using-woostack/references/model-tiers.md)
and inlined into `_orchestrator-header.md` above. The Anthropic column routes **every** tier to
`claude-opus-4-8`; the tier is expressed through reasoning **effort** instead
(`fast` → `effort: low`, `standard` → `effort: medium`, `deep` → `effort: xhigh`).

**Every Task/Agent spawn MUST pass `model:` explicitly** (always `claude-opus-4-8`), and MUST pass the tier's **`effort`** when the Task API accepts a reasoning-effort override. With Opus on every tier, the model is a no-op and **`effort` is the only tier differentiator** — omitting it runs rubric/`fast` angles at full effort and burns ~Nx the tokens. The `tier:` frontmatter is informational unless the spawning call passes both the resolved slug and the resolved effort.

Spawn review workers as **plain/general-purpose/default** subagents only. Do not use a
`woostack-review` skill-scoped agent, `@woostack-review`, `skill://woostack-review`, or the
orchestrator `SKILL.md` as worker context; the worker brief plus `_worker-header.md`, the angle
prompt, and `$OUTDIR` artifacts are the complete worker contract.

Concrete invocation (Claude Code `Task` / `Agent` tool):

```
Task({
  subagent_type: "general-purpose",
  model: "claude-opus-4-8",     // every tier → opus (model routing is a no-op)
  effort: "medium",             // tier expressed via effort (standard → medium); pass ONLY if the Task API accepts a reasoning-effort override
  description: "bugs angle audit",
  prompt: "<angle prompt body + Review Context>"
})
```

Resolution rule per spawn:
1. Determine effective tier.
2. Look up the Anthropic column in the shared Model Tiers table (inlined in `_orchestrator-header.md` above) — every tier resolves to `claude-opus-4-8`, with a per-tier default `effort` (`fast` → `low`, `standard` → `medium`, `deep` → `xhigh`).
3. **Per-repo override**: check `$OUTDIR/config.json` for `models.anthropic.<effective_tier>`, then flat `models.<effective_tier>`. The loader normalizes a scalar tier leaf to `{model, effort?}` and preserves a fallback leaf as an ordered array of those objects; select entry 0 before reading `.model` (e.g. when `run_tier=deep`: `jq -r '((.models.anthropic.deep // .models.deep) | if type=="array" then .[0] else . end | if type=="object" then .model else . end) // empty' $OUTDIR/config.json`). If non-empty, use that slug instead of the table value.
4. Resolve **effort** from that same primary entry, provider-scoped then flat (e.g. `jq -r '((.models.anthropic.deep // .models.deep) | if type=="array" then .[0] else . end | if type=="object" then .effort else empty end) // empty' $OUTDIR/config.json`); fall back to the tier default from step 2 when unset.
5. Pass the resolved slug as `model:` on the Task call, and the resolved effort as `effort:` **when the Task API accepts a reasoning-effort override** (if it accepts only `model`, still pass `model`; never fall back to parent-session inheritance).

The sole adjudicator is `standard` tier — pass `model: "claude-opus-4-8"` with `effort: "medium"` explicitly when the Task API accepts effort.

**OUTDIR handoff.** `$OUTDIR` defaults to a per-project `/tmp/pr-review-<hash>` (derived from the repo's git toplevel by `scripts/resolve-outdir.sh`) so concurrent reviews of different repos on one machine never share a tree. Resolve it ONCE in the orchestrator — `source "$WOO_REVIEW_ACTION_PATH/scripts/resolve-outdir.sh"` sets and exports `OUTDIR` — then export `OUTDIR` to **every** sub-agent you spawn. Sub-agents prefer the inherited `$OUTDIR`; if it is unset they re-derive via the same helper. Never fall back to a bare `/tmp/pr-review`.

## Step 1 — Context + Summary (single `fast`-tier subagent; full mode only)

Launch one `claude-opus-4-8` subagent at `fast`-tier effort (`effort: low`, when the Task API accepts it). Task:

- Read `$OUTDIR/diff.txt`, `$OUTDIR/meta.json`, and `$OUTDIR/angles.txt`.
- Produce a 1–2 sentence summary, a bullet list of changes, and files grouped by category. These feed the **Review body** in Step 4 only — they are never written to the PR title or PR description.
- If the diff has functional changes (business logic, UI, API, data mutations), produce a manual test plan as a Markdown checklist for inclusion in the Review body.
- Return: summary, bullets, files-by-category, test plan, **enabled angles list**.

Do NOT call `gh pr edit`. The PR title and description are immutable for this action.

## Step 2 — Parallel Angle Audits (one subagent per enabled angle, × chunk if chunked)

Read `$OUTDIR/angles.txt`. Check `$OUTDIR/chunks.txt`:

- **Unchunked** (file absent): launch **one subagent per enabled angle in the same response** to maximize parallelism.
- **Chunked** (file present, issue #14): launch **one subagent per `(angle, chunk_id)` pair**, again in the same response. Pass the chunk id explicitly in the subagent prompt and instruct it to read `$OUTDIR/diff.chunk-<id>.txt` and write `$OUTDIR/findings.<angle>.chunk-<id>.json`.

Each subagent:

- Loads its angle prompt: `$WOO_REVIEW_ACTION_PATH/prompts/angles/<angle>.md`.
- Runs on `claude-opus-4-8` (every tier → opus). The angle's `tier:` frontmatter now selects **effort**, not model: `standard` → `effort: medium` (`bugs`/`security`/`acceptance`/`architecture`/`design`/`react`/`database`/`tests`/`api`/`infra`/`observability`/`types`/`simplify`/`production-readiness`), `fast` → `effort: low` (`seo`/`aeo`/`i18n`/`docs`/`deps`/`comments`). The spawning Task call MUST pass `model:` explicitly, plus `effort:` when the Task API accepts it — see Model Routing section above.
- Reads its assigned diff (`$OUTDIR/diff.txt` for the unchunked case, `$OUTDIR/diff.chunk-<id>.txt` for chunked).
- For `react`: runs `npx -y react-doctor@$REACT_DOCTOR_VERSION --diff $BASE_REF --offline`, parses output, then performs LLM review per the react prompt.
- Returns its findings list AND writes them to `$OUTDIR/findings.<angle>.json` (unchunked) or `$OUTDIR/findings.<angle>.<chunk_id>.json` (chunked).

If the Task tool caps practical parallelism below the angle count, spawn in waves of ≤4 subagents. Do not skip any enabled angle.

**Retry-once recovery.** Sub-agents can die mid-run (model stream errors, turn-limit interrupts) and leave no findings file. After the swarm reports done, before invoking `merge-findings.sh`, scan `$OUTDIR/angles.txt` and check each angle's expected output:

- Unchunked: `$OUTDIR/findings.<angle>.json`
- Chunked: every `$OUTDIR/findings.<angle>.<chunk_id>.json` for each chunk id in `chunks.txt`

For any path that (a) does not exist, OR (b) does not parse as a JSON array (`jq -e 'type == "array"'` returns non-zero), re-launch THAT subagent ONCE with an identical brief and `model:` slug. Cap is one retry total per `(angle, chunk)` pair — if the retry also fails, leave the file missing/malformed and proceed to merge. The merge step's recovery handles malformed files; missing files simply count as "this angle produced no findings."

After recovery, run `bash $WOO_REVIEW_ACTION_PATH/scripts/merge-findings.sh` — it concatenates every `findings.<angle>*.json` into `raw_findings.json` and applies within-angle dedup so duplicates across chunks collapse before adjudication.

## Step 3 — Evidence adjudication

Always run the adjudicator, including when `raw_findings.json` is `[]`; an empty candidate set still
requires the independent adjudicator receipt before approval. Spawn exactly one fresh standard-tier
subagent with `$WOO_REVIEW_ACTION_PATH/prompts/validator.md`. It independently adjudicates evidence,
concrete failure, confidence/severity, changed-line ownership, tool overlap, defer semantics, and
fix shape. It writes `$OUTDIR/findings.adjudicator.json` and its receipt, then exits. Unsupported
candidates are dropped, not rewritten, in this sole adjudication pass.

The controller writes the post-exit binding manifest, verifies it, and finalizes:
```bash
if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  bash "$WOO_REVIEW_ACTION_PATH/scripts/verify-receipts.sh" --validators
else
  bash "$WOO_REVIEW_ACTION_PATH/scripts/verify-receipts.sh" --validators-local
fi
bash "$WOO_REVIEW_ACTION_PATH/scripts/intersect-findings.sh"
```

This produces `$OUTDIR/findings.json` once from the adjudicator output; deterministic severity,
defer, ownership, changed-line, stale-head, identity, and digest gates remain mandatory.

## Step 4 — Submit Native PR Review

Follow `_orchestrator-header.md` exactly. Compute `BLOCKING_COUNT`, `NONBLOCKING_COUNT`, `NIT_COUNT`, `HIGH_COUNT`, `MEDIUM_COUNT`, `LOW_COUNT`. Build `STATUS_LINE`. Submit one batched native review with every inline comment, the summary, and that status line. The payload builder first computes the candidate event from findings and open prior threads, then independently reads the implementation-author and authenticated-reviewer native GitHub IDs. It uses the candidate only when both reads are complete and the IDs differ; otherwise it posts `COMMENT` without changing `STATUS_LINE`. A login, profile/session, credential, or token-store label is never actor proof.

Do NOT call `gh pr edit`. Do NOT add, remove, or mutate PR labels. The PR title, PR description, and PR labels must remain untouched.

## Rules

- Execute every step autonomously — no confirmation prompts.
- Trust prefetched artifacts. Do NOT re-run `gh pr diff`.
- Parallel angle subagents in Step 2 must complete before Step 3.
- Each subagent stays within its angle scope; do not duplicate findings across angles (the adjudicator deduplicates).
- `findings.json` is the single source of truth for Step 4.
