# Settings, the in-app guide, the conventions every screen follows, and how the app is built, tested and shipped

> Verified against the code on 5 Oct 2026 (app 0.61).

**What this part is for.** Settings is the sixth tab, the place for what is used "now and then, not every day"
(his test K.2, 1 Oct 2026): the lists he authors himself (*Your choices*), the per-device packing reminders,
the iCloud sync card, the in-app guide (*What's new*, *How it works*, *Your first real trip*), opening a link
someone shared, the library's self-check (*Worth a look*), backup and restore, and what this device holds.
This chapter also writes down the conventions every screen follows (colours, drawn marks, buttons, headings,
type sizes, identifiers, the Mac rules), the invented sample library the UI tests run on, and the build, test
and release machinery.

**How one reaches it.** The tab bar's sixth button, *Settings* (id `tab-settings`, the slate "nut" mark). The
screen container is `screen-settings`. Settings is one of only two tabs with real content on an EMPTY library
(state `.empty`): `RootView.SectionScreen` shows `SettingsScreen` for both `(.ready, .settings)` and
`(.empty, .settings)`, so a fresh device can restore from a file before anything has arrived. No Shortcut and no
menu lead here. There is no way "out" other than another tab.

Sources read for this chapter: `App/Sources/Screens/SettingsScreen.swift`, `ListsScreen.swift`, `Countdown.swift`
(RemindersCard), `SyncCard.swift`, `Share.swift` (OpenSharedDoor), `RestoreSheet.swift`, `SmallDelete.swift`,
`Headings.swift`, `HomeScreen.swift` (Pills, FlowRow, PillTone, WorkoutTone), `Loop.swift` (the guide's loop card),
`App/Sources/Guide/*.swift`, `App/Sources/{AMSPackingApp,RootView,Theme,Sections,Buttons,SVGPath}.swift`,
`App/Sources/Store/{LibraryModel,SampleLibrary,RescueCopies,Reminders,Today}.swift`,
`Core/Sources/PackingLibrary/{SettingsLists,Health,Backup,Contrast,Countdown,SyncCheckIn,TripEdits}.swift`,
`Core/Sources/PackingCore/{SharedRows,Presets,Phases,ItemConditions,People,Vocabulary}.swift`, `project.yml`,
`App/Config/*`, `.github/workflows/*.yml`, `tools/*`, `Core/Package.swift`, `Core/Sources/{parity,import-check}`,
`docs/colours.md`, `README.md`, `TESTFLIGHT.md`, the UI tests and the model tests named in each section.
Storage and sync themselves are in `docs/store.md` and the storage chapter of this spec; they are linked, not repeated.

---

## 1. The Settings screen as a whole (`SettingsScreen`)

**Purpose and origin.** The type comment: "save a backup — a real Save window on the Mac, Files on the iPhone
(promised as one of the FIRST features) — and what this device holds, table by table, so two devices can be
compared by eye." Everything else was added later; the order was rearranged by his test K.2 (1 Oct 2026: "Move
down, back up, and restore to the bottom or at least further down"), recorded in Release 0.46 ("Settings: Save a
backup and Restore are further down, under Your choices, What's new and How it works").

**Layout.** One `KeyboardAwayScroll` (see §22) holding a `VStack(alignment: .leading, spacing: 14)`, padded 16
left/right and 24 at the bottom, inside the app's 720-point column (`RootView`). Top to bottom, exactly in this
order in the code:

| # | Element | Shown when | Id |
|---|---|---|---|
| 1 | *Your choices* door (§2) | always; 14 pt extra space above it | `settings-lists` |
| 2 | *Remind me to pack* card (§3) | always | `settings-reminders-card` |
| 3 | *iCloud sync* card (§4) | always | `sync-card` |
| 4 | Three guide doors: *What's new*, *How it works*, *Your first real trip* (§5) | always | `settings-whatsnew`, `settings-howitworks`, `settings-firsttrip` |
| 5 | *Open a shared link* door (§11) | always | `settings-openshared` |
| 6 | *Worth a look* card (§12) | only when `library.worries()` is not empty | `health-heading`, `health-<n>` … |
| 7 | Heading *BACKUP* (§13) | always | `backup-heading` |
| 8 | *Save a backup…* button + status line | always | `backup-save`, `backup-status` |
| 9 | *Restore from a file…* button (§14) | always | `backup-restore` |
| 10 | *Kept before a restore* list (§15) | only when a rescue copy exists on this device | `rescue-heading`, `rescue-row-<n>` |
| 11 | *This device holds* table + footer (sync mode, version) (§16) | always | `device-count-<table>` |

**Sheets and windows owned by the screen itself.** `.sheet(isPresented: lists)` → `ListsScreen`;
`.sheet(item: pending)` → `RestoreSheet`; `.fileImporter` (open a `.json`); `.fileExporter` (save the backup).
The guide doors and the shared-link door own their OWN sheets (`GuideDoors`, `OpenSharedDoor`) because "several
sheets on one view is a trap met in Search" (GuideScreen.swift comment).

**State held by the screen** (`@State`, lost when the tab is left): `exporting`, `status` (the line under Save),
`lists`, `picking`, `pending: PendingRestore?` (a file already read and checked, waiting for his yes),
`copies: [URL]` (rescue copies, read once when the view is created and again after a restore).

**iPhone vs Mac.** Identical layout. Save opens the Files picker on the iPhone and a real Save panel on the Mac;
Restore opens the Files browser / an Open panel. Sheets on the Mac get minimum sizes (each section says which).

**Tests.** `testSettingsOffersABackup` (the device check exists; *Save a backup* sits BELOW *Your choices*;
pressing it says "Choosing…"; on the Mac a Save window opens and Escape closes it), `testEveryTabOpensItsScreen`
(tab ids and `screen-settings`). Each card's own tests are in its section.

**Traps.** The backup JSON is built inside `body` (`BackupDocument(data: model.library.backupData())` is an
argument of `.fileExporter`), i.e. on every redraw of Settings — including all photo data. See Open questions.

---

## 2. *Your choices* — the lists he authors himself (`ListsScreen`, `SettingsLists.swift`, `SharedRows.swift`)

### 2.1 Purpose and origin
"The lists he authors himself: storage places, owners, packers, conditions and the 'When' timeline. They belong
to the account, so both devices show the same; an entry still in use cannot be removed by accident." Introduced
in 0.3 as *Your lists*; renamed *Your choices* in 0.34 ("so it never clashes with Your templates", UI test
comment 2026-09-27). Each part got a one- or two-line explanation in 0.46 (his test K.3, 1 Oct 2026: "a line or
two of explanations for each choice … so that this is totally clear to the user"). The part headings became
bands in 0.57 (field test 3 Oct 2026: headings "dominant").

### 2.2 The door on Settings
A full-width card button: title **"Your choices"** (18 bold, `Theme.ink`), under it **"Storage places, owners,
packers, conditions, "When" steps"** (14, `Theme.muted`, one line — truncated with "…" if too narrow), a drawn
chevron on the right (`SVGPath "M9 6l6 6-6 6"`, stroke 1.8, round caps, 24×24, muted). Card: minimum height 60,
14 horizontal padding, `Theme.card` fill, corner radius 12, 1-pt `Theme.line` border; whole card tappable; plain
style; `.focusEffectDisabled()`; id `settings-lists`. Tap → `lists = true` → sheet.

### 2.3 How it is reached and left
Reached only through the door. Left with **Done** (top right, `HeaderButtonStyle(tint: settings slate, filled:
true)`, id `lists-done`) which calls `dismiss()`; or by swiping the sheet down on the iPhone. Nothing is ever
"saved" on leaving — every Add and Remove is written immediately through `LibraryModel.change`.

### 2.4 What is on screen, top to bottom
- Header row (padding 16): **"Your choices"** (22 heavy, ink, id `choices-title`), Spacer, **Done**.
- Then a `KeyboardAwayScroll` with a `VStack(spacing: 8)`, padding 16 horizontal / 24 bottom:
  - Intro (15 medium, muted, wraps, id `choices-intro`): **"The words the app offers you as buttons. Add your
    own with the field under each part; one that is still in use somewhere cannot be removed."**
  - Problem line, only while `problem` is not empty (15 semibold, To-do red `#dc3d43`, id `lists-problem`):
    **"<label> is still used by <n> thing" + ("" if n == 1 else "s") + ", so it stays."** It sits at the TOP of
    the page, under the intro, whichever part was pressed.
  - Five parts, in this fixed order (`Kind.allCases`): `places`, `owners`, `people`, `conditions`, `phases`. For each:
    - A `HeadingBand` (§21) in the Settings slate, 16 pt space above, id `choices-heading-<kind>`. Titles:
      **"Storage places"**, **"Owners"**, **"Packers"**, **"Item conditions"**, **""When" steps"**.
    - The hint (15 medium, `Theme.ink` at 85 % opacity, wraps, id `choices-hint-<kind>`):
      - places: "Where a thing is kept at home — a cupboard, the garage, the basement. You give a thing its place
        under Kept at home; a trip sorted by From where then lists what to fetch room by room."
      - owners: "Whose a thing is — you, your partner, a child. You pick it under Whose it is on a thing, so on a
        shared trip everyone sees which things are theirs."
      - people: "Who packs a thing. You set it in the All your things table (Packed by), so you can see who is in
        charge of what."
      - conditions: "How worn a thing is: New, Good, Worn, Needs replacing. You set it under Condition on a thing;
        a thing that needs replacing is suggested on To buy."
      - phases: "The steps of packing, from a week ahead to the day you leave. Every thing has its When, and a trip
        shows its list in this order, step by step."
    - One row per entry (n = 0, 1, …): the label (17 medium, ink); if the entry is in use, its use count (14 bold,
      monospaced digits, muted) right after it; Spacer; a remove button — a drawn ✕ (`M6 6L18 18M18 6L6 18`,
      stroke 1.8, 22×22, muted) in a 40×40 hit area, id `list-<kind>-remove-<n>`, VoiceOver label
      "Remove <label>". The row is an accessibility container (`children: .contain`) with id `list-<kind>-row-<n>`
      and a 1-pt `Theme.line` hairline at its bottom. There is no empty-state text: an empty list (e.g. Owners on
      an account that never added one) shows no rows, only the Add field.
    - The Add row (`HStack(spacing: 8)`): a plain `TextField` with the placeholder **"Add to <title lower-cased>"**
      — i.e. "Add to storage places", "Add to owners", "Add to packers", "Add to item conditions", "Add to "when"
      steps" — 17 medium ink, 12 horizontal padding, min height 44, card fill, radius 10, 1-pt line border, id
      `list-<kind>-add-name`; Return (`onSubmit`) = Add. Then **Add** — `FieldButtonLabel(title: "Add", tint:
      Settings slate)`, id `list-<kind>-add`. Under the row, the needs line (`.needsLine`, id
      `list-<kind>-add-needs`, §20).
  - Footer (14, muted, 14 pt above): **"These belong to your account, so both your devices show the same."**
- Whole sheet: `Theme.bg` behind (ignores the safe area), accessibility container id `lists-detail`.

### 2.5 Behaviour
**Which entries a part shows** (`entries(kind)`):

| Part | Source | Label | Key used for removing | Use count looked up by |
|---|---|---|---|---|
| places | `library.storagePlaces()` (stored order, or the 12 factory places) | name | the name | `normName(name)` in `usesOf("places")` |
| owners | `library.owners()` (stored rows only, A–Z) | name | the name | `usesOf("owners")` |
| people | `library.people()` (stored roster, or the 2 factory packers) | `name` | `name` | `usesOf("people")` |
| conditions | `library.conditions()` (stored, or the factory 4) | `label` | `id` | `normName(id)` in `usesOf("conditions")` |
| phases | `library.timeline()` (stored `phases`, or the factory 7) | `label` | `id` | `normName(id)` in `usesOf("phases")` |

`Library.usesOf(kind)` counts, per normalised key (`normName`: trimmed, lower-cased, runs of white space collapsed;
empty keys skipped): for every catalogue item, its `storage` (places), `ownedBy` (owners), `packer` (people),
`condition` (conditions) or `phase` (phases). For `phases` ONLY it also counts every trip line's `phase` and every
membership's `phase`. Nothing else is counted (not to-dos, not trip lines for the other kinds).

**Add** (`add(kind)`; the same from the button and from Return):
1. `name = jsTrim(field)`. Empty → the needs line says **"Type a name first."** and nothing else happens (the
   button is never disabled or grey — §20).
2. `problem` is cleared.
3. One `model.change { … }`:
   - places: `setNames("places", storagePlaces() + [name])`
   - owners: `setNames("owners", owners() + [name])`
   - people: `setPeople(people() + [newPerson(name: name, color: PERSON_COLORS[people().count % 8])])` — the next
     colour of the 8-colour palette `#3b82f6 #a855f7 #22c55e #f59e0b #ef4444 #06b6d4 #ec4899 #84cc16`.
   - conditions: `setConditions(conditions() + [newCondition(name, conditions().map(\.id))])` — id = `jsSlug(name)`
     (a–z and 0–9 kept, every other run of characters becomes one "-", at most 24 characters), or
     `cond-<base-36 timestamp>` when the slug is empty; on a clash `-2`, `-3`, …; label = trimmed name cut to 60
     UTF-16 units; tone "" (no badge); `replace` false.
   - phases: `list = timeline(); list.append(newStep(named: name)); setTimeline(list)` — `newPhase` with: id from
     `jsSlug` (or `phase-<base-36 timestamp>`), clash → `-2`…; label ≤ 60; hint ""; emoji the default 📦 (data
     only, never drawn by this app); colour `COVER_COLOURS[count % 10]` — the web app's `TEMPLATE_COLORS` with cyan
     → orange and teal → indigo (spec 04 §3), so with the factory 7 the eighth is indigo `#4f46e5`, no longer teal
     `#14b8a6` ("Not teal", spec 04's pass, 5 Oct 2026); `task` false; `leadDays` 0; appended at the end (order =
     count, then renumbered).
4. The field is emptied.

What happens to odd input: for places, owners and packers a name that equals an existing one after `normName` is
silently dropped by the row builders (`nameRows` / `peopleRows`: no message; the field still empties). A list that
ends up identical to the factory list stores no rows at all (and `LibraryModel.change` writes nothing when no record
changed). A long name is cut AT ONCE, not later: the row is built by `coerceSharedRow`, which cuts its `name` to 80
UTF-16 units and its `key` (the normalised name) to 60, so the list shows the cut name straight away (a condition's
or a step's label is already cut to 60 by `newCondition` / `newPhase`). Two place or owner names that differ only
after their first 60 normalised units get the SAME row id (`places:<key>`) — two records under one key, settled to
one on the next load, so one of them is lost (edge case, untested). Two conditions or two "When" steps with the same
LABEL are possible (they get different ids, e.g. `good` and `good-2`), because only ids are de-duplicated for those
kinds.

**Remove** (`remove(kind, n)`):
1. The entries are recomputed; `n` out of range → nothing.
2. In use (`uses > 0`) → `problem` = "<label> is still used by <n> thing(s), so it stays." Nothing changes. (For
   "When" steps the number includes trip lines and template places, but the sentence still says "thing(s)".)
3. Otherwise `problem` is cleared and one `model.change`:
   - places: `setNames("places", storagePlaces().filter { $0 != key })`
   - owners: `setNames("owners", owners().filter { $0 != key })`
   - people: `setPeople(people().filter { $0.name != key })`
   - conditions: `setConditions(conditions().filter { $0.id != key })`
   - phases: `setTimeline(timeline().filter { $0.id != key })`
   The comparison is EXACT (case-sensitive) on the stored spelling. Removing the last remaining entry of places,
   people, conditions or phases brings the factory list back (an empty list means "the defaults").
   No confirmation is asked; there is no undo.

**What is NOT possible here** (the web app could): renaming an entry, reordering, choosing a person's or a step's
colour, a step's lead days or "to-do" flag, a condition's badge tone or its "needs replacing" flag, resetting to
factory. A condition added here can therefore never feed To buy (its `replace` is always false), and a step
added here falls due on the day of departure (`leadDays` 0).

### 2.6 Data
**The model API** (`extension Library`, `Core/Sources/PackingLibrary/SettingsLists.swift`):

| Function | Answer / effect |
|---|---|
| `storagePlaces()` | `orderedNamesFromRows(shared, "places")` (stored order); empty → `DEFAULT_STORAGE_LOCATIONS` |
| `owners()` | `namesFromRows(shared, "owners")` — A–Z (`jsLocaleCompare`, en-US collation); no defaults |
| `ownerChoices()` | what *Whose it is* on a thing offers: `owners()` then every item's trimmed `ownedBy` sorted A–Z, each normalised name ONCE, first spelling wins (fix of 2026-09-26: one name appeared once per thing he owns) |
| `people()` | `peopleFromRows(shared)`; empty → `DEFAULT_PEOPLE` each made a person with a fresh random id |
| `conditions()` | `conditionsFromRows(shared)`; empty → `DEFAULT_ITEM_CONDITIONS` |
| `timeline()` | `phases`; empty → `DEFAULT_PHASES` |
| `usesOf(kind)` | as above |
| `setNames(kind, names)` | only `"places"` and `"owners"` (anything else → returns false, changes nothing); trims, drops empties, removes every row of the kind, then appends `namesToRows(kind, clean)` unless `isFactoryList(kind, clean)` |
| `setPeople(list)` | removes every `people` row; appends `peopleToRows(list)` unless factory |
| `setConditions(list)` | removes every `conditions` row; appends `conditionsToRows(list)` unless factory; then installs the live condition list `setItemConditions(list.isEmpty ? DEFAULT : list)` |
| `setTimeline(list)` | `settled = setPhases(list.isEmpty ? DEFAULT_PHASES : list)` (installs the live `PHASES`, sorted and renumbered 0…n-1); `phases = phasesCustomised(settled) ? settled : []` |

**Factory lists (in the code, never stored — "nothing is ever seeded", the v118 lesson):**
- Storage places (`DEFAULT_STORAGE_LOCATIONS`, 12, in this order): Bedroom wardrobe, Chest of drawers, Hall
  closet, Bathroom cabinet, Kitchen cupboard, Garage, Loft / attic, Basement / cellar, Utility room, Storage box,
  Car boot, RV / camper.
- Item conditions (`DEFAULT_ITEM_CONDITIONS`): `new` "New" (no badge), `good` "Good" (no badge), `worn` "Worn"
  (tone `warn`, amber badge), `retire` "Needs replacing" (tone `danger`, red badge, `replace` true). Tones allowed:
  "" (No badge), `warn` (Amber badge), `danger` (Red badge).
- Packers (`DEFAULT_PEOPLE`): two starter people — the owner's household; their names are in the code and
  deliberately not repeated here — coloured `#3b82f6` and `#a855f7`, with id "" in the constant.
- "When" steps (`DEFAULT_PHASES`; id · label · lead days · to-do? · colour): `prep` · Preparations · 30 · yes ·
  `#7c5cd6`; `week` · ≥1 week ahead · 7 · no · `#3b82f6`; `daybefore` · Day before (stage / move to RV) · 1 · no ·
  `#06b6d4`; `morning` · Morning list · 0 · no · `#f59e0b`; `door` · At the front door · 0 · no · `#22c55e`;
  `wear` · Wear / carry on the day · 0 · no · `#ec4899`; `after` · After / recovery · −1 (after the trip) · no ·
  `#14b8a6`. Each also carries a one-line hint and an emoji from the web app; neither is shown in this app.
- Owners and trip presets have no factory list.

**The shared-row store** (`SharedRows.swift`, a port of the web app's v120 design). Every author-made list entry
is ONE record in the `shared` table — "a row is the unit the sync merges, so a person added here and a place
added there both survive". `SHARED_KINDS` = `conditions, presets, people, owners, places, grab` (a row of any
other kind is coerced to kind "" and then dropped). A row is `{ id, kind, key, name, order, data }`:
- `id` = `"<kind>:<normName(key)>"` — STABLE, so two devices adding "Garage shelf" independently land on the same
  record and merge (the "880-item lesson"). Never random.
- `key` = `normName(key)` cut to 60 UTF-16 units; `name` = trimmed display spelling cut to 80; `order` = position
  (non-finite → the row's index); `data` = everything else, NESTED in an object, so no field can collide with
  the sync add-on's reserved `owner` / `realmId` (the v117 incident).
- Reading a kind (`sharedRowsOfKind`): coerce each row, keep those of the kind with non-empty key and name, sort
  by `order`, ties broken by `id` (`jsLocaleCompare`) — "load-bearing, not tidiness": both devices must agree.
- Per kind: **places / owners** — key = normalised name, de-duplicated case-insensitively; read back either in
  stored order (`orderedNamesFromRows`, places) or A–Z (`namesFromRows`, owners). **people** — key = name,
  `data.color`; read back with the ROW id as the person's id (same on both devices). **conditions** — key = the
  condition's id, `data = { tone, replace, cid }`, where `cid` keeps the id VERBATIM because items are stamped
  with it. **presets** — §17. **grab** — the Home grab buttons (owned by the grab-list chapter): key = the code id
  (`bike`, `run-out`), `data = { gid, items (each trimmed, ≤ 80), label (≤ 24), icon, tone }`, name = label or gid.
- `isFactoryList(kind, list)` compares the would-be rows with the factory rows (count, then id, name and data of
  each); kinds without a factory list (owners, presets, grab) are never "factory", so they are always stored.
- `ownersByUsage(names, counts)` (most-owned first, ties A–Z) exists for parity with the web app but is NOT used
  by any native screen: the native Owners list is A–Z.

**Where the "When" steps live.** Not in `shared` but in their own `phases` table (one record per phase, key = the
phase id), stored only when customised; `[]` = the factory seven. `PHASES` / `PHASE_IDS` and `ITEM_CONDITIONS` are
module-level globals mirrored from the JS on purpose; `LibraryModel.reload()` re-installs both from the stored data
on every reload, and `setTimeline` / `setConditions` re-install them on every edit.

**How it travels.** Records → SwiftData → iCloud (docs/store.md). In a backup file the lists ride in `prefs`:
`storageLocations` (ordered), `owners` (A–Z), `people` (`{ id, name, color }`), `conditions`
(`{ id, label, tone, replace }`), `presets`; the phases ride top-level as `phases`. Only lists that are his own are
written (a factory library writes no settings lists — `testAFactoryLibraryWritesNoSettingsLists`). The importer
skips a list that is still exactly factory.

**Consumers elsewhere.** `storagePlaces()` feeds *Kept at home* and *Set place*; `ownerChoices()` feeds *Whose it
is*, whose pills start with **"Both have one"** (`OWNER_BOTH`, ThingFilters.swift — the label for `ownedBy` "", i.e.
no owner; "Nobody's in particular" until 0.59), which is also the label of the blank answer in the table's Owner
filter; `people()` feeds *Packed by* in the table; `conditions()` feeds *Condition* and the To buy suggestions;
`timeline()` drives every "When" (sorting, reminders, the countdown).

### 2.7 iPhone vs Mac
A sheet on both. Mac only: `.frame(minWidth: 520, minHeight: 600)`.

### 2.8 Tests
- Model — `SettingsListsTests`: `testAListWithNoRowsIsTheFactoryOneAndHisOwnIsStored` (factory answers, nothing
  stored; `setNames` trims and drops empties, one record per entry with keys `places:garage shelf`…; `setNames`
  refuses `people`; it also pins the two starter packer names), `testEachOwnerIsOfferedOnce` (40 items, three
  owners → each once, the list's own A–Z first, then the one not on it; nobody named → `[]`), `testPuttingTheFactoryListBackRemovesItsRows`,
  `testHisOwnTimelineIsStoredAndTheLiveStepsFollow` (8 steps stored and live; back to factory = 0 records),
  `testWhatIsInUseIsCounted` (places, owners; phases count trip lines and memberships).
- Model — `SharedRowsTests` (26 tests): stable ids across devices; conditions keep `cid` verbatim; order ties
  broken deterministically; people keep colour and share the id; same name twice → one row; owners/places
  de-duplicate case-insensitively and sort A–Z; presets re-saved under a name replace it; kinds never mix; junk
  rows dropped; `isFactoryList` recognises the defaults (and fills a missing colour); `sharedRowsFrom` for every
  kind; `orderedNamesFromRows` keeps stored order and settles two devices appending at the same order;
  `ownersByUsage`; five grab-row tests; `coerceSharedRow` type rules equal the JS answers; `namesToRows` reads
  strings and `{ name }`; `peopleToRows` skips junk; sorting of non-English letters matches Node.
- Model — `PhasesTests` (12), `ItemConditionsTests` (6), `PeopleTests` (8): `newPhase` / `newCondition` ids,
  collisions, timestamp fallback, `setPhases` sorting/renumbering/fallback, `phasesCustomised`, tones, palette.
- UI — `testHisOwnListsAreAddedAndProtectedWhileInUse` (title "Your choices"; intro and every hint exist and each
  hint is longer than 80 characters; "Garage shelf" added becomes `list-places-row-12`; given to the Headlamp in
  its editor; then Remove is refused with `lists-problem` and the row stays).
  `testEveryAddButtonIsReadyAndSaysWhatIsMissing` (`list-places-add` pressed empty answers on
  `list-places-add-needs`). `testTheEditorsLeadWithTheirHeadings` (all five `choices-heading-*`).
  `testWhoseItIsOffersEachOwnerOnce` (on a thing: `thing-owner-0` reads "Both have one", then exactly "Kim",
  "Robin"; Notes sit between Name and Kept at home; a 22-pt heading line is ≥ 25 tall, a pill ≥ 36).
- **Not covered by any test:** adding to owners, packers, conditions or steps from this screen; the packer
  colour rotation; a duplicate name being silently ignored; removing an entry that is NOT in use; removing the
  last entry (factory list returns); the exact wording of the problem line; the needs line disappearing on
  typing (tested only on *Your things*); long-name truncation and the shared row id of two long names; a removal
  blocked by trip lines only.

### 2.9 Traps and history
- 🪤 Never seed: v118 seeded factory phases with stable ids and they landed exactly on top of his customised rows
  and replaced them. A kind with no rows = defaults; writing a list equal to the factory one REMOVES its rows.
- 🪤 One row per entry, never one record per list, or the last device to save wins.
- 🪤 The `people` key keeps its old name ("People" until web v133) because rows have synced under it since v120.
- 🪤 `grabToRows` de-duplicates on the id AS WRITTEN while the row id is normalised, so `Bike` and `bike` build
  two rows with one id — kept as the JS has it (`testGrabToRowsKeepsTheJSQuirkOfTwoSpellingsOnOneRowId`).

---

## 3. *Remind me to pack* (`RemindersCard` in `Countdown.swift`, `PackingReminders` in `Store/Reminders.swift`)

**Purpose and origin.** His pre-trip idea 7 (2 Oct 2026), shipped in 0.49: at nine in the morning of the day a
packing step falls due, the trip's name and what is left. "Per device and off until he turns it on in Settings —
his iPhone and his Mac both reminding him would be the same news twice."

**On screen** (a card: padding 14, card fill, radius 12, 1-pt line border, container id
`settings-reminders-card`):
- A `Toggle` (id `settings-reminders`; a switch on the iPhone, a check box on the Mac), tinted Trips green
  `#2f9e63` ("Green when on, like every switch he knows: the Settings slate read as 'off'"). Its label: **"Remind me
  to pack"** (18 bold ink) and **"On this device, at 9 in the morning of the day each packing step is due — a week
  ahead, the day before, the morning."** (14 muted, wraps).
- If the system refused permission — or (0.6x) the switch is on but the app's notifications are switched off in
  the device's Settings — **"This device does not allow the app to remind you. Allow it in the device's
  Settings, under Notifications."** (15 semibold red, id `settings-reminders-refused`).
- Else, if on: **"Next: <d Mon> · <trip name> — <says>"**, e.g. "Next: 14 Oct · Sunny weeks — ≥1 week ahead: 12 to
  pack", or, with nothing ahead, **"Nothing to remind you of yet: no trip with dates ahead."** (15 semibold, Settings
  slate, id `settings-reminders-next`). Off → no line. The line sits OUTSIDE the Toggle so a test can read it (§23).

**Behaviour.** Turning it on runs, in a Task: `askToShow()` (under the UI tests: always yes; otherwise
authorized/provisional → yes, denied → no, not determined → the system's permission question for alert + sound);
then `on = want && ok`, `refused = want && !ok`, then `reschedule(library)`. Turning it off: `on = false`,
`refused = false`, reschedule (which removes them). `refused` is not stored: leaving Settings forgets it. Since
0.6x the card also looks up, whenever it is shown and whenever the app comes back to the front, whether the
device allows reminders now (`PackingReminders.allowed()`, which never asks him); switched on but not allowed, it
shows the red line instead of "Next" (Home spec, section 14).

`reschedule(library)` (skipped entirely under the UI tests): removes every pending notification whose id starts
`packing-`; stops if the switch is off or permission is not authorized/provisional; otherwise adds one
notification per entry of `upcoming(library)`: title = trip name, body = `says`, default sound,
`userInfo["tripId"]`, id `packing-<tripId>-<YYYY-MM-DD>`, a non-repeating calendar trigger at 09:00 local on that
day. It runs when the switch changes, whenever the library settles after a change (`RootView`: the library
publisher debounced 2 s), and (0.6x) whenever the app comes back to the front. A notification arriving while the app is open shows as banner + list + sound; tapping
one switches to Home and sets `model.tripToOpen`, which opens that trip.

`upcoming(library, now:)` = `library.reminderPlan(today: Today.local)` filtered to moments (09:00 local of the
date) still in the future — "today's only while it is not yet nine". `reminderPlan(today:limit: 48)`: for every
trip not done, not reviewed, with a valid start date on or after today; for each step of the LIVE timeline with
`leadDays >= 0`: the number of the trip's lines in that step that are neither ticked nor set aside; a step with 0
left says nothing; its date = start − lead days (Gregorian, UTC arithmetic); steps before today are dropped;
steps of one trip on the same day merge into one reminder whose `says` joins them with " · " in timeline order
("Morning list: 1 to pack · At the front door: 1 to pack"); a step says "<label>: <n> to pack", or "to do" for a
to-do step (Preparations). All reminders are sorted by date (stable) and cut to 48 (an iPhone keeps 64 waiting
notifications per app).

**Data.** `UserDefaults` key `ams.reminders` (Bool, per device, never synced; cleared at launch under the UI tests).
The notifications live in the system's notification centre.

**iPhone vs Mac.** Same code. The comment notes `.ephemeral` must not be named in the permission switch: it is
iPhone-only and broke the Mac build in 0.49.

**Tests.** UI `testSettingsTurnsOnPackingReminders` (`-uiTestingChecks`: off at first, no next line; on → the next
line names "Sunny weeks" and "week ahead"; off → the line goes). Model `CountdownTests`
(`testTheNextTripIsTheSoonestStillToLeave`, `testAStepFallsDueItsLeadDaysAheadAndGoesWhenPacked`,
`testOneReminderPerTripPerDayFromTodayOn` — dates, merged days, limit, a reviewed trip stops reminding —
`testDaysAreCountedOnTheCalendar`). **Not covered:** the refused line, the actual scheduling (skipped under
tests), a tapped notification opening the trip, the 09:00 cut-off for today.

---

## 4. *iCloud sync* card (`SyncCard.swift`) — briefly

Full behaviour belongs to the storage/sync chapter and `docs/store.md`; here only what Settings shows.
Origin: field test 3 Oct 2026 ("we need to get the sync going because I need to work from the Mac"), 0.54.

- Header: **"iCloud sync"** (18 bold) and a state pill (13 heavy white, id `sync-state`): **"Off"** (muted fill)
  when this build keeps its library on the device only (`model.usesICloud == false`, always so under tests);
  **"Stuck"** (red) when something is not in iCloud yet or the last send/receive failed; else **"Working"** (green) —
  also when iCloud is on but the store file could not be read (then no Sent/Not-in-iCloud/problem lines show).
- Lines (15 medium muted; "loud" ones 15 bold red): `sync-off` "This copy of the app keeps its library on this
  device only."; `sync-times` "Sent: <when> · received: <when>"; `sync-notsent` "Not in iCloud yet: <words>.";
  `sync-problem` "The last send|receive failed <when>: <plain words>."; `sync-other` "The <Mac|iPhone> last checked in
  <when>." or "The <other> has not checked in yet — press Sync now there."; `sync-self` "This <device> checked in
  <when>." or "This <device> has not checked in yet."; `sync-said` (after a press).
- **Sync now** (green capsule, 16 bold white, min height 44, id `sync-now`): writes `meta["syncCheck.<Device>"] =
  { at: nowISO, device }` (`Library.checkIn`), says "Checked in. On the <other>, Settings shows it within a minute
  or so if the road is open.", and 3 s later reloads the library and re-reads the sync record.
- **Copy details for Claude** (15 semibold slate, plain, id `sync-copy`): puts the sync record's details plus
  "This device holds: <table> <n>, …" (table names A–Z) on the clipboard; says "Copied. Paste it into the chat with
  Claude."
- `<when>`: "today HH:MM", "D Mon HH:MM" (local), or "never". The card border turns red when stuck. It refreshes on
  appear and 1 s after every library change. The device word is "Mac" under `#if os(macOS)`, else "iPhone".
- Tests: UI `testSyncNowChecksInFromThisDevice`; model `SyncCheckInTests.testACheckInTravelsWithTheLibraryAndKeepsTheDevicesApart`.

---

## 5. The guide doors (`GuideDoors` in `Guide/GuideScreen.swift`)

**Purpose and origin.** *What's new* and *How it works* are "his standing rule from the web apps, missing here
until 0.23"; *Your first real trip* got its own door in 0.56 because they asked to keep it where they can read it
again (field test 3 Oct 2026: "Please save this in the app … so that we can choose to read that later as well").

**On screen.** A `VStack(spacing: 10)` of three doors, each built exactly like the *Your choices* door (title 18
bold ink, one muted 14-pt line truncated to one line, chevron, min height 60, card, radius 12):

| Door | Line under it | Id | Opens |
|---|---|---|---|
| **What's new** | "<newest version> · <its title>" from `Releases.all.first`, e.g. "0.60 · Find a thing on a template" | `settings-whatsnew` | `WhatsNewScreen` |
| **How it works** | "The whole app in plain words, screen by screen" | `settings-howitworks` | `HowItWorksScreen` |
| **Your first real trip** | "In 6 steps, from a backup to the review" | `settings-firsttrip` | `FirstTripScreen` |

One `.sheet(item: page)` (`Page` = `whatsNew | howItWorks | firstTrip`) shows the chosen page.

**The sheet header** (`GuideHeader`, shared by all three): the title (22 heavy, Settings slate, id `guide-title`),
Spacer, **Done** (filled `HeaderButtonStyle`, slate, id `guide-done`, calls `dismiss()`), padding 16. Each page then
scrolls in a `KeyboardAwayScroll` padded 16 / 24 on `Theme.bg`. Mac only: `.frame(minWidth: 520, minHeight: 620)`.

---

## 6. *What's new* (`WhatsNewScreen`, `Guide/Releases.swift`)

**Purpose and origin.** "Every version, newest first, in his words — what was added, changed, fixed and removed.
His standing rule from the web apps: the version log and 'How it works' are updated on EVERY release." The UI test
`testWhatsNewStartsWithThisVersion` fails the build when the top entry is not the version being built.

**Structure of an entry.** `struct Release { version, date, title, new: [String], changed: [String], fixed:
[String], removed: [String] }`, `id = version`. `Releases.all` is a hand-ordered array, newest first; versions
are plain strings ("0.10" follows "0.9"). Dates are written "4 Oct 2026".

**On screen.** Container id `guide-whatsnew`; a `LazyVStack(spacing: 12)` of cards (padding 14, card, radius 12,
line border, container id `guide-release-<n>`, n = position, 0 = newest). Each card:
- First line (baseline-aligned, spacing 10): the version (20 heavy, monospaced digits, Settings slate, id
  `guide-release-<n>-version`), the title (17 bold ink), and — only when `version == AppInfo.marketing`
  (`CFBundleShortVersionString`) — the marker **"On this device"** (12 heavy, Trips green, 1.2-pt green capsule
  outline, padding 8×3).
- The date (14 muted).
- Up to four parts, each only if it has lines, always in this order: **NEW** (Trips green), **CHANGED** (Home
  blue), **FIXED** (Care orange), **REMOVED** (muted). The part name is upper-cased, 12 heavy, letter-spaced 0.6,
  in its colour; each line is a 6-pt dot in that colour and the text (16 ink, wraps).

**The version history** (60 entries; N/C/F/R = number of New/Changed/Fixed/Removed lines — every count checked
against `Releases.swift`):

| Version | Date | Title | Lines | Gist |
|---|---|---|---|---|
| 0.60 | 4 Oct 2026 | Find a thing on a template | N1 C1 | search field above a template's list, "how many of all", ✕; Worth a look offers a photo only when it can tell the photo is more than a day old |
| 0.59 | 4 Oct 2026 | A deleted trip takes its photos along | C4 | trip delete removes its bag photos unless shown elsewhere; Worth a look offers to remove left-behind photos older than a day; "Nobody's in particular" → "Both have one"; Notes under the name |
| 0.58 | 4 Oct 2026 | The table: filter by anything, sort by levels | N4 C2 | filter by every column with pills; 3 sort levels; arrow opens the thing; own Mac window; wider column controls; blanks sort last |
| 0.57 | 3 Oct 2026 | On site, and one bar per bag | N2 C6 | On site step and page; maintenance notes onto the thing; five-step loop; one bar per bag; headings lead; Add/New/Make/Weather never grey; Reminders carry the send date; Notes show every line |
| 0.56 | 3 Oct 2026 | Your field test, part two | N7 C6 | Pack to go home search/tick-all/used-up count/notes/Open; three bag photos; Valid until "in 10 days" + quick spans; folding in Choose from your things; ✕ in every search; first-trip door; Category column in Excel; Shelf → Activity area; Bought there → Bought on site; date grid shows range, OK/Cancel; Used up undo; Just added; bag rename/delete carries readings and photos |
| 0.55 | 3 Oct 2026 | Fixes from your field test | N2 C3 | Action-button "Choose a grab list"; Goes in the cabin from the trip; Quick says Transport counts; "Only on: Summer"; Reminders ticks read back on return |
| 0.54 | 3 Oct 2026 | iCloud sync, made visible | N3 | the sync card, Sync now, Copy details for Claude |
| 0.53 | 2 Oct 2026 | Pack to go home | N1 | the way-home list with its own ticks and photos |
| 0.52 | 2 Oct 2026 | A photo of the packed bag, and Bought there | N2 | bag photo on a trip; Bought there |
| 0.51 | 2 Oct 2026 | Shortcuts and the Action button | N1 | Open a grab list, Open my next trip |
| 0.50 | 2 Oct 2026 | The luggage scale, and To buy in Reminders | N2 | scale reading becomes the bag's weight; Send to Reminders |
| 0.49 | 2 Oct 2026 | Counting down, and reminders | N2 | Home countdown; Remind me to pack |
| 0.48 | 2 Oct 2026 | Check before you go | N3 | cabin and expiry checks; On a plane, Valid until; Goes in the cabin |
| 0.47 | 2 Oct 2026 | Your first real trip | N1 C1 | the 6 steps at the top of How it works; laundry nights 3/4/5/7/10/14 |
| 0.46 | 2 Oct 2026 | Icons, and eight grab lists | N1 C4 | 50 drawn template icons; eight grab lists; backup moved down; Your choices explained; shared grab list takes a free place |
| 0.45 | 1 Oct 2026 | A change to a thing reaches your trips | C1 | edits flow to unticked lines of trips ahead |
| 0.44 | 30 Sep 2026 | The iPhone hears about changes | F1 | iPhone build got the push entitlement |
| 0.43 | 30 Sep 2026 | Actions is now To do | C1 | tab renamed |
| 0.42 | 28 Sep 2026 | Choosing things for a template | N3 | Choose from your things; grouping on a template; All your trips + map |
| 0.41 | 28 Sep 2026 | Your test comments, part 2 | N1 C3 | Words chapter; tab marks on the loop strip; Refine stands out; review order |
| 0.40 | 28 Sep 2026 | Your test comments, part 1 | N4 C9 F1 R1 | place in Trip settings; Cancel on the date grid; ✕ asks first; Excel columns; pen not gear; real Share/Done buttons; workout colours; Quick in green; grab count sticky; larger capital headings; Now/Coming up/Done; activity-area question; map for trips without forecast; loop reload arrow removed |
| 0.39 | 28 Sep 2026 | A crash fixed | F1 | Trip settings crash with a thing on a trip twice |
| 0.38 | 27 Sep 2026 | Share | N2 | share trip/template/grab list; Open a shared link |
| 0.37 | 27 Sep 2026 | Where you have been | N2 C1 | the map of trips |
| 0.36 | 27 Sep 2026 | Everything at once | N2 F1 | Tick everything / Clear every tick; weather Add all |
| 0.35 | 27 Sep 2026 | Laundry and Excel | N2 F1 | laundry cap ×4; Save as Excel |
| 0.34 | 27 Sep 2026 | Templates, said one way | C3 F1 | "Templates" vocabulary; Your lists → Your choices; Save stays in sight; Make never grey |
| 0.33 | 27 Sep 2026 | Again, from this trip | N1 | Start a new trip from this one |
| 0.32 | 27 Sep 2026 | Trip settings | N2 | trip settings; Save rebuilds the list |
| 0.31 | 27 Sep 2026 | The loop | N2 | the loop in How it works and on trips |
| 0.30 | 27 Sep 2026 | Refine | N1 | Keep / Drop from reviews |
| 0.29 | 27 Sep 2026 | Bags, said one way | N3 C3 | bag deletion choices; Delete thing |
| 0.28 | 27 Sep 2026 | Headings in colour | C1 | editor headings coloured |
| 0.27 | 27 Sep 2026 | Larger headings | C1 | editor headings larger |
| 0.26 | 26 Sep 2026 | Your bags have their own page | N4 C2 | bag page, rename/delete; Brand/Colour/Notes; Create trip always ready; small side Delete buttons |
| 0.25 | 26 Sep 2026 | Set a place while packing | N2 C1 F2 | Set place; bag ⓘ; readable When colours; numbers saved as typed |
| 0.24 | 26 Sep 2026 | Delete a trip | N1 | Delete this trip |
| 0.23 | 26 Sep 2026 | The app explains itself | N3 C2 | What's new, How it works, section folding |
| 0.22 | 26 Sep 2026 | Two bugs from your screenshots | F2 | owner shown once; rows redraw on tick |
| 0.21 | 26 Sep 2026 | Dates like Booking, Today, bag headings | N2 C1 R1 | month-grid dates; Care calendar Today |
| 0.20 | 26 Sep 2026 | Into and From where | N1 C2 | From where sorting; Where → Into |
| 0.19 | 25 Sep 2026 | Sorting | C1 | "Sorting" label beside its buttons |
| 0.18 | 25 Sep 2026 | The maintenance calendar | N2 | Care List / Calendar |
| 0.17 | 25 Sep 2026 | Your bags | N2 F1 R1 | Care → Bags; Bags card on trips |
| 0.16 | 25 Sep 2026 | Search, list edits, your year | N3 C4 R1 | search; rename/delete list; Your year |
| 0.15 | 25 Sep 2026 | A list of your own | N1 | + New list |
| 0.14 | 24 Sep 2026 | How many and Section, per list | C1 | per-membership quantity and section |
| 0.13 | 24 Sep 2026 | Colour is the message | C1 R1 | filled tick boxes |
| 0.12 | 24 Sep 2026 | Change all | N1 | bulk change with Undo |
| 0.11 | 24 Sep 2026 | A real spreadsheet | N1 | All your things as a spreadsheet |
| 0.10 | 23 Sep 2026 | The table reads | C1 | places in full |
| 0.9 | 23 Sep 2026 | The web app's look | N1 | coloured headings, two-across lists, table |
| 0.8 | 23 Sep 2026 | What your kit adds up to | N1 | Care dashboard |
| 0.7 | 23 Sep 2026 | More grab lists | N2 | sometimes-things; more than six lists |
| 0.6 | 23 Sep 2026 | Where a trip stands | N3 | all packed; Planned/Packing/Ready; list usage |
| 0.5 | 23 Sep 2026 | Worth a look | N1 | the library's self-check |
| 0.4 | 23 Sep 2026 | Weather | N1 | trip weather |
| 0.3 | 23 Sep 2026 | Your lists, restore, the buy list | N3 | Settings lists; restore with rescue copy; To do / To buy |
| 0.2 | 22 Sep 2026 | The app does the job | N7 | the working app |
| 0.1 | 21 Sep 2026 | The app exists | N1 | one app for iPhone and Mac |

**Tests.** `testWhatsNewStartsWithThisVersion`: reads the version marker under the tab bar ("0.60 (2)"), takes the
part before the space, opens What's new, requires `guide-release-0-version` to equal it and a second entry to exist;
Done closes; then How it works must open with at least `guide-topic-0` and `guide-topic-1`. **Not covered:** the
"On this device" marker, the part colours, empty parts being hidden.

**Traps.** Lines inside a part are keyed by their own text (`ForEach(lines, id: \.self)`): two identical lines in
one part would clash. The marker compares with the bundle's short version, so a build whose MARKETING_VERSION has
no entry shows no marker anywhere (and fails the test).

---

## 7. *How it works* (`HowItWorksScreen`)

**Purpose.** "The whole app in plain words, one screen at a time, with each tab's own mark."

**On screen,** in this order inside a `VStack(spacing: 12)`, container id `guide-howitworks`:
1. `FirstTripCard` (§8) — "at the very top" (his idea 13, 2 Oct 2026).
2. `LoopGuideCard` (§9).
3. `WordsCard` (§10).
4. Eleven topic cards (padding 14, card, radius 12, line border, container id `guide-topic-<n>`): a header row —
   the topic's section mark (`SectionMark`, 24 pt, line 1.9, in the section's colour) and the title (19 heavy ink)
   — then each line as a 6-pt dot in the section colour + text (16 ink, wraps).

**The topics and their lines** (summarised; the code holds the exact sentences):

0. **Home** (Home mark): (1) eight grab lists, four in a row; tap one, tick what is in your hand; the count stays at
   the top; Ready to go too early says Not yet in the middle with what is missing. (2) Grab Lists: the ones on Home
   (up to eight) in order, and the waiting ones; make a new one at the bottom; tapping a waiting one puts it on
   Home — when full, you pick which one steps back. (3) The countdown to the next trip under the grab lists; tap
   opens the trip. (4) Create new trip: name, Dates (first day, last day; the line says range and nights; OK keeps,
   Cancel restores), Quick in green while on. (5) Create trip is always ready; what is missing is said under it.
   (6) So is every Add, New, Make, Weather: empty press adds nothing and a short red line says what is missing,
   gone as soon as you type. (7) Pick templates, Transport, Season, Food; workout colours (Swim blue, Bike yellow,
   Run green, Strength orange, Breath work lavender, Mobility pink); Context (Indoor, Outdoor, Race) set in under
   them. (8) Laundry: per-night things count only the nights before a wash — 4 unless 3, 5, 7, 10 or 14; shown as
   ×4 · laundry with a washtub. (9) This Device: how many trips, things and templates.
1. **Packing a trip** (Trips mark): tap to tick / untick; the round button ticks a section; Check before you go
   (cabin red/orange, expiry six months ahead for passports/IDs); the pen opens Trip settings (Save rebuilds, own
   ticks/additions stay); Start a new trip from this one; Tick everything / Clear every tick (asks first); Save as
   Excel and Share side by side; folding sections (remembered per trip); ⊘ not this time, ↻ back; Sorting When /
   Into / From where / Category; Weather line with + and Add all; tap a bag for Goes in the cabin; Bags fill
   colours and the scale reading, Clear, up to three photos; Set place under "No place set"; typing a thing adds it
   to this trip only, Bought on site adds it ticked; Delete this trip at the very end asks first (things and
   templates stay). (15 lines.)
2. **On site** (Trips mark): the door appears once the trip began or something was bought, with a summary line
   ("2 bought · 1 left · 3 notes · home 4/9"); Bought on site; Left on site with Undo; Maintenance notes (also
   dated onto the thing); Pack to go home with its own ticks; Used up / Undo; search with ✕, Tick everything;
   notes and Open on the way home; the packed-bag photos at the top, Next steps through them. (9 lines.)
3. **After a trip** (Trips mark): Review (tap unused, type missed, pick its template, Add, Save); the loop strip
   under a trip's name (Plan · Pack · On site · Review · Refine) with the tab mark; nothing is removed — "Didn't
   use" adds to history, missed things go onto a template. (3 lines.)
4. **Trips** (Trips mark): Now, Coming up and Done — Now always there; Planned / Packing / Ready; reviewed trips fold
   away; Your year; All your trips with the map; the pin opens Where you have been (pins with counts, line oldest
   first, card per place; a trip joins as soon as it has a place). (3 lines.)
5. **Your templates** (Templates mark): templates are the building blocks, in activity areas (GA, WET…); each has
   an icon (50 drawn ones, or Letter); + New asks the activity area; rename, ✕ takes a thing off (asks; the thing
   stays), How many and Section per template; Find a thing on this template ("3 of 40", ✕, adding clears it);
   Choose from your things or type a new one; folding in the picker (Fold all / Unfold all, counts, search opens
   all); Group: sections, When, Into, From where, Kind, A–Z; Delete template asks first; Share at the top (also on
   a grab list); Refine (violet card) after two or more reviews — Keep / Drop. (10 lines.)
6. **Care** (Care mark): Your things (changes reach trips ahead on unticked lines); Just added at the top until you
   leave; ✕ in search; On a plane and Valid until (+1 month … +10 years, red once run out); Bags with max weight,
   litres, empty weight and their own page; All your things · table (sort, filter, columns, Change all with Undo;
   own window on the Mac); Filter by every column (pills, Clear); Sort up to three levels (blank last); the arrow
   opens the thing and returns to the same spot; Services List or Calendar (Done today, Today); the numbers under
   the services. (10 lines.)
7. **To do** (To-do mark): To do; To buy with worn-out or run-down suggestions; Send to Reminders into the list
   "To buy · Packing", each once, dated, all day, ticks read back. (3 lines.)
8. **Settings** (Settings mark): Remind me to pack (9 in the morning, per device, next reminder shown); iCloud sync
   (times, what is not in iCloud, Sync now, Copy details for Claude); Save a backup / restore (a copy is kept
   first); Your first real trip door; Your choices (places, owners, packers, conditions, When steps); Worth a look
   (only when something seems wrong; one-press fix such as Remove it); Open a shared link (trip arrives unticked,
   template links to existing things, grab list takes a free Home place or waits). (7 lines.)
9. **Shortcuts and the Action button** (Home mark): three actions (Choose a grab list, Open a grab list, Open my next
   trip); the Action-button path (iPhone Settings → Action Button → Shortcut → Packing → Choose a grab list); if
   Packing is missing, open it once; Home Screen or Siri ("Open Swim in Packing"). (4 lines.)
10. **iPhone and Mac** (Settings mark): both hold the same library through iCloud, a change arrives within a minute or
    so; the magnifier searches everything. (2 lines.)

**Tests.** `testWhatsNewStartsWithThisVersion` (topics 0 and 1 exist), `testTheLoopShowsWhereATripStands` (loop
card, first-trip card, Words). **Not covered:** the number of topics, their order, their text.

---

## 8. *Your first real trip in 6 steps* (`FirstTripCard`, `FirstTripScreen`)

**Purpose and origin.** His idea 13 (2 Oct 2026, 0.47): "the whole app as one path, numbered, at the top of How it
works"; its own door since 0.56. The SAME card is used in both places "so the two can never say different things".

**On screen.** Card padding 14, background Home blue at 8 %, 1.2-pt Home-blue border, radius 12, container id
`guide-quickstart`. Heading **"Your first real trip in 6 steps"** (19 heavy ink, id `quickstart-title`). Six rows
(`HStack(alignment: .top, spacing: 12)`): a 30×30 Home-blue circle with the number in white (17 heavy); the step
title (17 heavy ink) and its text (16 ink, wraps). Each row is ONE combined accessibility element, id
`quickstart-step-<n>` (n = 0…5).

The steps (title — summary of its text):
1. **Save a backup** — Settings → Save a backup; again once the trip is set up — the safety net.
2. **Tidy your things** — Care → All your things · table: the No weight and No place chips; weights make the bag bars
   honest, places make From where one walk through the house.
3. **Build your templates** — one per activity or need; Choose from your things or type a new one; tap a thing for
   Only on some trips.
4. **Create the trip** — Home → Create new trip: name, Dates, templates, Transport, Season, Food, Laundry and its
   nights; then the pen: type the Place — the map pin and the weather follow.
5. **Pack** — Sorting: When, From where, Into; ⊘ is not this time; watch the bag bars and Check before you go;
   Settings → Remind me to pack.
6. **Go, use, review** — the On site page while away; grab lists for outings; back home: Review; Refine learns from it.

`FirstTripScreen` = `GuideHeader("First real trip")` + the card, container id `guide-firsttrip`, Mac min 520×620.

**Tests.** `testTheFirstTripStepsHaveTheirOwnDoor` (door opens the page; the card and exactly the six step ids
exist; Done closes). `testTheLoopShowsWhereATripStands` (the card is in How it works with six steps, not seven).

---

## 9. The loop in the guide (`LoopGuideCard`, `LoopPicture`, `LoopWords` in `Screens/Loop.swift`)

**Purpose.** His picture (2026-09-27): plan, pack, review, refine and round again; On site joined after Pack
(field test 3 Oct 2026). Violet = about his templates, green = about one trip.

**On screen** (card, padding 14, radius 12, line border, container id `guide-loop`): **"The loop"** (19 heavy);
"Every trip goes round the same five steps, and each time round your templates get a little better." (16); the
picture; the words.

- **The picture** (`LoopPicture(here: nil)`, container id `loop-picture`): five boxes in a ring of two columns —
  top row *1 · Plan* → *2 · Pack*; down the right side *3 · On site*; bottom row *5 · Refine* ← *4 · Review*; one
  long arrow up the left from Refine back to Plan. Drawn arrows (`LoopArrow`), gaps 30 pt. Each box: "<n> · <name>"
  (18 heavy, the tint made readable — `readableHex`), a short line (14 medium ink): Plan "Make templates, create a
  trip", Pack "Tick things as they go in", On site "Bought, left, notes, and packing for home", Review "After it:
  unused, missed", Refine "Keep or drop, from reviews"; the tab mark (15 pt) and "on Home" / "on Trips" / "on
  Templates" (13 bold, tab colour). Background tint 12 % (24 % when "here"), border 1.2 (3 when "here"). Tint:
  Pack, On site, Review = Trips green; Plan, Refine = Templates violet. A key under it: "About your templates",
  "About one trip" (14 medium muted). Each box is one accessibility element (`children: .ignore`) with label
  "<name>: <short>, on <tab>" (+ ". You are here" when marked), id `loop-step-<0…4>`. In the guide nothing is "here".
- **The words** (`LoopWords`): five rows — the step name (16 heavy, readable tint, 72 wide) and its sentence (16 ink)
  — then in bold: "Review looks back at one trip. Refine uses several reviews to make your templates better."

**Tests.** `testTheLoopShowsWhereATripStands`: `guide-loop` exists, exactly five `loop-step-*`, step 0 label contains
"on Home", step 2 starts "On site" and contains "on Trips", step 4 contains "on Templates", no step says "You are
here" in the guide. (The same test then checks the trip's strip and the full loop screen — owned by the loop chapter.)

**Trap.** "You are here" is put in the LABEL: the Mac does not pass on the value of a box that is not a control.

---

## 10. *Words* — the glossary (`Guide/Words.swift`)

**Purpose and origin.** His asks in tests F.7 and I.2 (2026-09-28): "We need to create a definition of words there,
a new chapter with these definitions", and "What do you mean by kit? … write that in the definition section".
Shipped in 0.41.

**On screen** (card, container id `guide-words`): a header "Aa" (17 heavy, Settings slate, in a 24×24 frame) and
**"Words"** (19 heavy); then each entry: the term (17 heavy, in its tab's colour, id `word-<n>`) and its meaning
(16 ink, wraps).

| # | Term | Colour (tab) | Meaning (as written) |
|---|---|---|---|
| 0 | Trip | Trips | One journey: its dates, place and templates, and the list you pack from. The Trips tab. |
| 1 | Template | Templates | A building block: the things for one activity or need — Hiking, Swim, Car. A trip is made from templates. The Templates tab. |
| 2 | Activity area | Templates | The group a template lives in, with its code: GA · Goal activity, WET · Workout, exercise & training, and so on. ("Activity area", not "shelf": "We understand that word much better.") |
| 3 | List | Trips | The one list you pack from for a trip, made from its templates. (A grab list is a list too.) |
| 4 | Grab list | Home | A short list for a quick outing — Swim, Bike, Run — ticked as each thing is in your hand. Up to eight are on Home; the rest wait in Grab Lists. |
| 5 | Common base | Templates | The template that comes along on every trip: passport, phone charger and the like. |
| 6 | Transport kit | Templates | What a way of travelling adds to a trip: the Car, Plane or RV things. |
| 7 | Quick | Home | A trip with only the templates you tick — no common base, no transport kit. |
| 8 | Context | Home | Indoor, Outdoor or Race: how a workout is done. It adds what that setting needs. |
| 9 | Thing | Care | One thing you own, in Your things on Care. It can be on many templates; a change to it reaches all of them. |
| 10 | Kit | Care | All your things together — what Care counts and weighs. |
| 11 | Cabin bag | Care | A bag that goes on board with you — Goes in the cabin, on the bag's page. On a plane trip it is checked for liquids and things not allowed. |
| 12 | Bag | Care | What a thing is packed into. A bag can have a max weight, and the trip shows how full it is. |
| 13 | From where · Into | Trips | Where a thing is kept at home · the bag it goes into. |
| 14 | When | Trips | The step of the packing timeline a thing belongs to: a week ahead, the day before, on the day… |
| 15 | On site | Trips | At the place the trip takes you, while the trip is under way — and the step of the loop after Pack. The trip's On site page holds what you bought, what you left, maintenance notes, and Pack to go home. |
| 16 | Set aside ⊘ | Trips | Not this time: the thing stays on the list but is not packed, and leaves the count. ↻ brings it back. |
| 17 | The loop | Trips | Plan (Home) › Pack (Trips) › On site (the trip, while away) › Review (the trip, afterwards) › Refine (Templates) — and round again. |
| 18 | Loop strip | Trips | The five steps under a trip's name. The filled one is where this trip stands, with the mark of the tab where that step is done (on a wide screen every step has its mark). |
| 19 | Review | Trips | Looking back at ONE trip: what you did not use, and what you missed. |
| 20 | Refine | Templates | Making your templates better from SEVERAL reviews: what a template carries for nothing. On the Templates tab. |
| 21 | Keep · Drop | Templates | In Refine. Keep: it stays on the template and is not asked about again. Drop: off that one template — the thing itself stays. |
| 22 | To do | To do | The tab for getting ready: things to sort out before you go, and — on its other side — To buy, with worn-out or run-down things suggested. |
| 23 | Your choices | Settings | Your own lists in Settings: storage places, owners, packers, conditions and the When steps. |
| 24 | Care | Care | Looking after your things: services that fall due, weights, bags. The Care tab. |

**Tests.** `testTheLoopShowsWhereATripStands` requires `guide-words` and a `word-<n>` reading exactly "Kit"
(searched among 0…29). **Not covered:** the other 24 terms.

---

## 11. *Open a shared link* door (`OpenSharedDoor` in `Screens/Share.swift`)

The door only (the sheet `OpenSharedScreen`, container `shared-screen`, belongs to the sharing chapter). Built like
the other doors: **"Open a shared link"** (18 bold), **"A trip, template or grab list someone shared"** (14 muted,
one line), chevron; id `settings-openshared`; it owns its sheet. Origin: 0.38 — the web app's "Paste a shared link".
Tests: `testATripIsSharedAndOpenedAgain`, `testATemplateAndAGrabListAreSharedAndOpenedAgain` (both enter here).

---

## 12. *Worth a look* — the library checks itself (`Health.swift`, `TripEdits.swift`)

**Purpose and origin.** "Both times this library went wrong, nothing on screen said so and the counts alone knew":
31 Aug 2026 (a joining device seeded starter templates — every template twice) and 23 Sep 2026 (an import onto a
device that looked empty merged with an older iCloud copy). Shipped 0.5; the photo repair in 0.59 (his ask, 4 Oct
2026: the practice trip was gone, its bag photo stayed); 0.60 stopped offering a photo whose age cannot be read.

**When shown.** Only when `library.worries()` is not empty; a sound library shows nothing at all.

**On screen** (card: padding 12, full width, card fill, radius 12, border To-do red at 50 %, 14 pt extra above):
- **"Worth a look"** (15 heavy, To-do red, id `health-heading`).
- For each worry n: its sentence (16 medium ink, id `health-<n>`); if it has a repair, a red capsule button with
  its words (16 bold white, min height 40, id `health-<n>-fix`); if it names things, up to six names joined by
  " · ", plus " …" when there are more (14 semibold muted, id `health-<n>-names`).
- Last: "A backup and then "Restore from a file…" puts a library back exactly as the file has it." (14 medium muted).

**The worries** (`Library.worries()`, in this order):
1. Template names that appear more than once (compared by `normName`, the bag list counted apart — its stored
   "Containers" is never shown, so a template he calls that is no twin; two bag lists still are — spec 04's pass;
   names in first-seen spelling and order):
   "<n> template name(s) appear(s) twice. Two libraries may have met on this account." — names listed, no repair.
2. Memberships pointing at a template that no longer exists: "<n> thing sits / things sit on a list that no longer
   exists." — no names, no repair.
3. Photos nothing shows any more (`unusedPhotos(now:)` in TripEdits.swift: not in use by anything — `photoInUse`:
   no thing, no trip line, no packed bag — and created strictly more than 86 400 s before now). `createdAt` is read
   by `isoMoment` (ISO 8601, with or without fractional seconds); a photo whose `createdAt` is empty or cannot be read
   is KEPT and never offered — "a date that cannot be read is no proof of age" (0.60; until 0.59 it counted as old
   and was offered at once). Sentence: "<n> photo is / photos are no longer shown anywhere — left behind by a deleted
   trip." with the button **"Remove it"** / **"Remove them"** → `model.change { $0.repair("unusedPhotos") }` →
   `removeUnusedPhotos()` (returns how many went). "Only photos older than a day, so one still on its way from your
   other device is never touched" (Release 0.59); "Worth a look offers to remove a photo only when it can tell the
   photo is more than a day old" (Release 0.60, under Changed).
A thing on no template and in no trip is deliberately NOT a worry ("he can keep things loose").

**Tests.** Model `HealthTests` (`testASoundLibraryHasNothingToSay`, `testTwoLibrariesThatMetAreNoticed`,
`testTheNameIsJudgedTheWayTheAppJudgesNames` — "  SAILING " twins "Sailing", `testAThingOnAListThatIsGoneIsNoticed`,
`testThingsOnNoListAreNotAWorry`); `PhotoTidyTests` (`testDeletingATripTakesItsBagPhotosAlong`,
`testAPhotoSomethingElseStillShowsStays`, `testWorthALookOffersToRemoveAPhotoLeftBehind` — clock frozen at
2026-10-04T10:00Z: the photo from 2 Oct is offered, the one from 30 minutes ago and the one with `createdAt` "" are
not; exact sentence and "Remove it"; the repair returns 1 and leaves the other two). UI `testALibraryThatHasMetAnotherSaysSo` (sound sample: no heading;
`-uiTestingTwoLibraries`: heading, "twice", names present), `testWorthALookRemovesAPhotoLeftBehind`
(`-uiTestingOldPhoto`: "1 photo is no longer shown anywhere", Remove it → card gone, photos count 0).
**Not covered on screen:** the lost-membership worry, the six-name cut with " …", "Remove them", an undated photo
(model-tested only). An undated unused photo now stays for ever and nothing on screen names it (Open questions).

---

## 13. Backup — *Save a backup…*

**Purpose.** A real file he can see (docs/store.md rule 10): the Save window on the Mac, Files on the iPhone — "the
same file the web app writes, so either app can read it."

**On screen.** `SectionTitle("Backup")` → **"BACKUP"** (18 heavy, letter-spaced 0.8, ink, 16 pt above, id
`backup-heading`). **"Save a backup…"** — full width, min height 52, Settings-slate fill, radius 12, 18 bold white,
id `backup-save`. Under it the status line (15 medium muted, id `backup-status`): by default **"The same file the web
app writes, so either app can read it."**, otherwise the last message.

**Behaviour.** Press → status "Choosing where to save…" and `exporting = true` → `.fileExporter` with
`BackupDocument(data: library.backupData())`, type `.json`, default name `Library.backupFileName(on: Today.local)`
= **`ams-packing-list-backup-YYYY-MM-DD.json`** (the local date). Saved → "Saved: <file name>"; cancelled or failed
→ "Not saved." `BackupDocument` is a `FileDocument` reading/writing the bytes unchanged (readable type `.json`).

**The file** (`Library.backupFile(exportedAt:)`, pretty-printed JSON): `app: "ams-packing-list"`, `version: 2`,
`exportedAt` (ISO, UTC), `lists` (every template resolved with its items, A–Z), `events` (trips with lines),
`actions`, `kits`, `phases` (only his own), `things` (items on no template), `photos` (all photo records, image data
inline), and `prefs` only when something is his own: `conditions`, `people`, `owners`, `storageLocations`,
`presets`, and `grab` (`items`/`meta` per grab button, `sometimes` per list, `own` lists and `home` order). The
library's other `meta` notes (import marker, sync check-ins) are NOT in the file.

**Tests.** UI `testSettingsOffersABackup`. Model `BackupTests` (`testABackupComesBackAsTheSameLibrary`,
`testAFactoryLibraryWritesNoSettingsLists`, `testTheFileIsWhatTheWebAppWrites` — includes the file name,
`testSettingALineAsideLeavesTheCounts`, `testCountsNameEveryTable`). **Not covered:** "Saved: …" / "Not saved." (a
system panel cannot be driven).

---

## 14. Restore — *Restore from a file…* and the comparison sheet (`RestoreSheet`)

**Purpose and origin.** 0.3. "A restore is the one move in the app that can take things away, so it is shown as a
comparison and the button that does it is red, quiet and last." He lost data to a restore in the web app
(2026-08-16), hence the rescue copy (§15).

**The button.** **"Restore from a file…"** — full width, min height 48, card fill + line border, radius 12, 17 bold
in Settings slate, id `backup-restore`. Press → status cleared; under the UI tests it reads the invented file
`SampleLibrary.fileToRestore()` ("Apple's file window cannot be driven by a test"), otherwise opens `.fileImporter`
for `.json`. Picked → security-scoped read → `offer(data)`; unreadable → "That file could not be read."; cancelled →
"Nothing chosen."

**Checking before offering** (`offer` → `LibraryModel.inspectBackup(data)`): parse the JSON and require
`BackupFile.looksLikeBackup`, else "That is not an AMS Packing backup file."; import it in memory with
`Importer.library(from:)`; if the import does not round-trip faithfully, "The import did not come back the same
(<n> rows differ), so nothing was stored."; otherwise `pending = PendingRestore(library)` → the sheet opens. Nothing
on the device changes until he confirms.

**The sheet** (container id `restore-detail`; `.frame(minWidth: 420, minHeight: 520)` on BOTH platforms):
- Header: **"Restore from a file"** (22 heavy ink) and **Cancel** (outlined `HeaderButtonStyle`, slate, id
  `restore-cancel`) → `answer(false)` + dismiss.
- "Everything on this device is replaced by what the file holds." (16 medium ink).
- Column heads **"The file"** and **"Now"** (15 heavy muted, 70 wide, right-aligned).
- A table, one row per table that has a count on either side, `meta` always left out ("the library's own
  bookkeeping … would only make the comparison look wrong"): the label (§16 names), the file's count (16 bold,
  RED when smaller than now, id `restore-file-<table>`), now (16 bold muted, id `restore-now-<table>`).
- If any table holds fewer in the file: **"This file holds less than this device does — "** + the three biggest
  losses, largest first, as "<label lower-cased> <file> against <now>", joined ", ", ending ", and more." when
  there are more than three, else "." (16 semibold red, id `restore-fewer`).
- "A copy of what is on this device now is written first, so there is a way back." (15 medium muted).
- **"Replace everything on this device"** — full width, min height 52, red fill, 17 bold white, id
  `restore-confirm` → `answer(true)` + dismiss.

**After the answer** (`pending = nil` first): no → status "Nothing was replaced."; yes → `model.restore(library)`:
(1) `RescueCopies.write(current)` — BEFORE anything is replaced; (2) `commit(imported)` — the record difference
between what was held and the file's library is applied to the store (everything not in the file is deleted);
(3) `reload()`. Then `copies` is re-read and status = "Restored from the file. A copy of what was here is kept on
this device."; an error → its description. Dismissing the sheet by swiping (iPhone) does not call `answer`, so the
status says nothing.

**Tests.** UI `testARestoreShowsWhatTheFileHoldsAndThenReplacesEverything` (device 10 things; file 2 vs now 10;
`restore-fewer` shown; Cancel changes nothing; confirm → 2 things, 0 trips). Model `RestoreTests`
(`testARestoreLeavesExactlyWhatTheFileHeldAndNothingOfWhatWasThere` — items, templates, no trips, no to-dos, no old
Settings-list entry, every table count equals the file's; `testTheFileHoldingLessThanTheDeviceIsVisibleInTheCounts`;
`testSomethingThatIsNotABackupIsNotReadAsOne`). **Not covered:** the error lines, "Nothing was replaced.", the ", and
more." wording, a restore onto an empty device.

---

## 15. *Kept before a restore* — rescue copies (`Store/RescueCopies.swift`)

**Purpose.** "A way back that he cannot reach is no way back, so they are listed here." A copy of the library is
written to this device BEFORE a restore replaces it — "never after" — so going back does not depend on his having
saved a file first.

**Storage.** Folder `Application Support/AMS Packing/rescue/` on this device only (never synced). File name
`before-restore-<ISO time with ":" replaced by "-">.json`, e.g. `before-restore-2026-09-22T23-04-11.123Z.json`;
content = the ordinary backup JSON (either app can read it). An EMPTY library writes nothing (and deletes nothing).
After each write the folder is pruned to the newest **3** (newest = file name sorted descending). Under the UI tests
the folder is emptied at launch.

**On screen** (only when at least one copy exists): **"Kept before a restore"** (15 heavy muted, 10 pt above, id
`rescue-heading`), then a card list, one row per copy, newest first: the moment written as **"22 September, 23:04"**
(16 medium ink; built from the file name — day number, English month name, hours:minutes; an unexpected name is
shown as it is) and **"Look at it"** (15 bold slate); min height 44; hairline under each; id `rescue-row-<n>`.
Tapping reads the file and goes through exactly the same `offer` → comparison sheet → confirm path as a chosen
file (an unreadable copy says "That is not an AMS Packing backup file.").

**Tests.** UI `testTheCopyKeptBeforeARestoreBringsEverythingBack` (no heading before any restore; after one: heading,
one row, no second; the copy holds 10 things; confirming brings 10 things and the 1 trip back). **Not covered:** the
three-copy limit, the date text, an empty library writing no copy.

---

## 16. *This device holds* and the version footer

**Purpose.** "What this device holds, table by table, so two devices can be compared by eye."

**On screen.** **"This device holds"** (15 heavy muted, 14 pt above), then a card with one row per storage table, in
`Table.allCases` order, ALWAYS all eleven (zero included): label (16 medium ink) and count (16 bold monospaced muted,
id `device-count-<table raw value>`), min height 40, hairline. Labels (`SettingsScreen.label`): `items` "Things",
`memberships` "Places on templates", `templates` "Templates", `trips` "Trips", `entries` "Trip lines", `actions`
"To-dos", `kits` "Kits", `phases` "Own "When" steps", `shared` "Choices", `photos` "Photos", `meta` "Notes about the
library". Last row: **"Synced through iCloud"** or **"On this device only"** (`model.usesICloud`) and the version
`AppInfo.version` = "<CFBundleShortVersionString> (<CFBundleVersion>)", e.g. "0.60 (2)" (both 15 semibold muted).

**Data.** `Library.counts` = for each `Table`, the number of records `library.records()` produces for it.

**Tests.** `testSettingsOffersABackup` (`device-count-items` exists), the restore tests (counts 10 → 2 → 10, trips
1 → 0 → 1), `testATripIsDeletedOnlyAfterAsking` and `testWorthALookRemovesAPhotoLeftBehind` (`device-count-photos`
0), model `testCountsNameEveryTable`.

---

## 17. Trip presets (`Core/Sources/PackingCore/Presets.swift`) — data only, no screen

**What it is.** A saved trip "recipe" from the web app — which activities and conditions — to spin up a similar trip;
dates, destination and lines are deliberately not part of it. **The native app has no screen that saves, lists or
applies presets**; it only carries them so nothing is lost: imported from a backup's `prefs.presets` into `shared`
rows of kind `presets`, kept and synced, and written back into every backup.

- `PresetConfig { mode ("trip"|"quick"), activities [String], transport (default "Car"), season (default "Summer"),
  contexts [String], catering (default "mixed"), weatherOn [String], laundry Bool }`.
- `presetConfigFromEvent(ev)`: copies those fields from a trip; mode is "quick" only when the trip's mode is "quick";
  empty transport/season/catering get the defaults. The JSON form: falsy → default, truthy non-text → "".
- `applyPresetConfig(ev, config)`: copies onto a trip, leaving name, dates, destination and lines alone; a missing
  or falsy key leaves the trip's value, EXCEPT `laundry`, which is always set (absent → off); a config that is not
  an object or array changes nothing; the result is not coerced.
- The row (`TripPreset { id, name, createdAt, config }`): key = normalised name (so saving again under the same name
  replaces it), `data = { config, createdAt }`; a preset without a truthy config is dropped (`{}` counts as one).
- Tests: `PresetsTests` (5: recipe not trip specifics; apply leaves name/dates/entries; round trip; defaults and the
  raw form; partial config always sets laundry), `SharedRowsTests.testPresetsReSavingUnderANameYouAlreadyUsedReplacesItNeverDoublesIt`,
  `testPresetsAnEmptyConfigIsAPresetAFalsyOneIsNot`, and the parity questions of §12 of QUESTIONS.md.

---

# Conventions every screen follows

## 18. Colours, light and dark (`Theme.swift`, `Sections.swift`, `docs/colours.md`, `Contrast.swift`)

**Purpose.** "The web app's colours, light and dark. He runs everything in DARK mode, so every colour here is a pair —
never a single hex." A colour is settled only once seen on the dark card as well as the light one (colours.md).

**Page and text tokens** (`enum Theme`, each a light/dark pair built with `Color(light:dark:)`, which wraps a
dynamic `NSColor` on the Mac — `bestMatch(from: [.darkAqua, .aqua])` — and a dynamic `UIColor` on the iPhone —
`userInterfaceStyle == .dark`; so a colour follows the system appearance live):

| Token | Light | Dark | Used for |
|---|---|---|---|
| `bg` | `#f4f6f7` | `#0e1416` | the page behind the cards (RootView, every sheet) |
| `card` | `#ffffff` | `#161f22` | cards, sheets, fields, the tab bar |
| `ink` | `#16232a` | `#e7edee` | text |
| `muted` | `#5f7078` | `#94a6ac` | secondary text, chevrons, ✕ marks |
| `line` | `#e2e8ea` | `#26343a` | hairlines and card borders (1 pt) |

**The six sections** (`enum AppSection: String, CaseIterable` — `home, events, templates, care, actions, settings`;
the same six, order and colours as the web app's tab bar; ONE sRGB hex each, the same in light and dark):

| Case (id) | Tab label | Colour | Hex | Drawn mark (24-unit box) |
|---|---|---|---|---|
| `home` | Home | blue | `#2f6fe0` | a suitcase: rounded rect 4,7.5 16×12.5 r2.2 + handle and two straps |
| `events` | Trips | green | `#2f9e63` | a calendar: rounded rect 3.5,5 17×15 r2 + a bar line and two rings |
| `templates` | Templates | violet | `#7c5cd6` | a list: three lines with three dots |
| `care` | Care | orange | `#dd7324` | a spanner (one SVG path) |
| `actions` | To do | red | `#dc3d43` | a ticked box: rounded rect 4,4 16×16 r2.5 + a tick |
| `settings` | Settings | slate | `#64748b` | a nut: a hexagon + an 8×8 circle |

The tab label of `events` is "Trips" and of `actions` is "To do" (his choice, test G.4, 2026-09-30; "Actions"
before 0.43), but identifiers keep the case names (`tab-events`, `tab-actions`) — "it never changes when a label is
reworded". Red `#dc3d43` is also the colour of every problem message (failed library, first-run problem, needs lines,
refused lines, restore warnings). Each section's colour is "the screen's colour": its buttons, headings and bands.

**Other fixed colours** (colours.md): grab-list tones (GrabScreen) blue `#3a86d4`, yellow `#c99700`, green
`#2e9e6b`, red `#cf5b52`, purple `#8a63c9`, teal `#17969b`, other `#64748b` — "mid-tones on purpose, so they read on
the light card and the dark one alike". Workout pills (`WorkoutTone.of(name)`, matched on `normName` with all white
space removed): swim `#0a84ff`/white, bike `#ffd60a`/`#3d3000`, run `#30d158`/`#0b3a17`, strength `#ff8c1a`/`#4a2300`,
breath work `#bf9cff`/`#2e1a5c`, mobility `#ff6fa8`/`#5a0f2e` (fill/words; light fills carry dark words — "white is
unreadable on yellow"). He does not like teal: "Do not use teal for anything new." `Color(hexString:)` (in
TemplatesScreen.swift) reads "#rgb"/"#rrggbb"; anything unreadable becomes slate `#64748b`.

**Readable chosen colours** (`Core/Sources/PackingLibrary/Contrast.swift`). Colours HE chooses (his "When" steps)
are used as text on light screens, dark screens and the green "all packed" screen; his screenshot 2026-09-26: "Bad
text color twice". `relativeLuminance(hex)` = WCAG relative luminance (sRGB linearised, 0.2126 R + 0.7152 G +
0.0722 B; nil for non-colours; accepts "#rgb", "#rrggbb", with or without "#"). `readableHex(hex, dark:, graphic:)`:
on a light screen, while luminance > 0.15 (a graphic: 0.35) multiply R, G, B by 0.92; on a dark screen, while
luminance < 0.25 (a graphic: 0.15) move each channel 8 % towards white; at most 40 steps; an already-readable colour
or a non-colour comes back unchanged; otherwise lower-case "#rrggbb". The hue is kept. Used for: a trip's "When"
section headings (text) and its tick circles (`graphic: true`), a template's "When" groups, the loop step names.
Tests: `ContrastTests` (`testEveryChosenColourReadsOnALightScreen` — ≤ 0.15 and ≥ 3:1 against `#b4dcc4`;
`testEveryChosenColourReadsOnADarkScreen` — ≥ 0.25; `testTheHueStaysAndADarkColourIsLeftAlone`).

**Dark mode, in practice.** Every surface uses the `Theme` pairs; section and tone colours are mid-tones that read on
both; user-chosen colours pass through `readableHex(…, dark: scheme == .dark)` with the view's `colorScheme`; the
`ClearMark` cross is cut out in `Theme.card` so it inverts with the theme. Nothing forces an appearance. UI tests
cannot read colour; the `shot()` helper exists so screens are LOOKED at (day and night) before release.

## 19. Drawn marks — no stock icons, no emoji (`SVGPath.swift`, `SectionMark`, `TemplateIcons.swift`)

**Rule.** "The web app's pictures are all hand-drawn SVG. Reading their path data directly means every mark here is
the SAME drawing, not a re-tracing of it." No SF Symbols, no emoji, no stock art anywhere in the app's own chrome
(TemplateIcons: "No stock art, no emoji (his rule)"). Text glyphs ⊘ ↻ ✕ × ▲▼ ⓘ appear inside sentences and a few
labels.

**`SVGPath.path(_ d: String) -> Path`** parses SVG path data: commands M L H V C S Q A Z, absolute (upper case) and
relative (lower case); numbers may be written "2.1-.6-.6" (a sign or a second dot starts a new number);
separators are spaces, commas, tabs, new lines; extra coordinate pairs after M are lines (L / l); S mirrors the
previous curve's second control point (or uses the current point); A is converted to cubic curves with the W3C
endpoint-to-centre method (radii scaled up when too small; zero radius or equal ends → a straight line; split into
≤ 90° pieces); arc flags are single digits that may be run together. Any other command → `assertionFailure`
("SVGPath cannot draw …") so a debug/test build stops loudly; a release build returns what was drawn so far. History:
an unknown command used to end the drawing silently and the map pin on Trips was invisible (0.37, 2026-09-27).

**Marks in use.** Chevron `M9 6l6 6-6 6` (doors, fold arrows — rotated 90° when open), cross `M6 6L18 18M18 6L6 18`
(remove), `PenMark` (`M15.2 5.3L18.7 8.8L8.6 18.9L4.3 19.7L5.1 15.4ZM13 7.5L16.5 11M5.1 15.4L8.6 18.9`, Trip
settings), `ShareMark` (a box with an arrow up), `ClearMark` (a muted disc with `M8.5 8.5L15.5 15.5M15.5 8.5L8.5 15.5`
cut out in card colour, line 2.2), the six section marks, 50 template icons (`TemplateIcons`, one stroke, round
ends, 24-point box, only the commands SVGPath draws). Strokes are round-capped and round-joined, usually 1.8–2.4.
Marks are `.accessibilityHidden(true)` where words already say it (Pen, Share, Clear, a template cover).

**`SectionMark(section, size = 24, weight = 1.9)`** scales the mark by size/24 and strokes it with
`weight × size/24`. Used in the tab bar, the How-it-works topics, the loop picture and placeholders.

**Data emoji.** Emoji that are DATA (a phase's or template's emoji imported from the web app) are not drawn, with one
exception: a template's `Cover` shows `list.emoji` as text when the template has no icon (his covers "are his data").

## 20. Buttons (`Buttons.swift`, `SmallDelete.swift`) and the "main button never grey" rule

**The rule** (his standing rule, 2026-09-26): "the app's central button is ALWAYS full colour; pressed too early it
says what's missing under it. Never disable+grey a primary action." Until the field test of 3 Oct 2026 the Add / New
/ Make buttons sat grey and switched off until something was typed; 0.34 had already fixed *Make the template*. No
`.disabled(…)` is put on a main action; the press validates and answers in words.

**`HeaderButtonStyle(tint:, filled: true, stretch: false)`** — the buttons at the top of sheets (Done, Save: filled;
Cancel, Share, Edit, Close: outlined). His words (test H.10, 2026-09-28): "make the Done and Share buttons visually
pleasing all over the app". Label 16 bold; white on a capsule filled with the tint, or tint-coloured on a 10 % tint
capsule with a 1.4-pt tint outline; never cut (`lineLimit(1)` + `fixedSize()` — the "D…" of 0.40's photos); padding
14 horizontal; min height 36; the whole capsule is the hit area; 70 % opacity while pressed; `stretch` makes it share
a card row's width. Used 47 times. (Callers also attach `.font(17 bold)` and a foreground colour outside the
button; the style's own 16 bold / white-or-tint wins.)

**`FieldButtonLabel(title:, tint:)`** — the button beside a field that takes what was typed (Add, New, Make): 16 bold
white on a tint-filled rounded rectangle (radius 10), padding 16, min height 44, never cut. Used by: Your choices
(Add, slate), To buy (Add, red), a trip (Add, green), a template (Add; a row's new section Add — violet), a grab list
(Add, its tone), Your things (New, orange), To do (Add, red), Your bags (Add, orange), Grab Lists (Make, blue).

**`.needsLine($says, typed:, id:)`** (`NeedsLine` modifier) — puts the content and, when `says` is not empty, a line
under it: 15 bold, To-do red, wraps, with the given id. It clears itself as soon as `typed` changes ("it never
outstays the problem it was about"). Convention: the id is `<button id>-needs` (`thing-new-needs`, `bag-new-needs`,
`buy-add-needs`, `grablists-new-needs`, `grab-add-needs`, `list-<kind>-add-needs`, `template-add-needs`,
`template-rename-needs`, `row-section-add-needs`, `trip-add-needs`, `action-add-needs`, `weather-look-needs`). Other
"needs" lines built by hand follow the same naming: `trip-create-needs`, `tripset-needs`, `tripset-again-needs`,
`newlist-needs`, `onsite-bought-needs`, `onsite-note-needs`, `range-needs`.

**`WideButtonLabel(title:, tint:, mark:)`** — the wide outlined buttons at the foot of a trip (Save as Excel, Share):
a 22×22 drawn mark and the word (17 bold, scales to 80 %), tint colour, full width, min height 48, 8 % tint fill,
1.4-pt tint border, radius 12.

**`.clearButton($text, id:)`** (`ClearButton` modifier) — the ✕ at the end of a search field; their field test
(3 Oct 2026): "please add an X so that it's quick to delete all typed alphanumeric characters". It names the FIELD
`id` (on the field itself — an id on the whole row would also reach the ✕) and, only while the text is not empty,
shows a `ClearMark` 24×24 in a 36×36 hit area, trailing padding −6, id `<id>-clear`, VoiceOver "Clear the search";
one tap empties the text and the keyboard stays. Uses: `things-search`, `pick-search`, `search-field`,
`table-search`, `template-find`, `filter-narrow`, `onsite-leave-search` / `onsite-note-search` (via `LinePicker`).
The way-home search draws its own ✕ instead (`wayhome-search-clear`, 44×44, a plain cross) — see Open questions.

**`SmallDeleteButton(title:, id:, action:)`** — his mark (2026-09-26): "Delete should be a small button at the side."
Right-aligned; 13 semibold red words in a capsule outlined in red at 60 %, padding 12, min height 30. It only ever
OPENS the question, never deletes by itself. Uses: Delete bag (`bag-delete`), Delete trip (`trip-delete`), Delete
template (`template-delete`), Delete thing (`thing-delete`).

**Every plain button** gets `.buttonStyle(.plain)` and `.focusEffectDisabled()` (no keyboard focus ring on the Mac)
and an explicit `.contentShape` so the whole drawn area takes the tap. There are no keyboard shortcuts anywhere
(`.keyboardShortcut`, `onExitCommand`: none).

**Tests.** `testEveryAddButtonIsReadyAndSaysWhatIsMissing` (Your things New + the line goes after typing, Your bags,
To buy, Grab Lists Make, a grab list's Add, Your choices' first Add, a template's Add, Rename to another template's
name, a row's new section, the trip Weather button; each must exist, be ENABLED, and answer on `<id>-needs`; all
failures are listed in one message). `testHomeBuildsATrip` (Create trip enabled, `trip-create-needs`). The ✕:
`testTheCrossEmptiesASearch` (Your things, the magnifier search, Choose from your things),
`testTheCrossKeepsTheKeyboard`. Deletes: `testATripIsDeletedOnlyAfterAsking`, `testAThingIsDeletedOnlyAfterAsking`,
`testABagIsRenamedAndDeletedFromItsPage`. **Colour cannot be tested**: "A colour cannot be read by a test; being
pressable and answering can."

## 21. Headings, pills and type sizes (`Headings.swift`, `Pills`/`FlowRow` in `HomeScreen.swift`)

**Origin.** Field test 3 Oct 2026 (mission 4.4): "adjust the headings so that they are dominant, and the other buttons
and pills are much smaller than the heading … throughout the app". Earlier: his sketch 2026-09-27 ("make the headings
pop"), 2026-09-28 ("should be larger or in capitals, as should all headings on the Care tab"; "Much larger headings,
please", H.13).

**Sizes** (`enum HeadingSize`): `band` 22, `title` 20, `question` 17 — all heavy. "Nothing under 15, so it still
reads without glasses."

- **`HeadingBand(title:, tint = Care orange, id:)`** — a block's heading: a 5×26 solid capsule mark, the words (22
  heavy, tint, wrap — never cut), on a full-width strip of the tint at 13 %, padding 10×9, radius 10. Used by Your
  choices, the thing and row editors, `Pills(heading: .band)`.
- **`HeadingTitle(title:, tint = ink, id:, question = false)`** — a heading inside a block: a 4×18 capsule mark aligned
  to the baseline and the words (20 heavy, tint); as a `question` (Laundry nights, Context, the review): no mark, 17
  heavy, ink.
- **`SectionTitle(title:, tint = ink, id:)`** — a heading that starts a part of a screen: the words UPPER-CASED, 18
  heavy, letter-spaced 0.8, 16 pt above (Care, Templates, Settings' BACKUP).
- **`Pills(title:, options:, selected:, id:, tint = Home blue, startIndex = 0, heading = .title, tones:, choose:)`** —
  a heading (band / title / question, id `<id>-title`) over pills in a `FlowRow(spacing: 6)`. Each pill: its words 15,
  bold when picked, medium when not; padding 12, min height 36 ("still 36 tall to press"); picked = filled with its
  tone or the tint, white (or the tone's dark) words; not picked = `Theme.bg` fill, ink words, outlined in `line`
  (1 pt) or, for a toned pill, in its tone (1.8 pt). Id `<id>-<startIndex + position>` — "its position — never its
  words"; picked pills carry the `.isSelected` trait (what tests read). `ContextPills` puts Context (Indoor, Outdoor,
  Race) as a `.question` row indented 18 with a 3-pt grey line down its side, in the Settings slate.
- **`FlowRow(spacing = 8)`** — a `Layout` that places children left to right at their natural size and wraps to a new
  row when the next one would pass the right edge; row height = tallest child; reported width = the proposed width
  (10 000 if none).

**The font floor in fact.** The floor of 15 holds for headings, pills, buttons and the main lines. Secondary lines are
smaller in many places: in this chapter's screens the door sub-lines and Reminders sub-line (14), *Your choices*' use
counts and footer (14), Worth a look's names and closing line (14), the sync pill (13), What's new dates (14), part
names and "On this device" (12), the loop's short lines (14), "on <tab>" and "You are here" (13), `SmallDeleteButton`
(13), the tab labels (12.5) and the version marker (11). Across the app 166 `.system(size:)` values below 15 appear in 42 (of 67)
files. See Open questions.

**Tests.** `testTheEditorsLeadWithTheirHeadings` (every heading id on the thing editor, the row editor, Create new
trip, Trip settings, the review and Your choices exists; photographs each), `testWhoseItIsOffersEachOwnerOnce` (a
22-pt heading line is at least 25 tall; a pill at least 36 tall), `testContextSitsUnderTheWorkouts`.

## 22. Scrolling and the keyboard (`KeyboardAwayScroll` in `Theme.swift`)

`KeyboardAwayScroll { … }` = `ScrollView { content }.scrollDismissesKeyboard(.immediately)`: "on the phone the
keyboard covers the tab bar, and dragging the list is how a person gets it out of the way." It is the scroll container
of 40 screens and sheets (Settings, Your choices, the guide, the restore sheet among them). The exceptions use a plain
`ScrollView`: the grab-list menu, the two-way grid and the chip strip of the things table, and the way-home photo strip.
The UI tests depend on it: `hideKeyboard` swipes the biggest list because "every screen uses
scrollDismissesKeyboard(.immediately)".

## 23. Accessibility identifiers, and the Mac rules

**Standing rule** (README, his words 2026-09-16): every control is found by its `accessibilityIdentifier`, never by
its words, "so rewording a button can never turn the suite red".

**Naming scheme** (from the code):
- Tabs `tab-<section>`; screens `screen-<section>` (built from the enum's raw value, never the label); the version
  marker `app-version`; a failed library `library-problem`; an unbuilt section's placeholder title `screen-title`.
- A sheet or page is a container named `<thing>-detail` or `<thing>-screen` (`lists-detail`, `restore-detail`,
  `things-detail`, `trip-detail`, `tripset-screen`, `loop-screen`, `guide-whatsnew`…); its buttons
  `<thing>-done`, `-cancel`, `-save`, `-confirm`.
- Rows and pills by POSITION: `<prefix>-row-<n>`, `<pill id>-<n>`, `guide-release-<n>`, `guide-topic-<n>`,
  `word-<n>`, `quickstart-step-<n>`, `loop-step-<n>`, `health-<n>`, `rescue-row-<n>`.
- Per-table numbers by table raw value: `device-count-<table>`, `restore-file-<table>`, `restore-now-<table>`.
- Derived parts: `<pill id>-title` (a pill row's heading), `<button id>-needs` (§20), `<field id>-clear` (§20),
  `<row id>-fix` / `-names`, `list-<kind>-add-name` / `-add` / `-remove-<n>`.
- Settings doors: `settings-lists`, `settings-reminders(-card|-next|-refused)`, `settings-whatsnew`,
  `settings-howitworks`, `settings-firsttrip`, `settings-openshared`.

**Container rule.** "A named container must say it CONTAINS its children, or it swallows their identifiers and the
tests cannot find anything inside it": every named container gets `.accessibilityElement(children: .contain)` before
its id (RootView's screens, cards, sheets). A few deliberate `.combine` / `.ignore` elements carry their words as one
label (`quickstart-step-<n>`, `loop-step-<n>`).

**The Mac rules** (each cost a red run):
1. On the Mac a Button (and a Toggle) folds ALL its child texts into its own label, while the iPhone keeps them as
   separate elements; and a button inside a button never reaches the tree at all on either platform. So a text a
   test must read lives OUTSIDE the Button/Toggle, side by side with it (the trip section name beside its fold arrow;
   *Remind me to pack*'s next line under the Toggle; the What's-new version as a plain text), or the button exposes it
   as its `accessibilityValue` (`trip-dates-field`), or a non-control box puts it in its LABEL — the Mac drops the
   value of a box that is not a control (`loop-step-<n>`). Rows that are buttons are read through `app.buttons[id]`.
2. The Mac reports a text's words as its VALUE, the iPhone as its LABEL — the tests' `words()` reads both.
3. A Toggle is a switch on the iPhone and a check box on the Mac; a dropdown is a button on the iPhone and a pop-up
   button on the Mac (`switchNamed`, `cellSays`).
4. A bare `Map` is reported as its own element kind on the Mac: name a container around it (`map-view`).
5. Window sizes under tests (§24): the main window is SET to 760 × 674 — GitHub's Mac runner's window, "read off its
   TAP-REPORT" — so a control below the fold there is below the fold here too; the things-table window opens at
   760 × 620 under tests (1180 × 780 otherwise).
6. A Mac window left open is restored at the next launch and covers the app: the table window has
   `.restorationBehavior(.disabled)` and `.defaultLaunchBehavior(.suppressed)` (0.58: every later UI test failed).
7. Frames, not `isHittable`: the runner calls a control below the window "hittable"; tests judge by frames.
8. The Mac UI job runs on macOS 26: on the older runner's SwiftUI a click on a pill "succeeded" and selected nothing.

---

# The app frame

## 24. Windows, tab bar, version marker and launch modes (`AMSPackingApp.swift`, `RootView.swift`, `LibraryModel.forThisLaunch`)

**Scenes.** One `WindowGroup` showing `RootView` with the shared `LibraryModel`. Mac only: content frame min 480 ×
600, ideal 760 × 900; `.defaultSize(760, 900)`; on appear `useTheRunnersWindowSize()`. Mac only: a second scene
`Window("All your things", id: ThingsTable.windowId)` (the table, his ask 4 Oct 2026: "I would like it wider"), default
1180 × 780 (760 × 620 under tests), `.windowResizability(.contentMinSize)`, restoration disabled, launch suppressed.

**`useTheRunnersWindowSize()`** (Mac, only when testing): on the next main-queue turn, every visible titled window is
set to x = its own, top edge kept, 760 wide, 674 tall. "Set, not suggested: macOS restores a window's last size and
ignores size limits on the content."

**`RootView`.** `VStack(spacing: 0)`: the current section's screen, at most 720 wide ("the web app's column, on the
Mac"), centred; under it the tab bar; `Theme.bg` behind, ignoring safe areas. Starts on Home. On appear: the
reminders' tap handler (→ Home + `tripToOpen`) and `PackingReminders.start()`. The library publisher, debounced 2 s:
reschedule reminders and update the Shortcuts parameters. Scene becomes active: read back Reminders ticks and
(0.6x) reschedule the packing reminders. A Shortcut asking for a grab list, the grab menu or a trip switches to
Home; `model.tabToOpen` (0.6x; Search's to-do) switches to that tab. Under the UI tests only, a return from the
background plays the `-…OnReturn` arguments below.

**`SectionScreen`.** By `(model.state, section)`: `.failed(why)` on any tab → the reason, 17 semibold, red, centred,
id `library-problem`; `(.empty, .home)` → `FirstRunView`; `(.ready, …)` → the tab's screen; `(.ready|.empty, .settings)`
→ Settings; anything else (loading; an empty library on Templates, Trips, Care, To do) → a placeholder: the section's
mark at 96 pt (line 1.6) in its colour and its label (34 heavy, id `screen-title`). Container id `screen-<section>`.

**Tab bar.** Six equal buttons (plain, no focus ring, id `tab-<section>`, VoiceOver label = the tab label, selected
trait on the current one). Each: the mark (24 pt) on a 46 × 30 capsule — active: white mark (line 2.2) on the
section colour; inactive: the mark in its colour (1.9) on its colour at 14 %; under it the label (12.5, heavy and ink
when active, semibold and muted otherwise, one line, scales to 80 %); min height 54. Below the buttons, in its own thin
row so it can never sit on a label: the build marker `AppInfo.version` (11 semibold, muted at 70 %, right-aligned,
8 from the edge, not tappable, id `app-version`). The bar: at most 720 wide, `Theme.card` behind (to the bottom edge),
a hairline on top, 6 above, 2 below.

**`AppInfo`.** `version` = "<CFBundleShortVersionString> (<CFBundleVersion>)" ("?" for a missing one) — "the number on
screen and the number TestFlight shows can never disagree"; `marketing` = the short version alone.

**Launch modes** (`AMSPackingApp.testing` = any launch argument starting `-uiTesting`):

| Argument | Library | Notes |
|---|---|---|
| `-uiTestingEmpty` | memory, nothing | first-run screen |
| `-uiTestingChecks` | memory, `SampleLibrary.checks()` | |
| `-uiTestingOnSite` | memory, `SampleLibrary.underWay()` | |
| `-uiTestingOldPhoto` | memory, `SampleLibrary.oldPhoto()` | |
| `-uiTestingTwoLibraries` | memory, `SampleLibrary.doubled()` | |
| `-uiTesting` | memory, `SampleLibrary.make()` | checked last |
| (none) | SwiftData; iCloud when the Info.plist key `PackingUsesICloud` is "YES" | a failure to open → `.failed("The library could not be opened: …")` |
| `-openGrab <label or title>`, `-openGrabMenu`, `-openNextTrip` | (testing only) play a Shortcut | |
| `-pretendShopTicks` | (ShopReminders) pretend ticks in Reminders | |
| `-pretendRemindersBlocked` | (PackingReminders) switched on earlier, then blocked in the device's Settings | 0.6x |
| `-openGrabOnReturn <label or title>`, `-openNextTripOnReturn`, `-dropOwnGrabListsOnReturn` | (testing only) played when the app returns from the background: a Shortcut, a tapped reminder, the other device's write that no longer holds his own grab lists | 0.6x |
| `-importFile <path>` | DEBUG builds only, not testing: import a backup into an EMPTY library at launch | keeps real data out of the repository |

Under testing, `usesICloud` is false, the forecast is `InventedForecast`, the rescue copies are deleted at launch,
reminders never touch the system, grab-list state is not persisted (`GrabStore(persistent: false)`), and these
`UserDefaults` keys are removed so every test starts from the same screen: `ams.table.columns`, `ams.table.sort`,
`ams.table.down`, `ams.table.then`, `ams.table.filters`, `ams.care.view`, `ams.view`, `ams.trip.folded`,
`ams.template.grouping`, `ams.pick.grouping`, `ams.pick.folded`, `ams.reminders`.

**Tests.** `testStartsOnHomeAndNamesItsVersion` (Home, a digit in `app-version`), `testEveryTabOpensItsScreen` (each
tab opens its screen and Home is gone; the To-do tab's words start "To do"), `testAnEmptyDeviceShowsTheTwoDoors`.

## 25. The invented sample library (`App/Sources/Store/SampleLibrary.swift`)

"An invented library for the UI tests (`-uiTesting`). Nothing of his is in here — this repository is public." Dates are
always relative to the day the tests run (`day(n)` = today + n on a Gregorian calendar in the device's time zone,
"YYYY-MM-DD"): the first version had fixed dates and on those very days the trip was under way and "an empty Now"
went red.

**`make()`** — built in this order:
1. Template **Common base** (`role: "base"`, no group): Passport, Phone charger, Toothbrush, Headlamp.
2. Template **Hiking** (group `GA`): Hiking boots, Rain jacket, Headlamp, Map. `saveTemplate` matches by name, so the
   Headlamp is ONE thing on two templates. 8 things so far.
3. Care: Hiking boots — maintenance notes "Clean and wax", every 90 days, last done 2025-01-01 (always overdue); Rain
   jacket — notes "Wash with tech wash, no softener", no schedule.
4. Weights (g), places and owners are applied to the things that exist NOW (the 8):

   | Thing | Weight | Place | Owner |
   |---|---|---|---|
   | Hiking boots | 1250 | Hall closet | Kim |
   | Rain jacket | 420 | Hall closet | Kim |
   | Headlamp | 88 | Garage | Kim |
   | Map | 60 | Garage | Kim |
   | Passport | 35 | Chest of drawers | Kim |
   | Phone charger | 120 | Chest of drawers | Robin |
   | Toothbrush | 18 | Bathroom cabinet | Robin |

   The dictionaries also hold Towel 340 g / Bathroom cabinet, Goggles 45 g / Bathroom cabinet and Swim cap 20 g, but
   those things are created only in step 7, so they get NO weight and NO place (the UI tests rely on Goggles, Swim
   cap and Towel being under "No place set"). Neither owner is on the owners list (the "Whose it is" bug shape).
5. Review history: Map packed 3, used 0, unused 3; Headlamp packed 0, skipped 2; Hiking boots packed 1, used 0,
   unused 1 (one quiet trip — not evidence).
6. Map condition `retire` (Needs replacing); Toothbrush `consumable` — two different reasons for To buy.
7. Template **Swim** (group `WET`): Goggles, Swim cap, Towel → 10 things. Towel `perNight` = true (only Swim holds it,
   so the trip's counts do not change).
8. Hiking gets a section **Lights**; the Headlamp's place on Hiking moves into it.
9. One trip, **"Weekend in the hills"**, today + 30 → today + 32, activities = [Hiking], lines =
   `buildTotalEntries(trip, resolvedTemplates())` (Hiking plus the common base, as every non-Quick trip).

Result: 3 templates, 10 things, 1 trip, nothing in `shared`, `phases` or `meta`; every thing in the default bag
"Carry-on / hand luggage".

**Variants:**
- **`checks()`** (`-uiTestingChecks`): `make()` + a bag "Carry-on / hand luggage" (`addBag`: it makes the bag
  template "Containers" — shown as "Bags" — and, as no thing has that name, a NEW thing of that name on it); two new
  things (`addThing`) put on Common base: Pocket knife (`restricted`), Sun cream (`liquid`, expiry today + 25 — runs
  out during the trip); Passport becomes category Documents & money with expiry today + 180 (about five months after
  the trip); the trips are replaced by **"Sunny weeks"**, today + 20 → today + 34, transport Plane, activities
  [Hiking], made with `createTrip`. Result: 4 templates and 13 things (10 + the bag + 2) — no test reads that count.
- **`underWay()`** (`-uiTestingOnSite`): `make()` with the trip moved to yesterday → today + 2 (it stands at On site);
  the Passport has the note "Keep it dry".
- **`oldPhoto()`** (`-uiTestingOldPhoto`): `make()` + a photo record id `left-behind`, data
  `data:image/jpeg;base64,AQID`, created 2026-01-01T09:00:00.000Z, used by nothing.
- **`doubled()`** (`-uiTestingTwoLibraries`): `make()` + every template again under new ids, same name, group and
  role, its things re-added by name (so the same 10 things sit on 6 templates).
- **`fileToRestore()`**: a DIFFERENT library as backup bytes (exportedAt 2026-09-22T09:00:00.000Z): one template "Day
  out" (`role: "base"`) with Water bottle and Sun hat — 2 things where the device holds 10, "so a restore that only
  ADDS would be caught". Read by *Restore from a file…* under the tests.

---

# How the app is built, tested and shipped

## 26. The project (`project.yml`, `App/Config/*`, `Core/Package.swift`)

**Generated, not committed.** `project.yml` is an XcodeGen spec; `xcodegen generate` writes `AMSPacking.xcodeproj`
(every script and workflow runs it first). "One target for the iPhone and the Mac, like AMS Coffee."

- **Project:** name `AMSPacking`; bundle id prefix and `DEVELOPMENT_TEAM` set in the file (the owner's); deployment
  targets **iOS 18.0, macOS 15.0**; automatic signing; Swift language mode 5.0; **`MARKETING_VERSION` "0.60"**,
  **`CURRENT_PROJECT_VERSION` "2"** (local builds; TestFlight overrides the build number with the run number).
- **Package** `PackingCore` at `Core/` (Swift tools 5.9; platforms iOS 17 / macOS 14) with products `PackingCore`
  (the port of the web app's `js/model.js` — pure logic) and `PackingLibrary` (the library in memory, records, import,
  backups; depends on PackingCore), the executables `parity` (depends on PackingCore only — public API) and
  `import-check` (PackingLibrary), and the test targets `PackingCoreTests`, `PackingLibraryTests`.
- **Target `AMSPacking`** (application, destinations iOS and macOS): sources `App/Sources`, `App/Resources` (asset
  catalogue: `AppIcon`, `AccentColor`); depends on both library products. Bundle id `<prefix>.AMSPacking`.
  `TARGETED_DEVICE_FAMILY` "1" (iPhone only, no iPad); `INFOPLIST_FILE` `App/Config/Info.plist`, not generated;
  `PACKING_USES_ICLOUD` "NO" by default.
- **Entitlements, plain build** (`AMSPacking.entitlements`, generated from project.yml): app sandbox,
  user-selected files read/write (Save and Open windows), personal-information.calendars (Reminders on the Mac). No
  iCloud: an ad-hoc-signed Mac app carrying iCloud entitlements is refused at launch, and that is how CI builds.
- **Entitlements, syncing build** (`AMSPacking-iCloud.entitlements`, hand-written): the three above + network client
  (a sandboxed Mac app may not reach iCloud without it), the iCloud container `iCloud.<bundle id>`, CloudKit, the
  container environment `Development`, the sandbox exception `mach-lookup` for `com.apple.cloudd` ("Without this the
  sandbox denies the app the CloudKit daemon and nothing syncs", found 2026-09-22; with it 1,438 records went up and
  came back to a wiped device in 10 s), `com.apple.developer.aps-environment` `development` (silent pushes).
- **Info.plist keys:** CFBundleDisplayName "Packing", CFBundleName "AMS Packing", versions from the build settings,
  CFBundleIconName AppIcon, LSApplicationCategoryType `public.app-category.travel`, ITSAppUsesNonExemptEncryption NO,
  NSRemindersFullAccessUsageDescription and NSRemindersUsageDescription "Your To buy list goes into Reminders, to
  take to the shop; what you tick there is ticked here.", NSCameraUsageDescription "A photo of a packed bag, kept with
  the trip, to repack from on the way home.", `PackingUsesICloud` = `$(PACKING_USES_ICLOUD)` (read at launch),
  UIBackgroundModes [remote-notification], UILaunchScreen (empty colour name), UISupportedInterfaceOrientations
  [Portrait] — "portrait by design, like the web app on the phone".
- **Target `AMSPackingUITests`** (UI-testing bundle, iOS and macOS), `TEST_TARGET_NAME` AMSPacking, generated
  Info.plist. **Scheme `AMSPacking`**: builds the app; tests `AMSPackingUITests` and the package's
  `PackingCoreTests` (not `PackingLibraryTests`, which only `swift test` runs). So the two UI jobs of CI and
  `tools/build.sh test` run `PackingCoreTests` as well (on the simulator / the Mac) — the "quick model tests" the
  timeout comment mentions — while `PackingLibraryTests` run only in the `core` job and `tools/test-core.sh`.

## 27. CI on every push (`.github/workflows/tests.yml`)

"Every push runs the suite — the model's own tests, then the UI tests on the iPhone AND on the Mac … A red run means
the build is not fit to install." Triggers: push, pull_request, manual, and `workflow_call` (the TestFlight workflow
runs it first). Four jobs, in parallel:

| Job | Runner | Timeout | What it does |
|---|---|---|---|
| `core` — The model (Core package) | macos-15 | 15 min | `cd Core && swift test` (both model test targets; 662 model tests in the repo) |
| `parity` — Parity with the web app's model | macos-15 | 20 min | checks out the web app's repository into `web-app/`, Node 22, `PARITY_MODEL=$PWD/web-app/js/model.js tools/parity/run.sh --invented` (§31) |
| `iphone` — UI tests — iPhone | macos-26, newest Xcode on the runner (since 5 Oct 2026: on macos-15 the tests ran under Xcode 16.4 on an iOS 18 simulator, a pairing no shipped build has, and the template search's ✕ failed there) | 120 min | xcodegen; picks the highest-numbered available iPhone simulator (`sort -V`), falls back to any iPhone, fails if none; boots it and waits (`bootstatus -b`) — a cold simulator once cost the first test 95 s; `xcodebuild test` with `-collect-test-diagnostics never -test-timeouts-enabled YES -maximum-test-execution-time-allowance 480`, unsigned (`CODE_SIGNING_ALLOWED=NO`); on failure uploads `TestResults-iPhone.xcresult` |
| `mac` — UI tests — Mac | macos-26 | 120 min | xcodegen; `xcodebuild test -destination platform=macOS`, allowance 300 s per test, signed ad hoc (`CODE_SIGN_IDENTITY="-"`, manual style, no team, no profile — "a Mac app cannot be driven unsigned"); on failure uploads `TestResults-Mac.xcresult` |

Timeout history (comments): 30 min outgrown at 48 tests (0.25), 55 nearly outgrown at 67 tests (0.46), 120 since 108
UI tests (0.58) when the iPhone job passed every test and was cancelled at 80 minutes. There are 110 UI tests now
(including the warm-up).

## 28. Shipping to TestFlight (`.github/workflows/testflight.yml`, `tools/release-to-testers.py`, `TESTFLIGHT.md`)

Started by hand (Actions → TestFlight → Run workflow) with an optional `notes` input. "A red suite must never reach a
device": job `tests` calls `tests.yml`; job `upload` (`needs: tests`, macos-26, 60 min) then:
0. Checks out with `fetch-depth: 30` and runs `tools/check-spec.sh` ("The specification moved with What's new",
   since 0.61): the last commit that changed `App/Sources/Guide/Releases.swift` must also change `docs/spec/`, or the
   job stops with "What's new changed in <commit> without docs/spec — update the specification in the same commit".
   With no such commit within reach it passes. His rule, 4 Oct 2026: every nit documented.
1. Selects the newest Xcode on the runner (Apple refuses uploads built with an older SDK).
2. Checks the four secrets exist — `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID` — and names the
   missing ones. 🚨 The key must have the **Admin** role: an App Manager key uploads but fails cloud signing ("Cloud
   signing permission error").
3. xcodegen.
4. Numbers the build: `APP_VERSION` = `MARKETING_VERSION` read from project.yml (fails if absent); `BUILD` = the
   workflow's run number (unique, as Apple requires).
5. Entitlements for a build that ships: from the iCloud file, `Development` → `Production` and `development` →
   `production` (`AMSPacking-Ship.entitlements`, Mac); a copy with the push key renamed to the iPhone's
   `aps-environment` (`AMSPacking-Ship-iOS.entitlements`) — with only the Mac's name the iPhone never got iCloud's
   "something changed" notice (his test A.4, 2026-09-28; fixed in 0.44). Both are grep-checked.
6. Writes the key file (CR stripped, blank lines dropped, mode 600) and verifies its BEGIN/END lines and that
   `openssl pkey` reads it.
7. Archives for `generic/platform=iOS` and `generic/platform=macOS` with `-allowProvisioningUpdates` and the API key
   (registers the bundle id and iCloud container on the first run), automatic signing, the matching entitlements,
   `PACKING_USES_ICLOUD=YES`, the version and build; each must log "** ARCHIVE SUCCEEDED **".
8. Exports and uploads both (`method app-store-connect`, `destination upload`, automatic signing, symbols uploaded,
   `manageAppVersionAndBuildNumber` false, the team id added) — cloud signing; each must log "** EXPORT SUCCEEDED **".
9. Releases them to the tester group (`release-to-testers.py`, env `ASC_KEY_PATH`, `BUILD_VERSION`, `APP_BUNDLE_ID`,
   `TESTER_GROUP` — the group's name is written into the workflow):
   "A successful upload does NOT put a build in TestFlight … an internal group does not pick new builds up by itself."
   It signs its own ES256 JWT with openssl (10-minute tokens), finds the app by bundle id, polls `/v1/builds` for this
   build number every 30 s up to 60 times (30 minutes) until BOTH the iPhone and the Mac build are VALID or
   PROCESSING (with only one after 30 minutes it warns that one device will not get it), finds the beta group by
   name (missing → error), POSTs each build to the group, then lists the group's builds and warns when this number
   is there fewer than 2 times. 🪤 0.27 (build 33): the old loop gave up after 5 minutes with one build and the Mac
   never got it.
10. Only when every step before it succeeded (`if: success()`): writes the run's step summary — "### Sent to
    TestFlight — iPhone and Mac", "AMS Packing <version>, build <n>.", "Apple processes it for a few minutes, then it
    appears in TestFlight on both devices." and, when notes were given, a blank line and "What is new: <notes>"
    (written with `printf '%s'`). The `notes` input reaches this step through an environment variable (`NOTES`),
    never pasted into the script: 0.59's notes held quotes ("Both have one") and the pasted text broke the shell —
    after the build had gone out, so a good release showed as failed. The notes go only into this summary, not to
    App Store Connect or the testers.
11. Always (`if: always()`) uploads `build/*.log` as `testflight-logs` (nothing to upload is not an error).

One-time owner steps (TESTFLIGHT.md): create the app record with BOTH platforms in App Store Connect; create the
internal tester group; set the secrets; deploy the CloudKit schema to Production before the first shipped build can
sync (and again when records start using a new field — docs/store.md: the first bag photo sank every send until
`CD_blob` and `CD_blob_ckAsset` were deployed).

## 29. Crash reports (`.github/workflows/crash-reports.yml`)

Manual, `how_many` (default 3, clamped 1…20), ubuntu-latest, 10 min. With the same API key (read only) it finds the
app, fetches the newest `betaFeedbackCrashSubmissions` (sorted by `-createdDate`), prints for each its date, comment,
device model, OS, platforms and bundle id, then its crash log text ("Apple sent no crash log text…" when there is
none), writes each to `crash-reports/<n>-<date>.txt` and always uploads the folder as `crash-reports`.

## 30. Local tools (`tools/`)

- **`tools/build.sh [build|test] [iphone|mac] [icloud]`** — clears extended attributes from every file except inside
  `.git` (anything under `~/Documents` collects them and codesign refuses "detritus"), runs xcodegen, builds or tests
  with derived data in `$TMPDIR/AMSPacking-build` (outside Documents). iPhone destination: the simulator named
  "iPhone 18 Pro", OS 27.0; Mac: `platform=macOS`. `test` adds `-collect-test-diagnostics never
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300` (otherwise a red test "sits collecting
  diagnostics for ten minutes"). `icloud` adds `-allowProvisioningUpdates -allowProvisioningDeviceRegistration`, the
  iCloud entitlements and `PACKING_USES_ICLOUD=YES` (needs his Apple ID in Xcode; the device-registration flag because
  a Mac development profile only counts on a registered Mac). Prints the built app's path.
- **`tools/test-core.sh [swift test args]`** — the model tests alone, in seconds, scratch path
  `$TMPDIR/AMSPacking-core-<8 hex of the checkout path>` (one per checkout, so worktrees do not fight).
- **`tools/import-check.sh [file]`** → `swift run import-check <file>` (default: the newest `private/migration-*.json`):
  dry-runs the one-time import, printing only numbers and positions (templates, rows → things and places, things on
  no list, trips/lines/ticks, to-dos/kits/photos, own "When" steps, settings rows, the fragile fields before → after,
  a store round trip's drift and records per table, the largest record, and per trip whether "regenerate" would change
  it). Exit 0 = "faithful: every row came back exactly as it is in the file", 1 = not faithful (up to 40 mismatches),
  2 = usage / not a backup.
- **`tools/prepare-migration.py`** — turns a web-app backup into the clean migration file in `private/` (one copy of
  each doubled template — the ORIGINAL, created first; test trips left behind by a name list in `private/`; trips
  repointed to the kept copies).
- **`tools/release-to-testers.py`** — §28.
- `private/` and `*backup*.json` are git-ignored: real data never enters the public repository.

## 31. The parity check against the web app (`Core/Sources/parity`, `tools/parity/`)

**Purpose.** The Swift model (`PackingCore`) is a port of the web app's `js/model.js` and must give the same answers.
Two programs answer the same questions about the same backup: `tools/parity/js-answers.mjs` (loads the web app's own
model, read-only; the reference) and the Swift `parity` tool (`parity <backup.json> [--today YYYY-MM-DD] [--locale
en-US]`, PackingCore's public API only, laid out like the JS half). `tools/parity/diff-answers.mjs a b [--max N]
[--only <prefix>] [--quiet]` compares the two documents and ends with exactly "differences: none" (exit 0) or
"differences: N" (exit 1).

**The contract** is `tools/parity/QUESTIONS.md` (contract version 3; needs web model v186+): determinism rules — today
is a parameter (default 2026-09-21), the clock frozen at noon UTC of that day, minted ids and timestamps never
compared (markers instead), each question gets its own deep copy, collation pinned to en-US, a throw is answered
`{"$error": message}`, absent entities absent on both sides; a canonical JSON form (sorted keys by UTF-16 order, NaN
→ null, −0 → 0, lone surrogates dropped, whole numbers exactly equal, others within 1e-9, a byte-exact `CJ` form for
the two hashed questions); fixed key sets per shape; question groups §6–§15 (setup state, coercion, per list, per trip,
probe trips, the whole library, the Settings lists and their shared rows — `settings.rows`, `rowsOfKind`,
`isFactoryList`, `back`, `ownersByUsage`, `grabShare` — every real string and id, fixed calculations, installing a
list last); §16 what is deliberately not compared (raw trip-link text, random ids, minted times, the `…ToRows`
functions reached through `sharedRowsFrom`, impossible dates, keys outside the shapes, photos and db/app code); §17 what the contract requires for `sub`, `ownedBy`, `u` and the reserved keys.

**Runs.** `tools/parity/run.sh [backup] [--today] [diff options]` builds the Swift half in release (same scratch path
as test-core), runs both halves over `private/migration-2026-09-21.json` by default and writes the answers into
`private/` (they contain real names — never public). `run.sh --invented` uses the INVENTED backup written afresh by
`fixtures/make-invented-backup.mjs` (deterministic; awkward on purpose: kits, things, presets, a customised phase list
with ties, an item on three lists, legacy `owner` fields, names cut inside an emoji, 405 items in one list, dates that
are not dates, the sync add-on's reserved keys on every row; its header lists the shapes deliberately left out) into
the build folder — this is the CI run. `fixtures/check-invented.mjs [real backup] [--show]` proves the invented file
shares no value and no word of five letters or more with the real one (exit 1 if it does).

## 32. The UI-test harness (`UITests/AMSPackingUITests.swift`, top of the file)

One class, `AMSPackingUITests`, 110 tests, run on the iPhone simulator and on the Mac. "Two tests to begin with, and
one more added at a time"; every test is seen to fail before it is committed (README). `continueAfterFailure = false`.

| Helper | What it does exactly |
|---|---|
| `launch(mode = "-uiTesting")` | adds the mode, launches; if not running in front within 30 s, launches again and waits 60 s (GitHub's slow runners). Mac: if no window within 5 s, Cmd-N and wait 5 s (the app once came up with no window). |
| `testAAAWarmsUpTheSimulator` | runs FIRST (name order): launch, wait up to 60 s for `screen-home`, terminate — inside `XCTExpectFailure(…, .nonStrict())`, so a fumbled cold launch is allowed and proves nothing. |
| `find(app, id)` | a named container: tries `otherElements`, `groups`, `scrollViews` (the same container is a Group on the Mac, an Other on the iPhone, or its ScrollView). Typed queries only — `descendants(matching: .any)` hangs the suite. |
| `appears` / `disappears` | poll `find` every 0.2 s until the timeout (default 10 s). |
| `words(e)` | "" if the element does not exist (reading a missing one is a HARD failure); else its label, or its value when the label is empty (Mac = value, iPhone = label). |
| `isOn(e)` | exists and is selected. |
| `shot(app, name)` | only when the env `SHOTS_DIR` is set (passed as `TEST_RUNNER_SHOTS_DIR`): a PNG of the window (Mac) or screen (iPhone) into that folder, falling back to the runner's temporary folder (the Mac runner is sandboxed); prints "SHOT <path>". 81 calls. |
| `type(text, into:)` | tap + type, verified by reading the value; up to 3 tries, deleting what landed in between. |
| `cellSays` | a dropdown's text: tries buttons, pop-up buttons, menu buttons, text fields, texts, others; value first. |
| `bringAcross` | travels a wide grid sideways (Mac scroll wheel ±240, iPhone swipes) until the element's middle is in the window; flips direction if it did not move; judges by frames. |
| `inWindow` / `onScreen` | frame-based: the middle inside the window (and inside its list for `onScreen`, which also asks `isHittable`). |
| `frontList` / `biggestList` | the last scroll view; the larger of the first and the last (a strip of pills is also a scroll view). |
| `scrollUntil(id, near:, tries: 8)` | until a button/other with the id EXISTS (far rows are not in the tree yet): scrolls the list holding `near` (else the biggest list); Mac ±220 (first half one sign, second half the other), iPhone swipe up; prints a TAP-REPORT with the tree when it gives up. |
| `scrollWithin(screen, until:, tries: 10)` | scrolls the first scroll view INSIDE a named sheet, never the screen behind it. |
| `listHolding(e)` | the list that CONTAINS the element, by descendancy — front list, first list, then every list front to back (with the keyboard up the front "list" is the text field). |
| `bringIntoView(e)` | up to 10 scrolls of the element's own list (±200 on the Mac) until `onScreen`; flips direction when the element did not move up; does nothing when no list holds it. |
| `tab(app, name)` | hides the keyboard, then taps `tab-<name>` up to 3 times until `screen-<name>` appears (4 s each) — a tap can be swallowed on a slow machine. |
| `keyboardArriving` / `hideKeyboard` | iPhone only: the keyboard still sliding in (frame below the screen or not settled); swipe the biggest list up and wait ≤ 3 s for the keyboard to go. |
| `tapVisible(e)` | `bringIntoView`, wait ≤ 3 s until settled (a gliding list takes a tap as "stop"), tap. |
| `tap(app, id:, timeout = 10)` | a FRESH `app.buttons[id]` query every 0.2 s; taps only when it exists, is ENABLED, is settled, and no keyboard is arriving; then `tapVisible`. On timeout: prints TAP-REPORT with the first 12 000 characters of the tree, attaches a screenshot `no-<id>`, fails. (So `tap(id:)` finds buttons only.) |
| `settled(e)` | a finite, non-empty frame that is the same 0.12 s later. |
| `replace(text, in:)` | Mac: click, Cmd-A, type; iPhone: tap at 90 % of the width (cursor after the text), delete old length + 2, type; verified; 3 tries. |
| `select(button)` | tap until it reports selected (3 tries, 2 s each), else `report`. |
| `report` | TAP-REPORT: the element's state, `trip-create`'s state, window and scroll frames, the first 8 000 characters of the tree, a screenshot; fails. |
| `waitUntil(timeout = 5, ok)` | polls every 0.2 s, one last check at the end. |
| `switchNamed` / `isSwitchOn` / `setSwitch` | a switch (iPhone) or check box (Mac); on = value "1"/true; set by tapping (iPhone: at 95 % of the width, on the switch not its words), up to 3 times. |
| `dayFromToday`, `pickDay`, `pickDates` | the month grid: page with `range-next`/`range-prev` towards the month, tap `range-day-YYYY-MM-DD`, OK with `range-ok`. |

Traps recorded with them: the hardware keyboard exists locally but not on GitHub's simulator, so a control under the
on-screen keyboard takes no tap while looking hittable; `scrollViews.firstMatch` is the screen BEHIND an open sheet,
and swiping a sheet's list that is already at the top drags the sheet shut (three red runs); "wait for a number, never
snatch it"; a locked Mac screen or a heavily loaded Mac makes the runner hang before connecting — CI's Mac job is the
gate that counts.

## 33. Test inventory for this chapter

UI (`AMSPackingUITests`): `testAAAWarmsUpTheSimulator`, `testStartsOnHomeAndNamesItsVersion`,
`testEveryTabOpensItsScreen`, `testAnEmptyDeviceShowsTheTwoDoors`, `testSettingsOffersABackup`,
`testWhatsNewStartsWithThisVersion`, `testTheLoopShowsWhereATripStands` (guide part),
`testTheFirstTripStepsHaveTheirOwnDoor`, `testSettingsTurnsOnPackingReminders`, `testSyncNowChecksInFromThisDevice`,
`testWorthALookRemovesAPhotoLeftBehind`, `testALibraryThatHasMetAnotherSaysSo`,
`testARestoreShowsWhatTheFileHoldsAndThenReplacesEverything`, `testTheCopyKeptBeforeARestoreBringsEverythingBack`,
`testHisOwnListsAreAddedAndProtectedWhileInUse`, `testWhoseItIsOffersEachOwnerOnce`,
`testEveryAddButtonIsReadyAndSaysWhatIsMissing`, `testTheEditorsLeadWithTheirHeadings`, `testTheCrossEmptiesASearch`,
`testTheCrossKeepsTheKeyboard`, `testATripIsDeletedOnlyAfterAsking` (photo count in Settings),
`testATripIsSharedAndOpenedAgain` and `testATemplateAndAGrabListAreSharedAndOpenedAgain` (the door).

Model: `SettingsListsTests` (5), `SharedRowsTests` (26), `PresetsTests` (5), `PhasesTests` (12),
`ItemConditionsTests` (6), `PeopleTests` (8), `HealthTests` (5), `PhotoTidyTests` (3), `BackupTests` (library, 5),
`RestoreTests` (3), `SyncCheckInTests` (1), `CountdownTests` (4), `ContrastTests` (3). Not unit-tested at all (the app
target has no unit-test target): `SVGPath`, `RescueCopies`, `AppInfo`, `Releases`/`Words`/`HowItWorksScreen`
content, the button and heading components.

---

## Open questions / discrepancies

Tags: **[bug]** the code does something wrong or surprising; **[rule-break]** it breaks one of his standing rules (or
the code's own stated rule); **[doc]** a comment or document disagrees with the code; **[untested]** behaviour that
matters and no test pins; **[idea]** worth deciding before a rewrite. (The 0.59 item "a photo whose `createdAt`
cannot be read is offered for removal at once" is gone: 0.60 keeps such a photo and never offers it — §12.)

1. [bug] [untested] **Sync now on an empty device blocks the import.** `Library.isEmpty` includes `meta`. On a fresh
   device (state `.empty`, Settings reachable), pressing *Sync now* writes `meta["syncCheck.<device>"]`, so the library
   is no longer empty: Home stops showing the first-run doors and `importBackup` refuses with "This library has
   already been imported into." (A check-in arriving from the other device has the same effect.)
2. [bug] **Rescue-copy times are UTC.** `RescueCopies.write` stamps the file with `nowISO()` (UTC, "Z") and `when(_:)`
   shows that clock as it is ("22 September, 23:04"), not local time — one or two hours off in his time zone, and
   near midnight the day is wrong too.
3. [bug] **RestoreSheet's minimum size applies on the iPhone too.** `.frame(minWidth: 420, minHeight: 520)` is not
   inside `#if os(macOS)` (every other sheet's is); 420 pt is wider than most iPhones. The UI test still passes on the
   iPhone.
4. [idea] **The backup JSON is rebuilt on every redraw of Settings** (it is an argument of `.fileExporter` in `body`),
   photos included — a full resolve, encode and pretty-print each time anything on the screen changes.
5. [rule-break] **The font floor of 15 is not universal**: 166 `.system(size:)` values below 15 in 42 of the 67 app
   source files (11–14 for secondary lines, the tab labels 12.5, the version marker 11, `SmallDeleteButton` 13). The
   code comments state the floor ("Nothing under 15, so it still reads without glasses") for headings and pills only.
6. [idea] **`HeaderButtonStyle` callers' fonts are dead**: Done/Cancel attach `.font(17 bold)` and a colour outside the
   style; the style's own 16 bold and white/tint win. Delete them or make the style honour them.
7. [rule-break] **The way-home search does not use `.clearButton`** although `ClearButton` says "ONE modifier for
   every search field, so they all behave alike": its ✕ (`wayhome-search-clear`) is a plain stroked cross in a 44×44
   area, not the `ClearMark` disc in 36×36.
8. [bug] **The use count's wording**: "is still used by N thing(s)" also counts trip lines and template places for
   "When" steps, so the number can be far larger than the things that use the step.
9. [doc] **`usesOf`'s doc comment** says it counts "things, trip lines and to-dos" — to-dos are never counted, and
   trip lines (and memberships) only for "When" steps.
10. [idea] **Your choices cannot edit**, only add and remove: no rename, reorder (although places' order "is something
    you arrange yourself" since web v125), colours, lead days, to-do flag, condition tone or "needs replacing". A
    condition added natively can never feed To buy; a step added natively is due on departure day (lead days 0).
11. [rule-break] **A new 8th "When" step gets teal** (`TEMPLATE_COLORS[7]` = `#14b8a6`), against docs/colours.md "Do
    not use teal for anything new" — and there is no way to change it in this app.
12. [bug] **Silent duplicates in Your choices**: adding a place, owner or packer that already exists (by `normName`)
    does nothing and says nothing, against the rule that a press says what went wrong; a condition or step with an
    existing label is added a second time (`good-2`).
13. [bug] **The problem line appears at the TOP** of a long sheet whichever part was pressed; on a phone it can be off
    screen when Remove is pressed in "When" steps, so the refusal looks like nothing happened.
14. [idea] **Owners are listed A–Z with no factory list**, so on an account whose things name owners but which never
    added one, the Owners part is empty while *Whose it is* offers those names (`ownerChoices`). `ownersByUsage`
    (the web app's most-owned-first order) is ported but unused.
15. [doc] **docs/colours.md is stale**: it calls the workout pills "decided … not built yet", but `WorkoutTone`
    implements them (0.40); it still names the tabs Events/Actions.
16. [doc] **Section colours are single hexes**, while Theme.swift's opening comment says "every colour here is a pair
    — never a single hex" (true of `Theme` only).
17. [idea] **Sheet dismissal without an answer**: swiping the restore sheet away (iPhone) leaves the status line
    unchanged (no "Nothing was replaced."). Escape on the Mac relies on SwiftUI's default; no keyboard shortcut
    (`.keyboardShortcut`, `onExitCommand`) exists anywhere in the app.
18. [rule-break] **Settings keeps two `.sheet` modifiers on one view** (Your choices and the restore sheet, plus a
    `.fileImporter` and a `.fileExporter`) although GuideScreen.swift's comment calls "several sheets on one view" a
    trap met in Search; it works today (both sheets are opened by UI tests).
19. [doc] **The shot helper's comment names `tools/shots.sh`**, which is not in the repository; the env var it reads
    is `SHOTS_DIR` (set as `TEST_RUNNER_SHOTS_DIR`). Nothing in the tests switches to dark mode, though the comment
    says shots are looked at "in dark mode".
20. [doc] **`forThisLaunch`'s doc comment lists only three test modes**; the code also has `-uiTestingChecks`,
    `-uiTestingOldPhoto`, `-uiTestingTwoLibraries` (and `-pretendShopTicks` elsewhere).
21. [doc] **SampleLibrary's weight/place tables name Towel, Goggles and Swim cap**, but they are applied before Swim
    exists, so those three have no weight and no place (the UI tests depend on that). Its comment "514 of 431 things
    weigh something" is self-contradictory.
22. [doc] **Worth a look calls templates "lists"** ("on a list that no longer exists") after 0.34 made "list" mean
    only the list you pack from. Release 0.59 files a new feature (Worth a look's photo repair) under *Changed*.
23. [idea] **The scheme runs `PackingCoreTests` but not `PackingLibraryTests`**: `tools/build.sh test` and the two UI
    jobs never run the library's model tests; only the `core` job's `swift test` (and `tools/test-core.sh`) does.
24. [doc] **The `mac` job's timeout comment is a copy of the iPhone job's** ("the iPhone job passed every one and was
    cancelled at 80 minutes").
25. [idea] **TestFlight `notes` never reach testers** — since 0.59's fix they travel safely through the `NOTES`
    environment variable, but still only into the run summary; the input's description ("What is new in this build")
    suggests more.
26. [doc] **The Reminders card's sub-line** names "a week ahead, the day before, the morning" but reminders also come
    for Preparations (30 days ahead) and any other step with lead days ≥ 0.
27. [bug] **`RemindersCard.refused` is not remembered**: after leaving Settings the "not allowed" line is gone while
    the switch is off. (Partly met in 0.6x: switched ON but blocked by the device, the line now shows every time —
    Home spec, item 13. Turning the switch on again still says why at that moment.)
28. [idea] **Template covers can still show an emoji** (data from the web app) when a template has no icon, despite
    "no emoji" — deliberate per the comment ("His covers are his data"), noted for a rewrite.
29. [rule-break] **The public repository holds real first names**: `DEFAULT_PEOPLE` in `SharedRows.swift` (the two
    factory packers — also asserted by `SettingsListsTests.testAListWithNoRowsIsTheFactoryOneAndHisOwnIsStored`) and
    the `TESTER_GROUP` value in `testflight.yml`. Not repeated here on purpose.
30. [bug] [untested] **Two long place or owner names can share one row**: the row id is built from the normalised
    name cut to 60 UTF-16 units, while de-duplication compares the full name — two names alike in their first 60
    normalised units become two records under one key, and the next load keeps only one (§2.5).
31. [doc] **"Kit" means two things**: Words defines it as "All your things together — what Care counts and weighs",
    while the library's `kits` table (counted as "Kits" in *This device holds*) holds named groups of things.
32. [idea] **An undated unused photo is now kept for ever and never mentioned** (0.60): it travels through iCloud and
    every backup; decide whether Worth a look should at least name it without offering removal.
