#!/usr/bin/env bash
# Renders $OUTDIR/findings.json into a sanitized, non-authoritative report (no network).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]:-$0}")/../../woostack-review/scripts/resolve-outdir.sh"
FINDINGS="$OUTDIR/findings.json"
[ -f "$FINDINGS" ] || echo '[]' > "$FINDINGS"
REPORT="${AUDIT_REPORT_PATH:?AUDIT_REPORT_PATH required}"
TARGET="${AUDIT_TARGET:-(unspecified)}"
REPOSITORY="${AUDIT_REPOSITORY:-$(git remote get-url origin 2>/dev/null || printf '(unknown repository)')}"
mkdir -p "$(dirname "$REPORT")"

python3 - "$FINDINGS" "$REPORT" "$TARGET" "$REPOSITORY" <<'PY'
import json
import os
from pathlib import Path
import re
import sys
import tempfile

findings = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
report, target, repository = Path(sys.argv[2]), sys.argv[3], sys.argv[4]

REDACTIONS = (
    (re.compile(r"-----BEGIN [^-]*PRIVATE KEY-----.*?-----END [^-]*PRIVATE KEY-----", re.S), "[REDACTED_PRIVATE_KEY]"),
    (re.compile(r"\bBearer\s+[A-Za-z0-9._~+/=-]+", re.I), "Bearer [REDACTED_TOKEN]"),
    (re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,})\b"), "[REDACTED_TOKEN]"),
    (re.compile(r"(?i)\b(password|passwd|secret|token|api[_ -]?key|cookie)\b(\s*[:=]\s*)([^\s,;]+)"), r"\1\2[REDACTED_SECRET]"),
    (re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.I), "[REDACTED_EMAIL]"),
    (re.compile(r"(?<![A-Za-z0-9_])/(?:Users|home)/[^/\s]+"), "[REDACTED_HOME]"),
    (re.compile(r"(?i)\b[A-Z]:\\Users\\[^\\\s]+"), "[REDACTED_HOME]"),
)
RESIDUALS = (
    re.compile(r"-----BEGIN [^-]*PRIVATE KEY-----", re.I),
    re.compile(r"\bBearer\s+(?!\[REDACTED_TOKEN\])\S+", re.I),
    re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,})\b"),
    re.compile(r"(?i)\b(?:password|passwd|secret|token|api[_ -]?key|cookie)\b\s*[:=]\s*(?!\[REDACTED_SECRET\])\S+"),
    re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.I),
    re.compile(r"(?<![A-Za-z0-9_])/(?:Users|home)/[^/\s]+"),
    re.compile(r"(?i)\b[A-Z]:\\Users\\[^\\\s]+"),
    re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]"),
)

def clean(value):
    text = "" if value is None else str(value)
    for pattern, replacement in REDACTIONS:
        text = pattern.sub(replacement, text)
    return text

target, repository = clean(target), clean(repository)
lines = [
    "Non-authoritative diagnostic evidence — report only.",
    "",
    f"# Audit report — `{target}`",
    "",
    f"- **Canonical repository:** {repository}",
    "- **Authority:** diagnostic evidence only; not scope, approval, assignment, lifecycle, or acceptance.",
    "- **Managed context:** none unless independently verified provenance is supplied by the caller.",
    "",
]
if not findings:
    lines += ["**Result: clean.** No findings in the executed audit coverage.", ""]
else:
    order = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}
    findings.sort(key=lambda finding: (order.get(clean(finding.get("severity") or "LOW"), 3), clean(finding.get("angle") or "")))
    current = None
    for finding in findings:
        severity = clean(finding.get("severity") or "LOW")
        if severity != current:
            lines += [f"## {severity}", ""]
            current = severity
        file = clean(finding.get("file") or "?")
        line = clean(finding.get("line") or "?")
        location = f"{file}:{line}"
        title = clean(finding.get("title") or "(untitled)")
        description = clean(finding.get("description") or "")
        direction = clean(finding.get("fix") or "Reproduce the cited behavior and define the smallest corrective change.")
        angle = clean(finding.get("angle") or "?")
        lines += [
            f"### {title} — `{location}` · `{angle}`",
            "",
            description,
            "",
            f"**Bounded remediation direction:** {direction}",
            "",
            "#### Proposed bounded remediation contract",
            "",
            f"- **Canonical repository:** {repository}",
            f"- **Proved problem/root cause:** {title} — {description}",
            f"- **Bounded source scope:** `{location}`",
            f"- **Evidence pointer:** validated `{angle}` audit finding at `{location}`",
            f"- **Observable acceptance criteria:** the cited behavior no longer reproduces at `{location}` under focused verification.",
            "",
        ]

markdown = "\n".join(lines) + "\n"
for residual in RESIDUALS:
    if residual.search(markdown):
        raise SystemExit("audit renderer residual sanitization failure")

fd, temporary_name = tempfile.mkstemp(prefix=".audit-", suffix=".md", dir=report.parent)
temporary = Path(temporary_name)
try:
    with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(markdown)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, report)
except BaseException:
    temporary.unlink(missing_ok=True)
    raise

print(f"audit: {len(findings)} finding(s) -> {report}")
PY
