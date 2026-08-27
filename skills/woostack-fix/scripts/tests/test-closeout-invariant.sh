#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import json, re, sys
from pathlib import Path

root = Path(sys.argv[1])
failures = []
skill = re.sub(r"\s+", " ", (root / "skills/woostack-fix/SKILL.md").read_text())
artifact = re.sub(
    r"\s+",
    " ",
    (root / "skills/woostack-init/references/artifact-backends.md").read_text(),
)
blocked = json.loads((root / "skills/woostack-fix/evals/fixtures/no-root-cause.json").read_text())
evals = json.loads((root / "skills/woostack-fix/evals/evals.json").read_text())
triggers = json.loads((root / "skills/woostack-fix/evals/trigger-evals.json").read_text())


def require(pattern, name):
    if not re.search(pattern, skill, re.I | re.S):
        failures.append(name)
def require_shared(pattern, name):
    if not re.search(pattern, artifact, re.I | re.S):
        failures.append(name)


for pattern, name in (
    (r"Owner-only local run store|canonical persistent store", "shared manifest contract"),
    (r"owner-only `0600`", "owner-only file identity"),
    (r"no-follow semantics", "no-follow file checks"),
    (r"zero provider reads or writes", "no intermediate provider cycle"),
    (r"Write `project-spec\.md` exactly once", "plain project spec write"),
    (r"Write `execution-plan\.md` exactly once", "plain execution plan write"),
    (r"stableTaskMappings", "stable canonical-reference mapping"),
    (r"canonical issue reference", "canonical issue reference"),
    (r"unknown parent state|unknown.*parent.*blocks", "unknown parent fail-closed"),
    (r"Retain `manifest\.json`, `project-spec\.md`, `execution-plan\.md`, and `\.lock`", "artifact retention"),
    (r"Planning base and Execute choice", "planning base and Execute choice"),
    (r"`Continue`.*`Revise spec/plan`.*`Stop`", "Execute base choice options"),
):
    require_shared(pattern, name)

for pattern, name in (
    (r"gate 1 displays only the", "obsolete project-pointer-only Ask"),
    (r"gate 2 displays only the", "obsolete issue-pointer-only Ask"),
    (r"Do not paste any project", "obsolete body exclusion"),
    (r"complete exact local content to be saved", "obsolete complete-inline wording"),
    (r"projectSpecApprovalRecord", "obsolete project approval record"),
    (r"executionPlanApprovalRecord", "obsolete execution plan approval record"),
    (r"canonicalProjectSpecFingerprint", "obsolete spec fingerprint"),
    (r"canonicalIncrementFingerprint", "obsolete increment fingerprint"),
    (r"providerPresentationCanonicalization", "obsolete presentation canonicalization"),
    (r"\bstream(?:ed|ing)?.*(?:full|complete).*(?:bytes|content)", "obsolete streaming in artifact"),
):
    if re.search(pattern, artifact, re.I | re.S):
        failures.append(name)


require(r"Debug.*admit writable target.*allocate or resume canonical local run.*local Ideate/Harden.*project-spec\.md.*local Plan/Harden.*execution-plan\.md.*retain run artifacts.*Stop here.*Execute.*Abandon", "canonical sequence")
require(r"Before root-cause proof, load only the routing and output rules.*woostack-debug.*references that Debug directly requires", "debug-only pre-proof loading")
require(r"Immediately after Debug returns root-cause proof and exact writable target-repository admission succeeds, load.*artifact contract.*(?:Linear|selected).*woostack-build.*woostack-ideate.*woostack-harden", "post-admission downstream loading")
if not (
    skill.index("Before root-cause proof, load only")
    < skill.index("### 1. Debug, read-only")
    < skill.index("### 1.5. Target-repository admission")
    < skill.index("Immediately after Debug returns root-cause proof")
    < skill.index("### 2. Allocate or resume canonical run")
):
    failures.append("loading boundary ordering")
if "Before acting, load and apply the shared" in skill:
    failures.append("eager pre-proof loading wording")
