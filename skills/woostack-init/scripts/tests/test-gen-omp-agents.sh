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

# --- AC1 missing config -> same unset-tier fallback ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
WOOSTACK_ROOT="$r" bash "$GEN"
f="$r/.omp/agents/woostack-standard.md"
assert_eq "$([ -f "$f" ] && echo y)" "y" "AC1 missing config: standard def still written"
assert_not_contains "$(cat "$f")" 'model:' "AC1 missing config: no model line"
assert_contains "$(cat "$f")" 'thinkingLevel: medium' "AC1 missing config: standard default=medium"

# --- AC1 error: empty-string leaf -> tier unset, def still written (default thinkingLevel) ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": "" }'
WOOSTACK_ROOT="$r" bash "$GEN" 2>/dev/null
f="$r/.omp/agents/woostack-fast.md"
assert_eq "$([ -f "$f" ] && echo y)" "y" "AC1 empty leaf: def still written"
assert_not_contains "$(cat "$f")" 'model:' "AC1 empty leaf: no model line"
assert_contains "$(cat "$f")" 'thinkingLevel: low' "AC1 empty leaf: tier default thinkingLevel"

# --- AC1 error: object leaf missing .model -> tier unset, def still written ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "deep": { "effort": "high" } }'
WOOSTACK_ROOT="$r" bash "$GEN" 2>/dev/null
f="$r/.omp/agents/woostack-deep.md"
assert_eq "$([ -f "$f" ] && echo y)" "y" "AC1 missing .model: def still written"
assert_not_contains "$(cat "$f")" 'model:' "AC1 missing .model: no model line"
assert_contains "$(cat "$f")" 'thinkingLevel: high' "AC1 missing .model: configured effort still applied"

# --- AC3 empty effort string -> tier default (not empty) ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": { "model": "x/y", "effort": "" } }'
WOOSTACK_ROOT="$r" bash "$GEN"
assert_contains "$(cat "$r/.omp/agents/woostack-fast.md")" 'thinkingLevel: low' "AC3 empty effort -> default"

# --- AC3 error: untrusted garbage effort -> safe warning + tier default ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "deep": { "model": "x/y", "effort": "turbo\nforged-log" } }'
warn="$(WOOSTACK_ROOT="$r" bash "$GEN" 2>&1 >/dev/null)"
assert_contains "$warn" 'effort not in enum; using tier default' "AC3 garbage effort: generic warning"
assert_not_contains "$warn" 'forged-log' "AC3 garbage effort: raw value not echoed"
assert_contains "$(cat "$r/.omp/agents/woostack-deep.md")" 'thinkingLevel: xhigh' "AC3 garbage effort -> default"

# --- AC1 error: malformed leaf (number) -> tier unset, no crash ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": 42 }'
WOOSTACK_ROOT="$r" bash "$GEN" 2>/dev/null
rc=$?
assert_exit 0 "$rc" "AC1 malformed leaf: exit 0 (best-effort)"
assert_not_contains "$(cat "$r/.omp/agents/woostack-fast.md")" 'model:' "AC1 malformed: tier unset"

# --- AC1 error: injection attempt in slug -> rejected, tier unset ---
# Clean first line + injected second line: this is what a per-line grep guard
# would wrongly pass, so it pins the whole-string safe_slug guard.
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": "good/slug\nmalicious: injected" }'
WOOSTACK_ROOT="$r" bash "$GEN" 2>/dev/null
assert_not_contains "$(cat "$r/.omp/agents/woostack-fast.md")" 'malicious' "AC1 injection: multi-line slug rejected"
assert_not_contains "$(cat "$r/.omp/agents/woostack-fast.md")" 'model:' "AC1 injection: unsafe slug -> tier unset"

# --- AC1 error: charset-valid leading punctuation -> rejected, tier unset ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": "-oProxyCommand" }'
WOOSTACK_ROOT="$r" bash "$GEN" 2>/dev/null
assert_not_contains "$(cat "$r/.omp/agents/woostack-fast.md")" 'model:' "AC1 leading punctuation: unsafe slug -> tier unset"

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
( cd "$wt" && env -u WOOSTACK_ROOT bash "$GEN" )
assert_eq "$([ -f "$r/.omp/agents/woostack-fast.md" ] && echo y)" "y" "AC2 worktree: def at primary root"
assert_eq "$([ -f "$wt/.omp/agents/woostack-fast.md" ] && echo y || echo n)" "n" "AC2 worktree: not in worktree tree"

