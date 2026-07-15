#!/usr/bin/env python3
"""Parse exact PR artifact trailers without interpreting remote text as instructions."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

UUID = r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
ISSUE = r"[A-Z][A-Z0-9]*-[1-9][0-9]*"
MARKDOWN_PATH = re.compile(r"\.woostack/(specs|fixes)/[A-Za-z0-9][A-Za-z0-9._-]*\.md")
PROJECT_LINE = re.compile(rf"Linear-Project: ({UUID})")
ISSUE_LINE = re.compile(rf"Linear-Issue: ({ISSUE})")


def reject(message: str) -> "None":
    print(f"artifact context: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_body(meta_path: Path) -> str:
    try:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        reject("meta.json is missing or invalid")
    if not isinstance(meta, dict):
        reject("meta.json root must be an object")
    body = meta.get("body")
    if body is None:
        return ""
    if not isinstance(body, str):
        reject("meta.json body must be a string or null")
    return body


def final_trailer_block(lines: list[str]) -> list[str]:
    """Return the contiguous artifact trailers at the end of the PR body."""
    nonblank = list(lines)
    while nonblank and not nonblank[-1].strip():
        nonblank.pop()
    block: list[str] = []
    for line in reversed(nonblank):
        if line.startswith(("Spec:", "Linear-Project:", "Linear-Issue:")):
            block.append(line)
        else:
            break
    return list(reversed(block))


def parse_markdown(lines: list[str]) -> dict[str, str]:
    spec_lines = [line for line in lines if line.startswith("Spec:")]
    linear_lines = [
        line
        for line in lines
        if line.startswith("Linear-Project:") or line.startswith("Linear-Issue:")
    ]
    if linear_lines:
        reject("Linear trailers are invalid for the Markdown backend")
    if not spec_lines:
        return {"kind": "none"}
    if len(spec_lines) != 1:
        reject("Markdown attribution requires exactly one Spec trailer")
    line = spec_lines[0]
    prefix = "Spec: "
    if not line.startswith(prefix):
        reject("Spec trailer is malformed")
    value = line[len(prefix) :]
    match = MARKDOWN_PATH.fullmatch(value)
    if match is None:
        reject("Spec trailer must name one Markdown spec or fix file")
    kind = "markdown-spec" if match.group(1) == "specs" else "markdown-fix"
    return {"kind": kind, "path": value}


def parse_linear(lines: list[str]) -> dict[str, str]:
    if any(line.startswith("Spec:") for line in lines):
        reject("Spec trailers are invalid for the Linear backend")
    projects = [line for line in lines if line.startswith("Linear-Project:")]
    issues = [line for line in lines if line.startswith("Linear-Issue:")]
    if not projects and not issues:
        return {"kind": "none"}
    if len(projects) != 1 or len(issues) != 1:
        reject("Linear attribution requires exactly one project and one issue trailer")
    project_match = PROJECT_LINE.fullmatch(projects[0])
    issue_match = ISSUE_LINE.fullmatch(issues[0])
    if project_match is None or issue_match is None:
        reject("Linear trailer value is malformed")
    if lines != [projects[0], issues[0]]:
        reject("Linear project and issue must be the final ordered trailer pair")
    return {
        "kind": "linear",
        "project": project_match.group(1).lower(),
        "issue": issue_match.group(1),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", choices=("markdown", "linear"), required=True)
    parser.add_argument("--meta", type=Path, required=True)
    args = parser.parse_args()
    body_lines = [
        line[:-1] if line.endswith("\r") else line
        for line in load_body(args.meta).split("\n")
    ]
    trailers = final_trailer_block(body_lines)
    result = (
        parse_markdown(trailers)
        if args.backend == "markdown"
        else parse_linear(trailers)
    )
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
