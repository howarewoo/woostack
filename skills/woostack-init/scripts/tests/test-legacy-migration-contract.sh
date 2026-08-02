#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
if py -3 --version >/dev/null 2>&1; then
    PYTHON=(py -3)
else
    PYTHON=(python3)
fi
"${PYTHON[@]}" - "$ROOT" <<'PY'
import copy
import hashlib
import json
import os
import stat
import pathlib
import shutil
import subprocess
import sys
import tempfile

root = pathlib.Path(sys.argv[1])
init = root / "skills/woostack-init"
evals = json.loads((init / "evals/evals.json").read_text())
expected = {
    "creates-missing-active-resource-after-durable-recovery-receipt": "eligible",
    "migrates-active-records-by-stable-client-id": "blocked",
    "classifies-completed-records-from-exact-merge-evidence": "eligible",
    "blocks-historical-deletion-on-resource-reconciliation-failure": "blocked",
    "blocks-post-create-receipt-transition-failure-without-replay-or-deletion": "blocked",
    "blocks-ambiguous-legacy-classification-without-deletion": "blocked",
    "blocks-incomplete-migration-receipts-without-deletion": "blocked",
    "resumes-unknown-migration-outcome-by-stable-client-id": "blocked",
    "blocks-partial-migration-without-deleting-any-record": "blocked",
    "blocks-foreign-migration-resource-without-deletion": "blocked",
    "migrates-mixed-active-and-historical-records-by-subset": "eligible",
}
cases = {case["id"]: case for case in evals["cases"] if case["id"] in expected}
if set(cases) != set(expected):
    raise SystemExit("migration corpus cases drifted")

for case_id, mode in expected.items():
    case = cases[case_id]
    if "/woostack-init --migrate-legacy" not in case["prompt"]:
        raise SystemExit(f"{case_id}: does not invoke packaged migration owner")
    project_files = [path for path in case["fixtures"] if "/project/.woostack/" in path]
    recovery_files = [path for path in case["fixtures"] if "/git-recovery/.woostack/" in path]
    if not project_files or len(project_files) != len(recovery_files):
        raise SystemExit(f"{case_id}: representative source/recovery bytes are incomplete")
    for relative in project_files:
        source = init / "evals/fixtures" / relative
        recovery_relative = relative.replace("/project/", "/git-recovery/")
        recovery = init / "evals/fixtures" / recovery_relative
        if source.read_bytes() != recovery.read_bytes():
            raise SystemExit(f"{case_id}: recovery bytes differ for {relative}")
        digest = "sha256:" + hashlib.sha256(source.read_bytes()).hexdigest()
        matching = [a for a in case["assertions"] if a.get("sha256") == digest]
        if mode == "blocked" and not any(a.get("file") == f"fixtures/{relative}" for a in matching):
            raise SystemExit(f"{case_id}: blocked source lacks SHA-256 retention assertion")
        if not any(a.get("file") == f"fixtures/{recovery_relative}" for a in matching):
            raise SystemExit(f"{case_id}: Git recovery lacks SHA-256 assertion")
    writable = "write-workspace" in case["capabilities"]
    if writable != (mode == "eligible"):
        raise SystemExit(f"{case_id}: write capability does not match deletion eligibility")

historical = cases["classifies-completed-records-from-exact-merge-evidence"]
historical_fixture = json.loads(
    (init / "evals/fixtures/migration/historical-completed.json").read_text()
)
NULL_GIT_OID = "0" * 40
EXPECTED_REPOSITORY_ID = "R_kgDORP1kWw"
EXPECTED_PR_NUMBER = 571
CANONICAL_RECORDS = {
    ".woostack/plans/2026-07-30-hermetic-migration.md":
        b"---\ntype: plan\nstatus: done\n---\n\n# Hermetic migration plan\n",
    ".woostack/overnight/2026-07-30-hermetic-run.md":
        b"---\ntype: overnight\nstatus: complete\n---\n\n# Hermetic overnight run\n",
}
CANONICAL_RECORD_KINDS = {
    path: "plan" if path.startswith(".woostack/plans/") else "overnight"
    for path in CANONICAL_RECORDS
}
HISTORICAL_PROJECT_CLIENT_ID = "10101010-1010-4010-8010-101010101010"
HISTORICAL_PLAN_CLIENT_ID = "20202020-2020-4020-8020-202020202020"
HISTORICAL_COMMENT_CLIENT_ID = "30303030-3030-4030-8030-303030303030"
HISTORICAL_CLIENT_IDS = (
    HISTORICAL_PROJECT_CLIENT_ID,
    HISTORICAL_PLAN_CLIENT_ID,
    HISTORICAL_COMMENT_CLIENT_ID,
)
HISTORICAL_PROJECT_NATIVE_ID = "linear-project-historical-hermetic"
HISTORICAL_PLAN_NATIVE_ID = "linear-issue-historical-hermetic-plan"
HISTORICAL_COMMENT_NATIVE_ID = "linear-comment-historical-hermetic-run"
HISTORICAL_PLAN_PATH = ".woostack/plans/2026-07-30-hermetic-migration.md"
HISTORICAL_OVERNIGHT_PATH = ".woostack/overnight/2026-07-30-hermetic-run.md"
CANONICAL_REPOSITORY = "https://github.com/howarewoo/woostack"
REPRESENTATIVE_CHANGED_PATH = "skills/woostack-init/references/migration-authority.txt"
post_create_case = cases[
    "blocks-post-create-receipt-transition-failure-without-replay-or-deletion"
]
post_create_assertions = {
    assertion["pointer"]: assertion["expected"]
    for assertion in post_create_case["assertions"]
    if assertion["kind"] == "final-json-path-equals"
}
post_create_observation = historical_fixture["historicalImport"]["receiptPreflight"][
    "postCreateTransitionFailureObservation"
]
if post_create_observation != {
    "resourceType": "project",
    "clientId": HISTORICAL_PROJECT_CLIENT_ID,
    "lastDurableBoundary": "attempting/unknown",
    "providerCreateAcknowledged": True,
    "attemptedBoundary": "verified-complete",
    "receiptWriteOutcome": "payload-digest-mismatch",
}:
    raise SystemExit("post-create receipt transition observation drifted")
post_create_expected = {
    "/status": "blocked",
    "/reasonCode": "historical-receipt-transition-failed",
    "/resourceType": "project",
    "/mutationAcknowledged": True,
    "/durableBoundary": "attempting/unknown",
    "/failedTransition": "verified-complete",
    "/clientId": HISTORICAL_PROJECT_CLIENT_ID,
    "/stableIdRediscoveryRequired": True,
    "/directReadBackRequired": True,
    "/createReplayAllowed": False,
    "/remoteMutationCount": 1,
    "/localDeletions": [],
}
if any(
    post_create_assertions.get(pointer) != expected_value
    for pointer, expected_value in post_create_expected.items()
):
    raise SystemExit("post-create recovery assertions do not derive the safe outcome")


def write_receipt_no_clobber(path, payload):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as handle:
        handle.write(payload)
        handle.flush()
        os.fsync(handle.fileno())


def advance_receipt_compare_and_swap(path, last_read_payload, next_payload):
    current_payload = path.read_bytes()
    if current_payload != last_read_payload:
        return False, current_payload
    temporary = path.with_suffix(path.suffix + ".next")
    write_receipt_no_clobber(temporary, next_payload)
    os.replace(temporary, path)
    return True, next_payload


last_read_receipt = b'{"boundary":"never-attempted"}\n'
concurrent_receipt = b'{"boundary":"verified-complete"}\n'
receipt_write_observations = historical_fixture["historicalImport"]["receiptPreflight"][
    "receiptWriteConflictObservations"
]
if receipt_write_observations != {
    "initialCreate": {
        "receiptAlreadyExists": True,
        "explicitResumeArgument": None,
        "providerCallCount": 0,
    },
    "attemptingBoundaryTransition": {
        "lastReadPayloadSha256": "sha256:" + hashlib.sha256(last_read_receipt).hexdigest(),
        "currentPayloadSha256": "sha256:" + hashlib.sha256(concurrent_receipt).hexdigest(),
        "targetBoundary": "attempting/unknown",
        "providerCallCount": 0,
    },
}:
    raise SystemExit("receipt write conflict observations drifted")

with tempfile.TemporaryDirectory() as receipt_directory:
    receipt_path = pathlib.Path(receipt_directory) / "receipt.json"
    receipt_path.write_bytes(last_read_receipt)
    provider_calls = []
    try:
        write_receipt_no_clobber(receipt_path, concurrent_receipt)
    except FileExistsError:
        pass
    else:
        raise SystemExit("initial receipt collision overwrote an existing ledger")
    if receipt_path.read_bytes() != last_read_receipt or provider_calls:
        raise SystemExit("initial receipt collision reached a provider call")

    receipt_path.write_bytes(last_read_receipt)
    last_read_payload = receipt_path.read_bytes()
    receipt_path.write_bytes(concurrent_receipt)
    advanced, reloaded_payload = advance_receipt_compare_and_swap(
        receipt_path,
        last_read_payload,
        b'{"boundary":"attempting/unknown"}\n',
    )
    if advanced or reloaded_payload != concurrent_receipt or provider_calls:
        raise SystemExit("attempting-boundary CAS conflict was not reloaded before create")

    receipt_path.write_bytes(b'{"boundary":"attempting/unknown"}\n')
    last_read_payload = receipt_path.read_bytes()
    provider_calls.append("create-project")
    receipt_path.write_bytes(concurrent_receipt)
    advanced, reloaded_payload = advance_receipt_compare_and_swap(
        receipt_path,
        last_read_payload,
        concurrent_receipt,
    )
    if (
        advanced
        or reloaded_payload != concurrent_receipt
        or provider_calls != ["create-project"]
    ):
        raise SystemExit("post-create CAS conflict replayed the provider mutation")

receipt_write_counterfactual_results = {
    "initialNoClobberCollision": "blocked",
    "attemptingBoundaryCompareAndSwapConflict": "blocked",
}



def git(repository, *arguments, input_bytes=None, check=True, env=None):
    result = subprocess.run(
        ["git", "-C", str(repository), *arguments],
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env=env,
    )
    if check and result.returncode != 0:
        raise SystemExit(
            f"git {' '.join(arguments)} failed: {result.stderr.decode(errors='replace')}"
        )
    return result


def commit_environment(timestamp):
    environment = dict(**__import__("os").environ)
    environment.update({
        "GIT_AUTHOR_NAME": "Woostack Contract",
        "GIT_AUTHOR_EMAIL": "contract@example.invalid",
        "GIT_COMMITTER_NAME": "Woostack Contract",
        "GIT_COMMITTER_EMAIL": "contract@example.invalid",
        "GIT_AUTHOR_DATE": timestamp,
        "GIT_COMMITTER_DATE": timestamp,
    })
    return environment


