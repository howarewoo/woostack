---
type: plan
source: .woostack/specs/2026-06-25-woostack-audit.md
status: done
branch: feature/woostack-audit
---

**Source:** [[specs/2026-06-25-woostack-audit]]

# woostack-audit — Standing-code multi-angle audit — Implementation Plan

**Goal:** Ship `woostack-audit`, a public skill that audits an explicit standing-code target by
synthesizing an all-added diff and driving `woostack-review`'s existing swarm + adversarial
validators, rendering a report-only findings doc — plus two new shared angles (`simplify`,
`production-readiness`) that are also active on review diffs.

**Architecture:** Seven linearly-stacked increments on the spec+plan base PR (#421). Increments
1–2 add and wire the two new shared angles into `woostack-review` (lockstep). Increments 3–6 build
the audit front-end (config loader, synthetic-diff builder, report renderer, the orchestration
`SKILL.md`) that reuses review's scripts via `WOO_REVIEW_ACTION_PATH`. Increment 7 (stacked
follow-up) does the 19th-public-skill command-surface bookkeeping. Audit reuses
`run-bounded-swarm.sh`, `verify-receipts.sh`, `merge-findings.sh`, the two validators,
`intersect-findings.sh`, `chunk-diff.sh`, `resolve-model.sh`, `resolve-outdir.sh`, `recall.sh`,
and the `_header.md` schema **unchanged**.

**Tech Stack:** Bash (`set -euo pipefail`, ERE `grep`), `jq`, `git diff --no-index`, the
`skills/woostack-init/scripts/tests/assert.sh` test helper, Markdown angle prompts + SKILL.

**Lockstep note (wisdom: [[lockstep-edit-sites]], [[review-add-angle-sites]]):** each new angle
moves the same ~11 sites together — `load-config.sh` `VALID_ANGLES`, `detect-angles.sh`
(gate + doc catalog), `_header.md` (count word + catalog table row + the two footer/schema
whitelists), the review `SKILL.md` angle table, the per-provider tier tables
(`anthropic.md`/`openai.md`/`google.md`/`opencode.md`), and a committed gating test. Increment 2
moves all of them for both angles at once. **Autonomy proof (wisdom:
[[autonomy-needs-structural-proof]]):** every increment pins its behavior with a committed
structural test (grep/`bash -n`/`jq`/`python3 -c`), never bare prose.

---

## Increment 1: New shared angle prompts (`simplify`, `production-readiness`)

> One independently shippable PR — two new prompt files only, not yet wired. A
> `woostack-defer(increment 2)` marker declares the wiring gap so reviewing this PR in isolation
> doesn't flag the unregistered angles. Base of the stack (stacks on #421).

### Task 1: Author `simplify.md`

**Files:**
- Create: `skills/woostack-review/prompts/angles/simplify.md`

- [x] **Step 1: Write the prompt file**
  ```markdown
  ---
  tier: standard
  ---

  <!-- woostack-defer(increment 2): registered in VALID_ANGLES + detect-angles + _header in increment 2 -->

  # Angle: Simplify

  **Scope.** Find code that should be **smaller or not exist at all**. Read `$OUTDIR/diff.txt`
  and the files in `$OUTDIR/meta.json`. Apply the ladder, stopping at the first rung that
  removes code: **(1)** does this need to exist (YAGNI)? **(2)** is it already in this codebase
  (reuse)? **(3)** does the stdlib do it? **(4)** does a native platform feature do it? **(5)**
  does an installed dependency do it? **(6)** can it be one line? **(7)** otherwise the minimum
  that works. Your output is a **delete-list**: each finding names code to remove or shrink and
  the smaller shape that replaces it.

  **Find:**

  - **Does-not-need-to-exist.** Speculative generality, unused options/flags, abstractions with
    one caller, config no path reads — code added for a future that is not here.
  - **Dead code / unused exports.** A symbol, file, or branch nothing reaches. For a suspected
    unused **export**, verify across the tree before flagging: run
    `rg -n --no-heading "\b<symbol>\b" -g '!<defining-file>'` (fall back to
    `git grep -n "\b<symbol>\b" -- ':!<defining-file>'`, else `grep -rn`). Flag **only** when the
    scan returns zero non-definition references. Quote the scan in `description`.
  - **Whole-tree duplication.** The same logic copy-pasted across files where one shared helper
    (or an existing canonical utility the repo already exports) would replace both.
  - **Thin / identity abstraction.** A wrapper, indirection, or generic that adds a hop without
    buying clarity — the code is simpler with it inlined.
  - **One-liner opportunities.** A hand-rolled loop/reducer a single stdlib/native call replaces.

  **Scope-split with `architecture`** (precedent: `types.md` defers to `react`). When the
  `architecture` angle is ALSO enabled (a `woostack-review` diff includes it in
  `$OUTDIR/angles.txt`), **defer within-change structural-shape** findings (nesting, layering,
  spaghetti, naming) to it and own only **existence/YAGNI, cross-file dead code, and
  duplication**. When `architecture` is NOT enabled (an audit run), own the full simplification
  surface including structural-shape.

  **Skip — "lazy, not negligent":**

  - **Never** recommend removing validation, error handling, security checks, or accessibility
    affordances. These are not over-engineering even when they look like extra code.
  - Anything a linter/formatter mechanically fixes.
  - Pure taste with no concrete smaller shape — if you cannot name what replaces it, do not flag.
  - A symbol whose reference scan you could not run to zero — do not assert "unused" from
    reading one file.

  **Severity rubric:**

  - `HIGH` + `blocking: true` — a whole module/file/dependency that can be deleted (nothing
    reaches it), or a large duplication a single shared helper removes. Rare.
  - `MEDIUM` + `blocking: false` — a real missed-deletion / duplication / thin-abstraction with a
    named smaller shape; the existing form still works. Default.
  - `LOW` + `blocking: false` — a one-liner or minor inlining opportunity.

  **Grounding requirement.** Every `description` MUST name (a) the specific code to remove/shrink
  and (b) the concrete smaller shape (and, for an unused-export claim, the zero-result scan). A
  finding that only says "could be simpler" is dropped by the validator.

  **Output.** Write findings as a JSON array to `$OUTDIR/findings.simplify.json` per the schema in
  `_header.md`. Each finding gets `"angle": "simplify"` and MUST populate `title` (≤60 chars),
  `description` (what to delete + the smaller shape, no fix steps), `fix` (the deletion/replacement
  in prose), and `fix_type`. Set `fix_type: "suggestion"` only for a ≤10-line single-file drop-in
  deletion/replacement at `line`; otherwise `fix_type: "prose"` with `suggestion: null`.
  ```

