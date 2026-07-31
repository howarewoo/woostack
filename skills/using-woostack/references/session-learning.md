# Session learning

Woostack converts durable session lessons into suggestions for instruction files, not persistent
knowledge stores. Treat every final user-facing reply as a session boundary.

## Analyze before the final reply

Review the completed conversation, tool evidence, user corrections, failed assumptions, and repeated
friction. Suggest a change only when the session produced a novel, reusable rule that would have
prevented a concrete mistake or made future work materially clearer. Do not suggest task facts,
transient state, preferences already present in loaded instructions, or advice too vague to enforce.

Compare each candidate with the instruction files already loaded for the session. Drop duplicates,
weaker restatements, conflicts, and lessons already encoded by a skill or canonical reference.
A successful session may produce no suggestion.

## Choose the scope

Use the narrowest applicable `AGENTS.md` scope.

1. The nearest directory-scoped `AGENTS.md` governing the affected files for a subsystem rule.
2. The repository-root `AGENTS.md` for a repository-wide invariant or workflow rule.
3. Use the global instruction file only for a cross-repository or harness-wide rule.

Name the intended scope as a concrete repository-relative path when possible. For a global
suggestion, name the host's loaded global instruction file; if the host exposes no path, say
`global AGENTS.md equivalent` rather than inventing one.

## Emit suggestions, not artifacts

When at least one candidate survives, append a compact `AGENTS.md suggestions` section to the
final reply:

```text
AGENTS.md suggestions
- Scope: <path or global AGENTS.md equivalent>
  Rule: <concise imperative rule>
  Evidence: <session fact that justifies the rule>
```

Keep each rule self-contained, durable, and ready to paste. Evidence explains why the suggestion
exists but is not part of the proposed rule. Omit the entire section when no candidate survives.
Never write an instruction file or a suggestion artifact automatically. Apply a suggestion only in
a later explicit user-requested change.
