#!/usr/bin/env bash
# Reads the sibling `audit` block and shared root `models` block from .woostack/config.json
# (or $AUDIT_CONFIG_FILE), then emits $OUTDIR/config.json in the shape detect-angles.sh /
# intersect-findings.sh consume. Forces the two audit angles on, skips architecture, applies an
# optional lens flag with a bugs+security safety floor (bugs/security are always-on in
# detect-angles.sh). Mirrors review load-config.sh strictness for audit-local keys.
set -euo pipefail
RVW="$(dirname "${BASH_SOURCE[0]:-$0}")/../../woostack-review/scripts"
source "$RVW/resolve-root.sh"     # exports WOOSTACK_ROOT
source "$RVW/resolve-outdir.sh"   # exports OUTDIR
CFG_FILE="${AUDIT_CONFIG_FILE:-$WOOSTACK_ROOT/.woostack/config.json}"
LENS="${AUDIT_LENS:-}"
VALID_KEYS='angles severity_floor ignore chunking report_dir'

PYTHONDONTWRITEBYTECODE=1 python3 - "$CFG_FILE" "$LENS" "$OUTDIR/config.json" "$VALID_KEYS" "$RVW" <<'PY'
import json, sys, os

sys.path.insert(0, sys.argv[5])
from model_config import normalize_models

cfg_file, lens, out, valid_keys = sys.argv[1], sys.argv[2], sys.argv[3], set(sys.argv[4].split())
audit = {}
models = {}
def _fail(path, message):
    sys.stderr.write("::error file=%s::%s\n" % (path, message))
    sys.exit(1)

if os.path.exists(cfg_file):
    with open(cfg_file) as f:
        try:
            root = json.load(f) or {}
        except json.JSONDecodeError as e:
            sys.stderr.write("::error file=%s::invalid JSON: %s\n" % (cfg_file, e)); sys.exit(1)
    audit = root.get("audit", {}) or {}
    models = normalize_models(root.get("models", {}), lambda message: _fail(cfg_file, message))
if "models" in audit:
    sys.stderr.write("::error file=%s::audit.models moved; use root models instead\n" % cfg_file); sys.exit(1)
bad = [k for k in audit if k not in valid_keys]
if bad:
    sys.stderr.write("::error file=%s::unknown audit key(s): %s\n" % (cfg_file, ", ".join(bad))); sys.exit(1)
force = ["simplify", "production-readiness"]
if lens == "simplify":
    force = ["simplify"]
elif lens == "prod":
    force = ["production-readiness"]
if "simplify" not in force:
    force.append("simplify")
ang = audit.get("angles", {}) or {}
skip = [a for a in (ang.get("skip", []) or []) if a != "simplify"]
out_cfg = {
    "angles": {"force": force + (ang.get("force", []) or []),
               "skip": ["architecture"] + skip},
    "severity_floor": audit.get("severity_floor", "high"),
    "ignore": audit.get("ignore", []),
    "models": models,
    "chunking": audit.get("chunking", {"max_loc": 4000}),
    "report_dir": audit.get("report_dir", ".woostack/audits"),
}
with open(out, "w") as f:
    json.dump(out_cfg, f)
PY
