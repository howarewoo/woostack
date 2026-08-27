#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
C="$HERE/../checks"

# gitignore-drift
r="$(mktemp -d)"; mkdir -p "$r/.woostack"; : > "$r/.woostack/.gitignore"
assert_contains "$(bash "$C/gitignore-drift.sh" "$r")" "gitignore-drift" "empty .gitignore drifts"
bash "$C/gitignore-drift.sh" --fix "$r"
assert_eq "$(bash "$C/gitignore-drift.sh" "$r")" "" "after fix, no drift"
before="$(wc -l < "$r/.woostack/.gitignore")"; bash "$C/gitignore-drift.sh" --fix "$r"
assert_eq "$(wc -l < "$r/.woostack/.gitignore")" "$before" "gitignore fix idempotent"

# config-keys (skips cleanly when jq absent)
if command -v jq >/dev/null 2>&1; then
  r2="$(mktemp -d)"; mkdir -p "$r2/.woostack"; echo '{}' > "$r2/.woostack/config.json"
  assert_contains "$(bash "$C/config-keys.sh" "$r2")" "config-key" "empty config missing keys"
  for k in $(jq -r 'keys[]' "$HERE/../../../woostack-init/templates/config.json"); do
    bash "$C/config-keys.sh" --fix "$r2" "$k"
  done
  assert_eq "$(bash "$C/config-keys.sh" "$r2")" "" "after fixing all template keys with default local provider, clean"

  tmp="$(mktemp)"
  jq '.linear = {saveArtifacts: true}' "$r2/.woostack/config.json" >"$tmp" && mv "$tmp" "$r2/.woostack/config.json"
  assert_contains "$(bash "$C/config-keys.sh" "$r2")" "linear.saveArtifacts is deprecated; migrate to artifacts.provider and artifacts.linear" "legacy saveArtifacts rejected"
  jq 'del(.linear)' "$r2/.woostack/config.json" >"$tmp" && mv "$tmp" "$r2/.woostack/config.json"

  jq '.artifacts = {provider: "invalid"}' "$r2/.woostack/config.json" >"$tmp" && mv "$tmp" "$r2/.woostack/config.json"
  assert_contains "$(bash "$C/config-keys.sh" "$r2")" "artifacts.provider must be \"local\", \"linear\", or \"plane\"" "invalid provider rejected"

  jq '.artifacts = {
    provider: "plane",
    plane: {
      baseUrl: "https://api.plane.so",
      workspace: "Acme",
      repository: "https://github.com/acme/widgets",
      projectLabels: ["woostack", "backend"],
      projectStatuses: {
        backlog: "Backlog",
        planned: "Planned",
        started: "Started",
        completed: "Completed",
        canceled: "Canceled"
      },
      issueStates: {
        planned: "Backlog",
        executing: "In Progress",
        inReview: "In Progress",
        done: "Done",
        blocked: "In Progress"
      }
    }
  }' "$r2/.woostack/config.json" >"$tmp" && mv "$tmp" "$r2/.woostack/config.json"
  assert_eq "$(bash "$C/config-keys.sh" "$r2")" "" "after configuring full provider fields with provider plane and projectLabels, clean"

  jq '.artifacts.plane.projectLabels = []' "$r2/.woostack/config.json" >"$tmp" && mv "$tmp" "$r2/.woostack/config.json"
  assert_contains "$(bash "$C/config-keys.sh" "$r2")" "projectLabels must be an array of non-empty strings" "empty projectLabels under plane fails"

  jq 'del(.artifacts.plane.baseUrl)' "$r2/.woostack/config.json" >"$tmp" && mv "$tmp" "$r2/.woostack/config.json"
  assert_contains "$(bash "$C/config-keys.sh" "$r2")" "plane policy requires baseUrl, workspace, repository, projectLabels, projectStatuses, and issueStates only" "missing baseUrl under plane fails"
  jq '.artifacts = {provider: "linear"}' "$r2/.woostack/config.json" >"$tmp" && mv "$tmp" "$r2/.woostack/config.json"
  assert_contains "$(bash "$C/config-keys.sh" "$r2")" "linear policy requires repository, workspace, team, projectLabels, projectStatuses, and issueStates only" "provider linear requires full provider fields"
  jq '.artifacts = {
    provider: "linear",
    linear: {
      repository: "https://github.com/acme/widgets",
      workspace: "Acme",
      team: "ENG",
      projectLabels: ["woostack", "backend"],
      projectStatuses: {
        backlog: "Backlog",
        planned: "Planned",
        started: "Started",
        completed: "Completed",
        canceled: "Canceled"
      },
      issueStates: {
        planned: "Backlog",
        executing: "In Progress",
        inReview: "In Progress",
        done: "Done",
        blocked: "In Progress"
      }
    }
  }' "$r2/.woostack/config.json" >"$tmp"
  mv "$tmp" "$r2/.woostack/config.json"
  assert_eq "$(bash "$C/config-keys.sh" "$r2")" "" "after configuring full provider fields with provider linear and projectLabels, clean"

  jq '.artifacts.linear.projectLabels = []' "$r2/.woostack/config.json" >"$tmp" && mv "$tmp" "$r2/.woostack/config.json"
  assert_eq "$(bash "$C/config-keys.sh" "$r2")" "" "empty array projectLabels is clean"

  jq 'del(.artifacts.linear.projectLabels)' "$r2/.woostack/config.json" >"$tmp" && mv "$tmp" "$r2/.woostack/config.json"
  assert_contains "$(bash "$C/config-keys.sh" "$r2")" "linear policy requires repository, workspace, team, projectLabels, projectStatuses, and issueStates only" "missing projectLabels under provider linear fails"

  jq '.artifacts.linear.projectLabels = "not-an-array"' "$r2/.woostack/config.json" >"$tmp" && mv "$tmp" "$r2/.woostack/config.json"
  assert_contains "$(bash "$C/config-keys.sh" "$r2")" "projectLabels must be an array of non-empty strings" "non-array projectLabels fails"

  jq '.artifacts.linear.projectLabels = [""]' "$r2/.woostack/config.json" >"$tmp" && mv "$tmp" "$r2/.woostack/config.json"
  assert_contains "$(bash "$C/config-keys.sh" "$r2")" "projectLabels must be an array of non-empty strings" "empty string projectLabels fails"
  jq '.artifacts = {provider: "local", linear: {workspace: "only-workspace", projectLabels: "not-an-array"}}' "$r2/.woostack/config.json" >"$tmp" && mv "$tmp" "$r2/.woostack/config.json"
  assert_eq "$(bash "$C/config-keys.sh" "$r2")" "" "local provider with invalid inactive linear block is clean"
  # --fix with no key arg must refuse, not write a bogus "" entry into config.
  r2b="$(mktemp -d)"; mkdir -p "$r2b/.woostack"; echo '{}' > "$r2b/.woostack/config.json"
  bash "$C/config-keys.sh" --fix "$r2b" >/dev/null 2>&1; assert_exit 2 "$?" "config-keys --fix without a key arg refuses"
  assert_eq "$(cat "$r2b/.woostack/config.json")" "{}" "config-keys --fix without a key leaves config untouched"