def build_authority(repository):
    repository.mkdir()
    git(repository, "init", "-q", "-b", "main")
    (repository / "base.txt").write_bytes(b"deterministic base\n")
    git(repository, "add", "base.txt")
    git(repository, "commit", "-q", "-m", "base", env=commit_environment("2026-07-30T00:00:00Z"))
    base = git(repository, "rev-parse", "HEAD").stdout.decode().strip()

    git(repository, "checkout", "-q", "-b", "historical-head")
    for relative, canonical_bytes in CANONICAL_RECORDS.items():
        target = repository / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(canonical_bytes)
    representative = repository / REPRESENTATIVE_CHANGED_PATH
    representative.parent.mkdir(parents=True, exist_ok=True)
    representative.write_bytes(b"independent changed-path authority\n")
    git(repository, "add", ".")
    git(repository, "commit", "-q", "-m", "head", env=commit_environment("2026-07-30T00:01:00Z"))
    head = git(repository, "rev-parse", "HEAD").stdout.decode().strip()

    git(repository, "checkout", "-q", "main")
    git(
        repository,
        "merge",
        "-q",
        "--no-ff",
        "historical-head",
        "-m",
        "merge",
        env=commit_environment("2026-07-30T00:02:00Z"),
    )
    merge = git(repository, "rev-parse", "HEAD").stdout.decode().strip()
    changed_paths = git(
        repository, "diff", "--name-only", base, head
    ).stdout.decode().splitlines()
    return {
        "base": base,
        "head": head,
        "merge": merge,
        "changedPaths": changed_paths,
    }


def is_full_sha(value):
    return (
        isinstance(value, str)
        and len(value) == 40
        and value != NULL_GIT_OID
        and all(character in "0123456789abcdef" for character in value)
    )


def derived_fields(value, location=""):
    found = []
    if isinstance(value, dict):
        for key, child in value.items():
            child_location = f"{location}/{key}"
            normalized = "".join(character for character in key.lower() if character.isalnum())
            if (
                normalized in {"phase", "verified", "complete", "completed", "independent"}
                or normalized.endswith(("verified", "complete", "completed"))
            ):
                found.append(child_location)
            found.extend(derived_fields(child, child_location))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found.extend(derived_fields(child, f"{location}/{index}"))
    return found


def git_blob_oid(source_bytes):
    header = f"blob {len(source_bytes)}\0".encode()
    return hashlib.sha1(header + source_bytes).hexdigest()


