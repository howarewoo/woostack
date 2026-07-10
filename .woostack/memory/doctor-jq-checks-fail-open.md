---
name: doctor-jq-checks-fail-open
type: gotcha
scope: skills/woostack-doctor/scripts/checks/**
tags: doctor, jq, fail-open, diagnose
hook: a doctor check wrapping jq in `2>/dev/null || true` converts jq program errors into silent passes
updated: 2026-07-10
source: [[plans/2026-07-10-tier-fallback-list]]
---

A diagnose check that swallows jq stderr and exit codes (`2>/dev/null || true`) is
fail-open: a jq program error (e.g. `IN()` on jq 1.5, `to_entries` on a non-object)
makes the check emit nothing — indistinguishable from a healthy config. Capture jq's
exit code and emit an explicit error record when it fails; validate the container
type (e.g. `.models | type == "object"`) inside the jq program so malformed shapes
are findings, not crashes. Also: jq builtins newer than 1.5 (`IN`) are banned in
checks — use `. == "a" or . == "b"` chains. Same law as wisdom
[[autonomy-needs-structural-proof]]: silence must never masquerade as a pass.
