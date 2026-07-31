#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
skill_path = root / "skills/woostack-commit/SKILL.md"
reference_dir = skill_path.parent / "references"
reference_names = (
    "linear-attribution.md",
    "pr-body.md",
    "graphite.md",
)
skill = skill_path.read_text(encoding="utf-8")
references = {}
errors = []


def check(condition, message):
    if not condition:
        errors.append(message)


def compact(text):
    return re.sub(r"\s+", " ", text)


# The root remains the shared orchestrator and safety boundary.
for heading in (
    "### 0. Bind the caller-supplied Linear work",
    "### 1. Inspect state",
    "### 2. Enforce issue-owned branch shape before committing",
    "### 3. Run the configured pre-commit command",
    "### 4. Stage only session-relevant changes",
    "### 4.5 Verify Linear identity and proposed attribution",
    "### 5. Commit",
    "### 5.5 Record finalized implementation evidence",
    "### 6. Push or submit",
    "### 7. Resolve and attribute the PR",
    "### 8. Report",
):
    check(heading in skill, f"root missing shared workflow stage {heading!r}")
check(re.search(r"^## Hard constraints\s*$", skill, re.MULTILINE), "root missing prominent Hard constraints section")
check(len(skill.splitlines()) <= 500, "root exceeds approximately 500 lines")

# Each conditional procedure is a direct reader from root, never an index chain.
for name in reference_names:
    path = reference_dir / name
    if path.is_file():
        references[name] = path.read_text(encoding="utf-8")
    else:
        references[name] = ""
        errors.append(f"direct reference missing: references/{name}")

    href = f"(references/{name}"
    paragraphs = [compact(part) for part in re.split(r"\n\s*\n", skill) if href in part]
    check(bool(paragraphs), f"root does not directly dispatch references/{name}")
    if paragraphs:
        context = " ".join(paragraphs)
        check(
            re.search(r"\b(when|if|only|for|read|use|load|follow)\b", context, re.IGNORECASE),
            f"references/{name} lacks conditional when-to-read context",
        )

for name, text in references.items():
    for other in reference_names:
        if other == name:
            continue
        for paragraph in (compact(part) for part in re.split(r"\n\s*\n", text)):
            links_other = f"({other}" in paragraph or f"(./{other}" in paragraph
            requires_other = re.search(r"\b(must|required|before continuing|first)\b", paragraph, re.IGNORECASE)
            check(not (links_other and requires_other), f"references/{name} requires nested procedure references/{other}")

corpus = "\n".join((skill, *references.values()))
normalized = compact(corpus)

# The split may relocate detail, but it may not weaken the observable Linear-only commit/PR contract.
for token in (
    "Official host-exposed Linear MCP",
    "There is no backend selection or resolver",
    "Linear-Project: <verified-project-uuid>\nLinear-Issue: <TEAM-NUMBER>",
    "For a role-`work-item` issue, the sole attribution line is exactly",
    "there is no `Linear-Project:` line anywhere",
    "There is no `Spec:` mention anywhere",
    "After the finalized commit exists and before any push or PR submission",
    "implementationEvidence",
    'gh pr edit <number> --title "<concise title>" --body-file <tmp-body-file>',
    "gt submit",
    "Re-fetch with `gh pr view`",
    "exact intended title and body read-back is success",
    "Never force-push",
    "Do not merge",
):
    check(compact(token) in normalized, f"combined package missing exact behavior {token!r}")

check(not (reference_dir / "markdown-attribution.md").exists(), "removed Markdown attribution reference still exists")
check("markdown-attribution.md" not in corpus, "Linear-only package still dispatches Markdown attribution")

if errors:
    raise SystemExit("test-progressive-disclosure:\n- " + "\n- ".join(errors))
print("test-progressive-disclosure: OK")
PY