fi

# orphan-worktree
# Physical path (pwd -P): git canonicalizes worktree paths, so on macOS where
# /var -> /private/var the registered list must match the resolved dir paths.
r3="$(cd "$(mktemp -d)" && pwd -P)"; ( cd "$r3" && git -c user.email=t@t -c user.name=t init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init )
mkdir -p "$r3/.woostack/worktrees/ghost"
assert_contains "$(bash "$C/orphan-worktree.sh" "$r3")" "orphan-worktree" "unregistered worktree dir flagged"
assert_contains "$(bash "$C/orphan-worktree.sh" "$r3")" "report" "present unregistered dir is report (never auto-pruned)"

# Prefix-collision regression: a registered worktree (app2) whose path contains an
# orphan dir's path (app) as a prefix must NOT make the orphan look registered.
git -C "$r3" worktree add -q "$r3/.woostack/worktrees/app2" -b wt-app2
mkdir -p "$r3/.woostack/worktrees/app"
assert_contains "$(bash "$C/orphan-worktree.sh" "$r3")" "worktrees/app	" "orphan 'app' flagged despite registered prefix-sibling 'app2'"

# Stale registration (dir gone, git entry remains) must be detected even with a
# RELATIVE WOO_ROOT — git emits absolute paths, so a relative wt_dir case-pattern
# would never match (regression guard for the "." default).
git -C "$r3" worktree add -q "$r3/.woostack/worktrees/stale" -b wt-stale
rm -rf "$r3/.woostack/worktrees/stale"
assert_contains "$( cd "$r3" && bash "$C/orphan-worktree.sh" . )" "stale worktree registration" "stale registration detected with a relative root"

