# The parity questions — contract version 3

**Needs the web app's model v186 or later** (`shareSafeOwner`, `SYNC_RESERVED_KEYS`);
the JS side refuses to run on an older one. What changed from version to version is
listed in §19.

Two programs answer the same questions about the same backup file:

- **JavaScript** — `tools/parity/js-answers.mjs`, which loads the web app's own
  `../AMS Packing/js/model.js` (read-only) and is the reference implementation of
  this document.
- **Swift** — `Core/Sources/parity` (the `parity` tool of the `PackingCore` package),
  written from THIS document and laid out like the JS half, one function per question
  group, so the two can be read side by side. It uses PackingCore's public API only.

Each writes one JSON document of answers. `tools/parity/diff-answers.mjs a.json b.json`
compares them and ends `differences: none` or `differences: N`.

```
tools/parity/run.sh [private/<backup>.json] [--today 2026-09-21] [--max N] [--only <prefix>] [--quiet]
```

builds the Swift half, runs both, writes the two documents into `private/`, compares
them and exits with the comparison's status.

```
tools/parity/run.sh --invented
```

does the same over `tools/parity/fixtures/invented-backup.json` — a backup in which
everything is made up and as awkward as a backup can get (kits, things, presets,
a customised phase list with ties, an item shared by three lists, legacy `owner`
fields, names cut inside an emoji, 405 items in one list, dates that are not dates).
It needs nothing private — its answers go to the build folder — so it is the run for
CI, and the one that finds port bugs the owner's tidy data cannot: it must end
`differences: none` too. The file is written by `fixtures/make-invented-backup.mjs`
(deterministic; its header lists the shapes it deliberately leaves out, and why), and
`fixtures/check-invented.mjs` proves mechanically that it shares no string and no
word with the real backup. By hand:

```
node tools/parity/js-answers.mjs private/<backup>.json [--today 2026-09-21] > private/answers-js.json
<scratch>/release/parity          private/<backup>.json  --today 2026-09-21  > private/answers-swift.json
node tools/parity/diff-answers.mjs private/answers-js.json private/answers-swift.json
```

(Never a bare `swift build` inside `Core/`: codesign refuses a build folder under
`~/Documents`. `run.sh` passes the same `--scratch-path` as `tools/test-core.sh`.)

**Privacy.** The backup is real data and this repository is public. Answers
documents, and the diff tool's output (its paths contain item names), stay in
`private/`. Every example in this file is invented.

If this document and `js-answers.mjs` ever disagree, that is a bug in one of them:
fix it, and bump `contract`.

---

## 1. Determinism rules

| # | Rule |
|---|------|
| D1 | **Today is a parameter.** `TODAY` = `--today` (default `2026-09-21`). It is passed to every function that accepts `todayISO`. |
| D2 | **The clock is frozen.** `NOW` = `<TODAY>T12:00:00.000Z`. Wherever the model reads the real clock (`nowISO()`, a missing `todayISO`, `placesVisited` → `sortEventsForList` with no date, `backupState` with no `now`), it must see `NOW`. JS replaces the global `Date`; Swift sets `PackingEnv.now`. |
| D3 | **Minted ids are never compared.** `id()` is random. Wherever a question's result contains an id the model minted during that question, the question says what is written instead: the marker `"<id>"`, a positional name (`I0`, `M0`, `S0` …), or the field is dropped. An id that came from the backup is written as it is. |
| D4 | **Minted timestamps are never compared.** `createdAt` / `updatedAt` minted during a question are written as `"<now>"`, where the question says so. (With D2 they would be equal anyway; the marker means the Swift side does not depend on D2 for them.) |
| D5 | **Every question gets its own deep copy of its inputs.** The model mutates what it is given (`coerceList`, `applyReview`, `applyPresetConfig`, `parseTripBundle`…). No question may see another's side effects. The only shared state is the phase list and the condition list installed in Setup (§4); the two questions that change them (§15) run last and put them back. |
| D6 | **Collation is pinned to `en-US`.** `a.localeCompare(b)` uses the runtime's default locale. JS restarts itself under `LC_ALL=en_US.UTF-8` if it has to. Swift's `jsLocaleCompare` must behave as ICU collation for `en-US` (root collation): default strength for the plain call, primary strength (`sensitivity: 'base'`: case and accents ignored) where the model asks for it. |
| D7 | **A question that throws** is answered `{"$error": "<the error's message>"}`. The model's messages are user-facing text and are ported verbatim, so they are compared. |
| D8 | A question with no entities (no kits in the backup → no `coerce.kit` answers) is simply absent from the document, on both sides. |

## 2. The document and canonical JSON

```json
{ "_info": { "generator": "swift", "contract": 3, "today": "2026-09-21", "...": "..." },
  "answers": { "<question key>": { "<entity key>": <answer> } } }
```

- `_info` is informational. The diff tool ignores it, except that `today` must be
  equal in both documents. Put anything useful in it (JS records counts, versions,
  the locale, and `unknownKeys`: data keys no shape carries).
- **Entity keys**: a list's `id`, an event's `id`, an action's `id` (or `#<index>` if
  it has none); `*` for a question asked once; otherwise whatever the question
  says (a string from the data, a date, a case name). The empty string is a legal
  key.

Canonical values (what `canon` does in the JS):

| JS value | Written as |
|---|---|
| `undefined`, a function | inside an object: the key is dropped. Inside an array: `null`. As a whole answer: `null`. |
| `NaN`, `±Infinity` | `null` (what `JSON.stringify` does) |
| `-0` | `0` |
| a string holding half an emoji (a lone surrogate — H4, H16) | the string with the half **dropped**: a Swift String cannot hold one. The share codes that carry the half are still compared byte for byte (`list.share.encoded`, `settings.grabShare`). |
| other numbers | as they are. The diff tool compares parsed numbers: two WHOLE numbers must be equal (counts, the FNV hashes of `calc.lzw` — a relative tolerance would wave through a 32-bit hash that is off by 4); anything else within 1e-9 (relative above 1). `1` and `1.0` are equal. |
| `Set` | array sorted by **UTF-16 code-unit order** (JS `<` on strings; in Swift compare `utf16` views, not `String <`) |
| `Map` | object; keys are the map's keys as strings; insertion order is **not** compared |
| `Uint8Array` | array of numbers |
| object | keys sorted by UTF-16 code-unit order |

The diff tool compares **parsed** values, so whitespace and key order in the file
never matter. **One place needs byte-exact text:** `CJ(value)`, used by
`event.packedCanonical` and `calc.lzw`. `CJ` is: canonical value as above; object
keys in UTF-16 code-unit order; no whitespace; separators `,` and `:`; strings and
numbers exactly as `JSON.stringify` writes them —

