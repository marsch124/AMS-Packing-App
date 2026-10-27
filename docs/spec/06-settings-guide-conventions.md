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
`Headings.swift`, `HomeScreen.swift` (Pills, FlowRow, PillTone, TemplateTone, WorkoutTone), `Loop.swift` (the guide's loop card),
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
| 1 | *For the lost-luggage desk* (0.80, spec 07 part 18 C: his name, phone, e-mail and home address, `DeskDoor`, its own sheet) above the *Your choices* door (§2) — a card of two rows since 0.80 | always; `Metrics.screenTop` (4 pt) above it — where every tab's first line starts (0.67; 14 before); on the Mac under the empty title bar strip | `settings-desk`, `settings-lists` |
| 2 | *Remind me to pack* card (§3) — on the iPhone also *Messages when a trip moves on* (0.77, §3c) | always | `settings-reminders-card` (`settings-moves-on`) |
| 2a | *Show my things in Spotlight* card (0.92, §3d) — the switch and how many things this device's Spotlight holds | always | `settings-spotlight-card` (`settings-spotlight`, `settings-spotlight-count`) |
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
Reached only through the door. **Since 0.92 the page works on a copy of the library** (`ListsScreen` =
`DraftedPage { ListsPage(page:) }`, §20a): every Add, Remove, Rename, move and This is me changes the copy — and so
does For the lost-luggage desk opened from This is me. Left with **Done** (top right, `HeaderButtonStyle(tint:
settings slate, filled: true)`, id `lists-done`, ⌘S), which hands over what was changed (`PageDraft.save`; since
0.102 `PageDraft.done`: a list the other device changed too meanwhile is asked about first — "Your storage places",
Keep both or Keep mine, §20c), or
**Cancel** (top left, outlined muted, id `lists-cancel`; Escape too — ⌘. on an iPhone keyboard, §20), which throws the
copy away; a swipe down on the iPhone closes it while nothing is changed and with something changed asks "Discard
changes?" first (§20a). Until 0.92 there was only Done (and Escape closed as Done
did), and every Add, Remove, Rename and move was written at once through `LibraryModel.change`.

### 2.4 What is on screen, top to bottom
- Header row (padding 16): **"Your choices"** (22 heavy, ink, id `choices-title`), Spacer, **Done**.
- Then a `KeyboardAwayScroll` with a `VStack(spacing: 8)`, padding 16 horizontal / 24 bottom:
  - Intro (15 medium, muted, wraps, id `choices-intro`): **"The words the app offers you as buttons. Add your
    own with the field under each part; hold the grip ≡ and drag one to its place; the pen renames one or moves it
    up or down; one that is still in use somewhere cannot be removed."** (the grip sentence 0.70) — the Mac's; on
    the iPhone (0.72, no ▲ ▼ there) "… the pen renames one; one that is still in use somewhere cannot be removed."
  - Five parts, in this fixed order (`Kind.allCases`): `places`, `owners`, `people`, `conditions`, `phases`. For each:
    - A `HeadingBand` (§21) in the Settings slate, 16 pt space above, id `choices-heading-<kind>`. Titles:
      **"Storage places"**, **"Owners"**, **"Packers"**, **"Item conditions"**, **""When" steps"**.
    - The hint (15 medium, `Theme.ink` at 85 % opacity, wraps, id `choices-hint-<kind>`):
      - places: "Where a thing is kept at home — a cupboard, the garage, the basement. You give a thing its place
        under Kept at home; a trip grouped by From where ("sorted" until 0.101) then lists what to fetch room by room. The square beside a
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
      conditions and steps, ON THE MAC two drawn chevrons ▲ ▼ (`M6 15l6-6 6 6` / `M6 9l6 6 6-6`, stroke 2.2, in 44×44 boxes,
      slate at 10 % with a 1.4-pt slate outline, ids `list-<kind>-up` / `list-<kind>-down`, VoiceOver "Move <label>
      up|down") and the line "Up or down the list." ("Up or down the timeline: every trip follows this order." for
      steps; 15 medium muted); ON THE IPHONE (0.72, his answer 8 Oct 2026: "Drag and drop on the phone as well") no
      chevrons, only the line "To move it, hold the grip ≡ at its left and drag it." ("To move it up or down the
      timeline, hold the grip ≡ at its left and drag it: every trip follows this order." for steps; 15 medium
      muted, id `list-<kind>-drag-hint`); for owners instead "Owners are always in A–Z order.", and under it (0.70, his answer
      "My things." to whose things Apple Health marks) **"This is me"** — a pill (Subheadline semibold, min height
      `Metrics.chip`; slate outline on 10 % slate, filled slate with white words while this owner is him; id
      `list-owners-me`, `.isSelected` when on) with a muted line beside it: "Whose things Apple Health marks in a
      trip's review." / "Apple Health marks your things in a trip's review." Press → `setMe(owner)`; pressed on the
      owner already marked → `setMe(nil)` (nobody). One at most: marking another moves the mark. On the owner marked as
      him only, under the pill (0.80, spec 07 part 18 C), **For the lost-luggage desk…** (Subheadline semibold slate,
      id `list-owners-desk`) opens his details for a baggage desk — the same sheet as Settings' first door. Under the card, its needs line
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
  then reads "Hall cupboard"). Since 0.72 the ▲ part is the Mac's; on the iPhone the pen shows no `list-places-up`
  but `list-places-drag-hint`, and Hall cupboard's grip dragged onto row 1's moves it there.
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
- (0.77, iPhone only) Under its own lines, a 1-pt hairline (`Theme.line`, 4 pt above and below) and a second
  `Toggle`, **"Messages when a trip moves on"** (id `settings-moves-on`, green; its words since 0.87 "On this
  iPhone: "Charge tonight" at 20:00 the evening before a trip, if something still needs charging; "Have a good
  trip" when a trip sets off — at the time you leave, else at 8 — and the morning after its last day, at 10, a word
  to review it." — until 0.87 without the first clause; `UserDefaults` `ams.movesOn`, absent = ON). Since 0.87 the
  switch holds Charge tonight too (spec 07 part 16, "0.87"). Turning it on asks the system's one question
  (`askToShow`); either way `TripMessages.reschedule` runs. See §3c. The red line below (since 0.77) sits under BOTH
  switches — it holds for every message the app sends — and the "Next" line under the first one.
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
notifications per app). (0.101, spec 07 part 21) A step's "to do" counts his things' own reminders not ticked on the
trip as well as the template reminders — "≥1 week ahead: 3 to pack, 1 to do" — so a day with only a thing's reminder
left still has its one notification ("Day before …: 1 to do"); the same rules otherwise (09:00, one per trip per day,
days past dropped, 48 at most).

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

## 3c. Take a break and messages when a trip moves on — notifications (`Store/TripMessages.swift`, `PackingLibrary/TakeABreak.swift`; 0.77)

His yes of 13 Oct 2026 (spec 07 part 16 has the words, the rules and the tests). The notification side, built
like the door check (§3a):
- **iPhone only** (`#if os(iOS)`). The Mac shows Take a break whole (the break is kept on the trip, so the iPhone
  reminds him — the sheet says "your iPhone will remind you"), has no Messages switch and never asks.
- **Permission**: the same one. Asked when a break time is picked, when the Messages switch is turned on, and —
  with the switch on and the iPhone never asked — the first time a trip at Pack is opened (`TripMessages.askOnce`).
- **Scheduling**: `TripMessages.reschedule(library)` — removes every pending id starting `break-`, `moves-` or
  (0.87) `charge-` (`TripMessages.prefixes`), then
  adds one calendar notification per `Library.tripMessages(now:movesOn:)` entry (title, body, default sound,
  `userInfo` `tripId` + `trip` = `break` | `onsite` | `review` | `charge`); `now` is `Today.now` (the tests' clock too). Run from
  `RootView` whenever the library settles (debounced 2 s) and when the app comes to the front, after a choice in the
  break sheet and after the switch. Under the UI tests: `planned` holds the plan (`-showTripMessages`).
- **Tapped**: the shared delegate sees `trip` in `userInfo` (checked before `door`) and calls `TripMessages.open`:
  Home and the trip; for `review`, `model.tripFocus` with `review: true` — the trip opens its Review; for `charge`
  (0.87), `charge: true` — every line shown, Before you go's To charge scrolled into view (spec 03).
- **Budget**: an iPhone keeps 64 waiting notifications per app: packing reminders ≤ 48, the moves-on messages and
  (0.87) Charge tonight together ≤ 6 (the soonest), one break per trip, the door checks (two per trip with times).

## 3b. "Where is my …?" — Siri and Shortcuts (`Store/WhereIsIntent.swift`; 0.69)

Stop B of his idea plan: "On site you ask 'Where is my charger?' and the answer comes back: 'Backpack, front
pocket.'" — on the iPhone and the Mac, on site and on the way home. `WhereIsIntent` ("Where is my thing?";
`openAppWhenRun = false`) takes a `ThingEntity` (`ThingQuery`: his things not "Not in use", A–Z, also found by a
typed or said part of the name) and answers `WhereAnswer.said` as a dialog and as its value; a thing gone since:
"That thing is not in Packing any more." A thing inside a kit (0.73): the kit, then where the kit is — "In the Camp
pouch, in the Backpack (front pocket)."; taken out of it: "Taken out of the Camp pouch." and its own place. The
action's description says so: "… A thing inside a kit: the kit, and where the kit is." Phrases (in `PackingShortcuts`, the fourth App Shortcut, tile "Where is my
thing?", symbol `bag` — the Shortcuts app's own tile, as the other three): "Where is my <thing> in Packing",
"Where's my <thing> in Packing", "Ask Packing where something is" (Siri asks "Which thing?"). The things offered
by name follow his library (`updateAppShortcutParameters` on every change, as for the grab lists). The answer's
rules: spec 03, "Bag pockets on a trip, and Where is my …?". **Not covered by a UI test** (no test can speak to
Siri): the words come from `Library.whereIs`, covered by `PocketsTests.testWhereIsMyCharger` and (kits) the two
`testWhereIsAThingInsideAKit…` tests, and the same answer shows first in Search
(`testSearchShowsWhereAThingIsOnTheTripUnderWay`, `testWhereIsAThingInsideAKitNamesTheKitAndWhereTheKitIs`).

## 3d. Find your things in Spotlight (`Store/Spotlight.swift`, `Screens/SpotlightCard.swift`; the words: `PackingLibrary/SpotlightThings.swift`, spec 05; 0.92)

