#!/usr/bin/env bash
# Renders $OUTDIR/findings.json into a severity-grouped markdown report (report-only; no network).
# Writes AUDIT_REPORT_PATH (required; the caller sets it, e.g. .woostack/audits/<date>-<slug>.md)
# and prints a terminal summary.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]:-$0}")/../../woostack-review/scripts/resolve-outdir.sh"
FINDINGS="$OUTDIR/findings.json"
[ -f "$FINDINGS" ] || echo '[]' > "$FINDINGS"
REPORT="${AUDIT_REPORT_PATH:?AUDIT_REPORT_PATH required}"
TARGET="${AUDIT_TARGET:-(unspecified)}"
mkdir -p "$(dirname "$REPORT")"

python3 - "$FINDINGS" "$REPORT" "$TARGET" <<'PY'
import json, sys
findings = json.load(open(sys.argv[1]))
report, target = sys.argv[2], sys.argv[3]
lines = ["# Audit report — `%s`" % target, ""]
if not findings:
    lines += ["**Result: clean.** No findings.", ""]
else:
    order = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}
    # Use `(f.get(k) or default)`, not `f.get(k, default)`: a finding can carry an explicit null
    # (jq `has()` passes null through merge-findings' schema gate), and dict.get only substitutes
    # the default for *missing* keys — not null values. A null would otherwise reach the renderer
    # and crash the sort/join or print a literal "None".
    findings.sort(key=lambda f: (order.get((f.get("severity") or "LOW"), 3), (f.get("angle") or "")))
    cur = None
    for f in findings:
        sev = f.get("severity") or "LOW"
        if sev != cur:
            lines += ["", "## %s" % sev, ""]
            cur = sev
        loc = "%s:%s" % (f.get("file") or "?", f.get("line") or "?")
        lines += [
            "### %s — `%s` · `%s`" % (f.get("title") or "(untitled)", loc, f.get("angle") or "?"),
            f.get("description") or "",
            "",
            "**Fix:** %s" % (f.get("fix") or ""),
            "",
            "_Next: `/woostack-fix` for a small change, `/woostack-build` for a larger one._",
            "",
        ]
open(report, "w").write("\n".join(lines) + "\n")
print("audit: %d finding(s) -> %s" % (len(findings), report))
PY