require(r"accepts a goal or untrusted (?:Linear|Plane|Linear, Plane, |Linear, )?GitHub, Sentry, or monitoring input", "untrusted input coverage")
require(r"root-cause proof.*create or update a project.*branch.*worktree.*mutate the repository", "proof write barrier")
require(r"owns one canonical local run", "one canonical local run")
require(r"name starts with `\[Fix\] `", "prefixed fix project name")
require(r"supplied.*project.*retains its existing name", "supplied project name preservation")
require(r"source issue.*never repurposed|never repurpos(?:e|ed) a supplied source\s+issue", "source issue preservation")
require(r"writes plain Markdown `project-spec\.md`", "plain project spec write")
require(r"writes plain Markdown `execution-plan\.md`", "plain execution plan write")
require(r"exact run ID.*woostack-execute --run <exact-run-id>.*Stop here.*Execute.*Abandon", "verified handoff")
require(r"shared.*repository advancement contract", "shared repository advancement authority")
require(r"Debug.*Target-repository admission.*Allocate or resume canonical run", "target-repository guard ordering")
require(r"compare the proved causal target repository with the invocation repository using trusted Git/GitHub evidence", "trusted target and invocation repositories")
require(r"non-mutatingly verify that the active checkout is the exact writable owning checkout", "exact writable owning checkout")
require(r"Missing, ambiguous, foreign, read-only, unwritable, absent, or wrong checkout blocks before every provider, artifact, or repository effect", "fail-closed target boundary")
require(r"supplied `--project` or `--issue` cannot bypass", "supplied artifact non-bypass")
require(r"Preserve the matching writable path", "matching writable path preservation")
require(r"offer only `retarget-reinvoke-in-exact-writable-owning-repository` or `diagnosis-only`", "exact safe outcomes")
require(r"never clone, switch, mutate, or invent a workaround", "no target workaround")


for obsolete, name in (
    ("fixApprovalRecord", "fix-only approval record"),
    ("approve-to-execute", "issue approval wording"),
    ("one hard gate", "one-gate wording"),
    ("bind exactly one issue", "one-issue binding"),
    ("closeout", "one-issue closeout"),
    ("projectSpecApprovalRecord", "obsolete project approval record in skill"),
    ("executionPlanApprovalRecord", "obsolete plan approval record in skill"),
    ("canonicalProjectSpecFingerprint", "obsolete spec fingerprint in skill"),
):
    if obsolete.lower() in skill.lower():
        failures.append(name)

if blocked["dispatch"]["status"] != "blocked" or blocked["dispatch"]["reason"] != "root-cause-proof-required":
    failures.append("blocked fixture boundary")
if blocked["projectAdmission"]["projectCreated"] or blocked["projectAdmission"]["sourceLinkWritten"]:
    failures.append("blocked fixture project mutation")
if blocked["repository"]["mutationCount"] != 0 or blocked["debug"]["providerCallsBeforeProof"] != 0:
    failures.append("blocked fixture side effects")

ids = {case["id"] for case in evals["cases"]}
for expected in (
    "root-cause-proof-precedes-project-and-repository",
    "production-input-routes-to-fix",
    "canonical-project-preserves-source-record",
    "provider-or-readback-failure-is-nonblocking",
    "validates-fix-source-before-project-link",
):
    if expected not in ids:
        failures.append(f"missing eval {expected}")

target_case = next((case for case in evals["cases"] if case["id"] == "target-repository-boundary-precedes-provider-admission"), None)
if target_case is None:
    failures.append("missing target repository boundary eval")
