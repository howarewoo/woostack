#!/usr/bin/env bash
# Renders $OUTDIR/findings.json into a severity-grouped markdown report (report-only; no network).
# Writes AUDIT_REPORT_PATH (default .woostack/audits/<date>-<slug>.md) and prints a terminal summary.
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
    findings.sort(key=lambda f: (order.get(f.get("severity", "LOW"), 3), f.get("angle", "")))
    cur = None
    for f in findings:
        sev = f.get("severity", "LOW")
        if sev != cur:
            lines += ["", "## %s" % sev, ""]
            cur = sev
        loc = "%s:%s" % (f.get("file", "?"), f.get("line", "?"))
        lines += [
            "### %s — `%s` · `%s`" % (f.get("title", "(untitled)"), loc, f.get("angle", "?")),
            f.get("description", ""),
            "",
            "**Fix:** %s" % f.get("fix", ""),
            "",
            "_Next: `/woostack-fix` for a small change, `/woostack-build` for a larger one._",
            "",
        ]
open(report, "w").write("\n".join(lines) + "\n")
print("audit: %d finding(s) -> %s" % (len(findings), report))
PY
