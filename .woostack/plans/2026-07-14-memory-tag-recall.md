---
type: plan
source: .woostack/specs/2026-07-14-memory-tag-recall.md
status: ready
branch: feature/memory-tag-recall
---

**Source:** [[specs/2026-07-14-memory-tag-recall]]

# Memory tag-hop recall axis — Implementation Plan

**Goal:** Make memory `tags:` a load-bearing recall axis by adding a one-hop tag expansion to `recall.sh` — a second expansion edge beside the existing `[[wikilink]]` hop — so notes sharing ≥1 tag with the scope-matched set surface under a new `## Tag-related notes` section.

**Architecture:** One behavior change in `skills/woostack-init/scripts/recall.sh`, driven test-first by `skills/woostack-init/scripts/tests/test-recall.sh`. After the existing wikilink expand, build a query tag-set from the scope-matched notes only, scan `MEM_DIR` for not-yet-loaded non-global notes sharing ≥1 tag (case-insensitive, trimmed), rank them (shared-tag count desc → `updated:` desc → name asc), stamp telemetry, and fill/​render them at strictly lowest cap precedence. The contract (`memory.md` §3, §6) and one authored site page (`concepts/memory.mdx`) move in lockstep. No caller-contract change, no new infrastructure, bash 3.2-compatible (no associative arrays — tag sets use temp files + `comm`).

**Tech Stack:** POSIX/bash 3.2 shell (`recall.sh`, `lib.sh` `field()`/`note_body()`), the bespoke bash test harness (`tests/assert.sh` + `tests/run-tests.sh`), Markdown contract/docs.

## Increment 1: Tag-hop recall axis

> One independently shippable PR (well under 500 LOC) — its own Graphite-stacked branch on top of the spec+plan base. The spec explicitly endorsed a single cohesive increment (spec §9): behavior + tests + contract + lockstep together, so the contract never contradicts the code within the stack.

### Task 1: Tag-hop expansion in `recall.sh` (test-first)

**Files:**
- Modify: `skills/woostack-init/scripts/recall.sh`
- Test: `skills/woostack-init/scripts/tests/test-recall.sh`

The failing test is authored first (AC1–AC7), confirmed red, then `recall.sh` is implemented to green. All test code appends to the existing `test-recall.sh` **before** its final `finish` call (line 135 today: `finish`). Insert the new blocks immediately before that `finish` line.

