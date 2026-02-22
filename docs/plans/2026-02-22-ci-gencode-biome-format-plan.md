# Fix CI gencode biome formatting mismatch — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the CI failure where `pnpm gencode` output doesn't match the biome-formatted committed `router-types.d.ts`.

**Architecture:** Add `pnpx biome check --write` after `pnpm gencode` in CI so the generated file is normalized to biome's format before the `git diff` check. Regenerate the file locally so the committed version matches.

**Tech Stack:** GitHub Actions CI, Biome 2.4.4, pnpm gencode script

---

### Task 1: Update CI workflow to format after gencode

**Files:**
- Modify: `.github/workflows/ci.yml:42-47`

**Step 1: Edit the CI workflow**

In `.github/workflows/ci.yml`, change the "Verify generated code is up to date" step from:

```yaml
      - name: Verify generated code is up to date
        run: |
          pnpm gencode
          git diff --exit-code packages/infrastructure/api-client/src/generated/ || {
            echo "::error::Generated router types are out of date. Run 'pnpm gencode' and commit the result."
            exit 1
          }
```

To:

```yaml
      - name: Verify generated code is up to date
        run: |
          pnpm gencode
          pnpx biome check --write packages/infrastructure/api-client/src/generated/
          git diff --exit-code packages/infrastructure/api-client/src/generated/ || {
            echo "::error::Generated router types are out of date. Run 'pnpm gencode' and commit the result."
            exit 1
          }
```

**Step 2: Verify the edit is correct**

Read the file and confirm the new line is between `pnpm gencode` and `git diff --exit-code`.

---

### Task 2: Regenerate router-types.d.ts with biome formatting

**Files:**
- Modify: `packages/infrastructure/api-client/src/generated/router-types.d.ts`

**Step 1: Regenerate the file**

Run: `pnpm gencode`

**Step 2: Format with biome**

Run: `pnpx biome check --write packages/infrastructure/api-client/src/generated/`

**Step 3: Verify the file changed**

Run: `git diff packages/infrastructure/api-client/src/generated/router-types.d.ts`
Expected: Shows formatting changes (whitespace only, no semantic difference).

---

### Task 3: Commit the changes

**Step 1: Stage the files**

```bash
git add .github/workflows/ci.yml packages/infrastructure/api-client/src/generated/router-types.d.ts
```

**Step 2: Commit**

```bash
gt modify -m "fix(ci): add biome format after gencode in CI verification step"
```

Or if a new commit is preferred:

```bash
gt create -m "fix(ci): add biome format after gencode in CI verification step"
```

**Step 3: Push**

```bash
gt submit
```
