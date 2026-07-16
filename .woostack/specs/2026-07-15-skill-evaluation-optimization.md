---
name: skill-evaluation-optimization
type: spec
status: hardened
date: 2026-07-15
branch: feature/skill-evaluation-optimization
links:
  - https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md
  - https://github.com/openai/skills/blob/main/skills/.system/skill-creator/SKILL.md
---

# Skill Evaluation and Optimization — Design Spec

> Artifact: `.woostack/specs/2026-07-15-skill-evaluation-optimization.md`. The selected backend artifact is the source of truth. Render with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich presentation only.

> `status:` follows the selected backend's owning-artifact contract. In Markdown, this spec owns `draft`, `hardened`, or `approved` while it exists; abandon removes the worktree and branch and closes the PR, leaving no artifact or authored abandoned status. Its joined plan owns later implementation phases and uses `in-review`. The enum and joins are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-07-15-skill-evaluation-optimization]]

## 1. Problem

Woostack has deterministic package checks and a dedicated `skills` review angle, but it has no committed skill-evaluation corpus: `skills/**/evals/**` currently resolves to no files. Skill changes therefore receive static prose and package review without paired old-skill versus candidate behavioral evidence, realistic trigger near-misses, objective assertions, run receipts, or comparable timing/token results. This leaves trigger regressions, skipped workflow gates, unnecessary file loading, premature handbacks, and other model behaviors outside the current proof surface.

The existing static review path also has two demonstrated blind spots:

- `skills/woostack-review/prompts/angles/skills.md:7` says every touched `SKILL.md` is available in full, while `prefetch.sh` builds `diff.txt` from Git diff sections and does not materialize a separate full-package snapshot. Reviewers may therefore reason from changed hunks or host-dependent repository access rather than a deterministic whole-package artifact.
- `skills/woostack-review/scripts/prefetch.sh:541-545` skips full-diff reviews below ten changed lines without exempting `SKILL.md`. A one-line description edit can change discovery and routing while bypassing the angle intended to inspect it.

Progressive disclosure is also uneven. The three largest always-loaded roots are currently `woostack-review` at 686 lines, `woostack-commit` at 462, and `woostack-build` at 403. Their root files mix core orchestration and safety barriers with conditional command variants, backend procedures, configuration catalogs, integration details, and troubleshooting. The explicit user request is to plan the evaluation, review-hardening, metadata, rubric, and progressive-disclosure fixes as separately shippable increments rather than narrowing to only the first optimization.

## 2. Goal

Create a model-agnostic, public `/woostack-eval` workflow that evaluates and reports on a target skill without editing it; establish portable behavior and trigger corpora; make skill-package review deterministic and small-diff safe; align the house rubric with complementary Anthropic and OpenAI guidance; improve adjacent command discovery; and progressively disclose the three largest orchestration skills without weakening their workflows, structural gates, receipts, backend isolation, or hard constraints.

## 3. Non-goals

- Do not vendor or require either upstream `skill-creator` package.
- Do not make Claude, Codex, a provider API, or a specific model a runtime dependency.
- Do not let `/woostack-eval` edit the evaluated `SKILL.md`, commit, open/update a PR, merge, or author feature lifecycle state. Skill changes remain owned by `/woostack-change` or `/woostack-build`.
- Do not add provider-backed model runs to this repository's own CI. CI remains deterministic; comparative runs occur in an agent host and carry explicit receipts.
- Do not turn benchmark scores into a universal merge gate. The command reports evidence; reviewers and the owning change workflow decide what action follows.
- Do not change the semantics or number of existing approval gates, backend lifecycle transitions, review posting rules, or proof-of-execution receipts while reorganizing skill content.
- Do not rename or move any existing fixed `SKILL.md` path.
- Do not add application code, an app lockfile, or dependencies outside the sanctioned `site/` subtree. Evaluation helpers use repository-standard shell and Node standard library only.
- Do not retain raw benchmark output as durable project knowledge by default. Run workspaces are ignored and the command hands the report back in conversation.
- Do not introduce localization infrastructure. The command and offline report follow this repository's existing English-only contributor/tooling surface; report semantics must remain machine-readable so localization can be added later without changing evidence contracts.
- Do not add behavior corpora to every skill in this feature. Initial behavior coverage is limited to the explicitly named load-bearing set below; trigger corpora cover the adjacent routing clusters separately.

