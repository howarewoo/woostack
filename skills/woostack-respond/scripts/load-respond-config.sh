#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -gt 1 ]; then
  path="${1:-.woostack/config.json}"
  printf '::error file=%s::respond.arguments: expected zero or one config path\n' "$path" >&2
  exit 1
fi

config_path="${1:-.woostack/config.json}"
PYTHONDONTWRITEBYTECODE=1 python3 - "$config_path" <<'PY'
import json
import os
import re
import sys

path = sys.argv[1]
def fail(key, reason):
    sys.stderr.write("::error file=%s::respond.%s: %s\n" % (path, key, reason))
    raise SystemExit(1)

if os.path.exists(path):
    try:
        with open(path, "r", encoding="utf-8") as config_file:
            root = json.load(config_file)
    except (OSError, UnicodeError) as error:
        fail("respond", "cannot read config: %s" % error)
    except json.JSONDecodeError as error:
        fail("respond", "invalid JSON: %s" % error)
else:
    root = {}

if not isinstance(root, dict):
    fail("respond", "configuration root must be an object")

respond = root.get("respond", {})
if not isinstance(respond, dict):
    fail("respond", "must be an object")

allowed = {"provider", "environment", "window", "max_groups", "remediation"}
credential_pattern = re.compile(
    r"(?:token|api[_-]?key|password|cookie|authorization|credential|secret|mutation_authority)"
)

# Reject key names before inspecting any values. This prevents credential-like
# additions from being reported merely as ordinary unknown settings.
for key in respond:
    if not isinstance(key, str):
        fail(str(key), "key must be a string")
    if credential_pattern.search(key.lower()):
        fail(key, "credential-like keys are forbidden")
for key in respond:
    if key not in allowed:
        fail(key, "unknown key")

def string_value(key, default):
    value = respond.get(key, default)
    if not isinstance(value, str):
        fail(key, "must be a string")
    if not value:
        fail(key, "must not be empty")
    return value

provider = string_value("provider", "auto")
if re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", provider) is None:
    fail("provider", "must be a lowercase provider slug")

environment = string_value("environment", "production")

window = string_value("window", "24h")
match = re.fullmatch(r"([1-9][0-9]*)(m|h|d)", window)
if match is None:
    fail("window", "must be a duration using m, h, or d")
amount = int(match.group(1))
minutes = amount * {"m": 1, "h": 60, "d": 1440}[match.group(2)]
if minutes < 5 or minutes > 30 * 1440:
    fail("window", "must be between 5m and 30d inclusive")

max_groups = respond.get("max_groups", 5)
if isinstance(max_groups, bool) or not isinstance(max_groups, int):
    fail("max_groups", "must be an integer")
if max_groups < 1 or max_groups > 5:
    fail("max_groups", "must be between 1 and 5 inclusive")

remediation = string_value("remediation", "prepare-fix")
if remediation not in {"prepare-fix", "report-only"}:
    fail("remediation", "must be prepare-fix or report-only")

normalized = {
    "provider": provider,
    "environment": environment,
    "window": window,
    "max_groups": max_groups,
    "remediation": remediation,
}
sys.stdout.write(json.dumps(normalized, separators=(",", ":")) + "\n")
PY
