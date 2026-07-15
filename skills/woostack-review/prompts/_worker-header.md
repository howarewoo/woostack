# Worker Review Contract

This contract is identical across every provider runner. The orchestration sections below the `---` are provider-specific.

## Output Discipline (READ FIRST)

> This section governs the **review JSON artifacts** below. For **prose handbacks** elsewhere in woostack (subagent reports, memory bodies), see the separate [internal-comms Output Discipline](../../using-woostack/references/output-discipline.md) — a different channel with different rules.

Every artifact you write under `$OUTDIR/findings.*.json` (default `/tmp/pr-review/findings.<angle>.json`) MUST be a valid JSON array — and **only** a JSON array.

- The file MUST start with `[` and end with `]`.
- No preamble, no commentary, no "I have completed the review…" sentence, no markdown fences (` ``` `), no trailing chatter.
- If you have nothing to report, write the literal `[]`.
- **Write `[]` to your findings file as the FIRST action.** Replace it with the real array just before EXIT. Sub-agents have died mid-run (stream errors, turn-limit interrupts) and left no file at all — the merge step then has no array to merge for that angle. An up-front empty array makes failure non-destructive: the worst case becomes "this angle reported nothing," not "this angle silently dropped out of the review."
- **Write your execution receipt as your LAST action.** After writing your real findings array, and just before EXIT, write `$OUTDIR/receipt.<angle>.json` (chunked runs: `$OUTDIR/receipt.<angle>.<chunk>.json`) — a JSON object that proves you actually ran: `{"angle":"<angle>","chunk":<chunk-id-or-null>,"runner":"<host or provider, e.g. claude-code>","model":"<your resolved model — the `Run model` line in the review context>","tier":"<fast|standard|deep — the `Force tier` line>","ts":"<ISO-8601 timestamp>"}`. `runner` and `model` MUST be non-empty. This receipt is how the orchestrator tells "ran and found nothing" (`[]` findings + receipt) apart from "never ran" (no receipt): a review where any angle has no valid receipt HARD-FAILS instead of silently reporting a clean pass. Do NOT pre-create the receipt — write it once, last, after the findings.
- If your runtime offers a "write file" tool, use it directly — do NOT echo the JSON through a chat channel that prepends prose.
- **Escape discipline inside string fields.** Every `"description"`, `"fix"`, and `"suggestion"` is a JSON string — inside it, the only valid backslash escapes are `\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`, and `\uXXXX`. Bare backslashes in code samples (Windows paths, regex like `\d`, LaTeX) MUST be doubled to `\\`. Tabs and newlines in code samples MUST be `\t` / `\n`, never raw control bytes. The merge step has a fallback sanitizer, but a finding that loses content during sanitization is one that fails to land cleanly on the PR.
- Before writing each finding's `line` field, validate it via:
  ```bash
  bash "$WOO_REVIEW_ACTION_PATH/scripts/resolve-diff-line.sh" \
    --file "<path>" --line "<N>"
  ```
  When the helper prints `null`, the line is not anchorable on the diff's RIGHT side and GitHub will reject the comment (HTTP 422). DROP the finding entirely rather than guessing a different line. The merge step also runs a final-pass safety net on this, but resolving up-front saves a round-trip and keeps the finding count honest.
- `$OUTDIR` defaults to a **per-project** path — `/tmp/pr-review-<hash>` derived from the repo's git toplevel (so concurrent reviews of different repos on one machine never share a tree). The orchestrator exports the resolved `OUTDIR` to you; **always prefer the exported `$OUTDIR` env var over any literal `/tmp/pr-review` path throughout this contract.** If `$OUTDIR` is somehow unset, re-derive it by sourcing `scripts/resolve-outdir.sh` — never fall back to a bare `/tmp/pr-review`.

## Prefetched Artifacts (do NOT re-fetch)

- **Diff**: `/tmp/pr-review/diff.txt` — may be a full PR diff OR an incremental `last_sha...HEAD` diff (see `last_sha.txt`).
- **PR metadata** (title, body, headRefOid, headRefName, baseRefName, files, author): `/tmp/pr-review/meta.json`
- **Enabled angles** (one per line): `/tmp/pr-review/angles.txt`
- **Project rules** (optional, present only if discovered): `/tmp/pr-review/rules.md`
- **Governing intent** (optional, present only when the PR resolves to a woostack spec+plan or fix): `/tmp/pr-review/intent.md` — each artifact is prefixed by `## SOURCE: <path>`. The `acceptance` worker verifies its criteria, checked steps, and code claims against the diff.
- **Per-repo config** (always present, defaults to `{"severity_floor":"high"}`): `/tmp/pr-review/config.json` — parsed from `.woostack/config.json` in the consumer repo.
- **Incremental base SHA** (always present, may be empty): `/tmp/pr-review/last_sha.txt` — non-empty means `diff.txt` covers only the new commits since the last woostack-review pass. Treat findings as scoped to those commits.
- **Prior unresolved review threads** (always present, may be `[]`): `/tmp/pr-review/prior-findings.json` — array of `{file, line, title, author}` for any unresolved thread on the PR. Consumed by the posting stage for the event-floor gate; angle workers MUST ignore this file. No per-entry `blocking` flag — any non-empty list floors the review event to `REQUEST_CHANGES` (conservative "do not APPROVE while threads open" rule).
- **Cross-PR memory** (optional, present when the consumer repo has `.woostack/memory/`): `/tmp/pr-review/memory.md` — a plain-markdown composition of gotchas and previously-accepted issues the team curates. When the repo has a `.woostack/memory/` scope-routed store, this file is composed per-PR: it contains the notes whose `scope` matches the PR's changed files, any one-hop `[[linked]]` notes, plus global-scoped notes. Treat it as additional rubric: do NOT re-flag an issue the memory file already records as known/accepted. See *Cross-PR memory* below.
- **Wisdom guidance** (optional, present when the consumer repo has a non-empty `.woostack/wisdom/`): `/tmp/pr-review/wisdom.md` — every wisdom file body, loaded **wholesale** (generalized, cross-cutting house-rules the team distilled via `woostack-dream`). Each section is prefixed `## SOURCE: <file>.md`. Treat it as an additional rubric: do NOT re-flag an issue wisdom already records as a known/accepted convention. Advisory context, not a `rule_quote` source.
- **Chunk manifest** (optional, present only when the diff exceeds `chunking.max_loc`): `/tmp/pr-review/chunks.txt` (one chunk id per line) and `/tmp/pr-review/chunks.json` (manifest: `[{id, files, loc, diff_path, boundary}]`). Each chunk also has its own diff at `/tmp/pr-review/diff.chunk-<id>.txt`. When a worker is dispatched with a chunk id (env `CHUNK` non-empty), it MUST read the chunk-specific diff and write findings to `/tmp/pr-review/findings.<angle>.<chunk>.json`. In the GitHub Action this swap happens transparently — `diff.txt` is replaced with the chunk's diff before the worker runs, and the worker's output is renamed afterwards. When `chunks.txt` is absent, chunking did not activate and the diff fits a single worker (no overhead).

If `/tmp/pr-review/rules.md` exists, treat it as an additional rubric on top of the per-angle scope. Each section is prefixed by a `## SOURCE: <path>` header identifying its origin file (`AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.windsurfrules`, or `GEMINI.md`). Any finding that claims a project-rule violation MUST populate `rule_quote` with a verbatim substring of `rules.md` (the rule text itself, not the source header). The validator discards rule-cited findings whose `rule_quote` is missing or not literally present in `rules.md`.

`woostack-defer(<ref>): <reason>` is an **intentional deferral signal** (issue #224), not a stray `TODO`. Do NOT raise a finding to flag or remove it. Only the defender validator acts on it — it demotes the *separate* missing/not-yet-wired finding the marker covers (see `validator.md`). Treat the marker line itself as inert.

If `/tmp/pr-review/memory.md` exists, read it before reporting. It is the team's cross-PR memory — gotchas, intentional design choices, and issues a prior review already surfaced and the team consciously accepted. If a finding you would report is already described there as known/accepted/wontfix, DROP it. Memory is advisory context, not a rule source: do not cite it in `rule_quote`.

If `/tmp/pr-review/wisdom.md` exists, read it before reporting. It is the team's generalized,
cross-cutting wisdom (loaded wholesale, not scope-routed). If a finding you would report is already
described there as a known/accepted convention, DROP it. Like memory, wisdom is advisory context —
do not cite it in `rule_quote`.


## Findings Schema (`/tmp/pr-review/findings.json`)

Every runner MUST write a final `findings.json` (for debugging + potential post-processing parity). Each per-angle step writes to `/tmp/pr-review/findings.<angle>.json`; the orchestrator merges them after validation:

```json
[
  {
    "angle": "bugs",
    "file": "src/foo.ts",
    "line": 42,
    "severity": "HIGH",
    "blocking": true,
    "nit": false,
    "title": "Short bold headline (≤60 chars, no trailing punctuation)",
    "description": "Issue description: what is wrong and why it matters. Do NOT include the fix here.",
    "fix_type": "suggestion",
    "fix": "Recommended change in prose (e.g. 'use `<=` instead of `<` so the boundary value is included').",
    "suggestion": "verbatim replacement code for the GitHub ```suggestion``` block — REQUIRED when fix_type == \"suggestion\", MUST be null when fix_type == \"prose\"",
    "rule_quote": "exact quoted rule text if rule-based, else null",
    "deferred_to": "the <ref> of a woostack-defer marker (e.g. \"increment 3\") this finding is deferred to, set by the defender when a marker covers the missing work; else null"
  }
]
```

`angle` is one of `bugs | security | conventions | acceptance | seo | aeo | design | react | database | tests | api | infra | observability | types | i18n | docs | deps | architecture | comments | simplify | production-readiness`.

`line` MUST be the post-patch absolute file line — i.e. a line that exists on the RIGHT side of the diff (a `+` added line or a ` ` context line within a hunk for `file`). Lines that fall in a deletion-only region, or outside any hunk for the file, will be rejected by the GitHub API. Validate every line via `scripts/resolve-diff-line.sh` before writing the finding (see *Output Discipline* above); drop the finding when the helper returns `null`.

### `fix_type` discriminator

Every finding MUST set `fix_type` to exactly one of:

- `"suggestion"` — a one-click GitHub ```suggestion``` block is safe. Requires `suggestion` to be populated with self-contained replacement code that is ALL of:
  - ≤10 lines,
  - scoped to the single file at `file`,
  - a complete drop-in replacement for the existing line(s) at `line` (no `...` placeholders, no partial diffs),
  - self-contained (does not reference symbols, imports, or context the diff does not already establish).
- `"prose"` — the change is too large, multi-file, structural, or context-dependent for a one-click block. `suggestion` MUST be `null`; the human-readable `fix` field carries the recommendation.

The validator enforces these rules and will downgrade a violating `fix_type: suggestion` to `fix_type: prose` (clearing `suggestion`) rather than emitting a broken block. When in doubt, prefer `prose` — a usable prose recommendation beats a broken one-click suggestion that loses author trust.

### Inline Comment Format (rendered on the PR)

Every inline comment posted to GitHub MUST follow this four-part structure, assembled from the schema fields above:

```
**<title>**

<description>

Fix: <fix>

<sub>— <strong><severity> · BLOCKING</strong> · flagged by the <code><angle></code> agent</sub>
```

- **Title** — bold one-liner, ≤60 characters, no trailing punctuation. Names the problem.
- **Description** — the issue itself: what is broken, why it matters, with diff-anchored evidence. Do NOT prescribe the fix here.
- **Fix** — recommended change, prefixed literally with `Fix: `. Required for every finding. The body builder appends a GitHub ```suggestion``` block after the `Fix:` line if and only if `fix_type == "suggestion"` AND `suggestion` is a non-empty string; `fix_type == "prose"` renders the recommendation in prose only.
- **Attribution footer** — small-print line carrying the finding's `severity` (HIGH / MEDIUM / LOW; suffixed with `· BLOCKING` when `blocking == true`, or `· NIT` when `nit == true`) and the angle agent that flagged it (e.g. `<sub>— <strong>HIGH · BLOCKING</strong> · flagged by the <code>bugs</code> agent</sub>`, or `<sub>— <strong>LOW · NIT</strong> · flagged by the <code>bugs</code> agent</sub>`). The body builder appends this automatically from the finding's `severity` / `blocking` / `nit` / `angle` fields. Both `severity` and `angle` are whitelisted against their known sets; unknown/missing values are dropped from the footer rather than injecting raw text. If both are missing, the footer is omitted entirely.

`nit` is a boolean set by `intersect-findings.sh` (the floor classifier), **not** by angle agents: `true` marks a validated below-floor non-blocking finding. The body builder renders a `nit: true` finding with a `Nit:` title prefix and a `· NIT` footer tag, and the event computation treats it as event-neutral (a PR whose only findings are nits still `APPROVE`s, with the nits posted inline). A nit is always non-blocking; a below-floor finding that is `blocking: true` stays a normal finding (`nit: false`).

`deferred_to` is a string (the marker `<ref>`, e.g. `"increment 3"`) or null, set by the defender validator (`validator.md`) when an inline `woostack-defer(<ref>)` marker in the diff covers the gap a finding flags as missing. `intersect-findings.sh` forces any finding carrying a non-empty `deferred_to` to `nit: true, blocking: false` (independent of `severity_floor`, gated by `review.defer_markers`), and the body builder appends a `Deferred to <ref>` line. Never set on `security` findings or on wrong code present in this PR.

The body builder in the posting step (see python snippet above) renders this format automatically from `title` / `description` / `fix` / `fix_type` / `suggestion` / `angle` / `severity` / `blocking` / `nit`. Angle agents and the validator MUST populate `title`, `description`, `fix`, `fix_type`, `angle`, `severity`, and `blocking` for every finding; `nit` is added downstream by the classifier.

## Blocking Criteria

A finding is `blocking: true` only when ALL hold:
- Real, in-diff, produced by this PR (not pre-existing).
- One of:
  - Code that will fail to compile/parse.
  - Code that will definitely produce wrong results regardless of inputs.
  - Clear, unambiguous rule violation with exact quoted rule text.
  - Security vulnerability with concrete exploit path.

Otherwise `blocking: false`:
- Style/quality concerns worth surfacing (but not lint-catchable).
- Performance smells (obvious N+1, unnecessary re-render).
- Missing tests on new business logic.
- Defensive coding improvements.
- Defensible subjective suggestions.

## Do NOT Flag

- Lint-catchable issues handled by Biome / ESLint / tsc / similar.
- Input-dependent maybe-issues with no concrete failure case.
- Pedantic nitpicks (whitespace, naming taste without rule backing).
- Pre-existing issues not introduced by this PR.
- Generic security concerns without concrete exploit path in this PR.

---

