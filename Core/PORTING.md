# Porting `js/model.js` to Swift — the rules

`PackingCore` is a port of the web app's `../AMS Packing/js/model.js` (pure logic,
no screen, no storage, no network) and of its tests, `../AMS Packing/tests/model.test.mjs`.
The port is **faithful, not creative**: the same question must get the same answer.
A parity checker will run both models over Martin's real data and compare every
answer, so a "sensible improvement" shows up as a difference and has to be undone.

## Names

- Every exported JS function keeps its **exact name** as a public Swift free
  function (`buildTotalEntries`, `coerceItem`, `phaseLabel`…), and every exported
  constant keeps its name too (`CATEGORIES`, `DEFAULT_PHASES`, `MAX_PHOTOS`…).
  The behaviour contract (`../AMS Packing/docs/behaviour-contract.md`) and the JS
  source are the documentation; identical names keep them usable.
- One Swift file per section of `model.js`, named for what it holds
  (`Phases.swift`, `Items.swift`, `TripBuilding.swift`, `Sharing.swift`…).
- Carry the **comments that explain WHY** across (shortened if long). Many of them
  record a real bug; they are the most valuable part of the file.

## Types

- Plain `struct`s, `public`, `Equatable`, `Codable`, all stored properties `public var`
  with a public memberwise-style `init` that has a default for every field (the
  defaults of `newItem` / `newList` / `newEvent`…), so `Item(name: "Socks")` works.
- **One `Item` struct serves the catalogue item, the resolved template item AND the
  trip entry**, exactly as one JS object shape does (`coerceItem` is applied to all
  three). Entry-only fields (`sourceListId`, `sourceItemId`, `custom`, `checked`,
  `skipped`, `_edited`, `_memId`, …) live on it too. Grep `js/model.js`, `js/db.js`
  and `js/app.js` for every field that is ever read or written on an item/entry,
  so none is lost on a round trip. A Swift property cannot start with `_`… it can,
  but prefer `edited` / `memId` with `CodingKeys` mapping to `_edited` / `_memId`.
- **Decoding is coercion.** `init(from:)` must never throw because a field is
  missing or has the wrong type: it applies exactly the rule `coerceX` applies
  (wrong type → the default). His backup JSON decodes straight into these types.
  Encoding writes the same keys the web app's backup uses.
- The JS `coerceX(obj)` functions still exist in Swift (`coerceItem(_ item: Item) -> Item`)
  for values built in memory.
- Free-form JSON (a shared row's `data`, a preset's `config`, a cached weather
  snapshot if it is not worth typing) → the package's `JSONValue` enum.
- JS numbers are `Double`, except where the JS floors them into a count (`Int`).
- Never name a field `owner` or `realmId` — the web app lost 422 item owners to a
  sync layer that reserves them. On decode, `owner`/`realmId` are IGNORED except
  for the legacy rule inside `coerceItem` (`ownedBy` adopts a non-e-mail `owner`).

## Global state — mirrored on purpose

`PHASES` / `PHASE_IDS` and `ITEM_CONDITIONS` / `ITEM_CONDITION_IDS` are module-level
mutable state in JS, replaced only through `setPhases` / `setItemConditions`. Keep
that: `public private(set) var PHASES`, changed only by `setPhases(_:)`. Tests that
change them must restore the defaults in `tearDown`. (XCTest runs serially.)

## Time and ids

`id()` and "now" must be injectable, or nothing can be compared:
`PackingEnv.now: () -> Date` and `PackingEnv.makeId: () -> String`, with the JS
behaviour as the default. Functions that take `todayISO` in JS take it in Swift too.

## JavaScript semantics that bite

- `str.slice(0, n)` counts **UTF-16 units**, not Characters. Use the package's
  `jsSlice` helper. `charCodeAt` hashing (`listColor`, `personColor`) walks UTF-16
  units with `>>> 0` (UInt32 wrap-around: use `&*` and `&+`).
- `Array.prototype.sort` is **stable**. Swift's `sort` does not promise it. Always
  sort through the package's `stableSorted(by:)` helper.
- `a.localeCompare(b)` is ICU collation in the runtime's locale — NOT `<`. Use the
  package's single `jsLocaleCompare(_:_:)` helper everywhere so it can be tuned
  once when the parity checker runs over his Swedish names (å ä ö).
- `normName` = trim, lowercase, collapse whitespace runs to one space.
- Truthiness: `''`, `0`, `null`, `undefined`, `NaN` are false. `Number.isFinite`.
- `Math.round` rounds .5 **up** (towards +∞), unlike Swift's `.rounded()`.
- Dates are `YYYY-MM-DD` strings compared as strings; day arithmetic is in UTC.

## Tests

Port `tests/model.test.mjs` **test by test**: same assertions, same data. One
XCTest method per JS `test(...)`, the JS test name kept verbatim in a comment
above it. Test files mirror the source files (`PhasesTests.swift`…). Run with
`tools/test-core.sh` (never bare `swift test` here: `~/Documents` breaks codesign).
A test that cannot be ported as written (it tests a JS-only quirk) is listed at
the bottom of its file with the reason — never silently dropped.

## Constraints

Swift tools 5.9, Swift 5 language mode, Foundation only, no dependencies. It must
compile on Xcode 16 (GitHub's macos-15 runner) as well as on Xcode 27.
No real data in this repository — it is public. Tests use invented items.