- [x] **Step 2: Confirm structural shape (verification)**
  Run: `bash -n /dev/stdin < /dev/null; grep -c '^tier: standard' skills/woostack-review/prompts/angles/simplify.md && grep -c 'findings.simplify.json' skills/woostack-review/prompts/angles/simplify.md`
  Expected: prints `1` then `1` (frontmatter tier present; output path correct).

- [x] **Step 3: Confirm deferral marker present**
  Run: `grep -c 'woostack-defer(increment 2)' skills/woostack-review/prompts/angles/simplify.md`
  Expected: `1`

### Task 2: Author `production-readiness.md`

**Files:**
- Create: `skills/woostack-review/prompts/angles/production-readiness.md`

- [x] **Step 1: Write the prompt file**
  ```markdown
  ---
  tier: standard
  ---

  <!-- woostack-defer(increment 2): registered in VALID_ANGLES + detect-angles + _header in increment 2 -->

  # Angle: Production readiness

  **Scope.** Audit the **resilience and operability** of the code in `$OUTDIR/diff.txt` (files in
  `$OUTDIR/meta.json`): will it survive partial failure, load, and operation in production? You
  own the failure-under-stress posture that no other angle covers.

  **Find:**

  - **No timeout / no deadline** on an outbound call (HTTP, DB, queue, RPC) that can hang.
  - **No retry / no backoff** on a transient-failure-prone call, OR retry without a cap / jitter
    (retry storm risk).
  - **Non-idempotent mutation** on a retried or at-least-once path (double-charge, double-write)
    with no idempotency key / dedup.
  - **No graceful degradation** — a non-critical dependency failure takes down the whole request
    instead of degrading; no fallback / circuit-breaker where one is warranted.
  - **Unbounded resource / concurrency** — unbounded queue, unbounded `Promise.all` fan-out over
    user-sized input, no connection-pool cap, no pagination on a list that grows.
  - **Config & secret hygiene** — required config read with no presence check / no fail-fast at
    boot; a secret read from source instead of env/secret-store (defer the *hardcoded-secret
    finding itself* to `security`; you own the **missing fail-fast / missing validation** around
    config).
  - **Missing health / readiness** — a new long-lived service/worker with no health or readiness
    signal, or shutdown that drops in-flight work (no graceful drain).
  - **Failure isolation** — one tenant/request able to exhaust a shared resource for all.

  **Scope-split (no double-report):**

  - **Signal quality** — whether a failure is *logged*, log levels, PII in logs, swallowed
    errors → `observability` owns it. You own whether the code *recovers*, not whether it *logs*.
  - **Threats** — injection, authz, secret exposure → `security` owns it.
  - **Correctness** — wrong result for valid input → `bugs` owns it.

  **Skip:**

  - Code with no I/O, no external calls, no shared resource, no long-lived process — it has no
    production-readiness surface; write `[]`.
  - Speculative "might not scale" with no concrete failure mode in the code as written.
  - Style / naming.

  **Severity rubric:**

  - `HIGH` + `blocking: true` — a concrete production-down failure mode: a retried non-idempotent
    payment, an unbounded fan-out over user input, a hang with no timeout on a request path.
  - `MEDIUM` + `blocking: false` — a real resilience gap that bites under failure/load but not on
    the happy path (missing backoff, no degradation).
  - `LOW` + `blocking: false` — a hardening nicety (add a deadline to a fast internal call).

  **Grounding requirement.** Every `description` MUST name the concrete failure mode (what
  happens when the call hangs / the retry fires / the input is large) — not a generic "add a
  timeout". A finding without a named failure mode is dropped by the validator.

  **Output.** Write findings as a JSON array to `$OUTDIR/findings.production-readiness.json` per
  the schema in `_header.md`. Each finding gets `"angle": "production-readiness"` and MUST
  populate `title` (≤60 chars), `description` (the failure mode, no fix), `fix` (the resilience
  change in prose), and `fix_type`. `fix_type: "suggestion"` only for a ≤10-line single-file
  drop-in at `line`; otherwise `fix_type: "prose"` with `suggestion: null`.
  ```

- [x] **Step 2: Confirm structural shape (verification)**
  Run: `grep -c '^tier: standard' skills/woostack-review/prompts/angles/production-readiness.md && grep -c 'findings.production-readiness.json' skills/woostack-review/prompts/angles/production-readiness.md`
  Expected: prints `1` then `1`.

- [x] **Step 3: Commit the increment**
  ```bash
  gt create -m "feat(review): add simplify + production-readiness angle prompts (unwired)"
  ```

---

