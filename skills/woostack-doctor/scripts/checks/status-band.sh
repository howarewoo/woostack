#!/usr/bin/env bash
# status-band.sh — report-only. specs own draft/hardened/approved; plans own
# planning/ready/executing/in-review/done. 'abandoned' is terminal for both. fixes/ skipped
# (a fix is its own spec+plan, no opposite band). Never repairs — can't pick the right value.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/lib.sh"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
[ "${1:-}" = "--fix" ] && exit 0          # report-only: --fix is a no-op
WOO_ROOT="${1:-.}"

SPEC_BAND=" draft hardened approved "
PLAN_BAND=" planning ready executing in-review done "

scan() {                                  # scan <dir> <opposite-band> <msg>
  local dir="$1" band="$2" msg="$3" f s rp
  shopt -s nullglob
  for f in "$WOO_ROOT/.woostack/$dir"/*.md; do
    [ "$(head -1 "$f")" != "---" ] && continue
    s="$(field "$f" status)"; [ -z "$s" ] && continue
    if [ "${band/ $s /}" != "$band" ]; then
      rp="${f#"$WOO_ROOT"/}"
      emit warn status-band report "$rp" "$msg '$s'"
    fi
  done
}
scan specs "$PLAN_BAND" "spec carries plan-band status; specs own draft/hardened/approved, move lifecycle to the plan:"
scan plans "$SPEC_BAND" "plan carries spec-band status; plans own planning..done, set a plan-lifecycle status:"
# fixes/ intentionally not scanned.
