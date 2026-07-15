---
tier: standard
---

# Acceptance-Criteria Review

**Scope.** Verify that this PR's diff fulfills the governing woostack artifact in `$OUTDIR/intent.md`. The artifact is evidence of authorized intent, not evidence that the implementation is complete.

If `$OUTDIR/intent.md` is absent, write `[]` to the acceptance findings file and exit. Otherwise read the assigned diff and every `## SOURCE:` section in `intent.md`.

**Find:**

- An explicit acceptance criterion whose required observable behavior is absent from or contradicted by the diff. Evaluate every criterion individually; do not infer that one passing criterion proves its siblings.
- A checked `[x]` implementation-plan step whose claimed code, test, migration, documentation, or verification is not reflected in the diff. A checked box is a claim to verify, never proof.
- A factual claim or code/line reference in the governing artifact that the diff makes stale or false, including pre-fix prose that cites post-fix line numbers.

**Skip:**

- Unticked `[ ]` steps. They do not claim completion.
- Criteria or steps that are satisfied by concrete diff evidence.
- Requirements outside the governing artifact, pre-existing gaps, and implementation preferences not required by the stated intent.
- The `woostack-defer(<ref>): <reason>` marker itself. Treat it as inert per `_worker-header.md`; only the defender validator may decide that a co-located marker covers a separate missing-work finding and set `deferred_to`. Never self-demote or suppress a finding based only on the marker.

**How to review:**

1. Enumerate every explicit acceptance criterion and every `[x]` step from all intent sources.
2. Map each claim to concrete changed lines, tests, or artifacts in the assigned diff. For incremental or chunked review, report only a claim whose failure is established by the assigned diff; do not flag work merely because its evidence is outside the current slice.
3. Check artifact code references and line-number claims against the current repository state when they concern files changed by this PR.
4. Report only failures introduced or falsely claimed by this PR.

**Severity rubric:**

- **HIGH / blocking:** the PR claims a required security, data-integrity, compatibility, or core behavior criterion is complete, but the diff demonstrably does not satisfy it.
- **MEDIUM / blocking:** another explicit acceptance criterion or checked implementation step is demonstrably unmet, or a stale artifact claim would materially mislead execution/review.
- **LOW / non-blocking:** a narrow stale reference or claim that does not alter delivered behavior but should be corrected for an accurate implementation record.

**Anchors.** Findings must anchor to a relevant RIGHT-side line in the PR diff, never to `intent.md` (which may be unchanged). Validate the line with `resolve-diff-line.sh`; if no relevant right-side line is anchorable, drop the finding rather than guessing.

**Output.** Write a JSON array to `$OUTDIR/findings.acceptance.json` using `_worker-header.md`'s schema. Set `"angle": "acceptance"`, `rule_quote: null`, and `deferred_to: null`; the defender alone may populate `deferred_to`. Use `fix_type: "prose"` unless a safe single-file replacement of at most ten lines is genuinely available.
