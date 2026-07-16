---
type: plan
source: .woostack/specs/2026-07-15-skill-evaluation-optimization.md
status: ready
branch: feature/skill-evaluation-optimization
---

**Source:** [[specs/2026-07-15-skill-evaluation-optimization]]

# Skill Evaluation and Optimization Implementation Plan

**Goal:** Add portable, receipt-backed skill evaluation; make skill-package review deterministic and tiny-diff safe; improve adjacent-command routing; and progressively disclose the three largest orchestration skills without weakening their contracts.

**Architecture:** Deterministic Node standard-library helpers validate skill packages and corpora, prepare isolated candidate/baseline workspaces, aggregate host-written evidence, and render an escaped report. The public `woostack-eval` skill owns corpus approval, host-native paired dispatch, degradation, and handback. Review reuses the same validator and a Git-visible package snapshot while retaining Git diff as the sole finding-anchor authority. Product-level eval corpora then protect trigger boundaries and load-bearing behavior before any root skill is split into direct references.

**Tech Stack:** Markdown Agent Skills, Node.js ESM standard library, Bash contract tests, Git/Graphite, GitHub CLI, Fumadocs site generator.

## Stack and execution order

Create one Graphite stack above the existing spec+plan base branch. Each increment has one branch and one PR; the Git parent is the preceding row. Do not flatten independent-looking later work onto the base: every trigger/refactor increment consumes the evaluator shipped earlier.

| Increment | Branch | Git parent | Acceptance coverage |
| --- | --- | --- | --- |
| 1 | `feature/skill-eval-validation` | `feature/skill-evaluation-optimization` | AC3, AC11 prerequisite, AC18 |
| 2 | `feature/skill-eval-runtime` | increment 1 | AC4–AC9 engine proof |
| 3 | `feature/skill-eval-command` | increment 2 | AC1, AC2, AC4–AC10, AC19 |
| 4 | `feature/skill-review-package-context` | increment 3 | AC3, AC11, AC12 |
| 5 | `feature/skill-review-rubric` | increment 4 | AC13 |
| 6 | `feature/skill-trigger-core` | increment 5 | AC14, cluster 1 |
| 7 | `feature/skill-trigger-utilities` | increment 6 | AC14, cluster 2 |
| 8 | `feature/skill-critical-corpora` | increment 7 | AC15 |
| 9 | `feature/review-progressive-disclosure` | increment 8 | AC16 |
| 10 | `feature/commit-progressive-disclosure` | increment 9 | AC17 |
| 11 | `feature/build-progressive-disclosure` | increment 10 | AC18 |

Every implementation branch follows Red → Green → Refactor. Run only the named bounded tests while developing; the final stack verification runs all affected suites once.

## Increment 1: Canonical package validation and shared frontmatter parser

> **Branch:** `feature/skill-eval-validation`  
> **Depends on:** Spec+plan base PR  
> **Git parent:** `feature/skill-evaluation-optimization`

> Independently shippable deterministic tooling. It replaces a duplicated production parser and is usable by site generation before the public command exists.

### Task 1: Pin the shared parser and validator contracts

**Files:**
- Create: `skills/woostack-eval/references/schemas.md`
- Create: `skills/woostack-eval/scripts/tests/run-tests.sh`
- Create: `skills/woostack-eval/scripts/tests/test-validate.sh`
- Create: `skills/woostack-eval/scripts/tests/test-shared-parser.sh`
- Test: `site/scripts/gen-skills.test.mjs`

- [x] **Step 1 — Red: write contract fixtures and assertions**

Use temporary package directories from the shell tests; do not commit synthetic skill packages. Pin these cases:

```text
valid: quoted description containing `: `
valid: plain description containing `<plan-path>`
invalid: plain description containing `status: approved`
invalid: `<script>` or paired XML/HTML tags in description
invalid: directory/name mismatch, empty or >1024 description
invalid: missing/fenced frontmatter
invalid: missing/escaping local Markdown resource link outside a fence
invalid: duplicate case IDs, unsupported capability/assertion, missing/traversing fixture
invalid: symlink, FIFO/special file, `.git`, `.env*`, or secret-looking package path
```

The parser test imports one exported `parseFrontmatter(raw, file)` function and asserts `{fm, body}` compatibility with the site generator. The package validator test expects a non-zero exit plus an exact field/path for each invalid fixture.

- [x] **Step 2 — Verify Red**

Run:

```bash
bash skills/woostack-eval/scripts/tests/test-validate.sh
bash skills/woostack-eval/scripts/tests/test-shared-parser.sh
```

Expected: both fail because `validate.mjs` does not exist.

### Task 2: Implement deterministic package and corpus validation

**Files:**
- Create: `skills/woostack-eval/scripts/validate.mjs`

- [x] **Step 1 — Green: implement the smallest exported API**

Export and document:

```js
parseFrontmatter(raw, file)
validatePackage(packagePath, { repositoryRoot, trackedOnly })
validateCorpus(corpusPath, packageInfo)
hashPackage(packagePath, { trackedOnly })
```

The CLI is:

```text
node validate.mjs --package <skill-dir-or-SKILL.md> [--repository-root <root>] [--tracked-only] [--json]
```

Required behavior:

- Resolve exactly one owning directory and regular `SKILL.md`; reject symlinks and special files before reading.
- Parse only the opening unfenced `---` block. Preserve compatibility with quoted scalar descriptions and plugin-specific extra frontmatter while validating `name` and `description` as scalar strings.
- Reject a plain-scalar `description` containing YAML's real colon-space mapping hazard. Permit a tested single-token `<placeholder-name>`; reject XML-like paired/closing/declaration markup.
- Enforce kebab-case name, directory equality, non-empty description, and 1024-character maximum.
- Ignore fenced Markdown when finding links. Resolve local links against their source file, require containment in the repository/package collection root, require regular non-symlink targets, and reject traversal outside the allowed root. URLs and anchors are not local resources.
- Classify package files as `skill`, `reference`, `script`, `asset`, or `eval`; reject `.git`, `.env*`, secret paths, symlinks, and special files.
- Validate `evals/evals.json` and `evals/trigger-evals.json` against `schemaVersion: 1`, exact skill identity, stable unique kebab-case IDs, allowed fields, allowed capabilities (`read-workspace`, `write-workspace`, `shell-workspace`), the eight assertion kinds plus explicit qualitative rubrics, critical booleans, and fixture containment.
- Canonical assertion fields are concrete: `file-contains`/`file-excludes` use literal UTF-8 substrings; `final-contains`/`final-excludes` use literal captured-output substrings; `json-path-equals` uses `file`, RFC 6901 `pointer`, and JSON `expected`; `receipt-field-equals` uses an RFC 6901 `pointer` into the action receipt. Path assertions never follow symlinks. Qualitative assertions require a boolean rubric question and preserve grader rationale separately.
- Emit one JSON result containing normalized metadata, file manifest, corpus summaries, package hash, and errors. Exit non-zero whenever `errors` is non-empty; advisory root/reference size and prose findings do not belong in this validator.
- Never call a model, network, package manager, or provider.
- Guard the CLI entrypoint with an `import.meta.url` check so site generation and `prepare.mjs` can import the module without executing argument parsing or writing output.