His yes of 19 Oct 2026 (spec 07 §11): "Find your things in Spotlight: type 'headlamp' in Spotlight on the iPhone or
Mac and see the thing and where it is, without opening the app." Every thing of his is one result in the device's
own Spotlight (Core Spotlight): its name, the line saying where it is now, its first photo (else the app's icon);
tapping it opens the app on the thing's page. What is shown, what it is found by and what never is: spec 05 "Your
things in Spotlight".

**The card** (`SpotlightCard`, id `settings-spotlight-card`), between *Remind me to pack* and *iCloud sync*, built as
that card is (12 / 10 padding, `Theme.card`, a 1-pt `line` border, radius 12):
- A `Toggle` (`settings-spotlight`, tinted `AppSection.events.color` — green when on): "Show my things in Spotlight"
  (Body semibold ink) over "Type a thing's name in Spotlight on this iPhone|Mac to see where it is — tap it and its
  page opens." (Footnote muted).
- Under it, always (`settings-spotlight-count`, Subheadline semibold; `AppSection.settings.color` while on, muted
  while off or unavailable) — `SpotlightCard.says(on:count:unavailable:)`: on → "10 things in Spotlight on this
  iPhone" ("1 thing"); on with none yet → "Putting your things in Spotlight…"; off and empty → "None of your things are
  in Spotlight on this iPhone."; off, still being taken out → "Taking your things out of Spotlight…"; on but the
  device's Spotlight takes nothing (`isIndexingAvailable` false) → "This iPhone's Spotlight cannot take them." The
  number is what the index holds — the fingerprints handed over and not taken out (the tests' shelf counts itself) —
  so "None" is said only once they are really out.

**Per device, on unless he switches it off** (`ams.spotlight.on`, default true; never synced, not in a backup): each
device has its own Spotlight, as it has its own reminders switch. Off (`ThingSpotlight.set(on:library:)`) takes every
thing out of this device's Spotlight at once (`deleteSearchableItems(withDomainIdentifiers: ["things"])`) and forgets
the fingerprints; on hands them all over again.

**Kept current** (`ThingSpotlight.sync(_:)`), from `RootView`: whenever the library settles after a change (the
2-second wait that also puts the reminders right — a thing added, renamed, deleted, moved to another bag, packed,
given a photo, here or on the other device) and whenever the app comes to the front (the day alone moves a trip
under way on). The words are worked out off the main thread (`Task.detached`, utility); only the things whose
fingerprint differs from the one handed over last are handed over (`SpotlightWords.changes`), in batches of 100, each
remembered as it lands (`ams.spotlight.indexed`, thing id → fingerprint) — a hand-over cut short resumes where it
stopped; things that went are taken out. A failed hand-over leaves the fingerprints as they were, so the next one
tries again. One job at a time, in order (`enqueue`: a chain of tasks on the main actor): a hand-over and the switch's
clearing never overlap; only the newest library waiting is handed over; a hand-over stops between batches when the
switch goes off (the clearing follows it).

**The index remembers its hand-over.** Every change is made in a batch that marks the index with the current
hand-over (`beginBatch` … `endBatch(withClientState:)`; `ams.spotlight.generation`, a UUID). Once a launch, before the
first hand-over, the app asks the index for its mark (`fetchLastClientState`): another mark, or none — an index lost,
rebuilt by the system, or not brought along to an iPhone restored from a backup — means what it holds is unknown, so
everything is taken out and handed over again under a new mark. If the index cannot answer (the iPhone locked), it is
asked again next time. The system's own requests while the app runs (`CSSearchableIndexDelegate`: reindex all, or
these identifiers) forget those fingerprints and hand them over again.

**Each result** (`DeviceSpotlight.put`): `CSSearchableItem(uniqueIdentifier: "thing:<id>", domainIdentifier:
"things")` with a `CSSearchableItemAttributeSet(contentType: .content)` — `title` and `displayName` the name,
`contentDescription` the line, `keywords`, `thumbnailData` the first photo at most 240 pixels on its long side
(`JPEG.make(from:maxSide:)`, from the photo's data URL) or nothing; `expirationDate = .distantFuture` (Spotlight's
default would drop a result after a month). The index is `CSSearchableIndex(name: "things")` — on the iPhone with
`protectionClass: .complete`: while the iPhone is locked his things are not searchable (a Passport's "Kept at home:
Chest of drawers" is nobody's business), and a hand-over tried then fails and is tried again later.

**A tapped result** (`ThingSpotlight.open(_:)`): the system hands the app an `NSUserActivity` of type
`CSSearchableItemActionType` (`com.apple.corespotlightitem`, declared in `NSUserActivityTypes`) with the identifier in
`userInfo[CSSearchableItemActivityIdentifier]` — at a cold start and while the app runs. On the iPhone `RootView`'s
`onContinueUserActivity(CSSearchableItemActionType)` takes it. On the Mac the app's delegate takes it
(`PackingMacDelegate.application(_:continue:restorationHandler:)`, Store/QuickActions.swift): an activity handed to
the app's delegate never reached SwiftUI's `onContinueUserActivity` there (GitHub's Mac, 19 Oct 2026 — "the tapped
result opened no page as the app opened"). Should one tap reach the app twice (both ways), the same thing within 2
seconds opens once (`lastOpened`) — a second request would close the page and open it again.
An identifier that is not a thing's, or a thing gone since (its result goes at the next hand-over), opens nothing.
Otherwise `model.thingToOpen = id`: the frame switches to Home, and Home opens `ThingEditor(itemId:)` as a sheet
through `whenFree` — closing any of Home's own windows first (Search, a trip, a grab list …), as for a Shortcut (spec
02 section 3). Save and Cancel bring him back to Home. On the Mac the app comes to the front, and with no window
open one opens for the page (`GrabQuickActions.openMainWindow`, as the Dock menu does). A thing set to Not in use
after its result was handed over still opens (its result goes at the next hand-over).

**Under the UI tests** the results go to a list in memory (`MemorySpotlight`, empty at every launch as a new
device's index is), never to the device's Spotlight — the tests run on his Mac too; `-spotlightForReal` (debug builds)
uses the real one, to look at results on a simulator. The switch's key is reset at launch. Hooks (`ThingSpotlight.playTapped`),
each taking the result titled so from what the app handed over (so a thing not handed over cannot be opened this
way), once it has been, and handing it to the app **as the system does** — the scene's delegate
(`scene(_:continue:)`, which reaches SwiftUI's `onContinueUserActivity`) on the iPhone, `NSApp.delegate`'s
`application(_:continue:restorationHandler:)` on the Mac: `-spotlightTap <name>` as the app opens;
`-spotlightTapOnReturn <name>` (iPhone) as it comes back to the front; `-spotlightTapWhenClosed <name>` (Mac) once
its last main window has closed.

**Tests.** `testASpotlightResultOpensItsThingsPage` — `-spotlightTap Headlamp`: the page opens (`thing-detail`,
`thing-name` "Headlamp"; picture `spotlight-opened`); iPhone: `-spotlightTapOnReturn "Rain jacket"` with Search up,
Home button, back: Rain jacket's page, Search gone, Cancel → Home; Mac: `-spotlightTapWhenClosed "Rain jacket"`, ⌘W:
a window with Rain jacket's page. `testSettingsTakesHisThingsOutOfSpotlightAndPutsThemBack` — on to begin with, "10
things in Spotlight" (picture `settings-spotlight`); a thing deleted in Your things → "9 things"; off → "None of your
things…"; on → "9 things" again. Seen red with planted faults (0.92): no `onContinueUserActivity` — "the tapped result
opened no page as the app opened"; Home opening the page without `whenFree` — "a result tapped while the app ran opened
no page over Search"; off not taking them out — "off, his things are still in Spotlight: 'Taking your things out of
Spotlight…'"; gone things not taken out — "a deleted thing is still in Spotlight: '10 things in Spotlight on this
iPhone'". Looked at for real on an iPhone 17 Pro simulator (iOS 26.5, 19 Oct 2026, an invented library brought in
with `-importFile`): Spotlight's Search showed "Headlamp — Usually in the Backpack · Front pocket · Kept at home:
Garage" with its photo as the Top Hit, under the app's heading "Packing"; tapped with the app not running, the app
started on the Headlamp's page; tapped while it ran in the background, Rain jacket's page opened. Not looked at for
real on the Mac (the Mac's tests go through the hooks above).

---

## 4. *iCloud sync* card (`SyncCard.swift`) — briefly

Full behaviour belongs to the storage/sync chapter and `docs/store.md`; here only what Settings shows.
Origin: field test 3 Oct 2026 ("we need to get the sync going because I need to work from the Mac"), 0.54.
A card like Remind me to pack's: padding 12 at the sides and 10 above and below, its lines **4** apart (0.67; 14 and 8
until then).

- (0.92) The pill says what Home's sync light says (`SyncCheck.light`; spec 02 §12b, spec 01 §8): iCloud off, Can’t
  tell, In sync (green), Sending… / Receiving… (orange), Stuck (red — failed, hung ten minutes, or waited half an hour);
  new lines `sync-running` (a send or receive running; loud once hung: "Receiving from iCloud has hung since 07:57 —
  quit Packing and open it again.") and `sync-waited`; "Not in iCloud yet" orange until it has waited too long; a
  receive with no end is never "failed" again. The card also opens from Home — the sync dot at the foot of "This
  Device", its bubble, Details — as Sync details (spec 02 §12b). What follows is the card before 0.92.
- (0.101) **No pill.** His words (26 Oct 2026) on Sync details' "In sync": "should not look as a pill. Please design
  it." The header's right end is Home's own sync dot — `SyncLight.dot` (8 pt), filled `SyncLight.color` (green In sync,
  orange Sending…/Receiving…, red Stuck, muted iCloud off / Can’t tell) — its own element `sync-state-dot` (image,
  label "iCloud sync"; in DEBUG builds its value is the colour's name, "green", the tests' only way to see it) — and
  6 pt after it the words `state.word` (id `sync-state`, unchanged) in Subheadline semibold, in that colour made
  readable as words on the card (`SyncLight.words`: `readableHex` of the section colour, darker by day, lighter by
  night; muted for grey); no capsule, no fill; the row on the first text baseline with "iCloud sync". Until 0.101: the
  words 13 heavy white on a capsule of the colour.
- (0.101) **A device checks in by itself.** His Mac's card, 26 Oct 2026: "This Mac checked in 10 Oct 19:11" over "Sent:
  today 11:52 · received: today 11:51". Nothing was lost or overwritten (every way a check-in is written or settled was
  read: one meta record per device, written only on a change of its own value, twins settled newest-first): until
  0.101 a check-in was written ONLY by Sync now, and Sync now had last been pressed on the Mac on 10 Oct, while the
  iPhone's line moved because it had been pressed there. Now, with iCloud on (`SyncWatch.on`), the library read
  (`state == .ready`) and never from a page's copy, `SyncWatch.checkInIfDue` writes this device's check-in through
  `Library.checkInIfDue(device:now:)` once `checkInDue` — never checked in, its last check-in `Library.checkInEvery`
  (15 minutes) old or older, or more than a minute in the future (a clock that ran ahead). Asked by `RootView` as the
  app opens and every 60 s while it runs (a `.task` loop), and when it comes back to the front. So "This <device>
  checked in" and the other device's "The <device> last checked in" say when each device was last there, at most a
  quarter of an hour behind; Sync now still checks in at once. With iCloud off (and under the UI tests' own library)
  only Sync now checks in — there is no other device to tell.
- Header (before 0.101's dot): **"iCloud sync"** (18 bold) and a state pill (13 heavy white, id `sync-state`; `SyncCheck.state`): **"Off"**
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
- Tests: UI `testSyncNowChecksInFromThisDevice`, `testSyncNowOnAnEmptyDeviceKeepsTheTwoDoors` (0.62),
  `testTheSyncLightOnHomeSaysHowICloudIsGoing` (0.92); model
  `SyncCheckInTests.testACheckInTravelsWithTheLibraryAndKeepsTheDevicesApart`, `SyncCheckTests` (0.62: the reading,
  the pill, the order, the plain words, `<when>`). (0.101) UI `testTheSyncCardSaysItsStateWithHomesDotNotAPill`
  (`-syncLight insync|sending|hung`: the words In sync / Sending… / Stuck, the dot green / orange / red, 8 pt, before
  the words and on their line; pictures `look101-sync-<state>`) — red on the base 0.100: "XCTAssertTrue failed - no dot
  before the sync card's 'In sync' — still a pill?"; UI `testThisDeviceChecksInByItselfWithICloudOn` (`-syncLight
  insync`: `sync-self` says "checked in today" with no press, no `sync-said`; picture `look101-sync-checkin`) — red on
  the base: "XCTAssertTrue failed - with iCloud on, this device did not check in by itself: 'This iPhone has not
  checked in yet.'"; model `SyncCheckInTests.testADeviceThatSyncsChecksInByItselfEveryQuarterOfAnHour` (his case: the
  Mac's 10 Oct check-in moves on the 26th, the iPhone's untouched; not again within 15 minutes, due at 15:00; never
  checked in = due; a check-in from the future = due, half a minute ahead = not; it travels through the records) —
  red with the base's "never by itself" planted: "XCTAssertTrue failed - a Mac that last checked in on 10 Oct did not
  check in by itself". All green on the iPhone (iPhone 17 Pro, iOS 26.5) by day and night and on GitHub's Mac (probe).

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
keyboard — 0.62; ⌘S too since 0.103, `commandS`, §20a), padding 16. Each page then
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

**The version history** (102 entries; N/C/F/R = number of New/Changed/Fixed/Removed lines — every count checked
against `Releases.swift`):

| Version | Date | Title | Lines | Gist |
|---|---|---|---|---|
| 0.102 | 27 Oct 2026 | Two devices, one list | N2 F1 | his choice B of 26 Oct (spec 01 OQ 32 closed): Done/Save asks Keep both / Keep mine when the other device changed the same block meanwhile (grab list + 1-in-10 marks, template name/cover/colour/sections/area, Your choices, kit contents; SavesThatCross.swift, three-way compare), plus a quiet note when the other device's later save overwrote ours (kept 10 min in memory, id save-crossed); Pack's light readable on the Mac (accessibility element trip-flash-n, fill hidden) |
| 0.101 | 26 Oct 2026 | Reminders on things, and your list | N6 C5 F1 | his list of 26 Oct + reminders on things (his yes to the picture): look101 (loop strip = Stations rule, sync dot, check-in by itself every 15 min, Group by, To do tab badge, Light blue/Light yellow), lists101 (Before you go folds, Fold all + Option-click, To do page Priority/Others/Done + Undo after a tick, To buy Bought), remind101 (Remember with it, Goes with, tapped station stays lit + Pack lights the next line, thing reminders in To prepare and notifications) |
| 0.100 | 24 Oct 2026 | Two Mac crashes | F2 | his Mac crash of 24 Oct (0.99): an Objective-C exception from SwiftData reading a photo whose external file was missing (iCloud mid-delivery) inside a Task left Swift's executor bookkeeping broken → next click EXC_BAD_ACCESS; Record.read() through AMSCatchException (ObjCExceptions.h/.m, bridging header), photo left out and re-read after 5 s (≤3), iCloud reload no longer in a Task; DropDown keyRows[-1] (18 Oct, 0.87) clamped (clampedLit); tests testAPhotoWhoseFileIsMissingNeitherStopsTheSyncNorShutsTheApp (-uiTestingPhotoGone), testAnArrowOnAnotherRowOfAnOpenListDoesNotShutTheApp, red on 0.99 on GitHub |
| 0.99 | 21 Oct 2026 | ⌘Q on the Mac | F1 | macOS refuses to quit while a sheet is open, silently: ⌘Q with a template page, Your choices or a bag page open now quits, and asks Discard changes? first when the page holds a change (EditDraft.swift, AMSPackingApp.swift, QuickActions.swift; work/macquit 4b925bc); Mac UI test red on 0.98 |
| 0.98 | 21 Oct 2026 | Cancel and Done the Apple way | C2 | his decision 21 Oct: template page/Your choices lose 0.94's save on background/quit (PageAway, keepAway removed); bag page holds every change incl. pockets until Done (EditDraft.step; PocketsTrail unused by the app); new tests testABagsPageKeepsNothingButByDone, testATemplatesPageAndYourChoicesKeepNothingButByDone (launch mode -uiTestingKept); 0.94's two keep-on-close tests replaced; the four GitHub-only iPhone tests fixed (work/gh4tests: keyboard put away as before) |
| 0.97 | 21 Oct 2026 | Sections and grab lists on both devices | F3 | his checks 6 and 7 of sheet 0.94–0.95: a line's record carries its section's {id, name} (inside the JSON, stripped on load); SectionsBack gives a lost section back on load (in memory, saved with the next save); DropDown(unknown:) so no raw id shows; twins of an original grab list's record merged (mergeGrabTwins), none deleted; new CrossingSavesTests (both sending orders) and UI test testALostSectionIsGivenBackAndNoRowShowsAnId |
| 0.96 | 20 Oct 2026 | No freeze on a trip | F1 | the trip list's endless redraw (iOS 26 lazy list): a trip row's state key moved off the lazy row onto an inner VStack, the row keyed by line id, group and position only; new UI test testATickedTripStillAnswersWithTheKeyboardUp; GitHub suite timeout 120 → 240 min (six full runs never finished, 0.89–0.94) and the Mac trip-name test typed while in view |
| 0.95 | 20 Oct 2026 | Both devices, every page | F4 | residual of the outside review: PageChanges merges to-dos, kits, When steps (mergePhases), settings rows (mergeShared), photos and meta (mergeMeta) field by field; list fields (sections, kit itemIds, photos, kitContents/kitOut, meta lists) merge as lists (mergeList); Trip settings (TripEvent.takingSettings), desk (setDeskDetails), grab Edit (saveGrabEdit), kit part (kitFromPage) write only changes; bag Cancel puts back only its own pocket changes (PocketsTrail) |
| 0.94 | 20 Oct 2026 | Nothing lost | F6 | outside review items 3, 4, 5, 7 + 0.93's two open points: bag page writes only on background/quit (DraftAway; savedHere after), template page/Your choices save on background/quit through the field-wise merge (PageAway), Library.mergeFields for things/rows/templates (deleted stays deleted), failed save keeps the page and typed name (LibraryModel.change returns kept), content-based twin plan (Records.planTwins), launch reads only the newest history entry (StoreHistory) |
| 0.93 | 20 Oct 2026 | Safe on both devices | F3 | outside review fixes 1, 2, 6: PageChanges merges trip heads and lines field-wise (follow stamp no change; deletions stay); failed save rolls back + note, red screen only when the store can't open, restore/import report failure; thing page Save writes only changed fields (Item.takePage, ThingPageSave.swift) |
| 0.92 | 19 Oct 2026 | Cancel everywhere, a sync dot and 41 new icons | N4 C3 | sync dot under This Device (SyncLight, SyncCheck.light, running vs left-behind vs hung); Duplicate a thing (ThingDuplicate.swift, copyRecord/copyRow); Spotlight (SpotlightThings.swift, Spotlight.swift, per-device switch); 132 icons (41 new + keywords); Cancel everywhere (PageDraft/DraftedPage, Library.applyingPage, swipe asks Discard changes?, §20a audit); bag page Cancel; Create new trip ink grey |
| 0.91 | 19 Oct 2026 | Home in frames, more colours, bags by hand | N6 C3 | Home frames (homeCard, home-grab-frame, home-create-card, This Device under the trip, Full/Quick full width); pill colours (Library.pillColour, TemplateTone); 16 colours (plum, navy, olive, sand; pickerRows 2); icon search (TemplateIconKeywords.swift); Activity areas pill at the foot; Your bags own order by hand, arrow after the name; bag page typing lag fixed; photos from a file (Mac drop, Files) |
| 0.90 | 19 Oct 2026 | Search, colours, bags and photos | N7 | How it works search (GuideSearch.swift, `guide-search`); template icon colour (TemplateColour.swift, TemplateColourSwatches); New template from a thing's page (NewTemplateDoor); thing photos (ThingPhotos.swift, THING_PHOTOS_MAX 2); bag Notes, Duplicate (BagDuplicate.swift), edit pen while packing (EditBagPen), Care → Bags sort (BagSorting.swift, bagEditedAt) |
| 0.89 | 19 Oct 2026 | Your own activity areas | N2 | his own areas (ActivityAreas.swift, meta `activityAreas`, own area in template extra["area"], built-ins keep `group`; AreasScreen; ChoiceEdits kind "areas"; WET never removable); template page Activity area drop-down; fast lane test phones iOS 26.5 by default |
| 0.88 | 18 Oct 2026 | Clearer notes | C1 | NoteHitLine: "Note on <template>: " / "Note: "; thing page "Note on the <template> template: " |
| 0.87 | 15 Oct 2026 | Charge tonight, and done headings fold | N2 | Charge tonight trip message (ChargeTonight.swift, CHARGE_TONIGHT_AT 20:00, `charge-<trip>`, kind .charge, follows the moves-on switch); grab-list heading rings + fold when all in hand (GrabFolds.swift, `grab-group-<g>-progress`, GroupProgressMark word) |
| 0.86 | 15 Oct 2026 | Battery, tags, and your lists at a hold | N2 C1 | Battery column in the things table (TableColumns/ThingsTable, batteryArrivedKey, Undo restores removed keys); Tags leaves out a bag inside another (TagsInside.swift, `day-tags-inside`); grab lists as Home Screen quick actions + Mac Dock menu (QuickActions.swift, GrabQuickActions, GrabIcons assets); fast lane shuts its simulators down |
| 0.85 | 15 Oct 2026 | Your own headings | N2 C1 R1 | his own grab-list headings (GrabHeadings.swift, GRAB_HEADING_MARK U+2063 "## " inside `items`, GrabDefinition.lines/GrabLine; `grab-group-<g>`); Heading above (context menu on a thing in Edit); GrabKinds removed; WorkoutKind.mobility label "Mobility & breath"; fast lane drops emoji from What to Test |
| 0.84 | 15 Oct 2026 | Calmer, and in groups | N1 C6 | grab list grouped by Kind of thing (GrabKinds.grabGroups, small grey headings `grab-group-<n>`; replaced in 0.85 by his own headings, spec 02 §6–7); Take a break a round cup / time capsule; Add to Calendar filled amber once chosen; 🎒 BREAK_TITLE; short station chips (`chip`); header Review only from On site (`Loop.offersReview`, test switch -reviewAtPack); grab Share round at the bottom right (ShareDoor round:) |
| 0.83 | 14 Oct 2026 | Add a bag anywhere | N1 C2 | + Add a bag on the Bags card (AddBagPanel with id prefix); Library.hasLostBagPage excludes On body / On me / Worn / Wearing; Lost bag? a quiet link |
| 0.82 | 14 Oct 2026 | See it grow | N3 | green ring per group + What's left with his pace (PackingPace, tickedAt; chapter 07 part 20); Before you start (chapter 07 part 19) |
| 0.81 | 14 Oct 2026 | Packing Stations | N3 C4 | renamed from Packing day; slimmer station chips; Tags Remind me + friendlier look; Ready Add a reminder (tripTodo lines, due at once); Bags out + Add a bag (dayAddedBags); header tones (TripHeaderTone); fast lane on three simulators (ui-split.py) |
| 0.80 | 14 Oct 2026 | If a bag goes missing | N4 | chapter 07 part 18: A bag details (BagDetails, own photos), B flights and stay + bag-tag numbers (TripTravel), C the Lost bag page + PDF (LostBag); Settings → For the lost-luggage desk |
| 0.79 | 14 Oct 2026 | Packing day | N4 C2 | Packing day stations (PackingDay.swift, chapter 07 part 17; his seven drawn icons); Has an AirTag on a bag; the photo of all the bags; Undo after a heading's tick and Clear every tick; Tick everything removed from the trip and Pack to go home; Clear every tick in Trip settings; How it works part |
| 0.78 | 13 Oct 2026 | Calmer words | N1 C4 | group headings not upper-cased (groupHeading, Templates tab, activityChoices "Other Templates"); weekendbag icon + short/weekend suggestions; Food label Mix; Season pills draw sun / snow (Pills(icons:)); Library.quickNote names the Always Packed templates |
| 0.77 | 13 Oct 2026 | Take a break | N2 C2 | Take a break sheet + Continue when? reminder; messages when a trip moves on (Have a good trip / Welcome home), Settings switch; Before you go = one card (flags, To do, To charge); the five step marks he picked (LoopStep.mark) |
| 0.76 | 13 Oct 2026 | Simpler new trips | N1 C4 | battery in a checked bag on plane trips (cabinCheck, inABag); Travelling by Plane / RV only, neither = Car stored; Season from the dates (Nov–Mar Winter) until picked; More choices fold (Season, Food, Laundry); new kits start kitCheck on unless switched off |
| 0.75 | 13 Oct 2026 | Charge before you go | N2 C5 | Has a battery (`battery` key) + To charge card with its own ticks (`charged`, `kitCharged`; Batteries.swift, ToCharge.swift; chapter 07 part 15) and a Your things filter; I leave at framed (LeaveTimes, DoorMark); On site from the leave time on day one (Library.hasSetOff, clockTurns); reminders show their template icons (TripChecks); weather past the reach says when it comes (ForecastAsk.comesFrom, dropWeather); Mac Tab through Only-on-some-trips pills and the battery switch |
| 0.74 | 12 Oct 2026 | Pack by template | N3 C2 | Sorting → Template (TripByTemplate, Library.lineTemplates); template icons on each line (TemplateMarks, `trip-line-<n>-from`); 40 new icons, 90 in six groups (TemplateIconCatalog, lounger for beach); Bags card folded by default; Sorting directly above the list |
| 0.73 | 12 Oct 2026 | Set it once | N4 C5 F1 | Only on some trips on the thing (OnlySomeTrips, chapter 07 part 14); Where is my … names the kit (Pockets); a place's code starts Pack by voice on its trip already open (PlaceOpening.voiceStart); reviewed trips keep their kits (kitThen); a full trip from Always packed alone (templateMissing); reviewed → Done (tripWhen); trip header pen/badge, Send to Obsidian at the foot; first owner / pocket / reminder When inside their lists; Mac Tab through a kit; weather reach 15 days + truthful refusals (ForecastAsk) |
| 0.72 | 8 Oct 2026 | Drag only on the iPhone | C2 | ReorderArrows.shown false on the iPhone; grips on pockets, reminders, grab-list editing, Home's grab-list order and the table's Columns; ↑↓ Mac only |
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

**On screen,** under `GuideHeader("How it works")` and (0.90) the search field (§7a), in this order inside a
`VStack(spacing: 12)` — since 0.90 the view `HowItWorksGuide`, which watches nothing, so a key pressed in the search
field never builds it again; the sheet's container id stays `guide-howitworks`:
1. `FirstTripCard` (§8) — "at the very top" (his idea 13, 2 Oct 2026).
2. `LoopGuideCard` (§9).
3. `WordsCard` (§10).
4. Twelve topic cards (eleven until 0.71) (padding 14, card, radius 12, line border, container id `guide-topic-<n>`): a header row —
   the topic's section mark (`SectionMark`, 24 pt, line 1.9, in the section's colour) and the title (19 heavy ink)
   — then each line as a 6-pt dot in the section colour + text (16 ink, wraps).
5. (0.103) **Keyboard shortcuts** (`KeysGuide`, `Guide/KeysGuide.swift`) — last, after the twelve topics: a heading card
   and a card for each kind of key (§7b).
4a. (0.80) A topic of its own, **If a bag goes missing** (the trips' section), right after *On site* (so the topics after
   it are numbered one more): where the Lost bag page is (Lost bag? in Bags, the Packing Stations' Photos and Ready), what it
   holds, "not filled in" and where a tap fills it in, the bag-tag number typed on the page, the AirTag's Find My hint,
   Share as PDF and Copy as text, his details in Settings → For the lost-luggage desk (or under This is me). Spec 07
   part 18 C. **Words** gains "Lost bag" (after "Packing Stations"). (0.83) Its second line ends "Not in a bag and On
   body (what you wear) have none — no desk can lose them."
5. (0.79) **Packing Stations** — "The Packing day" until 0.81, when he renamed it (14 Oct 2026; spec 07 part 17
   "0.81") — (`PackingDayGuideCard`, `Screens/PackingDay.swift`; container id `guide-packingday`) —
   right after topic 1, *Packing a trip* (drawn inside the topics' `ForEach`, after the topic of that title; it has no
   `guide-topic-<n>` id, so the topics keep their numbers). His ask of 13 Oct 2026: "remember to write about the
   Packing-Day-Stations in the How-this-works". Card padding 14, radius 12, `Theme.card`, a 1.2-pt ring of the Pack
   green at 70 % (the topics' is the hairline). Top to bottom, 12 apart:
   - the day's mark (`StationMark`, 24 pt, a sun rising out of an open case, the Pack step's readable green) and
     "Packing Stations" (Body semibold ink), one element `guide-day-title`;
   - "On a trip you are packing, a row sits right under the loop: Stations, then six stations in the order you go
     through them, each with a short word on its chip — Bags, Pack, Weigh, Tag, Photo, Ready. A station turns green
     when it is done. The one you tap is lit, and stays lit until you tap another (each trip remembers its own, on
     this device); before you tap one, the first still to do is lit. On the iPhone the row slides sideways." (0.101;
     until then "…; the next one to do is lit. On the iPhone …"; until 0.84 "…
     under the loop: Packing Stations, then six stations in the order you go through them. A station …"). The
     numbered stations below keep their full names (Bags out, Tags, Photos);
   - the six stations, in the row's order, each a row: the station's mark (20 pt, white) in a 34-pt green disc — the
     look of a station that is done; its own element `guide-day-<key>-mark`, label = what it shows ("Two bags on the
     floor" …) — then "<n> · <name>" (Body semibold, readable green) + " — <what the mark shows>" (Footnote muted), and
     under it what the station does and what turns it green (Callout ink); the words (`PackingDayGuideCard.says`)
     one element `guide-day-<key>` (`bags`, `pack`, `weigh`, `tags`, `photos`, `ready`):
     1. **Bags out** — "Lay every bag out where you pack, and tick it as it comes out. The bags are the ones your list
        packs into — “Not in a bag” is not one. Green when every bag is out." Since 0.81 then: "At the foot, + Add a bag:
        one of your bags not on the trip yet, or a new one (its name, whether it goes in the cabin, its max weight if
        you like). It joins the trip empty, and Weigh, Tags, Photos and Bags ask about it too; to fill it, pick it as
        Usually packed in on its things' pages. The ✕ beside an empty one takes it off again."
     2. **Pack** — "The trip's own list — how far you are is the count under the trip's name — and a tap takes you
        straight to the list. Green when everything is packed; a thing set aside ⊘ counts as done." (Until 0.84 "Its
        station shows how far you are — 12/40 — and a tap …".)
     3. **Weigh** — "The luggage scale, one bag after another: hang it on the scale, type what it says, Save — the next
        bag comes up. It is the same weight as in Bags. When you tick the last thing on the list, Weigh opens by itself
        — once per trip. Green when every bag is weighed."
     4. **Tags** — (0.81) "A card for every bag, with a green edge: a Name tag tick, and an AirTag tick for each bag
        that has one — each wearing the tag's or the AirTag's drawing. A bag whose ticks are all on turns light green,
        with a ✓. Remind me, under a bag not done yet, writes a To do on the trip — “Name tag for …”, ready to change —
        and it shows in Before you go." (until 0.81 "A Name tag tick for every bag, and an AirTag tick for each bag
        that has one.") "Has an AirTag is the
        bag's own switch — under the bag here, or on its page in Care → Bags; switch it on once and every trip asks for
        it. Green when every tick is on." Since 0.86 (spec 07 part 17 "0.86") then: "A bag packed inside another bag on
        this trip — a toiletry bag in the suitcase — never goes through the airport on its own, so it has no card here,
        nor an AirTag tick: one quiet line under the cards names it (“No tags inside another bag: …”). Which bag it is in
        is what the trip's list says (grouped by Into — "sorted" until 0.101); take it out — its Usually packed in set to No bag — and its card
        is back."
     5. **Photos** — "One photo of all your bags side by side, and each bag's own photo (the same ones as in Bags) —
        for the airline desk if a bag goes missing. With one bag, its own photo is enough. The photo of all of them
        stays in Bags after you leave. Green when every photo is there."
     6. **Ready** — "Every station, done or what is left — tap one to open it — and Ready to go once all are green. I
        leave at is right there: 15 minutes before, the iPhone names what is still unticked." Since 0.81 then: "Add a
        reminder, at the foot: anything last-minute, written as a To do on the trip — it shows in Before you go."
   - four dotted lines since 0.81 (three before; as a topic's, Pack green): getting around ("tap a station in the row to open it — Pack goes
     straight to the list and lights the first thing not packed yet a moment, wherever you are on it" — the words after
     "list" since 0.101. At the foot of each station, Next offers the next one still to do; in the sheet the
     stations are at the top too. Done closes it."); a trip with no bags yet ("those four stations are faded with a
     dashed edge and say “no bags yet”; opened, they say how to give things a bag … Ready then waits only for the
     packing."); (0.81) a To do written here ("A To do written here (Remind me, Add a reminder) is a line of the trip's
     own, under To do: due at once, so it is in Before you go at the top of the trip straight away — tick it there or
     on the list. Like every reminder it counts on the list: Pack waits for it."); afterwards ("Once the trip sets off,
     the row is gone — the weights and photos stay in Bags. A trip you share, or start again from this one, begins its
     stations afresh." — "its Packing day afresh" until 0.81).
   Spec 07 part 17 holds every rule behind these words.

**The topics and their lines** (summarised; the code holds the exact sentences):

0. **Home** (Home mark): (1) eight grab lists, four in a row; tap one, tick what is in your hand; (0.85, replacing
   0.84's grouping by Kind of thing) HIS OWN small grey headings group it: in Edit, holding a thing (right-click on the
   Mac) → Heading above puts one right above it, ready to name (unnamed, dropped on Save), A new heading + Add puts
   one last, its grip ≡ (on the Mac ▲▼ too) moves it, a thing belongs to the heading above it, tap a heading's name to change
   it, ✕ removes it and its things stay, joining what is above; headings are never ticked or counted; a list without
   them stays one plain list; (0.87) beside each heading a small ring fills as its things are ticked, and once everything
   under it is in hand (a thing left behind with ⊘ counts too) the heading turns green with a check and folds to that
   one line ("so you scroll less at the door"), a tap on a folded heading opens it again, a thing unticked under it
   keeps it open until everything is in hand again, Start over opens them all; the count stays at
   the top; Ready to go too early says Not yet in the middle with what is missing; ticks clear themselves 6 hours after
   the last tap (0.62). (2) Grab Lists: the ones on Home
   (up to eight) in order, and the waiting ones; make a new one at the bottom; tapping a waiting one opens it, On Home puts it on
   Home — when full, you pick which one steps back; Make refuses a name already in use (0.62). (3) The countdown to the next trip under the grab lists; tap
   opens the trip. (4) Create new trip: name, then Full trip or Quick (Quick = only the ticked templates, not the Always
   packed templates and no Plane or RV template, picking Plane still turns on the airport checks — the line under it
   names the Always packed templates, 0.78; 0.76 said "no common base or plane or RV template"); the dates in the calendar that is always open (first day,
   last day, set at once; the line under it says range and nights; Clear dates leaves none; no day tapped = no
   dates; Trip settings has the field with OK and Cancel) (0.67). (5) Create trip is always ready; what is missing is said under it.
   (6) So is every Add, New, Make, Weather: empty press adds nothing and a short red line says what is missing,
   gone as soon as you type. (7) (0.76) Travelling by: Plane or RV with their drawings, both off for an ordinary
   trip, one at a time, the lit one tapped off again; the line under them says what each adds (the airport checks,
   the RV template by its name). (8) (0.76) More choices folds Season, Food and Laundry away with one line of what is
   picked, a tap opens it; (0.78) Summer and Winter carry the sun and the snowflake, as Plane and RV carry theirs;
   Food is Self-sufficient, Eating out or Mix; Season follows the dates (November to March Winter, otherwise Summer) until picked by
   hand; the device remembers open or closed. (9) Pick templates, Travelling by and More choices; (0.91) a template given a colour shows it on its pill — filled once
   picked, outlined until then, the others violet once picked; workout colours (Swim blue, Bike yellow,
   Run green, Strength orange, Breath work lavender, Mobility pink) until one is given a colour of its own; each picked workout its own Context line
   (Indoor, Outdoor, Race) set in under them — Run outdoors and Swim indoors on one trip (0.67); templates without an activity area come last, under Other Templates (0.62; his casing 0.78). (10) Laundry: per-night things count only the nights before a wash — 4 unless 3, 5, 7, 10 or 14; shown as
   ×4 · laundry with a washtub. (11) This Device: how many trips, things and templates.
1. **Packing a trip** (Trips mark): tap to tick / untick; the round button ticks a section; (0.82, spec 07 part 20)
   "Green as you go" — the ring beside each heading's count, the green check and green heading when it is done, the
   round button unchanged — and "Under the trip's count" — "23 left · 2 to charge · about 25 min", All packed, the time
   from his own pace (the middle time between ticks over his last packings, a pause over 10 minutes a break, 45 s a
   thing until 20 are measured); Before you go
   (0.77: one card, one count of what is left, red / orange / green All set — folded to one line, its arrow opens it;
   0.101: its arrow folds it to one line whenever he likes, and this device remembers that per trip;
   its parts: the checks — cabin red/orange, a battery in a checked bag red (0.76), expiry six months ahead for
   passports/IDs; To do — the reminders due, each with its template's icon, a tap ticks — and (0.101, spec 07 part 21) a
   thing's own reminders due, as "Camera: Empty the SD card", the same tick as under its line; To charge from the day before
   the trip, with "1 of 2", a charge tick apart from packing — and (0.87) "Charge tonight" on the iPhone at 20:00 the
   evening before, the names not charged yet, four then how many more, only while something is left, a tap opens
   the trip at To charge); the pen opens Trip settings (every field it holds, Plane or RV and Pack weather gear anyway included, nothing folded, new dates leaving the season as it is — 0.76;
   Save rebuilds, own ticks/additions/what was sent stay; a swipe down closes it only when nothing is changed — 0.62); Start a new trip from this one, and last Clear every tick (asks first; 0.79 — Tick everything gone); the round button's Undo for 6 seconds above the add bar (0.79); Save as
   Excel and Share side by side; folding sections (remembered per trip; 0.101: the two-arrow button beside Group by
   folds every section at once and, all folded, opens them all; on the Mac Option-click on a section's arrow too); ⊘ not this time (any tick goes — 0.62), ↻ back unticked; (0.101, spec 07 part 21) two lines after the reminder's: a thing's
   own reminders — "2 left" in orange on its line, under it once ticked "Before it goes: …" each with its own tick, in
   Before you go's To do at their step as "Camera: …", one tick wherever ticked — and a line "with Camera" that came along
   with another thing (its own bag and place; goes when the camera goes unless a template, another thing or he himself
   put it there, a packed one stays; ⊘ on the camera sets it aside too, ↻ brings it back); Group by ("Sorting" until 0.101; "puts the lines under headings") When /
   Into / From where / Category; Weather line with + and Add all; tap a bag for Goes in the cabin; Bags fill
   colours and the scale reading, Clear, up to three photos, "Tap to weigh" on a bag with nothing weighed (0.62); (0.83) + Add a bag at its foot, as in Bags out, "nothing in it yet" and its ✕ for a bag added empty; Set place under "No place set"; (0.69) opened from a place's label, only what is kept there — the place's name
   under Group by shows every line again; typing a thing adds it
   to this trip only, Bought on site adds it ticked; Delete trip at the very end asks first (things and
   templates stay); a trip someone sent arrives Quick, and sharing sends just the list (0.62); (0.77) Take a break —
   since 0.84 "the round cup" — at the end of the count's line while packing — how far you have come (41 of 63, your
   list's groups under Group by ✓ or N left, To charge, To do), Continue when? In an hour / This evening 19:00 / Tomorrow 18:00 or
   your time / Just pause, the iPhone's "🎒 Back to packing" (the backpack since 0.84) and since 0.84 "the cup shows
   when, small beside it (19:00; on another day, Fri 18:00)" (the button's "Back at 19:00" until then), Add to
   Calendar "— filled once a time is chosen —" (0.84) (nothing added until you say), one break per trip, gone when
   the last thing is ticked, from the Mac your iPhone reminds you. (25 lines.)
2. **Pack by voice (iPhone, a test)** (Trips mark, 0.71 — spec 07 part 10): the button at the end of a trip's
   Group by row (Sorting until 0.101) walks what is still to pack, place by place as From where groups them — the place, then the thing
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
   dated onto the thing); Pack to go home with its own ticks; Used up / Undo; search with ✕ (Tick everything until 0.79);
   notes and Open on the way home; the packed-bag photos at the top, Next steps through them. (10 lines.)
4. **After a trip** (Trips mark): Review (since 0.84 its first line says where: "the violet button beside Done at the
   top of a trip, there once the trip has started — On site, or after it (a trip with no dates has it all along)";
   then tap unused, type missed, pick its template, Add, Save); the loop strip
   under a trip's name (Plan · Pack · On site · Review · Refine) with the step's own mark — a map, a suitcase with
   a tick, a pin on a map, a magnifier, a sprout (0.77; the tab's mark until then) — and (0.101) "As in the Stations
   row: a step done is in full colour, the one you are on is lightly shaded with a stronger ring, the steps ahead are
   outlined." (until 0.101 "the step it is at filled in"); nothing is removed — "Didn't
   use" adds to history, missed things go onto a template. (4 lines.)
5. **Trips** (Trips mark): Now, Coming up and Done — Now always there; Planned / Packing / Ready; reviewed trips fold
   away; Your year; All your trips with the map; the pin opens Where you have been (pins with counts, line oldest
   first, card per place; a trip joins as soon as it has a place). (3 lines.)
6. **Your templates** (Templates mark): templates are the building blocks, in activity areas (GA, WET…); the areas are
   his — the Activity areas pill, at the foot of the tab after the last area (0.91; under the Refine card until then): + Add (a name only), pen, grip ≡ (Mac arrows), Remove (asks; one holding templates
   stays and says which; Workout, Exercise & Training always stays), nothing until Save, both devices the same (0.89); each has
   an icon (the one its name suggests — a beach template gets the lounger under its parasol — or one of 132 drawn ones under six headings, or Letter; 50 until 0.74, 91 until 0.92, whose 41 close each heading so the ones he knows keep their places; 0.91: Find an icon finds one by its name or other words for it in English, Swedish or German — flyg, cykel, Fahrrad — the ✕ shows all, ⌘F on the Mac); + New asks the activity area; rename, ✕ takes a thing off (asks; the thing
   stays), (0.90) a colour of his — Automatic or "one of seventeen, in two rows" (fifteen until 0.101, when "then Red, Plum,
   Violet, Indigo, Navy, Light blue, Olive, Light yellow, Sand, Brown and Grey — on the pale ones the icon is drawn dark, so
   it reads" came in), How many and Section per template, a blank How many or Note = "the same as the thing" (0.62); Find a thing on this template ("3 of 40", ✕, adding clears it);
   Choose from your things (in the order ticked) or type a new one (one already there is not added twice — 0.62);
   folding in the picker (Fold all / Unfold all, counts, search opens
   all); Group: sections, When, Into, From where, Kind, A–Z; Activity area is a drop-down above Delete template — Always packed, his areas, No activity area, a new area at
   its foot; a template moved out of WET loses its own Context (0.89; a door beside Delete since 0.62); Delete template asks first; Arrange — drag headings and things, rename or remove a heading (0.63); Share at the top (a grab
   list's at its bottom right, round, under Ready to go — 0.84); Refine (violet card) after two or more reviews — Keep / Drop. (17 lines since 0.89, counted from the code.)
7. **Care** (Care mark): Your things (changes reach trips ahead on unticked lines; a name he has is not added
   again — 0.62); (0.101, spec 07 part 21) a thing's page order now Name, Notes, Photos, Remember with it, Goes with,
   Kind of thing…, and a line of its own on the two: reminders with a When (Add, tap to change words or When or remove,
   the grip ≡ / the Mac's arrows), Goes with's Add a thing and ✕, nothing changed until Save; Just added at the top until you
   leave; ✕ in search; (0.69) the search finds words in a thing's notes and its templates' notes, the matching line
   under the thing; On a plane and Valid until (+1 month … +10 years, red once run out); the rest of a thing's page — its templates'
   notes under Notes, places to tap under Kept at home, No bag, Care how often and what to do (0.62); Bags with max weight,
   litres, empty weight and their own page; All your things · table (sort, filter, columns, Change all — the line says what changed, Undo puts
   back just that, the bar counts ticked things out of sight — 0.62;
   own window on the Mac); Filter by every column (pills, Clear); Sort up to three levels (blank last); the arrow
   opens the thing and returns to the same spot; Services List or Calendar (Done today, Today); the numbers under
   the services; the bag page's saving line — (0.98, the Apple way) "Everything you change on a bag’s page — its
   numbers, Notes, the desk’s words and pills, the switches, a new name and its pockets — is kept as you go and saved
   only when you leave the page with Done (⌘S on the Mac); Duplicate and Its details save it first. So typing, moving
   to the next field and scrolling never wait. Switch to another app and back and the page is still open with all of
   it; close the app (swipe it away) or quit it and nothing you did not confirm with Done is kept." (0.94 to 0.97 it
   said the app going to the background saved it, and that a glance at Control Center saved nothing); its Cancel line
   (0.98) "… nothing you changed there is kept, the pockets included." (until 0.98 "the pockets go back as they were
   too"). (19 lines.)
8. **To do** (To-do mark): To do (0.101: Priority at the top — "!" when adding, or held / right-clicked Mark as
   priority; a ticked to-do goes into Done at the foot, folded until tapped, Undo under the list; To buy the same with
   Bought); (0.101, the second line) "The To do tab wears a small red badge: how many to-dos
   and to-buys are still open, together — no badge when there are none. VoiceOver says the two counts; on the Mac,
   rest the pointer on the tab to see them (3 to do · 2 to buy)."; To buy with worn-out or run-down suggestions, Undo after a removal (0.62); Send to Reminders into the list
   "To buy · Packing", each once, dated, all day, ticks read back; ticks and removals here follow there, and a reminder deleted there can be sent again
   (0.62). (4 lines since 0.101.)
9. **Settings** (Settings mark): Remind me to pack (9 in the morning, per device, next reminder shown; says in red when the iPhone does not allow
   notifications, switch on or off, and where to allow them — 0.62); (0.77) Messages when a trip moves on (iPhone, on
   until switched off: Have a good trip when it sets off, else at 8; Welcome home at 10 the morning after, tap → the
   review; (0.87) the same switch holds Charge tonight, at 20:00 the evening before, while something is still to
   charge; nothing without lines or dates, or once reviewed); (0.92) Show my things in Spotlight (on unless switched
   off, per device: a thing's name in Spotlight shows where it is — packed in which bag and pocket on a trip under way,
   else where it usually goes and is kept at home — with its photo; a tap opens its page; found by kind, owner,
   templates and brand, never its notes; nothing while the iPhone is locked; off takes them out at once); iCloud sync
   (times, what is not in iCloud, Sync now, Copy details for Claude, "Can't tell" explained — 0.62; since 0.101 first
   "at its top right the same dot as on Home, and its words in that colour — green In sync, orange while changes are on
   their way, red Stuck", and "With iCloud on, each device checks in by itself every quarter of an hour while it is
   open, so the card says when each was last there; Sync now checks in from here at once"); Save a backup / restore (a copy is kept
   first; when the last backup was saved, where the library came from — 0.62); Your first real trip door; Your choices (places, owners, packers, conditions, When steps; the pen renames, the arrows move, the grip drags (0.70), owners stay A–Z,
   no duplicates, the reason for a refused remove right under it, Owners from his things when he has no list — 0.62);
   (0.69) each storage place's square code and its label for the P-touch, 12 mm tape (iPhone: Share → Save Image, and
   Brother's app takes it from Photos; Mac: saved as a picture), all places at once; the Camera on a label opens the
   trip being packed on that place, what goes back after a trip, or everything kept there — Open on the place's page
   shows the same on the Mac; Worth a look
   (only when something seems wrong; one-press fix such as Remove it; an undated photo nothing shows goes only on Remove — 0.62); Open a shared link (trip arrives unticked,
   template links to existing things — with a name he has, a name of its own or Replace (0.62) —, grab list takes a free Home place or waits);
   (0.90, the sixth line, after the first-real-trip door) How it works' own search — "How it works has a search field
   at its top: type a word and only what says it shows — each paragraph under its part, with the word marked, and at
   the top how many places say it (“4 places”). Capitals and accents do not count; a part whose heading alone says it
   shows whole. The ✕ brings the whole guide back, where you were reading. On the Mac ⌘F puts the cursor in the
   field, and Escape empties it." (11 lines; 10 until 0.90.)
10. **Shortcuts and the Action button** (Home mark): three actions (Choose a grab list, Open a grab list, Open my next
   trip); the Action-button path (iPhone Settings → Action Button → Shortcut → Packing → Choose a grab list); if
   Packing is missing, open it once; Home Screen or Siri ("Open Swim in Packing"); (0.86) hold the Packing icon on
   the Home Screen for the four grab lists opened most recently — on the Mac, right-click its Dock icon for all of
   them. (5 lines.)
11. **iPhone and Mac** (Settings mark): both hold the same library through iCloud, a change arrives within a minute or
    so; the magnifier searches everything (a thing's notes too — 0.69); every page's Cancel and Save/Done and the swipe
    that asks (0.92) — and (0.98, the Apple way, replacing 0.94's "Put the app away with a template, Your choices or a
    bag open and what you changed there is kept; back in the app, Cancel puts back only what you change after that.")
    "Switch to another app and back with a page open and it is still open, with what you changed; close the app (swipe
    it away) or quit it and what you did not confirm with Save or Done is not kept — as in Calendar or Contacts."
    (§20a); (0.93) "Save keeps only
    what you changed on that page — a change made on the other device while it was open stays" — (0.95) ", and so does
    what it added to the same list (a section, a kind of thing, a grab list’s things)" — (0.98) "; Cancel never touches
    what the other device changed." (0.95 to 0.97: "Cancel on a bag takes back only what you changed there.") — (0.102,
    warn instead of merge, §20c) "If the other device changed the same grab list, template (its name, look or sections),
    kit or list of Your choices while your page was open, Save or Done asks first — “Changed on your iPhone meanwhile”:
    Keep both keeps what each device added and took off, Keep mine keeps your page as it is. If its change arrives only
    after yours was saved and takes its place, a small note names what was changed there — open it to check." — (0.93) "If a change cannot be
    saved, a small note says “Couldn't save that — try again.” The screen then shows what is kept; just do it again"
    — (0.94) "— a bag, a template or Your choices stays open with what you changed, so Done again saves it." (§20b); on the Mac Escape closes a window as its Cancel or Done does, never saving
    (0.62); (0.103) the last line now also says "⌘S is Save (or Done) on every page, even one that only shows
    something, like a trip. ⌘1 to ⌘6 change tabs. The All your things window closes with Done or ⌘W. Every key is on
    its own card under Keyboard shortcuts, the last part of this guide." (5 lines.)
12. **Keyboard shortcuts** (0.103; not one of the `topics` — a part of its own, `KeysGuide`, §7b): every key the app
    answers, as cards of key caps.

**Tests.** `testWhatsNewStartsWithThisVersion` (topics 0 and 1 exist), `testTheLoopShowsWhereATripStands` (loop
card, first-trip card, Words), (0.79) `testHowItWorksExplainsThePackingDayStations` (the Packing day part is there;
its six stations in order, "1 · " … "6 · ", each wearing its own mark — the label of `guide-day-<key>-mark` is his
pick's — the first five saying what turns them green, Weigh that it opens by itself, Tags the bag's Has an AirTag;
pictures `day-howitworks-1`/`-2`, day and night; seen red with the card left out: "How it works has no Packing day
part"); (0.90) `testHowItWorksSearchShowsOnlyWhatSaysTheWords` (§7a); (0.103) `testHowItWorksHasAKeyboardShortcutsTopic`
and model `KeyGuideTests` (§7b). **Not covered:** the number of topics, their order, their text.

### 7a. Search in How it works (0.90; `HowItWorksScreen`, `GuideSearchResults`, `GuideHitCard`, `GuideMarks` in `Guide/GuideScreen.swift`; the matching in `Core/Sources/PackingLibrary/GuideSearch.swift`)

**Origin.** His ask of 19 Oct 2026: "Search function in How-it-works. There is a lot of information in how it works,
and I really like that. Keep up the good work in making it extensive. The search function will make it even better."
(Spec 07 §11, decision log.)

**The field.** Right under the header (`GuideHeader`, padding 16; the field 4 pt up into that padding, 12 above the
guide): the app's search-field look — a plain `TextField` "Search How it works" (Body, ink), `Metrics.compact` tall
(32 iPhone / 24 Mac), 12 in from its edges, `Theme.card` with a 1-pt `Theme.line` ring, radius 10, 16 from the
sheet's sides — and the shared ✕ (`clearButton`, §20): there only while something is typed, one tap empties the field
and the keyboard stays. Field id `guide-search`, its ✕ `guide-search-clear`. The app puts no cursor there when How it
works opens (on the iPhone a keyboard would cover the guide he came to read; the Mac may give a sheet's first field
the focus by itself). **On the Mac:** ⌘F puts the cursor in the
field (a zero-opacity button behind it holds the shortcut, hidden from VoiceOver); Escape — which a text field keeps
for itself, so `GuideHeader`'s Done (`.cancelAction`) never hears it — empties the field when something is typed and
closes How it works, as Done does, when nothing is (`.onExitCommand`).

**When it searches.** As soon as the field holds anything but spaces (`GuideSearch.needle` not empty), on every key
press. Spaces alone are no search: the whole guide shows.

**What is searched** (`HowItWorksScreen.parts`, one `GuidePart` per card, in the guide's order, read from the same
statics the cards draw — so the search can never miss a sentence the guide has; a new card in How it works joins this
list):
1. `quickstart` — "Your first real trip in 6 steps" (`FirstTripCard.title`): its six steps, each "<n> · <title> —
   <words>" (lead "<n> · <title>").
2. `loop` — "The loop" (`LoopGuideCard.title`): its first line (`LoopGuideCard.intro`), the five steps "<name> —
   <sentence>" (`LoopStep.explained`) and the bold line (`LoopWords.footer`). **Not** the picture: its boxes repeat the
   steps' words.
3. `words` — "Words" (`WordsCard.title`): every entry "<term> — <meaning>". **The Words list IS searched** — it is a
   part of How it works, and a word he wonders about is the likeliest thing to look up.
4. `topic-<n>` — each topic, its title and its lines (n = the topic's own number, as `guide-topic-<n>`), and, right
   after `Packing a trip` (`HowItWorksScreen.stationsAfter`), `stations` — "Packing Stations"
   (`PackingDayGuideCard.title`): its first paragraph (`.intro`), the six stations "<n> · <name> — <words>"
   (`PackingDayGuideCard.says`; not the drawn marks' descriptions), its four closing lines (`.more`).

5. (0.103) `keys` — "Keyboard shortcuts" (`KeyGuide.title`), the last part: the line at the top, each card's heading
   with where its keys work (and its line), and each row "<action> — <keys in words> (<keys as symbols>). <note>
   <card>." (`KeyGuide.paragraphs`, in the model): "Save, or Done — Command S (⌘S). On any page." — so the key names, the
   symbols he sees in a menu and the action words all find it.

`Loop.swift` and `PackingDay.swift` gave up their inline sentences for these statics in 0.90 (the cards draw the same
words); `Words.swift` gained `WordsCard.title`, `FirstTripCard` its `title`.

**How words match** (`GuideSearch`, model-tested): as the app's other searches — `normName` (trimmed, lower case, runs
of spaces as one) and the words are ONE phrase ("bag weight" finds "bag weight", not "bag … weight"); and, the guide
being prose he did not type, also **accents** (`cafe` finds `café`) and the **curly and straight quotes** (‘ ’ ‛ ′ as
', “ ” „ ″ as "): "trip's" typed on the Mac finds "trip’s", and the iPhone's curly ’ finds a straight one.
Case-insensitive and diacritic-insensitive `range(of:)` over the text with its quotes straightened — each a one-UTF-16-
unit swap, so a place found there is at the same offset in the words as written.

**What shows** (`GuideSearch.find`): each part the words are in, in the guide's order, under its own heading — with
only its paragraphs that hold them, in order; **a part whose heading alone holds them shows whole** (it is about them:
"iPhone and Mac" shows that part, though no paragraph says the phrase). A part whose heading and some paragraphs hold
them shows just those paragraphs. Every other card is gone.

**On screen while searching** (`GuideSearchResults`, container `guide-search-results`, in a `KeyboardAwayScroll`, a
`LazyVStack(spacing: 12)` — one letter can find most of the guide, and only the cards in sight are built, so the next
key press is not kept waiting; 16 from the sides, 24 at the foot, `Theme.bg`):
- **The count line** (`guide-search-count`, Subheadline semibold, monospaced digits, muted): "1 place" / "<n> places"
  — the places the words are in: each paragraph holding them (twice in one paragraph is one place) and each heading
  holding them.
- **A card per part** (`GuideHitCard`, container `guide-hit-<key>`; padding 14, radius 12, the card's look as in the
  guide: the first trip's Home blue at 8 % with a 1.2-pt Home-blue ring, the stations' `Theme.card` with a 1.2-pt Pack
  green ring at 70 %, every other `Theme.card` with the 1-pt hairline): the heading as the guide shows it — the topic's
  `SectionMark` (24, 1.9) in its colour, the Words' "Aa" in slate, the stations' sun-out-of-a-case mark in the Pack
  step's readable green; the first trip and the loop wear none, as in the guide — then the title (Body semibold,
  ink; id `guide-hit-<key>-title`); then each paragraph after a 6-pt dot in the card's colour (a topic's section
  colour; first trip Home blue; loop Templates violet; Words Settings slate; stations Pack green): the text in
  Callout ink, its lead (a step's, a word's, a station's name) semibold; id `guide-hit-<key>-<n>`, n = the paragraph's
  place in its part (the first trip's steps 0–5; the loop's first line 0, steps 1–5, bold line 6; Words' entries as
  `word-<n>`; the stations' first paragraph 0, stations 1–6, closing lines 7–10; a topic's lines as in the code).
- **The words marked** (`GuideMarks`): every place, in the heading and the paragraphs, semibold, in How it works' own
  colour — its title's Settings slate — on a band of the same slate at 16 %, as a found note's line marks them in
  Search (`NoteHitLine`). **At night** the word keeps the text's own colour (ink) on a stronger band, slate at 55 %:
  slate words on the dark card read dimmer than the words around them, which is no mark (seen on the first night
  picture, 19 Oct 2026). Each heading and paragraph's accessibility value says how many places in it are marked
  ("1 place marked", "2 places marked") — what VoiceOver hears after the words, and what the test reads.
- **Nothing found** (`guide-search-none`): one calm line, "Nothing in How it works says that." (Callout, muted) —
  as a template's search says "Nothing on this template is called that.". No count line.

**Back to the whole guide.** The guide stays built under the search, only out of sight (`opacity` 0, no hit testing,
hidden from VoiceOver — so a test, or VoiceOver, finds no `guide-topic-<n>` while searching): the ✕ (or emptying the
field by hand) gives it back **exactly as it was, scrolled to where he was reading**. (How it works has no folds.)
Leaving How it works and opening it again starts with an empty field, at the top.

**Tests.** Model `GuideSearchTests` (5, `Core/Tests/PackingLibraryTests/GuideSearchTests.swift`, invented parts):
only the paragraphs holding the words, each under its part, in order, and "2 places"; a heading alone shows its whole
part ("1 place"), heading and paragraph show just the paragraph (2 places); case, spaces, accents and curly or straight
' and " do not count; every place marked, none overlapping ("aaaa"/"aa" → two), at the right offset after a curly
quote; spaces alone or nothing found → nothing. Each seen red with its fault planted: quotes not straightened —
`XCTAssertEqual failed: ("["don\'t"]") is not equal to ("["Don’t", "don\'t"]") - a straight ' finds the curly one
too`; accents counted — `("[]") is not equal to ("["café"]") - accents do not count`; a heading alone showing nothing
more — `… paragraphs: [], places: 1)]") is not equal to (… paragraphs: [0, 1], places: 1)]") - only the heading says
it: the part is about it, so all of it shows`; every paragraph of a found part shown — `("[0, 1, 2]") is not equal to
("[1]") - Care: only the kit paragraph says "the"`.
UI `testHowItWorksSearchShowsOnlyWhatSaysTheWords` (iPhone and Mac): the guide read on a little (two swipes; the
second topic's place noted); "siri" typed → "2 places", the paragraphs `guide-hit-topic-1-7` (Packing a trip,
Where is my …?) and `guide-hit-topic-11-3` (Shortcuts and the Action button), each under its heading, each saying
Siri with "1 place marked"; no `guide-hit-topic-1-0`, no Words part, no `guide-topic-1` (the guide out of sight);
"qxzqxz" → the nothing line, no count, no part; the ✕ → the search gone, the field empty, the second topic back within
4 points of where it was. On the Mac then ⌘F + "siri" → "2 places"; Escape empties it and How it works stays; a
second Escape closes it. Pictures `guide-search-0-before`, `-1-found`, `-2-none`, day and night. Seen red with each
fault planted: no marks — `XCTAssertEqual failed: ("0") is not equal to ("1") - Siri is not marked in paragraph 7 of
topic-1: 'Where is my …? …'`; every paragraph of a found part — `XCTAssertFalse failed - a paragraph that does not say
it shows`; the guide built again after the search (`if !searching`) — `XCTAssertEqualWithAccuracy failed:
("7973.166666666667") is not equal to ("6611.166666666667") +/- ("4.0") - the guide came back somewhere else, not where
it was`; no nothing line — `XCTAssertTrue failed - nothing found, and nothing says so`; the guide left in VoiceOver's
reach under the search — `XCTAssertNil failed: ""guide-topic-1" Other" - the whole guide still shows under the
search`.

### 7b. Keyboard shortcuts in How it works (0.103; `KeysGuide`/`KeyCap` in `Guide/KeysGuide.swift`; the words in `Core/Sources/PackingLibrary/KeyGuide.swift`)

**Origin.** His ask of 27 Oct 2026, with the shortcuts themselves ("103 - make the list visually pleasing and easy to
read for a human"): a topic **Keyboard shortcuts** in Settings → How it works, written from the code — every
`keyboardShortcut`, the thing page's key walk (`ThingKeys`), the drop-downs' keys (`DropDown`), How it works' and the icon
picker's ⌘F, the grab-list and Arrange keys, ⌘Q, the new Go menu. On the Mac it is also Help ▸ Keyboard Shortcuts (§20a).

**What the model says** (`KeyGuide`, tested by `KeyGuideTests`): `intro` — "These are the Mac’s keys, most of them also
in its menu bar. On an iPhone or iPad with a keyboard attached, the same keys work where a card says so." — and
`cards`, each `Card(id, title, reach, line, rows)`; `reach` is `.withKeyboard` ("Mac, and iPhone or iPad with a
keyboard") or `.macOnly` ("Mac only"); a `Row(action, chords, note)` has one chord or several ways ("Space or ↓"), a
chord being `Key`s pressed together; a `Key` has its cap ("⌘", "S", "Esc", "A–Z") and its spoken name ("Command", "S",
"Escape", "letters"). The seven cards, in order, with their rows:

| # | Card (id) | Reach | Rows (keys) |
|---|---|---|---|
| 0 | On any page (`any`) | Mac + keyboard | Save, or Done (⌘S; "On the Mac also on a page that only shows something — a trip, How it works, Search — where it closes the page.") · Cancel, or close the page (Esc or ⌘.; "Esc never saves anything. ⌘. is Esc on an iPhone.") · Add what you typed in an Add field (Return) |
| 1 | Go to (`go`) | Mac | Home ⌘1 · Trips ⌘2 · Templates ⌘3 · Care ⌘4 · To do ⌘5 · Settings ⌘6 or ⌘, — "The Mac’s Go menu. Switched off while a page is open: finish it with ⌘S or Esc first." |
| 2 | Search (`search`) | Mac | Search How it works (⌘F) · Find an icon, on a template’s icon page (⌘F) · Empty the search (Esc; "A second Esc closes the page.") |
| 3 | Editing a list or a page (`edit`) | Mac + keyboard | Save a grab list, a template, your lists or an activity area (⌘S) · Throw away what you changed (Esc; a grab list stays open, a template being arranged ends Arrange first) |
| 4 | A thing’s page (`thing`) | Mac | Save the thing ⌘S · Save, and start the next thing with the same choices ⌘N · Next thing in the list the page came from ⌘↓ · Previous thing ⌘↑ · Jump to a field by its name ⌘J · Next field Tab · Previous field ⇧Tab · Save from any field but Notes Return — "Also the Thing menu. Tab walks every field, top to bottom." |
| 5 | Lists and drop-downs (`lists`) | Mac | Open a drop-down (Space or ↓) · Move through its choices (↑ ↓) · Jump to a choice by typing (A–Z) · Choose the lit one (Return) · Close the list, and stay on the page (Esc) · Move along a row of pills (← →) · Switch the lit pill, or a switch (Space) — "On a thing’s page, with the field lit." |
| 6 | The Mac’s windows (`mac`) | Mac | Quit ⌘Q ("Asks first when a page holds a change you have not confirmed.") · New window ⌘N ("Not while a thing’s page is open: there ⌘N is Save and New.") · Close the All your things window ⌘W |

**On screen.** Last in the guide's `VStack(spacing: 12)`, after the twelve topics; every card padding 14, `Theme.card`,
radius 12, 1-pt `Theme.line`. First a **heading card** (id `guide-keys`): the `command` symbol (SF Symbol, 24, slate)
and "Keyboard shortcuts" (Body semibold, id `guide-keys-title`), the intro under it (Callout ink). Then one **card per
kind of key** (id `guide-keys-card-<n>`): its title (Body semibold, a heading for VoiceOver), under it where its keys work
(Footnote muted), its line if it has one (Footnote muted), then the rows with a 1-pt hairline between.
A **row** (id `guide-keys-<card>-<row>`): the action (Callout ink) with its note under it (Footnote muted) on the left, the
keys on the right as **key caps** (`KeyCap`): the key's name (Callout semibold ink — Apple's text styles, no small type), a
face in `Theme.bg` with a 1-pt `Theme.faint` ring at 55 % and a firmer edge 2 points under it, corner radius 7, at least
`Metrics.compact` (32 iPhone / 24 Mac) square, 7 points in from the name; several chords are separated by a muted "or";
a chord's caps are 3 points apart. The row keeps its action and its caps on one line and lets the action wrap; at the
accessibility text sizes the caps go under the action. Day and night are the app's tokens, nothing drawn in a fixed colour.
**VoiceOver** reads a row as one thing, one label (`KeyGuide.Row.voiceOver`): the action, then the keys in words — "Save, or
Done, Command S", "Cancel, or close the page, Escape, or Command period", "Settings, Command 6, or Command comma", "Previous
field, Shift Tab" — and the note as its hint; the caps themselves are not read, and the symbols never are. (First built as a
label and a separate value; the Mac's probe showed the value does not reach the Mac's accessibility tree, so the keys moved
into the label.) A card's title is a heading.

**Search.** `HowItWorksScreen.parts` ends with `keys` (kind `.keys`, slate dot, the `command` symbol before the heading in a
hit card); its paragraphs are `KeyGuide.paragraphs`, so the search finds the topic by a key's name (`command s`, `escape`,
`shift tab`, `down arrow`), by the symbol (`⌘s`, `⌘1`), by the action (`quit`, `jump`) and by the cards’ own words (`go menu`,
`keyboard attached`). Hits show as the search's text cards ("Save, or Done — Command S (⌘S). On any page."), marked as everywhere.

**From the Mac's Help menu.** Help ▸ Keyboard Shortcuts (`LibraryModel.keysToOpen`): the Settings tab, How it works open,
scrolled to the topic (`KeysGuide.scrollId`). Off while a page is open, like the Go menu.

**Tests.** Model `KeyGuideTests` (5): every key the app answers is in the topic with the right keys (a list written from the
code: the missing or wrong ones are named in one message); the Go card is the six tabs in the tab bar's order, ⌘1 to ⌘6;
VoiceOver's words ("Command S", "Shift Tab", "Command Down arrow", "Space, or Down arrow", "Escape, or Command period",
the row's one label "Save, or Done, Command S") and no symbol in any; the search finds the keys by name, symbol and action and the line at the top; the line says the Mac
first and then the iPhone and iPad, the seven cards in order. Seen red with faults planted (the Go card without Care; ⌘'s
spoken name the symbol): `("["go: no row for Care"]") is not equal to ("[]") - keys the app answers that the topic leaves
out or gets wrong`, `("Optional("⌘ S")") is not equal to ("Optional("Command S")")`. UI `testHowItWorksHasAKeyboardShortcutsTopic`
(iPhone and Mac): the topic is there, the heading card and seven cards, the rows' labels "Save, or Done, Command S", the Go
card's six rows `Home, Command 1` … `Settings, Command 6, or Command comma`, `Previous field, Shift Tab`; each card brought to the top for a picture
(`keys-0-top`, `keys-1-card` … `keys-7-card`, `keys-8-search`; day and night, iPhone and Mac); the search finds it for
`command s`, `jump to a field`, `shift tab` ("quit" is said in other parts too, and the lazy results would not have built the last card).

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
5. **Pack** — Group by (Sorting until 0.101): When, From where, Into; ⊘ is not this time; watch the bag bars and Before you go;
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
  long arrow up the left from Refine back to Plan. Drawn arrows (`LoopArrow`), gaps 30 pt. Each box: the step's own
  mark (0.77, `StepMark`, 17 pt, readable tint; spec 03, The loop) and "<n> · <name>"
  (18 heavy, the tint made readable — `readableHex`), a short line (14 medium ink): Plan "Make templates, create a
  trip", Pack "Tick things as they go in", On site "Bought, left, notes, and packing for home", Review "After it:
  unused, missed", Refine "Keep or drop, from reviews"; the tab mark (15 pt) and "on Home" / "on Trips" / "on
  Templates" (13 bold, tab colour). Background tint 12 % (24 % when "here"), border 1.2 (3 when "here"). Tint:
  Pack, On site, Review = Trips green; Plan, Refine = Templates violet. A key under it: "About your templates",
  "About one trip" (14 medium muted). Each box is one accessibility element (`children: .ignore`) with label
  "<name>: <short>, on <tab>" (+ ". You are here" when marked), id `loop-step-<0…4>`; its mark is an element of its
  own laid over the title from outside the box, id `loop-step-<n>-mark`, label = what it shows ("A map with a route to
  an X", "A suitcase with a tick", "A pin on a folded map", "A magnifier over a list", "A sprout"). In the guide nothing
  is "here".
- **The words** (`LoopWords`): five rows — the step name (16 heavy, readable tint, 72 wide) and its sentence (16 ink)
  — then in bold: "Review looks back at one trip. Refine uses several reviews to make your templates better."

**Searched** (0.90, §7a): the first line, the five steps' words and the bold line; not the picture.

**Tests.** `testTheLoopShowsWhereATripStands`: `guide-loop` exists, exactly five `loop-step-*`, step 0 label contains
"on Home", step 2 starts "On site" and contains "on Trips", step 4 contains "on Templates", each step's mark says
the mark he picked (0.77), no step says "You are here" in the guide. (The same test then checks the trip's strip and the full loop screen — owned by the loop chapter.)

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
| 1 | Template | Templates | A building block: the things for one activity or need — Hiking, Swim, RV. A trip is made from templates. The Templates tab. (Until 0.76 "…Hiking, Swim, Car.") |
| 2 | Activity area | Templates | The group a template lives in. Yours to make, rename, order and remove (Templates → Activity areas): the three the app starts with show their code (GA · Goal Activity, WET · Workout, Exercise & Training, OE · Other Events) until you rename them; your own show just your name. (His casing since 0.78; his own areas since 0.89.) ("Activity area", not "shelf": "We understand that word much better.") |
| 3 | List | Trips | The one list you pack from for a trip, made from its templates. (A grab list is a list too.) |
| 4 | Grab list | Home | A short list for a quick outing — Swim, Bike, Run — ticked as each thing is in your hand. Up to eight are on Home; the rest wait in Grab Lists. |
| 5 | Common base | Templates | The template that comes along on every trip: passport, phone charger and the like. |
| 6 | Transport kit | Templates | What Travelling by adds to a trip: your Plane or RV template. Both off is an ordinary trip. (Until 0.76 "What a way of travelling adds to a trip: the Car, Plane or RV things.") |
| 7 | Quick | Home | A trip with only the templates you tick — not your Always packed templates, no Plane or RV template. Picking Plane still turns on the airport checks. (0.78; until then "…no common base, no transport kit.") |
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
| 18 | Loop strip | Trips | The five steps under a trip's name, each with a mark of its own: a map with a route for Plan, a suitcase with a tick for Pack, a pin on a map for On site, a magnifier over a list for Review, a sprout for Refine. The filled one is where this trip stands, with its mark (on a wide screen every step has its mark). (Until 0.77: "with the mark of the tab where that step is done".) |
| 19 | Packing Stations | Trips | The stations of a trip’s Pack step, in a row under its loop strip: Bags out, Pack, Weigh, Tags, Photos, Ready. Each turns green when it is done; Ready to go when all are. The row itself says Stations, its chips the short words: Bags, Pack, Weigh, Tag, Photo, Ready. (Packing day until 0.81.) — "Packing day" until 0.81 (spec 07 part 17 "0.81"); the sentence on "Stations" and the chip words since 0.84 (part 17 "0.84"). |
| 20 | Review | Trips | Looking back at ONE trip: what you did not use, and what you missed. |
| 21 | Refine | Templates | Making your templates better from SEVERAL reviews: what a template carries for nothing. On the Templates tab. |
| 22 | Keep · Drop | Templates | In Refine. Keep: it stays on the template and is not asked about again. Drop: off that one template — the thing itself stays. |
| 23 | To do | To do | The tab for getting ready: things to sort out before you go, and — on its other side — To buy, with worn-out or run-down things suggested. |
| 24 | Your choices | Settings | Your own lists in Settings: storage places, owners, packers, conditions and the When steps. |
| 25 | Care | Care | Looking after your things: services that fall due, weights, bags. The Care tab. |

**Searched** (0.90, §7a): every entry, "<term> — <meaning>", in How it works' search — decided so: the Words are a
part of How it works, and a word he wonders about is the likeliest thing to look up.

**Tests.** `testTheLoopShowsWhereATripStands` requires `guide-words` and a `word-<n>` reading exactly "Kit"
(searched among 0…29). **Not covered:** the other 25 terms.

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
the light card and the dark one alike". Template pills he gave a colour (0.91): his colour and its ink
(`Library.pillColour`, spec 04 §3a), ahead of the workout colour. Workout pills (`WorkoutTone.of(name)`, matched on `normName` with all white
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
settings — since 0.73 in a ring, `RoundIconLabel`), `ShareMark` (a box with an arrow up), `VaultMark` (0.73, a stone:
`M12 3L18.5 8.5L15.5 20.5H8.5L5.5 8.5ZM5.5 8.5L12 12L18.5 8.5M12 12V20.5`, line 1.8, Send to Obsidian — never the
vault app's logo), `ClearMark` (a muted disc with `M8.5 8.5L15.5 15.5M15.5 8.5L8.5 15.5`
cut out in card colour, line 2.2), the six section marks, 50 template icons (`TemplateIcons`, one stroke, round
ends, 24-point box, only the commands SVGPath draws), the five loop-step marks (0.77, `StepMark` drawing
`Library.LoopStep.mark` through `IconMark`, line 1.9 — spec 03, The loop). Strokes are round-capped and round-joined, usually 1.8–2.4.
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

**The pictures under the app icon** (0.86, spec 02 §13b). The iPhone's Home Screen entries can only wear a picture
from the app's asset catalog (or an SF Symbol), so the grab lists' own drawings are written there once as template
PDFs — `Assets.xcassets/GrabIcons`: the six doodles, a list's initial (A–Z, Å Ä Ö Ü, 0–9) and the Home tab's suitcase
— by `tools/grab-icons.sh` from GrabDoodle's path data and `SVGPath` (§30). No SF Symbol there either.

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

**`WideButtonLabel(title:, tint:, mark:)`** — the wide outlined buttons at the foot of a trip (Save as Excel, Share;
since 0.73 Send to Obsidian on a reviewed trip, under them): a 22×22 drawn mark and the word (17 bold, scales to
80 %), tint colour, full width, min height 48, 8 % tint fill, 1.4-pt tint border, radius 12.

**`RoundIconLabel(tint:, mark:)`** (0.73) — a button that is ONLY a drawn mark and must still read as a button: a
circle `Metrics.tap` across (36 on the iPhone, 26 on the Mac), the tint at 10 % inside a 1.4-pt ring of the tint —
the outlined `HeaderButtonStyle`'s look, round — and the mark at `Metrics.glyph` (20 / 16) in the tint; the whole
circle takes the tap. His ask of 12 Oct 2026: the trip's bare pen did not read as an edit button. Used by: the
trip's pen (`trip-settings`, Trip settings — spec 03).

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
being edited has Cancel since 0.92 and Escape is that Cancel (until 0.92 it had no Cancel and no shortcut; its Done is
hidden while editing). Since 0.92 every page that changes something has a Cancel, and Escape is it (§20a): a
template's page and Your choices, whose Done carried Escape until then, too. The Mac's own *All your things* window
(`ThingsTable(inWindow: true)`) has none either — a window closes with ⌘W, and Escape in its search field would close
the whole table; its sheets (Filter, Sort, Columns, Change, a thing) do have it. On the iPhone a sheet that may be
swiped away also closes on ⌘. by itself (the system's own, shortcut or not), so there the tests pin that the right
window closes and nothing is saved; on the Mac nothing closes without the shortcut (so it was believed until 0.92 — the 0.92 probe saw a sheet close on Escape without its Cancel being pressed, §20a). There is no `onExitCommand`.
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

## 20a. Cancel everywhere — the one rule (0.92; `PageDraft`/`DraftedPage` in `Screens/EditDraft.swift`, `Library.applyingPage` in `PackingLibrary/PageChanges.swift`)

**His words** (19 Oct 2026): "I open an item and change some property. How do I cancel that? There is only a Done
button, right?" — and "the cancel function should be existing throughout the whole app right?"

**The rule.** A page where he changes a PROPERTY of something — several fields, or one thing's settings — has
**Cancel** top left (`HeaderButtonStyle(tint: Theme.muted, filled: false)`, quiet outlined, as the thing page's
`thing-cancel`) and **Save** — or a **Done** that saves — top right (filled, full colour, never grey, §20). Cancel
throws away every change made on that page since it opened; Save/Done keeps them. **Escape = Cancel** on the Mac (⌘.
on an iPhone keyboard), never Save (§20); **⌘S = Save/Done** (`.keyboardShortcut("s", modifiers: .command)`; the
thing page's ⌘S is the Mac's Thing menu, the button's own on the iPhone; since 0.103 on EVERY page that has a Done or a
Save — see "Keyboard shortcuts — the one table" below). **A swipe down (iPhone) never saves and
never throws a change away without a word** — the coordinator's decision for the whole app, 19 Oct 2026, per his "the
cancel function should be existing throughout the whole app": with nothing changed the page closes; with something
changed it holds still (`interactiveDismissDisabled`) and asks, as Notes and Calendar do — **"Discard changes?"** /
"What you changed on this page is not kept.", **Keep editing** (outlined; or a tap on the dimmed page) and **Discard**
(red, filled: what Cancel does). Cancel itself never asks — it was pressed on purpose. `View.asksBeforeDiscarding(_
changed:, holds:, keptEarlier:, discard:)` (`EditDraft.swift`): `holds` holds the page still without asking (a template being
arranged); `keptEarlier` (0.94) — part of the page was kept already while it stayed open — and the card's second line
says so instead: "Your latest changes are not kept. What the app kept earlier stays." (id `discard-says`; "is not kept"
of the whole page would not be true then). Since 0.98 only a bag's page passes it, after Its details wrote the page
(0.94 to 0.97 also the app put away, on a template's page and Your choices too). The question is the
app's own card in the look of a template's "Take it off?" (`DiscardCard`, ids
`discard-ask`, `discard-question`, `discard-says`, `discard-keep`, `discard-yes`) — a system action sheet's buttons cannot carry the
identifiers the tests find them by; the swipe is heard through UIKit's `presentationControllerDidAttemptToDismiss`
(`SwipeAttempt`: a relay in front of SwiftUI's own delegate of the sheet, passing everything else on). Until 0.92 a
swipe was Cancel on a thing's page, a row, Activity areas and the template's page, wrote everything on a bag's page,
and held without a word on Trip settings, the review and the desk. "Changed" per page: a template's page and Your
choices — the copy differs from the library they opened on (`PageDraft.changed`); a thing's page — any field, list,
section, kit, Only on some trips or care answer differs from what it loaded (`ThingKept`), or a list, section or
template is held to be made; a row — its answers (`RowKept`), a section typed, its lists changed; a bag's page — its
ledger held something (`EditDraft.onFirstHold`: told once, so a key draws nothing more) — since 0.98 a pocket changed
too, held on the ledger (until 0.98: or its pockets were touched);
a grab list's edit — its lines or "only sometimes" marks differ; Trip settings — its snapshot; the review — a mark,
a thing typed or added; the desk and Activity areas — a field or an area changed. On the Mac its sheets are not
swiped and Escape is Cancel; there the same question comes with **⌘Q** (below, "⌘Q with a page open").

**On the Mac, Escape closes a sheet by itself** (the 0.92 probe: with Cancel planted to SAVE, Escape on a template's
page and on Your choices still saved nothing — the sheet closed without its Cancel being pressed). The outcome is
Cancel's, since Cancel saves nothing; where Escape must NOT close the sheet — a grab list being edited, whose Cancel
keeps the list open — the sheet holds still on the Mac while editing (`interactiveDismissDisabled(editing)`, Mac only)
and the editor's `onExitCommand` is the Cancel, also while a field is being typed in. What ONE tap does and closes —
an icon or colour picked, a tick, Done today, a pill on a working list — is an action, not a form: it applies at once
and stays as it is (inside a page on a copy, the page's Cancel still throws it away).

**How a page holds its changes.** Either in its own state until Save (the thing page, a row, Trip settings, Activity
areas, the desk, a grab list's edit — as before), or — for a page whose controls change the library AT ONCE (a
template's page, Your choices) — on a **copy of the library** (0.92): `DraftedPage(live: model) { page in … }` makes a
`PageDraft` whose `copy` is a `LibraryModel(copyOf:)` — in memory only (`isDraft`: no store, no iCloud, no trip pages
written by `VaultShelf`, `reload()` does nothing) — and hands that copy to the page and to every page opened from it as
their `LibraryModel`. **Done** = `PageDraft.save()`: `live.change { $0 = $0.applyingPage(from: opened, to: copy) }` —
per record, by id: what the page added or changed is the page's, what it deleted goes, every other record keeps what
the real library holds NOW (the other device's changes while the page was open stay; a record both changed: the
page's wins) — and a TRIP, since 0.93, field by field: its head and each of its lines get only the fields the page
changed (a thing renamed or a place renamed reaches the open lines through the copy), so a tick or a line added on the
other device meanwhile stays, and the follow's stamp alone changes nothing (spec 01 §5, "A page's Save"); nothing changed = nothing written; the "When" steps and conditions are installed again from the real
library. Since 0.94 a THING, a ROW and a TEMPLATE are put in field by field too (only the fields the page changed,
onto the record as it is now; a record deleted on the other device stays deleted — spec 01 §5). A Done the store refuses
(0.94: `save()` returns false) leaves the page open, holding everything, with the note (§20b) — Done again saves it.
**Cancel** = dismiss; the copy is dropped; `PageDraft.left()` (on disappear) installs the real library's
"When" steps and conditions again if the copy changed them. The Mac's other windows are untouched by a page's copy (a
change made there while the page is open stays).

**The app put away or ended with a page open — the Apple way (0.98, his decision of 21 Oct 2026).** His words: "Yes,
go with the Apple way for Cancel/Done: remove the keep-on-close from the template page, your lists and the bag page,
and ship it after the trip." On his check sheet of 0.97 he found a template's new name NOT kept after swiping the app
away (0.94 meant to keep it — the rename was typed but not taken, so it was never in the copy) and asked "Why should you
keep a name that isn't confirmed with Done? What is the Apple standard?" The Apple standard, as Calendar's, Contacts'
and Reminders' edit sheets: unconfirmed changes on a Cancel/Done page survive switching to another app and coming back —
the page is still open with them; swiping the app away (or the app being ended, or the Mac app quitting) throws them
away; Cancel always throws away everything since the page opened; Done keeps. So since 0.98:
- **A template's page and Your choices** (`DraftedPage`/`PageDraft`): the copy lives in memory with the page. Nothing
  happens when the app goes to the background or the Mac app quits — `PageAway` and `PageDraft.keepAway()` are gone,
  `opened` is the library as the page opened (no longer moved on), `keptEarlier` is gone from `PageDraft`, and
  `TemplatePage`/`ListsPage` take the draft as a plain `let` again (they observed it only for 0.94's move). Done saves
  through the field-wise merge as before; Cancel, Escape and Discard throw away everything since the page opened; a row
  whose own Save was pressed is part of the page's copy, so it goes with it when the app is swiped away.
- **A bag's page**: its ledger (`EditDraft`) lives in memory with the page; `writesDraftWhenAway` is no longer on it, so
  the app going to the background or the Mac app quitting writes nothing, and `savedHere()` is called only after Its
  details. Its pockets, written as they changed from 0.69 to 0.97 (and put back by Cancel — 0.92, 0.95's
  `PocketsTrail`), are held on the ledger too (`EditDraft.step`, `BagPockets(draft:)`; spec 05), so nothing of the page
  reaches the store before Done — and nothing reaches the other device or a backup before Done either. Typing stays
  instant: still no store work per key (0.91).
- **Your bags** (a list with Done and no Cancel — what is typed in its rows counts as kept, as in a list of Apple's own)
  keeps 0.91's rule: its rows' numbers are written when the list is left, and when the app goes to the background or
  the Mac app quits (`writesDraftWhenAway`, now Your bags' only user; still never on the INACTIVE of a glance at Control
  Center — 0.94).
- **0.94 and why it went.** 0.94 (review item 5 of the outside review of 0.92) handed a template's page and Your choices
  over as the app went to the background (the Mac: as it quit) and moved Cancel's starting point there; the bag page
  wrote its ledger there too (`DraftAway` + `savedHere()`), and only on `.background` — not the `.inactive` of a glance
  at Control Center (review item 4; until 0.94 any phase but `.active` wrote, so Cancel after a glance had nothing to
  throw away). It meant an unconfirmed change was kept — the opposite of the Apple standard he chose. The debug-only
  hook that let a UI test pretend a glance (`PretendPhase`, the Darwin notification `se.ams.packing.uitest.inactive`)
  went with it: no page with Cancel listens to the scene phase any more, and a background is the stronger case, which
  the 0.98 tests use.
- **What remains not kept** (by design now): everything on a page not confirmed with Done when the app is swiped away,
  ended by the system while in the background, or quit on the Mac — the page is gone at the next launch, with no
  question. A page left open while the app is merely in the background for hours stays open as long as the system keeps
  the app. On the Mac ⌘Q asks first while the page holds a change (next point); the Dock's Quit, a log-out, Force Quit
  or a crash end the app without a question. The Mac tests end the app by force (`XCUIApplication.terminate()`).
- **⌘Q with a page open (Mac; 21 Oct 2026, after 0.98 — `QuitGuard`/`QuitCommand` in `EditDraft.swift`).** Found by the
  0.98 probe on GitHub's Mac: ⌘Q did NOTHING while a template's page, Your choices or a bag's page was open — no quit, no
  question, silently (any sheet did it: a thing's page, Trip settings, the review too). Not the app's own doing, and no
  quit-reply left waiting (the app never answered `applicationShouldTerminate`; 0.94's quit path only listened for
  `willTerminate`): every Mac window starts with `preventsApplicationTerminationWhenModal` on, a SwiftUI sheet is such a
  window, and while one is open the Mac refuses to quit before it even asks the app (proved with a bare SwiftUI app: a
  sheet open, `NSApp.terminate` returned and the app stayed; the delegate was never asked). Now:
  - **every sheet lets the app quit** — `QuitGuard.start()` (from `PackingMacDelegate.applicationDidFinishLaunching`)
    turns that switch off on each sheet as it opens (`NSWindow.willBeginSheetNotification`, and again when a window
    becomes key); so the Dock's Quit and a log-out end the app at once, with nothing of an open page written;
  - **⌘Q (the app menu's Quit, `QuitCommand` replacing `.appTermination`, still "Quit AMS Packing" ⌘Q)** quits at once
    when no open page holds a change; when one does — any page with Cancel, by the same "changed" as the iPhone's swipe
    (each `asksBeforeDiscarding` page tells `QuitGuard` as it shows, changes and goes) — it asks once, as an alert on
    the sheet in front: **"Discard changes?"** / "What you changed on this page is not kept." (or the `keptEarlier`
    line), **Keep editing** (Escape — Escape is Cancel on the Mac; ids `discard-keep`) stays with everything as it was,
    **Discard** (red; `discard-yes`) quits. Same words and ids as the iPhone's card (`DiscardWords`); a Mac alert rather
    than the card, so it always sits on the sheet in front (with a sheet over a changed page, the card would be under it).
    A second ⌘Q while the question is up does nothing.
  - Nothing of a page is written on the way out (the app quits in the same moment; no page's Cancel or Done runs). Your
    bags (Done only) still writes its rows as the app quits (`writesDraftWhenAway`).

**The audit (0.92)** — every screen or sheet where he changes data; "today" = before 0.92.

| Screen | How it saves | Cancel | Escape (Mac) | Swipe down (iPhone) |
|---|---|---|---|---|
| A thing's page (`ThingEditor`) | Save (state until Save; photos kept when taken) | `thing-cancel` | Cancel | **asks when changed** (was: Cancel) |
| Kit Inside, Only on some trips, Care schedule and notes, the drop-downs' own lists (Kind of thing, Whose it is, Kept at home, Usually packed in, Pocket, When, Condition) on a thing's page | held with the page (`KitDraft`, `ChoiceEdits` — 0.69/0.70) | the page's | the page's | the page's |
| A bag's page (`BagDetail`) incl. Pockets | written by Done (was: also by a swipe — `EditDraft`, 0.91; until 0.98 also by the app put away, and the pockets as they changed) | **added in 0.92 (work/dup092)**, `bag-cancel` | Cancel | **asks when changed** (was: wrote everything) |
| A template's page (`TemplatePage`): name, cover icon/colour, Counts as, Activity area, reminders, Add, ✕, Arrange | was: at once; **0.92: a copy until Done** | **0.92** `template-cancel` | Cancel (while arranging: ends Arrange first) | **asks when changed**; held while arranging |
| A row on a template (`RowEditor`) incl. its lists | Save (state); 0.92 ⌘S | `row-cancel` | Cancel | **asks when changed** (was: Cancel) |
| Reminders on a template | at once — on the template page's copy since 0.92 | the template's | the template's | the template's |
| Icon and colour picker (`IconPickerScreen`) | one tap applies and closes (an action) | `icon-cancel` closes without a choice | Cancel | closes |
| Choose from your things (`PickThings`) | Add N | yes | Cancel | Cancel |
| Small core (`SmallCoreSheet`), New template (`NewList`) | Make | yes | Cancel | Cancel |
| Activity areas (`AreasScreen`) | Save (state); 0.92 ⌘S | `areas-cancel` | Cancel | **asks when changed** (was: Cancel) |
| Your choices (`ListsPage`) | was: at once; **0.92: a copy until Done** | **0.92** `lists-cancel` | Cancel (was: closed as Done) | **asks when changed** (was: closed, all kept) |
| A grab list being edited | Save (draft); 0.92 ⌘S | **0.92** `grab-cancel` (the list stays open) | Cancel (was: none) | **asks when changed**; Discard closes the list without the edit (was: closed without a word) |
| For the lost-luggage desk (`DeskDetailsScreen`) | Save (state); 0.92 ⌘S | `desk-cancel`, **moved top left in 0.92** | Cancel | **asks when changed** (was: held without a word) |
| Trip settings (incl. Flights and stay, I leave at) | Save changes (foot); **0.92 also Save top right** `tripset-save-top`, ⌘S | `tripset-cancel` | Cancel | **asks when changed** (was: held without a word) |
| Trip review | Save review (foot); 0.92 ⌘S | `review-cancel`, **moved top left in 0.92** | Cancel | **asks when marked** (was: held without a word) |
| Create new trip (Home) incl. Flights and stay | Create trip — nothing is stored before | — (a form on a tab, not a sheet) | — | — |
| Change several things (`BulkChange`), the date picker, Restore | Change / OK / Replace | yes | Cancel | Cancel ("Nothing was replaced."; not changed in 0.92) |
| A trip's list, Packing day stations (tags, AirTag, add a to-do or a bag), On site, Pack to go home | one-tap actions at once; heading ticks and Clear have Undo; the composers have their own Cancel | — (working lists) | Done closes | closes |
| The bag-tag number (Packing day, Bags card), a bag's weight on a trip | one field, kept when left | — (one field) | — | — |
| To do, To buy | Add, tick, ✕ at once; ✕ offers Undo | — (lists) | — | — |
| Care (Done today) | one tap | — (an action) | — | — |
| Your bags (numbers per row), the things table's cells (Mac) | kept when the list is left or the app goes to the background (`EditDraft`; no Cancel, so it stays so in 0.98) / each cell at once with Undo | — (tables) | Done closes | closes |
| Settings' switches (Remind me to pack, messages, vault folder) | at once (Apple's switches) | — | — | — |

**Tests** (each seen RED with a planted fault first — Cancel saving — see spec 07 §11, 19 Oct 2026): model
`PageChangesTests` (Save hands over the page's rename, add, ✕ and a new place and keeps a thing and a place the
other device added meanwhile; a delete deletes only that; nothing changed = the library itself; Cancel hands nothing
over); UI `testCancelOnATemplatePutsItBackAndDoneKeepsIt` (Hiking renamed, a thing added, moved to OE → Cancel →
GA, "Hiking", 4 things; moved again → Done, ⌘S on the Mac → under OE), `testCancelOnYourChoicesPutsItBackAndDoneKeepsIt`
(a place added → Cancel → gone; added → Done/⌘S → kept), `testCancelWhileEditingAGrabListPutsItBack` (renamed and
one removed → Cancel, Escape on the Mac → 7 things, the old name, still open; renamed → Save → kept),
`testASwipeDownWithAChangeAsksFirst` (iPhone: an untouched template and thing close on a swipe; a changed template,
row, thing, Your choices, desk and grab list's edit ask — Keep editing keeps the change on the page, Discard closes and
keeps nothing), `testASwipeDownKeepsWhatIsNotSavedYet` (the review: Keep editing; Trip settings: Discard),
`testABagsPageKeepsEverythingTypedFieldAfterField` (a swipe asks; Discard keeps nothing; Keep editing, then Done keeps),
`testCancelOnTheDeskAndTripSettingsPutsItBackAndSaveKeepsIt` (Cancel left of Save; the phone changed → Cancel →
as it was → Save/⌘S → kept; the trip renamed → Cancel → unchanged → Save top right/⌘S → renamed); Escape on the Mac:
`testEscapeClosesSettingsWindowsAndNeverReplaces` (a place ADDED in Your choices, then Escape → gone) and
`testEscapeLeavesHomeAndTemplatesWindowsWithoutSaving` (the template's area changed, then Escape → as it was).
0.94: `testABagsPageStillCancelsAfterAGlanceAtControlCentre` and `testATemplatesPageIsKeptWhenTheAppIsPutAway` (they
asserted the keep-on-close; RED on 0.93) — replaced in 0.98 by the two below, whose expectations are the opposite.
0.98 (the Apple way; `-uiTestingKept`, debug builds: a store file that outlives the app, `-keptStart` making it afresh;
the app "ended" = on the iPhone put away and then terminated, as the app switcher does; on the Mac ended by force, as
Force Quit or a crash would — until 21 Oct 2026 ⌘Q did nothing on the Mac while a page's sheet was open, see
`testQuitWithAPageOpenQuitsOrAsksFirst` below):
`testABagsPageKeepsNothingButByDone` (the Wheeled duffel: iPhone — max 23 typed as 31 and a pocket Side added, the app
put away and back: the page still open with 31 and 2 pockets, Cancel → Your bags 23, 1 pocket; both — 32 typed, the
app ended → 23 at the next launch; 33 and Done/⌘S, the app ended → 33) and
`testATemplatesPageAndYourChoicesKeepNothingButByDone` (iPhone — a row's How many saved as 7 and Hiking renamed Hill
walk, the app put away and back: still open, named Hill walk, Cancel → Hiking and How many as it was; both — renamed
Hill trek and moved to OE, the app ended → Hiking in GA at the next launch; moved to OE and Done/⌘S, ended → under OE;
a place added in Your choices, ended → not there). Seen RED on 0.97 (iPhone, 0.97 with only the `-uiTestingKept` hook added): "the app put away kept the max, and Cancel could not take it back: Your bags says '31'", "the app put away kept the pocket, and Cancel could not take it back: 2 pockets" and `("32") is not equal to ("23") - the max typed and never confirmed with Done was kept when the app ended`; `("Hill walk") is not equal to ("Hiking") - the app put away kept the name, and Cancel could not take it back`, `("7") is not equal to ("e.g. 2, or 2 pairs") - the app put away kept the row's How many, and Cancel could not take it back` (the empty field reads as its prompt), the ended app's move kept (`("Swim") is not equal to ("Hiking") - the name never confirmed with Done was kept when the app ended` — Hiking had left GA, so the first row was Swim; the test now first checks GA and OE directly) and "the place never confirmed with Done was kept when the app ended".
⌘Q with a page open (Mac, 21 Oct 2026): `testQuitWithAPageOpenQuitsOrAsksFirst` (Mac only; `-uiTestingKept`) — Hiking's page and Your choices untouched → ⌘Q ends the app; the Wheeled duffel's max 23 typed as 32 → ⌘Q asks (`discard-yes`, `discard-keep`), the app still running → Keep editing: the bag's page still open with 32 → ⌘Q → Discard: the app ends; Hiking moved to OE → ⌘Q → Discard: ends; at the next launch Hiking under GA and the max 23. Seen RED on 0.98 on GitHub's Mac (Mac probe run 39660205132: "⌘Q did nothing with a template's page open"); green with the fix (run 39660205411, first time, with `testABagsPageKeepsNothingButByDone`, `testATemplatesPageAndYourChoicesKeepNothingButByDone`, both Escape tests and `testTheThingMenuIsOnOnlyWhileAPageIsOpen`).

### Keyboard shortcuts — the one table (0.103; `Screens/Keys.swift`, `Core/Sources/PackingLibrary/KeyGuide.swift`)

**His words** (27 Oct 2026, with a picture of a trip open over the Trips tab on the Mac, Done at its top right):
"Regarding keyboard shortcuts, when I am in a trip and want to press Command-S, it does not work." — and "I would also like
keyboard shortcuts to change tabs. Home, Trips, Templates, Care, To do and Settings." — and, for the guide, "make the list
visually pleasing and easy to read for a human" (§7b).

**Why ⌘S did nothing on a trip.** A SwiftUI button carries ONE keyboard shortcut, and a trip's Done (like every Done of a page
that only shows something — How it works, Search, Your things, the Stations …) carries Escape, `.cancelAction`. 0.92's audit
gave ⌘S to the pages that CHANGE something (a Save or a Done that saves), and only to those. On the trip nothing else
held ⌘S, so it fell through to the Thing menu's Save (⌘S, `ThingCommands`), which is switched off unless a thing's page is
open — the Mac beeped. Fixed by the rule below, not by a one-off: `View.commandS { … }` (`Keys.swift`) puts a hidden button
(zero opacity, no hit testing, hidden from VoiceOver — as How it works' ⌘F, 0.90) behind the Done, with ⌘S and the same
action, so the Done keeps Escape and gains ⌘S.

**The rule** (the Mac; an iPhone or iPad with a keyboard has ⌘S on the pages with a real Save button — 0.92's — and Esc / ⌘.
everywhere): **⌘S = Done or Save or Add or Make or Create** — the page's one confirming button; on a page whose Done only
closes it, ⌘S closes it. **Escape (and ⌘.) = Cancel, or Close where
there is no Cancel.** **⌘Q** quits (asks first while a page holds a change, 0.99). **Never on a destructive or replacing
button:** Restore's *Replace everything on this device*, Delete, Take it off, Discard keep no ⌘S (and Return stays with the
fields). **Mac only, deliberately:** the hidden button behind a Done (`commandS`) is left out on an iPhone or iPad — there
it stayed in the accessibility tree whatever `accessibilityHidden(true)` said (the iPhone run of 27 Oct 2026 found a second
`guide-done` button, labelled Save, beside every Done, so every tap by id was ambiguous; a duplicate "Save" for VoiceOver
besides). The Mac hands a sheet its own window, so a page's hidden ⌘S can never be reached from the page over it.

**The table.**

| Keys | What | Where it lives |
|---|---|---|
| ⌘S | Save / Done / Make / Add / Create trip | every page below; Thing menu ▸ Save on a thing's page |
| Esc, ⌘. | Cancel, or close | every sheet's Cancel or Done (`.cancelAction`); a template being arranged: Arrange first |
| Return | adds what is typed in an Add field; saves a thing's page from any field but Notes (Mac) | `onSubmit`; `ThingEditor.key` |
| ⌘1 … ⌘6 | Home, Trips, Templates, Care, To do, Settings | Go menu (`GoCommands`, Mac only) |
| ⌘, | the Settings tab | app menu ▸ Settings… (`SettingsAndHelpCommands`, Mac only) |
| — | Help ▸ Keyboard Shortcuts: How it works at its topic | `SettingsAndHelpCommands`, `LibraryModel.keysToOpen` |
| ⌘F | search How it works; find an icon | `GuideScreen`, `TemplatesScreen` icon picker (Mac) |
| Esc in those fields | empties the search, then closes the page | `onExitCommand` (Mac) |
| ⌘N | New Window (File menu) — Save and New while a thing's page is open | `ThingCommands` |
| ⌘↓ ⌘↑ ⌘J | next / previous thing, jump to a field | Thing menu (`ThingKeys`, Mac) |
| Tab ⇧Tab Space ↑ ↓ ← → Return, letters | the thing page's key walk and its drop-downs | `ThingEditor.key`, `DropDown.answer` (Mac) |
| ⌘Q | quit | `QuitCommand` |
| ⌘W | closes the All your things window | the system |

**The Go menu** (`GoCommands`, `CommandMenu("Go")`, before the Thing menu): the six tabs in the tab bar's order, ⌘1 to ⌘6 —
Apple's own convention — the tab showing ticked. It acts on the window in front (`RootView` gives its scene a
`SectionSwitch` through `focusedSceneValue`) and is **off (greyed) while a page is open** — the Apple modal rule: tabs do
not change underneath a page whose changes are not confirmed yet. "A page is open" = a sheet is attached to one of the
app's windows (`PageWatch`: `NSWindow` will-begin / did-end sheet, did-become / did-resign key, will-close, then
`sheetParent`/`attachedSheet`). The tab keys are the Mac's alone: an iPhone or iPad keyboard has no tab shortcuts (the hidden
buttons they would need cannot be kept out of the accessibility tree, above). The menu's items carry ids for the tests (`go-home`, `go-events`, `go-templates`, `go-care`,
`go-actions`, `go-settings`, `go-settings-comma`, `help-keys`), given by `ThingKeys.nameGoMenuItems` as the Thing menu's are.