## 4. Approach

### 4.1 Add one dedicated public command

Add `/woostack-eval` as the twenty-third public command and the twenty-sixth fixed `SKILL.md` location. Its interface is:

```text
/woostack-eval <skill-path> [--behavior | --triggers | --all] [--runs <1..10>] [--baseline-ref <git-ref> | --baseline-path <skill-dir>]
```

`--all` is the default. `--runs` defaults to three repetitions per case and variant and accepts integers from one through ten. The mode flags and baseline flags are mutually exclusive within their groups. The target must be one exact skill directory or its `SKILL.md`. The command may create or update that target's tracked eval corpus and may write transient run/report artifacts, but it never edits the target skill. A corpus is approval-pending when it is untracked or differs byte-for-byte from `HEAD`; the command presents those proposed cases for explicit approval before writing or running them. An existing valid corpus identical to `HEAD` runs without another gate.

The command resolves a baseline in this order: explicit `--baseline-ref`, explicit `--baseline-path`, the target directory at `git merge-base HEAD "$(resolve-base.sh)"`, then a no-skill baseline when the target did not exist at that valid merge-base or the target is outside a Git checkout. The two explicit flags cannot be combined. Candidate and baseline execute in isolated copies during the same wave with one shared resolved run configuration: a concrete model/tier/effort when the host exposes them, or a documented `session-default` identity only when both workers are guaranteed to inherit the same session model. Behavior workers receive only the selected copied package variant through a scoped task contract and must not load another installed copy of the target. The evaluator records the injected package hash and verifies the original target package hash again after the wave. The current host's native subagent primitive performs the model work; the evaluator scripts never invoke a provider directly.

### 4.2 Store portable corpora with each skill

An evaluated package may contain:

- `evals/evals.json` — versioned behavior cases with stable IDs, realistic prompts, optional fixture paths, expected outcomes, and objective or explicitly qualitative assertions.
- `evals/trigger-evals.json` — versioned should-trigger and near-miss should-not-trigger queries, the expected skill, and any adjacent command whose incorrect selection the case guards against.
- `evals/fixtures/` — deterministic inputs needed by behavior cases.

Tracked corpora are product tests. Run-specific prompts, observable transcripts, outputs, grades, receipts, aggregates, and HTML live under the primary repository's `.woostack/tmp/skill-evals/<run-id>/` only when the canonical root resolver is available and Git confirms that path is ignored. Otherwise the command allocates an atomic directory beneath `${TMPDIR:-/tmp}`, reports the fallback, and does not scaffold or modify `.woostack/` or `.gitignore`.

### 4.3 Use deterministic helpers around host-native workers

Place the evaluator under `skills/woostack-eval/` with a concise root `SKILL.md`, direct references for schemas and runner/grading behavior, scripts for deterministic operations, and shell-based contract tests. Helpers validate a package/corpus, prepare isolated candidate/baseline workspaces, aggregate receipts and grades, and render a self-contained escaped HTML review. They accept and emit documented JSON; they do not call a model, infer success from empty output, or hide partial failures.

Every model repetition writes a separate last-action receipt with at least: schema version, run ID, case ID, one-based repetition index, candidate/baseline variant, target skill, baseline identity, host, runner, concrete model or documented session identity, tier/effort when exposed, start time, duration, output identity, completion state, and explicit error. Missing or malformed receipts block comparative claims. Token counts and observable action transcripts are reported only when the host exposes them; their absence is `unavailable`, not zero or fabricated hidden reasoning.

The run manifest groups each case/repetition's candidate and baseline workers as an inseparable pair. Dispatch all independent pairs together when they fit the host's documented concurrency limit; otherwise partition them deterministically into bounded waves without splitting a pair. A host that cannot run one pair concurrently cannot produce a comparative benchmark.

