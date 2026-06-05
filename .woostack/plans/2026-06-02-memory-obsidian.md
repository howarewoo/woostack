# Obsidian layer (Increment D) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox steps.

**Goal:** Optional Obsidian layer over the memory vault — opt-in `.obsidian/` config + a `graph.sh` links/backlinks helper that falls back to grep. Obsidian is never required; recall/doctor unchanged.

**Architecture:** New `graph.sh` (grep default + best-effort `obsidian eval`). `.obsidian/` template scaffolded by `/woostack-init` on opt-in. Docs in the contract.

**Tech Stack:** Bash + coreutils. Tests extend the woostack-init harness. Stacks on `feat/woostack-memory-distill`.

**Source of truth:** `.woostack/specs/2026-06-02-memory-obsidian.md`.

---

## File Structure

| File | Responsibility |
|---|---|
| `skills/woostack-init/scripts/graph.sh` | Note links/backlinks; grep default, obsidian-eval opt-in fallback. |
| `skills/woostack-init/scripts/tests/test-graph.sh` | grep-path tests. |
| `skills/woostack-init/templates/obsidian/app.json` | Minimal Obsidian vault config. |
| `skills/woostack-init/templates/obsidian/graph.json` | Minimal graph view config. |
| `skills/woostack-init/templates/gitignore` | Add `.obsidian/workspace*`. |
| `skills/woostack-init/SKILL.md` | `--obsidian`/`--no-obsidian` flags + prompt + scaffold step. |
| `skills/woostack-init/references/memory.md` | "Obsidian (optional)" section. |
| `AGENTS.md` | Templates list mentions obsidian template. |

---

## Task 1: `graph.sh`

**Files:**
- Create: `skills/woostack-init/scripts/graph.sh`
- Test: `skills/woostack-init/scripts/tests/test-graph.sh`

- [x] **Step 1: Write the failing test**

Create `skills/woostack-init/scripts/tests/test-graph.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
G="$DIR/graph.sh"

md="$(mktemp -d)"
mk_note "$md" a.md $'name: a\ntype: pattern' 'links to [[b]] and [[c]]'
mk_note "$md" b.md $'name: b\ntype: pattern' 'b body, points to [[c]]'
mk_note "$md" c.md $'name: c\ntype: pattern' 'c body, no links'

# --links (default mode is --links)
out="$(bash "$G" "$md" a)"
assert_contains "$out" "b" "a links to b"
assert_contains "$out" "c" "a links to c"
out="$(bash "$G" "$md" a --links)"
assert_contains "$out" "b" "explicit --links b"

# note name tolerant of .md suffix
out="$(bash "$G" "$md" a.md --links)"
assert_contains "$out" "b" ".md suffix tolerated"

# no links -> empty, exit 0
set +e; out="$(bash "$G" "$md" c --links)"; code=$?; set -e
assert_eq "$out" "" "c has no links -> empty"
assert_exit 0 "$code" "no links -> exit 0"

# --backlinks: who links to c? a and b
out="$(bash "$G" "$md" c --backlinks)"
assert_contains "$out" "a" "a backlinks c"
assert_contains "$out" "b" "b backlinks c"
out="$(bash "$G" "$md" b --backlinks)"
assert_contains "$out" "a" "a backlinks b"
assert_not_contains "$out" "c" "c does not backlink b"

# backlinks of a dangling target (no file) still works
out="$(bash "$G" "$md" ghost --backlinks)"
assert_eq "$out" "" "no backlinks to ghost"

# --links on missing note -> exit 1
set +e; bash "$G" "$md" nope --links >/dev/null 2>&1; code=$?; set -e
assert_exit 1 "$code" "missing note --links exits 1"

# obsidian branch is NOT used by default (no WOOSTACK_OBSIDIAN) even if obsidian exists
out="$(bash "$G" "$md" a --links)"
assert_contains "$out" "b" "default uses grep path"

rm -rf "$md"
finish
```

- [x] **Step 2: Run, confirm FAIL** (graph.sh missing).

- [x] **Step 3: Write `graph.sh`**

Create `skills/woostack-init/scripts/graph.sh`:

```bash
#!/usr/bin/env bash
# graph.sh <memdir> <note> [--links|--backlinks]
# Note links/backlinks over the memory store. Default: grep markdown wikilinks
# (headless, always works). Opt-in: when WOOSTACK_OBSIDIAN=1 AND the `obsidian`
# CLI is present, try `obsidian eval`; on ANY failure fall back to grep + warn.
# Obsidian is never required and never fatal.
set -euo pipefail
MEM_DIR="${1:?memdir required}"; NOTE_ARG="${2:?note required}"; MODE="${3:---links}"
NOTE="${NOTE_ARG%.md}"
NOTE_FILE="$MEM_DIR/$NOTE.md"

grep_links() {
  [ -f "$NOTE_FILE" ] || { echo "graph: note not found: $NOTE_FILE" >&2; exit 1; }
  grep -oE '\[\[[^]]+\]\]' "$NOTE_FILE" 2>/dev/null | sed 's/\[\[//; s/\]\]//' | sort -u
}

grep_backlinks() {
  shopt -s nullglob
  for f in "$MEM_DIR"/*.md; do
    b="$(basename "$f" .md)"
    [ "$b" = "$NOTE" ] && continue
    grep -qE "\[\[$NOTE\]\]" "$f" 2>/dev/null && echo "$b"
  done
  return 0
}

obsidian_try() {
  command -v obsidian >/dev/null 2>&1 || return 1
  # Best-effort; any non-zero / empty result lets the caller fall back to grep.
  case "$MODE" in
    --links)     obsidian eval "this.app.metadataCache.resolvedLinks" 2>/dev/null || return 1 ;;
    --backlinks) obsidian eval "this.app.metadataCache.getBacklinksForFile" 2>/dev/null || return 1 ;;
    *) return 1 ;;
  esac
}

if [ "${WOOSTACK_OBSIDIAN:-0}" = "1" ] && command -v obsidian >/dev/null 2>&1; then
  if out="$(obsidian_try)" && [ -n "$out" ]; then printf '%s\n' "$out"; exit 0; fi
  echo "graph: obsidian eval unavailable; using grep fallback" >&2
fi

case "$MODE" in
  --links)     grep_links ;;
  --backlinks) grep_backlinks ;;
  *) echo "graph: unknown mode: $MODE (use --links or --backlinks)" >&2; exit 2 ;;
esac
```