def historical_group_key(authority):
    sources = [
        {
            "kind": CANONICAL_RECORD_KINDS[path],
            "path": path,
            "commit": authority["head"],
            "sourceSha256": "sha256:" + hashlib.sha256(CANONICAL_RECORDS[path]).hexdigest(),
        }
        for path in sorted(CANONICAL_RECORDS)
    ]
    canonical = json.dumps(
        {
            "canonicalRepository": CANONICAL_REPOSITORY,
            "sources": sources,
        },
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode()
    return "historical-group:v1:" + hashlib.sha256(canonical).hexdigest()


def historical_source_payload(path, authority):
    source_bytes = CANONICAL_RECORDS[path]
    return {
        "sourceBytes": source_bytes.decode(),
        "sourcePath": path,
        "sourceCommit": authority["head"],
        "sourceBlobObjectId": git_blob_oid(source_bytes),
        "sourceSha256": "sha256:" + hashlib.sha256(source_bytes).hexdigest(),
        "canonicalPullRequestUrl": (
            f"https://github.com/howarewoo/woostack/pull/{EXPECTED_PR_NUMBER}"
        ),
        "pullRequestNumber": EXPECTED_PR_NUMBER,
        "mergeCommit": authority["merge"],
    }


def historical_metadata(role, group_key=None):
    metadata = {
        "managedBy": "woostack",
        "canonicalRepository": CANONICAL_REPOSITORY,
        "repositoryId": EXPECTED_REPOSITORY_ID,
        "role": role,
        "referenceOnly": True,
        "grantsAuthority": False,
    }
    if group_key is not None:
        metadata["groupKey"] = group_key
    return metadata


def validate_historical_import(value, authority):
    imported = value.get("historicalImport")
    expected_fields = {
        "operationOrder",
        "receiptPreflight",
        "classificationPreflight",
        "groupingLedger",
        "resourceClientIds",
        "sourceResourceLedger",
        "preCreateStableIdDiscoveryPages",
        "stableIdDiscoveryPages",
        "mutationObservations",
        "independentReads",
        "terminalPreDeleteSnapshot",
    }
    if not isinstance(imported, dict) or set(imported) != expected_fields:
        return None

    group_key = historical_group_key(authority)
    expected_ids = {
        "project": HISTORICAL_PROJECT_CLIENT_ID,
        "planIssue": HISTORICAL_PLAN_CLIENT_ID,
        "overnightComment": HISTORICAL_COMMENT_CLIENT_ID,
    }
    expected_order = [
        "classify-records-and-groups",
        "derive-receipt-path",
        "acquire-exclusive-receipt-operation-lock",
        "observe-receipt-absence-or-require-explicit-resume",
        "discover-existing-resources-by-provenance",
        "allocate-or-reuse-immutable-client-id-ledger",
        "persist-recovery-receipt",
        "pre-create-discover-project-by-client-id",
        "compare-and-swap-project-attempting-unknown",
        "create-project",
        "post-create-discover-project-by-client-id",
        "direct-read-project",
        "compare-and-swap-project-verified-complete",
        "pre-create-discover-issue-by-client-id",
        "compare-and-swap-issue-attempting-unknown",
        "create-issue",
        "post-create-discover-issue-by-client-id",
        "direct-read-issue",
        "compare-and-swap-issue-verified-complete",
        "pre-create-discover-comment-by-client-id",
        "compare-and-swap-comment-attempting-unknown",
        "create-comment",
        "post-create-discover-comment-by-client-id",
        "direct-read-comment",
        "compare-and-swap-comment-verified-complete",
        "capture-fresh-terminal-pre-delete-snapshot",
        "pin-and-revalidate-source-files",
        "stage-and-verify-private-quarantine",
        "delete-source-set",
    ]
    receipt_handle = (
        "woostack-migration:v1:"
        + "d" * 64
        + ":"
        + "e" * 64
    )
    expected_receipt = {
        "derivedPath": (
            "/home/eval/.local/state/woostack/migrations/"
            + "d" * 64
            + "/"
            + "e" * 64
            + ".json"
        ),
        "portableHandle": receipt_handle,
        "operationLock": {
            "path": (
                "/home/eval/.local/state/woostack/migrations/"
                + "d" * 64
                + "/"
                + "e" * 64
                + ".json.lock"
            ),
            "mode": "exclusive-nonblocking",
            "acquired": True,
            "heldThrough": "terminal-result",
            "contentionDisposition": "blocked",
            "receiptWriteMode": "no-clobber-compare-and-swap",
        },
        "lostReceiptProvenanceDiscovery": {
            "groupKey": group_key,
            "sourceSha256s": sorted([
                historical_source_payload(path, authority)["sourceSha256"]
                for path in CANONICAL_RECORDS
            ]),
            "projectPages": [{"matches": [], "nextCursor": None}],
            "issuePages": [{"matches": [], "nextCursor": None}],
            "commentPages": [{"matches": [], "nextCursor": None}],
            "priorMappingDisposition": "absent",
        },
        "observedExistingReceipt": None,
        "explicitResumeArgument": None,
        "allocationMode": "allocate-after-proven-absence",
        "resourceAttemptBoundaries": {
            "project": "never-attempted",
            "planIssue": "never-attempted",
            "overnightComment": "never-attempted",
        },
        "resourceAttemptTransitionHistory": [
            {
                "resourceType": resource_type,
                "clientId": client_id,
                "beforeProviderCall": "attempting/unknown",
                "beforeProviderCallReceiptWrite": "no-clobber-compare-and-swap",
                "afterDirectRead": "verified-complete",
                "afterDirectReadReceiptWrite": "no-clobber-compare-and-swap",
            }
            for resource_type, client_id in (
                ("project", HISTORICAL_PROJECT_CLIENT_ID),
                ("issue", HISTORICAL_PLAN_CLIENT_ID),
                ("comment", HISTORICAL_COMMENT_CLIENT_ID),
            )
        ],
        "receiptWriteConflictObservations": {
            "initialCreate": {
                "receiptAlreadyExists": True,
                "explicitResumeArgument": None,
                "providerCallCount": 0,
            },
            "attemptingBoundaryTransition": {
                "lastReadPayloadSha256": (
                    "sha256:" + hashlib.sha256(last_read_receipt).hexdigest()
                ),
                "currentPayloadSha256": (
                    "sha256:" + hashlib.sha256(concurrent_receipt).hexdigest()
                ),
                "targetBoundary": "attempting/unknown",
                "providerCallCount": 0,
            },
        },
        "postCreateTransitionFailureObservation": {
            "resourceType": "project",
            "clientId": HISTORICAL_PROJECT_CLIENT_ID,
            "lastDurableBoundary": "attempting/unknown",
            "providerCreateAcknowledged": True,
            "attemptedBoundary": "verified-complete",
            "receiptWriteOutcome": "payload-digest-mismatch",
        },
        "existingReceiptResumeObservation": {
            "portableHandle": receipt_handle,
            "explicitResumeArgument": receipt_handle,
            "allocationMode": "reuse-immutable-ledger",
            "resourceClientIds": expected_ids,
            "resourceAttemptBoundaries": {
                "project": "verified-complete",
                "planIssue": "attempting/unknown",
                "overnightComment": "never-attempted",
            },
            "resumeStableIdDiscoveryPages": [
                {
                    "resourceType": "project",
                    "clientId": HISTORICAL_PROJECT_CLIENT_ID,
                    "attemptBoundary": "verified-complete",
                    "pages": [{
                        "matches": [{
                            "nativeId": HISTORICAL_PROJECT_NATIVE_ID,
                            "repositoryId": EXPECTED_REPOSITORY_ID,
                            "workspace": "Acme",
                            "team": "APP",
                            "role": "historical-project",
                        }],
                        "nextCursor": None,
                    }],
                },
                {
                    "resourceType": "issue",
                    "clientId": HISTORICAL_PLAN_CLIENT_ID,
                    "attemptBoundary": "attempting/unknown",
                    "pages": [{
                        "matches": [],
                        "nextCursor": None,
                    }],
                },
            ],
            "resumeDirectReadNativeIds": [HISTORICAL_PROJECT_NATIVE_ID],
            "resumeOperationOrder": [
                "discover-project-by-client-id",
                "direct-read-project",
                "discover-issue-by-client-id",
                "block-zero-match-at-unknown-boundary",
            ],
            "createReplayAllowed": False,
        },
    }
    expected_classification = {
        "groupResults": [{
            "groupKey": group_key,
            "memberClassifications": {
                HISTORICAL_OVERNIGHT_PATH: "historical-completed",
                HISTORICAL_PLAN_PATH: "historical-completed",
            },
            "disposition": "import",
        }],
        "mixedLifecycleCounterfactual": {
            "groupKey": "historical-group:v1:" + "f" * 64,
            "memberClassifications": {
                ".woostack/specs/counterfactual.md": "active",
                ".woostack/plans/counterfactual.md": "historical-completed",
            },
            "disposition": "preservation-only",
            "remoteMutationCount": 0,
        },
    }
    expected_grouping = [{
        "groupKey": group_key,
        "specificationPaths": [],
        "planPath": HISTORICAL_PLAN_PATH,
        "overnightPaths": [HISTORICAL_OVERNIGHT_PATH],
        "projectClientId": HISTORICAL_PROJECT_CLIENT_ID,
        "planIssueClientId": HISTORICAL_PLAN_CLIENT_ID,
    }]

    def ledger_entry(path, kind, resource_type, client_id, native_id, container_id):
        source = historical_source_payload(path, authority)
        return {
            "sourcePath": path,
            "sourceKind": kind,
            "resourceType": resource_type,
            "resourceClientId": client_id,
            "resourceNativeId": native_id,
            "containerClientId": container_id,
            "sourceCommit": source["sourceCommit"],
            "sourceBlobObjectId": source["sourceBlobObjectId"],
            "sourceSha256": source["sourceSha256"],
            "canonicalPullRequestUrl": source["canonicalPullRequestUrl"],
            "pullRequestNumber": source["pullRequestNumber"],
            "mergeCommit": source["mergeCommit"],
        }

    expected_ledger = [
        ledger_entry(
            HISTORICAL_PLAN_PATH,
            "plan",
            "issue",
            HISTORICAL_PLAN_CLIENT_ID,
            HISTORICAL_PLAN_NATIVE_ID,
            HISTORICAL_PROJECT_CLIENT_ID,
        ),
        ledger_entry(
            HISTORICAL_OVERNIGHT_PATH,
            "overnight",
            "comment",
            HISTORICAL_COMMENT_CLIENT_ID,
            HISTORICAL_COMMENT_NATIVE_ID,
            HISTORICAL_PLAN_CLIENT_ID,
        ),
    ]

    def precreate_discovery(resource_type, client_id, container_native_id=None):
        observation = {
            "resourceType": resource_type,
            "clientId": client_id,
            "attemptBoundary": "never-attempted",
            "pages": [{
                "matches": [],
                "nextCursor": None,
            }],
        }
        if container_native_id is not None:
            observation["containerNativeId"] = container_native_id
        return observation

    expected_precreate_discoveries = [
        precreate_discovery("project", HISTORICAL_PROJECT_CLIENT_ID),
        precreate_discovery(
            "issue",
            HISTORICAL_PLAN_CLIENT_ID,
            HISTORICAL_PROJECT_NATIVE_ID,
        ),
        precreate_discovery(
            "comment",
            HISTORICAL_COMMENT_CLIENT_ID,
            HISTORICAL_PLAN_NATIVE_ID,
        ),
    ]

    def discovery(resource_type, client_id, native_id, role):
        return {
            "resourceType": resource_type,
            "clientId": client_id,
            "pages": [{
                "matches": [{
                    "nativeId": native_id,
                    "repositoryId": EXPECTED_REPOSITORY_ID,
                    "workspace": "Acme",
                    "team": "APP",
                    "role": role,
                }],
                "nextCursor": None,
            }],
        }

    expected_discoveries = [
        discovery(
            "project",
            HISTORICAL_PROJECT_CLIENT_ID,
            HISTORICAL_PROJECT_NATIVE_ID,
            "historical-project",
        ),
        discovery(
            "issue",
            HISTORICAL_PLAN_CLIENT_ID,
            HISTORICAL_PLAN_NATIVE_ID,
            "historical-plan",
        ),
        discovery(
            "comment",
            HISTORICAL_COMMENT_CLIENT_ID,
            HISTORICAL_COMMENT_NATIVE_ID,
            "historical-overnight",
        ),
    ]
    expected_mutations = [
        {"operation": "create-project", "clientId": HISTORICAL_PROJECT_CLIENT_ID},
        {"operation": "create-issue", "clientId": HISTORICAL_PLAN_CLIENT_ID},
        {"operation": "create-comment", "clientId": HISTORICAL_COMMENT_CLIENT_ID},
    ]
    reads = imported.get("independentReads")
    if (
        imported.get("operationOrder") != expected_order
        or expected_order.index("derive-receipt-path")
        > expected_order.index("allocate-or-reuse-immutable-client-id-ledger")
        or imported.get("receiptPreflight") != expected_receipt
        or imported.get("classificationPreflight") != expected_classification
        or imported.get("groupingLedger") != expected_grouping
        or imported.get("resourceClientIds") != expected_ids
        or len(set(imported.get("resourceClientIds", {}).values())) != len(HISTORICAL_CLIENT_IDS)
        or imported.get("sourceResourceLedger") != expected_ledger
        or imported.get("preCreateStableIdDiscoveryPages")
        != expected_precreate_discoveries
        or imported.get("stableIdDiscoveryPages") != expected_discoveries
        or imported.get("mutationObservations") != expected_mutations
        or not isinstance(reads, dict)
        or set(reads) != {
            "projects",
            "issues",
            "comments",
            "projectIssueMembershipPages",
            "issueRelationPages",
            "issueCommentPages",
        }
    ):
        return None

    expected_project = {
        "clientId": HISTORICAL_PROJECT_CLIENT_ID,
        "nativeId": HISTORICAL_PROJECT_NATIVE_ID,
        "title": "[Historical] Hermetic migration",
        "workspace": "Acme",
        "team": "APP",
        "statusType": "completed",
        "lead": None,
        "members": [],
        "metadata": historical_metadata("historical-project", group_key),
        "overview": {
            "specificationSource": None,
            "specificationAbsence": "no-related-specification-record",
            "canonicalPullRequestUrl": (
                f"https://github.com/howarewoo/woostack/pull/{EXPECTED_PR_NUMBER}"
            ),
            "mergeCommit": authority["merge"],
        },
    }
    expected_issue = {
        "clientId": HISTORICAL_PLAN_CLIENT_ID,
        "nativeId": HISTORICAL_PLAN_NATIVE_ID,
        "title": "[Historical] Hermetic migration plan",
        "workspace": "Acme",
        "team": "APP",
        "projectNativeId": HISTORICAL_PROJECT_NATIVE_ID,
        "parentNativeId": None,
        "stateType": "completed",
        "assignee": None,
        "metadata": historical_metadata("historical-plan"),
        "description": historical_source_payload(HISTORICAL_PLAN_PATH, authority),
    }
    expected_comment = {
        "clientId": HISTORICAL_COMMENT_CLIENT_ID,
        "nativeId": HISTORICAL_COMMENT_NATIVE_ID,
        "issueNativeId": HISTORICAL_PLAN_NATIVE_ID,
        "author": "migration-principal",
        "metadata": {
            **historical_metadata("historical-overnight"),
            "verificationKind": "historical-handback",
        },
        "body": historical_source_payload(HISTORICAL_OVERNIGHT_PATH, authority),
    }
    expected_membership = [{
        "projectNativeId": HISTORICAL_PROJECT_NATIVE_ID,
        "issueNativeIds": [HISTORICAL_PLAN_NATIVE_ID],
        "nextCursor": None,
    }]
    expected_relations = [{
        "issueNativeId": HISTORICAL_PLAN_NATIVE_ID,
        "relationTuples": [],
        "nextCursor": None,
    }]
    expected_comments = [{
        "issueNativeId": HISTORICAL_PLAN_NATIVE_ID,
        "commentNativeIds": [HISTORICAL_COMMENT_NATIVE_ID],
        "nextCursor": None,
    }]
    plan_source = historical_source_payload(HISTORICAL_PLAN_PATH, authority)
    overnight_source = historical_source_payload(HISTORICAL_OVERNIGHT_PATH, authority)
    expected_terminal_direct_reads = [
        {
            "resourceType": "project",
            "clientId": HISTORICAL_PROJECT_CLIENT_ID,
            "nativeId": HISTORICAL_PROJECT_NATIVE_ID,
            "repositoryId": EXPECTED_REPOSITORY_ID,
            "role": "historical-project",
            "statusType": "completed",
            "lead": None,
            "members": [],
            "referenceOnly": True,
            "grantsAuthority": False,
            "groupKey": group_key,
            "specificationAbsence": "no-related-specification-record",
            "canonicalPullRequestUrl": (
                f"https://github.com/howarewoo/woostack/pull/{EXPECTED_PR_NUMBER}"
            ),
            "mergeCommit": authority["merge"],
        },
        {
            "resourceType": "issue",
            "clientId": HISTORICAL_PLAN_CLIENT_ID,
            "nativeId": HISTORICAL_PLAN_NATIVE_ID,
            "repositoryId": EXPECTED_REPOSITORY_ID,
            "role": "historical-plan",
            "stateType": "completed",
            "assignee": None,
            "projectNativeId": HISTORICAL_PROJECT_NATIVE_ID,
            "referenceOnly": True,
            "grantsAuthority": False,
            **{
                key: plan_source[key]
                for key in (
                    "sourceBytes",
                    "sourcePath",
                    "sourceCommit",
                    "sourceBlobObjectId",
                    "sourceSha256",
                    "canonicalPullRequestUrl",
                    "pullRequestNumber",
                    "mergeCommit",
                )
            },
        },
        {
            "resourceType": "comment",
            "clientId": HISTORICAL_COMMENT_CLIENT_ID,
            "nativeId": HISTORICAL_COMMENT_NATIVE_ID,
            "repositoryId": EXPECTED_REPOSITORY_ID,
            "role": "historical-overnight",
            "issueNativeId": HISTORICAL_PLAN_NATIVE_ID,
            "referenceOnly": True,
            "grantsAuthority": False,
            **{
                key: overnight_source[key]
                for key in (
                    "sourceBytes",
                    "sourcePath",
                    "sourceCommit",
                    "sourceBlobObjectId",
                    "sourceSha256",
                    "canonicalPullRequestUrl",
                    "pullRequestNumber",
                    "mergeCommit",
                )
            },
        },
    ]
    expected_source_file_reads = [
        {
            "path": path,
            "fileType": "regular",
            "noFollow": True,
            "descriptorPinned": True,
            "descriptorHeldThroughDeletion": True,
            "sourceBytes": CANONICAL_RECORDS[path].decode(),
            "sourceSha256": historical_source_payload(path, authority)["sourceSha256"],
            "preUnlinkIdentityStable": True,
            "quarantineIdentityCheck": "matched-pinned-descriptor",
        }
        for path in sorted(CANONICAL_RECORDS)
    ]
    terminal = imported.get("terminalPreDeleteSnapshot")
    if (
        reads.get("projects") != [expected_project]
        or reads.get("issues") != [expected_issue]
        or reads.get("comments") != [expected_comment]
        or reads.get("projectIssueMembershipPages") != expected_membership
        or reads.get("issueRelationPages") != expected_relations
        or reads.get("issueCommentPages") != expected_comments
        or terminal != {
            "snapshotId": "historical-terminal-read-0001",
            "capturedAfterMutationClientIds": list(HISTORICAL_CLIENT_IDS),
            "stableIdDiscoveryPages": expected_discoveries,
            "directReads": expected_terminal_direct_reads,
            "sourceFileReads": expected_source_file_reads,
            "projectIssueMembershipPages": expected_membership,
            "issueRelationPages": expected_relations,
            "issueCommentPages": expected_comments,
        }
    ):
        return None
    return imported


def validate_historical_raw_evidence(value, authority):
    legacy_records = value.get("legacyRecords")
    pull_request = value.get("pullRequestObservation")
    recovery_entries = value.get("gitRecoveryObservations")
    if (
        not isinstance(legacy_records, list)
        or not isinstance(pull_request, dict)
        or not isinstance(recovery_entries, list)
        or any(
            not isinstance(record, dict)
            or not isinstance(record.get("path"), str)
            or record.get("kind") not in {"plan", "overnight"}
            for record in legacy_records
        )
        or any(
            not isinstance(observation, dict)
            or not isinstance(observation.get("path"), str)
            or not is_full_sha(observation.get("sourceCommit"))
            or not isinstance(observation.get("sha256"), str)
            for observation in recovery_entries
        )
    ):
        return None
    historical_path_list = [record["path"] for record in legacy_records]
    historical_paths = set(historical_path_list)
    changed_paths = pull_request.get("changedPaths")
    recovery_observations = {entry["path"]: entry for entry in recovery_entries}
    expected_paths = set(CANONICAL_RECORDS)
    if (
        derived_fields(value)
        or set(value) != {
            "repositoryId",
            "legacyRecords",
            "pullRequestObservation",
            "gitRecoveryObservations",
            "historicalImport",
        }
        or historical_paths != expected_paths
        or len(historical_paths) != len(historical_path_list)
        or {record["kind"] for record in legacy_records} != {"plan", "overnight"}
        or any(
            record["kind"] != CANONICAL_RECORD_KINDS.get(record["path"])
            for record in legacy_records
        )
        or value.get("repositoryId") != EXPECTED_REPOSITORY_ID
        or pull_request.get("repositoryId") != EXPECTED_REPOSITORY_ID
        or not isinstance(pull_request.get("number"), int)
        or isinstance(pull_request.get("number"), bool)
        or pull_request.get("number") != EXPECTED_PR_NUMBER
        or pull_request.get("state") != "MERGED"
        or pull_request.get("baseCommit") != authority["base"]
        or pull_request.get("headCommit") != authority["head"]
        or pull_request.get("mergeCommit") != authority["merge"]
        or changed_paths != authority["changedPaths"]
        or len(changed_paths) != len(set(changed_paths))
        or not expected_paths.issubset(changed_paths)
        or set(recovery_observations) != expected_paths
        or len(recovery_observations) != len(recovery_entries)
        or validate_historical_import(value, authority) is None
    ):
        return None
    return historical_path_list, pull_request, recovery_observations


def validate_historical_recovery(
    value,
    recovery_root,
    repository,
    authority,
    after_record_validated=None,
    verify_topology=True,
):
    validated = validate_historical_raw_evidence(value, authority)
    if validated is None:
        return None
    historical_paths, pull_request, recovery_observations = validated
    if verify_topology:
        for ancestor in (authority["base"], authority["head"]):
            if git(repository, "merge-base", "--is-ancestor", ancestor, authority["merge"],
                   check=False).returncode != 0:
                return None
        merge_parents = git(
            repository, "show", "-s", "--format=%P", authority["merge"]
        ).stdout.decode().split()
        if merge_parents != [authority["base"], authority["head"]]:
            return None

    expected_provenance = []
    for record in value["legacyRecords"]:
        path = record["path"]
        recovery = recovery_observations[path]
        object_result = git(repository, "show", f"{authority['head']}:{path}", check=False)
        recovery_file = recovery_root / path
        expected_token = f"git:{authority['head'][:7]}:{path}"
        if object_result.returncode != 0 or not recovery_file.is_file():
            return None
        object_bytes = object_result.stdout
        digest = "sha256:" + hashlib.sha256(object_bytes).hexdigest()
        if (
            object_bytes != CANONICAL_RECORDS[path]
            or record.get("provenance") != [expected_token]
            or recovery.get("sourceCommit") != authority["head"]
            or recovery.get("sha256") != digest
            or recovery_file.read_bytes() != object_bytes
        ):
            return None
        expected_provenance.append(expected_token)
        if after_record_validated is not None:
            after_record_validated(path)
    expected_provenance.append(
        f"pr:{pull_request['number']}@{pull_request['mergeCommit'][:7]}"
    )
    return historical_paths, pull_request, recovery_observations, expected_provenance


def migrate_historical_source_set(
    value,
    source_root,
    recovery_root,
    repository,
    authority,
    delete_source=lambda path: path.unlink(),
    after_record_validated=None,
    before_terminal_snapshot=None,
    before_source_pin=None,
    before_source_unlink=None,
    restore_on_failure=True,
):
    validated = validate_historical_recovery(
        value,
        recovery_root,
        repository,
        authority,
        after_record_validated=after_record_validated,
    )
    if validated is None:
        return None

    historical_paths, pull_request, recovery_observations, expected_provenance = validated
    source_bytes = {}
    for path in historical_paths:
        source = source_root / path
        object_result = git(repository, "show", f"{authority['head']}:{path}", check=False)
        if object_result.returncode != 0 or not source.is_file():
            return None
        object_bytes = object_result.stdout
        if (
            source.read_bytes() != object_bytes
            or "sha256:" + hashlib.sha256(object_bytes).hexdigest()
            != recovery_observations[path]["sha256"]
        ):
            return None
        source_bytes[path] = object_bytes
    if before_terminal_snapshot is not None:
        before_terminal_snapshot(value)
    terminal_validated = validate_historical_recovery(
        value,
        recovery_root,
        repository,
        authority,
    )
    if terminal_validated is None:
        return None
    validated = terminal_validated
    if before_source_pin is not None:
        before_source_pin()

    class SourceRevalidationBlocked(Exception):
        pass

    pinned_descriptors = {}
    pinned_identities = {}
    quarantine_root = source_root / ".woostack-migration-quarantine"
    staged_paths = {}

    def restore_staged_sources():
        for path in historical_paths:
            source = source_root / path
            staged = staged_paths.get(path)
            restored = False
            source.parent.mkdir(parents=True, exist_ok=True)
            if staged is not None and os.path.lexists(staged):
                if os.path.lexists(source):
                    raise RuntimeError("rollback source path was concurrently recreated")
                os.rename(staged, source)
                restored = True
            elif not os.path.lexists(source):
                source.write_bytes(source_bytes[path])
                restored = True
            if restored and (
                source.is_symlink()
                or not source.is_file()
                or source.read_bytes() != source_bytes[path]
            ):
                raise RuntimeError("historical source rollback verification failed")

    try:
        for path in historical_paths:
            source = source_root / path
            descriptor = os.open(
                source,
                os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0),
            )
            pinned_descriptors[path] = descriptor
            identity = os.fstat(descriptor)
            if not stat.S_ISREG(identity.st_mode):
                raise SourceRevalidationBlocked
            with os.fdopen(os.dup(descriptor), "rb") as handle:
                pinned_bytes = handle.read()
            if pinned_bytes != source_bytes[path]:
                raise SourceRevalidationBlocked
            source_bytes[path] = pinned_bytes
            pinned_identities[path] = (
                identity.st_dev,
                identity.st_ino,
                stat.S_IFMT(identity.st_mode),
            )

        if before_source_unlink is not None:
            before_source_unlink()
        if os.path.lexists(quarantine_root):
            raise SourceRevalidationBlocked
        quarantine_root.mkdir(mode=0o700)

        for path in historical_paths:
            source = source_root / path
            try:
                current_identity = os.lstat(source)
            except OSError as error:
                raise SourceRevalidationBlocked from error
            if (
                stat.S_ISLNK(current_identity.st_mode)
                or (
                    current_identity.st_dev,
                    current_identity.st_ino,
                    stat.S_IFMT(current_identity.st_mode),
                )
                != pinned_identities[path]
            ):
                raise SourceRevalidationBlocked

            staged = quarantine_root / path
            staged.parent.mkdir(parents=True, exist_ok=True)
            os.rename(source, staged)
            staged_paths[path] = staged
            staged_identity = os.lstat(staged)
            if (
                (
                    staged_identity.st_dev,
                    staged_identity.st_ino,
                    stat.S_IFMT(staged_identity.st_mode),
                )
                != pinned_identities[path]
                or os.fstat(pinned_descriptors[path]).st_ino != staged_identity.st_ino
                or staged.read_bytes() != source_bytes[path]
            ):
                raise SourceRevalidationBlocked

        for path in historical_paths:
            delete_source(staged_paths[path])
        if any(os.path.lexists(staged_paths[path]) for path in historical_paths):
            raise RuntimeError("historical migration left a quarantined source undeleted")
        if any(os.path.lexists(source_root / path) for path in historical_paths):
            raise RuntimeError("historical source path was concurrently recreated")
    except SourceRevalidationBlocked:
        if staged_paths:
            restore_staged_sources()
        return None
    except Exception:
        # Deletion is migration-wide. Restore the complete source set from the independently
        # verified, descriptor-pinned bytes before surfacing any partial failure.
        if restore_on_failure:
            restore_staged_sources()
        raise
    finally:
        for descriptor in pinned_descriptors.values():
            os.close(descriptor)
        if (
            quarantine_root.is_dir()
            and not any(path.is_file() or path.is_symlink() for path in quarantine_root.rglob("*"))
        ):
            shutil.rmtree(quarantine_root)

    recovered = {
        path: git(repository, "show", f"{authority['head']}:{path}").stdout
        for path in historical_paths
    }
    if recovered != source_bytes:
        raise RuntimeError("historical migration cannot recover deleted source bytes")
    return validated