- [x] **Step 2 — Run Green tests**

```bash
bash skills/woostack-eval/scripts/tests/run-tests.sh
```

Expected: parser, package, corpus, path-safety, placeholder, and YAML-hazard cases pass.

### Task 3: Make the site generator consume the canonical parser

**Files:**
- Modify: `site/scripts/gen-skills.mjs:1-55`
- Modify: `site/scripts/gen-skills.test.mjs:1-35`

- [x] **Step 1 — Red: change the test import authority**

Import `parseFrontmatter` directly from `../../skills/woostack-eval/scripts/validate.mjs` in the test and add the safe-placeholder/colon-space pair. Expected failure: the generator still owns a second parser.

- [x] **Step 2 — Green: delete the duplicate parser**

Import and re-export `parseFrontmatter` from the canonical validator in `gen-skills.mjs` so existing generator consumers retain their API. Keep rendering functions in the site script.

- [x] **Step 3 — Verify shared production behavior**

```bash
node --test site/scripts/gen-skills.test.mjs
pnpm -C site build
```

Expected: generated pages build with the shared parser; quoted descriptions still render; the colon-space hazard fails deterministically.

### Task 4: Refactor without widening validation

Keep fatal validation limited to the deterministic list in the spec. Do not add root-size, TOC, unlinked-file, degrees-of-freedom, or prose-quality failures. Add comments only around the YAML scalar and containment rules that are not obvious from code.

**Increment verification:**

```bash
bash skills/woostack-eval/scripts/tests/run-tests.sh
node --test site/scripts/gen-skills.test.mjs
pnpm -C site build
```

Commit with `/woostack-commit --no-pr-update`, review this PR, and leave no registration deferral: there is no `SKILL.md` or public command yet.

## Increment 2: Isolated evaluator runtime, receipts, aggregation, and reports

> **Branch:** `feature/skill-eval-runtime`  
> **Depends on:** Increment 1  
> **Git parent:** `feature/skill-eval-validation`

> Independently shippable internal evaluator engine. It is deterministic and fully testable with synthetic worker evidence; it still exposes no public command.

### Task 1: Pin workspace and baseline preparation

**Files:**
- Create: `skills/woostack-eval/references/runner.md`
- Create: `skills/woostack-eval/scripts/tests/test-prepare.sh`

- [ ] **Step 1 — Red**

Cover explicit baseline-ref precedence, explicit baseline-path precedence, mutual exclusion, merge-base resolution through `skills/woostack-init/scripts/resolve-base.sh`, no-skill baseline only for proven absence/non-Git target, dirty candidate preservation, invalid Git lookup fail-closed, atomic run IDs, concurrent runs, ignored `.woostack/tmp` selection, `${TMPDIR:-/tmp}` fallback, traversal/symlink rejection, candidate/baseline separation, fixture copying, canonical trigger catalogs, and original-package pre-dispatch hash.

Expected manifest shape:

```json
{
  "schemaVersion": 1,
  "runId": "20260715T120000Z-1234",
  "targetSkill": "woostack-build",
  "mode": "all",
  "runs": 3,
  "baseline": {"kind": "git-ref", "identity": "0123456789abcdef0123456789abcdef01234567"},
  "runConfiguration": {"host": null, "runner": null, "model": null, "sessionIdentity": null, "tier": null, "effort": null},
  "originalPackageHash": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  "expected": [{"caseId": "markdown-handoff", "variant": "candidate", "repetition": 1, "kind": "behavior"}],
  "pairs": [{"caseId": "markdown-handoff", "repetition": 1, "candidate": "cases/markdown-handoff/1/candidate", "baseline": "cases/markdown-handoff/1/baseline"}]
}
```

### Task 2: Implement safe preparation

**Files:**
- Create: `skills/woostack-eval/scripts/prepare.mjs`

CLI:

```text
node prepare.mjs --target <path> --mode <behavior|triggers|all> --runs <1..10>
  [--baseline-ref <ref> | --baseline-path <dir>] [--catalog-root <skills-dir>]
  [--out-root <dir>] [--run-id <id>]
```

Implementation requirements:

- Reuse `validatePackage` and `hashPackage`; do not duplicate parser/path checks.
- Invoke Git with argument arrays, never shell interpolation. Resolve merge-base only via the canonical resolver; an unavailable resolver requires an explicit baseline.
- Read baseline Git objects without checking out over the user's worktree: enumerate with `git ls-tree -r -z <sha> -- <relative-package>`, reject non-regular modes, and materialize each accepted blob with `git show <sha>:<path>` into the private temporary tree. An explicit absolute baseline path establishes a read-only allowed root.
- Allocate the run directory atomically with mode `0700`; never reuse an existing ID.
- Use `.woostack/tmp/skill-evals` only after canonical-root resolution and `git check-ignore` proof; otherwise use an atomic system-temporary directory and report that fallback.
- Copy only allowed package/fixture files. Build one isolated workspace per case/variant/repetition, plus append-only `evidence/` paths outside the case's capability root. Evidence names are deterministic and collision-free: `action.<kind>.<case-id>.<variant>.<repetition>.json` and `grade.<case-id>.<repetition>.<grader-id>.json`; writers use create-new semantics.
- Produce candidate and baseline trigger catalogs from the same canonical public name/description list rooted at the explicit `--catalog-root` supplied by the skill; default only to the installed collection root derived from `import.meta.url`. Change only the target variant. Add an external target to the candidate catalog when absent; a no-skill baseline omits it.
- Group candidate/baseline workers into inseparable pairs; do not decide host concurrency in the script.

Run `test-prepare.sh`; expected pass.

### Task 3: Pin receipt, assertion, grade, and aggregate behavior

**Files:**
- Create: `skills/woostack-eval/scripts/tests/test-aggregate.sh`

Red cases:

- complete expected evidence; objective pass/fail deltas remain separate;
- missing, duplicate, unknown, malformed, timed-out, failed, model/tier/effort-mismatched, repetition-mismatched, and identity-mismatched receipts block comparison;
- one repetition reports variance unavailable;
- partial wave preserves successful evidence but overall status is blocked;
- candidate-only accepted smoke evidence is degraded and emits no comparative/trigger metric;
- qualitative grade identity remains blinded until its own complete receipt;
- trigger precision/recall uses explicit selected-skill receipts, not transcript text;
- absent token telemetry is `unavailable`, never zero; duration/completion identity are required.

### Task 4: Implement the single aggregate authority

**Files:**
- Create: `skills/woostack-eval/scripts/aggregate.mjs`

CLI:

```text
node aggregate.mjs --manifest <manifest.json> --evidence <dir> --out <aggregate.json>
```

Accept append-only action receipts with the spec-required identity, timing, output, completion, and error fields. Validate exactly the manifest's expected set before grading. Run deterministic assertions against copied workspaces/captured outputs, accept only explicit qualitative grades with completed grader receipts, compute per-case/overall rates and variance, and emit `executionStatus` exactly `complete | blocked | degraded`. Assertion failures may coexist with `complete`; missing execution proof may not. Do not emit a universal merge verdict.

Run `test-aggregate.sh`; expected pass.

### Task 5: Pin and implement escaped reporting

**Files:**
- Create: `skills/woostack-eval/scripts/tests/test-render-report.sh`
- Create: `skills/woostack-eval/scripts/render-report.mjs`

CLI:

```text
node render-report.mjs --aggregate <aggregate.json> --out <report.html> [--terminal]
```

The Red fixture contains `</script>`, active HTML, control bytes, a network URL, huge raw output, a missing token count, blocked/degraded cases, and equal/changed metrics. Green output must:

- start with a restrictive no-script/no-network CSP;
- escape every untrusted value and remove disallowed controls;
- use semantic headings/tables and native keyboard-operable `details/summary` disclosure;
- include visible status text beyond color and accessible contrast;
- link/reference oversized raw evidence by local relative identity instead of embedding it;
- preserve JSON evidence when HTML rendering fails;
- print a bounded terminal summary with report/aggregate paths and no secrets/environment dump.

### Task 6: Refactor and verify the complete engine

Keep worker dispatch out of scripts. Ensure no success file is preinitialized, each receipt is append-only, and aggregate/render writes use create-new or atomic rename semantics.

```bash
bash skills/woostack-eval/scripts/tests/run-tests.sh
```

Expected: all validation, preparation, receipt, partial-run, assertion, trigger, escaping, and concurrency tests pass without network or model access.

## Increment 3: Public `/woostack-eval` workflow and lockstep registration

> **Branch:** `feature/skill-eval-command`  
> **Depends on:** Increment 2  
> **Git parent:** `feature/skill-eval-runtime`

> First public release of the evaluator. Registration and a complete executable workflow ship together; there is no public half-state.

### Task 1: Pin command orchestration and write boundaries

**Files:**
- Create: `skills/woostack-eval/scripts/tests/test-command-contract.sh`
- Create: `skills/woostack-eval/scripts/tests/test-e2e.sh`

Red contract assertions:

```text
/woostack-eval <skill-path> [--behavior | --triggers | --all]
  [--runs <1..10>]
  [--baseline-ref <git-ref> | --baseline-path <skill-dir>]
```

Pin exact target resolution, default `--all`, default three runs, flag mutual exclusion, approval-pending corpus behavior, byte-identical tracked corpus no-gate behavior, no target edits, scoped capabilities, candidate/baseline same-wave pairing, last-action receipts, isolated graders, checksum revalidation, candidate-only accepted degradation, no provider invocation in scripts, renderer failure handback, and terminal no-chain behavior. `test-e2e.sh` simulates host worker outputs/receipts against a temporary skill and runs prepare → aggregate → render; it must not call a model.

### Task 2: Author the concise public skill

**Files:**
- Create: `skills/woostack-eval/SKILL.md`

Root content must remain below the soft 500-line ceiling and directly link `references/schemas.md` and `references/runner.md`. Structure:

1. Exact invocation and target/flag validation.
2. Static package/corpus validation.
3. Corpus discovery/drafting. New or HEAD-different cases are untrusted proposals: present stable IDs, prompts, fixtures, expected outcomes, and assertions; explicit approval is required before any corpus write or run. Silence/ambiguity/rejection writes/runs nothing.
4. Baseline preparation through `prepare.mjs`.
5. Host capability preflight. Load the current host mechanics file. Require isolated scoped contexts and concurrent dispatch of each candidate/baseline pair for a comparative benchmark.
6. Resolve one run configuration. Use a concrete model/tier/effort when exposed; permit `session-default` only when both workers provably inherit it.
7. Dispatch all independent inseparable pairs together when the host limit permits; otherwise deterministic bounded waves without splitting a pair. Worker prompts treat skill/corpus/fixtures/prior outputs as untrusted data and grant only approved workspace capabilities plus evidence writes.
8. Each worker writes output then its last-action receipt. Trigger workers write explicit selected skill/`none`; qualitative graders see anonymized outputs/criteria and write separate receipts.
9. Rehash the original package, aggregate, and render. Any unexpected target delta invalidates the run and never resets user files.
10. Hand back execution status, critical failures, noncritical deltas, telemetry availability, and evidence paths. Never edit the target skill, commit, merge, or chain. If evidence implies a change, name `/woostack-change` or `/woostack-build`.

Add prominent barriers and mirrored Hard constraints for corpus approval, no silent downgrade, no direct provider calls, no target edit, scoped capabilities, receipt completeness, and terminal handback.