## Increment 2: Wire both angles into review's catalog (lockstep) + review-conditional gate

> One PR — the lockstep wiring that registers both angles, gates them on the general-source
> signal (so they fire on review diffs like `architecture`/`comments`), and removes the
> increment-1 deferral markers. Pinned by a committed gating test.

### Task 1: Register both angles in `VALID_ANGLES`

**Files:**
- Modify: `skills/woostack-review/scripts/load-config.sh:92`

- [x] **Step 1: Add both angles to the set**
  Edit line 92 — append `, "simplify", "production-readiness"` inside the `VALID_ANGLES` set so it reads:
  ```python
  VALID_ANGLES = {"bugs", "security", "conventions", "seo", "aeo", "design", "react", "database", "tests", "api", "infra", "observability", "types", "i18n", "docs", "deps", "architecture", "skills", "comments", "simplify", "production-readiness"}
  ```

- [x] **Step 2: Verify both angles are in the validated set (structural)**
  Run:
  ```bash
  python3 -c "import re; s=open('skills/woostack-review/scripts/load-config.sh').read(); \
  m=re.search(r'VALID_ANGLES = \{([^}]*)\}', s).group(1); \
  print('ok' if '\"simplify\"' in m and '\"production-readiness\"' in m else 'MISSING')"
  ```
  Expected: `ok` (both names are members of `VALID_ANGLES`, so `force`/`skip` of them is accepted and not rejected as `bad_angles`).

### Task 2: Gate both angles on the general-source signal + update the doc catalog

**Files:**
- Modify: `skills/woostack-review/scripts/detect-angles.sh` (general-source block near `:326`, doc catalog near `:68`)

- [x] **Step 1: Push both angles where `architecture`/`comments` are pushed**
  After the existing `ANGLES+=("architecture")` / `ANGLES+=("comments")` lines (inside the
  general-purpose-source `if`), add:
  ```bash
  ANGLES+=("simplify")
  ANGLES+=("production-readiness")
  ```

- [x] **Step 2: Extend the top-of-file doc catalog**
  In the angle-gating comment block, add two lines mirroring the `architecture`/`comments` entries:
  ```bash
  #   simplify  — general-purpose source files in the diff (same signal as architecture).
  #               YAGNI / dead-code / duplication delete-list. Defers structural-shape to
  #               architecture when both are enabled.
  #   production-readiness — general-purpose source files in the diff. Resilience/operability
  #               posture (timeouts, retries, idempotency, degradation, resource limits).
  ```