- [ ] **Step 1: Write the failing tests (AC1–AC7)**
  Insert these blocks in `tests/test-recall.sh` immediately before the final `finish` line. They reuse the existing helpers (`mk_note`, `assert_contains`, `assert_not_contains`, `assert_eq`, `tel_get`, and the `PASS`/`FAIL` counters).

  ```bash
  # ===== tag-hop recall axis =====

  # --- AC1/AC2/AC4/AC6: general tag expansion, one-hop bound, global-not-source, dedup ---
  wooT1="$(mktemp -d)"; mdT1="$wooT1/memory"; mkdir -p "$mdT1"
  mk_note "$mdT1" hit.md     $'name: hit\ntype: pattern\nscope: packages/api/**\ntags: orpc, Errors' 'HIT scoped body'
  mk_note "$mdT1" rel.md     $'name: rel\ntype: pattern\nscope: apps/web/**\ntags: errors, onlyrel' 'REL tagged body'
  mk_note "$mdT1" second.md  $'name: second\ntype: pattern\nscope: yyy/**\ntags: onlyrel' 'SECOND body'
  mk_note "$mdT1" nomatch.md $'name: nomatch\ntype: pattern\nscope: zzz/**\ntags: unrelated' 'NOMATCH body'
  mk_note "$mdT1" gseed.md   $'name: gseed\ntype: convention\nscope: *\ntags: errors' 'GSEED global body'
  mk_note "$mdT1" gsrc.md    $'name: gsrc\ntype: convention\nscope: *\ntags: globonly' 'GSRC global body'
  mk_note "$mdT1" gtarget.md $'name: gtarget\ntype: pattern\nscope: qqq/**\ntags: globonly' 'GTARGET body'
  pT1="$(mktemp)"; printf 'packages/api/x.ts\n' > "$pT1"
  out="$(bash "$RECALL" "$wooT1" "$pT1")"
  assert_contains "$out" "## Tag-related notes"  "tag-related section rendered"
  assert_contains "$out" "REL tagged body"       "AC1 happy: shared-tag note surfaced (case-insensitive Errors/errors)"
  assert_not_contains "$out" "NOMATCH body"      "AC1 edge: no-shared-tag note not pulled"
  assert_not_contains "$out" "SECOND body"       "AC2 edge: one-hop only — tag shared with a tag-linked note not pulled"
  assert_not_contains "$out" "GTARGET body"      "AC4 happy: global tags do not seed expansion"
  cnt_gseed="$(printf '%s\n' "$out" | grep -c 'GSEED global body' || true)"
  assert_eq "$cnt_gseed" "1"                     "AC4 edge: global candidate skipped, not duplicated into tag-related"
  cnt_hit="$(printf '%s\n' "$out" | grep -c 'HIT scoped body' || true)"
  assert_eq "$cnt_hit" "1"                       "AC6 edge: scoped note not duplicated into tag-related"
  # section order: Scoped < Tag-related < Global (spec §4)
  sc="$(printf '%s\n' "$out" | grep -n '## Scoped memory'   | cut -d: -f1)"
  tg="$(printf '%s\n' "$out" | grep -n '## Tag-related notes'| cut -d: -f1)"
  gl="$(printf '%s\n' "$out" | grep -n '## Global memory'    | cut -d: -f1)"
  [ -n "$sc" ] && [ -n "$tg" ] && [ -n "$gl" ] && [ "$sc" -lt "$tg" ] && [ "$tg" -lt "$gl" ] \
    && PASS=$((PASS+1)) \
    || { FAIL=$((FAIL+1)); echo "  FAIL: section order — Scoped($sc) < Tag-related($tg) < Global($gl)"; }

  # AC6 happy: a tag-linked note is stamped in telemetry (fresh run for a clean count)
  WOOSTACK_NOW=2026-06-02 bash "$RECALL" "$wooT1" "$pT1" >/dev/null 2>&1 || true
  # (rel was stamped on the first `out` run above; assert cumulative count >=1)
  rel_count="$(tel_get "$mdT1" rel recall_count)"
  [ -n "$rel_count" ] && [ "$rel_count" -ge 1 ] \
    && PASS=$((PASS+1)) \
    || { FAIL=$((FAIL+1)); echo "  FAIL: AC6 telemetry — tag-linked note stamped (count=$rel_count)"; }
  rm -rf "$wooT1" "$pT1"

  # --- AC3: tag-related is lowest cap precedence (dropped first; scoped kept) ---
  wooT2="$(mktemp -d)"; mdT2="$wooT2/memory"; mkdir -p "$mdT2"
  mk_note "$mdT2" anchor.md $'name: anchor\ntype: pattern\nscope: packages/api/**\ntags: errors' 'ANCHOR body'
  mk_note "$mdT2" big.md    $'name: big\ntype: pattern\nscope: apps/web/**\ntags: errors' 'BIG tag body PADPADPADPADPADPADPADPADPADPADPADPADPADPADPADPAD'
  pT2="$(mktemp)"; printf 'packages/api/x.ts\n' > "$pT2"
  capout="$(RECALL_CAP=40 bash "$RECALL" "$wooT2" "$pT2" 2>/dev/null)"
  assert_contains "$capout" "ANCHOR body"      "AC3 edge: scoped note kept under cap"
  assert_not_contains "$capout" "BIG tag body" "AC3 happy: tag-related note dropped under cap"
  caperr="$(RECALL_CAP=40 bash "$RECALL" "$wooT2" "$pT2" 2>&1 >/dev/null)"
  assert_contains "$caperr" "dropped tag-related" "AC3: tag-related drop logged to stderr"
  rm -rf "$wooT2" "$pT2"

  # --- AC3 extra (spec §6 global tail-cap): globals over cap suppress tag-related too ---
  wooT2b="$(mktemp -d)"; mdT2b="$wooT2b/memory"; mkdir -p "$mdT2b"
  mk_note "$mdT2b" a2.md  $'name: a2\ntype: pattern\nscope: packages/api/**\ntags: errors' 'A2 body'
  mk_note "$mdT2b" r2.md  $'name: r2\ntype: pattern\nscope: apps/web/**\ntags: errors' 'R2 tag body'
  mk_note "$mdT2b" bg.md  $'name: bg\ntype: convention\nscope: *' 'BIG GLOBAL body PADPADPADPADPADPADPADPADPADPADPADPAD'
  pT2b="$(mktemp)"; printf 'packages/api/x.ts\n' > "$pT2b"
  tail_out="$(RECALL_CAP=20 bash "$RECALL" "$wooT2b" "$pT2b" 2>/dev/null)"
  tail_err="$(RECALL_CAP=20 bash "$RECALL" "$wooT2b" "$pT2b" 2>&1 >/dev/null)"
  assert_not_contains "$tail_out" "## Tag-related notes" "global tail-cap: tag-related suppressed with scoped/linked"
  assert_not_contains "$tail_out" "R2 tag body"          "global tail-cap: tag-related note not emitted"
  assert_contains "$tail_err" "exceed cap"               "global tail-cap branch logged"
  rm -rf "$wooT2b" "$pT2b"

  # --- AC5: no tags anywhere -> no tag-related section (regression / no-op) ---
  wooT3="$(mktemp -d)"; mdT3="$wooT3/memory"; mkdir -p "$mdT3"
  mk_note "$mdT3" p1.md $'name: p1\ntype: pattern\nscope: packages/api/**' 'P1 body'
  mk_note "$mdT3" p2.md $'name: p2\ntype: pattern\nscope: apps/web/**\ntags:   ,  ' 'P2 empty-tags body'
  mk_note "$mdT3" g1.md $'name: g1\ntype: convention\nscope: *' 'G1 global body'
  pT3="$(mktemp)"; printf 'packages/api/x.ts\n' > "$pT3"
  out3="$(bash "$RECALL" "$wooT3" "$pT3")"
  assert_not_contains "$out3" "## Tag-related notes" "AC5: no/empty tags -> no tag-related section"
  assert_contains "$out3" "P1 body"       "AC5: scoped output unchanged when no tags"
  assert_contains "$out3" "G1 global body" "AC5: global output unchanged when no tags"
  rm -rf "$wooT3" "$pT3"

  # --- AC7: ordering under cap (shared-count desc; recency then name tiebreak) ---
  wooT4="$(mktemp -d)"; mdT4="$wooT4/memory"; mkdir -p "$mdT4"
  mk_note "$mdT4" anc.md $'name: anc\ntype: pattern\nscope: packages/api/**\ntags: a, b' 'ANC body'
  mk_note "$mdT4" two.md $'name: two\ntype: pattern\nscope: xxx/**\ntags: a, b' 'TWO body PADPADPADPADPADPAD'
  mk_note "$mdT4" one.md $'name: one\ntype: pattern\nscope: yyy/**\ntags: a'    'ONE body PADPADPADPADPADPAD'
  pT4="$(mktemp)"; printf 'packages/api/x.ts\n' > "$pT4"
  out4="$(bash "$RECALL" "$wooT4" "$pT4")"
  two_line="$(printf '%s\n' "$out4" | grep -n 'TWO body' | cut -d: -f1)"
  one_line="$(printf '%s\n' "$out4" | grep -n 'ONE body' | cut -d: -f1)"
  [ -n "$two_line" ] && [ -n "$one_line" ] && [ "$two_line" -lt "$one_line" ] \
    && PASS=$((PASS+1)) \
    || { FAIL=$((FAIL+1)); echo "  FAIL: AC7 order — two(line $two_line) should precede one(line $one_line)"; }
  # under a cap that fits only one tag-related note, the higher-shared-count note survives
  cap4="$(RECALL_CAP=60 bash "$RECALL" "$wooT4" "$pT4" 2>/dev/null)"
  assert_contains "$cap4" "TWO body"     "AC7 happy: higher shared-tag-count note kept under cap"
  assert_not_contains "$cap4" "ONE body" "AC7 happy: lower shared-tag-count note dropped under cap"
  rm -rf "$wooT4" "$pT4"

  # --- AC7 edge: equal shared-count -> newer updated ranks first ---
  wooT5="$(mktemp -d)"; mdT5="$wooT5/memory"; mkdir -p "$mdT5"
  mk_note "$mdT5" anc2.md $'name: anc2\ntype: pattern\nscope: packages/api/**\ntags: a' 'ANC2 body'
  mk_note "$mdT5" tnew.md $'name: tnew\ntype: pattern\nscope: xxx/**\ntags: a\nupdated: 2026-06-02' 'TNEW body'
  mk_note "$mdT5" told.md $'name: told\ntype: pattern\nscope: yyy/**\ntags: a\nupdated: 2026-01-01' 'TOLD body'
  pT5="$(mktemp)"; printf 'packages/api/x.ts\n' > "$pT5"
  out5="$(bash "$RECALL" "$wooT5" "$pT5")"
  tnew_line="$(printf '%s\n' "$out5" | grep -n 'TNEW body' | cut -d: -f1)"
  told_line="$(printf '%s\n' "$out5" | grep -n 'TOLD body' | cut -d: -f1)"
  [ -n "$tnew_line" ] && [ -n "$told_line" ] && [ "$tnew_line" -lt "$told_line" ] \
    && PASS=$((PASS+1)) \
    || { FAIL=$((FAIL+1)); echo "  FAIL: AC7 recency — tnew(line $tnew_line) should precede told(line $told_line)"; }
  rm -rf "$wooT5" "$pT5"
  ```

