#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

SKILL="$ROOT/skills/woostack-review/SKILL.md"
REF_DIR="$ROOT/skills/woostack-review/references"
REFERENCES="commands.md configuration.md ci.md troubleshooting.md"
VALIDATOR_PATH="$ROOT/skills/woostack-review/prompts/validator.md"
PROSECUTOR_PATH="$ROOT/skills/woostack-review/prompts/validator-prosecutor.md"

assert_matches() { # content regex message
  if grep -Eq -- "$2" <<< "$1"; then
    pass
  else
    fail "$3"
    echo "    content does not match [$2]"
  fi
}

assert_fixed() { # content needle message
  if grep -qF -- "$2" <<< "$1"; then
    pass
  else
    fail "$3"
    echo "    content does not contain [$2]"
  fi
}

assert_absent() { # content needle message
  if grep -qF -- "$2" <<< "$1"; then
    fail "$3"
    echo "    content unexpectedly contains [$2]"
  else
    pass
  fi
}

assert_not_matches() { # content regex message
  if grep -Eq -- "$2" <<< "$1"; then
    fail "$3"
    echo "    content unexpectedly matches [$2]"
  else
    pass
  fi
}

normalize_paragraphs() {
  awk 'BEGIN { RS=""; ORS="\n" } { gsub(/[[:space:]]+/, " "); print }'
}

assert_corpus_term() { # regex message
  assert_matches "$CORPUS" "$1" "$2"
}

assert_root_term() { # regex message
  assert_matches "$ROOT_TEXT" "$1" "$2"
}

ROOT_TEXT="$(cat "$SKILL")"
ROOT_NORMALIZED="$(normalize_paragraphs < "$SKILL")"
VALIDATOR_TEXT="$(cat "$VALIDATOR_PATH")"
PROSECUTOR_TEXT="$(cat "$PROSECUTOR_PATH")"
COMMANDS=""
CONFIGURATION=""
CI=""
TROUBLESHOOTING=""

# The split is deliberately fixed: these are the four direct, conditional
# reading surfaces promised by the progressive-disclosure contract.
for reference in $REFERENCES; do
  path="$REF_DIR/$reference"
  if [ -f "$path" ]; then
    pass
    text="$(cat "$path")"
    case "$reference" in
      commands.md) COMMANDS="$text" ;;
      configuration.md) CONFIGURATION="$text" ;;
      ci.md) CI="$text" ;;
      troubleshooting.md) TROUBLESHOOTING="$text" ;;
    esac
  else
    fail "direct reference exists: references/$reference"
  fi
done

COMMANDS_NORMALIZED="$(normalize_paragraphs <<< "$COMMANDS")"
CONFIGURATION_NORMALIZED="$(normalize_paragraphs <<< "$CONFIGURATION")"
CI_NORMALIZED="$(normalize_paragraphs <<< "$CI")"
TROUBLESHOOTING_NORMALIZED="$(normalize_paragraphs <<< "$TROUBLESHOOTING")"
CORPUS="$ROOT_TEXT
$COMMANDS
$CONFIGURATION
$CI
$TROUBLESHOOTING"

# Root stays the orchestrator rather than becoming an index-only wrapper.
for stage in \
  'Stage 0.*Resolve skill path' \
  'Stage 1.*Prefetch' \
  'Stage 1a.*Resolve current contract context' \
  'Stage 2.*Detect Angles' \
  'Stage 3.*Run Review Swarm' \
  'Stage 4.*Merge.*Adversarial Validation' \
  'Stage 4a.*Prosecutor' \
  'Stage 4b.*Defender' \
  'Stage 4c.*Intersect' \
  'Stage 5.*Report' \
  'Stage 6.*metrics'; do
  assert_root_term "$stage" "root retains workflow heading: $stage"
done
assert_root_term '^## Hard constraints' 'root has a prominent Hard constraints section'
assert_root_term 'Receipt gate.*hard fail' 'root retains the worker receipt hard gate'
assert_root_term 'verify-receipts\.sh' 'root retains the worker receipt verifier command'
assert_root_term 'Verify.*retry.*Stage 3|missing pass exactly.*once' 'root retains the validator completion/retry gate'
assert_root_term 'single native batched GitHub Review|single.*GitHub Review' 'root retains batched PR posting behavior'
assert_root_term 'DO NOT modify the PR title or body' 'root retains the PR-mutation prohibition'
assert_root_term 'invoked locally.*no PR|local.*no PR' 'root retains local report behavior'
assert_root_term 'print the validated findings to the terminal' 'root keeps local findings terminal output'
assert_root_term 'Do not touch any remote' 'root keeps local mode remote-free'
assert_root_term 'Fold per-angle metrics' 'root retains the metrics stage'

