#!/usr/bin/env bash
# Resolves a PR to its governing woostack spec/plan/fix and composes intent.md.
# Missing or ambiguous intent is a successful no-op: review behavior stays unchanged.
set -euo pipefail

# shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
source "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-outdir.sh"
# shellcheck source=skills/woostack-review/scripts/resolve-root.sh
source "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-root.sh"

INTENT="$OUTDIR/intent.md"
META="$OUTDIR/meta.json"
rm -f "$INTENT"
[ -f "$META" ] || exit 0
[ -d "$WOOSTACK_ROOT/.woostack" ] || exit 0

python3 - "$WOOSTACK_ROOT" "$META" "$INTENT" <<'PY'
import json
import os
import re
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1]).resolve()
meta_path = Path(sys.argv[2])
intent_path = Path(sys.argv[3])
woo = root / ".woostack"
allowed_dirs = {
    "specs": woo / "specs",
    "plans": woo / "plans",
    "fixes": woo / "fixes",
}
trailer_re = re.compile(
    r"^[ \t]*(Spec|Plan):[ \t]*(\.woostack/(specs|plans|fixes)/[A-Za-z0-9][A-Za-z0-9._-]*\.md)[ \t]*$"
)
source_path_re = re.compile(r"^\.woostack/specs/([A-Za-z0-9][A-Za-z0-9._-]*\.md)$")
legacy_source_re = re.compile(
    r"^\*\*Source:\*\*[ \t]+(?:\.woostack/)?specs/([A-Za-z0-9][A-Za-z0-9._-]*\.md)[ \t]*$"
)
wikilink_source_re = re.compile(
    r"^\*\*Source:\*\*[ \t]+\[\[specs/([A-Za-z0-9][A-Za-z0-9._-]*?)(?:\.md)?\]\][ \t]*$"
)


def warn(message):
    print(f"::warning::resolve-intent: {message}", file=sys.stderr)


def markdown_files(kind):
    directory = allowed_dirs[kind]
    return (
        sorted(
            path
            for path in directory.glob("*.md")
            if path.resolve().parent == directory.resolve() and path.is_file()
        )
        if directory.is_dir()
        else []
    )


def relative(path):
    return path.relative_to(root).as_posix()


def frontmatter(path):
    try:
        lines = path.read_text(errors="replace").splitlines()
    except OSError:
        return {}
    if not lines or lines[0].strip() != "---":
        return {}
    fields = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        match = re.match(r"^([A-Za-z0-9_-]+):[ \t]*(.*?)[ \t]*$", line)
        if match:
            fields[match.group(1)] = match.group(2).strip().strip('"\'')
    return fields


def safe_artifact(repo_path):
    match = re.fullmatch(
        r"\.woostack/(specs|plans|fixes)/([A-Za-z0-9][A-Za-z0-9._-]*\.md)",
        repo_path,
    )
    if not match:
        return None
    candidate = (allowed_dirs[match.group(1)] / match.group(2)).resolve()
    expected_parent = allowed_dirs[match.group(1)].resolve()
    if candidate.parent != expected_parent or not candidate.is_file():
        return None
    return candidate


def plan_source(plan):
    source = frontmatter(plan).get("source", "")
    match = source_path_re.fullmatch(source)
    if match:
        candidate = safe_artifact(f".woostack/specs/{match.group(1)}")
        if candidate:
            return candidate
    try:
        lines = plan.read_text(errors="replace").splitlines()
    except OSError:
        return None
    for line in lines:
        match = legacy_source_re.fullmatch(line)
        if match:
            return safe_artifact(f".woostack/specs/{match.group(1)}")
        match = wikilink_source_re.fullmatch(line)
        if match:
            return safe_artifact(f".woostack/specs/{match.group(1)}.md")
    return None


def date_slug(name):
    return re.sub(r"^\d{4}-\d{2}-\d{2}-", "", name.removesuffix(".md"))


def plans_for_spec(spec):
    direct = [plan for plan in markdown_files("plans") if plan_source(plan) == spec]
    if direct:
        return direct
    spec_fields = frontmatter(spec)
    names = {date_slug(spec.name)}
    if spec_fields.get("name"):
        names.add(spec_fields["name"])
    return [
        plan
        for plan in markdown_files("plans")
        if plan_source(plan) is None and date_slug(plan.name) in names
    ]


def compose_artifact(path):
    kind = path.parent.name
    if kind == "fixes":
        return (path,)
    if kind == "plans":
        spec = plan_source(path)
        if not spec:
            warn(f"plan has no resolvable source spec: {relative(path)}")
            return None
        return (spec, path)
    plans = plans_for_spec(path)
    if len(plans) > 1:
        warn(f"spec has multiple matching plans: {relative(path)}")
        return None
    return (path, plans[0]) if plans else (path,)


def trailer_candidate(body):
    declared = []
    malformed = False
    for line in body.splitlines():
        match = trailer_re.fullmatch(line)
        if match:
            label, repo_path, kind = match.groups()
            if (label == "Spec" and kind not in {"specs", "fixes"}) or (
                label == "Plan" and kind != "plans"
            ):
                malformed = True
                continue
            artifact = safe_artifact(repo_path)
            if not artifact:
                malformed = True
                continue
            declared.append(artifact)
        elif re.match(r"^[ \t]*(Spec|Plan):", line):
            malformed = True
    unique = list(dict.fromkeys(declared))
    if malformed:
        warn("invalid or missing governing-artifact trailer")
        return False, None
    if len(unique) > 1:
        warn("conflicting governing-artifact trailers")
        return False, None
    if unique:
        return True, compose_artifact(unique[0])
    return None, None


def branch_candidate(branch):
    if not branch:
        return None
    candidates = []
    for kind in ("fixes", "plans", "specs"):
        for artifact in markdown_files(kind):
            if frontmatter(artifact).get("branch") == branch:
                composed = compose_artifact(artifact)
                if composed:
                    candidates.append(composed)
    unique = []
    seen = set()
    for candidate in candidates:
        key = tuple(str(path) for path in candidate)
        if key not in seen:
            seen.add(key)
            unique.append(candidate)
    if len(unique) > 1:
        warn(f"branch {branch!r} matches multiple unrelated artifacts")
        return None
    return unique[0] if unique else None


try:
    meta = json.loads(meta_path.read_text())
except (OSError, json.JSONDecodeError) as exc:
    warn(f"cannot read metadata: {exc}")
    sys.exit(0)

trailer_state, artifacts = trailer_candidate(meta.get("body") or "")
if trailer_state is False:
    sys.exit(0)
if trailer_state is None:
    artifacts = branch_candidate(meta.get("headRefName") or "")
if not artifacts:
    sys.exit(0)

intent_path.parent.mkdir(parents=True, exist_ok=True)
fd, temporary = tempfile.mkstemp(prefix="intent.", suffix=".tmp", dir=intent_path.parent)
try:
    with os.fdopen(fd, "w") as output:
        for artifact in artifacts:
            output.write(f"## SOURCE: {relative(artifact)}\n\n")
            content = artifact.read_text(errors="replace")
            output.write(content)
            output.write("\n" if content.endswith("\n") else "\n\n")
    os.replace(temporary, intent_path)
except Exception:
    try:
        os.unlink(temporary)
    except FileNotFoundError:
        pass
    raise
PY
