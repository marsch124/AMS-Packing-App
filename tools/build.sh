#!/bin/bash
# Builds AMS Packing for the iPhone simulator.   tools/build.sh [build|test]
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
[ -f project.yml ] && xcodegen generate

xcodebuild \
  -project AMSPacking.xcodeproj \
  -scheme AMSPacking \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath "$DD" \
  "${1:-build}"

echo
echo "App: $DD/Build/Products/Debug-iphonesimulator/AMSPacking.app"
