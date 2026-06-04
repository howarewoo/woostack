# Shared Review Contract

This contract is identical across every provider runner. The orchestration sections below the `---` are provider-specific.

## Output Discipline (READ FIRST)

Every artifact you write under `$OUTDIR/findings.*.json` (default `/tmp/pr-review/findings.<angle>.json`) MUST be a valid JSON array — and **only** a JSON array.

- The file MUST start with `[` and end with `]`.
- No preamble, no commentary, no "I have completed the review…" sentence, no markdown fences (` ``` `), no trailing chatter.
- If you have nothing to report, write the literal `[]`.
- **Write `[]` to your findings file as the FIRST action.** Replace it with the real array just before EXIT. Sub-agents have died mid-run (stream errors, turn-limit interrupts) and left no file at all — the merge step then has no array to merge for that angle. An up-front empty array makes failure non-destructive: the worst case becomes "this angle reported nothing," not "this angle silently dropped out of the review."
- If your runtime offers a "write file" tool, use it directly — do NOT echo the JSON through a chat channel that prepends prose.
- **Escape discipline inside string fields.** Every `"description"`, `"fix"`, and `"suggestion"` is a JSON string — inside it, the only valid backslash escapes are `\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`, and `\uXXXX`. Bare backslashes in code samples (Windows paths, regex like `\d`, LaTeX) MUST be doubled to `\\`. Tabs and newlines in code samples MUST be `\t` / `\n`, never raw control bytes. The merge step has a fallback sanitizer, but a finding that loses content during sanitization is one that fails to land cleanly on the PR.
- Before writing each finding's `line` field, validate it via:
  ```bash
  bash "$WOO_REVIEW_ACTION_PATH/scripts/resolve-diff-line.sh" \
    --file "<path>" --line "<N>"
  ```
  When the helper prints `null`, the line is not anchorable on the diff's RIGHT side and GitHub will reject the comment (HTTP 422). DROP the finding entirely rather than guessing a different line. The merge step also runs a final-pass safety net on this, but resolving up-front saves a round-trip and keeps the finding count honest.
- `$OUTDIR` defaults to a **per-project** path — `/tmp/pr-review-<hash>` derived from the repo's git toplevel (so concurrent reviews of different repos on one machine never share a tree). The orchestrator exports the resolved `OUTDIR` to you; **always prefer the exported `$OUTDIR` env var over any literal `/tmp/pr-review` path throughout this contract.** If `$OUTDIR` is somehow unset, re-derive it by sourcing `scripts/resolve-outdir.sh` — never fall back to a bare `/tmp/pr-review`.

## Prefetched Artifacts (do NOT re-fetch)

- **Diff**: `/tmp/pr-review/diff.txt` — may be a full PR diff OR an incremental `last_sha...HEAD` diff (see `last_sha.txt`).
- **PR metadata** (title, body, headRefOid, baseRefName, files, author): `/tmp/pr-review/meta.json`
- **Enabled angles** (one per line): `/tmp/pr-review/angles.txt`
- **Project rules** (optional, present only if discovered): `/tmp/pr-review/rules.md`
- **Per-repo config** (always present, defaults to `{"severity_floor":"high"}`): `/tmp/pr-review/config.json` — parsed from `.woostack/config.json` in the consumer repo.
- **Incremental base SHA** (always present, may be empty): `/tmp/pr-review/last_sha.txt` — non-empty means `diff.txt` covers only the new commits since the last woostack-review pass. Treat findings as scoped to those commits.
- **Prior unresolved review threads** (always present, may be `[]`): `/tmp/pr-review/prior-findings.json` — array of `{file, line, title, author}` for any unresolved thread on the PR. Consumed by the posting stage for the event-floor gate; angle workers MUST ignore this file. No per-entry `blocking` flag — any non-empty list floors the review event to `REQUEST_CHANGES` (conservative "do not APPROVE while threads open" rule).
- **Cross-PR memory** (optional, present when the consumer repo has `.woostack/memory/` and/or `.woostack/memory.md`): `/tmp/pr-review/memory.md` — a plain-markdown composition of gotchas and previously-accepted issues the team curates. When the repo has a `.woostack/memory/` scope-routed store, this file is composed per-PR: it contains the notes whose `scope` matches the PR's changed files, any one-hop `[[linked]]` notes, plus the always-included global shard (the flat `memory.md`, when present). Treat it as additional rubric: do NOT re-flag an issue the memory file already records as known/accepted. See *Cross-PR memory* below.
- **Chunk manifest** (optional, present only when the diff exceeds `chunking.max_loc`): `/tmp/pr-review/chunks.txt` (one chunk id per line) and `/tmp/pr-review/chunks.json` (manifest: `[{id, files, loc, diff_path, boundary}]`). Each chunk also has its own diff at `/tmp/pr-review/diff.chunk-<id>.txt`. When a worker is dispatched with a chunk id (env `CHUNK` non-empty), it MUST read the chunk-specific diff and write findings to `/tmp/pr-review/findings.<angle>.<chunk>.json`. In the GitHub Action this swap happens transparently — `diff.txt` is replaced with the chunk's diff before the worker runs, and the worker's output is renamed afterwards. When `chunks.txt` is absent, chunking did not activate and the diff fits a single worker (no overhead).

If `/tmp/pr-review/rules.md` exists, treat it as an additional rubric on top of the per-angle scope. Each section is prefixed by a `## SOURCE: <path>` header identifying its origin file (`AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.windsurfrules`, or `GEMINI.md`). Any finding that claims a project-rule violation MUST populate `rule_quote` with a verbatim substring of `rules.md` (the rule text itself, not the source header). The validator discards rule-cited findings whose `rule_quote` is missing or not literally present in `rules.md`.

If `/tmp/pr-review/memory.md` exists, read it before reporting. It is the team's cross-PR memory — gotchas, intentional design choices, and issues a prior review already surfaced and the team consciously accepted. If a finding you would report is already described there as known/accepted/wontfix, DROP it. Memory is advisory context, not a rule source: do not cite it in `rule_quote`.

Set `PR_NUMBER` and `HEAD_SHA` as shell variables before posting anything:

```bash
PR_NUMBER="<from Review Context>"
HEAD_SHA="$(jq -r '.headRefOid // empty' /tmp/pr-review/meta.json 2>/dev/null || echo "")"
if [ -z "$HEAD_SHA" ]; then
  # meta.json missing/empty (e.g. $OUTDIR was wiped mid-run, issue #48). Re-fetch
  # from GitHub so commit_id is never null (GitHub 422 "commit_id required").
  HEAD_SHA="$(gh pr view "$PR_NUMBER" --json headRefOid --jq '.headRefOid' 2>/dev/null || echo "")"
fi
# Export so the Python payload builder (os.environ.get("HEAD_SHA")) sees it.
export HEAD_SHA
```

## Model Tiers (host-agnostic)

Each angle prompt and the validator declare a `tier:` in frontmatter — `fast`, `standard`, or `deep`. The host/runner resolves the tier to a concrete model from the table below. The context+summary subagent (defined in each provider prompt) is implicitly `fast`.

| Tier | Use for | Anthropic | OpenAI (Codex) | Google (Gemini) | OpenRouter |
|---|---|---|---|---|---|
| `fast` | rubric checklists (`seo`, `aeo`, `observability`, `types`, `i18n`, `docs`, `deps`), context summaries | `claude-haiku-4-5` | `gpt-5.3-codex-spark` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-flash` |
| `standard` | reasoning workers (`bugs`, `security`, `architecture`, `design`, `react`, `database`, `tests`, `api`, `infra`) | `claude-sonnet-4-6` | `gpt-5.4` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-pro` |
| `deep` | skeptical validator (highest-leverage filter) | `claude-opus-4-7` | `gpt-5.5` + `reasoning_effort: xhigh` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-pro` + `reasoning_effort: xhigh` |

> **Provider notes:**
> - **Google** currently ships only `gemini-3-5-flash` in the 3.5 line; no Pro/Ultra/Thinking variant exists yet, so all tiers collapse onto flash (tier routing is effectively a no-op until Google releases a larger model).
> - **OpenAI** GPT-5-family reasoning is a parameter on the same slug, not a slug suffix. Use `gpt-5.5` for complex review and the skeptical validator, `gpt-5.4` for everyday coding review, and `gpt-5.3-codex-spark` for simple/cost-sensitive rubric workers and latency-first real-time coding checks. Use `gpt-5.4-mini` only as the non-Spark cost-sensitive fallback when Spark is unavailable. There is no `gpt-5-pro`.
> - **OpenRouter** DeepSeek exposes exactly two slugs — `deepseek/deepseek-v4-flash` and `deepseek/deepseek-v4-pro`. Reasoning is a `reasoning_effort` parameter (`high` / `xhigh`, where `xhigh` maps to max). Use plain `v4-pro` for standard and `v4-pro` with `reasoning_effort: xhigh` for deep. Do not route to `deepseek-r1` — V4 supersedes it.

**Routing rules by host capability:**

- **Per-call routing supported** (Claude Code `Task`, opencode `@subagent`): if `FORCE_TIER` is set in Review Context (`fast` or `deep`), use that as the effective tier for all routed calls first; otherwise use each prompt's own tier. Then apply provider overrides and table defaults.
- **Single model per session** (Codex Action, Gemini CLI): resolve one run model from `run_model` in Load Prompt (which already applies precedence below). You lose per-angle tier behavior; all calls in the session run that one model.
- **Override**: explicit `FORCE_TIER` and `run_model` win before per-repo/per-tier overrides. `run_model` already incorporates action input `model` when no `FORCE_TIER` override applies.

**Per-repo tier overrides (`.woostack/config.json`):** for per-call hosts, resolve effective tier as `FORCE_TIER` if set, else prompt `tier`. Then apply provider overrides from `/tmp/pr-review/config.json`: prefer provider-specific keys first, then flat tier fallbacks: `models.<provider>.<tier>` > `models.<tier>` > table default. Example for OpenAI deep: `jq -r '.models.openai.deep // .models.deep // empty' /tmp/pr-review/config.json` — empty means use the table default.
`inputs.model` (action.yml) and `run_model` (resolved in load-prompt) still win over per-repo and table defaults.

## Per-repo Config (`/tmp/pr-review/config.json`)

The prefetch step parses an optional `.woostack/config.json` in the consumer repo and writes a canonical JSON copy to `/tmp/pr-review/config.json`. Missing file = `{"severity_floor":"high"}` (the noise-control default). The full schema is documented in `SKILL.md`; runners only need to know which keys are consumed at which stage:

| Key | Consumed by | When |
|---|---|---|
| `angles.force`, `angles.skip` | `detect-angles.sh` | Stage 1 |
| `ignore` | `prefetch.sh` (filters diff + paths) | Stage 1 |
| `project_rules` | `prefetch.sh` (appends to `rules.md`) | Stage 1 |
| `authors_skip` | `prefetch.sh` (skips + posts one-line comment; default list applied when absent — issue #19) | Stage 1 |
| `release_rollup_pattern` | `prefetch.sh` (skips + posts one-line comment when PR title matches; default `^(staging\|release\|chore\(release\))` applied when absent — issue #19) | Stage 1 |
| `severity_floor` | `intersect-findings.sh` (floor classifier) | Stage 4c — **defaults to `high`**; below-floor validated findings become non-blocking nits, not drops; set `low`/`medium` to treat more findings as normal |
| `nits` | `intersect-findings.sh` (floor classifier) | Stage 4c — default `true`; `false` drops below-floor non-blocking findings (old behavior). Below-floor blocking findings always surface |
| `models.fast` / `.standard` / `.deep`; `models.<provider>.<tier>` | orchestrator prompts (tier resolution) | Stage 2 |
| `fix_commands` | persisted only; consumed by `--loop` mode (#15) | n/a |
| `chunking.max_loc` | `chunk-diff.sh` (split oversized diff into chunks; default 4000) | Stage 1 |

## Review Angles

This action runs up to seventeen distinct review angles, auto-selected from the changed files. The set of enabled angles is listed in `/tmp/pr-review/angles.txt`. The per-angle prompt bodies live at `${ACTION_PATH}/prompts/angles/<angle>.md` and are loaded by the orchestrator.

| Angle | Always-on | Tooling |
|---|---|---|
| `bugs` | yes | LLM only |
| `security` | yes | LLM + `openai/security-best-practices` rubric (loaded from installed skill or fetched via `gh api repos/openai/skills/contents/skills/.curated/security-best-practices/references/<file>`) |
| `conventions` | gated on `rules.md` presence | LLM + project-discovered `rules.md` (concatenated `AGENTS.md` / `CLAUDE.md` / `.cursorrules` / `.windsurfrules` / `GEMINI.md`) |
| `seo` | no | LLM + `coreyhaines31/seo-audit` rubric (embedded in `prompts/angles/seo.md`) |
| `aeo` | no | LLM + `coreyhaines31/ai-seo` rubric (embedded in `prompts/angles/aeo.md`); deeper `references/` fetched on demand via `gh api repos/coreyhaines31/marketingskills/contents/skills/ai-seo/references/<file>` |
| `design` | no | LLM + `npx -y impeccable@$IMPECCABLE_VERSION detect --json` (one run; quantitative pass from JSON + qualitative critique scoped to flagged files) |
| `react` | no | `npx -y react-doctor@$REACT_DOCTOR_VERSION --diff $BASE_REF --offline` (React linter) + LLM |
| `database` | no | LLM + `supabase/supabase-postgres-best-practices` rubric (loaded from installed skill or fetched via `gh api repos/supabase/agent-skills/contents/skills/supabase-postgres-best-practices/references/<file>`) |
| `tests` | no | LLM only — gated on test-file path in diff |
| `api` | no | LLM only — gated on OpenAPI / GraphQL / `.proto` / route-handler paths or HTTP-verb tokens in the diff |
| `infra` | no | LLM only — gated on `.github/workflows/`, `Dockerfile*`, Terraform / Pulumi / CDK, K8s manifests, Helm |
| `observability` | no | LLM only — gated on logging / error-handling tokens in the diff |
| `types` | no | LLM only — gated on `*.ts` / `*.tsx` / `*.cts` / `*.mts` in diff |
| `i18n` | no | LLM only — gated on `locales/` / `messages/` / `i18n/` / `translations/` directory trees, `*.po` / `*.pot` files, or `i18n.t(` / `useTranslations(` / `<Trans` / `<FormattedMessage` / `$t(` / `t("…")` tokens in the diff body |
| `docs` | no | LLM only — gated on docs paths (`README*`, `CHANGELOG*`, `docs/`, `.env.example`, `*.md`/`*.mdx`, `openapi.{yaml,yml,json}`, `swagger.{yaml,yml,json}`) in diff |
| `deps` | no | LLM only — gated on dependency-manifest paths (`package.json`, lockfiles, `requirements.txt`, `go.mod`, `Cargo.toml`, …) in diff |
| `architecture` | no | LLM only — gated on general-purpose source files in diff (`*.ts`/`*.js`/`*.py`/`*.go`/`*.rs`/`*.java`/`*.rb`/`*.php`/`*.cs`/…); structural-quality / code-judo pass; skips doc-only and config-only PRs |

Each angle writes its findings to `/tmp/pr-review/findings.<angle>.json`. The orchestrator merges them into `/tmp/pr-review/findings.json` after the validator pass, then posts inline comments via a single batched GitHub Review. PR labels MUST NOT be mutated — blocking is signalled exclusively through the native `REQUEST_CHANGES` review event.

## Output Contract

Every run MUST end with one batched GitHub Review submitted via `gh api repos/<repo>/pulls/<PR>/reviews` containing all inline comments, the summary, and the `STATUS_LINE` in the **review body**. The review `event` is the native blocking gate: `REQUEST_CHANGES` (≥1 blocking finding or open prior thread), `COMMENT` (≥1 non-nit non-blocking finding), or `APPROVE` (no findings, or only nits — nits post inline but never withhold approval). PR labels MUST NOT be added, removed, or otherwise mutated.

The PR title and the PR description (issue body) MUST NOT be modified. The `STATUS_LINE` lives inside the Review body — never in the PR body.

### STATUS_LINE (exact format)

Counts: `BLOCKING_COUNT` (blocking findings), `NONBLOCKING_COUNT` (non-nit, non-blocking findings), `NIT_COUNT` (findings with `nit: true`). The `H HIGH, M MEDIUM, L LOW` breakdown counts non-nit findings only. The ` + Q nit(s)` suffix appears only when `NIT_COUNT > 0`.

- `BLOCKING_COUNT >= 1` → `**Status: CHANGES REQUESTED** — N blocking finding(s) (H HIGH, M MEDIUM, L LOW) + K non-blocking[ + Q nit(s)]. See inline comments.`
- `BLOCKING_COUNT == 0, NONBLOCKING_COUNT >= 1` → `**Status: APPROVED WITH SUGGESTIONS** — N non-blocking finding(s) (H HIGH, M MEDIUM, L LOW)[ + Q nit(s)]. See inline comments.`
- `BLOCKING_COUNT == 0, NONBLOCKING_COUNT == 0, NIT_COUNT >= 1` → `**Status: APPROVED** — No blocking findings, Q nit(s). See inline comments.`
- All zero → `**Status: APPROVED** — No validated findings.`

### Pull Request Review (Batch)

Instead of posting individual comments, batch all findings into a single GitHub Review. This uses the `pull_request_review` API.

```bash
# 0. Self-PR detection. The GitHub API rejects `event: REQUEST_CHANGES` when
# the authenticated user is the PR author (HTTP 422 "Can not request changes
# on your own pull request"). Capture both logins so the payload-builder can
# downgrade silently when they match — without this, every self-review run
# with a blocking finding fails to post at all.
AUTH_LOGIN=$(gh api user --jq .login 2>/dev/null || echo "")
PR_AUTHOR=$(jq -r '.author.login // empty' /tmp/pr-review/meta.json 2>/dev/null || echo "")
if [ -z "$PR_AUTHOR" ]; then
  # meta.json gone (issue #48). Without the author the self-PR downgrade fails
  # and GitHub 422s on REQUEST_CHANGES against your own PR. Re-fetch it.
  PR_AUTHOR=$(gh pr view "$PR_NUMBER" --json author --jq '.author.login' 2>/dev/null || echo "")
fi
export AUTH_LOGIN PR_AUTHOR

# 1. Prepare the review body (Summary + Status Line + hidden SHA marker).
# The trailing <!-- woostack-review:sha=$HEAD_SHA --> marker is read by the next run's
# prefetch step to enable incremental review (diffs LAST_SHA...HEAD only). DO NOT
# remove or rename — it is the only state we persist across runs.
#
# Heredoc is single-quoted to disable shell expansion. The orchestrator agent
# substitutes ${STATUS_LINE} and ${HEAD_SHA} into the template text BEFORE
# running cat — same pattern already used for STATUS_LINE. Single-quoted form
# avoids any shell-expansion surface from values that pass through here.
cat <<'BODY_EOF' > /tmp/pr_review_body.txt
## AI Deep Code Review Summary

<1-2 sentence high-level summary of the review results>

---
${STATUS_LINE}
*Audited by woostack-review · Host: <host> · Provider: <provider> · Model: <model>*

<!-- woostack-review:sha=${HEAD_SHA} -->
BODY_EOF

# Surface a degraded adversarial pass (issue #47). When intersect-findings.sh
# fell back to defender-only WHILE adversarial was enabled (degraded:true), tell
# the author the findings are lower-confidence rather than silently shipping a
# single-pass review as if it were the full two-pass result.
if [ -f /tmp/pr-review/validator-metrics.json ] && \
   [ "$(jq -r '.degraded // false' /tmp/pr-review/validator-metrics.json 2>/dev/null)" = "true" ]; then
  printf '\n\n> ⚠️ **Adversarial prosecutor pass was unavailable** — these findings are *defender-only* (a single validation pass, lower confidence than the usual two-pass review).\n' >> /tmp/pr_review_body.txt
fi

# 2. Prepare the review payload with inline comments
python3 -c '
import json, sys, os, re

# Read the final validated findings (output of intersect-findings.sh).
try:
    findings = json.load(open("/tmp/pr-review/findings.json"))
except Exception:
    findings = []

# Prior threads include resolved entries (status field). Event floor counts
# OPEN threads only — resolved ones do not gate the review event.
try:
    priors = json.load(open("/tmp/pr-review/prior-findings.json"))
except Exception:
    priors = []

commit_id = os.environ.get("HEAD_SHA")
pr_body = open("/tmp/pr_review_body.txt").read()

has_new_blocking = any(f.get("blocking", False) for f in findings)
has_open_priors  = any(p.get("status") == "open" for p in priors)
# Nits are event-neutral: a non-nit, non-blocking finding triggers COMMENT; a PR
# whose only findings are nits (or none) APPROVEs. Nit comments still post inline
# under APPROVE — they inform without withholding the green check.
has_non_nit = any(not f.get("nit", False) for f in findings)
if has_new_blocking or has_open_priors:
    event = "REQUEST_CHANGES"
elif has_non_nit:
    event = "COMMENT"
else:
    event = "APPROVE"

# Self-PR downgrade. GitHub rejects REQUEST_CHANGES + APPROVE when the
# authenticated user is the PR author (HTTP 422 "Can not request changes on
# your own pull request" / "Can not approve your own pull request"). Downgrade
# both to COMMENT so the review still posts; the STATUS_LINE in the body
# already carries the accurate signal.
auth_login = (os.environ.get("AUTH_LOGIN") or "").lower()
pr_author = (os.environ.get("PR_AUTHOR") or "").lower()
self_pr = bool(auth_login) and bool(pr_author) and auth_login == pr_author
if self_pr and event in ("REQUEST_CHANGES", "APPROVE"):
    pr_body = pr_body.rstrip() + (
        f"\n\n_Review event downgraded to COMMENT — GitHub blocks "
        f"{event} on your own PR. Status line above carries the actual verdict._\n"
    )
    event = "COMMENT"

comments = []
for f in findings:
    # Inline comment format: bold title, issue description, recommended fix,
    # trailing attribution footer naming the severity + angle agent that
    # flagged the finding (plus a "blocking" tag when blocking == true).
    nit = bool(f.get("nit", False))
    title = f["title"].strip()
    # Guard against an angle that already phrased the title as "Nit: …".
    if nit and not title.lower().startswith("nit:"):
        title = f"Nit: {title}"
    description = f["description"].strip()
    fix = (f.get("fix") or "").strip()
    angle = (f.get("angle") or "").strip()
    severity = (f.get("severity") or "").strip().upper()
    blocking = bool(f.get("blocking", False))

    body = f"**{title}**\n\n{description}"
    if fix:
        body += f"\n\nFix: {fix}"
    # Render ```suggestion``` block only when validator-approved as fix_type=suggestion.
    # fix_type=prose (or missing) → prose-only recommendation, no block.
    if f.get("fix_type") == "suggestion" and f.get("suggestion"):
        # Defense-in-depth: neutralize any line of ≥3 backticks inside the snippet
        # that would close the fenced block early and let agent-supplied content
        # escape into the surrounding PR-comment Markdown. Validator step 7
        # already downgrades such findings, but we re-guard at the render site
        # because the renderer is the trust boundary to GitHub.
        safe_lines = []
        for line in f["suggestion"].splitlines():
            if re.match(r"^\s*`{3,}", line):
                line = line.replace("`", "'")
            safe_lines.append(line)
        safe = "\n".join(safe_lines)
        body += f"\n\n```suggestion\n{safe}\n```"

    # Attribution footer: severity + which angle agent found this. Both values
    # are whitelisted against their known sets so malformed/garbage input
    # cannot inject text into the rendered comment.
    footer_parts = []
    if severity in {"HIGH", "MEDIUM", "LOW"}:
        if nit:
            sev_tag = f"{severity} · NIT"
        elif blocking:
            sev_tag = f"{severity} · BLOCKING"
        else:
            sev_tag = severity
        footer_parts.append(f"<strong>{sev_tag}</strong>")
    if angle in {"bugs","security","conventions","seo","aeo","design","react","database","tests","api","infra","observability","types","i18n","docs","deps","architecture"}:
        footer_parts.append(f"flagged by the <code>{angle}</code> agent")
    if footer_parts:
        body += "\n\n<sub>— " + " · ".join(footer_parts) + "</sub>"

    comments.append({
        "path": f["file"],
        "line": int(f["line"]),
        "side": "RIGHT",
        "body": body
    })

payload = {
    "commit_id": commit_id,
    "body": pr_body,
    "event": event,
    "comments": comments
}
print(json.dumps(payload))
' > /tmp/pr_review_payload.json

# 3. Submit the review
gh api "repos/${GITHUB_REPOSITORY}/pulls/$PR_NUMBER/reviews" \
  --method POST --input /tmp/pr_review_payload.json
```

### Review Body Rules
The `pr_review_body.txt` should contain:
- A 1-2 sentence high-level summary of the findings.
- The `${STATUS_LINE}`.
- Credits line (*Audited by woostack-review...*).
- A hidden HTML comment `<!-- woostack-review:sha=${HEAD_SHA} -->` as the last line. This is the watermark the next run's prefetch step reads to enable incremental review.
- **DO NOT** update the main PR description or title.

### Credits line substitution

The orchestrator agent fills `<host>`, `<provider>`, and `<model>` literally into the credits line before posting — they are not shell variables. **Each value reports what actually executed the review, not what the orchestrator prompt file defaults to.** A user running the `opencode.md` orchestrator under an OpenCode agent (e.g. `mimo-v2.5`) that routes to Anthropic + Sonnet must post `Provider: anthropic · Model: claude-sonnet-4-6`, not the `openrouter` / `deepseek` defaults declared in `opencode.md`.

Resolution order (highest precedence first):

1. **Env-var override.** If `WOO_REVIEW_HOST`, `WOO_REVIEW_PROVIDER`, or `WOO_REVIEW_MODEL` is set, use that value verbatim. Hosts that already know their identity should set these before invoking the skill — it is the only fully reliable channel.
2. **Runtime introspection.** Ask the host runtime for the active model / provider of the **validator step** (the deep-tier pass; if adversarial mode is on, the defender). Examples: OpenCode exposes the active model via its config/SDK; Claude Code's `Task` call uses the explicit `model:` arg you just passed; Gemini CLI prints the active model in `gemini --version`.
3. **Orchestrator default.** Fall back to the validator slug declared in this orchestrator prompt (the `deep` row of the Model Tiers table).
4. **`unknown`.** If none of the above resolves, write `unknown` rather than leaving the placeholder literal.

Field-by-field:

- **`<host>`** — canonical slug for the host agent invoking this skill. Use one of: `claude-code`, `cursor`, `gemini-cli`, `codex`, `opencode`, or another stable identifier the host advertises. When a sub-agent profile or persona is identifiable (e.g. opencode running the `mimo-v2.5` agent), append it in parentheses: `opencode (mimo-v2.5)`. Detection hints: `CLAUDECODE=1` → `claude-code`; `OPENCODE*` env vars → `opencode`; `GEMINI_*` → `gemini-cli`; `CODEX_HOME` → `codex`; `CURSOR*` → `cursor`. Each orchestrator prompt declares a default host identifier near the top — prefer that only after the precedence above is exhausted.
- **`<provider>`** — `anthropic` / `openai` / `google` / `openrouter` / `bedrock` / `vertex` / etc. Whatever the host is *actually* routing through. `opencode.md` is loaded for any OpenRouter-style orchestration shape, but OpenCode can route to any provider — do NOT assume `openrouter` just because this file was selected.
- **`<model>`** — the actual validator model slug as the host sees it (e.g. `claude-opus-4-7`, `claude-sonnet-4-6`, `gpt-5.5`, `gpt-5.3-codex-spark`, `gemini-3-pro`, `openrouter/deepseek/deepseek-v4-pro`). When `inputs.model`, `models.<provider>.<tier>`, or flat `models.<tier>` in `config.json` overrode the default, report the override value, not the table default.

## Findings Schema (`/tmp/pr-review/findings.json`)

Every runner MUST write a final `findings.json` (for debugging + potential post-processing parity). Each per-angle step writes to `/tmp/pr-review/findings.<angle>.json`; the orchestrator merges them after validation:

```json
[
  {
    "angle": "bugs",
    "file": "src/foo.ts",
    "line": 42,
    "severity": "HIGH",
    "blocking": true,
    "nit": false,
    "title": "Short bold headline (≤60 chars, no trailing punctuation)",
    "description": "Issue description: what is wrong and why it matters. Do NOT include the fix here.",
    "fix_type": "suggestion",
    "fix": "Recommended change in prose (e.g. 'use `<=` instead of `<` so the boundary value is included').",
    "suggestion": "verbatim replacement code for the GitHub ```suggestion``` block — REQUIRED when fix_type == \"suggestion\", MUST be null when fix_type == \"prose\"",
    "rule_quote": "exact quoted rule text if rule-based, else null"
  }
]
```

`angle` is one of `bugs | security | conventions | seo | aeo | design | react | database | tests | api | infra | observability | types | i18n | docs | deps | architecture`.

`line` MUST be the post-patch absolute file line — i.e. a line that exists on the RIGHT side of the diff (a `+` added line or a ` ` context line within a hunk for `file`). Lines that fall in a deletion-only region, or outside any hunk for the file, will be rejected by the GitHub API. Validate every line via `scripts/resolve-diff-line.sh` before writing the finding (see *Output Discipline* above); drop the finding when the helper returns `null`.

### `fix_type` discriminator

Every finding MUST set `fix_type` to exactly one of:

- `"suggestion"` — a one-click GitHub ```suggestion``` block is safe. Requires `suggestion` to be populated with self-contained replacement code that is ALL of:
  - ≤10 lines,
  - scoped to the single file at `file`,
  - a complete drop-in replacement for the existing line(s) at `line` (no `...` placeholders, no partial diffs),
  - self-contained (does not reference symbols, imports, or context the diff does not already establish).
- `"prose"` — the change is too large, multi-file, structural, or context-dependent for a one-click block. `suggestion` MUST be `null`; the human-readable `fix` field carries the recommendation.

The validator enforces these rules and will downgrade a violating `fix_type: suggestion` to `fix_type: prose` (clearing `suggestion`) rather than emitting a broken block. When in doubt, prefer `prose` — a usable prose recommendation beats a broken one-click suggestion that loses author trust.

### Inline Comment Format (rendered on the PR)

Every inline comment posted to GitHub MUST follow this four-part structure, assembled from the schema fields above:

```
**<title>**

<description>

Fix: <fix>

<sub>— <strong><severity> · BLOCKING</strong> · flagged by the <code><angle></code> agent</sub>
```

- **Title** — bold one-liner, ≤60 characters, no trailing punctuation. Names the problem.
- **Description** — the issue itself: what is broken, why it matters, with diff-anchored evidence. Do NOT prescribe the fix here.
- **Fix** — recommended change, prefixed literally with `Fix: `. Required for every finding. The body builder appends a GitHub ```suggestion``` block after the `Fix:` line if and only if `fix_type == "suggestion"` AND `suggestion` is a non-empty string; `fix_type == "prose"` renders the recommendation in prose only.
- **Attribution footer** — small-print line carrying the finding's `severity` (HIGH / MEDIUM / LOW; suffixed with `· BLOCKING` when `blocking == true`, or `· NIT` when `nit == true`) and the angle agent that flagged it (e.g. `<sub>— <strong>HIGH · BLOCKING</strong> · flagged by the <code>bugs</code> agent</sub>`, or `<sub>— <strong>LOW · NIT</strong> · flagged by the <code>bugs</code> agent</sub>`). The body builder appends this automatically from the finding's `severity` / `blocking` / `nit` / `angle` fields. Both `severity` and `angle` are whitelisted against their known sets; unknown/missing values are dropped from the footer rather than injecting raw text. If both are missing, the footer is omitted entirely.

`nit` is a boolean set by `intersect-findings.sh` (the floor classifier), **not** by angle agents: `true` marks a validated below-floor non-blocking finding. The body builder renders a `nit: true` finding with a `Nit:` title prefix and a `· NIT` footer tag, and the event computation treats it as event-neutral (a PR whose only findings are nits still `APPROVE`s, with the nits posted inline). A nit is always non-blocking; a below-floor finding that is `blocking: true` stays a normal finding (`nit: false`).

The body builder in the posting step (see python snippet above) renders this format automatically from `title` / `description` / `fix` / `fix_type` / `suggestion` / `angle` / `severity` / `blocking` / `nit`. Angle agents and the validator MUST populate `title`, `description`, `fix`, `fix_type`, `angle`, `severity`, and `blocking` for every finding; `nit` is added downstream by the classifier.

## Blocking Criteria

A finding is `blocking: true` only when ALL hold:
- Real, in-diff, produced by this PR (not pre-existing).
- One of:
  - Code that will fail to compile/parse.
  - Code that will definitely produce wrong results regardless of inputs.
  - Clear, unambiguous rule violation with exact quoted rule text.
  - Security vulnerability with concrete exploit path.

Otherwise `blocking: false`:
- Style/quality concerns worth surfacing (but not lint-catchable).
- Performance smells (obvious N+1, unnecessary re-render).
- Missing tests on new business logic.
- Defensive coding improvements.
- Defensible subjective suggestions.

## Do NOT Flag

- Lint-catchable issues handled by Biome / ESLint / tsc / similar.
- Input-dependent maybe-issues with no concrete failure case.
- Pedantic nitpicks (whitespace, naming taste without rule backing).
- Pre-existing issues not introduced by this PR.
- Generic security concerns without concrete exploit path in this PR.

---
