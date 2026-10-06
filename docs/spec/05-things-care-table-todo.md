# Things, Care, the things table, and To do

> Verified against the code on 5 Oct 2026 (app 0.60).

State described: version 0.60 (4 Oct 2026), read from the code and the tests. Examples use the invented
sample library (`App/Sources/Store/SampleLibrary.swift`: things Passport, Hiking boots, Rain jacket, Headlamp,
Map, Towel, Goggles, Swim cap, Phone charger, Toothbrush; owners Kim and Robin; templates "Common base",
"Hiking", "Swim"; trip "Weekend in the hills").

## Overview

**What this part is for, in the owner's terms.** A *thing* is one physical object he owns (the glossary,
`Guide/Words.swift`: "One thing you own, in Your things on Care. It can be on many templates; a change to it
reaches all of them."). Everything a thing knows about itself — name, where it is kept at home, kind, its own
bag and "When", whose it is, condition, weight, brand, colour, notes, Liquid / Not allowed in the cabin,
Valid until — lives ONCE on the catalogue item; templates only hold *memberships* (the thing's place on that
template). This document covers:

- **The Care tab** (tab id `tab-care`, screen `screen-care`, orange `AppSection.care` #dd7324): the kit in one
  line, three doors (Your things, Bags, All your things · table), the care services (List or Calendar, "Done
  today"), and the kit dashboard.
- **Your things** (a sheet from Care) and **a thing's page** (`ThingEditor`, opened from Your things, the table,
  a bag's page, the trip checks, the review, the way home and the search).
- **Care → Bags** (`BagsScreen`) and **a bag's page** (`BagDetail`).
- **All your things · table** (`ThingsTable`): a spreadsheet of every thing — columns, cell editing, filters,
  sort levels, ticking several and "Change all" with Undo. On the Mac it is a window of its own.
- **The To do tab** (tab id `tab-actions`, screen `screen-actions`, red `AppSection.actions` #dc3d43; the tab
  label is "To do" since 0.43 / 30 Sep 2026, the case and identifiers stay "actions"): two sides, **To do** (the
  to-do list) and **To buy** (the buy list, with "Worth buying" suggestions and "Send to Reminders").

How one reaches them: the tab bar (`RootView.TabBar`, `tab-care`, `tab-actions`); the Trips screen's red
"N to do" chip (`events-todos`) switches to the To do tab; the global search (`search-open`, also on Care and
To do) opens a thing's page directly. Choosing a to-do in the search closes the search and opens the To do
tab, from whichever tab it was opened (0.62: `model.tabToOpen`, see the Home spec, section 15). There is no Shortcut and no menu command for anything in this area.

Every change goes through `LibraryModel.change { … }` (`App/Sources/Store/LibraryModel.swift`): the closure
edits a copy of the `Library`, the whole library is cut into records (`Library.records()`,
`PackingLibrary/LibraryRecords.swift`), only the records that differ are written to the store, and the store
syncs them through iCloud. One thing = one `items` record (key = item id); one membership = one `memberships`
record (parent = template id); one to-do or buy line = one `actions` record. See `docs/store.md` for the store,
the sync and its rules; `docs/colours.md` for the colour tokens (`Theme.bg/card/ink/muted/line`, the six
`AppSection` colours).

Shared building blocks referred to below (defined outside this area, summarised so this document stands alone):

| Piece | File | What it looks like / does |
|---|---|---|
| `HeaderButtonStyle(tint:filled:)` | `Buttons.swift` | The Done / Save / Cancel buttons at the top of a sheet. 17 bold (16 until 0.62, spec 06 §20), one line, capsule, min height 36, padding 14. Filled = white words on the tint; outlined (`filled: false`) = tint words on 10 % tint with a 1.4 stroke. Pressed = 70 % opacity. Never grey (his rule). |
| `FieldButtonLabel(title:tint:)` | `Buttons.swift` | The button beside an add-field (New, Add). 16 bold white on a full-colour rounded rectangle (radius 10), min height 44. Always enabled. |
| `.needsLine($says, typed:, id:)` | `Buttons.swift` | Under an add-row: a red (`AppSection.actions`) 15 bold line saying what a press was missing; it disappears as soon as the typed text changes. |
| `.clearButton($text, id:)` | `Buttons.swift` | Names a search field `id` and, while it holds text, shows a round ✕ (`id-clear`, label "Clear the search", 36×36 hit area) that empties it and keeps the keyboard. |
| `SmallDeleteButton(title:id:size:)` | `SmallDelete.swift` | Right-aligned small red outlined capsule (red words, 1 pt outline in red at 60 %, padding 12, min height 30). `size` (since 40be106) defaults to **13** semibold; "Delete thing" and "Delete bag" pass none, so they are 13 pt (only the grab list's delete passes 15). Only ever OPENS a question. |
| `HeadingBand(title:tint:id:)` | `Headings.swift` | A heading as a band: a 5×26 capsule in the tint, words 22 heavy in the tint, on a 13 % tint rounded strip. |
| `HeadingTitle`, `SectionTitle` | `Headings.swift` | 20 heavy with a 4×18 mark; SectionTitle = 18 heavy CAPITALS, kerning 0.8, 16 pt above. |
| `Pills(title:options:selected:id:tint:heading:choose:)` | `HomeScreen.swift` | A heading (here always `.band`, id `<id>-title`) over wrapping capsules (15 pt, medium; bold when picked), min height 36; picked = filled in the tint with white words; each pill id `<id>-<n>` by POSITION, never by words; picked pills carry the selected trait. Tapping calls `choose(id)` — the caller decides single or multiple choice. |
| `KeyboardAwayScroll` | `Theme.swift` | A vertical ScrollView that dismisses the keyboard immediately when dragged. |
| `SearchButton` | `SearchScreen.swift` | A drawn magnifier, 24 pt in a 40×36 hit area, id `search-open`, label "Search everything". |
| `Today.local` | `Store/Today.swift` | Today as `yyyy-MM-dd` in the device's time zone (Gregorian, POSIX). The model's own "today" default is the UTC date; the screens always pass this. |

---

## The thing itself: `Item` (PackingCore/Items.swift)

**Purpose and origin.** A port of the web app's item shape (`js/model.js`). ONE struct serves three roles,
exactly as one JS object shape does: a *catalogue item* (the thing, once), a *resolved item* (the thing as one
template sees it — carries `_itemId`, `_memId` and the `_ov…/_tpl…/_def…` parts), and a *trip entry* (a
frozen line on a trip — carries `sourceListId`, `sourceItemId`, `custom`, `checked`, `skipped`, `used`,
`_edited`). `coerceItem` is applied to all three.

**Decoding rules.** `Item(json:)` is coercion and never throws: a wrong type gives the default; a string field
that is not a string reads `""`; `name`, `id`, `qty`, `note`, `container` read a JSON number as its text
(`jsLooseText`). A field ABSENT from the JSON gets `coerceItem`'s answer, which for `container` is `""` —
`newItem(json:)` instead lays the JSON over `newItem`'s defaults first (so a missing container becomes
"Carry-on / hand luggage"). Unknown keys are kept in `extra` and written back unchanged; the two reserved sync
keys `owner` and `realmId` are dropped on read and never written (`RESERVED_SYNC_KEYS`, `extraKeys` in
`JSONValue.swift`).

**Fields, defaults and limits.** "Default" is `newItem`'s / `Item()`'s; "Coerced" is what `coerceItem` enforces;
"Edited natively" says where the native app lets him change it (the web app may edit more).

| JSON key (Swift) | Type, default | Coerced (`coerceItem`) | Edited natively |
|---|---|---|---|
| `id` | String, `PackingEnv.makeId()` | — | never |
| `name` | String, "" | — (loose text) | Your things (New), thing page Name, bag page name, Bags (Add). Rules: `addThing`/`renameThing` below |
| `swedish` | String, "" | — | nowhere |
| `qty` | String, "" | — (loose text) | nowhere on the thing; per template on the membership (table "How many") |
| `category` | String, `CATEGORY_DEFAULT` "Comfort & misc" | "" → "Comfort & misc" | thing page "Kind of thing" |
| `container` | String, "Carry-on / hand luggage" | — | thing page "Usually packed in" (also "No bag" = ""); table "Packed in" (his own bags included, 0.62); bag rename/delete rewrite it |
| `phase` | String, "week" | trimmed; empty → `defaultPhaseId()` (first non-task phase of the live timeline); otherwise KEPT even if unknown, cut to 40 UTF-16 units | thing page "When" |
| `itemType` | "item" | anything but "reminder" → "item" | nowhere |
| `charging` | Bool, false | truthy | table "Charges" |
| `chargeType` | "" | not in `CHARGE_TYPE_IDS` → "" | nowhere |
| `shortList` | false | truthy | nowhere |
| `seasons`, `contexts`, `transports`, `catering` | [] | string arrays | per template (membership), not here |
| `weather` | [] | filtered to `WEATHER_CONDITION_IDS` (rain, cold, hot, wind, snow) | per template |
| `sub` | [] | string array | nowhere |
| `note` | "" | — (loose text) | thing page "Notes"; table "Note". NB a membership's own note WINS on that template (`resolveMembership`: `r.note = mm.note.isEmpty ? base.note : mm.note`) |
| `weight` | Double grams, 0 = unknown | non-finite or negative → 0 | thing page Weight (decimals, comma or point, 0.62); table Weight; bag "Empty g" |
| `liquid` | false | truthy | thing page "On a plane"; table |
| `restricted` | false | truthy | thing page "Not allowed in the cabin"; table "Restricted" |
| `perNight` | false | truthy | table "Per night" |
| `consumable` | false | truthy | table "Runs out" |
| `section`, `kit` | "" | — | per template (contextual) |
| `packer` | "" | — | table "Packed by" |
| `storage` | "" | — | thing page "Kept at home" (typed, or a tap on one of his places, 0.62); table "Storage"; a trip's "Set place" (`Library.setPlace` → `updateThing`, see the Trips spec). `setStorage(id:place:)` exists but no screen calls it (a model test only) |
| `photos` | [] | empty strings dropped; more than `MAX_PHOTOS` = **5** → the first five kept; a legacy single `photo` string is folded in when `photos` is empty, then never written | **nowhere** (no native UI adds or removes a thing's photo; bag photos on a trip are a different store) |
| `thumb` | "" | — | nowhere |
| `maintenance` | nil | `normalizeMaintenance`; an empty record becomes nil | thing page "Care" (how often + what to do, 0.62 — its log, last service and link are kept); "Done today" logs a service. See Care below |
| `stats` | `ItemStats()` | every count ≥ 0, floored | written by the trip review |
| `color` | "" | — | thing page "Colour"; table "Colour" |
| `size`, `model`, `serial` | "" | — | table only ("Size", "Model", "Serial") |
| `manufacturer` | "" | — | thing page "Brand"; table "Maker" |
| `ownedBy` | "" | — | thing page "Whose it is"; table "Owner". "" (no owner) is labelled "Both have one" (`OWNER_BOTH`, `ThingFilters.swift`) in two places: the first pill of the thing page's Whose it is, and the blank answer of the table's Owner FILTER. Elsewhere an empty owner reads "—" (the table's Owner cell) or "Leave blank" (its menu, Change all) |
| `acquired` | "" | not YYYY-MM-DD → "" | nowhere |
| `price` | 0 | non-finite or negative → 0 | nowhere |
| `currency`, `purchaseLink` | "" | — | nowhere (`CURRENCIES` is offered nowhere natively) |
| `expiry` | "" | not YYYY-MM-DD → "" | thing page "Valid until" |
| `condition` | "" | trimmed, cut to 40 units; ANY non-empty id is kept, even one this device does not know | thing page "Condition", table "Condition" and Change all — all write the condition's **id** (the table wrote the label until 0.62; such things are repaired on load, `repairConditionLabels`) |
| `retired` | false | truthy | nowhere ("Not in use" only comes from the web app) |
| `retiredReason` | "" | not in `RETIRE_REASON_IDS` → "" | nowhere |
| `qtyOwned` | 0 | ≥ 0, floored on read | nowhere |
| `warranty` | "" | not YYYY-MM-DD → "" | nowhere |
| `capacityL` | 0 | non-finite/negative → 0 | bag "Litres" |
| `maxKg` | 0 | non-finite/negative → 0 | bag "Max kg" |
| `keep` | false | truthy; always written | Refine's Keep (not this area) |
| trip-entry only: `sourceListId`, `sourceItemId` (nil), `custom`, `checked`, `skipped` (false), `used` (nil = not answered), `_edited` (`edited`) | | written only when set/true | trips (not this area) |
| resolved only: `_itemId`, `_memId`, `_link`, `_ovContainer`, `_tplContainer`, `_defContainer`, `_ovPhase`, `_defPhase` | nil/false | written only when set | — |
| `extra` | [:] | unknown keys kept | natively used extra keys: `cabin` (Bool, a bag's "Goes in the cabin", `CABIN_KEY`) |

**JSON writing (`Item.json`).** Every plain field is always written (`maintenance` as `null` when nil, `keep`
always since v188); the Optional / trip / resolved markers only when set (`checked`, `custom`, `skipped`,
`_edited`, `_link` only when true).

**The care record (`Maintenance`).** `notes` (String), `link` (String), `intervalDays` (Int, 0 = no schedule;
from JSON: a finite number > 0 is floored, anything else 0), `lastDone` (YYYY-MM-DD or ""), `log`
([`{date, note}`], entries whose date is not YYYY-MM-DD are dropped, sorted oldest first). `normalizeMaintenance`
returns nil when everything is empty — so the 200+ everyday things carry no care record at all.

**Usage stats (`ItemStats`).** `packed`, `used`, `unused`, `skipped` (counts ≥ 0) and `lastReviewed` (ISO
string). `skipped` (on the list, never packed) is counted apart from `unused` (packed, not used) on purpose.

**Photo references.** `isPhotoRef(s)` = non-empty and not starting `data:`; `photoRefs`, `inlinePhotos`,
`hasInlinePhotos` split the two shapes during the old inline-photo migration.

**"Whose it is".** The field is `ownedBy`, never `owner`: the web app's sync addon stamped the signed-in
e-mail address into any synced field called `owner` (it once overwrote almost every owner in the catalogue).
On read, a legacy `owner` string is adopted into `ownedBy` only when `ownedBy` is absent AND it does not look
like an e-mail (`looksLikeEmail`: trimmed text, no whitespace, exactly one `@` not first, a domain of ≥ 3
characters with a dot that has a character on both sides). `ownerNameFromEmail` ("first.last@x" → "First";
falls back to the whole local part when the first word is shorter than 2) is ported but used by no screen.

**Tests.** `ItemsTests`: `testNewItemCarriesTheNewFlagsWithSafeDefaults`,
`testCoerceItemKeepsOnlyKnownWeatherConditions`, `testNormalizeMaintenanceEmptyRecordCollapsesToNull`,
`testNormalizeMaintenanceKeepsRealContentAndCleansBadValues` (90.7 → 90, bad date dropped, bad log entry
dropped), `testCoerceItemBackfillsCareFieldsOnLegacyItems`, `testCoerceItemPhotosArrayIsFilteredAndCapped`
(non-strings/empties dropped, cap at `MAX_PHOTOS`, explicit `photos` beats legacy `photo`),
`testCoerceItemDefaultsAndValidatesTheNewMetadataFields` (unknown condition kept trimmed, bad dates dropped,
negative price/qtyOwned clamped, unknown retire reason dropped), `testConsumableFlagSurvivesCoerceItemAndNewItem`,
`testIsPhotoRefIdsAreRefsDataURLsAreNot`, `testPhotoRefsAndInlinePhotosSplitAMixedItem`,
`testCoerceItemKeepsBothPhotoShapesAndDefaultsThumb`, `testLooksLikeEmailTellsASignInAddressFromAName`,
`testOwnerNameFromEmailAnAddressBecomesAName`, `testCoerceItemAdoptsALegacyOwnerNameButNeverTheSyncAddress`,
`testCoerceItemKeepsAPhaseThisDeviceDoesNotKnow`, `testTheReservedSyncKeysAreNeverKeptOrWritten`,
`testAnItemRoundTripsThroughJSONWithEveryEntryAndResolveField`, `testDecodingIsCoercionAndNeverThrows`,
`testNewItemFromARawPartialLaysItOverTheDefaultsAsTheJSSpreadDoes`, `testCoerceItemFallsBackToTheLivePhaseListsDefault`.

**Traps and history.** 🪤 `owner` is reserved by sync — never name a field `owner` or `realmId`
(docs/store.md rule 7). 🪤 Conditions and phases are editable and synced, so an unknown id is kept, never
"corrected" (a whitelist would silently retag the other device's choice).

---

## The library's operations on things (PackingLibrary/Library.swift, SettingsLists.swift, ThingFollows.swift)

**Purpose and origin.** The relational shape is the web app's (v108+): ONE catalogue item per physical thing
(`Library.items`), MANY memberships (`Library.memberships`), templates without items of their own
(`Library.templates`). A template is resolved on demand (`resolved`, `resolvedTemplate(id:)`,
`resolvedTemplates()` — the latter A–Z by `jsLocaleCompare`). Things on no template exist in their own right
(web app v175/v176; `thingsOnNoList()`).

**Behaviour, function by function.**

| Function | What it does, exactly |
|---|---|
| `thingRows() -> [(item, templates)]` | Every item (bags and "not in use" ones included), sorted A–Z by `jsLocaleCompare(…, sensitivity: .base)` (locale-aware, ignoring case and accents), each with the shown names of the templates it has a membership on, in `templates` order, each name once. The bag list reads "Bags" (`shownName`). `[]` = on no template. |
| `addThing(name:) -> Item?` | Trims (`jsTrim`). Refused (nil) when blank or when any item already has that name by `normName` (trimmed, lower-cased, runs of whitespace collapsed). Otherwise builds `catalogItemFromResolved(newItem(name:))` with a fresh id and appends it — on no template. Defaults therefore: category "Comfort & misc", container "Carry-on / hand luggage", phase "week" (kept even when his own timeline has no "week" step, because `coerceItem` keeps any non-empty phase). |
| `renameThing(id:to:) -> Bool` | Trims. Refused when blank, when the id is unknown, or when ANOTHER item already has that name by `normName` (renaming to a different capitalisation of its own name is allowed). If the thing is a bag and the name changed, `renameBagEverywhere(from:to:)` carries the new name through every field that names it (see Bags). Then `followThing(id:)`. Past trips keep the old name (a trip line is a copy), except trips still ahead (see `followThing`). |
| `updateThing(id:_ apply:) -> Bool` | Applies the closure to a copy of the catalogue item, stores `coerceItem(copy)`, then `followThing(id:)`. False for an unknown id. |
| `setOnTemplate(itemId:templateId:on:) -> Bool` | False unless both the item and the template exist. `on` and already on → true, nothing changes ("asking twice changes nothing"). `on` → a new membership (`newMembership`) with `order` = the template's highest order + 1 (or 0) — the bottom of the template. `off` → removes EVERY membership of that thing on that template; the thing stays. Does NOT call `followThing`. |
| `deleteThing(id:evenABag:) -> Bool` | False for an unknown id, and false for a bag unless `evenABag` (a bag goes through `deleteBag`, which asks where its things go). Removes every membership of the thing, removes its id from every kit's `itemIds`, removes the item. Trip lines are untouched (past trips keep their lines); to-dos and buy lines tied to it keep their `itemName`. |
| `listsOf(itemId:) -> [String]` | The shown names (bag list = "Bags") of the templates the thing is on, in `templates` order. |
| `setStorage(id:place:) -> Bool` | Stores the trimmed place. ("" = not said.) No `followThing`. Called by NO screen (only `ThingsTests`); every place the app sets goes through `updateThing` (thing page) or `setPlace` (a trip's Set place). |
| `thingsOnNoList()` | Items with no membership at all, each `resolveItemAlone`d. |
| `ownerChoices() -> [String]` | What "Whose it is" offers: `owners()` (his Settings → Your choices owners list, A–Z via `namesFromRows`) followed by every trimmed non-empty `ownedBy` of every item, sorted by `jsLocaleCompare`, keeping each name once by `normName` (first spelling met wins). Nobody named anywhere → []. |
| `owners()` | His owners list only (shared rows kind "owners"), A–Z. |
| `storagePlaces()` | His places list (kind "places", in his order) or, when he has none, `DEFAULT_STORAGE_LOCATIONS` (12, below). |
| `people()` | His packers roster (kind "people"); with none, the packers his things name (0.62); else the two factory packers `DEFAULT_PEOPLE` (`SharedRows.swift`; the invented Kim and Robin since 0.62). |
| `conditions()` | His conditions (kind "conditions") or `DEFAULT_ITEM_CONDITIONS`. |
| `conditionId(for:)` / `conditionLabel(_:)` (ThingConditions.swift, 0.62) | What a stored condition means: its id when it IS one of his ids; else the id of the condition whose LABEL it is (by `normName` — how the table stored it before 0.62); else nil (an unknown id is kept, never "corrected"). `conditionLabel` = that condition's label, or the stored text itself. |
| `repairConditionLabels() -> Int` (0.62) | Every thing whose condition is no id of his but IS one of his labels gets that condition's id; nothing else is touched (idempotent, the same answer on every device). `LibraryModel.reload()` runs it through `change` after every read of the store, so a repaired thing is written once. |
| `templatesForThings()` (Bags.swift, 0.62) | Every template but his bag list: the templates a thing's page and the table put a thing on or take it off. |
| `bagNames()` (Bags.swift, 0.62; 0.64) | His bags — the names on Your bags (`bags()`), trimmed, in that list's order, each once (`normName`) — and nothing else; `CONTAINERS` (the 17 built-in names) only while he has no bag of his own. Until 0.64 the built-in names always came first, then his own (his word, 6 Oct 2026: "No Triathlon bag in the Bag List … why does it not disappear?"; "Carry-on luggage is renamed to Hand Luggage but is still 'Carry-on / hand luggage' in the list"). The one answer for the thing page's "Usually packed in", a template row's bag, the table's "Packed in" and Change all. `ThingsAndCareFixesTests.testTheBagsOfferedAreHisOwnAndOnlyHis`, UI `testAThingIsOfferedOnlyHisOwnBags`. |
| `usesOf(kind)` | How many items name each place / owner / packer / condition / phase (by `normName`) — and, for a phase, the trips and templates that hold it, counted apart (a `ChoiceUse`, 0.62) — so Settings can refuse to remove one in use and say why. |
| `followThing(id:today:) -> Int` | His decision on test I.7 (1 Oct 2026, release 0.45): a change to a thing reaches trips still ahead — status not "done", not reviewed, and either no start date or an end date (or the start, when there is no end) ≥ today — and on them only lines of that thing (`sourceItemId == id`) that are not ticked, not custom and not edited on the trip. Each such line is rebuilt as a new trip would build it (`buildTotalEntries` over the resolved templates, so a template's own bag still wins; the fresh line from the same `sourceListId` first), keeping its id, tick, set-aside, `used` and its own `extra` marks (way home, used up, maintenance note — 0.62) — the line's other data are the fresh line's. Without `today` it uses `Library.localToday()`, the device's own date (0.62; it was the UTC date); `updateThing` and `renameThing` never pass one. Returns the number of lines changed. |

**Data.** Items → `items` records; memberships → `memberships` records (parent = template id); kits → `kits`
records; shared rows (owners/places/people/conditions) → `shared` records (`places:garage`-style keys).

**Tests.** `CreateTripTests.swift`: `ThingsTests.testYourThingsListsEverythingAndARenameReachesEveryList`
(A–Z rows; `addThing(" Sit mat ")` → "Sit mat" on no template; "sit MAT" refused; rename reaches both
templates; an OVER trip keeps the old name; rename onto another thing's name and to "  " refused;
`setStorage(" Hall closet ")` stores it trimmed); `ThingEditingTests.testWhatTheThingKnowsReachesEveryListItIsOn`
(category, owner, condition, weight, phase reach every template; a template's own bag exception stays);
`ThingEditingTests.testAThingIsPutOnAListAndTakenOff` (on twice = one membership; off keeps the thing; unknown
template refused); `LibraryTests.testTakingAThingOffItsLastListKeepsTheThing`;
`BagEditsTests.testAThingIsDeletedButABagIsNotDeletedAsAThing` (off every list and kit; a bag refused; unknown
id refused); `SettingsListsTests.testEachOwnerIsOfferedOnce` (40 things sharing three names → each once, the
list's own A–Z then one not on the list; empty library → []); `ThingFollowsTests`:
`testAChangeToAThingReachesOnlyWhatIsStillUndecided`, `testARenameAndAnEditedOrSetAsideLineAreHandledRightly`,
`testABagChosenForOneTemplateStillWins`; `HealthTests.testThingsOnNoListAreNotAWorry`.

Model tests of the 0.62 additions (`ThingsAndCareFixesTests`): `testTheBagNamesOfferedIncludeHisOwnBags`,
`testHisBagListIsNotATemplateAThingIsTickedOnto`, `testAConditionStoredAsItsLabelIsRepairedToItsId` (a label →
its id; an id and an unknown value untouched; a second run changes nothing; then To buy offers it and Your
choices counts it), `testHisOwnConditionIsRepairedByItsOwnLabel`. UI `testAConditionStoredTheOldWayIsRepairedOnLoad`
(`-uiTestingOldConditions`: the sample with the Goggles' condition stored as "Needs replacing" — To buy offers them).

The notes a template keeps for a thing (0.62, `RowNotesTests`): `testATemplatesOwnNoteForAThingIsListed` (trimmed;
a row without a note of its own is not listed), `testANoteTheThingAlreadySaysIsNotRepeated`,
`testEveryTemplateIsListedInItsOrderAndOneNoteOnce` (Hiking before Swim; the thing twice on Hiking with one note →
once; an unknown thing → []). UI `testAThingsPageShowsTheNotesItsTemplatesKeep` (a note typed on the Swim
template's Goggles row shows on the Goggles page as "On the Swim template: Rinse after the sea", and is not put in
the thing's own note).

**Not covered by a test.** `setOnTemplate` order placement (bottom of the template); `deleteThing` leaving
to-dos/buy lines that name the thing; `renameThing` to a different capitalisation of its own name.
(`followThing`'s local day is pinned by `ThingFollowsTests.testStillAheadGoesByTheDayWhereHeIs`, 0.62.)

---

## Fixed vocabularies used here (PackingCore/Vocabulary.swift)

| Constant | Value |
|---|---|
| `CATEGORIES` ("Kind of thing", 12, in this order) | Clothing, Adventure clothing, Footwear, Sport gear, Food & drink, Toiletries, Pharmacy / meds, Electronics, Documents & money, Charging, Comfort & misc, Reminders. `CATEGORY_DEFAULT` = "Comfort & misc". |
| `CONTAINERS` (17 built-in bag names, in this order) | Toiletry bag, Carry-on / hand luggage, Checked luggage, Hiking backpack, Climbing backpack, Golf bag, Triathlon bag, Swim bag, Duffel bag, Day pack, a branded backpack, Tech pouch, Electronics bag, Cool box, Handbag, RV storage box, Other. (Exact strings in the file.) |
| `CONTAINER_ROLE` / `CONTAINER_LIST_NAME` | "container" / "Containers" — the stored role and name of his bag list; shown as "Bags". |
| `CONTAINER_LIMITS_KG` | Built-in airline ceilings: "Carry-on / hand luggage" 8, "Checked luggage" 23, "Day pack" 8, and the branded backpack 8. A bag's own `maxKg` > 0 overrides (`containerLimits`). |
| `DEFAULT_STORAGE_LOCATIONS` (12) | Bedroom wardrobe, Chest of drawers, Hall closet, Bathroom cabinet, Kitchen cupboard, Garage, Loft / attic, Basement / cellar, Utility room, Storage box, Car boot, RV / camper. |
| `WEATHER_CONDITIONS` | rain "Rain", cold "Cold", hot "Heat", wind "Wind", snow "Snow". |
| `SEASONS`, `TRANSPORTS`, `CONTEXTS`, `CATERING` | Summer, Winter · Car, Plane, RV · Indoor, Outdoor, Race · self / eatout / mixed (per-template answers, not this area). |
| `CHARGE_TYPES` | "" Unspecified, usb-c, usb-a, micro-usb, lightning, special, mains (labels and short labels in the file). Not offered natively. |
| `RETIRE_REASONS` | sold, broken, destroyed, replaced, lost, other. Not offered natively. |
| `CURRENCIES` | SEK, EUR, USD, GBP, CHF, NOK, DKK. Not offered natively. |
| `GROUPS`, `ACTIVITY_ORDER`, `TEMPLATE_DEFAULT_EMOJI`, `TEMPLATE_COLORS` | Template-area vocabularies (not this area). |

**Tests.** `VocabularyTests`: `testTheDefaultCategoryIsOneOfTheCategories`, `testNoContainerIsListedTwice`.

---

## Item conditions (PackingCore/ItemConditions.swift)

**Purpose.** A wear rating, EDITABLE in Settings → Your choices. Factory list `DEFAULT_ITEM_CONDITIONS`:
`new` "New" (no badge), `good` "Good", `worn` "Worn" (tone `warn`), `retire` "Needs replacing" (tone
`danger`, `replace: true`). `CONDITION_TONES`: "" No badge, warn Amber badge, danger Red badge.

**Behaviour.** `ITEM_CONDITIONS` / `ITEM_CONDITION_IDS` are module-level live state, replaced only by
`setItemConditions` (called at load from his shared rows, and by `Library.setConditions`). `coerceCondition`:
id trimmed ≤ 40 units, label trimmed ≤ 60, unknown tone → "", `replace` truthy. `setItemConditions` drops rows
with no id, no label or a repeated id; an empty result falls back to the factory four. `newCondition(label,
taken)` makes an id from the label (`jsSlug`), "cond-<base36 time>" when the label is all punctuation, and
appends "-2", "-3"… on a clash. `itemCondition(id)` matches **by id only**; `itemConditionLabel(id)` = its label,
or the raw value when unknown ("" → ""); `conditionTone`; `conditionReplaces(id)` = the condition's `replace`
flag (drives the buy list's "Needs replacing").

**Natively used:** `ITEM_CONDITIONS` (thing page pills), `conditions()` (table answers: the id stored, the label
shown), `conditionReplaces` (buy suggestions). `conditionTone` and `itemConditionLabel` are used by no native
screen — there is no condition badge anywhere in the native app.

**Tests.** `ItemConditionsTests`: `testItemConditionLabelEveryConditionHasALabelUnratedHasNone`,
`testCoerceConditionTrimsBoundsAndRejectsAnUnknownTone`, `testNewConditionMakesAReadableIdAndNeverCollides`,
`testSetItemConditionsReplacesTheLiveListAndItsIds`, `testSetItemConditionsDropsUnusableRowsAndNeverLeavesTheAppWithNone`,
`testConditionReplacesAndToneFollowTheFlagNotTheId`.

---

## People and Places (PackingCore/People.swift, Places.swift)

**People** is the *Packers* roster ("who packs what"; the stored kind stays `people` since web v120).
`Person {id, name, color}`; `coercePerson` trims the name, a non-hex colour → `PERSON_COLORS[0]`, a missing id
is made. `PERSON_COLORS` = 8 hex colours. `personColor(name, people)` = the roster's colour by `normName`, else a
hash of the normalised name's UTF-16 units (`h = h*31 + unit`, UInt32 wrap) modulo 8; "" for a blank name.
`assignedPeople(entries)` = distinct `packer` names, first-seen order, case-folded. `groupByPacker(entries,
order)` = blocks in roster order, then names not on the roster A–Z, the unassigned remainder ("") always last;
entry order kept inside a block. In this area only `Library.people()` is used: its names are the table's
"Packed by" answers. `personColor`, `assignedPeople`, `groupByPacker` are used by no native screen.
Tests: `PeopleTests` (`testCoercePersonTrimsNameValidatesColourEnsuresId`,
`testPersonColorRosterColourWhenKnownStableHashOtherwiseBlankForEmpty`,
`testAssignedPeopleDistinctPackerNamesFirstSeenOrderCaseFolded`,
`testGroupByPackerRosterOrderFirstStraysAZUnassignedAlwaysLast`, `testGroupByPackerEntryOrderIsPreservedInsideABlock`,
`testGroupByPackerNobodyAssignedIsOneUnassignedBlockAndNothingIsDropped`, `testPersonColorHashMatchesTheJSAnswer`,
`testNewPersonThreeFormsAndTheJSONRoundTrip`).

**Places** is NOT about where things are kept at home (that is `storage` and `storagePlaces()`); it is the world
map's model: `eventCoords` (forecast coordinates first, then the cached `geo` fix; the label falls back to the
destination), `eventsNeedingCoords`, `placeKey` (`n:<normName label>` or `c:<lat 1 dp>,<lon 1 dp>`),
`placesVisited` (one pin per place, events in `sortEventsForList` order), `tripPath` (dated trips with
coordinates, oldest first, start dates compared as strings), `mostVisited` (nil unless some pin has ≥ 2
visits). Used by `PackingLibrary/WorldMap.swift` and the map screen (another area). Tests: `PlacesTests` (10
tests, names in the file).

---

## The catalogue write path and catalogue rows (PackingCore/Catalogue.swift, CatalogRows.swift)

**Catalogue.swift** keeps the rule "a value is either the ITEM's default, the TEMPLATE's default, or one
MEMBERSHIP's exception" (three web-app data bugs were a producer writing to the wrong one). In this area it
matters through:
- `catalogItemFromResolved(it)` — used by `addThing`, `saveTemplate`, `saveReview`: a new catalogue item from a
  resolved row; every field of `INTRINSIC_FIELDS` comes along, container and phase become the item's DEFAULTS
  (via `_defContainer`/`_defPhase` when present), contextual fields do not, and it gets a new id.
- `applyIntrinsic(cat, it)` — pushes a resolved row's intrinsic fields onto the catalogue item; an `undefined`
  (absent) field is left alone; a link (`_link`) carries no intrinsic field but its name.
- `containerOverrideFor(effective, tplDefault, itemDefault)` — an exception is stored only when the fallback
  chain (template default, else item default) does not already land on the wanted bag.
- `INTRINSIC_FIELDS` (Memberships.swift): name, swedish, category, charging, chargeType, liquid, restricted,
  perNight, consumable, shortList, weight, storage, packer, sub, photos, thumb, maintenance, stats, color, size,
  manufacturer, model, ownedBy, acquired, price, currency, purchaseLink, expiry, condition, retired,
  retiredReason, keep, serial, qtyOwned, warranty, capacityL, maxKg. `CONTEXTUAL_FIELDS`: seasons, contexts,
  transports, catering, weather, kit, qty, note, itemType. `DEFAULT_FIELDS`: container ⇐ `_defContainer`,
  phase ⇐ `_defPhase`.
- `buildCatalog` / `buildCatalogItem` (merge same-named copies: text by majority, booleans "true if any",
  numbers first positive, the richest stats), `linkFromResolved`, `mapSectionAcrossTemplates`,
  `planContainerMigration`, `containerDefaultsFrom`, `itemFromEntry`, `membershipFromResolved`,
  `membershipFromCopy` — the importer and template saving use some; `linkFromResolved`,
  `mapSectionAcrossTemplates`, `planContainerMigration`, `itemFromEntry` are used by no native code (ported for
  parity).

Tests: `CatalogueTests` (48 tests; e.g. `testApplyIntrinsicAnAbsentFieldIsLeftAloneAnEmptyOneStillClears`,
`testCatalogItemFromResolvedTakesItsOwnContainerAndPhaseAsDefaults`, `testEveryIntrinsicFieldSurvivesARebuildAndSoDoesTheId`,
`testContainerOverrideForAnExceptionIsOnlyKeptWhenTheFallbackMisses`, `testAPerListExceptionSurvivesAnEditToTheSharedDefault`).

**CatalogRows.swift** — the web app's "database overview": `catalogRows(lists, catalog)` (one row per item id,
or `name:<normName>` for an id-less item, gathering every template; things on no template folded in; A–Z
ignoring case), `dupeKey` (normalised name, punctuation → space, words longer than 3 UTF-16 units ending in "s"
but not "ss" lose the "s", spaces removed), `duplicateGroups` (2+ rows sharing a dupeKey; `exact` when all share
one normalised name; sorted by first row's name), `duplicateIds`, and `totalListRows` (flat Phase / Container /
Item / Qty / Packed "yes" / Note rows in timeline → container order). **None of these is used by a native
screen** (the native table is built on `Library.items` directly; Excel export lives elsewhere). Tests:
`CatalogRowsTests` (8 tests: `testCatalogRowsOneLinePerCatalogItemGatheringAllItsTemplates`,
`testDupeKeyCollapsesSpacingAndPluralsForProbableDuplicates`, `testDuplicateGroupsAndIdsSurfaceLookAlikeItems`,
`testDupeKeyWorksOnCodePointsAsTheJSRegexDoes`, `testCatalogRowsFoldsInThingsOnNoListAndSortsByNameIgnoringCase`,
`testDuplicateGroupsAreSortedByTheirFirstRowAndIdsKeepInsertionOrder`, `testTotalListRowsFlatRowsCarryPhaseContainerItem`,
`testTotalListRowsGoTimelineThenContainerOrder`).

---

## The Care tab (App/Sources/Screens/CareScreen.swift)

**Purpose and origin.** "Care: everything with a care schedule or care notes, what needs doing first at the
top." Overdue and Due soon stay open (what you act on); a service months away folds away. First built in 0.2
(22 Sep 2026); the dashboard 0.8; the table door 0.9; Bags 0.17; the calendar 0.18; Bags as a page 0.26;
headings in capitals 0.40 ("The heavy end" → "Heaviest things").

**How it is reached and left.** The tab bar's Care tab (`tab-care`). It is a tab, not a sheet: it is left by
choosing another tab. Everything else in this document except To do opens FROM here as sheets (or, for the
table on the Mac, a window).

**What is on screen, top to bottom** (one `KeyboardAwayScroll` holding a `LazyVStack`, 16 pt side padding):

1. **Heading row.** "Care" (28 heavy, care orange, id `care-heading`); under it the kit line (15 medium, muted,
   id `care-line`) = `CareScreen.line(stats)`: "`N` thing(s) · `<weight>` · `W` looked after" — the weight part
   only when the total is > 0, written by `KitDashboard.kilos` ("240 g" under 1000 g, else "2.4 kg"). Right:
   the magnifier (`search-open`) opening the global search as a sheet.
2. **"Your things" door** (`care-things`): a card (radius 12, card colour, 1 pt line border, min height 52):
   "Your things" (18 bold ink), the number of ALL items `library.items.count` (16 bold muted, monospaced), a
   chevron. Opens Your things with an empty search. The door counts what Your things lists — every thing,
   bags and "not in use" ones included — while the line above and the kit's "things" count only things in use
   (decided in the 0.62 spec pass: each number counts what its own screen shows; "not in use" comes only from
   the web app).
3. **"Bags" door** (`care-bags`): "Bags" (17 bold) + the number of bags (15 heavy muted) over "How much each may
   carry, and what goes in it" (13 medium muted, one line). Opens Your bags.
4. **"All your things · table" door** (`care-table`): "All your things · table" (17 bold) over "Weight and where
   each one lives, filled in row by row" (13 medium muted). Opens the table (a sheet on the iPhone, its own
   window on the Mac — `openWindow(id: "things-table")`).
5. **Summary** (`care-summary`, 17 heavy): `CareScreen.summary(rows:overdue:soon:)` — "Nothing has a care
   schedule yet." when there are no care rows at all; "All up to date" when none is overdue or due soon;
   otherwise "N overdue · M due soon" (each part only when > 0). Colour: red (actions) when anything is
   overdue, orange (care) when only due soon, green (events) otherwise.
6. **List / Calendar switch**: two capsules "List" (`care-view-list`) and "Calendar" (`care-view-calendar`), 14
   bold, padding 14, min height 32; the chosen one is filled orange with white words and carries the selected
   trait; the other is muted words on the card colour with a 1 pt line. The
   choice is remembered on this device (`@AppStorage("ams.care.view")`, "list" default, or "calendar").
7. **List view** (when "list"): the non-empty sections of `careSections(rows)`, in this order — OVERDUE, DUE
   SOON, UPCOMING, LATER, REFERENCE ONLY (NO SCHEDULE). Each section header is a button (`care-section-<key>`,
   keys `overdue`, `soon`, `upcoming`, `later`, `reference`): the label in CAPITALS (18 heavy, kerning 0.8)
   coloured by state (overdue red, soon orange, others muted), the row count (18 bold muted), and — only for a
   foldable section (Later, Reference) — a chevron (down when open, right when folded). A non-foldable header is
   `.disabled`. Foldable sections start folded; the open set is `@State`, so it resets whenever the Care screen
   is rebuilt (e.g. after switching tabs). Under an open section, one `CareRow` per row (below).
8. **Calendar view** (when "calendar"): `CareCalendarView` (below), 8 pt below the switch.
9. **The kit dashboard** (`KitDashboard`), 18 pt below, LAST: "what needs doing comes first, and the dashboard
   is what he browses afterwards".

**Behaviour.**
- All numbers come from `Library.careRows(today: Today.local)` and `Library.kitStats(today:)`, recomputed on
  every redraw. `careRows` (0.62) = `maintenanceList` over the resolved templates — each named as he sees it,
  his bag list "Bags" — plus a nameless list of the things on NO template (`thingsOnNoList`), with "not in use"
  (retired) things left out. So a thing with a schedule shows whether or not it is packed, and the Care
  summary, the calendar and the dashboard's "need care / due soon" count the same things.
- `care-row-N`: N is the row's position in the flattened order of ALL non-empty sections (folded ones
  included), so a row keeps its number whether or not a section above it is folded.
- "Done today" on a row → `model.change { $0.logCare(itemId: row.item.itemId ?? row.item.id, on: today) }`.
- A tap on a dashboard bar (a heavy thing, a place) opens Your things with the search filled in
  (`ThingsRequest(search:)`).

**Sheets.** Your things (`.sheet(item: $opening)`, carrying the search text as ONE value — a two-state
`sheet(isPresented:)` built its content before the search was set and the search arrived empty); the table
(`.sheet(isPresented: $table)`, iPhone only); the search; Your bags.

**Data.** Reads items (via resolved templates), memberships, templates. Writes only through `logCare` (one
`items` record). AppStorage `ams.care.view` (per device, not synced).

**iPhone vs Mac.** The table door opens a sheet on the iPhone and the `things-table` window on the Mac
(`#if os(macOS)`); everything else is the same. The tab content is limited to a 720-point column on the Mac
(`RootView`).

**Tests.** UI: `testEveryTabOpensItsScreen` (the Care tab opens `screen-care`);
`testCareShowsWhatIsOverdueAndDoneTodayMovesItOn` (sample boots: summary starts "1 overdue";
`care-row-0-done` → "All up to date"; still so after leaving the tab and coming back);
`testCareSaysWhatTheKitAddsUpTo` (heading, care-line contains "things" and "kg"); the care-line count is also
read by `testABagIsRenamedAndDeletedFromItsPage`, `testATripIsDeletedOnlyAfterAsking`,
`testRefineOffersWhatTheReviewsFoundAndKeepAndDropSettleIt`, `testThingsHeOwnsArePickedOntoATemplate`,
`testAListIsRenamedAndAnotherIsDeleted`, `testTheTableSortsAndSaves`. Model: `CareTests` in
`CreateTripTests.swift` (`testAThingOnTwoTemplatesIsOneCareRowAndDoneTodayMovesItOn`).

**Not covered by a test.** Folding Later / Reference; the summary's three colours; the "Nothing has a care
schedule yet." line; the List/Calendar choice surviving a relaunch; a care row's list-name line.

**Traps and history.** 🪤 The dashboard sits LAST also because a lazy list only builds what is near the screen:
placed first, it kept the rows below it from being built at all on the Mac's shorter window. 🪤 One sheet value
(`ThingsRequest`) instead of two states, or the search arrives empty.

### A care row (`CareRow`, in CareScreen.swift)

- Left: the thing's name (17 semibold ink); the "when" line (15 medium, coloured by state, up to 2 lines); the
  templates it is on (`row.listName`, joined ", ", 14 muted, 1 line, only when not empty — his bag list reads
  "Bags"; a thing on no template has none).
- Right, only for a SCHEDULED row: "Done today" (15 bold white on an orange capsule, min height 36), id
  `care-row-N-done`, accessibility label "`<name>` done today".
- The row: 10 pt vertical padding, a 1 pt line under it, id `care-row-N` (contains its children).
- The "when" line (`CareRow.when`): not scheduled → the first line of the care notes, or "Care notes";
  never done → "Never done — due now · every `I` days"; unreadable day count → "Due `<nextDue>` · every `I` days";
  overdue → "Overdue by `D` day(s) · every `I` days"; due today → "Due today · every `I` days"; else
  "Due in `D` day(s) · every `I` days". ("day" when |D| = 1.) The interval is always said in days, never with
  the `MAINTENANCE_INTERVALS` labels.

---

## Care records and their status (PackingCore/Care.swift; Library.careRows / logCare)

**Constants.** `MAINTENANCE_INTERVALS` (the thing page's Care pills since 0.62, 0 shown as "None"): 0 "No schedule (reference only)", 30
"Every month", 90 "Every 3 months", 182 "Every 6 months", 365 "Every year", 730 "Every 2 years".
`MAINTENANCE_SOON_DAYS` = 14. `MAINTENANCE_UPCOMING_DAYS` = 60.

**Date arithmetic.** `addDays(ymd, n)` and `daysBetween(a, b)` work on whole UTC days through `JSDay` (pure
arithmetic, no calendar or time zone); "" / nil when a side is not a date.

**Status (`maintenanceStatus(item, today)`).** nil without a care record. `intervalDays == 0` → state
`reference`, not scheduled, no due date, `days` nil, `neverDone` = no lastDone. Scheduled: next due = TODAY when
never done, else lastDone + interval; `days` = today → next due (negative = overdue); state `overdue` (< 0),
`soon` (0…14), `ok` (> 14). An unreadable date gives `days` nil and is treated as 0 → `soon` (as JS compares
null).

**`hasCare(item)`** = interval ≠ 0, or notes, link, lastDone or log non-empty.

**`maintenanceList(lists, today)`** — the Care list. Walks every RESOLVED template's rows; a row with care and a
status joins the list ONCE per item id (since v165: one jacket on three templates is one row with one record):
the first template met gives `listId` and starts `listNames`; later templates with a non-empty name are
appended once; `listName` = `listNames` joined ", ". An item with no id is never merged. Sort: overdue, soon, ok,
reference; inside a state, the sooner next due first (when both have one and they differ); then the name
(`jsLocaleCompare`).

**`careSections(rows, upcomingDays = 60)`** — five sections in this order: `overdue` "Overdue" (open),
`soon` "Due soon" (open), `upcoming` "Upcoming" (state ok, days ≤ 60, open), `later` "Later" (state ok, days
> 60 or no day count, `fold: true`), `reference` "Reference only (no schedule)" (`fold: true`). Rows keep their
arrival order inside a section; every row lands in exactly one section.

**`logMaintenance(&item, date, note, today)`** — `date` = the given YYYY-MM-DD, or today when not a date;
appends `{date, note}` to the log (re-sorted oldest first) and sets `lastDone = date` EVEN when a later service
is already logged (logging a forgotten old service moves the schedule back — as in JS). Creates the record when
missing. `Library.logCare(itemId:on:note:)` applies it to the catalogue item; false for an unknown id.

**Also ported, unused by native screens:** `maintenanceSummary`, `maintenanceByDate` (the calendar uses its own
`careMonth`).

**Data.** The care record is intrinsic (it describes the physical thing) and lives on the catalogue item; one
`items` record per "Done today".

**Tests.** `CareTests` (PackingCoreTests, 20 tests): `testAddDaysDaysBetweenUTCDateArithmetic`,
`testHasCareOnlyTrueWhenTheRecordHoldsSomething`, `testMaintenanceStatusOverdueSoonOkByNextDueDate`,
`testMaintenanceStatusReferenceOnlyAndNeverDone`, `testMaintenanceListOrdersOverdueSoonOkReference`,
`testMaintenanceSummaryCountsDue`, `testMaintenanceByDateBucketsScheduledItemsOnTheirNextDueDate`,
`testLogMaintenanceRecordsAServiceResetsTheScheduleAppendsHistory`,
`testCareSectionsOverdueAndDueSoonStayOpenFarOffAndReferenceFold`,
`testCareSectionsTheFoldBoundaryAndAMissingDayCountSinksToLater` (60 → Upcoming, 61 → Later, nil → Later),
`testCareSectionsRowsKeepTheOrderTheyArrivedIn`, `testMaintenanceListOneRowPerItemAcrossTemplatesNamingAllOfThem`,
`testMaintenanceListDifferentItemsAreStillSeparateRows`, `testTheConstantsAreTheJSOnes`,
`testDatesAreReadTheWayDateParseReadsThem`, `testADateThatCannotBeReadLandsInSoonWithNoDayCount`,
`testMaintenanceStatusUsesTheInjectedClockWhenNoDayIsGiven`,
`testTheFirstNAMEDTemplateNamesTheRowButTheFirstTemplateKeepsTheListId`,
`testRowsOfOneStateGoSoonestDueFirstThenByName`, `testLogMaintenanceAnOlderServiceMovesLastDoneBackAndANonDateMeansToday`.

**Native editing (0.62).** The thing's page has a "Care" block: how often (`MAINTENANCE_INTERVALS`, "None" for
0) and what to do (the notes). Saving changes the record only when either differs; its log, last service and
link stay. The link has no editor. Model: `ThingsAndCareFixesTests.testCareListsAThingOnNoTemplateAndLeavesOutOneNotInUse`
(a loose thing is a row with no template named, counted overdue, on the calendar; a retired one is not there),
`testCareAndTheDashboardSayBagsNeverContainers`.

---

## The care calendar (App/Sources/Screens/CareCalendarView.swift, PackingLibrary/CareCalendar.swift)

**Purpose and origin.** The web app's month view, "which he said he loves": Monday first, a count on each day
with something due, the day coloured by the worst thing on it, and a tap on a day lists what is due (0.18, 25
Sep 2026). "Today" button: his ask 26 Sep 2026 ("a button to return to today", 0.21).

**How it is reached and left.** Care → "Calendar" (`care-view-calendar`); left with "List", or with the red
overdue line (which switches to the List, where overdue services are).

**What is on screen.**
1. Header row: the month title (`care-cal-title`, 17 heavy ink, 1 line, may shrink to 80 %) — English month name
   and year, e.g. "September 2026" (`CareCalendarView.title`); right: "Today" (`care-cal-today`, 15 bold orange,
   orange outlined capsule, min height 32), the previous-month arrow (`care-cal-prev`) and the next-month arrow
   (`care-cal-next`), each a 22 pt drawn chevron in a 40×36 hit area.
2. When anything is overdue (in ANY month): "`N` overdue · show in List ›" (`care-cal-overdue`, 15 bold red);
   tapping it switches Care to the List.
3. The grid: a weekday row "Mon Tue Wed Thu Fri Sat Sun" (11 heavy muted), then weeks of 7 cells (4 pt
   spacing); `lead` empty cells before the 1st. Each day is a button `care-cal-<day of month>` with the
   accessibility value "`N` due" when something is due (else ""). A cell: the day number (14, heavy for today,
   medium otherwise; white when something is due), and under it the count (10 heavy, white 90 %) when > 0;
   background = the worst state's colour when something is due (overdue red, soon orange, ok green/events),
   otherwise the card colour; border = ink 2 pt on the picked day, orange 2 pt on today, else the line colour
   1 pt; radius 8; min height 40.
4. Under the grid, when a day is picked: "`<day> <Month>` · `N`" (`care-cal-day`, 15 heavy muted, e.g.
   "25 September · 1"), then one `CareRow` per service due that day (ids `care-row-900`, `care-row-901`… with
   their "Done today" `care-row-90N-done`), or "Nothing due that day." (14 medium muted). When no day is picked:
   "Nothing due this month. A thing shows here once it has a service interval." (`care-cal-empty`).

**Behaviour.**
- The shown month starts as today's month (`month` @State empty = today's). Which day is picked: the tapped
  one; else today if something is due today; else the first day of the month with something due; else none.
- Previous / next: move the month by one (`Library.shiftMonth`, which rolls the year: "2026-12" + 1 =
  "2027-01") and clear the picked day.
- Today: back to today's month and pick today (even when nothing is due today → "… · 0" and "Nothing due that
  day.").
- Done today on a listed row logs the service with today's date (the row then moves to its next due day).
- The calendar's state lives in the view: switching to List and back starts again at today's month.

**Model (`Library.careMonth(ym, today:)`).** Groups `careRows` that are scheduled and have a next due date by
that date. Month length = days from the 1st to the next month's 1st (30 if unreadable). `lead` = (days from
1970-01-01 to the 1st + 3) mod 7, made non-negative (1970-01-01 was a Thursday) — the number of empty cells
before the 1st with Monday first. Each `CareDay {ymd, day, count, state}`: state "overdue" if any due that day
is overdue, else "soon" if any is soon, else "ok" when something is due, else "". `overdue` = ALL overdue rows,
whatever month is showing. `careDue(on:today:)` = scheduled rows whose next due date is that day. An overdue
service sits on its (past) due day; a never-done one sits on today. Reference-only things are never on the
calendar.

**iPhone vs Mac.** Same. 🪤 The grid is NOT a `LazyVGrid`: a lazy grid built only the weeks on screen and on the
Mac's shorter window the month's last weeks never existed (0.18, CI). A month is at most 42 cells; all are built.

**Tests.** Model `CareCalendarTests`: `testTheMonthStartsOnTheRightWeekday` (Sep 2026 lead 1, 30 days; Feb 2028
has 29), `testAServiceSitsOnTheDayItFallsDueAndTakesItsColour`, `testAThingWithNoScheduleIsNotOnTheCalendar`,
`testMonthsTurnOverTheYear`. UI `testTheCareCalendarPutsEachServiceOnItsDay` (opens on this month; overdue line;
List → Done today → back: no overdue line; 90 days on, the boots sit on that day with value "1 due"; tapping it
lists them under `care-cal-day` ending "· 1"; Today returns to this month with today picked).

**Not covered by a test.** The cell colours; the empty-month text; that previous/next clears the picked day.
The weekday and month names are English whatever the device language.

---

## The kit dashboard (App/Sources/Screens/KitDashboard.swift, PackingLibrary/KitStats.swift)

**Purpose and origin.** "What his kit adds up to" (0.8, 23 Sep 2026): built on what his library actually
holds — weight, where things live, what is due — saying only things that are TRUE of his library, "bars and
rings, never art".

**How it is reached.** The bottom of the Care tab (List or Calendar alike).

**What is on screen** (14 pt between blocks):
1. **Four figures** in one row, each a card (radius 12, min height 58): the number (22 heavy, monospaced, 1 line,
   may shrink to 60 %) over a word (12 bold muted):
   - `kit-things`: things (non-retired), word "things", violet (templates colour);
   - `kit-weight`: `KitDashboard.kilos(totalGrams)` ("—" when 0, "N g" under 1000 g, else "%.1f kg"), word
     "in total", blue (home colour);
   - `kit-due`: overdue + due soon, word "need care" when anything is overdue (red) else "due soon" (orange);
   - `kit-noplace`: things without a storage place, word "no place", muted.
   Each figure is one combined accessibility element.
2. **"HEAVIEST THINGS"** (`kit-heavy-heading`, a `SectionTitle`), when any thing has a weight: up to 6 bars
   (`kit-heavy-0`…), each a button: the name (15 semibold, 1 line) and the weight (14 bold muted), and a 6 pt
   capsule bar whose length is this weight ÷ the heaviest (min 4 pt), blue. Tap → Your things searched for that
   name.
3. **"WHERE IT ALL LIVES"** (`kit-places-heading`), only when there are at least 2 place groups: up to 6 bars
   (`kit-place-N`): the place and its count, bar = count ÷ the largest count; violet, or the line colour for
   "Nowhere said". Tap → Your things searched for the place (for "Nowhere said": opened with an empty search).
4. **"WHAT EACH TEMPLATE WEIGHS"** (`kit-lists-heading`), only when there are at least 2 templates: up to 5 bars
   (`kit-list-N`, not buttons — a tap does nothing), template name and its weight, green.
5. **"THE YEAR AHEAD"** (`kit-year-heading`), when any month has something due: 12 bars bottom-aligned (height
   max(3, 44 × count ÷ tallest), orange when > 0 else the line colour), each over a 3-letter month name (10 bold
   muted) — the month `n` months from now in the DEVICE's locale (`setLocalizedDateFormatFromTemplate("MMM")`,
   first 3 characters); the block's id `kit-year`, accessibility label "Care due over the next twelve months".
6. **"WORTH KNOWING"** (`kit-tips-heading`), when there are tips: up to 4 tips (`kit-tip-N`), each a 6 pt orange
   dot and the sentence (15 medium ink, wrapping).

**Model (`Library.kitStats(today:heaviestCount: 8)`).** Live things = items not `retired` (bags included).
`things` = their count; `weighed`/`totalGrams` = those with weight > 0 and their sum; `withPlace` = trimmed
storage non-empty; `withCare` = a care record whose trimmed notes are non-empty OR whose interval > 0;
`neverUsed` = names of things with `stats.packed > 0` and `stats.used == 0`. From `careRows` (templates and things
on no template, retired things left out): `overdue`, `soon`, and `dueByMonth[m] += 1` for every row with days ≥ 0
whose next due date falls `m` CALENDAR months after today's month, 0…11 (this month is 0; a service in the
thirteenth month or later is on no bar). Until 0.62 the bars were 30-day blocks from today, the last one holding
everything from day 330 on. `heaviest` =
live weighed things by weight descending, first 8 (`name`, `grams`, `place`). `places` = live things grouped by
trimmed storage ("Nowhere said" when empty), count and sum of max(0, weight), sorted by count descending then
label. `lists` = every resolved template (his bag list as "Bags", 0.62) with its row count and the sum
of its rows' weights (no quantities), sorted by weight descending. `unweighed` = things − weighed,
`withoutPlace` = things − withPlace, `totalKilos` = grams ÷ 1000 rounded to 0.1 (used only by tests).

**Tips, in this order, each only when true:**
1. overdue > 0: "`N` thing(s) is/are overdue for looking after."
2. withCare ≤ 2 and things > 50: "Only `W` of your `T` things have care notes. The ones that wear out — boots,
   wetsuit, bike — are worth a schedule."
3. withoutPlace > 0: "`N` thing(s) has/have no storage place. Saying where they live makes packing quicker."
4. the heaviest thing is ≥ 5 % of the total (rounded): "`<name>` alone is `P`% of everything you own by weight."
5. neverUsed not empty: "`N` thing(s) went along and came home unused. Worth leaving behind next time."
6. unweighed > 0 and weighed > 0: "`N` thing(s) has/have no weight yet, so the totals are a little light."
Only the first 4 are shown.

**Tests.** Model `KitStatsTests`: `testItCountsWhatIsThereAndSaysWhatIsMissing`, `testTheHeaviestComeFirst`,
`testWhereThingsLive` ("Nowhere said" counted), `testWhatEachListWeighs`, `testCareDueIsCountedAndSpreadOverTheYear`
(a service due in late February counted once), `ThingsAndCareFixesTests.testTheYearAheadCountsCalendarMonths`
(31 Oct = this month; 1 Nov = next month though 27 days away; Sep 2027 = the twelfth; a year to the day = none),
`testATipIsOnlySaidWhenItIsTrue`, `testABigLibraryWithNoCareNotesIsNudged` (60 things),
`testThingsThatGoAlongAndAreNeverUsedAreNoticed`, `testARetiredThingIsNotPartOfTheKit`. UI
`testCareSaysWhatTheKitAddsUpTo` (figures exist; the weight says "kg" or " g"; heading reads "HEAVIEST THINGS";
`kit-heavy-0` opens Your things with "1 " thing; tip 0 says "overdue"; one of the tips starts "2 things went
along and came home unused").

**Not covered by a test.** The place and template bars; the year-ahead bars and their labels; the cut to 4 tips
(tips 5 and 6 can be hidden); tapping "Nowhere said".

**Traps and history.** The month labels name calendar months, and since 0.62 the bars count calendar months too
(they counted 30-day blocks from today). The labels use the device's clock and locale, the counts the day passed
in; the two agree except around midnight.

---

## Your things (App/Sources/Screens/ThingsScreen.swift — `ThingsScreen`)

**Purpose and origin.** Everything he owns, on a template or not — the web app's "Your things". Tap one to
change it; a change there reaches every template it is on. "Just added": their field test, 3 Oct 2026 ("When
you add an item, it needs to be on top of the list. Now it is just hidden in the total list.", 0.56).

**How it is reached and left.** Care → "Your things" (empty search); Care's dashboard bars (search filled in:
`ThingsScreen(searching:)` copies it into the search on appear when the search is empty). A sheet. Left with
"Done" (`things-done`; Escape too, ⌘. on an iPhone keyboard — 0.62) or (iPhone) a swipe down.

**What is on screen, top to bottom** (accessibility container `things-detail`):
1. Header (16 pt padding): "Your things" (22 heavy ink); right: "Done" (`HeaderButtonStyle`, filled orange).
2. Search field "Search your things…" (17, plain, min height 40, card background, radius 10, 1 pt line) with the
   ✕ (`things-search`, `things-search-clear`).
3. A row: the count (`things-count`, 15 bold muted, monospaced) — "1 thing" or "`N` things", counting what is
   SHOWN (after the search and the filter); right, only when at least one thing is on no template: the toggle
   pill "On no template `H`" (`things-nolist`; 15 bold; orange words on the card when off, white on orange
   when on; orange 60 % border; min height 36; selected trait when on). `H` counts ALL things on no template,
   whatever the search.
4. The list (`KeyboardAwayScroll` + `LazyVStack`, 16 pt sides, 24 pt bottom), with an invisible anchor at the
   top (`things-top`):
   - When something was added on this visit and is still shown: the heading "JUST ADDED"
     (`things-just-added`; the title upper-cased, 15 heavy, kerning 0.6, orange), its rows newest first, then —
     when other rows follow — the heading "A–Z" (`things-rest`).
   - Then every other shown thing, A–Z (`thingRows()` order).
   - A row (`thing-row-N`, N = its position on screen counting the Just added rows first): a full-width button;
     ONE line (0.62, his word: "set the item name and the info on the same line"): the name at the left (Body, ink,
     one line, keeps its room first) and at the right (Footnote, one line, cut in the middle when long) the template
     names (", "-joined) or "On no template", joined with " · " to the storage place when set — orange when on no
     template, muted otherwise; 5 pt vertical padding (until 0.62: the details on a second line, 10 pt padding); a
     1 pt line under it. A just-added row is lit for a moment: a rounded (8) orange 18 %
     background reaching 8 pt past the text on each side.
5. The add row at the BOTTOM (his rule): "A new thing" field (`thing-new-name`, 17 medium, min height 44) and
   "New" (`thing-new`, `FieldButtonLabel`, orange); its needs line `thing-new-needs`.

**Behaviour.**
- Search: keeps things whose `normName(name)` CONTAINS `normName(query)` (name only; not the place or the
  templates). The "On no template" toggle keeps only things with no template; both combine.
- Tap a row → the thing's page (`ThingEditor`) as a sheet over this one.
- New (or Return in the field): a blank or all-space name → "Type a name first." under the row (cleared as soon
  as the field changes). Otherwise `addThing(name:)`. Refused because a thing of that name exists (by `normName`):
  "You already have a thing called that." under the row, and the typed name STAYS (as Your bags does; 0.62 —
  the field used to empty without a word). Made: the field is emptied; if the
  current search would hide it, the search is emptied; its id goes to the front of "Just added" (a re-add of the
  same id is moved, not doubled); it is lit; 1.6 s later the light fades over 0.6 s (instantly with Reduce
  Motion); the list scrolls to the top (animated unless Reduce Motion).
- "Just added" lives only while the screen is open (`@State`): leaving and opening again puts every thing back
  in its A–Z place.

**Data.** Reads `thingRows()`; writes one new `items` record per New. The new thing is on no template, with
the defaults of `addThing`.

**iPhone vs Mac.** Mac: the sheet is at least 520 × 600. Otherwise the same.

**Tests.** UI `testYourThingsListsAddsAndRenames` (10 things; no "On no template" pill until "Sit mat" is
added; 11; the pill narrows to "1 thing"; the row opens; renamed "Sit pad" sticks);
`testANewThingShowsOnTopUnderJustAdded` (no heading at first; "Zip ties" on top under JUST ADDED; "Yoga strap"
above it; both back in A–Z after leaving); `testTheCrossEmptiesASearch` ("Head" → "1 thing"; ✕ → "10 things";
✕ gone); `testTheCrossKeepsTheKeyboard` (typing after the ✕ goes straight into the field);
`testEveryAddButtonIsReadyAndSaysWhatIsMissing` (New pressed empty says so; the line goes on typing);
`testAThingIsDeletedOnlyAfterAsking`, `testAThingsOwnDetailsAndItsListsAreChanged`,
`testAChangeToAThingReachesATripStillAhead`, `testHisOwnListsAreAddedAndProtectedWhileInUse`,
`testARowOfAListHasItsOwnAnswers`, `testANoteMadeOnSiteReachesTheThing` (all open things from here).

UI `testANewThingWithANameHeHasSaysSo` ("map" → the line says "already", the field still says "map", 10 things).

**Not covered by a test.** The light and the scroll to the top; the dashboard's search prefill other than
through `kit-heavy-0`.

**Traps and history.** 🪤 A Just added row is a row of its OWN (`.id("just-added-<id>")`), not the A–Z row moved
up: the Mac kept the moved row's old accessibility name ("thing-row-7" at the top of the list, 3 Oct 2026), so a
test — and VoiceOver — lost it.

---

## A thing's page (`ThingEditor`, in ThingsScreen.swift)

**Purpose and origin.** "One thing: what IT knows … and which lists it is on. A change here reaches every list;
a list's own exception for the bag stays that list's." Field order and wording follow his asks: Brand, Colour
and Notes (26 Sep 2026, 0.26); Delete thing (27 Sep, 0.29); headings in colour and larger (0.27/0.28); On a
plane and Valid until (his pre-trip ideas 4 and 5, 2 Oct 2026, 0.48); "Add a date" pill-sized and the words "in
N days" with quick spans (field test, 3 Oct 2026, 0.56); Notes on several lines (0.57); "Nobody's in
particular" → "Both have one" and Notes directly under the name (his asks, 4 Oct 2026, 0.59). Fields sit right
under their heading, the space goes BETWEEN headings (his screenshot, 28 Sep 2026: "put the Bike field much
nearer its heading").

**How it is reached and left.** A sheet from: Your things (a row), the table (a row's open arrow), a bag's
page ("Its details" and each thing "Usually in it"), the global search (a thing), a trip's "Check before you
go" (`TripScreen`), the trip review (`ReviewScreen`) and Pack to go home (`WayHomeScreen`, its "Open"). Left with
"Cancel" (`thing-cancel`: nothing is saved; Escape presses it too, 0.62 — never Save, so a name typed is not kept),
"Save" (`thing-save`: saves and closes, unless the name is refused), "Delete the thing" (closes, then deletes), or
(iPhone) a swipe down = Cancel. Only the thing's page closes, not the screen it was opened from. The screen behind is not
rebuilt, so it is exactly where it was (the table keeps its scroll position).

**What is on screen, top to bottom** (accessibility container `thing-detail`; 16 pt padding; headings 22 pt
apart; a field 6 pt under its heading):
1. Top bar: "Cancel" (outlined, muted) left; "Save" (filled orange) right.
2. **Name** — heading band "Name" (`thing-heading-name`); field (`thing-name`, 18 medium, min height 46, card,
   radius 10, 1 pt line), placeholder "Name".
3. **Notes** — band "Notes" (`thing-heading-notes`); a vertically growing field (`thing-notes`), placeholder
   "Anything worth remembering", 1 to 8 lines, 18 medium, min height 46. (A note written on site lands on a line
   of its own under the old text.) Under it (0.62), one line per note a template keeps for this thing on its own
   row: "On the <template> template: <note>" (15 medium muted, wraps, `thing-row-note-N`), from
   `Library.rowNotes(itemId:)` (RowNotes.swift) — the templates in their order (the bag list left out), then the
   rows in their order; only a note that is not blank and not the thing's own note (both trimmed); one note said
   twice on one template once. Read only: a row's note is changed on the template. Nothing when there is none.
4. **Kept at home** — band (`thing-heading-kept`); free-text field (`thing-storage`), placeholder "e.g. Hall
   closet"; under it his places (`storagePlaces()`, his order) as pills (`thing-place-N`, 15 pt, 36 tall,
   orange when lit, selected trait): a tap puts that place in the field; the pill matching the field (by
   `normName`) is lit. Typing stays free — a new place is just typed (0.62: a tap spells a known place the way
   the table's Storage menu does).
5. **Kind of thing** — pills band "Kind of thing" (`thing-category-title`), one pill per `CATEGORIES` entry
   (`thing-category-0` … `-11`; Electronics is `-7`), orange; single choice; the thing's category is lit.
6. **Usually packed in** — pills band (`thing-bag-title`): `bagNames()` = his own bags, in his bag list's order
   (the 17 built-in names only while he has none — then "Checked luggage" is `-2`; 0.64) (`thing-bag-N`); then the bag the thing names when it is none of those (so it is seen, lit);
   then **"No bag"** LAST (value "" — the same "no bag" a bag's delete can leave; 0.62). Single choice; a bag
   named in other capitals lights the offered spelling (`ThingEditor.bagChoices`).
7. **On a plane** — band (`thing-heading-plane`); two switches (orange tint): "Liquid" / "In the cabin: 100 ml at
   most, in the clear bag." (`thing-liquid`) and "Not allowed in the cabin" / "A knife, tools, gas — it goes in
   the hold." (`thing-restricted`); title 16 semibold, explanation 14 muted.
8. **Valid until** — band (`thing-heading-valid`):
   - No date: the pill "Add a date" (`thing-expiry-add`; 15 bold orange, orange 1.4 outline, min height 36) →
     sets the date to TODAY.
   - With a date: a compact date picker (`thing-expiry`) and "Remove the date" (`thing-expiry-clear`, 15
     semibold muted) on one row; under it the distance in words (`thing-expiry-distance`, 20 heavy; red once the
     date is past, ink otherwise) = `distanceWords(from: today, to: expiry)`; then five quick pills
     (`thing-expiry-quick-0` … `-4`): "+1 month", "+6 months", "+1 year", "+5 years", "+10 years", each setting the
     date to `addMonths(today, 1/6/12/60/120)`; the pill equal to the current date is filled orange with white
     bold words and the selected trait.
   - Always: "The trip warns before it runs out — a document (Documents & money) six months ahead." (14 muted).
9. **When** — pills band (`thing-when-title`), one pill per live `PHASES` step (id and label; `thing-when-N`).
10. **Whose it is** — pills band (`thing-owner-title`) when `ownerChoices()` is not empty: first
    "Both have one" (`OWNER_BOTH`; value "" = no owner — his words 4 Oct 2026, replacing "Nobody's in
    particular"; `thing-owner-0`), then each owner once (`thing-owner-1`…). Every owner named on a thing is offered,
    but once per `normName`, in the FIRST spelling met (his owners list before the things' names) — so a thing
    saying "kim" while "Kim" is offered shows no pill lit (the value compared is the exact text). With nobody
    named anywhere (0.62): the band stays, over "Nobody is named yet. Add the names in Settings, under Your
    choices." (`thing-owner-none`, 15 medium muted) — it used to vanish.
11. **Condition** — pills band (`thing-condition-title`): "Not said" (value "") then each live condition by
    label, storing its id (`thing-condition-N`). The lit pill is `conditionId(for:)` of the stored value, so a
    thing still holding a label lights its condition too.
11a. **Care** (0.62) — pills band "Care" (`thing-care-title`): "None" (0), "Every month" (30), "Every 3 months"
    (90), "Every 6 months" (182), "Every year" (365), "Every 2 years" (730) (`thing-care-0`…`-5`; an interval
    of his own, e.g. 45 from the web app, adds "Every 45 days"); under it a growing field "What to do, e.g. Wax
    the leather" (`thing-care-notes`, 1–6 lines, 18 medium) — the care notes.
12. **Weight** — band "Weight, in grams (0 = not known)" (`thing-heading-weight`); field (`thing-weight`),
    placeholder "0"; when Save found it unreadable, "The weight must be a number of grams, like 250 or 12,5."
    under it in red (`thing-weight-problem`, 15 semibold; gone as he types).
13. **Brand** — band (`thing-heading-brand`); field (`thing-brand`), placeholder "e.g. " and a clothing brand
    (see the code).
14. **Colour** — band (`thing-heading-colour`); field (`thing-colour`), placeholder "e.g. Black".
15. **On these templates** — pills band in VIOLET (templates colour, `thing-lists-title`): every template except
    the bag list (`templatesForThings()`), A–Z (`jsLocaleCompare`, base sensitivity) (`thing-lists-N`; with the sample: Common base 0,
    Hiking 1, Swim 2); several may be lit; a tap toggles.
16. "Only on some trips — Season, Indoor/Outdoor, Transport, Food — is set per template: open the template and
    tap this thing." (`thing-tags-hint`, 15 medium muted).
17. When a save was refused: the problem in red (`thing-problem`, 15 semibold): "A thing needs a name." or "You
    already have a thing called that."
18. "A change here reaches every template it is on. Past trips keep what they were packed with." (14 muted).
19. **Delete** — absent for a bag (a bag is deleted on its own page). Otherwise the small "Delete thing"
    (`thing-delete`); pressed, it becomes a card (card colour, red 1 pt border, radius 12): "Delete
    “`<name being edited>`”?" (16 heavy) and "It is on none of your templates. Trips you already packed keep it."
    or "It leaves your `A, B and C` template(s). Trips you already packed keep it." (15 medium; names joined
    "A", "A and B", "A, B and C"); "Keep it" (`thing-delete-no`, 16 bold ink) closes the question; "Delete the
    thing" (`thing-delete-yes`, 16 heavy white on a red capsule, min height 40).

The headings are `HeadingBand`s in orange (violet for On these templates); the pills 15 pt and 36 tall.

**Behaviour.**
- On appear the page copies the CATALOGUE item (not a template's resolved row) into a draft, and the set of
  template ids it has memberships on. Everything edits the draft; nothing is stored before Save.
- Weight field (0.62): its own text, filled on appear with `amountText(weight)` ("" for 0, whole grams without
  a point, otherwise up to two decimals — 88.7 stays "88.7"); typing is never rewritten, so "12," and "12."
  survive. Read on Save by `readAmount`: a comma or a point, empty = 0, anything else (letters, a minus,
  "1e3") = not a number. Untouched, the stored weight is kept exactly.
- **Save**, in this order: (0) the weight: unreadable → the line under the weight field, NOTHING saved, the page
  stays open. (1) when the trimmed name differs from the stored name, `renameThing` — on refusal
  the problem line shows and NOTHING else is saved (the page stays open). (2) One `model.change`:
  `updateThing` setting storage (trimmed), category, container, phase, ownedBy, condition, weight, manufacturer
  (trimmed), color (trimmed), note (trimmed), liquid, restricted, expiry, and — only when how often or the notes
  differ from the record — the care record (`normalizeMaintenance` of the old record with the new interval and
  trimmed notes: its log, last service and link kept; nothing said = no record); then for every template of
  `templatesForThings()` `setOnTemplate(on: chosen)` (a new membership goes to the bottom; an unticked template
  loses the membership; the bag list membership is never touched). (3) Close. Rename and update are two commits;
  each runs `followThing`, so open lines on trips still ahead follow.
- If the thing no longer exists when Save is pressed, the page just closes.
- Delete the thing: closes the page FIRST, then `deleteThing(id:)` (memberships and kit entries go; trips keep
  their lines).

**Data.** The catalogue item (`items` record) and its memberships (`memberships` records). The bag's `cabin`
extra key is preserved untouched (the draft is the whole item).

**iPhone vs Mac.** Mac: at least 520 × 600. The date picker is the platform's compact picker.

**Tests.** UI `testWhoseItIsOffersEachOwnerOnce` (`thing-owner-0` reads "Both have one"; Notes lie between Name
and Kept at home by frame; offered owners exactly ["Kim", "Robin"]; the "Kind of thing" heading ≥ 25 pt tall and
a pill ≥ 36); `testValidUntilSaysHowFarAwayAndOffersQuickSpans` (no words without a date; Add a date → "today";
the five quick pills read "in 1 month", "in 6 months", "in 1 year", "in 5 years", "in 10 years"; saved +1 year
reads back and its pill is lit; Remove the date → no words); `testAThingsOwnDetailsAndItsListsAreChanged`
(Electronics and the Swim template are kept); `testAChangeToAThingReachesATripStillAhead` (a new bag reaches the
trip still ahead); `testAThingIsDeletedOnlyAfterAsking` (Keep it keeps; Delete closes and the count drops 10 → 9);
`testTheEditorsLeadWithTheirHeadings` (every heading id above exists except the owner's);
`testATripChecksTheCabinAndTheDatesBeforeYouGo` (Liquid off and Remove the date clear the trip's checks);
`testAThingOpensFromTheWayHomeAndComesBack` (Kept at home saved; Save and Cancel return to the way home as it
was); `testANoteMadeOnSiteReachesTheThing` (Notes hold "old note\nOn site D Mon YYYY: text");
`testHisOwnListsAreAddedAndProtectedWhileInUse` (a place typed in Kept at home counts as in use);
`testARowOfAListHasItsOwnAnswers` (a template row's own bag does not change the thing's `thing-bag-1`);
`testYourThingsListsAddsAndRenames` (rename); `testOneSearchReachesEverything` (search → page → Cancel);
`testARowOpensItsThingAndComesBackToTheSameSpot` (Colour from the table). Model: `DateWordsTests`
(`distanceWords`, `addMonths`, every quick choice reads back as itself from every day of two years).

UI (0.62) `testAThingsPageTakesDecimalsAPlaceNoBagAndCare` ("abc" → the weight line and the page stays; "12,5"
kept while typing and read back as "12.5"; the first place pill fills the field and is lit; "No bag" is the
last bag pill and stays lit; Every month + what to do → Care says "1 due soon"); `testWhoseItIsSaysWhereNamesComeFromWhenNobodyIsNamed`
(every owner blanked by Change all → `thing-owner-none` names Your choices);
`testTheTableOffersHisOwnBagsAndOwnersAndAConditionReachesToBuy` (a condition set in the table lights
`thing-condition-4`).

**Not covered by a test.** The rename refusal messages; Brand; When; the hint and footer texts; that a bag has
no Delete; an interval of his own ("Every 45 days").

**`distanceWords(from:to:)` and `addMonths` (PackingLibrary/DateWords.swift).** "today", "tomorrow", "in `D`
days" (2–13), then whole weeks "in `W` weeks" up to two whole calendar months (with "in 1 month" for a month
and up to 4 weeks + days more, i.e. 1 whole month and < 5 weeks), "in `M` months" (2–11), "in 1 year", "in `Y`
years"; never rounded up (5 months 30 days = "in 5 months"). Past: "yesterday (out of date)", "`X` ago (out of
date)" with the same units. "" when either side is not exactly YYYY-MM-DD. `addMonths(ymd, n)`: a day the target
month lacks becomes its last day (31 Jan + 1 month = 28/29 Feb); years outside 0…9999 give "".

---

## Care → Bags (App/Sources/Screens/BagsScreen.swift, PackingLibrary/Bags.swift)

**Purpose and origin.** His bags and their three numbers: what each may carry (max kg), its size (litres) and
its empty weight (grams). A bag with a max weight shows how full it is on every trip (0.17, 25 Sep 2026).
🚨 WORDS (his ask, 27 Sep 2026): the app says **Bags** everywhere, never "containers"; the stored data keeps the
web app's names (`container` fields, list role "container", list name "Containers") because they are the shared
format with the web app, backups and iCloud.

**How it is reached and left.** Care → "Bags" (`care-bags`), a sheet. "Done" (`yourbags-done`; Escape too, 0.62) or a swipe.
A trip's bag ("Goes in the cabin", `BagCabinRow`) can also MAKE a bag (see a bag's page).

**What is on screen** (container `yourbags-detail`):
1. Header: "Your bags" (22 heavy orange), the count (`yourbags-count`, 15 heavy muted), "Done" (filled).
2. Fixed (does not scroll — his ask 26 Sep 2026, "keep the header row visible"): "Give a bag its max weight and
   every trip shows how full it is." (14 medium muted), then the column names right-aligned over the fields:
   "MAX KG" (64 wide), "LITRES" (64), "EMPTY G" (70) (10 heavy muted, kerning 0.4; one combined element
   `yourbags-columns`); a 1 pt line under.
3. Scrolling: one row per bag (min height 46, line under):
   - the name button (`bag-N-name`): the name (15 semibold, may shrink to 80 %) and under it the glance line
     (12 medium muted) — "`N` thing(s)" and/or "last trip `<weight>`" joined " · " (`BagsCard.kilos`: "N g" under
     1000 g, else "%.1f kg"), also the button's accessibility value; a small chevron. Opens the bag's page.
   - three number fields (`bag-N-maxkg` 64 wide, `bag-N-litres` 64, `bag-N-empty` 70; 15 semibold monospaced,
     right-aligned, height 34, card, radius 8). Max kg and litres show "" when 0, else the number without a
     decimal when whole, otherwise one decimal (`BagsScreen.show`); empty grams shows whole grams.
   - No bags: "No bags yet." (15 medium muted).
4. The add row at the BOTTOM: "A new bag" (`bag-new-name`) and "Add" (`bag-new`, orange `FieldButtonLabel`);
   needs line `bag-new-needs`.

**Behaviour.**
- Numbers are SAVED AS TYPED (`onChange` of the text): trimmed, a comma read as a point; empty → 0;
  unreadable → no change; a value different from the stored one → `setBag(id:maxKg:/capacityL:/emptyGrams:)`,
  which stores max(0, value) through `updateThing` (so `followThing` runs). The fields are filled from the bag
  when the row first appears, and follow the bag afterwards (0.62): when a number changes elsewhere — on the
  bag's own page, a sheet over this one — the row shows it as soon as that page closes, unless the field
  already says that number (so what he is typing in the row is never rewritten).
- Add (or Return): normalised name empty → "Type a name first."; a BAG of that name exists → "You already have a
  bag called that."; else `addBag(name:)` and the field is emptied.
- `addBag(name:)`: refused for blank or an existing bag name (`normName`). Makes his bag list first when he has
  none (`newList(name: "Containers", role: "container")` through `saveTemplate`). A THING he already owns by
  that name becomes the bag (no second thing: a toiletry bag he has only ever packed); otherwise `addThing`.
  Then `setOnTemplate(bag list, on)` — the new bag is last.
- `bags()` = the resolved bag list's rows in its own order. `bagList` = the first template with role
  "container". `shownName(list)` = "Bags" for it.
- `bagLimits()` = `containerLimits(resolvedTemplates())`: the built-in ceilings overlaid with each bag's own
  maxKg > 0. 🪤 It must be given the RESOLVED lists (the shells have no rows; the first Bags card did exactly
  that and saw none of his limits — its test caught it).
- `bagFacts(name:)`: `things` = items whose own container, or any membership's container exception, is this
  bag (by `normName`), minus bags, A–Z; `trips` = every trip whose `bagLoads` (things' weight × effective
  quantity, the trip's nights; NOT the scale reading, NOT the bag's empty weight) has this bag with grams > 0,
  as `{tripId, name, date (start date, else the creation day), grams, limitKg, over}`, newest date first;
  `heaviest` = the most grams.

**Data.** A bag = an item with a membership on the bag list. Its maxKg, capacityL and weight (= empty weight)
are its own fields. All per-trip notes about a bag (scale reading `WEIGHED_KEY`, photos `BAG_PHOTOS_KEY`) are
kept on the trip under the bag's NAME.

**iPhone vs Mac.** Mac: at least 480 × 560.

**Tests.** Model `BagsTests`: `testABagGetsMadeAndItsListWithIt`, `testTwoBagsWithOneNameAreRefused`,
`testALimitSetHereIsTheLimitATripUses`, `testSettingNumbersOnSomethingThatIsNotABagIsRefused`,
`testAThingHeAlreadyOwnsBecomesABagRatherThanBeingRefused`; `BagEditsTests.testTheBagListIsShownAsBags`,
`testABagKnowsItsTrips`. UI `testABagsLimitReachesTheTrip` (the column names sit outside every scroll view;
max 1 kg typed with Return and 33 litres typed WITHOUT Return both stay; the trip's Bags card turns "over");
`testABagIsRenamedAndDeletedFromItsPage`; `testEveryAddButtonIsReadyAndSaysWhatIsMissing`.

UI `testYourBagsShowsANumberChangedOnTheBagsPage` (7 typed as max kg on the bag's page → the row says "7").

**Not covered by a test.** The duplicate-bag message; negative or comma numbers; the glance line; the empty state.

**Traps and history.** 🪤 Saved AS HE TYPES: the numbers used to be saved only on Return, so numbers typed and
left looked set and were lost (his max weights of 26 Sep 2026 morning never reached the trips; fixed 0.25).

---

## A bag's page (App/Sources/Screens/BagDetail.swift; Bags.swift; TripChecks.swift for the cabin)

**Purpose and origin.** His asks (26 Sep 2026): rename a bag, delete a bag, and "see or get more information
about the bags" (0.26). His choices: a rename reaches every trip, old ones too; a delete first moves the bag's
things to a bag he picks — or to no bag (27 Sep: "an alternative… to not choose… do not use another bag"); an
unused bag gets a plain delete (27 Sep, his empty handbag); a bag that is also a thing he packs asks whether it
goes completely (27 Sep, "I thought it would just be a deleted bag"). "Goes in the cabin": his idea 4 (2 Oct
2026, 0.48).

**How it is reached and left.** Your bags → a bag's name. A sheet; "Done" (`bag-done`; Escape too, 0.62) or a swipe. If the bag
no longer exists the page closes itself on appear. "Delete …" closes it.

**What is on screen** (container `bag-detail`, 18 pt between blocks):
1. **Header:** the name IS the field (`bag-name`, 22 heavy orange). When the typed name differs from the stored
   one (trimmed), "Rename" appears beside it (`bag-rename`, 15 bold white on orange). "Done" (filled) right. A
   refusal shows under it in red (`bag-problem`, 14 semibold): "A bag needs a name." or "You already have
   something called that."
2. **Numbers:** "MAX KG", "LITRES", "EMPTY G" (11 heavy muted) over fields `bag-detail-maxkg`,
   `bag-detail-litres`, `bag-detail-empty` (17 semibold monospaced, height 40) — saved as typed, same rules as
   Your bags.
3. **Goes in the cabin** switch (`bag-detail-cabin`, orange): "Goes in the cabin" / "Carry-on. On a plane trip,
   the trip checks it for liquids and things not allowed on board."
4. **Usually in it** `N` (`bag-things-count`): "Nothing yet. A thing goes here when its “Usually packed in” is
   this bag." or up to 12 things (`bag-thing-i`: name 16 medium, weight when > 0), each opening its thing's page;
   "Show all `N`" / "Show fewer" (`bag-things-all`) when more than 12.
5. **On your trips** `N` (`bag-trips-count`): "Not packed on a trip yet." or up to 8 trips (`bag-trip-i`, one
   combined element): name, date (13 monospaced), and "`<weight>` / `L` kg" when the trip had a limit else the
   weight, red when over; "Heaviest: `<weight>` on `<trip>`" (`bag-heaviest`) when more than one trip.
6. **Its details** door (`bag-details`): "Its details" / "Kept at home, condition, brand, colour, notes" → the
   bag's own thing page (which has no Delete for a bag).
7. **Delete:** the small "Delete bag" (`bag-delete`). Pressed, a card (red 1 pt border) asks "Delete
   “`<name>`”?" and:
   - **Nothing packed in it** (`bagIsUsed` false: no thing, list row, list default or trip line names it):
     "Nothing is packed in the `<name>`, so nothing needs to move." (`bag-delete-empty`).
   - **Used:** "The `N` thing(s) packed in the `<name>` will be packed in another bag instead. Choose which one,
     or no bag:" — or, when it is used only by list defaults or trip lines, "Anything packed in the `<name>`
     will be packed in another bag instead. Choose which one, or no bag:" (`bag-delete-explain`); then one pill
     per OTHER bag (`bag-move-i`) and "No bag" (`bag-move-none`), single choice.
   - **Also on templates as a thing** (`listsHoldingBag`): "The `<name>` is also on your `A and B` template(s), as
     something you pack." (`bag-delete-lists`).
   - Buttons: "Keep it" (`bag-delete-no`, closes the question and forgets the choice). Right side: while a used
     bag has no choice yet, "Delete" (`bag-delete-yes`, full red like every main button — 0.62; it was a faded
     "Choose first" that did nothing): pressed, it deletes nothing and says under the buttons, in red, "Choose
     where its things go first — another bag, or No bag." (`bag-delete-needs`, 15 bold; gone once a bag or No
     bag is picked, or on Keep it). Ready and on no template: one button `bag-delete-yes` — "Delete the bag"
     (unused), "Delete, no bag" (No bag chosen) or "Move and delete". Ready and also on templates: a second row
     with "Keep it on `<template>`" / "Keep it on my templates" (`bag-delete-yes`, red outlined) and "Delete
     completely" (`bag-delete-all`, red filled).

**Behaviour.**
- Rename = `renameThing(id:to:)` (refused for blank or a name ANY other thing has); on success the field goes
  back to showing the stored name. `renameBagEverywhere(from:to:)` rewrites, comparing by `normName`: every
  item's `container`; every membership's container exception; every template's `defaultContainer`; every trip
  line's `container`, `_ovContainer`, `_tplContainer`, `_defContainer` — on ALL trips, past ones too; and each
  trip's notes about the bag (`moveBagNotes`): photos move to the new name (its own first, then the moved ones,
  up to `BAG_PHOTOS_MAX` = 3; photos pushed out are deleted unless something else still shows them); the scale
  reading moves only when the new name had neither a reading nor lines of its own on that trip (a reading is
  what ONE bag weighed); "" as the new name = no bag (photos go to "Other", the reading is dropped).
- Delete (`delete`): closes the page, then `deleteBag(id:moveTo:completely:)` with moveTo = the chosen bag ("" =
  no bag; "" also for an unused bag). `deleteBag`: refused unless it is one of his bags and `moveTo` is "" or
  another bag's name; renames everything to the target; takes the bag off the bag list; deletes the THING too
  when `completely`, or when it is on no other template. Past trips keep their line COUNT.
- Cabin: `Library.isCabinBag(thing)` = the bag's `extra["cabin"]` Bool when set, else its NAME says so
  (`normName` contains "carry-on", "carry on", "carryon", "hand luggage" or "cabin"). The switch writes
  `setBagCabin(id:on)` → `extra["cabin"] = on` through `updateThing`. A trip's bag can be said to go in the
  cabin from the trip (`setCabin(container:)`, field test 7.3, 3 Oct 2026): a name that is not a bag yet BECOMES
  one (and then shows here); "Other" and "" are refused.

**Data.** The bag's item (`cabin` in its extra keys, so the web app's model is untouched); memberships;
templates; trips (lines, `extra` scale/photos); photos.

**iPhone vs Mac.** Mac: at least 520 × 640.

**Tests.** Model `BagEditsTests`: `testARenamedBagTakesItsThingsListsTripsAndLimitAlong`,
`testADeletedBagMovesItsThingsToTheBagHePicks`, `testABagCanGoWithItsThingsLeftWithoutABag`,
`testABagThatIsAlsoOnAListIsKeptOrDeletedCompletely`, `testAThingIsDeletedButABagIsNotDeletedAsAThing`,
`testABagKnowsItsTrips`; `BagNotesTests`: `testARenamedBagTakesItsScaleReadingAndPhotosAlongOnEveryTrip`,
`testAPhotoKeptByAnOlderVersionAndAnotherSpellingFollowTheRename`,
`testARenameOntoANameTheTripAlreadyKeepsMergesThem`, `testADeletedBagTakesItsPhotosAndReadingToTheBagHePicks`,
`testABagDeletedWithNoBagLeavesItsPhotosWithItsThingsAndDropsItsReading`; `TripChecksTests`:
`testABagSaysWhetherItGoesInTheCabin`, `testABagNameOnTheTripCanBeSaidToGoInTheCabin`. UI
`testABagIsRenamedAndDeletedFromItsPage` (rename reaches the list and the trip's Bags card; delete refuses
before a choice and says so (`bag-delete-needs`), explains plainly, offers No bag, moves the things; an unused bag deletes at once with no
choices; a thing made a bag offers Keep it on / Delete completely, and Delete completely removes the thing);
`testABagSaysWhetherItGoesInTheCabin` (a carry-on is in the cabin by its name; switched off, the plane trip no
longer checks it); `testABagOnTheTripSaysWhetherItGoesInTheCabin` (from the trip).

**Not covered by a test.** The rename refusal texts; "Show all"; the trips list beyond the first; "Heaviest:".

---

## All your things · table (App/Sources/Screens/ThingsTable.swift)

**Purpose and origin.** All his things as a SPREADSHEET, as the web app's "All items · table" works: the name
column stays put while the rest travels sideways, the heading stays put while the rows travel down, every cell
is changed where it stands, he chooses which columns he sees and in which order, and sorts by any. The first
attempt (three fixed columns in a list) got: "It is not at all what it should be. You should be able to quickly
update items — like Excel." Releases: 0.9 (23 Sep 2026) the table; 0.11 a real spreadsheet; 0.12 Change all;
0.14 How many and Section per template; 0.58 (4 Oct 2026) filter by any column, up to three sort levels, the
open arrow, the Mac window, 44-point arrows in Columns.

**How it is reached and left.** Care → "All your things · table" (`care-table`). iPhone: a sheet; "Done"
(`table-done`; Escape too — ⌘. on an iPhone keyboard, 0.62) or a swipe closes it. Mac: the window "All your things"
(see The Mac window); "Done" closes the window, and Escape does NOT (0.62: `.keyboardShortcut(inWindow ? nil :
.cancelAction)` — a window closes with ⌘W, and Escape pressed in its search field would close the whole table).
Its sheets (Filter, Sort, Columns, Change, a thing) do close with Escape, on the Mac too.

**What is on screen, top to bottom** (container `table-detail`):
1. **Title row** (16 pt sides, 14 top): "All your things" (21 heavy orange), the number of rows shown
   (`table-count`, 15 heavy muted, monospaced — a bare number, e.g. "10"), "Done" (filled orange).
2. **Tools row:** a search field "Search" (`table-search`, ✕ `table-search-clear`; 15 medium, min height 34,
   radius 9); "Filter" or "Filter `N`" (`table-filter`; N = number of filtered columns; filled orange when any);
   "Sort" or "Sort `N`" (`table-sort`; N = number of levels; filled when more than one); "Columns"
   (`table-columns`). Chips: 14 bold, min height 34, radius 9.
3. **Quick chips:** "All" (`table-filter-all`), "No weight" (`table-filter-weight`), "No place"
   (`table-filter-place`) — capsules 14 bold, min height 30; the chosen one filled orange with the selected trait.
4. **Filter pills** (only when any column filter is on): a sideways-scrolling row with one pill per filtered
   column that is still a column — "`<Column>`: `<answers>` ✕" (14 bold orange on 14 % orange, id
   `table-pill-<safe key>`, accessibility label = the words) — then "Clear" (`table-filters-clear`, 14 bold red).
   Tapping a pill removes that column's filter; Clear removes all.
5. **"Sorted by …"** (`table-sorted-by`, 14 semibold muted, up to 2 lines), only when there is more than one
   level: "Sorted by `Name` ▲, then `Hiking · section` ▼" (each level's title and arrow, joined ", then ").
6. **The ticked bar** (only while anything is ticked, or a Change all can still be undone): "`N` ticked"
   (`table-chosen-count`, 15 heavy orange) — "`N` ticked · `H` not shown" when `H` ticked things are hidden by
   the search, a chip or a filter (0.62) — "Change all" (`table-change-all`, 14 bold white on orange capsule),
   "Clear" (`table-clear-chosen`, 14 bold muted); right: after a Change all, "Undo" (`table-undo`, 14 bold red,
   red outlined capsule); and on a line of its own under them what the change was, "`N` changed: `<sentence>`"
   — e.g. "2 changed: Condition → New" (`table-said`, 15 semibold muted, up to 2 lines; 0.62 — it said only
   "`N` changed").
7. A divider, then **the grid** — one `ScrollView` that scrolls both ways, holding a `LazyVStack` with a pinned
   section header:
   - **Band row** (20 tall): an empty block the width of the name column, then one band per run of neighbouring
     columns of the same group — "The thing itself", "On this template", "On these templates" (11 heavy orange,
     kerning 0.4, id `table-band-<n>-<group>`). A band's title holds still inside its run while the grid scrolls
     sideways (offset = min(max(0, scrolled − band start), max(0, band width − 130))).
   - **Column-name row** (26 tall): the "tick everything shown" box (`table-pick-all`, label "Tick everything
     shown"; an 18 pt outlined box with a dash) — if every shown row is already ticked it unticks them, else it
     ticks them all; "Thing" (`table-head-name`, 12 heavy muted, ▲ or ▼ in orange when the table is sorted by
     name); then one heading per column (`table-head-<column id>`), its title (12 heavy muted, 1 line, may shrink
     to 70 %) and ▲/▼ when it is the first sort level; a 1 pt line at each column's right edge; a 1 pt line under
     the row.
   - **Rows** (`table-row-N`, 34 tall, alternating background, a 1 pt line under each): the name cell — the
     tick box (`table-N-pick`, 18 pt, filled orange when ticked, no tick mark: "the colour is enough" — his
     words; selected trait), the name (`table-N-name`, 14 semibold, 1 line, may shrink to 80 %), and the open
     arrow (`table-N-open`, an orange chevron in a 26 × 34 area, label "Open `<name>`", tooltip on the Mac) — then
     one cell per chosen column (see Table columns).
8. When no row is shown, under the grid (`table-none`, 16 medium muted): "Nothing matches these filters." (any
   column filter on) — else "Nothing matches." (quick chip All) — else "Nothing missing that — all filled in."

**Behaviour.**
- **Which rows:** all `Library.items` (bags and "not in use" things included) → the search (normalised name
  contains the normalised query) → the quick chip ("No weight" = weight ≤ 0; "No place" = trimmed storage empty)
  → the column filters still meaning something (`TableKeys.filters(stored, library)` = `Library.liveFilters`,
  then `Library.passes`) → the sort (`Library.sortThings` with the first level `SortLevel(key: sortBy,
  descending:)` followed by the stored "then by" levels, any level whose key `Library.tableKnows` no longer
  dropped).
- **Forgetting what is gone (0.62):** on appear, and whenever the templates change (here, or on the other
  device), a stored filter or sort level naming a template that is gone (or his bag list) is dropped from
  `ams.table.filters` / `ams.table.sort` (back to "name", ▲) / `ams.table.then` (`forgetWhatIsGone`).
- **A heading press** (`turn(key)`): the same key again turns it over; another key becomes the first level,
  ascending; the "then by" levels lose any level with that key.
- **Ticks:** `chosen` holds ids and is kept while he searches or filters, so ticked rows that are now hidden
  stay ticked (the count and Change all include them) — on purpose ("narrow with a chip, then take the lot"),
  and the bar says how many are not shown (decided in the 0.62 spec pass: say it, do not drop his ticks).
- **Open arrow:** opens the thing's page as a sheet; the table underneath is not rebuilt, so it stays scrolled
  where it was; Save or Cancel comes back to the same spot.
- **Change all:** opens `BulkChange` with the ticked things. When it returns a change: the ticked things as they
  are now are kept as `wasBefore`, the bar says "`N` changed: `<sentence>`", every ticked thing gets
  `updateThing` with the change (one commit), and the things as the change left them are kept as `madeAs`.
  **Undo** = `Library.undoChange(before:after:)` (one commit, 0.62): for each thing, only the fields the change
  altered, and only where the thing still holds what the change wrote, go back — a cell edited on those things
  since, or the same field set again by hand, stays (Undo used to write each thing back WHOLE). Then it forgets
  them. Only the last Change all can be undone; a second Change all replaces the kept copy; closing the table
  forgets it.
- What stays while he works, on this device only (`@AppStorage`, UserDefaults, not synced):
  `ams.table.columns` (his columns as a comma-separated list of ids; "" = the starting columns),
  `ams.table.sort` (first sort key, "name"), `ams.table.down` (Bool, false), `ams.table.then` (JSON array of
  `SortLevel {key, descending}`), `ams.table.filters` (JSON object column id → array of kept answers).
  The search, the quick chip, the ticks and the undo copy are `@State` and start fresh every time.

**Data.** Reads items, memberships, templates, his Settings lists. Each cell change is one `model.change`
(usually one `items` or `memberships` record, plus trip lines through `followThing`).

**iPhone vs Mac.** The name column is 210 wide on the Mac, 172 on the iPhone (148 before the open arrow, 0.58).
Mac: own window, at least 760 × 560; iPhone: a sheet. The open arrow's tooltip shows only on the Mac.

**Tests.** UI `testTheTableSortsAndSaves` (10 rows; the weight heading pressed twice turns the order; a weight
typed into `table-0-weight` and Return changes the Care line); `testTheTableChipsFindWhatIsMissing` (No weight
narrows; filling one in drops the count by one; All restores 10); `testARowOpensItsThingAndComesBackToTheSameSpot`
(the arrow opens row 6; after Save the same thing is in row 6 at the same frame; the colour shows in the newly
shown Colour column; Done closes); `testManyThingsAreChangedAtOnceAndCanBePutBack`;
`testTheTableFiltersByAnyColumn`; `testTheTableSortsByLevels`; `testTheTableTakesTheColumnsHeChooses`;
`testWhatBelongsToAListIsEditedPerList`.

UI (0.62): `testChangeAllRefusesANonNumberAndCountsTicksOutOfSight` (two ticked, a search shows one → "2 ticked ·
1 not shown"), `testATemplateDeletedTakesItsFilterAndColumnAlong`, `testWhoseItIsSaysWhereNamesComeFromWhenNobodyIsNamed`
(`table-pick-all` ticks all ten). Model: `ThingsAndCareFixesTests.testUndoPutsBackOnlyWhatChangeAllChanged`.

**Not covered by a test.** "No place"; the empty-state texts; the band titles holding still.

**Traps and history.** 🪤 Performance: the first build kept the names in a column of their own moved by the
scroll offset — every one of his ~431 name rows was laid out again on every scroll tick, the app never went
idle and GitHub's runner timed out; now only the visible rows' name cells counter-scroll (`offset(x: across)`,
`zIndex(2)`, opaque). 🪤 The grid's width is SPELLED OUT (name width + column widths): a two-way scroll view asks
its content how wide it is and a lazy stack answers by building every row (two UI tests went from ~20 s to
~150 s). 🪤 The open arrow is a button of its own so the name stays plain text a test can read (a button folds
its words in on the Mac).

---

## Table columns and cells (App/Sources/Screens/TableColumns.swift)

**The columns** (`TableColumns.all = intrinsic + perListColumns + listColumns`), id · title · width · kind:

| Group "The thing itself" (`intrinsic`) | | | |
|---|---|---|---|
| `weight` | Weight | 74 | number (grams) |
| `storage` | Storage | 150 | choice from his places |
| `container` | Packed in | 140 | choice from bag names |
| `ownedBy` | Owner | 110 | choice from his owners list |
| `packer` | Packed by | 110 | choice from his packers |
| `condition` | Condition | 120 | choice from his conditions |
| `color` | Colour | 100 | words |
| `size` | Size | 84 | words |
| `manufacturer` | Maker | 120 | words |
| `model` | Model | 120 | words |
| `serial` | Serial | 120 | words |
| `note` | Note | 180 | words |
| `liquid` | Liquid | 62 | tick |
| `charging` | Charges | 68 | tick |
| `restricted` | Restricted | 78 | tick |
| `consumable` | Runs out | 72 | tick |
| `perNight` | Per night | 74 | tick |
| **Group "On this template"** (`perListColumns`) | | | |
| `listQty` | How many | 92 | per template: quantity |
| `listSection` | Section | 140 | per template: section |
| **Group "On these templates"** (`listColumns`) | | | |
| `list:<template id>` | the template's name | 100 | tick: on this template |

The template columns follow `Library.templates` order (after a load, sorted by template id — for ids this app
makes, roughly creation order), and are `templatesForThings()`: never his bag list (0.62 — a tick there made a
thing a bag, and an untick dropped a bag from the bag list without `deleteBag`'s question; a bag is made and
deleted on Your bags). The Filter and Sort sheets offer the same templates. Starting columns (`startingColumns`, when he has chosen nothing): weight,
storage, container, ownedBy, packer, condition, listQty. `TableColumns.ids(stored, library)` drops stored ids
that are no longer columns (a deleted template) BEFORE anything counts them (0.62), and gives the starting
columns when none is left. Row height 34 (`TableColumns.rowHeight`).

**The answers for choice columns (`Answers2`, worked out ONCE per redraw and handed to every cell):** each a
`Choice {value, label}` — what is stored and what he reads. places = `storagePlaces()`; bags = `bagNames()`
(his own bags too, 0.62); owners = `ownerChoices()` (every owner his things name, as the thing's page offers —
0.62); people = `people()` names; conditions = `conditions()` as {id, label} (the ID is stored, 0.62); plus a
map from a stored condition (id, or label by `normName`) to its label; every membership as
"itemId|templateId", memberships by thing, each template's sections and shown name.

**Each cell** (`Cell`, id `table-N-<column id>`, the column's width × 34, a 1 pt line at its right):
- **Number** (weight): a text box showing `amountText` (whole grams without a point, else up to two decimals —
  0.62; it showed the rounded whole grams) or "" for 0; a blank cell is tinted orange 10 % while not being typed
  in; text that is not a number tints it red 18 % (0.62). Saved on Return or when the box loses focus through
  `readAmount` (a comma or a point; empty = 0); not a number or negative → not saved (the typed text stays,
  red); a value equal to the stored one is not written (0.62: tapping into 88.7 and out wrote 89). When the
  thing changes elsewhere the box follows (unless it is being typed in).
- **Words** (colour, size, maker, model, serial, note): a text box; saved on Return or leaving, trimmed, only
  when different from the stored (trimmed) value.
- **Choice** (storage, packed in, owner, packed by, condition): a borderless menu showing the stored value — for
  a condition its label (0.62) — or "—" (13; "—" bold orange on an orange 10 % tint); the menu lists the
  answers' labels, a divider, and "Leave blank". Choosing writes the answer's VALUE (for a condition its id)
  through `updateThing`. Accessibility value = what the cell shows.
- **Tick** (liquid … per night): a 20 pt rounded box, filled orange when on (no mark); a tap flips it through
  `updateThing`; selected trait when on.
- **On a template** (`list:<id>`): the same tick; a tap calls `setOnTemplate(itemId:templateId:on:)` — taking
  a thing off a template drops only that membership; the thing, its weight, care and photos stay.
- **Per template** (How many, Section) — only answerable when the thing is on EXACTLY one template: How many is a
  text box saved (trimmed, every time it is left) to that membership's `qty` (`updateMembership`); Section is a
  menu of that template's sections plus "No section", showing the section's name, "Where?" (orange bold) when
  the template has sections but none is chosen, "—" (muted) when it has none. With no membership the cell reads
  "—"; with several, "`N` templates" (12 medium muted, not editable; tooltip "Different on each template — open
  the thing to set it"; with none: "On no template"); accessibility value = those words.

**Tests.** UI `testTheTableTakesTheColumnsHeChooses` (a Liquid tick flips), `testTheTableSortsAndSaves` (a weight
cell saves), `testWhatBelongsToAListIsEditedPerList` (the sample's second thing reads "2 templates" and is not a
text box; the first takes "3" and keeps it after closing and reopening),
`testARowOpensItsThingAndComesBackToTheSameSpot` (the Colour box shows the colour set on the page),
`testManyThingsAreChangedAtOnceAndCanBePutBack` (Condition cells).

UI (0.62) `testTheTableOffersHisOwnBagsAndOwnersAndAConditionReachesToBuy` (through Change all, which offers the
same `Answers2`: his own bag after the seventeen, Kim and Robin as owners, Needs replacing stored so the cell reads
it, the page lights it and To buy offers the thing); `testTheBagListIsNoColumnOfTheTable` (`-uiTestingChecks`:
three template columns in Filter and in Columns, not four).

**Not covered by a test.** Choice menus themselves (no test opens one); the Section menu; the "On a template"
tick; the red and blank tints.

**Traps and history.** 🪤 Each cell used to ask the library itself: a screenful of 20 rows × 5 choice columns =
100 walks of his Settings rows per frame, and a tick column 20 rescans of all memberships; one test went from
21 s to 151 s. Hence `Answers2`.

### Choosing columns (`ColumnPicker`)

Opened by "Columns" (`table-columns`) as a sheet (container `columns-detail`; Mac at least 460 × 540). Header
"Columns" (20 heavy orange) and "Done" (`columns-done`, filled; Escape too, 0.62). "SHOWING, IN THIS ORDER" (12 heavy muted,
kerning 0.6): one row per shown column of `TableColumns.ids` — live ids only (min height 44, line under): its
title (16 semibold), an up arrow (`columns-<key>-up`, disabled on the first row; `<key>` = `TableKeys.safe`, so a
template column is `list-<n>` — 0.62), a down arrow (`columns-<key>-down`, disabled on the last) — each a
22 pt drawn chevron pressed anywhere in a 44 × 44 square (his ask, 4 Oct 2026: "These arrows are rather
difficult to hit") — and "Hide" (`columns-<id>-hide`, 15 bold red, at least 52 × 44). "NOT SHOWING": every other
column, a row with its title (16 medium muted) and "Show" (14 bold orange), the whole row a button
(`columns-<key>-show`). Up/down swap neighbours; Show appends at the end; Hide removes — except the LAST column,
which cannot be hidden (an empty list would mean "nothing chosen" and bring the starting columns back). Every
change is written at once to `ams.table.columns` — live ids only, so a gone template's id is forgotten at the
next change (0.62; it kept an invisible place that arrows and "the last column" counted).
Tests: `testTheTableTakesTheColumnsHeChooses` (arrows and Hide at least 44 × 44; hiding six and showing Liquid;
the grid has Liquid and not Storage), `testManyThingsAreChangedAtOnceAndCanBePutBack`,
`testARowOpensItsThingAndComesBackToTheSameSpot`. Not tested: up/down order.

---

## Filtering the table (TableFilterSort.swift `FilterSheet`; PackingLibrary/ThingFilters.swift)

**Purpose and origin.** His ask, 4 Oct 2026: "I would like all existing columns to be able to be used as filter
criteria" (Travel section, owner, packed by, and so on) — 0.58. Ticks in one column mean "any of these"; two
filtered columns must both hold. The answers offered are the ones his things actually have, each with how many,
so a filter never empties the table by surprise.

**How it is reached and left.** "Filter" (`table-filter`) → a sheet (container `filter-sheet`; Mac at least
480 × 560). "Done" (`filter-done`; Escape too, 0.62 — only the filter closes, the table stays) or a swipe; every
tick is stored at once.

**What is on screen.** Header "Filter" (22 heavy orange), "`S` of `B`" (`filter-count`: S = things passing all
filters, B = things after the search and the quick chip), "Done". When any filter is on: "Clear all filters"
(`filter-clear-all`, 15 bold red). Then three groups, each under a `HeadingTitle` in orange: "The thing itself"
(the 17 intrinsic columns), "On this template" (How many, Section), "On these templates" (one per template,
the bag list included). A column row (`filter-col-<safe key>`, min height 46): its title (17 semibold), on the
right "Any" (muted) or the summary of its ticked answers (bold orange), and ▾/▴. One column is open at a time;
opening one closes the other and empties the narrow field. An open column lists its answers: a "Narrow the
answers" field (`filter-narrow`, with ✕) when there are more than 12; "None of the things in view has an answer
here." when none; each answer a row (`filter-<safe>-<n>`, min height 40): a 22 pt tick box (orange when
ticked), the label (16, bold when ticked, up to 2 lines), the count (15 bold muted), selected trait when ticked;
and, when anything is ticked, "Any — clear this one" (`filter-<safe>-clear`, 15 bold orange).

**Behaviour.**
- Faceted counts: a column's answers are counted among the base things that pass all the OTHER filters, so each
  count says what ticking it would leave. A ticked answer no longer given by any thing still shows, count 0,
  labelled with its STORED value — the normalised text (lower-cased), or "Blank" for "" (also for Owner, where
  the live answer says "Both have one").
- A stored filter whose column no longer exists (a deleted template's `list:<id>`, or his bag list's) is no
  longer applied, counted or offered (`Library.liveFilters`), and the table drops it from what is kept (0.62;
  it went on hiding every row with no pill to say why).
- The narrow field keeps answers whose normalised label contains the normalised text.
- Ticking toggles the value in that column's set; an empty set removes the column's filter. Stored as JSON
  (`TableKeys.store`: sorted arrays; "" when nothing is filtered) in `ams.table.filters`.
- `TableKeys.safe(key)`: `list:<id>` → `list-<index>` and `section:<id>` → `section-<index>` (the template's
  index in `Library.templates`), so a test never needs an id; other keys as they are.

**The model (`Library.filterValues`, `passes`, `filterAnswers`, `filterSummary`).** What one thing answers to
one column:

| Column | Value(s) | Answers offered, in order, with labels |
|---|---|---|
| storage, container, ownedBy, packer, condition, color, size, manufacturer, model, serial, note | `normName(trim(field))` | every non-empty value A–Z (plain string order of the normalised values), labelled as FIRST WRITTEN (trimmed); for condition the condition's label when the value is a known id or label; then the blank one last: "Both have one" for Owner, "Blank" otherwise |
| liquid, charging, restricted, consumable, perNight | "yes" / "no" | "Yes", "No" |
| weight | "" when ≤ 0 (or NaN); "w1" < 100 g; "w2" < 500; "w3" < 1000; "w4" otherwise | "Under 100 g", "100 – 500 g", "500 g – 1 kg", "Over 1 kg", then "No weight" |
| listQty | on no template → "none"; on several → "several"; else the membership's trimmed qty | the quantities sorted numerically (non-numbers after, by text), "Blank", "On several templates", "On no template" |
| listSection | "none" / "several" / the membership's section id ("" = none) | for each template, each section "`Section` (`Template`)", then "No section", "On several templates", "On no template" |
| `list:<id>` | not on it → "off"; on it → "on" plus "section:<section id>" for each membership there ("section:" = no section) | "On it", "Section: `X`" per section in the template's order, "On it, no section" (only when the template has sections), "Not on it" |

Only answers with a count > 0 are offered. `passes(thing, filters)`: every non-empty filter must share at least
one value with the thing's values. `filterSummary(column, kept)`: the labels of the kept answers (computed over
ALL things) joined ", " — "Kim, Robin" — or "`N` chosen" when none is found. Constants: `FILTER_ON` "on",
`FILTER_OFF` "off", `FILTER_SECTION` "section:", `FILTER_NO_TEMPLATE` "none", `FILTER_SEVERAL` "several",
`OWNER_BOTH` "Both have one", `FILTER_WEIGHTS` as in the table.

**Tests.** Model `ThingFiltersTests`: `testAWordsColumnOffersItsAnswersAToZWithBlankLastAndFilters` ("kim " and
"Kim" are one owner shown as first written; labels ["Kim", "Robin", "Both have one"], counts [2, 1, 2]; two
answers = either; Blank keeps the ownerless; nothing ticked filters nothing), `testTwoColumnsMustBothHold`,
`testWeightsAreGroupedLightToHeavy`, `testATemplateFiltersByBeingOnItAndByItsSections`,
`testThePerTemplateColumnsSayWhenAThingIsOnNoneOrSeveral`, `testAnswersCountOnlyTheThingsInView` (also the summary
"Kim, Robin"). UI `testTheTableFiltersByAnyColumn` (Owner Kim → "5 of 10"; Hiking's section Lights → "1 of 10";
Done → 1 row "Headlamp"; pill "Owner: Kim"; its ✕ removes only that filter; Clear → 10).

**Not covered by a test.** The narrow field; "Clear all filters"; "Any — clear this one"; a ticked answer with
count 0; the condition labels.

---

## Sorting the table (TableFilterSort.swift `SortSheet`; PackingLibrary/ThingSorting.swift)

**Purpose and origin.** His ask, 4 Oct 2026: "a nested sorting functionality … sorting on travel as a top sort
criterion and then sorting on section as an under criterion." Up to three levels (`SORT_LEVELS_MAX` = 3); each
level only decides between things the levels above call equal; the name settles the rest (0.58).

**How it is reached and left.** "Sort" (`table-sort`) → a sheet (container `sort-sheet`; Mac at least 480 × 560);
"Done" (`sort-done`; Escape too, 0.62); changes are stored at once.

**What is on screen.** "Sort" (22 heavy orange) and "Done". One row per level: "Sort by" (first) or "then by"
(15 heavy muted, 64 wide); a box with the level's title and ▾/▴ (`sort-level-<n>`, accessibility value = the
title; orange border while its list is open) — pressing it opens the list of keys under it; a ▲/▼ button
(`sort-dir-<n>`, 20 black orange, 44 × 44, accessibility value "up"/"down") turning that level round; for levels
after the first, ✕ (`sort-remove-<n>`, label "Remove this level"). The key list, in groups (13 heavy orange
capitals): "THE THING ITSELF" (Name + the 17 intrinsic columns), "ON THIS TEMPLATE" (How many, Section), "ON
THESE TEMPLATES" (one per template), and — only when some template has sections — "BY A TEMPLATE'S SECTIONS"
(one "`<Template>` · section" per such template); each a row (`sort-key-<safe key>`), the current one bold
orange. "+ Then by" (`sort-add`, 17 bold white on an orange capsule, min height 44) while there are fewer than
three levels. Footer: "Each level only orders the things the levels above it find equal. A blank always goes
last." (15 medium muted).

**Behaviour.** Picking a key sets that level and closes the list (two levels may name the same key here; a
heading press in the grid removes duplicates of its key). "+ Then by" appends a level "Name" and opens its list.
✕ removes that level. The first level is stored in `ams.table.sort` / `ams.table.down`, the rest (at most two)
as JSON in `ams.table.then`. `TableKeys.title`: "name" → "Name"; `section:<id>` → "`<shown name>` · section";
otherwise the column title (or the raw key when unknown).

**The model (`Library.sortValue`, `sortThings`).** One comparable string per thing and level; nil = blank, and a
blank goes LAST whichever way the level runs (the point of sorting by a column is usually to fill it in):
- `name` → `normName(name)`;
- the 11 text columns → `normName(field)`, nil when empty;
- the 5 flags → "0" when yes, "1" when no (ascending = yes first);
- `weight` → zero-padded "%012.2f" when > 0, else nil;
- `listQty` → only when on exactly one template and its qty is a number: zero-padded; else nil;
- `listSection` → only when on exactly one template and the section exists: the section's normalised name;
- `list:<id>` → "0" on it, "1" not (never blank);
- `section:<id>` → nil when not on that template; else "%04d" of the template's own section order (the lowest
  index among its memberships there), with "on it, no section" = the number of sections (after its sections).
Comparison: level by level with `jsLocaleCompare(…, sensitivity: .base)` — the order Your things and the
templates use, so å, ä, ö and é sit where they do there (0.62; it was plain code-point order) — at most the first
3 levels; then the normalised name the same way, and code-point order only between names that compare equal.
No levels = by name. A level whose key the table no longer knows (a deleted template) is dropped before sorting.

**Tests.** Model `ThingSortingTests`: `testTravelThenItsSectionsListsTheTravelThingsSectionBySection` (template
order of sections, not A–Z; "no section" after; the rest by name),
`testALowerLevelOnlyDecidesBetweenThingsTheLevelAboveCallsEqual`, `testABlankGoesLastWhicheverWayTheLevelRuns`,
`testOnlyThreeLevelsCountAndNoLevelMeansByName`; `ThingsAndCareFixesTests.testTheTableSortsAccentedNamesAsYourThingsDoes`.
UI `testTheTableSortsByLevels` (Hiking, then Hiking · section
▼ → Hiking boots, Map, Rain jacket, Headlamp, Goggles; "then Hiking · section ▼" said in words; removing the
second level → Headlamp, Hiking boots first; the words go).

**Not covered by a test.** Sorting by a choice column; duplicate levels; "+ Then by" at three levels hiding.

---

## Change all and Undo (App/Sources/Screens/BulkChange.swift)

**Purpose and origin.** His ask: "check a number of items and then, with only an easy change of condition, have
all of them get changed at once" (0.12, 24 Sep 2026). One field at a time on purpose — "the whole point is that
this takes two taps"; the grid keeps the old values so one press puts them back.

**How it is reached and left.** The ticked bar's "Change all" → a sheet (container `bulk-detail`; Mac at least
460 × 560). "Cancel" (`bulk-cancel`, outlined muted; Escape too, 0.62 — nothing changes) or choosing a value (which
applies and closes).

**What is on screen.** "Change `N` thing(s)" (`bulk-count`, 20 heavy orange) and under it the first three names
"A, B, C" or "A, B, C and `K` more" (13 medium muted, up to 2 lines). "WHAT TO CHANGE" (12 heavy muted). One row
per intrinsic column (`bulk-field-<id>`, min height 42; the chosen one heavy orange with ▾ and the selected
trait); under the chosen one its values, each a row "→ `<value>`" (15 semibold, min height 40):
- choice columns: each answer of `Answers2` by its label (`bulk-value-<n>`; a condition stores its id) then
  "Leave blank" (`bulk-value-blank`);
- ticks: "Yes" (`bulk-value-yes`), "No" (`bulk-value-no`);
- words: a text box (`bulk-text`) and "Leave blank" (when the trimmed text is empty — spaces alone too, 0.62) or
  "Set to “`x`”" (`bulk-apply`);
- number (weight): a text box and "Leave blank" or "Set to `x` g" (`bulk-apply`; `x` = `amountText` of what was
  read, or the typed text when it is no number); under it, after a refused press, "Type a weight in grams, like
  250 or 12,5." (`bulk-needs`, 15 bold red; gone as he types or picks another field).
Per-template columns are never offered (they do not belong to the thing).

**Behaviour.** Choosing a value hands back the change (and a sentence such as "Condition → New", "Liquid: yes",
"Colour cleared", "Weight → 250 g") and closes; the table then applies it to every ticked thing, says the
sentence, and offers Undo (see the table). Number: `readAmount` — empty → 0 ("Weight cleared"); a negative
number or text that is not a number → REFUSED: the sheet stays and says so under the button (0.62; a typo was
written as 0 to every ticked thing, and a negative did nothing without a word).

**Tests.** UI `testManyThingsAreChangedAtOnceAndCanBePutBack` (no bar before ticking; "2 ticked"; the sheet says
"Change 2 things"; Condition → the first answer changes rows 0 and 1, not row 2; Undo puts both back).

UI (0.62) `testChangeAllRefusesANonNumberAndCountsTicksOutOfSight` (spaces in Colour offer "Leave blank"; "abc"
in Weight → `bulk-needs`, the sheet stays; Cancel; the Map's weight still 60);
`testTheTableOffersHisOwnBagsAndOwnersAndAConditionReachesToBuy` (the said line).

**Not covered by a test.** Ticks (Yes/No); a weight actually set for many.

---

## The Mac window (App/Sources/AMSPackingApp.swift)

His ask, 4 Oct 2026: "I would like it wider in order to see more columns" (0.58). On the Mac only, the app
declares a second scene: `Window("All your things", id: "things-table")` (`ThingsTable.windowId`) holding
`ThingsTable(inWindow: true)` with the same `LibraryModel`, so both windows show the same library.
- Default size 1180 × 780 (under UI tests — any launch argument starting `-uiTesting` — 760 × 620);
  `.windowResizability(.contentMinSize)` (the table's own minimum is 760 × 560); it can be dragged as wide as he
  likes or made full screen.
- `.restorationBehavior(.disabled)` and `.defaultLaunchBehavior(.suppressed)`: it opens ONLY from Care, never by
  itself. 🪤 Left open when the app quit, the Mac brought it back at the next start, in front of the app — every
  UI test after the first one that opened it failed on GitHub (0.58, 4 Oct 2026).
- Care's door calls `openWindow(id:)` (a window already open comes to the front); "Done" calls
  `dismissWindow(id:)`; its sheets (thing page, Filter, Sort, Columns, Change all) attach to this window.
- The main window: `WindowGroup` with `RootView`, at least 480 × 600, ideal and default 760 × 900; under the UI
  tests every visible titled window is SET to 760 × 674 (GitHub's runner size), keeping its top edge.
Tests: no test opens the window on purpose; the Mac UI tests that tap `care-table` go through it.

---

## The To do tab: To do (App/Sources/Screens/ActionsScreen.swift; PackingCore/Actions.swift)

**Purpose and origin.** The central to-do list: open before done, high before normal, sooner before later; a
tick is permanent (it does not reset per trip). The tab has two sides on one screen: things to DO and things to
BUY (0.3, 23 Sep 2026). "Actions" became "To do" by his choice (test G.4, 30 Sep 2026, 0.43); the identifiers
stay `actions`.

**How it is reached and left.** The tab bar (`tab-actions`, label "To do"); the Trips screen's chip "`N` to do"
(`events-todos`, label "`N` to do, open the To do tab") when there are open to-dos. Choosing a to-do in the
global search does NOT bring him here: it only closes the search (no caller passes `SearchScreen.go`; see Open
questions). Left by another tab. The side shown ("To do" or "To buy")
is `@State`: every time the tab is built again it starts on "To do".

**What is on screen.**
1. Top row (16 pt sides, 12 top): two equal-width side buttons "To do" (`actions-tab-todo`) and "To buy"
   (`actions-tab-buy`) — 17 bold, min height 44, radius 10; the side showing is filled red with white words and
   carries the selected trait, the other is ink on the card with a 1 pt line — and the magnifier (`search-open`).
2. On the To do side, a scrolling list (`LazyVStack`, 4 pt spacing):
   - The count (`actions-count`, 16 bold muted, monospaced): "Nothing to do." (no to-dos), "All done." (all
     ticked), else "`N` to do".
   - One row per to-do in `sortedActions(kind: "todo")` order: the row button (`action-N`, selected trait when
     done) — a 26 pt circle with a red 2 pt ring; when done, a filled red circle with a white drawn tick; the
     text (17, medium; regular, muted and struck through when done); and, when the to-do has a thing, high
     priority or a "When" step, a second line (13 semibold) joining with " · " "High", the thing's name and the
     step's label (`phaseLabel`: a step this device does not know is shown by its raw id) — red while a high
     one is open, muted otherwise. At the right a ✕ (`action-N-remove`, label
     "Remove", 24 pt mark in a 40 × 40 area). A 1 pt line under each row.
3. After a ✕ (0.62): above the add row, "Removed “`<text>`”" (`action-undo-says`, 15 semibold muted, 1 line)
   and "Undo" (`action-undo`, 15 bold red, red outlined capsule, min height 36) — until it is used, another
   to-do is removed, or the screen is rebuilt.
4. The add row at the BOTTOM: "Add a to-do" (`action-add-text`, 17 medium, min height 44), "!" (`action-add-high`,
   18 heavy, 44 × 44 — red on the card when off, white on red when on; label "High priority", selected trait),
   "Add" (`action-add`, red `FieldButtonLabel`); needs line `action-add-needs`.

**Behaviour.**
- Tapping a row flips it: `setActionDone(!done, id:)` sets `done`, `doneAt` = now (ISO) or "", `updatedAt` = now.
- ✕ removes the to-do at once (`removeLine(id:)`) and offers Undo, which puts the very same line back under
  its own id (`putBackLine`). His rule is that things, bags, templates and trips ask before they go; a line of
  a quick list goes at once but can be brought back (decided in the 0.62 spec pass — asking each time would
  make the list slow).
- Add / Return: blank or all-space → "Type a to-do first."; else `addAction(text:priority:)` with priority "high"
  when "!" is on, "normal" otherwise; then the field is emptied and "!" turned off.
- Each side has its own add text (0.62; one shared `text` showed a half-typed to-do on To buy too). Both live
  in `ActionsScreen`, so a half-typed line survives a look at the other side.
- There is no way here to edit a to-do's text, priority, thing, step or date after it is made.

**The model.** `ActionItem` (named so because `Action` is taken):

| Field | Default | Coerced (`coerceAction`) |
|---|---|---|
| `id` | `makeId()` | — (number read as its text) |
| `text` | "" | non-string → "" |
| `kind` | "todo" | anything but "shopping" → "todo" ("todo" = To do, "shopping" = To buy) |
| `itemId` | "" (loose) | — |
| `itemName` | "" (a cached name, kept when the thing is deleted) | — |
| `priority` | "normal" | not "high"/"normal" → "normal" (`ACTION_PRIORITIES`: High, Normal) |
| `whenPhase` | "" | trimmed, cut to 40 units; an unknown step is KEPT |
| `whenDate` | "" | not YYYY-MM-DD → "" |
| `done` | false | truthy |
| `doneAt`, `createdAt`, `updatedAt` | "", now, now | a missing `createdAt` → now; a missing `updatedAt` → `createdAt` |
| `phase` | nil | 🪤 a JS quirk kept for parity (`referencedListValues` reads `a.phase`, a key no real action has); written only when set |
| `extra` | [:] | unknown keys kept (natively: `reminderId` on a sent buy line) |

`Library.addAction(text:kind:itemId:itemName:priority:whenPhase:)` trims and refuses blank (nil).
`compareActions`: open before done; high before normal; then the "when" rank — a date first ("0-YYYY-MM-DD",
soonest first), then a step in timeline order ("1-NN"; an unknown step ranks after the known ones), then
untimed ("9"); then the newest `createdAt` first. `sortedActions(kind:)` filters by kind and sorts stably.
`openToDoCount()` = open to-dos (kind "todo") — the Trips chip. `actionPriorityLabel` ("Normal" for anything
unknown).

**Data.** `actions` records, key = the action's id. To-dos and buy lines share the table, told apart by `kind`,
exactly as the web app keeps them, so both come through a backup either way.

**iPhone vs Mac.** Same.

**Tests.** Model `ActionsTests`: `testActionKindDefaultsToTodoKeepsAValidShoppingKind`,
`testCompareActionsOpenFirstHighFirstSoonerFirstNewestFirst`, `testCoerceActionRules`; `CreateTripTests`
`testToDosAreAddedTickedAndOrderedTheWebAppsWay` (trimmed; high before normal; open before done; `doneAt` set;
blank refused; one record per to-do). UI `testAToDoIsAddedAndTicked` (Add is enabled when empty and says what is
missing; the line goes on typing; "1 …" counted; ticking → "All done…"; the tick survives leaving the tab);
`testEveryTabOpensItsScreen` (the tab says "To do"); `testEachTripSaysWhereItHasGotTo` (a to-do makes the Trips
chip appear and it opens this tab); `testTheBuyListOffersWhatIsWornOutAndKeepsTheToDosSeparate` (buy lines never
appear here: "Nothing to do.").

UI (0.62) `testToDoAndToBuyKeepTheirOwnTextAndUndoARemoval` (a half-typed to-do is not on To buy and is still
there on return; ✕ then Undo on each side). Model `ThingsAndCareFixesTests.testALineRemovedComesBackWithUndoAndItsReminderIsNamed`.

**Not covered by a test.** "!" (high priority) and the second line; the sort beyond what the model test pins.

---

## The To do tab: To buy (App/Sources/Screens/BuyList.swift; PackingLibrary/ShoppingList.swift; PackingCore/Shopping.swift)

**Purpose and origin.** What he has put down to buy, and what the library itself thinks is worth buying — a
consumable, something marked "needs replacing", something past or near its replace-by date. An offer says WHY,
and taking it up stops it being offered (0.3, 23 Sep 2026; the web app's pre-trip restock & replace list).

**How it is reached and left.** The To do tab → "To buy" (`actions-tab-buy`). Back with "To do".

**What is on screen** (a scrolling list, then the add row):
1. The count (`buy-count`, 16 bold muted): "Nothing to buy." (no lines), "All bought." (all ticked), else "`N` to
   buy".
2. When there is at least one line: the Reminders block (`RemindersSend`, below).
3. One row per line in `buyList()` order (= `sortedActions(kind: "shopping")`): the row button (`buy-N`, selected
   trait when bought) with the same red circle tick as a to-do and the text (`buy-N-name`, 17; struck through
   and muted when bought) — no second line; ✕ (`buy-N-remove`, label "Remove `<text>`") deletes at once.
4. When there are offers: "Worth buying" (`buy-offers`, 15 heavy muted, 18 pt above), then each offer as a button
   (`buy-offer-N`): a red "+" (22 heavy), the thing's name (`buy-offer-N-name`, 17 medium) over the reason
   (`buy-offer-N-why`, 14 semibold; red for "Needs replacing" and "Expired", muted otherwise).
5. After a ✕ (0.62): "Removed “`<text>`”" (`buy-undo-says`) and "Undo" (`buy-undo`), as on To do.
6. The add row at the BOTTOM: "Add something to buy" (`buy-add-text`), "Add" (`buy-add`, red); needs line
   `buy-add-needs` "Type what to buy first."

**Behaviour.**
- Tapping a line flips bought / not bought (`setActionDone`); a line sent to Reminders ticks or unticks its
  reminder too (0.62, below). ✕ removes the line (`removeLine`) and takes its reminder out of Reminders;
  Undo brings the line back, not sent (its reminder is gone), so Send offers it again.
- Tapping an offer → `addToBuyList(suggestion)` = `addAction(text: thing's name, kind: "shopping", itemId:,
  itemName:)`; the offer disappears because the thing is now on the OPEN list.
- Add → `addToBuyList(text:)` (a line with no thing behind it); blank refused with the needs line.
- **Offers** (`buySuggestions(today: Today.local)` = `shoppingSuggestions(items, actions, today)`): every
  thing that is not retired ("not in use") and is not already on the OPEN buy list (matched by thing id), with a
  reason from `shoppingReason` — the most urgent wins: "Needs replacing" (its condition has the `replace` flag —
  any condition, not just the built-in one; the reason text is fixed whatever the condition is called) >
  "Expired" (its Valid until is before today) > "Replace soon" (within `EXPIRY_SOON_DAYS` = 30 days) > "Restock"
  (a consumable). A date that cannot be read raises nothing. Sorted by reason (that order) then name
  (`jsLocaleCompare`). A bought (ticked) line no longer blocks its offer, so a consumable is offered again once
  bought — as in the web app.
- `openShoppingCount` (open buy lines) and `expiringOnTrip` (a trip's own "runs out before home", used by the
  trip checks) live in Shopping.swift; `openShoppingCount` is used by no native screen.

**Data.** `actions` records with `kind` "shopping"; a line taken from an offer keeps `itemId` and `itemName`.

**Tests.** Model `ShoppingListTests`: `testTheReasonsAreWhatTheThingItselfSays`, `testTheWorstReasonComesFirst`,
`testTakingUpAnOfferPutsItOnTheListAndStopsTheOffer`, `testABoughtLineStopsBeingOpenButTheOfferStaysAway`,
`testABuyLineSurvivesABackupAsABuyLine`, `testALineHeTypesHimselfNeedsNoThing`; `ShoppingTests`:
`testShoppingReasonMostUrgentReasonWins`, `testShoppingSuggestionsSkipsRetiredAndAlreadyListedSortsByUrgency`,
`testOpenShoppingCountCountsOnlyOpenShoppingKindActions`, `testShoppingReasonAnyNeedsReplacingConditionFeedsTheBuyList`,
`testShoppingReasonAnUnreadableDateRaisesNothingButStillRestocks`, and the four `expiringOnTrip` tests. UI
`testTheBuyListOffersWhatIsWornOutAndKeepsTheToDosSeparate` (starts "Nothing to buy."; the first offer is the
sample's Map, "Needs replacing"; taking it makes `buy-0` "Map", "1 to buy", and it is no longer offered; "Gas
canister" typed → "2 to buy"; ticking one → "1 to buy"; the To do side still "Nothing to do.");
`testEveryAddButtonIsReadyAndSaysWhatIsMissing`.

UI (0.62) `testToDoAndToBuyKeepTheirOwnTextAndUndoARemoval` (✕ on a buy line and Undo).

**Not covered by a test.** "Expired" and "Replace soon" offers in the UI; "All bought." (only via the Reminders
test on the iPhone).

---

## To buy → Apple Reminders (RemindersSend.swift, Store/ShopReminders.swift, PackingLibrary/BuyReminders.swift)

**Purpose and origin.** His pre-trip idea 9 (2 Oct 2026, 0.50): the buy list goes with him to the shop in the app
he already shops with. A line sent once is not sent again; a reminder ticked in the shop ticks its line here
(never the other way round). Read back whenever the app comes to the front (field test 8.4, 3 Oct 2026: "we had
to change tabs between To Buy and To Do for it to update", 0.55). Dated the day it is sent (field test 8.3, 3 Oct
2026: "there is no date, so it's very anonymous"; he chose the day he sends it, 0.57).

**What is on screen** (at the top of To buy, only when the buy list has at least one line):
- "Send 1 to Reminders" / "Send `N` to Reminders" (`buy-send`; 16 bold white on a red capsule, min height 44),
  only while some open lines have not been sent (`buyLinesToSend()`).
- After a press, a line (`buy-send-says`, 15 semibold; red on trouble, muted otherwise):
  - success: "`N` in Reminders, in the list “To buy · Packing”. Tick them there in the shop — they tick here too."
  - no access: "This device does not let the app into Reminders. Allow it in the device's Settings, under
    Reminders."
  - failure: "Reminders did not take them. Try again in a moment."
  The line is `@State`: it is gone when the screen is left.

**Behaviour.**
- Send: `ShopReminders.askAccess()` — true at once with full access; otherwise asks for FULL access to Reminders
  (the system question; the purpose string, iOS and Mac alike: "Your To buy list goes into Reminders, to take to
  the shop; what you tick there is ticked here."). Then `send(lines)`: finds the Reminders list titled exactly
  "To buy · Packing" (`ShopReminders.listName`) or makes it (in the source of the default reminders list, else a
  local source; neither → an error); for each line a reminder whose title is the line's text, in that list, with
  a due date of TODAY as year/month/day only (Gregorian, the device's time zone) — an all-day reminder, never an
  alarm; all saved, then committed once. Each line then gets `markSent(actionId:reminderId:)`, which stores the
  reminder's EXTERNAL identifier (the same on his iPhone and his Mac; the local identifier when there is none)
  in the line's `extra["reminderId"]` (`REMINDER_ID_KEY`) and bumps `updatedAt`. `markSent` refuses a to-do
  (kind must be "shopping") and an empty id.
- Read back (`ShopReminders.readBack(into:)`): when the To buy list's Reminders block appears (`.task`) and
  whenever the app becomes active (`RootView`, `scenePhase == .active`). It never asks for access: only with full
  access already granted. It takes the sent lines that are still open, asks Reminders which of those reminders
  are completed (`calendarItems(withExternalIdentifier:)`), and ticks those lines (`takeBought(reminderIds:)` →
  `setActionDone(true)`); it returns how many. A line is never un-ticked by a reminder.
- **Kept in step (0.62).** A sent line ticked or unticked HERE ticks or unticks its reminder
  (`ShopReminders.setDone`; `Library.reminderOf(actionId:)`), so a line unticked here after the shop ticked it
  is not ticked again at the next read back. A sent line removed here takes its reminder out of Reminders
  (`ShopReminders.remove`, the id from `removeLine`). Each time the Reminders block appears it also asks which
  sent, open lines' reminders are GONE from Reminders (`ShopReminders.gone` — deleted there); those count among
  "Send `N` to Reminders" again (`buyLinesToSend(gone:)`) — sent only when he presses Send, never by
  themselves, so a reminder that has merely not reached this device yet is never doubled behind his back. A
  new send gives the line its new reminder id. All three need full access already; without it nothing happens.
- `buyLinesToSend(gone:)` = open buy lines without a `reminderId`, or whose reminder id is in `gone`;
  `sentBuyLines()` = buy lines with one.
- Under the UI tests (`-uiTesting…`) nothing is asked of the system: a pretend Reminders in memory gives ids
  "pretend-`<line id>`-`<n>`"; `-pretendShopTicks` plays a shop where everything sent gets ticked (an untick
  here unticks it there); `-pretendShopDeleted` plays a Reminders list he has emptied (every sent reminder is
  gone). The pretend store keeps no dates, so the due date is seen only in Reminders itself.

**Data.** `extra["reminderId"]` on the buy line's `actions` record (the web app's model is untouched). The
Reminders list and reminders live in Apple Reminders (EventKit), outside the library. The Mac needs the
`com.apple.security.personal-information.calendars` entitlement (both entitlement files).

**iPhone vs Mac.** The same code (EventKit on both). "Comes to the front" = the scene becoming active.

**Tests.** Model `BuyRemindersTests.testALineIsSentOnceAndTickedFromTheShop` (only open buy lines go; a sent line
is not offered again; the reminder ids survive the records; an unknown reminder id ticks nothing; ticked twice =
0; a to-do cannot be marked sent); `ThingsAndCareFixesTests.testALineWhoseReminderWasDeletedThereCanBeSentAgain`.
UI `testTheBuyListGoesToReminders` (no Send with nothing to buy; "Send 2"; "2 in Reminders"; Send gone; a new line
→ "Send 1"); `testWhatWasTickedInTheShopIsTickedOnReturn` (iPhone only: sent, "2 to buy"; home and back → "All
bought."; one unticked here → "1 to buy", and still after home and back); `testALineWhoseReminderWasDeletedCanBeSentAgain`
(`-pretendShopDeleted`: sent, then "Send 2" again once the list is shown again).

**Not covered by a test.** The real EventKit path (list creation, the date, all-day, the external identifier,
removing, ticking, finding a reminder gone); the no-access and failure messages; read back on the Mac.

---

## What is kept per device (AppStorage) in this area

| Key | Type, default | Meaning |
|---|---|---|
| `ams.care.view` | String "list" | Care shows List or Calendar ("calendar"). |
| `ams.table.columns` | String "" | The table's columns, comma-separated ids; "" = the starting seven. |
| `ams.table.sort` | String "name" | The first sort level's key. |
| `ams.table.down` | Bool false | The first level runs ▼. |
| `ams.table.then` | String "" | JSON `[SortLevel]` — the "then by" levels (at most two). |
| `ams.table.filters` | String "" | JSON `{column id: [kept values]}`. |

They live in this device's UserDefaults: they do not sync, are not in a backup, and a fresh device starts with
the defaults. Everything else in this area is library data (records → SwiftData → iCloud, docs/store.md).

---

## Open questions / discrepancies

Tags: [bug] the code does something wrong · [rule-break] against one of his standing rules · [doc] a
comment, doc or guide text disagrees with the code, or code that is dead · [untested] behaviour no test
pins · [idea] a gap worth deciding on.

1. [bug] Resolved in 0.62: the table and Change all offer `Library.bagNames()` — his own bags after the built-in
   names, the same answer as the thing's page (`testTheBagNamesOfferedIncludeHisOwnBags`, UI
   `testTheTableOffersHisOwnBagsAndOwnersAndAConditionReachesToBuy`).
2. [bug] Resolved in 0.62: the table and Change all store the condition's ID and show its label; things stored with
   a label are repaired on every read of the store (`repairConditionLabels`, run by `LibraryModel.reload`); the
   thing's page lights a stored label too; the comment's example says "Needs replacing"
   (`testAConditionStoredAsItsLabelIsRepairedToItsId`, UI `testAConditionStoredTheOldWayIsRepairedOnLoad`).
3. [bug] Resolved in 0.62: the table and Change all offer `ownerChoices()` (every owner his things name); with
   nobody named anywhere the thing's page keeps "Whose it is" and says the names come from Settings → Your choices
   (UI `testTheTableOffersHisOwnBags…`, `testWhoseItIsSaysWhereNamesComeFromWhenNobodyIsNamed`).
4. [bug] Resolved in 0.62: his bag list is no table column, filter or sort key (`templatesForThings()`); a bag is
   made and deleted on Your bags only (`testHisBagListIsNotATemplateAThingIsTickedOnto`, UI
   `testTheBagListIsNoColumnOfTheTable`).
5. [rule-break] Resolved in 0.62: the dashboard's template weights and a care row name his bag list "Bags"
   (`shownName`) (`testCareAndTheDashboardSayBagsNeverContainers`).
6. [bug] Resolved in 0.62: the weight field keeps what he types and is read on Save by `readAmount` (a comma or a
   point, decimals); shown with `amountText` (88.7 stays 88.7); an unreadable weight saves nothing and says so
   under the field; the table's weight cell shows decimals too and writes only a real change
   (`testAnAmountTakesACommaOrAPointAndRefusesWhatIsNotANumber`, UI
   `testAThingsPageTakesDecimalsAPlaceNoBagAndCare`).
7. [rule-break] Resolved in 0.62: New on a name he has says "You already have a thing called that." and keeps the
   typed name (UI `testANewThingWithANameHeHasSaysSo`).
8. [bug] Resolved in 0.62: the bar says "`N` changed: `<sentence>`" on a line of its own, 15 pt (UI
   `testTheTableOffersHisOwnBags…`).
9. [bug] Resolved in 0.62: a weight that is not a number, or a negative one, is refused with "Type a weight in
   grams, like 250 or 12,5." under the button; spaces alone read "Leave blank" (UI
   `testChangeAllRefusesANonNumberAndCountsTicksOutOfSight`).
10. [bug] Resolved in 0.62: Undo puts back only the fields Change all altered, and only where they still hold what
    it wrote (`Library.undoChange`, `testUndoPutsBackOnlyWhatChangeAllChanged`).
11. [idea] Resolved in 0.62 (the gentlest version): ticks still survive the search and filters — on purpose,
    "narrow with a chip, then take the lot" — and the bar now says how many ticked things are not shown ("2 ticked
    · 1 not shown") (UI `testChangeAllRefusesANonNumberAndCountsTicksOutOfSight`).
12. [bug] Resolved in 0.62: filters and sort levels for a template that is gone are neither applied nor counted
    (`liveFilters`, `tableKnows`) and are dropped from what the table keeps
    (`testAFilterForADeletedTemplateIsForgotten`, UI `testATemplateDeletedTakesItsFilterAndColumnAlong`).
13. [bug] Resolved in 0.62: `TableColumns.ids` drops gone ids before anything counts them and falls back to the
    starting columns when none is left; the picker writes live ids only (UI
    `testATemplateDeletedTakesItsFilterAndColumnAlong`).
14. [bug] Resolved in 0.62: `careRows` also lists things on no template and leaves out "not in use" ones, so the
    list, the calendar, the summary and the dashboard agree
    (`testCareListsAThingOnNoTemplateAndLeavesOutOneNotInUse`).
15. [bug] Resolved in 0.62: the year-ahead bars count calendar months, this month first; a service in the
    thirteenth month is on no bar (`testTheYearAheadCountsCalendarMonths`).
16. [doc] Resolved in 0.62 (decided, no change in the app): each number counts what its own screen shows — the
    "Your things" door everything Your things lists, the Care line and the kit only things in use ("not in use"
    comes only from the web app). Said under The Care tab.
17. [idea] Resolved in 0.62 (in part): the thing's page edits a care schedule and care notes ("Care"), so Care is
    no longer only the web app's records (UI `testAThingsPageTakesDecimalsAPlaceNoBagAndCare`). Left on purpose:
    photos of a thing, price, currency, dates bought/warranty, quantity owned, charge type, "not in use" and the
    care link — nothing he has asked for, and the web app still edits them; size, model, serial, packer, runs out,
    per night and charges stay in the table, where they are edited already.
18. [bug] Resolved in 0.62: the thing page lists, under its own Notes, every note its templates keep for it
    on their rows ("On the <template> template: <note>", `thing-row-note-N`; `Library.rowNotes`) — a row's note
    still wins on its template, and the thing's own note stays the thing's (model `RowNotesTests`, UI
    `testAThingsPageShowsTheNotesItsTemplatesKeep`).
19. [idea] Resolved in 0.62: "Usually packed in" ends with "No bag" (value ""), and a bag name not among the
    offered ones is shown as a pill of its own, lit (UI `testAThingsPageTakesDecimalsAPlaceNoBagAndCare`).
20. [idea] Resolved in 0.62 (the gentlest version): Kept at home stays a text field, with his places as pills under
    it — a tap spells a known place the way the table does (UI `testAThingsPageTakesDecimalsAPlaceNoBagAndCare`).
21. [bug] Resolved in 0.62: each side has its own add text (UI `testToDoAndToBuyKeepTheirOwnTextAndUndoARemoval`).
22. [rule-break] Resolved in 0.62 (decided: Undo rather than a question — a quick list that asked each time would
    be slow): ✕ removes at once and "Removed “…” · Undo" brings the line back
    (`testALineRemovedComesBackWithUndoAndItsReminderIsNamed`, UI
    `testToDoAndToBuyKeepTheirOwnTextAndUndoARemoval`).
23. [bug] Resolved in 0.62: a line removed here takes its reminder out; ticking or unticking here ticks or unticks
    its reminder; a line whose reminder was deleted in Reminders is offered by Send again (only on his press)
    (`testALineWhoseReminderWasDeletedThereCanBeSentAgain`, UI `testWhatWasTickedInTheShopIsTickedOnReturn`,
    `testALineWhoseReminderWasDeletedCanBeSentAgain`).
24. [bug] Resolved in 0.62: confirmed (the row kept the old number), and each row now follows its bag's numbers
    unless the field already says them (UI `testYourBagsShowsANumberChangedOnTheBagsPage`).
25. [bug] **`followThing` used the UTC date.** Resolved in 0.62 (the trips area, F036): it goes by
    `Library.localToday()`, the device's own date.
26. [bug] Resolved in 0.62: the table sorts with `jsLocaleCompare` (base), as Your things and the templates do
    (`testTheTableSortsAccentedNamesAsYourThingsDoes`).
27. [doc] Resolved in 0.62: `KitDashboard`'s comments say it is the foot of the tab and that template bars are not
    buttons; `headHeight` is gone; `CareScreen` says "a sheet"; `deleteBag`'s doc comment is back above `deleteBag`
    (the `@discardableResult` was already on it).
28. [doc] Resolved in 0.62 (decided: kept): these ports stay — the parity tool (`Core/Sources/parity`) checks them
    against the web app, which is still in use during the change-over, and a rewrite should start from them;
    `Library.setStorage` stays as the plain setter its model test pins. Nothing on screen depends on them.
29. [rule-break] Resolved in 0.62: the bag delete's main button is full red ("Delete"); pressed before a bag is
    chosen it says "Choose where its things go first — another bag, or No bag." under it (UI
    `testABagIsRenamedAndDeletedFromItsPage`).
30. **Resolved in 0.62** — ~~[untested] Escape on the Mac: no screen in this area declares a keyboard shortcut.~~
    Escape (⌘. on an iPhone keyboard) presses Cancel on a thing's page and on Change, and Done on Your things,
    Your bags, a bag's page, the table (as a sheet — not the Mac's own window), Filter, Sort and Columns; never a
    Save (spec 06 §20). Pinned by `testEscapeCancelsAThingAndClosesCaresWindows` (a renamed thing cancelled, Your
    things behind it still open; Your bags; the table's Filter alone, then the table — on the Mac the window stays
    and Done closes it); a bag's page, Sort, Columns and Change by the code only (the same one line). With
    Escape planted on Save the test goes red on the iPhone ("Escape saved the thing").
31. **Resolved in 0.62** — ~~A to-do found by the search goes nowhere.~~ `SearchScreen.chose` closes the
    search and sets `model.tabToOpen = .actions`; the frame opens the To do tab. Pinned by
    `testASearchedToDoOpensTheToDoTab` (Home spec).
32. Withdrawn (his word, 5 Oct 2026): there is no 15-pt floor in this app — it uses Apple's standard text styles (spec 06, "Type"). Was: [rule-break] **Small type**: "Delete thing" / "Delete bag" 13 (`SmallDeleteButton`'s
    default; only the grab list's delete passes 15), the bag glance line 12, Your bags' column names 10, the
    bag page's number titles 11, the table's cells 13–14, headings 12 and bands 11, the kit figures' words 12
    and the year-ahead months 10, the calendar's weekday row 11 and counts 10, the Care doors' second lines 13.
