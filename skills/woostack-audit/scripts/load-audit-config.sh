#!/usr/bin/env bash
# Reads the sibling `audit` block and shared root `models` block from effective .woostack
# configuration, then emits $OUTDIR/config.json in the shape detect-angles.sh /
# intersect-findings.sh consume. Forces the two audit angles on, skips architecture, applies an
# optional lens flag with a bugs+security safety floor (bugs/security are always-on in
# detect-angles.sh). Mirrors review load-config.sh strictness for audit-local keys.
set -euo pipefail
RVW="$(dirname "${BASH_SOURCE[0]:-$0}")/../../woostack-review/scripts"
source "$RVW/resolve-root.sh"     # exports WOOSTACK_ROOT
source "$RVW/resolve-outdir.sh"   # exports OUTDIR
LENS="${AUDIT_LENS:-}"
VALID_KEYS='angles severity_floor ignore chunking report_dir'
CONFIG_RESOLVER="$(dirname "${BASH_SOURCE[0]:-$0}")/../../woostack-init/scripts/config/resolve-config.sh"

resolver_err="$(mktemp)"
if ! effective_config="$(bash "$CONFIG_RESOLVER" "$WOOSTACK_ROOT" 2>"$resolver_err")"; then
  err_msg="$(cat "$resolver_err")"
  rm -f "$resolver_err"
  [ -n "$err_msg" ] || err_msg="resolve-config failed"
  sys_err_msg="${err_msg#resolve-config: }"
  printf '::error file=.woostack/config.json::%s\n' "$sys_err_msg" >&2
  exit 1
fi
rm -f "$resolver_err"

effective_file="$(mktemp)"
printf '%s\n' "$effective_config" >"$effective_file"
trap 'rm -f "$effective_file"' EXIT

PYTHONDONTWRITEBYTECODE=1 python3 - "$effective_file" "$LENS" "$OUTDIR/config.json" "$VALID_KEYS" "$RVW" <<'PY'
import json, sys, os

sys.path.insert(0, sys.argv[5])
from model_config import normalize_models

src, lens, out, valid_keys = sys.argv[1], sys.argv[2], sys.argv[3], set(sys.argv[4].split())
audit = {}
models = {}
def _fail(path, message):
    sys.stderr.write("::error file=%s::%s\n" % (path, message))
    sys.exit(1)

with open(src, "r") as fh:
    effective_text = fh.read()

if effective_text.strip() == "":
    root = {}
else:
    try:
        root = json.loads(effective_text) or {}
    except json.JSONDecodeError as e:
        _fail(".woostack/config.json", "invalid JSON: %s" % e)

audit = root.get("audit", {}) or {}
if not isinstance(audit, dict):
    _fail(".woostack/config.json", "`audit` must be an object")
models = normalize_models(root.get("models", {}), lambda message: _fail(".woostack/config.json", message))
if "models" in audit:
    _fail(".woostack/config.json", "audit.models moved; use root models instead")
bad = [k for k in audit if k not in valid_keys]
if bad:
    _fail(".woostack/config.json", "unknown audit key(s): %s" % ", ".join(bad))
force = ["simplify", "production-readiness"]
if lens == "simplify":
    force = ["simplify"]
elif lens == "prod":
    force = ["production-readiness"]
if "simplify" not in force:
    force.append("simplify")
ang = audit.get("angles", {}) or {}
if not isinstance(ang, dict):
    _fail(".woostack/config.json", "`audit.angles` must be an object")
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
