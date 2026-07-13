#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# The default suite proves credential-free static behavior; mocked live tests opt in locally.
unset LINEAR_API_KEY WOOSTACK_DOCTOR_LIVE WOOSTACK_DOCTOR_LIVE_CONTEXT WOOSTACK_LINEAR_ADAPTER WOOSTACK_BACKEND_RESOLVER
rc=0
for t in test-*.sh; do
  [ -e "$t" ] || continue
  echo "== $t =="
  if bash "$t"; then :; else rc=1; fi
done
exit "$rc"