- [x] **Step 3: Write the gating test (red→green)**
  Create `skills/woostack-review/scripts/tests/test-detect-angles-audit-angles.sh`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  ROOT="$(cd "$DIR/../../.." && pwd)"
  source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
  SCRIPT="$DIR/detect-angles.sh"
  setup() { work="$(mktemp -d)"; export OUTDIR="$work/out"; mkdir -p "$OUTDIR"; \
    printf '%s\n' "$1" | jq -R . | jq -s '{files: [.[] | {path: .}]}' > "$OUTDIR/meta.json"; : > "$OUTDIR/diff.txt"; }

  # Source file enables both new angles (same gate as architecture).
  setup "src/index.ts"; bash "$SCRIPT" >/dev/null 2>&1
  assert_contains "$(cat "$OUTDIR/angles.txt")" "simplify" "source enables simplify"
  assert_contains "$(cat "$OUTDIR/angles.txt")" "production-readiness" "source enables production-readiness"
  rm -rf "$work"

  # Docs-only PR enables neither.
  setup "README.md"; bash "$SCRIPT" >/dev/null 2>&1
  assert_eq "$(grep -cx 'simplify' "$OUTDIR/angles.txt" || true)" "0" "docs-only: no simplify"
  assert_eq "$(grep -cx 'production-readiness' "$OUTDIR/angles.txt" || true)" "0" "docs-only: no production-readiness"
  rm -rf "$work"
  finish
  ```

- [x] **Step 4: Run the gating test, confirm pass**
  Run: `bash skills/woostack-review/scripts/tests/test-detect-angles-audit-angles.sh`
  Expected: `4 passed, 0 failed`

### Task 3: Update `_header.md` count, catalog table, and whitelists

**Files:**
- Modify: `skills/woostack-review/prompts/_header.md` (count `:100`, table `:120`, footer whitelist `:295`, schema list `:429`)

- [x] **Step 1: Bump the angle count word**
  Line ~100: change "runs up to **nineteen** distinct review angles" → "**twenty-one**".

- [x] **Step 2: Add two catalog table rows**
  After the `comments` row (~`:122`), add:
  ```markdown
  | `simplify` | no | LLM only — gated on general-purpose source files in diff (same signal as `architecture`); YAGNI / dead-code / duplication delete-list; defers structural-shape to `architecture` when both run |
  | `production-readiness` | no | LLM only — gated on general-purpose source files in diff; resilience/operability posture (timeouts, retries, idempotency, degradation, resource limits) |
  ```

- [x] **Step 3: Add both to the two angle whitelists**
  Line ~295 (python footer whitelist set) and line ~429 (the `angle is one of …` schema list):
  append `"simplify","production-readiness"` to the set on 295, and ` | simplify | production-readiness` to the pipe list on 429.

- [x] **Step 4: Verify all whitelist sites carry both names**
  Run:
  ```bash
  grep -c 'simplify' skills/woostack-review/prompts/_header.md; \
  grep -c 'production-readiness' skills/woostack-review/prompts/_header.md
  ```
  Expected: each ≥ `3` (catalog row + footer whitelist + schema list).

### Task 4: Assign tiers in the per-provider tables + remove deferral markers

**Files:**
- Modify: `skills/woostack-review/prompts/anthropic.md`, `openai.md`, `google.md`, `opencode.md` (tier tables)
- Modify: `skills/woostack-review/prompts/angles/simplify.md`, `production-readiness.md` (drop markers)

- [x] **Step 1: Add `standard`-tier rows for both angles in each provider table**
  In each provider prompt's per-angle tier table, add `simplify` and `production-readiness` at
  `standard` (mirroring the existing `architecture` row's placement).

- [x] **Step 2: Remove the increment-1 deferral markers**
  Delete the `<!-- woostack-defer(increment 2): … -->` line from both new angle prompts (the
  wiring they pointed at now exists in this increment).

- [x] **Step 3: Verify markers are gone and tiers are present**
  Run:
  ```bash
  ! grep -rq 'woostack-defer(increment 2)' skills/woostack-review/prompts/angles/ && echo "markers-cleared"; \
  grep -l 'simplify' skills/woostack-review/prompts/anthropic.md skills/woostack-review/prompts/openai.md skills/woostack-review/prompts/google.md skills/woostack-review/prompts/opencode.md | wc -l
  ```
  Expected: prints `markers-cleared` then `4`.

- [x] **Step 4: Commit the increment**
  ```bash
  gt modify -c -m "feat(review): wire simplify + production-readiness angles into the catalog"
  ```

---

## Increment 3: Audit config loader (`audit` block) + angle resolution

> One PR — the audit-side config loader that reads a sibling `audit` block and emits the per-run
> `config.json` review's `detect-angles.sh` consumes (forcing `simplify`+`production-readiness`,
> skipping `architecture`, honoring lens flags + a `bugs`+`security` safety floor).

### Task 1: `load-audit-config.sh`

**Files:**
- Create: `skills/woostack-audit/scripts/load-audit-config.sh`
- Test: `skills/woostack-audit/scripts/tests/test-load-audit-config.sh`

- [x] **Step 1: Write the failing test**
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  ROOT="$(cd "$DIR/../../.." && pwd)"
  source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
  SCRIPT="$DIR/load-audit-config.sh"

  # Call run as a plain function (not via $(...)) so its OUTDIR export reaches the
  # parent shell; it stashes the script's exit code in global `ec` (set -e-safe).
  run() { work="$(mktemp -d)"; export OUTDIR="$work/out"; mkdir -p "$OUTDIR"; \
    printf '%s' "$1" > "$work/config.json"; \
    AUDIT_CONFIG_FILE="$work/config.json" AUDIT_LENS="${2:-}" bash "$SCRIPT" >/dev/null 2>&1 && ec=0 || ec=$?; }

  # No audit block → defaults: force simplify+production-readiness, skip architecture.
  run '{}'; assert_eq "$ec" "0" "empty config ok"
  cfg="$(cat "$OUTDIR/config.json")"
  assert_contains "$cfg" "simplify" "force includes simplify"
  assert_contains "$cfg" "production-readiness" "force includes production-readiness"
  assert_contains "$cfg" "architecture" "skip includes architecture"

  # Sibling review block is ignored, not an error.
  run '{"review":{"severity_floor":"low"},"audit":{"severity_floor":"medium"}}'
  assert_eq "$ec" "0" "sibling review block ignored"
  assert_contains "$(cat "$OUTDIR/config.json")" "medium" "audit severity_floor applied"

  # Lens flag --simplify keeps bugs+security floor, drops production-readiness from force.
  run '{}' 'simplify'; assert_eq "$ec" "0" "lens ok"
  cfg="$(cat "$OUTDIR/config.json")"
  assert_contains "$cfg" "simplify" "lens simplify forces simplify"
  assert_not_contains "$cfg" "production-readiness" "lens simplify drops prod-readiness"

  # Unknown audit key → loud non-zero.
  run '{"audit":{"bogus":1}}'; assert_eq "$ec" "1" "unknown audit key rejected"
  finish
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `bash skills/woostack-audit/scripts/tests/test-load-audit-config.sh`
  Expected: FAIL — `load-audit-config.sh: No such file or directory`.

- [x] **Step 3: Implement the loader**
  ```bash
  #!/usr/bin/env bash
  # Reads the sibling `audit` block from .woostack/config.json (or $AUDIT_CONFIG_FILE) and emits
  # $OUTDIR/config.json in the shape detect-angles.sh / intersect-findings.sh consume. Forces the
  # two audit angles on, skips architecture, applies an optional lens flag with a bugs+security
  # safety floor. Mirrors review load-config.sh strictness: unknown audit keys hard-fail.
  set -euo pipefail
  RVW="$(dirname "${BASH_SOURCE[0]:-$0}")/../../woostack-review/scripts"
  source "$RVW/resolve-root.sh"     # exports WOOSTACK_ROOT
  source "$RVW/resolve-outdir.sh"   # exports OUTDIR
  CFG_FILE="${AUDIT_CONFIG_FILE:-$WOOSTACK_ROOT/.woostack/config.json}"
  LENS="${AUDIT_LENS:-}"
  VALID_KEYS='angles severity_floor ignore models chunking report_dir'

  python3 - "$CFG_FILE" "$LENS" "$OUTDIR/config.json" "$VALID_KEYS" <<'PY'
  import json, sys, os
  cfg_file, lens, out, valid_keys = sys.argv[1], sys.argv[2], sys.argv[3], set(sys.argv[4].split())
  audit = {}
  if os.path.exists(cfg_file):
      with open(cfg_file) as f:
          try: audit = (json.load(f) or {}).get("audit", {}) or {}
          except json.JSONDecodeError as e:
              sys.stderr.write(f"::error file={cfg_file}::invalid JSON: {e}\n"); sys.exit(1)
  bad = [k for k in audit if k not in valid_keys]
  if bad:
      sys.stderr.write(f"::error file={cfg_file}::unknown audit key(s): {', '.join(bad)}\n"); sys.exit(1)
  # AUDIT_LENS is set by the SKILL CLI flags: --simplify -> "simplify",
  # --prod-only -> "prod"; unset (the default) runs both lenses.
  force = ["simplify", "production-readiness"]
  if lens == "simplify": force = ["simplify"]
  elif lens == "prod": force = ["production-readiness"]
  # bugs+security are always-on in detect-angles.sh (the safety floor); architecture is skipped.
  out_cfg = {
      "angles": {"force": force + ((audit.get("angles") or {}).get("force", [])),
                 "skip": ["architecture"] + ((audit.get("angles") or {}).get("skip", []))},
      "severity_floor": audit.get("severity_floor", "high"),
      "ignore": audit.get("ignore", []),
      "models": audit.get("models", {}),
      "chunking": audit.get("chunking", {"max_loc": 4000}),
      "report_dir": audit.get("report_dir", ".woostack/audits"),
  }
  with open(out, "w") as f: json.dump(out_cfg, f)
  PY
  ```

- [x] **Step 4: Run the test, confirm it passes**
  Run: `bash skills/woostack-audit/scripts/tests/test-load-audit-config.sh`
  Expected: `… passed, 0 failed`

- [x] **Step 5: Commit**
  ```bash
  gt modify -c -m "feat(audit): add audit config loader (sibling audit block + lens flags)"
  ```

---

## Increment 4: `build-target-diff.sh` (synthetic all-added diff + meta + cap + chunk)

> One PR — audit's Stage-1 builder: walks the explicit target, emits an all-added `diff.txt` +
> `meta.json`, applies review's section-aware cap and `chunk-diff.sh`, composes memory + rules.

### Task 1: Synthetic-diff builder

**Files:**
- Create: `skills/woostack-audit/scripts/build-target-diff.sh`
- Test: `skills/woostack-audit/scripts/tests/test-build-target-diff.sh`

- [x] **Step 1: Write the failing test**
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  ROOT="$(cd "$DIR/../../.." && pwd)"
  source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
  SCRIPT="$DIR/build-target-diff.sh"

  # A dir with two text files + one binary → diff.txt has two new-file sections, all + lines,
  # binary skipped; meta.json lists the two text files.
  t="$(mktemp -d)"; mkdir -p "$t/src"; printf 'export const a = 1\n' > "$t/src/a.ts"; \
    printf 'def b():\n    return 2\n' > "$t/src/b.py"; printf '\x00\x01\x02' > "$t/src/c.bin"
  export OUTDIR="$(mktemp -d)/out"; mkdir -p "$OUTDIR"
  AUDIT_TARGET="$t/src" bash "$SCRIPT" >/dev/null 2>&1; ec=$?
  assert_eq "$ec" "0" "builder exits 0 on a normal target"
  assert_eq "$(grep -c '^diff --git' "$OUTDIR/diff.txt")" "2" "one new-file section per text file"
  assert_eq "$(grep -c '^new file mode' "$OUTDIR/diff.txt")" "2" "marked as new files (all-added)"
  assert_not_contains "$(cat "$OUTDIR/diff.txt")" "c.bin" "binary file skipped"
  assert_eq "$(jq '.files | length' "$OUTDIR/meta.json")" "2" "meta lists 2 files"
  rm -rf "$t" "$OUTDIR"

  # Missing target → non-zero, no diff.txt.
  export OUTDIR="$(mktemp -d)/out"; mkdir -p "$OUTDIR"
  AUDIT_TARGET="/no/such/path" bash "$SCRIPT" >/dev/null 2>&1; ec=$?
  assert_eq "$ec" "1" "missing target exits 1"
  assert_eq "$([ -f "$OUTDIR/diff.txt" ] && echo y || echo n)" "n" "no diff.txt on missing target"
  rm -rf "$OUTDIR"

  # Binary-only target → empty diff.txt, exit 0 (caller reports "nothing to audit").
  t="$(mktemp -d)"; printf '\x00\x01' > "$t/x.bin"; export OUTDIR="$(mktemp -d)/out"; mkdir -p "$OUTDIR"
  AUDIT_TARGET="$t" bash "$SCRIPT" >/dev/null 2>&1; ec=$?
  assert_eq "$ec" "0" "binary-only exits 0"
  assert_eq "$(wc -c < "$OUTDIR/diff.txt" | tr -d ' ')" "0" "binary-only yields empty diff"
  rm -rf "$t" "$OUTDIR"
  finish
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `bash skills/woostack-audit/scripts/tests/test-build-target-diff.sh`
  Expected: FAIL — script not found.

- [x] **Step 3: Implement the builder**
  ```bash
  #!/usr/bin/env bash
  # Builds an all-added synthetic diff for an explicit standing-code target so review's
  # diff-anchored swarm audits code at rest. AUDIT_TARGET is required (no default). Skips binary,
  # gitignored, lockfile, and generated files. Applies the same section-aware cap as
  # prefetch.sh (WOO_REVIEW_DIFF_CAP_BYTES) and chunk-diff.sh chunking.
  set -euo pipefail
  RVW="$(dirname "${BASH_SOURCE[0]:-$0}")/../../woostack-review/scripts"
  source "$RVW/resolve-outdir.sh"
  TARGET="${AUDIT_TARGET:?AUDIT_TARGET (an explicit path) is required — woostack-audit <target>}"
  if [ ! -e "$TARGET" ]; then
    echo "::error::audit target not found: $TARGET" >&2; exit 1
  fi
  : > "$OUTDIR/diff.txt"
  files=()
  # Enumerate candidate files (a single file, or all files under a dir), honoring .gitignore when
  # inside a repo; fall back to find when the target is untracked.
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    case "$f" in *.lock|*-lock.json|*.min.js|*.map) continue;; esac
    grep -Iq . "$f" 2>/dev/null || continue   # -I skips binary
    files+=("$f")
  done < <(
    if git -C "$(dirname "$TARGET")" rev-parse --show-toplevel >/dev/null 2>&1; then
      git ls-files --cached --others --exclude-standard -- "$TARGET" 2>/dev/null || find "$TARGET" -type f
    else find "$TARGET" -type f; fi
  )
  for f in ${files[@]+"${files[@]}"}; do
    # `git diff --no-index /dev/null <f>` prints a new-file all-added section; exit 1 means
    # "differs" (always true vs /dev/null) and is expected — never a failure.
    git diff --no-index -- /dev/null "$f" >> "$OUTDIR/diff.txt" 2>/dev/null || true
  done
  # Synthesize meta.json (synthetic head = current HEAD when in a repo, else "audit").
  head_oid="$(git rev-parse HEAD 2>/dev/null || echo audit)"
  printf '%s\n' ${files[@]+"${files[@]}"} | jq -R 'select(length>0)' | jq -s \
    --arg oid "$head_oid" --arg t "$TARGET" \
    '{headRefOid:$oid, baseRefName:"audit", title:("(audit: "+$t+")"), body:"", files:[.[]|{path:.}]}' \
    > "$OUTDIR/meta.json"
  # Section-aware cap + chunking, reusing review's machinery on the synthetic diff.
  cap="${WOO_REVIEW_DIFF_CAP_BYTES:-300000}"
  if [ "$(wc -c < "$OUTDIR/diff.txt")" -gt "$cap" ]; then
    echo "::warning::audit diff exceeds ${cap}B; chunking" >&2
  fi
  bash "$RVW/chunk-diff.sh" >/dev/null 2>&1 || true
  ```

- [x] **Step 4: Run the test, confirm it passes**
  Run: `bash skills/woostack-audit/scripts/tests/test-build-target-diff.sh`
  Expected: `… passed, 0 failed`

- [x] **Step 5: Verify a synthetic line is review-anchorable**
  Run:
  ```bash
  t="$(mktemp -d)"; printf 'export const a = 1\n' > "$t/a.ts"; export OUTDIR="$(mktemp -d)/out"; mkdir -p "$OUTDIR"; \
  AUDIT_TARGET="$t" bash skills/woostack-audit/scripts/build-target-diff.sh >/dev/null 2>&1; \
  bash skills/woostack-review/scripts/resolve-diff-line.sh --file "$t/a.ts" --line 1
  ```
  Expected: a non-`null` value (the all-added line resolves on the RIGHT side). *(If `resolve-diff-line.sh` expects a repo-relative path, pass the path as it appears in `diff.txt`.)*

- [x] **Step 6: Commit**
  ```bash
  gt modify -c -m "feat(audit): synthesize all-added target diff + meta (cap + chunk reuse)"
  ```

---

## Increment 5: `render-report.sh` (report-only output)

> One PR — turns the validated `findings.json` into a git-tracked, severity-grouped markdown
> report under `.woostack/audits/` plus a terminal summary. Makes no network call.

### Task 1: Report renderer

**Files:**
- Create: `skills/woostack-audit/scripts/render-report.sh`
- Test: `skills/woostack-audit/scripts/tests/test-render-report.sh`

- [x] **Step 1: Write the failing test**
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  ROOT="$(cd "$DIR/../../.." && pwd)"
  source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
  SCRIPT="$DIR/render-report.sh"

  export OUTDIR="$(mktemp -d)/out"; mkdir -p "$OUTDIR"
  cat > "$OUTDIR/findings.json" <<'JSON'
  [{"angle":"simplify","severity":"HIGH","file":"src/a.ts","line":1,"title":"Unused export `a`","description":"nothing references a","fix":"delete it"},
   {"angle":"production-readiness","severity":"LOW","file":"src/b.py","line":2,"title":"No timeout on fetch","description":"call can hang","fix":"add a deadline"}]
  JSON
  out="$(mktemp -d)/report"; mkdir -p "$(dirname "$out")"
  AUDIT_REPORT_PATH="$out.md" AUDIT_TARGET="src" bash "$SCRIPT" >/dev/null 2>&1; ec=$?
  assert_eq "$ec" "0" "renderer exits 0"
  body="$(cat "$out.md")"
  assert_contains "$body" "## HIGH" "groups by severity"
  assert_contains "$body" "src/a.ts:1" "anchors finding"
  assert_contains "$body" "/woostack-fix" "suggests a next step"
  assert_not_contains "$body" "REQUEST_CHANGES" "no PR-event language (report-only)"

  # Zero findings → clean report, exit 0.
  echo '[]' > "$OUTDIR/findings.json"
  AUDIT_REPORT_PATH="$out.md" AUDIT_TARGET="src" bash "$SCRIPT" >/dev/null 2>&1; ec=$?
  assert_eq "$ec" "0" "clean exits 0"
  assert_contains "$(cat "$out.md")" "clean" "clean report states clean"
  finish
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `bash skills/woostack-audit/scripts/tests/test-render-report.sh`
  Expected: FAIL — script not found.

- [x] **Step 3: Implement the renderer**
  ```bash
  #!/usr/bin/env bash
  # Renders $OUTDIR/findings.json into a severity-grouped markdown report (report-only; no
  # network). Writes AUDIT_REPORT_PATH (default .woostack/audits/<date>-<slug>.md) and prints a
  # terminal summary.
  set -euo pipefail
  source "$(dirname "${BASH_SOURCE[0]:-$0}")/../../woostack-review/scripts/resolve-outdir.sh"
  FINDINGS="$OUTDIR/findings.json"; [ -f "$FINDINGS" ] || echo '[]' > "$FINDINGS"
  REPORT="${AUDIT_REPORT_PATH:?AUDIT_REPORT_PATH required}"
  TARGET="${AUDIT_TARGET:-(unspecified)}"
  mkdir -p "$(dirname "$REPORT")"
  python3 - "$FINDINGS" "$REPORT" "$TARGET" <<'PY'
  import json, sys
  findings = json.load(open(sys.argv[1]))
  report, target = sys.argv[2], sys.argv[3]
  lines = [f"# Audit report — `{target}`", ""]
  if not findings:
      lines += ["**Result: clean.** No findings.", ""]
  else:
      order = {"HIGH":0,"MEDIUM":1,"LOW":2}
      findings.sort(key=lambda f:(order.get(f.get("severity","LOW"),3), f.get("angle","")))
      cur = None
      for f in findings:
          sev = f.get("severity","LOW")
          if sev != cur: lines += ["", f"## {sev}", ""]; cur = sev
          loc = f"{f.get('file','?')}:{f.get('line','?')}"
          lines += [f"### {f.get('title','(untitled)')} — `{loc}` · `{f.get('angle','?')}`",
                    f"{f.get('description','')}", "", f"**Fix:** {f.get('fix','')}",
                    "", "_Next: `/woostack-fix` for a small change, `/woostack-build` for a larger one._", ""]
  open(report,"w").write("\n".join(lines)+"\n")
  print(f"audit: {len(findings)} finding(s) → {report}")
  PY
  ```

- [x] **Step 4: Run the test, confirm it passes**
  Run: `bash skills/woostack-audit/scripts/tests/test-render-report.sh`
  Expected: `… passed, 0 failed`

- [x] **Step 5: Verify no network call in the renderer**
  Run: `! grep -Eq 'gh |curl |wget |api\.github' skills/woostack-audit/scripts/render-report.sh && echo report-only`
  Expected: `report-only`

- [x] **Step 6: Commit**
  ```bash
  gt modify -c -m "feat(audit): render report-only severity-grouped findings doc"
  ```

---

## Increment 6: `woostack-audit/SKILL.md` orchestration + gitignore allow + smoke test

> One PR — the SKILL that drives the full pipeline and ties the scripts to review's swarm; ensures
> `.woostack/.gitignore` does not exclude `audits/`; pinned by an end-to-end smoke test on a fixture.

### Task 1: Authoring `SKILL.md`

**Files:**
- Create: `skills/woostack-audit/SKILL.md`

- [x] **Step 1: Write the SKILL**
  Author `skills/woostack-audit/SKILL.md` with: frontmatter (`name: woostack-audit`,
  `description:` per the discovery rubric, `requires: { bins: [jq, node, git] }`,
  `recommends: { bins: [rg] }`); the command (`/woostack-audit <target> [--fast|--deep]
  [--simplify|--prod-only]`, explicit target required, `--all` = repo root); and the staged
  workflow that, with `WOO_REVIEW_ACTION_PATH` set to the installed `woostack-review` dir and
  `OUTDIR` resolved once, runs in order: `build-target-diff.sh` → `load-audit-config.sh` →
  review `detect-angles.sh` → `run-bounded-swarm.sh` → `verify-receipts.sh` → `merge-findings.sh`
  → prosecutor → defender → `intersect-findings.sh` → `render-report.sh`. State the hard
  boundaries (report-only, no GitHub, no auto-fix, no merge, explicit target). Cross-link
  `woostack-review`, `woostack-fix`, `woostack-build`; do not restate review's stage internals.

- [x] **Step 2: Verify the SKILL declares the contract (structural checks)**
  Run:
  ```bash
  grep -c 'WOO_REVIEW_ACTION_PATH' skills/woostack-audit/SKILL.md; \
  grep -Ec 'verify-receipts\.sh' skills/woostack-audit/SKILL.md; \
  grep -Ec 'report-only|never (posts|merges)' skills/woostack-audit/SKILL.md; \
  grep -Eqc '\bgh \b|api\.github' skills/woostack-audit/SKILL.md && echo "LEAK" || echo "no-github"
  ```
  Expected: `≥1`, `1`, `≥1`, then `no-github`.

### Task 2: Keep `audits/` git-tracked

**Files:**
- Modify: `.woostack/.gitignore`

- [x] **Step 1: Assert audits/ is not ignored, add a guard comment if a pattern would catch it**
  Run: `git check-ignore .woostack/audits/x.md || echo "not-ignored"`
  Expected: `not-ignored`. If it IS ignored, append `!audits/` to `.woostack/.gitignore` and re-run until `not-ignored`.

### Task 3: End-to-end smoke test on a fixture

**Files:**
- Test: `skills/woostack-audit/scripts/tests/test-audit-smoke.sh`

- [x] **Step 1: Write the smoke test (pipeline wiring, mocked swarm)**
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  ROOT="$(cd "$DIR/../../.." && pwd)"
  source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

  # Fixture target.
  t="$(mktemp -d)"; printf 'export const unused = 1\n' > "$t/a.ts"
  export OUTDIR="$(mktemp -d)/out"; mkdir -p "$OUTDIR"

  # Stage 1: build the synthetic diff.
  AUDIT_TARGET="$t" bash "$DIR/build-target-diff.sh" >/dev/null 2>&1
  assert_eq "$(grep -c '^diff --git' "$OUTDIR/diff.txt")" "1" "synthetic diff built"

  # Stage 2: audit config emits forced angles.
  AUDIT_CONFIG_FILE="$t/none.json" bash "$DIR/load-audit-config.sh" >/dev/null 2>&1
  assert_contains "$(cat "$OUTDIR/config.json")" "simplify" "config forces simplify"

  # Stage N: render a hand-seeded findings.json (swarm output is mocked — wiring test, not model).
  echo '[{"angle":"simplify","severity":"HIGH","file":"'"$t"'/a.ts","line":1,"title":"Unused export","description":"x","fix":"delete"}]' > "$OUTDIR/findings.json"
  AUDIT_REPORT_PATH="$OUTDIR/report.md" AUDIT_TARGET="$t" bash "$DIR/render-report.sh" >/dev/null 2>&1
  assert_contains "$(cat "$OUTDIR/report.md")" "Unused export" "report rendered from findings"
  rm -rf "$t" "$OUTDIR"
  finish
  ```

