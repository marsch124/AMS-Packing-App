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
  package's single `jsLocaleCompare(_:_:)` helper everywhere. The parity checker has
  run over his Swedish names (å ä ö): every pair of his real strings orders as in JS.
  Where Foundation still parts from ICU (compatibility variants such as a no-break
  space, emoji modifiers) is written down at the helper — read it before "fixing" it.
- `normName` = trim, lowercase, collapse whitespace runs to one space.
- 🪤 Swift's `String ==` (and `Set` / `Dictionary` keys) is Unicode CANONICAL equivalence;
  JS `===` / `Map` / `Set` compare code units. `é` precomposed and `e` + U+0301 are two
  names to the web app and one here. Known, not fixed (QUESTIONS.md H17).
- Truthiness: `''`, `0`, `null`, `undefined`, `NaN` are false. `Number.isFinite`.
- `Math.round` rounds .5 **up** (towards +∞), unlike Swift's `.rounded()`.
- Dates are `YYYY-MM-DD` strings compared as strings; day arithmetic is in UTC.
  **ONE date parser**: `JSDay` in `JSSemantics.swift` — `Date.parse` as V8 reads it
  (`2026-02-30` rolls over to 2 March; `YYYY` and `YYYY-MM` are dates). Never write
  a second one: care and the trip dates once had a copy each.
- **ONE number writer**: `jsNumberToString` — `String(n)`, `JSON.stringify` and the
  share codes all go through it (`0.00001`, never `1e-05`; `1e+21`; no `.0`).
  `x.toFixed(1)` is `jsToFixed1`, beside it.
- `JSON.parse` accepts half an emoji written as a lone `\ud83d` escape; Foundation's
  parser throws. Always parse through `JSONValue.parse`, which reads it (and drops the
  half: a Swift String cannot hold one).

## Tests

Port `tests/model.test.mjs` **test by test**: same assertions, same data. One
XCTest method per JS `test(...)`, the JS test name kept verbatim in a comment
above it. Test files mirror the source files (`PhasesTests.swift`…). Run with
`tools/test-core.sh` (never bare `swift test` here: `~/Documents` breaks codesign).
A test that cannot be ported as written (it tests a JS-only quirk) is listed at
the bottom of its file with the reason — never silently dropped.

## Conventions the foundation slice set (follow them in every later slice)

- **Every model type conforms to `JSONModel`**: `init(json: JSONValue)` (the `coerceX`
  rules; never fails — a non-object reads as `{}`) and `var json: JSONValue` (the web
  app's own keys). `Codable` comes free from those two: never write a `CodingKeys`
  enum or a throwing `init(from:)`.
- **Every `coerceX` has two forms**: `coerceItem(_ it: Item) -> Item` (the VALUE rules,
  for something built in memory) and `coerceItem(json: JSONValue?) -> Item?` (type
  rules, then the value rules; nil when it is not an object, where JS hands the junk
  back). Write the value rules ONCE, in the typed form; `Item(json:)` ends by calling it.
- **Every `newX` has three forms**: `newItem(name: "Tent", weight: 300)` — the same
  parameter list as `Item.init`, then coerced; this is how a JS
  `newItem({ name: 'Tent', weight: 300 })` reads in a test — plus `newItem(_ item: Item)`
  and `newItem(json: ["name": "Tent", "photos": ["a", nil, 42]])` for a partial with junk
  in it. `Item(…)` alone has `newItem`'s defaults but does NOT coerce.
- **Optional vs default.** A field `coerceX` always fills is a plain type with a default.
  A field JS leaves `undefined`, and whose absence MEANS something, is Optional (nil =
  undefined = null): `used`, `sourceListId`, `sourceItemId`, `itemId`, `memId`,
  `ovContainer`, `tplContainer`, `defContainer`, `ovPhase`, `defPhase`. Markers JS only
  tests for truthiness are plain Bools: `checked`, `custom`, `skipped`, `keep`, `edited`,
  `link`. All of these are left OUT of the JSON when false / nil.
- **Underscore keys lose the underscore in Swift**: `_edited` → `edited`, `_memId` →
  `memId`, `_itemId` → `itemId`, `_link` → `link`, `_ovContainer` → `ovContainer`…
- **Unknown keys** land in `extra: [String: JSONValue]` and are written back. `owner`
  and `realmId` never are (`RESERVED_SYNC_KEYS`).
- **Where JS walks field NAMES** (`INTRINSIC_FIELDS`, `slimEntry`'s `Object.entries`),
  go through `item.json` / `Item(json:)` — those lists hold JSON keys.
- A JS **NaN** that would be stored is `nil` (`WeatherDay.tmax`, `WeatherSnapshot.lat`):
  NaN breaks `Equatable` and cannot be written as JSON.
- Sorting: `xs.stableSorted(compare: { a, b in jsOr(jsSign(a.n - b.n), jsLocaleCompare(a.id, b.id)) })`.
  `{ sensitivity: 'base' }` is `jsLocaleCompare(a, b, sensitivity: .base)`.
- Inside a type with its own `id` / `phase` property, the free functions of the same
  name are `PackingEnv.makeId()` and `PackingCore.phase(_:)`.
- Tests: `PackingEnv.freeze()` gives a fixed clock and ids "id-1", "id-2"…. In `tearDown`
  call `PackingEnv.reset()`, and `setPhases(DEFAULT_PHASES)` /
  `setItemConditions(DEFAULT_ITEM_CONDITIONS)` when a test touched them.

## The parity checker

`tools/parity/run.sh` puts the contract's questions (`tools/parity/QUESTIONS.md`) to
the web app's model and to this package over a real backup, and compares every
answer; it must end `differences: none` — and so must `tools/parity/run.sh --invented`,
the same questions over an invented, deliberately awkward backup (no private data: the
run for CI). The Swift half is the `parity` executable
target of this package (`Sources/parity`), which may use the PUBLIC API only — if it
needs something that is not public, that is a finding about the port. A difference is
a port bug until proved otherwise: fix `PackingCore`, and add a regression test with
INVENTED data that fails without the fix. The JS model is right by definition.

## Constraints

Swift tools 5.9, Swift 5 language mode, Foundation only, no dependencies. It must
compile on Xcode 16 (GitHub's macos-15 runner) as well as on Xcode 27.
No real data in this repository — it is public. Tests use invented items.
