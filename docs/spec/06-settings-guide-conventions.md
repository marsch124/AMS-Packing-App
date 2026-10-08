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

**Layout.** One `KeyboardAwayScroll` (see §22) holding a `VStack(alignment: .leading, spacing: 8)` — the cards **8
points apart** (0.67; 10 until then, 14 before 0.62) — padded 16 left/right and 24 at the bottom, inside the app's
720-point column (`RootView`). His words (6 Oct 2026, testing 0.63, the gaps between the cards marked in orange):
"Far too much space in the settings tab." Top to bottom, exactly in this order in the code:

| # | Element | Shown when | Id |
|---|---|---|---|
| 1 | *Your choices* door (§2), a card of one row | always; `Metrics.screenTop` (4 pt) above it — where every tab's first line starts (0.67; 14 before); on the Mac under the empty title bar strip | `settings-lists` |
| 2 | *Remind me to pack* card (§3) | always | `settings-reminders-card` |
| 3 | *iCloud sync* card (§4) | always | `sync-card` |
| 4 | ONE card of four door rows (0.67; four cards 10 apart until then): *What's new*, *How it works*, *Your first real trip* (§5) and *Open a shared link* (§11), a `CardHairline` between them | always | `settings-whatsnew`, `settings-howitworks`, `settings-firsttrip`, `settings-openshared` |
| 5 | *Worth a look* card (§12) | only when `library.worries()` is not empty; 6 pt extra above it (14 until 0.67) | `health-heading`, `health-<n>` … |
| 6 | Heading *BACKUP* (§13) | always | `backup-heading` |
| 7 | *Save a backup…* button + status line (+ "Last saved from this …" once saved here, 0.62) | always | `backup-save`, `backup-status`, `backup-last` |
| 8 | *Restore from a file…* button (§14) | always | `backup-restore` |
| 9 | *Kept before a restore* list (§15) | only when a rescue copy exists on this device | `rescue-heading`, `rescue-row-<n>` |
| 10 | *This device holds* table + footer (sync mode, version) (§16), and under it where the library came from (0.62); its heading 10 pt extra above (14 until 0.67) | always; the line only for a library brought in from a file | `device-count-<table>`, `device-import` |

**A door row and a card** (0.67, SettingsScreen.swift). `SettingsDoorLabel(title:, line:)` is every door's face: the
title (Body semibold ink) over its line (Footnote muted, one line, cut with "…"), 0 pt between, a spacer, and the
chevron (`"M9 6l6 6-6 6"`, stroke 1.8, muted) shown at `Metrics.glyph` (20 / 16) with `onGrid`; 12 pt side and 6 pt
top and bottom padding, at least `Metrics.row` tall (40 / 30), full width, **filled with `Theme.card`** and shaped as
a whole rectangle, so the whole row takes a press on the Mac too (a slim whole-row plain button with nothing behind its
words once took no clicks — §15). On the iPhone a door row is 48 tall, 49 top to top with the hairline (70 until
0.67: 60-tall cards 10 apart). `CardHairline` is a 1-pt `line` from 12 pt in (where the words start), on the card's
colour — as in the iPhone's own Settings. `.settingsCard()` clips its content to a radius-12 rounded rectangle and
draws a 1-pt `line` round it.

