# Verification and evidence

Use the bundled [testing guidance](tdd.md) to select
focused behavioral checks and broaden for changed integration boundaries. Preserve explicit
acceptance checks. This reference defines evidence for this skill, not a new universal test runner.

## Verify the target

Discover commands in the actual created or existing target manifest and documentation; a catalog
need not name its scripts `verify`, `build`, or `dev` — exercise its real check, build, and
inspection equivalents. The target-owned coverage record (per
[adaptation](adaptation.md#agree-the-coverage)) determines required coverage: check imports,
required specimens, provenance and distinct extensions against that record, then compile and
run the actual catalog. Check preservation boundaries with focused tests or before/after file
and dependency-state comparison where appropriate.

Before claiming recreation, observe the actual current-upstream sourcing of missing controls —
the Base UI-backed shadcn CLI, live registry item, or adapted current component documentation
example — or real compatible project imports for reused controls. Check that sourced items
retain their applicable upstream license/copyright notices (catalog notice entry or file
headers, per the coverage record); a missing notice is a failed source-ingestion check.
Embedded, mirrored, or test-only source is not recreation. Confirm no CLI overwrite or product
API migration. Creation
needs registry/CLI network access when controls are missing; report its absence as an
unverified prerequisite rather than filling missing imports with mocks. Runtime must remain
independent of that access, Woostack, Git Stacks and remote component documentation.

Use a real browser against the generated surface, not an HTML screenshot or a template-only fixture:

| Behavior | Observable evidence |
| --- | --- |
| Search | Matching component/group results; unmatched query yields a clear empty state; clearing restores navigation |
| Stable links | Direct component URL opens the correct specimen; selection updates the link; reload and Back/Forward restore selection |
| Narrow navigation | At a narrow viewport the navigation opens/closes, selecting an item exposes content, and focus does not remain in hidden navigation |
| Keyboard and focus | Controls have accessible names; keyboard navigation/shortcuts use documented keys, respect text editing and modifiers, and move focus to the intended content; visible focus and Escape behavior work |
| Appearance | Light/dark switch applies to chrome, tokens and specimens; project theme contract is respected |
| Representative overlays | Open and close dialog, popover/select/menu examples; confirm portals, focus transfer/return, dismissal and keyboard selection on real shared primitives |

Test additional material states required by the agreed coverage and affected target APIs, such
as disabled, invalid, loading, empty and controlled state. Do not infer overlay accessibility
from a successful build. If browser access or installation is unavailable, state that exact
missing prerequisite and leave the affected evidence unverified.

## Distribution and five scenario recipes

Exercise the candidate through a supported coding host in disposable repositories, never personal
repositories. Record the installed skill location, candidate revision, host/invocation, target fixture,
commands and observed outputs. Keep the installed assets outside the source checkout and make the
checkout unavailable to the recreation invocation; a manually authored catalog alone does not
prove distribution or skill execution.

1. **Distribution prerequisite:** install the candidate using supported skill tooling. Confirm
   that the installed `SKILL.md` and its reference set are available together and that every
   local link resolves. Resolve references relative to that installation, not the checkout. This
   skill ships no templates, component sources, or frozen inventory: an installed package
   carrying such assets is not this candidate. Asset availability and a correct package layout
   are deterministic evidence; model execution is separate evidence.
2. **New repository:** invoke the installed skill in a fresh disposable target with no catalog or
   design rules. Agreeing focused coverage with the requester is acceptable. Observe neutral
   styling, a runnable catalog covering the recorded agreement, project-owned source and
   recorded provenance. Run generated native verification/build commands, validate actual
   imports and specimens, and run the browser table above. Confirm no Woostack/Git Stacks
   runtime dependencies or automatic Git/GitHub mutations. A manually instantiated or authored
   copy can diagnose a failure but cannot count as the required installed-skill recreation
   outcome.
3. **Compatible existing UI:** supply real public components with meaningful API differences from
   upstream defaults (for example different button variants or overlay composition) and project
   tokens. Invoke creation through the installed skill. Observe actual project imports in both
   chrome and specimens, examples adapted to those APIs, no duplicate controls and no component
   API migration. Check original component source and dependency versions remain unchanged
   unless a specifically necessary authorized configuration edit was identified. Exercise the
   adapted interactions in the browser; provenance alone is not proof of compatibility.
4. **Incompatible/non-React product:** establish the existing product framework, manifest/runtime
   dependencies and representative behavior before invocation. Observe an independently runnable
   React catalog, separate dependency ownership and accurate catalog-only labels. Verify the
   product source, framework and runtime dependency graph remain unchanged and exercise the
   existing product's relevant native smoke, alongside the catalog commands/browser. Do not call
   a product rewrite isolation or treat an existing catalog as absent just because it uses
   another framework.
5. **Existing catalog:** start with customized examples/tokens and snapshot source, manifests,
   lockfiles and generated state. Ordinary installed-skill invocation must produce a useful
   coverage/drift/compatibility report against the target's recorded coverage and current
   upstream, and leave all that state unchanged. Do not install dependencies to improve the
   report. Identify runtime behavior as unverified when inspection cannot establish it.
6. **Explicit maintenance:** request one bounded addition or repair in a customized catalog. Prove
   the requested behavior changes while unrelated examples/tokens/dependency versions stay intact.
   Include an incompatible requested change; observe a specific conflict report with the owned
   surface unchanged, not silent replacement or hidden duplicate controls. Run focused checks and
   browser interactions for the changed surface, not unrequested regeneration.

Items 2–6 are the five behavior scenarios; distribution is their installation prerequisite.

## Verify changes to this skill distribution

From the Woostack repository root, run the required existing packaging suites:

```sh
node --test apps/docs/scripts/gen-skills.test.mjs
node --test apps/docs/scripts/skill-assets.test.mjs
```

`skill-assets.test.mjs` covers the installed design-system package's template-free layout and
resolving reference links. Select authored-site rendering/build checks under repository
validation policy when their boundaries are affected. Packaging/parser tests establish discovery
and asset inclusion, not that a model followed this skill. Focused deterministic tests should
exercise real integration contracts and preservation/compatibility helpers if present, rather
than exact instruction wording or test-only copies. Never run applications or install their
dependencies inside `skills/`.

## Report three evidence classes separately

- **Deterministic:** packaging/parser/helper checks and actual target commands, with observed result.
- **Installed skill/host:** real invocation outcomes for distribution and each behavior scenario;
  identify manual authoring separately, and leave unrun scenarios unverified.
- **Browser:** actual target URL/surface, tested interactions and observations, not inferred behavior.

Include preserved customizations, conflicts and unavailable prerequisites. Failed, blocked or unrun
checks are not passes. Site tests alone do not prove recreation; a build alone does not prove
reuse or read-only behavior. Stop after the authorized local outcome, without publication.
