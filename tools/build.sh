#!/bin/bash
# Builds AMS Packing.   tools/build.sh [build|test] [iphone|mac]
#
# Two traps this script exists for (both met first on AMS Coffee):
#  1. Anything under ~/Documents picks up macOS extended attributes, and
#     codesign refuses them ("resource fork ... detritus not allowed").
#     So: clear them first — but never inside .git, whose objects are
#     read-only and would fail the sweep.
#  2. Derived data must land OUTSIDE ~/Documents for the same reason.
set -e
cd "$(dirname "$0")/.."
DD="${TMPDIR:-/tmp}/AMSPacking-build"

find . -path ./.git -prune -o -print0 | xargs -0 xattr -c 2>/dev/null || true
xcodegen generate

if [ "${2:-iphone}" = "mac" ]; then
  DEST='platform=macOS'
  OUT="$DD/Build/Products/Debug/AMSPacking.app"
else
  DEST='platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
  OUT="$DD/Build/Products/Debug-iphonesimulator/AMSPacking.app"
fi

# After a RED test xcodebuild otherwise sits "collecting diagnostics" for ten
# minutes and looks hung; and no single test may run away with the suite.
EXTRA=()
if [ "${1:-build}" = "test" ]; then
  EXTRA=(-collect-test-diagnostics never -test-timeouts-enabled YES
         -maximum-test-execution-time-allowance 300)
fi

xcodebuild \
  -project AMSPacking.xcodeproj \
  -scheme AMSPacking \
  -destination "$DEST" \
  -derivedDataPath "$DD" \
  "${EXTRA[@]}" \
  "${1:-build}"

echo
echo "App: $OUT"