### Task 3: Register the twenty-third public command in lockstep

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`
- Modify: `skills/using-woostack/SKILL.md`
- Modify: `skills/woostack-bootstrap/references/development.md`
- Modify: `skills/using-woostack/references/hosts/omp.md`
- Modify: `skills/using-woostack/references/hosts/opencode.md`
- Modify: `skills/using-woostack/references/hosts/claude-code.md`
- Modify: `skills/using-woostack/references/hosts/codex.md`
- Modify: `skills/using-woostack/references/hosts/cursor.md`
- Modify: `skills/using-woostack/references/hosts/antigravity.md`
- Modify: `site/content/docs/concepts/index.mdx`
- Modify: `site/content/docs/concepts/utilities.mdx`
- Modify: `site/scripts/gen-skills.mjs`
- Modify: `site/scripts/gen-skills.test.mjs`
- Modify: `skills/using-woostack/tests/test-artifact-reader-contract.sh`
- Modify: `skills/woostack-change/scripts/tests/test-command-surface.sh`
- Modify: `skills/woostack-respond/scripts/tests/test-command-surface.sh`
- Create: `skills/woostack-eval/scripts/tests/test-command-surface.sh`

Update all public/fixed counts from 22/25 to 23/26 and add `woostack-eval` to the public list, Mode B routing, fixed-path constraint, quick map, README command catalog, contributor map, bootstrap adoption map, `using-woostack` command table, and authored utility docs. Keep `woostack-ask` supporting/unregistered and `woostack-harden`/`woostack-ideate` internal.

Correct the existing generated-site ordering gap in the same lockstep edit: add both already-public `woostack-change` and new `woostack-eval` to `PUBLIC_ORDER`; expected lengths become 23 public and 26 total. Do not hand-edit the generated per-skill page.

Each host file gains only mechanics: how `woostack-eval` dispatches inseparable pairs, whether a concrete per-call model can be pinned, when `session-default` is provable, and whether host concurrency can satisfy comparative mode. Keep evaluator law in `SKILL.md`, not duplicated in host notes.

The new command-surface test reads every site above, asserts one routing row, exact counts/orders, no stale 22/25 phrases in adoption docs, and the utility page's honest write boundary (tracked corpora only after approval; transient reports; no target skill edit).

### Task 4: Verify functional and adoption surfaces

```bash
bash skills/woostack-eval/scripts/tests/run-tests.sh
bash skills/using-woostack/tests/test-artifact-reader-contract.sh
bash skills/woostack-change/scripts/tests/test-command-surface.sh
bash skills/woostack-respond/scripts/tests/test-command-surface.sh
node --test site/scripts/gen-skills.test.mjs
pnpm -C site build
```

Then run one host-native smoke evaluation against `skills/woostack-eval` with `--all --runs 1` and an explicit no-skill or parent-ref baseline. Confirm candidate/baseline pair dispatch when supported, valid receipts, aggregate JSON, escaped HTML, and unchanged target hash. One run must label variance unavailable.

## Increment 4: Git-visible review package context and tiny-skill-diff coverage

> **Branch:** `feature/skill-review-package-context`  
> **Depends on:** Increment 3  
> **Git parent:** `feature/skill-eval-command`

### Task 1: Pin safe full-package snapshot behavior

**Files:**
- Create: `skills/woostack-review/scripts/tests/test-prefetch-skill-package.sh`
- Create: `skills/woostack-review/scripts/tests/test-prefetch-skill-package-ci.sh`

Red scenarios:

- touched existing `SKILL.md` snapshots only Git-visible tracked files from its owning package;
- manifest classifies `SKILL.md`, direct references, scripts, assets, and eval files and records hashes;
- unrelated, ignored, and untracked files never enter the snapshot;
- symlink/special/unsafe path or validator failure blocks prefetch;
- new skill package works;
- multiple touched skills receive distinct deterministic package directories;
- local fresh mode and CI's preserved artifact flow both materialize/read the same package contract;
- diff remains unchanged and is still the only finding-anchor source.

### Task 2: Materialize and validate package artifacts

**Files:**
- Modify: `skills/woostack-review/scripts/prefetch.sh:1-8,448-547`
- Modify: `skills/woostack-review/prompts/_worker-header.md:26-45`
- Modify: `skills/woostack-review/prompts/angles/skills.md:5-7,41-54`

After the authoritative diff/meta are available and before skip/angle decisions:

- detect touched paths ending in `/SKILL.md` or exactly `SKILL.md`;
- use `git ls-files --stage -z` under each owning package to reject symlink/special modes and enumerate only tracked files;
- invoke the shared `validate.mjs --tracked-only --json` before copying;
- materialize under `$OUTDIR/skill-packages/<encoded-skill>/` and write `$OUTDIR/skill-packages.json` atomically;
- fail closed with a blocking prefetch error on snapshot/validation failure; never claim diff-only whole-package review;
- preserve artifacts in CI's detection/review handoff and local per-run output.

Update the worker header to describe the artifact and its untrusted-data boundary. Update the skills angle to require lazy package-manifest inspection, never host-CWD sibling reads, while retaining changed-right-side anchor requirements.

### Task 3: Pin and fix the `<10 LOC` blind spot

**Files:**
- Create: `skills/woostack-review/scripts/tests/test-prefetch-skill-small-diff.sh`
- Modify: `skills/woostack-review/scripts/prefetch.sh:514-545`

Red cases:

1. one-line existing `SKILL.md` description edit: prefetch does not emit `<10 LOC changed`, package validates, and the `skills` angle can run;
2. one-line non-skill source edit: existing full-diff skip remains;
3. one-line non-skill Markdown edit: preserve current behavior unless already exempt;
4. touched skill package snapshot/validation failure: hard failure, not skip;
5. incremental behavior remains unchanged.

Green rule: compute `HAS_TOUCHED_SKILL` from authoritative PR scope/current diff and exempt only that case from the full-diff LOC floor. Do not disable no-new-commits, no-reviewable-files, ignore, cap, or receipt gates.

### Task 4: Preserve anchor integrity

Add fixture assertions that a package-level concern on unchanged content cannot be assigned to an unrelated changed line, while a newly added skill can anchor any added line. The worker prompt keeps `resolve-diff-line.sh` as authority.

### Task 5: Verify both review contexts

```bash
bash skills/woostack-review/scripts/tests/test-prefetch-skill-package.sh
bash skills/woostack-review/scripts/tests/test-prefetch-skill-package-ci.sh
bash skills/woostack-review/scripts/tests/test-prefetch-skill-small-diff.sh
bash skills/woostack-review/scripts/tests/test-detect-angles-skills.sh
bash skills/woostack-eval/scripts/tests/run-tests.sh
```

Smoke a local review on a temporary one-line `SKILL.md` description diff. Observe package manifest, validator result, `skills` in `angles.txt`, and no `<10 LOC` skip; do not require a model finding.

## Increment 5: Cross-vendor skill-authoring rubric

> **Branch:** `feature/skill-review-rubric`  
> **Depends on:** Increment 4  
> **Git parent:** `feature/skill-review-package-context`

### Task 1: Pin rubric behavior, not provider branding

**Files:**
- Create: `skills/woostack-review/scripts/tests/test-skills-angle-rubric.sh`

Assert that the rubric covers:

- what + when metadata and positive/near-miss trigger evidence;
- required degree of freedom rather than blanket low/high freedom;
- concise root plus one-level direct references;
- reusable deterministic scripts/assets and package hygiene;
- realistic candidate/baseline behavior cases, objective assertions, qualitative review, transcript inspection, and iterative feedback;
- token/duration only when observable;
- woostack barriers, backend isolation, receipts, model agnosticism, and no silent downgrade;
- approximately 500-line soft root ceiling;
- TOC required above approximately 300 reference lines and judgment at 100–300;
- safe angle-bracket placeholder distinct from the YAML colon-space hazard;
- no recommendation to copy provider-specific runners or remove intentional safety redundancy.

Red: current rubric fails eval/transcript, degrees-of-freedom, TOC threshold, placeholder/YAML, and package-artifact instructions.

### Task 2: Rewrite the skills angle as the house standard

**Files:**
- Modify: `skills/woostack-review/prompts/angles/skills.md`

Cite and synthesize the complementary Anthropic and OpenAI skill-creator sources named in the spec. The rubric judges the whole package from `$OUTDIR/skill-packages.json` but anchors only on diff-visible changed right-side lines. Deterministic validator failures should have stopped prefetch; the model handles advisory design/prose/eval quality and must not duplicate fatal parser guesses.

Keep severity tied to observable impact: discovery/loading failures are blocking; progressive disclosure, trigger quality, eval evidence, transcript use, and package design are nonblocking unless an exact project rule makes them load-bearing.

### Task 3: Verify rubric and snapshot integration

```bash
bash skills/woostack-review/scripts/tests/test-skills-angle-rubric.sh
bash skills/woostack-review/scripts/tests/test-prefetch-skill-package.sh
bash skills/woostack-review/scripts/tests/test-detect-angles-skills.sh
```

Run a host review of a fixture skill package containing one advisory defect and one deterministic invalid frontmatter case. Confirm the invalid package stops before the model and the advisory case reaches the skills worker with a valid changed-line anchor.

## Increment 6: Trigger boundaries for build/change/fix and execution/review commands

> **Branch:** `feature/skill-trigger-core`  
> **Depends on:** Increment 5  
> **Git parent:** `feature/skill-review-rubric`

### Task 1: Add first-cluster trigger corpora

**Files:**
- Create: `skills/woostack-build/evals/trigger-evals.json`
- Create: `skills/woostack-change/evals/trigger-evals.json`
- Create: `skills/woostack-fix/evals/trigger-evals.json`
- Create: `skills/woostack-bootstrap/evals/trigger-evals.json`
- Create: `skills/woostack-execute/evals/trigger-evals.json`
- Create: `skills/woostack-execute-overnight/evals/trigger-evals.json`
- Create: `skills/woostack-review/evals/trigger-evals.json`
- Create: `skills/woostack-sweep/evals/trigger-evals.json`
- Create: `skills/woostack-address-comments/evals/trigger-evals.json`

Each corpus contains at least one realistic positive and two near-misses guarding:

- new project from scratch → bootstrap; existing multi-PR feature → build; bounded one-PR non-bug change → change; diagnosed/undiagnosed bug → fix;
- supervised approved-plan execution → execute; explicitly unattended overnight execution → execute-overnight;
- one PR/diff review → review; whole stacked-PR convergence loop → sweep; existing unresolved threads → address-comments.

Every near-miss sets `shouldTrigger: false` and `conflictsWith`; positive cases set exact `expectedSkill`. IDs remain stable and wording is user-like, not a restatement of the frontmatter.

### Task 2: Establish the baseline before metadata edits

Run each new corpus against the parent descriptions with three repetitions. The corpora are new, so present all proposed cases and obtain explicit corpus approval before writing/running. Preserve the aggregate as transient evidence; do not convert it to a gate score.

### Task 3: Tighten only descriptions with a demonstrated boundary gap

**Files:**
- Modify: `skills/woostack-build/SKILL.md:1-4`
- Modify: `skills/woostack-review/SKILL.md:1-6`

Use concise third-person what+when metadata:

- `woostack-build`: explicitly say an existing repository feature/work item that needs the full gated multi-PR loop; direct from-scratch projects to bootstrap and bounded one-PR work to change/fix.
- `woostack-review`: explicitly say one PR or local diff; direct whole-stack convergence to sweep and existing unresolved threads to address-comments.

Do not lengthen already-distinct `change`, `fix`, `bootstrap`, `execute`, `execute-overnight`, `sweep`, or `address-comments` descriptions without a failed case proving the need.

### Task 4: Verify candidate routing

```text
/woostack-eval skills/woostack-build --triggers --runs 3 --baseline-ref <increment-5-sha>
/woostack-eval skills/woostack-review --triggers --runs 3 --baseline-ref <increment-5-sha>
```

Also run trigger mode once for each unchanged owning corpus to prove no adjacency regression. Require explicit selected-skill receipts; report precision/recall by stable ID. A changed description must improve the failing case and introduce no new near-miss failure, or revert it.

## Increment 7: Trigger boundaries for investigation, workspace, and QA utilities

> **Branch:** `feature/skill-trigger-utilities`  
> **Depends on:** Increment 6  
> **Git parent:** `feature/skill-trigger-core`

### Task 1: Add second-cluster trigger corpora

**Files:**
- Create: `skills/woostack-ask/evals/trigger-evals.json`
- Create: `skills/woostack-debug/evals/trigger-evals.json`
- Create: `skills/woostack-audit/evals/trigger-evals.json`
- Create: `skills/woostack-init/evals/trigger-evals.json`
- Create: `skills/woostack-doctor/evals/trigger-evals.json`
- Create: `skills/woostack-status/evals/trigger-evals.json`
- Create: `skills/woostack-dream/evals/trigger-evals.json`
- Modify: `skills/woostack-review/evals/trigger-evals.json`
- Create: `skills/woostack-qa/evals/trigger-evals.json`

Guard:

- read-only codebase question → ask; reproduce/root-cause a bug → debug; standing-code multi-angle assessment → audit;
- first-time/repair scaffold → init; diagnose/gated repair workspace integrity → doctor; board/in-flight/next action → status; curate memory/wisdom/docs → dream;
- code diff/PR → review; running-app browser exploration → QA.

### Task 2: Tighten weak metadata and prove it

**Files:**
- Modify: `skills/woostack-qa/SKILL.md:1-6`
- Modify: `skills/woostack-ask/SKILL.md:27-34`
- Modify: `skills/woostack-bootstrap/SKILL.md:25-31`
- Modify: `skills/woostack-debug/SKILL.md:29-34`

Revise `woostack-qa` metadata to state when to use it (a running web app in a real browser) and contrast code-diff review/standing-code audit. Existing ask/debug/audit and init/doctor/status/dream descriptions already carry their primary distinctions; change them only if a named case fails.

After candidate trigger evals pass with no regression, remove only the redundant body-level `## When to use` sections in ask/bootstrap/debug whose unique information is now present in frontmatter and covered by stable trigger cases. Keep all procedure, prerequisites, safety, degradation, and handback text.

