#!/bin/bash
# Runs the model's own tests (the Core package) — no simulator, a few seconds.
# The build folder is kept OUTSIDE ~/Documents: codesign refuses the extended
# attributes that folder collects, and the test bundle has to be signed.
set -e
cd "$(dirname "$0")/../Core"
# One build folder per checkout, so two copies of the repo (git worktrees) can be
# tested at the same time without fighting over it.
SCRATCH="${TMPDIR:-/tmp}/AMSPacking-core-$(pwd | shasum | cut -c1-8)"
swift test --scratch-path "$SCRATCH" "$@"
