#!/usr/bin/env bash
set -euo pipefail

# Legacy filename retained so committed test runners keep discovering this contract. The old
# spec-commit/docs-PR ordering is retired: build now advances one verified Linear project through
# design approval, managed specification capture and hardening, explicit spec approval, planning,
# and the execution handoff.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

BUILD_SKILL="$ROOT/skills/woostack-build/SKILL.md"
PROCEDURE="$ROOT/skills/woostack-build/references/linear-procedure.md"
CONTEXT="$ROOT/skills/woostack-build/references/linear-context.md"
AUTHORITY="$ROOT/skills/woostack-init/references/artifact-backends.md"

# Keep every assertion input bounded. Besides making failures easier to locate, this avoids
# grep -q closing a pipe early under pipefail when a reference grows beyond the pipe buffer.
section() { # file exact-level-two-heading
  awk -v heading="$2" '
    $0 == heading { found = 1 }
    found && $0 != heading && /^## / { exit }
    found { print }
    END { if (!found) exit 1 }
  ' "$1"
}

before_first_section() { # file
  awk '/^## / { exit } { print }' "$1"
}

flow_slice() { # file
  awk '
    $0 == "## Design, shape classification, and project creation" { found = 1 }
    $0 == "## Abandonment and blockers" { exit }
    found { print }
    END { if (!found) exit 1 }
  ' "$1"
}

# Bash matching avoids the shared printf | grep -q helper's SIGPIPE edge case.
assert_contains() { # content literal message
  if [[ "$1" == *"$2"* ]]; then pass; else fail "$3"; fi
}

assert_not_contains() { # content literal message
  if [[ "$1" == *"$2"* ]]; then fail "$3"; else pass; fi
}

assert_ordered() { # content scope tokens...
  local content="$1" scope="$2" token rest
  shift 2
  rest="$content"
  for token in "$@"; do
    if [[ "$rest" == *"$token"* ]]; then
      rest="${rest#*"$token"}"
    else
      fail "$scope missing or misorders [$token]"
      return
    fi
  done
  pass
}

for file in "$BUILD_SKILL" "$PROCEDURE" "$CONTEXT" "$AUTHORITY"; do
  if [ -f "$file" ]; then pass; else fail "required build contract exists: ${file#"$ROOT/"}"; fi
done

OVERVIEW_TEXT="$(section "$BUILD_SKILL" '## Overview')"
ROOT_AUTHORITY_TEXT="$(section "$BUILD_SKILL" '## Authority and context')"
ROOT_GATES_TEXT="$(section "$BUILD_SKILL" '## Exactly three hard gates')"
ROOT_HANDOFF_TEXT="$(section "$BUILD_SKILL" '## Terminal choices at the execution handoff')"
FLOW_TEXT="$(flow_slice "$PROCEDURE")"
DESIGN_TEXT="$(section "$PROCEDURE" '## Design, shape classification, and project creation')"
SPEC_TEXT="$(section "$PROCEDURE" '## Specification hardening and approval')"
PLANNING_TEXT="$(section "$PROCEDURE" '## Planning, hardening, and ready')"
HANDOFF_TEXT="$(section "$PROCEDURE" '## Execution handoff')"
CAPABILITIES_TEXT="$(section "$CONTEXT" '## Official MCP capability discovery')"
AUTHORITY_INTRO="$(before_first_section "$AUTHORITY")"
RESOURCE_TEXT="$(section "$AUTHORITY" '## Managed resource model')"

# The lifecycle is one ordered Linear flow. Approval precedes managed capture; the approved,
# read-back specification precedes issue planning; execution remains behind the third gate.
assert_ordered "$FLOW_TEXT" 'Linear build lifecycle' \
  '<HARD-GATE name="design-approval">' \
  '3. Immediately classify the approved design' \
  'append `designApproved`' \
  '## Specification hardening and approval' \
  'Invoke [`woostack-harden`' \
  'append `specHardened`' \
  '<HARD-GATE name="spec-approval">' \
  'On **Go**, append `specApproved`' \
  '## Planning, hardening, and ready' \
  'Invoke [`woostack-plan`' \
  'append `ready`' \
  '## Execution handoff' \
  '<HARD-GATE name="execution-handoff">' \
  '`executionApproved` with a new stable event UUID' \
  'Only then call the selected executor'

assert_contains "$DESIGN_TEXT" 'do not create a Linear development' \
  'ideation cannot create development artifacts before design approval'
assert_contains "$DESIGN_TEXT" 'obtains its explicit approval' \
  'design gate requires explicit approval'
