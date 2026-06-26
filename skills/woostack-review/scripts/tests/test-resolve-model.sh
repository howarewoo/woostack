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
printf '%s\n' '{"models":{"openai":{"standard":"gpt-5.3-codex-spark"}}}' > "$outdir/config.json"
model="$(run_resolve "$outdir" --provider openai --tier standard)"
assert_eq "$model" "gpt-5.3-codex-spark" \
  "config models.openai.standard wins over default gpt-5.4-mini (issue #295)"
rm -rf "$outdir"

# --- provider-scoped override leaves other tiers on the default table ---
outdir="$(mktemp -d)"
printf '%s\n' '{"models":{"openai":{"standard":"gpt-5.3-codex-spark"}}}' > "$outdir/config.json"
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
assert_eq "$(run_resolve "$outdir" --provider openai --tier standard)" "gpt-5.4-mini" \
  "default openai/standard is gpt-5.4-mini"
assert_eq "$(run_resolve "$outdir" --provider openai --tier fast)" "gpt-5.3-codex-spark" \
  "default openai/fast is gpt-5.3-codex-spark"
assert_eq "$(run_resolve "$outdir" --provider openai --tier deep)" "gpt-5.5" \
  "default openai/deep is gpt-5.5"
assert_eq "$(run_resolve "$outdir" --provider anthropic --tier standard)" "claude-sonnet-4-6" \
  "default anthropic/standard is claude-sonnet-4-6"
assert_eq "$(run_resolve "$outdir" --provider anthropic --tier deep)" "claude-opus-4-8" \
  "default anthropic/deep is claude-opus-4-8"
assert_eq "$(run_resolve "$outdir" --provider google --tier standard)" "gemini-3-5-flash" \
  "default google/standard is gemini-3-5-flash"
rm -rf "$outdir"

# --- config.json absent entirely (OUTDIR has no config) → defaults still resolve ---
outdir="$(mktemp -d)"
assert_eq "$(run_resolve "$outdir" --provider anthropic --tier fast)" "claude-haiku-4-5" \
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

finish