# Every reference is selected directly from root at the point it becomes useful.
# Match the literal href, then remove it before judging the surrounding prose.
COMMANDS_LINK_CONTEXT=""
CONFIGURATION_LINK_CONTEXT=""
CI_LINK_CONTEXT=""
TROUBLESHOOTING_LINK_CONTEXT=""
for reference in $REFERENCES; do
  href="(references/$reference)"
  link_paragraph="$(awk -v href="$href" 'BEGIN { RS=""; ORS="\n" } index($0, href) { gsub(/[[:space:]]+/, " "); print }' "$SKILL")"
  if [ -n "$link_paragraph" ]; then
    pass
  else
    fail "root directly links exact href references/$reference"
    continue
  fi
  link_context="$(awk -v href="$href" '{
    pos=index($0, href)
    before=substr($0, 1, pos - 1)
    after=substr($0, pos + length(href))
    sub(/\[[^][]*\]$/, "", before)
    print before after
  }' <<< "$link_paragraph")"
  assert_matches "$link_context" '([Ww]hen|[Ii]f|[Oo]nly|[Rr]ead.*(when|for)|[Uu]se.*(when|for))' \
    "references/$reference link has meaningful when-to-read prose"
  case "$reference" in
    commands.md)
      COMMANDS_LINK_CONTEXT="$link_context"
      assert_matches "$link_context" '[Cc]ommand|[Ii]nvoke|[Ll]ocal' 'commands reference is selected for command/local invocation needs'
      ;;
    configuration.md)
      CONFIGURATION_LINK_CONTEXT="$link_context"
      assert_matches "$link_context" '[Cc]onfig|\.woostack/config\.json|[Oo]verride' 'configuration reference is selected only when configuring'
      ;;
    ci.md)
      CI_LINK_CONTEXT="$link_context"
      assert_matches "$link_context" 'CI|GitHub Action|[Ww]orkflow' 'CI reference is selected only for CI setup'
      ;;
    troubleshooting.md)
      TROUBLESHOOTING_LINK_CONTEXT="$link_context"
      assert_matches "$link_context" '[Ff]ail|[Ee]rror|[Rr]ecover|[Pp]roblem|[Tt]roubleshoot' 'troubleshooting reference is selected only on failure'
      ;;
  esac
done
assert_absent "$ROOT_TEXT" 'Read all references' 'root never requires loading every reference'
assert_absent "$ROOT_TEXT" 'read all references' 'root never requires loading every reference (lowercase)'

# Local and CI setup are mutually selective: ordinary local invocation does not
# pull CI installation details, and CI setup does not pull the local catalog.
if [ -n "$COMMANDS_LINK_CONTEXT" ]; then
  assert_matches "$COMMANDS_LINK_CONTEXT" '[Ll]ocal|[Ii]nvoke' 'local invocation selects the commands reference'
  assert_not_matches "$COMMANDS_LINK_CONTEXT" 'CI|GitHub Action|[Ww]orkflow setup' 'local invocation does not require the CI reference'
  assert_absent "$COMMANDS_LINK_CONTEXT" 'references/ci.md' 'local command setup does not select the CI reference'
fi
if [ -n "$CI_LINK_CONTEXT" ]; then
  assert_matches "$CI_LINK_CONTEXT" 'CI|GitHub Action|[Ww]orkflow' 'CI setup selects the CI reference'
  assert_not_matches "$CI_LINK_CONTEXT" '[Ll]ocal (command|invocation)|command catalog' 'CI setup does not require the local command catalog'
  assert_absent "$CI_LINK_CONTEXT" 'references/commands.md' 'CI setup does not select the local command catalog'
fi

