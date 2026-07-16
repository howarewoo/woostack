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
PR_URL_RE = re.compile(
    r"^https://github\.com/(?P<repository>[^/\s]+/[^/\s]+)/pull/(?P<number>[1-9][0-9]*)$"
)
GIT_COMMIT_SHA_RE = re.compile(r"^[0-9a-f]{40}$")
UUID_RE = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-"
    r"[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"
)
ISSUE_IDENTIFIER_RE = re.compile(r"^[A-Z][A-Z0-9]*-[1-9][0-9]*$")
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
DESIGN_SEQUENCE = (
    "draft",
    "hardened",
    "approved",
    "planning",
    "ready",
    "executionApproved",
    "executing",
    "inReview",
    "done",
)
DESIGN_STATES = set(DESIGN_SEQUENCE) | {"abandoned"}


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


def normalize_pull_request(value: Any, repository: str) -> str:
    if not isinstance(value, str) or not value:
        raise MetadataError("pull request evidence is invalid")

    urls: list[str]
    canonical = PR_URL_RE.fullmatch(value)
    if canonical is not None:
        urls = [value]
    else:
        linked = re.fullmatch(
            r"\[(?P<label>https://github\.com/[^\s<>]+)\]\("
            r"(?P<target><https://github\.com/[^\s<>]+>|https://github\.com/[^\s<>]+)\)",
            value,
        )
        angle = re.fullmatch(r"<(?P<url>https://github\.com/[^\s<>]+)>", value)
        if linked is not None:
            target = linked.group("target")
            urls = [linked.group("label"), target[1:-1] if target.startswith("<") else target]
        elif angle is not None:
            urls = [angle.group("url")]
        else:
            raise MetadataError("pull request evidence is foreign or invalid")

    if len(set(urls)) != 1:
        raise MetadataError("pull request evidence is foreign or invalid")
    match = PR_URL_RE.fullmatch(urls[0])
    if match is None or match.group("repository") != repository:
        raise MetadataError("pull request evidence is foreign or invalid")
    return urls[0]


def normalize_content(text: str) -> str:
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    result: list[str] = []
    fence_character: str | None = None
    fence_length = 0
    for line in normalized.splitlines(keepends=True):
        content = line.removesuffix("\n")
        fence = re.match(r"^ {0,3}(?P<marker>`{3,}|~{3,})(?P<rest>.*)$", content)
        if fence_character is not None:
            if (
                fence is not None
                and fence.group("marker")[0] == fence_character
                and len(fence.group("marker")) >= fence_length
                and not fence.group("rest").strip()
            ):
                fence_character = None
                fence_length = 0
            result.append(line)
            continue
        if fence is not None:
            marker = fence.group("marker")
            rest = fence.group("rest")
            if marker[0] == "~" or "`" not in rest:
                fence_character = marker[0]
                fence_length = len(marker)
                result.append(line)
                continue
        if re.fullmatch(r" {0,3}\*(?:[ \t]*\*){2,}[ \t]*", content):
            result.append(line)
            continue
        result.append(re.sub(r"^( {0,3})[+*](?=[ \t]+)", r"\1-", line))
    return "".join(result)


def normalize_content_fields(value: Any) -> Any:
    pending = [value]
    while pending:
        current = pending.pop()
        if isinstance(current, dict):
            if isinstance(current.get("content"), str):
                current["content"] = normalize_content(current["content"])
            pending.extend(current.values())
        elif isinstance(current, list):
            pending.extend(current)
    return value


def require_nonempty_string(value: Any, message: str) -> str:
    if not isinstance(value, str) or not value:
        raise MetadataError(message)
    return value


def valid_git_branch(value: Any) -> bool:
    if (
        not isinstance(value, str)
        or not value
        or value in {"@", "HEAD"}
        or value.startswith("-")
        or value.endswith((".", "/"))
        or ".." in value
        or "@{" in value
        or "//" in value
        or any(ord(character) <= 0x20 or ord(character) == 0x7F for character in value)
        or any(character in "~^:?*[\\" for character in value)
    ):
        return False
    components = value.split("/")
    return all(
        component
        and component not in {".", ".."}
        and not component.startswith(".")
        and not component.endswith(".lock")
        for component in components
    )


