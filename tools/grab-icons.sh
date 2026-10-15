#!/bin/bash
# Draws the pictures the grab lists wear under the app icon (0.86, spec 02 §13b): the
# entries iOS shows when the Packing icon is held can only carry an image from the app's
# own asset catalog, so each drawing is written there once, as a template PDF of 35 × 35
# points — the size iOS draws a quick action's icon — which Xcode turns into pictures.
#
#   tools/grab-icons.sh
#
# From the SAME drawings the app uses, never a re-tracing: GrabDoodle's path data (copied
# out of App/Sources/Screens/GrabScreen.swift as it stands) drawn by App/Sources/SVGPath.swift:
#   grab-swim, grab-bike, grab-run, grab-swim-sun, grab-bike-sun, grab-run-sun  the six doodles
#   grab-initial-<hex>   a list of his own wears its initial, as on its tile: A–Z, Å Ä Ö Ü,
#                        0–9 in the system font's heaviest weight (<hex> = the letter's code)
#   grab-list            any other initial: the Home tab's suitcase (Sections.swift)
# Run it again after a doodle changes; it rewrites App/Resources/Assets.xcassets/GrabIcons.
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# GrabDoodle, from its line to the brace that closes it at the start of a line.
{ echo 'import SwiftUI'
  awk '/^struct GrabDoodle: View \{/{on=1} on{print} on&&/^\}/{exit}' App/Sources/Screens/GrabScreen.swift; } > "$WORK/GrabDoodle.swift"
grep -q 'static func path' "$WORK/GrabDoodle.swift" || { echo "GrabDoodle not found in GrabScreen.swift" >&2; exit 1; }

swiftc -parse-as-library -O -o "$WORK/draw" App/Sources/SVGPath.swift "$WORK/GrabDoodle.swift" tools/grab-icons/main.swift
OUT=App/Resources/Assets.xcassets/GrabIcons
rm -rf "$OUT"
"$WORK/draw" "$OUT"
echo "Drawn into $OUT: $(ls "$OUT" | grep -c imageset) pictures"
