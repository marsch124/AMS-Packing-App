#!/bin/bash
# His floor (F073, 5 Oct 2026): nothing a person reads is smaller than 15 points — he
# reads the app without his glasses. 0.6x raised about 150 sizes of 10–14 to 15; this
# keeps them there. It fails, naming file:line, for:
#   1. a `size: N` under 15 (or a `size: a ? N : M` with either under 15) — unless the
#      line says `// not text: <what it is>` (a drawn mark, a shape, a glyph);
#   2. a text style under 15: .caption, .caption2, .footnote, .subheadline — and .callout,
#      .body and .headline too, which are 12–13 on the Mac (16–17 only on the iPhone);
#   3. a minimumScaleFactor that lets words shrink under 15 (the nearest `size: N` on
#      that line or the four above, times the factor).
# Run by the Tests workflow on every push, before the model's tests.
set -e
cd "$(dirname "$0")/.."

files=()
while IFS= read -r f; do files+=("$f"); done < <(find App/Sources -name '*.swift' | sort)

problems=$(awk '
  function small(n) { return n + 0 < 15 }
  FNR == 1 { delete back }
  {
    line = $0
    code = line; sub(/\/\/.*$/, "", code)          # what a comment says does not count
    marked = (line ~ /\/\/ *not text/)

    # 1. size: N, and size: cond ? N : M
    if (!marked) {
      rest = code
      while (match(rest, /size: *[0-9]+(\.[0-9]+)?/)) {
        n = substr(rest, RSTART, RLENGTH); sub(/size: */, "", n)
        if (small(n)) { printf "%s:%d: size %s is under 15 — make it 15, or mark a drawn mark // not text: <what>\n", FILENAME, FNR, n }
        rest = substr(rest, RSTART + RLENGTH)
      }
      rest = code
      while (match(rest, /size: *[^,()]*\? *[0-9]+(\.[0-9]+)? *: *[0-9]+(\.[0-9]+)?/)) {
        t = substr(rest, RSTART, RLENGTH); sub(/^[^?]*\? */, "", t)
        split(t, ab, /[ :]+/)
        if (small(ab[1]) || small(ab[2])) { printf "%s:%d: size %s or %s — one is under 15\n", FILENAME, FNR, ab[1], ab[2] }
        rest = substr(rest, RSTART + RLENGTH)
      }
    }

    # 2. text styles that are under 15 on the iPhone or on the Mac
    if (code ~ /(\.font\( *|\.system\( *|Font)\.(caption2?|footnote|subheadline|callout|body|headline)([^A-Za-z0-9_]|$)/) {
      printf "%s:%d: a text style under 15 pt (on the Mac .body/.headline are 13, .callout 12) — use .system(size: 15 or more)\n", FILENAME, FNR
    }

    # 3. minimumScaleFactor(f) × the nearest literal size on this line or the four above
    if (match(code, /minimumScaleFactor\( *[0-9.]+/)) {
      f = substr(code, RSTART, RLENGTH); sub(/minimumScaleFactor\( */, "", f)
      size = ""
      for (k = 0; k <= 4 && size == ""; k++) {
        src = (k == 0) ? code : back[k]
        if (match(src, /size: *[0-9]+(\.[0-9]+)?/)) { size = substr(src, RSTART, RLENGTH); sub(/size: */, "", size) }
      }
      if (size != "" && size * f < 14.95) {
        printf "%s:%d: minimumScaleFactor(%s) lets %s-pt words shrink to %.1f — keep it at or above 15/%s\n", FILENAME, FNR, f, size, size * f, size
      }
    }

    for (k = 4; k > 1; k--) back[k] = back[k - 1]
    back[1] = code
  }
' "${files[@]}")

if [ -n "$problems" ]; then
  echo "$problems" | while IFS= read -r p; do echo "::error::$p"; done
  echo "type floor: $(echo "$problems" | wc -l | tr -d ' ') place(s) under 15 pt — his floor is 15 (he reads without glasses)"
  exit 1
fi
echo "type floor: nothing under 15 pt in ${#files[@]} files"
