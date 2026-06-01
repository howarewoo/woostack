# Addressing review threads (the `address` verb)

You are addressing the unresolved review threads on a pull request. The threads
are in `/tmp/pr-review/address-threads.json` (written by `fetch-threads.sh`),
each: `{ threadId, file, line, diffHunk, comments: [ { author, body } ] }`. The
team's accepted-design memory is in `/tmp/pr-review/memory.md` (may be absent).

By **default** you run an interactive walk-through: analyze every thread, then
present a single batched table of *recommended* verdicts for the user to approve
or override before anything is applied. If the run was invoked with `--auto`,
skip the gate and act on your recommendations directly (the pre-walk-through
autonomous flow).

## Phase 1 — Analysis loop (no side effects)

For **every** thread, decide a recommended verdict. Make **no** working-tree
edits, **no** replies, **no** resolves, and **no** memory writes in this phase.

1. **READ** the whole thread — the original finding and every reply.
2. **UNDERSTAND** — restate the ask in one sentence.
3. **VERIFY** against the actual codebase — open `file` near `line`; confirm the
   concern is real and still present.
4. **EVALUATE** for this stack/context, then recommend ONE:
   - **FIX** — the suggestion is correct and improves the code.
   - **ACCEPT** — push back: the behavior is intentional / accepted-by-design
     (it breaks working behavior, violates YAGNI, conflicts with an
     architectural decision, or the reviewer lacks context).
   - **CLARIFY** — genuinely ambiguous; you cannot verify intent on your own.
5. Stage a record per thread:
   `{ threadId, file, line, finding, recommended, reasoning, learning }`
   — `finding` is the one-line restatement, `reasoning` is why you recommend
   that verdict, `learning` is the reusable memory pattern to write **if** the
   final verdict is ACCEPT (else leave empty).
6. **Never** use performative language ("You're absolutely right!", "Great
   point!"). Reasoning and replies are technical only.

## Phase 2 — Verdict gate

**If `--auto` was set:** skip this phase. The final verdict for each thread is
your recommendation. Go to Phase 3.

**Otherwise (default):** present all staged threads as ONE batched table —
columns: thread, finding, recommended verdict, reasoning. Then ask the user to
either **approve all** recommendations or **override** specific threads to a
different verdict (any of FIX / ACCEPT / CLARIFY).

- Host mechanics: a host with a structured question primitive (e.g. Claude
  Code's `AskUserQuestion`) offers an "approve all" choice plus per-thread
  overrides; a plain host prints the numbered table and asks for "approve all,
  or list `thread#=verdict` overrides".
- The **final verdict** per thread = the user's override where given, else your
  recommendation. Only Phase 3 acts, and only on final verdicts.
- **Non-interactive host, no `--auto`:** if you cannot obtain confirmation,
  **abort** without acting — tell the user: "interactive verdict review needs a
  user; re-run with `--auto` to address autonomously." Never act unapproved.

## Phase 3 — Act on final verdicts

- **FIX**: edit the working tree. Accumulate all fixes; do NOT commit per thread.
- **ACCEPT**: this is the issue-#53 step. First check `/tmp/pr-review/memory.md`
  (and the live `.woo-stack/memory.md`): if an existing entry already covers
  this learning — even phrased differently or more broadly — do NOT add a
  duplicate; widen the existing entry instead. Only when the learning is
  genuinely new, record it as a **pattern, not an instance**:

  ```bash
  LEARNING="<general pattern>: <why it is accepted / what not to re-flag>" \
    bash "$WOO_REVIEW_ACTION_PATH/scripts/memory-append.sh"
  ```

  Only a final ACCEPT (accept-by-design) writes memory. A "won't-fix because
  transient / out-of-scope" is not a reusable rule — do not record it.
- **CLARIFY**: do not fix, do not write memory, do not resolve. Reply with a
  specific question (handled below with `RESOLVE=0`).

## After the loop

1. If any FIX edits were made, make ONE descriptive commit referencing the
   threads addressed, then push to the PR head branch. Capture the new `<sha>`.
   Never force-push.
2. For each handled thread, reply and resolve:

   ```bash
   # FIXED thread:
   THREAD_ID="<id>" REPLY_BODY="Fixed in <sha>." \
     bash "$WOO_REVIEW_ACTION_PATH/scripts/resolve-thread.sh"
   # ACCEPTED thread:
   THREAD_ID="<id>" REPLY_BODY="<technical reasoning for accepting as-is>" \
     bash "$WOO_REVIEW_ACTION_PATH/scripts/resolve-thread.sh"
   # CLARIFY thread (reply only, leave open):
   THREAD_ID="<id>" REPLY_BODY="<your specific question>" RESOLVE=0 \
     bash "$WOO_REVIEW_ACTION_PATH/scripts/resolve-thread.sh"
   ```

3. Print a summary table: thread → recommended → final → action → memory-written?

## Guardrails

- A thread that errors (cannot verify, fix fails) is marked `errored` in the
  report and left open — never abort the whole run for one thread.
- If the push is rejected (remote ahead), stop: do NOT post "Fixed in <sha>"
  replies (the sha is not on the remote). Report which fixes are unpushed.