# Detect prerequisite chains across a whole paragraph/list item, including
# wrapped Markdown. Filename matching is fixed-string so `.md` is never regex.
for reference in $REFERENCES; do
  path="$REF_DIR/$reference"
  [ -f "$path" ] || continue
  paragraphs="$(normalize_paragraphs < "$path")"
  for other in $REFERENCES; do
    [ "$other" = "$reference" ] && continue
    required_chain=false
    while IFS= read -r paragraph; do
      if grep -qF -- "($other" <<< "$paragraph" || grep -qF -- "(./$other" <<< "$paragraph"; then
        if grep -Eiq '(must|required|before continuing|first)' <<< "$paragraph"; then
          required_chain=true
          break
        fi
      fi
    done <<< "$paragraphs"
    if [ "$required_chain" = true ]; then
      fail "references/$reference must not require reading references/$other"
    else
      pass
    fi
  done
done

# Root carries orchestration; details live in conditional references.
root_lines="$(wc -l < "$SKILL" | tr -d ' ')"
if [ "$root_lines" -le 650 ]; then
  pass
else
  fail "root stays at or below approximately 650 lines (actual: $root_lines)"
fi

# Long references need real navigation. Medium references (100–300 lines) are
# valid without a TOC. Above 300, every top-level section must have an anchor.
for reference in $REFERENCES; do
  path="$REF_DIR/$reference"
  [ -f "$path" ] || continue
  lines="$(wc -l < "$path" | tr -d ' ')"
  if [ "$lines" -le 300 ]; then
    pass
    continue
  fi
  reference_text="$(cat "$path")"
  assert_matches "$reference_text" '^## (Table of [Cc]ontents|Contents)$' \
    "references/$reference has a TOC because it exceeds 300 lines"
  contents_block="$(awk '
    /^## (Table of [Cc]ontents|Contents)$/ { inside=1; next }
    inside && /^## / { exit }
    inside { print }
  ' "$path")"
  section_count=0
  while IFS= read -r heading; do
    [ -n "$heading" ] || continue
    title="${heading#\#\# }"
    case "$title" in
      Contents|'Table of Contents'|'Table of contents') continue ;;
    esac
    section_count=$((section_count + 1))
    slug="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/`//g; s/<[^>]*>//g; s/[^a-z0-9 _-]//g; s/[ _]+/-/g; s/^-+//; s/-+$//')"
    assert_fixed "$contents_block" "](#$slug)" \
      "references/$reference Contents block links top-level section: $title"
  done < <(grep '^## ' "$path")
  if [ "$section_count" -gt 0 ]; then
    pass
  else
    fail "references/$reference has at least one substantive top-level section"
  fi
done

# Moved surfaces are owned by one reference. Assertions use normalized
# paragraphs so harmless wrapping and section reordering do not matter.
if [ -n "$COMMANDS" ]; then
  for command in \
    '/woostack-review' '/woostack-review <PR#>' '/woostack-review --fast' \
    '/woostack-review --deep' '/woostack-review --full' \
    'woostack-review install' 'woostack-review status' \
    '/woostack-review recheck' '/woostack-review force' '@review --full'; do
    assert_fixed "$COMMANDS" "$command" "commands.md retains command: $command"
  done
  assert_fixed "$COMMANDS" '--issue <Linear issue URL|UUID>' 'commands.md exposes exact local issue identity'
  assert_fixed "$COMMANDS" '--project <Linear project URL|UUID>' 'commands.md exposes exact local project identity'
  assert_matches "$COMMANDS_NORMALIZED" '--fast.*(/woostack-review fast|`fast`)|(/woostack-review fast|`fast`).*--fast' 'commands.md retains the fast alias'
  assert_matches "$COMMANDS_NORMALIZED" '--deep.*(/woostack-review deep|`deep`)|(/woostack-review deep|`deep`).*--deep' 'commands.md retains the deep alias'
  assert_matches "$COMMANDS_NORMALIZED" '/woostack-review force recheck|force.*combinable.*recheck' 'commands.md retains force+recheck composition'
  assert_matches "$COMMANDS_NORMALIZED" 'authors_skip.*release_rollup_pattern|release_rollup_pattern.*authors_skip' 'commands.md retains both auto-skip routes'
  assert_matches "$COMMANDS_NORMALIZED" 'woostack-review:skipped.*(re-skip silently|comment spam).*force' 'commands.md retains skip-marker dedupe and force recovery'
  assert_matches "$COMMANDS_NORMALIZED" 'woostack-review:sha=.*bot-authored.*local.*gh user' 'commands.md retains trusted incremental marker authors'
  assert_matches "$COMMANDS_NORMALIZED" 'CI collaborator cannot forge|only bots are honored' 'commands.md retains the CI marker trust boundary'
  assert_matches "$COMMANDS_NORMALIZED" 'incremental: off.*--full|--full.*incremental: off' 'commands.md retains both full-review overrides'
  assert_matches "$COMMANDS_NORMALIZED" 'compare API returns 404.*falls back to the full diff' 'commands.md retains force-push incremental fallback'
  assert_matches "$COMMANDS_NORMALIZED" 'no new commits.*skip=true|skip=true.*no new commits' 'commands.md retains same-SHA incremental skip'
  assert_matches "$COMMANDS_NORMALIZED" 'marker IS the state|There is no DB' 'commands.md retains state-light marker semantics'
  assert_matches "$COMMANDS_NORMALIZED" 'optional artifact contract.*official.*MCP|official.*MCP.*supplied resource' 'commands.md gates optional artifact reads through official MCP'
  assert_matches "$COMMANDS_NORMALIZED" 'Missing MCP.*omits.*Linear contribution|omits.*Linear contribution.*Missing MCP' 'commands.md degrades missing optional MCP context without losing active contract'
  assert_matches "$COMMANDS_NORMALIZED" 'GitHub Actions.*diff-only advisory|diff-only advisory.*GitHub Actions' 'commands.md distinguishes CI advisory delivery'
  assert_matches "$COMMANDS_NORMALIZED" '[Nn]either path accepts the work|accepts the work.*[Nn]either path' 'commands.md denies review self-acceptance'
  assert_not_matches "$CONFIGURATION_NORMALIZED