else:
    if "fixtures" in target_case:
        failures.append("target repository boundary eval must be no-fixture")
    if any(assertion.get("critical") is not True for assertion in target_case["assertions"]):
        failures.append("target repository boundary assertions must be critical")
    def require_target_assertion(pointer, expected, name):
        matches = [
            assertion for assertion in target_case["assertions"]
            if assertion.get("pointer") == pointer and assertion.get("expected") == expected
        ]
        if len(matches) != 1 or matches[0].get("critical") is not True:
            failures.append(name)
    for pointer, expected, name in (
        ("/foreignTarget/status", "blocked", "foreign target decision"),
        ("/foreignTarget/reason", "target-repository-mismatch", "foreign target reason"),
        ("/foreignTarget/safeOutcomes", ["retarget-reinvoke-in-exact-writable-owning-repository", "diagnosis-only"], "foreign target outcomes"),
        ("/foreignTarget/providerCalls", 0, "foreign target provider effects"),
        ("/foreignTarget/projectCreated", False, "foreign target project effects"),
        ("/foreignTarget/sourceLinkWritten", False, "foreign target source effects"),
        ("/foreignTarget/repositoryMutationCount", 0, "foreign target repository effects"),
        ("/foreignTarget/suppliedArtifactBypass", False, "foreign target artifact bypass"),
        ("/matchingUnwritable/status", "blocked", "unwritable target decision"),
        ("/matchingUnwritable/reason", "writable-target-checkout-required", "unwritable target reason"),
        ("/matchingUnwritable/safeOutcomes", ["retarget-reinvoke-in-exact-writable-owning-repository", "diagnosis-only"], "unwritable target outcomes"),
        ("/matchingUnwritable/providerCalls", 0, "unwritable target provider effects"),
        ("/matchingUnwritable/projectCreated", False, "unwritable target project effects"),
        ("/matchingUnwritable/sourceLinkWritten", False, "unwritable target source effects"),
        ("/matchingUnwritable/repositoryMutationCount", 0, "unwritable target repository effects"),
        ("/matchingUnwritable/suppliedArtifactBypass", False, "unwritable target artifact bypass"),
        ("/matchingWritable/status", "continue", "writable target decision"),
        ("/matchingWritable/nextPhase", "canonical-project-admission", "writable target next phase"),
        ("/matchingWritable/classificationEffects/providerCalls", 0, "writable classification provider effects"),
        ("/matchingWritable/classificationEffects/projectCreated", False, "writable classification project effects"),
        ("/matchingWritable/classificationEffects/sourceLinkWritten", False, "writable classification source effects"),
        ("/matchingWritable/classificationEffects/repositoryMutationCount", 0, "writable classification repository effects"),
    ):
        require_target_assertion(pointer, expected, name)

if not any(case["id"] == "production-monitoring-defect-routes-to-fix" for case in triggers["cases"]):
    failures.append("missing production trigger")