- [ ] **Step 2: Run the tests, confirm they fail**
  Run: `bash skills/woostack-init/scripts/tests/test-recall.sh`
  Expected: FAIL — multiple lines, e.g. `FAIL: tag-related section rendered` / `[...] does not contain [## Tag-related notes]` (the section does not exist yet), plus the ordering/cap failures.

- [ ] **Step 3: Implement tag-hop expansion in `recall.sh`**
  Apply these edits to `skills/woostack-init/scripts/recall.sh` (anchors are current line numbers/content; re-read the file first).

  (a) **Header comment** — line 3, add the new section to the stdout summary:
  ```bash
  # stdout: ## Scoped memory + ## Linked notes + ## Tag-related notes + ## Global memory.
  ```

  (b) **`note_tags` helper** — insert immediately after the `render()` definition (current line 18):
  ```bash
  # note_tags <file> -> normalized tag tokens, one per line (lowercased, trimmed,
  # non-empty). Absent/empty/whitespace-only `tags:` yields no output.
  note_tags() {
    local raw; raw="$(field "$1" tags 2>/dev/null || true)"
    printf '%s' "$raw" | tr ',' '\n' | tr '[:upper:]' '[:lower:]' \
      | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^[[:space:]]*$' || true
  }
  ```

  (c) **Temp files** — extend the `mktemp`/`trap` lines (current lines 22–23):
  ```bash
  matched="$(mktemp)"; linked="$(mktemp)"; globals="$(mktemp)"
  tag_scored="$(mktemp)"; qtags="$(mktemp)"
  trap 'rm -f "$matched" "$linked" "$globals" "$inc_set" "$tag_scored" "$qtags"' EXIT
  ```

  (d) **Tag-hop expansion block** — insert immediately after the wikilink-expand `for` loop closes (current line 59, the `done` ending the `for f in "${matched_files[@]:-}"` wikilink loop), before the `# Read linked files into array` comment:
  ```bash
  # --- One-hop tag expansion (matched-only source, exactly one hop). Pull any
  # not-yet-loaded, non-global note sharing >=1 tag with the scope-matched set.
  # tag_linked notes are never themselves an expansion source. ---
  for f in "${matched_files[@]:-}"; do
    [ -n "${f:-}" ] || continue
    note_tags "$f"
  done | LC_ALL=C sort -u > "$qtags"

  if [ -s "$qtags" ] && [ -d "$MEM_DIR" ]; then
    shopt -s nullglob
    for f in "$MEM_DIR"/*.md; do
      b="$(basename "$f")"; [ "$b" = "MEMORY.md" ] && continue
      in_set "$b" && continue          # already scoped / linked / global
      shared="$(note_tags "$f" | LC_ALL=C sort -u | LC_ALL=C comm -12 - "$qtags" | grep -c . || true)"
      if [ "${shared:-0}" -gt 0 ]; then
        upd="$(field "$f" updated || true)"
        printf '%s\t%s\t%s\n' "$shared" "$upd" "$f" >> "$tag_scored"
        add_set "$b"
      fi
    done
  fi

  # Order: shared-tag count desc, then updated recency desc, then name asc.
  tag_linked_files=()
  while IFS= read -r line; do
    [ -n "$line" ] && tag_linked_files+=("$line")
  done < <(sort -t"$(printf '\t')" -k1,1nr -k2,2r -k3,3 "$tag_scored" | cut -f3-)
  ```

  (e) **Telemetry stamp** — insert after the globals stamp loop (current line 77, `while IFS= read -r f; do [ -n "$f" ] && stamp_note "$f"; done < "$globals"`):
  ```bash
  for f in "${tag_linked_files[@]:-}"; do [ -n "${f:-}" ] && stamp_note "$f"; done
  ```

  (f) **Declare `tag_out`** — extend current line 86:
  ```bash
  scoped_out=""; linked_out=""; tag_out=""
  ```

  (g) **Fill `tag_out`** — inside the `else` branch, after the linked-fill loop closes (current line 105, the `done` ending the `for f in "${linked_files[@]:-}"` fill loop) and before the branch's closing `fi` (current line 106):
  ```bash
  rem2=$(( rem - ${#linked_out} ))
  for f in "${tag_linked_files[@]:-}"; do
    [ -n "${f:-}" ] || continue
    chunk="$(render "$f")"$'\n\n'
    if [ $(( ${#tag_out} + ${#chunk} )) -le "$rem2" ]; then tag_out+="$chunk"
    else echo "recall: dropped tag-related $(basename "$f") (cap)" >&2; fi
  done
  ```

  (h) **Render the section** — insert between the linked print and the global print (current lines 109–110):
  ```bash
  [ -n "$tag_out" ] && printf '## Tag-related notes\n\n%s' "$tag_out"
  ```