Behavior cases use deterministic assertions where possible. A separate isolated grader handles only explicitly qualitative criteria and writes its own receipt. Trigger cases run a controlled catalog-selection task: candidate and baseline workers receive the same canonical public skill name/description catalog except for the target variant, then record the selected skill or `none`. This measures semantic routing precision and recall portably; it does not claim to test a host's private loader implementation, and prompt-text similarity without an explicit selection receipt is not evidence.

### 4.4 Make review package-aware and small-diff safe

Keep Git diff as the only source for finding anchors, but make package context independent of the diff. `prefetch.sh` will materialize the Git-visible tracked files for each touched skill package under the review output directory, rejecting symlinks and special files. Its manifest distinguishes the full `SKILL.md`, direct references, scripts, assets, and eval files. The `skills` worker reads this snapshot lazily and deterministically in local and CI modes; unrelated, ignored, and untracked filesystem content never enters the artifact.

A touched `SKILL.md` bypasses the full-diff `<10 LOC` skip. The review still applies the normal diff-anchor rule: package context informs a finding, but an edited existing skill finding must resolve to a changed right-side line. Static validation runs before the model angle and fails closed on discovery-breaking supported frontmatter syntax, missing linked resources, invalid corpus schemas, or unsafe package paths. The validator exports the collection's one skill-frontmatter parser, and `site/scripts/gen-skills.mjs` imports it instead of retaining a second parser; both consumers therefore agree on quoted descriptions, the real colon-space hazard, required fields, and safe placeholder syntax.

Validator errors are limited to deterministic contract failures: missing/fenced frontmatter, invalid or directory-mismatched names, empty/oversized descriptions, unsafe XML-like markup while allowing single-token `<placeholder-name>` usage, escaping or missing relative Markdown links outside fenced code, unsafe file types/paths, and invalid eval schemas. Root/reference size, TOC need, unlinked auxiliary files, degrees of freedom, and prose quality are advisories for the model rubric, not fatal parser guesses. Collection-wide command-surface bookkeeping remains a separate structural test because it is not a generic skill-package property.

### 4.5 Adopt a cross-vendor house rubric

Preserve current safety and installer rules while combining complementary guidance:

- OpenAI-style checks: choose the required degree of freedom, keep the root concise, use one-level direct references, package reusable scripts/assets, avoid auxiliary documentation that does not help runtime execution, validate deterministically, and explain fragile operations rather than relying on prose alone.
- Anthropic-style checks: prove behavior with realistic candidate/baseline cases, inspect transcripts rather than final output only, include objective assertions where possible, review qualitative output, measure tokens/time when available, test trigger precision and recall, and iterate from evidence.
- Woostack rules: remain model-agnostic; structurally enforce approval barriers and proof receipts; preserve backend isolation; never silently downgrade; keep the tested safe angle-bracket placeholder exception and the real YAML colon-space hazard distinct.

Use a soft root ceiling of approximately 500 lines. Require a table of contents for reference files over approximately 300 lines; treat 100–300 lines as reviewer judgment based on navigation cost rather than an automatic defect.

### 4.6 Improve metadata before deleting body guidance

Add realistic positive and near-miss trigger corpora for adjacent commands, then revise their frontmatter descriptions to state the differentiating what-and-when boundary. Only after the metadata and trigger evidence cover a unique body-level `When to use` section may that redundant section be removed. Do not remove procedural prerequisites, safety boundaries, degradation behavior, or command handbacks merely because similar words appear in metadata.

Cover these clusters:

1. `build` / `change` / `fix`; `bootstrap` / `build`; `execute` / `execute-overnight`; `review` / `sweep` / `address-comments`.
2. `ask` / `debug` / `audit`; `init` / `doctor` / `status` / `dream`; `review` / `qa`.

### 4.7 Add critical behavior corpora

Add initial behavior corpora for `woostack-eval`, `woostack-build`, `woostack-fix`, `woostack-execute`, `woostack-execute-overnight`, `woostack-commit`, `woostack-review`, `woostack-sweep`, `woostack-address-comments`, `woostack-ask`, `woostack-debug`, `woostack-audit`, `woostack-init`, `woostack-doctor`, and `woostack-status`. Cases are intentionally narrow: approval barriers, write boundaries, backend isolation, proof receipts, lifecycle/terminal states, and handbacks. Critical assertions mark safety invariants; qualitative assertions judge clarity or efficiency without converting preference into a gate.

