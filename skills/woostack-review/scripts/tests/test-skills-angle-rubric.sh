#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

PROMPT="$ROOT/skills/woostack-review/prompts/angles/skills.md"
load_prompt() {
  local prompt_path="$1"
  local line current_section=""

  [ -f "$prompt_path" ] || return 1

  sources_section=""; scope_section=""; find_section=""
  skip_section=""; severity_section=""; output_section=""
  section_order=""
  count_sources=0; count_scope=0; count_find=0
  count_skip=0; count_severity=0; count_output=0

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '**Sources (principles only):**')
        current_section="Sources"
        count_sources=$((count_sources + 1))
        section_order="${section_order}${section_order:+ }Sources"
        ;;
      '**Scope.**'*)
        current_section="Scope"
        count_scope=$((count_scope + 1))
        section_order="${section_order}${section_order:+ }Scope"
        ;;
      '**Find:**')
        current_section="Find"
        count_find=$((count_find + 1))
        section_order="${section_order}${section_order:+ }Find"
        ;;
      '**Skip:**')
        current_section="Skip"
        count_skip=$((count_skip + 1))
        section_order="${section_order}${section_order:+ }Skip"
        ;;
      '**Severity rubric:**')
        current_section="Severity"
        count_severity=$((count_severity + 1))
        section_order="${section_order}${section_order:+ }Severity"
        ;;
      '**Output.**'*)
        current_section="Output"
        count_output=$((count_output + 1))
        section_order="${section_order}${section_order:+ }Output"
        ;;
    esac

    case "$current_section" in
      Sources) sources_section+="$line"$'\n' ;;
      Scope) scope_section+="$line"$'\n' ;;
      Find) find_section+="$line"$'\n' ;;
      Skip) skip_section+="$line"$'\n' ;;
      Severity) severity_section+="$line"$'\n' ;;
      Output) output_section+="$line"$'\n' ;;
    esac
  done < "$prompt_path"
}

load_prompt "$PROMPT" || {
  echo "  FAIL: cannot read skills angle prompt"
  exit 1
}

assert_all_fragments() { # haystack message fragment...
  local haystack="$1" message="$2"
  shift 2
  local fragment
  local missing=()

  for fragment in "$@"; do
    if ! grep -Fqi -- "$fragment" <<< "$haystack"; then
      missing+=("$fragment")
    fi
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    pass
  else
    fail "$message"
    printf '    missing semantic fragment: [%s]\n' "${missing[@]}"
  fi
}

assert_all_matches() { # haystack message regex...
  local haystack="$1" message="$2"
  shift 2
  local bounded regex
  local missing=()
  bounded="${haystack//$'\n\n'/. }"
  bounded="${bounded//$'\n'/ }"

  for regex in "$@"; do
    if ! grep -Eiq -- "$regex" <<< "$bounded"; then
      missing+=("$regex")
    fi
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    pass
  else
    fail "$message"
    printf '    missing semantic pattern: [%s]\n' "${missing[@]}"
  fi
}

assert_no_match() { # haystack regex message
  local haystack="$1" regex="$2" message="$3"
  local bounded
  bounded="${haystack//$'\n\n'/. }"
  bounded="${bounded//$'\n'/ }"
  if grep -Eiq -- "$regex" <<< "$bounded"; then
    fail "$message"
    echo "    contradictory wording matches [$regex]"
  else
    pass
  fi
}
all_fixed_in() { # haystack fragment...
  local haystack="$1"
  shift
  local fragment
  for fragment in "$@"; do
    grep -Fqi -- "$fragment" <<< "$haystack" || return 1
  done
}

all_matches_in() { # haystack regex...
  local haystack="$1"
  shift
  local bounded regex
  bounded="${haystack//$'\n\n'/. }"
  bounded="${bounded//$'\n'/ }"
  for regex in "$@"; do
    grep -Eiq -- "$regex" <<< "$bounded" || return 1
  done
}

structure_contract() {
  load_prompt "$1" &&
    [ "$count_sources" -eq 1 ] &&
    [ "$count_scope" -eq 1 ] &&
    [ "$count_find" -eq 1 ] &&
    [ "$count_skip" -eq 1 ] &&
    [ "$count_severity" -eq 1 ] &&
    [ "$count_output" -eq 1 ] &&
    [ "$section_order" = "Sources Scope Find Skip Severity Output" ]
}

