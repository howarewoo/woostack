#!/usr/bin/env bash
# Test the standalone Stage-3 model resolver used by local per-call-routing hosts.
# resolve-model.sh --provider <p> --tier <fast|standard|deep> prints the resolved
# model slug, honoring $OUTDIR/config.json overrides (issue #295).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/resolve-model.sh"

# Run resolve-model.sh under a clean env with an explicit OUTDIR. Echoes stdout
# (the resolved model) on success; on failure prints captured streams and returns
# the script's exit code so callers can assert on it.
run_resolve() {
  local outdir="$1"; shift
  env -i \
    PATH="$PATH" \
    HOME="${HOME:-}" \
    TMPDIR="${TMPDIR:-/tmp}" \
    OUTDIR="$outdir" \
    bash "$SCRIPT" "$@"
}

# --- issue #295: provider-scoped config override wins over the default table ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"openai":{"standard":"override-standard-model"}}}' > "$outdir/config.json"
model="$(run_resolve "$outdir" --provider openai --tier standard)"
assert_eq "$model" "override-standard-model" \
  "config models.openai.standard wins over default gpt-5.5 (issue #295)"
rm -rf "$outdir"

# --- provider-scoped override leaves other tiers on the default table ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"openai":{"standard":"override-standard-model"}}}' > "$outdir/config.json"
model="$(run_resolve "$outdir" --provider openai --tier deep)"
assert_eq "$model" "gpt-5.5" "untouched tier (deep) falls through to default table"
rm -rf "$outdir"

# --- flat models.<tier> fallback when no provider-scoped entry ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"standard":"flat-standard-x"}}' > "$outdir/config.json"
model="$(run_resolve "$outdir" --provider openai --tier standard)"
assert_eq "$model" "flat-standard-x" "flat models.standard used when no provider-scoped entry"
rm -rf "$outdir"

# --- provider-scoped beats flat when both present ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"standard":"flat-standard-x","openai":{"standard":"scoped-y"}}}' > "$outdir/config.json"
model="$(run_resolve "$outdir" --provider openai --tier standard)"
assert_eq "$model" "scoped-y" "provider-scoped models.openai.standard beats flat models.standard"
rm -rf "$outdir"

# --- no config: default table per provider/tier ---
outdir="$(mktemp -d)"
assert_eq "$(run_resolve "$outdir" --provider openai --tier standard)" "gpt-5.5" \
  "default openai/standard is gpt-5.5"
assert_eq "$(run_resolve "$outdir" --provider openai --tier fast)" "gpt-5.5" \
  "default openai/fast is gpt-5.5"
assert_eq "$(run_resolve "$outdir" --provider openai --tier deep)" "gpt-5.5" \
  "default openai/deep is gpt-5.5"
assert_eq "$(run_resolve "$outdir" --provider anthropic --tier standard)" "claude-opus-4-8" \
  "default anthropic/standard is claude-opus-4-8"
assert_eq "$(run_resolve "$outdir" --provider anthropic --tier deep)" "claude-opus-4-8" \
  "default anthropic/deep is claude-opus-4-8"
assert_eq "$(run_resolve "$outdir" --provider google --tier standard)" "gemini-3-5-flash" \
  "default google/standard is gemini-3-5-flash"
rm -rf "$outdir"

# --- config.json absent entirely (OUTDIR has no config) → defaults still resolve ---
outdir="$(mktemp -d)"
assert_eq "$(run_resolve "$outdir" --provider anthropic --tier fast)" "claude-opus-4-8" \
  "missing config.json falls back to default table"
rm -rf "$outdir"

# --- unknown provider errors out ---
outdir="$(mktemp -d)"
set +e
run_resolve "$outdir" --provider bogus --tier standard >/dev/null 2>&1
code=$?
set -e
assert_exit 1 "$code" "unknown provider exits non-zero"
rm -rf "$outdir"

# --- missing/invalid --tier errors out ---
outdir="$(mktemp -d)"
set +e
run_resolve "$outdir" --provider openai --tier bogus >/dev/null 2>&1
code=$?
set -e
assert_exit 1 "$code" "invalid tier exits non-zero"
rm -rf "$outdir"

# --- missing required flags error out ---
outdir="$(mktemp -d)"
set +e
run_resolve "$outdir" --tier standard >/dev/null 2>&1
code=$?
set -e
assert_exit 1 "$code" "missing --provider exits non-zero"
rm -rf "$outdir"

# --- object leaf {model,effort}: resolver returns .model ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"openai":{"standard":{"model":"obj-standard-x","effort":"low"}}}}' > "$outdir/config.json"
assert_eq "$(run_resolve "$outdir" --provider openai --tier standard)" "obj-standard-x" \
  "object leaf {model,effort}: resolver returns .model"
rm -rf "$outdir"

# --- flat object leaf: resolver returns .model ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"standard":{"model":"flat-obj-y"}}}' > "$outdir/config.json"
assert_eq "$(run_resolve "$outdir" --provider openai --tier standard)" "flat-obj-y" \
  "flat object leaf: resolver returns .model"
rm -rf "$outdir"

# --- array leaf: resolver returns entry 0 (flat) ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"standard":[{"model":"arr-primary","effort":"low"},{"model":"arr-fallback"}]}}' > "$outdir/config.json"
assert_eq "$(run_resolve "$outdir" --provider openai --tier standard)" "arr-primary" \
  "flat array leaf: resolver returns entry-0 .model"
rm -rf "$outdir"