def replace_repository_ids(value, repository_id):
    value["repositoryId"] = repository_id
    value["pullRequestObservation"]["repositoryId"] = repository_id


authority_temporary = tempfile.TemporaryDirectory()
authority_repository = pathlib.Path(authority_temporary.name) / "authority"
authority = build_authority(authority_repository)
recovery_root = init / "evals/fixtures/migration/historical-completed/git-recovery"
validated_historical = validate_historical_recovery(
    historical_fixture, recovery_root, authority_repository, authority
)
if validated_historical is None:
    raise SystemExit("historical migration must bind fixture evidence to the hermetic Git authority")
historical_paths, pull_request, recovery_observations, expected_provenance = validated_historical

mutations = (
    ("zero PR number", lambda value: value["pullRequestObservation"].update(number=0)),
    ("negative PR number", lambda value: value["pullRequestObservation"].update(number=-1)),
    ("Boolean PR number", lambda value: value["pullRequestObservation"].update(number=True)),
    ("foreign repository", lambda value: replace_repository_ids(value, "repo-foreign")),
    ("Boolean repository", lambda value: replace_repository_ids(value, True)),
    ("wrong state", lambda value: value["pullRequestObservation"].update(state="OPEN")),
    ("null head", lambda value: value["pullRequestObservation"].update(headCommit=NULL_GIT_OID)),
    ("malformed merge", lambda value: value["pullRequestObservation"].update(mergeCommit="bad")),
    ("wrong base", lambda value: value["pullRequestObservation"].update(baseCommit=authority["head"])),
    ("wrong head", lambda value: value["pullRequestObservation"].update(headCommit=authority["base"])),
    ("missing changed path", lambda value: value["pullRequestObservation"]["changedPaths"].pop()),
    ("duplicate changed path", lambda value: value["pullRequestObservation"]["changedPaths"].append(
        value["pullRequestObservation"]["changedPaths"][0])),
    ("duplicate recovery", lambda value: value["gitRecoveryObservations"].append(
        copy.deepcopy(value["gitRecoveryObservations"][0]))),
    ("swapped record kinds", lambda value: [
        record.update(kind="plan" if record["kind"] == "overnight" else "overnight")
        for record in value["legacyRecords"]
    ]),
    ("unknown record kind", lambda value: value["legacyRecords"][0].update(kind="unknown")),
    ("duplicate record kind", lambda value: value["legacyRecords"][0].update(
        kind=value["legacyRecords"][1]["kind"])),
    ("kind path mismatch", lambda value: value["legacyRecords"][0].update(kind="plan")),
    ("derived receipt", lambda value: value.update(receiptComplete=True)),
)
for label, mutate in mutations:
    counterfactual = copy.deepcopy(historical_fixture)
    mutate(counterfactual)
    if validate_historical_raw_evidence(counterfactual, authority) is not None:
        raise SystemExit(f"historical migration accepts {label}")

