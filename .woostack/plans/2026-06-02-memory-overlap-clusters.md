---
name: memory-overlap-clusters-plan
type: plan
date: 2026-06-02
branch: feature/memory-overlap-clusters
spec: .woostack/specs/2026-06-02-memory-overlap-clusters.md
source: .woostack/specs/2026-06-02-memory-overlap-clusters.md
status: done
---

**Source:** [[specs/2026-06-02-memory-overlap-clusters]]


# Memory Scope-Overlap Clusters + Recall Recency Tiebreak — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flag scope-overlap clusters in `doctor.sh` (warning-only) and break `recall.sh` match-count ties by `updated:` recency. Closes #162.

**Architecture:** `doctor.sh` captures each non-global note's matched-tracked-file set (reusing the stale-scope `scope-match.sh` call, not adding one), emits `file<TAB>note` pairs, and after the loop runs an awk union-find (canonical cluster id = lexicographically smallest member) → one warning per ≥2-note cluster. `recall.sh` adds `updated:` as a secondary sort column so ties order newest-first. Docs in `memory.md` §6/§8.

**Tech Stack:** Bash (3.2-compatible), awk (BSD, native assoc arrays), the `tests/` fixture harness (`assert.sh` + `mk_note` + `run_doctor`).

---

## File structure

| File | Responsibility | Change |
|---|---|---|
| `skills/woostack-init/scripts/recall.sh` | Compose per-PR memory | Emit `cnt<TAB>updated<TAB>path`; sort `-k1,1nr -k2,2r`; `cut -f3-` |
| `skills/woostack-init/scripts/tests/test-recall.sh` | recall tests | Recency-tiebreak + undated-loses + cap-drops-older tests |
| `skills/woostack-init/scripts/doctor.sh` | Memory-store linter | Capture matched files; emit pairs; awk union-find cluster warnings |
| `skills/woostack-init/scripts/tests/test-doctor.sh` | doctor tests | Overlap-cluster tests in an isolated git fixture repo |
| `skills/woostack-init/references/memory.md` | Memory contract | §8 overlap-warning bullet; §6 recency-tiebreak note |

Run suites with: `bash skills/woostack-init/scripts/tests/run-tests.sh`

---

## Task 1: recall.sh — recency tiebreak on match-count ties

**Files:**
- Modify: `skills/woostack-init/scripts/recall.sh` (matched emission ~line 36; sort ~line 44)
- Test: `skills/woostack-init/scripts/tests/test-recall.sh`

- [x] **Step 1: Write the failing tests**

Append before the final `finish` (after the telemetry block, line ~98). Each uses its own fixture so it is order-independent:

```bash
# --- recency tiebreak: equal match-count, newer updated: ranks first ---
woo6="$(mktemp -d)"; md6="$woo6/memory"; mkdir -p "$md6"
mk_note "$md6" older.md $'name: older\ntype: pattern\nscope: packages/api/**\nupdated: 2026-01-01' 'OLDER body'
mk_note "$md6" newer.md $'name: newer\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02' 'NEWER body'
p6="$(mktemp)"; printf 'packages/api/x.ts\n' > "$p6"
out="$(bash "$RECALL" "$woo6" "$p6")"
o_line="$(printf '%s\n' "$out" | grep -n 'OLDER body' | cut -d: -f1)"
n_line="$(printf '%s\n' "$out" | grep -n 'NEWER body' | cut -d: -f1)"
[ -n "$o_line" ] && [ -n "$n_line" ] && [ "$n_line" -lt "$o_line" ] \
  && PASS=$((PASS+1)) \
  || { FAIL=$((FAIL+1)); echo "  FAIL: recency tie — newer(line $n_line) should precede older(line $o_line)"; }

# --- undated loses the tie to a dated note of equal count ---
woo7="$(mktemp -d)"; md7="$woo7/memory"; mkdir -p "$md7"
mk_note "$md7" undated.md $'name: undated\ntype: pattern\nscope: packages/api/**' 'UNDATED body'
mk_note "$md7" dated.md   $'name: dated\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02' 'DATED body'
p7="$(mktemp)"; printf 'packages/api/x.ts\n' > "$p7"
out="$(bash "$RECALL" "$woo7" "$p7")"
u_line="$(printf '%s\n' "$out" | grep -n 'UNDATED body' | cut -d: -f1)"
d_line="$(printf '%s\n' "$out" | grep -n 'DATED body' | cut -d: -f1)"
[ -n "$u_line" ] && [ -n "$d_line" ] && [ "$d_line" -lt "$u_line" ] \
  && PASS=$((PASS+1)) \
  || { FAIL=$((FAIL+1)); echo "  FAIL: undated tie — dated(line $d_line) should precede undated(line $u_line)"; }

# --- under a tight cap, the OLDER same-count note is the one dropped ---
# Both bodies are similar length; cap admits the global shard (none here) + exactly one note.
cap_out="$(RECALL_CAP=40 bash "$RECALL" "$woo6" "$p6" 2>/dev/null)"
assert_contains "$cap_out" "NEWER body" "newer note survives the cap on a tie"
assert_not_contains "$cap_out" "OLDER body" "older note dropped first under cap on a tie"

rm -rf "$woo6" "$p6" "$woo7" "$p7"
```

