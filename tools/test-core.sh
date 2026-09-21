#!/bin/bash
# Runs the model's own tests (the Core package) — no simulator, a few seconds.
# The build folder is kept OUTSIDE ~/Documents: codesign refuses the extended
# attributes that folder collects, and the test bundle has to be signed.
set -e
cd "$(dirname "$0")/../Core"
swift test --scratch-path "${TMPDIR:-/tmp}/AMSPacking-core" "$@"