historical_resource_counterfactuals = {
    "readBack": {
        "absent": lambda value: value["historicalImport"]["independentReads"].update(issues=[]),
        "foreign": lambda value: value["historicalImport"]["independentReads"]["issues"][0][
            "metadata"
        ].update(repositoryId="repo-foreign"),
        "duplicated": lambda value: value["historicalImport"]["independentReads"]["projects"].append(
            copy.deepcopy(value["historicalImport"]["independentReads"]["projects"][0])
        ),
    },
    "membership": {
        "absent": lambda value: value["historicalImport"]["independentReads"].update(
            projectIssueMembershipPages=[]
        ),
        "foreign": lambda value: value["historicalImport"]["independentReads"][
            "projectIssueMembershipPages"
        ][0].update(projectNativeId="linear-project-foreign"),
        "duplicated": lambda value: value["historicalImport"]["independentReads"][
            "projectIssueMembershipPages"
        ][0]["issueNativeIds"].append(HISTORICAL_PLAN_NATIVE_ID),
    },
    "relation": {
        "absent": lambda value: value["historicalImport"]["independentReads"].update(
            issueRelationPages=[]
        ),
        "foreign": lambda value: value["historicalImport"]["independentReads"][
            "issueRelationPages"
        ][0]["relationTuples"].append(
            [HISTORICAL_PLAN_NATIVE_ID, "linear-issue-foreign", "blocks"]
        ),
        "duplicated": lambda value: value["historicalImport"]["independentReads"][
            "issueRelationPages"
        ][0]["relationTuples"].extend([
            [HISTORICAL_PLAN_NATIVE_ID, "linear-issue-foreign", "blocks"],
            [HISTORICAL_PLAN_NATIVE_ID, "linear-issue-foreign", "blocks"],
        ]),
    },
    "comment": {
        "absent": lambda value: value["historicalImport"]["independentReads"][
            "issueCommentPages"
        ][0].update(commentNativeIds=[]),
        "foreign": lambda value: value["historicalImport"]["independentReads"]["comments"][0].update(
            issueNativeId="linear-issue-foreign"
        ),
        "duplicated": lambda value: value["historicalImport"]["independentReads"]["comments"].append(
            copy.deepcopy(value["historicalImport"]["independentReads"]["comments"][0])
        ),
    },
    "stableIdentity": {
        "absent": lambda value: value["historicalImport"]["resourceClientIds"].pop("planIssue"),
        "foreign": lambda value: value["historicalImport"]["independentReads"]["issues"][0].update(
            clientId="40404040-4040-4040-8040-404040404040"
        ),
        "duplicated": lambda value: value["historicalImport"]["resourceClientIds"].update(
            overnightComment=HISTORICAL_PLAN_CLIENT_ID
        ),
    },
    "stableIdDiscovery": {
        "zero": lambda value: value["historicalImport"]["stableIdDiscoveryPages"][0]["pages"][
            0
        ].update(matches=[]),
        "foreign": lambda value: value["historicalImport"]["stableIdDiscoveryPages"][1]["pages"][
            0
        ]["matches"][0].update(repositoryId="repo-foreign"),
        "duplicated": lambda value: value["historicalImport"]["stableIdDiscoveryPages"][2]["pages"][
            0
        ]["matches"].append(
            copy.deepcopy(
                value["historicalImport"]["stableIdDiscoveryPages"][2]["pages"][0]["matches"][0]
            )
        ),
        "nonNullCursor": lambda value: value["historicalImport"]["stableIdDiscoveryPages"][0][
            "pages"
        ][0].update(nextCursor="cursor-unread"),
    },
    "receipt": {
        "existingWithoutExplicitResume": lambda value: value["historicalImport"][
            "receiptPreflight"
        ].update(observedExistingReceipt={"payloadSha256": "sha256:existing"}),
        "reallocatedLedger": lambda value: value["historicalImport"]["receiptPreflight"][
            "existingReceiptResumeObservation"
        ]["resourceClientIds"].update(project="40404040-4040-4040-8040-404040404040"),
    },
    "receiptLock": {
        "concurrentInvocation": lambda value: value["historicalImport"]["receiptPreflight"][
            "operationLock"
        ].update(acquired=False),
    },
    "receiptLoss": {
        "priorProvenanceMapping": lambda value: value["historicalImport"]["receiptPreflight"][
            "lostReceiptProvenanceDiscovery"
        ]["projectPages"][0]["matches"].append({
            "nativeId": HISTORICAL_PROJECT_NATIVE_ID,
            "repositoryId": EXPECTED_REPOSITORY_ID,
        }),
        "nonTerminalCursor": lambda value: value["historicalImport"]["receiptPreflight"][
            "lostReceiptProvenanceDiscovery"
        ]["issuePages"][0].update(nextCursor="cursor-unread"),
    },
    "resumeBoundary": {
        "attemptedZeroMatchCreateReplay": lambda value: (
            value["historicalImport"]["receiptPreflight"][
                "existingReceiptResumeObservation"
            ]["resourceAttemptBoundaries"].update(project="attempting/unknown"),
            value["historicalImport"]["receiptPreflight"][
                "existingReceiptResumeObservation"
            ]["resumeStableIdDiscoveryPages"][0].update(
                attemptBoundary="attempting/unknown"
            ),
            value["historicalImport"]["receiptPreflight"][
                "existingReceiptResumeObservation"
            ]["resumeStableIdDiscoveryPages"][0]["pages"][0].update(matches=[]),
            value["historicalImport"]["receiptPreflight"][
                "existingReceiptResumeObservation"
            ].update(
                resumeOperationOrder=[
                    "discover-project-by-client-id",
                    "create-project",
                ],
                createReplayAllowed=True,
            ),
        ),
        "unknownCreateReplay": lambda value: value["historicalImport"]["receiptPreflight"][
            "existingReceiptResumeObservation"
        ].update(
            resumeOperationOrder=[
                "discover-issue-by-client-id",
                "create-issue",
            ],
            createReplayAllowed=True,
        ),
        "unknownPartialDiscovery": lambda value: value["historicalImport"]["receiptPreflight"][
            "existingReceiptResumeObservation"
        ]["resumeStableIdDiscoveryPages"][1]["pages"][0].update(
            nextCursor="cursor-unread"
        ),
    },
    "lifecycleGroup": {
        "mixedActiveHistorical": lambda value: value["historicalImport"][
            "classificationPreflight"
        ]["mixedLifecycleCounterfactual"].update(
            disposition="import",
            remoteMutationCount=1,
        ),
    },
    "sourceLedger": {
        "swappedRevision": lambda value: value["historicalImport"]["sourceResourceLedger"][
            0
        ].update(sourceCommit=authority["base"]),
        "swappedDigest": lambda value: value["historicalImport"]["sourceResourceLedger"][
            1
        ].update(sourceSha256="sha256:" + "0" * 64),
    },
    "terminalSnapshot": {
        "lateInvalidation": lambda value: value["historicalImport"][
            "terminalPreDeleteSnapshot"
        ]["issueCommentPages"][0].update(commentNativeIds=[]),
        "payloadCorruption": lambda value: value["historicalImport"][
            "terminalPreDeleteSnapshot"
        ]["directReads"][1].update(sourceBytes="corrupted"),
        "sourceReplacement": lambda value: value["historicalImport"][
            "terminalPreDeleteSnapshot"
        ]["sourceFileReads"][0].update(sourceBytes="replaced"),
        "sourceIdentityReplacement": lambda value: value["historicalImport"][
            "terminalPreDeleteSnapshot"
        ]["sourceFileReads"][0].update(preUnlinkIdentityStable=False),
    },
}
expected_counterfactual_shape = {
    "readBack": {"absent", "foreign", "duplicated"},
    "membership": {"absent", "foreign", "duplicated"},
    "relation": {"absent", "foreign", "duplicated"},
    "comment": {"absent", "foreign", "duplicated"},
    "stableIdentity": {"absent", "foreign", "duplicated"},
    "stableIdDiscovery": {"zero", "foreign", "duplicated", "nonNullCursor"},
    "receipt": {"existingWithoutExplicitResume", "reallocatedLedger"},
    "receiptLock": {"concurrentInvocation"},
    "receiptLoss": {"priorProvenanceMapping", "nonTerminalCursor"},
    "resumeBoundary": {
        "attemptedZeroMatchCreateReplay",
        "unknownCreateReplay",
        "unknownPartialDiscovery",
    },
    "lifecycleGroup": {"mixedActiveHistorical"},
    "sourceLedger": {"swappedRevision", "swappedDigest"},
    "terminalSnapshot": {
        "lateInvalidation",
        "payloadCorruption",
        "sourceReplacement",
        "sourceIdentityReplacement",
    },
}
if (
    set(historical_resource_counterfactuals) != set(expected_counterfactual_shape)
    or any(
        set(historical_resource_counterfactuals[evidence_class]) != outcomes
        for evidence_class, outcomes in expected_counterfactual_shape.items()
    )
):
    raise SystemExit("historical resource counterfactual matrix drifted")
for evidence_class, variants in historical_resource_counterfactuals.items():
    for outcome, mutate in variants.items():
        counterfactual = copy.deepcopy(historical_fixture)
        mutate(counterfactual)
        if validate_historical_raw_evidence(counterfactual, authority) is not None:
            raise SystemExit(
                f"historical migration accepts {evidence_class} {outcome} evidence"
            )

counterfactual_case = cases[
    "blocks-historical-deletion-on-resource-reconciliation-failure"
]
counterfactual_assertion = next(
    assertion
    for assertion in counterfactual_case["assertions"]
    if assertion["id"] == "migration-historical-counterfactual-matrix"
)
expected_counterfactual_results = {
    evidence_class: {outcome: "blocked" for outcome in variants}
    for evidence_class, variants in historical_resource_counterfactuals.items()
}
expected_counterfactual_results["receiptWrite"] = receipt_write_counterfactual_results
if counterfactual_assertion.get("expected") != expected_counterfactual_results:
    raise SystemExit("historical evaluation counterfactual matrix is incomplete")

rewritten_fixture = copy.deepcopy(historical_fixture)
with tempfile.TemporaryDirectory() as rewritten_directory:
    rewritten_root = pathlib.Path(rewritten_directory)
    rewritten_bytes = b"rewritten standalone recovery bytes\n"
    for observation in rewritten_fixture["gitRecoveryObservations"]:
        rewritten_file = rewritten_root / observation["path"]
        rewritten_file.parent.mkdir(parents=True, exist_ok=True)
        rewritten_file.write_bytes(rewritten_bytes)
        observation["sha256"] = "sha256:" + hashlib.sha256(rewritten_bytes).hexdigest()
    if validate_historical_recovery(
        rewritten_fixture, rewritten_root, authority_repository, authority
    ) is not None:
        raise SystemExit("historical migration accepts rewritten recovery bytes and digests")