- strings: `"` → `\"`, `\` → `\\`, U+0008 `\b`, U+000C `\f`, U+000A `\n`, U+000D `\r`,
  U+0009 `\t`, any other code unit below U+0020 → `\u00xx` (lowercase hex). **Nothing
  else is escaped**: not `/`, not U+007F, not U+2028, not non-ASCII. (Swift's
  `JSONEncoder` escapes `/` unless told not to, and cannot be trusted on order.
  Write `CJ` by hand.)
- numbers: an integral double has no decimal point (`23`, not `23.0`); otherwise
  the shortest text that round-trips (`58.41`, `0.30000000000000004`); exponent
  form only at or above 1e21 and below 1e-6, written `1e+21`, `1e-7`.

## 3. Shapes — the fixed key sets

The model keeps whatever extra keys an object arrives with; a typed Swift struct
cannot. So every entity is written with a **fixed key set**. Keys outside the set
are dropped on both sides (JS lists them in `_info.unknownKeys`; on the owner's
backup, apart from the sync layer's two reserved keys — §4.1 — there are none).

### 3.1 ITEM — catalogue item, resolved template item, trip entry, thing

| Keys | Rule |
|---|---|
| `seasons contexts transports catering weather sub phase category itemType charging chargeType shortList swedish stats weight liquid restricted perNight consumable section kit packer storage photos thumb maintenance color size manufacturer model ownedBy acquired price currency purchaseLink expiry condition retired retiredReason serial qtyOwned warranty capacityL maxKg` | written as `coerceItem` leaves them. `stats` = `{packed, used, unused, skipped, lastReviewed}`. `maintenance` = `null` or `{notes, link, intervalDays, lastDone, log:[{date, note}]}`. |
| `id name qty container note sourceListId sourceItemId` | always written, as a string: a string as it is; absent or `null` → `""`; a number → `String(n)`. |
| `custom checked skipped _edited keep` | always written, as `!!value` |
| `used` | written only when it is a boolean |
| `_ovContainer _tplContainer _defContainer _ovPhase _defPhase _itemId _memId` | written only when it is a string |

`sub` is an array of names — strings — and each element is written **exactly as
the model left it** (canonical value; nothing is put back together by the
contract). Wherever the model is required to produce plain names, a non-string
element is therefore a difference. See §17.

`owner` and `realmId` (`SYNC_RESERVED_KEYS`) are not part of any shape and are
never written (§4.1).

### 3.2 LIST
`id name emoji color sections group role transport defaultContainer builtin createdAt updatedAt items`
— `sections` = `[{id, name}]`; `builtin` = `!!`; `id name createdAt updatedAt` by the
string rule above; `items` = ITEM shapes.

### 3.3 EVENT
`id name mode activities transport season contexts weatherOn catering startDate endDate nights laundry destination weather geo entries status reviewedAt generatedAt createdAt updatedAt`
— `id name transport season catering startDate generatedAt createdAt updatedAt` by
the string rule; `weather` = `null` or `{place, lat, lon, fetchedAt, daily:[{date, code, tmax, tmin, precipProb, wind}]}`;
`geo` = `null` or `{lat, lon, place}`; `entries` = ITEM shapes.

### 3.4 Others
- ACTION `id text kind itemId itemName priority whenPhase whenDate done doneAt createdAt updatedAt`
- KIT `id name emoji note itemIds createdAt updatedAt`
- PHASE `id label hint emoji color task leadDays order`
- CONDITION `id label tone replace`
- PERSON `id name color`
- MEMBERSHIP `id itemId templateId seasons contexts transports catering weather container section kit phase itemType qty note order`
- ROW (a shared Settings row) `id kind key name order data` — `data` is free-form: canonical value.

### 3.5 SLIM ENTRY — an entry as a trip bundle carries it
Only the ITEM-shape keys that are **present** in the slimmed object, as canonical
values. Nothing is defaulted in. (So `sub` is present only when it holds at least
one non-empty name, and `ownedBy` only when `shareSafeOwner` lets it through.)

### 3.6 Identifying tuples
Inside grouping and sorting results an entry is written as one string, not as an
object — the whole object is compared once, in §7.

- `entryRef(e)` = `sourceItemId|name|container|phase`
- `buildRef(e)` = `sourceListId|` + `entryRef(e)`
- `itemRef(it)` = `id|name`

Each part by the string rule (absent → empty). `refs(xs)` = the entries' `entryRef`s in order.

## 4. Setup — once, in this order

`B` is the parsed backup: `{ app, version: 2, exportedAt, lists, events, actions, kits, phases, things, photos, prefs }`.
A missing array is `[]`; a missing `prefs` is `{}`. `photos` is not used.

**4.1 Nothing is stripped.** The backup goes to the model exactly as the file
holds it. On synced data every list, item, event, entry and action carries the
sync addon's two reserved properties, `owner` and `realmId`, both holding the
account's e-mail address (JS counts them in `_info.reservedKeysSeen`). They are
**not data**: no shape writes them, and `Core/PORTING.md` has the Swift types ignore
them on decode. The one place `owner` is read is `coerceItem`'s legacy rule — when
`ownedBy` is **not a string at all**, a non-e-mail `owner` is adopted into `ownedBy`
(`calc.coerceHostile` proves it). Keeping the two keys, and any address, out of
everything that leaves the device is the model's job since v186, and
`event.tripBundle.leaks`, `list.share.addressInside`, `calc.tripBundleOutgoing` and
`calc.tripBundleIncoming` check that it does. (Contract 1 deleted the two keys
here, to step around two web-app bugs that v186 fixed.)

**4.2 Phases first**, as `applyBackup` does: `incoming = B.phases.map((p, i) => coercePhase(p, i))` keeping those
with an `id` and a `label`; then `setPhases(incoming)` (an empty list installs the factory seven).

**4.3 Conditions**: `setItemConditions(B.prefs.conditions)` when that is a non-empty
array, else `setItemConditions([])` (the factory four).

**4.4 The Settings lists in force**
- `CONDITIONS_IN` = `prefs.conditions` if a non-empty array, else a copy of `DEFAULT_ITEM_CONDITIONS`
- `PEOPLE_IN` = `prefs.people` …, else a copy of `DEFAULT_PEOPLE`
- `PLACES_IN` = `prefs.storageLocations` …, else `DEFAULT_STORAGE_LOCATIONS`
- `OWNERS_IN` = `prefs.owners` …, else `[]`
- `PEOPLE` = `peopleFromRows(peopleToRows(PEOPLE_IN))`; `PEOPLE_NAMES` = their names.

**4.5 Coerce everything once**
`LISTS = B.lists.map(coerceList)`, `EVENTS = B.events.map(coerceEvent)`,
`ACTIONS = B.actions.map(coerceAction)`, `KITS = B.kits.map(coerceKit)`,
`THINGS = B.things.map(coerceItem)` — order as in the file.
**Below, every mention of `LISTS`, `EVENTS`, `ACTIONS`, `KITS`, `THINGS`, `PEOPLE`
means a fresh deep copy (D5).** `L` is one list, `E` one event, `i` its index.

**4.6** `ROWS(lists)` = `catalogRows(lists, THINGS)`.

## 5. Synthetic overlays

The real backup leaves some questions empty (no expiry dates, no kits, one
packer). Questions marked **synth** run on the real data with these deterministic
changes on top. `addDays` is the model's.

**`SL` — synthetic lists.** Number every distinct item id `k = 0, 1, 2…` in order of
first appearance (LISTS in order, items in order). On a copy of LISTS, for every
item (the same `k` wherever that id appears):
- `k % 5 == 0` → `expiry = addDays(TODAY, (k % 120) - 40)`
- `k % 7 == 1` → `condition = ITEM_CONDITION_IDS[k % ITEM_CONDITION_IDS.count]`; else `k % 13 == 3` → `condition = "mystery"`
- `k % 6 == 0` → `consumable = true`
- `k % 17 == 5` → `retired = true`
- `k % 8 == 2` → `maintenance = { notes: "Synthetic care note", link: "", intervalDays: [30, 90, 182, 365, 0][k % 5], lastDone: (k % 3 == 0) ? "" : addDays(TODAY, -((k * 7) % 400)), log: [] }`
- `k % 10 == 4` → `stats = { packed: k % 4, used: (k % 3 == 0) ? 0 : 1, unused: 0, skipped: k % 3, lastReviewed: "" }`

**`SE(E)` — synthetic event.** On a copy of `E`, for the entry at index `i`:
- `i % 5 == 0` → `expiry = addDays(TODAY, (i % 120) - 40)`
- `i % 4 == 1` (and the roster is not empty) → `packer = PEOPLE_NAMES[floor(i / 4) % PEOPLE_NAMES.count]`; else `i % 11 == 2` → `packer = "Zed Guest"`; else `i % 11 == 6` → `packer = "amy guest"`
- `i % 6 == 2` → `kit = "Kit " + "ABC"[floor(i / 6) % 3]`
- `skipped = (i % 9 == 4)`, `checked = (i % 2 == 0)`, `used = (i % 3 != 0)`

**`SA` — synthetic actions.** For `i = 0…11`, with `iid` = the item id numbered `k = i`
and `name` that item's name (first appearance): `coerceAction` of
`{ id: "synth-action-<i>", text: "Synthetic <i>", kind: i % 3 == 0 ? "shopping" : "todo", itemId: iid, itemName: name, priority: i % 2 == 0 ? "high" : "normal", whenPhase: i % 4 == 1 ? (PHASE_IDS[i % PHASE_IDS.count] ?? "") : (i % 4 == 2 ? "no-such-phase" : ""), whenDate: i % 4 == 0 ? addDays(TODAY, i) : "", done: i % 5 == 0, doneAt: i % 5 == 0 ? NOW : "", createdAt: S, updatedAt: S }`
where `S = addDays("2026-01-01", i % 7) + "T00:00:00.000Z"`. (Fewer than 12 distinct items → as many as there are.)

---

## 6. Setup state

| Key | Entity | Answer |
|---|---|---|
| `setup.phases` | `*` | `{ phases: PHASES as PHASE shapes, ids: PHASE_IDS, customised: phasesCustomised(), defaultPhaseId: defaultPhaseId() }` |
| `setup.conditions` | `*` | `{ conditions: ITEM_CONDITIONS as CONDITION shapes, ids: ITEM_CONDITION_IDS }` |
| `setup.people` | `*` | `PEOPLE` as PERSON shapes |
| `coerce.phase` | index in `B.phases` | `coercePhase(B.phases[i], i)` → PHASE |
| `coerce.condition` | index in `CONDITIONS_IN` | `coerceCondition(c)` → CONDITION |
| `coerce.person` | index in `PEOPLE_IN` | `coercePerson(copy of p)` → PERSON; `id` is `"<id>"` when the input had no non-empty string id |

## 7. Coercion — whole objects

Input is the **raw** object from the backup, not the coerced one.

| Key | Entity | Answer |
|---|---|---|
| `coerce.list` | list id | `coerceList(raw)` → LIST. A section that arrived without an id is written `S<its index in the coerced sections>`. |
| `coerce.event` | event id | `coerceEvent(raw)` → EVENT |
| `coerce.action` | action id | `coerceAction(raw)` → ACTION. If the raw action had no string `createdAt`: `createdAt` = `"<now>"`, and `updatedAt` = `"<now>"` too if that was also missing. |
| `coerce.kit` | kit id | `coerceKit(raw)` → KIT |
| `coerce.thing` | thing id | `coerceItem(raw)` → ITEM |

## 8. Per list — entity = list id

| Key | Answer |
|---|---|
| `list.cover` | `{ emoji: listEmoji(L), color: listColor(L), hashedById: listColor(a list with only L's id and name, colour blank), hashedByName: listColor(a list with only L's name), contextApplies: contextApplies(L), defaults: templateDefaults(L), groupLabel: groupLabel(L.group) }` |
| `list.sectionNames` | `L.items.map(it => sectionName(L, it.section))` |
| `list.groupItemsBySection` | `groupItemsBySection(L.items, L.sections)` → `[{ section: {id, name} or null, items: [itemRef] }]` |
| `list.photos` | `{ hasInline: hasInlinePhotos(L.items), refs: Σ photoRefs(it).count, inline: Σ inlinePhotos(it).count }` |
| `list.share.encoded` | `encodeListShare(L)` → **the string itself**. An empty list throws (D7). |
| `list.share.decoded` | `decodeListShare("https://example.invalid/app/#/l/" + code)` → `{ name, emoji, color, group, role, transport, defaultContainer, sections: [names], items: [...] }`; each item = `{ name, swedish, qty, category, phase, container, note, chargeType, section, kit, storage, packer, ownedBy, itemType, weight, seasons, contexts, transports, catering, weather, sub, shortList, charging, liquid, restricted, perNight, consumable }`, as returned — `ownedBy` is `shareSafeOwner(u)`; there is no `owner` key. Absent when encoding threw. |
| `list.share.addressInside` | whether the JSON text inside the code, `unpackShare(code)`, contains an e-mail address anywhere: a match for `/[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+/`. `false` on any data whose `ownedBy` values are names. Absent when encoding threw. |
| `list.share.imported` | `listFromShare(decodeListShare(code))` → LIST with: list `id` = `"<id>"`; `createdAt`, `updatedAt` = `"<now>"`; each section id = `S<index>`; each item `id` = `"<id>"`; each item `section` mapped to the same `S<index>` (blank stays blank). Absent when encoding threw. |

**The share string is compared byte for byte.** It is `packShare(JSON text)`, and
the JSON text's key order is fixed by the code, so it is reproducible — but only
with a hand-written, ordered JSON writer using the §2 string/number rules:

- top level, in this order, each only when the model sets it: `k v n x i c g r tp d s`
- each item in `x`: `n f w q c p b o y e k s a u t g se cx tr ca we sb`.
  **`u` = `shareSafeOwner(it.ownedBy)`**, written only when that is not blank —
  never the reserved `owner`.

`packShare` picks the `z.`-prefixed LZW form when its **string length** is shorter
than the plain base64url form, else the plain form.

## 9. Per event — entity = event id

`n = qtyNights(E)`. "real + synth" means the key is asked twice: `<key>` on `E`,
`<key>.synth` on `SE(E)`.

### Building
| Key | Answer |
|---|---|
| `event.listsForEvent` | `listsForEvent(E, LISTS)` → list ids |
| `event.matchCounts` | for every list in LISTS: `{ listId: count of items where itemMatchesEvent(it, E, list) }` |
| `event.buildTotalEntries` | `buildTotalEntries(E, LISTS)` → ITEM shapes **with `id` dropped** |
| `event.buildTotalEntries.weatherAll` | the same with `E.weatherOn = WEATHER_CONDITION_IDS` → `[buildRef]` |
| `event.regenerateEntries` | `regenerateEntries(E, LISTS)` → `[entryRef + "\|" + (the entry's id if E.entries already held that id, else "<new>")]` |

### Grouping and progress — real + synth
| Key | Answer |
|---|---|
| `event.entriesByPhase` | `entriesByPhase(entries)` → `[{ phase: PHASE, entries: refs }]` |
| `event.groupBy.<mode>` for `category container section stored when` | `groupBy(mode, entries)` → `[{ label, hint (only when present), entries: refs }]` |
| `event.progress` | `{ progress: progress(entries), packable: packable(entries).count, setAside: count of isSetAside }` |
| `event.packSteps` | `packSteps(entries)` → `[{ phase: <phase id>, total, done, remaining, entries: refs }]` |
| `event.assignedPeople` | `assignedPeople(entries)` |
| `event.groupByPacker` | `groupByPacker(entries, PEOPLE_NAMES)` → `[{ packer, entries: refs }]` |
| `event.clusterByKit` | `clusterByKit(entries)` → `[{ kit, entries: refs }]` |
| `event.expiringOnTrip` | `expiringOnTrip(entries, end, TODAY)` with `end = tripEndDate(E)`, or `addDays(TODAY, 14)` when that is blank → `[{ entry: entryRef, expiry, alreadyOut, daysLeft }]` |
| `event.bagLoads` | `bagLoads(entries, n, containerLimits(LISTS))` as returned |
| `event.packingFlags` | `packingFlags(entries, n)` |
| `event.tripNudge` | `tripNudge(the event, TODAY)` |

### Grouping and sorting — once
| Key | Answer |
|---|---|
| `event.groupByContainer`, `event.groupByCategory`, `event.groupBySection`, `event.groupByStorage` | the function on `E.entries` → `[{ container \| category \| label, entries: refs }]` |
| `event.sortRowsBy.<field>.<dir>` | `sortRowsBy(E.entries, valOf, { dir, num, tie })` → refs. Fields: `name` (text, `tie: null`), `storage` (text), `container` (text), `weight` (`num: true`); `dir` = `asc`, `desc`. For every field but `name`, `tie` = `byName`: `String(a.name ?? "").localeCompare(String(b.name ?? ""), undefined, { sensitivity: "base" })`. |
| `event.groupRowsBy.<field>` | **on `SE(E).entries`**: `groupRowsBy(entries, keyOf, opts)` → `[{ key, label, rows: refs }]`. `category` (`order: CATEGORIES`), `container` (`order: CONTAINERS`), `storage` (no options), `packer` (`order: PEOPLE_NAMES, emptyLabel: "Anyone"`). |

### Quantities, dates, weather
| Key | Answer |
|---|---|
| `event.qtyNights` | `qtyNights(E)` |
| `event.effectiveQty` | `{ entryId: [effectiveQty(e, n), effectiveQty(e, 0), effectiveQty(e, 7)] }` (`#<index>` for an entry with a blank id) |
| `event.bagLoads.n7`, `event.packingFlags.n7` | `bagLoads(E.entries, 7)` (default limits), `packingFlags(E.entries, 7)` |
| `event.dates` | `{ daysUntil: d = daysUntil(start, TODAY), countdown: countdownLabel(d), nightsBetween(start, end), tripEndDate(E), endFromNights(start, E.nights), monthKeyStart, monthKeyEnd, orderRange(start, end), orderRangeReversed: orderRange(end, start) }` |
| `event.tripNudge.sweep` | on `SE(E)` (a blank `startDate` becomes TODAY): for `d` in `40 30 8 7 2 1 0 -1` → `{ "<d>": tripNudge(event, addDays(startDate, -d)) }` |
| `event.rangeCells` | `monthGrid(monthKey(start), 1).days.map(day => rangeCellState(day.iso, start, end))`; `null` when the event has no start month |
| `event.deriveWeather`, `event.weatherGear`, `event.pendingWeatherItems`, `event.weatherSuggestions`, `event.eventCoords` | the function on `E` (and `LISTS` where it takes lists), as returned |
| `event.weatherSuggestions.synth` | on a copy of `E` with `entries = []` and `weather` = `coerceEvent({ weather: F }).weather`, where `F = { place: "Testville, XX", lat: 12.25, lon: -12.25, fetchedAt: NOW, daily: [ {date: d0, code: 61, tmax: 12.5, tmin: 4.5, precipProb: 80, wind: 10}, {date: addDays(d0, 1), code: 1, tmax: 27.5, tmin: 15.49, precipProb: 49.5, wind: 35}, {date: addDays(d0, 2), code: 73, tmax: -0.5, tmin: -2.5, precipProb: 0, wind: 34.4} ] }` and `d0 = E.startDate` or TODAY → `{ derived: deriveWeather, suggestions: weatherSuggestions(·, LISTS), coords: eventCoords }` |

### Export, sharing, presets, review
| Key | Answer |
|---|---|
| `event.totalListRows` | `totalListRows(E, LISTS)` as returned |
| `event.tripBundle` | `buildTripBundle(E, NOW)` → `{ app, kind, version, exportedAt, event: EVENT shape whose entries are SLIM ENTRY shapes }`. In a slim entry `sub` is the non-empty sub-item **names** (absent when there are none) and `ownedBy` is `shareSafeOwner(ownedBy)` (absent when blank). |
| `event.tripBundle.leaks` | on the bundle itself, `b = buildTripBundle(E, NOW)`, before any shape is applied: `{ reservedOnBundle: those of SYNC_RESERVED_KEYS that are keys of b, reservedOnEvent: … of b.event, entriesWithReserved: how many of b.event.entries have either key, addressInside: whether JSON text of b matches the §8 address pattern }`. `E` still carries both keys on the event and on its entries (§4.1), so this is the model's stripping, on real data. Swift: inspect the bundle as it would be written to a file or a link. Required on the owner's data: `[]`, `[]`, `0`, `false`. |
| `event.tripBundle.parsed` | `parseTripBundle(JSON text of buildTripBundle(E, NOW))` → EVENT with `id` = `"<id>"`, `createdAt`/`updatedAt` = `"<now>"`, every entry `id` = `"<id>"` |
| `event.tripLink` | `encodeTripLink(E, NOW)` → `{ fits: false, roundTrip: null }` when it returns null; else `{ fits: true, prefix: first 4 characters, roundTrip: decodeTripLink(link without its first 4 characters) in the same form as tripBundle.parsed }`. **The link string itself is not compared** — see N1 in §16. |
| `event.packedCanonical` | with `text = CJ(this document's own answer to event.tripBundle)`: `{ packed: packShare(text), textLength: text's UTF-16 length, roundTrip: unpackShare(packed + ".") == text }`. **`packed` is compared byte for byte** — this is the LZW + base64url test on a whole real trip. |
| `event.presetConfig` | `presetConfigFromEvent(E)` |
| `event.applyPresetConfig` | `applyPresetConfig(E, presetConfigFromEvent(EVENTS[(i + 1) % EVENTS.count]))`, then `presetConfigFromEvent` of the result |
| `event.applyReview.real`, `event.applyReview.synth`, `event.applyReview.synthUnticked` | event = `E` / `SE(E)` / `SE(E)` with every `checked = false`. On one copy `ls` of LISTS: `changed = applyReview(event, ls, NOW)` → `{ changed: ids in returned order, stats: { listId: { itemId: stats } } for the items of changed lists whose stats.lastReviewed == NOW, prune1, prune2 }` where `pruneN = pruneSuggestions(ls, { minTrips: N })` on the **same mutated** `ls` → `[{ listId, listName, item: itemRef, stats, reason, times }]` |
| `event.itemFromEntry` | for entries at index < 10, or with `custom` true: `{ "<index>": itemFromEntry(entry) }` → ITEM with `id` = `"<id>"` |

## 10. Probe trips

`base = coerceEvent({ id: "probe", name: "Probe", mode: "trip", activities: ids of every list in LISTS with a blank role (in order), transport: "Car", season: "Summer", contexts: [], weatherOn: [], catering: "mixed", entries: [] })`.

`probe.buildTotalEntries`, entity `<name>` = `buildTotalEntries(base with one patch, LISTS)` → `[buildRef]`, for:
`baseline`; `season=<s>` for each of SEASONS; `transport=<t>` for each of TRANSPORTS;
`catering=<id>` for each of CATERING; `contexts=<c>` (`contexts: [c]`) for each of
CONTEXTS; `contexts=Indoor+Race`; `mode=quick`; `weatherOn=all`
(`WEATHER_CONDITION_IDS`); `activities=reversed`.

`probe.weatherGear`, entity `baseline` = `weatherGear(base, LISTS)` as returned.

## 11. The whole library

| Key | Entity | Answer |
|---|---|---|
| `library.containerNames`, `library.containerLimits` | `*` | the function on LISTS |
| `library.backupCounts` | `*` | `backupCounts({ lists: LISTS, events: EVENTS, actions: ACTIONS })` |
| `library.orderActivities` | each of GROUP_IDS, and `""` | `orderActivities(gid, LISTS where group == gid and role is blank)` → ids. Plus entity `WET-reversed`: the WET lists handed over in reverse order. |

### The relational core
`CAT = buildCatalog(LISTS)`. Its ids are minted, so: item `n` of `CAT.items` is
written `I<n>`, membership `n` of `CAT.memberships` is `M<n>`, and every `itemId`,
`_itemId`, `_memId` pointing at one is written the same way.

| Key | Entity | Answer |
|---|---|---|
| `library.buildCatalog.items` | `*` | ITEM shapes |
| `library.buildCatalog.memberships` | `*` | MEMBERSHIP shapes |
| `library.buildCatalog.templates` | `*` | LIST shapes (no items) |
| `library.resolveTemplate` | list id | `resolveTemplate(template, CAT.items, CAT.memberships)` → LIST |
| `library.resolveTemplate.drift` | list id | the resolved items against the originals (`LISTS[i].items` with a non-blank name), index by index: `{ original, resolved, drift: [{ index, fields }] }` — `fields` = those of `name container phase itemType qty note section seasons contexts transports catering weather category weight storage swedish packer ownedBy` whose canonical values differ. This is how much a restore changes the data; both sides must agree on it. |
| `library.resolveTemplateItems` | list id | `resolveTemplateItems(template, a Map of CAT.items by id, CAT.memberships reversed)` → `["I<n>\|name\|container\|phase"]` |
| `library.resolveItemAlone` | `*` | first 25 of `CAT.items` → `resolveItemAlone(item)` → ITEM |
| `library.applyIntrinsic` | `*` | first 25 of `CAT.items`: `src` = the first item in LISTS (list order, then item order) with the same `normName(name)`; `applyIntrinsic(item, src)` → ITEM |
| `library.planContainerMigration` | `*` | `planContainerMigration(CAT.items, CAT.memberships, CAT.templates)` → `{ defaults: {I: container}, effective: {M: container}, itemChanges: [{id, container}], memChanges: [{id, container}] }` |
| `library.planContainerMigration.legacy` | `*` | first rewrite a copy into the pre-v108 shape — every membership `container = its own \|\| its template's default \|\| its item's container \|\| ""` (all read before any item is changed), then every item `container = "Carry-on / hand luggage"` — then as above |
| `library.decompose` | list id | the save path. For each item of `L` with a non-blank name, `order` counting from 0: `cat = catalogItemFromResolved(it)`; `m = membershipFromResolved(cat, L.id, it, order)`; `back = resolveMembership(cat, m, templateDefaults(L))` → `[{ membership: MEMBERSHIP, resolved: ITEM }]`, every minted id (`id`, `itemId`, `_itemId`) = `"<id>"` |
| `library.decompose.inferred` | list id | the same, but the item handed to `membershipFromResolved` is a copy **without** `_ovContainer` and `_ovPhase`, and with `_tplContainer = templateDefaults(L).container` → `[MEMBERSHIP]` |
| `library.containerOverrideFor` | list id | per item: `containerOverrideFor(it.container, templateDefaults(L).container, it._defContainer or "")` |
| `library.mapSectionAcrossTemplates` | `<A id>><B id>`, `B` = the next list (wrapping) | `{ sectionId: mapSectionAcrossTemplates(sectionId, A, B) }` for each section of `A`, plus `"(unknown)"` for the id `"no-such-section"` and `"(blank)"` for `""` |
| `library.linkFromResolved` | list id | `it` = first item of `L` (none → `null`); `linkFromResolved(it, it._itemId \|\| it.id, { section: mapSectionAcrossTemplates(it.section, L, next list) })` → only the keys `_itemId _link name seasons contexts transports catering weather kit qty note itemType section _ovContainer _ovPhase` |
| `library.containerDefaultsFrom` | `*` | rows `{ itemId: it.id, container: it.container }` for every item of every list, in order → `containerDefaultsFrom(rows)` as an object |

### Overview, duplicates, sorting
| Key | Entity | Answer |
|---|---|---|
| `library.catalogRows` | `*` | `ROWS(LISTS)` → `[{ id, name, item: itemRef, templates: [{id, name, role}] }]` |
| `library.duplicateGroups` | `*` | `duplicateGroups(ROWS(LISTS))` → `[{ key, exact, rows: [row id] }]` |
| `library.duplicateIds` | `*` | `duplicateIds(ROWS(LISTS))` (a Set) |
| `library.sortRowsBy.<field>.<dir>` | `*` | `sortRowsBy(ROWS(LISTS), r => r.item.<field>, …)` → row ids. `name` (text, `tie: null`); `manufacturer`, `storage` (text, `tie: byName` on the ROW's `name`); `weight`, `price` (`num: true`, `tie: byName`). |
| `library.groupRowsBy.<field>` | `*` | **on `ROWS(SL)`** → `[{ key, label, rows: [row id] }]`. `category` (`order: CATEGORIES`), `storage` (`order: PLACES_IN`, each entry as `String()` reads it — `groupRowsBy` does that itself), `ownedBy` (no options), `condition` (`keyOf = itemConditionLabel(r.item.condition)`, `order` = the labels of ITEM_CONDITIONS). |

### Care, shopping, actions — each asked twice: `<key>` with `(LISTS, ACTIONS)`, `<key>.synth` with `(SL, SA)`
| Key | Answer |
|---|---|
| `library.maintenanceList` | `maintenanceList(lists, TODAY)` → `[{ listId, listName, listNames, item: itemRef, status }]` |
| `library.maintenanceStatus` | for every row of `ROWS(lists)` with `hasCare(r.item)`: `{ rowId: maintenanceStatus(r.item, TODAY) }` |
| `library.careSections` | `careSections(maintenanceList(lists, TODAY))` → `[{ key, state, label, fold, rows: [item id] }]` |
| `library.maintenanceSummary` | as returned |
| `library.maintenanceByDate` | `{ date: [item id] }` |
| `library.logMaintenance` | for every row of the maintenance list: `{ itemId: logMaintenance(copy of item, TODAY, "parity").maintenance }` |
| `library.shoppingSuggestions` | `shoppingSuggestions(ROWS(lists).map(r => r.item), actions, TODAY)` → `[{ item: itemRef, reason }]` |
| `library.shoppingReason` | `{ rowId: shoppingReason(r.item, TODAY) }`, only where it is not blank |
| `library.openShoppingCount` | `openShoppingCount(actions)` |
| `library.compareActions` | `actions.sort(compareActions)` → ids |
| `library.pruneSuggestions` | `[minTrips 1, minTrips 2]`, each `pruneSuggestions(lists, { minTrips })` → `[{ listId, item: itemRef, reason, times }]` |

### Does this device hold the whole copy?
`referenced = referencedListValues({ lists: LISTS, events: EVENTS, actions: ACTIONS })`;
`inForce = { places: PLACES_IN, owners: OWNERS_IN, conditions: ITEM_CONDITIONS, people: PEOPLE, phases: PHASES }`.

| Key | Entity | Answer |
|---|---|---|
| `library.referencedListValues` | `*` | `{ <kind>: the Set, display: { <kind>: the Map } }` for each of AUDITABLE_KINDS |
| `library.auditList` | each of AUDITABLE_KINDS, and `presets` | `auditList(kind, referenced, inForce[kind])` |
| `library.auditDeviceLists` | `signedIn` / `signedOut` / `emptyLists` | `auditDeviceLists({ referenced, inForce, signedIn: true \| false \| true, hasCatalogue: true })`; `emptyLists` hands every kind an empty list |

### Events as a set
`todays` = the distinct, non-blank values of: TODAY, and for every event with a `tripEndDate`: that date plus 0, 1, 30 and 31 days.

| Key | Entity | Answer |
|---|---|---|
| `library.sortEventsForList` | each of `todays` | `sortEventsForList(EVENTS, t)` → ids |
| `library.tripsAwaitingReview` | each of `todays`, plus `<TODAY>/window=365` | `tripsAwaitingReview(EVENTS, t)` (or `(EVENTS, TODAY, 365)`) → `[{ event: id, endedDaysAgo }]` |
| `library.eventsNeedingCoords`, `library.placesVisited`, `library.tripPath`, `library.mostVisited` | `*` | on EVENTS: ids / `[{ key, place, lat, lon, events: ids }]` / as returned / that place shape or `null` (`mostVisited(placesVisited(events))`). **`placesVisited` reads the clock (D2).** |
| the same four with `.synth` | `*` | on EVENTS where every event with no `eventCoords` gets `geo = coerceGeo({ lat: 12.25 + (i % 2) * 0.5, lon: -(12.25 + (i % 2) * 0.5), place: i % 2 ? "Testville, XX" : "" })`, and when `i % 2 == 0` its `destination` blanked (`i` = index in EVENTS). The quarter degrees are deliberate — H9 in §18. |
| `library.mostVisited.doubled` | `*` | `mostVisited(placesVisited(that synth list twice over))` |

### Backup reminders
`groups = (EVENTS, LISTS, ACTIONS, KITS)`; `changedAt = newestChangeAt(groups…)`, `firstUseAt = oldestCreatedAt(groups…)`.

| Key | Entity | Answer |
|---|---|---|
| `library.backupClock` | `*` | `{ newest: changedAt, oldest: firstUseAt }` |
| `library.backupState` | case name | `backupState({ lastBackupAt, changedAt, firstUseAt, hasData: true, now: NOW })` with `lastBackupAt` = `exportedAt`: `B.exportedAt` · `never`: `""` · `today-13` / `today-14` / `today-45`: `addDays(TODAY, -N) + "T08:00:00.000Z"` · `date-only`: `addDays(TODAY, -20)` · `future`: `addDays(TODAY, 3) + "T08:00:00.000Z"`. Plus `noData` (`lastBackupAt: ""`, `hasData: false`) and `clock`: `backupState({ lastBackupAt: "", changedAt: "", firstUseAt: "", hasData: true })` — no `now`, so D2. |

## 12. The Settings lists and their shared rows

Inputs by kind: `conditions` → CONDITIONS_IN · `people` → PEOPLE_IN · `places` → PLACES_IN · `owners` → OWNERS_IN ·
`presets` → `prefs.presets` (if a non-empty array) **followed by** one per event `{ name: "Preset <i+1>", createdAt: E.createdAt, config: presetConfigFromEvent(E) }`, then `{ name: "  preset 1 ", createdAt: "", config: { mode: "quick" } }` and `{ name: "No config" }` (both must be dropped) ·
`grab` → from `prefs.grab = { items: {gid: [names]}, meta: {gid: {label, icon, tone}} }`: the union of both objects' keys in UTF-16 order, each → `{ id: gid, items: items[gid] or [], label, icon, tone }` (missing → `""`).

`ALLROWS` = for each kind in SHARED_KINDS order, `sharedRowsFrom(kind, input)`, concatenated.

| Key | Entity | Answer |
|---|---|---|
| `settings.rows` | kind | `sharedRowsFrom(kind, input)` → ROW shapes |
| `settings.rowsOfKind` | kind | `sharedRowsOfKind(ALLROWS reversed, kind)` → ids |
| `settings.isFactoryList` | kind | `{ inForce: isFactoryList(kind, input), factory: isFactoryList(kind, defaultListFor(kind)), defaultList: defaultListFor(kind) }` |
| `settings.back` | kind | from `ALLROWS reversed`: `conditions` → `conditionsFromRows` as CONDITIONs · `people` → `peopleFromRows` as PERSONs · `places`, `owners` → `{ ordered: orderedNamesFromRows(rows, kind), az: namesFromRows(rows, kind) }` · `presets` → `presetsFromRows` · `grab` → `grabFromRows`, as returned |
| `settings.ownersByUsage` | `*` | `counts` = Map `normName(ownedBy)` → number of distinct `(_itemId \|\| id)` over all LISTS items (blank owners skipped); `names` = OWNERS_IN's names, or when that is empty the first-seen trimmed spelling of each owner → `{ counts, order: ownersByUsage(names, counts) }` |
| `settings.grabShare` | gid | `code = encodeGrabShare({ name: label \|\| gid, icon, tone, items })` → `{ code` (compared byte for byte; key order `k v n x i c`)`, decoded: decodeGrabShare("Try this: https://example.invalid/#/g/" + code + ".") }` |

## 13. Every real string, and every id

**`FIXED`** (invented; `<U+XXXX>` is that one code point):
`""` · `"  Mixed   CASE  "` · `"Sun-glasses"` · `"sunglasses"` · `"Sun glasses"` · `"Glass"` · `"Boss"` · `"Socks"` · `"ÅÄÖ åäö"` ·
`"Tab<U+0009>and<U+000A>newline"` · `"e<U+0301> combining"` · `"😀 emoji 👍🏽"` · `"nbsp<U+00A0><U+00A0>gap"` · `"<U+FEFF>bom lead"` ·
`"nel<U+0085><U+0085>gap"` · `"thin<U+2009><U+2009>gap<U+2028>"` · `"İstanbul ǅ ß"` (U+0130, U+01C5, U+00DF) · `"½ litre №5"` (U+00BD, U+2116)

**`POOL`** = FIXED plus every non-empty string among: each list's `name`,
`defaultContainer`, section names, and its items' `name swedish storage ownedBy packer kit container category`;
each event's `name`, `destination`, and its entries' same eight fields plus `section`;
each action's `text`, `itemName`; kit names; thing names; PLACES_IN and OWNERS_IN
(a string, or an object's `name`); PEOPLE names. Distinct, sorted by UTF-16 code unit.

| Key | Entity | Answer |
|---|---|---|
| `strings.normName`, `strings.dupeKey` | each string of POOL | the function's result |
| `strings.collation` | `variant` / `base` | POOL sorted (stable) by `a.localeCompare(b)` / by `a.localeCompare(b, undefined, { sensitivity: "base" })` |
| `strings.compare` | each string `s = POOL[i]` | for `step` in `1, 37`: `other = POOL[(i + step) % POOL.count]` → `[{ with: other, variant: sign of s.localeCompare(other), base: sign with sensitivity base }]` (sign = -1, 0, 1). When `strings.collation` disagrees, this says which two strings. |
| `strings.share` | each of FIXED ∪ list names ∪ section names | `{ b64: toBase64Url(s), back: fromBase64Url(b64) == s, packed: packShare(s), unpacked: unpackShare(packed) == s }` |
| `strings.newPhase` | each of: list names, PHASES labels, `"!!!"`, `"Ärlig Test 2"` | `newPhase(label, copy of PHASE_IDS, { leadDays: 3 })` → PHASE. When the trimmed, lower-cased label holds no `a–z` or `0–9`, the id is clock-made and is written `"<time-id>"`. |
| `strings.newCondition` | the same labels | `newCondition(label, copy of ITEM_CONDITION_IDS)`, same `"<time-id>"` rule |
| `strings.email` | `anna.berg@example.com` · `m.s@example.org` · `x@y.z` · `first_last+tag@example.com` · `"  spaced.name@example.com "` · `UPPER.case@example.com` · `élan.vital@example.com` · `-lead@example.com` · `noatsign` · `two@@example.com` · `a b@example.com` · `""` · PEOPLE_NAMES | `{ looksLikeEmail, ownerName: ownerNameFromEmail }` |
| `strings.shareSafeOwner` | the `strings.email` addresses, PEOPLE_NAMES, every `ownedBy` of every item and entry, and: `Anna Berg` · `Anna <anna.berg@example.com>` · `"  Two   Spaces  "` · `name@host` · `mailto:someone@example.com` · `at @ sign alone` · `A very long owner name that runs well past forty characters` · thirty-eight `x` then `" late@example.com"` | `[shareSafeOwner(v), shareSafeOwner(v, 10)]` |
| `strings.personColor` | PEOPLE_NAMES, `Zed Guest`, `amy guest`, `Åsa`, `""`, and every `packer` and `ownedBy` of every item and entry | `{ roster: personColor(name, PEOPLE), hashed: personColor(name, []) }` |
| `strings.qty` | `""` `2` `0` `-1` `2.5` `abc` `" 3 "` `1e2` `0x10` `Infinity` `3 pairs` `١٢` (Arabic-Indic one-two), and every `qty` of every item and entry | `[effectiveQty({qty}, 0), effectiveQty({qty, perNight: true}, 0), effectiveQty({qty, perNight: true}, 5)]` |
| `ids.phase` | `""`, `no-such-phase`, DEFAULT_PHASES ids, PHASE_IDS, every `phase` of every item and entry, every action's `whenPhase` | `{ known: phase(id) != null, label, emoji, color, leadDays, order, fallback: phaseOrFallback(id) as PHASE }` |
| `ids.condition` | `""`, `mystery`, the factory ids, ITEM_CONDITION_IDS, every item's `condition` | `{ known, label: itemConditionLabel, tone: conditionTone, replaces: conditionReplaces }` |
| `ids.chargeType` | `bogus`, CHARGE_TYPE_IDS, every item's `chargeType` | `{ id: chargeType(id).id, label, short }` |
| `ids.labels` | `*` | one object: `catering:<id>` → `cateringLabel` (ids + `bogus`) · `group:<id>` → `groupLabel`, `groupHint:<id>` → `group(id)?.hint ?? null` (GROUP_IDS, `""`, `bogus`) · `rowId:<kind>` → `sharedRowId(kind, "  Garage   SHELF ")` · `retire:<id>` → `retireReasonLabel` (ids, `""`, `bogus`) · `priority:<id>` → `actionPriorityLabel` (ids, `""`, `bogus`) · `kitEmoji:<CJ of the kit>` → `kitEmoji` for `{emoji: " 🎒 "}`, `{emoji: ""}`, `{}` · `snooze:<level>` → `backupSnoozeDays` for `urgent due ok` |
| `ids.weatherCode` | `-1` … `100` | `weatherCode(n)` |

## 14. Fixed calculations — the same on any data

| Key | Entity | Answer |
|---|---|---|
| `calc.constants` | `*` | every exported constant by name, except `PHASES PHASE_IDS ITEM_CONDITIONS ITEM_CONDITION_IDS` (those are §6), each written **as the JS module holds it** — which a typed port has to know: `DEFAULT_PEOPLE` entries are `{ name, color }` (no `id`); `DEFAULT_PHASES` entries have no `order`; `DEFAULT_FIELDS` is the object `{ container: "_defContainer", phase: "_defPhase" }`; a `WEATHER_SUGGESTIONS` entry is `{ name, category }` plus `liquid: true` only where it is; `ACTIVITY_ORDER`, `AUDIT_LABELS`, `CONTAINER_LIMITS_KG`, `WEATHER_THRESHOLDS` are objects. The 61 names: `ACTION_PRIORITIES ACTION_PRIORITY_IDS ACTIVITY_ORDER AUDITABLE_KINDS AUDIT_LABELS AUDIT_STRAY_TOLERANCE BACKUP_DUE_DAYS BACKUP_URGENT_DAYS CATEGORIES CATEGORY_DEFAULT CATERING CHARGE_TYPES CHARGE_TYPE_IDS CONDITION_TONES CONTAINERS CONTAINER_LIMITS_KG CONTAINER_LIST_NAME CONTAINER_ROLE CONTEXTS CONTEXTUAL_FIELDS CURRENCIES DEFAULT_FIELDS DEFAULT_ITEM_CONDITIONS DEFAULT_PEOPLE DEFAULT_PHASES DEFAULT_STORAGE_LOCATIONS EXPIRY_SOON_DAYS GRAB_SHARE_ITEMS_MAX GRAB_SHARE_ITEM_MAX GRAB_SHARE_KIND GRAB_SHARE_NAME_MAX GROUPS GROUP_IDS INTRINSIC_FIELDS KIT_DEFAULT_EMOJI LAUNDRY_CAP_NIGHTS LIST_SHARE_ITEMS_MAX LIST_SHARE_KIND LIST_SHARE_NAME_MAX MAINTENANCE_INTERVALS MAINTENANCE_SOON_DAYS MAINTENANCE_UPCOMING_DAYS MAX_PHOTOS PERSON_COLORS PHASE_DEFAULT_EMOJI RETIRE_REASONS RETIRE_REASON_IDS REVIEW_WINDOW_DAYS SEASONS SHARED_KINDS SHARE_ZIP_PREFIX SYNC_RESERVED_KEYS TEMPLATE_COLORS TEMPLATE_DEFAULT_EMOJI TRANSPORTS TRIP_KIND TRIP_LINK_MAX WEATHER_CONDITIONS WEATHER_CONDITION_IDS WEATHER_SUGGESTIONS WEATHER_THRESHOLDS` |
| `calc.constructors` | `*` | one object, minted ids `"<id>"`, minted stamps `"<now>"`: `newItem` = `newItem()` · `newItemNamed` = `newItem({ name: "Test socks", qty: "2", weight: 40, phase: "door", perNight: true })` · `newList` = `newList({ name: "Test list", sections: [{id: "", name: " Tools "}, {id: "", name: ""}, {id: "keep-me", name: "Kept"}, {id: "keep-me", name: "Twin"}] })` (the id `keep-me` is written as it is) · `newEvent` = `newEvent({ name: "Test trip", nights: 3, mode: "quick", weatherOn: ["rain", "fog"] })` · `newAction` = `newAction({ text: "Test", priority: "urgent", whenDate: "2026-1-1" })` · `newKit` = `newKit({ name: "Test kit", itemIds: ["a", "b", "a", ""] })` · `newPerson` = `newPerson({ name: "  Test  ", color: "blue" })` · `newMembership` = `newMembership()` · `newSection` = `{ id: "<id>", name: newSection("  Tools ").name }` |
| `calc.coerceHostile` | case | **decode the JSON text below**, coerce, write the shape |
| `calc.tripBundleIncoming` | case | `parseTripBundle(the JSON text below)` → EVENT in the `event.tripBundle.parsed` form (`id` = `"<id>"`, stamps = `"<now>"`, entry ids = `"<id>"`) |
| `calc.tripBundleOutgoing` | `*` | `b = buildTripBundle(coerceEvent(the JSON text below), NOW)` → `{ bundle: b in the event.tripBundle form, leaks: as event.tripBundle.leaks }` |
| `calc.countdownLabel` | `*` | `{ "<d>": countdownLabel(d) }` for `null -10 -3 -2 -1 0 1 2 3 10` (key `"null"`) |
| `calc.qtyNights` | `*` | `{ "<n>/<laundry>": qtyNights({ nights: n, laundry }) }`, n = 0…10, laundry `false`, `true` |
| `calc.backupShrinks` | `*` | `{ "<p>><n>": backupShrinks({items: p}, {items: n}) }` for `0>0 0>5 10>0 10>4 10>5 10>6 3>1` |
| `calc.coerceGeo` | `*` | `coerceGeo` of — `valid` `{lat: 58.5, lon: 16.25, place: "Testville"}` · `strings` `{lat: "12.5", lon: "-7"}` · `tooFarNorth` `{lat: 91, lon: 0}` · `tooFarEast` `{lat: 0, lon: 180.5}` · `edge` `{lat: -90, lon: 180}` · `notNumbers` `{lat: "x", lon: 1}` · `blankStrings` `{lat: "", lon: ""}` · `nothing` `null` · `placeNotString` `{lat: 1, lon: 2, place: 7}` |
| `calc.photos` | `*` | with `item = { photos: ["ref-1", "data:image/png;base64,AAAA", "", 5, "ref-2"] }`: `{ isPhotoRef: for "ref-1", "data:x", "", null; photoRefs(item); inlinePhotos(item); hasInline: hasInlinePhotos([item]); hasInlineNone: hasInlinePhotos([{photos: ["ref-1"]}]) }` |
| `calc.dates` | each date of: TODAY, `2024-02-29`, `2026-12-31`, `2026-01-01`, `2026-03-29`, `2026-10-25`, `""`, `not-a-date`, `2026-13-01`, every event's `startDate`/`endDate`, every action's `whenDate`, every item's `acquired`, `expiry`, `warranty`, `maintenance.lastDone`, `maintenance.log[].date` | `{ addDays: { "<n>": addDays(d, n) } for -366 -1 0 1 30 365, daysBetween(d, TODAY), daysUntil(d, TODAY), monthKey(d), endFromNights(d, 3), nightsToToday: nightsBetween(d, TODAY), nightsFromToday: nightsBetween(TODAY, d) }` |
| `calc.monthGrid` | `<month>/<weekStart>` | months = `monthKey(TODAY)`, `2024-02`, `2026-12`, `2027-01`, every event's start and end month (non-blank), each with the month before and after it (`shiftMonth ±1`); weekStart `1` and `0` → `{ key, year, month, days: ["<iso>" + ("*" when not inMonth)] }`. Plus entity `invalid`: `monthGrid("2026-1", 1)` as returned. |
| `calc.shiftMonth` | each of those months, `x`, `2026-1` | `{ "<n>": shiftMonth(m, n) }` for `-13 -12 -1 0 1 12 13` |
| `calc.rangeCellState` | `*` | `{ "<d>\|<a>\|<b>": rangeCellState(d, a, b) }` for ranges `(2026-09-10, 2026-09-14)`, `(2026-09-10, "")`, `(2026-09-10, 2026-09-10)`, `("", 2026-09-14)` × days `2026-09-09 2026-09-10 2026-09-12 2026-09-14 2026-09-15 ""` |
| `calc.lzw` | text name | texts: `empty` `""` · `one` `"a"` · `run` forty `a` · `classic` `"TOBEORNOTTOBEORTOBEORNOT"` · `unicode` `"Åäö – “quotes” 😀 "` (en dash U+2013, curly quotes U+201C/U+201D, trailing space) twenty times · `lists` = `CJ(this document's whole answer to coerce.list)` · `events` = `CJ(… coerce.event)` (`CJ({})` when absent). · `both` = `lists` text followed by `events` text. With `raw` = UTF-8 bytes, `z = lzwCompress(raw)`, `b64 = bytesToBase64Url(z)` → `{ textBytes, textHash: FNV(raw), zipBytes, zipHash: FNV(z), b64Head: first 64 chars, b64Tail: last 64, b64Length, roundTrip: lzwDecompress(z) equals raw, b64RoundTrip: base64UrlToBytes(b64) equals z }`. **FNV** = FNV-1a 32-bit: `h = 2166136261`; per byte `h = (h XOR byte) × 16777619 mod 2^32`. On the owner's backup `lists` (~600 kB) widens the LZW codes to the full 16 bits, and `both` (~1 MB) goes on to fill the 65 536-entry dictionary, after which the encoder stops learning — a branch no name or single trip ever reaches. |

**`calc.coerceHostile` inputs** — each is JSON **text**; parse it, then coerce. (📦 is U+1F4E6.)

| Case | Call → shape | JSON |
|---|---|---|
| `item` | `coerceItem` → ITEM | `{"id":"x","name":"Hostile","seasons":"Summer","weather":["rain","fog",3],"phase":7,"category":"","itemType":"task","chargeType":"usb-d","stats":{"packed":2.9,"used":-1,"unused":"3","lastReviewed":5},"weight":"12","liquid":1,"section":null,"photos":["a","",null,"b","c","d","e","f"],"maintenance":{"notes":3,"intervalDays":90.7,"lastDone":"2026-1-1","log":[{"date":"2026-02-01","note":1},{"date":"nope"},{"date":"2025-12-31","note":"older"}]},"owner":"Legacy Owner","acquired":"2026-02-3","price":-1,"condition":"  worn-out-and-then-some-more-text-to-cut-at-forty  ","retired":"yes","retiredReason":"stolen","qtyOwned":2.9,"capacityL":null,"maxKg":"7","sub":"nope"}` |
| `itemLegacyPhoto` | `coerceItem` → ITEM | `{"id":"y","name":"Legacy photo","photo":"ref-legacy","owner":"someone@example.com","maintenance":{"notes":"","link":"","intervalDays":0},"phase":"   "}` |
| `itemOwnedByWins` | `coerceItem` → ITEM | `{"id":"z","name":"Owned","ownedBy":"","owner":"Legacy Owner"}` |
| `membership` | `coerceMembership` → MEMBERSHIP | `{"id":"m","itemId":"i","templateId":"t","seasons":"x","weather":["cold","mist"],"container":5,"phase":"  door ","itemType":"task","qty":3,"note":null,"order":"2"}` |
| `membershipQtySmall` · `membershipQtyTiny` · `membershipQtyHuge` | `coerceMembership` → MEMBERSHIP | `{"id":"m2","itemId":"i","templateId":"t","qty":<n>}` with `<n>` = `0.00001` · `1.5e-7` · `1e21`. Expected `qty`: `"0.00001"` · `"1.5e-7"` · `"1e+21"` — H14. |
| `action` | `coerceAction` → ACTION | `{"id":"a","text":5,"kind":"buy","priority":"urgent","whenPhase":"  week  ","whenDate":"2026-9-1","done":"yes","createdAt":"2026-01-01T00:00:00.000Z"}` |
| `kit` | `coerceKit` → KIT | `{"id":"k","name":7,"emoji":"  ","itemIds":["a","a",3,"","b"]}` |
| `event` | `coerceEvent` → EVENT | `{"id":"e","mode":"fast","activities":"x","nights":2.7,"laundry":"","status":"finished","weather":{"daily":[{"date":"2026-09-01","code":"61","tmax":"20.5","tmin":null,"precipProb":"x"},{"code":1}],"lat":"58.5","lon":null,"place":3},"weatherOn":["snow","sleet"],"geo":{"lat":"95","lon":0},"entries":[{"name":"In a hostile event"}]}` |
| `eventNoWeather` | `coerceEvent` → EVENT | `{"id":"e2","nights":-1,"weather":{"daily":[]},"geo":{"lat":"12.5","lon":"-7","place":"Testville"}}` |
| `list` | `coerceList` → LIST | `{"id":"l","name":"Hostile list","group":"XX","role":"special","transport":"Boat","emoji":"  📦📦📦  ","color":"red","defaultContainer":4,"sections":[{"id":"s1","name":" A "},{"id":"s1","name":"B"},{"id":"s2","name":"  "}],"items":[{"name":"Inside"}]}` |
| `maintenance` | `normalizeMaintenance`, as returned | `{"notes":"Wax it","link":7,"intervalDays":"30","lastDone":"2026-03-01","log":[{"date":"2026-03-01","note":"b"},{"date":"2026-03-01","note":"a"},null]}` |
| `sections` | `normalizeSections`, as returned | `[{"id":"a","name":" One "},{"id":"a","name":"Twin"},{"id":"b"},{"id":"c","name":7},"text",{"id":"d","name":"Four"}]` |
| `sharedRow` | `coerceSharedRow(·, 4)` → ROW | `{"kind":"nonsense","key":"  Some   KEY ","name":"  N  ","order":"3","data":[1,2]}` |
| `sharedRowNull` | `coerceSharedRow(null, 2)` → ROW | — |
| `phase` | `coercePhase(·, 3)` → PHASE | `{"id":" x ","label":" L ","leadDays":400.6,"order":"2","color":"#12","emoji":"  ","task":1}` |
| `phaseLeadHalf` | `coercePhase(·, 13)` → PHASE | `{"id":"h","label":"Half","leadDays":-0.5,"color":"#ABCDEF12"}` |
| `condition` | `coerceCondition` → CONDITION | `{"id":" c ","label":" L ","tone":"loud","replace":1}` |
| `person` | `coercePerson` → PERSON, `id` = `"<id>"` | `{"name":"  P ","color":"#GGG"}` |

**`calc.tripBundleIncoming` inputs** — a bundle as an app from before v186 made it:
both reserved keys at every level, an address as the owner, sub-items taken apart.

| Case | JSON text |
|---|---|
| `oldBundle` | `{"app":"ams-packing-list","kind":"trip","version":1,"exportedAt":"2026-08-01T00:00:00.000Z","owner":"sender@example.com","realmId":"sender@example.com","event":{"name":"Old shared trip","owner":"sender@example.com","realmId":"sender@example.com","mode":"quick","startDate":"2026-08-10","status":"done","reviewedAt":"2026-08-20T00:00:00.000Z","entries":[{"name":"Tent","owner":"sender@example.com","realmId":"rlm-1","ownedBy":"sender@example.com","sub":[{"0":"P","1":"e","2":"g","3":"s"},{"name":"Guy lines"},"Mallet","",{"x":1},null],"checked":true,"used":true},{"name":"Stove","owner":"Legacy Name","sub":"nope"},{"name":"Lamp","ownedBy":"Anna <anna@example.com>"},{"name":"Mug","ownedBy":"  Anna   Berg  "}]}}` |
| `oldBundleEmoji` | `{"app":"ams-packing-list","kind":"trip","version":1,"event":{"name":"Emoji trip","entries":[{"name":"Kit","sub":[{"0":"H","1":"i","2":" ","3":"\ud83d","4":"\ude00","5":"!"}]}]}}` — the two `\u…` are ESCAPES in the JSON text: each is half of an emoji, a lone surrogate, which `JSON.parse` accepts and Foundation's parser refuses (H16). Expected `sub`: `["Hi 😀!"]`. |
| `notATrip` | `{"app":"ams-packing-list","kind":"grab","event":{"name":"x"}}` — throws (D7) |
| `noEvent` | `{"kind":"trip"}` — throws (D7) |

Expected of `oldBundle`, entry by entry — `ownedBy`, `sub`: Tent `""`, `["Pegs","Guy lines","Mallet"]` ·
Stove `"Legacy Name"` (a legacy `owner` that is a name is adopted; one that is an address is not), `[]` ·
Lamp `""`, `[]` · Mug `"Anna Berg"`, `[]`. Every entry unchecked with no `used`; the event `active`, never reviewed.

**`calc.tripBundleOutgoing` input:**
`{"id":"out","name":"Outgoing","owner":"me@example.com","realmId":"me@example.com","mode":"trip","startDate":"2026-10-01","entries":[{"id":"e1","name":"Rope","owner":"me@example.com","realmId":"me@example.com","ownedBy":"me@example.com","sub":["Sling","","Carabiner"],"weight":120,"checked":true,"used":false,"custom":true,"sourceListId":"l","sourceItemId":"i","stats":{"packed":3}},{"id":"e2","name":"Helmet","ownedBy":"Anna Berg","sub":[],"itemType":"reminder"}]}`
Expected slim entries: Rope = `{ category, name, phase, sub: ["Sling","Carabiner"], weight: 120 }` — no `ownedBy`;
Helmet = `{ category, itemType: "reminder", name, ownedBy: "Anna Berg", phase }`. (`phase` is
`defaultPhaseId()` of the §4 phases.) `leaks` = `[]`, `[]`, `0`, `false`.

A few answers worth knowing in advance, because each is a JS rule a typed decoder
gets wrong by default: `weight: "12"` → `0` (a string is not a number) but
`geo.lat: "12.5"` → `12.5` (`Number()` parses it) and `weather.lon: null` → `0`;
`leadDays: -0.5` → `0` (`Math.round` goes up); `emoji "  📦📦📦  "` → two boxes
(`slice(0, 4)` counts UTF-16 units); `item.owner: "Legacy Owner"` is adopted into
`ownedBy` only when `ownedBy` is not a string at all.

## 15. Installing a list — asked LAST

These change `PHASES` / `ITEM_CONDITIONS`. Run them after everything else, and put
the §4 lists back afterwards.

| Key | Entity | Answer |
|---|---|---|
| `calc.setPhases` | `hostile` / `empty` / `notAList` | `setPhases(parsed JSON)` → `{ phases: PHASE shapes, ids: PHASE_IDS, customised: phasesCustomised(), defaultPhaseId: defaultPhaseId(), orderOfUnknown: phaseOrder("nowhere") }`. `hostile` = `[{"id":"zeta","label":"Zeta","order":1},{"id":"alpha","label":"Alpha","order":1},{"id":"alpha","label":"Twin","order":0},{"id":"","label":"No id"},{"id":"nolabel"},{"id":"Beta","label":"Beta","order":1},{"id":"last","label":"Last","order":"7","leadDays":-5,"task":true},{"id":"first","label":"First","order":-2}]` · `empty` = `[]` · `notAList` = `{"id":"x","label":"X"}`. (Three phases tie on `order: 1`; the tiebreak is `id.localeCompare` — `alpha`, `Beta`, `zeta`, which `<` would order differently.) |
| `calc.setItemConditions` | `hostile` / `empty` | `setItemConditions(parsed JSON)` → `{ conditions, ids, replaces: conditionReplaces("gone"), reason: shoppingReason({ condition: "gone" }, TODAY) }`. `hostile` = `[{"id":"ok","label":"Fine","tone":"warn"},{"id":"ok","label":"Twin"},{"id":"","label":"No id"},{"id":"gone","label":"Gone","tone":"danger","replace":"yes"},{"label":"No id either"}]` · `empty` = `[]` |

---

## 16. What is deliberately NOT compared, and why

| # | What | Why |
|---|---|---|
| N1 | The raw `encodeTripLink` string | It is `packShare(JSON.stringify(bundle))`, and that JSON's key order is whatever order the event object's keys happen to be in — it comes from the backup file, not from the code. A typed port cannot and need not reproduce it; what matters is that each side can read the other's links. Compared instead: `fits`, the decoded round trip, and `event.packedCanonical` (the same bytes on both sides, through the same LZW + base64url). `fits` is only meaningful away from the 30 000-character limit; real trips pack to 4–15 k. |
| N2 | `id()` | Random by design. Everything that mints one is covered with markers (D3). |
| N3 | Minted timestamps | D4. |
| N4 | `conditionsToRows`, `namesToRows`, `presetsToRows`, `grabToRows` | Reached through `sharedRowsFrom` (§12), which is what the app calls; not asked a second time directly. |
| N5 | `Date.parse` of an impossible day (`2026-02-30`), and of the short forms `2026` / `2026-07` | V8 (Node) rolls the day into March and reads the short forms as the 1st; JavaScriptCore (Safari, where the app really runs) says invalid. There is no single JS truth to match, so it is not asked. The port follows **V8** — the engine this reference and the model's own tests run on — through its ONE date parser (`JSDay` in `JSSemantics.swift`), so care dates and trip dates can never disagree with each other; `isYMD` keeps such text out of stored dates either way. |
| N6 | Keys outside the shapes | §3. |
| N7 | `photos` in the backup, and everything in `db.js` / `app.js` | Not the model. |

## 17. What the contract requires for `sub`, `ownedBy`, `u` and the reserved keys

Contract 1 stepped around two web-app bugs (a trip bundle took string sub-items
apart into character maps; a shared template carried the sync account's address
in `u`). Model v186 fixed both, the workarounds are gone, and the port is now
held to the fixed behaviour:

| What | Required |
|---|---|
| `sub`, everywhere | An array of strings, written as the model left it. The contract reassembles nothing. |
| `sub` going OUT in a trip bundle (`slimEntry`) | each element through `subName` (a string as it stands; an object with a string `name` → that; an object with `"0","1",…` string values → those joined, stopping at the first missing index; anything else → `""`), blanks dropped; the key is absent when nothing is left. [`event.tripBundle`, `calc.tripBundleOutgoing`] |
| `sub` coming IN (`parseTripBundle` → `incomingEntry`) | the same `subName` + drop-blanks, only when the entry has a `sub` key at all; a `sub` that is not an array → `[]`. [`calc.tripBundleIncoming`] |
| `ownedBy` going OUT in a trip bundle | `shareSafeOwner(ownedBy)`; absent when blank. [`event.tripBundle`, `calc.tripBundleOutgoing`] |
| `ownedBy` coming IN | `shareSafeOwner(who)`, where `who` = the entry's `ownedBy` if that is a string, else its legacy `owner`. Always set, so it is `""` rather than missing. |
| `u` in a template code | written from `shareSafeOwner(it.ownedBy)`, only when not blank, in its fixed place in the key order (§8); read back into `ownedBy` through `shareSafeOwner` again. The reserved `owner` is never read. [`list.share.encoded`, `list.share.decoded`, `list.share.imported`] |
| `shareSafeOwner(v, max = 40)` | `String(v ?? "")`, every whitespace run (JS `\s` — H5) → one space, trimmed; then **blank if an address is anywhere inside** (`/[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+/`, tested BEFORE cutting); else the first `max` UTF-16 units — not trimmed again after the cut. [`strings.shareSafeOwner`] |
| `SYNC_RESERVED_KEYS` = `owner`, `realmId` | Never in any shape. Going out: dropped from the bundle's event and from every entry. Coming in: dropped from the event and from every entry before coercion. [`event.tripBundle.leaks`, `calc.tripBundleOutgoing`, `calc.tripBundleIncoming`, `calc.constants`] |

One web-app quirk remains that the port must copy to match:

- **Q3 — `referencedListValues` reads `action.phase`**, a field actions do not
  have (theirs is `whenPhase`). So actions contribute nothing to the phases audit.
  To match, the port must also read nothing there.

## 18. JavaScript behaviour that is hard to reproduce

Every one of these is exercised by a question above; the key in brackets is where
a mistake will show.

- **H1 Collation.** `localeCompare` is ICU collation, not `<`: `a A å ä ö v w z Z`
  in `en-US`, accents and case decided only after the letters, punctuation not
  ignored. Two strengths are used (D6). Used by: `orderActivities`, `groupByKey`
  (container / category), `groupByStorage`, `groupByPacker`, `sortRowsBy`,
  `groupRowsBy`, `catalogRows`, `duplicateGroups`, `maintenanceList`,
  `shoppingSuggestions`, `namesFromRows`, `ownersByUsage`, `compareActions`,
  `sortEventsForList`, `setPhases`, `sharedRowsOfKind`. [`strings.collation`,
  `strings.compare`, `calc.setPhases`] — On the owner's backup, switching the JS
  side between `en-US` and `sv-SE` changed **no model answer at all**, only the
  collation probe; so real-data risk is low, and the probe is the strict test.
  **What the Swift side can and cannot match.** Foundation offers no ICU collator,
  only `String.compare(_:options:range:locale:)` (`[]` for the plain call,
  `[.caseInsensitive, .diacriticInsensitive]` for `sensitivity: "base"`). Measured
  against Node (ICU 78, `en-US`): every one of the 795 664 ordered pairs of the
  owner's 892 strings agrees, at both strengths, and so do ~29 000 pairs of invented
  English / Swedish / German names, punctuation, digits and emoji. It differs only
  on characters a keyboard does not produce: (a) a character against its
  *compatibility variant* — full-width `ａ` vs `a`, U+00A0 / U+2009 / U+202F vs a
  space, U+2011 vs `-`, `²` vs `2`, `ℬ` vs `B` — where ICU orders the two at the
  tertiary level (the plain one first) and Foundation calls it a tie. The case a
  person can produce — a pasted no-break space; the invented backup has an owner
  spelt both ways — is put right in `jsLocaleCompare` (on a tie, plain ASCII before
  its compatibility variant: six deviations in ten gone, none added, measured).
  Left: variant against variant, and a longer string in which Foundation lets a
  later case difference decide before the earlier width difference;
  (b) at `base` strength, an emoji skin-tone modifier, U+200C/U+200D and the
  combining Latin letters U+0363–U+036F, which ICU gives a primary weight and
  Foundation ignores as if they were accents; (c) U+FE0F after a symbol (`☀️` vs
  `☀`), which ICU ignores completely and Foundation does not. `.forcedOrdering`
  makes it worse, not better; an exact match needs the UCA tertiary weights, i.e.
  ICU's data. Because every sort is stable and these are ties between names that
  read the same, the visible effect is the order of two near-identical names.
- **H2 Stable sort.** `Array.prototype.sort` is stable and the model leans on it
  (ties keep input order). [`sortRowsBy.*`, `pruneSuggestions`, `bagLoads`]
- **H3 Insertion order.** `Map` and `Set` remember it and "first seen wins a tie"
  depends on it: `containerDefaultsFrom`, `buildCatalog` (group order, `_mostCommon`),
  `groupBySection`, `assignedPeople`, `clusterByKit`. A Swift `Dictionary` does not.
  [`library.buildCatalog.*`, `library.containerDefaultsFrom`]
- **H4 UTF-16.** `slice`, `length`, `charCodeAt` count code units. `listColor` /
  `personColor` hash code units with 32-bit wrap. `slice(0, 4)` on an emoji can cut
  a surrogate pair in half, leaving a lone surrogate a Swift `String` cannot hold
  (none in the owner's data). [`list.cover`, `strings.personColor`, `calc.coerceHostile.list`]
- **H5 Whitespace.** `trim()` and `\s` cover U+00A0, U+FEFF, U+2028/9 and every
  Unicode space — but **not** U+0085, which Swift's `.whitespacesAndNewlines` does
  include. [`strings.normName`]
- **H6 `\p{L}\p{N}` in `dupeKey`** works on code points: a combining accent is not
  a letter and is dropped, `½` is a number and stays, `№` is a symbol and goes.
  Work on unicode scalars, not `Character`s. `toLowerCase` is the full, locale-free
  mapping (`İ` becomes two code points). [`strings.dupeKey`]
- **H7 `Number(string)`** in `effectiveQty`: `""` → 0, `" 3 "` → 3, `"0x10"` → 16,
  `"1e2"` → 100, `"Infinity"` → infinite (so rejected), `"3 pairs"` → NaN. Swift's
  `Double(String)` does not trim and treats hex differently. [`strings.qty`]
- **H8 `Math.round`** rounds half towards +∞: `-2.5` → `-2`, `-0.5` → `-0` (written
  `0`). [`event.weatherSuggestions.synth`, `calc.coerceHostile.phaseLeadHalf`]
- **H9 `toFixed(1)`** in the map's pin key rounds an exact tie away from zero
  (`12.25` → `"12.3"`, `-12.25` → `"-12.3"`); `printf("%.1f")` gives `12.2`.
  [`library.placesVisited.synth`]
- **H10 Strings are not numbers — except where they are.** `Number.isFinite("12")`
  is false (weight, price, stats → default), but `Number("12.5")` is used for
  `geo`, `weather`, phase `order` and `leadDays`, where `null` → 0 and `""` → 0.
  [`calc.coerceHostile`, `calc.coerceGeo`]
- **H11 Day of week** comes from `new Date(date + "T00:00:00")` in the **local**
  zone — i.e. the weekday of that calendar date; a `date` that is not exactly
  `YYYY-MM-DD` gives `""`. Everything else is UTC. [`event.deriveWeather`]
- **H12 Code-unit order** for a bare `.sort()` (`auditList`'s `missing`) and for
  `<` on dates. Swift's `String <` differs above the BMP. [`library.auditList`]
- **H13 Ordered JSON text** for the list and grab share codes — §8.
  [`list.share.encoded`, `settings.grabShare`]
- **H14 Number → string** in `coerceMembership` (`qty: 3` → `"3"`), by JS's number
  formatting — the §2 number rules: `0.00001` is `"0.00001"` (C and Swift say
  `1e-05`), `1.5e-7` is `"1.5e-7"`, `1e21` is `"1e+21"`, and a whole number above
  2^53 is its shortest digits followed by zeros. One writer must serve `String(n)`,
  `CJ` and the share codes. [`calc.coerceHostile.membership`, `…membershipQty*`]
- **H15 `shareSafeOwner`** cuts by UTF-16 units AFTER testing for an address, and
  does not trim again: `"at @ sign alone"` cut to 10 is `"at @ sign "`, with its
  trailing space. [`strings.shareSafeOwner`]

- **H16 Half an emoji in JSON text.** A lone surrogate escape (`\ud83d` with no
  partner) is legal to `JSON.parse` and an error to Foundation's parser. It reaches
  the app in a name cut by `slice`, and in the sub-items an app from before v186
  took apart one UTF-16 unit at a time. `JSONValue.parse` reads it; a Swift String
  cannot hold the half, so outside `subName` (which joins two halves back into the
  emoji) it is dropped — which is why no question's ANSWER may contain one.
  [`calc.tripBundleIncoming.oldBundleEmoji`]

- **H17 Equal strings.** JS `===`, `Map` and `Set` compare UTF-16 code units. Swift's
  `String ==`, `Set<String>` and `Dictionary` keys compare by Unicode CANONICAL
  EQUIVALENCE: `é` as one code point and as `e` + U+0301 are two names to JS and one
  to Swift. So where the model keys things by `normName` (`buildCatalog`,
  `buildTotalEntries`' de-duplication, the duplicate finder, the shared rows' ids),
  two such spellings are two things in JS and merge in Swift — and the Swift
  tool's own POOL loses one of them. Nothing in the owner's data does this (text
  typed on Apple keyboards is precomposed; a name pasted from a file name may not be),
  and no question asks it: the invented backup leaves such a pair out on purpose.
  **Not fixed** — a faithful fix means keying by code units (`[UInt16]`) throughout.
- **H18 What is left of half an emoji.** `decodeListShare` / `decodeGrabShare` keep the
  half in the parsed text until JS's own trim and cut are done, then drop it (§2) — so a
  name that arrives as `"brim "` + half keeps its space, as in JS. `listFromShare`
  cleans the decoded name AGAIN; in JS the half is still there to shield that space, in
  a typed `SharedList` it is gone, so there the space goes. One character, one corner;
  the invented backup's long name therefore has no space in front of the emoji.

## 19. Contract history

**Version 3** (the Swift half exists). No key was renamed or redefined, and on the
owner's backup no version-2 answer changed.

| Key | Change |
|---|---|
| `calc.coerceHostile` | NEW cases `membershipQtySmall`, `membershipQtyTiny`, `membershipQtyHuge` — a numeric `qty` as JS writes numbers. The port's first number writer gave `1e-05`; nothing in the owner's data showed it. |
| `calc.tripBundleIncoming` | NEW case `oldBundleEmoji` — H16. |
| the diff tool | two whole numbers must be EQUAL (§2). |
| §2 canonical values | half an emoji (a lone surrogate) is dropped from every written string — H16, H18. |
| NEW `run.sh --invented` | the same 209 questions (211 with `coerce.kit` and `coerce.thing`, which the owner's backup leaves empty) over an invented, deliberately awkward backup. |
| §16 N5, §18 H1 | what the port does about an impossible day, and exactly where Foundation's collation parts from ICU's. |


**Version 2** (model v186). Every other key is unchanged in name, definition and —
on the owner's backup — in answer.

| Key | Change |
|---|---|
| Setup §4.1 | `owner` / `realmId` are no longer deleted from the backup before the model sees it. No answer depends on it: no shape carries them. |
| ITEM and SLIM ENTRY shapes (§3.1, §3.5) | `sub` is written as it is; the rule that put a taken-apart name back together is gone. |
| `list.share.encoded` | the code now carries `u` = `shareSafeOwner(it.ownedBy)`. |
| `list.share.decoded` | items have `ownedBy`; the dropped legacy `owner` key no longer exists. |
| `list.share.imported` | definition unchanged; items now arrive with their `ownedBy`. |
| `event.tripBundle`, `event.tripBundle.parsed`, `event.tripLink`, `event.packedCanonical` | definition unchanged but for the `sub` shape rule; `ownedBy` in a bundle goes through `shareSafeOwner`. |
| `calc.constants` | 61 names: `SYNC_RESERVED_KEYS` added. |
| NEW `list.share.addressInside` | §8 |
| NEW `event.tripBundle.leaks` | §9 |
| NEW `strings.shareSafeOwner` | §13 |
| NEW `calc.tripBundleIncoming`, `calc.tripBundleOutgoing` | §14 |
