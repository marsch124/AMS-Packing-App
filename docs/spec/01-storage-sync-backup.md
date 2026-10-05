# Storage, sync and backup

> Verified against the code on 5 Oct 2026 (app 0.61).

This part is the foundation: how the whole library (his things, his templates, his trips and their lines, his to-dos, kits, "When" steps, his own Settings choices, photos and the library's own notes) is held in memory, cut into small records, stored with SwiftData, carried between his iPhone and his Mac by iCloud (CloudKit, private database), saved to a backup file, read back from one, checked for damage, exported to Excel and shared as links/codes.

In the owner's terms: "the same library on iPhone and Mac, kept in step through iCloud" (0.2, 22 Sep 2026); "a backup with a real Save window" (0.2); "Restore from a backup file; a copy of what was here is kept first, and you can go back to it" (0.3); "Worth a look" (0.5); "Share" (0.38); "iCloud sync, made visible" (0.54, his field test 3 Oct 2026: "we need to get the sync going because I need to work from the Mac").

How one reaches the visible parts:

| Part | Where |
|---|---|
| iCloud sync card, Open a shared link, Worth a look, Backup (Save / Restore / Kept before a restore), This device holds | **Settings** tab (`tab-settings`, label "Settings", colour slate `#64748b`) |
| First-run screen (two doors, one-time import) | **Home** tab, only while the device holds nothing (`LibraryModel.State.empty`) |
| Save as Excel, Share (trip) | foot of a trip's screen (Trips tab → a trip) |
| Share (template) | template detail header (Templates tab → a template) |
| Share (grab list) | grab list header (Home → a grab button), only when not editing |
| A broken library | every tab shows one red sentence (`library-problem`) |

Nothing here is reachable from a Shortcut, a menu command or a deep link (the app registers no URL scheme and has no `onOpenURL`; a shared link is opened only by pasting it).

Files (all read for this spec):
- Model: `Core/Sources/PackingLibrary/Library.swift`, `Records.swift`, `LibraryRecords.swift`, `LibraryStore.swift`, `StoreSession.swift` (0.62), `SyncCheckIn.swift`, `SyncCheck.swift` (moved from the app in 0.62), `RescueNames.swift` (0.62), `Backup.swift`, `BackupWords.swift` (0.62), `Importer.swift`, `SharingReplace.swift` (0.62), `Workbook.swift`, `Health.swift`, `Sharing.swift`, `TripEdits.swift` (photo tidy), `OnTheTrip.swift` (photo bookkeeping), `SettingsLists.swift`; `Core/Sources/PackingCore/JSONValue.swift`, `Items.swift`, `Memberships.swift`, `Resolve.swift`, `Lists.swift`, `Events.swift`, `Actions.swift`, `Kits.swift`, `Phases.swift`, `SharedRows.swift`, `Backup.swift`, `BackupState.swift`, `DeviceAudit.swift`, `ShareEncoding.swift`, `TripSharing.swift`, `ListSharing.swift`, `GrabSharing.swift`, `PackingEnv.swift`, `JSSemantics.swift`, `Catalogue.swift` (the save helpers); tool `Core/Sources/import-check/main.swift`.
- App: `App/Sources/Store/CloudStore.swift`, `LibraryModel.swift`, `RescueCopies.swift`, `SampleLibrary.swift`, `Today.swift`; `App/Sources/Screens/SyncCard.swift`, `RestoreSheet.swift`, `SettingsScreen.swift`, `FirstRunView.swift`, `Share.swift`, `Laundry.swift` (the Excel button); `App/Sources/RootView.swift`, `AMSPackingApp.swift`; `project.yml`, `App/Config/*.entitlements`, `.github/workflows/testflight.yml`.
- Existing doc, reused not repeated: `docs/store.md` (the ten rules, the layers, the 22 Sep proof run, the 3 Oct photo-field lesson).

---

## 1. The data model — `Library` and its collections

**Purpose and origin.** A port of the web app's relational model (web app v175–v188): ONE catalogue item per physical thing, MANY memberships (one per place it sits on a template), templates that hold no items of their own, and trips whose lines are self-contained copies. All model types live in PackingCore (a line-by-line port of the web app's `js/model.js`, parity-checked against it); `Library` (PackingLibrary) is the in-memory library plus the operations the screens need.

### 1.1 `Library` (Library.swift)

`public struct Library: Equatable, Sendable` with exactly these stored properties, each one a "table" of records (§3):

| Property | Type | Holds | Empty means |
|---|---|---|---|
| `items` | `[Item]` | the catalogue: one per physical thing (bags included) | no things |
| `memberships` | `[Membership]` | one per (thing, template, place on it) | — |
| `templates` | `[PackList]` | templates WITHOUT their items (`items == []`) | — |
| `trips` | `[TripEvent]` | trips WITH their lines (`entries`) | — |
| `actions` | `[ActionItem]` | to-dos and buy lines | — |
| `kits` | `[Kit]` | kits | — |
| `phases` | `[Phase]` | his own "When" timeline | "use the factory seven" (`DEFAULT_PHASES`), never "no phases" |
| `shared` | `[SharedRow]` | his authored Settings lists, one row per entry | a kind with no rows = "use the code's defaults" |
| `photos` | `[PhotoRecord]` | every picture, once | — |
| `meta` | `[String: JSONValue]` | facts about the library itself, by name | — |

`isEmpty` is true only when all ten are empty — a device's check-in aside (0.62): a `meta` key for which `Library.isDeviceNote` is true (`syncCheck.*`) does not count, because it is about the device, not about his things. Until 0.62 one press of Sync now on an empty device made it "not empty" (Open questions 3).

Rule 1 of docs/store.md is built in: nothing factory-made is ever stored. `Library().records()` is `[]`.

### 1.2 `Item` (PackingCore/Items.swift) — one struct, three roles

The same struct is (a) a catalogue item, (b) a resolved template row, (c) a trip line. Every field below is a JSON key of the same name unless noted.

