#!/bin/bash
# Runs one UI-test group on GitHub and gives the tests that failed ONE retry in the same
# job, on the build it already has (9 Oct 2026: a single flaky test cost a 45-minute
# re-run of the whole group).
#
#   tools/ui-test.sh RESULT PLATFORM GROUP OF -- <xcodebuild options>
#
# RESULT is the result bundle's name without .xcresult; the retry writes RESULT-retry.
# The job is green only if the retry is. More than 5 failures, a failed model test, or a
# red run with no failed test (build error) are not retried (tools/ui-failed.py). Every
# retried test is listed in the job summary and as a warning, so a flake stays visible.
set -uo pipefail
RESULT=$1 PLATFORM=$2 GROUP=$3 OF=$4
shift 4
[ "${1:-}" = "--" ] && shift
HERE=$(cd "$(dirname "$0")" && pwd)
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
TITLE="UI tests — $PLATFORM group $GROUP of $OF"

rm -rf "$RESULT.xcresult" "$RESULT-retry.xcresult"
xcodebuild test $(python3 "$HERE/ui-shard.py" "$PLATFORM" "$GROUP" "$OF") \
  -resultBundlePath "$RESULT.xcresult" "$@"
status=$?
if [ $status -eq 0 ]; then
  echo "### $TITLE: green on the first run" >> "$SUMMARY"
  exit 0
fi

WHYFILE=$(mktemp)
if ! RETRY=$(python3 "$HERE/ui-failed.py" "$RESULT.xcresult" 2> "$WHYFILE"); then
  WHY=$(cat "$WHYFILE")
  echo "::error::$TITLE — no retry: $WHY"
  { echo "### $TITLE: red, no retry"; echo; echo "$WHY"; } >> "$SUMMARY"
  exit $status
fi

COUNT=$(echo "$RETRY" | wc -l | tr -d ' ')
echo "Retrying $COUNT failed test(s) once:"
echo "$RETRY"
xcodebuild test-without-building $RETRY \
  -resultBundlePath "$RESULT-retry.xcresult" "$@"
retry=$?

NAMES=$(echo "$RETRY" | sed 's|.*/||')
if [ $retry -eq 0 ]; then
  echo "retried=1" >> "${GITHUB_OUTPUT:-/dev/null}"
  for n in $NAMES; do echo "::warning::$TITLE — $n failed, then passed on its retry (flaky)"; done
  { echo "### $TITLE: green after a retry"; echo
    echo "Failed the first time, passed on the one retry:"; echo
    for n in $NAMES; do echo "- \`$n\`"; done; } >> "$SUMMARY"
  exit 0
fi
STILL=$(python3 "$HERE/ui-failed.py" "$RESULT-retry.xcresult" 2>/dev/null | sed 's|.*/||')
for n in ${STILL:-$NAMES}; do echo "::error::$TITLE — $n failed twice"; done
{ echo "### $TITLE: red after a retry"; echo
  echo "Retried once:"; echo
  for n in $NAMES; do
    if echo "$STILL" | grep -qx "$n"; then echo "- \`$n\` — failed again"; else echo "- \`$n\` — passed on retry"; fi
  done; } >> "$SUMMARY"
exit $retry