wrong_source = copy.deepcopy(historical_fixture)
def commit_tree(treeish, parents, message, timestamp, reference):
    tree = git(authority_repository, "rev-parse", f"{treeish}^{{tree}}").stdout.decode().strip()
    arguments = ["commit-tree", tree]
    for parent in parents:
        arguments.extend(["-p", parent])
    commit = git(
        authority_repository,
        *arguments,
        input_bytes=f"{message}\n".encode(),
        env=commit_environment(timestamp),
    ).stdout.decode().strip()
    git(authority_repository, "update-ref", f"refs/heads/{reference}", commit)
    return commit


def fixture_for_authority(candidate_authority):
    fixture = copy.deepcopy(historical_fixture)
    observation = fixture["pullRequestObservation"]
    observation.update(
        baseCommit=candidate_authority["base"],
        headCommit=candidate_authority["head"],
        mergeCommit=candidate_authority["merge"],
        changedPaths=candidate_authority["changedPaths"],
    )
    for record in fixture["legacyRecords"]:
        record["provenance"] = [
            f"git:{candidate_authority['head'][:7]}:{record['path']}"
        ]
    for recovery in fixture["gitRecoveryObservations"]:
        recovery["sourceCommit"] = candidate_authority["head"]
    imported = fixture["historicalImport"]
    group_key = historical_group_key(candidate_authority)
    lost_receipt_discovery = imported["receiptPreflight"][
        "lostReceiptProvenanceDiscovery"
    ]
    lost_receipt_discovery["groupKey"] = group_key
    lost_receipt_discovery["sourceSha256s"] = sorted(
        historical_source_payload(path, candidate_authority)["sourceSha256"]
        for path in CANONICAL_RECORDS
    )
    imported["groupingLedger"][0]["groupKey"] = group_key
    imported["classificationPreflight"]["groupResults"][0]["groupKey"] = group_key
    project = imported["independentReads"]["projects"][0]
    project["metadata"]["groupKey"] = group_key
    project["overview"]["mergeCommit"] = candidate_authority["merge"]
    imported["independentReads"]["issues"][0]["description"] = historical_source_payload(
        HISTORICAL_PLAN_PATH, candidate_authority
    )
    imported["independentReads"]["comments"][0]["body"] = historical_source_payload(
        HISTORICAL_OVERNIGHT_PATH, candidate_authority
    )
    for ledger in imported["sourceResourceLedger"]:
        source = historical_source_payload(ledger["sourcePath"], candidate_authority)
        for key in (
            "sourceCommit",
            "sourceBlobObjectId",
            "sourceSha256",
            "canonicalPullRequestUrl",
            "pullRequestNumber",
            "mergeCommit",
        ):
            ledger[key] = source[key]
    terminal_reads = imported["terminalPreDeleteSnapshot"]["directReads"]
    terminal_reads[0]["groupKey"] = group_key
    terminal_reads[0]["mergeCommit"] = candidate_authority["merge"]
    for terminal_read, path in zip(
        terminal_reads[1:],
        (HISTORICAL_PLAN_PATH, HISTORICAL_OVERNIGHT_PATH),
    ):
        source = historical_source_payload(path, candidate_authority)
        for key in (
            "sourceCommit",
            "sourceBlobObjectId",
            "sourceSha256",
            "canonicalPullRequestUrl",
            "mergeCommit",
        ):
            terminal_read[key] = source[key]
    return fixture


unrelated_head = commit_tree(
    authority["head"], [], "unrelated head", "2026-07-30T00:03:00Z", "unrelated-head"
)
later_head = commit_tree(
    authority["head"], [authority["head"]], "later head", "2026-07-30T00:04:00Z", "later-head"
)
reversed_merge = commit_tree(
    authority["merge"],
    [authority["head"], authority["base"]],
    "reversed parents",
    "2026-07-30T00:05:00Z",
    "reversed-parents",
)
extra_merge = commit_tree(
    authority["merge"],
    [authority["base"], authority["head"], unrelated_head],
    "extra parent",
    "2026-07-30T00:06:00Z",
    "extra-parent",
)
incorrect_merge = commit_tree(
    authority["merge"],
    [authority["base"], later_head],
    "incorrect head parent",
    "2026-07-30T00:07:00Z",
    "incorrect-parents",
)
topology_counterfactuals = {
    "source commit not ancestor": {
        **authority, "head": later_head,
    },
    "reversed merge parents": {
        **authority, "merge": reversed_merge,
    },
    "extra merge parent": {
        **authority, "merge": extra_merge,
    },
    "incorrect merge parent": {
        **authority, "merge": incorrect_merge,
    },
    "unrelated history": {
        **authority, "head": unrelated_head,
    },
    "wrong merge base head relationship": {
        **authority, "base": authority["head"], "head": later_head,
    },
}
for label, malformed_authority in topology_counterfactuals.items():
    malformed_fixture = fixture_for_authority(malformed_authority)
    if validate_historical_recovery(
        malformed_fixture, recovery_root, authority_repository, malformed_authority
    ) is not None:
        raise SystemExit(f"historical migration accepts {label}")
    if validate_historical_recovery(
        malformed_fixture,
        recovery_root,
        authority_repository,
        malformed_authority,
        verify_topology=False,
    ) is None:
        raise SystemExit(
            f"topology-check-removal counterfactual was rejected independently for {label}"
        )

wrong_source["legacyRecords"][0]["provenance"] = [
    f"git:{authority['base'][:7]}:{wrong_source['legacyRecords'][0]['path']}"
]
wrong_source["gitRecoveryObservations"][0]["sourceCommit"] = authority["base"]
if validate_historical_recovery(
    wrong_source, recovery_root, authority_repository, authority
) is not None:
    raise SystemExit("historical migration accepts recovery outside the observed head")

preserved_provenance = next(
    assertion["expected"]
    for assertion in historical["assertions"]
    if assertion["id"] == "migration-historical-provenance"
)
historical_mapping = next(
    assertion["expected"]
    for assertion in historical["assertions"]
    if assertion["id"] == "migration-historical-resource-ledger"
)
historical_assertions = {assertion["id"]: assertion for assertion in historical["assertions"]}
required_historical_boundaries = {
    "migration-historical-receipt-before-ids",
    "migration-historical-resume-ledger",
    "migration-historical-ledger-provenance",
    "migration-historical-stable-discovery",
    "migration-historical-stable-discovery-cursors",
    "migration-historical-fresh-terminal-snapshot",
    "migration-historical-precreate-discovery",
    "migration-historical-create-boundaries",
    "migration-historical-create-transitions",
    "migration-historical-resume-readback-first",
    "migration-historical-operation-lock",
    "migration-historical-lost-receipt-discovery",
    "migration-historical-source-pin",
    "migration-historical-source-quarantine",
}
if (
    set(recovery_observations) != set(historical_paths)
    or preserved_provenance != expected_provenance
    or not any(path.startswith(".woostack/plans/") for path in historical_paths)
    or not any(path.startswith(".woostack/overnight/") for path in historical_paths)
    or next(
        assertion for assertion in historical["assertions"]
        if assertion["id"] == "migration-historical-stable-id"
    ).get("expected") != list(HISTORICAL_CLIENT_IDS)
    or historical_mapping != {
        HISTORICAL_PLAN_PATH: f"linear://issue/{HISTORICAL_PLAN_CLIENT_ID}",
        HISTORICAL_OVERNIGHT_PATH: f"linear://comment/{HISTORICAL_COMMENT_CLIENT_ID}",
    }
    or any(
        historical_assertions[assertion_id].get("expected") is not True
        for assertion_id in required_historical_boundaries
    )
):
    raise SystemExit(
        "historical migration must cover exact Linear mappings plus Git-object provenance"
    )