- [ ] **Step 4: Run the tests, confirm they pass**
  Run: `bash skills/woostack-init/scripts/tests/test-recall.sh`
  Expected: PASS — final line `  N passed, 0 failed` (N = prior count + the new assertions). Also confirm the pre-existing recall cases still pass (no regression).
  Also run the full script suite: `bash skills/woostack-init/scripts/tests/run-tests.sh` — Expected: every `test-*.sh` reports `0 failed`; overall exit 0.

- [ ] **Step 5: Lint the script**
  Run: `bash -n skills/woostack-init/scripts/recall.sh`
  Expected: no output, exit 0 (syntactically valid). If `shellcheck` is available: `shellcheck -S error skills/woostack-init/scripts/recall.sh` — Expected: no error-level findings.

- [ ] **Step 6: Commit**
  ```bash
  # First commit in the increment (creates the stacked branch on top of the spec+plan base):
  gt create -m "feat(memory): one-hop tag expansion in recall.sh"
  ```

### Task 2: Contract update in `memory.md`

**Files:**
- Modify: `skills/woostack-init/references/memory.md` (§3 field table row `tags`, current line 73; §6 recall procedure, current lines 133–143)

- [ ] **Step 1: Write the failing checks (concrete grep verifications)**
  Run these before editing to confirm the current (pre-edit) state — they are the red state:
  ```bash
  grep -n 'informational only in increment A' skills/woostack-init/references/memory.md   # tags row still says "informational only"
  grep -cn 'One-hop tag expand' skills/woostack-init/references/memory.md                 # -> 0 (no tag step yet)
  ```
  Expected (red): the first prints the current `tags` row; the second prints `0`.

