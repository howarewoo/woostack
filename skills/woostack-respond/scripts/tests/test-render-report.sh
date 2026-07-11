#!/usr/bin/env bash
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
renderer="$root/woostack-respond/scripts/render-report.py"
fixtures="$root/woostack-respond/scripts/tests/fixtures"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/respond-render.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
reports="$tmp/reports"
mkdir -p "$reports"
reports=$(CDPATH= cd -- "$reports" && pwd)

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
render() { python3 "$renderer" --input "$1" --output-dir "$reports" --date 2026-07-10; }

complete=$(render "$fixtures/report-complete.json")
[ "$complete" = "$reports/2026-07-10-http-500-checkout-acme-api-production.md" ] || fail "normalized complete path"
[ -f "$complete" ] || fail "complete report exists"

python3 - "$complete" <<'PY' || exit 1
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
assert text.startswith("---\ntype: response\noutcome: complete\n")
assert "\nstatus:" not in text
assert "Raw Payload" not in text
sections = [
 "## Response & Scope", "## Query Coverage", "## Ranked Error Queue",
 "## Impact Summary", "## Incident Timeline", "## Investigated Groups",
 "## Verified Root Causes", "## External or Non-Code Incidents",
 "## Observability Gaps", "## Remediation", "## Uncovered and Blocked Evidence"
]
positions = [text.index(section) for section in sections]
assert positions == sorted(positions)
assert text.index("g1 — Checkout 500 A") < text.index("g2 — Checkout 500 B") < text.index("g6 — Worker timeout")
assert text.count("### rc-checkout — Nil cart currency") == 1
assert "Deferred" in text and "hyp-webhook" in text and "hyp-cache" in text
assert ".woostack/fixes/checkout.md" in text and ".woostack/fixes/provider-observability.md" in text
assert text.index("sentry / error-tracking") < text.index("vercel / deployment")
PY

second=$(render "$fixtures/report-complete.json")
third=$(render "$fixtures/report-complete.json")
[ "$second" = "${complete%.md}-2.md" ] || fail "second collision suffix"
[ "$third" = "${complete%.md}-3.md" ] || fail "third collision suffix"
cmp -s "$complete" "$second" || fail "collision rendering deterministic"

partial=$(render "$fixtures/report-partial.json")
blocked=$(render "$fixtures/report-blocked.json")
[ "$(basename "$partial")" = "2026-07-10-latency-spike-payments-production.md" ] || fail "partial slug"
grep -q '^outcome: partial$' "$partial" || fail "partial outcome"
grep -q 'tracing: authentication unavailable' "$partial" || fail "partial uncovered evidence"
grep -q '^outcome: blocked$' "$blocked" || fail "blocked outcome"

python3 - "$fixtures/report-complete.json" "$tmp" <<'PY'
import json, pathlib, sys
source, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
data = json.loads(source.read_text())
data["unknown_section"] = "must reject"
(out / "unknown.json").write_text(json.dumps(data))
data.pop("unknown_section")
data["outcome"] = "complete"
data["coverage"][0] = {"provider": data["coverage"][0]["provider"], "role": data["coverage"][0]["role"], "state": "blocked", "reason": "synthetic blocker"}
(out / "false-complete.json").write_text(json.dumps(data))
data = json.loads(source.read_text())
data["verified_root_causes"][0]["evidence"] = ["Authorization: Bearer synthetic-secret-token"]
(out / "token.json").write_text(json.dumps(data))
data = json.loads(source.read_text())
data["investigation_bound"] = 6
(out / "bound-high.json").write_text(json.dumps(data))
data = json.loads(source.read_text())
data["investigation_bound"] = 2  # the complete fixture investigates five groups
(out / "bound-low.json").write_text(json.dumps(data))
data = json.loads(source.read_text())
data["window"]["start"] = "2026-07-10T05:00:00-10:00"  # 15:00Z, after the 14:00Z end
data["window"]["end"] = "2026-07-10T14:00:00Z"
(out / "reversed-offset.json").write_text(json.dumps(data))
partial = json.loads((source.parent / "report-partial.json").read_text())
partial["investigation_bound"] = 3
(out / "bound-three.json").write_text(json.dumps(partial))
partial = json.loads((source.parent / "report-partial.json").read_text())
partial["window"]["start"] = "2026-07-09T18:00:00-04:00"  # 22:00Z, before the next-day 18:00Z end
partial["window"]["end"] = "2026-07-10T18:00:00Z"
(out / "offset-window.json").write_text(json.dumps(partial))
PY

before=$(find "$reports" -type f | wc -l | tr -d ' ')
if render "$tmp/unknown.json" >/dev/null 2>&1; then fail "unknown top-level field accepted"; fi
if render "$tmp/false-complete.json" >/dev/null 2>&1; then fail "false complete accepted"; fi
if render "$tmp/token.json" >/dev/null 2>&1; then fail "bearer token accepted"; fi
if render "$tmp/bound-high.json" >/dev/null 2>&1; then fail "investigation_bound above five accepted"; fi
if render "$tmp/bound-low.json" >/dev/null 2>&1; then fail "investigated groups exceeding bound accepted"; fi
if render "$tmp/reversed-offset.json" >/dev/null 2>&1; then fail "offset-reversed window accepted"; fi
after=$(find "$reports" -type f | wc -l | tr -d ' ')
[ "$before" = "$after" ] || fail "rejected render created report"
grep -q '^- Deep-investigation bound: 5$' "$complete" || fail "complete report bound not rendered"
bound_three=$(render "$tmp/bound-three.json")
grep -q '^- Deep-investigation bound: 3$' "$bound_three" || fail "configured bound not rendered"
offset_ok=$(render "$tmp/offset-window.json")
grep -q '^outcome: partial$' "$offset_ok" || fail "valid offset window rejected"

printf 'PASS: response report renderer\n'