# Own the historical plan and overnight record as one destructive source set. A late failure
# after the first record validates must preserve both records because deletion starts only after
# complete-set validation.
with tempfile.TemporaryDirectory() as historical_directory:
    historical_root = pathlib.Path(historical_directory)
    source_root = historical_root / "project"
    isolated_recovery_root = historical_root / "git-recovery"
    for path, canonical_bytes in CANONICAL_RECORDS.items():
        source = source_root / path
        recovery = isolated_recovery_root / path
        source.parent.mkdir(parents=True, exist_ok=True)
        recovery.parent.mkdir(parents=True, exist_ok=True)
        source.write_bytes(canonical_bytes)
        recovery.write_bytes(canonical_bytes)

    before_failure = {
        path: (source_root / path).read_bytes()
        for path in CANONICAL_RECORDS
    }
    deletion_count = 0

    def count_deletion(path):
        nonlocal_deletion_count[0] += 1
        path.unlink()

    def corrupt_second_recovery(validated_path):
        if not late_validation_seen:
            late_validation_seen.append(validated_path)
            second_path = next(path for path in CANONICAL_RECORDS if path != validated_path)
            (isolated_recovery_root / second_path).write_bytes(b"late validation failure\n")

    late_validation_seen = []
    nonlocal_deletion_count = [deletion_count]
    if migrate_historical_source_set(
        historical_fixture,
        source_root,
        isolated_recovery_root,
        authority_repository,
        authority,
        delete_source=count_deletion,
        after_record_validated=corrupt_second_recovery,
    ) is not None:
        raise SystemExit("late second-record validation failure was accepted")
    if nonlocal_deletion_count[0] != 0 or any(
        not (source_root / path).is_file()
        or (source_root / path).read_bytes() != canonical_bytes
        for path, canonical_bytes in before_failure.items()
    ):
        raise SystemExit("late validation failure deleted or changed a historical source")

    for path, canonical_bytes in CANONICAL_RECORDS.items():
        (isolated_recovery_root / path).write_bytes(canonical_bytes)
    late_terminal_fixture = copy.deepcopy(historical_fixture)

    def invalidate_terminal_snapshot(value):
        value["historicalImport"]["terminalPreDeleteSnapshot"]["issueCommentPages"][0][
            "commentNativeIds"
        ] = []

    if migrate_historical_source_set(
        late_terminal_fixture,
        source_root,
        isolated_recovery_root,
        authority_repository,
        authority,
        delete_source=count_deletion,
        before_terminal_snapshot=invalidate_terminal_snapshot,
    ) is not None:
        raise SystemExit("late terminal resource invalidation was accepted")
    if nonlocal_deletion_count[0] != 0 or any(
        not (source_root / path).is_file()
        or (source_root / path).read_bytes() != canonical_bytes
        for path, canonical_bytes in before_failure.items()
    ):
        raise SystemExit("late terminal invalidation unlinked or changed a historical source")
    replaced_path = next(iter(CANONICAL_RECORDS))

    def replace_source_before_pin():
        (source_root / replaced_path).write_bytes(b"late source replacement\n")

    if migrate_historical_source_set(
        historical_fixture,
        source_root,
        isolated_recovery_root,
        authority_repository,
        authority,
        delete_source=count_deletion,
        before_source_pin=replace_source_before_pin,
    ) is not None:
        raise SystemExit("late source replacement was accepted")
    if (
        nonlocal_deletion_count[0] != 0
        or any(not (source_root / path).is_file() for path in CANONICAL_RECORDS)
        or (source_root / replaced_path).read_bytes() != b"late source replacement\n"
    ):
        raise SystemExit("late source replacement unlinked a historical source")
    for path, canonical_bytes in CANONICAL_RECORDS.items():
        (source_root / path).write_bytes(canonical_bytes)
    identity_replaced_path = historical_fixture["legacyRecords"][0]["path"]

    def replace_source_identity_before_unlink():
        replacement = (source_root / identity_replaced_path).with_suffix(".replacement")
        replacement.write_bytes(CANONICAL_RECORDS[identity_replaced_path])
        os.replace(replacement, source_root / identity_replaced_path)

    if migrate_historical_source_set(
        historical_fixture,
        source_root,
        isolated_recovery_root,
        authority_repository,
        authority,
        delete_source=count_deletion,
        before_source_unlink=replace_source_identity_before_unlink,
    ) is not None:
        raise SystemExit("identity-only source replacement was accepted")
    if nonlocal_deletion_count[0] != 0 or any(
        not (source_root / path).is_file()
        or (source_root / path).read_bytes() != canonical_bytes
        for path, canonical_bytes in CANONICAL_RECORDS.items()
    ):
        raise SystemExit("identity-only source replacement unlinked or changed a source")

    staged_then_replaced_path = historical_fixture["legacyRecords"][1]["path"]

    def replace_second_source_before_unlink():
        replacement = (source_root / staged_then_replaced_path).with_suffix(".replacement")
        replacement.write_bytes(b"late staged source replacement\n")
        os.replace(replacement, source_root / staged_then_replaced_path)

    if migrate_historical_source_set(
        historical_fixture,
        source_root,
        isolated_recovery_root,
        authority_repository,
        authority,
        delete_source=count_deletion,
        before_source_unlink=replace_second_source_before_unlink,
    ) is not None:
        raise SystemExit("post-staging source replacement was accepted")
    first_path = historical_fixture["legacyRecords"][0]["path"]
    if (
        nonlocal_deletion_count[0] != 0
        or (source_root / first_path).read_bytes() != CANONICAL_RECORDS[first_path]
        or (source_root / staged_then_replaced_path).read_bytes()
        != b"late staged source replacement\n"
    ):
        raise SystemExit("post-staging source replacement did not restore the staged source")
    (source_root / staged_then_replaced_path).write_bytes(
        CANONICAL_RECORDS[staged_then_replaced_path]
    )

    dangling_path = historical_fixture["legacyRecords"][0]["path"]

    def replace_source_with_dangling_symlink():
        source = source_root / dangling_path
        source.unlink()
        source.symlink_to(source.with_name("missing-source-target"))

    if migrate_historical_source_set(
        historical_fixture,
        source_root,
        isolated_recovery_root,
        authority_repository,
        authority,
        delete_source=count_deletion,
        before_source_unlink=replace_source_with_dangling_symlink,
    ) is not None:
        raise SystemExit("dangling-symlink source replacement was accepted")
    if (
        nonlocal_deletion_count[0] != 0
        or not os.path.lexists(source_root / dangling_path)
        or not (source_root / dangling_path).is_symlink()
    ):
        raise SystemExit("dangling-symlink source replacement was unlinked")
    (source_root / dangling_path).unlink()
    (source_root / dangling_path).write_bytes(CANONICAL_RECORDS[dangling_path])

    deletion_count = [0]

    def fail_second_quarantined_deletion(source):
        deletion_count[0] += 1
        if deletion_count[0] == 2:
            raise RuntimeError("second quarantined deletion failed")
        source.unlink()

    try:
        migrate_historical_source_set(
            historical_fixture,
            source_root,
            isolated_recovery_root,
            authority_repository,
            authority,
            delete_source=fail_second_quarantined_deletion,
        )
    except RuntimeError:
        pass
    else:
        raise SystemExit("post-first-unlink failure did not block")
    if deletion_count[0] != 2 or any(
        not (source_root / path).is_file()
        or (source_root / path).read_bytes() != canonical_bytes
        for path, canonical_bytes in CANONICAL_RECORDS.items()
    ):
        raise SystemExit("post-first-unlink failure was not fully rolled back")



    migrated = migrate_historical_source_set(
        historical_fixture,
        source_root,
        isolated_recovery_root,
        authority_repository,
        authority,
    )
    if migrated is None or any((source_root / path).exists() for path in CANONICAL_RECORDS):
        raise SystemExit("validated historical source set was not fully deleted")
    for path, canonical_bytes in CANONICAL_RECORDS.items():
        recovered = git(
            authority_repository, "show", f"{authority['head']}:{path}"
        ).stdout
        if recovered != canonical_bytes:
            raise SystemExit(f"independent post-delete Git recovery failed for {path}")

historical_path_order = [record["path"] for record in historical_fixture["legacyRecords"]]
for failure_index in (0, 1):
    with tempfile.TemporaryDirectory() as undeletable_directory:
        undeletable_root = pathlib.Path(undeletable_directory)
        undeletable_sources = undeletable_root / "project"
        undeletable_recovery = undeletable_root / "git-recovery"
        for path, canonical_bytes in CANONICAL_RECORDS.items():
            source = undeletable_sources / path
            recovery = undeletable_recovery / path
            source.parent.mkdir(parents=True, exist_ok=True)
            recovery.parent.mkdir(parents=True, exist_ok=True)
            source.write_bytes(canonical_bytes)
            recovery.write_bytes(canonical_bytes)
        before_deletion = {
            path: (undeletable_sources / path).read_bytes()
            for path in historical_path_order
        }
        deletion_attempts = []

        def reject_indexed_deletion(path):
            deletion_attempts.append(path)
            if path == (
                undeletable_sources
                / ".woostack-migration-quarantine"
                / historical_path_order[failure_index]
            ):
                raise PermissionError(f"counterfactual record index {failure_index} is undeletable")
            path.unlink()

        try:
            migrate_historical_source_set(
                historical_fixture,
                undeletable_sources,
                undeletable_recovery,
                authority_repository,
                authority,
                delete_source=reject_indexed_deletion,
            )
        except PermissionError:
            pass
        else:
            raise SystemExit(f"undeletable historical record index {failure_index} was accepted")
        if deletion_attempts != [
            undeletable_sources / ".woostack-migration-quarantine" / path
            for path in historical_path_order[:failure_index + 1]
        ]:
            raise SystemExit(f"historical deletion order drifted at failure index {failure_index}")
        if any(
            not (undeletable_sources / path).is_file()
            or (undeletable_sources / path).read_bytes() != original_bytes
            for path, original_bytes in before_deletion.items()
        ):
            raise SystemExit(
                f"failed historical deletion at index {failure_index} did not restore exact bytes"
            )

# Mutation probe: disabling the complete restoration loop after index 0 was deleted must
# violate the owner invariant when deletion of index 1 fails.
with tempfile.TemporaryDirectory() as rollback_mutant_directory:
    rollback_mutant_root = pathlib.Path(rollback_mutant_directory)
    rollback_mutant_sources = rollback_mutant_root / "project"
    rollback_mutant_recovery = rollback_mutant_root / "git-recovery"
    for path, canonical_bytes in CANONICAL_RECORDS.items():
        source = rollback_mutant_sources / path
        recovery = rollback_mutant_recovery / path
        source.parent.mkdir(parents=True, exist_ok=True)
        recovery.parent.mkdir(parents=True, exist_ok=True)
        source.write_bytes(canonical_bytes)
        recovery.write_bytes(canonical_bytes)

    def fail_second_without_rollback(path):
        if path == (
            rollback_mutant_sources
            / ".woostack-migration-quarantine"
            / historical_path_order[1]
        ):
            raise PermissionError("rollback-removal mutant")
        path.unlink()

    try:
        migrate_historical_source_set(
            historical_fixture,
            rollback_mutant_sources,
            rollback_mutant_recovery,
            authority_repository,
            authority,
            delete_source=fail_second_without_rollback,
            restore_on_failure=False,
        )
    except PermissionError:
        pass
    else:
        raise SystemExit("rollback-removal mutant unexpectedly completed")
    if all(
        (rollback_mutant_sources / path).is_file()
        and (rollback_mutant_sources / path).read_bytes() == canonical_bytes
        for path, canonical_bytes in CANONICAL_RECORDS.items()
    ):
        raise SystemExit("rollback-removal mutant did not remove the first record")