**The audit (0.103) — every page with a Done, a Save or an Add, and its ⌘S.** Real Save/Done, since 0.92: Trip settings
(`tripset-save-top`, `tripset-save`), the trip review, Your choices (`lists-done`), Activity areas, a template's page
(`template-detail-done`) and a row on it, a thing's page, the bag page, the lost-luggage desk, a grab list being edited.
Done that only closes, ⌘S added in 0.103 (`.commandS { dismiss() }` unless said): the trip (`trip-done`); How it works, What's
new, Your first real trip (`guide-done`); Sync details; Filter, Sort, Columns, the things table (sheet and window,
`table-done`); the Packing Stations sheet (`day-done`); Take a break; Before you start; On site; Way home; Lost bag
(`lost-done`); Search; Refine; a place (`place-done`) and its label (`place-code-done`); a grab list not being edited
(`grab-done`); Your grab lists; Which grab list? (`grab-menu-close`); Your things; Your bags; Where you have been; The loop; Share
(`share-done`); Open a shared link (`shared-done`); a bag's photos (`bag-photo-done`); Pack by voice (`voice-done` — which had
no Escape either until 0.103). Confirming buttons that add or make: Choose from your things (`pick-add`), New template
(`newlist-make`), A small core (`smallcore-make`), Change several things' "Set to …" (`bulk-apply`), **Create trip** on Home
(`trip-create`). Not bound, on purpose (they have nothing to save, or replace): the icon picker, Restore (whose Replace is
never ⌘S), Which one steps back?, and: Restore's Replace, every Delete / Take it off / Discard, the
small cards inside a page (Close on a place card, OK on a news card, the calendar's OK — Trip settings' own ⌘S takes them).
Escape was missing on one page only: Pack by voice.

