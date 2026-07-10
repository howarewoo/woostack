#!/usr/bin/env bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
validator="$script_dir/../validate-receipt.py"
tmp=${TMPDIR:-/tmp}/woostack-receipt-test-$$
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/run" "$tmp/outside" "$tmp/real-intermediate"

python3 - "$tmp" <<'PY'
import hashlib, json, os, pathlib, sys
root = pathlib.Path(sys.argv[1])
run = root / "run"
base_envelope = {
    "schema_version": 1,
    "provider": "sentry",
    "role": "error-tracking",
    "target": {"project": "acme/api", "environment": "production"},
    "window": {"start": "2026-07-09T18:00:00Z", "end": "2026-07-10T18:00:00Z"},
    "query_summary": "unresolved error/fatal groups",
    "records": [{"id": "one"}],
}
base_receipt = {
    "provider": "sentry", "role": "error-tracking", "integration": "sentry-cli",
    "project": "acme/api", "environment": "production",
    "window_start": "2026-07-09T18:00:00Z", "window_end": "2026-07-10T18:00:00Z",
    "query_summary": "unresolved error/fatal groups", "status": "executed",
    "records_returned": 1,
}

def put(name, receipt_changes=None, envelope_changes=None, records=None, output=None):
    case = run / name
    case.mkdir(exist_ok=True)
    envelope = json.loads(json.dumps(base_envelope))
    if envelope_changes:
        for key, value in envelope_changes.items():
            if "." in key:
                outer, inner = key.split(".")
                envelope[outer][inner] = value
            elif value is DELETE:
                envelope.pop(key, None)
            else:
                envelope[key] = value
    if records is not None:
        envelope["records"] = records
    output_path = pathlib.Path(output) if output else case / "output.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(envelope, sort_keys=True).encode() + b"\n"
    if not output_path.exists(): output_path.write_bytes(data)
    receipt = dict(base_receipt)
    receipt.update(output_path=str(output_path), output_sha256=hashlib.sha256(output_path.read_bytes()).hexdigest())
    receipt["records_returned"] = len(envelope.get("records", [])) if isinstance(envelope.get("records"), list) else 1
    if receipt_changes:
        for key, value in receipt_changes.items():
            if value is DELETE: receipt.pop(key, None)
            else: receipt[key] = value
    (case / "receipt.json").write_text(json.dumps(receipt))
    return case

DELETE = object()
put("valid")
put("zero", records=[])
(run / "empty").mkdir(); (run / "empty" / "receipt.json").write_text("{}")
put("missing-field", {"provider": DELETE})
put("non-executed", {"status": "blocked"})
put("blocked-role", {"role": "blocked"}, {"role": "blocked"})
put("negative-count", {"records_returned": -1})
put("fractional-count", {"records_returned": 1.5})
put("malformed-time", {"window_start": "yesterday"})
put("unordered-window", {"window_start": "2026-07-10T18:00:00Z", "window_end": "2026-07-09T18:00:00Z"}, {"window.start": "2026-07-10T18:00:00Z", "window.end": "2026-07-09T18:00:00Z"})
missing = put("missing-output"); pathlib.Path(json.loads((missing/"receipt.json").read_text())["output_path"]).unlink()
put("outside-output", output=root / "outside" / "output.json")
direct = put("direct-symlink"); target = direct / "real.json"; (direct/"output.json").rename(target); (direct/"output.json").symlink_to(target)
intermediate = run / "intermediate-symlink"; intermediate.mkdir(); (intermediate/"link").symlink_to(root/"real-intermediate", target_is_directory=True)
put("intermediate-symlink", output=intermediate/"link"/"output.json")
put("digest-mismatch", {"output_sha256": "0" * 64})
put("count-mismatch", {"records_returned": 2})
for field in ("provider", "role", "query_summary"):
    put("mismatch-" + field, {field: "different"})
put("mismatch-project", {"project": "different"})
put("mismatch-environment", {"environment": "different"})
put("mismatch-window", {"window_end": "2026-07-10T17:00:00Z"})
put("stale-scope", {"project": "old/api"}, {"target.project": "old/api"})
put("bad-envelope-schema", envelope_changes={"schema_version": 2})
put("bad-envelope-records", envelope_changes={"records": {"not": "array"}})
PY

run_case="$tmp/run"
invoke() {
  case_name=$1
  python3 "$validator" --receipt "$run_case/$case_name/receipt.json" --run-dir "$run_case" \
    --expected-project acme/api --expected-environment production \
    --expected-window-start 2026-07-09T18:00:00Z \
    --expected-window-end 2026-07-10T18:00:00Z
}

for case_name in valid zero; do
  if ! invoke "$case_name" >"$tmp/stdout" 2>"$tmp/stderr"; then
    echo "FAIL: $case_name should validate: $(cat "$tmp/stderr")" >&2; exit 1
  fi
  python3 -m json.tool "$tmp/stdout" >/dev/null
  [ ! -s "$tmp/stderr" ] || { echo "FAIL: $case_name emitted stderr" >&2; exit 1; }
done

for case_name in empty missing-field non-executed blocked-role negative-count fractional-count malformed-time unordered-window missing-output outside-output direct-symlink intermediate-symlink digest-mismatch count-mismatch mismatch-provider mismatch-role mismatch-query_summary mismatch-project mismatch-environment mismatch-window stale-scope bad-envelope-schema bad-envelope-records; do
  if invoke "$case_name" >"$tmp/stdout" 2>"$tmp/stderr"; then
    echo "FAIL: $case_name should be rejected" >&2; exit 1
  fi
  [ ! -s "$tmp/stdout" ] || { echo "FAIL: $case_name leaked normalized stdout" >&2; exit 1; }
  [ -s "$tmp/stderr" ] || { echo "FAIL: $case_name lacked actionable stderr" >&2; exit 1; }
  lines=$(wc -l <"$tmp/stderr" | tr -d ' ')
  [ "$lines" = 1 ] || { echo "FAIL: $case_name emitted more than one error line" >&2; exit 1; }
done

# Current-request arguments are mandatory.
if python3 "$validator" --receipt "$run_case/valid/receipt.json" --run-dir "$run_case" >"$tmp/stdout" 2>"$tmp/stderr"; then
  echo "FAIL: expected request scope arguments to be required" >&2; exit 1
fi

echo "PASS: acquisition receipt validator"