$CI_NORMALIZED
$TROUBLESHOOTING_NORMALIZED" '/woostack-review --fast|woostack-review install' 'command catalog is not duplicated into another reference'
fi

if [ -n "$CONFIGURATION" ]; then
  for key in \
    'angles.force' 'angles.skip' 'severity_floor' 'nits' 'defer_markers' \
    'ignore' 'project_rules' 'authors_skip' 'release_rollup_pattern' \
    'force_tier' 'fix_commands' 'disable_adversarial' 'metrics' \
    'chunking.max_loc' 'models'; do
    assert_fixed "$CONFIGURATION" "$key" "configuration.md retains key: $key"
  done
  assert_matches "$CONFIGURATION_NORMALIZED" 'severity_floor.*default(s| is| to)? `?high|Default `high`' 'configuration.md retains severity_floor=high default'
  assert_matches "$CONFIGURATION_NORMALIZED" 'severity_floor.*(low.*medium.*high|low.*high)' 'configuration.md retains severity_floor accepted values'
  assert_matches "$CONFIGURATION_NORMALIZED" 'nits.*default.*true|default.*true.*nits' 'configuration.md retains nits=true default'
  assert_matches "$CONFIGURATION_NORMALIZED" 'nits.*false.*(drop|old behavior|pre-reframe)' 'configuration.md retains nits=false behavior'
  assert_matches "$CONFIGURATION_NORMALIZED" 'blocking.*(never demoted|always surface|overrides)' 'configuration.md retains blocking-over-floor safety'
  assert_matches "$CONFIGURATION_NORMALIZED" 'defer_markers.*default.*true|default.*true.*defer_markers' 'configuration.md retains defer_markers=true default'
  assert_matches "$CONFIGURATION_NORMALIZED" 'security.*never defer|never defers.*security' 'configuration.md retains security deferral exclusion'
  assert_matches "$CONFIGURATION_NORMALIZED" 'wrong code.*present.*never defer|never defers.*wrong code' 'configuration.md retains present-code deferral exclusion'
  assert_matches "$CONFIGURATION_NORMALIZED" 'authors_skip.*dependabot\[bot\].*renovate\[bot\].*github-actions\[bot\]' 'configuration.md retains authors_skip defaults'
  assert_matches "$CONFIGURATION_NORMALIZED" 'authors_skip.*\[\].*(opt out|disable)|\[\].*(opt out|disable).*authors_skip' 'configuration.md retains authors_skip opt-out'
  assert_matches "$CONFIGURATION_NORMALIZED" 'release_rollup_pattern.*default.*staging.*release' 'configuration.md retains release-rollup default'
  assert_matches "$CONFIGURATION_NORMALIZED" 'release_rollup_pattern.*empty string.*(opt out|disable)' 'configuration.md retains release-rollup opt-out'
  assert_matches "$CONFIGURATION_NORMALIZED" 'chunking.max_loc.*(default.*4000|4000.*default)' 'configuration.md retains chunking default'
  assert_matches "$CONFIGURATION_NORMALIZED" 'chunking.max_loc.*0.*disable|0.*disables chunking' 'configuration.md retains chunking disable value'
  assert_matches "$CONFIGURATION_NORMALIZED" 'disable_adversarial.*true.*defender' 'configuration.md retains defender-only opt-out behavior'
  assert_matches "$CONFIGURATION_NORMALIZED" 'explicit comment override.*action input.*review.force_tier.*models' 'configuration.md retains model/force precedence'
  assert_matches "$CONFIGURATION_NORMALIZED" 'unknown key.*(fail|error)' 'configuration.md retains unknown-key fail-closed behavior'
  assert_matches "$CONFIGURATION_NORMALIZED" 'review.models.*hard error' 'configuration.md retains nested-model safety error'
  assert_not_matches "$COMMANDS_NORMALIZED