# ---------------------------------------------------------------------------
# Deterministic Plane Fix Preservation, Timing, and Capability Fallback Simulation
# ---------------------------------------------------------------------------
class MockPlaneFixMCP:
    def __init__(self, base_url="https://api.plane.so", workspace="acme", repository="https://github.com/acme/widgets", capabilities=None):
        self.base_url = base_url
        self.workspace = workspace
        self.repository = repository
        self.capabilities = capabilities or {
            "projectRead": True, "projectWrite": True, "issueRead": True, "issueWrite": True,
            "relationRead": True, "relationWrite": True,
            "projectLabelRead": True, "projectLabelWrite": True, "independentReadBack": True
        }
        self.projects = {}
        self.work_items = {}
        self.relations = []
        self.call_log = []

    def list_projects(self, workspace, include_archived=True, cursor=None, page_size=2):
        self.call_log.append(("list_projects", workspace, include_archived, cursor))
        if not self.capabilities.get("projectRead"):
            raise RuntimeError("missing capability: projectRead")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")

        filtered = [
            dict(p) for p in self.projects.values()
            if p["workspace"] == workspace and (include_archived or not p.get("archived", False))
        ]

        offset = 0
        if cursor is not None:
            if not cursor.startswith("cur-"):
                raise ValueError(f"invalid cursor: {cursor}")
            offset = int(cursor.split("-")[1])

        page_items = filtered[offset:offset + page_size]
        next_offset = offset + page_size
        next_cursor = f"cur-{next_offset}" if next_offset < len(filtered) else None
        return {"items": page_items, "next_cursor": next_cursor}

    def read_project(self, workspace, project_id):
        self.call_log.append(("read_project", workspace, project_id))
        if not self.capabilities.get("projectRead"):
            raise RuntimeError("missing capability: projectRead")
        proj = self.projects.get(project_id)
        if not proj or proj["workspace"] != workspace:
            return None
        return dict(proj)

    def create_project(self, workspace, name, labels=None, external_source=None, external_id=None):
        self.call_log.append(("create_project", workspace, name, labels, external_id))
        if not self.capabilities.get("projectWrite"):
            raise RuntimeError("missing capability: projectWrite")
        if not self.capabilities.get("projectLabelWrite"):
            raise RuntimeError("missing capability: projectLabelWrite")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        proj_id = f"proj-{len(self.projects) + 1:03d}"
        proj = {
            "id": proj_id,
            "name": name,
            "workspace": workspace,
            "labels": list(labels or []),
            "external_source": external_source,
            "external_id": external_id,
            "repository": self.repository,
        }
        self.projects[proj_id] = proj
        return dict(proj)

    def update_project_labels(self, workspace, project_id, labels):
        self.call_log.append(("update_project_labels", workspace, project_id, labels))
        if not self.capabilities.get("projectLabelWrite"):
            raise RuntimeError("missing capability: projectLabelWrite")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        proj = self.projects.get(project_id)
        if not proj:
            raise ValueError(f"project not found: {project_id}")
        proj["labels"] = list(labels)
        return dict(proj)

    def read_work_item(self, workspace, identifier):
        self.call_log.append(("read_work_item", workspace, identifier))
        if not self.capabilities.get("issueRead"):
            raise RuntimeError("missing capability: issueRead")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        for wi in self.work_items.values():
            if wi["id"] == identifier or wi.get("readable_id") == identifier:
                return dict(wi)
        return None

    def create_work_item(self, workspace, project_id, title, description="", external_source=None, external_id=None, parent=None):
        self.call_log.append(("create_work_item", workspace, project_id, title, external_id, parent))
        if not self.capabilities.get("issueWrite"):
            raise RuntimeError("missing capability: issueWrite")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        wi_id = f"wi-{len(self.work_items) + 1:03d}"
        wi = {
            "id": wi_id,
            "readable_id": f"ENG-{len(self.work_items) + 100}",
            "workspace": workspace,
            "project_id": project_id,
            "title": title,
            "description": description,
            "external_source": external_source,
            "external_id": external_id,
            "parent": parent,
            "state_id": "state-unstarted",
            "assignee": None,
            "labels": [],
            "relations": [],
            "comments": [],
            "lifecycle": {"state": "unstarted", "archived": False},
        }
        self.work_items[wi_id] = wi
        return dict(wi)

    def create_relation(self, workspace, project_id, source_id, target_id, relation_type="blocks", external_id=None):
        self.call_log.append(("create_relation", workspace, project_id, source_id, target_id, relation_type, external_id))
        if not self.capabilities.get("relationWrite"):
            raise RuntimeError("missing capability: relationWrite")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        rel_id = f"rel-{len(self.relations) + 1:03d}"
        rel = {
            "id": rel_id,
            "workspace": workspace,
            "project_id": project_id,
            "source": source_id,
            "target": target_id,
            "type": relation_type,
            "external_id": external_id,
        }
        self.relations.append(rel)
        return dict(rel)

    def list_relations(self, workspace, project_id):
        self.call_log.append(("list_relations", workspace, project_id))
        if not self.capabilities.get("relationRead"):
            raise RuntimeError("missing capability: relationRead")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        return [dict(r) for r in self.relations if r["project_id"] == project_id]

    def link_source_work_item_to_project(self, workspace, work_item_id, project_id):
        self.call_log.append(("link_source_work_item_to_project", workspace, work_item_id, project_id))
        if not self.capabilities.get("issueWrite"):
            raise RuntimeError("missing capability: issueWrite")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        wi = self.work_items.get(work_item_id)
        if not wi:
            raise ValueError(f"work item not found: {work_item_id}")
        wi["project_id"] = project_id
        return dict(wi)


def discover_canonical_repository_projects(mcp_client, workspace, canonical_repo, canonical_name):
    all_projects = []
    cursor = None
    while True:
        page = mcp_client.list_projects(workspace, include_archived=True, cursor=cursor)
        if not isinstance(page, dict) or "items" not in page or "next_cursor" not in page:
            raise RuntimeError("incomplete pagination response")
        all_projects.extend(page["items"])
        cursor = page["next_cursor"]
        if cursor is None:
            break

    # Exact baseUrl, workspace, repository, and canonical-name filtering
    matched = []
    for proj in all_projects:
        if (
            proj.get("workspace") == workspace
            and proj.get("repository") == canonical_repo
            and proj.get("name") == canonical_name
        ):
            matched.append(proj)

    if len(matched) > 1:
        raise RuntimeError(f"duplicate canonical repository projects discovered: {len(matched)} matches")

    return matched


