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
    "markdown-attribution.md",
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
    "### 1. Inspect state",
    "### 2. Enforce branch shape before committing",
    "### 3. Run configured pre-commit command",
    "### 4. Stage only session-relevant changes",
    "### 4.5 Backend-specific invariant and attribution checks",
    "### 5. Commit",
    "### 6. Push or submit",
    "### 7. Resolve and attribute the PR",
    "### 8. Report",
):
    check(heading in skill, f"root missing shared workflow stage {heading!r}")
check(re.search(r"^## Hard constraints\s*$", skill, re.MULTILINE), "root missing prominent Hard constraints section")
check(len(skill.splitlines()) <= 500, "root exceeds approximately 500 lines")
default_update = re.search(
    r"For Markdown-backed and verified `change/\*` invocations only, when PR updates are enabled, apply\s+this entire controller-owned body workflow:(.*?)(?=For any invocation other than verified `change/\*`)",
    skill,
    re.DOTALL,
)
check(default_update is not None, "root no longer scopes PR field updates to the enabled-update path")
if default_update:
    for token in (
        "1. Load [`references/pr-body.md`](references/pr-body.md)",
        "2. For a non-change Markdown invocation",
        "3. Before any `gh pr create` or `gh pr edit`, validate the proposed body",
        "4. If the PR already exists, apply the validated fields",
    ):
        check(token in default_update.group(1), f"enabled PR update path missing {token!r}")

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
            re.search(r"\b(when|if|only|for|read|use|load)\b", context, re.IGNORECASE),
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

# The split may relocate detail, but it may not weaken the observable commit/PR contract.
for token in (
    "Spec: .woostack/specs/<file>.md",
    "Spec: .woostack/fixes/<file>.md",
    "Linear-Project: <uuid>",
    "Linear-Issue: <TEAM-NUMBER>",
    "gh pr edit <number> --title \"<concise title>\" --body-file <tmp-body-file>",
    "gt submit",
    "gh pr view",
    "re-fetch its body",
    "exact intended read-back is success",
    "Never force-push",
    "Do not merge",
):
    check(compact(token) in normalized, f"combined package missing exact behavior {token!r}")


if errors:
    raise SystemExit("test-progressive-disclosure:\n- " + "\n- ".join(errors))
print("test-progressive-disclosure: OK")
PY