- [x] **Step 2: Run the smoke test, confirm pass**
  Run: `bash skills/woostack-audit/scripts/tests/test-audit-smoke.sh`
  Expected: `3 passed, 0 failed`

- [x] **Step 3: Commit**
  ```bash
  gt modify -c -m "feat(audit): add woostack-audit SKILL orchestration + smoke test"
  ```

---

## Increment 7 (stacked follow-up): Command-surface wiring (19th public skill)

> One PR — the bookkeeping that registers `woostack-audit` across the command surface. Per
> `[[woostack-review-is-not-stack-aware-224]]`, this is a deliberate stacked follow-up; the
> skill+angles land first.

### Task 1: Register across the surface

**Files:**
- Modify: `AGENTS.md` (count "eighteen"→"nineteen", public list, file-map, Mode B list)
- Modify: `README.md`, `skills/using-woostack/SKILL.md` (routing), `CONTRIBUTING.md`,
  `skills/woostack-bootstrap/references/development.md`
- Modify: `site/content/docs/` authored pages naming the skill surface/count

- [x] **Step 1: Update AGENTS.md count + lists**
  Change the "eighteen skills" phrasing to "nineteen", add `woostack-audit` to the public
  command list, the Quick file map, and the Mode B command list.

- [x] **Step 2: Add the routing row + README/CONTRIBUTING/development entries**
  Add a `woostack-audit` routing row to `skills/using-woostack/SKILL.md` and matching mentions in
  `README.md`, `CONTRIBUTING.md`, and `skills/woostack-bootstrap/references/development.md`.

