#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$HERE/.." && pwd)"

bash "$HERE/test-linear-execute-contract.sh"
bash "$SKILL_ROOT/scripts/tests/run-tests.sh"