# retained-plane-runs
r4="$(mktemp -d)"; mkdir -p "$r4/.woostack/tmp/runs/run-legacy"
cat > "$r4/.woostack/tmp/runs/run-legacy/manifest.json" <<'JSON'
{
  "runId": "run-legacy",
  "mirror": {
    "provider": "plane",
    "project": {
      "id": "33333333-3333-4333-8333-333333333333",
      "name": "[Build] Legacy feature"
    }
  }
}
JSON
legacy_before="$(cat "$r4/.woostack/tmp/runs/run-legacy/manifest.json")"
assert_contains "$(bash "$C/retained-plane-runs.sh" "$r4")" "retained-plane-runs" "missing specItem in Plane run flagged"
assert_contains "$(bash "$C/retained-plane-runs.sh" "$r4")" "regenerate via /woostack-build <goal> or /woostack-fix <prompt>" "regeneration guidance emitted"
assert_eq "$(cat "$r4/.woostack/tmp/runs/run-legacy/manifest.json")" "$legacy_before" "retained Plane check is report-only (zero mutation)"

# Incompatible Plane run with mismatched repository project name flagged
cat > "$r4/.woostack/tmp/runs/run-legacy/manifest.json" <<'JSON'
{
  "runId": "run-legacy",
  "canonicalRepository": "howarewoo/woostack",
  "mirror": {
    "provider": "plane",
    "status": "synced",
    "project": {
      "id": "33333333-3333-4333-8333-333333333333",
      "name": "[Repo] other-owner/mismatched-repo"
    },
    "specItem": {
      "externalId": "11111111-1111-4111-8111-111111111111",
      "canonicalRef": "ENG-40",
      "nativeId": "11111111-1111-4111-8111-111111111111"
    }
  }
}
JSON
assert_contains "$(bash "$C/retained-plane-runs.sh" "$r4")" "retained-plane-runs" "mismatched repo project name flagged"

# Incompatible Plane run with missing canonicalRepository flagged
cat > "$r4/.woostack/tmp/runs/run-legacy/manifest.json" <<'JSON'
{
  "runId": "run-legacy",
  "mirror": {
    "provider": "plane",
    "status": "synced",
    "project": {
      "id": "33333333-3333-4333-8333-333333333333",
      "name": "[Repo] howarewoo/woostack"
    },
    "specItem": {
      "externalId": "11111111-1111-4111-8111-111111111111",
      "canonicalRef": "ENG-40",
      "nativeId": "11111111-1111-4111-8111-111111111111"
    }
  }
}
JSON
assert_contains "$(bash "$C/retained-plane-runs.sh" "$r4")" "retained-plane-runs" "missing canonicalRepository flagged"

# Incompatible Plane run with empty canonicalRepository flagged
cat > "$r4/.woostack/tmp/runs/run-legacy/manifest.json" <<'JSON'
{
  "runId": "run-legacy",
  "canonicalRepository": "",
  "mirror": {
    "provider": "plane",
    "status": "synced",
    "project": {
      "id": "33333333-3333-4333-8333-333333333333",
      "name": "[Repo] "
    },
    "specItem": {
      "externalId": "11111111-1111-4111-8111-111111111111",
      "canonicalRef": "ENG-40",
      "nativeId": "11111111-1111-4111-8111-111111111111"
    }
  }
}
JSON
assert_contains "$(bash "$C/retained-plane-runs.sh" "$r4")" "retained-plane-runs" "empty canonicalRepository flagged"

# Incompatible Plane run with missing mirror.status flagged
cat > "$r4/.woostack/tmp/runs/run-legacy/manifest.json" <<'JSON'
{
  "runId": "run-legacy",
  "canonicalRepository": "howarewoo/woostack",
  "mirror": {
    "provider": "plane",
    "project": {
      "id": "33333333-3333-4333-8333-333333333333",
      "name": "[Repo] howarewoo/woostack"
    },
    "specItem": {
      "externalId": "11111111-1111-4111-8111-111111111111",
      "canonicalRef": "ENG-40",
      "nativeId": "11111111-1111-4111-8111-111111111111"
    }
  }
}
JSON
assert_contains "$(bash "$C/retained-plane-runs.sh" "$r4")" "retained-plane-runs" "missing mirror.status flagged"