### 4.8 Progressively disclose conditional detail

Refactor only after `/woostack-eval` can compare the old and candidate packages.

- `woostack-review`: keep the stage-by-stage orchestration, execution receipts, posting behavior, and hard constraints in root. Move invocation catalog, configuration schema/key reference, integration-specific setup, installation examples, and troubleshooting into direct conditional references.
- `woostack-commit`: keep shared inspection, attribution decision, staging, commit, submission, verification, and reporting in root. Move Markdown- and Linear-specific attribution detail, PR-body formatting, and Graphite fallback/reference detail into direct references.
- `woostack-build`: keep backend resolution, the shared three-gate chain, backend branch dispatch, terminal states, and hard constraints in root. Move the full Markdown and Linear procedures into direct references loaded only after the backend is resolved. Repeat all three gate barriers and shared hard constraints in root; progressive disclosure is not permission to hide load-bearing safety text.

## 5. Components & data flow

### 5.1 Files and ownership

- `skills/woostack-eval/SKILL.md` — public command contract, corpus approval gate, orchestration, degradation, write boundary, and handback.
- `skills/woostack-eval/references/schemas.md` — canonical corpus, receipt, grade, and aggregate field contracts.
- `skills/woostack-eval/references/runner.md` — baseline resolution, isolation, dispatch, grading, report, and failure procedure.
- `skills/woostack-eval/scripts/validate.mjs` — shared skill-frontmatter parser plus package and JSON validation using Node standard library; imported by the site generator and review prefetch.
- `skills/woostack-eval/scripts/prepare.mjs` — safe baseline/candidate/fixture copying and run manifest creation.
- `skills/woostack-eval/scripts/aggregate.mjs` — receipt completeness, assertion grades, metrics, and deltas.
- `skills/woostack-eval/scripts/render-report.mjs` — escaped self-contained HTML plus machine-readable summary.
- `skills/woostack-eval/scripts/tests/` — deterministic validation, path safety, partial-run, escaping, aggregate, shared-parser, and command-contract tests.
- `skills/<name>/evals/` — tracked product-level behavior and trigger corpora.
- `.woostack/tmp/skill-evals/<run-id>/`, or an atomic `${TMPDIR:-/tmp}` fallback outside initialized woostack checkouts — ignored run workspace and report output.
- `skills/woostack-review/scripts/prefetch.sh` and its tests — Git-visible package snapshot, skill-aware skip decision, and validator invocation.
- `skills/woostack-review/prompts/angles/skills.md` — cross-vendor rubric and package-context instructions.
- `skills/using-woostack/SKILL.md`, six `references/hosts/*.md` files, repo command maps, and authored site pages — new command discovery and host-specific dispatch notes.
- Direct references split from `woostack-review`, `woostack-commit`, and `woostack-build`, linked from their root `SKILL.md` files.

### 5.2 Eval corpus contracts

Both corpus files are JSON objects with `schemaVersion: 1`, a `skill` value that exactly matches the target frontmatter name, and a `cases` array. Case IDs are unique kebab-case strings and remain stable across revisions.

A behavior case carries `id`, `prompt`, optional `fixtures`, optional `capabilities`, `expected`, and `assertions`. Capabilities are restricted to `read-workspace`, `write-workspace`, and `shell-workspace`; omitted capabilities default to `read-workspace`. Network, credentials, environment inspection, provider access, and reads/writes outside the copied run workspace are never grantable by corpus data. Supported deterministic assertion kinds are `path-exists`, `path-absent`, `file-contains`, `file-excludes`, `json-path-equals`, `final-contains`, `final-excludes`, and `receipt-field-equals`; their paths are relative to the copied run workspace or captured final output. An assertion may instead declare `qualitative` with an explicit boolean grading rubric. Each assertion may set `critical: true`; critical candidate assertions must pass every repetition and are reported separately from noncritical quality deltas. Fixture paths are relative to the owning `evals/fixtures/` directory and may not escape it.