- [x] **Step 2: Run to verify the new tests fail**

Run: `bash skills/woostack-init/scripts/tests/test-recall.sh`
Expected: FAIL on `recency tie` and `older note dropped first` (current sort ignores `updated:`, so tie order is arbitrary/insertion — at least one assertion fails). The undated test MAY pass by luck; the recency + cap tests will not be reliably green until Step 3.

- [x] **Step 3: Implement the tiebreak**

In `recall.sh`, the matched-note emission currently is (line ~36):

```bash
    [ "${cnt:-0}" -gt 0 ] && printf '%s\t%s\n' "$cnt" "$f" >> "$matched"
```

Change it to also emit the note's `updated:` as a middle column:

```bash
    if [ "${cnt:-0}" -gt 0 ]; then
      upd="$(field "$f" updated || true)"
      printf '%s\t%s\t%s\n' "$cnt" "$upd" "$f" >> "$matched"
    fi
```

Then the sort that feeds `matched_files` (line ~44) currently is:

```bash
done < <(sort -t"$(printf '\t')" -k1,1nr "$matched" | cut -f2-)
```

Change it to add the recency secondary key and shift the cut:

```bash
done < <(sort -t"$(printf '\t')" -k1,1nr -k2,2r "$matched" | cut -f3-)
```

`-k1,1nr` keeps match-count primary (numeric, descending); `-k2,2r` orders the `updated:` column descending (ISO dates sort chronologically; an empty column sorts last under reverse, so undated loses the tie); `cut -f3-` recovers the path now that it is the third column.

- [x] **Step 4: Run to verify pass + no regressions**

Run: `bash skills/woostack-init/scripts/tests/test-recall.sh`
Expected: PASS — all new assertions green. The existing match-count ordering test (wide/narrow, different counts) still passes because the primary key is unchanged.

- [x] **Step 5: Commit**

```bash
git add skills/woostack-init/scripts/recall.sh skills/woostack-init/scripts/tests/test-recall.sh
git commit -m "feat(recall): break match-count ties by updated: recency (#162)"
```

---

## Task 2: doctor.sh — scope-overlap cluster warnings

**Files:**
- Modify: `skills/woostack-init/scripts/doctor.sh` (`seen` setup; the scope/stale block; after the per-note loop; cleanup)
- Test: `skills/woostack-init/scripts/tests/test-doctor.sh`

- [x] **Step 1: Write the failing tests (isolated git fixture repo)**

The shared `$repo`/`$md` store already holds many `packages/api/**` notes that would all cluster; overlap tests MUST use their own git repo. Append after the dead-note block (before the `finish` at the end of `test-doctor.sh`):