def valid_frozen_base(base_branch: Any, base_commit_sha: Any) -> bool:
    if (base_branch is None) != (base_commit_sha is None):
        return False
    return base_branch is None or (
        valid_git_branch(base_branch)
        and isinstance(base_commit_sha, str)
        and GIT_COMMIT_SHA_RE.fullmatch(base_commit_sha) is not None
    )


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

    if artifact_type == "spec":
        base_branch = value.get("baseBranch")
        base_commit_sha = value.get("baseCommitSha")
        design_state = value.get("designState")
        if design_state is not None and (
            not isinstance(design_state, str) or design_state not in DESIGN_STATES
        ):
            raise MetadataError("spec design lifecycle is invalid")
        if not valid_frozen_base(base_branch, base_commit_sha):
            raise MetadataError("spec frozen base metadata is invalid")
        if base_branch is not None and design_state is None:
            raise MetadataError("spec frozen base metadata is invalid")

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
        for key in ("branch", "pullRequest"):
            if key in value and not optional_string(value[key]):
                raise MetadataError("increment metadata is invalid")
        if value.get("pullRequest") is not None:
            value["pullRequest"] = normalize_pull_request(
                value["pullRequest"], value["repository"]
            )
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
        newline = "\r\n"
    elif body.endswith("\n"):
        newline = "\n"
    else:
        raise MetadataError("managed metadata block is malformed")

    if body.startswith(newline) and body.endswith(newline * 2):
        json_text = body[len(newline) : -len(newline * 2)]
    else:
        json_text = body[: -len(newline)]
    if "\n" in json_text or "\r" in json_text or not json_text:
        raise MetadataError("managed metadata block is malformed")

    raw_value = load_json(json_text, "managed metadata JSON is malformed")
    if json_text != canonical_json(raw_value):
        raise MetadataError("managed metadata JSON is not canonical")
    value = validate_metadata(raw_value)
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


def command_body(args: argparse.Namespace) -> None:
    _, text = read_stdin()
    headers = list(HEADER_RE.finditer(text))
    if len(headers) != 1:
        raise MetadataError("managed metadata block is absent or duplicated")
    header = headers[0]
    closer = CLOSER_RE.search(text, header.end())
    if closer is None:
        raise MetadataError("managed metadata block is unterminated")
    value = validate_metadata(
        load_json(text[header.end() : closer.start()], "managed metadata JSON is malformed")
    )
    check_ownership(value, args.repository, args.project_id)
    before = text[: header.start()]
    after = text[closer.end() :]
    if before.endswith(("\r\n", "\n")) and after.startswith(("\r\n", "\n")):
        after = after[2:] if after.startswith("\r\n") else after[1:]
    sys.stdout.write(before + after)


def read_text_file(path: str, message: str) -> str:
    try:
        return Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        raise MetadataError(message) from error


def command_compare(args: argparse.Namespace) -> None:
    expected = normalize_content(read_text_file(args.expected_file, "expected content could not be read"))
    observed = normalize_content(read_text_file(args.observed_file, "observed content could not be read"))
    raise SystemExit(0 if expected == observed else 1)


def command_normalize_content(args: argparse.Namespace) -> None:
    _, text = read_stdin()
    sys.stdout.write(normalize_content(text))


def command_normalize_plan(args: argparse.Namespace) -> None:
    _, text = read_stdin()
    value = load_json(text, "plan JSON is malformed")
    if not isinstance(value, list):
        raise MetadataError("plan JSON must be an array")
    print(canonical_json(normalize_content_fields(value)))


def command_normalize_pr(args: argparse.Namespace) -> None:
    _, text = read_stdin()
    print(normalize_pull_request(text.rstrip("\r\n"), args.repository))


def command_normalize_prs(args: argparse.Namespace) -> None:
    _, text = read_stdin()
    value = load_json(text, "pull request evidence JSON is malformed")
    if not isinstance(value, list):
        raise MetadataError("pull request evidence must be an array")
    for item in value:
        if not isinstance(item, dict) or "url" not in item:
            raise MetadataError("pull request evidence is invalid")
        item["url"] = normalize_pull_request(item["url"], args.repository)
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


def replan_has_no_implementation_evidence(raw: str | None) -> bool:
    if raw is None:
        return False
    evidence = load_json(raw, "increment evidence JSON is malformed")
    if not isinstance(evidence, list):
        raise MetadataError("increment evidence is invalid")
    for increment in evidence:
        if (
            not isinstance(increment, dict)
            or "branch" not in increment
            or "pullRequest" not in increment
            or (
                increment["branch"] is not None
                and (
                    not isinstance(increment["branch"], str)
                    or not increment["branch"]
                )
            )
            or (
                increment["pullRequest"] is not None
                and (
                    not isinstance(increment["pullRequest"], str)
                    or not increment["pullRequest"]
                )
            )
        ):
            raise MetadataError("increment evidence is invalid")
        if increment["branch"] is not None or increment["pullRequest"] is not None:
            return False
    return True


