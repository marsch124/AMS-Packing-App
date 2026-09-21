#!/bin/bash
# The parity checker, both halves and the comparison, in one go.
#
#   tools/parity/run.sh [backup.json] [--today YYYY-MM-DD] [diff options: --max N --only <prefix> --quiet]
#   tools/parity/run.sh --invented [...]      the same, over the INVENTED backup (fixtures/make-invented-backup.mjs)
#
# Builds the Swift half (the `parity` tool of the Core package), runs the JavaScript
# half (the web app's own model) and the Swift half over the same backup file —
# private/migration-2026-09-21.json unless another is named — writes
# private/answers-js.json and private/answers-swift.json, compares them, and exits
# with the comparison's status: 0 when it ends "differences: none".
#
# --invented needs nothing private: the backup is made up (and awkward on purpose). It is
# written afresh by its generator on every run — `*backup*.json` is git-ignored here, to
# keep real backups out — and it and its two answers documents go to the build folder. That is the run for
# CI — it needs the web app's model beside this checkout (../AMS Packing/js/model.js) or
# named in PARITY_MODEL.
#
# 🚨 Without --invented, the answers and the comparison's output contain real item names. They stay in
# private/ (git-ignored) and on this screen — never paste them anywhere public.
#
# The build folder is kept OUTSIDE ~/Documents, exactly as tools/test-core.sh does:
# codesign refuses the extended attributes that folder collects.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BACKUP=""
INVENTED=0
TODAY="2026-09-21"
DIFF_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --today) TODAY="$2"; shift 2 ;;
    --max|--only) DIFF_ARGS+=("$1" "$2"); shift 2 ;;
    --quiet) DIFF_ARGS+=("$1"); shift ;;
    --invented) INVENTED=1; shift ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    --*) echo "Unknown option $1" >&2; exit 2 ;;
    *) BACKUP="$1"; shift ;;
  esac
done
BACKUP="${BACKUP:-$ROOT/private/migration-2026-09-21.json}"
if [ "$INVENTED" = 0 ]; then
  if [ ! -f "$BACKUP" ]; then echo "No backup file at $BACKUP" >&2; exit 2; fi
  BACKUP="$(cd "$(dirname "$BACKUP")" && pwd)/$(basename "$BACKUP")"
fi

# One build folder per checkout — the same one tools/test-core.sh uses.
cd "$ROOT/Core"
SCRATCH="${TMPDIR:-/tmp}/AMSPacking-core-$(pwd | shasum | cut -c1-8)"
swift build --scratch-path "$SCRATCH" --product parity -c release
BIN="$(swift build --scratch-path "$SCRATCH" --product parity -c release --show-bin-path)/parity"

cd "$ROOT"
if [ "$INVENTED" = 1 ]; then OUT="$SCRATCH/parity-invented"; else OUT="$ROOT/private"; fi
mkdir -p "$OUT"
if [ "$INVENTED" = 1 ]; then
  BACKUP="$OUT/invented.json"
  node tools/parity/fixtures/make-invented-backup.mjs > "$BACKUP"
fi
node tools/parity/js-answers.mjs "$BACKUP" --today "$TODAY" > "$OUT/answers-js.json"
"$BIN" "$BACKUP" --today "$TODAY" > "$OUT/answers-swift.json"
node tools/parity/diff-answers.mjs "$OUT/answers-js.json" "$OUT/answers-swift.json" ${DIFF_ARGS[@]+"${DIFF_ARGS[@]}"}