sources_contract() {
  load_prompt "$1" &&
    all_fixed_in "$sources_section" \
      'Anthropic skill-creator: <https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md>' \
      'OpenAI skill-creator: <https://github.com/openai/skills/blob/main/skills/.system/skill-creator/SKILL.md>'
}

scope_contract() {
  load_prompt "$1" &&
    all_fixed_in "$scope_section" \
      '$OUTDIR/skill-packages.json' '$OUTDIR/<snapshotPath>' \
      'host working directory' 'untrusted review artifacts' \
      'deterministic parser and package validator' \
      'Do not duplicate fatal parser/validator guesses' &&
    all_matches_in "$scope_section" \
      'lazily find only[^.]{0,120}skillPath' \
      'lazily read only[^.]{0,160}snapshotPath' \
      'never[^.]{0,160}read sibling files[^.]{0,80}host working directory' \
      'untrusted review artifacts[^.]{0,160}cannot expand[^.]{0,120}repository[^.]{0,40}tool[^.]{0,40}network[^.]{0,40}credential[^.]{0,40}disclosure scope' \
      '(fatal|deterministic)[^.]{0,160}(should have stopped|stopped before)[^.]{0,100}(worker|prefetch)'
}

find_contract() {
  load_prompt "$1" &&
    all_matches_in "$find_section" \
      '(what it does)[^.]{0,100}(when to use it)|(when to use it)[^.]{0,100}(what it does)' \
      'positive[^.]{0,120}(trigger|case|example|quer(y|ies))' \
      'near[- ]miss[^.]{0,120}(trigger|case|example|quer(y|ies))' \
      '(report|flag)[^.]{0,80}absent[^.]{0,160}(only when|when only)[^.]{0,120}(exact[^.]{0,60}rule|diff[^.]{0,60}(claim|explicit))' \
      '(candidate|baseline)[^.]{0,120}(only when|when only)[^.]{0,120}(validated snapshot|artifacts?[^.]{0,40}present|explicitly claimed)' \
      'SKILL\.md[^.]{0,80}(over|above|exceed(s|ing)?)[^.]{0,30}~?500 lines[^.]{0,120}soft ceiling' \
      '(recommend|should)[^.]{0,60}split[^.]{0,80}reference files?' \
      '((require(s|d)?|must)[^.]{0,100}(table of contents|TOC)[^.]{0,100}(over|above|exceed(s|ing)?|>)[^.]{0,30}~?300|(over|above|exceed(s|ing)?|>)[^.]{0,30}~?300[^.]{0,100}(require(s|d)?|must)[^.]{0,60}(table of contents|TOC))' \
      '(appropriate|required|choose|select)[^.]{0,80}degrees? of freedom|degrees? of freedom[^.]{0,80}(appropriate|required|choose|select)' \
      'reusable mechanics[^.]{0,160}(scripts?|deterministic)' \
      'candidate[^.]{0,80}baseline|baseline[^.]{0,80}candidate' \
      'approval barriers?'
}

skip_contract() {
  load_prompt "$1" &&
    all_fixed_in "$skip_section" \
      'Fatal deterministic parser/validator conditions that prefetch owns' \
      'safe single-token angle-bracket placeholder' '<placeholder-name>' \
      'YAML colon-space hazard' 'RIGHT-side diff line'
}

severity_contract() {
  load_prompt "$1" &&
    all_fixed_in "$severity_section" \
      '`HIGH` + `blocking: true`' \
      '`MEDIUM` + `blocking: false`' \
      '`LOW` + `blocking: false`' \
      'nonblocking unless' 'exact load-bearing project rule' 'observable failure'
}

output_contract() {
  load_prompt "$1" &&
    all_fixed_in "$output_section" \
      '$OUTDIR/findings.skills.json' '"angle": "skills"' \
      'title' 'description' 'fix' 'fix_type' \
      '`diff.txt` is the sole finding-anchor' \
      '`resolve-diff-line.sh` authority' 'RIGHT-side candidate line' \
      'DROP any finding that resolves to `null`' \
      'Never anchor directly to an unchanged snapshot sibling' \
      'fix_type: "suggestion"' 'fix_type: "prose"'
}