A trigger case carries `id`, `query`, `shouldTrigger`, `expectedSkill`, and optional `conflictsWith`. Positive and negative cases share one schema and the same controlled catalog-selection procedure so precision and recall are comparable across variants and hosts.

Receipts and grades are append-only per repetition and are never preinitialized as successful. The aggregate accepts only the manifest's expected case/variant/repetition set, rejects duplicates and unknown identities, distinguishes failed assertions from missing/failed execution, computes per-case and overall variance across the selected repetition count, and never converts absent values to passing defaults. Qualitative graders receive anonymized outputs and criteria without candidate/baseline labels; the aggregate restores variant identity only after each grader's receipt is complete. `executionStatus` is exactly `complete`, `blocked`, or `degraded`; assertion failures can coexist with `complete`, while missing execution evidence is `blocked` and candidate-only smoke evidence is `degraded`. The report exposes critical failures and per-assertion deltas but does not manufacture a universal merge verdict.

### 5.3 Runtime flow

```text
exact skill target
  -> static package/corpus validation
  -> corpus approval when new or changed
  -> baseline resolution
  -> isolated candidate + baseline + fixtures
  -> same-wave scoped candidate/baseline workers
  -> per-worker last-action receipts
  -> deterministic assertions + isolated qualitative grades
  -> completeness check and aggregate deltas
  -> escaped static review + terminal summary
  -> conversational handback; no target edit
```

### 5.4 Review flow

```text
touched SKILL.md in PR/local diff
  -> preserve diff for anchors
  -> snapshot full owning package + manifest
  -> deterministic package/corpus validator
  -> bypass <10 LOC skip for skill changes
  -> skills worker reads package snapshot lazily
  -> findings still require changed right-side anchors
```

## 6. Error handling

- Invalid or ambiguous target, missing `SKILL.md`, invalid frontmatter, malformed corpus, duplicate case IDs, unsupported assertions/capabilities, missing fixtures, or escaping fixture paths: stop before any worker spawn and report the exact field/path.
- An untracked or `HEAD`-different corpus without explicit approval: write and run nothing; hand back the proposed cases.
- Invalid `--baseline-ref`, invalid `--baseline-path`, combined baseline flags, or Git lookup failure: stop. Do not silently substitute the merge-base or no-skill baseline.
- In Git, the merge-base path requires the collection's canonical `resolve-base.sh`. If that script is unavailable, require one explicit baseline flag rather than duplicating or guessing base-branch logic.
- Target absent at a valid merge-base, or an exact target outside Git with no explicit baseline: record a no-skill baseline. Target present but unreadable/incomplete at the merge-base: stop rather than treating corruption as absence.
- Existing dirty target changes: copy the current filesystem candidate exactly; do not reset, stage, or modify it. Baseline reads use Git objects or an explicit external path, never checkout over the worktree.
- Unsafe symlink, traversal, special file, or package/fixture path escaping its allowed root: reject before copying. A user-named absolute baseline path establishes its own read-only allowed root; all nested paths remain containment-checked. Never copy `.git`, `.env*`, secrets, or ignored run output into a worker workspace.
- Worker prompts wrap corpus prompts, fixtures, skill text, baseline text, and prior outputs as untrusted data beneath a higher-priority scoped task contract. A requested network/credential/environment/provider capability is invalid rather than an instruction to expand access.
- Host cannot provide isolated worker contexts or enforce the scoped task contract: permit a clearly labeled candidate-only qualitative smoke run only when the user accepts the limitation; do not emit candidate-versus-baseline or trigger-selection metrics or claim benchmark completion.
- The evaluator hashes the original target package after any approved corpus write and before dispatch, then again after all workers finish. Any unexpected delta invalidates the run, preserves the workspace, and reports the changed paths; it never resets or overwrites the user's files.
- Partial spawn, worker error, timeout, malformed output, duplicate receipt, missing receipt, grader failure, or mismatched model/tier/effort between variants: preserve the workspace, mark the affected case blocked/failed, and refuse a clean aggregate.
- Missing token telemetry: show `unavailable`. Missing duration or completion identity: invalid receipt and blocked aggregate.
- Static renderer failure: retain JSON and terminal evidence, report the renderer failure explicitly, and mark the HTML review unavailable; do not discard successful run evidence.
- HTML output: strip disallowed control bytes; escape every prompt, observable transcript, path, error, and model-produced value; emit a restrictive no-script/no-network content-security policy; use semantic headings/tables, keyboard-operable disclosure controls, visible text in addition to status color, and accessible contrast. Never embed model-produced scripts or active external resources.
- Concurrent runs allocate workspaces atomically beneath the primary common root or `${TMPDIR:-/tmp}` fallback. Never reuse or overwrite an existing run ID.
- Missing root resolver, an unignored `.woostack/tmp`, or a non-woostack target uses the system-temporary fallback and reports it. The command never guesses a common root or edits ignore rules.
- Review package snapshot failure or validator failure: emit a blocking prefetch error. Do not fall back to diff-only claims that the full package was inspected.
- Command-surface bookkeeping mismatch after adding `/woostack-eval`: deterministic cross-site tests fail and block the registration increment.
- Progressive-disclosure refactor with broken links, missing moved content, changed gates, lost backend branch, or benchmark regression: fail the owning increment and keep the old root structure.
- Logs and reports must not include environment variables, credentials, or unrelated repository content. Prompts, fixtures, baseline skill text, and model output are untrusted data and cannot expand tool, repository, or disclosure scope.