```bash
# --- overlap clusters (own git repo: needs tracked files) ---
orepo="$(mktemp -d)"
( cd "$orepo" && git -c user.email=t@t -c user.name=t init -q \
    && mkdir -p packages/api apps/web && touch packages/api/x.ts apps/web/y.tsx \
    && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )
omd="$orepo/.woostack/memory"; mkdir -p "$omd"

# two notes matching the same tracked file → one cluster naming both (min-name order)
mk_note "$omd" c1.md $'name: c1\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02\nsource: pr-1' 'b'
mk_note "$omd" c2.md $'name: c2\ntype: gotcha\nscope: packages/api/orpc/**, packages/api/x.ts\nupdated: 2026-06-02\nsource: pr-2' 'b'
pushd "$orepo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_contains "$OUT" "overlap cluster: c1.md, c2.md" "two notes on a shared file form one cluster"
assert_exit 0 "$CODE" "overlap cluster is a warning (exit 0)"

# add a disjoint note (apps/web only) → not in the api cluster
mk_note "$omd" web.md $'name: web\ntype: pattern\nscope: apps/web/**\nupdated: 2026-06-02\nsource: pr-3' 'b'
pushd "$orepo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "web.md" "a disjoint-scope note is not clustered"
assert_contains "$OUT" "overlap cluster: c1.md, c2.md" "disjoint note does not disturb the api cluster"

# add a global note → never clustered
mk_note "$omd" g.md $'name: g\ntype: convention\nscope: *\nupdated: 2026-06-02\nsource: pr-4' 'b'
pushd "$orepo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "overlap cluster: c1.md, c2.md, g.md" "global note is exempt from clustering"

# add a third api note → single cluster of three, sorted
mk_note "$omd" c3.md $'name: c3\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02\nsource: pr-5' 'b'
pushd "$orepo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_contains "$OUT" "overlap cluster: c1.md, c2.md, c3.md" "three notes on a shared file form one sorted cluster"

# a stale note (matches no tracked file) is never clustered, only stale-warned
ostale="$(mktemp -d)"
( cd "$ostale" && git -c user.email=t@t -c user.name=t init -q \
    && mkdir -p packages/api && touch packages/api/x.ts \
    && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )
osmd="$ostale/.woostack/memory"; mkdir -p "$osmd"
mk_note "$osmd" real.md  $'name: real\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02\nsource: pr-1' 'b'
mk_note "$osmd" ghost.md $'name: ghost\ntype: pattern\nscope: zzz/**\nupdated: 2026-06-02\nsource: pr-2' 'b'
pushd "$ostale" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "overlap cluster" "a lone real note + a stale note form no cluster"
assert_contains "$OUT" "ghost.md: scope 'zzz/**' matches no tracked files (stale)" "stale note still stale-warned"

rm -rf "$orepo" "$ostale"
```

Note: the fixture notes carry `source:`/`updated:` so the #161 missing-source / missing-updated warnings don't add noise to `$OUT` that could confuse the `assert_not_contains` checks. `c2.md` uses a multi-glob scope including the literal `packages/api/x.ts`, guaranteeing it co-matches `c1.md` on that file.

- [x] **Step 2: Run to verify the new tests fail**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh`
Expected: FAIL on every `overlap cluster: …` assertion (no clustering implemented yet).

- [x] **Step 3: Add the pairs temp file to setup**

In `doctor.sh`, the setup block has `seen="$(mktemp)"`. Add a sibling temp file right after it:

```bash
seen="$(mktemp)"
overlap_pairs="$(mktemp)"
```

- [x] **Step 4: Capture matched files in the scope/stale block (replace, don't double, the scope-match call)**

The current block is:

```bash
  scope="$(field "$f" scope)"
  if [ -n "$scope" ] && [ "$scope" != "*" ] && [ -n "$paths" ]; then
    if ! printf '%s\n' "$paths" | bash "$HERE/scope-match.sh" "$scope" >/dev/null 2>&1; then
      warn "$base: scope '$scope' matches no tracked files (stale)"
    fi
  fi
```

Replace it with a single scope-match call whose output is captured and reused for both the stale signal and the overlap pairs:

```bash
  scope="$(field "$f" scope)"
  if [ -n "$scope" ] && [ "$scope" != "*" ] && [ -n "$paths" ]; then
    matches="$(printf '%s\n' "$paths" | bash "$HERE/scope-match.sh" "$scope" 2>/dev/null)"
    if [ -z "$matches" ]; then
      warn "$base: scope '$scope' matches no tracked files (stale)"
    else
      while IFS= read -r p; do
        [ -n "$p" ] && printf '%s\t%s\n' "$p" "$base" >> "$overlap_pairs"
      done <<< "$matches"
    fi
  fi
```

- [x] **Step 5: Emit cluster warnings after the per-note loop**

The loop ends with `done` then `rm -f "$seen"`. Insert the cluster block between them:

```bash
done

# Overlap clusters: non-global notes sharing >=1 tracked file. awk union-find,
# canonical cluster id = lexicographically smallest member name (deterministic
# output regardless of git ls-files / glob ordering). Warning-only.
if [ -s "$overlap_pairs" ]; then
  awk -F'\t' '
    function find(x,   r,t){ r=x; while(parent[r]!=r) r=parent[r];
      while(parent[x]!=x){ t=parent[x]; parent[x]=r; x=t } return r }
    function union(a,b,   ra,rb){ ra=find(a); rb=find(b); if(ra!=rb) parent[rb]=ra }
    { note=$2; if(!(note in parent)) parent[note]=note;
      f=$1; if(f in first) union(first[f], note); else first[f]=note }
    END{
      for(n in parent){ r=find(n); if(!(r in mn) || n < mn[r]) mn[r]=n }
      for(n in parent){ r=find(n); print mn[r] "\t" n }
    }
  ' "$overlap_pairs" | sort -u | awk -F'\t' '
    { members[$1] = members[$1] (members[$1]==""?"":", ") $2; cnt[$1]++ }
    END{ for(c in cnt) if(cnt[c] >= 2) print c "\t" members[c] }
  ' | sort | while IFS="$(printf '\t')" read -r _cid _members; do
    warn "overlap cluster: $_members — intersecting scope, review for contradiction"
  done