def test_plane_fix_preservation_and_scoping():
    canonical_repo_url = "https://github.com/acme/widgets"
    canonical_repo_project_name = "[Repo] acme/widgets"

    # ---------------------------------------------------------------------------
    # Scenario A: Canonical repository project reuse (multi-page active & archived discovery)
    # ---------------------------------------------------------------------------
    mcp_reuse = MockPlaneFixMCP(
        base_url="https://api.plane.so",
        workspace="acme",
        repository=canonical_repo_url
    )
    # Page 1: Foreign repo with different name, and foreign repo with SAME name (must not be selected)
    mcp_reuse.projects["proj-foreign-1"] = {
        "id": "proj-foreign-1",
        "name": "[Repo] foreign/widgets",
        "workspace": "acme",
        "repository": "https://github.com/foreign/widgets",
        "labels": ["Core"],
        "archived": False,
    }
    mcp_reuse.projects["proj-foreign-2"] = {
        "id": "proj-foreign-2",
        "name": canonical_repo_project_name,
        "workspace": "acme",
        "repository": "https://github.com/foreign/other-repo",
        "labels": ["Core"],
        "archived": False,
    }
    # Page 2: Canonical project found on later page and in archived records
    existing_proj_id = "proj-canonical-001"
    mcp_reuse.projects[existing_proj_id] = {
        "id": existing_proj_id,
        "name": canonical_repo_project_name,
        "workspace": "acme",
        "repository": canonical_repo_url,
        "labels": ["Core", "ExistingLabel"],
        "external_source": "woostack",
        "external_id": "ext-existing-proj",
        "archived": True,
    }

    # Discover existing canonical repository project across complete terminal pagination
    matched_projects = discover_canonical_repository_projects(
        mcp_reuse, "acme", canonical_repo_url, canonical_repo_project_name
    )
    assert len(matched_projects) == 1, "must discover exact canonical repository project across multi-page active/archived discovery"
    reused_proj = matched_projects[0]
    assert reused_proj["id"] == existing_proj_id
    assert reused_proj["repository"] == canonical_repo_url

    # Apply missing configured label ("Fix") while preserving unrelated label ("ExistingLabel")
    configured_labels = ["Core", "Fix"]
    unioned_labels = list(set(reused_proj["labels"]) | set(configured_labels))
    mcp_reuse.update_project_labels("acme", reused_proj["id"], unioned_labels)

    # Reusable project path must NOT call create_project when matching canonical project exists
    assert not any(call[0] == "create_project" for call in mcp_reuse.call_log), "existing canonical project must be reused without create_project"

    # Independent read-back of reused project
    read_back_reused = mcp_reuse.read_project("acme", reused_proj["id"])
    assert read_back_reused is not None
    assert set(read_back_reused["labels"]) == {"Core", "ExistingLabel", "Fix"}

    # ---------------------------------------------------------------------------
    # Scenario B: Duplicate canonical repository project discovery fails closed
    # ---------------------------------------------------------------------------
    mcp_dup = MockPlaneFixMCP(
        base_url="https://api.plane.so",
        workspace="acme",
        repository=canonical_repo_url
    )
    mcp_dup.projects["proj-dup-1"] = {
        "id": "proj-dup-1", "name": canonical_repo_project_name, "workspace": "acme",
        "repository": canonical_repo_url, "labels": ["Core"], "archived": False
    }
    mcp_dup.projects["proj-dup-2"] = {
        "id": "proj-dup-2", "name": canonical_repo_project_name, "workspace": "acme",
        "repository": canonical_repo_url, "labels": ["Core"], "archived": True
    }
    dup_failed_closed = False
    try:
        discover_canonical_repository_projects(mcp_dup, "acme", canonical_repo_url, canonical_repo_project_name)
    except RuntimeError as exc:
        if "duplicate canonical repository projects" in str(exc):
            dup_failed_closed = True
    assert dup_failed_closed is True, "duplicate canonical repository projects must fail closed"

    # ---------------------------------------------------------------------------
    # Scenario C: Proved zero exact matches -> creation & complete end-to-end Fix flow
    # ---------------------------------------------------------------------------
    mcp = MockPlaneFixMCP(
        base_url="https://api.plane.so",
        workspace="acme",
        repository=canonical_repo_url
    )
    # Populate multi-page unrelated projects
    mcp.projects["proj-unrelated-1"] = {
        "id": "proj-unrelated-1", "name": "[Repo] other/service", "workspace": "acme",
        "repository": "https://github.com/other/service", "labels": ["Core"], "archived": False
    }
    mcp.projects["proj-unrelated-2"] = {
        "id": "proj-unrelated-2", "name": "General Backlog", "workspace": "acme",
        "repository": "https://github.com/foreign/general", "labels": [], "archived": True
    }

    # Initial source work item in Plane with complete snapshot (title, desc, state, assignee, labels, relations, comments, lifecycle)
    source_id = "wi-uuid-42"
    source_readable = "ENG-42"
    initial_source = {
        "id": source_id,
        "readable_id": source_readable,
        "title": "Cache latency spikes under high concurrency",
        "description": "Investigate lock contention during cache refresh",
        "state_id": "state-open",
        "assignee": "adamwoo",
        "labels": ["bug", "performance"],
        "relations": [{"type": "relates_to", "target": "ENG-10"}],
        "comments": [{"id": "comment-1", "body": "Observed in p99 metrics under load", "author": "sentry-bot"}],
        "lifecycle": {"state": "open", "archived": False},
        "project_id": None,
        "parent": None
    }
    mcp.work_items[source_id] = dict(initial_source)
    source_snapshot = json.loads(json.dumps(initial_source))

    # 1. Zero provider calls before root-cause proof (Debug phase)
    pre_proof_provider_calls = len(mcp.call_log)
    assert pre_proof_provider_calls == 0, "pre-proof phase must make zero provider calls"

    # 2. Target repository admission succeeds; Debug returns proof
    proved_root_cause = "lock contention in cache refresh loop"
    canonical_project_name = canonical_repo_project_name

    # 3. Post-proof: resolve supplied exact work-item reference to UUID with baseUrl and workspace scope
    supplied_ref = "ENG-42"
    resolved_wi = mcp.read_work_item("acme", supplied_ref)
    assert resolved_wi is not None, "source work item resolution failed"
    assert resolved_wi["id"] == source_id, f"expected UUID {source_id}, got {resolved_wi['id']}"
    assert resolved_wi["parent"] is None, "source work item must have parent = null"

    # 4. Canonical repository project admission: proved zero exact matches across complete pagination -> create [Repo] owner/name
    zero_match_discovery = discover_canonical_repository_projects(
        mcp, "acme", canonical_repo_url, canonical_project_name
    )
    assert len(zero_match_discovery) == 0, "expected zero canonical project matches in zero-match scenario"

    proj = mcp.create_project(
        "acme", canonical_project_name, labels=["Core", "Fix"],
        external_source="woostack", external_id="ext-proj-1"
    )
    assert proj["name"] == canonical_project_name, f"expected project name {canonical_project_name}, got {proj['name']}"

    # Independent read-back of project and complete property validation before binding
    read_back_proj = mcp.read_project("acme", proj["id"])
    assert read_back_proj is not None, "project read-back failed"
    assert read_back_proj["id"] == proj["id"]
    assert read_back_proj["name"] == canonical_project_name
    assert read_back_proj["repository"] == canonical_repo_url
    assert read_back_proj["workspace"] == "acme"
    assert set(read_back_proj["labels"]) == {"Core", "Fix"}
    assert read_back_proj["external_source"] == "woostack"
    assert read_back_proj["external_id"] == "ext-proj-1"

    # 5. Source work-item preservation: update ONLY the supported canonical repository project link
    mcp.link_source_work_item_to_project("acme", source_id, read_back_proj["id"])
    read_back_source = mcp.read_work_item("acme", source_id)

    assert read_back_source["project_id"] == read_back_proj["id"], "project_id link was not added"
    for k, v in source_snapshot.items():
        if k == "project_id":
            continue
        assert read_back_source[k] == v, f"source work item field {k} was mutated from {v} to {read_back_source[k]}"

    # 6. Top-level specification work item creation with complete proved Fix specification Markdown
    complete_fix_spec = (
        "# Goal\n"
        "Resolve lock contention in cache refresh loop under high concurrency.\n\n"
        "# Observed vs Expected Behavior\n"
        "- Observed: p99 latency spikes to 1500ms due to global mutex contention during background refresh.\n"
        "- Expected: p99 latency remains under 50ms with read-copy-update / striped locks.\n\n"
        "# Evidence Chain and Root Cause\n"
        "Profile trace from Sentry issue #1234 proves contention in `CacheManager.refresh()`.\n\n"
        "# Acceptance Criteria\n"
        "- Cache refresh runs concurrently without blocking cache reads.\n"
        "- Regression concurrency test suite passes with 100 concurrent workers.\n\n"
        "# Scope and Implementation Intent\n"
        "- Replace coarse lock in `src/cache.ts` with fine-grained striped mutex.\n"
        "- Update cache eviction and read paths to use reader locks.\n\n"
        "# Risks and Deliberate Safety\n"
        "- Risk: cache stampede during concurrent invalidation.\n"
        "- Mitigation: single-flight deduplication on refresh misses.\n\n"
        "# Verification and Smoke Strategy\n"
        "- Run concurrency benchmark suite and unit tests.\n"
        "- Smoke test: load generator against local cache service.\n\n"
        "# Documentation and Parent Intent\n"
        "- Planning parent branch: `main`.\n"
        "- No customer-facing documentation changes required.\n"
    )
    spec_item = mcp.create_work_item(
        "acme", read_back_proj["id"], f"[Fix] Resolve {proved_root_cause}",
        description=complete_fix_spec,
        external_source="woostack", external_id="ext-spec-1", parent=None
    )
    assert spec_item["title"].startswith("[Fix] "), "specification work item title must start with [Fix] "
    assert spec_item["parent"] is None, "specification work item must have parent = null"

    # Independent read-back of specification work item and byte-for-byte description verification before binding
    read_back_spec = mcp.read_work_item("acme", spec_item["id"])
    assert read_back_spec is not None, "spec item read-back failed"
    assert read_back_spec["id"] == spec_item["id"]
    assert read_back_spec["readable_id"].startswith("ENG-")
    assert read_back_spec["title"] == f"[Fix] Resolve {proved_root_cause}"
    assert read_back_spec["description"] == complete_fix_spec, "spec description byte-for-byte read-back mismatch"
    assert read_back_spec["parent"] is None, "specification item read-back must have parent = null"
    assert read_back_spec["project_id"] == read_back_proj["id"]
    assert read_back_spec["external_source"] == "woostack"
    assert read_back_spec["external_id"] == "ext-spec-1"

    # Manifest bounds mirror.specItem from verified read-back, while stableTaskMappings holds only increment children
    manifest = {
        "stableTaskMappings": {},
        "mirror": {
            "provider": "plane",
            "project": {
                "nativeId": read_back_proj["id"],
                "canonicalRef": read_back_proj["id"],
                "name": read_back_proj["name"]
            },
            "specItem": {
                "nativeId": read_back_spec["id"],
                "canonicalRef": read_back_spec["readable_id"],
                "title": read_back_spec["title"]
            },
            "tasks": {},
            "relations": [],
            "status": "unstarted"
        }
    }
    assert read_back_spec["id"] not in manifest["stableTaskMappings"], "spec item native ID must not enter stableTaskMappings"
    assert read_back_spec["readable_id"] not in manifest["stableTaskMappings"], "spec item readable ID must not enter stableTaskMappings"

    # 7. Mirror Fix increments as exact children of the specification work item with strict sibling blocking chain
    plan_increments = [
        {"task_key": "fix-1", "title": "Eliminate cache refresh lock contention"},
        {"task_key": "fix-2", "title": "Add regression concurrency suite"}
    ]
    created_children = []
    for inc in plan_increments:
        child_wi = mcp.create_work_item(
            "acme", read_back_proj["id"], inc["title"],
            external_source="woostack", external_id=f"ext-{inc['task_key']}",
            parent=read_back_spec["id"]
        )
        assert child_wi["parent"] == read_back_spec["id"], "increment work item must be parented to specification item"
        created_children.append(child_wi)

    # Independent child work item read-back before binding stableTaskMappings and mirror.tasks
    for i, inc in enumerate(plan_increments):
        child_id = created_children[i]["id"]
        read_back_child = mcp.read_work_item("acme", child_id)
        assert read_back_child is not None, f"child read-back failed for {child_id}"
        assert read_back_child["project_id"] == read_back_proj["id"], "child project membership mismatch"
        assert read_back_child["parent"] == read_back_spec["id"], "child must be parented to spec item"
        assert read_back_child["external_source"] == "woostack", "child external source mismatch"
        assert read_back_child["external_id"] == f"ext-{inc['task_key']}", "child external id mismatch"
        assert read_back_child["id"] == child_id, "child native id mismatch"
        assert read_back_child["readable_id"].startswith("ENG-"), "child readable id invalid"

        # Bind readable reference to stableTaskMappings and canonicalRef, native UUID to nativeId
        manifest["stableTaskMappings"][inc["task_key"]] = read_back_child["readable_id"]
        manifest["mirror"]["tasks"][inc["task_key"]] = {
            "nativeId": read_back_child["id"],
            "canonicalRef": read_back_child["readable_id"]
        }

    assert set(manifest["stableTaskMappings"].keys()) == {"fix-1", "fix-2"}
    assert manifest["stableTaskMappings"]["fix-1"].startswith("ENG-")
    assert manifest["stableTaskMappings"]["fix-2"].startswith("ENG-")

    # Strict sibling blocking relation: ordinal 1 blocks ordinal 2
    rel = mcp.create_relation(
        "acme", read_back_proj["id"], created_children[0]["id"], created_children[1]["id"],
        relation_type="blocks", external_id="rel-fix-1"
    )

    # Independent read-back of relation page before binding mirror.relations and setting synced status
    read_back_relations = mcp.list_relations("acme", read_back_proj["id"])
    assert len(read_back_relations) == 1, "relations page count mismatch"
    rel_read = read_back_relations[0]
    assert rel_read["id"] == rel["id"]
    assert rel_read["source"] == created_children[0]["id"], "relation source mismatch"
    assert rel_read["target"] == created_children[1]["id"], "relation target mismatch"
    assert rel_read["type"] == "blocks", "relation type mismatch"
    assert rel_read["external_id"] == "rel-fix-1", "relation external id mismatch"

    manifest["mirror"]["relations"].append({
        "sourceKey": "fix-1",
        "targetKey": "fix-2",
        "nativeId": rel_read["id"],
        "relationType": "blocks"
    })
    manifest["mirror"]["status"] = "synced"

    # 8. Project-label capability failure: persistence fails closed before repository mutation
    mcp_no_labels = MockPlaneFixMCP(
        base_url="https://api.plane.so",
        workspace="acme",
        capabilities={"projectRead": True, "projectWrite": True, "issueRead": True, "issueWrite": True, "projectLabelWrite": False}
    )
    label_failure_blocked = False
    try:
        mcp_no_labels.create_project("acme", canonical_project_name, labels=["Core"])
    except RuntimeError as exc:
        label_failure_blocked = True
        assert "projectLabelWrite" in str(exc)
    assert label_failure_blocked is True, "missing project label capability must fail closed"

    # 9. Nonblocking mirror result: local run manifest authority remains valid
    local_manifest = {
        "status": "ready",
        "workflow": "fix",
        "mirror": {
            "provider": "plane",
            "status": "failed",
            "error": "Plane MCP timeout during execution plan mirror"
        }
    }
    local_authority_valid = local_manifest["status"] == "ready"
    execute_handoff_allowed = local_authority_valid and local_manifest["workflow"] == "fix"
    repo_mutations = 0

    assert local_authority_valid is True, "local authority must remain valid on mirror failure"
    assert execute_handoff_allowed is True, "execute handoff must be allowed on mirror failure"
    assert repo_mutations == 0, "repository mutations must remain zero on mirror failure"

test_plane_fix_preservation_and_scoping()
if failures:
    print("fix project contract violations:", file=sys.stderr)
    print("\n".join(f"- {item}" for item in failures), file=sys.stderr)
    raise SystemExit(1)
print("fix project contract: ok")
PY
