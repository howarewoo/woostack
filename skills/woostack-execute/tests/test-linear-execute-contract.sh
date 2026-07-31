#!/usr/bin/env bash
# Compatibility entrypoint for the artifact-optional execution contract.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$HERE/../scripts/tests/test-exact-issue-admission.sh"