root_ceiling_contract() {
  load_prompt "$1" &&
    all_matches_in "$find_section" \
      'SKILL\.md[^.]{0,80}(over|above|exceed(s|ing)?)[^.]{0,30}~?500 lines[^.]{0,120}soft ceiling' \
      '(recommend|should)[^.]{0,60}split[^.]{0,80}reference files?' &&
    ! all_matches_in "$find_section" \
      '(always acceptable|do not split|never split)[^.]{0,100}(500|reference)|500[^.]{0,100}(always acceptable|do not split|never split)'
}

assert_contract() { # checker path message
  local checker="$1" prompt_path="$2" message="$3"
  if ( "$checker" "$prompt_path" ); then
    pass
  else
    fail "$message"
  fi
}

assert_rejected_mutant() { # checker path message
  local checker="$1" prompt_path="$2" message="$3"
  if ( "$checker" "$prompt_path" ); then
    fail "$message"
    echo "    mutant unexpectedly satisfied [$checker]"
  else
    pass
  fi
}

assert_contract structure_contract "$PROMPT" \
  "rubric sections exist exactly once and in contract order"
assert_contract sources_contract "$PROMPT" \
  "Sources carries exact Anthropic and OpenAI skill-creator authorities"
assert_contract scope_contract "$PROMPT" \
  "Scope preserves snapshot-only untrusted artifacts and validator separation"
assert_contract find_contract "$PROMPT" \
  "Find owns the affirmative authoring and evaluation rules"
assert_contract skip_contract "$PROMPT" \
  "Skip owns deterministic exclusions and the safe placeholder exception"
assert_contract severity_contract "$PROMPT" \
  "Severity keeps blocking discovery failures separate from advisory quality"
assert_contract output_contract "$PROMPT" \
  "Output preserves schema, RIGHT-side resolver authority, and null-drop behavior"

# Discovery metadata must state both halves of the routing contract and prove
# that boundary with positive and confusing near-miss examples.
assert_all_fragments \
  "$find_section" \
  "description guidance states what the skill does and when to use it" \
  "what it does" "when to use it"
assert_all_matches \
  "$find_section" \
  "trigger guidance requires positive and near-miss evidence" \
  'positive[^.]{0,120}(trigger|case|example|quer(y|ies))' \
  'near[- ]miss[^.]{0,120}(trigger|case|example|quer(y|ies))' \
  '(trigger|routing)[^.]{0,120}(evidence|corpus|eval|test)'
assert_all_matches \
  "$find_section" \
  "trigger absence findings require present or explicitly claimed evidence" \
  '(report|flag)[^.]{0,80}absent[^.]{0,160}(only when|when only)[^.]{0,120}(exact[^.]{0,60}rule|diff[^.]{0,60}(claim|explicit))' \
  '(otherwise|without)[^.]{0,100}(never|do not|must not)[^.]{0,80}infer[^.]{0,60}absence'

# Freedom is selected for the operation: fragile mechanics need less freedom,
# while judgment-heavy work needs more. A blanket setting is not the rule.
assert_all_matches \
  "$find_section" \
  "rubric requires the appropriate degree of freedom" \
  '(required|appropriate|choose|select|match)[^.]{0,80}degrees? of freedom|degrees? of freedom[^.]{0,80}(required|appropriate|choose|select|match)'
assert_no_match \
  "$find_section" \
  '(^|[.!?] |[-*] +)(always|must) (use|choose|select|require) (only )?(low|high)( degree of)? freedom|(^|[.!?] |[-*] +)(low|high)( degree of)? freedom (is|must be) (always|mandatory|required)' \
  "rubric does not prescribe blanket low or high freedom"

# Progressive disclosure keeps the root compact and every reference directly
# reachable from it rather than creating a reference-of-a-reference maze.
assert_all_fragments \
  "$find_section" \
  "root has an approximately 500-line soft ceiling" \
  "SKILL.md body over ~500 lines" "recommend splitting into reference files"
