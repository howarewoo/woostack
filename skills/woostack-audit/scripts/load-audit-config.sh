#!/usr/bin/env bash
# Reads the sibling `audit` block from .woostack/config.json (or $AUDIT_CONFIG_FILE) and emits
# $OUTDIR/config.json in the shape detect-angles.sh / intersect-findings.sh consume. Forces the
# two audit angles on, skips architecture, applies an optional lens flag with a bugs+security
# safety floor (bugs/security are always-on in detect-angles.sh). Mirrors review load-config.sh
# strictness: an unknown key inside the audit block hard-fails.
set -euo pipefail
RVW="$(dirname "${BASH_SOURCE[0]:-$0}")/../../woostack-review/scripts"
source "$RVW/resolve-root.sh"     # exports WOOSTACK_ROOT
source "$RVW/resolve-outdir.sh"   # exports OUTDIR
CFG_FILE="${AUDIT_CONFIG_FILE:-$WOOSTACK_ROOT/.woostack/config.json}"
LENS="${AUDIT_LENS:-}"
VALID_KEYS='angles severity_floor ignore models chunking report_dir'

python3 - "$CFG_FILE" "$LENS" "$OUTDIR/config.json" "$VALID_KEYS" <<'PY'
import json, sys, os
cfg_file, lens, out, valid_keys = sys.argv[1], sys.argv[2], sys.argv[3], set(sys.argv[4].split())
audit = {}
if os.path.exists(cfg_file):
    with open(cfg_file) as f:
        try:
            audit = (json.load(f) or {}).get("audit", {}) or {}
        except json.JSONDecodeError as e:
            sys.stderr.write("::error file=%s::invalid JSON: %s\n" % (cfg_file, e)); sys.exit(1)
bad = [k for k in audit if k not in valid_keys]
if bad:
    sys.stderr.write("::error file=%s::unknown audit key(s): %s\n" % (cfg_file, ", ".join(bad))); sys.exit(1)
force = ["simplify", "production-readiness"]
if lens == "simplify":
    force = ["simplify"]
elif lens == "prod":
    force = ["production-readiness"]
ang = audit.get("angles", {}) or {}
out_cfg = {
    "angles": {"force": force + (ang.get("force", []) or []),
               "skip": ["architecture"] + (ang.get("skip", []) or [])},
    "severity_floor": audit.get("severity_floor", "high"),
    "ignore": audit.get("ignore", []),
    "models": audit.get("models", {}),
    "chunking": audit.get("chunking", {"max_loc": 4000}),
    "report_dir": audit.get("report_dir", ".woostack/audits"),
}
with open(out, "w") as f:
    json.dump(out_cfg, f)
PY
