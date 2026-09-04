# Development Patterns

Projects own their technology choices. Bootstrap researches current named options, obtains explicit
approval, and records the selected stack; these patterns preserve engineering outcomes without
selecting a framework, language, package manager, test runner, database, or vendor.

## 1. Repository-owned technology choices

- Follow the approved stack and the repository's native conventions.
- Do not introduce or substitute a technology the user has not approved.
- Record material choices and live-resolved dependency versions in the project README.

## 2. App-local code and shared extraction

New components, layouts, services, schemas, contracts, utilities, and vendor integrations live in
the application that owns them.

- Follow the application's native module and export conventions.
- When multiple applications need the same implementation or contract, extract the smallest
  coherent surface to the repository's shared-code location.
- After extraction, remove application-local duplicates and have each consumer use the shared
  implementation.

## 3. Application-boundary adapters

When data crosses between applications, use explicit adapters at the receiving and sending boundaries so transport, client, and vendor formats never leak into application or domain logic.

- **Scope:** Applies in both directions across HTTP/RPC server-client, service-service, webhooks, queues/events, and third-party APIs. Excludes database persistence mapping and ordinary in-process module calls.
- **Responsibilities:** Adapters validate or narrow untrusted wire input; map wire or vendor representations to application/domain models and map domain models back to wire shapes; and translate transport-specific errors so business logic remains independent of transport, client, and vendor details.
- **Form:** Functions or modules satisfy the pattern; classes are not required.
- **Placement:** Keep adapters in the application that owns the boundary, optionally in an application-local adapter location. Extract to the repository's shared-code location only when multiple applications consume the exact same contract or implementation, then remove application-local duplicates.
- **Compatibility and safety:** Preserve existing wire and API contracts unless an approved change explicitly versions or breaks them. Preserve input validation, error handling, security, accessibility, and data-loss protections.
- **Touched-flow policy:** Apply to new boundary flows and existing flows materially changed by a task. Do not migrate untouched legacy boundary flows.
- **Identity-shape exception:** When a deliberately shared contract is already the application/domain shape, do not add an identity-only or no-op wrapper. Boundary validation and transport/error handling still apply, but a separate adapter module is required only where translation or transport/vendor isolation performs real work.
- **Review criteria:** Architecture review blocks concrete changed-code transport/client/vendor leaks or missing required boundary validation and error translation. Review does not block folder/file naming, class-vs-function style, or the omission of identity/no-op wrappers.

## 4. Test-Driven Development

Red → Green → Refactor, test-first. The canonical TDD kernel — the workflow, coverage classes, and
repository-runner rule — lives once in [woostack-tdd](../../woostack-tdd/SKILL.md); follow it.
Use the repository's approved test runner, layout, and naming conventions. A change is incomplete
until its required verification passes.

## 5. API stability

Preserve published API compatibility within the repository's supported compatibility window.

- Existing route or operation identifiers remain stable.
- Inputs may gain optional fields; do not remove or rename existing fields.
- Outputs may gain fields; do not remove existing fields or change their meaning or type.
- Existing error codes retain their meaning; add distinct codes for new conditions.
- An approved breaking change requires the repository's documented versioning mechanism.

## 6. Type safety

- Use the approved stack's strongest practical static and runtime type-safety mechanisms.
- Validate or narrow untrusted values at trust boundaries before application code consumes them.
- Derive related contract types from one source of truth when the selected technology supports it.
- Do not bypass type checks without a narrow, documented reason.
- Keep type and contract helpers application-local; extract only when multiple applications need
  the same definition.

## 7. Least code & comments

Write as little code as necessary — but never at the cost of correctness or safety. Understand the
problem first, then take the first rung that holds.

- **The ladder.** Before adding code, walk the rungs and stop at the first that works: (1) YAGNI —
  is it needed at all? (2) in-tree reuse — a helper/util/pattern that already exists here; (3)
  standard facilities; (4) a native platform feature; (5) an already-installed dependency; (6)
  one line; (7) only then the minimum new code that works. The review
  [`simplify` angle](../../woostack-review/prompts/angles/simplify.md) enforces this ladder.
- **Read first (delta A).** The ladder runs *after* you understand the problem: read the code the
  change touches and trace the real flow end to end before picking a rung. Lazy about the
  solution, never about reading — the smallest change in the wrong place is a second bug.
- **Equal-size tie-breaker (delta B).** When two approaches are the same size, pick the
  edge-case-correct one. Lazy means less code, not the flimsier algorithm.
- **Never-cut list (delta C).** Never shrink code by dropping validation, error handling,
  security, accessibility, or data-loss handling. Keep deliberate multi-layer safety redundancy
  (it is not DRY-removable); prefer scoped parsing over a greedy regex; a behavior-changing
  simplification keeps its regression test.
- **Boring over clever (delta D).** Deletion over addition; boring over clever. Code is small
  because it's necessary, not because it's golfed.
- **Deliberate-corner marker (delta E).** A knowingly-cut corner with a known ceiling leaves a
  `why` comment naming the ceiling and the upgrade path. If broadly reusable, surface it as a
  session-end instruction suggestion.
- Non-test source files: ≤ 500 lines.
- User-facing components and procedures: document purpose, inputs, and outputs using the
  repository's native documentation convention.
- Comments explain **why** when non-obvious (hidden constraint, workaround, surprising invariant).
  Skip the **what** — code names that.
- Replace unexplained repeated or policy-bearing literals with descriptively named constants using
  the repository's naming convention.

## 8. Dependency ownership

- Each application declares the dependencies and versions its runtime needs in its own manifest.
- Shared code declares its own runtime, peer, and development dependencies when those categories
  exist in the selected ecosystem.
- Keep only genuine repository-wide tooling at the root.
