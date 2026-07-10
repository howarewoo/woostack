#!/usr/bin/env python3
"""Validate that an acquisition receipt is bound to current-run evidence."""

import argparse
import hashlib
import json
import os
import stat
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class ValidationError(Exception):
    """A receipt invariant failed."""


def fail(message: str) -> None:
    raise ValidationError(message)

class ReceiptArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> None:
        raise ValidationError(f"invalid arguments: {message}")


def require_object(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(f"{label} must be a JSON object")
    return value


def require_nonempty_string(obj: dict[str, Any], field: str, label: str) -> str:
    value = obj.get(field)
    if not isinstance(value, str) or not value.strip():
        fail(f"{label}.{field} must be a non-empty string")
    return value


def parse_utc(value: str, label: str) -> datetime:
    try:
        parsed = datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except (TypeError, ValueError):
        fail(f"{label} must be a UTC timestamp in YYYY-MM-DDTHH:MM:SSZ form")
    if parsed.strftime("%Y-%m-%dT%H:%M:%SZ") != value:
        fail(f"{label} must be a UTC timestamp in YYYY-MM-DDTHH:MM:SSZ form")
    return parsed


def validate_window(start: str, end: str, label: str) -> None:
    if parse_utc(start, f"{label} start") >= parse_utc(end, f"{label} end"):
        fail(f"{label} start must be earlier than end")


def contained_output(output_value: str, run_dir_value: str) -> Path:
    run_lexical = Path(os.path.abspath(run_dir_value))
    try:
        run_resolved = run_lexical.resolve(strict=True)
    except OSError as exc:
        fail(f"run directory cannot be resolved: {exc}")
    if not run_resolved.is_dir():
        fail("run directory is not a directory")

    output_lexical = Path(os.path.abspath(output_value))
    try:
        relative = output_lexical.relative_to(run_lexical)
    except ValueError:
        fail("receipt output_path must be inside the current run directory")

    current = run_lexical
    for component in relative.parts:
        current = current / component
        try:
            mode = current.lstat().st_mode
        except FileNotFoundError:
            fail(f"receipt output_path does not exist: {current}")
        except OSError as exc:
            fail(f"receipt output_path cannot be inspected: {exc}")
        if stat.S_ISLNK(mode):
            fail(f"receipt output_path contains a symlink component: {current}")

    try:
        output_resolved = output_lexical.resolve(strict=True)
        output_resolved.relative_to(run_resolved)
    except ValueError:
        fail("fully resolved output_path escapes the current run directory")
    except OSError as exc:
        fail(f"receipt output_path cannot be resolved: {exc}")
    try:
        mode = output_resolved.stat().st_mode
    except OSError as exc:
        fail(f"receipt output_path cannot be inspected: {exc}")
    if not stat.S_ISREG(mode):
        fail("receipt output_path must identify a regular file")
    return output_resolved


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        fail(f"cannot read receipt output: {exc}")
    return digest.hexdigest()


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as stream:
            return require_object(json.load(stream), label)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        fail(f"cannot read {label} JSON: {exc}")


def validate(args: argparse.Namespace) -> dict[str, Any]:
    receipt = load_json(Path(args.receipt), "receipt")
    strings = {
        field: require_nonempty_string(receipt, field, "receipt")
        for field in (
            "provider", "role", "integration", "project", "environment",
            "window_start", "window_end", "query_summary", "status",
            "output_path", "output_sha256",
        )
    }
    if strings["status"] != "executed":
        fail("receipt.status must be exactly 'executed'; blocked sources are not receipts")
    if strings["role"].strip().lower() == "blocked":
        fail("receipt.role cannot represent a blocked source as executed")
    count = receipt.get("records_returned")
    if isinstance(count, bool) or not isinstance(count, int) or count < 0:
        fail("receipt.records_returned must be a non-negative integer")
    validate_window(strings["window_start"], strings["window_end"], "receipt window")

    expected_start = args.expected_window_start
    expected_end = args.expected_window_end
    validate_window(expected_start, expected_end, "current-request window")
    expected = {
        "project": args.expected_project,
        "environment": args.expected_environment,
        "window_start": expected_start,
        "window_end": expected_end,
    }
    if not expected["project"].strip() or not expected["environment"].strip():
        fail("current-request project and environment must be non-empty")
    for field, value in expected.items():
        if strings[field] != value:
            fail(f"receipt.{field} does not match the current request")

    output = contained_output(strings["output_path"], args.run_dir)
    expected_digest = strings["output_sha256"].lower()
    if len(expected_digest) != 64 or any(char not in "0123456789abcdef" for char in expected_digest):
        fail("receipt.output_sha256 must be a 64-character SHA-256 hex digest")
    if sha256_file(output) != expected_digest:
        fail("receipt.output_sha256 does not match the output file bytes")

    envelope = load_json(output, "result envelope")
    if envelope.get("schema_version") != 1 or isinstance(envelope.get("schema_version"), bool):
        fail("result envelope.schema_version must equal 1")
    envelope_strings = {
        field: require_nonempty_string(envelope, field, "result envelope")
        for field in ("provider", "role", "query_summary")
    }
    target = require_object(envelope.get("target"), "result envelope.target")
    window = require_object(envelope.get("window"), "result envelope.window")
    envelope_project = require_nonempty_string(target, "project", "result envelope.target")
    envelope_environment = require_nonempty_string(target, "environment", "result envelope.target")
    envelope_start = require_nonempty_string(window, "start", "result envelope.window")
    envelope_end = require_nonempty_string(window, "end", "result envelope.window")
    validate_window(envelope_start, envelope_end, "result envelope window")
    records = envelope.get("records")
    if not isinstance(records, list):
        fail("result envelope.records must be an array")
    if len(records) != count:
        fail("receipt.records_returned does not match result envelope.records count")

    comparisons = {
        "provider": envelope_strings["provider"],
        "role": envelope_strings["role"],
        "query_summary": envelope_strings["query_summary"],
        "project": envelope_project,
        "environment": envelope_environment,
        "window_start": envelope_start,
        "window_end": envelope_end,
    }
    for field, envelope_value in comparisons.items():
        if strings[field] != envelope_value:
            fail(f"receipt.{field} does not match the result envelope")
    for field, envelope_value in {
        "project": envelope_project,
        "environment": envelope_environment,
        "window_start": envelope_start,
        "window_end": envelope_end,
    }.items():
        if envelope_value != expected[field]:
            fail(f"result envelope {field} does not match the current request")
    return receipt


def parser() -> argparse.ArgumentParser:
    result = ReceiptArgumentParser(description=__doc__)
    result.add_argument("--receipt", required=True)
    result.add_argument("--run-dir", required=True)
    result.add_argument("--expected-project", required=True)
    result.add_argument("--expected-environment", required=True)
    result.add_argument("--expected-window-start", required=True)
    result.add_argument("--expected-window-end", required=True)
    return result


def main() -> int:
    try:
        receipt = validate(parser().parse_args())
    except ValidationError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    json.dump(receipt, sys.stdout, sort_keys=True, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