**Tests** (Mac; `launch`ed on GitHub's Mac probe, not on this Mac's screen): `testCommandSIsDoneOnATripsPage` (the picture: a
trip open over Trips, ⌘S → gone, the tab still there), `testCommandSIsDoneOnEveryPageWithADone` (What's new, How it works,
First trip, Your things, Search, the trip's loop and Share — each opened, ⌘S, gone; every failure listed in one message),
`testCommandSMakesANewTemplate`, `testCommandNumbersChangeTabs` (the Go menu has six items, all on; ⌘6 … ⌘1 each open their
tab; ⌘, opens Settings), `testTheTabKeysAreOffWhileAPageIsOpen` (a trip open: all six items off, ⌘3 changes nothing and
closes nothing; Done: on again, ⌘3 opens Templates), `testHelpOpensTheKeyboardShortcutsTopic`. Model and guide: §7b.

## 20b. A save that fails — a note, never a dead app (0.93; `SaveNote` in `RootView.swift`, `LibraryModel.couldNotSave`, `CloudStore.apply`)

**Why** (the outside review of 0.92, fixed at his word on 20 Oct 2026, "fix 1, 2 and 6 as one version (0.93) and ship
it to TestFlight before the trip"): one failed save replaced EVERY tab with the error (`.failed`, spec 01 §5), the failed
change stayed waiting in the store — the next save stored it or failed on it again — and a restore that was not saved
said "Restored".

**The rule.** A change the store refuses is rolled back in the store (`context.rollback()`, spec 01 §4); the screens
stay; the library is read again, so the screen shows exactly what is kept (the change he just made goes back on the
screen); and a small calm note says, in plain words, **"Couldn't save that — try again."** — no error codes, no
technical words. Where he asked for a replacing write and waits for its answer (Restore from a file, the first-run
import), that answer says it too: "Nothing was replaced — it couldn't be saved. Try again." / "Nothing was brought in —
it couldn't be saved. Try again." The red `library-problem` screen remains only for a store that cannot be opened or
read at all.

**The note.** `Text(SaveNote.words)` (since 0.102 `show(_:id:seconds:)` also carries a save that crossed, §20c — its own words, id and 8 s, wrapped at 330 pt; the failed save's note is unchanged), Subheadline semibold, `Theme.ink` on a `Theme.card` capsule (since 0.102 drawn as a rounded rectangle of radius 20 — the same capsule on one line) with a 1-pt
`Theme.line` border, padding 16 × 10; id `save-problem`; shown for 4 s, a tap puts it away; a second failure shows it
afresh. It must be seen over whatever is open — a page is a sheet above the tabs — so it is a small window of its own:
on the iPhone a `UIWindow` at `.alert + 1`, the note's own size, centred, 64 pt above the bottom safe area, and — while
the keyboard is up — 12 pt above the keyboard (`SaveNote.watchKeyboard`, started with the frame in `RootView.onAppear`;
first try sat under the keyboard: there for the test, hidden for him), never made key (typing stays where it was); on
the Mac a borderless non-activating `NSPanel`, a child of the window in front (a sheet's own window when one is open),
centred 24 pt above its foot. Day and night: the app's colours (looked at in both, 20 Oct 2026).

**What a page does with a save that fails (0.94, the empty bag name of 0.93's report).** In 0.93 the store and the
screen agreed, but a page that wrote lost what it held: Your bags' Add emptied the name typed (he had to type it again —
the 0.93 test did), a bag page's Done closed the page — the name taken with Rename and every field typed gone with the
failed save — and Duplicate turned the page to a copy that was never kept. `LibraryModel.change` now answers whether it
was kept (spec 01 §5); `EditDraft.flush` / `EditDraft.writing(_:also:)` put everything back on the ledger when it was
not; and: Your bags' Add keeps the name in its field (and the rows' typed numbers held); a bag page's Done, Its details
and Duplicate leave the page open, still holding everything — the name too; a template page's and Your choices' Done
leave the page open on its copy. "Try again" is then one press of the same button. Since 0.98 (the Apple way, §20a)
what such a page holds after a refused Done lives in memory only, like everything else on it: still there after
switching to another app and back, gone when the app is swiped away or quit — until 0.97 the app put away tried the
write again (`DraftAway`, `PageAway`). Your bags' typed rows still get that try as the app goes to the background.

**Tests.** UI `testAFailedSaveKeepsTheScreensAndSaysSo`, `testARestoreThatCannotBeSavedSaysNothingWasReplaced`
(`-uiTestingSaveFails`, debug builds: a store file whose first save fails) — spec 01 §5 and §11; seen RED on 0.92.
0.94: `testAFailedSaveKeepsTheScreensAndSaysSo` also checks the name stays in Your bags' field and the second Add needs
no retyping — RED on 0.93: `("A new bag") is not equal to ("Tote") - the failed save emptied the name typed` (the
empty field reads as its prompt); `testAFailedSaveOnABagsPageKeepsTheName` (`-saveFailsBags`: the Wheeled duffel
renamed Big duffel, Done fails → the note, the page still open, "Big duffel" in the name field; Done again → saved) —
RED on 0.93: "a failed save closed the bag's page, and what it held went with it".

**A photo whose file is missing as the store is read — never a dead app (0.100; `Record.read` and `CloudStore.loadAll`
in `Store/CloudStore.swift`, `AMSCatchException` in `Store/ObjCExceptions.h/.m`).** His Mac, 24 Oct 2026, on 0.99: iCloud
had just brought a change in (09:06:23) and the app read the store again; one photo's bytes — kept by SwiftData in a
file of their own (`.externalStorage`) — were not there as they were read, and SwiftData THREW: an Objective-C exception,
"External data reference can't find underlying file.", which no Swift code can catch. It ran out through the reading,
which ran inside a Swift `Task`; the Mac swallowed it and the app went on, with Swift's own bookkeeping of what runs on
the main thread left pointing at nothing — and the next click on a button, six minutes later (09:12:04), shut the app
(the crash report names no line of the app's: a bad address inside the button's own check that it runs on the main
thread). On the iPhone the same throw shuts the app at once. The rules since 0.100:
- A record's contents are read through `AMSCatchException` (the app's one piece of Objective-C, the target's bridging
  header): such a throw is caught where it is thrown, and that photo is LEFT OUT of this read — not read as a photo
  without a picture — so nothing the read leads to can write it (no settling of twins, no difference stored): the store
  keeps it exactly as iCloud left it. The rest of the library is read as always.
- The store is read again 5 s later, when iCloud has usually finished — at most 3 times in a row (`readsAgainAtMost`);
  a read with nothing missing starts the count afresh.
- A change from iCloud is read straight away on the main thread, never in a Swift `Task` (`LibraryModel.init`'s
  `onRemoteChange`, `MainActor.assumeIsolated`): any other exception a framework throws while the store is read then
  costs that one read, not the rest of the app's life.

Test: UI `testAPhotoWhoseFileIsMissingNeitherStopsTheSyncNorShutsTheApp` (`-uiTestingPhotoGone`, debug builds: a store
file with the sample; 6 s after launch "the other device" writes a photo of 1 MB and a thing called Sunglasses through a
store of its own on the same file, and the photo's file — with its second names in `.LINKS` — is deleted between the
app's fetch and its reading of the bytes, `CloudStore.afterFetchForTests`): the Sunglasses arrive, a search and a thing's
page answer after it, the app keeps running. RED on 0.99 — iPhone: "com.schabbauer.AMSPacking crashed", *Terminating app
due to uncaught exception 'NSInternalInconsistencyException', reason: 'External data reference can't find underlying
file.'*; Mac (GitHub's): "com.schabbauer.AMSPacking crashed in <external symbol>" at the click after the photo, and
its crash report is HIS: the button's own main-thread check (`MainActor.assumeIsolated` in `_ButtonGesture` →
`swift_task_isMainExecutorImpl` → `swift_getObjectType`), beside the system's note that an exception had been swallowed
a second before. 🪤 The file deleted BEFORE the app's fetch is not enough: the photo is then read without a word
(no throw, the test green on 0.99) — the throw comes only when the file goes between the fetch and the bytes.

## 20c. Changed on the other device meanwhile — asked, never merged silently (0.102; `CrossedAsk` in `Screens/CrossedAsk.swift`, `PackingLibrary/SavesThatCross.swift`)

**Why** (his decision of 26 Oct 2026 — "warn instead of merge", option B of spec 01 Open question 32). Some of the
library is ONE value in ONE record, and iCloud keeps the last whole version sent: a grab list (its lines and "1 in 10"
marks), a template's head (name, cover, sections…), what a kit holds, a list of Your choices, his kinds of thing
(`Block`, spec 01 §5). Until 0.102 a page's Done merged the other device's change of such a block with the page's
without a word (0.95/0.97), and a save that crossed lost one device's change without a word.

**The question.** Done (Save) on a page that changed such a block, when the block changed here too since the page opened
(the live value is not the one the page opened with — the other device's save arrived meanwhile) AND Keep both and Keep
mine would give different blocks — asks, before anything is written: an Apple alert (`UIAlertController` on the
iPhone, an `NSAlert` sheet on the page's sheet on the Mac; system type and colours, day and night): title **"Changed on
your iPhone meanwhile"** ("your Mac" on the iPhone; "your other device" until that device has checked in here, spec 01
§8), message one line naming it — **"Indoor swim’s grab list"**, **"The Hiking template"**, **"What the Camp pouch
holds"**, **"Your storage places"** (several: "The Hiking template and your storage places") — and two buttons:
**Keep both** (first, the preferred one — Return on the Mac; id `crossed-both`): the merge of 0.95/0.97, what each
device added and took off; **Keep mine** (`crossed-mine`): the page's version of that block, whole — the other
device's change of it goes. No third answer: the page's own Cancel is still there once the alert is answered — only
after an answer does anything get written. The alert itself: `crossed-ask`. Nothing changed meanwhile, the page changed
nothing in the block, or both devices made the same change: no question, saved as before.

**Where.** A template's page and Your choices (`PageDraft.done`, §20a — every block the page's copy changed), the grab
list's editor (`GrabScreen.saveEdits`), a thing's page for what it holds as a kit (`ThingEditor.save`, `KitDraft.crosses`).
The small core's way out of a template's page (`page.save()` as its sheet closes) keeps the merge without asking.

**The note — the case Done cannot see.** The other device's save of the same block, made before this device's save had
reached it, arrives AFTER this device saved: iCloud keeps the last one sent, so this device's change is gone. The app
watches each block it saved for 10 minutes (`RecentSaves`, in memory; nothing stored): when the store is read again and
the block no longer holds what this device changed (our change put onto it again would change it — `mergeValue`), the
note of §20b shows, with its own words and id, for 8 s: **"Indoor swim’s grab list was also changed on your iPhone —
open it to check."** (several: "… were also changed … — open them to check."; id `save-crossed`; wrapped on two
lines, 330 pt wide). Told once; a later save of the other device that HOLDS this device's change (it had seen it) is no
loss and says nothing; a block deleted there says nothing. The app does not put its change back: he looks and decides.
The same on both devices — whichever device's change was lost is the one told.