def validate_design_state_transition(
    current: Any, replacement: Any, increment_evidence: str | None
) -> None:
    if current == replacement:
        return
    if current is None:
        if replacement == "draft":
            return
        raise MetadataError("design lifecycle must initialize at draft")
    if current in {"done", "abandoned"}:
        raise MetadataError("terminal design lifecycle is immutable")
    if replacement == "abandoned":
        return
    if (current, replacement) == ("ready", "planning"):
        if not replan_has_no_implementation_evidence(increment_evidence):
            raise MetadataError("implementation evidence blocks design lifecycle replan")
        return
    current_index = DESIGN_SEQUENCE.index(current)
    if (
        current_index + 1 < len(DESIGN_SEQUENCE)
        and replacement == DESIGN_SEQUENCE[current_index + 1]
    ):
        if current == "ready" and not replan_has_no_implementation_evidence(
            increment_evidence
        ):
            raise MetadataError("implementation evidence blocks execution approval")
        return
    raise MetadataError("non-canonical design lifecycle transition")


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

    if existing["artifactType"] == "spec":
        validate_design_state_transition(
            existing.get("designState"),
            replacement.get("designState"),
            args.increment_evidence,
        )
        if (
            existing.get("designState") == "ready"
            and replacement.get("designState") == "executionApproved"
            and (
                existing.get("baseBranch") is None
                or replacement.get("baseBranch") != existing.get("baseBranch")
                or replacement.get("baseCommitSha")
                != existing.get("baseCommitSha")
            )
        ):
            raise MetadataError("execution approval requires the frozen base pair")
    base_changed = existing["artifactType"] == "spec" and (
        replacement.get("baseBranch") != existing.get("baseBranch")
        or replacement.get("baseCommitSha") != existing.get("baseCommitSha")
    )
    if base_changed:
        no_implementation_evidence = replan_has_no_implementation_evidence(
            args.increment_evidence
        )
        initial_ready_freeze = (
            "baseBranch" not in existing
            and "baseCommitSha" not in existing
            and existing.get("designState") == "ready"
            and replacement.get("designState") == "ready"
            and no_implementation_evidence
        )
        explicit_pre_execution_replan = (
            "baseBranch" in existing
            and "baseCommitSha" in existing
            and existing.get("designState") in {"ready", "planning"}
            and replacement.get("designState") == "planning"
            and no_implementation_evidence
        )
        if not (initial_ready_freeze or explicit_pre_execution_replan):
            raise MetadataError(
                "execution base change is not an eligible evidence-free replan or ready-state freeze"
            )

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
        + newline
        + canonical_json(replacement)
        + newline * 2
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
    require_keys(
        feature,
        {"id", "url", "title", "status", "baseBranch", "baseCommitSha"},
        "normalized feature is invalid",
    )
    feature_id = require_nonempty_string(feature["id"], "normalized feature is invalid")
    require_nonempty_string(feature["url"], "normalized feature is invalid")
    require_nonempty_string(feature["title"], "normalized feature is invalid")
    strict_ids = UUID_RE.fullmatch(feature_id) is not None
    base_branch = feature["baseBranch"]
    base_commit_sha = feature["baseCommitSha"]
    if (
        not isinstance(feature["status"], str)
        or feature["status"] not in FEATURE_STATUSES
        or not valid_frozen_base(base_branch, base_commit_sha)
    ):
        raise MetadataError("normalized feature is invalid")
    if expected_project_id is not None and feature_id.lower() != expected_project_id.lower():
        raise MetadataError("normalized feature ownership mismatch")

    spec = value["spec"]
    if not isinstance(spec, dict):
        raise MetadataError("normalized spec is invalid")
    require_keys(spec, {"id", "url", "content", "revision"}, "normalized spec is invalid")
    for key in ("id", "url"):
        require_nonempty_string(spec[key], "normalized spec is invalid")
    revision = spec["revision"]
    if (
        (strict_ids and not UUID_RE.fullmatch(spec["id"]))
        or not isinstance(spec["content"], str)
        or not isinstance(revision, dict)
        or set(revision) != {"contentHash", "updatedAt"}
        or not isinstance(revision.get("contentHash"), str)
        or SHA256_RE.fullmatch(revision["contentHash"]) is None
        or not isinstance(revision.get("updatedAt"), str)
        or not revision["updatedAt"]
    ):
        raise MetadataError("normalized spec is invalid")

    increments = value["increments"]
    if not isinstance(increments, list):
        raise MetadataError("normalized increments are invalid")
    ids: set[str] = set()
    identifiers: set[str] = set()
    ordinals: set[int] = set()
    dependencies_by_id: dict[str, list[str]] = {}
    parents_by_id: dict[str, str] = {}
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
        git_parent_value = increment.get("gitParent")
        git_parent = (
            require_nonempty_string(git_parent_value, "normalized increment is invalid")
            if strict_ids
            else (git_parent_value if isinstance(git_parent_value, str) and git_parent_value else
                  (dependencies[-1] if dependencies else "legacy-base"))
        )
        if (
            (strict_ids and not UUID_RE.fullmatch(increment_id))
            or not ISSUE_IDENTIFIER_RE.fullmatch(identifier)
            or increment_id in ids
            or identifier in identifiers
            or type(ordinal) is not int
            or ordinal < 1
            or ordinal in ordinals
            or ordinal <= previous_ordinal
            or not isinstance(increment["status"], str)
            or increment["status"] not in INCREMENT_STATUSES
            or not isinstance(dependencies, list)
            or any(not isinstance(item, str) or not item or (strict_ids and not UUID_RE.fullmatch(item)) for item in dependencies)
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
        parents_by_id[increment_id] = git_parent

    ordinals_by_id = {
        increment["id"]: increment["ordinal"] for increment in increments
    }
    dependents: dict[str, list[str]] = {issue_id: [] for issue_id in ids}
    remaining_dependencies: dict[str, int] = {}
    for issue_id, dependencies in dependencies_by_id.items():
        for dependency in dependencies:
            if dependency not in ids or dependency == issue_id:
                raise MetadataError("normalized increment dependencies are invalid")
            if not strict_ids and ordinals_by_id[dependency] >= ordinals_by_id[issue_id]:
                raise MetadataError("normalized increment dependencies are invalid")
            dependents[dependency].append(issue_id)
        remaining_dependencies[issue_id] = len(dependencies)
    ready = [
        issue_id
        for issue_id, count in remaining_dependencies.items()
        if count == 0
    ]
    visited_count = 0
    while ready:
        issue_id = ready.pop()
        visited_count += 1
        for dependent in dependents[issue_id]:
            remaining_dependencies[dependent] -= 1
            if remaining_dependencies[dependent] == 0:
                ready.append(dependent)
    if visited_count != len(ids):
        raise MetadataError("normalized increment dependency graph is cyclic")

    def reaches(start: str, wanted: str) -> bool:
        pending = [start]
        seen: set[str] = set()
        while pending:
            current = pending.pop()
            if current == wanted:
                return True
            if current not in seen:
                seen.add(current)
                pending.extend(dependencies_by_id[current])
        return False

    if strict_ids:
        for issue_id, dependencies in dependencies_by_id.items():
            parent = parents_by_id[issue_id]
            if not dependencies:
                if UUID_RE.fullmatch(parent):
                    raise MetadataError("root increment Git parent must be the frozen base")
                continue
            if parent not in dependencies:
                raise MetadataError("increment Git parent must be one dependency")
            if any(not reaches(parent, dependency) for dependency in dependencies):
                raise MetadataError("multi-dependency ancestry is not representable")


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

    body_parser = subparsers.add_parser("body")
    body_parser.add_argument("--repository")
    body_parser.add_argument("--project-id")
    body_parser.set_defaults(handler=command_body)

    compare_parser = subparsers.add_parser("compare")
    compare_parser.add_argument("--expected-file", required=True)
    compare_parser.add_argument("--observed-file", required=True)
    compare_parser.set_defaults(handler=command_compare)

    normalize_content_parser = subparsers.add_parser("normalize-content")
    normalize_content_parser.set_defaults(handler=command_normalize_content)

    normalize_plan_parser = subparsers.add_parser("normalize-plan")
    normalize_plan_parser.set_defaults(handler=command_normalize_plan)

    normalize_pr_parser = subparsers.add_parser("normalize-pr")
    normalize_pr_parser.add_argument("--repository", required=True)
    normalize_pr_parser.set_defaults(handler=command_normalize_pr)

    normalize_prs_parser = subparsers.add_parser("normalize-prs")
    normalize_prs_parser.add_argument("--repository", required=True)
    normalize_prs_parser.set_defaults(handler=command_normalize_prs)

    replace_parser = subparsers.add_parser("replace")
    replacement = replace_parser.add_mutually_exclusive_group(required=True)
    replacement.add_argument("--metadata")
    replacement.add_argument("--metadata-file")
    replace_parser.add_argument("--repository")
    replace_parser.add_argument("--project-id")
    replace_parser.add_argument("--expected-revision")
    replace_parser.add_argument("--updated-at")
    replace_parser.add_argument("--increment-evidence")
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
