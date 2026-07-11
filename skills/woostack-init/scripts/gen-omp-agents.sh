#!/usr/bin/env bash
# gen-omp-agents.sh - bake .woostack/config.json models.<tier> into omp agent-defs
#   <primary-root>/.omp/agents/woostack-{fast,standard,deep}.md
# Single generation authority; callers: woostack-init (scaffold), woostack-doctor
# (--fix), woostack-execute (safety-net). Idempotent (overwrite). Best-effort + loud:
# a malformed/unsafe leaf -> that tier unset (thinkingLevel-only) + stderr warn, exit 0.
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
  # if the file exists without a trailing newline, add one first so the pattern
  # can't glue onto a consumer's unterminated last entry (custom-entrywoostack-*.md)
  if [ -s "$ignore" ] && [ -n "$(tail -c1 "$ignore")" ]; then printf '\n' >> "$ignore"; fi
  printf '%s\n' 'woostack-*.md' >> "$ignore"
fi

# omp thinkingLevel enum (verified: omp models.md). woostack effort maps 1:1 (+ off).
valid_effort() { case "$1" in off|minimal|low|medium|high|xhigh) return 0 ;; *) return 1 ;; esac; }
default_effort() { case "$1" in fast) echo low ;; standard) echo medium ;; deep) echo xhigh ;; esac; }
# model slug charset guard -> no YAML metachars/newlines -> no frontmatter injection.
# Whole-string case match (bash globs span newlines) so a multi-line value can't
# slip a clean first line past a per-line grep and inject frontmatter/body.
safe_slug() {
  case "$1" in
    ''|*[!A-Za-z0-9._/:+-]*) return 1 ;;
    [A-Za-z0-9]*) return 0 ;;
    *) return 1 ;;
  esac
}

render_tier() {
  local tier="$1" leaf ltype model effort tl f
  leaf="$(jq -c --arg t "$tier" '(.models // {})[$t] // null' "$CFG" 2>/dev/null || echo null)"
  ltype="$(printf '%s' "$leaf" | jq -r 'type' 2>/dev/null || echo null)"
  # Array leaf = ordered fallback list; entry 0 is the primary and renders here.
  # Entries 1..n feed host-level fallback (spec 2026-07-10-tier-fallback-list).
  # woostack-defer(increment 3): configuration.mdx/model-tiers.md array-leaf docs sync.
  if [ "$ltype" = "array" ]; then
    if [ "$(printf '%s' "$leaf" | jq 'length' 2>/dev/null || echo 0)" -eq 0 ]; then
      echo "gen-omp-agents.sh: $tier: empty array leaf; tier unset" >&2
      leaf=null; ltype=null
    else
      leaf="$(printf '%s' "$leaf" | jq -c '.[0]')"
      ltype="$(printf '%s' "$leaf" | jq -r 'type' 2>/dev/null || echo null)"
      if [ "$ltype" = "null" ]; then
        echo "gen-omp-agents.sh: $tier: array entry 0 is null; tier unset" >&2
      fi
    fi
  fi
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
    [ -n "$effort" ] && echo "gen-omp-agents.sh: $tier: effort not in enum; using tier default" >&2
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
