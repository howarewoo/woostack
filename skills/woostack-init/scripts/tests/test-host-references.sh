#!/usr/bin/env bash
# Structural contract: per-host mechanics live in using-woostack/references/hosts/,
# consuming skills carry the canonical load directive, and the provider/tier layer
# stays stable for the CI-inlined review prompt (wisdom: lockstep-edit-sites).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/assert.sh"
S="$(cd "$HERE/../../.." && pwd)"          # -> repo/skills
H="$S/using-woostack/references/hosts"

# (a) host files exist and honor the six-section contract (loop, not a hardcoded list)
assert_eq "$([ -f "$H/README.md" ] && echo y)" "y" "hosts: README present"
n=0
for f in "$H"/*.md; do
  [ "$(basename "$f")" = "README.md" ] && continue
  n=$((n+1))
  body="$(cat "$f")"
  for hdr in "## Detection" "## Subagent spawn" "## Tier routing" "## Host-level fallback" "## Per-skill notes" "## Degradation"; do
    assert_contains "$body" "$hdr" "hosts: $(basename "$f") has '$hdr'"
  done
done
for h in antigravity claude-code codex cursor hermes omp opencode; do
  assert_eq "$([ -f "$H/$h.md" ] && echo y)" "y" "hosts: $h.md present"
done
assert_eq "$([ "$n" -ge 7 ] && echo y)" "y" "hosts: at least seven host files (found $n)"

# (b) canonical load directive in every consumer (one physical line, ASCII)
D='load `skills/using-woostack/references/hosts/<current-host>.md`; no matching file -> treat the host as having no per-call routing and say so (degraded)'
assert_contains "$(cat "$S/using-woostack/references/model-tiers.md")" "$D" "directive: model-tiers.md"
assert_contains "$(cat "$S/using-woostack/references/hosts/README.md")" "$D" "directive: hosts README"
assert_contains "$(cat "$S/woostack-execute/references/subagent-driver.md")" "$D" "directive: subagent-driver.md"
assert_contains "$(cat "$S/woostack-review/SKILL.md")" "$D" "directive: review SKILL.md"
assert_contains "$(cat "$S/woostack-commit/SKILL.md")" "$D" "directive: commit SKILL.md"
assert_contains "$(cat "$S/woostack-init/SKILL.md")" "$D" "directive: init SKILL.md"
assert_contains "$(cat "$S/woostack-execute-overnight/SKILL.md")" 'references/hosts/<current-host>.md' "directive: overnight advisory host pointer"

# (c) provider/tier layer stable for the CI-inlined blob
mt="$(cat "$S/using-woostack/references/model-tiers.md")"
assert_contains "$mt" "| Tier | Use for | Anthropic | OpenAI (Codex) | Google (Gemini) | OpenRouter |" "stability: provider table columns unchanged"
assert_contains "$mt" "hosts/README.md" "stability: model-tiers points at hosts/"
assert_contains "$(cat "$S/woostack-review/prompts/_orchestrator-header.md")" "<!-- WOO_MODEL_TIERS_TABLE -->" "stability: CI table-inline marker intact"

# (d) omp uses fixed role-backed built-in workers, not generated project agents
omp="$(cat "$H/omp.md")"
for row in \
  '| `deep -> slow` | `slow` | `agent: oracle` |' \
  '| `standard -> default` | `default` | `agent: task` |' \
  '| `fast -> smol` | `smol` | `agent: quick_task` |'; do
  assert_contains "$omp" "$row" "omp roles: canonical guidance contains $row"
done
assert_contains "$omp" "role-backed built-in workers" "omp roles: canonical guidance names bundled routing"
for token in "gen-omp-agents.sh" "woostack-fast" "woostack-standard" "woostack-deep" "agent-by-tier" "Agent-by-tier" "models.<tier>"; do
  assert_not_contains "$omp" "$token" "omp roles: canonical guidance omits $token"
done

# (e) generic Hermes stays usable; the optional Hermes + omp pair pins safe dispatch and authority
hermes="$(tr '\n\t' '  ' < "$H/hermes.md" | tr -s ' ')"
omp="$(tr '\n\t' '  ' < "$H/omp.md" | tr -s ' ')"
pair="$hermes $omp"
pair_command='omp --profile <engineer> -p --cwd <repo> <prompt>'
safe_pair_launcher='terminal(command="<resolved-absolute-launcher-dir>/launch-omp", workdir=<host-generated-dispatch-directory>, pty=true)'
unsafe_pair_launcher='terminal(command="omp --profile <engineer> -p --cwd <repo> <prompt>", pty=true)'
assert_contains "$hermes" "$pair_command" "engineer pair: Hermes retains the conceptual omp argv"
assert_contains "$omp" "$pair_command" "engineer pair: omp retains the conceptual profile-pinned argv"
assert_contains "$hermes" "$safe_pair_launcher" "engineer pair: Hermes invokes one static PTY launcher"
assert_contains "$omp" "$safe_pair_launcher" "engineer pair: omp links the same static PTY launcher"
assert_not_contains "$pair" "$unsafe_pair_launcher" "engineer pair: no issue text enters terminal shell syntax"
assert_not_contains "$pair" 'terminal(command="./launch-omp"' \
  "engineer pair: launcher is installed outside untrusted dispatch data"
assert_contains "$hermes" '`omp --help`' "engineer pair: omp help is the executable authority"

for source in \
  'https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/profiles.md' \
  'https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/mcp.md' \
  'https://github.com/NousResearch/hermes-agent/blob/main/website/docs/reference/tools-reference.md#delegation-toolset' \
  'https://github.com/NousResearch/hermes-agent/blob/main/website/docs/reference/tools-reference.md#terminal-toolset' \
  'https://github.com/NousResearch/hermes-agent/blob/main/tools/terminal_tool.py#L934-L944' \
  'https://github.com/NousResearch/hermes-agent/blob/main/tools/environments/local.py#L1318-L1375' \
  'https://github.com/NousResearch/hermes-agent/blob/main/tools/process_registry.py#L685-L780'; do
  assert_contains "$hermes" "$source" "Hermes adapter: cites official source $source"
done

for token in \
  'Use this adapter whenever the current host is Hermes' \
  'default route is Hermes'"'"' native' \
  'does not require omp' \
  'Generic Hermes route (default)' \
  '`delegate_task`' \
  '`delegate_task(tasks=[...])`' \
  'missing omp profile does not degrade the generic Hermes route' \
  'woostack-review (generic Hermes)' \
  'woostack-eval (generic Hermes)' \
  'Optional Hermes + omp engineer-pair route' \
  'When and only when the pair branch passed Detection'; do
  assert_contains "$hermes" "$token" "Hermes generic adapter: contains $token"
done

for token in \
  'argv semantics' \
  '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' \
  'existing canonical absolute' \
  'exactly equal the allocated issue worktree' \
  '${WOO_ENGINEER_LAUNCHER_DIR:-$HOME/.local/libexec/woostack}' \
  'mode `0700`' \
  'mode `0500`' \
  'mode `0600`' \
  'owned regular no-follow files named `profile`, `repo`, `prompt`, and `session`' \
  'with no terminator or encoding wrapper' \
  'never copied into a dispatch directory' \
  'Reject NUL' \
  '["omp", "--profile", profile, "-p", "--cwd", repo, "--", prompt]' \
  '["omp", "--profile", profile, "--resume", session, "-p", "--cwd", repo, "--", prompt]' \
  'reads the staged values without evaluation' \
  '`os.execvpe`' \
  'Direct exec replaces the launcher process' \
  'inherits the PTY, terminal signals/resizes, stdout/stderr, and real process status' \
  'four staged files and dispatch directory'; do
  assert_contains "$hermes" "$token" "engineer pair safe launcher: contains $token"
done
assert_contains "$omp" 'end-of-options barrier before the positional prompt' \
  "engineer pair safe launcher: installed omp parser preserves leading-dash prompts"

for hostile in \
  '$()' \
  'backticks' \
  'single and double quotes' \
  'semicolons' \
  'embedded newlines' \
  'leading dashes'; do
  assert_contains "$pair" "$hostile" "engineer pair adversarial argv: $hostile remains data"
done
assert_contains "$omp" 'remain literal prompt data' "engineer pair adversarial argv: bytes stay data"
assert_contains "$hermes" 'These bytes must reach omp unchanged' "engineer pair adversarial argv: no byte rewriting"
assert_contains "$hermes" 'login-shell `-c` program' "engineer pair shell model: official command-string risk stated"

for token in \
  'stable `ENGINEER_NAME`' \
  'distinct `ENGINEER_NAME`, Linear principal, Hermes profile/session, omp' \
  'same unit Linear principal' \
  'separate host secret stores' \
  'they never copy or share a token/session' \
  'The principal is shared only by that pair' \
  '`terminal.home_mode: profile`'; do
  assert_contains "$pair" "$token" "engineer pair isolation: contains $token"
done

for token in \
  '`actor=app`' \
  '`app:assignable`' \
  '`app:mentionable`' \
  '`actor=user`' \
  'Personal OAuth is not a fallback' \
  'https://linear.app/developers/oauth-2-0-authentication'; do
  assert_contains "$pair" "$token" "engineer pair identity: contains $token"
done

for token in \
  'read-only repository/source access' \
  'GitHub credential limited to reading PRs/diffs and posting review comments' \
  'implementation Git/Graphite/GitHub credentials' \
  'no implementation source-write or push credential' \
  'repository config, prompts, logs, generated files, and development records.' \
  'native GitHub login and immutable principal ID' \
  'implementation author' \
  'Hermes identity as reviewer' \
  'same actor' \
  '`COMMENT` review' \
  'must not attempt `APPROVE`'; do
  assert_contains "$hermes" "$token" "engineer pair credentials: contains $token"
done

for token in \
  'omp-native auth/session/settings/cache state only' \
  'profile-owned root' \
  '`GH_CONFIG_DIR`' \
  '`GIT_CONFIG_GLOBAL`' \
  '<launcher-dir>/profiles/<profile>' \
  '`GH_TOKEN`' \
  '`GITHUB_TOKEN`' \
  '`LINEAR_API_KEY`' \
  'credential-helper/SSH context' \
  'Graphite state' \
  '`omp --profile` alone is not proof' \
  'gen-omp-agents.sh' \
  'No secret is staged'; do
  assert_contains "$pair" "$token" "engineer pair external CLI isolation: contains $token"
done

for token in \
  'woostack-review (selected Hermes + omp pair only)' \
  'terminal(command="<resolved-absolute-launcher-dir>/launch-hermes-review", workdir=<host-generated-review-dispatch-directory>, pty=false)' \
  '["hermes", "chat", "-p", reviewer, "-q", review_prompt]' \
  'fresh isolated session' \
  'differ from the paired implementation profile' \
  'Reviewers return advisory analysis' \
  'posts the verdict comment' \
  '`reviewResult` receipt' \
  'retains every acceptance decision'; do
  assert_contains "$hermes" "$token" "engineer pair review dispatch: contains $token"
done

for token in \
  'standalone dispatcher deliberately assigns' \
  '`assignmentAccepted`' \
  '`assignmentAccepted`, and only then launches omp' \
  'The selected pair must not respond by coding inline' \
  'Immediately before every redispatch' \
  'Hermes re-reads the current issue, owner, state, relations' \
  'MCP session immediately before each allowed edit, commit, push, PR, or Linear evidence mutation' \
  'omp never self-claims' \
  'may not mutate allocation, contracts, dependencies, gates' \
  'not the default independent reviewer' \
  'must never accept its own work' \
  'Only an explicit `/woostack-review`' \
  'Hermes independently reads and reviews the PR' \
  '`precommitReview`' \
  'authorize exactly one `/woostack-commit`' \
  '`--resume <coding-session-id>`' \
  'commit the already reviewed diff' \
  'uses only its coder-owned credentials' \
  'append and read back' \
  'create or refresh and read back the exact native PR relation' \
  'transition `executing` to `inReview` and read it back' \
  'later update must remain `inReview`' \
  'Failure consumes the grant' \
  'No implementation edit, force-push, restack' \
  'other issue/project event or relation' \
  'other lifecycle or gate mutation' \
  'decides acceptance'; do
  assert_contains "$pair" "$token" "engineer pair authority: contains $token"
done

for token in \
  'Woostack does not generate or doctor these profiles.' \
  'unsupported PTY backend' \
  'fails closed before' \
  'missing or mismatched role resolution must fail closed' \
  'Never retry a selected pair without `--profile`' \
  'using an unprofiled omp session' \
  'The explicit `--profile` is mandatory' \
  'selected omp profile and expected model role are pinned' \
  'No local artifact, custom Linear client'; do
  assert_contains "$pair" "$token" "engineer pair fail-closed: contains $token"
done

for consumer in \
  "init:$S/woostack-init/SKILL.md" \
  "commit:$S/woostack-commit/SKILL.md" \
  "execute:$S/woostack-execute/references/subagent-driver.md" \
  "review:$S/woostack-review/SKILL.md"; do
  label="${consumer%%:*}"
  body="$(cat "${consumer#*:}")"
  for token in "gen-omp-agents.sh" "woostack-fast" "woostack-standard" "woostack-deep" "agent-by-tier" "Agent-by-tier"; do
    assert_not_contains "$body" "$token" "omp consumers: $label omits stale $token guidance"
  done
done

# (e) authored docs mirror the supported-host contract
ROOT="$(cd "$S/.." && pwd)"
DOCS="$ROOT/site/content/docs"
HARNESS_DOCS="$DOCS/harnesses"
assert_contains "$(cat "$DOCS/meta.json")" '"harnesses"' "docs: root navigation registers harnesses"
assert_eq "$([ -f "$HARNESS_DOCS/index.mdx" ] && echo y)" "y" "docs: harness overview present"
assert_eq "$([ -f "$HARNESS_DOCS/meta.json" ] && echo y)" "y" "docs: harness navigation present"
if [ -f "$HARNESS_DOCS/index.mdx" ] && [ -f "$HARNESS_DOCS/meta.json" ]; then
  overview="$(cat "$HARNESS_DOCS/index.mdx")"
  harness_nav="$(cat "$HARNESS_DOCS/meta.json")"
  assert_contains "$overview" "skill logic should work in any harness" "docs: portability contract"
  assert_contains "$overview" "native capabilities" "docs: unsupported-host capability caveat"
  assert_contains "$overview" "model selection" "docs: model-selection caveat"
  for f in "$H"/*.md; do
    slug="$(basename "$f" .md)"
    [ "$slug" = "README" ] && continue
    # Hermes' authored engineer-agent page is published by the later product-docs contract.
    [ "$slug" = "hermes" ] && continue
    assert_contains "$harness_nav" "\"$slug\"" "docs: harness nav registers $slug"
    assert_contains "$overview" "/docs/harnesses/$slug" "docs: overview links $slug"
    assert_eq "$([ -f "$HARNESS_DOCS/$slug.mdx" ] && echo y)" "y" "docs: $slug page present"
    if [ -f "$HARNESS_DOCS/$slug.mdx" ]; then
      assert_contains "$(cat "$HARNESS_DOCS/$slug.mdx")" "references/hosts/$slug.md" "docs: $slug links canonical reference"
    fi
  done
fi
for page in "harnesses/index.mdx:$HARNESS_DOCS/index.mdx" "harnesses/omp.mdx:$HARNESS_DOCS/omp.mdx" "configuration.mdx:$DOCS/configuration.mdx" "concepts/context-management.mdx:$DOCS/concepts/context-management.mdx"; do
  label="${page%%:*}"
  path="${page#*:}"
  assert_eq "$([ -f "$path" ] && echo y)" "y" "docs: omp guidance page present: $label"
  [ -f "$path" ] || continue
  source="$(cat "$path")"
  assert_contains "$source" "host-owned role routing" "docs: $label summarizes OMP routing"
  assert_contains "$source" "skills/using-woostack/references/hosts/omp.md" "docs: $label links canonical OMP guidance"
  for token in "deep -> slow" "standard -> default" "fast -> smol" "role-backed built-in workers"; do
    assert_not_contains "$source" "$token" "docs: $label cross-links instead of duplicating $token"
  done
  for token in "gen-omp-agents.sh" "woostack-fast" "woostack-standard" "woostack-deep" "agent-by-tier" "Agent-by-tier" "models.<tier>"; do
    assert_not_contains "$source" "$token" "docs: $label omits $token"
  done
done
landing="$(cat "$DOCS/index.mdx")"
assert_not_contains "$landing" "Aider" "docs: Aider is not explicitly supported"
assert_contains "$landing" "/docs/harnesses" "docs: landing links harnesses"

# (e) review schema and host routing stay aligned on ordered fallback leaves.
review_skill="$(cat "$S/woostack-review/SKILL.md")"
review_header="$(cat "$S/woostack-review/prompts/_orchestrator-header.md")"
assert_contains "$review_skill" "non-empty ordered array" "fallback schema: review skill accepts arrays"
assert_contains "$review_skill" "entry 0 is the primary" "fallback schema: review skill defines primary"
assert_contains "$review_skill" "call the repository model resolver for that route." "omp review: host-owned route skips repository model resolution"
assert_contains "$review_skill" "host recovery is the only model fallback" "omp review: host-owned route skips repository fallback redispatch"
assert_contains "$review_header" "non-empty ordered array" "fallback schema: orchestrator accepts arrays"
assert_contains "$review_header" "entry 0 is primary" "fallback schema: orchestrator defines primary"
for prompt in anthropic openai opencode; do
  assert_contains "$(cat "$S/woostack-review/prompts/$prompt.md")" 'if type=="array" then .[0]' \
    "fallback routing: $prompt selects entry 0"
done

# (f) generic review/sweep fallback recovery remains intact
assert_contains "$review_skill" "concurrent-spawn burst" "re-dispatch: review names the burst condition"
assert_contains "$review_skill" "resolve-model.sh --provider <p> --tier <t> --index N" "re-dispatch: review pins the next configured entry via resolver"
assert_contains "$review_skill" "walking the configured fallback chain" "re-dispatch: review walks the chain before the receipt gate"
sweep_skill="$(cat "$S/woostack-sweep/SKILL.md")"
assert_contains "$sweep_skill" "usage-limit swarm failure is" "re-dispatch: sweep clarifies usage-limit is not an immediate blocker"

finish