# --- array leaf: resolver returns entry 0 (provider-scoped, string entries) ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"openai":{"deep":["arr-scoped-primary","arr-scoped-fallback"]}}}' > "$outdir/config.json"
assert_eq "$(run_resolve "$outdir" --provider openai --tier deep)" "arr-scoped-primary" \
  "provider-scoped string-array leaf: resolver returns entry 0"
rm -rf "$outdir"

# --- empty-array leaf: falls through to default table (no crash, no empty output) ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"standard":[]}}' > "$outdir/config.json"
assert_eq "$(run_resolve "$outdir" --provider openai --tier standard)" "gpt-5.5" \
  "empty-array leaf: falls through to default table"
rm -rf "$outdir"

# === issue #494: --index resolves configured fallback entries for orchestrator re-dispatch ===

# --- flat object-array leaf: --index 1 returns entry-1 .model; --index 0 unchanged ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"standard":[{"model":"arr-primary","effort":"medium"},{"model":"arr-fallback","effort":"medium"}]}}' > "$outdir/config.json"
assert_eq "$(run_resolve "$outdir" --provider openai --tier standard --index 0)" "arr-primary" \
  "--index 0 on object array returns entry-0 .model"
assert_eq "$(run_resolve "$outdir" --provider openai --tier standard --index 1)" "arr-fallback" \
  "--index 1 on object array returns entry-1 .model (issue #494)"
rm -rf "$outdir"

# --- flat string-array leaf: --index N returns entry-N slug ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"standard":["prime-slug","fb-slug","fb2-slug"]}}' > "$outdir/config.json"
assert_eq "$(run_resolve "$outdir" --provider openai --tier standard --index 1)" "fb-slug" \
  "--index 1 on string array returns entry-1 slug"
assert_eq "$(run_resolve "$outdir" --provider openai --tier standard --index 2)" "fb2-slug" \
  "--index 2 on string array returns entry-2 slug"
rm -rf "$outdir"

# --- provider-scoped array preferred for fallback resolution too ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"standard":["flat-prime","flat-fb"],"openai":{"standard":["scoped-prime","scoped-fb"]}}}' > "$outdir/config.json"
assert_eq "$(run_resolve "$outdir" --provider openai --tier standard --index 1)" "scoped-fb" \
  "--index 1 prefers provider-scoped array over flat"
rm -rf "$outdir"

# --- provider-scoped scalar shadows a flat array: no fallback (winning leaf is the scalar) ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"standard":["flat-prime","flat-fb"],"openai":{"standard":"scoped-scalar"}}}' > "$outdir/config.json"
assert_eq "$(run_resolve "$outdir" --provider openai --tier standard --index 0)" "scoped-scalar" \
  "--index 0 uses provider-scoped scalar as primary"
set +e
run_resolve "$outdir" --provider openai --tier standard --index 1 >/dev/null 2>&1; code=$?
set -e
assert_exit 3 "$code" "provider-scoped scalar shadows flat array: --index 1 has no fallback (exit 3)"
rm -rf "$outdir"

# --- out-of-range index on a real array: exit 3, no stdout ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"standard":["only-one"]}}' > "$outdir/config.json"
set +e
out="$(run_resolve "$outdir" --provider openai --tier standard --index 1 2>/dev/null)"; code=$?
set -e
assert_exit 3 "$code" "out-of-range --index exits 3"
assert_eq "$out" "" "out-of-range --index prints nothing"
rm -rf "$outdir"

# --- scalar leaf has no fallback: --index 1 exits 3 ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"standard":"just-a-string"}}' > "$outdir/config.json"
set +e
run_resolve "$outdir" --provider openai --tier standard --index 1 >/dev/null 2>&1; code=$?
set -e
assert_exit 3 "$code" "scalar leaf: --index 1 has no fallback (exit 3)"
rm -rf "$outdir"

# --- single-object leaf has no fallback: --index 1 exits 3 ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"openai":{"standard":{"model":"obj-x","effort":"low"}}}}' > "$outdir/config.json"
set +e
run_resolve "$outdir" --provider openai --tier standard --index 1 >/dev/null 2>&1; code=$?
set -e
assert_exit 3 "$code" "single-object leaf: --index 1 has no fallback (exit 3)"
rm -rf "$outdir"

# --- no config leaf: --index 0 still defaults; --index 1 has no fallback (exit 3) ---
outdir="$(mktemp -d)"
assert_eq "$(run_resolve "$outdir" --provider openai --tier standard --index 0)" "gpt-5.5" \
  "--index 0 with no config still resolves the default"
set +e
run_resolve "$outdir" --provider openai --tier standard --index 1 >/dev/null 2>&1; code=$?
set -e
assert_exit 3 "$code" "no config: --index 1 has no fallback (exit 3)"
rm -rf "$outdir"

# --- empty-array leaf: --index 1 has no fallback (exit 3) ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"standard":[]}}' > "$outdir/config.json"
set +e
run_resolve "$outdir" --provider openai --tier standard --index 1 >/dev/null 2>&1; code=$?
set -e
assert_exit 3 "$code" "empty-array leaf: --index 1 has no fallback (exit 3)"
rm -rf "$outdir"

# --- invalid --index (non-integer / negative): usage error exit 1 ---
outdir="$(mktemp -d)"
set +e
run_resolve "$outdir" --provider openai --tier standard --index abc >/dev/null 2>&1; code=$?
set -e
assert_exit 1 "$code" "non-integer --index is a usage error (exit 1)"
set +e
run_resolve "$outdir" --provider openai --tier standard --index -1 >/dev/null 2>&1; code=$?
set -e
assert_exit 1 "$code" "negative --index is a usage error (exit 1)"
rm -rf "$outdir"

finish