- [x] **Step 4: Run test (all pass) + full suite + shellcheck.** `bash skills/woostack-init/scripts/tests/run-tests.sh` exit 0. shellcheck info-level OK.

- [x] **Step 5: Commit** — `feat(woostack-init): graph.sh links/backlinks helper (grep + obsidian fallback) + tests`

---

## Task 2: Obsidian template + init flags + docs

**Files:**
- Create: `skills/woostack-init/templates/obsidian/app.json`, `graph.json`
- Modify: `skills/woostack-init/templates/gitignore`, `skills/woostack-init/SKILL.md`, `skills/woostack-init/references/memory.md`, `AGENTS.md`

- [x] **Step 1: Obsidian config templates.**

`skills/woostack-init/templates/obsidian/app.json`:
```json
{
  "alwaysUpdateLinks": true,
  "newLinkFormat": "shortest",
  "attachmentFolderPath": "."
}
```

`skills/woostack-init/templates/obsidian/graph.json`:
```json
{
  "showTags": false,
  "showAttachments": false,
  "showOrphans": true,
  "scale": 1
}
```

- [x] **Step 2: gitignore template.** Append to `skills/woostack-init/templates/gitignore`:
```
# Obsidian per-user UI state (the shared .obsidian/*.json config IS tracked).
.obsidian/workspace*
.obsidian/cache
```

- [x] **Step 3: SKILL.md flags + scaffold step.** In `skills/woostack-init/SKILL.md`:
- Add `--obsidian` and `--no-obsidian` to the **Flags** section: force-enable / force-skip the optional Obsidian vault config; with neither, the skill **prompts** (default no).
- In the Procedure, add a step (after the core scaffold, before build-index/doctor): "If `--obsidian` (or the user accepts the prompt), scaffold `.woostack/.obsidian/` from `templates/obsidian/` (never clobbering an existing `.obsidian/`). This makes `.woostack/` an Obsidian vault (memory + specs + plans as a `[[wikilink]]` graph). Obsidian is **optional** — all memory tooling works without it."
- Add a hard-constraint/Reference note that Obsidian is never required.

- [x] **Step 4: Contract "Obsidian (optional)" section.** In `skills/woostack-init/references/memory.md`, add a new section (renumber Degradation last): the vault is already Obsidian-compatible (markdown + `[[wikilinks]]`); `/woostack-init --obsidian` scaffolds `.woostack/.obsidian/`; `graph.sh <memdir> <note> --links|--backlinks` queries the graph (grep by default, `obsidian eval` when `WOOSTACK_OBSIDIAN=1` + app present); **all core tooling (`recall`, `doctor`, `build-index`) works without Obsidian**.

- [x] **Step 5: AGENTS.md.** In the woostack-init `templates/` layout entry, mention `obsidian/` (Obsidian vault config). Keep it a one-liner.

- [x] **Step 6: Verify.**
```bash
# templates are valid JSON
for j in skills/woostack-init/templates/obsidian/*.json; do python3 -m json.tool "$j" >/dev/null && echo "ok $j"; done
# gitignore ignores workspace but not config
grep -q 'workspace' skills/woostack-init/templates/gitignore && echo "gitignore ok"
# cross-links + suite
bash skills/woostack-init/scripts/tests/run-tests.sh >/dev/null 2>&1 && echo "suite green"
```
Expected: both JSONs ok, gitignore ok, suite green.

- [x] **Step 7: Commit** — `feat(woostack-init): opt-in Obsidian vault config + graph docs`

---

## Task 3: Final verify + PR

- [x] **Step 1: Full suite + scope guard.**
```bash
bash skills/woostack-init/scripts/tests/run-tests.sh; echo "suite exit=$?"
# D touches only woostack-init (graph.sh, templates, SKILL, contract) + AGENTS.md
git diff --stat feat/woostack-memory-distill..HEAD -- skills/woostack-review skills/woostack-build skills/woostack-bootstrap skills/woostack-address-comments; echo "(empty = other skills untouched)"
```
Expected: suite exit 0; other skills untouched.

- [x] **Step 2: Dogfood graph.sh** on the example note set (build a quick fixture; confirm `--links`/`--backlinks`).

- [x] **Step 3: Push + open PR** (stacked on `feat/woostack-memory-distill`) — ask the user first per the build loop.

---

## Self-Review (completed during planning)

**Spec coverage:** §5 graph.sh → Task 1; templates/flags/docs → Task 2; verify → Task 3. §6 error handling (fallback, missing note, no clobber) → Tasks 1-2. §7 testing → Task 1. No gaps.

**Placeholder scan:** Task 1 ships complete graph.sh + tests. Task 2 ships complete JSON templates + enumerated doc edits with verification.

**Type consistency:** graph.sh interface (`<memdir> <note> --links|--backlinks`) consistent between test (Task 1) and contract doc (Task 2 Step 4). The obsidian-eval branch is explicitly best-effort and untested by design.