- [ ] **Step 2: Confirm the checks reflect the gap**
  Expected: FAIL to find the target post-edit strings — `grep -c 'One-hop tag expand'` returns `0`, proving §6 has no tag step yet.

- [ ] **Step 3: Edit the contract**
  (a) Replace the `tags` row (current line 73):
  ```markdown
  | `tags` | no | Comma list; a **load-bearing recall axis** — a one-hop tag expansion loads notes sharing ≥1 tag (trimmed, case-insensitive) with the scope-matched set (see §6). Format unchanged. |
  ```
  (b) In §6, insert a new step 5 after the current step 4 (`One-hop link expand`, line 140) and renumber the current `Stop` (line 141) to step 6:
  ```markdown
  5. **One-hop tag expand:** build the query tag-set as the union of `tags:` across the notes loaded in step 3 (scope-matched only — not globals, not the wikilinked notes from step 4). For each not-yet-loaded, non-global note whose `tags:` share ≥1 token (whitespace-trimmed, case-insensitive) with that set, load its body. This is a second one-hop expansion edge beside step 4; tag-loaded notes are never themselves an expansion source. They rank **below** wikilinked notes and are **dropped first** under `RECALL_CAP` (a broad tag can never evict a scoped, linked, or global note). Recall renders them in a dedicated `## Tag-related notes` section, after `## Linked notes` and before `## Global memory`.
  6. **Stop.** Notes not matched in steps 3–5 are never loaded.
  ```
  (c) Update the orchestration sentence (current line 143): change `which orchestrates steps 2–4` to `which orchestrates steps 2–5`.

- [ ] **Step 4: Confirm the checks pass**
  ```bash
  grep -c 'load-bearing recall axis' skills/woostack-init/references/memory.md   # -> 1
  grep -c 'One-hop tag expand' skills/woostack-init/references/memory.md         # -> 1
  grep -c 'orchestrates steps 2–5' skills/woostack-init/references/memory.md     # -> 1
  grep -c 'informational only in increment A' skills/woostack-init/references/memory.md  # -> 0
  ```
  Expected: `1`, `1`, `1`, `0` respectively.

- [ ] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(memory): tags is a recall axis in the memory contract"
  ```