# --- AC4 gitignore: generated def ignored, custom def tracked ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": "p/q" }'
WOOSTACK_ROOT="$r" bash "$GEN"
touch "$r/.omp/agents/custom.md"
ig="$(cd "$r" && git check-ignore .omp/agents/woostack-fast.md; echo $?)"
assert_contains "$ig" ".omp/agents/woostack-fast.md" "AC4: generated def ignored"
cst=$(cd "$r" && git check-ignore .omp/agents/custom.md >/dev/null 2>&1; echo $?)
assert_eq "$cst" "1" "AC4: custom.md NOT ignored"

# --- AC4b gitignore: append exactly once + preserve a consumer's existing entry ---
# Seed a consumer .gitignore with NO trailing newline to pin the glue-guard.
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": "p/q" }'
mkdir -p "$r/.omp/agents"
printf 'custom-entry.md' > "$r/.omp/agents/.gitignore"   # deliberately unterminated
WOOSTACK_ROOT="$r" bash "$GEN"
WOOSTACK_ROOT="$r" bash "$GEN"   # second run must not duplicate the pattern
ig="$r/.omp/agents/.gitignore"
assert_eq "$(grep -c '^woostack-\*\.md$' "$ig")" "1" "AC4b: pattern appended exactly once"
assert_eq "$(grep -c '^custom-entry\.md$' "$ig")" "1" "AC4b: consumer entry preserved, not glued"

# --- AC5 array leaf -> entry 0 object rendered (model + its effort) ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "deep": [ { "model": "openai/gpt-5.3-codex", "effort": "high" }, { "model": "anthropic/claude-opus-4-8", "effort": "xhigh" } ] }'
WOOSTACK_ROOT="$r" bash "$GEN"
f="$r/.omp/agents/woostack-deep.md"
assert_contains "$(cat "$f")" 'model: "openai/gpt-5.3-codex"' "AC5 array: entry-0 model line"
assert_contains "$(cat "$f")" 'thinkingLevel: high' "AC5 array: entry-0 effort"
assert_not_contains "$(cat "$f")" 'claude-opus' "AC5 array: entry 1 not rendered into def"

# --- AC5 array of strings -> entry 0 string rendered, tier-default effort ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "standard": [ "openai/gpt-5.5", "google/gemini-3-5-flash" ] }'
WOOSTACK_ROOT="$r" bash "$GEN"
f="$r/.omp/agents/woostack-standard.md"
assert_contains "$(cat "$f")" 'model: "openai/gpt-5.5"' "AC5 string-array: entry-0 model"
assert_contains "$(cat "$f")" 'thinkingLevel: medium' "AC5 string-array: tier default effort"

# --- AC5 error: empty array -> tier unset + warn, def still written, exit 0 ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": [] }'
err="$(WOOSTACK_ROOT="$r" bash "$GEN" 2>&1 >/dev/null)"
rc=$?
assert_exit 0 "$rc" "AC5 empty array: exit 0 (best-effort)"
assert_contains "$err" "empty array" "AC5 empty array: loud stderr warn"
assert_not_contains "$(cat "$r/.omp/agents/woostack-fast.md")" 'model:' "AC5 empty array: tier unset"

# --- AC5 error: array entry 0 = null -> loud warn, tier unset (never silent) ---
r="$(mktemp -d)"; ( cd "$r" && git init -q )
mkcfg "$r" '{ "fast": [ null, "a/b" ] }'
err="$(WOOSTACK_ROOT="$r" bash "$GEN" 2>&1 >/dev/null)"
assert_contains "$err" "fast" "AC5 null entry 0: loud stderr warn"
assert_not_contains "$(cat "$r/.omp/agents/woostack-fast.md")" 'model:' "AC5 null entry 0: tier unset"

finish