fi

rm -f "$seen" "$overlap_pairs"
```

(Replace the existing `rm -f "$seen"` line with the `rm -f "$seen" "$overlap_pairs"` above.)

How it works: the first awk unions notes that share a file and, for each component, emits `min-member<TAB>note` for every member; `sort -u` orders members within a component; the second awk groups by the canonical id and keeps only ≥2-member clusters; the final `sort` orders the cluster lines; the `while` loop turns each into a warning. A note that shares no file with any other never gets unioned → its component has one member → dropped by `cnt >= 2`.

- [x] **Step 6: Run to verify pass + no regressions**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh`
Expected: PASS — all overlap assertions green; the pre-existing stale-scope assertion still fires (the stale branch behavior is unchanged); every other assertion unaffected (the shared `$repo` store has tracked files but its notes are validated only via exit code / specific substrings — `overlap cluster` is a new substring not referenced by old assertions). If the shared store happens to emit an `overlap cluster` line, no existing `assert_not_contains` targets that string, so it is harmless.

- [x] **Step 7: Run the full init suite**

Run: `bash skills/woostack-init/scripts/tests/run-tests.sh`
Expected: every `test-*.sh` reports `0 failed`; runner exits 0.

- [x] **Step 8: Commit**

```bash
git add skills/woostack-init/scripts/doctor.sh skills/woostack-init/scripts/tests/test-doctor.sh
git commit -m "feat(doctor): warn on scope-overlap clusters of memory notes (#162)"
```

---

## Task 3: memory.md — document overlap warning (§8) + recency tiebreak (§6)

**Files:**
- Modify: `skills/woostack-init/references/memory.md` (§6 Recall Procedure, §8 Scripts staleness warnings)

- [x] **Step 1: Document the recency tiebreak in §6**

In `## 6. Recall Procedure`, step 3 currently ends describing scope-match load. Append a sentence to step 3 (the scope-match step):

```markdown
   When two matched notes have the **same** match-count, the tie is broken by `updated:` recency — the newer note ranks first, and a note without `updated:` ranks last (so under cap pressure the older / undated note is dropped first). Match-count remains the primary key.
```

- [x] **Step 2: Document the overlap-cluster warning in §8**

In `## 8. Scripts`, in the **Staleness warnings** list, add after the existing bullets:

```markdown
- **Overlap cluster:** non-global notes whose `scope:` globs match at least one common tracked file are grouped into a cluster and flagged for human review (`overlap cluster: a.md, b.md — intersecting scope, review for contradiction`). doctor cannot judge whether the advice actually contradicts — it surfaces the co-load so a human can. Global notes (`*`/absent) co-load with everything by design and are exempt; a note whose scope matches no tracked file is stale, not clustered. Overlap is measured by shared tracked files (via `scope-match.sh`), so it is skipped when there is no git repo.
```

- [x] **Step 3: Verify + commit**

Run: `grep -n "Overlap cluster\|broken by .updated. recency" skills/woostack-init/references/memory.md`
Expected: both additions present.

```bash
git add skills/woostack-init/references/memory.md
git commit -m "docs(memory): document overlap-cluster warning + recall recency tiebreak (#162)"
```

---

## Self-review (done while writing)

- **Spec coverage:** Part 1 doctor overlap → Task 2 (capture/emit/awk union-find/min-id/cluster warn). Part 2 recall tiebreak → Task 1. §6/§8 docs → Task 3. Testing §7 → Task 1 + Task 2 tests (isolated git repo for overlap; per-fixture recall ties). All covered.
- **Determinism:** min-member canonical id + `sort` on both awk output and final cluster lines → stable warning strings, asserted exactly.
- **No doubled work:** Task 2 Step 4 *replaces* the stale-scope `scope-match >/dev/null` with a single captured call; the stale branch behavior is byte-identical.
- **Non-goals respected:** no glob-string math; no pairwise output; no auto-resolution; recall primary key unchanged; linked/global ordering untouched.
- **bash 3.2 / BSD:** no `declare -A` (awk owns the assoc arrays); here-string `<<<` and `printf '\t'` delimiters are 3.2-safe; awk uses only basic arrays + `split`-free union-find.
- **No placeholders:** every code + command step is concrete.
```