assert_all_fragments \
  "$find_section" \
  "references stay one level deep and link directly from the root" \
  "more than one level deep" "link directly from SKILL.md"

# The package is part of the authored product, not incidental prose. Reusable
# mechanics belong in deterministic scripts/assets; runtime-irrelevant extras
# and brittle package contents are review concerns.
assert_all_matches \
  "$find_section" \
  "rubric covers reusable deterministic scripts, assets, and package hygiene" \
  'reus(e|able)[^.]{0,100}scripts?' \
  'reus(e|able)[^.]{0,100}assets?|assets?[^.]{0,100}reus(e|able)' \
  'deterministic[^.]{0,100}(scripts?|mechanics|validation)|(scripts?|mechanics|validation)[^.]{0,100}deterministic' \
  'auxiliary documentation[^.]{0,120}(runtime|execution|useful|help)'
assert_all_fragments \
  "$find_section" \
  "script and package mechanics retain existing hygiene checks" \
  "Non-descriptive bundled filenames" "punts errors" "magic numbers" "install step"

# Behavioral evidence compares the candidate to a baseline. It checks machine-
# gradeable outcomes and qualitative output, inspects the transcript rather
# than only the final answer, and feeds observations into another iteration.
assert_all_matches \
  "$find_section" \
  "rubric requires candidate/baseline cases and iterative eval evidence" \
  'realistic[^.]{0,160}(case|prompt|eval|scenario)' \
  'candidate[^.]{0,100}baseline|baseline[^.]{0,100}candidate' \
  'objective[^.]{0,40}(assertion|check|grade)' \
  'qualitative[^.]{0,60}(review|output|assessment)' \
  'inspect[^.]{0,60}transcripts?|transcripts?[^.]{0,60}(inspect|review)' \
  'iterat(e|ion|ive)[^.]{0,100}(evidence|feedback)|(evidence|feedback)[^.]{0,100}iterat(e|ion|ive)'
assert_all_matches \
  "$find_section" \
  "evaluation absence findings require snapshot or explicit diff evidence" \
  '(candidate|baseline)[^.]{0,120}(only when|when only)[^.]{0,120}(validated snapshot|artifacts?[^.]{0,40}present|explicitly claimed)' \
  '(never|do not|must not)[^.]{0,80}infer[^.]{0,60}(absence|missing)'
assert_all_matches \
  "$find_section" \
  "token and duration comparisons are conditional on observability" \
  '(((tokens?|token counts?)[^.]{0,80}(duration|tim(e|ing))|(duration|tim(e|ing))[^.]{0,80}(tokens?|token counts?))[^.]{0,120}(only )?(when|if)[^.]{0,60}(observable|available|exposed)|(only )?(when|if)[^.]{0,60}(observable|available|exposed)[^.]{0,120}((tokens?|token counts?)[^.]{0,80}(duration|tim(e|ing))|(duration|tim(e|ing))[^.]{0,80}(tokens?|token counts?)))'
assert_no_match \
  "$find_section" \
  '((must|mandatory|required|always)[^.]{0,100}(report|measure|compare)[^.]{0,100}((tokens?|token counts?)[^.]{0,80}(duration|tim(e|ing))|(duration|tim(e|ing))[^.]{0,80}(tokens?|token counts?))|((tokens?|token counts?)[^.]{0,80}(duration|tim(e|ing))|(duration|tim(e|ing))[^.]{0,80}(tokens?|token counts?))[^.]{0,100}(mandatory|required|must always|always required|regardless[^.]{0,40}(observable|available|exposed)|even (when|if)[^.]{0,30}unavailable)|(regardless[^.]{0,40}(observable|available|exposed)|even (when|if)[^.]{0,30}unavailable)[^.]{0,120}((tokens?|token counts?)[^.]{0,80}(duration|tim(e|ing))|(duration|tim(e|ing))[^.]{0,80}(tokens?|token counts?)))' \
  "rubric never requires unavailable token or duration metrics"

# Skill review must preserve woostack's cross-host safety contract instead of
# treating one provider's behavior as portable proof.
assert_all_matches \
  "$find_section" \
  "rubric preserves woostack barriers, isolation, receipts, and degradation rules" \
  'approval barriers?' 'backend isolation' 'receipts?' \
  'model[- ]agnostic' '(never|do not|must not)[^.]{0,80}silently downgrade'