# Incompatible Plane run with invalid mirror.status flagged
cat > "$r4/.woostack/tmp/runs/run-legacy/manifest.json" <<'JSON'
{
  "runId": "run-legacy",
  "canonicalRepository": "howarewoo/woostack",
  "mirror": {
    "provider": "plane",
    "status": "in_progress",
    "project": {
      "id": "33333333-3333-4333-8333-333333333333",
      "name": "[Repo] howarewoo/woostack"
    },
    "specItem": {
      "externalId": "11111111-1111-4111-8111-111111111111",
      "canonicalRef": "ENG-40",
      "nativeId": "11111111-1111-4111-8111-111111111111"
    }
  }
}
JSON
assert_contains "$(bash "$C/retained-plane-runs.sh" "$r4")" "retained-plane-runs" "invalid mirror.status flagged"

# Incompatible Plane run with synced status but null refs flagged
cat > "$r4/.woostack/tmp/runs/run-legacy/manifest.json" <<'JSON'
{
  "runId": "run-legacy",
  "canonicalRepository": "howarewoo/woostack",
  "mirror": {
    "provider": "plane",
    "status": "synced",
    "project": {
      "id": "33333333-3333-4333-8333-333333333333",
      "name": "[Repo] howarewoo/woostack"
    },
    "specItem": {
      "externalId": "11111111-1111-4111-8111-111111111111",
      "canonicalRef": null,
      "nativeId": null
    }
  }
}
JSON
assert_contains "$(bash "$C/retained-plane-runs.sh" "$r4")" "retained-plane-runs" "synced status with null refs flagged"
# Valid Plane run with synced mirror passes cleanly
cat > "$r4/.woostack/tmp/runs/run-legacy/manifest.json" <<'JSON'
{
  "runId": "run-legacy",
  "canonicalRepository": "howarewoo/woostack",
  "mirror": {
    "provider": "plane",
    "status": "synced",
    "project": {
      "id": "33333333-3333-4333-8333-333333333333",
      "name": "[Repo] howarewoo/woostack"
    },
    "specItem": {
      "externalId": "11111111-1111-4111-8111-111111111111",
      "canonicalRef": "ENG-40",
      "nativeId": "11111111-1111-4111-8111-111111111111"
    }
  }
}
JSON
assert_eq "$(bash "$C/retained-plane-runs.sh" "$r4")" "" "valid Plane run with synced specItem is clean"

# Valid Plane run with unstarted/null preallocation passes cleanly
cat > "$r4/.woostack/tmp/runs/run-legacy/manifest.json" <<'JSON'
{
  "runId": "run-legacy",
  "canonicalRepository": "howarewoo/woostack",
  "mirror": {
    "provider": "plane",
    "status": "unstarted",
    "project": {
      "id": "33333333-3333-4333-8333-333333333333",
      "name": "[Repo] howarewoo/woostack"
    },
    "specItem": {
      "externalId": "11111111-1111-4111-8111-111111111111",
      "canonicalRef": null,
      "nativeId": null
    }
  }
}
JSON
assert_eq "$(bash "$C/retained-plane-runs.sh" "$r4")" "" "valid Plane run with unstarted null preallocation is clean"

# Valid Plane run with failed status and null preallocation passes cleanly
cat > "$r4/.woostack/tmp/runs/run-legacy/manifest.json" <<'JSON'
{
  "runId": "run-legacy",
  "canonicalRepository": "howarewoo/woostack",
  "mirror": {
    "provider": "plane",
    "status": "failed",
    "project": {
      "id": "33333333-3333-4333-8333-333333333333",
      "name": "[Repo] howarewoo/woostack"
    },
    "specItem": {
      "externalId": "11111111-1111-4111-8111-111111111111",
      "canonicalRef": null,
      "nativeId": null
    }
  }
}
JSON
assert_eq "$(bash "$C/retained-plane-runs.sh" "$r4")" "" "valid Plane run with failed status and null preallocation is clean"

# Linear and local runs pass cleanly without specItem
cat > "$r4/.woostack/tmp/runs/run-legacy/manifest.json" <<'JSON'
{
  "runId": "run-legacy",
  "mirror": {
    "provider": "linear",
    "project": {
      "id": "99999999-9999-4999-8999-999999999999",
      "name": "[Build] Linear feature"
    }
  }
}
JSON
assert_eq "$(bash "$C/retained-plane-runs.sh" "$r4")" "" "Linear run without specItem passes Plane check"

finish