### Task 3: Verify controlled routing

Run `/woostack-eval <target> --triggers --runs 3 --baseline-ref <increment-6-sha>` for changed descriptions and one run for every other second-cluster corpus. Reject any metadata edit that raises adjacent-command confusion. The report must label this controlled catalog selection, not host-loader proof.

## Increment 8: Critical behavior corpora for fifteen workflows

> **Branch:** `feature/skill-critical-corpora`  
> **Depends on:** Increment 7  
> **Git parent:** `feature/skill-trigger-utilities`

### Task 1: Add narrow load-bearing behavior cases

**Files:**
- Create: `skills/woostack-eval/evals/evals.json`
- Create: `skills/woostack-build/evals/evals.json`
- Create: `skills/woostack-fix/evals/evals.json`
- Create: `skills/woostack-execute/evals/evals.json`
- Create: `skills/woostack-execute-overnight/evals/evals.json`
- Create: `skills/woostack-commit/evals/evals.json`
- Create: `skills/woostack-review/evals/evals.json`
- Create: `skills/woostack-sweep/evals/evals.json`
- Create: `skills/woostack-address-comments/evals/evals.json`
- Create: `skills/woostack-ask/evals/evals.json`
- Create: `skills/woostack-debug/evals/evals.json`
- Create: `skills/woostack-audit/evals/evals.json`
- Create: `skills/woostack-init/evals/evals.json`
- Create: `skills/woostack-doctor/evals/evals.json`
- Create: `skills/woostack-status/evals/evals.json`
- Create as needed: `skills/<name>/evals/fixtures/**`

