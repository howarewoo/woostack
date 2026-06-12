#!/usr/bin/env bash
# resolve-marker.sh — single authority for the woostack-review incremental
# SHA-watermark trust gate. Reads `gh pr view --json reviews` JSON on stdin and
# prints the trusted `<!-- woostack-review:sha=<oid> -->` watermark from the most
# recent prior review body, or empty when none is trusted.
#
# Usage:
#   printf '%s' "$REVIEWS_JSON" | resolve-marker.sh <bot-pattern> <me> <local>
#     $1 bot-pattern : regex alternation of trusted bot login prefixes
#                      (e.g. "claude|openai|gemini|opencode"), start-anchored.
#     $2 me          : authenticated gh login (lowercased) of the user running
#                      this review; '' disables self-trust.
#     $3 local       : "1" when NOT running in GitHub Actions, else "0".
#   stdout: the trusted SHA, or empty.
#
# Trust rule — a marker is honored iff its review author is:
#   - a woostack-review bot (login starts with the bot pattern), OR
#   - (local run only) the authenticated gh user running this review (login==me).
# The self-trust clause is gated on a local run ($local=="1"). In CI any PR
# collaborator could otherwise post a review with a forged sha= marker pointing
# PAST their own malicious commits, narrowing the next incremental window to skip
# them. Locally the user reviews as themselves with their own token, so trusting
# a marker authored as themselves introduces no new forger. A different local
# reviewer (me mismatch) or any CI third-party still falls back to a full review.
#
# The read side accepts the legacy `woo-stack-review:sha=` watermark too
# (woo-?stack), so a PR last reviewed before the woostack rename still resolves
# incrementally; writes use the new brand. Hand-edited / malformed / absent
# markers yield empty → silent fallback to the full diff.
set -euo pipefail

BOTS="${1:?bot pattern required}"
ME="${2:-}"
LOCAL="${3:-0}"

jq -r --arg bots "$BOTS" --arg me "$ME" --arg local "$LOCAL" '
  [ .reviews[]?
    | { body: (.body // ""),
        submittedAt: (.submittedAt // ""),
        login: (.author.login // "") }
    | select((.login | test("^(" + $bots + ")"; "i"))
             or ($local == "1" and $me != "" and (.login | ascii_downcase) == $me))
    | select(.body | test("<!-- woo-?stack-review:sha=[a-f0-9]+ -->"))
  ]
  | sort_by(.submittedAt)
  | last
  | if . == null then empty
    else (.body | capture("<!-- woo-?stack-review:sha=(?<sha>[a-f0-9]+) -->") | .sha)
    end
' 2>/dev/null || true
