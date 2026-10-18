# Implementation patterns

These patterns define engineering outcomes, not frameworks, languages, package managers, test
runners, databases, or vendors. They apply to new and existing projects alike: repository
instructions, existing architecture, native conventions, the selected dependency set, and
lockfiles stay authoritative, and nothing here imposes a layout, an abstraction, or a version
change the task did not require. Load this reference when the work establishes placement,
boundaries, contracts, types, or dependencies. Testing remains canonical in
[tdd.md](tdd.md).

## 1. Repository-owned technology choices

- Follow the repository's own instructions, structure, and naming. In a new repository, use the
  selected ecosystem's native structure instead of imposing a second layout.
- Do not introduce or substitute a technology the user has not selected.
- Create only the directories, modules, and surfaces the requested product needs.

## 2. Native placement and shared code

Application code starts in the deployable unit that owns it. Business logic, data access,
authentication, observability, UI, utilities, and vendor integrations stay with that unit.

- Follow the unit's native module, export, and manifest conventions.
- When several units need the same implementation or contract, extract the smallest coherent
  surface — named and placed for the capability it owns — to the repository's shared-code
  location, then remove application-local duplicates.
- Create no empty shared locations, placeholder packages, or wrapper manifests.
- In a mixed-technology repository, each unit keeps its native structure and manifest. Add root
  orchestration only when it simplifies real cross-application commands, and use a
  technology-neutral contract representation when unlike applications share a boundary contract.

## 3. Application-boundary adapters

When data crosses between applications, use explicit adapters at the sending and receiving
boundaries so transport, client, and vendor formats never leak into application or domain logic.

- **Scope:** Applies in both directions across HTTP/RPC server-client, service-service, webhooks,
  queues/events, and third-party APIs. Excludes database persistence mapping and ordinary
  in-process module calls.
- **Responsibilities:** Adapters validate or narrow untrusted wire input; map wire or vendor
  representations to application/domain models and map domain models back to wire shapes; and
  translate transport-specific errors so business logic remains independent of transport,
  client, and vendor details.
- **Form:** Functions or modules satisfy the pattern; classes are not required.
- **Placement:** Keep adapters in the unit that owns the boundary, optionally in an
  application-local adapter location. Extract to shared code only when multiple applications
  consume the exact same contract or implementation, then remove application-local duplicates;
  see [Native placement and shared code](#2-native-placement-and-shared-code).
- **Compatibility and safety:** Preserve existing wire and API contracts unless an approved change
  explicitly versions or breaks them. Preserve input validation, error handling, security,
  accessibility, and data-loss protections.
- **Touched-flow policy:** Apply to new boundary flows and existing flows materially changed by
  the task. Do not migrate untouched legacy boundary flows.
- **Identity-shape exception:** When a deliberately shared contract is already the
  application/domain shape, do not add an identity-only or no-op wrapper. Boundary validation
  and transport/error handling still apply, but a separate adapter module is required only where
  translation or transport/vendor isolation performs real work.
- **Review criteria:** Architecture review blocks concrete changed-code transport/client/vendor
  leaks and missing required boundary validation or error translation. Review does not block
  folder/file naming, class-vs-function style, or the omission of identity/no-op wrappers.

## 4. API compatibility

Preserve published API compatibility within the repository's supported compatibility window.

- Existing route or operation identifiers remain stable.
- Inputs may gain optional fields; do not remove or rename existing fields.
- Outputs may gain fields; do not remove existing fields or change their meaning or type.
- Existing error codes retain their meaning; add distinct codes for new conditions.
- An approved breaking change uses the repository's documented versioning mechanism.

## 5. Type safety

- Use the selected stack's strongest practical static and runtime type-safety mechanisms.
- Validate or narrow untrusted values at trust boundaries before application code consumes them.
- Derive related contract types from one source of truth when the selected technology supports
  it.
- Do not bypass type checks without a narrow, documented reason.
- Keep type and contract helpers with the unit that owns them; extract only when several units
  need the same definition.

## 6. Dependencies: resolution, ownership, and integrity

- Resolve a version from the authoritative current source only when selecting or changing a
  dependency, never from memory — for example `npm view <pkg> version`, plus
  `npm view <pkg> dist-tags` when a prerelease channel is explicitly required, or the equivalent
  metadata lookup in the selected ecosystem. Prefer stable releases unless the selection requires
  a prerelease.
- Preserve existing versions and lockfiles when the task needs no dependency change. Resolving
  current versions is not a mandate to upgrade.
- Each application declares the dependencies its runtime needs in its own manifest.
- Shared code declares its own runtime, peer, and development dependencies where the ecosystem
  distinguishes those categories.
- Keep only genuine repository-wide tooling at the root.
- When the selected package manager restricts lifecycle scripts, enable only the dependencies
  whose required native installation has been verified.
- Resolve peer or compatibility warnings within the consuming application or shared unit.
- Verify that intentionally shared local code resolves from the repository rather than an
  external registry, and that every selected dependency supports its target runtime and
  deployment environment.
- Preserve the lockfile and integrity metadata produced by the selected package manager.

## 7. Least code & comments

Write as little code as necessary — but never at the cost of correctness or safety. Understand the
problem first, then take the first rung that holds.

- **The ladder.** Before adding code, walk the rungs and stop at the first that works: (1) YAGNI —
  is it needed at all? (2) in-tree reuse — a helper/util/pattern that already exists here; (3)
  standard facilities; (4) a native platform feature; (5) an already-installed dependency; (6)
  one line; (7) only then the minimum new code that works. This standard governs new and existing
  code alike.
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
- User-facing components and procedures: document purpose, inputs, and outputs using the
  repository's native documentation convention.
- Comments explain **why** when non-obvious (hidden constraint, workaround, surprising invariant).
  Skip the **what** — code names that.
- Replace unexplained repeated or policy-bearing literals with descriptively named constants using
  the repository's naming convention.