Use one or two realistic cases per skill, not exhaustive transcripts. Mark safety invariants `critical: true`:

| Skill | Minimum observable contract |
| --- | --- |
| eval | corpus approval before writes/runs; target hash unchanged; missing receipt blocks |
| build | backend resolved once; exactly three explicit gates; handoff/Go/overnight terminal choice; no merge |
| fix | diagnosis/root cause before plan; plan approval gate; execution delegated; no merge |
| execute | approved input; per-increment implement/verify/commit/review/distill evidence; lifecycle handback; no merge |
| execute-overnight | autonomous blocker policy plus proof receipts and morning report; no hidden downgrade/merge |
| commit | backend before invariants; targeted staging; Graphite submit/read-back; exact attribution; no merge |
| review | all angle receipts before merge/post; one batched review; local/CI boundary; no fix/Linear mutation |
| sweep | bottom-up bounded loop, address pass, no-progress guard, clean-or-blocked handback; no merge |
| address-comments | every unresolved thread fixed or pushed back, replied/resolved/pushed; receipt/verdict gate; no merge |
| ask | read-only backend-first investigation, citations, no artifact/code write, terminal handback |
| debug | root cause before fix proposal, read-only investigation, no chained implementation |
| audit | standing target → synthetic all-added review → report only; no post/fix/merge |
| init | canonical workspace creation/repair boundary and doctor validation; no secret/config invention |
| doctor | diagnose first, explicit local repair approval, remote read-only, exit-coded CI behavior |
| status | backend-aware board; Markdown read-only; only verified merge-backed Linear reconciliation |

Prefer deterministic path/final/receipt assertions. Use `qualitative` only for clarity or sufficiency, with explicit boolean criteria. Corpus data may grant only the three scoped capabilities and cannot request network, credentials, provider access, environment inspection, or out-of-workspace access.

### Task 2: Add named-corpus structural coverage

**Files:**
- Create: `skills/woostack-eval/scripts/tests/test-critical-corpora.sh`

The test enumerates exactly the fifteen required paths, runs `validate.mjs` on each package, proves at least one critical assertion per applicable safety contract, rejects prohibited capabilities, and confirms no corpus is an empty placeholder. It does not inspect prose with brittle full-output snapshots.

### Task 3: Approve and smoke the corpora

Present all new cases grouped by skill and obtain explicit approval before writing/running. Run deterministic validation for all fifteen. Then run `--behavior --runs 1` on each to smoke execution shape and `--runs 3` on at least build, eval, review, commit, and execute to prove paired receipts and variance. Use old/no-skill baselines as appropriate; record noncritical clarity/cost differences as evidence, not merge verdicts.

```bash
bash skills/woostack-eval/scripts/tests/test-critical-corpora.sh
```

## Increment 9: Progressively disclose `woostack-review`

> **Branch:** `feature/review-progressive-disclosure`  
> **Depends on:** Increment 8  
> **Git parent:** `feature/skill-critical-corpora`

### Task 1: Capture a precise pre-refactor baseline

Before editing, record `BASE_SHA=$(git rev-parse HEAD)` and run:

```text
/woostack-eval skills/woostack-review --behavior --runs 3 --baseline-ref $BASE_SHA
```

This candidate-equals-baseline control must complete before the refactor. Retain transient aggregate paths in the PR test plan, not tracked output.

### Task 2: Pin root/reference ownership and all moved content

**Files:**
- Create: `skills/woostack-review/scripts/tests/test-progressive-disclosure.sh`

The structural test concatenates root plus direct references and asserts every existing command, configuration key, integration route, CI setup rule, posting constraint, receipt gate, local/CI distinction, and troubleshooting recovery remains exactly represented. It also asserts:

- root retains stage-by-stage workflow, worker/validator receipt gates, posting behavior, local report behavior, memory/metrics stages, and a prominent `## Hard constraints`;
- every new reference is linked directly from root with a condition saying when to read it;
- no reference links to another reference for required procedure;
- root is below approximately 500 lines;
- references above 300 lines have a TOC; 100–300 lines are not auto-failed;
- local and CI paths select only their needed conditional setup reference.

Red: current monolith has no references and exceeds the target.

### Task 3: Move only conditional catalogs/setup/troubleshooting

**Files:**
- Create: `skills/woostack-review/references/commands.md`
- Create: `skills/woostack-review/references/configuration.md`
- Create: `skills/woostack-review/references/ci.md`
- Create: `skills/woostack-review/references/troubleshooting.md`
- Modify: `skills/woostack-review/SKILL.md`

Move without semantic rewriting:

- detailed invocation/comment trigger/auto-skip/incremental/defer catalog → `commands.md`;
- full config schema/key reference and optional knowledge/memory configuration detail → `configuration.md`;
- action installation example, provider/Linear secret setup, CI-only integration notes → `ci.md`;
- troubleshooting catalog → `troubleshooting.md`.

Root keeps concise command forms, stages 0–6.5, package context, receipts, adversarial validation, one-review posting, local reporting, memory/metrics behavior, and all hard constraints. Add conditional direct links at the decision points: command parsing, config load, CI invocation, and failure diagnosis. Do not move safety law merely to hit a line count.

### Task 4: Update readers and verify behavior/context

Run the structural test and shared package validator. Then evaluate the candidate against `$BASE_SHA` with representative local-PR, local-diff, CI, config override, deferred-stack, posting, and failure prompts. Require no critical behavior loss and lower/equal loaded context on paths that do not need the moved references. If host token telemetry is unavailable, report it unavailable and use deterministic root/selected-reference byte counts plus observable read actions; do not invent token savings.

```bash
bash skills/woostack-review/scripts/tests/test-progressive-disclosure.sh
bash skills/woostack-eval/scripts/tests/test-critical-corpora.sh
node skills/woostack-eval/scripts/validate.mjs --package skills/woostack-review
```

## Increment 10: Progressively disclose `woostack-commit`

> **Branch:** `feature/commit-progressive-disclosure`  
> **Depends on:** Increment 9  
> **Git parent:** `feature/review-progressive-disclosure`

### Task 1: Capture baseline and pin cross-file attribution readers

Record `BASE_SHA=$(git rev-parse HEAD)` before editing. Create a candidate-equals-baseline control eval for Markdown and Linear commit cases.

**Files:**
- Create: `skills/woostack-commit/tests/test-progressive-disclosure.sh`
- Modify: `skills/woostack-commit/tests/test-linear-attribution.sh`

The new test requires direct root links, shared inspect→report stages in root, root hard constraints, exact PR trailer/body/push/read-back behavior in the combined package, and root under approximately 500 lines. Update `test-linear-attribution.sh` to read root plus the selected attribution/PR/Graphite references for detailed tokens while still asserting backend resolution and reference dispatch precede staging/commit/submit in root. Do not weaken the exact `Spec:`, `Linear-Project:`, or `Linear-Issue:` tests.

### Task 2: Split backend and formatting detail

**Files:**
- Create: `skills/woostack-commit/references/markdown-attribution.md`
- Create: `skills/woostack-commit/references/linear-attribution.md`
- Create: `skills/woostack-commit/references/pr-body.md`
- Create: `skills/woostack-commit/references/graphite.md`
- Modify: `skills/woostack-commit/SKILL.md`

Root retains backend resolution, inspect state, branch shape, pre-commit hook, targeted staging, shared attribution decision, commit, submit, verification, report, failure retention, and Hard constraints. Move:

- Markdown invariant/trailer details → `markdown-attribution.md`;
- Linear identity/read-back/transition and exact trailer details → `linear-attribution.md`;
- title/body templates and formatting rules → `pr-body.md`;
- Graphite fallback/reference mechanics → `graphite.md`.

At each root decision point, link directly and load only the selected backend/detail. Verified `change/*` remains artifact-neutral. Shared rules are not duplicated into both backend references.

### Task 3: Prove both backends and Graphite failure behavior

```bash
bash skills/woostack-commit/tests/test-linear-attribution.sh
bash skills/woostack-commit/tests/test-progressive-disclosure.sh
node skills/woostack-eval/scripts/validate.mjs --package skills/woostack-commit
```

Run behavior eval against `$BASE_SHA` for Markdown, Linear, verified `change/*`, `--no-pr-update`, Graphite success, unknown submit outcome, and failure-retention cases. Require exact attribution/trailers, no critical regression, and lower/equal loaded context per selected backend. Missing token telemetry remains unavailable.

## Increment 11: Progressively disclose `woostack-build`

> **Branch:** `feature/build-progressive-disclosure`  
> **Depends on:** Increment 10  
> **Git parent:** `feature/commit-progressive-disclosure`

### Task 1: Capture baseline and adapt lockstep contract tests

Record `BASE_SHA=$(git rev-parse HEAD)` before editing and run a candidate-equals-baseline build eval.

**Files:**
- Create: `skills/woostack-build/scripts/tests/test-progressive-disclosure.sh`
- Modify: `skills/woostack-build/tests/test-linear-build-contract.sh`
- Modify as required: `skills/woostack-build/scripts/tests/test-build-spec-commit-ordering.sh`

Update `test-linear-build-contract.sh` so `markdown_branch` reads `references/markdown-procedure.md`, `linear_branch` reads `references/linear-procedure.md`, and shared root assertions still read `SKILL.md`. Preserve every ordered three-gate, UUID context, replan, freeze, handoff, terminal-state, no-cross-backend, no-GraphQL, and template join assertion. Keep `test-build-spec-commit-ordering.sh` unchanged where root Hard constraints retain its strings; change a reader path only if a backend-specific token intentionally moved.

The new progressive-disclosure test asserts root contains backend resolution, shared chain, dispatch, all three prominent gate barriers, shared terminal states, hard constraints, and direct conditional links; each backend reference repeats the same three ordered gate barriers and contains the complete prior procedure. Root must be below approximately 500 lines.

### Task 2: Move full backend procedures behind resolved dispatch

**Files:**
- Create: `skills/woostack-build/references/markdown-procedure.md`
- Create: `skills/woostack-build/references/linear-procedure.md`
- Modify: `skills/woostack-build/SKILL.md`

Move existing Markdown steps and preserved Markdown hard constraints to the Markdown reference; move Linear preflight/design/spec/plan/replan/freeze/handoff/execute procedure to the Linear reference. Do not rewrite their order while moving.

Root retains:

- resolve backend exactly once and never mix/fallback;
- shared ideate → spec → harden/persist → spec approval → plan → harden/ready → execution handoff chain;
- structurally prominent design approval, spec approval, and execution handoff barriers plus the Hard-constraints restatement that silence is not approval;
- one conditional direct link after backend resolution;
- shared Hand off/Go/Run overnight terminal states;
- Markdown spec-before-approval/base-PR safety and Linear verified-mutation/frozen-base safety where needed to keep the gates skim-resistant;
- never-merge and lifecycle authority rules.

No backend reference may be read before the resolver succeeds. Linear failures never load/fall back to Markdown; Markdown never loads Linear setup.

### Task 3: Verify gates, both backends, and context reduction