| Group | Fields (type, default from `newItem`) |
|---|---|
| identity | `id` (String, `PackingEnv.makeId()`), `name` (""), `swedish` (original wording, ""), `qty` (free text, ""; a JSON number is read as its text) |
| grouping | `category` (`CATEGORY_DEFAULT` = "Comfort & misc"), `container` (the bag NAME, "Carry-on / hand luggage"), `phase` (the "When" id, "week"), `itemType` ("item" or "reminder") |
| flags | `charging`, `chargeType` (one of "", usb-c, usb-a, micro-usb, lightning, special, mains), `shortList`, `liquid`, `restricted`, `perNight`, `consumable` (all Bool false) |
| conditions | `seasons`, `contexts`, `transports`, `catering`, `weather` (each `[String]`, [] = applies to any); `sub` (sub-item names) |
| words | `note`, `section` (on a resolved row: a SECTION ID; on a trip line: the section's display NAME), `kit` (kit NAME), `packer` (person name), `storage` (where kept at home) |
| pictures | `photos` (`[String]` of photo ids, max `MAX_PHOTOS` = 5; may still hold legacy inline `data:` URLs), `thumb` |
| care | `maintenance` (`Maintenance?`: notes, link, intervalDays, lastDone, log[{date, note}]; nil unless it holds something), `stats` (`ItemStats`: packed, used, unused, skipped, lastReviewed) |
| metadata | `color`, `size`, `manufacturer`, `model`, `ownedBy` ("whose it is" — NEVER `owner`), `acquired` (YYYY-MM-DD), `price` (≥0), `currency`, `purchaseLink`, `expiry` (YYYY-MM-DD), `condition` (condition id), `retired`, `retiredReason` (sold/broken/destroyed/replaced/lost/other), `serial`, `qtyOwned` (Int ≥0), `warranty` (YYYY-MM-DD), `capacityL`, `maxKg` (bag numbers), `weight` (grams per unit, ≥0), `keep` (Refine's "Keep it") |
| trip line only | `sourceListId`, `sourceItemId` (String?, nil = absent), `custom`, `checked`, `skipped` (= set aside for this trip), `used` (Bool?, nil = not answered), `edited` (JSON key `_edited`) |
| resolved row only | `itemId` (`_itemId`), `memId` (`_memId`, "" = a thing on no list), `link` (`_link`), `ovContainer` (`_ovContainer`), `tplContainer` (`_tplContainer`), `defContainer` (`_defContainer`), `ovPhase` (`_ovPhase`), `defPhase` (`_defPhase`) — all optional |
| unknown | `extra: [String: JSONValue]` — every key this build does not know, kept and written back |

Written JSON: every plain field always; `keep` always; the optional/trip/resolved fields only when set (`custom`/`checked`/`skipped`/`_edited`/`_link` only when true). `maintenance` is written as `null` when nil.

**Coercion (`coerceItem`), applied on every decode and by `newItem`:**
- `weather` keeps only the ids rain, cold, hot, wind, snow.
- `phase`: trimmed; empty → `defaultPhaseId()` (first non-task phase of the live list); any non-empty id is KEPT even when unknown (phases sync), cut to 40 UTF-16 units.
- `category` "" → "Comfort & misc". `itemType` anything but "reminder" → "item". `chargeType` not in the list → "".
- `weight`, `price`, `capacityL`, `maxKg`: non-finite or negative → 0. `qtyOwned` < 0 → 0.
- `photos`: empties dropped, cut to 5. `acquired`, `expiry`, `warranty`: not YYYY-MM-DD → "".
- `condition`: trimmed, cut to 40, unknown ids KEPT. `retiredReason`: not in the list → "".
- `maintenance` normalised (interval floored, ≥0; dates must be YYYY-MM-DD; log entries without a date dropped; log sorted oldest first; all-empty → nil). `stats`: every count floored, negatives → 0.
- Legacy: a single `photo` string is folded into `photos` when `photos` is empty. A legacy `owner` is adopted into `ownedBy` only when there is no `ownedBy` AND it does not look like an e-mail address.
- `id`, `name`, `qty`, `container`, `note` read a JSON number as its text (`jsLooseText`), anything else that is not a string as "".
- NOTE `Item(json:)` (= `coerceItem`) gives a MISSING key coerceItem's answer, not `newItem`'s default: a missing `container` reads "" (not the hand luggage), a missing `phase` reads the live default phase. `newItem(json:)` lays a partial over `newItem`'s defaults first.
- A non-object reads as `{}`; decoding never throws (`JSONModel`: decoding IS coercion).

### 1.3 `Membership` (PackingCore/Memberships.swift)

Fields: `id`, `itemId`, `templateId`, `seasons`, `contexts`, `transports`, `catering`, `weather` (conditions — they belong to the place on the list, not to the thing), `container` ("" = follow the template's default, then the thing's own), `section` (section id in THIS template), `kit` (kit name, per template), `phase` ("" = the thing's own), `itemType` ("" = the thing's own), `qty`, `note` ("" = the thing's own), `order` (Double, position in the template, never floored), `extra`.

Coercion: `weather` filtered to the five ids; `phase` trimmed, cut to 40, unknown kept; `itemType` only "item"/"reminder"/""; non-finite `order` → 0; `qty` a number → its text, falsy → "".

Field ownership (single source of truth, `INTRINSIC_FIELDS` / `DEFAULT_FIELDS` / `CONTEXTUAL_FIELDS`):
- INTRINSIC (belongs to the THING): name, swedish, category, charging, chargeType, liquid, restricted, perNight, consumable, shortList, weight, storage, packer, sub, photos, thumb, maintenance, stats, color, size, manufacturer, model, ownedBy, acquired, price, currency, purchaseLink, expiry, condition, retired, retiredReason, keep, serial, qtyOwned, warranty, capacityL, maxKg.
- DEFAULTS (the thing's own bag and When, reaching it only through `_defContainer` / `_defPhase`): container, phase.
- CONTEXTUAL (per template): seasons, contexts, transports, catering, weather, kit, qty, note, itemType. `section` travels between templates by NAME only.

### 1.4 `PackList` — a template (PackingCore/Lists.swift)

Fields: `id`, `name`, `emoji` (cover glyph, trimmed, ≤4 units; "" = 📋), `color` (hex `#rgb`…`#rrggbbaa` or "" = a stable hashed pick from `TEMPLATE_COLORS`), `sections` (`[TemplateSection{id, name}]`: unnamed dropped, missing id made up, repeated id dropped), `group` (GA / WET / OE or ""), `role` ("base" = always on every trip, "transport", "loose" = the retired Loose-items bin, "container" = his BAG list, stored as "Containers", shown as "Bags"; anything else → ""), `transport` (Car / Plane / RV or ""), `defaultContainer`, `builtin`, `items` (resolved rows — only in a backup and in resolved views; ALWAYS [] in `Library.templates`), `createdAt`, `updatedAt`, `extra`.

### 1.5 `TripEvent` — a trip, and its lines (PackingCore/Events.swift)

Fields: `id`, `name`, `mode` ("trip" or "quick"), `activities` (template ids chosen), `transport`, `season`, `contexts`, `weatherOn` (filtered to the five weather ids), `catering`, `startDate`, `endDate`, `nights` (Int ≥0, floored), `laundry`, `destination`, `weather` (`WeatherSnapshot?`: place, lat?, lon?, fetchedAt, daily[{date, code, tmax?, tmin?, precipProb, wind}] — nil when no dated days), `geo` (`GeoFix?`: lat −90…90, lon −180…180, place — nil when out of range), `entries` (`[Item]`, the lines), `status` ("active" or "done"), `reviewedAt`, `generatedAt`, `createdAt`, `updatedAt`, `extra`.

`newEvent` defaults: mode "trip", transport "Car", season "Summer", catering "mixed", status "active", createdAt/updatedAt now. `TripEvent(json:)` does NOT apply those defaults for missing keys (missing transport reads ""), exactly as the web app's `coerceEvent`.

A trip line is an `Item` copy: it stands on its own when its template or thing is gone (rule 9).

### 1.6 `ActionItem` — a to-do or a buy line (PackingCore/Actions.swift)

Fields: `id`, `text`, `kind` ("todo" or "shopping"; anything else → "todo"), `itemId` ("" = loose), `itemName` (cached), `priority` ("high" or "normal"; else "normal"), `whenPhase` (trimmed, ≤40, unknown kept), `whenDate` (YYYY-MM-DD or ""), `done`, `doneAt`, `createdAt` (missing → now), `updatedAt` (missing → createdAt), `phase` (String?, a parity quirk: never written by the app), `extra`.

### 1.7 `Kit` (PackingCore/Kits.swift)

Fields: `id`, `name`, `emoji` (trimmed; "" = 🧰), `note`, `itemIds` (member catalogue ids; empties and repeats dropped, order kept), `createdAt`, `updatedAt`, `extra`.

### 1.8 `Phase` — a "When" step (PackingCore/Phases.swift)

Fields: `id` (≤40), `label` (≤60), `hint` (≤200), `emoji` (≤8; "" → 📦), `color` (hex, else `TEMPLATE_COLORS[position % 10]`), `task` (holds to-dos, not things), `leadDays` (rounded, clamped −1…365; −1 = after the trip), `order`. No `extra`: unknown keys on a phase are NOT kept.

The factory seven, with stable ids: prep (Preparations, task, 30 days), week (≥1 week ahead, 7), daybefore (Day before, 1), morning (Morning list, 0), door (At the front door, 0), wear (Wear / carry on the day, 0), after (After / recovery, −1). `setPhases` drops rows without id or label and repeated ids, falls back to the factory seven when nothing usable is left, sorts by `order` then `id` (locale compare; the tiebreak keeps two devices agreeing) and renumbers `order` 0…n−1. It installs the result into the GLOBAL `PHASES` / `PHASE_IDS` (module state, as in the web app). `phasesCustomised` is true when the list differs from the factory seven in count or in any of id, label, emoji, color, task, leadDays. Only a customised list is stored (`Library.setTimeline`).

An id this device does not know is drawn with `phaseOrFallback`: label = the raw id ("Unsorted" when empty), emoji ❓, colour `#64748b`, sorted to the end.

### 1.9 `SharedRow` — his authored Settings lists (PackingCore/SharedRows.swift)

Six kinds in ONE table, one row per entry: `conditions`, `presets`, `people`, `owners`, `places`, `grab`. Fields (exactly these six, nothing else is kept): `id` (= `"<kind>:<normName(key)>"`, stable so two devices adding "Garage shelf" land on one key), `kind` (unknown → ""), `key` (normalised name, ≤60; for a condition its slug id; for a grab list its code id), `name` (display spelling, trimmed, ≤80), `order` (Double; non-finite → position), `data` (an object; everything else nested so nothing collides with the reserved sync keys):
- conditions: `data = {tone, replace, cid}` — `cid` keeps the id verbatim.
- people: `data = {color}`; the person's id IS the row id.
- owners / places: no data. Owners read A–Z; places read in stored order (he arranges them).
- presets: `data = {config, createdAt}`; a preset with a falsy config is dropped; same name replaces.
- grab: `data = {gid, items, label, icon, tone}` (label ≤24, items ≤80 units each, blanks dropped).

`sharedRowsOfKind` filters to one kind, drops rows without key or name, sorts by order then id. Writing a list that is still exactly the factory list REMOVES its rows (`isFactoryList`; `setNames`, `setPeople`, `setConditions`). The factory lists live in code: `DEFAULT_ITEM_CONDITIONS` (new, good, worn, retire), two factory people (names in SharedRows.swift), `DEFAULT_STORAGE_LOCATIONS` (Bedroom wardrobe, Chest of drawers, Hall closet, Bathroom cabinet, Kitchen cupboard, Garage, …, RV / camper).

### 1.10 `PhotoRecord` (PackingCore/Backup.swift)

`{id, data, createdAt}`, `data` a `data:image/jpeg;base64,…` URL. In memory and in a backup the picture is that URL; in the store it is split into bytes + mime (§3). Who points at a photo: an item's `photos`, a trip line's `photos`, and a trip's `extra.bagPhotos` (up to `BAG_PHOTOS_MAX` = 3 per bag). `photoInUse(id)` checks all three.

### 1.11 `meta` keys (every one used anywhere)

| Key | Value | Written by | Meaning |
|---|---|---|---|
| `import` | `{at, exportedAt, templates, items, memberships, trips, lines}` | `Importer.library` | this library came from a backup file: when, which file (its `exportedAt`), how many of each. Shown since 0.62 under This device holds (`broughtInWords`, §13) |
| `syncCheck.iPhone`, `syncCheck.Mac` | `{at: ISO, device}` | `Library.checkIn` (Sync now) | when that device last checked in. A "device note" (`isDeviceNote`, 0.62): not counted by `isEmpty`, and carried across an import and a restore (`keepingDeviceNotes`, §9, §11) |
| `grabOwnLists` (`GRAB_OWN_META`) | `[{id, label, title, tone, icon, items}]` | GrabCollection | grab lists he made himself (ids `own-` + `PackingEnv.makeId()` since 0.62; lists made before keep `own-<ms>-<3 digits>`) |
| `grabHome` (`GRAB_HOME_META`) | `[id]` | GrabCollection (`setHomeGrabLists`; `deleteOwnGrabList` takes a deleted list's id out) | which grab lists sit on Home, in order (at most 8 places) |
| `grabOff` (`GRAB_OFF_META`, 0.61) | `[id]` | GrabCollection (`setHomeGrabLists`, written together with `grabHome`; an empty list removes the key) | the grab lists he left off Home when he last arranged it: they wait until he puts them back, and a free place on Home never pulls one of them in |
| `grabSometimes` (`GRAB_SOMETIMES_META`) | `{listId: [names]}` | GrabSometimes | things taken "only sometimes", per grab list |

The four grab keys ride in a backup under `prefs.grab` (`own`, `home`, `off`, `sometimes`; §10) and come back with an import (§9). `import` and `syncCheck.*` are never written into a backup. Each key is ONE record (§3), so the later of two offline writes wins for the whole key; the Home arrangement is two records (`grabHome`, `grabOff`) that settle separately.

### 1.12 `extra` keys (every one written anywhere in the native app)

The native app adds its own fields as `extra` keys so the web app's model stays untouched; they ride through the store, backups and (for trips) share links.

| Holder | Key (constant) | Value | Meaning |
|---|---|---|---|
| trip | `laundryNights` (`LAUNDRY_NIGHTS_KEY`) | number 1…60 | nights packed for before a wash (else 4) |
| trip | `weighed` (`WEIGHED_KEY`) | `{bag name: grams}` | the luggage-scale reading per bag; removed when empty |
| trip | `bagPhotos` (`BAG_PHOTOS_KEY`) | `{bag name: [photo id]}` (0.52/0.53 stored ONE id as a string; read as a list of one) | photos of each packed bag, ≤3; removed when empty |
| trip line | `boughtThere` (`BOUGHT_ON_SITE_KEY`) | true | bought on site (stored name kept from before the rename) |
| trip line | `packedHome` (`HOME_KEY`) | true / absent | ticked for the way home |
| trip line | `usedUp` (`USED_UP_KEY`) | true / absent | used up or left on site (clears `packedHome`) |
| trip line | `homeNote` (`HOME_NOTE_KEY`) | string / absent | a note made while packing to go home |
| trip line | `packedAt` | — | never written by the native app; only CLEARED by "start a new trip from this one" (a web-app key) |
| action | `reminderId` (`REMINDER_ID_KEY`) | string | the Apple Reminders id a buy line became |
| template | `iconKey` (`Library.iconKey`) | icon key, or "letter" | the icon he picked |
| item (a bag) | `cabin` (`CABIN_KEY`) | Bool | his word that this bag goes in the cabin (else judged by its name) |
| trip head record only | `entryOrder` | `[entry id]` | the order of the lines (store-only, never in memory — §3) |

Reserved: `owner` and `realmId` are never read into `extra`, never written (`RESERVED_SYNC_KEYS`); the web app lost 422 owners to `owner`.

**Through a backup and a restore (0.61).** A thing's `extra` keys — the bag's `cabin` answer and any key this build does not know (one the web app keeps) — come back exactly: from a file this app wrote they arrive with the thing as stored (the file's `items` key, §10); from an older file of ours or the web app's they are carried from the template rows (`carryRowExtras`) and, for a thing on no list, from its `things` entry (§9). A membership's own `extra` comes back only from a file this app wrote (`memberships` key); a resolved row does not carry it. Trip, line, template, action and kit `extra` keys travel inside their own records in every file. Pinned by `BackupTests.testABackupBringsBackExactlyWhatWasThereCabinAnswersIncluded`, `testAnOlderBackupComesBackWithItsCabinAnswersAndUnknownKeys`, `ImporterTests.testAKeyThisBuildDoesNotKnowComesAcross` and `RestoreTests.testTheCopyKeptBeforeARestoreBringsBackEverythingCabinAnswersIncluded`.

### 1.13 Ids and timestamps

- Ids: `PackingEnv.makeId()` → `<now in ms, base36>-<sequence, base36>-<6 random base36 chars>` (the web app's `id()` format). Stable keys for things that are the same thing on every device: phases (`prep`…), shared rows (`places:garage shelf`), grab rows (`grab:swim`). Trip lines keyed `"<tripId>|<entryId>"` in the store.
- `nowISO()` = UTC `YYYY-MM-DDTHH:MM:SS.mmmZ` through `PackingEnv.now`.
- Model `updatedAt` fields are strings on templates (set by `saveTemplate`), trips (set by most trip edits), actions, kits. They are NOT used for sync. The store's own `updatedAt` (a `Date` on every record, §3) is what settles twins.

**iPhone vs Mac.** None: the model is shared code.

**Tests.** Model: `ItemsTests` (all 20, e.g. `testCoerceItemKeepsAPhaseThisDeviceDoesNotKnow`, `testTheReservedSyncKeysAreNeverKeptOrWritten`, `testDecodingIsCoercionAndNeverThrows`, `testCoerceItemAdoptsALegacyOwnerNameButNeverTheSyncAddress`, `testCoerceItemPhotosArrayIsFilteredAndCapped`), `MembershipsTests` (5), `ListsTests` (15), `EventsTests` (6), `ActionsTests` (3), `KitsTests` (5), `PhasesTests` (12), `SharedRowsTests` (26, e.g. `testSharedRowIdTwoDevicesAddingTheSameNameLandOnTheSameKey`, `testIsFactoryListTheDefaultsAreRecognisedSoTheyAreNeverWrittenAsData`, `testGrabIsAKindOfTheExistingSharedTableNotANewTable`), `SettingsListsTests`, `LibraryTests.testAnEmptyStoreIsAnEmptyLibrary`, `StoreTests.testAnEmptyDeviceThatHasCheckedInStillTakesItsBackup` (0.62: check-ins do not count), `StoreTests.testANewGrabListsIdComesFromTheAppsIdMaker` (0.62). Each extra key the app writes has a store round-trip test in its own feature's tests (`LaundryNightsTests`, `WeighingTests`, `OnTheTripTests`, `WayHomeTests`, `BuyRemindersTests`, `TemplateIconTests`, `TripChecksTests`, `GrabSometimesTests`, `GrabCollectionTests`).
Not covered: unknown keys on phases / shared rows / photos / sections being dropped on rewrite.

**Traps and history.**
- 🪤 `owner` / `realmId`: the web app's sync addon stamped the account address into `owner` on every write (v117, 422 owners lost). The field is `ownedBy`; the two keys are refused everywhere.
- 🪤 Phases and conditions keep unknown ids: a whitelist would silently retag a thing the moment one device read a phase the other had just added.
- 🪤 Never seed: v118 seeded factory phases with stable ids and they landed on top of his customised rows. A kind with no rows means "defaults".
- 🪤 One row per entry, never one row per list (web v120): a whole list in one record lets the last device to save win outright.

---

## 2. Resolving a template, saving it back, regenerating a trip

**Purpose and origin.** A template is never stored with its items; screens always work on a RESOLVED copy (`Library.resolved(_:)`, the web app's `resolveOne`) and a save takes it apart again (`saveTemplate`, the web app's `saveList`, v176/v188).

**Behaviour — resolving (Resolve.swift, `Library.resolveOne`).**
1. Memberships of the template, stable-sorted by `order` (NaN counts as 0).
2. For each, the thing by id (a membership whose thing is missing is skipped).
3. `resolveMembership(item, m, templateDefaults)`: starts from the coerced thing; the membership's conditions REPLACE the thing's; container = membership exception, else the template's `defaultContainer`, else the thing's own; `_ovContainer`/`_tplContainer`/`_defContainer` hand back the three parts; `section` and `kit` come only from the membership; phase = exception else the thing's (`_ovPhase`, `_defPhase`); itemType / qty / note = membership's when non-empty, else the thing's. The thing's `extra` rides along on the row.
4. The row gets `_itemId` = thing id and `_memId` = membership id. Row `id` = the THING's id — so the same thing twice on one template gives two rows with the same `id`; rows are told apart by `memId`.
5. `resolvedTemplates()` sorts templates A–Z by `jsLocaleCompare(name)`.
- `resolveItemAlone(thing)` resolves against an empty membership (`memId` ""): a thing on no list. `thingsOnNoList()` = the things with no place in `placesOnTemplates()`, each resolved alone.
- `placesOnTemplates()` (0.61) = the memberships whose template AND thing both exist — the places that can be shown. A membership pointing at a gone template (a delete on the other device while this one added to it) is left out, so a thing whose only memberships are such orphans now counts as on no list. (Until 0.61 `thingsOnNoList()` excluded every thing with any membership, so such a thing was in neither `lists` nor `things` of a backup and a restore lost it.) Both are used only by the backup (§10).

**Behaviour — saving (`Library.saveTemplate(_ list:, keepingMembershipIds: true)`).** For each row of the edited resolved list, in order (`order` = 0, 1, 2…):
1. Rows with a blank (trimmed) name are skipped.
2. Which thing: by `_itemId` if it exists; else by `normName(name)` (first thing of that name); else new.
3. Existing thing → `applyIntrinsic(thing, row)`: every INTRINSIC field the row carries is written onto the thing, plus `_defContainer`→container and `_defPhase`→phase when present; the thing's other fields and its `extra` stay. A `_link` row carries only `name`.
4. No thing and the row is a link → row skipped (never invent a thing from a link whose target vanished).
5. New thing → `catalogItemFromResolved(row)` (its container/phase/itemType + intrinsic fields + default channels; nothing contextual — so no `note` and no `qty`, which go onto the membership; the row's `extra` is NOT copied — the import carries it afterwards, §9); keeps the row's `_itemId` as its id when one is given.
6. Membership: the row's `_memId` if it belongs to this template; else an unused membership of this template for the same thing; else (keepingMembershipIds) a new membership WITH the row's `_memId`; else a new id. `membershipFromResolved` writes conditions, the exception (`_ovContainer` verbatim when present, else inferred with `containerOverrideFor`), section, kit, phase exception, itemType when it differs from the thing's, qty, note, order — then qty and note are put right (`Library.placeAnswer`, spec 04 §13): an unchanged row keeps what its place stored; a changed or new one stores them only where they differ from the thing's own, else "" (until spec 04's pass, 5 Oct 2026, the thing's own note and qty were copied in).
7. Memberships of this template not touched by the save are removed. Things are never removed.
8. The template is stored without items, coerced, `updatedAt` = now; replaced in place or appended.

**Behaviour — regenerating a trip (`Library.regenerated(_ trip:)`, used by `changeTrip`).** Fresh lines = `buildTotalEntries(trip, resolvedTemplates())`. Each fresh line with a non-empty `sourceItemId` is REPLACED by an old line with the same `sourceItemId` — preferring one in the same bag (normName of container) — each old line at most once. The old line is kept exactly as it was (id, tick, set-aside, note, qty, extra keys, everything); the fresh copy is thrown away, so a Trip settings Save never brings a template's newer qty/note/bag onto a line that already existed (only `followThing` does that, for unticked lines of trips ahead — another chapter). Leftover old lines (not taken) are kept when: custom; or ticked/edited AND they have a non-empty `sourceItemId` that no fresh line covers; or their `sourceListId` is non-empty and names a template that no longer exists. Every other leftover is dropped — including a TICKED line that has neither `sourceItemId` nor `sourceListId` and is not custom (the shape of every line of a shared trip, Open questions) (rule 9: one of his real trips names three deleted templates — "from 88 lines to none"). Finally any repeated line id is replaced by a new id ("belt and braces", his E.6 crash 2026-09-28: one id twice made the Mac app stop).

**Data.** Reads `items`, `memberships`, `templates`; writes the same.

**Tests.** `ResolveTests` (8), `LibraryTests`: `testOneThingOnTwoTemplatesIsOneItemWithTwoMemberships`, `testTheSameThingTwiceOnOneTemplateKeepsBothRows`, `testTakingAThingOffItsLastListKeepsTheThing`, `testRegeneratingNeverDropsTheLinesOfADeletedTemplate`, `testRegeneratingStillDropsWhatALivingTemplateNoLongerHas`; `TripEditsTests.testAThingOnTheTripTwiceKeepsBothLinesAndTheirTicks`, `testAChangedTripRebuildsAndKeepsWhatHeDid`; `CreateTripTests` (14).

**Traps and history.** 🪤 The same thing can sit on ONE template twice (a different "When"): key rows by membership id, never by item id. 🪤 A partial copy once erased photos/care/purchase details everywhere — hence one `INTRINSIC_FIELDS` list and the "absent key is left alone" rule of `applyIntrinsic`. 🪤 `saveReview` writes review history straight onto each thing, not through `saveTemplate`, because a stale twin row would overwrite it.

---

## 3. Records — how the library is cut up for storing and syncing

**Purpose and origin.** docs/store.md (decided 21–22 Sep 2026): one small record per thing, one generic shape for all of them, so the CloudKit schema never has to change. `LibraryRecords.swift` is "the ONLY place that knows how the library is cut into records".

**Shapes (Records.swift).**
- `enum Table: String, CaseIterable` — in this order: `items`, `memberships`, `templates`, `trips`, `entries`, `actions`, `kits`, `phases`, `shared`, `photos`, `meta`. The raw value is what is stored.
- `RecordID(table, key)` — ordered by table raw value, then key (plain Swift `String <`).
- `StoredRecord { table, key, parent, json: JSONValue, blob: Data?, updatedAt: Date }`. `sameContent(as:)` compares everything except `updatedAt`.

**Behaviour — `Library.records(at now = PackingEnv.now())`.** Deterministic; every record gets `updatedAt = now`. A record whose key is "" is silently NOT produced.

| Table | One record per | key | parent | json |
|---|---|---|---|---|
| items | thing | item id | "" | `Item.json` |
| memberships | membership | membership id | template id | `Membership.json` |
| templates | template | template id | "" | `PackList.json` with `items: []` |
| trips | trip | trip id | "" | `TripEvent.json` WITHOUT `entries`, PLUS `entryOrder: [line ids]` |
| entries | trip line | `"<tripId>\|<entryId>"` | trip id | `Item.json` of the line |
| actions / kits / phases / shared | each | its id | "" | its json |
| photos | photo | photo id | "" | `{id, createdAt, mime}`; the picture's BYTES go in `blob` |
| meta | key | the meta key | "" | the value |

A photo's `data` URL is split by `Library.bytes(fromDataURL:)`: it must start `data:` and contain a comma; the mime is the first `;`-part of the header, empty parts kept (so `data:;base64,…` reads `image/jpeg`, not "base64"); default `image/jpeg`. Since 0.62 it is read the way a browser reads a picture (`looseBase64`): when one of the header's `;`-parts is `base64`, the rest is taken exactly when `Data(base64Encoded:)` accepts it (nearly every photo), else again with white space and line breaks dropped, the web-safe `-` `_` read as `+` `/` and the `=` padding made right; a data URL that is not base64 is read as `%`-escaped bytes (`percentDecoded`). Only what is no picture at all (not a data URL, a broken `%` escape, base64 that is still wrong) gives no bytes (`blob` nil) — after the next load that photo's `data` is "": its record stays, its picture is gone. Until 0.62 a line break or a missing `=` in the code was enough for that, and nothing said so (Open questions 27). A picture read loosely comes back as the plain base64 URL of the same bytes.

**Behaviour — `Library(records:)` (never fails).**
1. `settleDuplicates` (below), then the survivors sorted by `RecordID` — so after a load every collection is in KEY order (items by id, templates by id, trips by id…), not in the order they were added.
2. Each record decoded by its type's coercing `init(json:)`. `templates` get `items = []`.
3. Trips: `entryOrder` is read and removed from the head. Lines are grouped by `parent`. A trip's lines = first the ids named in `entryOrder` (each once), then any other line of that trip in key order (a line added on the other device while this one saved the head is NOT lost — it is appended). A line id appearing twice is kept once.
4. Lines whose trip has not arrived are not shown (they stay in the store).
5. Photos: `id` = the record KEY (not the json's `id`); `data = "data:<mime>;base64,<blob>"`, or "" when there is no blob; `mime` default image/jpeg; `createdAt` from the json ("" when absent).
6. `phases` finally stable-sorted by order, then id (`jsLocaleCompare`).

**Behaviour — `settleDuplicates(_:)`.** CloudKit cannot enforce a unique key; two devices can create `phases/prep` independently. Group by (table, key); the NEWEST `updatedAt` wins; on an exact tie the record whose `json.text()` is greater (plain string compare) wins, so both devices pick the same survivor whatever order they read them in. Returns `(kept, dropped)`; kept in first-seen order.

**Behaviour — `recordChanges(from: old, to: new)` — the write path of the whole app.** Puts = every new record that is not in old with the same content (`updatedAt` ignored); deletes = every old id not in new, sorted. So a tick is ONE `entries` put; deleting a trip deletes its head and its line records; nothing that did not change is ever written.

**Data.** JSON text in the store is `JSONValue.text()`: keys sorted, `/` not escaped, whole numbers without ".0", NaN/∞ as null.

**Tests.** `LibraryTests.testRecordsRoundTrip`, `testATickIsOneSmallRecord` (a tick puts only `.entries`), `testALineTheTripHeadHasNotHeardOfIsStillShown`, `testTwoRecordsWithOneKeySettleTheSameWayOnBothDevices`, `testAnEmptyStoreIsAnEmptyLibrary`, `testTheStoreOnlyEverSeesTheDifference`; `TripEditsTests.testADeletedTripTakesOnlyItself` (its lines leave the records); `CreateTripTests` ("one record per to-do", one items record per thing); the import-check tool asserts zero drift after a store round trip.
`StoreTests.testAPhotoWrittenLooselyKeepsItsPicture` (0.62: line breaks, no padding, web-safe letters and a `%`-escaped URL all keep their picture), `testRecordsTheLibraryCannotShowAreLeftInTheStore` (0.62: an orphan line stays in the store), `testCountsAreWhatTheRecordsWouldBeWithoutWritingThem` (empty keys are not written and not counted).

**Traps and history.** 🪤 Web v120: one row per list made the last device to save win — here a line, a membership, a shared entry each is its own record. 🪤 What this gives up: two edits to the SAME record on two offline devices — the later write wins.

---

## 4. Where records are kept — `LibraryStore`, `MemoryStore`, `CloudStore`

**`protocol LibraryStore: AnyObject`** (LibraryStore.swift): `loadAll() throws -> [StoredRecord]`; `apply(_ changes: RecordChanges) throws` (write and delete in one step); `var onRemoteChange: (() -> Void)?` (records arrived from the other device; the library reloads).

**`MemoryStore`** (tests): a dictionary by `RecordID` plus insertion order; `log` of every applied change set ("what was actually written?"); `simulateRemote(_:)` applies changes and calls `onRemoteChange`. A memory store cannot hold twins.

**`CloudStore`** (App/Sources/Store/CloudStore.swift):
- ONE SwiftData model, `@Model final class Record { table: String = ""; key: String = ""; parent: String = ""; json: Data = Data(); @Attribute(.externalStorage) blob: Data?; updatedAt: Date = .distantPast }`. Every attribute has a default or is optional and nothing is unique — CloudKit's rules for a synced model. `json` holds the UTF-8 bytes of `JSONValue.text()`. In CloudKit the fields appear as `CD_table`, `CD_key`, `CD_parent`, `CD_json`, `CD_updatedAt`, and the external blob as `CD_blob` (Bytes) and `CD_blob_ckAsset` (Asset).
- `Record.stored`: nil when `table` is not a known `Table` or the json does not parse — such records are invisible to the app (a newer build's new table is ignored, never deleted).
- `init(cloud: Bool, inMemory: Bool = false)`: `ModelConfiguration("Library", schema: [Record], isStoredInMemoryOnly: inMemory, cloudKitDatabase: cloud ? .private(containerId) : .none)`; a `ModelContext` with `autosaveEnabled = false`; observes `.NSPersistentStoreRemoteChange` (any object, main queue) → `onRemoteChange`. `containerId` = `"iCloud." + PRODUCT_BUNDLE_IDENTIFIER` (the literal is in CloudStore.swift and both iCloud entitlement files; it must never change, or the app opens a different, empty container). The store file is `Application Support/Library.store` (in the Mac's sandbox container).
- `loadAll()`: fetch every `Record`, map `stored`.
- `apply(_:)`: no-op when empty; fetch ALL records, group by (table, key); each put updates the FIRST twin in place (parent, json, blob, updatedAt) and deletes the other twins, or inserts a new `Record`; each delete removes every twin of that id; one `context.save()`.

**iPhone vs Mac.** Same code. The Mac app is sandboxed; the iCloud build carries the extra entitlements of §7.

**Tests.** `LibraryTests.testTheStoreOnlyEverSeesTheDifference` (MemoryStore). CloudStore itself has NO test: it is SwiftData in the app target, there is no app-hosted unit-test target, and no iCloud in CI (docs/store.md: proved on his devices). Its twin rule is played by `StoreTests.TwinStore` (a put updates the first twin and deletes the others, as `apply` does) in `testLoadingSettlesTwinsSoBothDevicesHoldTheSame` (0.62).

**Traps and history.** 🪤 Every `apply` fetches the whole store to find twins — O(records) per change (said in a
comment in `apply` since 0.62, with why: only a full fetch is sure to see every twin of a key). 🪤 The remote-change
notification is heard on the main queue and the model reloads the whole store there (comment in `CloudStore.init` and
`LibraryModel.init`, 0.62).

---

## 5. `LibraryModel` — the one way the library changes

**Purpose.** `@MainActor final class LibraryModel: ObservableObject` (App/Sources/Store/LibraryModel.swift): "the values in memory, and the one way to change them — change the library, store the difference." One instance per run, `LibraryModel.shared`, shared by the screens and the Shortcuts.

**Published state.** `library: Library`; `state: State` = `.loading` | `.empty` | `.ready` | `.failed(String)`; weather/map flags (`lookingUpWeather`, `weatherTrouble`, `findingPlaces`, another spec); `tripToOpen`, `grabToOpen`, `grabMenuOpen` (requests from reminders/Shortcuts). Private: `store`, `held: [StoredRecord]` (what the store is believed to hold), `usesICloud`, `sky` (forecaster). (`lastImport`, published and never shown, is gone since 0.62: the import's own marker is shown instead, §13.)

**Behaviour.**
- `init(store:usesICloud:sky:)`: sets `store.onRemoteChange = { Task { @MainActor in reload() } }`, then `reload()` synchronously (so `.loading` is only momentary).
- `reload()` = `StoreSession.load(store)` (PackingLibrary, 0.62 — the same steps, moved where the model tests reach them): `loadAll()` → `settleDuplicates`; if anything was dropped, RE-WRITE the survivors of those keys (`apply(puts:)`, which in CloudStore deletes the losing twins) so both devices end up holding the same records; `fresh = Library(records: kept)`; `held = fresh.records()` (rebuilt from the library, NOT the loaded records — so records the library cannot see, e.g. orphan lines or an unknown table, are never in `held` and therefore never deleted by a later diff). Then: publish `library` only when `fresh != library`; `fresh.installLiveChoices()` installs the live phases (`setPhases(fresh.phases)` — [] gives the factory seven) and conditions (`conditionsFromRows(shared)`, or `DEFAULT_ITEM_CONDITIONS`); `state = fresh.isEmpty ? .empty : .ready`; then (0.62) `change { $0.repairConditionLabels() }` — a thing whose condition the table stored as a LABEL before 0.62 gets the condition's id, written once (nothing to repair = no write; the same answer on every device; Things spec). Any throw → `.failed(error.localizedDescription)`.
- When reload runs: at launch; on every remote-change notification; 3 s after Sync now; right after a restore.
- `change(_ body: (inout Library) -> Void)`: copy, mutate, `commit`.
- `commit(next)` = `StoreSession.save(next, held:, to: store)` (0.62): `records = next.records()`; `changes = recordChanges(from: held, to: records)`; nothing changed → nil, and commit returns WITHOUT publishing `next`; else `store.apply`, then `held = records`, `library = next`, `state = next.isEmpty ? .empty : .ready`. A throw → `.failed(...)`, and `library`/`held` keep their old values.
- Order note: after `commit` the in-memory arrays are in edit order; after the next `reload` they are in key order (§3).

**What `.failed` shows.** `RootView`/`SectionScreen`: EVERY tab shows only the message, 17 semibold, red `#dc3d43`, centred, padding 24, id `library-problem`. `.empty` shows `FirstRunView` on Home and the real `SettingsScreen` on Settings; every other tab shows its placeholder (the section's mark at 96 and its name, 34 heavy, id `screen-title`). `.ready` shows the screens.

**`importBackup(_ data:)`** — the one-time import (first-run door) = `Importer.firstImport(data, onto: library)` (0.62; `LibraryModel.ImportError` is `Importer.Refusal`): not JSON or not `looksLikeBackup` → `.notABackup` ("That is not an AMS Packing backup file."); `library` not empty (`isEmpty`: anything of his — a device's check-in does not count) → `.alreadyImported` ("This library has already been imported into."); `Importer.library(from:)`; not faithful → `.notFaithful(n)` ("The import did not come back the same (n rows differ), so nothing was stored."); else the imported library with this device's check-ins laid over it (`keepingDeviceNotes` — the import used to delete them) → `commit`, then `installLiveChoices()`.

**`inspectBackup(_ data:)`** = `Importer.read(data)` — read a file and change NOTHING: the same two refusals (`notABackup`, `notFaithful`); returns `(library, report)`. Since 0.62 "nothing" includes the live "When" steps and conditions: `Importer.library` installs the file's only while it reads it and puts the live ones back (Open questions 4).

**`restore(_ imported:)`** — `RescueCopies.write(library)` FIRST (a throw aborts the restore; an empty library writes nothing and the restore goes on), then `commit(Importer.restoring(imported, over: library))` — the file's library with this device's check-ins laid over it (0.62) — then `reload()` (which also re-installs the live "When" steps and conditions from what is now stored). The restore is a diff like any change: every record not in the file is DELETED, so through iCloud a restore replaces the library on BOTH devices.

**Tests.** LibraryModel itself is exercised by every UI test (in a MemoryStore). Its moves, since 0.62, by `StoreTests` (PackingLibrary): `testLoadingSettlesTwinsSoBothDevicesHoldTheSame`, `testOnlyTheDifferenceIsStoredAndNothingWhenNothingChanged`, `testAStoreThatRefusesKeepsWhatItHeld`, `testRecordsTheLibraryCannotShowAreLeftInTheStore`, `testTheImportDoorRefusesWhatItMust` (each refusal and its words; a file whose `items` disagree with its `lists` is refused whole), `testAnEmptyDeviceThatHasCheckedInStillTakesItsBackup`, `testLookingAtAFileLeavesTheLiveWhenStepsAndConditionsAlone`, `testARestoreKeepsTheDevicesCheckInsAndNothingElseOfWhatWasThere`; UI `testSyncNowOnAnEmptyDeviceKeepsTheTwoDoors`. `RestoreTests.testARestoreLeavesExactlyWhatTheFileHeldAndNothingOfWhatWasThere` re-creates its diff-apply path in the model.

**Traps and history.** 🪤 Every change rebuilds ALL records (`next.records()`), including base64-decoding every photo, and diffs them — the cost of one tick grows with the library and its photos (written down in StoreSession.swift since 0.62 and at `LibraryModel.commit` since 0.62; left as it is — Open questions 15). 🪤 Every iCloud notification reloads the whole store on the main thread, once per notification (written down at `LibraryModel.init`, 0.62). 🪤 `.failed` is sticky until a later reload or commit succeeds.

---

## 6. Launch modes, test isolation, time and ids

**`LibraryModel.forThisLaunch()`** decides the store. `AMSPackingApp.testing` = any launch argument starting with `-uiTesting`. Checked in this order (first match wins):

| Argument | Store | Holds |
|---|---|---|
| `-uiTestingEmpty` | MemoryStore | nothing → the first-run screen |
| `-uiTestingChecks` | MemoryStore | `SampleLibrary.checks()`: the sample plus a bag "Carry-on / hand luggage" (`addBag` makes the bag template "Containers" — shown as "Bags" — and a new thing of that name, so 4 templates and 13 things), a Pocket knife (restricted) and Sun cream (liquid, runs out in 25 days) on the base template, the Passport in "Documents & money" running out in 180 days, and one plane trip "Sunny weeks" from day +20 to +34 built from Hiking |
| `-uiTestingOnSite` | MemoryStore | `SampleLibrary.underWay()`: the sample trip moved to yesterday … +2 days; the Passport's note "Keep it dry" |
| `-uiTestingOldPhoto` | MemoryStore | the sample plus photo `left-behind`, created 2026-01-01, shown nowhere — and (0.62) photo `no-date`, with no `createdAt`, shown nowhere |
| `-uiTestingOldConditions` | MemoryStore | `SampleLibrary.oldConditions()` (0.62): the sample with the Goggles' condition stored as the LABEL "Needs replacing" — repaired on load |
| `-uiTestingTwoLibraries` | MemoryStore | `SampleLibrary.doubled()`: every template a second time under new ids (what two libraries meeting on one account look like) |
| `-uiTesting` | MemoryStore | `SampleLibrary.make()` |
| none, Info.plist `PackingUsesICloud` = "YES" | CloudStore(cloud: true) | iCloud (TestFlight and release builds) |
| none, otherwise | CloudStore(cloud: false) | SwiftData on this device only (a plain debug build) |

The sample (`SampleLibrary.make()`, invented, public repo): templates "Common base" (role base: Passport, Phone charger, Toothbrush, Headlamp), "Hiking" (GA: Hiking boots, Rain jacket, Headlamp, Map; section "Lights" holding the Headlamp), "Swim" (WET: Goggles, Swim cap, Towel); 10 things — 7 of them with weights, storage places and owners Kim / Robin (Towel, Goggles and Swim cap are made after the weights and places are applied, so they have none; details in the settings chapter §25) — care (boots overdue, jacket notes), review history, Map condition "retire", Toothbrush consumable, Towel per night; one trip "Weekend in the hills", 30–32 days from the day the tests run, built from Hiking (and the base) — 7 lines (the UI tests read "1/7" after one tick). `SampleLibrary.fileToRestore()`: a different, smaller library as backup bytes (template "Day out", role base, with Water bottle and Sun hat; `exportedAt` 2026-09-22T09:00:00.000Z) — under the tests the Restore button reads this instead of Apple's file window.

CloudStore failing to open → a MemoryStore with `state = .failed("The library could not be opened: <reason>")`.

DEBUG builds only: `-importFile <path>` imports that backup at launch when the library is `.empty` (errors ignored). On the Mac the path must be inside the app's sandbox container.

**Under the tests** (`testing` true), before the model is made: `RescueCopies.clearForTesting()` (deletes this device's rescue copies), and these UserDefaults keys are removed: `ams.table.columns`, `ams.table.sort`, `ams.table.down`, `ams.table.then`, `ams.table.filters`, `ams.care.view`, `ams.view`, `ams.trip.folded`, `ams.template.grouping`, `ams.pick.grouping`, `ams.pick.folded`, `ams.reminders` (`PackingReminders.onKey`), `ams.backup.savedAt` (`SettingsScreen.savedKey`, 0.62). Also: the forecaster is `InventedForecast`; grab-list ticks live in memory only (`GrabStore(persistent: false)`, normally UserDefaults `ams.grab.<id>`); the Mac window is set to 760 × 674 (GitHub's runner size) and the "All your things" window defaults to 760 × 620. Extra test arguments read by `LibraryModel.shared`: `-openGrab <label or title>`, `-openGrabMenu`, `-openNextTrip`; and `-pretendShopTicks` and `-pretendShopDeleted` (ShopReminders; Things spec).

**`Today`** (App/Sources/Store/Today.swift): `Today.local` = today as YYYY-MM-DD in the device's time zone (Gregorian, en_US_POSIX). The model's date helpers default to the UTC date — which in his time zone (UTC+1, UTC+2 in summer) is yesterday until 01:00 (02:00 in summer) — so the app always passes `Today.local`. `Today.date(_:)` / `Today.iso(_:)` convert at local midnight.

**`PackingEnv`** (PackingCore/PackingEnv.swift): `now` (default `Date()`), `makeId` (default `defaultMakeId()`), `collationLocale` (default "en"). `freeze(at: "2026-01-01T00:00:00.000Z", idPrefix: "id-")` fixes the clock and makes ids "id-1", "id-2"…; `reset()` restores all three. Model tests freeze in `setUp` and reset in `tearDown` (and restore `setPhases(DEFAULT_PHASES)` / `setItemConditions(DEFAULT_ITEM_CONDITIONS)`, the global module state). The UI tests do NOT freeze anything: the app runs on the real clock, so sample dates are computed from the day the tests run.

**Tests.** UI: `testAnEmptyDeviceShowsTheTwoDoors` (`-uiTestingEmpty`), `testALibraryThatHasMetAnotherSaysSo` (`-uiTestingTwoLibraries`), `testWorthALookRemovesAPhotoLeftBehind` (`-uiTestingOldPhoto`), `testAConditionStoredTheOldWayIsRepairedOnLoad` (`-uiTestingOldConditions`), the On site tests (`-uiTestingOnSite`), the cabin/checks tests (`-uiTestingChecks`), `testAShortcutOpensAGrabListOrTheNextTrip`, `testTheActionButtonMenuOpensTheChosenGrabList`, `testWhatWasTickedInTheShopIsTickedOnReturn`. Model: `JSSemanticsTests.testIdHasTheJSShapeAndCanBeInjected`, `testTodayYMDAndNowISOGoThroughTheInjectedClock`, `PhasesTests.testNewPhaseTimestampIdUsesTheInjectedClock`.

**Traps and history.** 🪤 The sample trip's dates were once fixed (3–5 Oct 2026); on those days it was under way and "an empty Now" went red — dates are relative now. 🪤 Window restoration on the Mac brought the "All your things" window back in front of the next test (0.58).

---

## 7. iCloud sync — behaviour and the Production facts

**Purpose and origin.** docs/store.md (read it for the reasoning): CloudKit private database, his Apple ID on both devices, no other account, no server. "Proved on his Mac, 2026-09-22": 1,438 records pushed to Development, local store deleted, all pulled back within 10 s.

**How it works.**
- Each change is a SwiftData save of the changed `Record`s; SwiftData's CloudKit mirroring sends them. A change from the other device arrives as a silent push, is imported behind the app's back, and `NSPersistentStoreRemoteChange` makes `LibraryModel` reload everything.
- Conflicts: per record. Two devices ticking different lines both win (different records). Two edits of the same record: the later wins. Twins (same table+key created on both devices) are settled on load (§3, §5).
- The ten rules of docs/store.md apply: never seed; an empty device is not a verdict (two doors, §9); the import happens once; same key → one survivor; stable keys; no `owner`/`realmId`; a restore never quietly overwrites (§11); regenerating keeps lines of deleted templates; backups are visible files.

**What a build needs (project.yml, entitlements, testflight.yml).**
- Info.plist `PackingUsesICloud` = `$(PACKING_USES_ICLOUD)`; "NO" by default, "YES" only in builds signed with `App/Config/AMSPacking-iCloud.entitlements` (`tools/build.sh … icloud`, and the TestFlight workflow). CI builds without iCloud: an ad-hoc signed Mac app carrying iCloud entitlements is refused at launch.
- iCloud entitlements: app sandbox; user-selected read-write files; `network.client`; iCloud container identifiers (the one container); iCloud services CloudKit; `icloud-container-environment` Development; temporary mach-lookup exception for `com.apple.cloudd` (without it the sandbox denies the CloudKit daemon — "Error connecting to CloudKit daemon"); `aps-environment` development; calendars (Reminders).
- TestFlight workflow: rewrites Development → Production and development → production into a ship file, and for the iPhone renames `com.apple.developer.aps-environment` to `aps-environment` (with only the Mac's name the iPhone never got the "something changed" push and fetched only when reopened — his test A.4, 28 Sep 2026; fixed 0.44).
- `UIBackgroundModes: [remote-notification]` (iPhone).
- The CloudKit schema must be deployed to Production (CloudKit Console). 🚨 **3 Oct 2026 lesson**: a schema contains only fields records have USED. The first deployment (22 Sep) came from a Development schema that had never seen a photo, so Production had no `CD_blob` / `CD_blob_ckAsset`. The first bag photo then made every send from that iPhone fail — one refused record fails its whole batch, so trips, lines and to-dos stuck behind it. Both fields were added in Development and deployed. Before a new attribute ships, check that the Production record type has its field(s).

**Tests.** None can run in CI (no iCloud account). Sync is proved on his two devices; the Settings card (§8) and "This device holds" (§13) are the tools for that.

---

## 8. Settings → iCloud sync card (`SyncCard`, `SyncCheck`, `SyncCheckIn`)

(`SyncCheck` lives in PackingLibrary since 0.62 — moved from the app unchanged apart from what is marked 0.62 below — so its reading, its plain words and the card's verdict are held by model tests.)

**Purpose and origin.** His field test, 3 Oct 2026 (0.54 "iCloud sync, made visible"): the iPhone's new trips, templates and lines never reached the Mac, and only the iPhone could say why. The card says when this device last sent and received, what iCloud does not have yet, why a send failed — and "Sync now" checks in so the OTHER device can show it ("a direct test of each road").

**How it is reached and left.** Settings, third block (after "Your choices" and the Remind me to pack card). Always shown, also on an empty device. Nothing to leave.

**What is on screen** (card: padding 14, `Theme.card`, corner 12, 1-pt border `Theme.line` — red `#dc3d43` when stuck; id `sync-card`, contains its children). Top to bottom:
1. Row: "iCloud sync" (18 bold, ink) · spacer · state pill (13 heavy white on a capsule, padding 10×3, id `sync-state`), `SyncCheck.state(usesICloud:check:)`: **"Off"** (muted) when this build does not use iCloud; **"Can’t tell"** (muted, 0.62) when iCloud is on but the store could not be read; **"Stuck"** (red) when iCloud is on and something is not sent or the last attempt failed; **"Working"** (green `#2f9e63`) otherwise.
2. When off: "This copy of the app keeps its library on this device only." (quiet, id `sync-off`).
3. When on and the store could be read:
   - "Sent: <when> · received: <when>" (quiet, `sync-times`).
   - If any records are not in iCloud: "Not in iCloud yet: <words>." (loud, `sync-notsent`), e.g. "Not in iCloud yet: 3 trips, 21 trip lines." — kinds sorted by count, most first; equal counts in `Table` order (0.62; a kind the app does not know after those, A–Z).
   - If there is a problem: "The last send|receive failed <when>: <plain words>." (loud, `sync-problem`).
   When on and the store could NOT be read (0.62): "This device cannot tell right now how the sync is going." (quiet, `sync-unknown`).
4. "The <other> last checked in <when>." or "The <other> has not checked in yet — press Sync now there." (quiet, `sync-other`).
5. "This <device> checked in <when>." or "This <device> has not checked in yet." (quiet, `sync-self`).
6. Row: **"Sync now"** (16 bold white on a green capsule, padding 16, min height 44, id `sync-now`) · "Copy details for Claude" (15 semibold slate text button, id `sync-copy`).
7. When something was said: the message (quiet, `sync-said`).

Card column spacing 8; the header row spacing 8; the button row spacing 10. When iCloud is on but the store file cannot be read (`SyncCheck.read()` nil — file missing, or SQLite refuses it), none of the lines of item 3 show but `sync-unknown`, and the pill says "Can’t tell" (0.62; until then it said a green "Working" over nothing — Open questions 25). Quiet = 15 medium muted; loud = 15 bold red; both wrap. `<device>` is "Mac" on the Mac and "iPhone" elsewhere; `<other>` the opposite. `<when>` (`SyncCard.when` = `SyncCheck.when`): "never" for none; "today HH:mm" for today; otherwise "D Mon HH:mm" (English three-letter month, local time). A check-in time is read from ISO with or without milliseconds (`isoMoment`; anything else reads "never").

**Behaviour.**
- The store is read on appear and 1 s after any library change (debounced), only when iCloud is on: `SyncCheck.read()` opens `Application Support/Library.store` READ-ONLY with SQLite (nil when the file is missing or cannot be opened) and reads Core Data's CloudKit bookkeeping:
  - the newest 300 send (type 2) and receive (type 1) events from `ANSCKEVENT` (succeeded, error domain, error code, end time or start time);
  - `lastSent` / `lastReceived` = the newest successful send / receive;
  - `problem` = the newest failed attempt of either kind, kept only if it is later than the last success of the same kind;
  - `failedSends` = failed sends after the last good send;
  - `notSent` = per `Record.table`, the records with no CloudKit metadata row or marked `ZNEEDSUPLOAD = 1`.
- Kind words: trips "trips", entries "trip lines", items "things", memberships "places on templates", templates "templates", actions "to-dos", photos "photos", meta "notes", phases "“When” steps", shared "choices", kits "kits".
- Plain words (`SyncCheck.plain`) for `CKErrorDomain`: 25 "Your iCloud storage is full"; 9 "This device is not signed in to iCloud"; 3, 4, 6, 7, 23 "iCloud could not be reached — it tries again by itself"; 27 "A change was too big for iCloud"; 14 "A change crossed a newer one"; 26, 28 "The copy in iCloud was reset"; 2 "iCloud refused some of the changes"; 36 "iCloud is busy with this account — it tries again by itself"; other codes "iCloud said no (<code>)". Empty domain: "It stopped without saying why". Any other domain: "Something went wrong (<code>)".
- **Sync now**: `model.change { $0.checkIn(device:) }` writes meta `syncCheck.<device>` = `{at: nowISO(), device}` (one small record that travels like everything else; a later check-in replaces the earlier one; the two devices never overwrite each other). Says "Checked in. On the <other>, Settings shows it within a minute or so if the road is open." After 3 s: `model.reload()` and read the store again. Works with iCloud off too (the check-in is then local only).
- **Copy details for Claude**: puts on the clipboard (`UIPasteboard` / `NSPasteboard`):
  - `Sync details · <device> · <version (build)>`
  - `Last sent: <ISO or never> · last received: <ISO or never>`
  - `Not in iCloud yet: nothing | <words>`
  - `Failed sends since the last good one: N`
  - up to 30 lines `  send|receive ok|FAILED <domain> <code> <ISO>`
  - (when the store could not be read: `Sync details · <device> · <version>` + `No iCloud record on this device.`)
  - `This device holds: <table> <n>, …` (tables A–Z by raw name, only those with records)
  Then says "Copied. Paste it into the chat with Claude."

**Data.** Writes meta `syncCheck.iPhone` / `syncCheck.Mac` (`syncCheckKey`, `Library.checkIn(device:at:)`, `lastCheckIn(device:)` → ISO or nil when absent/empty). Reads the SwiftData store file directly.

**iPhone vs Mac.** Device word and clipboard API only.

**Tests.** Model: `SyncCheckInTests.testACheckInTravelsWithTheLibraryAndKeepsTheDevicesApart`; since 0.62 `SyncCheckTests` — `testTheCardReadsWhatTheStoreKept` (a small SQLite file laid out as Core Data keeps it: last sent/received, the problem, failed sends, "not in iCloud yet" through the metadata join — a metadata row of another entity does not count — Stuck, Copy details' count line), `testAFailurePutRightIsNoProblem`, `testTheCardSaysItCannotTellWhenItCannotRead` (all four pill states), `testNotInICloudYetKeepsItsOrder`, `testThePlainWords`, `testWhenIsSaidInTheDevicesOwnTime`. UI: `testSyncNowChecksInFromThisDevice` (both lines say "has not checked in", Sync now → "checked in today", `sync-said` appears), `testSyncNowOnAnEmptyDeviceKeepsTheTwoDoors` (0.62). Not covered: the card on screen with iCloud on (UI tests never use iCloud); Apple's own table names (the fixture is ours).

**Traps and history.** 🪤 The check reads Core Data's private tables (`ANSCKEVENT`, `ANSCKRECORDMETADATA`, `ZRECORD`, `Z_PRIMARYKEY`) — an OS update can rename them; then the card simply shows "never". 🪤 Until 0.62 ties in "Not in iCloud yet" were in dictionary order and could swap between drawings.

---

## 9. First run — an empty device and the one-time import (`FirstRunView`, `Importer`)

**Purpose and origin.** docs/store.md rules 2–4. A fresh device cannot tell "nothing has arrived yet" from "there is nothing", so it never decides by itself and never plants starter templates (31 Aug 2026: a joining device seeded the starter templates and every template existed twice).

**How it is reached and left.** Home tab while `state == .empty`. It disappears by itself the moment the library holds anything of his (records arriving from iCloud, or an import), because `state` turns `.ready`. A device's check-in — Sync now pressed here, or the other device's arriving — does not count (0.62).

**What is on screen** (centred column, spacing 22, horizontal padding 20, spacers above and below):
1. The Home mark (suitcase), 84 pt, line weight 1.6, blue `#2f6fe0`.
2. "No templates on this device yet" — 26 heavy, ink, centred.
3. Two "doors" (max width 420, spacing 12; each: title 19 heavy, detail 16 medium at 85% opacity, padding 16, corner 14):
   - "My other device has my templates" — card colour with a line border, ink text. Detail: "Leave this open. They arrive through iCloud." (iCloud build) or "This build does not use iCloud." Id `first-run-wait`. NOT a button: there is nothing to press.
   - "This is my first device" — filled blue, white text; detail "Bring in a backup file from the web app." A button (plain style; unlike every other plain button it has no `.focusEffectDisabled()`, so the Mac may draw a focus ring), id `first-run-import`.
4. When an import failed: the reason, 16 semibold red `#dc3d43`, centred, id `first-run-problem`.

**Behaviour.** "This is my first device" opens the system file picker for `.json`. The chosen file is read (security-scoped access) and passed to `LibraryModel.importBackup` (§5) — `Importer.firstImport`, which keeps this device's check-ins. Any error is shown under the doors (including "That is not an AMS Packing backup file.", "This library has already been imported into.", "The import did not come back the same (n rows differ), so nothing was stored."). A picker failure is shown the same way (whether a plain cancel reaches the completion at all is up to the system). On success the screen goes away (state `.ready`).

**The import (`Importer.library(from: BackupFile, now:)`), in order:**
0. (0.62) The live "When" steps and conditions are noted; at the end, whatever happens, they are put back. The file's are installed below only for the reading itself — whoever STORES the result installs them (`installLiveChoices`: the first-run import after its commit, a restore through its reload). Until 0.62 the restore preview left the file's installed after Cancel (Open questions 4).
1. "When" steps: if the file has phases, `setPhases(file.phases)` (installs them GLOBALLY, for the reading) and store them only when customised (`phasesCustomised`).
2. Settings lists from `prefs`: conditions (`conditions`), people (`people`), owners (`owners`), places (`storageLocations`), presets (`presets`) → shared rows, each SKIPPED when empty or exactly the factory list (`isFactoryList`; presets are never "factory").
3. `prefs.grab`: `items` + `meta` (`{gid: {label, icon, tone}}`) → one `grab` row per id (union of both maps' keys, sorted); `sometimes` → meta `grabSometimes`; `own` → meta `grabOwnLists` (as-is); `home` → meta `grabHome`; `off` → meta `grabOff` (0.61; "the ones he sent off Home, which stay off"). `own`, `home` and `off` are written only when non-empty; `home` and `off` keep their string entries unchecked.
4. If `prefs.conditions` is a non-empty array, `setItemConditions` with its entries coerced (GLOBAL, for the reading — step 0; unusable entries dropped there, nothing usable left → the factory four) — even when the list was exactly factory and so not stored.
5. The templates, the things and their places — one of two ways (0.61, "the spec pass, 2026-10-05"):
   - **a. As stored** — a file THIS app wrote since 0.61. When the file holds BOTH an `items` array and a `memberships` array (top-level keys `Library.backupItemsKey` / `backupPlacesKey`, read from `BackupFile.extra`; `Importer.asStored`), `report.asStored = true` and `Importer.take` takes them as they are: every template of `lists` without its rows, coerced (`coerceList`; a repeated template id taken once), so it keeps the file's `createdAt` / `updatedAt`, cover, sections and `extra`; every thing of `items` with a non-empty id (a repeated id taken once; each coerced on decode, `extra` included); every membership of `memberships` with a non-empty id whose template AND thing were taken (a repeated id taken once). "Only what can be shown comes in": a place on a gone template — what Worth a look complains about — is not brought back, because a restore is its cure. `saveTemplate` is NOT called. A thing's own note, qty and item type and each place's own answers come back exactly as they were split on the device, `extra` keys on both included. The rows of `lists` are still there for the web app and for the self-check (step 9), which holds the stored things and places to them.
   - **b. Rebuilt from the rows** — the web app's file, or one of ours from before 0.61 (the rescue copies already on his devices). Each template of `lists` goes through `saveTemplate` — the everyday save, NOT the web app's `buildCatalog` (which drops consumable, packer, review history, "not in use" and kit membership — found 21 Sep 2026; web fixed it in v188). Item ids and membership ids come across from the rows' `_itemId` / `_memId`, so trip lines still point at their things. Then the template's `updatedAt` is set back to the file's when the file has one ("a restore is not an edit"; before 0.61 it became the moment of the import). Then `carryRowExtras`: for each template whose rows (blank names left out) carry any `extra` and whose rebuilt rows are as many, each row that is not a link and has `extra` merges it onto the thing it was saved into (rows and places run in the same order; a key present on both takes the file's value). This is what brings back a bag's `cabin` answer and the keys the web app keeps that this build does not know: `catalogItemFromResolved` copies only the named fields, so without it the self-check said "did not come back the same" and refused the WHOLE file (the copy kept before a restore too) once any bag had a cabin answer. Then (0.62) `settleOwnNotes`: for each rebuilt thing whose own note is empty and whose places ALL carry the same non-empty note, the note goes onto the thing and every place's note becomes "" — the same for qty. Places whose notes differ keep their own. The resolved rows are the same either way (an empty place falls back to the thing), so the self-check still holds.
   - Limitation of **b**: a resolved row cannot say whether its note, qty or item type are the thing's or its place's. A rebuilt thing gets the item type of the first row it is saved from; each membership gets its row's note and qty, and `settleOwnNotes` (0.62) then gives a note or qty that every place of the thing shows back to the thing. What remains: a note or qty that was a place's own on EVERY place of its thing (most often a thing on one template with a note on that place) becomes the thing's — the templates read the same, and the note then also shows on a template the thing is put on later; a thing's own note that one place overrode stays on the other places; a place's own item type can move onto the thing. A membership's own `extra` is not in a row at all and does not come back. Only path **a** keeps everything exactly.
6. `things` (items on no template; missing from backups before web v178): blank names skipped; id = `_itemId` or `id`. When that id already exists it is skipped — and, on path **a**, counted in `report.things` ("it came across with the others"). Otherwise a catalogue item through `catalogItemFromResolved`, given that id, and then (0.61) the entry's own `note` and `qty` and its `extra` merged in (the file's value wins): `catalogItemFromResolved` is written for a row on a template, whose note and qty belong to its place, while a thing on no list was resolved against no place, so they are its own. The self-check below does not look at `things`.
7. Trips are taken whole; a line with an empty or repeated id (within its trip) gets a new id. Actions, kits and photos are taken as they are.
8. The report counts: templates, rows (file rows with a name), items, memberships, things, trips, lines, ticks, actions, kits, photos, phases, sharedRows; and `asStored` says which way step 5 went.
9. **The self-check**: every template is resolved again and compared with the file, row by row (rows with a blank name left out on both sides), by full JSON. Different row count → "template T: X rows in the file, Y after the import"; different row → "template T, row R: <field names>" (T and R count from 1; the differing JSON keys sorted A–Z and joined ", "; positions and field names only, never his words). `notFaithful(n)` reports n = the number of these mismatch lines (a count difference counts once per template), not rows. The "fragile" fields (`consumable`, `packer`, `retired`, `retiredReason`, `reviewed` = stats.packed > 0 or lastReviewed set, `kit`, `keep`) are counted over the file's rows and over the rebuilt rows. `isFaithful` = no mismatches AND equal fragile counts.
10. The marker: meta `import` = `{at: now (ISO), exportedAt: the file's, templates, items, memberships, trips, lines}`.

`import-check <backup.json>` (Core/Sources/import-check) runs the same import on a real file without storing anything and prints the numbers (since 0.61 a line "things as stored" reading "yes: a file this app wrote, taken as it is" or "no: rebuilt from the rows"), the fragile counts ("✗ LOST" where they differ), the record count and drift after a store round trip, the largest record, and per trip how many lines a regenerate would keep (model alone vs the library). Exit 0 = faithful.

**Data.** Writes everything, plus meta `import`.

**iPhone vs Mac.** The system file picker; on the Mac the sandbox needs the user-selected read-write entitlement.

**Tests.** UI: `testAnEmptyDeviceShowsTheTwoDoors` (the import door is there; no template count; the Templates tab has no rows — nothing seeded), `testSyncNowOnAnEmptyDeviceKeepsTheTwoDoors` (0.62). Model: `StoreTests` (0.62) — `testAnEmptyDeviceThatHasCheckedInStillTakesItsBackup`, `testTheImportDoorRefusesWhatItMust`, `testAFileWithOnlyOneOfTheTwoKeysIsRebuiltFromItsRows`, `testLookingAtAFileLeavesTheLiveWhenStepsAndConditionsAlone`, `testAnOlderFileGivesEachThingItsOwnNoteAndAmountBack`; `ImporterTests` — `testTheImportBringsBackEveryRowExactly`, `testWhatTheWebAppsRestoreLosesComesAcross`, `testATripsLinesStillPointAtTheirThings`, `testNothingFactoryMadeIsEverStored`, `testHisOwnTimelineAndListsAreStored`, `testTheImportLeavesItsMark`, `testAKeyThisBuildDoesNotKnowComesAcross` (0.61: an unknown key on a thing on two templates and on a thing on no list comes across from the web app's kind of file; not as stored; the resolved templates are equal), `testAThingOnNoListComesAcross`; the four 0.61 `BackupTests` and the `RestoreTests` test of §10 and §11; core `BackupTests` (decoding). Not covered: the file-picker path (the system window cannot be driven), `-importFile` (a debug-only launch argument).

**Traps and history.** 🪤 23 Sep 2026: an import landed on a device that LOOKED empty while iCloud still held an older copy, and the two libraries merged — the reason for "two doors" and for Worth a look (§14). 🪤 Sandbox: a debug `-importFile` path outside the container is denied (`deny(1) file-read-data`).

---

## 10. The backup file, and Settings → Save a backup

**Purpose and origin.** "A backup with a real Save window" (0.2): a Save window on the Mac, Files on the iPhone; the same JSON the web app writes, so either app reads the other's file during the change-over (rule 10). Moved further down Settings by his test K.2 (1 Oct 2026): "Move down, back up, and restore to the bottom or at least further down."

**The file (`Library.backupFile(exportedAt:)` / `backupData`).** A JSON object, written by `JSONValue.text(pretty: true)` — Foundation's `JSONEncoder` with `.sortedKeys`, `.prettyPrinted`, `.withoutEscapingSlashes`; whole numbers below 2^53 written without ".0", NaN/∞ as null. Keys are SORTED, not in the web app's own order, so the two apps' files are not the same byte for byte; each reads the other's (`backupData`'s comment said "laid out the way the web app lays them out" until 0.62). The object is built, then passed once through `BackupFile(json:)` and back to `.json` before writing:

| Key | Value |
|---|---|
| `app` | "ams-packing-list" |
| `version` | 2 (photos in their own array; 1 had them inline) |
| `exportedAt` | ISO now |
| `lists` | `resolvedTemplates()` — every template WITH its resolved rows, A–Z; each row carries `_itemId`, `_memId`, `_ovContainer`, `_tplContainer`, `_defContainer`, `_ovPhase`, `_defPhase`, and the thing's `extra` |
| `events` | every trip with its lines (full `TripEvent.json`, extra keys included) |
| `actions`, `kits` | as stored |
| `phases` | his own timeline; [] when factory |
| `things` | `thingsOnNoList()` resolved alone (`_memId` ""): every thing with no place in `placesOnTemplates()` — since 0.61 including a thing whose only memberships point at gone templates |
| `photos` | every `{id, data (data URL), createdAt}` |
| `items` (`Library.backupItemsKey`, 0.61) | EVERY thing exactly as stored (`Item.json`, `extra` included, bags included), in library order — read only by this app |
| `memberships` (`Library.backupPlacesKey`, 0.61) | every place on a template as stored (`Membership.json`, `extra` included) — only `placesOnTemplates()`, i.e. those whose template and thing both exist — read only by this app |
| `prefs` | only what he customised (key absent when nothing): `conditions` [{id,label,tone,replace}], `people` [{id,name,color}], `owners` [names A–Z], `storageLocations` [names in his order], `presets` [{name, createdAt, config}], `grab` {`items` {gid: [names]}, `meta` {gid: {label, icon, tone}}, `sometimes` {listId: [names]}, `own` [{id,label,title,tone,icon,items}], `home` [ids], `off` [ids] (0.61)} — `sometimes`, `own`, `home` and `off` each only when non-empty; without factory rows `grab` holds only those of the four that exist |

Why `items` and `memberships` (0.61, "the spec pass, 2026-10-05"): a resolved row shows a place's own note OR the thing's, never which, and does not carry a membership's `extra`; a restore built from rows alone moved every thing's note onto its places and needed the row-`extra` repair to bring a bag's cabin answer back (§9). With the two keys a restore puts back exactly what was here. The web app reads `lists` and `things` and neither of the two (`testTheWebAppStillFindsEverythingWhereItLooks`: `lists` and `things` are exactly what they were; the two keys hold every thing and every place), so its file and ours stay readable by both. The two are not in `BackupFile.knownKeys`: on reading they land in `BackupFile.extra`, and on writing they go out through it. docs/store.md rule 10 says the same.

Not in the file: meta `import`, meta `syncCheck.*`, and memberships whose template or thing is gone (in neither `lists` nor `memberships`). A thing whose only places are on gone templates IS in the file since 0.61 (in `things` and in `items`); a file written before 0.61 left it out, so it is not in the rescue copies made before then.

File name: `Library.backupFileName(on: Today.local)` = `ams-packing-list-backup-YYYY-MM-DD.json` (his local date). Reading (`BackupFile(json:)`) is as forgiving as the web app's restore: lists/events/actions/kits coerced, junk entries dropped; phases coerced at their position, rows without id or label dropped; `things` coerced; photos kept only when `id` and `data` are strings; `prefs` only when an object; unknown top-level keys kept in `extra`. `BackupFile.looksLikeBackup(json)` = it has a `lists` array or an `events` array — ask it first, because decoding never fails.

**What is on screen (the Backup block of Settings).**
1. Heading "BACKUP" (`SectionTitle`: upper-cased, 18 heavy, kerning 0.8, ink, top padding 16), id `backup-heading`.
2. **"Save a backup…"** — full width, min height 52, 18 bold white on slate `#64748b`, corner 12, id `backup-save`.
3. Status line, 15 medium muted, id `backup-status`: "The same file the web app writes, so either app can read it." until something happens; then "Choosing where to save…", "Saved: <file name>", "Not saved.", or the restore messages of §11.
3a. (0.62) Only once a backup has been saved from this device: "Last saved from this <device> <when>." (15 medium muted, id `backup-last`; `Library.lastSavedWords`, `<when>` as on the sync card, §8).
4. **"Restore from a file…"** (§11), id `backup-restore`.
5. "Kept before a restore" (§11).

**Behaviour.** Save sets the status to "Choosing where to save…", builds a `BackupDocument` (content type `.json`) holding `model.library.backupData()` — at that moment, for this save only (0.62; it used to be built on every drawing of Settings) — and presents `.fileExporter` with it and the default name above. Success → "Saved: <last path component>" and (0.62) the moment is kept on THIS device (UserDefaults `ams.backup.savedAt`, ISO; per device, like the web app's — never in the library, so it does not travel); failure (including a cancel) → "Not saved.". Nothing in the library changes. There is no backup reminder (Open questions 17).

**iPhone vs Mac.** Mac: a Save sheet on the window. iPhone: the Files "save to" sheet.

**Tests.** UI: `testSettingsOffersABackup` (`device-count-items` present; `backup-save` exists and sits BELOW `settings-lists`; pressing it shows "Choosing…"; on the Mac a Save sheet/dialog opens, closed with Escape). Model (0.62): `StoreTests.testSettingsSaysWhenTheLibraryCameFromAFileAndWhenItWasLastSaved` (the `backup-last` words). Model: `BackupTests` (PackingLibrary) — `testABackupComesBackAsTheSameLibrary` (ticks, set-aside lines, own phases, places and people survive), `testAFactoryLibraryWritesNoSettingsLists` (no `prefs`, `phases` []), `testTheFileIsWhatTheWebAppWrites` (keys present, file name), `testCountsNameEveryTable`, `testSettingALineAsideLeavesTheCounts`; and, since 0.61, on a richer sample (a bag he said goes in the cabin, one whose NAME says cabin and he said it does not, an unknown key on a thing on two templates, a thing on no list with its own note, qty and unknown key, an unknown key on a trip line, his icon on a template): `testABackupBringsBackExactlyWhatWasThereCabinAnswersIncluded` (faithful, as stored, NO stored record differs apart from `meta`; both cabin answers, the thing's own note stays the thing's and is not pinned onto its places, the trip line's key, the icon), `testTheWebAppStillFindsEverythingWhereItLooks`, `testAnOlderBackupComesBackWithItsCabinAnswersAndUnknownKeys` (the same file without the two keys: faithful, rebuilt, equal resolved templates, both cabin answers, the unknown keys, the thing on no list with its note and qty, equal trips, every template keeps its `updatedAt`), `testAThingWhoseOnlyListIsGoneSurvivesABackup` (a thing whose only template was deleted is in `things`; restored from the as-stored file, an older file and a file with the broken place written into `memberships` by hand, it comes back on no list and Worth a look has nothing to say); `GrabCollectionTests.testAListHeTakesOffHomeStaysOff` (`prefs.grab.off` through a backup); core `BackupTests` (3). Not covered: the Save panel's "Saved:" / "Not saved." and the `backup-last` line appearing (the system panel cannot be driven).

**Traps and history.** 🪤 Until 0.62 the document was built from `backupData()` every time Settings was drawn (the `.fileExporter` argument), not when Save was pressed — a full resolve and pretty-print of the library, photos included, on every redraw.

---

## 11. Restore from a file, and the copies kept before a restore

**Purpose and origin.** 0.3 (23 Sep 2026): "Restore from a backup file; a copy of what was here is kept first, and you can go back to it." He lost data to a restore in the web app (2026-08-16), so: rule 8 — a restore never quietly overwrites; it shows what it will replace, takes a copy first, and is one deliberate act.

**How it is reached and left.** Settings → "Restore from a file…" → the system file picker (`.json`) → the file is read and CHECKED (`inspectBackup`) → only then the `RestoreSheet`. Under `-uiTesting…` the button skips the picker and offers `SampleLibrary.fileToRestore()`. Also from "Kept before a restore" → a row → the same sheet. Leave the sheet with "Cancel" (Escape too, ⌘. on an iPhone keyboard — 0.62), with "Replace everything on this device", or by dismissing the sheet (swipe on iPhone) — the last changes nothing and, since 0.62, says what Cancel says: "Nothing was replaced." (until then it said nothing). The sheet is Settings' one sheet with a destination (spec 06 §1, 0.62).

**What is on screen — the Settings parts.**
- "Restore from a file…" — full width, min height 48, 17 bold slate text on `Theme.card` with a 1-pt line border, corner 12, id `backup-restore`. Pressing it first resets the status line to its default sentence.
- "Kept before a restore" — shown only when this device has rescue copies: heading 15 heavy muted (top padding 10, id `rescue-heading`), then a card with one row per copy, newest first (min height 44, divider): the moment ("22 September, 23:04", 16 medium ink) and "Look at it" (15 bold slate); id `rescue-row-0`, `rescue-row-1`, ….

**What is on screen — `RestoreSheet`** (min frame 420 × 520 on the Mac only — 0.62; until then on the iPhone too, wider than its screen; background `Theme.bg`, id `restore-detail`; header padding 16, then a `KeyboardAwayScroll` column, spacing 10, padding 16 sides / 24 bottom; the column titles 6 pt, the footnote 4 pt and the red button 10 pt further down):
1. Header: "Restore from a file" (22 heavy ink) · "Cancel" (`HeaderButtonStyle`, slate outline: 17 bold — the style's own, 16 until 0.62, when it overrode the 17 bold the caller attaches (spec 06 §20); id `restore-cancel`; Escape presses it — `.keyboardShortcut(.cancelAction)`, 0.62; no key presses Replace).
2. "Everything on this device is replaced by what the file holds." (16 medium ink).
3. Column titles "The file" and "Now" (15 heavy muted, each 70 wide, right-aligned).
4. A card of rows: one per table (in `Table` order) except `meta`, and only tables where the file or the device holds anything. Label (`SettingsScreen.label`, 16 medium ink) · file count (16 bold monospaced digits; RED when lower than the device's, else ink; id `restore-file-<table>`) · device count (16 bold monospaced muted; id `restore-now-<table>`). Row min height 40, divider.
5. Only when the file holds less of something: "This file holds less than this device does — <up to 3 biggest losses, e.g. "things 2 against 10, trips 0 against 1">" + (", and more." when more than 3 tables are lower, else "."). 16 semibold red, id `restore-fewer`.
6. "A copy of what is on this device now is written first, so there is a way back." (15 medium muted).
7. **"Replace everything on this device"** — full width, min height 52, 17 bold white on red `#dc3d43`, corner 12, LAST on the sheet, id `restore-confirm`.

**Behaviour.**
- Picking: unreadable file → status "That file could not be read."; a picker failure (a cancel, where the system reports one) → "Nothing chosen."; not a backup or not faithful → the error text in the status line (no sheet).
- Cancel, Escape, or (0.62) the sheet swiped away → status "Nothing was replaced.".
- Replace → `LibraryModel.restore`: (1) `RescueCopies.write(current library)`; (2) commit the file's library with this device's check-ins laid over it (`Importer.restoring`, 0.62) — deletes everything else, writes the file's records, a new `import` marker included; (3) reload. Status "Restored from the file: <holdsWords>. A copy of what was here is kept on this device." (0.62: `holdsWords` = "1 template, 2 things and 0 trips" — what came in) and the copies list is re-read. An error (e.g. the copy could not be written) → its text in the status line, nothing replaced.
- What a restore KEEPS: nothing of the device's library — not his trips, not his to-dos, not his Settings lists; it is exactly the file (plus the new import marker) and, since 0.62, the devices' check-ins (`syncCheck.*`): they are about the devices, and deleting them told the other device, through iCloud, that it had never checked in. From a file this app wrote since 0.61 that means exactly the records the device held when the file was written, cabin answers, unknown keys and each thing's own note included (§9 path a); from an older file or the web app's, the same resolved templates with the note / item-type split of §9 path b. What lives outside the library is untouched: rescue copies, device settings (UserDefaults), grab-list ticks.
- Through iCloud the deletes and puts reach the other device: a restore replaces the library everywhere.

**Rescue copies (`RescueCopies`, App/Sources/Store/RescueCopies.swift).**
- Folder: `Application Support/AMS Packing/rescue/` on this device only (never synced).
- `write(library, at: nowISO())`: nothing for an empty library (and nothing deleted); file `RescueNames.fileName(at:)` = `before-restore-<ISO with ":" replaced by "-">.json` (e.g. `before-restore-2026-09-22T23-04-11.123Z.json`; world time, so names sort by time) holding `library.backupData(exportedAt:)` — the ordinary backup JSON (since 0.61 with `items` and `memberships`, so it comes back as stored); then keeps the newest `RescueNames.keep` = 3 (by file name, descending — `RescueNames.toRemove`) and deletes the rest.
- A copy written before 0.61 has neither key and is rebuilt from its rows (§9 path b). Until 0.61 such a copy was REFUSED ("did not come back the same") once any bag had a cabin answer — "the way back was shut exactly when it was needed"; it now comes back with its cabin answers and unknown keys.
- `all()`: the `.json` files, newest first. `read(url)`: the bytes, read through the same checks as any backup file (an unreadable copy is offered as empty data and refused as "not a backup").
- `when(url)` = `RescueNames.when(fileName:)`: "<day> <Month>, <HH>:<MM>" from the name, in THIS DEVICE'S time zone (0.62; until then the world time of the name was shown as it was — a copy written at 01:04 on 23 September in summer read "22 September, 23:04"), e.g. "23 September, 01:04" (day not zero-padded, full English month); the name (without `.json`) when it cannot be read.
- `clearForTesting()`: deletes every copy at launch under the UI tests.

**Data.** Reads/writes the whole library; files in Application Support.

**iPhone vs Mac.** File picker differs; the sheet's minimum frame 420 × 520 is the Mac's only (0.62).

**Tests.** UI: `testARestoreShowsWhatTheFileHoldsAndThenReplacesEverything` (device 10 things; no `device-import` line; sheet shows file 2 / now 10 and `restore-fewer`; 0.62: the sheet and its two buttons lie inside the window; Cancel changes nothing; Replace → 2 things and 0 trips, the status "Restored from the file: 1 template, 2 things and 0 trips.", and `device-import` "Brought in from a backup today …"), `testTheCopyKeptBeforeARestoreBringsEverythingBack` (no copy before; after a restore exactly one row; that row's sheet shows 10 things; Replace brings back 10 things and 1 trip). Model: `RestoreTests` — `testARestoreLeavesExactlyWhatTheFileHeldAndNothingOfWhatWasThere`, `testTheFileHoldingLessThanTheDeviceIsVisibleInTheCounts`, `testSomethingThatIsNotABackupIsNotReadAsOne`, `testTheCopyKeptBeforeARestoreBringsBackEverythingCabinAnswersIncluded` (0.61: played as the app plays it — the copy is written, a file replaces everything, the copy is read through the same check and put back — for a copy written now and one as written before 0.61: faithful, the cabin answer, an unknown key on a thing and on a trip line, and NO stored record differs from before apart from `meta`). Model (0.62): `RescueNamesTests.testACopyIsReadOutInHisOwnTime`, `testTheNewestThreeAreKept`; `StoreTests.testARestoreKeepsTheDevicesCheckInsAndNothingElseOfWhatWasThere`. Not covered: the "and more." wording, the picker paths, a failing rescue write.

**Traps and history.** 🪤 The web app once restored a file and quietly kept parts of what was there (his timeline, things on no list) — hence the strict "exactly the file, nothing else" test. 🪤 Until 0.61 the self-check refused every file — the rescue copy too — once a bag had a cabin answer, because the rebuild left each row's `extra` behind; found by the spec pass of 5 Oct 2026, never by a test (the cabin flag was round-tripped through the store only). 🪤 A restore that only ADDS would pass a naive test — the test file holds 2 things where the device holds 10.

---

## 12. Backup reminders and the shrink guard — ported, NOT used by the app

`PackingCore/BackupState.swift` ports the web app's `backupCounts`, `backupShrinks`, `newestChangeAt`, `oldestCreatedAt`, `backupSnoozeDays` and `backupState` (#13). The native app calls none of them (only the parity tool and the tests do): there is no backup reminder and no shrink warning in the app. Since 0.62 Settings says when a backup was last saved from this device (`backup-last`, §10) — its own stamp, not `backupState`. A rebuild that wants the web app's behaviour has the rules here:
- `backupCounts`: unique catalogue items (via `buildCatalog`, merged by name), templates, events, actions; a raw payload that would throw in JS counts items 0. `things` are not counted.
- `backupShrinks(prev, next)`: false when prev has 0 items; true when next has 0; else next < half of prev.
- `backupState(lastBackupAt, changedAt, firstUseAt, hasData, now)`: no data → level "ok", days nil. Unsaved = never backed up, or no change stamp, or last backup < newest change (ISO text compare; same-day edits count as unsaved). Days since the backup (or first use, or the change, or today). Saved → "ok". Unsaved: ≥ 45 days "urgent", ≥ 14 "due", else "ok". Snooze: 1 day when urgent, else 7.

**Tests.** `BackupStateTests` (15 tests, e.g. `testBackupStateEscalatesAmberThenRedOnceThereAreUnsavedChanges`, `testBackupStateNeverBackedUpEscalatesFromFirstUse`, `testBackupShrinksFlagsAReplaceThatLosesMoreThanHalfTheCatalog`).

---

## 13. Settings → This device holds

**Purpose and origin.** docs/store.md: "a Settings screen that shows what this device holds, table by table, so two devices can be compared by eye — the web app's 'this device has everything' check." Both times this library went wrong, "nothing on screen said so and the counts alone knew".

**What is on screen** (last block of Settings): title "This device holds" (15 heavy muted, top padding 14), then a card: one row per `Table`, always all eleven, in this order and with these labels — Things (`items`), Places on templates (`memberships`), Templates, Trips, Trip lines (`entries`), To-dos (`actions`), Groups of things (`kits`; "Kits" until 0.62 — in his words a kit is all his things, spec 06 §10), Own "When" steps (`phases`), Choices (`shared`), Photos, Notes about the library (`meta`). Label 16 medium ink; count 16 bold monospaced muted, id `device-count-<table raw value>`; min height 40; divider. Footer row: "Synced through iCloud" or "On this device only" (15 semibold muted) · the app version "0.61 (NN)" (`AppInfo.version` = `CFBundleShortVersionString (CFBundleVersion)`).

Under the card (0.62), only for a library that came from a backup file: "Brought in from a backup <when> (the file was saved <when>)." (15 medium muted, id `device-import`; `Library.broughtInWords`, from meta `import`'s `at` and `exportedAt`, `<when>` as on the sync card; the part in brackets only when the file had a readable `exportedAt`). The marker travels with the library, so both devices say it.

**Behaviour.** `Library.counts` = the number of records `records()` would write per table — i.e. what the in-memory library holds (Own "When" steps is 0 while the timeline is factory; Choices counts only authored rows). Since 0.62 counted WITHOUT building the records (which decoded every photo on every redraw): ids/keys that are not empty, every trip line. It does NOT read the store: records the app cannot see (orphan lines, unknown tables, unparsable records) are not counted.

**Tests.** UI: `testSettingsOffersABackup` (`device-count-items` exists), the restore tests (counts 10 → 2 → 10, trips 1/0; `device-import`), `testATripIsDeletedOnlyAfterAsking` and `testWorthALookRemovesAPhotoLeftBehind` (`device-count-photos` = "0"). Model: `BackupTests.testCountsNameEveryTable`, `StoreTests.testCountsAreWhatTheRecordsWouldBeWithoutWritingThem`, `testSettingsSaysWhenTheLibraryCameFromAFileAndWhenItWasLastSaved` (0.62).

---

## 14. Settings → Worth a look (`Library.worries()`, `repair(_:)`) — and the device audit

**Purpose and origin.** 0.5 (23 Sep 2026): "Settings says when something in the library looks wrong." The answer has been "no" twice: 31 Aug 2026 (every template twice after a joining device seeded starters) and 23 Sep 2026 (two libraries merged after an import). 0.59 (4 Oct 2026, his ask: "the practice trip was gone, its bag photo stayed behind") added the first one-press repair; 0.60 (Release line: "Worth a look offers to remove a photo only when it can tell the photo is more than a day old") stopped offering a photo whose age cannot be read.

**How it is reached and left.** Settings, between "Open a shared link" and the Backup block — shown ONLY when there is at least one worry.

**What is on screen** (card: padding 12, top padding 14, `Theme.card`, corner 12, border red at 50% opacity):
1. "Worth a look" — 15 heavy red, id `health-heading`.
2. For each worry n (0, 1, …): its sentence (16 medium ink, wraps, id `health-n`); when it has a repair, a red capsule button with white 16 bold text (padding 16, min height 40, id `health-n-fix`); when it names things, up to six names joined " · " plus " …" when there are more (14 semibold muted, id `health-n-names`).
3. "A backup and then "Restore from a file…" puts a library back exactly as the file has it." (14 medium muted).

**The worries, in this order (exact words).**
1. Template names that appear more than once (compared by `normName`; blank names ignored; listed in first-seen spelling): "1 template name appears twice. Two libraries may have met on this account." / "N template names appear twice. Two libraries may have met on this account." Names = those template names. No repair.
2. Memberships whose template does not exist: "1 thing sits on a template that no longer exists." / "N things sit on a template that no longer exists." ("on a list" until 0.62 — spec 06, item 22). No names, no repair. Its cure is the footer's backup and Restore: since 0.61 the file leaves such memberships out and keeps their things (in `things` and in `items`), so after the restore the thing is on no list and the worry is gone (`BackupTests.testAThingWhoseOnlyListIsGoneSurvivesABackup`). Before 0.61 the same cure lost a thing whose only places were orphaned.
3. Unused photos (`unusedPhotos(now:)`, TripEdits.swift: not shown by any thing, trip line or packed bag — `photoInUse`'s rule, gathered once for all photos by `photoIdsInUse()` since 0.62 — AND created strictly more than 86 400 s before `now` — a photo may arrive from the other device a little before the trip that shows it). `createdAt` is read by `isoMoment` (ISO 8601 with or without fractional seconds); a photo whose `createdAt` is empty or cannot be read is KEPT and never offered ("a date that cannot be read is no proof of age" — changed in 0.60; before, it counted as old and was offered at once): "1 photo is no longer shown anywhere — left behind by a deleted trip." / "N photos are no longer shown anywhere — left behind by a deleted trip." Repair `unusedPhotos` (`Library.FIX_UNUSED_PHOTOS`), button "Remove it" / "Remove them".
4. (0.62) Unused photos whose age cannot be read (`undatedUnusedPhotos()`: not in `photoIdsInUse()` and `isoMoment(createdAt)` nil — never offered by worry 3): "1 photo with no date is no longer shown anywhere." / "N photos with no date are no longer shown anywhere." Repair `undatedPhotos` (`Library.FIX_UNDATED_PHOTOS` → `removeUndatedUnusedPhotos()`), button "Remove it" / "Remove them" — only his press removes them. Until 0.62 such a photo stayed in the library, in iCloud and in every backup for ever, and nothing on screen mentioned it (Open questions 26). This app dates every photo it makes, so one without a date is old, not on its way from the other device.
A thing on no list and in no trip is deliberately NOT a worry.

**Behaviour.** The repair button runs `model.change { $0.repair(fix) }` → `removeUnusedPhotos()` with the current clock, or `removeUndatedUnusedPhotos()` (returns how many went; an unknown `fix` returns 0 and changes nothing); the worry disappears with the next draw. The card is a VStack (spacing 6); worries are listed by position, so their ids shift when an earlier worry goes away. `deleteTrip(id:)` itself removes the trip's photos (its lines' and its bags') unless something else still shows them (0.59).

**The device audit (`PackingCore/DeviceAudit.swift`) — ported, NOT used.** `referencedListValues`, `auditList`, `auditDeviceLists` (levels off/ok/suspect/broken; `AUDIT_STRAY_TOLERANCE` = 2; broken = a list missing at least as many entries as it lists — the shape of a web-app table that never downloaded: 2 places listed, 15 unaccounted for). The native app shows none of it; only the parity tool and `DeviceAuditTests` (12) use it.

**Tests.** Model: `HealthTests` — `testASoundLibraryHasNothingToSay`, `testTwoLibrariesThatMetAreNoticed`, `testTheNameIsJudgedTheWayTheAppJudgesNames`, `testAThingOnAListThatIsGoneIsNoticed`, `testThingsOnNoListAreNotAWorry`; `PhotoTidyTests` — `testDeletingATripTakesItsBagPhotosAlong`, `testAPhotoSomethingElseStillShowsStays`, `testWorthALookOffersToRemoveAPhotoLeftBehind` (clock frozen at 2026-10-04T10:00Z: a photo from 2 Oct is offered, one from 30 minutes ago and one with `createdAt` "" are not; the exact sentence; "Remove it"; the repair returns 1 and leaves the two); `OnTheTripTests` (photos still shown elsewhere are kept); `UndatedPhotoTests.testAPhotoWithNoDateIsNamedOnItsOwnAndGoesOnlyWhenAsked` (0.62: a photo still shown is no worry; "2 photos with no date…", "Remove them" takes exactly those two; the singular). UI: `testALibraryThatHasMetAnotherSaysSo` (sound sample: no heading; `-uiTestingTwoLibraries`: heading, "twice", names), `testWorthALookRemovesAPhotoLeftBehind` (`-uiTestingOldPhoto`: "1 photo is no longer shown anywhere…" and, 0.62, "1 photo with no date…" under it; Remove it → the old one goes, photos 1, the undated worry moves up; Remove it → heading gone, photos 0), `testATripIsDeletedOnlyAfterAsking` (a bag photo leaves with its trip). Not covered: plural wordings, the six-name cap, worry 2 in the UI.

---

## 15. Save as Excel — a trip as a spreadsheet (`Library.tripWorkbook`, `Xlsx`, `TripExcelButton`)

**Purpose and origin.** The web app's "Excel" button and its `js/xlsx.js`, ported (0.35, 27 Sep 2026): "the trip as a spreadsheet by When and bag, with how many and what is packed; the header row stays in place". Columns From where and Into added by his test D.23 (0.40, 28 Sep); Category added by their field test, 3 Oct 2026: "Please add a category to the Excel export as a new column." No library, nothing online.

**How it is reached and left.** A trip's screen, near the end (after "tick all", before Delete): "Save as Excel" sits on ONE line with "Share", Share to its right (his test D.22).

**What is on screen.** `WideButtonLabel` "Save as Excel" in green with a drawn sheet mark (`SheetMark`), id `trip-excel`. Below it, only once something happened, a status line (14 medium muted, id `trip-excel-status`): "Choosing where to save…", "Saved: <file name>", "Not saved.".

**Behaviour.** Press → `tripWorkbook(tripId:)` (nil for an unknown trip: nothing happens) → `.fileExporter` with an `XlsxDocument` (type `org.openxmlformats.spreadsheetml.sheet`) and the default file name.
- File name `workbookFileName(trip.name)`: each of `/ : \ ? * " < > |` becomes a space, trimmed, "Trip" when empty, + " packing list.xlsx" (e.g. "Weekend in the hills packing list.xlsx").
- One sheet, named after the trip (`Xlsx.sheetName`: each of `[ ] : * ? / \` → space, trimmed, first 31 Swift Characters — grapheme clusters, so a cut never splits an emoji, but a name with emoji can exceed Excel's 31 UTF-16 units — "Trip" when empty).
- Rows in the trip screen's order: by When (`entriesByPhase`: the live phases in timeline order, empty steps left out, then unknown phase ids in first-seen order, labelled with the raw id via `phaseOrFallback`), inside each by bag (`groupByContainer`: the built-in bag order of `CONTAINERS` first, any other name after them by `jsLocaleCompare`; an empty bag is grouped as "Other" — but its Into cell stays empty), inside each bag in the trip's line order. Every line, set-aside lines and reminders included.
- Columns (header row 1; width):

| Col | Header | Width | Value |
|---|---|---|---|
| A | When | 22 | the phase label |
| B | From where | 20 | the line's storage place, trimmed |
| C | Into | 20 | the line's bag, as written |
| D | Thing | 30 | the line's name |
| E | Category | 20 | its category, trimmed — "Comfort & misc" when blank |
| F | How many | 10 | a NUMBER: `effectiveQty(line, qtyNights(trip))` — per-night things count the nights (capped at the trip's laundry nights — `extra.laundryNights` when it is a number 1…60, truncated to a whole number, else 4 — when laundry is on and the trip is longer); a per-night thing on a 0-night trip, and every other line, takes its qty read as a number (`jsParseNumber`: "2.5" is 2.5, "1 pair" is not a number), 1 when not a positive finite number |
| G | Packed | 10 | "set aside" when set aside, else "yes" when ticked, else empty |
| H | Note | 30 | the line's note |

- An empty text or a non-finite number writes no cell. Text cells are inline strings with `xml:space="preserve"`, XML-escaped (`& < > " '`). Whole numbers are written without decimals.
- Styles: body (Calibri 11, wrapped, top-aligned); header bold white Calibri 11 on solid teal `#127A8A`, vertically centred. Row 1 frozen (pane ySplit 1, top-left A2). Default row height 15; column widths custom.
- Package: `[Content_Types].xml`, `_rels/.rels`, `xl/workbook.xml`, `xl/_rels/workbook.xml.rels`, `xl/styles.xml`, `xl/worksheets/sheet1.xml`, zipped with no compression ("store") and the standard CRC-32.

**iPhone vs Mac.** Mac: Save sheet. iPhone: Files.

**Tests.** Model: `WorkbookTests.testTheChecksumIsTheStandardOne` (CRC of "123456789" = CBF43926), `testColumnsAndSheetNamesFollowExcelsRules`, `testATripBecomesASoundWorkbook` (unzip tests the archive; parts present; headers in order A–H; frozen; escaping; "set aside"; Socks per night capped at 4 with laundry, 7 without; category default). UI: `testATripIsSavedAsExcel` (button present; Share on the same line and to the right; "Choosing…"; a Save sheet on the Mac). Not covered: unknown phases, an empty bag name, a trip name longer than 31 characters or holding emoji, a per-night thing on a day trip, "Saved:" / "Not saved." (the system panel cannot be driven).

---

## 16. Sharing — links, QR codes, trip files, and opening them

**Purpose and origin.** The web app's share links and QR codes (0.38, 27 Sep 2026, the gap list): a trip, a template or a grab list as a link that opens in the web app (for anyone) and in this app (Settings → Open a shared link); a QR code when the link is short enough; a trip also as a file. The codes are PackingCore's byte-exact port of `encodeTripLink` / `encodeListShare` / `encodeGrabShare` and their decoders, so a link made here opens in the web app and the other way round.

### 16.1 Encoding (PackingCore/ShareEncoding.swift)

- `OrderedJSON`: JSON with keys in the order the web app builds them, written exactly as `JSON.stringify` (no `/` escaping, `\uXXXX` only below U+0020, whole numbers without ".0", NaN/∞ → null, half an emoji written `\ud83d`).
- base64url (`-` `_`, no padding) of the UTF-8 text; `atob` rules on the way in (whitespace ignored, padding optional, anything else → "This code is damaged."); strict UTF-8 on decode.
- `packShare(text)`: the shorter of plain base64url and `"z." + base64url(LZW(text))` — the `z.` form only when it is STRICTLY shorter in UTF-16 units (LZW over the UTF-8 bytes: codes 9 → 16 bits, dictionary up to 65 536 entries, then it stops learning). A plain code always starts "eyJ" (base64 of `{"`), so the two can never be confused. `unpackShare`: trims, drops trailing full stops ("a sentence's full stop is not part of the code"), `z.` → LZW (a leading BOM swallowed, bad UTF-8 → U+FFFD), else plain.
- `shareSafeOwner(v)`: "whose it is" may leave the device only as a name — whitespace collapsed and trimmed; "" when an e-mail-like address appears ANYWHERE in it (checked before the cut); cut to 40 UTF-16 units.
- `sharePayload(in:marker:)`: the code after `#/g/` or `#/l/` inside any text.

### 16.2 What each kind carries

**A trip** (`encodeTripLink`, `buildTripBundle`, TripSharing.swift):
- Link = `SHARE_WEB_BASE` (the web app's public address, a constant in Sharing.swift) + `#/t/` + `packShare(bundle text)`; nil when the fragment is longer than `TRIP_LINK_MAX` = 30 000 characters ("share it as a file instead").
- Bundle `{app: "ams-packing-list", kind: "trip", version: 1, exportedAt, event}`. The event: every trip key (extra keys included — laundryNights, weighed, bagPhotos travel; photos themselves do not), `owner`/`realmId` removed. Each line slimmed: dropped `id`, `sourceListId`, `sourceItemId`, `stats`, `checked`, `used`, `custom`, `owner`, `realmId`; dropped every "defaulty" value ('', false, 0, null, []); `itemType` "item" dropped; `sub` as plain names; `ownedBy` only through `shareSafeOwner`. Kept when set: `skipped`, `_edited`, `keep`, the resolve parts, extra keys (way-home marks, bought on site…), photo ids.
- File (`Library.shareFile`): "<name> trip.json" (name cleaned as for the Excel file), the bundle pretty-printed.
- Reading (`parseTripBundle`): must parse, have `kind` "trip" and a truthy `event`, and every line must be an object — else "This does not look like a shared AMS trip.". Incoming lines lose `owner`/`realmId`, keep `ownedBy` only as a name (an old `owner` that is a name is adopted), and sub-items taken apart by old web versions are put back together. The trip gets a NEW id, status "active", no review date, createdAt/updatedAt now; every line a new id, unticked, `used` cleared. Everything else arrives as the sender had it: set-aside marks (`skipped`), `_edited`, notes, the lines' extra keys (way-home ticks `packedHome`, `usedUp`, `homeNote`, `boughtThere`), and the trip's extra keys (`laundryNights`, the sender's scale readings `weighed`, and `bagPhotos` ids that point at photos this device does not have). The lines have no `sourceListId`, `sourceItemId` or `custom` (all dropped by the sender), and `activities` still names the SENDER's template ids.

**A template** (`encodeListShare`, ListSharing.swift):
- Link = `SHARE_WEB_BASE` + `#/l/` + code. Errors (link then nil): "There is no template to share.", "This template has nothing on it to share." (no row with a name).
- Code JSON, short keys in this order: `k` "tpl", `v` 1, `n` name (≤60), `x` items, then only when set `i` emoji (≤4 units), `c` colour (≤9), `g` group, `r` role, `tp` transport, `d` default bag (≤60), `s` section names (≤40). The first 400 rows are taken, THEN rows without a name are dropped; each item: `n` name (≤60), `f` flag bits (shortList 1, charging 2, liquid 4, restricted 8, perNight 16, consumable 32), `w` original wording — the `swedish` field (≤60), `q` qty (≤20), `c` category, `p` phase, `b` bag, `o` note (≤200), `y` charge type, `e` section NAME (≤40), `k` kit (≤40), `s` storage (≤60), `a` packer (≤40), `u` owner name (`shareSafeOwner`), `t` 1 for a reminder, `g` weight rounded (when >0), `se`/`cx`/`tr`/`ca`/`we` (each ≤40), `sb` sub-items (≤60). Photos, care records, history, ids and prices do NOT travel ("they describe the physical thing standing in this home, not the recipe") — but where it is kept at home (`s`), who packs it (`a`) and whose it is (`u`) do. All text limits are UTF-16 units after collapsing white space and trimming; `c`/`p`/`b`/`y` are not cut. The template-level `i` and `c` are cut without trimming.
- Reading (`decodeListShare`): a bare code, a whole link or a message containing one; not a template → "This is not an AMS Packing template link or code."; no named item → "The shared template is empty.".
- `listFromShare`: fresh ids (sections, items, list); sections rebuilt and items pointed at them by name (case-insensitive); role "loose" or "container" becomes "" (the two system bins never arrive as themselves); never built-in; empty name → "Shared template".

**A grab list** (`encodeGrabShare`, GrabSharing.swift):
- Link = `SHARE_WEB_BASE` + `#/g/` + code. Code `{k: "grab", v: 1, n: name (≤14), x: items, i: icon, c: tone}` (icon/tone only when set). Items: strings only, trimmed and collapsed, ≤60 each, blanks and case-insensitive repeats dropped, at most 100. No items → "This list has nothing on it to share." (link nil).
- Reading: not a grab list → "This is not an AMS Packing grab-list link or code."; no items → "The shared list is empty.".

`Library.readShared(text)` (trimmed; "" → nil) tries, in the web app's order: grab list, template, then trip (the code after `#/t/` when present, else the whole text). Anything else → nil.

### 16.3 The Share button and the Share screen (App/Sources/Screens/Share.swift)

**Where.** Trip: wide green "Share" button with a drawn share mark beside Save as Excel (`trip-share`). Template detail header: outlined "Share" in violet with the mark (`template-share`; shown on every template, the base and the bag list included). Grab list header: the mark only, in the list's colour, hidden while editing (`grab-share`). All have the accessibility label "Share" and own their sheet (`ShareDoor`). Pressing makes the `ShareOffer` (title "Share “<name>”" — for a grab list its label —, the link built at that moment, and for a trip the file) and opens the sheet.

**What is on screen** (id `share-screen`; on the Mac min 480 × 560):
1. Header: the title (20 heavy ink, one line) · "Done" (`HeaderButtonStyle`, filled green, 17 bold white — the style's own since 0.62 (16 until then, overriding the caller's 17 bold); id `share-done`).
2. With a link:
   - The QR code (CoreImage, correction level "L", scaled ×8, at most 260 wide, on a white rounded card, padding 12; a11y label "QR code", id `share-qr`) — or, when the link is too long for a QR code, "Too long for a QR code. Send the link instead." (15 medium muted, `share-qr-toolong`).
   - The link itself (13 monospaced muted, up to 3 lines, truncated in the middle, selectable, `share-link`).
   - "Send…" (system share sheet for the URL — a `ShareLink`, shown only when the link parses as a `URL`; green filled, 17 bold white, min height 48, `share-send`) · "Copy link" (outlined green 1.4 pt; becomes "Copied" for as long as the sheet is open, accessibility value "copied"; `share-copy`). Row spacing 10, each half full width.
3. Without a link: with a file to offer (a trip), "This is too big for a link. Share it as a file instead." (15 medium muted, `share-toolong`); with no file either (an empty template or grab list), "There is nothing on it to share yet." (15 medium muted, `share-empty`; 0.62).
4. With a file (trips): "Share as a file" (outlined green, system share sheet for the file written to the temporary folder on appear, `share-file`).
5. "The link opens in the web app, and in this app under Settings → Open a shared link." (14 muted).

### 16.4 Settings → Open a shared link (`OpenSharedDoor`, `OpenSharedScreen`)

**Where.** Settings, after the guide doors: a card "Open a shared link" (18 bold ink) with "A trip, template or grab list someone shared" (14 muted, one line) and a chevron; min height 60; id `settings-openshared`. Opens a sheet (id `shared-screen`; on the Mac min 480 × 520). Leave with "Done" (filled slate header button, `shared-done`) or by dismissing the sheet.

**What is on screen** (header: "Open a shared link", 20 heavy ink, · Done; then a scroll column, spacing 12):
1. "A trip, a template or a grab list someone shared, from the web app or this one." (15 muted).
2. A text field "Paste the link or code" (1–4 lines, 15 monospaced, card with line border, `shared-input`).
3. "Paste and open" (slate filled, 16 bold white, min height 46, `shared-paste`: replaces the field with the clipboard and opens it) · "Open" (outlined slate, `shared-open`).
4. When an attempt found nothing: "This is not an AMS Packing link or code." (15 bold red, `shared-bad`).
5. When something was found — a preview card (`shared-preview`): the kind upper-cased ("A TRIP", "A TEMPLATE", "A GRAB LIST"; 12 heavy, kerning 0.6, muted, `shared-kind`), the name (18 bold ink, `shared-name`; a trip without a name shows "Untitled trip"), "1 thing" / "<N> things" (15 medium muted, `shared-count`; a trip counts all its lines — "1 things" until 0.62). Then:
   - Trip: "Add this trip" (green filled, 17 bold, min height 48, `shared-add`) → `importTrip` (the sender's own marks left out — `Library.justTheList` —, arrives Quick so Trip settings keeps its list as it came, appended, `updatedAt` now; 0.62, see the trips spec) → "Added. It is under Trips, nothing ticked."
   - Template: the kind says "A TEMPLATE", "AN ALWAYS-PACKED TEMPLATE" or "A TRANSPORT TEMPLATE". When he has a template of that name (the bag list aside), "This one needs a name of its own" with a field (`shared-new-name`) holding a free name ("<name> 2"). "Add as a new template" (`shared-add`) → `importTemplate(shared, named:)` → "Added. It is under Templates. Things you already had keep your details." (for an always-packed or transport one it says so: "…, Always packed: every new trip packs it. …"); a blank or taken name → `shared-add-needs` says what is missing (spec 04 §19). When he has an ordinary template (role "") of the same name (`templateNamed`, by `normName`): "Replace your <name> instead" (15 bold violet, `shared-replace`) → a confirm row "Replace your <name>?" with "Keep mine" (`shared-replace-no`) and "Replace" (red capsule, `shared-replace-yes`), and under it (0.62) what Replace does (15 medium muted, wraps, `shared-replace-says`; `replaceWords`): "2 things come in and 1 thing leaves it." (either part only when not 0; "It keeps the same things, in their order." when both are) + " Your icon, sections, bags and answers on the things you had stay yours." → `replaceTemplate(id:with:)` (0.62; was `importTemplate(shared, replacing: id)`) (his template keeps its role, activity area and transport — spec 04 §19) → "Replaced your <name>. Trips that use it keep working."
   - Grab list: "Add it to your grab lists" (`shared-add`) → `importGrab` → "Added — it is on Home, in a free place." when Home (8 places) had room, else "Added — it waits in Grab Lists, as Home is full. Put it on Home when you want it there."
6. The result (15 bold green, `shared-result`). After an add the preview, the "tried" flag and the field are cleared.

Every Open / Paste and open runs `Library.readShared(text)` afresh, clears the result line and closes an open Replace question; an empty or blank field counts as "found nothing" and shows `shared-bad`. Nothing is stored until an Add / Replace button is pressed (each one `model.change`).

**How opening merges.**
- A trip is always ADDED as a new trip (`importTrip`: appended, `updatedAt` now; opening the same link twice adds it twice). Its lines carry no `sourceListId`/`sourceItemId`/`custom` (see Open questions 11).
- A template: each row whose name matches one of his things (`normName`; the first thing of that name) is LINKED to that thing (`_itemId`, `_link`): his weight, bag, brand, notes, photos and care stay his; the link carries only the name, so `applyIntrinsic` writes only the name — which means his thing takes the SENDER's spelling of its name ("towel" renames his "Towel"); his own When applies on the new template, and his own bag too unless the share carries a template default bag (`d`), which then wins as for any template (the membership's bag and When exceptions are written ""). The sender's per-template answers (conditions, kit, qty, note, section, item type) come along on the membership. Rows new to him become new things with the sender's details (the sender's bag and When become the new thing's own defaults). Replace (`replaceTemplate`, 0.62) takes the sender's THINGS — which are on the template and in which order — and keeps what is his: the template record stays exactly his (id, `createdAt`, name, cover emoji/colour, group, role, transport, default bag, his sections, the icon he picked in `extra.iconKey`, every other `extra` key; `updatedAt` = now), plus any of the sender's sections that a NEW thing sits in and he has no section of that name for (matched by `normName`; a new thing in a section he has by name goes into his). A thing that was already on it keeps its membership — every answer (conditions, bag/When exceptions, qty, note, section, kit, item type, `extra`) — matched by membership id first, then by thing; only its place in the order is the sender's. A thing new to it comes with the sender's answers. Memberships of things not in the share are removed, the things stay. Until 0.62 Replace overwrote all of it — the template's look, sections, bag and icon, and every answer on every row — while the question said only "Replace your <name>?" (Open questions 23). `replacePreview(id:with:)` counts, by `normName` (each of his rows matched once), the shared rows new to it (`comeIn`) and his rows not in the share (`leave`).
- A grab list becomes one of HIS OWN grab lists (`addGrabList` → meta `grabOwnLists`, id `own-` + `PackingEnv.makeId()` since 0.62 — `own-<ms since 1970>-<random 100…999>` before), label = the shared name or "Shared", title = the label, tone = the shared tone or "blue", icon as shared, items trimmed and blanks dropped; Home takes it only when a place is free (the result line asks `homeGrabLists()` afterwards); being new — in neither `grabHome` nor `grabOff` — it takes any free place, one he freed with Off Home included.

**Tests.** Model: `SharingTests` — `testATripTravelsAsALink` (link prefix, read back from inside a message, nothing ticked, new id, the original keeps its tick, file name "<name> trip.json" readable by `parseTripBundle`), `testATemplateArrivesWithoutTouchingHisThings` (link `#/l/`, his Towel keeps weight and bag, Fins new with the sender's weight, Replace keeps the id), `ReplaceTemplateTests` (0.62: `testReplaceTakesTheirThingsAndKeepsWhatIsHis` — his cover, group, role, bag, icon, sections; the sender's things in the sender's order; his headlamp's membership unchanged but its order; a new thing in his "Lights" by name; "Water" added; `testTheQuestionSaysWhatReplaceDoes`), `testAGrabListWaitsInGrabLists` (Home full → waits; rubbish and blanks read as nothing); `ShareEncodingTests` (20), `TripSharingTests` (17), `ListSharingTests` (18), `GrabSharingTests` (8) — including byte-for-byte equality with web-app fixtures (`ShareReferenceFixtures`). UI: `testATripIsSharedAndOpenedAgain` (link starts with the web address + `#/t/`, Send present, Copy → "copied", Paste and open → "A TRIP" with the trip's name, Add → "Added…", a second trip row), `testATemplateAndAGrabListAreSharedAndOpenedAgain` (template link has a QR code; "hello there" refused out loud; "A TEMPLATE" "Hiking" with Replace offered; Add → template count changes; grab list → "on Home" and a 7th Home button), `testReplacingATemplateSaysWhatItKeeps` (0.62: no question before Replace is pressed; then "It keeps the same things…" "…stay yours"; Replace → "Replaced…", the template count unchanged).
Not covered: the "too big for a link" path, "Too long for a QR code", Share as a file in the UI, adding the same thing twice, a linked row renaming his thing, a shared trip's lines after a Trip settings Save.

**Traps and history.** 🪤 v186 (web): every shared trip carried the sender's sign-in address twice (`owner`, `realmId`) and every shared template carried it on every item — both ends now refuse them. 🪤 A sub-item is a name; old versions took it apart into `{"0":"a","1":"b"}` and the receiver showed "[object Object]" — read back together here. 🪤 Half an emoji (a name cut by `slice`) is read, not refused (`JSONValue.parse` parks lone surrogates).

---

## 17. Comparing and normalising text, dates and numbers (`JSSemantics.swift`)

These helpers decide what counts as "the same" everywhere in this area; a rewrite must give the same answers.

- `normName(s)` = JS-trim, lower-case (Swift `lowercased()`), collapse every run of JS whitespace to one space. Used for: thing names (one thing per name), template names (Worth a look, Replace), shared-row keys, bag names, section names, kit membership.
- `jsTrim` / `jsIsWhitespace`: the JS whitespace set (includes U+FEFF and U+00A0, NOT U+0085).
- `jsSlice(s, a, b)` and `jsLength`: count UTF-16 units; a cut inside an emoji drops the broken half.
- `jsLocaleCompare(a, b, sensitivity)`: Foundation compare in `PackingEnv.collationLocale` ("en"); `.base` ignores case and accents; ties at the default strength broken so a plain ASCII character sorts before its compatibility variant. Measured equal to Node's `en-US` on 795 664 pairs of his real strings (letters such as å ä ö included).
- `jsStringLess`: plain UTF-16 order (dates, ranks, ISO stamps).
- `stableSorted`: every sort is stable (JS `Array.sort` is).
- `isYMD`: exactly `DDDD-DD-DD` (no calendar check). `JSDay`: the one date reader (V8 rules: a day the month lacks rolls over). `jsISOString`: UTC with milliseconds, no Calendar.
- `jsRound` (a half rounds up), `jsNumberToString` (JS number printing), `jsParseNumber` (`Number(str)`: '' → 0, junk → NaN).
- `isHexColor`: `#` + 3–8 hex digits. `jsSlug`: a–z0–9 runs joined by "-", ≤24.

**Tests.** `JSSemanticsTests` (20), e.g. `testNormNameTrimsLowercasesAndCollapses`, `testJsLocaleCompareMatchesNode`, `testJsSliceCountsUTF16UnitsAndTakesNegativeIndices`, `testJSONValueParseReadsALoneSurrogateEscape`; `SharedRowsTests.testNameSortingMatchesNodeOnSwedishLetters`.

---

## 18. The Settings screen, top to bottom (for orientation)

`SettingsScreen` (a keyboard-dismissing scroll view, horizontal padding 16, spacing 14): (1) "Your choices" door (`settings-lists`, another spec); (2) Remind me to pack card (another spec); (3) iCloud sync card (§8); (4) What's new / How it works doors (`GuideDoors`, another spec); (5) Open a shared link door (§16.4); (6) Worth a look, only when needed (§14); (7) BACKUP: Save a backup…, status line, Restore from a file…, Kept before a restore (§10, §11); (8) This device holds (§13). Settings is reachable while the device is empty; it is NOT reachable while the library has failed to open.

---

## Open questions / discrepancies

Found by reading the code; none of these is covered by a test unless said. Tags: **[bug]** the code does something wrong or surprising; **[rule-break]** it breaks one of his standing rules; **[doc]** a comment or document disagrees with the code; **[untested]** behaviour that matters and no test pins; **[idea]** worth deciding before a rewrite. Items marked **Resolved in 0.61** keep their number so that references stay valid; they carry no tag and are not counted as open.

1. **Resolved in 0.61** — ~~A restore or import of a library with a bag marked cabin / not cabin is refused — the rescue copy included.~~ A file this app writes now carries every thing as stored (`items`), and a file without it has each row's `extra` carried onto its thing (`carryRowExtras`); a thing on no list keeps its `extra` from its `things` entry (§9, §10, §11). Pinned by `BackupTests.testABackupBringsBackExactlyWhatWasThereCabinAnswersIncluded`, `testAnOlderBackupComesBackWithItsCabinAnswersAndUnknownKeys`, `ImporterTests.testAKeyThisBuildDoesNotKnowComesAcross` and `RestoreTests.testTheCopyKeptBeforeARestoreBringsBackEverythingCabinAnswersIncluded`.
2. **Resolved in 0.61** — ~~Things can vanish from a backup.~~ `thingsOnNoList()` now counts only places in `placesOnTemplates()`, so a thing whose only memberships are orphaned is written in `things` (and in `items`), and Worth a look's backup-and-restore cure keeps it (§2, §10, §14). Pinned by `BackupTests.testAThingWhoseOnlyListIsGoneSurvivesABackup`. A file written before 0.61 still lacks such a thing.
3. **Resolved in 0.62** — ~~`isEmpty` counts `meta`; one check-in shut the doors and refused the import.~~ A device's check-in (`isDeviceNote`, `syncCheck.*`) no longer counts, and the import and a restore keep the check-ins (§1.1, §5, §9). Pinned by `StoreTests.testAnEmptyDeviceThatHasCheckedInStillTakesItsBackup` and UI `testSyncNowOnAnEmptyDeviceKeepsTheTwoDoors`.
4. **Resolved in 0.62** — ~~Looking at a file changes the live "When" steps and conditions.~~ `Importer.library` puts the live ones back when it has read the file; whoever stores a library installs its own (`installLiveChoices`, §9). Pinned by `StoreTests.testLookingAtAFileLeavesTheLiveWhenStepsAndConditionsAlone`.
5. **Resolved in 0.62** — ~~docs/store.md rule 5 says "the key is the tiebreak".~~ Rule 5 now says what `settleDuplicates` does: on equal `updatedAt` the greater JSON text wins.
6. **Resolved in 0.62** — ~~docs/store.md says unknown keys are written back untouched.~~ docs/store.md now names the kinds that keep them (things, places, templates, trips, lines, to-dos, kits) and those whose JSON is rebuilt from known fields (phases, shared rows, photos, template sections, care records, forecasts).
7. **Resolved in 0.62** — ~~`forThisLaunch`'s doc comment lists three test modes.~~ It lists all six, in the order they are checked, and says the rescue copies are real files deleted at launch; the UI tests' `launch` comment no longer says "no files".
8. **Resolved in 0.62** — ~~Rescue copy times are UTC.~~ `RescueNames.when` reads the name's world time and says it in the device's time zone ("23 September, 01:04", §11). Pinned by `RescueNamesTests.testACopyIsReadOutInHisOwnTime`.
9. **Resolved in 0.62** — ~~`backupData`'s comment says the file is laid out the way the web app lays it out.~~ The comment (and §10) now say: Foundation's pretty-printer with sorted keys; each app reads the other's file, byte equality does not hold.
10. [bug] **"Add as a new template" with one of his template names** — Resolved in 0.62 (spec 04, item 5): a name he has is refused as a new template; the screen offers a free one ("Hiking 2") and says what is missing when pressed with a taken one; `testATemplateAndAGrabListAreSharedAndOpenedAgain` now adds it as "Hiking club".
11. Resolved in 0.62 (the trips area, F001): a line with nothing behind it — sent by someone — survives a rebuild and is not doubled, and a received trip arrives Quick (spec 03). Was: [bug] [untested] **A shared trip loses its lines on the first Trip settings Save.** Its lines have no `sourceItemId`, no `sourceListId` and no `custom` (the sender's bundle drops all three), so `changeTrip` → `regenerated` drops EVERY received line — ticked ones too — and puts in what HIS templates produce for that trip (his base and transport templates, plus any of the sender's template ids he happens to have — usually none).
12. **Resolved in 0.62** — ~~Misleading share message for an empty template or grab list.~~ With no link and no file the Share screen says "There is nothing on it to share yet." (`share-empty`); "too big" is said only where a file is offered (a trip). Pinned by the UI test `testAnEmptyGrabListSaysHowToFillIt` (Home spec).
13. **Resolved in 0.62** — ~~RestoreSheet's minimum frame 420 × 520 is applied on the iPhone too.~~ It is the Mac's only (`#if os(macOS)`, §11). Pinned by `testARestoreShowsWhatTheFileHoldsAndThenReplacesEverything` (the sheet and its buttons lie inside the window; red on the iPhone with the minimum back).
14. **Resolved in 0.62** — ~~`lastImport` is published but never shown.~~ `lastImport` is gone; This device holds says where the library came from, from the import's own marker ("Brought in from a backup …", `device-import`, §13), and a restore says what came in ("Restored from the file: 1 template, 2 things and 0 trips.", §11). The fragile counts are not shown: a file whose counts differ is refused, so an accepted one always has them equal. Pinned by `StoreTests.testSettingsSaysWhenTheLibraryCameFromAFileAndWhenItWasLastSaved` and the restore UI test.
15. **Resolved in 0.62 (written down; one cheap cure)** — every one of these now says in a comment, where it happens, what it costs and why it stays: `LibraryModel.commit` (and StoreSession.swift since 0.62), `CloudStore.apply`, the remote-change reload (`CloudStore.init`, `LibraryModel.init`), Settings' `body`. Settings no longer builds the backup on a redraw (0.62, built on Save) and `counts` counts the arrays (0.62, no records built); since 0.62 Worth a look gathers the photos still shown in ONE walk (`photoIdsInUse`, `PhotoTidyTests.testOneWalkFindsEveryPhotoStillShownAsTheOneByOneCheckDoes`) instead of walking every thing and trip line once per photo on every drawing of Settings. Left as they are, on purpose (no safe cheap cure, and CloudStore has no test in CI): the full rebuild and diff on every change, the full fetch in `apply`, the full reload per notification on the main thread. Was: [idea] **Performance traps not written down in comments:** every change rebuilds and diffs every record and base64-decodes every photo (`commit`); `CloudStore.apply` fetches the whole store per change; Settings recomputes `backupData()`, `counts` (records twice, photos decoded) and `worries()` on every redraw, and the restore sheet builds `counts` for both libraries; every remote notification reloads the whole store on the main thread. Since 0.61 the backup also carries every thing and every place a second time (`items`, `memberships`), so the file — and that redraw — is larger.
16. Decided in 0.62 (kept, F123): a record the library cannot show stays in the store on purpose — during a sync a trip's lines can arrive before the trip itself, and a record from a newer build may be one this build cannot read yet; deleting them could lose what is still on its way. Pinned by `StoreTests.testRecordsTheLibraryCannotShowAreLeftInTheStore`. Was: [idea] **Orphans that never leave the store:** a line record whose trip was deleted on the other device, records of an unknown table, and records whose JSON does not parse are invisible, never in `held`, never deleted, and "This device holds" does not count them.
17. Partly resolved in 0.62: Settings now says when a backup was last saved on this device and where the library came from (§ Settings). `BackupState`'s reminder and `DeviceAudit` stay ported and unused — held to the web app by the parity check. Was: [idea] **Ported but unused:** `BackupState` (backup reminders, the shrink guard) and `DeviceAudit`; the native app has no backup reminder, no "last backup" date and no "is this device complete?" verdict. Decide whether a rewrite needs them.
18. [idea] **Entitlements:** the iCloud entitlements file is written for Development and rewritten to Production only by the TestFlight workflow; the `com.apple.cloudd` sandbox exception "stays in until a shipped build proves it is not needed" (testflight.yml, docs/store.md) — still open.
19. **Resolved in 0.62** — ~~`addGrabList` makes ids from `Date()` and `Int.random`.~~ A new list's id is `own-` + `PackingEnv.makeId()` (lists made before keep theirs). Pinned by `StoreTests.testANewGrabListsIdComesFromTheAppsIdMaker`.
20. **Resolved in 0.62** — ~~"Not in iCloud yet" order for equal counts is dictionary order.~~ Equal counts follow the `Table` order (§8). Pinned by `SyncCheckTests.testNotInICloudYetKeepsItsOrder`.
21. **Resolved in 0.62** — ~~No keyboard shortcuts on Cancel / Done / Replace.~~ Escape (⌘. on an iPhone keyboard) presses the restore's Cancel, Your choices' Done and Open a shared link's Done — every sheet's Cancel, or its Done where it has none (spec 06 §20). Never Replace: no `.defaultAction` anywhere, so Return replaces nothing. Pinned by `testEscapeClosesSettingsWindowsAndNeverReplaces` (Escape on the restore: closed, "Nothing was replaced.", still 10 things).
22. **Resolved in 0.62** — ~~Opening a shared template renames his things.~~ A linked row takes HIS spelling of the thing's name before the save (spec 04, item 6; `testALinkedThingKeepsHisSpelling`).
23. **Resolved in 0.62** — ~~Replace (shared template) silently loses what was his.~~ Replace takes the sender's things and keeps his template and the answers on the things he had; the question says how many come in and leave and what stays (`replaceTemplate`, `shared-replace-says`, §16.4). Pinned by `ReplaceTemplateTests` and UI `testReplacingATemplateSaysWhatItKeeps`.
24. Resolved in 0.62 (the trips area, F019): `Library.justTheList` — a link or file leaves the sender's marks, scale readings and photo ids out, and an older link's are dropped on arrival (spec 03). Was: [bug] **A shared trip carries the sender's private state** and arrives with it: set-aside marks, `_edited`, way-home ticks, used-up and home notes, bought-on-site marks, the sender's scale readings (`weighed`) and `bagPhotos` ids that point at photos the receiver does not have.
25. **Resolved in 0.62** — ~~The sync card says "Working" when it knows nothing.~~ The pill says "Can’t tell" (muted) with "This device cannot tell right now how the sync is going." (`sync-unknown`, §8). Pinned by `SyncCheckTests.testTheCardSaysItCannotTellWhenItCannotRead`.
26. **Resolved in 0.62** — ~~An undated unused photo stays for ever, unmentioned.~~ Worth a look names it on its own ("1 photo with no date is no longer shown anywhere.") and removes it only when he presses "Remove it" (§14). Pinned by `UndatedPhotoTests` and UI `testWorthALookRemovesAPhotoLeftBehind`.
27. **Resolved in 0.62** — ~~A photo whose base64 is not strictly valid loses its picture.~~ The store reads it the way a browser does — line breaks, missing padding, web-safe letters, `%`-escaped — and keeps the picture (§3). Pinned by `StoreTests.testAPhotoWrittenLooselyKeepsItsPicture`.
28. **Resolved in 0.62** — ~~docs/store.md rule 8 says a restore never quietly overwrites a newer copy on the other device.~~ Rule 8 now says what the code does: the restore compares the file with THIS device only (the sheet's counts), keeps a copy of this device first, and its changes then reach the other device through iCloud without a look at what that device holds — so restore on the device that holds the newest work, or check both with This device holds first.
29. **Resolved in 0.62** — ~~Untested areas worth a test before a rewrite.~~ Now tested: the store's moves and twin handling (`StoreTests`, with a store that keeps twins as CloudKit can), `SyncCheck` reading, plain words, the order of "Not in iCloud yet" and Copy details' counts (`SyncCheckTests`), rescue-copy pruning and the time read out (`RescueNamesTests`), the import door's refusals, a file holding one of the two keys, a file whose keys disagree with its rows (refused), the restore preview leaving the live "When" steps alone, the note split after a rebuild (`StoreTests`). Still untested, with reasons: CloudStore itself (SwiftData in the app, no app-hosted test target, no iCloud in CI — proved on his devices), the file pickers and Save panel (system windows), and shared-trip lines after a Trip settings change (item 11 — the trips area).
30. **Resolved in 0.62** — ~~An older file of ours, or the web app's, cannot say whose note it is.~~ After a rebuild from the rows, a note or qty that every place of a thing carries goes back onto the thing (`settleOwnNotes`, §9 path b); notes that differ per place stay the places'. What a row truly cannot say is listed under §9's limitation. Pinned by `StoreTests.testAnOlderFileGivesEachThingItsOwnNoteAndAmountBack`.