## 7. Acceptance criteria

- **AC1 — The evaluator has one explicit public contract and write boundary.**
  - happy: `/woostack-eval <skill-path>` resolves one skill, defaults to all evals and three repetitions, and hands back evidence without editing the target skill.
  - error: a missing/ambiguous target, an out-of-range/non-integer `--runs`, or an attempt to request target editing stops before dispatch with the appropriate correction or change/build handback.
  - edge: invoking with the exact `SKILL.md` path and with its owning directory resolves the same package; `--runs 1` is valid but reports variance as unavailable.
- **AC2 — New or changed eval corpora require approval.**
  - happy: for an untracked corpus or one that differs from `HEAD`, the command presents stable case IDs, prompts, fixtures, expected outcomes, and assertions, then writes/runs them only after explicit approval.
  - error: silence, ambiguity, rejection, or invalid cases produces no tracked corpus write and no model run.
  - edge: an existing valid corpus byte-identical to `HEAD` runs without manufacturing a repeated approval gate.
- **AC3 — Package and corpus validation is deterministic and safe.**
  - happy: valid frontmatter, direct resources, eval schemas, IDs, assertions, restricted capabilities, fixtures, and relative paths pass without a model.
  - error: invalid supported frontmatter syntax or JSON, missing resources, duplicate IDs, unsupported assertion/capability kinds, traversal, unsafe symlinks, special files, secret paths, or any requested network/credential/environment/provider access fails before dispatch.
  - edge: tested safe angle-bracket usage placeholders pass while a real YAML colon-space mapping hazard fails.
- **AC4 — Baselines are explicit and reproducible.**
  - happy: exactly one explicit ref/path baseline wins; otherwise the package at `git merge-base HEAD "$(resolve-base.sh)"` is copied and identified in the manifest.
  - error: combined baseline flags, an invalid explicit baseline, or Git lookup failure stops without fallback.
  - edge: a new skill absent at the merge-base, or an exact non-Git target with no explicit baseline, records a no-skill baseline rather than failing or inventing old content.
- **AC5 — Candidate and baseline runs are isolated and comparable.**
  - happy: both variants run in the same wave, in separate copied workspaces, with one proven shared run configuration, the same approved restricted capabilities, injected package hashes, and a pre/post checksum proving the original target package did not change.
  - error: a worker configuration/capability mismatch, installed-target contamination, scoped-task violation, out-of-workspace access, or original-package checksum delta blocks comparative output and never triggers an automatic reset.
  - edge: a documented `session-default` identity is valid only when both workers inherit the same session model; unavailable token telemetry is labeled unavailable while duration, completion, capability, and package identity remain comparable.