- [x] **Step 3: Update authored docs-site pages + verify build**
  Update any authored `site/content/docs/` page that states the skill surface or its count, then:
  Run: `pnpm -C site build`
  Expected: build succeeds.

- [x] **Step 4: Verify the count is consistent across the surface**
  Run:
  ```bash
  grep -rl 'woostack-audit' AGENTS.md README.md CONTRIBUTING.md skills/using-woostack/SKILL.md skills/woostack-bootstrap/references/development.md | wc -l
  ```
  Expected: `5` (every surface doc names the skill).

- [x] **Step 5: Commit**
  ```bash
  gt create -m "docs: register woostack-audit across the command surface (19th skill)"
  ```

---

## Plan Checks

- **Spec coverage** — AC1 (synthetic diff)→Inc 4; AC2 (explicit target)→Inc 4 (`AUDIT_TARGET:?`)
  + Inc 6 SKILL; AC3 (catalog/lens)→Inc 3 + Inc 2 gate; AC4 (simplify incl. cross-file dead
  export)→Inc 1 `simplify.md` + Inc 2 gating test; AC5 (production-readiness scope-split)→Inc 1
  `production-readiness.md`; AC6 (report-only, no post)→Inc 5 (+no-network check); AC7 (adversarial
  + severity reused)→Inc 6 pipeline (reuses validators/intersect unchanged); AC8 (config
  isolation)→Inc 3; AC9 (review-active + scope-split)→Inc 2 gating test + Inc 1 scope-split clause.
