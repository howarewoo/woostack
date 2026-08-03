#!/usr/bin/env bash
# Structural entrypoint for the exact-resource sequential execution contract.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$HERE/../scripts/tests/test-exact-issue-admission.sh"