- **AC6 — Proof receipts prevent empty or partial success.**
  - happy: every expected case/variant/repetition and qualitative grader writes one valid last-action receipt that aggregates exactly once.
  - error: missing, duplicate, malformed, failed, timed-out, repetition-mismatched, or identity-mismatched receipts block a clean benchmark.
  - edge: a partial wave preserves successful evidence but reports the overall comparison as blocked; one repetition reports no variance rather than zero variance.
- **AC7 — Behavior grading distinguishes objective and qualitative evidence.**
  - happy: deterministic assertions execute without a model; explicitly qualitative criteria use an isolated grader and preserve its rationale/receipt.
  - error: a grader failure or unsupported assertion cannot be converted to pass.
  - edge: a case may combine objective and qualitative criteria, and the report keeps each result separate.
- **AC8 — Trigger evals measure controlled routing boundaries.**
  - happy: positive and near-miss negative queries run against candidate/baseline variants of the same canonical name/description catalog and report explicit selected-skill receipts plus precision/recall by stable case ID.
  - error: transcript wording, prompt similarity, or an unrecorded host loader decision cannot count as a trigger pass.
  - edge: a near-miss that correctly selects an adjacent `conflictsWith` command passes only when the target is not selected; reports label the result as catalog selection rather than host-loader proof.
- **AC9 — Reports are complete, escaped, accessible, and honest about degradation.**
  - happy: the command emits machine-readable aggregate data, a terminal summary, and self-contained escaped HTML with per-case candidate/baseline evidence, metrics, semantic structure, keyboard operation, non-color status text, accessible contrast, and a no-script/no-network policy.
  - error: renderer failure is explicit and does not erase JSON/terminal results; missing required evidence blocks clean status; untrusted output cannot inject markup, scripts, control bytes, or network loads.
  - edge: raw output may remain in the workspace while the summary references it without embedding oversized content; the English-only presentation does not alter the language-neutral JSON contract.
- **AC10 — `/woostack-eval` is registered in lockstep.**
  - happy: all command routing, skill counts/orders, contributor maps, host notes, authored docs/navigation, generated site expectations, and package tests agree on 23 public commands and 26 fixed `SKILL.md` locations.
  - error: any missing or stale site fails deterministic command-surface tests.
  - edge: the evaluator engine may land one stacked increment before public registration only with the repository's explicit down-stack deferral marker; no final stack may retain that deferral.
- **AC11 — Tiny skill edits cannot bypass skill review.**
  - happy: a one-line `SKILL.md` description change bypasses the full-diff `<10 LOC` skip, snapshots the full owning package, runs deterministic validation, and invokes the skills angle.
  - error: snapshot or validation failure blocks rather than claiming whole-package review.
  - edge: a tiny non-skill change retains the existing skip behavior.
- **AC12 — Package context does not weaken diff anchoring.**
  - happy: workers can inspect the full touched package from the review artifact while findings on edited skills still resolve to changed right-side lines.
  - error: a valid package-level concern with no changed anchor is dropped rather than attached to an unrelated line.
  - edge: every line of a newly added `SKILL.md` remains anchorable while sibling resources inform the finding.
- **AC13 — The skills rubric reflects the combined house standard.**
  - happy: it checks degrees of freedom, package hygiene, progressive disclosure, deterministic mechanics, eval evidence, trigger quality, transcript review, and feedback loops.
  - error: it does not recommend copying provider-specific runners or weakening woostack barriers.
  - edge: references over 300 lines require a TOC, 100–300 lines receive judgment, and safe placeholder/YAML rules remain distinct.
- **AC14 — Adjacent commands have tested trigger boundaries.**
  - happy: both defined clusters gain positive/near-miss corpora and descriptions that state their differentiating what-and-when conditions.
  - error: a description change that increases adjacent-command confusion fails its trigger comparison.
  - edge: redundant body trigger prose is removed only after metadata plus eval evidence preserves its unique routing information.