```bash
bash skills/woostack-build/tests/test-linear-build-contract.sh
bash skills/woostack-build/scripts/tests/test-build-spec-commit-ordering.sh
bash skills/woostack-build/scripts/tests/test-progressive-disclosure.sh
node skills/woostack-eval/scripts/validate.mjs --package skills/woostack-build
pnpm -C site build
```

Run build behavior eval against `$BASE_SHA` for Markdown Go/Hand off/abandon, Linear Go/Hand off/replan/unknown mutation, and overnight selection. Require all three gate receipts and terminal behavior to match, no cross-backend load/fallback, no critical regression, and lower/equal selected-context bytes/read actions. Token telemetry may be unavailable but never fabricated.

## Plan Checks

| Acceptance criterion | Failing proof and owning increment |
| --- | --- |
| AC1 | `test-command-contract.sh`: exact target/flags/defaults/write boundary (3) |
| AC2 | `test-command-contract.sh` + E2E rejection case: corpus approval before write/run (3) |
| AC3 | `test-validate.sh`: parser, schema, path, capability, fixture, and secret rejection (1) |
| AC4 | `test-prepare.sh`: explicit/ref/path/merge-base/no-skill precedence and failures (2) |
| AC5 | `test-prepare.sh` + `test-e2e.sh`: isolated paired workspaces/config/hash proof (2–3) |
| AC6 | `test-aggregate.sh`: exact append-only receipt set and partial-wave blocking (2) |
| AC7 | `test-aggregate.sh`: deterministic assertions and blinded qualitative grades (2) |
| AC8 | `test-aggregate.sh` + trigger corpora: explicit catalog selection and precision/recall (2, 6–7) |
| AC9 | `test-render-report.sh`: CSP, escaping, accessibility, degradation, retained JSON (2) |
| AC10 | `test-command-surface.sh` plus existing adoption/site tests: 23 public/26 fixed (3) |
| AC11 | `test-prefetch-skill-small-diff.sh`: skill-only LOC-floor exemption and failure close (4) |
| AC12 | package/anchor fixtures: full context with changed-right-side anchoring only (4) |
| AC13 | `test-skills-angle-rubric.sh`: combined house rubric and exceptions (5) |
| AC14 | approved trigger corpora plus three-run old/candidate comparisons (6–7) |
| AC15 | `test-critical-corpora.sh` plus behavior smoke/comparative runs (8) |
| AC16 | review structural test plus old/candidate local+CI behavior/context eval (9) |
| AC17 | commit attribution/structural tests plus Markdown+Linear behavior/context eval (10) |
| AC18 | build gate/Linear/ordering/structural tests plus both-backend behavior/context eval (11) |
| AC19 | command-surface test, authored docs sync, generated page build, no stale deferral (3) |

- **Spec coverage:** Every §4 component, §5 file/data-flow contract, §6 failure class, and §7 AC has an owning task and proof above.
- **Increment shape:** Eleven unique branches form one representable Graphite parent chain. Registration ships only after the deterministic engine is complete. Every later refactor depends on committed behavior corpora.
- **No placeholders:** Commands, paths, schemas, branch names, failure expectations, and smoke stories are concrete; implementation may not introduce stubs, provider calls, or fake receipts.
- **Type consistency:** All helper interfaces use documented JSON with `schemaVersion: 1`; IDs, variants, repetitions, statuses, capabilities, assertions, receipt names, and RFC 6901 pointers have one meaning across prepare/aggregate/report/review.
- **Premise:** The linked approved spec §1 records the measured absence of corpora, current tiny-diff skip, duplicate parser, routing gaps, and oversized roots; the plan does not restate or inflate that evidence.
- **Architecture:** One parser/validator authority feeds site, evaluator, and review. Scripts own deterministic mechanics; the skill owns approval and host dispatch. No backend/provider/runtime layer leaks across those boundaries.
- **Security/observability:** Untrusted corpus/model/remote text cannot expand capabilities; unsafe paths/secrets fail before dispatch; every non-success is explicit in a receipt, aggregate status, terminal summary, or renderer handback.
- **Dependencies/infra:** No new package dependency, lockfile, provider SDK, app code, or model-backed CI is introduced. Existing Node, Bash, Git, Graphite, GitHub CLI, and site build surfaces remain the only runtime/tooling assumptions.

## Final stack verification and handback

After all eleven increment PRs are implemented and individually reviewed, run from the top branch:

```bash
bash skills/woostack-eval/scripts/tests/run-tests.sh
bash skills/woostack-eval/scripts/tests/test-critical-corpora.sh
bash skills/woostack-review/scripts/tests/test-prefetch-skill-package.sh
bash skills/woostack-review/scripts/tests/test-prefetch-skill-package-ci.sh
bash skills/woostack-review/scripts/tests/test-prefetch-skill-small-diff.sh
bash skills/woostack-review/scripts/tests/test-skills-angle-rubric.sh
bash skills/woostack-review/scripts/tests/test-progressive-disclosure.sh
bash skills/woostack-commit/tests/test-linear-attribution.sh
bash skills/woostack-commit/tests/test-progressive-disclosure.sh
bash skills/woostack-build/tests/test-linear-build-contract.sh
bash skills/woostack-build/scripts/tests/test-build-spec-commit-ordering.sh
bash skills/woostack-build/scripts/tests/test-progressive-disclosure.sh
bash skills/using-woostack/tests/test-artifact-reader-contract.sh
bash skills/woostack-change/scripts/tests/test-command-surface.sh
bash skills/woostack-respond/scripts/tests/test-command-surface.sh
node --test site/scripts/gen-skills.test.mjs
pnpm -C site build
```

Then perform these observable smoke stories:

1. New/changed corpus: explicit approval required; rejection/silence writes and runs nothing.
2. Existing HEAD-identical corpus: three paired repetitions run without a repeated gate.
3. Explicit ref/path, merge-base, no-skill, and invalid baseline paths behave exactly by precedence/failure contract.
4. Partial/missing/mismatched receipt blocks comparison while retaining successful evidence.
5. One-line `SKILL.md` edit reaches validated package-aware skills review locally; CI fixture proves the same artifact contract.
6. Trigger corpora select adjacent commands correctly and disclose controlled-catalog scope.
7. Review/commit/build old-versus-candidate behavior retains critical contracts and reduces root/selected context without fabricated token claims.
8. Escaped HTML opens locally with no script/network capability, keyboard-operable disclosure, visible non-color statuses, and machine-readable aggregate alongside it.

Update each increment PR body with exact automated commands/results and manual eval receipt/report paths. Never claim model-backed evals passed unless their aggregate and receipts were observed. Run the standard woostack review sweep bottom-up; do not merge.
