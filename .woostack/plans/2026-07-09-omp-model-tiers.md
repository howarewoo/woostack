---
type: plan
source: .woostack/specs/2026-07-09-omp-model-tiers.md
status: executing
date: 2026-07-09
branch: feature/omp-model-tiers
links:
  - "[[2026-07-09-omp-model-tiers]]"
---
**Source:** [[specs/2026-07-09-omp-model-tiers]]

# omp host support for woostack model tiers - Implementation Plan

**Goal:** make woostack subagents obey the `fast | standard | deep` tier system when
running under omp (Oh My Pi), whose `task` tool exposes no per-call model/effort override.
Approved design (Option A, spec §3): a `gen-omp-agents.sh` generator bakes
`.woostack/config.json` `models.<tier>` into three generated agent-defs
`.omp/agents/woostack-{fast,standard,deep}.md` (`model` + `thinkingLevel`, general-purpose
worker, `tools` omitted so the full default worker set is inherited); the dispatch skills
select `agent: woostack-<effective-tier>` per spawn. `.woostack/config.json` flat
`models.<tier>` stays the single source of truth; `woostack-init` scaffolds the defs,
`woostack-doctor` regenerates on drift, and the defs are gitignored.

## Architecture

```
.woostack/config.json  (models.<tier> - single source of truth)
        |
        v
skills/woostack-init/scripts/gen-omp-agents.sh   (generation authority)
        |  reads config, resolves PRIMARY root, maps effort->thinkingLevel,
        |  guards model slug, writes 3 defs + adjacent .gitignore
        v
<primary-root>/.omp/agents/woostack-{fast,standard,deep}.md   (gitignored)
        ^                                   ^                        ^
        |                                   |                        |
  woostack-init                    woostack-doctor            woostack-execute /
  (scaffold: run once)         (--fix: regenerate on drift)   -commit / -review
                                                              (dispatch agent:
                                                               woostack-<tier>)
```

Three callers, one generator (wisdom: `autonomy-needs-structural-proof` - one authority,
no drift). Dispatch is agent-by-tier because omp has **no per-call model knob** on `task`
(`subagent-driver.md:122-135`; omp `task-agent-discovery.md` / `models.md`).

## Increment order & dependencies

Linear Graphite stack (no tracks). The structural lockstep test (Increment 5) enumerates
every omp-host edit site and MUST land last, after all sites exist, or it fails prematurely.

1. Generator authority + gitignore (the source of truth for every later site).
2. Canonical `model-tiers.md` omp bucket + `woostack-init` scaffold caller.
3. `woostack-doctor` drift check + test + catalog.
4. Dispatch wiring: `woostack-execute` + `woostack-commit` + `woostack-review` (local).
5. Docs-site sync + structural lockstep test.

## Testing note (this repo)

There is no app test harness. "Failing test first" = a concrete verification command whose
expected output is stated. Shell unit tests use the existing
`skills/woostack-init/scripts/tests/assert.sh` helpers (`assert_eq`, `assert_contains`,
`assert_not_contains`, `assert_exit`, `finish`) and the doctor arg/`emit` contract
(`sev<TAB>code<TAB>fixable<TAB>path<TAB>msg`). omp spawn behavior (agent-def load, tool
inheritance) cannot be unit-tested in bash; it is an execution-time probe (Increment 1, V1).

---

## Increment 1 - Generator authority + gitignore

