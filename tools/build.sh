#!/bin/bash
# Builds AMS Packing.   tools/build.sh [build|test] [iphone|mac] [icloud]
#
# "icloud" builds with the iCloud entitlements and PACKING_USES_ICLOUD=YES — the
# build that syncs. It needs his Apple ID in Xcode (automatic signing registers
# the app and its iCloud container on first use), so it is for THIS Mac, not CI.
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

if [ "${3:-}" = "icloud" ]; then
  # …DeviceRegistration: a Mac DEVELOPMENT profile only counts on a Mac that is
  # registered in the developer portal. Without it the app carries the iCloud
  # entitlements but is not GRANTED them, and the sandbox denies it the CloudKit
  # daemon (found 2026-09-22 in the kernel's sandbox log).
  EXTRA+=(-allowProvisioningUpdates -allowProvisioningDeviceRegistration
          CODE_SIGN_ENTITLEMENTS=App/Config/AMSPacking-iCloud.entitlements
          PACKING_USES_ICLOUD=YES)
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
