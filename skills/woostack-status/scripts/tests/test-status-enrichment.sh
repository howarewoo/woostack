#!/usr/bin/env bash
# Status fixture harness: verifies Linear and Plane enrichment parity,
# identical repository-derived state, and absent-repo negative cases.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"

python3 - "$HERE" <<'PY'
import json, sys
from pathlib import Path

fixtures_dir = Path(sys.argv[1]) / "fixtures"

repo_snapshot = json.loads((fixtures_dir / "repository-snapshot.json").read_text())
linear_fixture = json.loads((fixtures_dir / "linear-enrichment.json").read_text())
plane_fixture = json.loads((fixtures_dir / "plane-enrichment.json").read_text())
unmatched_fixture = json.loads((fixtures_dir / "unmatched-repo-enrichment.json").read_text())

def derive_status_board(repo, artifact=None):
    rows = []
    canonical_repo = repo["canonicalRepository"]
    for branch in repo.get("branches", []):
        pr = branch.get("pullRequest")
        if not pr:
            state = "local"
        elif pr.get("draft"):
            state = "draft"
        elif pr.get("merged"):
            state = "merged"
        elif pr.get("reviewState") == "clean" and pr.get("unresolvedThreads", 0) == 0:
            state = "review-clean"
        else:
            state = "in-review"
        
        row = {
            "identity": branch["name"],
            "state": state,
            "prUrl": pr.get("url") if pr else None,
            "artifact": None,
            "enrichmentOmitted": False,
        }
        
        if artifact:
            # Check canonical repository association
            art_provider = artifact.get("provider")
            art_item = artifact.get("issue") if art_provider == "linear" else artifact.get("workItem")
            if art_item and art_item.get("canonicalRepository") == canonical_repo and pr and art_item.get("pullRequestNumber") == pr.get("number"):
                row["artifact"] = {
                    "provider": art_provider,
                    "identifier": art_item.get("identifier") or art_item.get("sequenceId"),
                    "url": art_item.get("url"),
                    "label": art_item.get("project", {}).get("name"),
                    "nativeState": art_item.get("state", {}).get("name"),
                }
            else:
                row["enrichmentOmitted"] = True
                
        rows.append(row)
    return rows

# Scenario 1: Baseline repository snapshot (no artifact)
base_rows = derive_status_board(repo_snapshot, None)
assert len(base_rows) == 1, "Baseline should have exactly 1 row"
assert base_rows[0]["state"] == "review-clean", "Baseline state must be review-clean"
assert base_rows[0]["artifact"] is None, "Baseline row must have no artifact enrichment"

# Scenario 2: Linear artifact enrichment
linear_rows = derive_status_board(repo_snapshot, linear_fixture)
assert len(linear_rows) == 1, "Linear enriched board should have exactly 1 row"
assert linear_rows[0]["state"] == "review-clean", "Linear state must not override repository review-clean state"
assert linear_rows[0]["artifact"]["provider"] == "linear", "Artifact provider must be linear"
assert linear_rows[0]["artifact"]["identifier"] == "APP-42", "Artifact identifier must be APP-42"
assert linear_rows[0]["artifact"]["label"] == "[Build] Auth subsystem", "Artifact label must match"

# Scenario 3: Plane artifact enrichment
plane_rows = derive_status_board(repo_snapshot, plane_fixture)
assert len(plane_rows) == 1, "Plane enriched board should have exactly 1 row"
assert plane_rows[0]["state"] == "review-clean", "Plane state must not override repository review-clean state"
assert plane_rows[0]["state"] == linear_rows[0]["state"], "Linear and Plane must yield identical repository row state"
assert plane_rows[0]["artifact"]["provider"] == "plane", "Artifact provider must be plane"
assert plane_rows[0]["artifact"]["identifier"] == "ENG-42", "Artifact identifier must be ENG-42"
assert plane_rows[0]["artifact"]["label"] == "[Build] Auth subsystem", "Artifact label must match"

# Scenario 4: Absent/unmatched repository negative case
unmatched_rows = derive_status_board(repo_snapshot, unmatched_fixture)
assert len(unmatched_rows) == 1, "Unmatched artifact must not create new rows"
assert unmatched_rows[0]["identity"] == "adamwoo/auth-subsystem", "Existing repo row remains unchanged"
assert unmatched_rows[0]["state"] == "review-clean", "Row state remains review-clean"
assert unmatched_rows[0]["artifact"] is None, "Unmatched artifact must not enrich repo row"
assert unmatched_rows[0]["enrichmentOmitted"] is True, "Enrichment omission must be recorded"

# Scenario 5: Empty repository snapshot negative case
empty_snapshot = {"canonicalRepository": "howarewoo/woostack", "branches": []}
empty_linear = derive_status_board(empty_snapshot, linear_fixture)
empty_plane = derive_status_board(empty_snapshot, plane_fixture)
assert len(empty_linear) == 0, "Artifacts cannot create board rows in empty repo (Linear)"
assert len(empty_plane) == 0, "Artifacts cannot create board rows in empty repo (Plane)"

print("status enrichment fixture parity and negative cases: ok")
PY
