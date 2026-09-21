#!/bin/bash
# Dry-runs the one-time import on a backup file (default: the newest migration file
# in private/) and says whether every row came across. Nothing is stored.
set -e
cd "$(dirname "$0")/.."
FILE="${1:-$(ls -t private/migration-*.json | head -1)}"
cd Core
SCRATCH="${TMPDIR:-/tmp}/AMSPacking-core-$(pwd | shasum | cut -c1-8)"
swift run --scratch-path "$SCRATCH" import-check "../$FILE" 2>&1 | grep -v "^\[\|^Building\|^Build \|^Compiling\|^Linking\|warning: unre"
exit "${PIPESTATUS[0]}"