mixed_case = cases["migrates-mixed-active-and-historical-records-by-subset"]
mixed_fixture = json.loads(
    (init / "evals/fixtures/migration/mixed.json").read_text()
)
mixed_fix_path = ".woostack/fixes/cache-header.md"
mixed_fix_client_id = "67676767-6767-4676-8676-676767676767"
mixed_fix_native_id = "linear-issue-historical-cache-header"
mixed_fix_source = (
    init / "evals/fixtures/migration/mixed/project" / mixed_fix_path
).read_bytes()
mixed_import = mixed_fixture.get("historicalImport", {})
mixed_reads = mixed_import.get("independentReads", {})
mixed_issues = mixed_reads.get("issues", [])
mixed_issue = mixed_issues[0] if len(mixed_issues) == 1 else {}
mixed_description = mixed_issue.get("description", {})
mixed_metadata = mixed_issue.get("metadata", {})
mixed_source_identity = {
    "sourceCommit": "ca71002ca71002ca71002ca71002ca71002ca710",
    "sourceBlobObjectId": git_blob_oid(mixed_fix_source),
    "sourceSha256": "sha256:" + hashlib.sha256(mixed_fix_source).hexdigest(),
    "canonicalPullRequestUrl": "https://github.com/acme/woostack/pull/441",
    "pullRequestNumber": 441,
    "mergeCommit": "ca71003ca71003ca71003ca71003ca71003ca710",
}
mixed_precreate_discovery = [{
    "resourceType": "issue",
    "clientId": mixed_fix_client_id,
    "attemptBoundary": "never-attempted",
    "pages": [{
        "matches": [],
        "nextCursor": None,
    }],
}]
mixed_discovery = [{
    "resourceType": "issue",
    "clientId": mixed_fix_client_id,
    "pages": [{
        "matches": [{
            "nativeId": mixed_fix_native_id,
            "repositoryId": "repo-woostack",
            "workspace": "Acme",
            "team": "APP",
            "role": "historical-fix",
        }],
        "nextCursor": None,
    }],
}]
mixed_membership = [{
    "issueNativeId": mixed_fix_native_id,
    "projectNativeIds": [],
    "nextCursor": None,
}]
mixed_relations = [{
    "issueNativeId": mixed_fix_native_id,
    "relationTuples": [],
    "nextCursor": None,
}]
mixed_comments = [{
    "issueNativeId": mixed_fix_native_id,
    "commentNativeIds": [],
    "nextCursor": None,
}]
mixed_order = mixed_import.get("operationOrder", [])
mixed_expected_order = [
    "classify-records-and-groups",
    "derive-receipt-path",
    "observe-receipt-absence-or-require-explicit-resume",
    "allocate-or-reuse-immutable-client-id-ledger",
    "persist-recovery-receipt",
    "pre-create-discover-historical-fix-by-client-id",
    "create-historical-fix-issue",
    "post-create-discover-historical-fix-by-client-id",
    "direct-read-historical-fix",
    "capture-fresh-terminal-pre-delete-snapshot",
    "delete-source-set",
]
if (
    set(mixed_import) != {
        "operationOrder",
        "receiptPreflight",
        "classificationPreflight",
        "resourceClientIds",
        "sourceResourceLedger",
        "preCreateStableIdDiscoveryPages",
        "stableIdDiscoveryPages",
        "mutationObservations",
        "independentReads",
        "terminalPreDeleteSnapshot",
    }
    or mixed_order != mixed_expected_order
    or mixed_import.get("receiptPreflight", {}).get("observedExistingReceipt") is not None
    or mixed_import.get("receiptPreflight", {}).get("allocationMode")
    != "allocate-after-proven-absence"
    or mixed_import.get("receiptPreflight", {}).get("resourceAttemptBoundaries")
    != {"fixIssue": "never-attempted"}
    or mixed_import.get("classificationPreflight", {}).get("mixedLifecycleGroupCount") != 0
    or mixed_import.get("resourceClientIds") != {"fixIssue": mixed_fix_client_id}
    or mixed_import.get("sourceResourceLedger") != [{
        "sourcePath": mixed_fix_path,
        "sourceKind": "fix",
        "resourceType": "issue",
        "resourceClientId": mixed_fix_client_id,
        "resourceNativeId": mixed_fix_native_id,
        "containerClientId": None,
        **mixed_source_identity,
    }]
    or mixed_import.get("preCreateStableIdDiscoveryPages")
    != mixed_precreate_discovery
    or mixed_import.get("stableIdDiscoveryPages") != mixed_discovery
    or mixed_import.get("mutationObservations") != [{
        "operation": "create-issue",
        "clientId": mixed_fix_client_id,
    }]
    or mixed_issue.get("clientId") != mixed_fix_client_id
    or mixed_issue.get("nativeId") != mixed_fix_native_id
    or mixed_issue.get("title") != "[Historical] Cache header fix"
    or mixed_issue.get("stateType") != "completed"
    or mixed_issue.get("assignee") is not None
    or mixed_issue.get("projectNativeId") is not None
    or mixed_metadata != {
        "managedBy": "woostack",
        "canonicalRepository": "https://github.com/acme/woostack",
        "repositoryId": "repo-woostack",
        "role": "historical-fix",
        "referenceOnly": True,
        "grantsAuthority": False,
    }
    or mixed_description.get("sourceBytes") != mixed_fix_source.decode()
    or mixed_description.get("sourcePath") != mixed_fix_path
    or not is_full_sha(mixed_description.get("sourceCommit"))
    or mixed_description.get("sourceBlobObjectId") != git_blob_oid(mixed_fix_source)
    or mixed_description.get("sourceSha256")
    != "sha256:" + hashlib.sha256(mixed_fix_source).hexdigest()
    or mixed_description.get("canonicalPullRequestUrl")
    != "https://github.com/acme/woostack/pull/441"
    or mixed_description.get("pullRequestNumber") != 441
    or not is_full_sha(mixed_description.get("mergeCommit"))
    or mixed_reads.get("issueProjectMembershipPages") != mixed_membership
    or mixed_reads.get("issueRelationPages") != mixed_relations
    or mixed_reads.get("issueCommentPages") != mixed_comments
    or mixed_import.get("terminalPreDeleteSnapshot") != {
        "snapshotId": "mixed-terminal-read-0001",
        "capturedAfterMutationClientIds": [mixed_fix_client_id],
        "stableIdDiscoveryPages": mixed_discovery,
        "directReads": [{
            "resourceType": "issue",
            "clientId": mixed_fix_client_id,
            "nativeId": mixed_fix_native_id,
            "repositoryId": "repo-woostack",
            "role": "historical-fix",
            "stateType": "completed",
            "assignee": None,
            "projectNativeId": None,
            "referenceOnly": True,
            "grantsAuthority": False,
            **{
                key: mixed_description[key]
                for key in (
                    "sourceBytes",
                    "sourcePath",
                    "sourceCommit",
                    "sourceBlobObjectId",
                    "sourceSha256",
                    "canonicalPullRequestUrl",
                    "pullRequestNumber",
                    "mergeCommit",
                )
            },
        }],
        "issueProjectMembershipPages": mixed_membership,
        "issueRelationPages": mixed_relations,
        "issueCommentPages": mixed_comments,
    }
):
    raise SystemExit("mixed migration lacks an exact historical fix issue read-back")

mixed_assertions = {assertion["id"]: assertion for assertion in mixed_case["assertions"]}
if (
    mixed_assertions["migration-mixed-history-linear-mutation"].get("expected") != 1
    or mixed_assertions["migration-mixed-history-mapping"].get("expected") != {
        mixed_fix_path: f"linear://issue/{mixed_fix_client_id}"
    }
    or mixed_assertions["migration-mixed-history-readback"].get("expected") is not True
    or mixed_assertions["migration-mixed-history-topology"].get("expected") is not True
    or mixed_assertions["migration-mixed-receipt-before-ids"].get("expected") is not True
    or mixed_assertions["migration-mixed-history-ledger-provenance"].get("expected") is not True
    or mixed_assertions["migration-mixed-history-stable-discovery"].get("expected") is not True
    or mixed_assertions["migration-mixed-history-terminal-snapshot"].get("expected") is not True
    or mixed_assertions["migration-mixed-precreate-discovery"].get("expected") is not True
    or mixed_assertions["migration-mixed-create-boundary"].get("expected") is not True
):
    raise SystemExit("mixed evaluation does not require the historical Linear mapping")

create_fixture = json.loads(
    (init / "evals/fixtures/migration/create-active.json").read_text()
)
create_source = (
    init
    / "evals/fixtures/migration/create-active/project/.woostack/specs/orders.md"
).read_bytes()
source_digest = hashlib.sha256(create_source).hexdigest()
transcript = create_fixture["operationTranscript"]
by_operation = {item["operation"]: item for item in transcript}
required = (
    "create-design-approved-update",
    "direct-read-design-approved-update",
    "create-spec-hardened-update",
    "direct-read-spec-hardened-update",
    "create-spec-approved-update",
    "direct-read-spec-approved-update",
    "read-current-project-phase-chain",
    "read-project-issue-graph",
)
if any(operation not in by_operation for operation in required):
    raise SystemExit("create migration omits the canonical specification chain")
design = by_operation["create-design-approved-update"]
hardened = by_operation["create-spec-hardened-update"]
approved = by_operation["create-spec-approved-update"]
chain = by_operation["read-current-project-phase-chain"]
read_pairs = (
    ("create-project", "direct-read-project"),
    ("create-design-approved-update", "direct-read-design-approved-update"),
    ("create-spec-hardened-update", "direct-read-spec-hardened-update"),
    ("create-spec-approved-update", "direct-read-spec-approved-update"),
)
if "terminalReceipt" in create_fixture:
    raise SystemExit("create migration fixture exposes a derived terminal receipt")

if (
    any(
        by_operation[created].get("envelope") != by_operation[read_back].get("envelope")
        or by_operation[created].get("readable") != by_operation[read_back].get("readable")
        for created, read_back in read_pairs
    )
    or design["envelope"].get("event") != "designApproved"
    or design["envelope"].get("predecessorId") is not None
    or design["readable"].get("approvedDesign", {}).get("goal") is None
    or design["readable"].get("approvalEvidence", {}).get("decision") != "Go"
    or hardened["envelope"].get("event") != "specHardened"
    or hardened["envelope"].get("predecessorId") != "linear-update-orders-design-approved"
    or hardened["readable"].get("specification") != create_source.decode()
    or hardened["readable"].get("bodySha256") != source_digest
    or approved["envelope"].get("event") != "specApproved"
    or approved["envelope"].get("predecessorId") != "linear-update-orders-spec-hardened"
    or approved["readable"].get("approvedRevision") != 1
    or approved["readable"].get("approvedUpdateId") != "linear-update-orders-spec-hardened"
    or approved["readable"].get("approvalEvidence", {}).get("decision") != "Go"
    or design["readable"].get("approvalEvidence") != create_fixture["approvalReceipts"]["design"]
    or approved["readable"].get("approvalEvidence")
    != create_fixture["approvalReceipts"]["specification"]
    or any(
        by_operation[operation].get("workspace") != "Acme"
        or by_operation[operation].get("team") != "APP"
        or by_operation[operation].get("nativeCategory") != "backlog"
        or by_operation[operation].get("nativeActor") != {"type": "user", "id": "user-7"}
        or not by_operation[operation].get("readComplete")
        for operation in required
        if operation.startswith("direct-read")
    )
    or chain.get("phases") != ["designApproved", "specHardened", "specApproved"]
    or chain.get("currentHeadCount") != 1
    or any(
        receipt.get("provider") != "official-linear-mcp"
        or not receipt.get("authenticated")
        or not receipt.get("current")
        or receipt.get("principalId") != "user-7"
        or receipt.get("actorType") != "user"
        or receipt.get("decision") != "Go"
        or not receipt.get("nativeReceiptId")
        or receipt.get("workspace") != "Acme"
        or receipt.get("team") != "APP"
        or receipt.get("repository") != "https://github.com/acme/woostack"
        or not receipt.get("readComplete")
        for receipt in create_fixture.get("approvalReceipts", {}).values()
    )
    or set(create_fixture.get("approvalReceipts", {})) != {"design", "specification"}
    or not by_operation["pre-delete-read-complete-set"].get("readComplete")
    or not by_operation["pre-delete-read-complete-set"].get("relationsPaginationComplete")
    or by_operation["pre-delete-read-complete-set"].get("currentHeadCount") != 1
    or by_operation["pre-delete-read-complete-set"].get("provenance", {}).get("specificationBodySha256")
    != source_digest
    or not by_operation["pre-delete-git-recovery"].get("bytesVerified")
    or by_operation["pre-delete-git-recovery"].get("sha256") != source_digest
):
    raise SystemExit("create migration lacks exact readable payload read-backs")

# Exercise the documented Git byte-recovery and post-receipt deletion boundary for the eligible
# destructive create path. The incomplete active resume remains preservation-only.
destructive_cases = (cases["creates-missing-active-resource-after-durable-recovery-receipt"],)
with tempfile.TemporaryDirectory() as directory:
    repo = pathlib.Path(directory)
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "migration-test@example.invalid"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "Migration Test"], cwd=repo, check=True)
    sources = []
    for active in destructive_cases:
        for relative in (path for path in active["fixtures"] if "/project/.woostack/" in path):
            source = init / "evals/fixtures" / relative
            target_relative = pathlib.Path(relative.split("/project/", 1)[1])
            target = repo / target_relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            sources.append((target_relative, hashlib.sha256(target.read_bytes()).hexdigest()))
    subprocess.run(["git", "add", ".woostack"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-qm", "track legacy migration input"], cwd=repo, check=True)
    for relative, digest in sources:
        recovered = subprocess.run(
            ["git", "show", f"HEAD:{relative.as_posix()}"], cwd=repo, check=True, stdout=subprocess.PIPE
        ).stdout
        if hashlib.sha256(recovered).hexdigest() != digest:
            raise SystemExit(f"pre-delete Git recovery failed for {relative}")
        (repo / relative).unlink()
        recovered_after = subprocess.run(
            ["git", "show", f"HEAD:{relative.as_posix()}"], cwd=repo, check=True, stdout=subprocess.PIPE
        ).stdout
        if (repo / relative).exists() or hashlib.sha256(recovered_after).hexdigest() != digest:
            raise SystemExit(f"post-delete Git recovery failed for {relative}")

print("test-legacy-migration-contract: ok")
PY
