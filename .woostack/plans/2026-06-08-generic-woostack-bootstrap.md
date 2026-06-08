**Source:** .woostack/specs/2026-06-08-generic-woostack-bootstrap.md

# Dynamic, Requirements-Driven `woostack-bootstrap` Implementation Plan

**Goal:** Refactor the `woostack-bootstrap` skill and its references to remove hardcoded defaults, replacing them with a dynamic requirements-gathering and live-lookup stack-options presentation protocol.

**Architecture:** We will update `skills/woostack-bootstrap/SKILL.md` and all 5 reference markdown files in `skills/woostack-bootstrap/references/` in place. We will use grep searches to verify that hardcoded assumptions are removed and that new protocols (questionnaire, live lookup, dynamic slice architecture) are correctly documented.

**Tech Stack:** Markdown, git, Graphite (`gt`), grep.

---

## Increment 1: Skill Definition and Decisions Protocol

> This increment updates the main skill file and the decisions reference to remove the default stack and implement the dynamic lookup protocol.

### Task 1: Update main `woostack-bootstrap` skill definition

**Files:**
- Modify: `skills/woostack-bootstrap/SKILL.md`:1-83
- Test: Verify the file exists and contains the updated dynamic procedure.

- [x] **Step 1: Write the verification command**

Run: `grep -q "dynamic stack selection" skills/woostack-bootstrap/SKILL.md`
Expected: exit status 1 (since the term is not yet present)

- [x] **Step 2: Run the verification, confirm it fails**

Run: `grep -q "dynamic stack selection" skills/woostack-bootstrap/SKILL.md`
Expected: FAIL (exit status 1)

- [x] **Step 3: Minimal implementation**

Edit `skills/woostack-bootstrap/SKILL.md` to:
1. Update the description to reflect a generic, requirements-driven bootstrap.
2. Remove the hardcoded "Default stack" section.
3. Update the "Procedure" section to outline the dynamic stack selection and requirements questionnaire steps.

- [x] **Step 4: Run the verification, confirm it passes**

Run: `grep -q "dynamic stack selection" skills/woostack-bootstrap/SKILL.md`
Expected: PASS (exit status 0)

- [x] **Step 5: Commit**

```bash
gt create -m "docs: make woostack-bootstrap skill definition dynamic"
```

---

### Task 2: Update decisions reference guide

**Files:**
- Modify: `skills/woostack-bootstrap/references/decisions.md`:1-98
- Test: Verify the file exists and contains the dynamic requirements questions.

- [x] **Step 1: Write the verification command**

Run: `grep -q "Requirements gathering questionnaire" skills/woostack-bootstrap/references/decisions.md`
Expected: exit status 1

- [x] **Step 2: Run the verification, confirm it fails**

Run: `grep -q "Requirements gathering questionnaire" skills/woostack-bootstrap/references/decisions.md`
Expected: FAIL (exit status 1)

- [x] **Step 3: Minimal implementation**

Edit `skills/woostack-bootstrap/references/decisions.md` to:
1. Remove all hardcoded defaults (Supabase, Vercel, Stripe, Axiom, etc.).
2. Define the requirements-gathering questionnaire (scale, database, hosting, compliance, budget, integrations).
3. Outline the protocol for presenting 2-3 stack options with detailed pros/cons.

- [x] **Step 4: Run the verification, confirm it passes**

