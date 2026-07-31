#!/usr/bin/env bash
# Compatibility entrypoint for the current repository-first overnight contract.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$HERE/../scripts/tests/test-sweep-integrity-contract.sh"
