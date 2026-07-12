#!/usr/bin/env python3
"""Canonical Linear metadata transforms for woostack-managed artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from typing import Any, NoReturn

HEADER = "+++ Woostack metadata — managed, do not edit"
HEADER_RE = re.compile(rf"^{re.escape(HEADER)}(?:\r?\n|$)", re.MULTILINE)
CLOSER_RE = re.compile(r"^\+\+\+(?:\r?\n|$)", re.MULTILINE)
SCHEMA = 1
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
FEATURE_STATUSES = {
    "draft",
    "hardened",
    "approved",
    "planning",
    "ready",
    "executing",
    "inReview",
    "done",
    "abandoned",
}
INCREMENT_STATUSES = {"planned", "executing", "inReview", "done", "blocked"}


class MetadataError(Exception):
    """A safe, user-facing validation failure."""


def fail(message: str) -> NoReturn:
    print(f"linear metadata error: {message}", file=sys.stderr)
    raise SystemExit(1)


def read_stdin() -> tuple[bytes, str]:
    raw = sys.stdin.buffer.read()
    try:
        return raw, raw.decode("utf-8")
    except UnicodeDecodeError as error:
        raise MetadataError("input is not valid UTF-8") from error


def no_duplicate_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise MetadataError("JSON contains duplicate keys")
        result[key] = value
    return result


def reject_nonstandard_number(_: str) -> NoReturn:
    raise MetadataError("JSON contains a nonstandard number")


def parse_finite_float(token: str) -> float:
    value = float(token)
    if not math.isfinite(value):
        raise MetadataError("JSON number is not finite")
    return value


def validate_json_scalars(value: Any) -> None:
    pending = [value]
    while pending:
        current = pending.pop()
        if isinstance(current, str):
            if any(0xD800 <= ord(character) <= 0xDFFF for character in current):
                raise MetadataError("JSON string contains an invalid Unicode scalar")
        elif isinstance(current, dict):
            pending.extend(current.keys())
            pending.extend(current.values())
        elif isinstance(current, list):
            pending.extend(current)
        elif isinstance(current, float) and not math.isfinite(current):
            raise MetadataError("JSON number is not finite")


def load_json(text: str, error_message: str) -> Any:
    try:
        value = json.loads(
            text,
            object_pairs_hook=no_duplicate_object,
            parse_constant=reject_nonstandard_number,
            parse_float=parse_finite_float,
        )
        validate_json_scalars(value)
        return value
    except (json.JSONDecodeError, MetadataError, OverflowError, ValueError) as error:
        raise MetadataError(error_message) from error


def canonical_json(value: Any) -> str:
    try:
        return json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
    except (TypeError, ValueError, UnicodeError) as error:
        raise MetadataError("JSON value cannot be canonicalized") from error


def require_nonempty_string(value: Any, message: str) -> str:
    if not isinstance(value, str) or not value:
        raise MetadataError(message)
    return value


def validate_metadata(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise MetadataError("managed metadata must be a JSON object")
    schema = value.get("schema")
    if type(schema) is not int or schema != SCHEMA:
        raise MetadataError("metadata schema is unsupported")
    artifact_type = require_nonempty_string(
        value.get("artifactType"), "metadata artifact type is invalid"
    )
    if artifact_type not in {"spec", "increment"}:
        raise MetadataError("metadata artifact type is invalid")
    require_nonempty_string(value.get("repository"), "metadata ownership is invalid")
    require_nonempty_string(value.get("projectId"), "metadata ownership is invalid")

    if artifact_type == "increment":
        require_nonempty_string(value.get("incrementId"), "increment metadata is invalid")
        ordinal = value.get("ordinal")
        if type(ordinal) is not int or ordinal < 1:
            raise MetadataError("increment metadata is invalid")
        dependencies = value.get("dependencies")
        if (
            not isinstance(dependencies, list)
            or any(not isinstance(item, str) or not item for item in dependencies)
            or len(dependencies) != len(set(dependencies))
        ):
            raise MetadataError("increment metadata is invalid")
        require_nonempty_string(value.get("gitParent"), "increment metadata is invalid")
    return value


def managed_section(text: str) -> tuple[int, int, str, dict[str, Any]]:
    headers = list(HEADER_RE.finditer(text))
    if not headers:
        raise MetadataError("managed metadata block is absent")
    if len(headers) != 1:
        raise MetadataError("managed metadata block is duplicated")

    header = headers[0]
    if header.end() == len(text):
        raise MetadataError("managed metadata block is malformed")
    closer = CLOSER_RE.search(text, header.end())
    if closer is None:
        raise MetadataError("managed metadata block is malformed")

    body = text[header.end() : closer.start()]
    if body.endswith("\r\n"):
        json_text = body[:-2]
        newline = "\r\n"
    elif body.endswith("\n"):
        json_text = body[:-1]
        newline = "\n"
    else:
        raise MetadataError("managed metadata block is malformed")
    if "\n" in json_text or "\r" in json_text or not json_text:
        raise MetadataError("managed metadata block is malformed")

    value = validate_metadata(load_json(json_text, "managed metadata JSON is malformed"))
    if json_text != canonical_json(value):
        raise MetadataError("managed metadata JSON is not canonical")
    return header.end(), closer.start(), newline, value


def check_ownership(
    value: dict[str, Any], repository: str | None, project_id: str | None
) -> None:
    if repository is not None and value["repository"] != repository:
        raise MetadataError("metadata ownership mismatch")
    if project_id is not None and value["projectId"] != project_id:
        raise MetadataError("metadata ownership mismatch")


def revision_value(raw: bytes, updated_at: str) -> dict[str, str]:
    if not updated_at:
        raise MetadataError("updatedAt is invalid")
    return {
        "contentHash": hashlib.sha256(raw).hexdigest(),
        "updatedAt": updated_at,
    }


def parse_expected_revision(text: str) -> dict[str, str]:
    value = load_json(text, "expected revision is malformed")
    if (
        not isinstance(value, dict)
        or set(value) != {"contentHash", "updatedAt"}
        or not isinstance(value.get("contentHash"), str)
        or SHA256_RE.fullmatch(value["contentHash"]) is None
        or not isinstance(value.get("updatedAt"), str)
        or not value["updatedAt"]
    ):
        raise MetadataError("expected revision is malformed")
    return value


def command_parse(args: argparse.Namespace) -> None:
    _, text = read_stdin()
    _, _, _, value = managed_section(text)
    check_ownership(value, args.repository, args.project_id)
    print(canonical_json(value))


def read_replacement(args: argparse.Namespace) -> dict[str, Any]:
    if args.metadata is not None:
        text = args.metadata
    else:
        try:
            text = Path(args.metadata_file).read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            raise MetadataError("replacement metadata could not be read") from error
    return validate_metadata(load_json(text, "replacement metadata JSON is malformed"))


def command_replace(args: argparse.Namespace) -> None:
    raw, text = read_stdin()
    body_start, closer_start, newline, existing = managed_section(text)
    check_ownership(existing, args.repository, args.project_id)
    replacement = read_replacement(args)
    check_ownership(replacement, args.repository, args.project_id)
    if replacement["artifactType"] != existing["artifactType"]:
        raise MetadataError("metadata artifact identity mismatch")
    if (
        existing["artifactType"] == "increment"
        and replacement["incrementId"] != existing["incrementId"]
    ):
        raise MetadataError("metadata artifact identity mismatch")
    if (
        replacement["repository"] != existing["repository"]
        or replacement["projectId"] != existing["projectId"]
    ):
        raise MetadataError("metadata ownership mismatch")

    if args.expected_revision is not None:
        if args.updated_at is None:
            raise MetadataError("updatedAt is required for revision validation")
        expected = parse_expected_revision(args.expected_revision)
        if expected != revision_value(raw, args.updated_at):
            raise MetadataError("optimistic revision mismatch")
    elif args.updated_at is not None:
        raise MetadataError("expected revision is required with updatedAt")

    output = (
        text[:body_start]
        + canonical_json(replacement)
        + newline
        + text[closer_start:]
    )
    sys.stdout.buffer.write(output.encode("utf-8"))


def command_revision(args: argparse.Namespace) -> None:
    raw, _ = read_stdin()
    print(canonical_json(revision_value(raw, args.updated_at)))


def require_keys(value: dict[str, Any], keys: set[str], message: str) -> None:
    if not keys.issubset(value):
        raise MetadataError(message)


def optional_string(value: Any) -> bool:
    return value is None or isinstance(value, str)


def validate_feature(value: Any, expected_project_id: str | None) -> None:
    if not isinstance(value, dict):
        raise MetadataError("normalized feature is invalid")
    require_keys(value, {"backend", "feature", "spec", "increments"}, "normalized feature is invalid")
    if value["backend"] != "linear":
        raise MetadataError("normalized feature backend is invalid")

    feature = value["feature"]
    if not isinstance(feature, dict):
        raise MetadataError("normalized feature is invalid")
    require_keys(feature, {"id", "url", "title", "status", "branch"}, "normalized feature is invalid")
    feature_id = require_nonempty_string(feature["id"], "normalized feature is invalid")
    require_nonempty_string(feature["url"], "normalized feature is invalid")
    require_nonempty_string(feature["title"], "normalized feature is invalid")
    if (
        not isinstance(feature["status"], str)
        or feature["status"] not in FEATURE_STATUSES
        or not optional_string(feature["branch"])
    ):
        raise MetadataError("normalized feature is invalid")
    if expected_project_id is not None and feature_id != expected_project_id:
        raise MetadataError("normalized feature ownership mismatch")

    spec = value["spec"]
    if not isinstance(spec, dict):
        raise MetadataError("normalized spec is invalid")
    require_keys(spec, {"id", "url", "content", "revision"}, "normalized spec is invalid")
    for key in ("id", "url", "revision"):
        require_nonempty_string(spec[key], "normalized spec is invalid")
    if not isinstance(spec["content"], str):
        raise MetadataError("normalized spec is invalid")

    increments = value["increments"]
    if not isinstance(increments, list):
        raise MetadataError("normalized increments are invalid")
    ids: set[str] = set()
    identifiers: set[str] = set()
    ordinals: set[int] = set()
    dependencies_by_id: dict[str, list[str]] = {}
    ordinals_by_id: dict[str, int] = {}
    previous_ordinal = 0
    for increment in increments:
        if not isinstance(increment, dict):
            raise MetadataError("normalized increment is invalid")
        require_keys(
            increment,
            {
                "id",
                "identifier",
                "ordinal",
                "status",
                "dependencies",
                "branch",
                "pullRequest",
                "content",
            },
            "normalized increment is invalid",
        )
        increment_id = require_nonempty_string(increment["id"], "normalized increment is invalid")
        identifier = require_nonempty_string(increment["identifier"], "normalized increment is invalid")
        ordinal = increment["ordinal"]
        dependencies = increment["dependencies"]
        if (
            increment_id in ids
            or identifier in identifiers
            or type(ordinal) is not int
            or ordinal < 1
            or ordinal in ordinals
            or ordinal <= previous_ordinal
            or not isinstance(increment["status"], str)
            or increment["status"] not in INCREMENT_STATUSES
            or not isinstance(dependencies, list)
            or any(not isinstance(item, str) or not item for item in dependencies)
            or len(dependencies) != len(set(dependencies))
            or not optional_string(increment["branch"])
            or not optional_string(increment["pullRequest"])
            or not isinstance(increment["content"], str)
        ):
            raise MetadataError("normalized increment is invalid")
        ids.add(increment_id)
        identifiers.add(identifier)
        ordinals.add(ordinal)
        previous_ordinal = ordinal
        dependencies_by_id[increment_id] = dependencies
        ordinals_by_id[increment_id] = ordinal

    for increment_id, dependencies in dependencies_by_id.items():
        for dependency in dependencies:
            if (
                dependency not in ids
                or dependency == increment_id
                or ordinals_by_id[dependency] >= ordinals_by_id[increment_id]
            ):
                raise MetadataError("normalized increment dependencies are invalid")


def command_validate_feature(args: argparse.Namespace) -> None:
    _, text = read_stdin()
    value = load_json(text, "normalized feature JSON is malformed")
    validate_feature(value, args.project_id)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    parse_parser = subparsers.add_parser("parse")
    parse_parser.add_argument("--repository")
    parse_parser.add_argument("--project-id")
    parse_parser.set_defaults(handler=command_parse)

    replace_parser = subparsers.add_parser("replace")
    replacement = replace_parser.add_mutually_exclusive_group(required=True)
    replacement.add_argument("--metadata")
    replacement.add_argument("--metadata-file")
    replace_parser.add_argument("--repository")
    replace_parser.add_argument("--project-id")
    replace_parser.add_argument("--expected-revision")
    replace_parser.add_argument("--updated-at")
    replace_parser.set_defaults(handler=command_replace)

    revision_parser = subparsers.add_parser("revision")
    revision_parser.add_argument("--updated-at", required=True)
    revision_parser.set_defaults(handler=command_revision)

    feature_parser = subparsers.add_parser("validate-feature")
    feature_parser.add_argument("--project-id")
    feature_parser.set_defaults(handler=command_validate_feature)
    return parser


def main() -> None:
    try:
        args = build_parser().parse_args()
        args.handler(args)
    except MetadataError as error:
        fail(str(error))
    except BrokenPipeError:
        raise SystemExit(1) from None
    except Exception:
        fail("operation failed safely")


if __name__ == "__main__":
    main()
