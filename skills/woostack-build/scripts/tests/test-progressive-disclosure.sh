#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

SKILL="$ROOT/skills/woostack-build/SKILL.md"
PROCEDURE="$ROOT/skills/woostack-build/references/linear-procedure.md"
CONTEXT="$ROOT/skills/woostack-build/references/linear-context.md"
AUTHORITY="$ROOT/skills/woostack-init/references/artifact-backends.md"

# Extract level-two sections instead of piping entire, potentially very large reference bodies
# through grep -q under pipefail.
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

# Bash literal matching cannot receive SIGPIPE when a match occurs near the start of a long value.
assert_contains() { # content literal message
  if [[ "$1" == *"$2"* ]]; then pass; else
    fail "$3"
    echo "    bounded section does not contain [$2]"
  fi
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

for file in "$SKILL" "$PROCEDURE" "$CONTEXT" "$AUTHORITY"; do
  if [ -f "$file" ]; then pass; else fail "required workflow reference exists: ${file#"$ROOT/"}"; fi
done

ROOT_OVERVIEW_TEXT="$(section "$SKILL" '## Overview')"
ROOT_AUTHORITY_TEXT="$(section "$SKILL" '## Authority and context')"
ROOT_CHAIN_TEXT="$(section "$SKILL" '## Fixed chain')"
ROOT_GATES_TEXT="$(section "$SKILL" '## Exactly three hard gates')"
ROOT_HANDOFF_TEXT="$(section "$SKILL" '## Terminal choices at the execution handoff')"
ROOT_CONSTRAINTS_TEXT="$(section "$SKILL" '## Hard constraints')"

PROCEDURE_INTRO="$(before_first_section "$PROCEDURE")"
EVENT_TEXT="$(section "$PROCEDURE" '## Event write discipline')"
DESIGN_TEXT="$(section "$PROCEDURE" '## Design, shape classification, and project creation')"
SPEC_TEXT="$(section "$PROCEDURE" '## Specification hardening and approval')"
PLANNING_TEXT="$(section "$PROCEDURE" '## Planning, hardening, and ready')"
HANDOFF_TEXT="$(section "$PROCEDURE" '## Execution handoff')"
ABANDONMENT_TEXT="$(section "$PROCEDURE" '## Abandonment and blockers')"
FLOW_TEXT="$(flow_slice "$PROCEDURE")"

CAPABILITIES_TEXT="$(section "$CONTEXT" '## Official MCP capability discovery')"
IDENTITY_TEXT="$(section "$CONTEXT" '## Repository policy and identity')"
RETAINED_TEXT="$(section "$CONTEXT" '## Retained run context')"
READ_BACK_TEXT="$(section "$CONTEXT" '## Stable mutation and read-back rule')"

AUTHORITY_INTRO="$(before_first_section "$AUTHORITY")"
METADATA_TEXT="$(section "$AUTHORITY" '## Versioned managed metadata')"
RECEIPTS_TEXT="$(section "$AUTHORITY" '## Verified receipts')"

# The root remains a compact orchestrator with direct links to canonical authority, retained
# context, and the detailed lifecycle procedure.
assert_contains "$ROOT_AUTHORITY_TEXT" '(../woostack-init/references/artifact-backends.md)' \
  'root links canonical Linear authority'
assert_contains "$ROOT_AUTHORITY_TEXT" '(references/linear-context.md)' \
  'root links retained project context'
assert_contains "$ROOT_AUTHORITY_TEXT" '(references/linear-procedure.md)' \
  'root links the lifecycle procedure'
assert_contains "$ROOT_OVERVIEW_TEXT" 'Official host-exposed Linear MCP' \
  'root names the only development-record authority'
assert_contains "$ROOT_OVERVIEW_TEXT" 'never creates a docs-only base PR' \
  'root excludes the retired docs-only PR path'

assert_ordered "$ROOT_CHAIN_TEXT" 'root lifecycle' \
  'ideate' 'designApproved' 'harden specification' 'specHardened' 'specApproved' \
  'planning' 'harden increment graph' 'ready' 'executionApproved' 'execute'
assert_ordered "$ROOT_GATES_TEXT" 'root hard gates' \
  'design-approval' 'spec-approval' 'execution-handoff'
assert_contains "$ROOT_GATES_TEXT" 'exactly these three barriers' \
  'root preserves exactly three gates'
assert_contains "$ROOT_GATES_TEXT" 'Silence, implication, an MCP mutation' \
  'root rejects inferred approval'
assert_contains "$ROOT_GATES_TEXT" 'never clears a gate' \
  'root requires explicit gate clearance'
assert_contains "$ROOT_HANDOFF_TEXT" 'append and independently verify' \
  'root verifies approval before execution handoff'
assert_contains "$ROOT_CONSTRAINTS_TEXT" 'Independently read every create, update, transition' \
  'root preserves independent mutation read-back'

root_lines="$(wc -l < "$SKILL" | tr -d ' ')"
if [ "$root_lines" -le 500 ]; then pass; else
  fail "root stays at or below approximately 500 lines (actual: $root_lines)"
fi

# The direct lifecycle reader retains the full structural barriers and ordered Linear flow that the
# compact root intentionally omits.
assert_contains "$PROCEDURE_INTRO" \
  '<!-- linear-gates: design-approval | spec-approval | execution-handoff -->' \
  'procedure retains the ordered gate manifest'
assert_ordered "$FLOW_TEXT" 'procedure gate barriers' \
  '<HARD-GATE name="design-approval">' '</HARD-GATE>' \
  '<HARD-GATE name="spec-approval">' '</HARD-GATE>' \
  '<HARD-GATE name="execution-handoff">' '</HARD-GATE>'
gate_count="$(grep -Ec '<HARD-GATE name="(design-approval|spec-approval|execution-handoff)">' \
  "$PROCEDURE" || true)"
assert_eq "$gate_count" 3 'procedure has exactly three structural barriers'

assert_contains "$PROCEDURE_INTRO" 'official host-exposed Linear MCP' \
  'procedure retains official MCP authority'
assert_contains "$EVENT_TEXT" '`projectEvent` envelope' \
  'procedure retains the managed project-event envelope'
assert_contains "$EVENT_TEXT" 'stable event `clientId`' \
  'procedure retains stable event identity'
assert_contains "$EVENT_TEXT" 'Independently read back every append' \
  'procedure retains per-append read-back'
assert_contains "$EVENT_TEXT" 'exactly one current lifecycle chain' \
  'procedure retains one-chain validation'

assert_ordered "$FLOW_TEXT" 'procedure lifecycle' \
  '`woostack-ideate` presents the complete design' \
  'append `designApproved`' \
  'Invoke [`woostack-harden`' \
  'append `specHardened`' \
  'Only explicit **Go** approves it' \
  'append `specApproved`' \
  'Invoke [`woostack-plan`' \
  'one stable managed issue per increment' \
  'Append `ready`' \
  'Only explicit **Go**, **Run overnight**, or **Hand off**' \
  '`executionApproved` with a new stable event UUID' \
  'Only then call the selected executor'
assert_contains "$DESIGN_TEXT" 'Silence, ambiguity,' \
  'design approval cannot be inferred from silence'
assert_contains "$SPEC_TEXT" 'Silence, ambiguity, an unverified revision' \
  'spec approval cannot be inferred from silence'
assert_contains "$SPEC_TEXT" 'No planning event or increment issue may exist before Go' \
  'planning remains behind explicit spec approval'
assert_contains "$PLANNING_TEXT" 'native dependency relations' \
  'procedure retains the managed dependency graph'
assert_contains "$PLANNING_TEXT" 'exact commit SHA' \
  'procedure retains frozen Git base evidence'
assert_contains "$PLANNING_TEXT" '### Explicit replan' \
  'procedure retains explicit replan semantics'
assert_contains "$HANDOFF_TEXT" '`executionApproved`' \
  'procedure retains verified execution approval'
assert_contains "$HANDOFF_TEXT" 'mutation response without' \
  'execution handoff rejects an unverified mutation response'
assert_contains "$ABANDONMENT_TEXT" 'native `canceled`' \
  'procedure retains canceled abandonment state'
assert_contains "$ABANDONMENT_TEXT" 'native `planned`' \
  'procedure reuses planned blocker state'

# Shared references own capability discovery, retained identity, receipts, and trust boundaries
# instead of duplicating their detailed schemas in the root.
assert_contains "$CAPABILITIES_TEXT" 'host-exposed official Linear MCP connection' \
  'context retains official MCP discovery'
assert_contains "$CAPABILITIES_TEXT" 'advertise; never depend on a particular MCP tool name' \
  'context discovers tools by capability rather than name'
assert_contains "$CAPABILITIES_TEXT" 'independently readable capabilities' \
  'context requires independently readable capabilities'
assert_contains "$IDENTITY_TEXT" 'canonical `https://github.com/<owner>/<repository>` URL' \
  'context retains canonical repository identity'
assert_contains "$IDENTITY_TEXT" 'workspace and team' \
  'context retains configured workspace and team'
assert_contains "$RETAINED_TEXT" 'Do not serialize it as a development artifact' \
  'retained run context is not a local development artifact'
assert_contains "$READ_BACK_TEXT" 'new independent MCP read rather than trust in the mutation' \
  'context retains independent read-back'

assert_contains "$AUTHORITY_INTRO" 'host'\''s official Linear MCP connection' \
  'authority retains the official MCP connection'
assert_contains "$AUTHORITY_INTRO" 'There is no selectable development-artifact backend, local spec or plan authority' \
  'authority excludes retired local backends'
assert_contains "$AUTHORITY_INTRO" 'Git and GitHub' \
  'authority retains Git and GitHub source authority'
assert_contains "$METADATA_TEXT" 'exactly one managed block' \
  'authority retains managed metadata'
assert_contains "$RECEIPTS_TEXT" 'followed by an independent read' \
  'authority retains independent mutation receipts'
assert_contains "$RECEIPTS_TEXT" 'there is no local,' \
  'authority excludes local fallback'
assert_contains "$RECEIPTS_TEXT" 'document, custom-transport, or alternate-authority fallback' \
  'authority excludes document and alternate transport fallback'

finish