- **AC15 — Critical workflows gain behavioral corpora.**
  - happy: the fifteen named skills test their applicable approval barriers, write boundaries, backend isolation, receipts, terminal states, and handbacks against old/no-skill baselines; safety invariants are marked critical.
  - error: a skipped gate, silent downgrade, cross-backend fallback, fabricated receipt, unauthorized write, premature chain, or missing named corpus fails the owning assertion/structural test.
  - edge: autonomous modes remain autonomous while still proving their structural completion receipts; noncritical clarity/efficiency findings remain report evidence rather than merge gates.
- **AC16 — `woostack-review` progressively discloses without behavior loss.**
  - happy: conditional catalogs/setup/troubleshooting move to direct references; root retains stages, receipts, posting, and hard constraints; old versus candidate evals preserve behavior with lower or equal context use on representative prompts.
  - error: missing commands, configuration behavior, integration routes, or posting/receipt constraints blocks the refactor.
  - edge: local and CI modes both load only the conditional reference they need and remain independently proven.
- **AC17 — `woostack-commit` progressively discloses without behavior loss.**
  - happy: backend-specific attribution/formatting and Graphite detail move to direct references; shared inspect-to-report workflow remains root-visible and benchmarks preserve both backends.
  - error: changed PR trailers, attribution, push/read-back, or failure retention blocks the refactor.
  - edge: Markdown and Linear runs load only their selected attribution reference.
- **AC18 — `woostack-build` progressively discloses without weakening gates.**
  - happy: the root resolves the backend once and loads only the selected backend procedure while retaining the three-gate chain, terminal states, and all hard constraints.
  - error: any missing/extra gate, inferred approval, mixed backend, lifecycle drift, implementation artifact before handoff, or changed never-merge behavior blocks the refactor.
  - edge: both Markdown and Linear benchmark cases prove revise, abandon, handoff, go, and overnight branches where applicable.
- **AC19 — Public documentation remains synchronized.**
  - happy: authored site pages and contributor/project maps describe the new command, count, evaluation loop, and any changed public workflow after the behavior is proven.
  - error: site generation/order tests or the site build fail on stale routing/count/navigation claims.
  - edge: generated per-skill reference pages remain generator-owned and receive no manual edit.

## 8. Testing

Use the existing shell-test conventions and repository-standard runtimes; add no external dependency or provider call to CI.

- Unit/contract tests for every evaluator helper: schema/version validation, IDs, assertion kinds, fixture containment, symlink/special-file rejection, baseline manifests, no-skill baseline, receipt completeness, duplicates, partial waves, metrics unavailable, aggregate deltas, HTML escaping, and renderer degradation.
- End-to-end deterministic fixtures for `/woostack-eval`: exact file/directory target resolution, corpus approval/no approval, candidate/baseline workspace isolation, same-model manifest enforcement, no target mutation, successful report, blocked partial run, and non-isolated-host degradation. Stub only the host dispatch boundary; do not fake helper behavior.
- Review prefetch tests for one-line description diffs, unchanged tiny non-skill diffs, full package snapshot inventory, missing resource/invalid corpus failures, local/CI parity, and right-side finding anchors.
- Cross-skill contract tests for public command order/count, all routing and authored-document sites, six host-file notes, direct-reference existence, one-level navigation, preserved gate text, backend-resolve-before-load order, and no stale deferral marker.
- Committed trigger corpora for the two adjacent-command clusters and behavior corpora for critical workflow invariants. CI validates their schemas; agent-host runs generate candidate/baseline evidence during the owning implementation increments.
- For each progressive-disclosure increment, run `/woostack-eval --behavior` against the old skill and candidate with the same model configuration, inspect the static review, and require no critical assertion regression. Record context/token deltas when the host exposes them; otherwise record the metric as unavailable.
- Run the bounded existing test scripts for every touched skill package. After behavior is proven and authored site claims change, run `node --test site/scripts/gen-skills.test.mjs` and `pnpm -C site build`.

## 9. Open questions

N/A — the design and hardening gates resolved the public command surface, evaluate/report-only authority, corpus approval boundary, three-run default with bounded override, provider-neutral worker boundary, controlled catalog routing proxy, baseline precedence, scoped capabilities, receipt/status contracts, tracked-versus-transient persistence, non-Git degradation, report accessibility/security, initial corpus scope, and all eleven increment themes.