assert_contains "$DESIGN_TEXT" 'Silence, ambiguity,' \
  'design gate rejects silence and implication'
assert_contains "$DESIGN_TEXT" 'Independently read the project and lead back' \
  'approved project creation is independently read back'
assert_contains "$DESIGN_TEXT" 'complete approved design and approval evidence' \
  'design approval is captured in the managed project event'

assert_contains "$SPEC_TEXT" 'Persist durable questions and resolutions as append-only' \
  'spec hardening persists managed decisions'
assert_contains "$SPEC_TEXT" 'complete written specification in the readable body' \
  'specification is captured in the managed project update'
assert_contains "$SPEC_TEXT" 'Only explicit **Go** approves it' \
  'spec gate requires explicit approval'
assert_contains "$SPEC_TEXT" 'Silence, ambiguity, an unverified revision' \
  'spec gate rejects silence and unverified state'
assert_contains "$SPEC_TEXT" 'No planning event or increment issue may exist before Go' \
  'planning stays behind spec approval'
assert_contains "$SPEC_TEXT" 'native `backlog` category before planning' \
  'spec approval is read back before planning'

assert_contains "$PLANNING_TEXT" 'one stable managed issue per increment and native dependency relations' \
  'planning creates the managed increment graph'
assert_contains "$PLANNING_TEXT" 'independent complete read proves the current `planning` chain and issue graph' \
  'planning independently reads back its managed graph'
assert_contains "$HANDOFF_TEXT" 'Only explicit **Go**, **Run overnight**, or **Hand off**' \
  'execution handoff requires an explicit terminal choice'
assert_contains "$HANDOFF_TEXT" 'mutation response without' \
  'execution handoff does not trust a mutation response'
assert_contains "$HANDOFF_TEXT" 'independent read-back clears nothing' \
  'execution handoff rejects unverified approval'
assert_contains "$HANDOFF_TEXT" 'Only then call the selected executor' \
  'execution starts only after verified execution approval'

# Tool names are host-defined; the workflow discovers official MCP capabilities and reads every
# mutation independently.
assert_contains "$ROOT_AUTHORITY_TEXT" 'official MCP capability set' \
  'build root requires official MCP capability discovery'
assert_contains "$ROOT_AUTHORITY_TEXT" 'Discover MCP operations by capability rather than hard-coded' \
  'build root discovers MCP operations by capability'
assert_contains "$ROOT_AUTHORITY_TEXT" 'tool names, and treat the linked authority contract as exhaustive' \
  'build root does not pin MCP tool names'
assert_contains "$CAPABILITIES_TEXT" 'Use only the host-exposed official Linear MCP connection' \
  'context requires the official Linear MCP connection'
assert_contains "$CAPABILITIES_TEXT" 'advertise; never depend on a particular MCP tool name' \
  'context discovers operations from advertised capabilities'
assert_contains "$CAPABILITIES_TEXT" 'independently readable capabilities' \
  'capability discovery includes independent reads'
assert_contains "$ROOT_GATES_TEXT" 'Silence, implication, an MCP mutation' \
  'root gate contract rejects inferred approval'
assert_contains "$ROOT_GATES_TEXT" 'response, or a native status name never clears a gate' \
  'root gate contract rejects tool-response approval'
assert_contains "$ROOT_HANDOFF_TEXT" 'append and independently verify' \
  'root verifies execution approval before executor handoff'

# The retired compatibility path must stay retired: Linear project updates own the spec, planning
# owns increment issues, and no local artifact or docs-only base PR participates in approval.
assert_contains "$OVERVIEW_TEXT" 'never creates a docs-only base PR' \
  'build rejects docs-only approval PRs'
assert_contains "$AUTHORITY_INTRO" 'There is no selectable development-artifact backend, local spec or plan authority' \
  'authority rejects local artifact compatibility'
assert_contains "$AUTHORITY_INTRO" 'Linear document' \
  'authority rejects Linear document compatibility'
assert_contains "$RESOURCE_TEXT" 'Project updates own its specification' \
  'managed project updates own the specification'
assert_contains "$RESOURCE_TEXT" 'no Linear document is created' \
  'feature workflow does not create a spec document'
for legacy in \
  'commit spec PR' \
  'append plan to spec+plan PR' \
  'commit spec+plan as their own PR' \
  '.woostack/specs/' \
  '.woostack/plans/'; do
  assert_not_contains "$FLOW_TEXT" "$legacy" "Linear lifecycle excludes retired contract [$legacy]"
done

finish