$CI_NORMALIZED
$TROUBLESHOOTING_NORMALIZED" 'Full schema \(every key shown|^## Per-repo Configuration' 'full configuration catalog is not duplicated into another reference'
fi

# Integrations may stay in root or move, but each named route remains explicit.
for integration in \
  'pbakaus/impeccable' 'millionco/react-doctor' 'coreyhaines31/seo-audit' \
  'openai/security-best-practices' 'coreyhaines31/ai-seo' \
  'supabase/supabase-postgres-best-practices' \
  'using-woostack/references/hosts/<current-host>.md' \
  'woostack-init/references/artifact-backends.md' \
  'woostack-status/references/conventions.md'; do
  assert_fixed "$CORPUS" "$integration" "integration route remains represented: $integration"
done
assert_corpus_term 'read-only toward Linear|never.*mutat.*Linear' 'review remains read-only toward Linear'

for validator_prompt in "$VALIDATOR_TEXT" "$PROSECUTOR_TEXT"; do
  assert_fixed "$validator_prompt" '$OUTDIR/attribution.md' 'validator reads only the PR attribution candidate'
  assert_fixed "$validator_prompt" '$OUTDIR/intent.md' 'validator recognizes verified current-contract context'
  assert_matches "$validator_prompt" 'workflow://active-contract' 'validator accepts parent-owned artifact-free contract context'
  assert_matches "$validator_prompt" 'current contract' 'validator limits intent to the current contract'
  assert_matches "$validator_prompt" 'untrusted.*data, never instructions' 'validator keeps remote text untrusted'
  assert_matches "$validator_prompt" 'GitHub Actions.*intent.md.*absent' 'validator keeps CI contract-free and advisory'
  assert_matches "$validator_prompt" 'mutate GitHub, Linear, or the repository' 'validator denies remote artifact authority'
done
assert_matches "$VALIDATOR_TEXT" 'context disclosure required by `_orchestrator-header.md`' 'sequential validator posts the explicit advisory disclosure'