**Ships:** the single generation authority + its ignore mechanism, fully tested standalone.
**Files:**
- Create `skills/woostack-init/scripts/gen-omp-agents.sh`
- Create `skills/woostack-init/scripts/tests/test-gen-omp-agents.sh`
- Edit repo-root `.gitignore` (dogfood: ignore this repo's own generated defs)

**Spec coverage:** AC1 (emitted frontmatter: string leaf, object leaf, unset), AC2
(idempotent; worktree cwd -> primary root), AC3 (effort->thinkingLevel; empty/garbage
effort -> tier default), AC4 (git check-ignore ignores `woostack-*.md`, keeps `custom.md`).

**Deviation from spec §5 (gitignore mechanism) - flag:** spec §5 lists
`skills/woostack-init/templates/gitignore` as edited. That template renders
`.woostack/.gitignore` (scoped to `.woostack/`); it **cannot** ignore repo-root
`.omp/agents/`, and `woostack-init` is hard-constrained never to write outside `.woostack/`
(so it can't touch the repo-root `.gitignore`). Editing that template would be a **dead,
never-matching** line. Instead the **generator writes an adjacent
`.omp/agents/.gitignore` containing `woostack-*.md`** (surgical, portable to consumers,
respects init's constraint), and this repo gets a root-`.gitignore` dogfood entry. The
component's GOAL (generated defs never committed) is met; the no-op template edit is
intentionally skipped.

- [x] **Step 1.1 (RED) - write the generator test first**

Create `skills/woostack-init/scripts/tests/test-gen-omp-agents.sh`:

```bash
#!/usr/bin/env bash
# Tests for gen-omp-agents.sh: config leaf shapes -> agent-def frontmatter,
# effort->thinkingLevel, idempotency, worktree->primary-root, gitignore scope.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/assert.sh"
GEN="$HERE/../gen-omp-agents.sh"

mkcfg() { # <root> <models-json>
  mkdir -p "$1/.woostack"
  printf '{ "models": %s }\n' "$2" > "$1/.woostack/config.json"
}

# --- AC1 string leaf -> model + tier-default thinkingLevel ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": "google/gemini-3-5-flash" }'
WOOSTACK_ROOT="$r" bash "$GEN"
f="$r/.omp/agents/woostack-fast.md"
assert_eq "$([ -f "$f" ] && echo y)" "y" "AC1 string: fast def written"
assert_contains "$(cat "$f")" 'model: "google/gemini-3-5-flash"' "AC1 string: model line"
assert_contains "$(cat "$f")" 'thinkingLevel: low' "AC1 string: fast default effort=low"
assert_contains "$(cat "$f")" 'name: woostack-fast' "AC1 string: name"

# --- AC1/AC3 object leaf -> model + configured effort ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "deep": { "model": "anthropic/claude-opus-4-8", "effort": "xhigh" } }'
WOOSTACK_ROOT="$r" bash "$GEN"
f="$r/.omp/agents/woostack-deep.md"
assert_contains "$(cat "$f")" 'model: "anthropic/claude-opus-4-8"' "AC1 object: model line"
assert_contains "$(cat "$f")" 'thinkingLevel: xhigh' "AC3 object: configured effort"

# --- AC1 unset tier -> no model line, thinkingLevel-only (tier default) ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{}'
WOOSTACK_ROOT="$r" bash "$GEN"
f="$r/.omp/agents/woostack-standard.md"
assert_eq "$([ -f "$f" ] && echo y)" "y" "AC1 unset: standard def still written"
assert_not_contains "$(cat "$f")" 'model:' "AC1 unset: no model line"
assert_contains "$(cat "$f")" 'thinkingLevel: medium' "AC1 unset: standard default=medium"

# --- AC3 empty effort string -> tier default (not empty) ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": { "model": "x/y", "effort": "" } }'
WOOSTACK_ROOT="$r" bash "$GEN"
assert_contains "$(cat "$r/.omp/agents/woostack-fast.md")" 'thinkingLevel: low' "AC3 empty effort -> default"

# --- AC3 error: garbage effort -> tier default ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "deep": { "model": "x/y", "effort": "turbo" } }'
WOOSTACK_ROOT="$r" bash "$GEN" 2>/dev/null
assert_contains "$(cat "$r/.omp/agents/woostack-deep.md")" 'thinkingLevel: xhigh' "AC3 garbage effort -> default"

# --- AC1 error: malformed leaf (number) -> tier unset, no crash ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": 42 }'
WOOSTACK_ROOT="$r" bash "$GEN" 2>/dev/null
rc=$?
assert_exit 0 "$rc" "AC1 malformed leaf: exit 0 (best-effort)"
assert_not_contains "$(cat "$r/.omp/agents/woostack-fast.md")" 'model:' "AC1 malformed: tier unset"

# --- AC1 error: injection attempt in slug -> rejected, tier unset ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": "x/y\"\nmalicious: true" }'
WOOSTACK_ROOT="$r" bash "$GEN" 2>/dev/null
assert_not_contains "$(cat "$r/.omp/agents/woostack-fast.md")" 'malicious' "AC1 injection: rejected"

# --- AC2 idempotency: two runs byte-identical ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "standard": "openai/gpt-5.5" }'
WOOSTACK_ROOT="$r" bash "$GEN"; a="$(cat "$r/.omp/agents/woostack-standard.md")"
WOOSTACK_ROOT="$r" bash "$GEN"; b="$(cat "$r/.omp/agents/woostack-standard.md")"
assert_eq "$a" "$b" "AC2 idempotent: identical output"

# --- AC2 edge: run from a worktree cwd, no WOOSTACK_ROOT -> primary root ---
r="$(mktemp -d)"; ( cd "$r" && git init -q && git commit -q --allow-empty -m init )
mkcfg "$r" '{ "fast": "p/q" }'
wt="$(mktemp -d)"; ( cd "$r" && git worktree add -q "$wt" -b wt-branch )
( cd "$wt" && bash "$GEN" )
assert_eq "$([ -f "$r/.omp/agents/woostack-fast.md" ] && echo y)" "y" "AC2 worktree: def at primary root"
assert_eq "$([ -f "$wt/.omp/agents/woostack-fast.md" ] && echo n || echo n)" "n" "AC2 worktree: not in worktree tree"

# --- AC4 gitignore: generated def ignored, custom def tracked ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": "p/q" }'
WOOSTACK_ROOT="$r" bash "$GEN"
touch "$r/.omp/agents/custom.md"
ig="$(cd "$r" && git check-ignore .omp/agents/woostack-fast.md; echo $?)"
assert_contains "$ig" ".omp/agents/woostack-fast.md" "AC4: generated def ignored"
cst=$(cd "$r" && git check-ignore .omp/agents/custom.md >/dev/null 2>&1; echo $?)
assert_eq "$cst" "1" "AC4: custom.md NOT ignored"

finish
```

Run: `bash skills/woostack-init/scripts/tests/test-gen-omp-agents.sh`
Expected (RED): fails because `gen-omp-agents.sh` does not exist yet (non-zero exit,
`No such file`).

- [x] **Step 1.2 (GREEN) - implement the generator**

Create `skills/woostack-init/scripts/gen-omp-agents.sh`:

```bash
#!/usr/bin/env bash
# gen-omp-agents.sh - bake .woostack/config.json models.<tier> into omp agent-defs
#   <primary-root>/.omp/agents/woostack-{fast,standard,deep}.md
# Single generation authority; callers: woostack-init (scaffold), woostack-doctor
# (--fix), woostack-execute (safety-net). Idempotent (overwrite). Best-effort + loud:
# a malformed/unsafe leaf -> that tier unset (thinkingLevel-only) + stderr warn, exit 0.
# woostack-defer(increment 4): callers wired in increments 2-4 (init, doctor --fix, execute).
set -uo pipefail

# --- primary-root resolution (worktree contract; mirrors resolve-root.sh) ---
# Precedence: WOOSTACK_ROOT > git-common-dir parent (primary root from any worktree) > pwd.
resolve_root() {
  if [ -n "${WOOSTACK_ROOT:-}" ]; then
    ( cd "$WOOSTACK_ROOT" 2>/dev/null && pwd -P ) || printf '%s\n' "$WOOSTACK_ROOT"
    return
  fi
  local cg
  cg="$(git rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -n "$cg" ]; then
    ( cd "$cg/.." 2>/dev/null && pwd -P ) && return
  fi
  pwd -P
}

ROOT="$(resolve_root)"
CFG="$ROOT/.woostack/config.json"
OUT_DIR="${WOO_OMP_AGENTS_DIR:-$ROOT/.omp/agents}"

command -v jq >/dev/null 2>&1 || { echo "gen-omp-agents.sh: jq not found; skipping" >&2; exit 0; }
mkdir -p "$OUT_DIR"

# gitignore generated defs (scoped: woostack-*.md only; a consumer's own custom.md stays tracked)
ignore="$OUT_DIR/.gitignore"
if ! [ -f "$ignore" ] || ! grep -qxF 'woostack-*.md' "$ignore" 2>/dev/null; then
  printf '%s\n' 'woostack-*.md' >> "$ignore"
fi

# omp thinkingLevel enum (verified: omp models.md). woostack effort maps 1:1 (+ off).
valid_effort() { case "$1" in off|minimal|low|medium|high|xhigh) return 0 ;; *) return 1 ;; esac; }
default_effort() { case "$1" in fast) echo low ;; standard) echo medium ;; deep) echo xhigh ;; esac; }
# model slug charset guard -> no YAML metachars/newlines -> no frontmatter injection
safe_slug() { printf '%s' "$1" | grep -qE '^[A-Za-z0-9][A-Za-z0-9._/:+-]*$'; }

render_tier() {
  local tier="$1" leaf ltype model effort tl f
  if [ -f "$CFG" ]; then
    leaf="$(jq -c --arg t "$tier" '(.models // {})[$t] // null' "$CFG" 2>/dev/null || echo null)"
  else
    leaf="null"
  fi
  ltype="$(printf '%s' "$leaf" | jq -r 'type' 2>/dev/null || echo null)"
  model=""; effort=""
  case "$ltype" in
    string)
      model="$(printf '%s' "$leaf" | jq -r '.')"
      [ -n "$model" ] || echo "gen-omp-agents.sh: $tier: empty string leaf; tier unset" >&2
      ;;
    object)
      model="$(printf '%s' "$leaf" | jq -r '.model // ""')"
      effort="$(printf '%s' "$leaf" | jq -r '.effort // ""')"
      [ -n "$model" ] || echo "gen-omp-agents.sh: $tier: object leaf missing .model; tier unset" >&2
      ;;
    null) : ;;
    *) echo "gen-omp-agents.sh: $tier: malformed leaf ($ltype); tier unset" >&2 ;;
  esac

  if [ -n "$model" ] && ! safe_slug "$model"; then
    echo "gen-omp-agents.sh: $tier: unsafe model slug; tier unset" >&2
    model=""
  fi

  if [ -n "$effort" ] && valid_effort "$effort"; then
    tl="$effort"
  else
    [ -n "$effort" ] && echo "gen-omp-agents.sh: $tier: effort '$effort' not in enum; using tier default" >&2
    tl="$(default_effort "$tier")"
  fi

  f="$OUT_DIR/woostack-$tier.md"
  {
    printf -- '---\n'
    printf 'name: woostack-%s\n' "$tier"
    printf 'description: woostack %s-tier general-purpose worker (generated from .woostack/config.json; edits are overwritten).\n' "$tier"
    [ -n "$model" ] && printf 'model: "%s"\n' "$model"
    printf 'thinkingLevel: %s\n' "$tl"
    printf -- '---\n\n'
    printf 'You are a general-purpose woostack worker running at the %s tier. The task you receive on\n' "$tier"
    printf 'the role / context / assignment fields is authoritative - do exactly what it specifies; it\n'
    printf 'carries the full context you need. Do not load skill://woostack-review or route through\n'
    printf 'using-woostack.\n'
  } > "$f"
}

for tier in fast standard deep; do render_tier "$tier"; done
```

Run: `bash skills/woostack-init/scripts/tests/test-gen-omp-agents.sh`
Expected (GREEN): `N passed, 0 failed`, exit 0.

- [x] **Step 1.3 - repo-root gitignore dogfood entry**

Edit repo-root `.gitignore`: append
```
# generated omp tier agent-defs (see skills/woostack-init/scripts/gen-omp-agents.sh)
.omp/agents/woostack-*.md
```
Verify (after generator runs in this repo): `git check-ignore .omp/agents/woostack-fast.md`
prints the path (exit 0); `git check-ignore .omp/agents/custom.md` exits 1.

- [x] **Step 1.4 (V1, execution-time probe - non-blocking) - confirm the agent-def shape loads under omp**

The def puts the worker instructions in the **body** (systemPrompt) with `name`/`model`/
`thinkingLevel` in frontmatter - matching omp's bundled `task`/`sonic` ("body plus injected
frontmatter", `task-agent-discovery.md`), and omits `tools` to inherit omp's full default
worker set (`tools/task.md:92`: no-`tools` default = full worker set). Confirm empirically
(we run under omp): generate defs, then `task` a throwaway `agent: woostack-fast` with a
trivial "echo OK and read one file" assignment. Pass iff it (a) loads (no "Unknown agent")
and (b) can use `read`/`bash`/`edit` (tools inherited).
**Fallback if body-as-systemPrompt is rejected:** emit the body as a frontmatter block
scalar (`systemPrompt: |`) instead; re-run the probe. Record the outcome in the increment PR.

**Verification (increment):** `bash .../test-gen-omp-agents.sh` green; `bash -n gen-omp-agents.sh`;
`git check-ignore` dogfood check; V1 probe result noted.

---

## Increment 2 - Canonical `model-tiers.md` omp bucket + `woostack-init` scaffold caller

**Ships:** the host-taxonomy documentation bucket for omp + the scaffold caller.
**Files:**
- Edit `skills/using-woostack/references/model-tiers.md`
- Edit `skills/woostack-init/SKILL.md`

**Spec coverage:** AC8 (bucket present; provider table columns unchanged), §4.1/§4.4.

- [x] **Step 2.1 (RED) - assert the bucket & column-stability before writing**

Command: `grep -c 'agent-by-tier' skills/using-woostack/references/model-tiers.md`
Expected (RED): `0`.

- [x] **Step 2.2 (GREEN) - add the omp host bucket to model-tiers.md**

Below the four-provider table (leave the table's column header **byte-unchanged**:
`| Tier | Use for | Anthropic | OpenAI (Codex) | Google (Gemini) | OpenRouter |`), add a new
subsection. Use the exact token `agent-by-tier` (pinned by the Increment 5 lockstep test):

> **Per-call routing via agent-by-tier (omp / Oh My Pi).** omp's `task` tool has **no
> per-call `model`/`tier`/`effort` argument**, so per-spawn tier routing is not available.
> Instead, omp resolves a subagent's model from the **agent definition** (`model` +
> `thinkingLevel`). woostack ships three generated defs
> `.omp/agents/woostack-{fast,standard,deep}.md` (from `.woostack/config.json` via
> `skills/woostack-init/scripts/gen-omp-agents.sh`) and the driver selects
> `agent: woostack-<effective-tier>` per spawn - **agent-by-tier** routing. This is a
> routing pattern over the existing flat `models.<tier>` config, **not a fifth provider
> column** and **not a new config key**. An unset tier -> `thinkingLevel`-only def
> (fast->low, standard->medium, deep->xhigh) inheriting the session model. woostack effort
> (`minimal|low|medium|high|xhigh`) maps 1:1 to omp `thinkingLevel` (which also allows
> `off`).
>
> **Cross-consumer coexistence.** On CI/single-session hosts the flat provider table above
> and `resolve-model.sh` are untouched; the omp bucket is informational only. A consumer
> can still set provider-specific columnar models for those hosts.

- [x] **Step 2.3 (GREEN) - woostack-init scaffold caller**

Edit `skills/woostack-init/SKILL.md`: in the scaffolding steps, add that when running under
omp (host applies its own capability knowledge), init runs
`skills/woostack-init/scripts/gen-omp-agents.sh` after writing `config.json`, so the
generated tier defs exist on first run. Note the defs are gitignored (generator writes
`.omp/agents/.gitignore`).

**Verification:** `grep -c 'agent-by-tier' .../model-tiers.md` = 1; provider table header
line byte-present (`grep -F '| Tier | Use for | Anthropic | OpenAI (Codex) | Google (Gemini) | OpenRouter |'`);
init SKILL references `gen-omp-agents.sh`.

---

## Increment 3 - `woostack-doctor` drift check + test + catalog

**Ships:** the drift guard that keeps generated defs in sync with config.
**Files:**
- Create `skills/woostack-doctor/scripts/checks/omp-agents.sh`
- Create `skills/woostack-doctor/scripts/tests/test-omp-agents.sh`
- Edit `skills/woostack-doctor/references/checks.md` (add catalog row)

**Spec coverage:** AC5 (diagnose warns on missing/drift; `--fix` regenerates; gated on
`.omp/` existing - silent otherwise).

### Step 3.1 (RED) - write the check test first

Create `skills/woostack-doctor/scripts/tests/test-omp-agents.sh` (mirrors
`test-review-models-moved.sh`: sources init `assert.sh`, drives the check as diagnose &
`--fix`):

```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../woostack-init/scripts/tests/assert.sh"
CHK="$HERE/../checks/omp-agents.sh"
GEN="$HERE/../../../woostack-init/scripts/gen-omp-agents.sh"

# no .omp/ -> silent, exit 0 (not an omp workspace)
r="$(mktemp -d)"; mkdir -p "$r/.woostack"; printf '{}' > "$r/.woostack/config.json"
out="$(bash "$CHK" "$r")"; rc=$?
assert_exit 0 "$rc" "no .omp: exit 0"
assert_eq "$out" "" "no .omp: silent"

# .omp/ present, defs missing -> warn
r="$(mktemp -d)"; mkdir -p "$r/.woostack" "$r/.omp/agents"
printf '{ "models": { "fast": "p/q" } }' > "$r/.woostack/config.json"
out="$(bash "$CHK" "$r")"
assert_contains "$out" "omp-agents-missing" "missing def -> warn"

# --fix -> regenerates, then diagnose is silent
bash "$CHK" --fix "$r" >/dev/null 2>&1
out="$(bash "$CHK" "$r")"
assert_eq "$out" "" "after --fix: no drift"

# drift (hand-edit a def) -> warn
echo "tampered" >> "$r/.omp/agents/woostack-fast.md"
out="$(bash "$CHK" "$r")"
assert_contains "$out" "omp-agents-drift" "tampered def -> drift warn"

finish
```

Run: `bash skills/woostack-doctor/scripts/tests/test-omp-agents.sh`
Expected (RED): fails - `omp-agents.sh` missing.

### Step 3.2 (GREEN) - implement the check

Create `skills/woostack-doctor/scripts/checks/omp-agents.sh` (arg/`emit` contract copied
from `config-keys.sh`; auto-discovered by `doctor.sh`'s `checks/*.sh` loop - no `doctor.sh`
edit):

```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
if [ "${1:-}" = "--fix" ]; then FIX=1; WOO_ROOT="${2:-.}"; else FIX=0; WOO_ROOT="${1:-.}"; fi
GEN="$HERE/../../../woostack-init/scripts/gen-omp-agents.sh"
[ -d "$WOO_ROOT/.omp" ] || exit 0          # not an omp workspace -> silent
[ -f "$GEN" ] || exit 0
if [ "$FIX" -eq 1 ]; then
  WOOSTACK_ROOT="$WOO_ROOT" bash "$GEN" >/dev/null 2>&1 || true
  exit 0
fi
tmp="$(mktemp -d)"
WOOSTACK_ROOT="$WOO_ROOT" WOO_OMP_AGENTS_DIR="$tmp" bash "$GEN" >/dev/null 2>&1 || true
for want in "$tmp"/woostack-*.md; do
  [ -e "$want" ] || continue
  base="$(basename "$want")"; have="$WOO_ROOT/.omp/agents/$base"
  if [ ! -f "$have" ]; then
    emit warn omp-agents-missing auto "$have" "generated omp tier def missing"
  elif ! diff -q "$want" "$have" >/dev/null 2>&1; then
    emit warn omp-agents-drift auto "$have" "generated omp tier def drifted from .woostack/config.json"
  fi
done
rm -rf "$tmp"
```

### Step 3.3 (GREEN) - catalog row

Edit `skills/woostack-doctor/references/checks.md`: add a catalog row for `omp-agents.sh` -
severity `warn`, fixable `auto`, codes `omp-agents-missing` / `omp-agents-drift`, repair args
`omp-agents --fix <WOO_ROOT>`, gated on `.omp/` (silent otherwise).

**Verification:** `bash skills/woostack-doctor/scripts/tests/test-omp-agents.sh` -> `N passed,
0 failed`; `bash -n omp-agents.sh`.

**Harden - severity/fixable + CI-safety.** The check emits `warn`/`auto` (never `error`), so a
consumer's `woostack-doctor --check` in CI stays green on omp drift: `doctor.sh:43` exits nonzero
**iff** an `error` finding exists. The `--fix` branch is reached only via the doctor SKILL's
repair-apply step (`SKILL.md:48`, uniform `<check> --fix <WOO_ROOT>`); `doctor.sh` itself invokes
checks with `"$WOO_ROOT"` only (no `--fix`) and offers a *gated* repair. Auto-discovery
(`checks/*.sh`) + `fixable=auto` wires it - no `doctor.sh` edit.

---

## Increment 4 - Dispatch wiring (execute + commit + review-local)

**Ships:** the three dispatch call sites that select `agent: woostack-<tier>` under omp.
Removes the Increment 1 deferral marker (generator now has its execute caller).
**Files:**
- Edit `skills/woostack-execute/references/subagent-driver.md`
- Edit `skills/woostack-commit/SKILL.md`
- Edit `skills/woostack-review/SKILL.md`
- Edit `skills/woostack-init/scripts/gen-omp-agents.sh` (remove `woostack-defer` marker line)

**Spec coverage:** AC6 (execute agent-by-tier + ensure-then-select), AC7 (commit fast-draft ->
`woostack-fast`; review-local angle workers -> `woostack-<tier>`, validator -> `woostack-deep`).

### Step 4.1 (RED) - assert the omp dispatch tokens are absent

Commands (all expected `0` at RED):
- `grep -c 'woostack-<effective-tier>' skills/woostack-execute/references/subagent-driver.md`
- `grep -c 'woostack-fast' skills/woostack-commit/SKILL.md`
- `grep -c 'woostack-<tier>' skills/woostack-review/SKILL.md`

### Step 4.2 (GREEN) - `subagent-driver.md` "Dispatch model"

Append a paragraph to the **Dispatch model** section (after line 135, the "say so"
degraded line), using the exact token `woostack-<effective-tier>`:

> **Under omp (agent-by-tier).** omp's `task` tool has no per-call `model`/`tier`/`effort`
> arg, so instead of passing resolved values on the spawn, select
> `agent: woostack-<effective-tier>` - the generated tier def carries `model` +
> `thinkingLevel`. **Ensure-then-select:** before dispatch, ensure the defs exist and are
> current by running `skills/woostack-init/scripts/gen-omp-agents.sh` (idempotent); then
> select the per-task effective tier's agent. This is the omp branch of "when the host
> cannot route per call" - it is **not** degraded: the tier's model/effort are applied via
> the def, so do not "run at session model + say so" under omp.

### Step 4.3 (GREEN) - `commit/SKILL.md` fast-draft

Extend the fast-tier routing bullet (lines 53-57): under omp, since `task` has no per-call
model knob, select `agent: woostack-fast` for the drafting spawn (ensure defs first via the
generator). Use the exact token `woostack-fast`.

### Step 4.4 (GREEN) - `review/SKILL.md` Stage 3 local swarm

Add an omp bullet to the per-host primitive list (after line 337, the opencode bullet),
consistent with the "plain/general-purpose/default worker" mandate (lines 328-332). Use the
exact token `woostack-<tier>`:

> - omp (Oh My Pi): dispatch each angle worker as `agent: woostack-<tier>` (the omp
>   general-purpose worker profile, tier-pinned by the generated def) and the deep validator
>   as `agent: woostack-deep`; ensure defs first via
>   `skills/woostack-init/scripts/gen-omp-agents.sh`. **Local only** - the CI single-session
>   `load-prompt.sh` / `resolve-model.sh` path is unchanged.

### Step 4.5 - remove deferral marker

Delete the `# woostack-defer(increment 4): ...` line from `gen-omp-agents.sh`.

**Verification:** the three `grep -c` commands now each return `>= 1`; `grep -rc
'woostack-defer' skills/woostack-init/scripts/gen-omp-agents.sh` = 0; re-run
`test-gen-omp-agents.sh` (green - marker removal is a comment-only change).

---

## Increment 5 - Docs-site sync + structural lockstep test

**Ships:** authored docs-site pages in sync + the multi-site lockstep guard. Lands LAST
(the lockstep test enumerates every site from Increments 1-4).
**Files:**
- Edit `site/content/docs/configuration.mdx`
- Edit `site/content/docs/concepts.mdx`
- Create `skills/woostack-init/scripts/tests/test-omp-lockstep.sh`

**Spec coverage:** AC9 (docs-site sync), AC8 (structural lockstep enumerating the omp-host
site-list).

### Step 5.1 (RED) - write the lockstep test first

Create `skills/woostack-init/scripts/tests/test-omp-lockstep.sh`:

```bash
#!/usr/bin/env bash
# Structural lockstep: every omp-host edit site must carry its pinned marker.
# Adding an omp host touches all of these in lockstep (wisdom: lockstep-edit-sites).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/assert.sh"
S="$(cd "$HERE/../../.." && pwd)"          # -> repo/skills

mt="$(cat "$S/using-woostack/references/model-tiers.md")"
assert_contains "$mt" "agent-by-tier" "site: model-tiers.md omp bucket"
assert_contains "$mt" "| Tier | Use for | Anthropic | OpenAI (Codex) | Google (Gemini) | OpenRouter |" "site: provider table columns unchanged"
assert_contains "$(cat "$S/woostack-execute/references/subagent-driver.md")" "woostack-<effective-tier>" "site: execute dispatch"
assert_contains "$(cat "$S/woostack-commit/SKILL.md")" "woostack-fast" "site: commit fast-draft"
assert_contains "$(cat "$S/woostack-review/SKILL.md")" "woostack-<tier>" "site: review local swarm"
assert_eq "$([ -f "$S/woostack-init/scripts/gen-omp-agents.sh" ] && echo y)" "y" "site: generator present"
assert_eq "$([ -f "$S/woostack-doctor/scripts/checks/omp-agents.sh" ] && echo y)" "y" "site: doctor check present"
assert_contains "$(cat "$S/woostack-review/prompts/_orchestrator-header.md")" "<!-- WOO_MODEL_TIERS_TABLE -->" "site: CI table-inline marker intact"
finish
```

Note `$HERE/../../..` from `skills/woostack-init/scripts/tests` -> `skills`.
Run: `bash skills/woostack-init/scripts/tests/test-omp-lockstep.sh`
Expected at this point (Increments 1-4 merged): all present except it also guarantees future
edits stay in lockstep. If any site regresses, the matching assertion fails.

**AC8 second assertion (CI-inline resolves).** The omp bucket is *appended* to
`model-tiers.md`, which `load-prompt.sh:193` cats whole into the review orchestrator prompt at
the `<!-- WOO_MODEL_TIERS_TABLE -->` marker (`prompts/_orchestrator-header.md`). The lockstep
test pins the marker intact + the table columns unchanged; **full composed-prompt inline
resolution is already covered by the existing
`skills/woostack-review/scripts/tests/test-load-prompt-models.sh`**, which this increment
re-runs to confirm the append did not break the CI inline.

### Step 5.2 (GREEN) - docs-site sync

- `site/content/docs/configuration.mdx` (the `models.<tier>` / `models.<provider>.<tier>`
  section, ~line 111+): add a short note that **under omp**, the flat `models.<tier>`
  (fully-qualified `provider/slug`) drives per-tier cross-provider routing via generated
  `.omp/agents/woostack-<tier>.md` - no new config key.
- `site/content/docs/concepts.mdx` (the tier->model / host routing section, ~line 123-130):
  add omp to the host routing description as an agent-by-tier host (defs generated from
  config; the Anthropic-model table row stays as-is).

Per-skill reference pages regenerate from `SKILL.md` at build time (gitignored) - no manual
edit.

### Step 5.3 (GREEN) - verify

- `bash skills/woostack-init/scripts/tests/test-omp-lockstep.sh` -> `N passed, 0 failed`.
- `pnpm -C site build` -> succeeds (authored pages compile).

**Verification:** both commands green.

---

## Final increment verification (whole feature)

Run the full shell test set touched by this feature and the site build:
- `bash skills/woostack-init/scripts/tests/test-gen-omp-agents.sh`
- `bash skills/woostack-doctor/scripts/tests/test-omp-agents.sh`
- `bash skills/woostack-init/scripts/tests/test-omp-lockstep.sh`
- `bash skills/woostack-init/scripts/tests/run-tests.sh` (globs `test-*.sh`; auto-includes the two new tests)
- `bash skills/woostack-doctor/scripts/tests/run-tests.sh`
- `bash skills/woostack-review/scripts/tests/test-load-prompt-models.sh` (CI table-inline unaffected by the omp bucket append)
- `pnpm -C site build`
- `bash -n` on `gen-omp-agents.sh` and `omp-agents.sh`
- Dogfood: run the generator in this repo, confirm `.omp/agents/woostack-*.md` are
  gitignored and the V1 probe (Increment 1.4) passed.

## Non-goals (carried from spec §2)

- No per-call model knob added to omp `task` (it has none; that's the whole reason).
- No new config key; no `models.omp`; no fifth provider column in `model-tiers.md`.
- CI single-session path (`load-prompt.sh` / `resolve-model.sh`) is untouched.
- Generated defs are never committed (gitignored).

## Open questions

- **V1 (Increment 1.4, non-blocking):** confirm empirically under omp that a `tools`-omitted
  def inherits the full worker set and that body-as-`systemPrompt` loads (fallback:
  `systemPrompt: |` block scalar). Resolved during execution of Increment 1; documented in
  its PR.