**Sheets and windows owned by the screen itself.** Two sheets, as in 0.61: `.sheet(isPresented: lists)` →
`ListsScreen`, and `.sheet(item: pending)` → `RestoreSheet` (0.62 tried ONE sheet with a destination, and with an
`onDismiss` on it; on GitHub's Mac run the kept copy's restore then never opened after a first restore — item 18);
`.fileImporter` (open a `.json`); `.fileExporter` (save the
backup) — system windows, each opened only by its own button. The guide doors and the shared-link door own their OWN
sheets (`GuideDoors`, `OpenSharedDoor`) because "several sheets on one view is a trap met in Search" (GuideScreen.swift
comment). Every answer to a restore comes from inside the sheet once it has gone (`RestoreSheet`'s `onDisappear`, 0.63), a
swipe-away answering "no", so the status line says "Nothing was replaced." (§14).

**State held by the screen** (`@State`, lost when the tab is left): `exporting`, `saving` (the backup document, built when Save is pressed — 0.62), `status` (the line under Save),
`lists` (Your choices open), `pending: PendingRestore?` (the file already read and checked, waiting for his yes),
`picking`,
`copies: [URL]` (rescue copies, read once when the view is created and again after a restore).

**iPhone vs Mac.** Identical layout. Save opens the Files picker on the iPhone and a real Save panel on the Mac;
Restore opens the Files browser / an Open panel. Sheets on the Mac get minimum sizes (each section says which).

**Tests.** `testSettingsOffersABackup` (the device check exists; *Save a backup* sits BELOW *Your choices*;
pressing it says "Choosing…"; on the Mac a Save window opens and Escape closes it), `testEveryTabOpensItsScreen`
(tab ids and `screen-settings`), `testSettingsDoorsAreRowsOfOneCard` (0.67: `settings-whatsnew`,
`settings-howitworks`, `settings-firsttrip` and `settings-openshared` are rows of one card — at most 1.5 pt between
one and the next, at most 52 pt top to top on the iPhone and 46 on the Mac; `settings-reminders-card` at most 8.5 pt
under `settings-lists`; `settings-firsttrip` still opens its page and `guide-done` closes it; picture
`tight-settings`. Seen red on 0.66: "10.0 points between settings-whatsnew and settings-howitworks: not rows of one
card"). Each card's own tests are in its section.

**Traps.** Until 0.62 the backup JSON was built inside `body` (`BackupDocument(data: model.library.backupData())` was an
argument of `.fileExporter`), i.e. on every redraw of Settings — including all photo data. Now it is built when Save is pressed.
What is still asked on every drawing — `worries()`, `counts`, the reminder plan — walks the library in memory only: no
record is built and no photo decoded (`counts` counts the arrays; since 0.62 the photos still shown are gathered in one
walk, `photoIdsInUse`, not one walk per photo). A comment in `body` says so (0.62; spec 01 item 15).

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
A card of one door row (`SettingsDoorLabel` in `.settingsCard()`, §1; 0.67): title **"Your choices"** (Body
semibold, `Theme.ink`), under it **"Storage places, owners, packers, conditions, "When" steps"** (Footnote,
`Theme.muted`, one line — truncated with "…" if too narrow), a drawn chevron on the right. At least `Metrics.row`
tall (minimum height 60 with 14 horizontal padding until 0.67); whole row tappable; plain style;
`.focusEffectDisabled()`; id `settings-lists`. Tap → `lists = true` → sheet.

### 2.3 How it is reached and left
Reached only through the door. Left with **Done** (top right, `HeaderButtonStyle(tint: settings slate, filled:
true)`, id `lists-done`) which calls `dismiss()` — Escape too (⌘. on an iPhone keyboard, 0.62, §20); or by swiping
the sheet down on the iPhone. Nothing is ever
"saved" on leaving — every Add, Remove, Rename and move is written immediately through `LibraryModel.change`.

### 2.4 What is on screen, top to bottom
- Header row (padding 16): **"Your choices"** (22 heavy, ink, id `choices-title`), Spacer, **Done**.
- Then a `KeyboardAwayScroll` with a `VStack(spacing: 8)`, padding 16 horizontal / 24 bottom:
  - Intro (15 medium, muted, wraps, id `choices-intro`): **"The words the app offers you as buttons. Add your
    own with the field under each part; hold the grip ≡ and drag one to its place; the pen renames one or moves it
    up or down; one that is still in use somewhere cannot be removed."** (the grip sentence 0.70)
  - Five parts, in this fixed order (`Kind.allCases`): `places`, `owners`, `people`, `conditions`, `phases`. For each:
    - A `HeadingBand` (§21) in the Settings slate, 16 pt space above, id `choices-heading-<kind>`. Titles:
      **"Storage places"**, **"Owners"**, **"Packers"**, **"Item conditions"**, **""When" steps"**.
    - The hint (15 medium, `Theme.ink` at 85 % opacity, wraps, id `choices-hint-<kind>`):
      - places: "Where a thing is kept at home — a cupboard, the garage, the basement. You give a thing its place
        under Kept at home; a trip sorted by From where then lists what to fetch room by room. The square beside a
        place is its code: print its label, and the iPhone's Camera opens the app on that place." (the last
        sentence 0.69)
    - (places only, 0.69) right under the hint: **Labels for P-touch, all places** (`WideButtonLabel`, slate, the
      drawn square `CodeMark`; id `list-places-labels`). Mac: a folder window ("Choose a folder for the P-touch
      labels of your places.", button "Save labels here", new folders allowed) → every place's code kept
      (`PlaceLabels.keepCodes`), every label written there as "<place> label.png" (a file of that name replaced);
      under the button "<n> labels saved in <folder>." / "1 label saved in …" / "Not saved." (Footnote muted, id
      `list-places-labels-said`). iPhone: two steps, so nothing is kept just by opening this page — the press keeps
      the codes and makes the files, then the button becomes **Share <n> labels** ("Share 1 label"; white on slate,
      `Metrics.tap` tall, radius 12; id `list-places-labels-share`), a Share of all the PNGs (Save Images → Photos,
      or Save to Files) for Brother's app. The labels: spec 05, "A place's code and its label".
      - owners: "Whose a thing is — you, your partner, a child. You pick it under Whose it is on a thing, so on a
        shared trip everyone sees which things are theirs."
      - people: "Who packs a thing. You set it in the All your things table (Packed by), so you can see who is in
        charge of what."
      - conditions: "How worn a thing is: New, Good, Worn, Needs replacing. You set it under Condition on a thing;
        a thing that needs replacing is suggested on To buy."
      - phases: "The steps of packing, from a week ahead to the day you leave. Every thing has its When, and a trip
        shows its list in this order, step by step."
    - One row per entry (n = 0, 1, …; since 0.70 the rows are followed by the entry's key, not its place, so a row
      being dragged keeps its gesture): where the order is his (`Library.canMove`: all but Owners, A–Z), first a
      **grip ≡** (`list-<kind>-grip-<n>`, `ReorderGrip` → `GripMark`, 36 wide, 8 pt into the left margin; 0.70, his
      ask testing 0.69: "Can we make the reordering easier for a human by introducing drag and drop?"): hold and
      drag — each place passed is `moveChoice(kind, key, ±1)` at once, exactly the pen's ▲ ▼; the carried row is
      lifted on the card colour with a slate edge and a shadow and follows the finger; then the label (17 medium, ink, id `list-<kind>-name-<n>`); if THINGS use the
      entry, how many (14 bold, monospaced digits, muted) right after it — things only, also for a "When" step;
      on the owner marked "This is me" (0.70), right after its name, a small **"Me"** tag (Caption semibold white on a
      slate capsule, min height 20, padding 8 sideways; id `list-owners-me-<n>`)
      (0.62; until then a step's number added its trip lines and template places); Spacer; (places only, 0.69) the
      place's square — a drawn `CodeMark` (three corner squares and two dots on the 24 grid, stroke 1.8) 22×22,
      muted, in a `Metrics.tap` square; id `list-places-code-<n>`, VoiceOver "Square code for <label>" — which opens
      the place's own page (`PlaceCodeSheet`, a sheet; spec 05): its code, its label for the P-touch and Open; the pen — a drawn
      `PenMark` 22×22, muted (Settings slate on a 16 % slate rounded square while that entry's editor is open), in a 44×44 hit area, id
      `list-<kind>-edit-<n>`, VoiceOver "Change <label>" (0.62); a remove button — a drawn ✕ (`M6 6L18 18M18 6L6 18`,
      stroke 1.8, 22×22, muted) in a 40×40 hit area, id `list-<kind>-remove-<n>`, VoiceOver label
      "Remove <label>". The row is an accessibility container (`children: .contain`) with id `list-<kind>-row-<n>`
      and a 1-pt `Theme.line` hairline at its bottom. There is no empty-state text: an empty list (Owners when no
      thing names an owner and he never added one — since 0.62 an account that never added one shows the owners its
      things name) shows no rows, only the Add field.
    - Right under the row whose ✕ was refused (0.62 — until then at the TOP of the sheet, off screen when Remove
      was pressed far down the "When" steps): the problem line (15 semibold, To-do red `#dc3d43`, wraps, id
      `lists-problem`), `ChoiceUse.refusal(label)`, e.g. **"Garage is still used by 3 things, so it stays."** or
      **"≥1 week ahead is still used by 10 things and on 1 trip, so it stays."** One at a time; an Add that adds, a press
      on a pen or a remove that removes clears it.
    - Under the row whose pen is open (one at a time, followed by the entry's KEY so it stays on the entry as it
      moves; the pen again closes it), the editor (0.62): a card (padding 12, card fill, radius 12, 1.4-pt Settings
      slate border, container id `list-<kind>-editor`) holding a field **"New name"** pre-filled with the entry's
      label (17 medium, `Theme.bg` fill, radius 10, min height 44, id `list-<kind>-rename-name`; Return = Rename)
      and **Rename** (`FieldButtonLabel`, slate, id `list-<kind>-rename`); under them, for places, packers,
      conditions and steps, two drawn chevrons ▲ ▼ (`M6 15l6-6 6 6` / `M6 9l6 6 6-6`, stroke 2.2, in 44×44 boxes,
      slate at 10 % with a 1.4-pt slate outline, ids `list-<kind>-up` / `list-<kind>-down`, VoiceOver "Move <label>
      up|down") and the line "Up or down the list." ("Up or down the timeline: every trip follows this order." for
      steps; 15 medium muted); for owners instead "Owners are always in A–Z order.", and under it (0.70, his answer
      "My things." to whose things Apple Health marks) **"This is me"** — a pill (Subheadline semibold, min height
      `Metrics.chip`; slate outline on 10 % slate, filled slate with white words while this owner is him; id
      `list-owners-me`, `.isSelected` when on) with a muted line beside it: "Whose things Apple Health marks in a
      trip's review." / "Apple Health marks your things in a trip's review." Press → `setMe(owner)`; pressed on the
      owner already marked → `setMe(nil)` (nobody). One at most: marking another moves the mark. Under the card, its needs line
      (id `list-<kind>-edit-needs`, §20): what Rename was missing or refused, or "<label> is already at the top." /
      "… at the bottom." for an arrow that cannot move it.
    - The Add row (`HStack(spacing: 8)`): a plain `TextField` with the placeholder **"Add to <title lower-cased>"**
      — i.e. "Add to storage places", "Add to owners", "Add to packers", "Add to item conditions", "Add to "when"
      steps" — 17 medium ink, 12 horizontal padding, min height 44, card fill, radius 10, 1-pt line border, id
      `list-<kind>-add-name`; Return (`onSubmit`) = Add. Then **Add** — `FieldButtonLabel(title: "Add", tint:
      Settings slate)`, id `list-<kind>-add`. Under the row, the needs line (`.needsLine`, id
      `list-<kind>-add-needs`, §20): "Type a name first." or (0.62) "You already have <name>.".
  - Footer (14, muted, 14 pt above): **"These belong to your account, so both your devices show the same."**
- Whole sheet: `Theme.bg` behind (ignores the safe area), accessibility container id `lists-detail`.

### 2.5 Behaviour
**Which entries a part shows** (`entries(kind)`):

| Part | Source | Label | Key (remove, rename, move) | Use looked up by |
|---|---|---|---|---|
| places | `library.storagePlaces()` (stored order, or the 12 factory places) | name | the name | `normName(name)` in `usesOf("places")` |
| owners | `library.owners()` (stored rows, A–Z; none stored → the owners his THINGS name, A–Z, each once — 0.62) | name | the name | `usesOf("owners")` |
| people | `library.people()` (stored roster; else the packers his things name; else the 2 starters — §2.6) | `name` | `name` | `usesOf("people")` |
| conditions | `library.conditions()` (stored, or the factory 4) | `label` | `id` | `normName(id)` in `usesOf("conditions")` |
| phases | `library.timeline()` (stored `phases`, or the factory 7) | `label` | `id` | `normName(id)` in `usesOf("phases")` |

`Library.usesOf(kind)` answers, per normalised key (`normName`: trimmed, lower-cased, runs of white space collapsed;
empty keys skipped), a `ChoiceUse { things, trips, templates }` (0.62; until then one number): `things` = the
catalogue items whose `storage` (places), `ownedBy` (owners), `packer` (people), `condition` (conditions) or
`phase` (phases) it is. For `phases` ONLY also `trips` = the trips with at least one line in that step and
`templates` = the templates with at least one membership whose `phase` is that step. Nothing else is counted (not
to-dos — a to-do's When is only a label and reads as the fallback step when its own is gone — and not trip lines
for the other kinds). The number on a row is `things`; an entry is in use (`inUse`) when any of the three is above 0.

**Add** (`add(kind)`; the same from the button and from Return):
1. `name = jsTrim(field)`. Empty → the needs line says **"Type a name first."** and nothing else happens (the
   button is never disabled or grey — §20).
2. (0.62) `library.existingChoice(kind, name)` finds one he already has → the needs line says **"You already have
   <its spelling>."**, nothing is added, and what he typed stays (so the line stays until he types). Places,
   owners and packers match by `Library.choiceKey` (the normalised name cut to 60 UTF-16 units — what the store keys
   them by); a condition or a step by `choiceKey` of its LABEL.
3. `problem` is cleared.
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
5. The field is emptied.

What happens to odd input: a name he already has is refused with words (step 2; until 0.62 a place, owner or packer
was dropped by the row builders without a message and a condition or step was added a second time as `good-2`). A
list that ends up identical to the factory list stores no rows at all (and `LibraryModel.change` writes nothing when
no record changed). A long name is cut AT ONCE, not later: the row is built by `coerceSharedRow`, which cuts its
`name` to 80 UTF-16 units and its `key` (the normalised name) to 60, so the list shows the cut name straight away (a
condition's or a step's label is already cut to 60 by `newCondition` / `newPhase`). Two place, owner or packer
names alike in their first 60 normalised units are ONE name (0.62): Add says he already has the first, and
`setNames` / `setPeople` keep only the first of such twins, so no two records ever share a row id (until 0.62
they were two records under one key and the next load kept only one).

**Remove** (`remove(kind, n)`):
1. The entries are recomputed; `n` out of range → nothing.
2. In use (`uses.inUse`) → `problem` = `(kind, key, uses.refusal(label))`, shown under that row: "<label> is still
   used " + the parts that apply, joined ", " and " and " — "by <n> thing(s)", "on <n> trip(s)", "on <n>
   template(s)" — + ", so it stays." Nothing changes. (Until 0.62: "used by <n> thing(s)" with a step's trip lines
   and template places counted as things.)
3. Otherwise `problem` is cleared (and the entry's editor, if open) and one `model.change`:
   - places: `setNames("places", storagePlaces().filter { $0 != key })`
   - owners: `setNames("owners", owners().filter { $0 != key })`
   - people: `setPeople(people().filter { $0.name != key })`
   - conditions: `setConditions(conditions().filter { $0.id != key })`
   - phases: `setTimeline(timeline().filter { $0.id != key })`
   The comparison is EXACT (case-sensitive) on the stored spelling. Removing the last remaining entry of places,
   people, conditions or phases brings the factory list back (an empty list means "the defaults").
   No confirmation is asked; there is no undo.

**Rename** (0.62; the pen, then Rename or Return — `library.renameChoice(kind, key:, to:)` inside one
`model.change`): the new name is trimmed; empty → "Type a name first."; one he already has (`existingChoice`, the
entry itself excepted, so a change of spelling only is allowed) → "You already have <name>."; for a place, owner or
packer, a name his THINGS already carry though it is not on the list → "Some of your things already say <name>.
Pick another name." (renaming into it would merge two entries, which no rename could undo). Otherwise: a place,
owner or packer takes the new name in its own position (a packer keeps its colour) and EVERY thing and EVERY trip
line whose `storage` / `ownedBy` / `packer` is the old name by `normName` (any spelling) is given the new one — trip
lines of every trip, done ones included: it is the same place under a new name. A condition or a step is pointed at
by its id, which stays, so only its label changes (cut to 60) — `setConditions` / `setTimeline` re-install the live
lists, so every screen says the new words at once. A list renamed from the factory one becomes his own (stored).
Success closes the editor; a refusal says why under it and keeps it open.

**Move** (0.62; ▲ / ▼ in the editor — `library.moveChoice(kind, key:, by: -1|1)`): swaps the entry with its
neighbour. Places (stored order), packers and conditions (row `order`) and steps (written into each `order` before
`setTimeline`, which sorts by it — so every trip's "When" order follows) can move; owners cannot (`Library.canMove`:
always A–Z, as every Owner dropdown offers them — the editor says so instead of showing arrows). The first entry
up or the last down → "<label> is already at the top." / "… at the bottom." under the editor. Moving a list back
into the factory order stores nothing again.

**What is NOT possible here** (the web app could): choosing a person's or a step's colour, a step's lead days or
"to-do" flag, a condition's badge tone or its "needs replacing" flag, resetting to factory. A condition added here
can therefore never feed To buy (its `replace` is always false), and a step added here falls due on the day of
departure (`leadDays` 0). Left on purpose in 0.62 (the spec pass): each of these changes what To buy suggests or
when reminders come, which is his to decide; rename and reorder were the parts that change nothing else.

### 2.6 Data
**The model API** (`extension Library`, `Core/Sources/PackingLibrary/SettingsLists.swift`):

| Function | Answer / effect |
|---|---|
| `storagePlaces()` | `orderedNamesFromRows(shared, "places")` (stored order); empty → `DEFAULT_STORAGE_LOCATIONS` |
| `owners()` | `namesFromRows(shared, "owners")` — A–Z (`jsLocaleCompare`, en-US collation); no defaults; empty → (0.62) the owners his THINGS already name: every item's trimmed `ownedBy` sorted A–Z, each normalised name once (the first spelling in that order wins — the same names *Whose it is* offers). Things only, not trip lines, as for `people()`: every name shown is in use by a thing, so none can be removed (the ✕ says "Kim is still used by 5 things, so it stays."); a rename or an Add stores them all as his own list, still A–Z. Until 0.62 the Owners part was empty on such an account while *Whose it is* offered those very names (Open questions 14) |
| `me()` / `setMe(_:)` (0.70, `Me.swift`) | the owner marked "This is me": stored in `meta["me"]` (its own record, so it syncs; in a backup `prefs.me`, read back by the import). `me()` answers it spelled as `ownerChoices()` has it, or nil when nobody is marked or the name is no longer an owner; `setMe` refuses a name that is no owner, nil/blank clears; a rename in Owners carries it (`renameChoice`). Apple Health's review (chapter 07 part 7) treats this owner's things and "Both have one" as his; nobody marked → its guess, the name on most things, and the card asks "Who are you? Mark yourself in Your choices → Owners." |
| `ownerChoices()` | what *Whose it is* on a thing offers: `owners()` then every item's trimmed `ownedBy` sorted A–Z, each normalised name ONCE, first spelling wins (fix of 2026-09-26: one name appeared once per thing he owns); on an account with no Owners of its own the two lists are now the same |
| `people()` | `peopleFromRows(shared)`; empty → (0.62) the packers his THINGS already name (`assignedPeople(items)`, each once, A–Z, coloured `PERSON_COLORS[n % 8]`), so an account that never wrote Packers of its own keeps showing its own people now that the starters are invented; none → `DEFAULT_PEOPLE`, each made a person with a fresh random id. Things only, not trip lines: every name it offers is then in use, so none can be removed only to come back from an old trip |
| `conditions()` | `conditionsFromRows(shared)`; empty → `DEFAULT_ITEM_CONDITIONS` |
| `timeline()` | `phases`; empty → `DEFAULT_PHASES` |
| `usesOf(kind)` | `[key: ChoiceUse]` — as above (0.62: things, trips, templates apart; was one number) |
| `ChoiceUse.refusal(label)` | the sentence of a refused remove (§2.5) |
| `existingChoice(kind, name, except:)` | (0.62) the entry `name` would repeat, as the list spells it, or nil (§2.5 Add step 2); `except` = the key of the entry being renamed |
| `Library.choiceKey(name)` | (0.62) `jsSlice(normName(name), 0, 60)` — the key a place, owner or packer is stored under |
| `renameChoice(kind, key:, to:)` | (0.62) §2.5 Rename; returns the refusal in words, or nil when done |
| `Library.canMove(kind)` / `moveChoice(kind, key:, by:)` | (0.62) §2.5 Move; false when it cannot move |
| `setNames(kind, names)` | only `"places"` and `"owners"` (anything else → returns false, changes nothing); trims, drops empties, keeps one name per `choiceKey` (first spelling wins, 0.62), removes every row of the kind, then appends `namesToRows(kind, clean)` unless `isFactoryList(kind, clean)` |
| `setPeople(list)` | keeps one person per `choiceKey` of the name (0.62); removes every `people` row; appends `peopleToRows(list)` unless factory |
| `setConditions(list)` | removes every `conditions` row; appends `conditionsToRows(list)` unless factory; then installs the live condition list `setItemConditions(list.isEmpty ? DEFAULT : list)` |
| `setTimeline(list)` | `settled = setPhases(list.isEmpty ? DEFAULT_PHASES : list)` (installs the live `PHASES`, sorted and renumbered 0…n-1); `phases = phasesCustomised(settled) ? settled : []` |

**Factory lists (in the code, never stored — "nothing is ever seeded", the v118 lesson):**
- Storage places (`DEFAULT_STORAGE_LOCATIONS`, 12, in this order): Bedroom wardrobe, Chest of drawers, Hall
  closet, Bathroom cabinet, Kitchen cupboard, Garage, Loft / attic, Basement / cellar, Utility room, Storage box,
  Car boot, RV / camper.
- Item conditions (`DEFAULT_ITEM_CONDITIONS`): `new` "New" (no badge), `good` "Good" (no badge), `worn` "Worn"
  (tone `warn`, amber badge), `retire` "Needs replacing" (tone `danger`, red badge, `replace` true). Tones allowed:
  "" (No badge), `warn` (Amber badge), `danger` (Red badge).
- Packers (`DEFAULT_PEOPLE`): two starter people, **Kim** `#3b82f6` and **Robin** `#a855f7` (0.62), with id "" in
  the constant — INVENTED, the practice library's two names. Until 0.62 they were the owner's household by name, as
  the web app's still are; the repository is public. The parity check compares everything about them but their
  names (tools/parity/QUESTIONS.md §16 N8). On an account that never wrote Packers of its own, `people()` shows the
  packers his things name before it falls back to these two (table above).
- "When" steps (`DEFAULT_PHASES`; id · label · lead days · to-do? · colour): `prep` · Preparations · 30 · yes ·
  `#7c5cd6`; `week` · ≥1 week ahead · 7 · no · `#3b82f6`; `daybefore` · Day before (stage / move to RV) · 1 · no ·
  `#06b6d4`; `morning` · Morning list · 0 · no · `#f59e0b`; `door` · At the front door · 0 · no · `#22c55e`;
  `wear` · Wear / carry on the day · 0 · no · `#ec4899`; `after` · After / recovery · −1 (after the trip) · no ·
  `#14b8a6`. Each also carries a one-line hint and an emoji from the web app; neither is shown in this app.
- Owners and trip presets have no factory list. (With none of his own, Owners shows the owners his things name — 0.62.)

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
- 0.70 — "This is me": model `AppleHealthReviewTests.testThisIsMeDecidesWhoseThingsAppleHealthMarks` (the guess
  until marked; Robin marked → Robin's things and "Both have one" are his, Kim's left; one at most; no-owner refused;
  kept through a rename, the sync records and a backup; unmarked → the guess); UI
  `testThisIsMeDecidesWhoseThingsAppleHealthMarks` (`-uiTestingHealth`: the review asks `review-health-who` and says
  "Marked 3 didn't use, 3 used."; pen on Robin (`list-owners-edit-1`) → `list-owners-me` on, tag
  `list-owners-me-1` and none on row 0; the review then "Marked 3 didn't use, 4 used." and no longer asks). Seen
  red with `mainOwner()` planted to ignore the mark.
- Model — `SettingsListsTests`: `testAListWithNoRowsIsTheFactoryOneAndHisOwnIsStored` (factory answers, nothing
  stored; `setNames` trims and drops empties, one record per entry with keys `places:garage shelf`…; `setNames`
  refuses `people`; it also pins the two INVENTED starter packer names, Kim and Robin), `testEachOwnerIsOfferedOnce` (40 items, three
  owners → each once, the list's own A–Z first, then the one not on it; nobody named → `[]`), `testPuttingTheFactoryListBackRemovesItsRows`,
  `testHisOwnTimelineIsStoredAndTheLiveStepsFollow` (8 steps stored and live; back to factory = 0 records),
  `testWhatIsInUseIsCounted` (places, owners; a step's `things` are things only, its `trips` the one trip).
  0.62: `testAStepsNumberIsItsThingsAndTheRefusalSaysWhatElseHoldsIt` (one thing, five lines = one trip, two places =
  one template; every wording of `refusal`), `testADuplicateIsFoundTheWayTheListWouldSeeIt`,
  `testTwoLongNamesTheStoreCannotTellApartAreOneName` (no two records under one key; packers too),
  `testRenamingAPlaceCarriesItToEveryThingAndTripLine` (any spelling follows, another place is left alone, counts
  of things/lines/templates unchanged, the three refusals, a change of spelling only),
  `testRenamingAnOwnerOrAPackerCarriesItToEveryThingAndTripLine`, `testRenamingAConditionOrAStepChangesOnlyItsWords`
  (ids, tone, lead days and timeline place stay; the live lists follow), `testMovingAnEntryChangesItsPlaceAndNothingElse`
  (first up / last down refused, owners refused, steps re-ordered live and back to factory = nothing stored),
  `testPackersWithNoListOfHisOwnAreThePeopleHisThingsName`; 0.62: `testOwnersWithNoListOfHisOwnAreTheOwnersHisThingsName`
  (each once, A–Z, things not trip lines, the same as `ownerChoices`, nothing stored by looking; every one in use; a
  twin name refused, a rename stores the list and both spellings on things follow; an Add keeps the names things carry;
  owners cannot move).
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
  `testWhoseItIsOffersEachOwnerOnce` (on a thing, with its Whose it is list opened (0.64): `thing-owner-0` reads
  "Both have one", then exactly "Kim", "Robin"; Notes sit between Name and Kept at home; the heading line is ≥ 15
  tall over a drop-down field `Metrics.tap` tall).
  0.62: `testOwnersAreTheNamesHisThingsCarry` (the sample stores no owners: the Owners part reads Kim, Robin and no
  third; ✕ on Kim → "Kim is still used by 5 things, so it stays."), `testEscapeClosesSettingsWindowsAndNeverReplaces`
  (a place typed and not added, then Escape: closed, and no 13th place).
  0.62: `testYourChoicesSaysWhyRightWhereItWasPressed` ("garage" → "You already have Garage." and no 13th row;
  Remove on "≥1 week ahead" → `lists-problem` says "on 1 trip" and sits within 60 points under the ✕ pressed),
  `testAChoiceIsRenamedAndMovedAndItsThingsFollow` (Hall closet → Hall cupboard through the pen; the editor
  closes; ▲ moves it to row 1 with the editor following; ▲ at the top says so; the Rain jacket's *Kept at home*
  then reads "Hall cupboard").
- UI — `testEachPlaceHasACodeToPrintAndOpen` (0.69): `list-places-name-5` is "Garage"; `list-places-code-5` opens
  `place-code-detail` titled "Garage"; `place-code` at least 200 wide; `place-label` 48 points tall (64 dots at ¾
  point); `place-label-share` (iPhone) / `place-label-save` (Mac); `place-code-open` → `place-detail` "Garage",
  "Everything kept here: 2 things."; both closed; `list-places-labels` there, and on the iPhone a press turns it
  into `list-places-labels-share` reading "Share 12 labels". Pictures `place-code`.
- **Not covered by any test:** adding to owners, packers, conditions or steps from this screen; the packer
  colour rotation; removing an entry that is NOT in use; removing the last entry (factory list returns); the
  needs line disappearing on typing (tested only on *Your things*); renaming or moving on screen for any part but
  places (the model tests cover every kind).

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

**On screen** (a card: padding 12 at the sides and 10 above and below — 14 all round until 0.67 — its lines 6 apart
(8 until 0.67), card fill, radius 12, 1-pt line border, container id `settings-reminders-card`):
- A `Toggle` (id `settings-reminders`; a switch on the iPhone, a check box on the Mac), tinted Trips green
  `#2f9e63` ("Green when on, like every switch he knows: the Settings slate read as 'off'"). Its label: **"Remind me
  to pack"** (18 bold ink) and **"On this device, at 9 in the morning of each day a packing step is due —
  Preparations a month ahead, then a week ahead, the day before and the day you leave."** (14 muted, wraps; 0.62 —
  until then it named only "a week ahead, the day before, the morning", though Preparations and every step with
  lead days ≥ 0 remind too).
- If the device does not allow the app to remind him — the system's question just refused; or (0.62) the app's
  notifications switched off in the device's Settings, whether the switch here is on or off; or (0.62) the switch on
  while the app has no permission at all — **"This device does not allow the app to remind you. Allow it in the
  device's Settings, under Notifications."** (15 semibold red, id `settings-reminders-refused`). Never asked yet is no
  refusal: no line.
- Else, if on: **"Next: <d Mon> · <trip name> — <says>"**, e.g. "Next: 14 Oct · Sunny weeks — ≥1 week ahead: 12 to
  pack", or, with nothing ahead, **"Nothing to remind you of yet: no trip with dates ahead."** (15 semibold, Settings
  slate, id `settings-reminders-next`). Off → no line. The line sits OUTSIDE the Toggle so a test can read it (§23).

**Behaviour.** Turning it on runs, in a Task: `askToShow()` (under the UI tests: always yes; otherwise
authorized/provisional → yes, denied → no, not determined → the system's permission question for alert + sound);
then `on = want && ok`, `refused = want && !ok`, the permission looked up again (below), then `reschedule(library)`.
Turning it off: `on = false`, `refused = false`, the permission looked up again, reschedule (which removes them).
`refused` is not stored: leaving Settings forgets it — but the card looks up, whenever it is shown, whenever the app
comes back to the front (0.62) and after every turn of the switch (0.62), what the device says now
(`PackingReminders.permission()`: `allowed` = authorized or provisional, `refused` = denied, `notAskedYet` = not
determined; it never asks him), and `blocked = refused || (on && not allowed)`. The red line shows when `refused` or
`blocked`, instead of "Next" (Home spec, section 14). Until 0.62 only a switch that was ON looked: refused while off,
the line was gone as soon as he left Settings, and nothing said why switching on would not work (Open questions 27).

`reschedule(library)` (skipped entirely under the UI tests): removes every pending notification whose id starts
`packing-`; stops if the switch is off or permission is not authorized/provisional; otherwise adds one
notification per entry of `upcoming(library)`: title = trip name, body = `says`, default sound,
`userInfo["tripId"]`, id `packing-<tripId>-<YYYY-MM-DD>`, a non-repeating calendar trigger at 09:00 local on that
day. It runs when the switch changes, whenever the library settles after a change (`RootView`: the library
publisher debounced 2 s), and (0.62) whenever the app comes back to the front. A notification arriving while the app is open shows as banner + list + sound; tapping
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
line names "Sunny weeks" and "week ahead"; off → the line goes); `testRemindersSayWhenTheDeviceBlocksThem`
(`-pretendRemindersBlocked`: on and blocked → the red line, no "Next", again after Home and back; 0.62: switched off
→ the line stays, and after Home and back the switch is off and the line still there). Model `CountdownTests`
(`testTheNextTripIsTheSoonestStillToLeave`, `testAStepFallsDueItsLeadDaysAheadAndGoesWhenPacked`,
`testOneReminderPerTripPerDayFromTodayOn` — dates, merged days, limit, a reviewed trip stops reminding —
`testDaysAreCountedOnTheCalendar`). **Not covered:** the line at the moment the system's question is refused (the
system's own window), "not asked yet" giving no line (the tests answer yes or refused, never "not yet"), the actual
scheduling (skipped under tests), a tapped notification opening the trip, the 09:00 cut-off for today.

---

## 3a. The door check — notifications (`Store/DoorChecks.swift`, `PackingLibrary/DoorCheck.swift`; 0.69)

His choice of idea 4 (7 Oct 2026, "c, a time"). Set on a trip ("I leave at", Create new trip and Trip settings —
spec 03 "The door check", which has the words, the moments and the tests). The notification side:
- **iPhone only** (`#if os(iOS)`): the Mac at home saying the same would be the same news twice. The Mac shows "I
  leave at" too (the times sync) with "…your iPhone names…" under it, and never asks for permission.
- **Permission**: the app's one notification permission, shared with Remind me to pack. "Add a time" asks for it
  (`PackingReminders.askToShow`, the system's own question, once); "I leave at" says in red under the times when the
  device does not allow it (`PackingReminders.permission() == .refused`, looked up whenever a time changes) — the
  same words as the Remind me to pack card. It does NOT depend on the Remind me to pack switch: a time set on a trip
  is the asking.
- **Scheduling**: `DoorChecks.reschedule(library)` — removes every pending id starting `door-`, then adds one
  calendar notification per `Library.doorChecks(now:)` entry (title, body, default sound, `userInfo` `tripId` +
  `door`). Run from `RootView` whenever the library settles (debounced 2 s) and when the app comes to the front.
  Under the UI tests: nothing reaches the system; `planned` holds the plan (`-showDoorChecks` shows it on the trip).
- **Tapped**: the shared notification delegate (`PackingReminders`) sees `door` in `userInfo` and calls
  `DoorChecks.open(tripId, kind)` (RootView: Home, `model.tripFocus`, `model.tripToOpen`), else the packing reminder's
  `open`.

## 3b. "Where is my …?" — Siri and Shortcuts (`Store/WhereIsIntent.swift`; 0.69)

Stop B of his idea plan: "On site you ask 'Where is my charger?' and the answer comes back: 'Backpack, front
pocket.'" — on the iPhone and the Mac, on site and on the way home. `WhereIsIntent` ("Where is my thing?";
`openAppWhenRun = false`) takes a `ThingEntity` (`ThingQuery`: his things not "Not in use", A–Z, also found by a
typed or said part of the name) and answers `WhereAnswer.said` as a dialog and as its value; a thing gone since:
"That thing is not in Packing any more." Phrases (in `PackingShortcuts`, the fourth App Shortcut, tile "Where is my
thing?", symbol `bag` — the Shortcuts app's own tile, as the other three): "Where is my <thing> in Packing",
"Where's my <thing> in Packing", "Ask Packing where something is" (Siri asks "Which thing?"). The things offered
by name follow his library (`updateAppShortcutParameters` on every change, as for the grab lists). The answer's
rules: spec 03, "Bag pockets on a trip, and Where is my …?". **Not covered by a UI test** (no test can speak to
Siri): the words come from `Library.whereIs`, covered by `PocketsTests.testWhereIsMyCharger`, and the same answer
shows first in Search (`testSearchShowsWhereAThingIsOnTheTripUnderWay`).

---

## 4. *iCloud sync* card (`SyncCard.swift`) — briefly

Full behaviour belongs to the storage/sync chapter and `docs/store.md`; here only what Settings shows.
Origin: field test 3 Oct 2026 ("we need to get the sync going because I need to work from the Mac"), 0.54.
A card like Remind me to pack's: padding 12 at the sides and 10 above and below, its lines **4** apart (0.67; 14 and 8
until then).

- Header: **"iCloud sync"** (18 bold) and a state pill (13 heavy white, id `sync-state`; `SyncCheck.state`): **"Off"**
  (muted fill) when this build keeps its library on the device only (`model.usesICloud == false`, always so under
  tests); **"Can’t tell"** (muted, 0.62) when iCloud is on but the store file could not be read — then no
  Sent/Not-in-iCloud/problem lines show, only `sync-unknown` "This device cannot tell right now how the sync is
  going."; **"Stuck"** (red) when something is not in iCloud yet or the last send/receive failed; else **"Working"**
  (green). Until 0.62 the unreadable case said a green "Working".
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
- "Not in iCloud yet" lists kinds most first; equal counts in the order of the store's tables (0.62).
- Tests: UI `testSyncNowChecksInFromThisDevice`, `testSyncNowOnAnEmptyDeviceKeepsTheTwoDoors` (0.62); model
  `SyncCheckInTests.testACheckInTravelsWithTheLibraryAndKeepsTheDevicesApart`, `SyncCheckTests` (0.62: the reading,
  the pill, the order, the plain words, `<when>`).

---

## 5. The guide doors (`GuideDoors` in `Guide/GuideScreen.swift`)

**Purpose and origin.** *What's new* and *How it works* are "his standing rule from the web apps, missing here
until 0.23"; *Your first real trip* got its own door in 0.56 because they asked to keep it where they can read it
again (field test 3 Oct 2026: "Please save this in the app … so that we can choose to read that later as well").

**On screen.** A `VStack(spacing: 0)` of three door rows (`SettingsDoorLabel`, §1), a `CardHairline` between them —
the top three rows of Settings' card of doors, whose fourth is *Open a shared link* (§11); Settings wraps them in
`.settingsCard()`. Until 0.67 each was a card of its own (min height 60, 10 apart).

| Door | Line under it | Id | Opens |
|---|---|---|---|
| **What's new** | "<newest version> · <its title>" from `Releases.all.first`, e.g. "0.60 · Find a thing on a template" | `settings-whatsnew` | `WhatsNewScreen` |
| **How it works** | "The whole app in plain words, screen by screen" | `settings-howitworks` | `HowItWorksScreen` |
| **Your first real trip** | "In 6 steps, from a backup to the review" | `settings-firsttrip` | `FirstTripScreen` |

One `.sheet(item: page)` (`Page` = `whatsNew | howItWorks | firstTrip`) shows the chosen page.

**The sheet header** (`GuideHeader`, shared by all three): the title (22 heavy, Settings slate, id `guide-title`),
Spacer, **Done** (filled `HeaderButtonStyle`, slate, id `guide-done`, calls `dismiss()`; Escape too, ⌘. on an iPhone
keyboard — 0.62), padding 16. Each page then
scrolls in a `KeyboardAwayScroll` padded 16 / 24 on `Theme.bg`. Mac only: `.frame(minWidth: 520, minHeight: 620)`.

---

## 6. *What's new* (`WhatsNewScreen`, `Guide/Releases.swift`)

**Purpose and origin.** "Every version, newest first, in his words — what was added, changed, fixed and removed.
His standing rule from the web apps: the version log and 'How it works' are updated on EVERY release." The UI test
`testWhatsNewStartsWithThisVersion` fails the build when the top entry is not the version being built.

**Structure of an entry.** `struct Release { version, date, title, new: [String], changed: [String], fixed:
[String], removed: [String] }`, `id = version`. `Releases.all` is a hand-ordered array, newest first; versions
are plain strings ("0.10" follows "0.9"). Dates are written "4 Oct 2026".

**On screen.** Container id `guide-whatsnew`; a `VStack(spacing: 12)` of cards — every card built at once since 0.62 (a
lazy list left the next card unbuilt once the newest entry outgrew the screen, and the Mac test could not scroll to it) — (padding 14, card, radius 12,
line border, container id `guide-release-<n>`, n = position, 0 = newest). Each card:
- First line (baseline-aligned, spacing 10): the version (20 heavy, monospaced digits, Settings slate, id
  `guide-release-<n>-version`), the title (17 bold ink), and — only when `version == AppInfo.marketing`
  (`CFBundleShortVersionString`) — the marker **"On this device"** (15 heavy since 0.62, 12 until then; Trips green, 1.2-pt green capsule
  outline, padding 8×3).
- The date (15 muted; 14 until 0.62).
- Up to four parts, each only if it has lines, always in this order: **NEW** (Trips green), **CHANGED** (Home
  blue), **FIXED** (Care orange), **REMOVED** (muted). The part name is upper-cased, 15 heavy (12 until 0.62), letter-spaced 0.6,
  in its colour; each line is a 6-pt dot in that colour and the text (16 ink, wraps).

**The version history** (71 entries; N/C/F/R = number of New/Changed/Fixed/Removed lines — every count checked
against `Releases.swift`):

| Version | Date | Title | Lines | Gist |
|---|---|---|---|---|
| 0.71 | 8 Oct 2026 | A small core, a big kit you tick | N1 C1 | Activity area can be Always packed (and back); Make a small core from this… with Paste a list (indented lines = kits), a kept copy first (SmallCore.swift, SmallCoreSheet.swift; spec 04 §14b) |
| 0.70 | 8 Oct 2026 | Drag to reorder | N1 C1 | a grip on every reorderable row (drop-downs and Your choices; Reorder.swift), template names violet in Your things (ThingDetailLine) |
| 0.69 | 7 Oct 2026 | Change your lists where you pick from them | N2 C2 | chapter 07 part 13: rename, reorder, remove and add inside every pick-one list of his own (ChoiceEdits), held until Save; kinds of thing his own list (meta categories) |
| 0.68 | 7 Oct 2026 | Beyond the list | N9 C3 | chapter 07 parts 1-12: Mac keyboard on a thing's page, sections edited from it, place codes + P-touch labels, search in notes, bag pockets + Siri "Where is my ...?", the door check, kits, Apple Health in the review + This is me, the vault page, template reminders, Pack by voice (test); the Weather freeze fixed; GitHub: an already-green commit is not tested twice |
| 0.67 | 7 Oct 2026 | Your field test: lines without air, an open calendar | N2 C6 | his ten points on the field-test page (6 Oct, testing 0.63): Create new trip's month grid always open, Create waits for the last day, Clear dates, no Dates switch; Full trip \| Quick under the name; Context per workout (`activityContexts`, spec 01/03); list lines `Metrics.line` 30 / 22 (trip, template, To do, To buy, grab list), Settings' doors one card, slim grab tiles; one centre line for every tab header (`ScreenHeader`), Home leads with Grab and go, `Metrics.screenTop`; the Mac's main window without a title bar, its headers in the strip after the window buttons (`Metrics.windowButtons`); Share's mark centred (`GridShape`); Arrange's two grips; GitHub on five machines, the release waits 90 minutes (§27, §28) |
| 0.66 | 6 Oct 2026 | Column widths | N1 | the things table's columns (and Thing) are dragged wider or narrower at their heading's right edge, kept in `ams.table.widths`, a double tap puts one back (spec 05); guide: a line after the Care topic's table line |
| 0.65 | 6 Oct 2026 | A table without air | C1 | the things table's rows `TableColumns.rowHeight` 22 on the Mac / 28 on the iPhone (34 before), boxes 14 / 18, the open arrow centred, the grid anchored top-left (spec 05); not in the app: GitHub runs the UI tests in 3 iPhone + 2 Mac groups side by side (§27), the fifth Escape test runs on the Mac only, the TestFlight log step can no longer fail a release (§28) |
| 0.64 | 6 Oct 2026 | Drop-downs, your own bags, and sections | N3 C3 | every pick-one list on a thing's page and a template's row is a `DropDown` (§ DropDown); Kept at home from his places (a new place joins Your choices); a trip sorts by Section from one Sorting drop-down; a thing's Section on each template set from its page (spec 05); Usually packed in = his own bags only (`bagNames()`); the thing's page in his order; the cabin switches without explanations; guide: Packing a trip's Sorting line, the template row's drop-downs, Care's three thing-page lines |
| 0.63 | 5 Oct 2026 | Arrange a template | N1 | Arrange on a template: drag headings and things (its things come along), rename and remove a heading; new trips pack in the new order (spec 04 §6a, §13a) |
| 0.62 | 5 Oct 2026 | The big check-up: everything we found, put right | N7 C26 F12 | the fix-everything program: every finding of specs 01–06 dealt with (each chapter's open questions say how); Apple's standard text styles and slim controls throughout (§21), one-line rows in Your things and Search; Escape on the Mac everywhere, Owners from his things, the reminders line kept; rename and reorder in Your choices; template notes on a thing's page; Care schedules; Pack weather gear anyway; 0.59's Worth a look line moved from Changed to New |
| 0.61 | 5 Oct 2026 | Your own grab lists, and a restore that brings back everything | N1 C5 | own grab lists can be filled, keep their ticks and be deleted; Off Home really takes a list off Home; Make says where the list went; restore accepts a cabin bag and brings back every note |
| 0.60 | 4 Oct 2026 | Find a thing on a template | N1 C1 | search field above a template's list, "how many of all", ✕; Worth a look offers a photo only when it can tell the photo is more than a day old |
| 0.59 | 4 Oct 2026 | A deleted trip takes its photos along | N1 C3 | trip delete removes its bag photos unless shown elsewhere; Worth a look offers to remove left-behind photos older than a day; "Nobody's in particular" → "Both have one"; Notes under the name |
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
4. Twelve topic cards (eleven until 0.71) (padding 14, card, radius 12, line border, container id `guide-topic-<n>`): a header row —
   the topic's section mark (`SectionMark`, 24 pt, line 1.9, in the section's colour) and the title (19 heavy ink)
   — then each line as a 6-pt dot in the section colour + text (16 ink, wraps).

**The topics and their lines** (summarised; the code holds the exact sentences):

0. **Home** (Home mark): (1) eight grab lists, four in a row; tap one, tick what is in your hand; the count stays at
   the top; Ready to go too early says Not yet in the middle with what is missing; ticks clear themselves 6 hours after
   the last tap (0.62). (2) Grab Lists: the ones on Home
   (up to eight) in order, and the waiting ones; make a new one at the bottom; tapping a waiting one opens it, On Home puts it on
   Home — when full, you pick which one steps back; Make refuses a name already in use (0.62). (3) The countdown to the next trip under the grab lists; tap
   opens the trip. (4) Create new trip: name, then Full trip or Quick (Quick = only the ticked templates, no common
   base or transport kit, said in the line under it); the dates in the calendar that is always open (first day,
   last day, set at once; the line under it says range and nights; Clear dates leaves none; no day tapped = no
   dates; Trip settings has the field with OK and Cancel) (0.67). (5) Create trip is always ready; what is missing is said under it.
   (6) So is every Add, New, Make, Weather: empty press adds nothing and a short red line says what is missing,
   gone as soon as you type. (7) Pick templates, Transport, Season, Food; workout colours (Swim blue, Bike yellow,
   Run green, Strength orange, Breath work lavender, Mobility pink); each picked workout its own Context line
   (Indoor, Outdoor, Race) set in under them — Run outdoors and Swim indoors on one trip (0.67); templates without an activity area come last, under Other templates (0.62). (8) Laundry: per-night things count only the nights before a wash — 4 unless 3, 5, 7, 10 or 14; shown as
   ×4 · laundry with a washtub. (9) This Device: how many trips, things and templates.
1. **Packing a trip** (Trips mark): tap to tick / untick; the round button ticks a section; Check before you go
   (cabin red/orange, expiry six months ahead for passports/IDs); the pen opens Trip settings (every field it holds, Pack weather gear anyway included;
   Save rebuilds, own ticks/additions/what was sent stay; a swipe down closes it only when nothing is changed — 0.62); Start a new trip from this one; Tick everything / Clear every tick (asks first); Save as
   Excel and Share side by side; folding sections (remembered per trip); ⊘ not this time (any tick goes — 0.62), ↻ back unticked; Sorting When /
   Into / From where / Category; Weather line with + and Add all; tap a bag for Goes in the cabin; Bags fill
   colours and the scale reading, Clear, up to three photos, "Tap to weigh" on a bag with nothing weighed (0.62); Set place under "No place set"; (0.69) opened from a place's label, only what is kept there — the place's name
   under Sorting shows every line again; typing a thing adds it
   to this trip only, Bought on site adds it ticked; Delete trip at the very end asks first (things and
   templates stay); a trip someone sent arrives Quick, and sharing sends just the list (0.62). (21 lines.)
2. **Pack by voice (iPhone, a test)** (Trips mark, 0.71 — spec 07 part 10): the button at the end of a trip's
   Sorting row walks what is still to pack, place by place as From where sorts them — the place, then the thing
   ("Garage. Goggles.") — and listens for five words; Packed ticks, Skip sets aside (as ⊘), Later moves on
   unticked, Where says the place again, Stop ends; other ways of saying them (packed it, next, not this time,
   that's all); the count at each new place and after every five things ("Garage done, 12 of 40"); English,
   understood on the iPhone itself without the internet, nothing leaves it, AirPods work; asks for the microphone
   and speech recognition the first time, and says where to allow them; the panel (thing, place, said, heard, the
   five words as buttons); the screen stays on, put away it stops; at the end what it did, how often it understood,
   how long it took, each answer — and it stays only if it understands at least 9 times in 10 and beats tapping;
   "once more?" over what was left for later; a scanned place code starts it at that place (switch on the panel).
   (8 lines.)
3. **On site** (Trips mark): the door appears once the trip began or something was bought, with a summary line
   ("2 bought · 1 left · 3 notes · home 4/9"); Bought on site; Left on site with Undo; Maintenance notes (also
   dated onto the thing); Pack to go home with its own ticks; Used up / Undo; search with ✕, Tick everything;
   notes and Open on the way home; the packed-bag photos at the top, Next steps through them. (10 lines.)
4. **After a trip** (Trips mark): Review (tap unused, type missed, pick its template, Add, Save); the loop strip
   under a trip's name (Plan · Pack · On site · Review · Refine) with the tab mark; nothing is removed — "Didn't
   use" adds to history, missed things go onto a template. (4 lines.)
5. **Trips** (Trips mark): Now, Coming up and Done — Now always there; Planned / Packing / Ready; reviewed trips fold
   away; Your year; All your trips with the map; the pin opens Where you have been (pins with counts, line oldest
   first, card per place; a trip joins as soon as it has a place). (3 lines.)
6. **Your templates** (Templates mark): templates are the building blocks, in activity areas (GA, WET…); each has
   an icon (50 drawn ones, or Letter); + New asks the activity area; rename, ✕ takes a thing off (asks; the thing
   stays), How many and Section per template, a blank How many or Note = "the same as the thing" (0.62); Find a thing on this template ("3 of 40", ✕, adding clears it);
   Choose from your things (in the order ticked) or type a new one (one already there is not added twice — 0.62);
   folding in the picker (Fold all / Unfold all, counts, search opens
   all); Group: sections, When, Into, From where, Kind, A–Z; Delete template asks first, with Activity area beside it (0.62); Arrange — drag headings and things, rename or remove a heading (0.63); Share at the top (also on
   a grab list); Refine (violet card) after two or more reviews — Keep / Drop. (13 lines.)
7. **Care** (Care mark): Your things (changes reach trips ahead on unticked lines; a name he has is not added
   again — 0.62); Just added at the top until you
   leave; ✕ in search; (0.69) the search finds words in a thing's notes and its templates' notes, the matching line
   under the thing; On a plane and Valid until (+1 month … +10 years, red once run out); the rest of a thing's page — its templates'
   notes under Notes, places to tap under Kept at home, No bag, Care how often and what to do (0.62); Bags with max weight,
   litres, empty weight and their own page; All your things · table (sort, filter, columns, Change all — the line says what changed, Undo puts
   back just that, the bar counts ticked things out of sight — 0.62;
   own window on the Mac); Filter by every column (pills, Clear); Sort up to three levels (blank last); the arrow
   opens the thing and returns to the same spot; Services List or Calendar (Done today, Today); the numbers under
   the services. (19 lines.)
8. **To do** (To-do mark): To do; To buy with worn-out or run-down suggestions, Undo after a removal (0.62); Send to Reminders into the list
   "To buy · Packing", each once, dated, all day, ticks read back; ticks and removals here follow there, and a reminder deleted there can be sent again
   (0.62). (3 lines.)
9. **Settings** (Settings mark): Remind me to pack (9 in the morning, per device, next reminder shown; says in red when the iPhone does not allow
   notifications, switch on or off, and where to allow them — 0.62); iCloud sync
   (times, what is not in iCloud, Sync now, Copy details for Claude, "Can't tell" explained — 0.62); Save a backup / restore (a copy is kept
   first; when the last backup was saved, where the library came from — 0.62); Your first real trip door; Your choices (places, owners, packers, conditions, When steps; the pen renames, the arrows move, the grip drags (0.70), owners stay A–Z,
   no duplicates, the reason for a refused remove right under it, Owners from his things when he has no list — 0.62);
   (0.69) each storage place's square code and its label for the P-touch, 12 mm tape (iPhone: Share → Save Image, and
   Brother's app takes it from Photos; Mac: saved as a picture), all places at once; the Camera on a label opens the
   trip being packed on that place, what goes back after a trip, or everything kept there — Open on the place's page
   shows the same on the Mac; Worth a look
   (only when something seems wrong; one-press fix such as Remove it; an undated photo nothing shows goes only on Remove — 0.62); Open a shared link (trip arrives unticked,
   template links to existing things — with a name he has, a name of its own or Replace (0.62) —, grab list takes a free Home place or waits). (9 lines.)
10. **Shortcuts and the Action button** (Home mark): three actions (Choose a grab list, Open a grab list, Open my next
   trip); the Action-button path (iPhone Settings → Action Button → Shortcut → Packing → Choose a grab list); if
   Packing is missing, open it once; Home Screen or Siri ("Open Swim in Packing"). (4 lines.)
11. **iPhone and Mac** (Settings mark): both hold the same library through iCloud, a change arrives within a minute or
    so; the magnifier searches everything (a thing's notes too — 0.69); on the Mac Escape closes a window as its Cancel or Done does, never saving
    (0.62). (3 lines.)

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
| 8 | Context | Home | Indoor, Outdoor or Race: how a workout is done, picked for each workout on its own. It adds what that setting needs. |
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

The door only (the sheet `OpenSharedScreen`, container `shared-screen`, belongs to the sharing chapter; its Done,
`shared-done`, is pressed by Escape too since 0.62). Built like
the other doors (`SettingsDoorLabel`, §1): **"Open a shared link"**, **"A trip, template or grab list someone
shared"**, chevron; id `settings-openshared`; it owns its sheet. Since 0.67 the last row of the card of doors, under a
`CardHairline` (a card of its own until then). Origin: 0.38 — the web app's "Paste a shared link".
Tests: `testATripIsSharedAndOpenedAgain`, `testATemplateAndAGrabListAreSharedAndOpenedAgain` (both enter here),
`testSettingsDoorsAreRowsOfOneCard` (0.67, §1).

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
2. Memberships pointing at a template that no longer exists: "<n> thing sits / things sit on a template that no
   longer exists." (0.62; "on a list" until then, though since 0.34 a list is only what you pack from) — no names,
   no repair.
3. Photos nothing shows any more (`unusedPhotos(now:)` in TripEdits.swift: not in use by anything — `photoInUse`'s
   rule: no thing, no trip line, no packed bag; since 0.62 gathered in ONE walk, `photoIdsInUse()`, instead of one
   walk per photo, as this is asked on every drawing of Settings — and created strictly more than 86 400 s before now). `createdAt` is read
   by `isoMoment` (ISO 8601, with or without fractional seconds); a photo whose `createdAt` is empty or cannot be read
   is KEPT and never offered — "a date that cannot be read is no proof of age" (0.60; until 0.59 it counted as old
   and was offered at once). Sentence: "<n> photo is / photos are no longer shown anywhere — left behind by a deleted
   trip." with the button **"Remove it"** / **"Remove them"** → `model.change { $0.repair("unusedPhotos") }` →
   `removeUnusedPhotos()` (returns how many went). "Only photos older than a day, so one still on its way from your
   other device is never touched" (Release 0.59); "Worth a look offers to remove a photo only when it can tell the
   photo is more than a day old" (Release 0.60, under Changed).
4. (0.62) Photos nothing shows whose `createdAt` cannot be read (`undatedUnusedPhotos()`): "<n> photo(s) with no
   date is / are no longer shown anywhere." with **"Remove it"** / **"Remove them"** → `repair("undatedPhotos")` →
   `removeUndatedUnusedPhotos()`. Never offered with worry 3 (0.60's rule stands); named on its own, and only his
   press removes it. This app dates every photo it makes, so one without a date is old, not on its way.
A thing on no template and in no trip is deliberately NOT a worry ("he can keep things loose").

**Tests.** Model `HealthTests` (`testASoundLibraryHasNothingToSay`, `testTwoLibrariesThatMetAreNoticed`,
`testTheNameIsJudgedTheWayTheAppJudgesNames` — "  SAILING " twins "Sailing", `testAThingOnAListThatIsGoneIsNoticed`,
`testThingsOnNoListAreNotAWorry`); `PhotoTidyTests` (`testDeletingATripTakesItsBagPhotosAlong`,
`testAPhotoSomethingElseStillShowsStays`, `testWorthALookOffersToRemoveAPhotoLeftBehind` — clock frozen at
2026-10-04T10:00Z: the photo from 2 Oct is offered, the one from 30 minutes ago and the one with `createdAt` "" are
not; exact sentence and "Remove it"; the repair returns 1 and leaves the other two). UI `testALibraryThatHasMetAnotherSaysSo` (sound sample: no heading;
`-uiTestingTwoLibraries`: heading, "twice", names present), `testWorthALookRemovesAPhotoLeftBehind`
(`-uiTestingOldPhoto`: "1 photo is no longer shown anywhere" and, 0.62, "1 photo with no date…" under it; Remove
it → the old one goes, the undated worry moves up; Remove it → card gone, photos count 0); model
`UndatedPhotoTests` (0.62). **Not covered on screen:** the lost-membership worry, the six-name cut with " …",
"Remove them".

---

## 13. Backup — *Save a backup…*

**Purpose.** A real file he can see (docs/store.md rule 10): the Save window on the Mac, Files on the iPhone — "the
same file the web app writes, so either app can read it."

**On screen.** `SectionTitle("Backup")` → **"BACKUP"** (18 heavy, letter-spaced 0.8, ink, 16 pt above, id
`backup-heading`). **"Save a backup…"** — full width, min height 52, Settings-slate fill, radius 12, 18 bold white,
id `backup-save`. Under it the status line (15 medium muted, id `backup-status`): by default **"The same file the web
app writes, so either app can read it."**, otherwise the last message. Under that, once a backup has been saved from
this device (0.62): **"Last saved from this <iPhone|Mac> <when>."** (15 medium muted, id `backup-last`; UserDefaults
`ams.backup.savedAt`, per device, cleared under the tests). No reminder.

**Behaviour.** Press → status "Choosing where to save…", `saving = BackupDocument(data: library.backupData())` (built
now, 0.62) and `exporting = true` → `.fileExporter` with it, type `.json`, default name `Library.backupFileName(on: Today.local)`
= **`ams-packing-list-backup-YYYY-MM-DD.json`** (the local date). Saved → "Saved: <file name>" and the moment kept for
`backup-last`; cancelled or failed → "Not saved." `BackupDocument` is a `FileDocument` reading/writing the bytes unchanged (readable type `.json`).

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

**Checking before offering** (`offer` → `LibraryModel.inspectBackup(data)` = `Importer.read`, which since 0.62 leaves
the live "When" steps and conditions as they were): parse the JSON and require
`BackupFile.looksLikeBackup`, else "That is not an AMS Packing backup file."; import it in memory with
`Importer.library(from:)`; if the import does not round-trip faithfully, "The import did not come back the same
(<n> rows differ), so nothing was stored."; otherwise `pending = PendingRestore(library)` → the sheet opens. Nothing on the device changes until he confirms.

**The sheet** (container id `restore-detail`; `.frame(minWidth: 420, minHeight: 520)` on the Mac only — 0.62; on the
iPhone it was wider than the screen and its edges were cut off):
- Header: **"Restore from a file"** (22 heavy ink) and **Cancel** (outlined `HeaderButtonStyle`, slate, id
  `restore-cancel`) → closes the sheet; the answer "no" is given once it has gone. Escape presses it (⌘. on an iPhone keyboard — 0.62); Return
  presses nothing, so no key ever replaces.
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
  `restore-confirm` → closes the sheet; the answer "yes" is given once it has gone.

**After the answer** — given by `RestoreSheet`'s `onDisappear`, i.e. only once the sheet has GONE (0.63: on the Mac,
restoring while the sheet was still closing left it attached but invisible, and Settings took no more clicks — the
kept copy's row did nothing, found on GitHub's Mac run) — (`pending = nil` first): no → status "Nothing was replaced."; yes → `model.restore(library)`:
(1) `RescueCopies.write(current)` — BEFORE anything is replaced; (2) `commit(Importer.restoring(imported, over:
current))` — the record difference between what was held and the file's library (with the devices' check-ins kept,
0.62) is applied to the store (everything else not in the file is deleted); (3) `reload()`. Then `copies` is re-read
and status = "Restored from the file: <n> template(s), <n> thing(s) and <n> trip(s). A copy of what was here is kept
on this device." (the counts since 0.62); an error → its description. Dismissing the sheet any other way — swiping it
down on the iPhone — answers "no": `RestoreSheet` keeps `choice` (set by Cancel or Replace, nil otherwise) and its
`onDisappear` calls `answer(choice ?? false)`, so the status says what Cancel says: "Nothing
was replaced." (0.63; in 0.62 it was the sheet's `onDismiss`, dropped because of the Mac — item 18; until then the
status said nothing — Open questions 17).

**Tests.** UI `testARestoreShowsWhatTheFileHoldsAndThenReplacesEverything` (device 10 things; file 2 vs now 10;
`restore-fewer` shown; 0.62: the sheet inside the window; Cancel changes nothing; confirm → 2 things, 0 trips, the
counts in the status line, `device-import`); 0.62: `testSettingsOpensYourChoicesAndTheRestoreOneAfterTheOther`
(twice: Your choices then the restore, each its own window; Cancel → "Nothing was replaced."),
`testARestoreSwipedAwaySaysNothingWasReplaced` (iPhone: swiped down → "Nothing was replaced.", still 10 things),
`testEscapeClosesSettingsWindowsAndNeverReplaces` (Escape → closed, "Nothing was replaced.", 10 things). Model `RestoreTests`
(`testARestoreLeavesExactlyWhatTheFileHeldAndNothingOfWhatWasThere` — items, templates, no trips, no to-dos, no old
Settings-list entry, every table count equals the file's; `testTheFileHoldingLessThanTheDeviceIsVisibleInTheCounts`;
`testSomethingThatIsNotABackupIsNotReadAsOne`). **Not covered:** the error lines, the ", and more." wording, a
restore onto an empty device.

---

## 15. *Kept before a restore* — rescue copies (`Store/RescueCopies.swift`)

**Purpose.** "A way back that he cannot reach is no way back, so they are listed here." A copy of the library is
written to this device BEFORE a restore replaces it — "never after" — so going back does not depend on his having
saved a file first.

**Storage.** Folder `Application Support/AMS Packing/rescue/` on this device only (never synced). File name
(`RescueNames.fileName`) `before-restore-<ISO time, world time, with ":" replaced by "-">.json`, e.g.
`before-restore-2026-09-22T23-04-11.123Z.json`;
content = the ordinary backup JSON (either app can read it). An EMPTY library writes nothing (and deletes nothing).
After each write the folder is pruned to the newest **3** (newest = file name sorted descending). Under the UI tests
the folder is emptied at launch.

**On screen** (only when at least one copy exists): **"Kept before a restore"** (15 heavy muted, 10 pt above, id
`rescue-heading`), then a card list, one row per copy, newest first: the moment written as **"23 September, 01:04"**
(16 medium ink; `RescueNames.when` — the file name's world time said in this device's time zone (0.62; until then the
world time as it was, an hour or two off and near midnight the wrong day), day number, English month name,
hours:minutes; an unexpected name is shown as it is) and **"Look at it"** — since 0.63 a button of its own (outlined
`HeaderButtonStyle` in the Settings slate, id `rescue-row-<n>`); 5 pt above and below; hairline under each. Until 0.63 the
whole row was one plain button (min height 44, slimmed to `Metrics.tap` in 0.62), and on the Mac a click on the slim row
did nothing (GitHub's Mac run, 6 Oct 2026). Pressing it reads the file and goes through exactly the same `offer` → comparison sheet → confirm path as a chosen
file (an unreadable copy says "That is not an AMS Packing backup file.").

**Tests.** UI `testTheCopyKeptBeforeARestoreBringsEverythingBack` (no heading before any restore; after one: heading,
one row, no second; the copy holds 10 things; confirming brings 10 things and the 1 trip back); model
`RescueNamesTests` (0.62: the three-copy limit, the date text in a given time zone). **Not covered:** an empty
library writing no copy.

---

## 16. *This device holds* and the version footer

**Purpose.** "What this device holds, table by table, so two devices can be compared by eye."

**On screen.** **"This device holds"** (15 heavy muted, 14 pt above), then a card with one row per storage table, in
`Table.allCases` order, ALWAYS all eleven (zero included): label (16 medium ink) and count (16 bold monospaced muted,
id `device-count-<table raw value>`), min height 40, hairline. Labels (`SettingsScreen.label`): `items` "Things",
`memberships` "Places on templates", `templates` "Templates", `trips` "Trips", `entries` "Trip lines", `actions`
"To-dos", `kits` "Groups of things" (0.62; "Kits" until then — but in his words a kit is ALL his things, Words §10,
while this table holds the web app's named groups of things, such as a dive kit), `phases` "Own "When" steps", `shared` "Choices", `photos` "Photos", `meta` "Notes about the
library". Last row: **"Synced through iCloud"** or **"On this device only"** (`model.usesICloud`) and the version
`AppInfo.version` = "<CFBundleShortVersionString> (<CFBundleVersion>)", e.g. "0.60 (2)" (both 15 semibold muted).

Under the card, only for a library brought in from a file (0.62): **"Brought in from a backup <when> (the file was
saved <when>)."** (15 medium muted, id `device-import`; from the import's own marker, so both devices say it).

**Data.** `Library.counts` = for each `Table`, the number of records `library.records()` produces for it — counted
without building them since 0.62 (building decoded every photo on every redraw).

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
| `faint` | `#a9b5ba` | `#5a6a71` | a mark to be found, not read: a thing's grip ≡ while arranging (0.67) |

**The six sections** (`enum AppSection: String, CaseIterable` — `home, events, templates, care, actions, settings`;
the same six, order and colours as the web app's tab bar; ONE sRGB hex each, the same in light and dark — mid-tones
on purpose, each at least 3.2 : 1 on the light card and 3.5 : 1 on the dark one, the WCAG ratios in docs/colours.md,
enough for headings, bands, bold words and white words on a filled button; checked 5 Oct 2026, and Theme.swift's
opening comment now says the pairs are the page and text colours, not every colour):

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
unreadable on yellow"). He does not like teal: "Do not use teal for anything new." (docs/colours.md was brought up to date in 0.62: the
workout pills are marked built in 0.40, and the tabs are named Trips and To do, with their code names beside them.)
`Color(hexString:)` (in
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
cannot read colour; the `shot()` helper exists so screens are LOOKED at (day and night) before release — night by
putting the simulator in dark mode (`xcrun simctl ui <device> appearance dark`) and running the same tests again
(§32); no test switches it.

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

**`GridShape(d:)`** (SVGPath.swift, 0.67) — a 24-grid drawing as a Shape that scales to whatever square it is
framed in (factor min(width, height)/24) and is centred in it; the stroke width is not scaled. 🪤 A bare
`SVGPath.path` is drawn at its own coordinates: framed smaller than 24 it hangs off to the bottom right, framed
bigger it sits up and left. 0.63's Share mark, framed at 18 in a sheet's Share pill, hung 3 pt low with its box
through the pill's edge (his note "The share buttons is not aligned with the icon"); the grip ≡ (framed 20) sat
2 pt off; the map pin (26) 1 pt. `ShareMark`, `PenMark` and `GripMark` draw through `GridShape` now; a mark still
drawn with a bare `SVGPath.path` must be framed at exactly 24 × 24.

**Data emoji.** Emoji that are DATA (a phase's or template's emoji imported from the web app) are not drawn, with one
exception: a template's `Cover` shows `list.emoji` as text when the template has no icon (his covers "are his data").

## 20. Buttons (`Buttons.swift`, `SmallDelete.swift`) and the "main button never grey" rule

**The rule** (his standing rule, 2026-09-26): "the app's central button is ALWAYS full colour; pressed too early it
says what's missing under it. Never disable+grey a primary action." Until the field test of 3 Oct 2026 the Add / New
/ Make buttons sat grey and switched off until something was typed; 0.34 had already fixed *Make the template*. No
`.disabled(…)` is put on a main action; the press validates and answers in words.

**`HeaderButtonStyle(tint:, filled: true, stretch: false)`** — the buttons at the top of sheets (Done, Save: filled;
Cancel, Share, Edit, Close: outlined). His words (test H.10, 2026-09-28): "make the Done and Share buttons visually
pleasing all over the app". Label 17 bold (0.62; 16 until then, while the screens asked for 17 — see below); white
on a capsule filled with the tint, or tint-coloured on a 10 % tint capsule with a 1.4-pt tint outline; never cut
(`lineLimit(1)` + `fixedSize()` — the "D…" of 0.40's photos); padding 14 horizontal; min height 36; the whole capsule
is the hit area; 70 % opacity while pressed; `stretch` makes it share a card row's width. Most callers also attach
a `.font` and a foreground colour outside the button — nearly all 17 (bold or semibold), a few 16 bold and one 13
bold — which the style's own font and white-or-tint always override; the style now draws the 17 bold most of them
ask for, the same on every header. (The callers' own modifiers are left in place, harmless, so this change touches
no screen's file.)

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
`table-search`, `template-find`, `filter-narrow`, `onsite-leave-search` / `onsite-note-search` (via `LinePicker`),
and (0.62) `wayhome-search` — until then the way-home search drew its own plain cross in a 44×44 area.

**`SmallDeleteButton(title:, id:, action:)`** — his mark (2026-09-26): "Delete should be a small button at the side."
Right-aligned; 13 semibold red words in a capsule outlined in red at 60 %, padding 12, min height 30. It only ever
OPENS the question, never deletes by itself. Uses: Delete bag (`bag-delete`), Delete trip (`trip-delete`), Delete
template (`template-delete`), Delete thing (`thing-delete`).

**Every plain button** gets `.buttonStyle(.plain)` and `.focusEffectDisabled()` (no keyboard focus ring on the Mac)
and an explicit `.contentShape` so the whole drawn area takes the tap.

**Escape** (the trips' windows in 0.62, every other sheet in 0.62 — "Escape everywhere"). Every sheet's **Cancel** —
or, where it has no Cancel, its **Done** / **Close** — carries `.keyboardShortcut(.cancelAction)`: Escape on the Mac,
⌘. on an iPhone with a keyboard. Never a Save, a Replace or an Add: no key saves anything by accident, and Return
(`.defaultAction`) is given to no button, so it stays with the fields (`onSubmit`). Nested sheets: only the top one
closes (each sheet is its own window on the Mac; on the iPhone the top sheet's shortcut is met first). A grab list
being edited has no Cancel and no shortcut (its Done is hidden while editing). The Mac's own *All your things* window
(`ThingsTable(inWindow: true)`) has none either — a window closes with ⌘W, and Escape in its search field would close
the whole table; its sheets (Filter, Sort, Columns, Change, a thing) do have it. On the iPhone a sheet that may be
swiped away also closes on ⌘. by itself (the system's own, shortcut or not), so there the tests pin that the right
window closes and nothing is saved; on the Mac nothing closes without the shortcut. There is no `onExitCommand`.
A mode inside a sheet takes Escape first: on a template's page while **arranging** (0.63, spec 04 §6a), the Arrange
pill carries the shortcut and Done gives it up, so Escape ends Arrange (a heading's name typed and not saved is
dropped) and a second Escape closes the page; meanwhile the page cannot be swiped away (`interactiveDismissDisabled`),
so the iPhone's own ⌘. does not close it first.

**Escape tests on the iPhone** (0.63): the four window-by-window Escape tests (`testEscapeClosesTheTripsWindows`,
`testEscapeEndsArrangingWithoutSavingAHeading`, `testEscapeClosesSettingsWindowsAndNeverReplaces`,
`testEscapeLeavesHomeAndTemplatesWindowsWithoutSaving`) skip on the iPhone (`XCTSkip("Escape is checked on the Mac")`):
GitHub's iPhone (iOS 26, on-screen keyboard) did not deliver ⌘. there; the Mac run checks every one.
Since 0.65 the fifth, `testEscapeCancelsAThingAndClosesCaresWindows`, too: the local iPhone 17 passed it at 15:00 and
refused ⌘. at 18:10 on the same code (6 Oct 2026). On an iPhone, ⌘. needs a hardware keyboard; the screens answer it
as before, and nothing of it is checked on the iPhone any more.

**Tests.** `testEveryAddButtonIsReadyAndSaysWhatIsMissing` (Your things New + the line goes after typing, Your bags,
To buy, Grab Lists Make, a grab list's Add, Your choices' first Add, a template's Add, Rename to another template's
name, a row's new section, the trip Weather button; each must exist, be ENABLED, and answer on `<id>-needs`; all
failures are listed in one message). `testHomeBuildsATrip` (Create trip enabled, `trip-create-needs`). The ✕:
`testTheCrossEmptiesASearch` (Your things, the magnifier search, Choose from your things),
`testTheCrossKeepsTheKeyboard`, `testTheWayHomeIsSearched` (0.62: its ✕ is the shared 36-point one). Deletes: `testATripIsDeletedOnlyAfterAsking`, `testAThingIsDeletedOnlyAfterAsking`,
`testABagIsRenamedAndDeletedFromItsPage`. **Colour cannot be tested**: "A colour cannot be read by a test; being
pressable and answering can."

## 21. Type, headings, pills, drop-downs and sizes (`Headings.swift`, `Theme.swift` `Metrics`, `ScreenHeader.swift`, `Pills`/`FlowRow` in `HomeScreen.swift`, `DropDown` in `Screens/DropDown.swift`)

**Origin.** His word, 5 Oct 2026: "make things smaller so that the app is efficient, fluid, and Apple-standard",
and "make the buttons even slimmer, smaller when possible"; "less space between blocks on the forms and slimmer
rows in the trip, smaller tick circles and less space between lines". Until 0.62 the app set every size by hand
(641 places, nearly all 15–18 pt, mostly heavy or bold), drew a block's heading as a coloured band, wrote part
headings in capitals with letter-spacing, and made buttons 44–52 tall. There is **no minimum size of its own**:
the app follows Apple's.

**Type.** Every word is set in one of Apple's text styles — `Font.system(_ style:, design:, weight:)` — never a
point size. A text style follows the device: on the iPhone (at the default text size) Large Title 34, Title 28,
Title 2 22, Title 3 20, Headline 17 semibold, Body 17, Callout 16, Subheadline 15, Footnote 13, Caption 12, Caption 2
11; on the Mac the same styles are the Mac's own, smaller sizes (Body 13). The iPhone's text-size setting is
followed. The one exception is a letter drawn inside an icon tile (a grab list's or a cover's letter), which keeps its
size in proportion to the tile (`size × 0.5`, `size × 0.46`).

**The conversion of 0.62** (one rule for every screen; the chapters of this specification still give many sizes in
the old points — read them through this table):

| Old size (pt) | Text style |
|---|---|
| under 12 | Caption 2 |
| 12 | Caption |
| 13–14 | Footnote |
| 15 | Subheadline |
| 16 | Callout |
| 17–19 | Body |
| 20–25 | Title 3 |
| 26–29 | Title 2 |
| 30–36 | Title |
| 37 and up (the countdown's 44) | Large Title |

| Old weight | New weight |
|---|---|
| heavy, black | bold on Title 3 and larger; semibold below |
| bold | bold on Title 3 and larger; semibold below |
| semibold | semibold |
| medium, regular | regular (none written) |

A size or weight that depended on a state (`on ? 17 : 15`, `on ? .heavy : .medium`) is converted on both sides. The
loop strip's words: Footnote, or Caption where the narrowest fit needs it; the Delete buttons' words: Footnote
semibold (the `size` parameter of `SmallDeleteButton` is gone).

**Heights** (`enum Metrics`, Theme.swift) — every button, field, pill and door row takes its height from here:

| Name | iPhone | Mac | Used for (old height) |
|---|---|---|---|
| `row` | 40 | 30 | doors and cards' rows (52) |
| `tap` | 36 | 26 | buttons and fields (44, 46, 48); also the 44×44 arrow boxes (now `tap`×`tap`) |
| `compact` | 32 | 24 | smaller buttons (40) |
| `chip` | 28 | 22 | pills (36) |
| `header` | 30 | 24 | Done, Cancel, Share … at the top of a page (`HeaderButtonStyle`, 36) |
| `contextName` | 72 | 64 | a WIDTH, not a height: the workout's name before its own Context pills (`WorkoutContexts`, 0.67 — new) |
| `screenTop` | 4 | — | from the top of a tab (under the iPhone's status bar) to its first line (0.67; 14 on most tabs, 12 on To do before). On the Mac the first line sits in the title bar strip instead (below) |
| `windowButtons` | — | 80 | the Mac: where a tab's title may start, from the window's LEFT EDGE — after the three window buttons, whose green one ends at 68 on macOS 26 (measured on his 0.63 picture; its accessibility frame ends at 70; the system's own title started at 84) |

Buttons have 12 pt side padding (14–16 before); the field button (Add, New, Make) a corner radius of 8. One exception
keeps its size on both: `Metrics.fingertip` = 44, the touch area of the table's column arrows and Hide (his ask, 4 Oct
2026: "These arrows are rather difficult to hit") — the arrows are drawn 22 within it.

**A list's line** (0.67) — a trip's lines, a template's rows, To do and To buy, a grab list's lines: as tall as its
words and a hair, the feel of the table "without air" (spec 05). His words, 6 Oct 2026, testing 0.63: "Far too much
space between the lines … Change this dramatically, not only a bit."

| Name | iPhone | Mac | Used for (until 0.67) |
|---|---|---|---|
| `line` | 30 | 22 | the least height of a line, top to top — no spacing between lines; the words have 2 pt above and below, so a name on two lines grows the line (trip 44, template 42, To do 44, grab list 46) |
| `mark` | 18 | 14 | the tick circle of a line, `TickCircle` (trip 20; To do, To buy and grab list 26) |
| `glyph` | 20 | 16 | ✕, ⊘/↻, the fold arrow and the washtub on a line (22–24) |
| `lineButton` | 40 | 30 | the width that takes a press on ✕, ⊘ or a heading's tick-all; its height is the line's (40 × 40 or 40 × 36) |

`onGrid(size)` (a `View` extension in Theme.swift) shows a mark drawn on the 24-point grid at `size`: framed at 24 so it
stays in the middle, then scaled — framed smaller, a 24-grid drawing hangs off-centre. `TickCircle(on:, tint:, ring:)`
(TripScreen.swift) is the one round tick of every such line: a 1.6-pt ring in the tint (or `ring`, the hairline colour
for a line set aside or skipped), filled with a white tick (stroke a tenth of its width) when on.

**The tab header** — **`ScreenHeader(title:, tint:, id:, font = Title 2 bold, line:, lineId:, trailing:)`**
(ScreenHeader.swift, 0.67): the first line of Home, Trips, Templates and Care. `Metrics.screenTop` above it; one row,
at least `Metrics.tap` tall, `HStack(alignment: .center, spacing: 8)`: the title (one line, scales to 80 %, id `id`), a
spacer (≥ 8), then the tab's buttons (`trailing`) — all on ONE centre line. Under the row, when given, the `line`
(Subheadline, muted, id `lineId`). Used as: Home — "Grab and go", Title 3 bold, ink, with the magnifier and Grab
Lists; Trips — "Trips", green, map pin, magnifier, the to-do chip, line = the trips summary; Templates — "Your
templates", violet, magnifier, + New, line = the templates summary; Care — "Care", orange, magnifier, line = the kit
line. To do's first line (To do · To buy · magnifier) is its own `HStack` (centred, `Metrics.screenTop` above);
Settings has no header line. History: his note on 0.63 (6 Oct 2026), "Overall, icons are not aligned", with a
picture of Trips — every tab built this row itself, aligned on the title's first text baseline with 14 pt above it,
so a 36-pt icon button stood up from the baseline about 10 pt higher than the title, and left an empty band at the
top of every tab ("The area above Grab and go is underused"). UI `testEveryTabsHeaderIsOnOneCentreLine` checks on
Home, Trips, Templates, Care and To do that every button of the line sits within 1.5 pt of the title's centre line
and nothing reaches above the top of the screen (the iPhone's status bar, the Mac's title bar; 2 pt allowed), and
that Settings' first card (`settings-lists`) does not either; it keeps a picture of each tab ("header-<tab>"). The
top of the screen is the screen's own frame, but at least the foot of the iPhone's status bar (the scroll view
reaches up under it) — on the Mac, should the screen reach under the title bar, the bar's foot worked out from the
traffic lights. On
0.66 it was red on four tabs (the magnifier 10–11 pt off everywhere, Home's Grab Lists and Templates' + New 2.5 pt);
planted again by aligning `ScreenHeader`'s row on `.firstTextBaseline`, the same four.

**The Mac: the header in the title bar strip** (0.67; his boxes on the 0.63 picture covered the title bar too). The
main window (`WindowGroup`) has **no title bar**: `.windowStyle(.hiddenTitleBar)`. The window "All your things" keeps
its own. `RootView` measures the strip with a `GeometryReader` — its height is the window's top safe area (32 on
macOS 26) — and how far a header must step in so its title starts just after the three window buttons:
`lead = max(0, Metrics.windowButtons − (window width − column) / 2 − 16)`, where the column is `RootView.column` =
720, centred, and 16 the page's side padding (44 in a 760-wide window). Both travel down in the environment as
`TitleBarStrip(height:, lead:)` (ScreenHeader.swift).
- `headerOnTheMac { header }` (View extension): on the Mac the page becomes `VStack(spacing: 0) { header (16 side
  padding); page }` with the top safe area ignored, so the header is PINNED in the strip and the page scrolls under
  it — nothing ever slides beneath the window buttons. On the iPhone it does nothing: there the page puts the header
  in itself as its first line (`#if !os(macOS)`). Home, Trips, Templates and Care build their header once
  (`grabHeader`, `header(…)`) and use it both ways. On the Mac 6 pt follow the header (below).
- `headerLine()` (View extension, used by `ScreenHeader`'s row and To do's first line): on the Mac the line steps
  in by `lead` and is at least the strip's height tall, so it is centred on the traffic lights' line; on the
  iPhone it is `Metrics.tap` tall with `Metrics.screenTop` above. To do's whole screen ignores the top safe area on
  the Mac, so its To do · To buy · search line sits in the strip, after the buttons. Settings, the first-run doors,
  the placeholder and the library problem keep the safe area: they start under the strip.
- Moving the window: the empty parts of the strip (all of it on a tab with no header) move the window when
  dragged, as the title bar did — the Mac does that itself: nothing of the page claims those points.
  `.windowBackgroundDragBehavior(.disabled)`: a drag on a page's empty space does not carry the window. UI
  `testTheWindowMovesByItsEmptyStrip` (Mac only) drags Home's strip halfway across and sees the window move (and
  drags it back). A `WindowDragGesture` layer behind the strip was tried first and taken out: on GitHub's Mac run
  the window moved just the same without it — and still did with a tap or a drag gesture planted over the whole
  header row: the Mac moves a window by its title bar region whatever lies there. Seen red with the window made
  unmovable (`isMovable = false`): "the window did not move when its strip was dragged".
- 🪤 **The page under a pinned header must not touch the strip.** `headerOnTheMac` puts 6 pt under the header
  (To do's first line has the same), and the page's scroll views have no top edge effect on macOS 26
  (`titleBarSafeScroll()`: `.scrollEdgeEffectHidden(true, for: .top)`). On GitHub's Mac run (6 Oct 2026) a
  click on Grab Lists (Home) and on To buy (To do) — the two pages whose header is ONE line, so their scroll view
  began exactly at the strip's foot — never arrived, while the search and + New on Templates and the map on Trips
  (a summary line under the title) worked. Both changes went in together and all clicks arrived after; which of
  the two did it was not separated.
- Sheets are unchanged: they come down over the page as before.
- Tests (Mac branch of `testEveryTabsHeaderIsOnOneCentreLine` and `testHomeLeadsWithGrabAndGoAtTheTop`): each
  tab's title within 2 pt of the window buttons' line (`XCUIIdentifierCloseWindow`, `…MinimizeWindow`,
  `…ZoomWindow`, `…FullScreenWindow` — the green one is "full screen" on macOS 26 — as one box) and starting at
  least 6 pt after them (seen red on GitHub's Mac with the step-in planted at 0: "home: the title starts at 168.0,
  on or too near the window buttons", and the same on Trips, Templates, Care and To do); nothing above the window's
  top; Settings' first
  card under the strip (its foot worked out from the buttons, which sit in its middle); Home's first tile less than
  16 pt under Grab and go and less than 50 pt under the window's top. Mac pictures came from the probe workflow
  (`mac-probe.yml`, on a probe branch only).

**Headings.**
- **`HeadingBand(title:, tint = Care orange, id:)`** — a block's heading: Headline in the tint, full width, wraps,
  never cut. No strip, no mark (0.62; until then a 22-heavy title on a tinted strip with a capsule mark).
- **`HeadingTitle(title:, tint = ink, id:, question = false)`** — a heading inside a block: Subheadline semibold in
  the tint; as a `question` (Laundry nights, Context, the review) in ink.
- **`SectionTitle(title:, tint = ink, id:)`** — a heading that starts a part of a screen: Headline in the tint, 12 pt
  above. Not in capitals (0.62). The template's section headings, the Care parts, the picker's groups and Your
  things' list headings are Headlines the same way; the activity areas keep his code in capitals ("GA · GOAL
  ACTIVITY", `groupHeading`) at Headline.
- Small capitals stay where Apple uses them: column titles over a table or the bag numbers, the kind of a shared
  thing ("A TEMPLATE"), What's new's part names — Caption or Caption 2, semibold.

**`Pills(title:, options:, selected:, id:, tint = Home blue, startIndex = 0, heading = .title, tones:, choose:)`** —
a heading (band / title / question, id `<id>-title`) over pills in a `FlowRow(spacing: 6)`. Each pill: Subheadline,
semibold when picked, regular when not; padding 12 sideways, min height `Metrics.chip`; picked = filled with its tone
or the tint, white (or the tone's dark) words; not picked = `Theme.bg` fill, ink words, outlined in `line` (1 pt) or,
for a toned pill, in its tone (1.8 pt). Id `<id>-<startIndex + position>` — "its position — never its words";
picked pills carry the `.isSelected` trait (what tests read). `cursor: Int?` (0.68, nil everywhere but a thing's On
these templates on the Mac): the pill the keys' arrows are on, ringed 2 pt in the tint just outside it (`focusRing`).
`WorkoutContexts` (0.67; `ContextPills` until then)
puts Context under the workouts, indented 18 with a 3-pt grey line down its side: a `.question` heading "Context",
then one line per ticked workout — its name in its colour made readable (`WorkoutTone.words`, `readableHex`), in a
`Metrics.contextName` column (72 / Mac 64) — and its own Indoor, Outdoor, Race pills in the Settings slate
(padding 10). **`TripKindChoice`** (0.67): two answers in one capsule track — Full trip | Quick — the picked one
filled with the tint, `.isSelected`; a muted Footnote line under it.

**`DropDown` (0.64, `Screens/DropDown.swift`)** — ONE pick-one list: a heading band over a field-like button that
opens its choices as a list beside it. His word, 6 Oct 2026, after Kept at home became the first: "I like the
dropdown for 'kept in'. Well done. Can we please make these kinds of drop-downs everywhere? I think it would lend
itself perfectly for 'usually packed in', 'Kind of thing' etc." Used for every pick-one list on a thing's page (Kind
of thing, Whose it is, Kept at home, Usually packed in, When, Condition, Care, and — 0.64 — the Section on each
template it is on — spec 05), on a template's row (Bag, When, Section — spec 04 §7) and, since 0.64, a trip's
Sorting (spec 03: five pills no longer fit an iPhone's line). Lists where SEVERAL may be picked stay `Pills` (On
these templates; a row's Season, Context, Transport, Food), and so do the short toggles of Create new trip and Trip
settings (a few words each, seen at a glance, one tap).

`DropDown(title:, heading = .band, options:, selected:, id:, tint = Care orange, blank = nil, other = false,
same = exact, newEntry = nil, tools = nil, ring = nil, choose:)`:
- `title: String?` — the heading's words (no heading when nil).
- `heading: DropDownHeading` (0.64) — how the title reads: `.band` — a `HeadingBand` in the tint over the field (every
  drop-down until 0.64); `.title` — a `HeadingTitle` in the tint over the field (Subheadline semibold): a heading
  inside a block that already has one — a thing's "Section on <template>" under its On these templates band;
  `.beside` — the words to the LEFT of the field on the same line (Subheadline semibold, muted, one line, never
  squeezed: `fixedSize`; 10 apart; the field takes the rest of the line) — the trip's "Sorting", kept where his marks
  of 2026-09-25 put it when its pills became a drop-down. In all three the title's id is `ids.title`.
- `options: [(value: String, label: String)]` — the rows, in order; `value` is what is stored, `label` what is read.
- `selected: String` — the value that stands; `choose(value)` is called when a row is tapped (the caller keeps the
  value in its own draft — nothing is stored before the page's Save).
- `id: DropDownIds` — the names of its parts. A string literal is a prefix: the field `<prefix>`, the list
  `<prefix>-list`, the rows `<prefix>-<n>` (the position in `options`, from 0 — the SAME ids the pills had, so a
  test that named a pill names the same row), the heading `<prefix>-title`. Kept at home, which came first, passes
  its own: `DropDownIds(field: "thing-storage", list: "thing-places", row: "thing-place", title: "thing-heading-kept")`.
- `blank: String?` — words for a first row meaning "nothing said" (value ""), named `<row>-none`, before the
  options (Kept at home's "Not said", and since 0.64 a thing's Section's "No section" — new, so no pill ids to keep,
  and its sections count from 0; elsewhere such a row is simply option 0, as its pill was — a row's own Section
  has "No section" as `row-section-0`).
- `other: Bool` — when the value that stands is not blank and none of the rows, a row of its own at the END, its
  words = the value, ticked, named `<row>-other`; for lists whose values are words (Kind of thing, Whose it is, Kept
  at home, a row's Bag) — an id (a When step, a section, a condition) would read as nonsense.
- `same: (String, String) -> Bool` — when two values are one choice: exact; Kept at home compares by `normName`.
- `newEntry: DropDownNew?` — a foot under the rows: `DropDownNew(placeholder:, button = "Add", needs:, add:)` — a
  field (`<row>-new`) and the button (`<row>-add`, `FieldButtonLabel` in the tint, never grey); Add or Return with
  nothing typed (after `jsTrim`) shows `needs` under them (`<row>-add-needs`, `NeedsLine`, gone as he types) and
  the list stays open; otherwise `add(trimmed words)` is called, the field empties and the list closes. Kept at
  home: "A new place" / "Type the place first."; a row's Section and a thing's Section on a template (0.64): "A new
  section" / "Type the section's name first.".
- `tools: DropDownRowTools?` (0.68) — rows that are themselves changed: for each row `applies(value)` says yes to, the
  row's words (a button that chooses) then, at its right, a pen (`<row id>-rename`), ↑ (`-up`), ↓ (`-down`) and a quiet
  red "Remove" (`-remove`), each `Metrics.compact` wide and `Metrics.tap` tall, hand-drawn marks on the 24 grid at 16
  (pen muted; arrows in the tint, `Theme.faint` where `canMove` says no — and then they do nothing). The pen turns the
  row into a field (`-name`, tint 1.5 border; Return → `rename(value, words)`, which answers "" when taken or the words
  of what is wrong, shown under it as `-name-needs`; Esc on the Mac leaves it); the arrows call `move(value, ±1)`;
  Remove asks in place of the row — `question(value)` (`-ask`), "Remove" (`-remove-yes`, white on a red capsule) and
  "Keep" (`-remove-no`) — then `remove(value)`. A row `isRemoved` is struck out and muted, chooses nothing, and has
  "Put back" (`-putback` → `putBack(value)`) instead of its tools. The caller holds every change and hands the list its
  options as they stand. Since 0.69 also (defaults keep 0.68's Section lists as they were): `orders` (false = no ↑ ↓:
  Whose it is, A–Z); `refusal(value)` — what still uses the row, said in the question's card instead of the question
  (`-refused`), with "OK" (`-remove-no`) and no Remove; `open: DropDownOpen?` — a way on under a refusal ("Open the
  bag", `-open`: the list closes, then `open(value)`); `nameHint` — the name field's grey words ("Section name";
  "Name" for his lists). The tools of a row, in Tab's order, come from one place (`toolsOf`). Which lists have tools:
  a thing's and a template row's Section lists, and every pick-one list of his own on a thing's page and a template's
  row (spec 05 "His lists inside their drop-downs", spec 07 part 13) — built by `ChoiceDrop`
  (`Screens/ChoiceDropDown.swift`) and `DropDownRowTools.sections`.
- **Drag and drop (0.70, `Screens/Reorder.swift`)** — on a tool row whose list `orders` and that is not removed, a
  **grip ≡** at the row's LEFT (`<row id>-grip`; `ReorderGrip` drawing Arrange's `GripMark`, the thin grey one: 24-pt
  grid, 36 × `Metrics.compact`; read as "Move <name>", hint "Hold and drag to move it; the arrows move it one place").
  iPhone: hold 0.2 s, then drag (a swipe over it still scrolls); Mac: drag with the mouse. As the row is carried past
  one row-height (its own measured height, `reorderStep`) it takes ONE step with the list's own `move(value, ±1)` —
  the call ↑ / ↓ make, so a drag is a row of arrow presses (held until Save; Cancel undoes), one step per drag event
  (the list's `move` reads the list as last drawn). The carried row is drawn on the card colour with a 1-pt tint edge
  and a shadow, `zIndex` 1, offset to follow the finger (at most 0.6 row past the first or last place); let go — or
  the system cancels the gesture — it settles (0.15 s). The grip is not one of the tools Tab reaches: the keys keep
  ↑ ↓. Since 0.70 the options are `ForEach`-ed by VALUE (a repeated value gets "<value>#<n>") and a tool row's scroll
  name (`.id(<row id>)`) sits on a clear view BEHIND it — on the row itself it gave the row a new identity at each
  step, which dropped the drag (the row stayed lifted half a row low). Also 0.70: the list with tools is 370 wide
  (`idealWidth`; 320 without), each tool keeps its own width (`fixedSize`) and the name comes first (`layoutPriority`),
  so names break less ("Comfort & misc" was broken a word a line with the grip added). Why not a `List` with
  `.onMove` (Arrange's way): a popover is sized by its content, which a List does not give; its rows carry tools a
  List row's drag would grab; and the Mac's List drops at a row's middle BELOW it (spec 04 §6a).
- `ring: Color?` (0.68) — the field's border drawn 2 pt in this colour instead of the 1-pt line: the Mac's focus on a
  thing's page (spec 05, Keyboard (Mac)).
- **The Mac's keys (0.68)** — only where the page hands the drop-down a `DropDownKeys` in the environment
  (`dropDownKeys`; a thing's page): each drop-down hands in its answer to a key under its field's id
  (`DropDownKeyAnswer`, refreshed each time it is drawn, taken back when it goes) and reports its list opened or
  closed; the page asks the one in focus (`DropDownKey`: letters, open, up, down, choose, close, back, space, tab).
  Closed: letters pick at once (type-ahead, a second's pause starts afresh; the name's start first, then a word's start, then inside a word — a list with a `newEntry` by the name's start only), Space or ↓ open; with a `newEntry`, letters matching nothing open the list with the offer "<placeholder>:
  <typed>" (`<row>-offer`; before typing `<row>-offer-hint`) in place of the foot's field — Return makes it via
  `newEntry.add`. Open: the lit row (the list's tint at 18 % behind it, scrolled to), ↑ ↓ move it, letters jump,
  Return / Space choose, Esc closes; with `tools`, Tab steps through the lit row's tools (a 2-pt tint ring) and Space /
  Return press them. Every other screen's drop-downs have none of this, exactly as before. Spec 05 has every key.

What it draws:
- **The field**: the words of the choice that stands — the matching row's label; with a `blank` row and a blank
  value, its words; with nothing matching, the value itself, or "Not said" when it is blank — in Body, ink, or
  muted when the value is blank (value "", e.g. "Both have one", "No bag", "Same as the thing …"), one line,
  truncated at the end; then a drawn ▾ (`M6 9l6 6 6-6`, 1.8 stroke, 16 × 16, muted). Padding 12 sideways, min
  height `Metrics.tap` (36 iPhone / 26 Mac), `Theme.card` fill, radius 10, a 1-pt `line` border — like the text
  fields around it. Accessibility: label = the title (the words when there is none), VALUE = the words shown (what
  tests read), id = the field id. A tap opens the list — on the iPhone after first putting the keyboard away
  (`resignFirstResponder` sent to the app): with the weight still being typed, a list opened over the keys was
  squeezed into the space above them, and a test could not reach its last rows.
- **The list**: a popover (`presentationCompactAdaptation(.popover)`, so the iPhone shows a popover too, not a
  sheet) with NO arrow edge given, so the system puts it above or below its field, wherever it fits — a field near
  the top of the page opens downwards; a short list may open above a field in the middle (the first Kept at home fixed it above its field: on a row's Bag, near the top,
  it was squeezed to three rows). Inside: a `ScrollView` (padding 12; min width 280, ideal 320, max height 440;
  `Theme.bg` behind) holding, top to bottom, the `blank` row, the options, the `other` row and the foot; it opens
  scrolled to the ticked row (centred), so the tick is seen in a long list. Container: `.contain`, id = the list
  id.
- **A row**: its label in Body (muted for the value "", ink otherwise; wraps rather than cut), a spacer, and for
  the chosen one a drawn `Tick` in the tint (2-pt stroke, 18 × 18); 6 pt above and below, min height
  `Metrics.tap`, FILLED with `Theme.bg` and shaped as a whole rectangle — on the Mac a slim whole-row plain button
  with nothing behind its words once took no clicks; a 1-pt `line` under it. The chosen row carries the
  `.isSelected` trait. A tap calls `choose(value)` and closes the list.
- Closing the list any other way (a tap outside, Escape on the Mac) chooses nothing and drops what was typed in
  the foot.

**`FlowRow(spacing = 8)`** — a `Layout` that places children left to right at their natural size and wraps to a new
row when the next one would pass the right edge; row height = tallest child; reported width = the proposed width
(10 000 if none).

**Spacing.** The thing editor, the row editor and a bag's page: blocks 12 apart (22, 20 and 18 before). Create new
trip and Trip settings: 10 (14 before); Settings' cards: 8 (0.67; 10 before, 14 before 0.62). **A list's line since
0.67** — a trip's lines, a template's rows, to-dos and buy lines, a grab list's lines: no spacing between lines, each
at least `Metrics.line` (30 / 22) tall with 2 pt above and below its words, a `TickCircle` of `Metrics.mark` (18 / 14),
8 pt between circle and words, ✕ and ⊘ `Metrics.lineButton` × `Metrics.line` (the table above). Until 0.67: a trip's
line had a 20-pt tick circle (1.6-pt ring, 2-pt tick), 10 pt between circle and words, 5 pt above and below, a 40 × 40
⊘ and 4 pt between lines (44 top to top); a section's tick-all circle 20; to-dos, buy lines and grab lists a 26-pt
circle, 5 pt above and below and a 40 × 40 ✕ or ⊘; a template's rows 3 pt above and below, a 40 × 36 ✕ and 6 between.
The other lists — Care, Your choices, On site and the way home, the picker, Search, the table's filter and sort
lists, Your things, the weather lines — 5 pt above and below (10–12 before; 3 where it was 6, 4 where it was 8): "less
air between the lines". Your things and Search show a thing's name and its details on one line.

**Tests.** `testTheEditorsLeadWithTheirHeadings` (every heading id on the thing editor, the row editor, Create new
trip, Trip settings, the review and Your choices exists; When's drop-down field exists; photographs each),
`testWhoseItIsOffersEachOwnerOnce` (0.64: a heading line at least 15 tall over a drop-down field of `Metrics.tap` —
36 on the iPhone, 26 on the Mac — and less than 6 more; until 0.64 over pills of `Metrics.chip`),
`testContextSitsUnderTheWorkouts`; the drop-down itself: `testThePickOneListsAreDropDownsThatChooseAndKeep` (0.64:
every pick-one list of the thing's page and a row is a field whose rows are out only once opened; a tap on a row
closes the list and the field shows its words; Save keeps it; the kept row is the ticked one), with the UI helpers
`openDropDown`, `choose`, `chosen`, `isChosen`, `closeDropDown` (spec 05, A thing's page, Tests).

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
  `<thing>-done`, `-cancel`, `-save`, `-confirm` (the `-cancel`, or else the `-done`, is the one Escape presses, §20).
- Rows and pills by POSITION: `<prefix>-row-<n>`, `<pill id>-<n>`, a drop-down's rows `<prefix>-<n>` (0.64, the ids
  its pills had; with `<prefix>` its field, `<prefix>-list` its open list, `<prefix>-none` / `-other` / `-new` /
  `-add` / `-add-needs` its extra rows and foot, §21), `guide-release-<n>`, `guide-topic-<n>`,
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
   as its `accessibilityValue` (`tripset-dates-field`), or a non-control box puts it in its LABEL — the Mac drops the
   value of a box that is not a control (`loop-step-<n>`). Rows that are buttons are read through `app.buttons[id]`.
2. The Mac reports a text's words as its VALUE, the iPhone as its LABEL — the tests' `words()` reads both.
3. A Toggle is a switch on the iPhone and a check box on the Mac; a dropdown is a button on the iPhone and a pop-up
   button on the Mac (`switchNamed`, `cellSays`) — the table's menus; the app's own `DropDown` (§21) is a plain
   button on both, read through `app.buttons[id]` and its value.
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
Links (0.69, a place's label, spec 05): on the Mac the main window's content says `.handlesExternalEvents(preferring:
["*"], allowing: ["*"])` and its `WindowGroup` `.handlesExternalEvents(matching: ["*"])`, so a link goes to the open
window instead of opening a new one for every link; the "All your things" window `.handlesExternalEvents(matching:
[])` — never the one a link opens in. `RootView.onOpenURL` → `LibraryModel.open(_:)` (spec 02 §1).

**`useTheRunnersWindowSize()`** (Mac, only when testing): on the next main-queue turn, every visible titled window is
set to x = its own, top edge kept, 760 wide, 674 tall. "Set, not suggested: macOS restores a window's last size and
ignores size limits on the content."

**`RootView`.** `VStack(spacing: 0)`: the current section's screen, at most 720 wide ("the web app's column, on the
Mac"), centred; under it the tab bar; `Theme.bg` behind, ignoring safe areas. Starts on Home. On appear: the
reminders' tap handler (→ Home + `tripToOpen`) and `PackingReminders.start()`. The library publisher, debounced 2 s:
reschedule reminders and update the Shortcuts parameters. Scene becomes active: read back Reminders ticks and
(0.62) reschedule the packing reminders. A Shortcut asking for a grab list, the grab menu or a trip switches to
Home; `model.tabToOpen` (0.62; Search's to-do) switches to that tab. Under the UI tests only, a return from the
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
| `-uiTestingPlaces <when>` | memory, `SampleLibrary.places(when)` | 0.69; checked before `-uiTestingNotes`, `-uiTestingPockets` and `-uiTesting` |
| `-uiTestingNotes` | memory, `SampleLibrary.notes()` | 0.69 |
| `-uiTestingPockets` | memory, `SampleLibrary.pockets()` | 0.69 |
| `-uiTesting` | memory, `SampleLibrary.make()` | checked last |
| (none) | SwiftData; iCloud when the Info.plist key `PackingUsesICloud` is "YES" | a failure to open → `.failed("The library could not be opened: …")` |
| `-openGrab <label or title>`, `-openGrabMenu`, `-openNextTrip` | (testing only) play a Shortcut | |
| `-uiTestingOpen <link>` | (testing only) a link handed to the app at launch, as the Camera hands a place's label (`LibraryModel.open`) | 0.69 |
| `-pretendShopTicks` | (ShopReminders) pretend ticks in Reminders | |
| `-pretendRemindersBlocked` | (PackingReminders) switched on earlier, then blocked in the device's Settings — also "I leave at"'s red line (0.69) | 0.62 |
| `-showDoorChecks` | (DEBUG, testing only) the trip lists the door checks that would be scheduled (`door-check-out/home/none`) | 0.69 |
| `-tapDoorCheck out\|home` | (testing only) a door check tapped at launch, for the first trip with that time | 0.69 |
| `-openGrabOnReturn <label or title>`, `-openNextTripOnReturn`, `-dropOwnGrabListsOnReturn` | (testing only) played when the app returns from the background: a Shortcut, a tapped reminder, the other device's write that no longer holds his own grab lists | 0.62 |
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
   Headlamp is ONE thing on two templates. 7 things so far.
3. Care: Hiking boots — maintenance notes "Clean and wax", every 90 days, last done 2025-01-01 (always overdue); Rain
   jacket — notes "Wash with tech wash, no softener", no schedule.
4. Weights (g), places and owners are applied to the things that exist NOW (the 7):

   | Thing | Weight | Place | Owner |
   |---|---|---|---|
   | Hiking boots | 1250 | Hall closet | Kim |
   | Rain jacket | 420 | Hall closet | Kim |
   | Headlamp | 88 | Garage | Kim |
   | Map | 60 | Garage | Kim |
   | Passport | 35 | Chest of drawers | Kim |
   | Phone charger | 120 | Chest of drawers | Robin |
   | Toothbrush | 18 | Bathroom cabinet | Robin |

   Goggles, Swim cap and Towel are created only in step 7, so they have NO weight and NO place — on purpose: the UI
   tests rely on them being under "No place set". (Until 0.62 the dictionaries also named the three, with weights,
   though they were never applied; the dead entries are gone and the comment says why the three have none.)
   Neither owner is on the owners list (the "Whose it is" bug shape).
5. Review history: Map packed 3, used 0, unused 3; Headlamp packed 0, skipped 2; Hiking boots packed 1, used 0,
   unused 1 (one quiet trip — not evidence).
6. Map condition `retire` (Needs replacing); Toothbrush `consumable` — two different reasons for To buy.
7. Template **Swim** (group `WET`): Goggles, Swim cap, Towel → 10 things. Towel `perNight` = true (only Swim holds it,
   so the trip's counts do not change).
8. Hiking gets a section **Lights**; the Headlamp's place on Hiking moves into it.
9. One trip, **"Weekend in the hills"**, today + 30 → today + 32, activities = [Hiking], lines =
   `buildTotalEntries(trip, resolvedTemplates())` (Hiking plus the common base, as every non-Quick trip).

Result: 3 templates, 10 things, 1 trip, nothing in `shared`, `phases` or `meta`; every thing in the default bag
"Carry-on / hand luggage". No thing names a packer, so *Your choices* → Packers shows the two starters, Kim and
Robin (§2.6). The weights comment once said "514 of 431 things weigh something" — impossible; it now says almost
every one of his things does.

**Variants:**
- **`checks()`** (`-uiTestingChecks`): `make()` + a bag "Carry-on / hand luggage" (`addBag`: it makes the bag
  template "Containers" — shown as "Bags" — and, as no thing has that name, a NEW thing of that name on it); two new
  things (`addThing`) put on Common base: Pocket knife (`restricted`), Sun cream (`liquid`, expiry today + 25 — runs
  out during the trip); Passport becomes category Documents & money with expiry today + 180 (about five months after
  the trip); the trips are replaced by **"Sunny weeks"**, today + 20 → today + 34, transport Plane, activities
  [Hiking], made with `createTrip`. Result: 4 templates and 13 things (10 + the bag + 2) — no test reads that count.
- **`underWay()`** (`-uiTestingOnSite`): `make()` with the trip moved to yesterday → today + 2 (it stands at On site);
  the Passport has the note "Keep it dry".
- **`pockets()`** (`-uiTestingPockets`, 0.69): `underWay()` + a bag **Backpack** (`addBag`) with pockets Main, Front
  pocket, Lid; the Phone charger and the Headlamp usually in the Backpack, the charger's usual pocket Front pocket;
  the trip's lines rebuilt (7: Passport 0, Phone charger 1, Toothbrush 2, Headlamp 3, Hiking boots 4, Rain jacket 5,
  Map 6), the Passport ticked; "I leave at" 07:30 on the first day (yesterday — no check left) and 10:00 on the last.
- **`oldPhoto()`** (`-uiTestingOldPhoto`): `make()` + a photo record id `left-behind`, data
  `data:image/jpeg;base64,AQID`, created 2026-01-01T09:00:00.000Z, used by nothing.
- **`doubled()`** (`-uiTestingTwoLibraries`): `make()` + every template again under new ids, same name, group and
  role, its things re-added by name (so the same 10 things sit on 6 templates).
- **`places(when)`** (`-uiTestingPlaces <when>`, 0.69): `make()` + the Garage's code **G4R** (meta
  `placeCode:G4R`, as if its label were printed); "soon" → the trip moved to today + 2 → today + 4 (being packed);
  "home" → today − 3 → today, every line ticked (back from it: the way home); anything else → the trip as in
  `make()`, a month ahead. The Garage holds the Headlamp and the Map.
- **`notes()`** (`-uiTestingNotes`, 0.69): `make()` + the Passport's note "Renew before May" / "Keep it in the blue
  pouch with the tickets" (two lines) and the Hiking template's own note for the Map, "The waterproof one, folded in
  the lid" — neither name says the words the test searches for.
- **`fileToRestore()`**: a DIFFERENT library as backup bytes (exportedAt 2026-09-22T09:00:00.000Z): one template "Day
  out" (`role: "base"`) with Water bottle and Sun hat — 2 things where the device holds 10, "so a restore that only
  ADDS would be caught". Read by *Restore from a file…* under the tests.

---

# How the app is built, tested and shipped

## 26. The project (`project.yml`, `App/Config/*`, `Core/Package.swift`)

**Generated from `project.yml`.** `project.yml` is an XcodeGen spec; `xcodegen generate` writes `AMSPacking.xcodeproj`
(every script and workflow runs it first). The generated project and its shared scheme are ALSO in the repository,
so a change to `project.yml` is committed together with the regenerated files. "One target for the iPhone and the Mac, like AMS Coffee."

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
  user-selected files read/write (Save and Open windows), app-scoped bookmarks (`files.bookmarks.app-scope`, 0.70:
  the Obsidian folder he picks once is remembered — spec 07 part 8), personal-information.calendars (Reminders on the Mac). No
  iCloud: an ad-hoc-signed Mac app carrying iCloud entitlements is refused at launch, and that is how CI builds.
  Since 0.70 this is the MAC's file: an iPhone build (device or simulator) signs with the hand-written
  `AMSPacking-iOS.entitlements` (`CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]` / `[sdk=iphonesimulator*]`) — the same
  three keys (no file bookmarks: the vault page is the Mac's) + `com.apple.developer.healthkit` and `com.apple.developer.healthkit.access` [] (Apple Health in the
  review, read only; chapter 07 part 7). The TestFlight workflow adds those two keys to the shipped iPhone file and
  fails the run if the archived iPhone app lacks HealthKit.
- **Entitlements, syncing build** (`AMSPacking-iCloud.entitlements`, hand-written): the four above + network client
  (a sandboxed Mac app may not reach iCloud without it), the iCloud container `iCloud.<bundle id>`, CloudKit, the
  container environment `Development`, the sandbox exception `mach-lookup` for `com.apple.cloudd` ("Without this the
  sandbox denies the app the CloudKit daemon and nothing syncs", found 2026-09-22; with it 1,438 records went up and
  came back to a wiped device in 10 s), `com.apple.developer.aps-environment` `development` (silent pushes).
- **Info.plist keys:** CFBundleDisplayName "Packing", CFBundleName "AMS Packing", versions from the build settings,
  CFBundleIconName AppIcon, LSApplicationCategoryType `public.app-category.travel`, ITSAppUsesNonExemptEncryption NO,
  NSRemindersFullAccessUsageDescription and NSRemindersUsageDescription "Your To buy list goes into Reminders, to
  take to the shop; what you tick there is ticked here.", NSCameraUsageDescription "A photo of a packed bag, kept with
  the trip, to repack from on the way home.", NSHealthShareUsageDescription "AMS Packing reads your workouts during a
  trip to suggest what you used. It never writes to Apple Health." and NSHealthUpdateUsageDescription "AMS Packing
  never writes to Apple Health. Apple requires this text all the same." (0.70), `PackingUsesICloud` = `$(PACKING_USES_ICLOUD)` (read at launch),
  UIBackgroundModes [remote-notification], UILaunchScreen (empty colour name), UISupportedInterfaceOrientations
  [Portrait] — "portrait by design, like the web app on the phone"; (0.69) CFBundleURLTypes: one type, name
  `com.schabbauer.AMSPacking.place`, role Viewer, scheme `amspacking` — a place's printed label
  (`AMSPACKING://P/<code>`, spec 05) opens the app, on the iPhone and the Mac. No new entitlement: a link
  scheme needs none (the NFC stickers first planned for this would have; he dropped them on 7 Oct 2026).
- **Target `AMSPackingUITests`** (UI-testing bundle, iOS and macOS), `TEST_TARGET_NAME` AMSPacking, generated
  Info.plist. **Scheme `AMSPacking`**: builds the app; tests `AMSPackingUITests` and the package's
  `PackingCoreTests` AND (0.62) `PackingLibraryTests`. So the two UI jobs of CI and `tools/build.sh test` run both
  model bundles as well (on the simulator / the Mac) — until 0.62 the library's ran only in the `core` job and
  `tools/test-core.sh`. One library test reads its workbook back with the Mac's `/usr/bin/unzip`; on the iPhone
  (no `Process`) that read-back is skipped with `XCTSkip` (`WorkbookTests.run`), the Mac and the `core` job still do it.

## 27. CI on every push (`.github/workflows/tests.yml`)

"Every push runs the suite — the model's own tests, then the UI tests on the iPhone AND on the Mac … A red run means
the build is not fit to install." Triggers: push, pull_request, manual, and `workflow_call` (the TestFlight workflow
runs it first). Since 0.67 FIVE machines in parallel — `iphone` (3 groups) and `mac` (2 groups); the model's
tests ride in Mac group 1 and the parity check in Mac group 2 (`if: matrix.group == …` steps before the UI tests).
Until 0.67 `core` and `parity` were jobs of their own (seven machines with the groups of 0.65–0.66), and on 0.66's
release one Mac group waited 40 minutes for a free machine. The rows `core` and `parity` below describe those steps:

| Job | Runner | Timeout | What it does |
|---|---|---|---|
| `core` — The model (Core package); since 0.67 steps in Mac group 1 | macos-15 (macos-26 since 0.67) | 15 min (the group's 120 since 0.67) | `cd Core && swift test` (both model test targets); then (0.62) `python3 tools/release-to-testers.py --self-check` — the "What to Test" requests checked without the network (§28); (0.65) `python3 tools/ui-shard.py --check` — every UI test in exactly one group, with each group's minutes |
| `parity` — Parity with the web app's model; since 0.67 steps in Mac group 2 | macos-15 (macos-26 since 0.67) | 20 min (the group's 120 since 0.67) | checks out the web app's repository into `web-app/`, Node 22, `PARITY_MODEL=$PWD/web-app/js/model.js tools/parity/run.sh --invented` (§31) |
| `iphone` — UI tests — iPhone (N of 3) | matrix `group: [1, 2, 3]`, `fail-fast: false`; macos-26, newest Xcode on the runner (since 5 Oct 2026: on macos-15 the tests ran under Xcode 16.4 on an iOS 18 simulator, a pairing no shipped build has, and the template search's ✕ failed there) | 120 min per group (0.65; 180 for the single job in 0.63–0.64, 120 before — 0.63's run on GitHub stopped at 158 of 167 tests) | xcodegen; picks the highest-numbered iPhone simulator that `xcodebuild -showdestinations` offers for the scheme (0.68 — on 0.67's run `simctl` listed an iPhone 17 that xcodebuild then could not find, and group 3 stopped before its first test; the newest iOS on a tie), falls back to `simctl`'s highest-numbered iPhone (`sort -V`), fails if none; boots it and waits (`bootstatus -b`) — a cold simulator once cost the first test 95 s; `xcodebuild test $(python3 tools/ui-shard.py iphone N 3)` — that group's `-only-testing:` lines — with `-collect-test-diagnostics never -test-timeouts-enabled YES -maximum-test-execution-time-allowance 480`, unsigned (`CODE_SIGNING_ALLOWED=NO`); on failure uploads `TestResults-iPhone-N.xcresult` (artifact `TestResults-iPhone-N`) |
| `mac` — UI tests — Mac (N of 2) | matrix `group: [1, 2]`, `fail-fast: false`; macos-26 | 120 min per group (0.65; 180 in 0.63–0.64, 120 before; its own comment since 0.62) | xcodegen; `xcodebuild test $(python3 tools/ui-shard.py mac N 2) -destination platform=macOS`, allowance 300 s per test, signed ad hoc (`CODE_SIGN_IDENTITY="-"`, manual style, no team, no profile — "a Mac app cannot be driven unsigned"); on failure uploads `TestResults-Mac-N.xcresult` (artifact `TestResults-Mac-N`) |

Timeout history (comments): 30 min outgrown at 48 tests (0.25), 55 nearly outgrown at 67 tests (0.46), 120 since 108
UI tests (0.58) when the iPhone job passed every test and was cancelled at 80 minutes. Both UI jobs also run both
model bundles since 0.62 (§26) — since 0.65 in group 1 only (`-only-testing:PackingCoreTests`, `-only-testing:PackingLibraryTests`).

**The groups (0.65, `tools/ui-shard.py`)** — his ask, 6 Oct 2026, after 0.63's release run took 164 minutes (iPhone job
148, Mac 101, upload 15). The tests are read from `UITests/AMSPackingUITests.swift` itself (`func test…()`), so a new
test is never left out. Each costs its seconds on GitHub from `tools/ui-test-times.json` (0.63's release run, per
platform); a test not yet measured costs the median; a test measured on one platform only (an `#if os(...)` test)
costs 1 s on the other. Longest first, each into the group with the least so far (ties: the lower group). Three
iPhone and two Mac groups because a free account gets five macOS machines at once; the model and parity steps take a
minute or two each inside Mac groups 1 and 2. At 0.63's times: iPhone 3 × ~47 min, Mac 2 × ~51 min of tests, plus each group's own build. The
TestFlight job still `needs: tests` — every group must pass.

## 28. Shipping to TestFlight (`.github/workflows/testflight.yml`, `tools/release-to-testers.py`, `TESTFLIGHT.md`)

Started by hand (Actions → TestFlight → Run workflow) with an optional `notes` input ("What is new in this build —
testers see it as "What to Test""). "A red suite must never reach a
device": since 0.68 a first job `tested` (ubuntu) looks whether the commit BEFORE this one passed the whole "Tests" workflow and this one changes only `project.yml` / `AMSPacking.xcodeproj/project.pbxproj` (the version bump) — then the suite is skipped (it ran on the release branch already; about an hour saved per release); otherwise job `tests` calls `tests.yml`; job `upload` (`needs: tests`, macos-26, 120 min since 0.67 — 60 before) then:
0. Checks out with `fetch-depth: 30` and runs `tools/check-spec.sh` ("The specification moved with What's new",
   since 0.61): the last commit that changed `App/Sources/Guide/Releases.swift` must also change `docs/spec/`, or the
   job stops with "What's new changed in <commit> without docs/spec — update the specification in the same commit".
   With no such commit within reach it passes. His rule, 4 Oct 2026: every nit documented.
1. Selects the newest Xcode on the runner (Apple refuses uploads built with an older SDK).
2. Checks the four secrets exist — `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID` — and names the
   missing ones; and (0.62) that the tester group's name is set — the repository variable `TESTER_GROUP`, or a
   secret of that name (`secrets.TESTER_GROUP || vars.TESTER_GROUP`; a secret is also hidden in the run's log, which
   is public like the repository) — else it stops with "The repository variable TESTER_GROUP is not set — add it
   under Settings > Secrets and variables > Actions > Variables…" before anything is built. 🚨 The key must have the **Admin** role: an App Manager key uploads but fails cloud signing ("Cloud
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
   `TESTER_GROUP` from the repository as in step 2 — the step stops with the same message when it is empty; until
   0.62 the group's name was written into the workflow, a public file — and `WHAT_TO_TEST` = the `notes`, through
   the environment):
   "A successful upload does NOT put a build in TestFlight … an internal group does not pick new builds up by itself."
   It signs its own ES256 JWT with openssl (10-minute tokens), finds the app by bundle id, polls `/v1/builds` for this
   build number every 30 s up to 180 times (90 minutes since 0.67; 60 times / 30 minutes before — 0.65's iPhone build
   appeared after 31 minutes and was added to the group by hand) until BOTH the iPhone and the Mac build are VALID or
   PROCESSING (with only one after 90 minutes it warns that one device will not get it), finds the beta group by
   name (missing → error; the name itself is never printed), then (0.62) — when notes were given — gives each build
   its TestFlight **What to Test**: the notes trimmed and cut to 4000 characters, as the `en-US`
   `betaBuildLocalizations` record of the build (`GET /v1/betaBuildLocalizations?filter[build]=…&filter[locale]=en-US`;
   none → `POST /v1/betaBuildLocalizations` with `locale`, `whatsNew` and the build relationship; one → `PATCH
   /v1/betaBuildLocalizations/<id>` with `whatsNew`; a 409 on the POST → look again and PATCH). A failure there
   only WARNS ("the build is released all the same") — it never fails a release. Then it POSTs each build to the
   group, lists the group's builds and warns when this number is there fewer than 2 times.
   `release-to-testers.py --self-check` (run by the `core` job on every push, §27) checks the request bodies and the
   GET → POST / PATCH / 409 conversation against a pretend App Store Connect, without the network. 🪤 0.27 (build 33): the old loop gave up after 5 minutes with one build and the Mac
   never got it.
10. Only when every step before it succeeded (`if: success()`): writes the run's step summary — "### Sent to
    TestFlight — iPhone and Mac", "AMS Packing <version>, build <n>.", "Apple processes it for a few minutes, then it
    appears in TestFlight on both devices." and, when notes were given, a blank line and "What is new: <notes>"
    (written with `printf '%s'`). The `notes` input reaches this step through an environment variable (`NOTES`),
    never pasted into the script: 0.59's notes held quotes ("Both have one") and the pasted text broke the shell —
    after the build had gone out, so a good release showed as failed. Since 0.62 the same notes are also the builds'
    What to Test (step 9); until then they went only into this summary, which no tester sees.
11. Always (`if: always()`) uploads `build/*.log` as `testflight-logs` (nothing to upload is not an error); since 0.65 with `continue-on-error: true` — in 0.64's run both builds were sent and released and this step alone timed out talking to GitHub, which marked the whole run failed.

One-time owner steps (TESTFLIGHT.md): create the app record with BOTH platforms in App Store Connect; create the
internal tester group and put its name in the repository variable `TESTER_GROUP` (0.62); set the secrets; deploy the CloudKit schema to Production before the first shipped build can
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

**The contract** is `tools/parity/QUESTIONS.md` (contract version 4 since 0.62; needs web model v186+): determinism rules — today
is a parameter (default 2026-09-21), the clock frozen at noon UTC of that day, minted ids and timestamps never
compared (markers instead), each question gets its own deep copy, collation pinned to en-US, a throw is answered
`{"$error": message}`, absent entities absent on both sides; a canonical JSON form (sorted keys by UTF-16 order, NaN
→ null, −0 → 0, lone surrogates dropped, whole numbers exactly equal, others within 1e-9, a byte-exact `CJ` form for
the two hashed questions); fixed key sets per shape; question groups §6–§15 (setup state, coercion, per list, per trip,
probe trips, the whole library, the Settings lists and their shared rows — `settings.rows`, `rowsOfKind`,
`isFactoryList`, `back`, `ownersByUsage`, `grabShare` — every real string and id, fixed calculations, installing a
list last); §16 what is deliberately not compared (raw trip-link text, random ids, minted times, the `…ToRows`
functions reached through `sharedRowsFrom`, impossible dates, keys outside the shapes, photos and db/app code, and —
N8, 0.62 — the NAMES of the two starter packers: the web app's are the owner's household, the native ones invented;
the JS half puts the native names in by position wherever the roster itself is an answer or an input, so their
count, colours and factory-ness are still compared and a wrong name turns it red; on a real backup whose own packers
are exactly the web app's starters, `settings.isFactoryList` people `inForce` is the one expected difference); §17 what the contract requires for `sub`, `ownedBy`, `u` and the reserved keys.

**Runs.** `tools/parity/run.sh [backup] [--today] [diff options]` builds the Swift half in release (same scratch path
as test-core), runs both halves over `private/migration-2026-09-21.json` by default and writes the answers into
`private/` (they contain real names — never public). `run.sh --invented` uses the INVENTED backup written afresh by
`fixtures/make-invented-backup.mjs` (deterministic; awkward on purpose: kits, things, presets, a customised phase list
with ties, an item on three lists, legacy `owner` fields, names cut inside an emoji, 405 items in one list, dates that
are not dates, the sync add-on's reserved keys on every row; its header lists the shapes deliberately left out) into
the build folder — this is the CI run. Since 0.62 (contract 4) the example people in the questions' own inputs are
invented too (an address and a pair of initials once held a real name). `fixtures/check-invented.mjs [real backup] [--show]` proves the invented file
shares no value and no word of five letters or more with the real one (exit 1 if it does).

## 32. The UI-test harness (`UITests/AMSPackingUITests.swift`, top of the file)

One class, `AMSPackingUITests`, 132 tests (counted on this chapter's branch, 5 Oct 2026), run on the iPhone simulator and on the Mac. "Two tests to begin with, and
one more added at a time"; every test is seen to fail before it is committed (README). `continueAfterFailure = false`.

| Helper | What it does exactly |
|---|---|
| `launch(mode = "-uiTesting")` | adds the mode, launches; if not running in front within 30 s, launches again and waits 60 s (GitHub's slow runners). Mac: if no window within 5 s, Cmd-N and wait 5 s (the app once came up with no window). |
| `testAAAWarmsUpTheSimulator` | runs FIRST (name order): launch, wait up to 60 s for `screen-home`, terminate — inside `XCTExpectFailure(…, .nonStrict())`, so a fumbled cold launch is allowed and proves nothing. |
| `find(app, id)` | a named container: tries `otherElements`, `groups`, `scrollViews` (the same container is a Group on the Mac, an Other on the iPhone, or its ScrollView). Typed queries only — `descendants(matching: .any)` hangs the suite. |
| `appears` / `disappears` | poll `find` every 0.2 s until the timeout (default 10 s). |
| `words(e)` | "" if the element does not exist (reading a missing one is a HARD failure); else its label, or its value when the label is empty (Mac = value, iPhone = label). |
| `isOn(e)` | exists and is selected. |
| `shot(app, name)` | only when the env `SHOTS_DIR` is set (an xcodebuild line starting `TEST_RUNNER_SHOTS_DIR=<folder>` hands it to the runner): a PNG of the window (Mac) or screen (iPhone) into that folder, falling back to the runner's temporary folder (the Mac runner is sandboxed); prints "SHOT <path>". 110 calls. Night mode is not switched by any test: the simulator is put in dark mode first (`xcrun simctl ui <device> appearance dark`) and the same tests run again. (Until 0.62 its comment named a `tools/shots.sh` that does not exist.) |
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
| `dayFromToday`, `pickDay(…, grid:)`, `pickDates`, `openTripSettingsDates` | the month grids: `pickDay` pages with `<grid>-next`/`<grid>-prev` towards the month and taps `<grid>-day-YYYY-MM-DD` — `grid` "range" (Trip settings', default) or "trip-range" (Create new trip's, always open since 0.67); `pickDates` taps two days in Create new trip's grid and waits for "… night(s)" under it (no OK there); `openTripSettingsDates` opens the sample trip's Trip settings and its grid (the field, OK `range-ok` and Cancel live there). |

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
`testATripIsSharedAndOpenedAgain` and `testATemplateAndAGrabListAreSharedAndOpenedAgain` (the door);
`testThePickOneListsAreDropDownsThatChooseAndKeep` (0.64, `DropDown`, §21); 0.62:
`testYourChoicesSaysWhyRightWhereItWasPressed`, `testAChoiceIsRenamedAndMovedAndItsThingsFollow`,
`testTheWayHomeIsSearched` (its ✕ is the shared one); 0.62: `testRemindersSayWhenTheDeviceBlocksThem` (switched off
too), `testOwnersAreTheNamesHisThingsCarry`, `testSettingsOpensYourChoicesAndTheRestoreOneAfterTheOther`,
`testARestoreSwipedAwaySaysNothingWasReplaced` (iPhone), and Escape everywhere:
`testEscapeClosesSettingsWindowsAndNeverReplaces`, `testEscapeCancelsAThingAndClosesCaresWindows`,
`testEscapeLeavesHomeAndTemplatesWindowsWithoutSaving` (with the trips' `testEscapeClosesTheTripsWindows`, spec 03);
0.67: `testSettingsDoorsAreRowsOfOneCard` (§1), and the lines without air of §21 — `testATripsLinesSitTightUnderTheirHeadings`
(spec 03), `testATemplatesRowsSitTight` (spec 04), `testToDoAndToBuyLinesSitTight` (spec 05),
`testAGrabListAndItsTilesAreSmall` (spec 02) — whose limits are the test file's `tightLine` (30 / 22), `tightTile`
(36 / 26) and `doorPitch` (52 / 46), measured top to top by the helpers `rowFrames` and `pitch` (the rows on screen,
by `shownRow`) and `airAbove` (a heading to the bottom of the row above it).

Model: `SettingsListsTests` (14 since 0.62), `SharedRowsTests` (26), `PresetsTests` (5), `PhasesTests` (12),
`ItemConditionsTests` (6), `PeopleTests` (8), `HealthTests` (5), `PhotoTidyTests` (4 since 0.62), `BackupTests` (library, 5),
`RestoreTests` (3), `SyncCheckInTests` (1), `CountdownTests` (4), `ContrastTests` (3); and (0.62)
`tools/release-to-testers.py --self-check`. Not unit-tested at all (the app
target has no unit-test target): `SVGPath`, `RescueCopies` (its naming, time and pruning are, since 0.62: `RescueNamesTests`; also `StoreTests`, `SyncCheckTests`, `UndatedPhotoTests`), `AppInfo`, `Releases`/`Words`/`HowItWorksScreen`
content, the button and heading components.

---

## Open questions / discrepancies

Tags: **[bug]** the code does something wrong or surprising; **[rule-break]** it breaks one of his standing rules (or
the code's own stated rule); **[doc]** a comment or document disagrees with the code; **[untested]** behaviour that
matters and no test pins; **[idea]** worth deciding before a rewrite. (The 0.59 item "a photo whose `createdAt`
cannot be read is offered for removal at once" is gone: 0.60 keeps such a photo and never offers it — §12.)

1. **Resolved in 0.62** — ~~Sync now on an empty device blocks the import.~~ A device's check-in no longer counts as holding anything (`Library.isDeviceNote`); the doors stay and the import is taken. See the storage chapter (01), item 3.
2. **Resolved in 0.62** — ~~Rescue-copy times are UTC.~~ They are said in the device's time zone (`RescueNames.when`, §15).
3. **Resolved in 0.62** — ~~RestoreSheet's minimum size applies on the iPhone too.~~ It is the Mac's only; the restore UI test checks the sheet lies inside the window.
4. **Resolved in 0.62** — ~~The backup JSON is rebuilt on every redraw of Settings.~~ It is built when Save is pressed (§1, §13).
5. Withdrawn (his word, 5 Oct 2026): there is no 15-pt floor in this app — it uses Apple's standard text styles (spec 06, "Type"). Was: [rule-break] The font floor of 15 is not universal (finding F073).
6. **Resolved in 0.62** — ~~`HeaderButtonStyle` callers' fonts are dead.~~ The style draws the 17 bold the screens ask
   for (it drew 16); a caller's own font is still overridden, by design, so every header is alike (§20).
7. **Resolved in 0.62** — ~~The way-home search does not use `.clearButton`.~~ It does: the shared round ✕, 36 points
   (§20; `testTheWayHomeIsSearched` measures it).
8. **Resolved in 0.62** — ~~The use count's wording.~~ The number is things only; a refused remove names what holds
   the entry — "by 3 things, on 2 trips and on 1 template" (`ChoiceUse`, §2.5).
9. **Resolved in 0.62** — ~~`usesOf`'s doc comment.~~ It says what is counted: things for every kind, trips and
   templates apart for a step, and why to-dos are not.
10. **Resolved in 0.62 (rename and reorder)** — ~~Your choices cannot edit.~~ The pen renames an entry (every thing
    and trip line follows) and moves it up or down (owners stay A–Z) — §2.5. Still not here, on purpose: colours,
    lead days, the to-do flag, a condition's tone and "needs replacing" — each changes what To buy suggests or when
    reminders come, so they wait for his decision (a condition added here still never feeds To buy; a step added
    here is still due on departure day).
11. **Resolved in 0.62** (the templates pass, spec 04 §3) — ~~A new 8th "When" step gets teal.~~ `newStep(named:)` takes
    its colour from the app's cover colours, so the eighth is indigo `#4f46e5` (§2.5); changing a step's colour here is
    still not possible (item 10).
12. **Resolved in 0.62** — ~~Silent duplicates in Your choices.~~ Add says "You already have <name>." for every part,
    and adds nothing (§2.5).
13. **Resolved in 0.62** — ~~The problem line appears at the TOP.~~ It appears right under the entry whose ✕ was
    pressed (§2.4; `testYourChoicesSaysWhyRightWhereItWasPressed`).
14. **Resolved in 0.62** — ~~Owners are listed A–Z with no factory list, so the Owners part is empty on an account
    that never added one while *Whose it is* offers names.~~ With no Owners of his own, `owners()` is the owners his
    things name — A–Z, each once, things only, as `people()` does for Packers; each is in use, so none can be
    removed; a rename or an Add stores them as his own list, still A–Z (§2.5, §2.6). Pinned by
    `SettingsListsTests.testOwnersWithNoListOfHisOwnAreTheOwnersHisThingsName` and UI
    `testOwnersAreTheNamesHisThingsCarry`. `ownersByUsage` (the web app's most-owned-first order) stays ported and
    unused: owners stay A–Z.
15. **Resolved in 0.62** — ~~docs/colours.md is stale.~~ The workout pills are marked built (0.40), the tabs are
    Trips and To do with their code names beside them.
16. **Resolved in 0.62** — ~~Section colours are single hexes.~~ On purpose, and now said so: Theme.swift's comment
    speaks of the page and text colours; docs/colours.md gives each section colour's contrast on the light card
    (3.2–4.8 : 1) and the dark one (3.5–5.2 : 1) — enough for headings, bands, bold words and white words on a fill.
17. **Resolved in 0.62** — ~~Sheet dismissal without an answer; no Escape.~~ A restore swiped away (iPhone) says
    "Nothing was replaced.", as Cancel does (§14; `testARestoreSwipedAwaySaysNothingWasReplaced`). Every sheet's
    Cancel — or Done where it has none — is pressed by Escape (⌘. on an iPhone keyboard), never a Save (§20).
    Pinned by `testEscapeClosesSettingsWindowsAndNeverReplaces`, `testEscapeCancelsAThingAndClosesCaresWindows`,
    `testEscapeLeavesHomeAndTemplatesWindowsWithoutSaving` and (0.62) `testEscapeClosesTheTripsWindows`. Covered by
    a test: Your choices, the restore, What's new, Open a shared link, Your things, a thing, Your bags, the table
    (iPhone) and its Filter, Search, Grab Lists, a template, a row, New, and the trips' windows. By the code only
    (the same one line): the other guide pages (How it works, Your first real trip — the same `GuideHeader`), the
    swap sheet, the grab menu, a grab list, the icon picker, Choose from your things, Refine, a bag's page, Sort,
    Columns, Change (the table's bulk change), the world map. On the iPhone ⌘. closes a sheet that may be swiped
    away by itself, so these tests go red there only when Escape SAVES (seen: Escape planted on Save → "Escape
    saved the thing / the row"); a missing shortcut shows on the Mac, in CI's Mac job.
18. [rule-break] **Settings keeps two `.sheet` modifiers on one view** (Your choices and the restore, plus a
    `.fileImporter` and a `.fileExporter`). Tried in 0.62 as one `.sheet(item:)` with a destination; on GitHub's Mac
    run the rescue copy's restore then never opened after a first restore (`testTheCopyKeptBeforeARestoreBringsEverythingBack`),
    so it is two sheets again, as in 0.61, which that test passes. Left open: the single sheet needs a Mac to prove it on.
    `testSettingsOpensYourChoicesAndTheRestoreOneAfterTheOther` opens both one after the other.
19. **Resolved in 0.62** — ~~The shot helper's comment names `tools/shots.sh`.~~ It says how pictures are taken
    (`TEST_RUNNER_SHOTS_DIR`) and that night mode is the simulator's appearance, set before running the same tests again.
20. **Resolved in 0.62** — ~~`forThisLaunch`'s doc comment lists only three test modes.~~ It lists all six.
21. **Resolved in 0.62** — ~~SampleLibrary's weight/place tables name Towel, Goggles and Swim cap.~~ The dead
    entries are gone and the comment says why those three have no weight and no place; "514 of 431" is gone.
22. **Resolved in 0.62 (the screen)** — ~~Worth a look calls templates "lists".~~ It says "on a template that no
    longer exists". Release 0.59 filing its new feature under *Changed* is in Releases.swift, which only a release
    edits: proposed for the next What's new pass.
23. **Resolved in 0.62** — ~~The scheme runs `PackingCoreTests` but not `PackingLibraryTests`.~~ It runs both, on the
    iPhone and the Mac (§26).
24. **Resolved in 0.62** — ~~The `mac` job's timeout comment is a copy of the iPhone job's.~~ It has its own.
25. **Resolved in 0.62** — ~~TestFlight `notes` never reach testers.~~ They become the builds' "What to Test"; a
    failure to set it only warns (§28).
26. **Resolved in 0.62** — ~~The Reminders card's sub-line.~~ It names Preparations a month ahead, a week ahead, the
    day before and the day you leave (§3).
27. **Resolved in 0.62** — ~~`RemindersCard.refused` is not remembered.~~ The card asks the device whenever it shows,
    whenever the app comes back to the front and after every turn of the switch (`PackingReminders.permission()`);
    refused by the device, the red line shows with the switch on or off; never asked yet is no refusal (§3). Pinned
    by `testRemindersSayWhenTheDeviceBlocksThem` (switched off, left and opened again: the line stays).
28. Resolved in 0.62 (the templates area): a cover never shows an emoji, even one a template brought from the web app — the drawn icon or the letter instead (spec 04). Was: [idea] **Template covers can still show an emoji** (data from the web app) when a template has no icon, despite
    "no emoji" — deliberate per the comment ("His covers are his data"), noted for a rewrite.
29. **Resolved in 0.62** — ~~The public repository holds real first names.~~ The starter packers are the invented
    Kim and Robin (parity stays honest: QUESTIONS.md §16 N8), every example person in tests and parity inputs is
    invented, and the tester group's name comes from the repository variable `TESTER_GROUP` (§28).
30. **Resolved in 0.62** — ~~Two long place or owner names can share one row.~~ Names alike in their first 60
    normalised units are one name: Add says so, and `setNames` / `setPeople` keep only the first (§2.5).
31. **Resolved in 0.62** — ~~"Kit" means two things.~~ "Kit" is his word for all his things (Words); the table
    of the web app's named groups is counted as "Groups of things" in *This device holds* (§16).
32. **Resolved in 0.62** — ~~An undated unused photo is kept for ever and never mentioned.~~ Worth a look names it on its own and removes it only on his press (§12, worry 4).