- **AC coverage** — every AC and its happy/error/edge has a task/test above; none `N/A`.
- **No placeholders** — every step carries real prompt/script/test content, exact commands, and
  expected output. Verification steps use grep/`jq`/`python3`/the `assert.sh` helper, the
  repo-appropriate "failing test" substitute.
- **Type/name consistency** — angle ids `simplify` / `production-readiness` are spelled
  identically across `VALID_ANGLES`, `detect-angles.sh`, `_header.md` whitelists, prompt filenames,
  finding `angle` fields, and the loader's `force`/`skip`. Findings JSON keys
  (`angle/severity/file/line/title/description/fix/fix_type`) match `_header.md`.
- **Angle coverage (plan lens)** — architecture: new audit scripts are small, single-responsibility
  files under `skills/woostack-audit/scripts/`, reusing review's via `WOO_REVIEW_ACTION_PATH` (no
  copy). security: audit makes no network call (pinned in Inc 5 + Inc 6 checks); secrets are
  surfaced locally, never posted. observability: degraded/missing-receipt states reuse
  `verify-receipts.sh` hard-fail. tests: every increment ships a committed structural test
  ([[autonomy-needs-structural-proof]]). deps: no new dependency — `rg` is recommend-only with a
  `git grep`/`grep -rn` fallback; `gh` is intentionally NOT required.
