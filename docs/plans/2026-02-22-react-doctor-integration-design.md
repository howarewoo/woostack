# React Doctor Integration Design

**Date**: 2026-02-22
**Status**: Approved

## Overview

Integrate [react-doctor](https://github.com/millionco/react-doctor) into the pr-review skill as a pre-check gate and into the CI pipeline as a parallel GitHub Action. Remove overlapping React-specific rules from the Code Quality Auditor to avoid duplication.

## Context

The pr-review skill's Code Quality Auditor has 7 hand-written React checks (Missing Keys, Inline Object/Function Props, State Management Issues, Effect Dependencies, Missing Memoization, Unnecessary Re-renders, God Components). react-doctor provides 63+ rules covering React state/effects, performance, architecture, bundle size, security, correctness, Next.js (16 rules), server, client, JS performance, and React Native (8 rules), plus a 0-100 health score.

## Design

### 1. PR-Review Workflow: New Task 2.5 (React Doctor Pre-Check)

Runs between Task 2 (Post Starting Comment) and Task 3 (Prepare Shared Context).

**Step 2.5.1**: Run react-doctor against changed files:
```bash
npx -y react-doctor@latest . --verbose --diff <base_branch>
```

**Step 2.5.2**: Parse output — extract score (0-100) and diagnostics (file, rule, severity, message, line, column).

**Step 2.5.3**: Convert diagnostics to `---AUDIT_FINDINGS---` format:
- Map severity: `"error"` → HIGH, `"warning"` → MEDIUM
- Set Type: `react-doctor`
- Set Blocking: `true` for errors, `false` for warnings
- Store converted findings for merging in Task 6

**Step 2.5.4**: Log score:
- Display: `"React Doctor Score: XX/100 (threshold: 90)"`
- If score >= 90: `"React health check passed"`
- If score < 90: `"React health check: X issues found, continuing with full review"`

**Always continues to Task 3** regardless of score. Findings get merged into the aggregated review.

### 2. Task 6 Aggregation Update

Add a new category **"React Health"** in aggregation, sourced from react-doctor findings stored in Task 2.5. The review comment template gains a new section:
- `react-doctor` type → React Health section
- Positioned after Code Quality and before Constitution Violations in the review output

### 3. Loop Mode Integration

Task 2.5 re-runs each iteration (just like Tasks 3-6). The iteration wrapper becomes:

```
For each iteration (1 through max_iterations):
  1. Execute Task 2.5 (React Doctor Pre-Check) — re-scan changed files
  2. Execute Task 3 (Prepare Shared Context)
  3. Execute Task 4 (Launch 5 Parallel Auditors)
  4. Execute Task 5 (Collect Agent Results)
  5. Execute Task 6 (Aggregate & Generate Review) — merges react-doctor findings
  6. Count findings (including react-doctor blocking findings)
  ... exit conditions unchanged ...
```

Task 9 (Fix All Findings) receives react-doctor blocking findings alongside other auditor findings. After fixes, the next iteration re-runs react-doctor to verify improvement.

`blocking_count` includes react-doctor errors — the loop won't approve until react-doctor errors are resolved.

### 4. Code Quality Auditor Changes

**Remove React-Specific Issues section** (4 items):
- Missing Keys
- Inline Object/Function Props
- State Management Issues
- Effect Dependencies

**Remove overlapping Performance Concerns** (3 items):
- Missing Memoization
- Unnecessary Re-renders
- Missing Code Splitting

**Keep everything else**: complexity, code smells, error handling, TypeScript quality, N+1 queries, testing gaps, Large Bundle Imports (partially — react-doctor covers barrel imports and specific libraries but not general "importing entire libraries").

### 5. CI Pipeline: New react-doctor Job

Add a parallel job to `.github/workflows/ci.yml`:

```yaml
react-doctor:
  name: React Doctor
  runs-on: ubuntu-latest
  concurrency:
    group: react-doctor-${{ github.event.pull_request.number }}
    cancel-in-progress: true
  steps:
    - uses: actions/checkout@v6
      with:
        fetch-depth: 0
    - uses: millionco/react-doctor@main
      with:
        diff: main
        verbose: "true"
        github-token: ${{ secrets.GITHUB_TOKEN }}
        fail-on: "error"
```

Runs independently from the `tests` job. Posts its own PR comment (updates via `<!-- react-doctor -->` marker). CI fails on errors, allows warnings.

### 6. react-doctor Configuration

New file at repo root: `react-doctor.config.json`

```json
{
  "ignore": {
    "rules": [],
    "files": [
      "packages/infrastructure/api-client/src/generated/**",
      "packages/infrastructure/supabase/src/generated/**"
    ]
  },
  "lint": true,
  "deadCode": false,
  "verbose": true,
  "diff": "main"
}
```

- `deadCode: false` — Knip is noisy in monorepos with workspace cross-references
- Ignore generated files (router types, Supabase DB types)
- All 63+ rules enabled; add ignores later if specific rules prove too noisy

### 7. Document Updates

**No changes** to `eng-constitution.md` or `.claude/CLAUDE.md` — they contain architectural patterns (server components, React Compiler, cross-platform UI) that are complementary to react-doctor, not conflicting.

**Files that change:**
1. `.claude/skills/pr-review/SKILL.md` — mention react-doctor pre-check in capabilities
2. `.claude/skills/pr-review/WORKFLOW.md` — add Task 2.5, update loop mode iteration wrapper
3. `.claude/skills/pr-review/ANALYSIS_GUIDE.md` — add "React Health" category, update aggregation rules and markdown template
4. `.claude/skills/pr-review/agents/code-quality-auditor.md` — remove React-specific section and overlapping performance items
5. `.github/workflows/ci.yml` — add react-doctor job
6. `react-doctor.config.json` (new) — repo root config