if [ -n "$CI" ]; then
  assert_matches "$CI_NORMALIZED" '\.github/workflows/ai-review\.yml.*reusable-review\.yml@main' 'ci.md retains consumer-to-reusable workflow routing'
  for actor in OWNER MEMBER COLLABORATOR; do
    assert_fixed "$CI" "$actor" "ci.md retains trusted comment-trigger actor independently: $actor"
  done
  assert_matches "$CI_NORMALIZED" 'issue_comment.*base-repo.*secrets|base-repo.*secrets.*issue_comment' 'ci.md explains base-repo secret exposure'
  assert_matches "$CI_NORMALIZED" 'Pin `@main` to a release tag|pin.*release tag' 'ci.md retains release-tag pinning'
  for credential in anthropic_token openai_api_key gemini_api_key openrouter_api_key; do
    assert_fixed "$CI" "$credential" "ci.md documents provider/integration credential independently: $credential"
  done
  assert_matches "$CI_NORMALIZED" 'GitHub Actions has no host-exposed Linear MCP|no host-exposed Linear MCP channel' 'ci.md states the missing host-MCP channel'
  assert_matches "$CI_NORMALIZED" 'diff-only advisory' 'ci.md labels CI review delivery advisory'
  assert_matches "$CI_NORMALIZED" 'exact.*Linear-Project:.*Linear-Issue:.*attribution.md|Linear-Project:.*Linear-Issue:.*attribution.md' 'ci.md preserves exact trailer candidates'
  assert_matches "$CI_NORMALIZED" 'authoritative-issue-context: absent' 'ci.md emits the explicit absent-authority marker'
  assert_matches "$CI_NORMALIZED" 'never creates `intent.md`|`intent.md`.*never' 'ci.md keeps verified contract intent out of CI'
  assert_matches "$CI_NORMALIZED" 'never runs.*`acceptance` angle|`acceptance` angle.*never' 'ci.md keeps acceptance angle out of CI'
  assert_matches "$CI_NORMALIZED" 'advisory-only evidence|advisory.*evidence' 'ci.md limits receipts and reviews to advisory evidence'
  assert_matches "$CI_NORMALIZED" 'neither Linear read-back nor issue acceptance' 'ci.md denies CI authority claims'
  for provider in anthropic openai google openrouter; do
    assert_matches "$CI_NORMALIZED" "provider.*$provider|$provider.*provider" "ci.md retains provider route: $provider"
  done
  assert_matches "$CI_NORMALIZED" 'only (the )?credential.*chosen provider|chosen provider.*only' 'ci.md scopes credentials to the selected provider'
  assert_matches "$CI_NORMALIZED" 'contents: read.*pull-requests: read' 'ci.md retains read-only detect/worker permissions'
  assert_matches "$CI_NORMALIZED" 'contents: read.*pull-requests: write' 'ci.md scopes PR write permission to posting'
  assert_not_matches "$COMMANDS_NORMALIZED
$CONFIGURATION_NORMALIZED
$TROUBLESHOOTING_NORMALIZED" 'reusable-review\.yml@main.*anthropic_token' 'full CI setup is not duplicated into another reference'
fi

# Root owns execution gates and user-visible behavior.
for event in APPROVE COMMENT REQUEST_CHANGES; do
  assert_fixed "$ROOT_TEXT" "$event" "root retains native GitHub review event independently: $event"
done
assert_matches "$ROOT_NORMALIZED" 'blocking finding.*REQUEST_CHANGES' 'root retains blocking finding event mapping'
assert_matches "$ROOT_NORMALIZED" 'open prior thread.*REQUEST_CHANGES|REQUEST_CHANGES.*open prior thread' 'root retains prior-thread event floor'
assert_matches "$ROOT_NORMALIZED" 'non-nit non-blocking finding.*COMMENT|COMMENT.*non-nit non-blocking' 'root retains nonblocking COMMENT mapping'
assert_matches "$ROOT_NORMALIZED" 'only findings are nits.*APPROVE|nits.*event-neutral.*APPROVE' 'root retains nit-only APPROVE mapping'
assert_matches "$ROOT_NORMALIZED" 'native GitHub principal ID.*IDs differ.*COMMENT.*STATUS_LINE|IDs match.*unproved.*COMMENT.*STATUS_LINE' 'root gates native approval on distinct GitHub principals and preserves status on COMMENT downgrade'
assert_matches "$ROOT_NORMALIZED" 'pending review.*422.*discarded.*retried once' 'root retains pending-review collision recovery'
assert_matches "$ROOT_NORMALIZED" 'DO NOT modify the PR title or body.*DO NOT mutate PR labels' 'root retains posting mutation limits'

