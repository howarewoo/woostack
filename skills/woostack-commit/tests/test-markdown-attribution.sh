#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
commit = (root / "skills/woostack-commit/SKILL.md").read_text(encoding="utf-8")
markdown = (
    root / "skills/woostack-commit/references/markdown-attribution.md"
).read_text(encoding="utf-8")
step7_match = re.search(
    r"^### 7\. Resolve and attribute the PR\s*$"
    r"(.*?)"
    r"(?=^### 8\. Report\s*$)",
    commit,
    re.MULTILINE | re.DOTALL,
)
if step7_match is None:
    raise SystemExit("test-markdown-attribution: Step 7 section boundary missing")
step7 = step7_match.group(1)

markdown_update_match = re.search(
    r"For Markdown-backed and verified `change/\*` invocations only,"
    r"(.*)$",
    step7,
    re.DOTALL,
)
if markdown_update_match is None:
    raise SystemExit("test-markdown-attribution: Markdown update block missing")
markdown_update = markdown_update_match.group(0)

no_update_match = re.search(
    r"If the `--no-pr-update` flag is specified"
    r"(.*?)"
    r"(?=Resolve the PR:)",
    step7,
    re.DOTALL,
)
if no_update_match is None:
    raise SystemExit("test-markdown-attribution: no-PR-update paragraph boundary missing")
no_update = no_update_match.group(0)

neutral_match = re.search(
    r"For a verified `change/\*` invocation,"
    r"(.*?)"
    r"(?=For any invocation other than verified `change/\*`)",
    step7,
    re.DOTALL,
)
if neutral_match is None:
    raise SystemExit("test-markdown-attribution: artifact-neutral paragraph boundary missing")
neutral = neutral_match.group(0)

markdown_contract = "\n".join((markdown, markdown_update))


def fail(message):
    raise SystemExit(f"test-markdown-attribution: {message}")


def compact(value):
    return re.sub(r"\s+", " ", value)


def must(text, token, scope):
    if compact(token) not in compact(text):
        fail(f"{scope} missing {token!r}")


def ordered(text, tokens, scope):
    haystack = compact(text)
    position = -1
    for token in tokens:
        position = haystack.find(compact(token), position + 1)
        if position < 0:
            fail(f"{scope} missing or misorders {token!r}")


# Markdown bodies are validated before mutation, then the exact body is read back.
ordered(markdown_update, (
    "For Markdown-backed and verified `change/*` invocations only",
    "proposed body",
    "gh pr edit",
    "gh pr view",
    "read-back",
), "Markdown proposed-body and read-back workflow")

# A raw spec or fix trailer is the sole final nonblank attribution line.
for token in (
    "raw `Spec: .woostack/specs/<file>.md`",
    "raw `Spec: .woostack/fixes/<file>.md`",
    "sole final nonblank attribution line",
):
    must(markdown_contract, token, "canonical Markdown trailer")

# Validation fails closed on every ambiguous attribution shape.
for token in (
    "wrapped",
    "duplicate",
    "mixed",
    "mismatched",
    "Linear-Project:",
    "Linear-Issue:",
):
    must(markdown_contract, token, "invalid Markdown attribution")

# Artifact-neutral PRs omit every backend attribution form.
for token in (
    "artifact-neutral",
    "contain no `Spec:`, `Linear-Project:`, or `Linear-Issue:` trailer",
):
    must(neutral, token, "artifact-neutral body")

# Skipping the edit is not permission to accept missing or malformed existing attribution.
for token in (
    "`--no-pr-update`",
    "valid existing attribution",
):
    must(no_update, token, "no-PR-update validation")

print("test-markdown-attribution: OK")
PY