Run: `grep -q "Requirements gathering questionnaire" skills/woostack-bootstrap/references/decisions.md`
Expected: PASS (exit status 0)

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs: rewrite decisions reference to use dynamic questionnaire"
```

---

## Increment 2: Bootstrap Procedure and Architecture Slicing

> This increment updates the step-by-step bootstrap procedure and the package slice architecture conventions to accommodate arbitrary stacks.

### Task 1: Generalize bootstrap procedure

**Files:**
- Modify: `skills/woostack-bootstrap/references/bootstrap.md`:1-187
- Test: Verify the file contains instructions for custom CLI generation.

- [x] **Step 1: Write the verification command**

Run: `grep -q "CLI bootstrap commands for the chosen stack" skills/woostack-bootstrap/references/bootstrap.md`
Expected: exit status 1

- [x] **Step 2: Run the verification, confirm it fails**

Run: `grep -q "CLI bootstrap commands for the chosen stack" skills/woostack-bootstrap/references/bootstrap.md`
Expected: FAIL (exit status 1)

- [x] **Step 3: Minimal implementation**

Edit `skills/woostack-bootstrap/references/bootstrap.md` to:
1. Generalize inputs to include the chosen stack's specific services.
2. Outline how to run arbitrary CLIs (Next.js, FastAPI, etc.) and clean their boilerplates.
3. Detail how to initialize workspace files dynamically.

- [x] **Step 4: Run the verification, confirm it passes**

Run: `grep -q "CLI bootstrap commands for the chosen stack" skills/woostack-bootstrap/references/bootstrap.md`
Expected: PASS (exit status 0)

- [x] **Step 5: Commit**

```bash
gt create -m "docs: generalize bootstrap procedure for arbitrary CLIs"
```

---

### Task 2: Adapt monorepo slice architecture to arbitrary stacks

**Files:**
- Modify: `skills/woostack-bootstrap/references/architecture.md`:1-103
- Test: Verify the file details multi-language workspace boundaries.

- [x] **Step 1: Write the verification command**

Run: `grep -q "guidance for multi-language monorepos" skills/woostack-bootstrap/references/architecture.md`
Expected: exit status 1

- [x] **Step 2: Run the verification, confirm it fails**

Run: `grep -q "guidance for multi-language monorepos" skills/woostack-bootstrap/references/architecture.md`
Expected: FAIL (exit status 1)

- [x] **Step 3: Minimal implementation**

Edit `skills/woostack-bootstrap/references/architecture.md` to:
1. Adapt the package tiers to generalize how non-JS/TS services (Python, Rust, etc.) reside in the structure.
2. Explain how to manage dependencies natively (e.g. `cargo`, `uv`) and orchestrate build pipelines with Turborepo.
3. Generalize `@infrastructure/` wrapper packages to be database/auth provider agnostic.

- [x] **Step 4: Run the verification, confirm it passes**

Run: `grep -q "guidance for multi-language monorepos" skills/woostack-bootstrap/references/architecture.md`
Expected: PASS (exit status 0)

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs: update architecture reference for dynamic package slicing"
```

---

## Increment 3: Framework Resolution and Infrastructure Patterns

> This increment generalizes the framework versioning rules and provides stack-agnostic production-readiness patterns.

### Task 1: Update frameworks versioning reference

**Files:**
- Modify: `skills/woostack-bootstrap/references/frameworks.md`:1-119
- Test: Verify that the frameworks list is generalized and specific versions/gotchas are removed.

- [ ] **Step 1: Write the verification command**

Run: `grep -q "Registry-based version lookup" skills/woostack-bootstrap/references/frameworks.md`
Expected: exit status 1

- [ ] **Step 2: Run the verification, confirm it fails**

Run: `grep -q "Registry-based version lookup" skills/woostack-bootstrap/references/frameworks.md`
Expected: FAIL (exit status 1)

- [ ] **Step 3: Minimal implementation**

Edit `skills/woostack-bootstrap/references/frameworks.md` to:
1. Focus on the live lookup protocol using `npm view` or registry CLIs.
2. Remove the static package list and all framework-specific gotchas.
3. Provide general guidelines on peer dependencies and monorepo catalogs.

- [ ] **Step 4: Run the verification, confirm it passes**

Run: `grep -q "Registry-based version lookup" skills/woostack-bootstrap/references/frameworks.md`
Expected: PASS (exit status 0)

- [ ] **Step 5: Commit**

```bash
gt create -m "docs: update frameworks reference to remove static list and gotchas"
```

---

### Task 2: Update infrastructure and production-readiness reference

**Files:**
- Modify: `skills/woostack-bootstrap/references/infrastructure.md`:1-183
- Test: Verify the file contains generalized guidelines.

- [ ] **Step 1: Write the verification command**

Run: `grep -q "Stack-agnostic database migrations" skills/woostack-bootstrap/references/infrastructure.md`
Expected: exit status 1

- [ ] **Step 2: Run the verification, confirm it fails**

Run: `grep -q "Stack-agnostic database migrations" skills/woostack-bootstrap/references/infrastructure.md`
Expected: FAIL (exit status 1)

- [ ] **Step 3: Minimal implementation**

Edit `skills/woostack-bootstrap/references/infrastructure.md` to:
1. Provide general guidance on environment variable management and validation.
2. Formulate generalized CI/CD pipeline structures (GitHub Actions) for arbitrary build targets.
3. Detail how to wrap auth/observability/database libraries in `@infrastructure/` modules.
4. Remove the hardcoded Supabase, Vercel, Stripe, Axiom setup steps.

- [ ] **Step 4: Run the verification, confirm it passes**

Run: `grep -q "Stack-agnostic database migrations" skills/woostack-bootstrap/references/infrastructure.md`
Expected: PASS (exit status 0)

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "docs: generalize infrastructure and production readiness"
```

---

## Self-review (run before handing back)

- [x] **Spec coverage** — every spec requirement maps to a task above.
- [x] **AC coverage** — each spec §7 acceptance criterion (and its filled happy/error/edge cases) maps to a test.
- [x] **No placeholders** — no TBD/TODO; complete code, exact commands, and expected output in every step.
- [x] **Type consistency** — types, signatures, and names match across tasks.