assert_matches "$ROOT_NORMALIZED" 'angles.txt.*chunks.txt' 'root retains angle-by-chunk expected work set'
assert_matches "$ROOT_NORMALIZED" 'receipt\.<angle>.*matching `angle`/`chunk`.*runner.*model' 'root retains worker receipt identity contract'
assert_matches "$ROOT_NORMALIZED" 'authority:"advisory-only"|authority.*advisory-only' 'root marks worker receipts advisory-only'
assert_matches "$ROOT_NORMALIZED" 'reviewerProfile.*reviewerSessionId.*reviewerPrincipalId.*reviewerCredentialContextId' 'root binds receipts to reviewer profile/session/native principal/credential context'
assert_matches "$ROOT_NORMALIZED" 'reviewer-identities\.json.*implementingCoder.*decisionMaker.*reviewers' 'root requires the engineer-unit controller identity manifest'
assert_matches "$ROOT_NORMALIZED" 'paired coder.*shared.*profile/session/native principal/credential context|paired coder.*shared.*session.*credential' 'root rejects coder or shared-context reviewer receipts'
assert_matches "$ROOT_NORMALIZED" 'host-bound reviewer identity.*never native GitHub posting-actor proof|host binding.*not the native GitHub.*actor' 'root keeps receipt identity separate from native GitHub actor proof'
assert_matches "$ROOT_NORMALIZED" 'fresh home/config/cache/temp.*env -i|fresh `HOME`.*XDG.*temp.*allowlist' 'root launches engineer reviewers with fresh filesystem and environment contexts'
assert_matches "$ROOT_NORMALIZED" 'validates and hashes.*reviewer identity manifest' 'root protects the controller-owned identity manifest across dispatch'
assert_matches "$ROOT_NORMALIZED" 'branch/head.*staged and unstaged.*untracked.*hard-fails' 'root fingerprints Git-visible repository state across reviewer dispatch'
assert_matches "$ROOT_NORMALIZED" 'workflow://active-contract' 'root supports artifact-free current contract context'
assert_matches "$ROOT_NORMALIZED" 'Missing MCP.*omits only.*artifact contribution|artifact contribution.*Missing MCP' 'root degrades missing optional MCP context without losing active contract'
assert_matches "$ROOT_NORMALIZED" 'authoritative Linear issue context is absent|authoritative-issue-context: absent' 'root labels unverified PR attribution'
assert_matches "$ROOT_NORMALIZED" 'no parent-supplied contract context' 'root denies CI contract context claims'
assert_matches "$ROOT_NORMALIZED" 'retry missing, empty, invalid-JSON, or non-array artifacts once' 'root retains worker artifact retry'
assert_matches "$ROOT_NORMALIZED" 'usage_limit_reached.*rate_limit_error.*fallback chain' 'root retains worker model-fallback recovery'
assert_matches "$ROOT_NORMALIZED" 'abort the run.*do NOT proceed to merge/validate/post' 'root retains receipt hard gate before pipeline tail'
assert_matches "$ROOT_NORMALIZED" 'findings.prosecutor.json.*findings.defender.json' 'root retains both validator completion artifacts'
assert_matches "$ROOT_NORMALIZED" 'Re-launch a missing pass exactly.*once' 'root retains validator retry gate'
assert_matches "$ROOT_NORMALIZED" 'single-pass mode.*degraded: true.*validator-metrics.json' 'root retains validator degradation record'
assert_matches "$ROOT_NORMALIZED" 'tell the user.*lower-confidence|summary.*disclose.*degraded' 'root retains degradation disclosure'
assert_matches "$ROOT_NORMALIZED" '[Ll]ocal only.*CI|CI.*[Ll]ocal only|local.*not-in-CI' 'root retains explicit local/CI distinction'
assert_matches "$ROOT_NORMALIZED" 'GitHub Action does .*not.*fold' 'root keeps metrics persistence out of CI'

if [ -n "$TROUBLESHOOTING" ]; then
  for recovery in \
    'review-artifacts' 'raw_findings.json' 'resolve-diff-line.sh' \
    'rm -rf "$OUTDIR"' 'angles.json' 'Export `OUTDIR`' \
    'validator-metrics.json' 'derives the PR number itself' \
    'GITHUB_ACTIONS=true' 'same or an unproved actor posts `COMMENT`' \
    'retries missing/non-array artifacts once' 'json.loads(strict=False)' \
    'WOO_REVIEW_DIFF_CAP_BYTES'; do
    assert_fixed "$TROUBLESHOOTING" "$recovery" "troubleshooting.md retains recovery: $recovery"
  done
  assert_not_matches "$COMMANDS_NORMALIZED
$CONFIGURATION_NORMALIZED
$CI_NORMALIZED" '^## Troubleshooting|Missing artifacts.*review-artifacts' 'troubleshooting catalog is not duplicated into another reference'
fi

assert_fixed "$(cat "$ROOT/README.md")" \
  '(site/content/docs/configuration.mdx)' \
  'README links directly to the authored repository configuration reference'

finish