# A long reference does not become an automatic defect at 101 lines. The TOC
# threshold is above approximately 300; the middle band needs reviewer judgment.
assert_all_matches \
  "$find_section" \
  "reference TOC policy uses the 300-line threshold and 100-300 judgment band" \
  '((require(s|d)?|must|mandatory)[^.]{0,100}(table of contents|TOC)[^.]{0,100}(over|above|exceed(s|ing)?|>)[^.;]{0,30}(~|approximately |about )?300[^.;]{0,30}lines?|(over|above|exceed(s|ing)?|>)[^.;]{0,30}(~|approximately |about )?300[^.;]{0,30}lines?[^.]{0,100}(require(s|d)?|must|mandatory)[^.]{0,60}(table of contents|TOC))' \
  '(100[-–—]300[^.]{0,140}((judgment|judgement)[^.]{0,100}navigation cost|navigation cost[^.]{0,100}(judgment|judgement))|((judgment|judgement)[^.]{0,100}navigation cost|navigation cost[^.]{0,100}(judgment|judgement))[^.]{0,140}100[-–—]300)'
assert_no_match \
  "$find_section" \
  '(reference files?[^.]{0,80}(over|above|exceed(s|ing)?)[^.]{0,30}~?100 lines[^.]{0,100}(with no|missing|require(s|d)?|must)[^.]{0,50}(table of contents|TOC)|(require(s|d)?|must)[^.]{0,80}(table of contents|TOC)[^.]{0,100}reference files?[^.]{0,80}(over|above|exceed(s|ing)?)[^.]{0,30}~?100 lines|(does not|do not|need not|not required|not mandatory)[^.]{0,100}(table of contents|TOC)[^.]{0,100}(over|above|exceed(s|ing)?|>)[^.;]{0,30}(~|approximately |about )?300|(table of contents|TOC)[^.]{0,60}(is |are )?(not required|not mandatory|unnecessary)[^.]{0,100}(over|above|exceed(s|ing)?|>)[^.;]{0,30}(~|approximately |about )?300|(over|above|exceed(s|ing)?|>)[^.;]{0,30}(~|approximately |about )?300[^.;]{0,30}lines?[^.]{0,100}(does not|do not|need not|not required|not mandatory)[^.]{0,80}(table of contents|TOC))' \
  "rubric keeps the >300 TOC rule normative and rejects an automatic >100 rule"

# A single-token angle-bracket placeholder is intentionally safe. It must not
# be conflated with the real unquoted YAML colon-space mapping hazard.
assert_all_matches \
  "$skip_section" \
  "rubric distinguishes safe angle-bracket placeholders from YAML colon-space" \
  '(safe|allow(ed)?)[^.]{0,100}<[a-z0-9]+(-[a-z0-9]+)*>|<[a-z0-9]+(-[a-z0-9]+)*>[^.]{0,100}(safe|allow(ed)?)' \
  '(single[- ]token|angle[- ]bracket)[^.]{0,100}(placeholder|<[a-z0-9]+(-[a-z0-9]+)*>)|(placeholder|<[a-z0-9]+(-[a-z0-9]+)*>)[^.]{0,100}(single[- ]token|angle[- ]bracket)' \
  'YAML[^.]{0,100}colon[- ]space|colon[- ]space[^.]{0,100}YAML' \
  '(placeholder|angle[- ]bracket)[^.]{0,120}(distinct|different|separate)[^.]{0,120}(YAML|colon[- ]space)|(YAML|colon[- ]space)[^.]{0,120}(distinct|different|separate)[^.]{0,120}(placeholder|angle[- ]bracket)'
assert_no_match \
  "$skip_section" \
  '(angle[- ]bracket placeholders?|<[a-z0-9]+(-[a-z0-9]+)*>)[^.]{0,50}(are|is) (invalid|forbidden|rejected|unsafe)' \
  "rubric does not classify the safe placeholder form as invalid"

