# Contributing

This repo publishes skills for AI coding assistants, their supporting files, and a documentation
site. The [command index](skills/using-woostack/SKILL.md#command-routing) lists the public
commands, including the standalone Ideate, Harden, and planning-only Prepare phases, and explains
when to use each one. Read [AGENTS.md](AGENTS.md) for the standing repository rules, the sanctioned
`site/` exception, and the verified checks this repo has.

## What to change

| You want to... | Edit |
|---|---|
| Change project adoption / command routing guidance | `skills/using-woostack/SKILL.md` |
| Change retained run handling or direct GitHub publication | `skills/woostack-init/references/artifact-backends.md` and the GitHub profile |
| Add/revise a bootstrap decision or its default | `skills/woostack-bootstrap/references/decisions.md` |
| Swap a default framework | `skills/woostack-bootstrap/references/frameworks.md` |
| Document a new gotcha | `skills/woostack-bootstrap/references/frameworks.md` (Known gotchas section) |
| Adjust the monorepo layout or naming | `skills/woostack-bootstrap/references/architecture.md` |
| Recommend a new hosting/CI/auth choice | `skills/woostack-bootstrap/references/infrastructure.md` |
| Add or revise a development pattern | `skills/woostack-bootstrap/references/patterns.md` |
| Update the branching model | `skills/woostack-bootstrap/references/development.md` |
| Refine the bootstrap procedure | `skills/woostack-bootstrap/references/bootstrap.md` |
| Change the bootstrap skill entry / discovery description | `skills/woostack-bootstrap/SKILL.md` |
| Prepare a feature or proved defect for issue planning | `skills/woostack-prepare/SKILL.md` |
| Change requirements gathering (Ideate) | `skills/woostack-ideate/SKILL.md` |
| Change the check of requirements against the repository (Harden) | `skills/woostack-harden/SKILL.md` |
| Change the Plan publisher and issue graph contract | `skills/woostack-plan/SKILL.md` |
| Change GitHub issue-graph dispatch and stacked delivery | `skills/woostack-orchestrate/SKILL.md`, `skills/woostack-orchestrate/scripts/` |
| Change the execute phase implementation step | `skills/woostack-execute/SKILL.md` |
| Change browser-based app checks (`/woostack-qa`) | `skills/woostack-qa/SKILL.md`, `skills/woostack-qa/references/` |
| Change session reflection (`/woostack-reflect`) | `skills/woostack-reflect/SKILL.md`, `skills/woostack-reflect/scripts/` |
| Change the systematic-debugging behavior (`/woostack-debug`) | `skills/woostack-debug/SKILL.md` |
| Change test-writing guidance | `skills/woostack-execute/SKILL.md`, `skills/woostack-execute/references/tdd.md` |
| Run Plan/Execute/Orchestrate smoke checks | `skills/using-woostack/references/workflow-smoke.md` |
| Change how review comments are addressed | `skills/woostack-address-comments/SKILL.md` |

| Change workspace checks and repairs (`/woostack-doctor`) | `skills/woostack-doctor/SKILL.md` |
| Update agent instructions (Claude or any) | `AGENTS.md` (`.claude/CLAUDE.md` is a symlink to it) |
| Update reader-facing guides | `site/content/docs/` |
| Change the documentation site or skill-page generator | `site/` |

## Workflow

1. Create a Git branch from `main`. The branch is a separate line of work;
   `main` is protected, so changes go through a pull request (PR).
2. Edit the relevant files. Keep each PR focused on one concern where possible.
3. Check that relative links and heading links still resolve (`[label](path.md#anchor)`).
4. Run the changed asset's actual command or focused smoke, plus relevant behavioral tests and
   syntax checks. Tests should check behavior, not exact instruction wording or a test-only copy.
   This repo has no universal test command or CI for its own PRs. For this collection, use
   `pnpm -C site test` and `pnpm -C site build` for catalog/parser structure,
   `bash skills/woostack-orchestrate/scripts/tests/run-tests.sh` for production-controller behavior,
   and the [on-demand workflow smoke recipes](skills/using-woostack/references/workflow-smoke.md)
   for material Plan/Execute/Orchestrate changes. Their installed integration matrix and bounded
   before/after recipe cover cross-boundary changes without a model benchmark service. Run
   `bash skills/woostack-init/scripts/tests/run-tests.sh` and
   `bash skills/woostack-doctor/scripts/tests/run-tests.sh` when those helpers are affected.
   Report deterministic helper results, manual instruction traces, and real host/model outcomes
   separately; never report an unrun smoke as passed.
5. Push the exact branch without force and open a draft PR with `gh`, filling out the PR template.
   Follow the
   [source-control contract](skills/woostack-commit/references/source-control.md).
   Agents must not mark it ready, enable auto-merge, queue it for merging, or merge it.

For site changes, run `pnpm -C site build`. The site is the exception to this repository's
no-application-code rule. Its [README](site/README.md) covers local development and deployment.

## Editing conventions

- Keep workflow changes in skill files and their supporting Markdown, templates, scripts,
  prompts, or JSON. Application code, build configuration, and lockfiles belong only in `site/`.
- Pull-request review uses [Pullfrog](https://pullfrog.com/); the shipped workflow is
  `.github/workflows/pullfrog.yml`.
- Resolve package versions from the registry when needed (`npm view <pkg> version`).
  Name frameworks without versions, except where a known incompatibility requires a pin in
  `skills/woostack-bootstrap/references/frameworks.md`.
- Keep retained run data and direct GitHub publication in the
  [artifact contract](skills/woostack-init/references/artifact-backends.md). Link to the
  [GitHub profile](skills/woostack-init/references/artifact-providers/github.md) for configuration
  and capability details; Prepare and parent-issue Plan do not require Project configuration.
- Use tables to compare options and numbered lists for steps.
- Keep the command names and fixed skill paths listed in the
  [command index](skills/using-woostack/SKILL.md#command-routing).
- GitHub operations do not add commands.
- Keep each `SKILL.md` consistent with its references. Its `description` should explain when to
  use the skill; put the procedure in the body and linked references.
- Update affected authored site guides when behavior changes. Do not edit generated skill pages;
  they are rebuilt from `skills/*/SKILL.md`.

## Instruction and complexity review

Apply the [least-code standard](skills/woostack-bootstrap/references/patterns.md#7-least-code--comments)
to instruction and runtime changes in this collection:

- **Establish the need.** Name an observed failure, demonstrable risk, or requested capability.
  Evidence-backed security hardening need not wait for an incident. An isolated model mistake
  does not justify a universal rule or speculative exception list.
- **Repair the owner first.** Remove obsolete/conflicting rules and dependent explanations,
  clarify the existing rule, or reuse a host/helper capability before appending instructions.
  Keep one general invariant at its narrowest owner and link to it. When relaxing a restriction,
  retain only necessary positive invariants, not lists of newly permitted behavior. Put incident
  IDs, transcripts, debugging narratives, and one-off examples in issue/PR evidence or focused
  regressions, not permanent entry instructions.
- **Keep loading boundaries real.** Root instructions hold standing truths, the router selects
  workflows, and owning skills hold procedures. Detailed schemas, recovery, and host mechanics
  load only for applicable operations; required runtime references must resolve in an installed
  collection. Moving prose to a reference every invocation must read saves no context.
- **Justify machinery.** For a new helper, wrapper, config key, state/receipt, gate, adapter, or
  fallback, explain why deletion, reuse, and the existing host cannot satisfy the need. Prefer
  existing deterministic checks to model-authored bookkeeping. Retirement includes obsolete code,
  examples, callers, and mutation-only tests in the same bounded change; preserve required
  compatibility and all user-owned data.
- **Show recurring cost where it changes.** Growth in standing/entry context, mandatory reads,
  recurring tool calls, or protocol steps needs relevant before/after evidence and a short
  necessity rationale in the existing PR description. Use the
  [measurement recipe](skills/using-woostack/references/workflow-smoke.md#6-bounded-same-task-beforeafter-measurement)
  and [installed smoke guidance](skills/using-woostack/references/workflow-smoke.md#5-installed-integration-matrix):
  distinguish file bytes, actual loaded context, and tokens; include transitive reads, repeated
  worker payloads, and new runtime concepts. This is not a benchmark requirement for typo fixes.
- **Keep correctness above size.** Justified features and security fixes may grow. Retain
  independent action-boundary checks, security, ownership, identity/head/diff binding, error
  handling, and recovery; explain deliberate safety redundancy rather than deduplicating it.
  No global line/byte ceiling, one-in/one-out quota, mandatory net-negative diff, or size-only
  rejection applies.

Review whether following the changed instructions produces the intended working result. A finding
must name the duplicated owner, unnecessary required read/step, or unsupported mechanism and a
concrete smaller correction; “too verbose” alone is not a finding. Use existing review, not another
review agent, approval round, or required GitHub status check.

## Questions

Open a [skill issue](.github/ISSUE_TEMPLATE/bug_report.yml) or [skill proposal](.github/ISSUE_TEMPLATE/feature_request.yml).
