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
    "blocks-ambiguous-legacy-classification-without-deletion": "blocked",
    "blocks-incomplete-migration-receipts-without-deletion": "blocked",
    "resumes-unknown-migration-outcome-by-stable-client-id": "blocked",
    "blocks-partial-migration-without-deleting-any-record": "blocked",
    "blocks-foreign-migration-resource-without-deletion": "blocked",
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
REPRESENTATIVE_CHANGED_PATH = "skills/woostack-init/references/migration-authority.txt"


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

    try:
        for path in historical_paths:
            delete_source(source_root / path)
        if any((source_root / path).exists() for path in historical_paths):
            raise RuntimeError("historical migration left a source record undeleted")
    except Exception:
        # Deletion is migration-wide. If any unlink fails, restore every already-removed source
        # from the independently verified Git bytes before surfacing the failure.
        if restore_on_failure:
            for path, object_bytes in source_bytes.items():
                source = source_root / path
                if not source.exists():
                    source.parent.mkdir(parents=True, exist_ok=True)
                    source.write_bytes(object_bytes)
        raise

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
if (
    set(recovery_observations) != set(historical_paths)
    or preserved_provenance != expected_provenance
    or not any(path.startswith(".woostack/plans/") for path in historical_paths)
    or not any(path.startswith(".woostack/overnight/") for path in historical_paths)
    or next(
        assertion for assertion in historical["assertions"]
        if assertion["id"] == "migration-historical-stable-id"
    ).get("expected") != []
):
    raise SystemExit("historical migration must cover plan and overnight Git-object provenance")


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
            if path == undeletable_sources / historical_path_order[failure_index]:
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
            undeletable_sources / path
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
        if path == rollback_mutant_sources / historical_path_order[1]:
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