# Cross-vendor synthesis imports principles, not provider harnesses, and least-
# code advice cannot delete deliberate multi-layer safety.
assert_all_matches \
  "$skip_section" \
  "rubric forbids provider-runner copying and removal of safety redundancy" \
  '(do not|never|must not|avoid)[^.]{0,100}((copy|clone|import|adopt)[^.]{0,80}(provider|vendor)[- ]specific[^.]{0,40}(runners?|harness(es)?)|(provider|vendor)[- ]specific[^.]{0,40}(runners?|harness(es)?)([^.]{0,40}(copy|clone|import|adopt))?)' \
  '(do not|never|must not)[^.]{0,80}(remov(e|ing|al)|deduplicat(e|ing)|eliminate)[^.]{0,80}(intentional|deliberate)[^.]{0,40}safety redundancy'

write_inverted_root() { # source destination
  local source_path="$1" destination="$2"
  local line changed=0
  : > "$destination"
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == *"SKILL.md body"* && "$line" == *"500 lines"* ]]; then
      printf '%s\n' \
        '  - SKILL.md body over ~500 lines is always acceptable; do not split it into reference files.' \
        >> "$destination"
      changed=$((changed + 1))
    else
      printf '%s\n' "$line" >> "$destination"
    fi
  done < "$source_path"
  [ "$changed" -eq 1 ]
}

write_relocated_rule() { # source destination first-fragment second-fragment
  local source_path="$1" destination="$2"
  local first_fragment="$3" second_fragment="$4"
  local line rule="" moved=0 inserted=0
  : > "$destination"
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == *"$first_fragment"* && "$line" == *"$second_fragment"* ]]; then
      rule="$line"
      moved=$((moved + 1))
      continue
    fi
    printf '%s\n' "$line" >> "$destination"
    if [ "$line" = "**Skip:**" ] && [ -n "$rule" ]; then
      printf '%s\n' "$rule" >> "$destination"
      inserted=$((inserted + 1))
    fi
  done < "$source_path"
  [ "$moved" -eq 1 ] && [ "$inserted" -eq 1 ]
}

write_without_process_evidence_guards() { # source destination
  local source_path="$1" destination="$2"
  local line removed=0
  : > "$destination"
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == *"Report absent in-package trigger"* ]] ||
      [[ "$line" == *"Review candidate/baseline comparison"* ]]; then
      removed=$((removed + 1))
      continue
    fi
    printf '%s\n' "$line" >> "$destination"
  done < "$source_path"
  [ "$removed" -eq 2 ]
}

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/woostack-skills-rubric.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

inverted_root="$tmpdir/inverted-root.md"
if write_inverted_root "$PROMPT" "$inverted_root"; then
  assert_rejected_mutant root_ceiling_contract "$inverted_root" \
    "inverting the soft 500-line guidance is rejected"
else
  fail "inverted-root fixture changed exactly one root-ceiling rule"
fi

missing_sections="$tmpdir/missing-sections.md"
printf '%s\n\n%s\n' "$find_section" "$skip_section" > "$missing_sections"
assert_rejected_mutant structure_contract "$missing_sections" \
  "removing Sources, Scope, Severity, and Output is rejected"

relocated_rule="$tmpdir/relocated-rule.md"
if write_relocated_rule "$PROMPT" "$relocated_rule" "table of contents" "300 lines"; then
  assert_rejected_mutant find_contract "$relocated_rule" \
    "moving a required affirmative rule from Find into Skip is rejected"
else
  fail "relocated-rule fixture moved exactly one TOC rule"
fi
relocated_discovery="$tmpdir/relocated-discovery.md"
if write_relocated_rule "$PROMPT" "$relocated_discovery" "what it does" "when to use it"; then
  assert_rejected_mutant find_contract "$relocated_discovery" \
    "moving discovery metadata rules from Find into Skip is rejected"
else
  fail "relocated-discovery fixture moved exactly one discovery rule"
fi

missing_process_guards="$tmpdir/missing-process-evidence-guards.md"
if write_without_process_evidence_guards "$PROMPT" "$missing_process_guards"; then
  assert_rejected_mutant find_contract "$missing_process_guards" \
    "removing trigger and evaluation evidence guards is rejected"
else
  fail "process-evidence mutant removed exactly two guard rules"
fi


finish