### Task 3: Site lockstep — `concepts/memory.mdx`

**Files:**
- Modify: `site/content/docs/concepts/memory.mdx` (recall sentence, current lines 55–56)

> Lockstep rationale (`lockstep-edit-sites`): three authored pages restate the recall mechanic. `concepts/memory.mdx` is the memory-system page and must name the new tag axis. The two overview lines — `concepts.mdx` ("scope match and the one-hop expansion") and `concepts/context-management.mdx` (identical) — stay accurate (tag-hop *is* a one-hop expansion) and are **not** changed unless the enriched phrasing reads cleanly; do not force them. Per-skill `.mdx` under `site/content/docs/skills/` is generated + gitignored and is not touched.

- [ ] **Step 1: Confirm current (red) state**
  ```bash
  grep -n 'scope match and one-hop' site/content/docs/concepts/memory.mdx   # current sentence, no tag mention
  grep -c 'tags:. hop' site/content/docs/concepts/memory.mdx                # -> 0
  ```
  Expected: the sentence prints; the count is `0`.

- [ ] **Step 2: Confirm the gap**
  Expected: FAIL — `concepts/memory.mdx` does not yet mention the tag hop.

- [ ] **Step 3: Edit the memory page**
  Replace the recall sentence (current lines 55–56) with:
  ```mdx
  Recall is run in the shell, not the prompt: `recall.sh` does the scope match plus two one-hop
  expansions — a `[[wikilink]]` hop and a `tags:` hop that pulls notes sharing a tag with the
  matched set — and `build-index.sh` keeps `MEMORY.md` as a one-line-per-note index. See
  [Context management](/docs/concepts/context-management) for why that matters.
  ```

- [ ] **Step 4: Confirm the check passes**
  ```bash
  grep -c 'tags:. hop' site/content/docs/concepts/memory.mdx   # -> 1
  ```
  Expected: `1`. Optional full confirmation (heavier): `pnpm -C site build` — Expected: build succeeds (the authored page is valid MDX).

- [ ] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(site): name the tags recall axis on the memory concepts page"
  ```

## Plan Checks

- **Spec coverage** — recall.sh behavior (Task 1) ← spec §4; `memory.md` §3/§6 (Task 2) ← spec §5; site lockstep (Task 3) ← spec §5 lockstep bullet; testing (Task 1 Steps 1–4) ← spec §8. All spec sections map to a task.
- **AC coverage** — AC1 (happy/edge), AC2 (edge one-hop), AC3 (happy/edge + §6 global tail-cap extra), AC4 (happy/edge), AC5 (happy/edge no-op), AC6 (happy/edge dedup+telemetry), AC7 (happy/edge ordering) each map to a named assertion block in Task 1 Step 1. No `N/A` whole sections.
- **No placeholders** — every step carries the actual shell/markdown/mdx and exact commands with expected output.
- **Type consistency** — helper/var names (`note_tags`, `qtags`, `tag_scored`, `tag_linked_files`, `tag_out`, `rem2`) are used consistently across the recall.sh edits; test helper names (`mk_note`, `assert_contains`, `assert_not_contains`, `assert_eq`, `tel_get`, `PASS`/`FAIL`) match `tests/assert.sh`.
- **Angle coverage** — architecture: one behavior change, contract + one authored doc in lockstep, no caller change (spec §3). observability: cap-drop (`recall: dropped tag-related <note> (cap)`) and global-tail-cap (`exceed cap`) log to stderr, asserted in Task 1. tests: a failing check precedes every implementation step (AC1–AC7 in Task 1; grep red/green in Tasks 2–3). security/database/deps/i18n: N/A (reads local note files; no new input, network, migration, or dependency).