**Tests.** Model `WarnInsteadOfMergeTests` (8). UI (`-otherDeviceOnOpen <grab|template|kit>`: the other device's save,
through the store as iCloud brings it, with its check-in, 0.5 s after the page opened; `-otherDeviceAfterSave grab`: its
save of the list as Edit opened, 0.5 s after Save): `testAGrabListChangedOnTheOtherDeviceWhileEditingAsksAtSave`,
`testATemplateChangedOnTheOtherDeviceWhileItsPageIsOpenAsksAtDone`, `testAKitChangedOnTheOtherDeviceWhileItsPageIsOpenAsksAtSave`,
`testAGrabListSaveTheOtherDeviceWroteOverIsTold` — spec 01 §5 has what each proves and its RED.

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
(ScreenHeader.swift, 0.67): the first line of Trips, Templates and Care (and of Home until 0.91). `Metrics.screenTop` above it; one row,
at least `Metrics.tap` tall, `HStack(alignment: .center, spacing: 8)`: the title (one line, scales to 80 %, id `id`), a
spacer (≥ 8), then the tab's buttons (`trailing`) — all on ONE centre line. Under the row, when given, the `line`
(Subheadline, muted, id `lineId`). Used as: Home until 0.91 — "Grab and go", Title 3 bold, ink, with the magnifier
and Grab Lists (since 0.91 that line is the first line INSIDE Grab and go's frame, `grabHeading`, without
`headerLine()` — his "I would like the "Grab and Go" heading to be inside this frame"; on the Mac Home's strip
holds only the magnifier, `searchStrip`; spec 02 "What is on screen"); Trips — "Trips", green, map pin, magnifier, the to-do chip, line = the trips summary; Templates — "Your
templates", violet, magnifier, + New, line = the templates summary; Care — "Care", orange, magnifier, line = the kit
line. To do's first line (To do · To buy · magnifier) is its own `HStack` (centred, `Metrics.screenTop` above);
Settings has no header line. History: his note on 0.63 (6 Oct 2026), "Overall, icons are not aligned", with a
picture of Trips — every tab built this row itself, aligned on the title's first text baseline with 14 pt above it,
so a 36-pt icon button stood up from the baseline about 10 pt higher than the title, and left an empty band at the
top of every tab ("The area above Grab and go is underused"). UI `testEveryTabsHeaderIsOnOneCentreLine` checks on
Home (since 0.91 Grab and go's line in its frame: Grab Lists, and on the iPhone the magnifier, on the heading's
centre line; on the Mac the magnifier on the window buttons' line), Trips, Templates, Care and To do that every button of the line sits within 1.5 pt of the title's centre line
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
  in itself as its first line (`#if !os(macOS)`). Trips, Templates and Care build their header once
  (`header(…)`) and use it both ways; Home (0.91) pins `searchStrip` (a spacer and the magnifier, `headerLine()`)
  on the Mac and has no header line on the iPhone — its first block is Grab and go's frame (`Metrics.screenTop`
  above it, as Settings' first card), whose own line holds the magnifier there. On the Mac 6 pt follow the header (below).
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
  things' list headings are Headlines the same way; the activity areas say his code in capitals and the words as he
  writes them ("GA · Goal Activity", "Always Packed", "Other Templates"; since 0.89 `Library.areaWords`, and an area
  he made or renamed is his words alone) at Headline — until 0.78
  the words were upper-cased too ("GA · GOAL ACTIVITY"); his "not all caps", 13 Oct 2026.
- Small capitals stay where Apple uses them: column titles over a table or the bag numbers, the kind of a shared
  thing ("A TEMPLATE"), What's new's part names — Caption or Caption 2, semibold.

**`Pills(title:, options:, selected:, id:, tint = Home blue, startIndex = 0, heading = .title, tones:, choose:)`** —
a heading (band / title / question, id `<id>-title`) over pills in a `FlowRow(spacing: 6)`. Each pill: Subheadline,
semibold when picked, regular when not; padding 12 sideways, min height `Metrics.chip`; picked = filled with its tone
or the tint, white (or the tone's dark) words; not picked = `Theme.bg` fill, ink words, outlined in `line` (1 pt) or,
for a toned pill, in its tone (1.8 pt). `tones` is asked by the option's **id** (by its words until 0.91): the
template pills pass `TemplateTone.byId(lists, workouts:)` — his colour for the template (`Library.pillColour`), else a
workout's `WorkoutTone`, else none. `PillTone` holds hexes (`fillHex`, `inkHex`; `fill`/`ink` the colours); in a DEBUG
build a toned pill with no drawing says `"<fillHex>/<inkHex>"` as its accessibility value. Id `<id>-<startIndex + position>` — "its position — never its words";
picked pills carry the `.isSelected` trait (what tests read). `cursor: Int?` (0.68, nil everywhere but a thing's On
these templates on the Mac): the pill the keys' arrows are on, ringed 2 pt in the tint just outside it (`focusRing`).
`WorkoutContexts` (0.67; `ContextPills` until then)
puts Context under the workouts, indented 18 with a 3-pt grey line down its side: a `.question` heading "Context",
then one line per ticked workout — its name in its pill's colour made readable (`Workout.fill`, `readableHex`; 0.91:
his colour for it when he chose one — `WorkoutTone.words` is gone), in a
`Metrics.contextName` column (72 / Mac 64) — and its own Indoor, Outdoor, Race pills in the Settings slate
(padding 10). **`TripKindChoice`** (0.67): two answers in one capsule track — Full trip | Quick — the picked one
filled with the tint, `.isSelected`; a muted Footnote line under it. The track is as wide as its column — the name
field above it on Create new trip and in Trip settings (0.91, his "in line with the name field above"; at most 360
until then) — and a container `<id>-track`.

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
unknown = nil, same = exact, newEntry = nil, tools = nil, ring = nil, choose:)`:
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
- `unknown: String?` (0.97, his check 6 of 21 Oct 2026) — what the FIELD reads when the value that stands is not
  blank and none of the rows, for a list whose values are ids: a row's When ("Not said") and Section ("No
  section"); a thing's bag, When and Condition ("Not said") and its Section on each template ("No section"); a
  template's activity area ("No activity area"). nil (every other list): the value itself, as before — a pocket's
  or a number's words are his. Until 0.97 an id read as itself: a line naming a section its template had lost
  showed "mvho3cjj-0-r6dbge" (spec 01 §5, saves that cross).
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
  (`Screens/ChoiceDropDown.swift`) and `DropDownRowTools.sections` — and (0.73) a reminder's two When lists on a
  template's page, built by `ChoiceDrop.atOnce`: the same tools with nothing held, each change written as it is made
  (`applyChoiceEditsNow`), so a removed row goes at once instead of being struck out (spec 07 part 13, "The last three
  lists"). A list with none of his rows yet still opens to its foot (Whose it is with nobody named, Pocket for a bag
  with none).
- **Drag and drop (0.70, `Screens/Reorder.swift`)** — on a tool row whose list `orders` and that is not removed, a
  **grip ≡** at the row's LEFT (`<row id>-grip`; `ReorderGrip` drawing Arrange's `GripMark`, the thin grey one: 24-pt
  grid, 36 × `Metrics.compact`; read as "Move <name>", hint "Hold and drag to move it; the arrows move it one place"
  — on the iPhone "Hold and drag to move it"; VoiceOver actions **Move up** / **Move down** (0.72) take one step).
  iPhone: hold 0.2 s, then drag (a swipe over it still scrolls); Mac: drag with the mouse. As the row is carried past
  one row-height (its own measured height, `reorderStep`) it takes ONE step with the list's own `move(value, ±1)` —
  the call ↑ / ↓ make, so a drag is a row of arrow presses (held until Save; Cancel undoes), one step per drag event
  (the list's `move` reads the list as last drawn). The carried row is drawn on the card colour with a 1-pt tint edge
  and a shadow, `zIndex` 1, offset to follow the finger (at most 0.6 row past the first or last place); let go — or
  the system cancels the gesture — it settles (0.15 s). The grip is not one of the tools Tab reaches: the keys keep
  ↑ ↓.
- **↑ ↓ are the Mac's only (0.72, `ReorderArrows.shown`: true on the Mac, false on the iPhone).** His answer, 8 Oct
  2026, to "now that rows can be dragged, should the arrows come off the iPhone?": "Drag and drop on the phone as
  well." On the iPhone a tool row is grip · name · pen · Remove — no `-up` / `-down`, and `toolsOf` leaves `.up`
  `.down` out — so the name has the arrows' room: "Pharmacy / meds" and "Comfort & misc" are one line (two in 0.70).
  The Mac keeps grip · name · pen · ↑ · ↓ · Remove, Tab reaching ↑ ↓ as before. The same rule holds outside the
  drop-downs: Your choices' pen (§2), a bag's pockets (spec 05), a template's reminders (spec 07 part 12), a grab
  list's things while edited and Grab Lists' Home order (spec 02) and the table's Columns (spec 05) — each has a grip
  on both, arrows on the Mac only. Rows are followed by a key, never their place (a grab list's draft keeps
  `rowKeys` beside its names); where rows have a gap, the grip's step is the row plus the gap. Since 0.70 the options are `ForEach`-ed by VALUE (a repeated value gets "<value>#<n>") and a tool row's scroll
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
  **The light stays inside the list (0.100, crash B).** A list opened by a click lights its ticked row too (`lit =
  chosenIndex`). Until 0.100 every ↑ ↓ pressed on a row's tools moved the light one place as well, whichever row it was
  on — so with "Not said" ticked (the first row), ↑ on the second place put the light at −1, and the list scrolled to
  row −1: "Index out of range", the app shut (two TestFlight crash reports from his Mac, 18 Oct 2026, 0.87; still in
  0.99). Now the light goes with a row moved only when that row is the lit one, the other way when the moved row takes
  the lit one's place, and stays put for any other row (`clampedLit` keeps it inside the list); the list scrolls only
  to a row it has, or to the offer one past the last; ↓ in a list with no row does nothing. Test: UI (Mac)
  `testAnArrowOnAnotherRowOfAnOpenListDoesNotShutTheApp` (Map's Kept at home set to Not said, opened again, ↑ on the
  second place: it moves up, the app keeps running) — RED on 0.99 on GitHub's Mac: the app shut at the click ("↑ on
  the second place did not move it up: ''"; its crash report: Index out of range in `closure #3 in closure #1 in
  DropDown.list.getter`, DropDown.swift:289 — the same place as his).

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

**The app's delegates** (0.86, spec 02 §13b). `AMSPackingApp` has `@UIApplicationDelegateAdaptor(PackingAppDelegate)`
on the iPhone and `@NSApplicationDelegateAdaptor(PackingMacDelegate)` on the Mac, both in `Store/QuickActions.swift`
and there only for the grab lists under the app icon / in the Dock icon's menu. The iPhone's names a scene delegate
(`PackingSceneDelegate`) in `application(_:configurationForConnecting:options:)`; SwiftUI keeps its own window and
`onOpenURL` still receives a place's link.

**`RootView`.** `VStack(spacing: 0)`: the current section's screen, at most 720 wide ("the web app's column, on the
Mac"), centred; under it the tab bar; `Theme.bg` behind, ignoring safe areas. Starts on Home. On appear: the
reminders' tap handler (→ Home + `tripToOpen`) and `PackingReminders.start()`; on the Mac (0.86) the window counts
itself in for the Dock menu (and out on disappear). The library publisher, debounced 2 s:
reschedule reminders, update the Shortcuts parameters and (0.86, iPhone) the entries under the app icon, which are
put right again when the app goes to the background. Scene becomes active: read back Reminders ticks and
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
| `-uiTestingLeaving` | memory, `SampleLibrary.leaving()` | 0.75: the sample trip starts today, "I leave at" 08:00 |
| `-uiTestingOldPhoto` | memory, `SampleLibrary.oldPhoto()` | |
| `-uiTestingTwoLibraries` | memory, `SampleLibrary.doubled()` | |
| `-uiTestingPlaces <when>` | memory, `SampleLibrary.places(when)` | 0.69; checked before `-uiTestingNotes`, `-uiTestingPockets` and `-uiTesting` |
| `-uiTestingNotes` | memory, `SampleLibrary.notes()` | 0.69 |
| `-uiTestingPockets` | memory, `SampleLibrary.pockets()` | 0.69 |
| `-uiTestingTravel` | memory, `SampleLibrary.travel()` | 0.76: the sample plus an RV transport template "Camper kit" (Travelling by) |
| `-uiTestingGrabHeadings` | memory, `SampleLibrary.grabHeadings()` | 0.85: Outdoor bike under three headings of his own (it replaced 0.84's `-uiTestingGrabKinds`, kinds of thing behind Indoor swim) |
| `-uiTesting` | memory, `SampleLibrary.make()` | checked last |
| (none) | SwiftData; iCloud when the Info.plist key `PackingUsesICloud` is "YES" | a failure to open → `.failed("The library could not be opened: …")` |
| `-openGrab <label or title>`, `-openGrabMenu`, `-openNextTrip` | (testing only) play a Shortcut | |
| `-uiTestingOpen <link>` | (testing only) a link handed to the app at launch, as the Camera hands a place's label (`LibraryModel.open`) | 0.69 |
| `-pretendShopTicks` | (ShopReminders) pretend ticks in Reminders | |
| `-pretendRemindersBlocked` | (PackingReminders) switched on earlier, then blocked in the device's Settings — also "I leave at"'s red line (0.69) | 0.62 |
| `-showDoorChecks` | (DEBUG, testing only) the trip lists the door checks that would be scheduled (`door-check-out/home/none`) | 0.69 |
| `-tapDoorCheck out\|home` | (testing only) a door check tapped at launch, for the first trip with that time | 0.69 |
| `-showTripMessages` | (DEBUG, testing only) the trip lists the break and moves-on messages that would be scheduled (`trip-message-break/onsite/review/none`; `trip-message-charge` since 0.87) | 0.77 |
| `-breakRealCalendar` | (testing only) Add to Calendar hands the break over for real — the system's New Event window on the iPhone, Calendar on the Mac — instead of only saying what it would; for looking by hand, no test uses it | 0.77 |
| `-tapTripMessage break\|onsite\|review\|charge` | (testing only) a trip message tapped at launch, for the first trip with lines (`review` opens its Review; `charge`, 0.87, its To charge) | 0.77 |
| `-reviewAtPack` | (testing only) the trip header's Review shows at Pack too (`TripScreen.reviewAtPack`) — for the tests about the review itself on the sample trip a month ahead; the rule of when it shows (`Library.offersReview`, once the trip has started) is tested without it | 0.84 |
| `-clockAt HH:mm:ss` | (testing only) the app's clock (`Today.now`) is today at that time when the app opened, and runs on — when a trip sets off (spec 03, The loop) | 0.75 |
| `-openGrabOnReturn <label or title>`, `-openNextTripOnReturn`, `-dropOwnGrabListsOnReturn` | (testing only) played when the app returns from the background: a Shortcut, a tapped reminder, the other device's write that no longer holds his own grab lists | 0.62 |
| `-bagOnReturn <thing> <bag>` | (testing only) played when the app returns from the background: the other device puts that thing in that bag (a thing's page open meanwhile, spec 05) | 0.93 |
| `-uiTestingSaveFails` | (debug builds only) the sample in a store file whose first save after launch fails (§20b, spec 01 §6) | 0.93 |
| `-saveFailsBags` | (debug builds only, with `-uiTestingSaveFails`) the sample with bags, so the failed save can be a bag page's (§20b) | 0.94 |
| Darwin notification `se.ams.packing.uitest.inactive` | **gone in 0.98** — (debug builds only; not a launch argument — the UI test posted it) a page that wrote when the app went away heard the phase go inactive and come back, as for a glance at Control Center (`PretendPhase`); since 0.98 no page with Cancel listens to the phase (§20a) | 0.94 |
| `-uiTestingKept` | (debug builds only) the sample with bags in a store file that outlives the app — a test ends the app with a page open and finds what was kept at the next launch (§20a, 0.98) | 0.98 |
| `-keptStart` | (with `-uiTestingKept`) the file is made afresh | 0.98 |
| `-quickAction <title>` | (testing only, iPhone) the entry under the app icon with that title — taken from the entries the app hands the system, so only one of the four — tapped to START the app: handed over through the cold-start path (`PackingAppDelegate`, as `options.shortcutItem`) | 0.86 |
| `-quickActionOnReturn <title>` | (testing only, iPhone) played when the app returns from the background: that entry handed to the scene's delegate (`windowScene(_:performActionFor:)`), as iOS does while the app runs | 0.86 |
| `-dockMenu <title>`, `-dockMenuWhenClosed <title>` | (testing only, Mac) the Dock icon's menu asked of the app's delegate and that entry performed — a second after the window is up / after the last main window closed | 0.86 |
| `-spotlightTap <name>`, `-spotlightTapOnReturn <name>` (iPhone), `-spotlightTapWhenClosed <name>` (Mac) | (testing only) that thing's Spotlight result tapped — taken from what the app handed over and handed to the app as the system does: as it opens / as it comes back to the front / once its last window has closed (§3d) | 0.92 |
| `-spotlightForReal` | (DEBUG, testing only) the device's own Spotlight instead of the memory one, to look at real results on a simulator (§3d) | 0.92 |
| `-importFile <path>` | DEBUG builds only, not testing: import a backup into an EMPTY library at launch | keeps real data out of the repository |

Under testing, `usesICloud` is false, the forecast is `InventedForecast`, the rescue copies are deleted at launch,
reminders never touch the system, grab-list state is not persisted (`GrabStore(persistent: false)`), and these
`UserDefaults` keys are removed so every test starts from the same screen: `ams.table.columns`, `ams.table.sort`,
`ams.table.down`, `ams.table.then`, `ams.table.filters`, `ams.care.view`, `ams.view`, `ams.trip.folded`,
`ams.template.grouping`, `ams.pick.grouping`, `ams.pick.folded`, `ams.reminders`, and (0.76) `ams.create.more` — Create
new trip's More choices, open or closed — and (0.86) `ams.grab.opened`, the iPhone's record of the grab lists opened
(the four under the app icon, spec 02 §13b).

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
- **`travel()`** (`-uiTestingTravel`, 0.76): `make()` + a transport template **"Camper kit"** (role `transport`,
  transport `RV`; an invented name) holding Levelling blocks and Wheel chocks — under Templates → By transport. No
  Plane or Car template; the sample trip stays an ordinary one ("Car"). An RV trip from Hiking is 9 lines.
- **`grabHeadings()`** (`-uiTestingGrabHeadings`, 0.85): `make()` + Outdoor bike (`grab-4`, the factory `bike-out`)
  saved with `saveGrabList(id:lines:)` as he might arrange it: "Check the tyres" above every heading (free text, no
  thing of his), then **On me** (Helmet, Sunglasses, Cycling gloves, Sports watch), **On the bike** (Drink / water
  bottle, Spare tube & pump, iPhone) and **After** (Towel, Recovery drink) — ten things, three headings, invented
  names. Spec 02 §6. (It replaced 0.84's `grabKinds()`, kinds of thing behind Indoor swim, with the grouping by kind.)
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
  **`CURRENT_PROJECT_VERSION` "2"** (local builds; a release overrides the build number — one above the highest App
  Store Connect has, §28).
- **Package** `PackingCore` at `Core/` (Swift tools 5.9; platforms iOS 17 / macOS 14) with products `PackingCore`
  (the port of the web app's `js/model.js` — pure logic) and `PackingLibrary` (the library in memory, records, import,
  backups; depends on PackingCore), the executables `parity` (depends on PackingCore only — public API) and
  `import-check` (PackingLibrary), and the test targets `PackingCoreTests`, `PackingLibraryTests`.
- **Target `AMSPacking`** (application, destinations iOS and macOS): sources `App/Sources`, `App/Resources` (asset
  catalogue: `AppIcon`, `AccentColor`, and since 0.86 the folder `GrabIcons` — the grab lists' pictures under the app
  icon, §19, §30); depends on both library products. Bundle id `<prefix>.AMSPacking`.
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
  scheme needs none (the NFC stickers first planned for this would have; he dropped them on 7 Oct 2026); (0.92)
  NSUserActivityTypes [`com.apple.corespotlightitem`] — `CSSearchableItemActionType`, the activity a tapped
  Spotlight result brings (§3d). Core Spotlight needs no entitlement and no usage text.
- **Target `AMSPackingUITests`** (UI-testing bundle, iOS and macOS), `TEST_TARGET_NAME` AMSPacking, generated
  Info.plist. **Scheme `AMSPacking`**: builds the app; tests `AMSPackingUITests` and the package's
  `PackingCoreTests` AND (0.62) `PackingLibraryTests`. So the two UI jobs of CI and `tools/build.sh test` run both
  model bundles as well (on the simulator / the Mac) — until 0.62 the library's ran only in the `core` job and
  `tools/test-core.sh`. One library test reads its workbook back with the Mac's `/usr/bin/unzip`; on the iPhone
  (no `Process`) that read-back is skipped with `XCTSkip` (`WorkbookTests.run`), the Mac and the `core` job still do it.

## 27. CI on every push (`.github/workflows/tests.yml`)

**Since 12 Oct 2026 the safety net, not the gate.** His decision ("yes, switch to the fast lane"): a release is
checked on his Mac before it goes up — the model, parity and the iPhone smoke set (§28a) — and is uploaded from
there; then the release commit is pushed to main, and THIS workflow runs every test on both devices after the fact.
If it goes red, the next build fixes it. Helper branches cancel the run their push starts (one full suite per
release, on main); the TestFlight workflow (§28b, the fallback) still runs it first, unless the same code is
already green.

"Every push runs the suite — the model's own tests, then the UI tests on the iPhone AND on the Mac … A red run means
the build is not fit to install." Triggers: push, pull_request, manual, and `workflow_call` (the TestFlight workflow
runs it first). Since 9 Oct 2026 a push whose every change is in `.github/workflows/testflight.yml`, `docs/**` or a
`*.md` file starts no suite (`paths-ignore`; such a commit once held all five Mac machines for an hour). Since 0.67 FIVE machines in parallel — `iphone` (3 groups) and `mac` (2 groups); the model's
tests ride in Mac group 1 and the parity check in Mac group 2 (`if: matrix.group == …` steps before the UI tests).
Until 0.67 `core` and `parity` were jobs of their own (seven machines with the groups of 0.65–0.66), and on 0.66's
release one Mac group waited 40 minutes for a free machine. The rows `core` and `parity` below describe those steps:

| Job | Runner | Timeout | What it does |
|---|---|---|---|
| `core` — The model (Core package); since 0.67 steps in Mac group 1 | macos-15 (macos-26 since 0.67) | 15 min (the group's 120 since 0.67) | `cd Core && swift test` (both model test targets); then (0.62) `python3 tools/release-to-testers.py --self-check` — the "What to Test" requests checked without the network (§28); (0.65) `python3 tools/ui-shard.py --check` — every UI test in exactly one group, with each group's minutes |
| `parity` — Parity with the web app's model; since 0.67 steps in Mac group 2 | macos-15 (macos-26 since 0.67) | 20 min (the group's 120 since 0.67) | checks out the web app's repository into `web-app/`, Node 22, `PARITY_MODEL=$PWD/web-app/js/model.js tools/parity/run.sh --invented` (§31) |
| `iphone` — UI tests — iPhone (N of 3) | matrix `group: [1, 2, 3]`, `fail-fast: false`; macos-26, newest Xcode on the runner (since 5 Oct 2026: on macos-15 the tests ran under Xcode 16.4 on an iOS 18 simulator, a pairing no shipped build has, and the template search's ✕ failed there) | 120 min per group (0.65; 180 for the single job in 0.63–0.64, 120 before — 0.63's run on GitHub stopped at 158 of 167 tests) | xcodegen; picks the highest-numbered iPhone simulator that `xcodebuild -showdestinations` offers for the scheme (0.68 — on 0.67's run `simctl` listed an iPhone 17 that xcodebuild then could not find, and group 3 stopped before its first test; the newest iOS on a tie), falls back to `simctl`'s highest-numbered iPhone (`sort -V`), fails if none; boots it and waits (`bootstatus -b`) — a cold simulator once cost the first test 95 s; `xcodebuild test $(python3 tools/ui-shard.py iphone N 3)` — that group's `-only-testing:` lines — with `-collect-test-diagnostics never -test-timeouts-enabled YES -maximum-test-execution-time-allowance 480`, unsigned (`CODE_SIGNING_ALLOWED=NO`); on failure uploads `TestResults-iPhone-N.xcresult` (artifact `TestResults-iPhone-N`); since 9 Oct 2026 run through `tools/ui-test.sh`: when the group goes red, `tools/ui-failed.py` reads the failed tests from the result bundle (`xcresulttool get test-results tests`) and ONLY those are run once more with `xcodebuild test-without-building -only-testing:` on the same build (result `…-N-retry.xcresult`); the job is green only if the retry is; no retry when more than 5 failed, a model test failed, or the run is red with no failed test (build error); every retried test is listed in the job summary and as a warning; on failure or after a retry uploads both result bundles |
| `mac` — UI tests — Mac (N of 2) | matrix `group: [1, 2]`, `fail-fast: false`; macos-26 | 120 min per group (0.65; 180 in 0.63–0.64, 120 before; its own comment since 0.62) | xcodegen; `xcodebuild test $(python3 tools/ui-shard.py mac N 2) -destination platform=macOS`, allowance 300 s per test, signed ad hoc (`CODE_SIGN_IDENTITY="-"`, manual style, no team, no profile — "a Mac app cannot be driven unsigned"); on failure uploads `TestResults-Mac-N.xcresult` (artifact `TestResults-Mac-N`); since 9 Oct 2026 run through `tools/ui-test.sh`: when the group goes red, `tools/ui-failed.py` reads the failed tests from the result bundle (`xcresulttool get test-results tests`) and ONLY those are run once more with `xcodebuild test-without-building -only-testing:` on the same build (result `…-N-retry.xcresult`); the job is green only if the retry is; no retry when more than 5 failed, a model test failed, or the run is red with no failed test (build error); every retried test is listed in the job summary and as a warning; on failure or after a retry uploads both result bundles |

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

## 28. Shipping to TestFlight — the fast lane (`tools/quick-release.sh`) and the fallback workflow (`.github/workflows/testflight.yml`, `tools/release-to-testers.py`, `TESTFLIGHT.md`)

### 28a. The fast lane — the normal path since 12 Oct 2026 (`tools/quick-release.sh`, `tools/smoke-tests.txt`, `tools/ui-split.py`, `tools/ExportOptions.plist`)

His decision (12 Oct 2026, "yes, switch to the fast lane"), as for his Workout Sync app: a finished change reaches
TestFlight in about half an hour instead of about three hours. A short check on his Mac gates the upload; GitHub's
full suite (§27 — every UI test on both devices, ~80 minutes) runs AFTER, on main, as the safety net. If it goes
red, the next build fixes it. Small versions, one change or fix each, shipped when ready.

`tools/quick-release.sh VERSION "notes" [extra UI tests…]` runs on his Mac (Claude runs it; he never needs the
Terminal). `VERSION` e.g. 0.73; `notes` become both builds' What to Test; the extra tests are the changed screens'
own, by name (`testATickCountsAndStays`) or as `-only-testing:` ids — each checked against the test file first, as
a misspelt name would quietly run nothing. bash, `set -euo pipefail`. Every stage is timed and printed in plain
words; the first failure stops everything with `STOPPED at "<stage>": <why>` and the times so far (an `EXIT` trap
says the same for any other failing command). The stages:

1. **Ready?** — xcodebuild, xcodegen, node, gh, python3, git and the private helpers (below) are there; `git fetch`;
   the checkout is clean; `origin/main` is an ancestor of HEAD (main can fast-forward to it); the newest What's new
   entry (`Releases.swift`) is VERSION — otherwise "What's new leads with X, not VERSION", before any test runs.
   When project.yml still says another version it is set to VERSION, and with the regenerated project that is the
   release commit "AMS Packing VERSION" (project.yml, the project, the generated entitlements and Info.plist — any
   other change stops it). Extended attributes are cleared (never inside .git), xcodegen runs, and
   `tools/check-spec.sh` must pass (§28b step 0).
2. **Model tests** — `tools/test-core.sh` (both bundles).
3. **Parity** — `tools/parity/run.sh --invented` (§31) with the web app's model beside the MAIN checkout
   (`../AMS Packing/js/model.js`, or `PARITY_MODEL`): it must end "differences: none".
4. **iPhone build** — ONE `build-for-testing`, unsigned like GitHub's iPhone job, into
   `$TMPDIR/AMSPacking-quick-<8 hex of the checkout path>` (outside Documents, kept between runs), for the first test
   simulator. **Since 14 Oct 2026 the tests run on simulators of their own, side by side** (his ask: "can we deploy
   more agents to speed things up?"; measured below). `PACKING_SIM` (default "Packing CI iPhone 18 Pro") is no longer
   tested on: it is the MODEL — its device type and iOS runtime — for `PACKING_SIM_COUNT` (1–9, default 3)
   simulators named "Packing CI fast 1" … "Packing CI fast N", made with `simctl create` when missing (one made like
   an older model or iOS, or a second of the same name, is deleted and made again). They are kept between runs and
   left booted, and they start (`bootstatus -b`, in the background) while the app builds. They are not erased: every
   test launches the app with an invented library held in memory (`-uiTesting`), so nothing carries over from one
   run to the next — the single simulator before them was never erased either; `PACKING_SIM_ERASE=1` erases them
   first. Several sessions release side by side and two test runs on one simulator kill each other, so the script
   TAKES them: a lock folder `$TMPDIR/AMSPacking-fast-sims.lock` holding its process id (another fast lane waits; a
   holder that is gone, or whose number now belongs to a program that is not quick-release.sh, leaves it free, and so
   does one without an id that is older than a minute), then no other `xcodebuild` may name one of them (someone's
   own run by hand) — waited for up to `SIM_WAIT_MIN` (30) minutes in all. The lock is given back after stage 5, or
   by the `EXIT` trap however the script ends. The build's own `.xctestrun` (the newest
   `Build/Products/*iphonesimulator*.xctestrun`: its products and the scheme's test settings) is what every
   simulator's run starts from.
5. **iPhone tests** — the smoke set and the extras (each test once) shared out over the simulators by
   `tools/ui-split.py split`: longest first, each to the simulator with the least so far. A test's cost is what it
   took on THIS Mac — the median of its last three passing runs (`$TMPDIR/AMSPacking-ui-times-local.json`, each
   test's last three seconds, added after every run by `ui-split.py record` — outside the repository; a file from
   before holds a single number per test and is read the same way) — else its GitHub time (`tools/ui-test-times.json`) scaled by how
   this Mac compares on the tests both know, else the median. The warm-up `testAAAWarmsUpTheSimulator` goes to EVERY
   simulator (each one's first launch is the slow one). The plan is printed ("simulator 1: 17 tests, about 9.5 min").
   Each simulator is put in day mode (`simctl ui … appearance light`; night mode is looked at by hand, §32), then all
   run at once, each `xcodebuild test-without-building -xctestrun <the build's> -destination <its id>
   -only-testing:… -collect-test-diagnostics never -test-timeouts-enabled YES -maximum-test-execution-time-allowance
   300` with its own result bundle `smoke-<n>.xcresult` and log `iphone-tests-<n>.log`. Then one line from the
   bundles: "34 passed, 0 failed, 0 skipped — Packing CI fast 1: 17 in 12 min 54 s · Packing CI fast 2: 17 in 14 min
   4 s" (the warm-up counts once per simulator). A red simulator → `tools/ui-failed.py` on its bundle, as on GitHub
   (§27): a red run with no failed test (build error, hung runner) stops the release; more than 5 failed over all the
   simulators together is a real break and stops it; otherwise ONLY the failed tests run once more, shared out the
   same way (`smoke-retry-<n>`, `iphone-tests-retry-<n>.log`), and must pass ("red twice: …" stops it; "green on the
   retry (flaky — worth a look)" is printed). Last, checked not trusted: `ui-split.py unpassed` — every test must
   have passed (or skipped itself, as a Mac-only test does on the iPhone) in one of the bundles, else "these tests
   never passed — did a test runner stop half way?" (a runner that dies half way leaves tests that never ran, which
   a retry of only the FAILED ones would not notice). A test still running when the script stops is ended with it.
   Xcode's own parallel testing (`-parallel-testing-enabled YES`) is not used: it shares out test CLASSES between its
   clones, and every UI test is in the one class `AMSPackingUITests`; it also makes and deletes its clones on every
   run.
6. **Build number** — one above the highest build App Store Connect has for the app (any version, either platform):
   Apple refuses a repeated number, and a Mac build lower than the last. The workflow counts on the same way (§28b
   step 6).
7. **Certificates** — counts the "Created via API" development certificates (every GitHub archive of his apps mints
   one; at about a dozen, signing stops). At `CERT_NEAR` (7) or more, `revoke-api-certs.sh` revokes them — his
   standing OK, 9 Oct 2026; never the one with his name. A dry run only says so.
8. **Archive** — the workflow's ship entitlements (§28b step 4), made the same way into the run's folder, not into
   App/Config. `xcodebuild archive` for `generic/platform=iOS` and `generic/platform=macOS` with
   `-allowProvisioningUpdates` and Xcode's own account (no API key): `DEVELOPMENT_TEAM` from ExportOptions.plist,
   automatic signing, the matching entitlements file, `PACKING_USES_ICLOUD=YES`, VERSION and the build number;
   derived data `$TMPDIR/AMSPacking-archive-<8 hex>`. Each must log "** ARCHIVE SUCCEEDED **" and its Info.plist
   must say "VERSION (BUILD)". Then the signed app's entitlements (`codesign -d --entitlements - --xml`): the iPhone
   needs Apple Health (`com.apple.developer.healthkit`), the container `iCloud.com.schabbauer.AMSPacking`, CloudKit
   and `aps-environment`; the Mac the container, CloudKit, the sandbox, `com.apple.security.network.client` and
   `com.apple.developer.aps-environment`. One missing stops the release ("MISSING: Apple Health (…)"). A signing
   error about the account says what to do in plain words: Xcode ▸ Settings ▸ Accounts, sign in.
9. **Upload** — `xcodebuild -exportArchive -exportOptionsPlist tools/ExportOptions.plist -allowProvisioningUpdates`
   for each archive: method app-store-connect, destination upload, the team, automatic signing (the cloud-managed
   distribution certificate), symbols uploaded, `manageAppVersionAndBuildNumber` false. The script waits on it with
   its progress lines shown as they come; when it says nothing for `EXPORT_IDLE_MIN` (10) minutes it is stopped (a
   background export once hung silently on "The Internet connection appears to be offline" — Workout Sync, 14 Sep
   2026). A hang or a dropped connection gets ONE more try after 30 s, then it stops with a plain message. Each must
   log "EXPORT SUCCEEDED".
10. **Testers** — done by the script itself in Python, which calls `asc.py` with an argument list (no shell in
    between); the group id is read from `ensure-group.sh`, which is no longer run. (a) Every 30 s, up to
    `TESTERS_WAIT_MIN` (90) minutes: the builds numbered BUILD with their version and Apple's beta state
    (`include=preReleaseVersion,buildBetaDetail`); a line is printed when the state changes ("build 96: iPhone
    VALID (IN_BETA_TESTING), Mac VALID (…)"). It goes on when the iPhone AND the Mac build are VALID and their
    `internalBuildState` is past PROCESSING; a build of another version ("build 96 is version 0.74 … not 0.73") or a
    processing that ended FAILED/INVALID stops it. (b) What to Test FIRST, so the testers' notice carries it: read
    for each build; written only when Apple's record is empty (PATCH) or missing (POST) and notes were given.
    (c) The tester group read in full (every page, `links.next`); each build not in it added (`POST
    /v1/betaGroups/<id>/relationships/builds`, `{"data":[{"type":"builds","id":…}]}`); a refusal is printed with
    Apple's own code and reason and tried again every 30 s for 15 minutes. (d) Checked, not trusted: the group read
    back (up to 7 times, 10 s apart) until both builds are in it, else it stops with "… run tools/quick-release.sh
    --testers-only VERSION BUILD later". Fewer than 2 builds with What to Test only warns. A build already in the
    group with its notes is only read — nothing is written.
    **Why (12 Oct 2026):** the stage failed on both of that day's real runs (0.73 build 95, 0.74 build 96: "reached
    the tester group 0 time(s) of 2") although the same add by hand answered 204 at once. `ensure-group.sh` wrote
    the add's JSON inside `echo "… adding — $(… "{\"data\":[{\"type\":\"builds\",\"id\":\"$id\"}]}" …)"`;
    macOS's bash 3.2 brace-expands the `{…,…}` in it, so `asc.py` was called twice with broken bodies
    (`{"data":["type":"builds"]}` and `{"data":["id":"…"]}`) and Apple answered 400 to both — the fingerprint is the
    doubled log line "MAC_OS 96: adding — 400 MAC_OS 96: adding — 400". Its notes went in (their body was built in
    Python). The helper is still broken when run by hand; `--testers-only` replaces it.
11. **Main** — `git fetch`; when main moved meanwhile it stops ("the builds ARE in TestFlight … merge origin/main and
    push by hand"); otherwise `git push origin HEAD:main`, then it prints the "Tests" run GitHub starts on that
    commit (`gh run list --workflow tests.yml --commit`, up to 3 minutes): the full suite, after the fact.

At the end: the time of each stage and all together.

**`--dry-run [VERSION] [extra tests…]`** — every stage but the upload, on the version in project.yml (another VERSION
stops it); uncommitted changes and a main that moved on are only noted; nothing is committed, revoked, released or
pushed. Stage 9 exports with a copy of ExportOptions.plist whose `destination` is `export`, so the App Store signing
really happens; the exported `.ipa` (unzipped) and `.pkg` (`pkgutil --expand-full`) are checked for the same
entitlements, and who signed each is printed. Stage 10 only reads the tester group; stage 11 says whether main could
fast-forward.

**`--testers-only VERSION BUILD ["notes"]`** — stage 10 alone, for builds already uploaded: a Testers stage that
stopped is run again with it (it replaces running `ensure-group.sh` by hand). BUILD must belong to VERSION; the
notes, when given, fill an empty What to Test. Nothing else runs — no checkout check, test, archive, commit or
push; the folder is `<version>-<date-time>-testers`. Proven on 12 Oct 2026 against 0.74 build 96, already in the
group with its notes — read only, nothing written, 7 s:
`build 96: iPhone VALID (IN_BETA_TESTING), Mac VALID (IN_BETA_TESTING)` · `iPhone 96: What to Test is there` ·
`Mac 96: What to Test is there` · `iPhone 96: already in the tester group` · `Mac 96: already in the tester group`
· `done — 7 s · build 96 — iPhone and Mac — in the tester group, What to Test on 2`. The refused-then-added path
(a 409 first, then 204), the wait through PROCESSING and the group's second page were run against a stand-in
for `asc.py`.

**`--tests-only [extra tests…]`** (14 Oct 2026) — stages 4 and 5 alone, on the checkout as it is: "Ready?" only
checks xcodebuild, xcodegen, python3 and git and runs `xcodegen generate` (uncommitted changes are allowed and named,
no `git fetch`, no version or spec check); then the build and the tests on `PACKING_SIM_COUNT` simulators, timed, with
the same retry and checks; the folder is `<version in project.yml>-<date-time>-tests`. No build number, certificate,
archive, upload, commit or push. For timing the test stage, and for the fast lane's verdict on a branch before it
ships. `-h` / `--help` prints the script's own help (its header) at any time.

**Where things go** — `$TMPDIR/AMSPacking-release/<version>-<date-time>[-dry|-tests]/`: the logs (per simulator:
`iphone-tests-<n>.log`, `smoke-<n>.xcresult`, and `-retry-<n>` for a retry; the share-out in `split.txt` and its plan
in `split-plan.txt`), the ship entitlements, the archives, the export. All of it outside `~/Documents` (codesign
refuses the extended attributes that folder collects). This Mac's test times: `$TMPDIR/AMSPacking-ui-times-local.json`;
the simulators' lock: `$TMPDIR/AMSPacking-fast-sims.lock`.

**The private helpers** — `private/release-tools/` of the MAIN checkout (git-ignored; found from a worktree too, or
named in `RELEASE_TOOLS`): `asc.py` (App Store Connect with the Admin key; the issuer id is read from a note outside
the repository), `ensure-group.sh` (the tester group's id is written only there — the script only READS it for
that id, `G=<36 characters>`), `revoke-api-certs.sh`. They are called, never copied into the repository.
`revoke-api-certs.sh` names `asc.py` by a folder of its own and calls it unquoted, so the script runs it from a
temporary folder without spaces that links to `asc.py`.

**The smoke set** (`tools/smoke-tests.txt`) — one test per line, the comment line above it saying what it guards;
`#` lines are ignored. Chosen on 12 Oct 2026 from the test names and `tools/ui-test-times.json` — the main flows,
quick tests preferred — and timed on his Mac: the warm-up `testAAAWarmsUpTheSimulator` and 20 checks. Start and Home: `testStartsOnHomeAndNamesItsVersion`, `testAnEmptyDeviceShowsTheTwoDoors`, `testEveryTabOpensItsScreen`, `testHomeCountsDownToTheNextTrip`; making a trip: `testHomeBuildsATrip`, `testCreateNewTripTakesTheTimeHeLeaves`; ticking and unticking: `testATickCountsAndStays`, `testAWholeSectionIsTickedInOnePress`; templates: `testATemplateOpensAndCloses`, `testAThingAddedToATemplateStays`; a thing's page saved (its kind chosen from a drop-down): `testAThingsOwnDetailsAndItsListsAreChanged`; the review: `testATripReviewIsSavedAndTheMissedThingIsFiled`; a drop-down: `testTheTripSaysSortingBesideItsDropDown`; bags and kits: `testABagSaysWhetherItGoesInTheCabin`, `testYourBagsShowsANumberChangedOnTheBagsPage`, `testAKitIsOneLineOnATripAndWeighsWhatIsInside`; To do: `testAToDoIsAddedAndTicked`; backup and restore: `testSettingsOffersABackup`, `testARestoreShowsWhatTheFileHoldsAndThenReplacesEverything`; What's new: `testWhatsNewStartsWithThisVersion`. `testThePickOneListsAreDropDownsThatChooseAndKeep` was in the first draft and took 162 s of the 10 minutes alone; the trip's Sorting drop-down (44 s) took its place. No dark-mode test exists (night mode is looked at by hand,
§32), so none is in the set.

**The first dry runs** (12 Oct 2026, main at `13c8082` = 0.72, build 95 would have been next; on the simulator
"Packing CI fast", his Mac busy with other sessions' builds). Cold — new build folders, the draft smoke set with the
162-second test: Ready? 2 s · Model tests 50 s · Parity 1 min 12 s · iPhone build 1 min 22 s · iPhone tests 10 min 6 s
(21 passed) · Build number 2 s · Certificates 1 s · Archive 4 min 49 s · Export 56 s · Testers 2 s · Main 0 s —
19 min 22 s. Warm, with the final set: 1 s · 6 s · 24 s · 3 s · 7 min 58 s (21 passed) · 2 s · 1 s · 4 min 8 s · 56 s ·
1 s · 1 s — 13 min 41 s. Both exports were signed "Apple Distribution" (the Mac installer "3rd Party Mac Developer
Installer"), with push set to production, iCloud, and Apple Health on the iPhone; Xcode's account signed without
asking him for anything. A real run uploads instead of exporting, then waits for Apple's processing (usually 5–30
minutes) before the testers have it.

**Side by side, measured** (14 Oct 2026, `--tests-only` on 0.79's release commit `2cb447e`: the 21 smoke tests and
0.79's 12 extra ones, 33 in all; warm build; his M1 Max, 10 cores, 64 GB, shared all the while with other sessions —
2 to 6 other `xcodebuild` runs and 7–9 booted simulators). Stage 5 ("iPhone tests"), two rounds:

| Simulators | Round 1 (08:19–08:55) | Round 2 (12:03–12:42) | Each simulator (round 2) |
|---|---|---|---|
| 1 | 25 min 17 s | 19 min 34 s | 33 tests in 19 min 31 s |
| 2 | — (see below) | 10 min 56 s | 17 in 10 min 52 s · 17 in 10 min 50 s |
| 3 | 9 min 36 s | **8 min 22 s** | 11 in 8 min 12 s · 12 in 7 min 45 s · 12 in 8 min 0 s |

For comparison, 0.79's real release that morning ran the same 33 on the one simulator in 19 min 10 s. Every run was
green on its first try, no retry. Three is the default: about 2.3–2.6 times as fast as one; going from two to three
still saves about 2½ minutes, though less than from one to two (each simulator's own start — its test runner and
the warm-up — is paid once per simulator). Round 1's run with two simulators is not counted: it took 132 minutes,
every test in it from about 09:05 on 15 to 40 times its usual length (`testWeighOpensByItselfOnceAndWeighsOneBagAfterAnother`
2 548 s) while the Mac was starved by something outside the run — and still passed; a first run with two at 07:59,
under the same heavy load, took 14 min 8 s. That one run is why `ui-split.py` keeps the median of a test's last
THREE times, not the last one: one starved run cannot skew the next split. More than three was not measured.
The retry was proven the same day with two tests made to fail the first time only (a marker file, never committed),
which landed on two different simulators: "33 passed, 2 failed" → "failed, so run once more: …" → one test on each of
two simulators, "2 passed" → "green on the retry (flaky — worth a look)", the stage green in 7 min 40 s.

### 28b. The fallback — the TestFlight workflow

Since 12 Oct 2026 the FALLBACK — for when his Mac cannot release (§28a). Started by hand (Actions → TestFlight → Run
workflow) with an optional `notes` input ("What is new in this build — testers see it as "What to Test""). "A red suite must never reach a
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
4. Entitlements for a build that ships: from the iCloud file, `Development` → `Production` and `development` →
   `production` (`AMSPacking-Ship.entitlements`, Mac); a copy with the push key renamed to the iPhone's
   `aps-environment` (`AMSPacking-Ship-iOS.entitlements`) — with only the Mac's name the iPhone never got iCloud's
   "something changed" notice (his test A.4, 2026-09-28; fixed in 0.44). Both are grep-checked.
5. Writes the key file (CR stripped, blank lines dropped, mode 600) and verifies its BEGIN/END lines and that
   `openssl pkey` reads it.
6. Numbers the build: `APP_VERSION` = `MARKETING_VERSION` read from project.yml (fails if absent); `BUILD` = one
   above the highest build App Store Connect has for the app, and never below the workflow's run number
   (`release-to-testers.py --next-build` with `MIN_BUILD` = the run number; it needs the key, so since 12 Oct 2026 this
   step comes after step 5). The fast lane (§28a) numbers its uploads from App Store Connect, so the run number alone
   would repeat a number Apple has seen — refused, and a Mac build may not be numbered lower than the last. When App
   Store Connect cannot be asked, the run number, with a warning. (Until 12 Oct 2026: the run number alone, as step 4.)
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
   GET → POST / PATCH / 409 conversation against a pretend App Store Connect, without the network — and (12 Oct 2026)
   the next build number of step 6: above every number Apple has, never below the run number. 🪤 0.27 (build 33): the old loop gave up after 5 minutes with one build and the Mac
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
- **`tools/release-to-testers.py`** — §28b; `--next-build` prints the next build number (§28b step 6).
- **`tools/quick-release.sh VERSION "notes" [extra UI tests…]`**, **`--dry-run`**, **`--tests-only`** and
  **`--testers-only`** — the fast lane to TestFlight from his Mac (§28a); **`tools/smoke-tests.txt`** — the iPhone UI
  tests it runs before every upload (§28a); **`tools/ui-split.py`** — shares those tests out over the simulators that
  run them side by side (`split N LOCAL.json test…`), keeps this Mac's times (`record LOCAL.json RESULT.xcresult…`)
  and names the tests that passed in none of the bundles (`unpassed RESULT.xcresult… -- test…`) (§28a stage 5);
  **`tools/ExportOptions.plist`** — how it exports and uploads (method app-store-connect, destination upload, team,
  automatic signing, symbols, the build number left alone).
- **`tools/grab-icons.sh`** (0.86) — draws the pictures the grab lists wear under the app icon (spec 02 §13b) into
  `App/Resources/Assets.xcassets/GrabIcons` (rewritten whole): GrabDoodle is copied out of `Screens/GrabScreen.swift`
  (from its `struct` line to the brace that closes it at the start of a line) and compiled with `SVGPath.swift` and
  `tools/grab-icons/main.swift`; each picture is a 35 × 35-point PDF, template rendering — the six doodles stroked
  4.5 of 64 units with round ends inside a 2-point margin, `grab-initial-<hex>` for A–Z, Å Ä Ö Ü and 0–9 in the
  system font, heavy, 23 points, centred, and `grab-list`, the Home tab's suitcase (stroke 1.9 of 24 units). Run it
  after a doodle changes, and commit the pictures.
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
| `scrollWithin(screen, until:, tries: 10)` | scrolls the TALLEST scroll view INSIDE a named sheet (`tallestList(in:)`), never the screen behind it. Until 0.79 the first one: a trip's Packing day row (a sideways strip of station chips on the iPhone) comes before its list, and swiping the strip up moved nothing — five red tests in one local run. |
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
0.92, Cancel everywhere (§20a): `testCancelOnATemplatePutsItBackAndDoneKeepsIt`,
`testCancelOnYourChoicesPutsItBackAndDoneKeepsIt`, `testCancelWhileEditingAGrabListPutsItBack`,
`testCancelOnTheDeskAndTripSettingsPutsItBackAndSaveKeepsIt`; model `PageChangesTests`;
0.67: `testSettingsDoorsAreRowsOfOneCard` (§1), and the lines without air of §21 — `testATripsLinesSitTightUnderTheirHeadings`
(spec 03), `testATemplatesRowsSitTight` (spec 04), `testToDoAndToBuyLinesSitTight` (spec 05),
`testAGrabListAndItsTilesAreSmall` (spec 02) — whose limits are the test file's `tightLine` (30 / 22), `tightTile`
(36 / 26) and `doorPitch` (52 / 46), measured top to top by the helpers `rowFrames` and `pitch` (the rows on screen,
by `shownRow`) and `airAbove` (a heading to the bottom of the row above it). 0.79:
`testHowItWorksExplainsThePackingDayStations` (§7, the Packing day's part; the Packing day's own tests are in spec 07
part 17). 0.90: `testHowItWorksSearchShowsOnlyWhatSaysTheWords` (§7a). 0.92: `testASpotlightResultOpensItsThingsPage`,
`testSettingsTakesHisThingsOutOfSpotlightAndPutsThemBack` (§3d).

Model: `SettingsListsTests` (14 since 0.62), `SharedRowsTests` (26), `PresetsTests` (5), `PhasesTests` (12),
`ItemConditionsTests` (6), `PeopleTests` (8), `HealthTests` (5), `PhotoTidyTests` (4 since 0.62), `BackupTests` (library, 5),
(0.92) `SpotlightThingsTests` (10, spec 05 "Your things in Spotlight"),
`RestoreTests` (3), `SyncCheckInTests` (1), `CountdownTests` (4), `ContrastTests` (3), (0.90) `GuideSearchTests` (5,
§7a); and (0.62)
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
33. [idea] **The fast lane checks the Mac only by building it** (12 Oct 2026, §28a): before an upload the UI tests run
    on the iPhone simulator alone (Mac UI tests are not run on his Mac); the Mac archive proves the Mac app builds and
    carries its entitlements, but a break only the Mac's UI shows reaches TestFlight and turns GitHub's suite red
    after the fact (§27) — fixed by the next build, by his choice.
