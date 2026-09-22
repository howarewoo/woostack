#!/usr/bin/env bash
# Behavioral helper tests.  The suite creates temporary Git repositories and
# invokes the shipped Python CLI through recording_driver.py; no network or
# project-wide test command is involved.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONPATH="$HERE${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONDONTWRITEBYTECODE=1
exec python3 -m unittest discover -s "$HERE" -p 'test_*.py' -v
