# Templates — the building blocks, and how things sit on them

> Verified against the code on 5 Oct 2026 (app 0.60).

**What this part is for, in the owner's terms.** A *template* is a building block: the things for one activity
or need — Hiking, Swim, Car, the Common base. A trip's packing list is *made from* templates: the always-packed
base template(s), the transport template that matches the trip's transport, and the activity templates ticked on
Create new trip (Quick mode: only the ticked ones). The word "template" is used everywhere since 0.34
(27 Sep 2026: "The app says Templates for the building blocks your trips are made from … 'List' now means only the
list you pack from, and grab lists"). The group a template lives in is its **activity area** (GA · Goal Activity,
WET · Workout, Exercise & Training, OE · Other Events) — the word replaced "shelf" in 0.56 (3 Oct 2026, field
test: "Please change the word 'shelf' throughout the app and call it 'Activity area.' We understand that word
much better.").

A template holds **rows**. A row is a **membership**: the link between ONE *thing* (a catalogue item, shown in
Care → Your things) and ONE template, carrying what *this template* says about the thing (its bag here, its "When"
here, its section, how many, a note, and "Only on some trips" conditions). A thing exists once; it can sit on many
templates, and even twice on one template (e.g. a different "When" each time). Taking a row off a template or
deleting a template **never deletes a thing**.

**How one reaches it.**
- The **Templates** tab (third tab; `tab-templates`, screen container `screen-templates`; violet `#7c5cd6`).
- The magnifier (Search) on the Templates tab and other tabs → a result under "Templates" opens the same template
  page (`TemplateDetail`) — see the Search spec.
- Settings → **Open a shared link** → a shared template is added or replaces one of his.
- Settings → **Your choices** (`ListsScreen`, documented here because it lives in `ListsScreen.swift`).
- There is no Shortcut / App Intent and no URL handler for templates (`Shortcuts.swift` has only grab-list and
  next-trip intents; no `onOpenURL` exists — a `#/l/` link opens the web app; in-app only by pasting).

**Files covered.** `App/Sources/Screens/TemplatesScreen.swift` (Templates tab, `TemplateCard`, `Cover`, `IconMark`,
`CoverDoor`, `IconPickerScreen`, `TemplateDetail`, `RowEditor`, `Color(hexString:)`), `App/Sources/TemplateIcons.swift`,
`App/Sources/Screens/NewList.swift`, `App/Sources/Screens/PickThings.swift`, `App/Sources/Screens/ListsScreen.swift`;
model: `PackingCore/Lists.swift`, `Memberships.swift`, `Resolve.swift`, `Grouping.swift`, `Kits.swift`,
`ListSharing.swift`; `PackingLibrary/Library.swift` (template parts), `EditLists.swift`, `Bags.swift` (list role and
`shownName`), `TemplateIcon.swift`, `TemplatePicking.swift`, `TemplateUse.swift`, `ThingFollows.swift`,
`Sharing.swift` (template parts). Storage and sync are in `docs/store.md`; colours in `docs/colours.md` (both
linked, not repeated).

---

## 0. The data shape in one page (read first)

| Library field | What it holds | Record (`docs/store.md`) |
|---|---|---|
| `items: [Item]` | The catalogue: one item per physical thing. | table `items`, key = item id |
| `memberships: [Membership]` | One per row of a template (thing ↔ template). | table `memberships`, key = membership id, **parent = templateId** |
| `templates: [PackList]` | Template *shells*: name, cover, sections, group, role… with `items == []`. | table `templates`, key = template id; written with `items` emptied |
| `kits: [Kit]` | Bundles of thing ids (data only in this app). | table `kits` |

- A template "with its things" is always **resolved on demand** (`Library.resolved(_:)`, `resolvedTemplate(id:)`,
  `resolvedTemplates()`): each membership + its item → one row (`Item`) stamped with `itemId` (the thing) and
  `memId` (the membership). 🪤 A resolved row's `id` is the **thing's** id, so two rows of the same thing share
  it; rows are always told apart by **`memId`**.
- Every change goes through `LibraryModel.change { … }`: the closure edits a copy of the `Library`; the whole
  library is cut into records (`Library.records()`), only the differing records are written to the store
  (`recordChanges`), and SwiftData/CloudKit carry them to the other device. Nothing in this area writes the store
  directly.
- `extra` on a template / membership keeps unknown JSON keys for round trips; the reserved sync keys `owner` and
  `realmId` are always dropped (`extraKeys` + `RESERVED_SYNC_KEYS`; pinned by
  `ListsTests.testAListRoundTripsThroughJSONAndCarriesUnknownKeys`).
- The template's chosen icon is stored in the template's `extra["iconKey"]` (see §3).

---

## 1. The Templates tab (`TemplatesScreen`)

### Purpose and origin
"Your templates": every template, grouped "the way he organises his life — always packed, by transport, then his
activity groups" (code comment). A card per template, two across, "as the web app shows them". The "+ New" button
(0.15, 25 Sep 2026: "name a list and choose its shelf"), the Refine door (roadmap stop E, his test F.6), and the
magnifier.

### How it is reached and left
- Reached: tab `tab-templates`. Left: any other tab.
- When the library state is `.empty` (nothing at all on the device), the tab does **not** show this screen: it shows
  the placeholder — the Templates mark (a list drawing) 96 pt in violet and the word "Templates" (34 heavy ink,
  id `screen-title`). Nothing is ever seeded (`docs/store.md` rule 1); pinned by
  `testAnEmptyDeviceShowsTheTwoDoors` (no `template-row-0`).
- When the library failed to load: the error text in red (`library-problem`) instead.

### What is on screen (top to bottom), inside a `KeyboardAwayScroll` (a ScrollView that dismisses the keyboard on drag) with a `LazyVStack(spacing: 8)`, side padding 16, bottom 24
1. **Header row** (top padding 14, bottom 4):
   - "Your templates" — 28 heavy, violet (`AppSection.templates.color`), id `templates-heading`.
   - Under it the **summary** — 15 medium, `Theme.muted`, id `templates-summary`:
     `"<T> template(s) · <N> thing(s)"` plus `" · <K> trip(s) packed from them"` only when K > 0. Singular when the
     number is 1. T = the number of templates shown on this screen (bag list and "loose" lists excluded);
     N = `library.items.count` (ALL things, including bags and things on no template); K = `library.trips.count`
     (ALL trips, whichever templates they used). Separator " · " (U+00B7).
   - The magnifier `SearchButton` (24 pt drawn magnifier in a 40×36 hit area, muted, id `search-open`,
     label "Search everything") → opens `SearchScreen` as a sheet.
   - "+ New" — 15 heavy white on a violet capsule, min height 36, horizontal padding 14, id `templates-new` →
     opens `NewList` (§5) as a sheet.
2. **Refine door** (`RefineDoor`, id `refine-open`, bottom padding 4): violet card "Refine your templates" with a
   count of waiting suggestions; owns its own sheet (`RefineScreen`). Documented in the Refine spec.
3. For each **activity area** (see Behaviour) in order:
   - Heading — `areaHeading`: `groupHeading(code, title)` = `"<CODE> · <TITLE IN CAPITALS>"` for a GROUP, otherwise
     just the title in capitals: "ALWAYS PACKED", "BY TRANSPORT", "GA · GOAL ACTIVITY",
     "WET · WORKOUT, EXERCISE & TRAINING", "OE · OTHER EVENTS", "OTHER TEMPLATES". 18 heavy, `Theme.ink`, kerning
     0.8, top padding 20 ("Much larger headings", his H.13). id `templates-area-<id>` where id is `base`,
     `transport`, `GA`, `WET`, `OE` or `other`.
   - A `LazyVGrid` of two flexible columns (spacing 8 both ways) of **cards** (§2). Each card is a plain Button;
     id `template-row-<n>` where n = the template's index in the flattened list of all areas, top to bottom
     (so with the sample library: 0 = Common base, 1 = Hiking, 2 = Swim). Tap → opens `TemplateDetail` (§6) as a
     sheet (`sheet(item:)`, `PackList` made `Identifiable` by its `id`).
- No empty-state text: a ready library with no templates shows the header, the summary "0 templates · …" and the
  Refine door only.

### Behaviour
- `activityAreas(all)` takes `library.resolvedTemplates()` (every template resolved, sorted A–Z with
  `jsLocaleCompare` default sensitivity) and builds, **omitting empty areas**:
  1. `base` "Always packed" — templates with `role == "base"` (A–Z).
  2. `transport` "By transport" — `role == "transport"` (A–Z).
  3. For each GROUP in `GROUPS` order (GA, WET, OE): templates with `role == ""` and `group == id`, ordered by
     `orderActivities(groupId, …)` — only WET has a fixed order (`ACTIVITY_ORDER["WET"]` = Swim, Bike, Run,
     Strength, Mobility, Breath work, matched by `normName`); unknown names follow A–Z; GA/OE keep the A–Z input.
  4. `other` "Other templates" — `role == ""` and `group == ""`.
  - Templates with role `container` (the bag list, "Containers"/"Bags") and `loose` (the web app's retired "Loose
    items" bin) appear in **no** area: "Bags are not an activity: they have their own screen, on Care".
  - A base or transport template that also has a group is shown only under Always packed / By transport.
- The template's stored field is still `group`; only the shown word changed ("activity area").
- Every render recomputes `resolvedTemplates()` and `templateUse()` (§16).
- `NewList` hands back the new template → `model.change { saveTemplate(list) }` → `open = list`, so the new
  template's page opens straight away ("a list he cannot see the inside of is not made yet").

### Data
Reads `library.templates`, `memberships`, `items`, `trips`. Writes only via `saveTemplate` (new template). Sheets:
template page, Search, New — three `.sheet` modifiers on the same scroll view.

### iPhone vs Mac
Same layout on both. On the Mac the whole app column is at most 720 wide (`RootView`), so cards are wider; sheets
appear as Mac sheets with the minimum sizes given per screen below. No keyboard shortcuts are declared anywhere in
this area (no `.keyboardShortcut`, no `.onExitCommand`), so Return/Escape have no app-defined meaning beyond a
text field's `onSubmit`; on the iPhone every sheet here can be swiped down (no `interactiveDismissDisabled`).

### Tests
- UI: `testEveryTabOpensItsScreen`; `testATemplateOpensAndCloses` (row-0 and row-2 exist — three sample templates;
  `templates-area-GA` reads "GA · GOAL ACTIVITY"; summary contains "templates"; a card opens `template-detail`,
  Done closes it); `testAnEmptyDeviceShowsTheTwoDoors`; `testHeMakesAListOfHisOwn` (heading reads "Your templates");
  `testRefineOffersWhatTheReviewsFoundAndKeepAndDropSettleIt` and `testTheLoopShowsWhereATripStands` (use
  `refine-open` here).
- Model: `ListsTests.testOrderActivities*` (4 tests); `CreateTripTests.testTheChoicesAreHisGroupsInHisOrder`.
- **Not covered:** the "By transport" and "Other templates" areas, the exact summary wording with trips, the
  exclusion of bag/loose lists from the tab.

### Traps and history
- "15 lists · 431 things · 4 trips packed from them" in the code comment predates the word change; the code says
  "templates".

---

## 2. A template card (`TemplateCard`)

### What is on screen
A card (`RoundedRectangle(12)` filled `Theme.card`, 1-pt `Theme.line` stroke, padding 10, min height 104, full
column width, whole card tappable):
1. Row: the **cover** (§3) at 34 pt · spacer · the number of rows on the template (`list.items.count`, i.e.
   memberships whose thing exists — a thing twice counts twice) 15 heavy monospaced digits, muted.
2. The template's **name** — 16 semibold, ink, at most 2 lines, wraps.
3. The **"used" line** (`lastTaken`) — 12 medium, one line, id `template-used`; muted, or muted at 65 % opacity
   when the template has never been used ("Quiet, not invisible: the divider colour could not be read on either a
   white or a black background").

### Behaviour — `TemplateCard.lastTaken(use)`
- No use record, or `use.trips == 0` → "Never taken along".
- `use.lastTrip` empty (every trip that used it has no start date — or the latest dated one has an empty
  name) → "Taken on <n> trip(s)".
- Otherwise `ago = countdownLabel(daysUntil(use.lastDate, Today.local))` (Today.local = the device's local
  `yyyy-MM-dd`): "Today", "Tomorrow", "Yesterday", "in <d> days", "<d> days ago". The line is
  `"<ago> · <trip name>"` ("the WHEN first: it is the part that is always worth reading, and the part that still
  shows when a long trip name is cut off"), or `"Last: <trip name>"` if `ago` is empty (unreadable date).
- Because `lastDate` is the **latest start date**, a trip still ahead counts: the sample shows
  "in 30 days · Weekend in the hills".

### Tests
- Model: `TemplateUseTests` (§16). **Not covered:** `lastTaken` wording, the 65 % opacity, the count.

### Traps
- A card's texts are children of a Button; the Mac and the iPhone report a button's child texts differently, so the
  UI tests read a template's name from the open page's name field instead (`testAListIsRenamedAndAnotherIsDeleted`).

---

## 3. The cover and the template icons (`Cover`, `IconMark`, `CoverDoor`, `TemplateIcons`, `TemplateIcon.swift`)

### Purpose and origin
His test H.1. 50 icons "of my own, drawn in the app's style (one stroke, round ends, a 24-point box)"; he saw them
on a sample sheet in day and night mode and said (2 Oct 2026): "Your suggestions are fine. Please implement."
Released in 0.46. No stock art, no emoji in the icon set.

### `Cover(list, size = 40)` — what is drawn
- A rounded square (`cornerRadius = size × 0.28`) filled with **`listColor(list)`**: the template's own `color` if
  it is a valid hex colour, else a stable pick from `TEMPLATE_COLORS` (`#7c5cd6 #3b82f6 #06b6d4 #22c55e #f59e0b
  #ef4444 #ec4899 #14b8a6 #8b5cf6 #64748b`) by `jsHash31(id)` (`h = h*31 + utf16 unit`, wrapping at 32 bits;
  falls back to the name when the id is empty; `listColor(nil)` = the first colour) modulo 10. The web app picks the
  same colour (pinned: id "fixed-id" → `#8b5cf6`).
- If `TemplateIcons.icon(Library.icon(of: list))` exists → that icon drawn white at `size × 0.66`
  (`IconMark`, stroke 1.9 × size/24, round caps and joins).
- Otherwise a glyph, white, heavy: the template's `emoji` if it has one (font `size × 0.52`), else the first
  character of the name upper-cased (font `size × 0.46`).
- `accessibilityHidden(true)`.
- `Color(hexString:)`: trims spaces, drops a leading "#", expands 3-digit hex, parses the first 6 hex digits;
  anything unreadable → slate `#64748b`.

### Which icon (`PackingLibrary/TemplateIcon.swift`)
- Stored under the template's `extra["iconKey"]` (`Library.iconKey`). A blank string counts as nothing.
  `"letter"` (`Library.letterIcon`) = he chose the first letter.
- `chosenIcon(templateId:)` → his stored choice (letter included) or nil.
- `Library.icon(of: list)` (static, from a resolved list's extra) and `icon(for:)` (instance): choice
  `"letter"` → nil (draw the letter); else the choice; else `suggestedIcon(for:)`.
- `setTemplateIcon(id:key:)`: a non-empty key is stored; nil or "" removes the key ("back to the suggestion");
  sets the template's `updatedAt`; false for an unknown template.
- `suggestedIcon(for:)` — **first rule that matches wins** (`name = normName(list.name)`; *has* = substring of
  name; *word* = a whole word, words split on any non-letter):
  1. role `container` → `box`
  2. has "freediv" → `fin`
  3. has "diving", word "dive", has "scuba" or "snorkel" → `diving`
  4. word "car" → `car`
  5. has "plane", "flight" or word "fly" → `plane`
  6. word "rv", has "camper", "motorhome", "caravan" → `rv`
  7. has "train" → `train`
  8. has "ferry" or "boat" → `ferry`
  9. has "golf" → `golf`
  10. has "hik" or "trek" → `hiking`
  11. has "climb" → `climb`
  12. word "ski" or has "skiing" → `ski`
  13. has "camp" → `tent`
  14. has "bike" or "cycl" → `bike`
  15. word "run" or has "running" → `run`
  16. has "swim" → `swim`
  17. has "strength" or word "gym" → `strength`
  18. has "breath" → `breath` ("his 'Mobility & Breath work' is breath")
  19. has "mobility", "stretch", "yoga" → `mobility`
  20. has "padel" or "tennis" → `racket`
  21. has "beach" → `beach`
  22. has "fish" → `fishing`
  23. word "work" or has "business" → `laptop`
  24. has "travel" → `suitcase`
  25. none matched: role `base` → `suitcase`, else nil (the letter).

### The 50 icons (`TemplateIcons.all`, key → label shown in the picker; path data in the file, a 24-pt box, only the SVG commands M L H V C S Q A Z that `SVGPath` draws)
car Car · plane Plane · rv Camper · train Train · ferry Ferry · suitcase Travel · backpack Backpack · box Boxes ·
hiking Hiking · mountain Summit · diving Diving · fin Freediving · golf Golf · bike Bike · run Run · strength
Strength · kettlebell Kettlebell · swim Swim · mobility Mobility · breath Breath work · yoga Stretch · tent Camping ·
fire Campfire · ski Skiing · snow Winter · sun Summer · beach Beach · rain Rain · compass Orienteering · kayak
Paddling · fishing Fishing · climb Climbing · racket Racket sports · passport Passport · firstaid First aid · pill
Medicine · toiletry Toiletries · plug Electronics · laptop Work · camera Camera · coffee Coffee · food Food · sleep
Sleeping · sauna Sauna · paw Dog · book Reading · gift Party · glasses Sunglasses · headlamp Headlamp · heart Health.
`TemplateIcons.icon(key)` → the icon or nil (unknown key → nil → the cover falls back to letter/emoji).
`IconMark` is also used by `TripChecks.swift`.

### `CoverDoor` (on the template page)
A plain button showing `Cover(size: 40)`; id `template-cover`; accessibility label "Icon of <name>";
accessibility **value** = the icon key in force, or "letter" when none (the UI test reads this value). Owns its own
sheet → `IconPickerScreen(templateId:)` ("the page keeps the one sheet it has").

### Tests
- Model: `TemplateIconTests.testTheSuggestionsComeFromRoleAndName` (Car/Plane/RV transports, Travel base, Containers
  → box, Diving, Freediving → fin, Golf, Hiking, Bike, "Mobility & Breath work" → breath, Mobility, Run, Strength,
  Swim, "Carry-on things" → nil, "Brunch" → nil, "Common base" (base) → suitcase);
  `testHisChoiceIsKeptThroughEditsBackupsAndRecords` (choice survives `addToTemplate`, `renameTemplate`, records
  round trip, backup round trip; "letter" → nil; nil → back to the suggestion; unknown id → false);
  `ListsTests.testListColorCustomColourWinsElseAStablePalettePick`, `testListEmojiCustomEmojiElseTheDefaultGlyph`.
- UI: `testATemplatesIconIsSuggestedAndCanBeChosen`.
- **Not covered:** the emoji glyph path, an unknown stored key, the "train"/"training" overlap (see open questions).

---

## 4. The icon picker (`IconPickerScreen`)

### How it is reached and left
Tap the cover on a template's page (`template-cover`). Left by: "Cancel" (`icon-cancel`), by any pick (each pick
saves and closes), or a swipe down on the iPhone.

### What is on screen
- Top row (padding 16): the template's cover (40), its name (20 heavy ink, 1 line, shrinks to 80 %), spacer,
  "Cancel" (outlined `HeaderButtonStyle`, muted tint).
- Scroll (side 16, bottom 24), spacing 10:
  - Two tiles side by side: **"Suggested"** (id `icon-suggested`; shows the suggested icon at 30, or the first
    letter 22 heavy when there is no suggestion; selected when no choice is stored) and **"Letter"** (id
    `icon-letter`; the first letter 22 heavy; selected when the stored choice is "letter").
  - `SectionTitle` "All icons" (shown in capitals, 18 heavy, kerning 0.8, 16 above).
  - The 50 icons in rows of **5** (plain `HStack` rows, not a lazy grid: "the Mac builds only what is on screen").
    Each tile: icon at 30 + its label; id `icon-<key>`; selected when a choice is stored and the icon in force is
    this key.
- Tile look: mark 32 high; label 12 bold, 1 line, shrinks to 70 %; min height 74, full width share; selected =
  filled with the template's own colour (`listColor`), white mark and label, 2-pt stroke in that colour, trait
  `isSelected`; not selected = `Theme.card`, ink mark, muted label, 1-pt `Theme.line` stroke.
- Container id `icon-picker` (`children: .contain`). Mac: min 520 × 620.

### Behaviour
- `pick(key)` → `model.change { setTemplateIcon(id:, key:) }` then dismiss. Suggested = nil (removes the key),
  Letter = "letter", an icon = its key. Picking the very icon that is suggested **stores** it, so it no longer
  follows later renames.
- When the stored key is not one of the 50 (e.g. from a newer build), no tile is ringed and the cover shows the
  letter/emoji.

### Tests
UI `testATemplatesIconIsSuggestedAndCanBeChosen`: Hiking's cover value "hiking"; Suggested is selected; picking
`icon-tent` closes the picker and the value becomes "tent"; it survives closing/reopening; Letter → "letter";
Suggested → "hiking".

---

## 5. A new template (`NewList`)

### Purpose and origin
"Make a new list of his own." Shipped 0.15 (25 Sep 2026); the area question is his test H.6; reworded to
"activity area" in 0.56. The web app asks only a name (and leaves the list in "Other"); here the area is asked at
the same time "because it is one tap". It **refuses a name he already has** because the health check reads two
templates sharing a name as "two libraries have met on one account" (31 August 2026).

### How it is reached and left
"+ New" on the Templates tab (`templates-new`). Left by "Cancel" (`newlist-cancel`), swipe down (iPhone), or
"Make the template" succeeding (closes and the new template's page opens).

### What is on screen
- Top row (padding 16): "A new template" — 20 heavy violet, id `newlist-title`; spacer; "Cancel" (outlined,
  muted; the style's own 16 bold).
- Scroll (side 16, bottom 24):
  - "WHAT IS IT CALLED" — 12 heavy muted, kerning 0.6.
  - Name field — no placeholder, 17 semibold ink, min height 44, card fill, 10-radius border in `Theme.line`, or in
    red (`AppSection.actions.color` `#dc3d43`) while the name is taken; focused on appear; Return = Make;
    id `newlist-name`.
  - While taken: "You already have a template called that." — 14 semibold red, id `newlist-taken`.
  - `SectionTitle` "In which activity area should it live?" (rendered in capitals), id `newlist-area-title`.
  - One row per GROUP: "GA · Goal Activity", "WET · Workout, Exercise & Training", "OE · Other Events", then
    "No activity area". Rows are full-width buttons, min height 44, a hairline under each; the chosen one is 16
    heavy violet with trait `isSelected`, the others 16 medium ink. ids `newlist-area-GA`, `-WET`, `-OE`,
    `-none`. Default: "No activity area".
  - "Make the template" — 17 heavy white on a violet rounded rectangle (radius 12), full width, min height 50,
    24 above; id `newlist-make`. **Always in colour and always pressable** (his rule, 2026-09-26).
  - When pressed too early, a line under it: 15 bold red, centred, id `newlist-needs`.
- Container id `newlist-detail`. Mac: min 440 × 480.

### Behaviour
- `taken` = `normName(name)` is not empty AND **any** template (any role, the bag list "Containers" included) has
  the same `normName` (trimmed, lower-cased, whitespace runs collapsed).
- `make()`: blank (after `jsTrim`) → needs "Give the template a name."; taken → "Pick a name you do not have
  yet."; else clears needs, calls `made(newList(name: jsTrim(name), group: chosen))` and dismisses. The new list:
  role "", no items, no sections, no cover, fresh id, `createdAt`/`updatedAt` now; `coerceList` keeps the group only
  if it is a GROUP id.
- The caller saves it (`saveTemplate`) and opens it.
- The needs line is a plain text: it stays until the next press (it does **not** clear on typing, unlike the
  `needsLine` used elsewhere).
- There is no way here (or anywhere in this app) to make a `base` or `transport` template, or to set a colour,
  emoji or default bag.

### Tests
UI `testHeMakesAListOfHisOwn` (title "A new template"; Make enabled; empty press says "…name…"; "Hiking" shows
`newlist-taken` and a press says "…do not have…"; "Mushroom picking" + GA → page opens; summary changes; the
"Other templates" area does not appear); `testANewTemplateAsksForItsActivityArea` (question text, "No activity
area").

### Traps
- `canMake` is computed but never used (dead code).

---

## 6. One template (`TemplateDetail`)

### Purpose and origin
"One template: its things under his headings; a thing can be added at the foot and taken off with ✕ (the thing
itself survives)." Grew through: rename/delete (0.16), headings in capitals (0.40, H.13), ✕ asks first (0.40,
H.5), Group pills (0.42, H.3: "group and sort the items in a template in the same way as when you pack"), Choose
from your things (0.42, H.9), icon (0.46), "Only on:" line (0.55, field test 4.4), Find (0.60, 4 Oct 2026: "add a
search function so that the user can find a specific item without the need to scroll").

### How it is reached and left
- Reached: a card on the Templates tab; a Search result; straight after "Make the template".
- Left: "Done" (`template-detail-done`), "Delete the template", swipe down on the iPhone. A rename typed but not
  confirmed (Rename / Return) is **discarded** on leaving.
- Sheet; container id `template-detail` (`children: .contain`). Mac: min 480 × 600.
- If the template no longer exists while open (deleted elsewhere), it renders as an empty unnamed template
  (`?? newList()`, a fresh id on every redraw). Add, Choose and the cover then do nothing
  (`addToTemplate`/`putOnTemplate`/`setTemplateIcon` find no template), and a rename is refused silently by
  `renameTemplate` while the field's typed text is cleared.

### What is on screen, top to bottom

**Header row** (HStack spacing 12, padding 16):
- `CoverDoor` (§3).
- **The name is the field** ("Press it, type, and it is renamed — no second screen for one word"): plain
  TextField, 22 heavy ink, id `template-name`, shows the typed text while typing (`renaming`), else the name.
  Return = save the name.
- **"Rename"** — only while the typed name differs from the stored one after `jsTrim`: 15 bold violet plain text
  button, id `template-rename`. Always in colour.
- Spacer.
- **Share** — `ShareDoor(id: "template-share")`: outlined violet capsule with the drawn share mark (18) and
  "Share"; label "Share". Opens the share sheet with title `Share “<name>”` and
  `link = library.shareLink(templateId:)` (§19).
- **"Done"** — `HeaderButtonStyle` filled violet (white 16 bold on a capsule, min height 36).
- Under the row, `needsLine` id `template-rename-needs` (15 bold red), cleared as soon as the typed name changes.

**Group pills** (`FlowRow` spacing 6, side 16, bottom 4): the word "Group" (15 heavy muted, min height 36), then
one capsule per way: on = 15 heavy white on violet; off = 15 medium ink on `Theme.card` with a `Theme.line`
stroke; min height 36; ids `template-grouping-<raw>` (`section`, `when`, `into`, `fromWhere`, `kind`, `name`);
trait `isSelected` on the chosen one. Labels: Section · When · Into · From where · Kind · A–Z.
- "Section" is offered **only when at least one row has a non-empty section** (even an id that belongs to another
  template). His lists are built in sections ("511 of his 538 rows sit in one").

**Find** (shown when the template has at least one row, or while something is typed; side 16, top 6):
- TextField "Find a thing on this template" — 17 regular ink, min height 40, card fill, 10-radius hairline border;
  with the shared ✕ (`clearButton`): field id `template-find`, ✕ id `template-find-clear` ("Clear the search"),
  the ✕ shown only while the field holds text; one tap empties it and keeps the keyboard.
- Beside it, **"<found> of <all>"** — 15 bold monospaced muted, id `template-find-count` — only while the query is
  not blank AND finds something ("'0 of 4' would say again what the line under it says").

**The rows** (`KeyboardAwayScroll` + `LazyVStack(spacing: 6)`, side 16, bottom 24):
- A query that finds nothing: "Nothing on this template is called that." — 16 medium muted, 16 above, id
  `template-find-none`.
- For each group, its **heading**: the title in capitals, 18 heavy, kerning 0.8, 16 above; colour = the phase's
  colour made readable (When grouping) or violet (other groupings); id `template-group-<g>` (g = position of the
  group on screen).
- Under it each **row** (HStack spacing 4, a hairline under it):
  - A button (id `template-item-<n>`) holding: the thing's name (17 medium ink); a second line when it has a
    quantity or note: `"×<qty>"` and the note joined by " · " (13 regular muted, 1 line); a third line when the row
    is limited: **`"Only on: <tags>"`** (13 semibold violet, 1 line); and on the right the bag the row resolves to
    (`item.container`, 15 regular muted, 1 line). Vertical padding 6. Tap → the row editor (§7) as a sheet.
  - The **✕** — a drawn cross 22 pt (stroke 1.8, muted) in a 40 × 36 hit area; id `template-item-<n>-remove`;
    label "Take <name> off this template". Tap → the take-off question (below), with a 0.15 s ease-out.
  - n = the row's position **as read**, top to bottom across all shown groups (keyed by membership id).
  - Each row view is given the identity `"<memId>#<n>"` (see Traps).

**Choose from your things** — `PickThingsDoor` (side 16, top 10): wide outlined button (drawn list mark 22,
"Choose from your things" 17 bold violet, min height 48, 8 % violet fill, 1.4 stroke, radius 12); id
`template-pick`; owns its own sheet → `PickThingsScreen` (§8).

**Type a new thing** (side 16, vertical 10): TextField "Or type a new thing" (17 medium ink, min height 44, card
fill, hairline border; id `template-add-name`; Return = Add) and **"Add"** (`FieldButtonLabel`: 16 bold white on
violet, radius 10, min height 44; id `template-add`). `needsLine` id `template-add-needs`.

**Delete** — when not asking: `SmallDeleteButton` "Delete template" (13 semibold red text in a red 60 % outlined
capsule, min height 30, right-aligned; id `template-delete`; side 16, bottom 8). When asking, in its place a card
(padding 14, card fill, red 1-pt border, radius 12, side 16, bottom 10):
- `Delete “<name>”?` — 16 heavy ink.
- "The template and its <N> row(s) go. The THINGS stay — they are still in Your things and on any other template."
  — 14 medium muted.
- "Keep it" (plain, 16 bold ink, id `template-delete-no`) · spacer · "Delete the template" (16 heavy white on a red
  capsule, min height 40; id `template-delete-yes`).

**The take-off question** (overlay over the whole page while `takingOff` is set; fades in/out):
- The page dimmed (black 35 %); a tap on the dim = "Keep it".
- A centred card (max width 360, padding 22, radius 18, card fill, hairline, shadow 25 % radius 20 y 8, outer
  padding 24), spacing 14: a red drawn ✕ (22, stroke 2.2) in a 48 circle of red at 14 %;
  `Take “<thing>” off “<template>”?` — 19 heavy ink, centred, id `template-remove-question`;
  "It stays in Your things and on your other templates." — 15 medium muted, centred;
  two equal-width buttons: "Keep it" (outlined, ink, id `template-remove-no`) and "Take it off" (filled red,
  id `template-remove-yes`).

### Behaviour
- **Which grouping.** `ways = (sectioned ? [.section] : []) + [.when, .into, .fromWhere, .kind, .name]`. The choice
  is stored in `@AppStorage("ams.template.grouping")` (default "") — one value **for all templates on this
  device**. A stored way not offered here (e.g. "section" on a template without sections, or "") falls back to
  `ways[0]` (Section if sectioned, else When) without being stored.
- **How rows are grouped** (from the rows that pass Find):
  - When: `entriesByPhase(found)` (timeline order; a phase id this device does not know gets its own group at the
    end, titled by the raw id, or "Unsorted" for ""); rows keep **template order** inside a group; heading colour
    = `readableHex(phase.color, dark:)` (light mode: darkened until luminance ≤ 0.15; dark mode: lightened until
    ≥ 0.25; at most 40 steps; see `docs/colours.md`); an unknown phase carries slate `#64748b`
    (`phaseOrFallback`), made readable the same way.
  - Section / Into / From where / Kind / A–Z: `ThingGrouping.groups(found, sections: list.sections)` (§9); empty
    groups dropped; headings violet.
- **Find.** `q = normName(text)`; a row passes when `normName(row.name)` contains q (substring, case-insensitive,
  spaces collapsed, accents significant). Only the name is searched (not note, bag or section). The pills are
  worked out from the WHOLE template "so they stay put while he searches". A query of only spaces counts as empty
  (no filter, no count) but the ✕ is shown. The rows are re-numbered as read, so the first match is
  `template-item-0`.
- **Rename** (`saveName`): only when something was typed. Blank (after `normName`) → needs "Type a name first.";
  another template (any role, the bag list included, compared by `normName`, itself excluded) already has the name
  → "You already have a template called that."; else `renameTemplate(id:to:)` (§14), the typed state is dropped
  and the field loses focus. Only a case change of its own name is allowed (it is not "another" template).
- **Take off** ("Take it off"): `removeFromTemplate(templateId:memId:)` → the template resolved, the row with that
  `memId` removed, `saveTemplate` (§13). The thing survives in Your things and on its other templates; past and
  current trips are not touched.
- **Add** (`add()`): blank after `jsTrim` → needs "Type a thing first."; else `addToTemplate(templateId:name:)`
  (§13), the field emptied, and **Find emptied** too ("A search left on would hide the new thing… and then Add looks
  as if it did nothing"). A name he already owns (by `normName`) puts THAT thing on (one thing, one more place,
  bringing its own defaults); a new name makes a new thing (bag "Carry-on / hand luggage", When = the first
  non-task phase, by default "≥1 week ahead"). There is **no check** that the thing is already on this template:
  typing the name of a thing already here adds a **second row** of it.
- **Delete template** ("Delete the template"): `deleteTemplate(id:)` (§14) then dismiss. Things stay; trips keep
  their lines.

### Data
Reads `resolvedTemplate(id:)`, `templates` (name check), `shareLink(templateId:)`. Writes through
`renameTemplate`, `removeFromTemplate`, `addToTemplate`, `deleteTemplate`, `setTemplateIcon` (cover), and through
the sheets. AppStorage: `ams.template.grouping`.

### iPhone vs Mac
Same content; Mac min size 480 × 600. The header holds cover, name field, Rename, Share and Done in one row on
both.

### Tests
- UI: `testATemplateOpensAndCloses`; `testAThingAddedToATemplateStays` (Hiking has 4 rows; "Gaiters" added →
  `template-item-4`, survives close/reopen; ✕ asks first, Keep it keeps, Take it off removes, the other rows stay);
  `testATemplatesThingsGroupTheWaysATripSorts` (a sectioned template starts on Section, first heading "LIGHTS";
  A–Z is one group "A–Z"; Into's first heading "CARRY-ON / HAND LUGGAGE");
  `testATemplateFindsAThingWithoutScrolling` ("map" → the Map first and alone, "1 of 4", no none-line; "mapzz" →
  none-line, no count, no rows; ✕ brings all back and hides count and none-line; Add while searching clears the
  search and shows the new row); `testAListIsRenamedAndAnotherIsDeleted` (rename via `template-rename`, reread from
  `template-name`; delete asks (`template-delete-yes` exists), closes, summary changes, Care still says
  "10 things"); `testEveryAddButtonIsReadyAndSaysWhatIsMissing` (`template-add` → `template-add-needs`; name
  replaced by "Swim" → `template-rename` → `template-rename-needs`); `testATripReviewIsSavedAndTheMissedThingIsFiled`
  (a missed thing lands on the base template: `template-item-4`); `testOneSearchReachesEverything` (a Search
  result opens `template-detail`); `testATemplateAndAGrabListAreSharedAndOpenedAgain` (`template-share`).
- Model: `TemplateEditingTests`, `EditListsTests`, `RowEditingTests` (§13–14).
- **Not covered:** the device-wide grouping memory; When's colours; the "×qty · note" line; adding a thing already on
  the template (duplicate row); Delete's "Keep it"; a rename discarded by Done; Return in the name field.

### Traps and history
- 🪤 **Row identity.** "A row whose number changes is built afresh: kept, it kept its OLD number — the Map, the only
  row a search left, still said 'template-item-1' (4 Oct 2026), as the Mac did on Your things." Hence
  `.id("<memId>#<n>")`.
- 🪤 The page keeps **one** sheet of its own (the row editor); the cover and Choose doors own theirs ("several
  sheets on one view is a trap met in Search").
- 🪤 The rows are in a lazy stack: rows far down are not built until scrolled near — the UI tests scroll to reach
  `template-item-4` ("since the Find field … the fifth row sits past what a lazy list builds").

---

## 7. A row of a template (`RowEditor`)

### Purpose and origin
"What THIS list says about the thing — its bag and 'When' here, how many, a note, which section it sits in. Blank
means 'the same as the thing itself', so a change to the thing still reaches this list." How many and Section
became per-template in 0.14 (24 Sep 2026). "Only on some trips" is his ask of 2 Oct 2026 ("a towel can be
summer-only on Beach and always on Swim"). Heading bands: field test 3 Oct 2026 (the headings had been 14 grey,
smaller than the pills).

### How it is reached and left
Tap a row on a template page. Left by "Cancel" (`row-cancel`, nothing saved), "Save" (`row-save`, saves then
closes), swipe down (= Cancel). Container id `row-detail`. Mac: min 520 × 600.

### What is on screen
- Top row (padding 16): "Cancel" (outlined, muted) · spacer · "Save" (filled violet).
- Scroll (side 16, bottom 24), blocks 20 apart, each field right under its heading:
  1. The thing's name — 26 heavy ink, wraps, id `row-thing-name`; "On <template name>" — 15 semibold muted.
  2. **"Bag on this template"** (heading band, id `row-bag-title`): pills `row-bag-0` = "Same as the thing (<the
     thing's own bag>)", then `row-bag-1…` = `containerNames(resolvedTemplates())` (the 17 built-in names —
     Toiletry bag, Carry-on / hand luggage, Checked luggage, Hiking backpack, Climbing backpack, Golf bag,
     Triathlon bag, Swim bag, Duffel bag, Day pack, Bellroy backpack, Tech pouch, Electronics bag, Cool box,
     Handbag, RV storage box, Other — then his own bags from the bag list, de-duplicated case-insensitively). One
     choice.
  3. **"When, on this template"** (band, `row-when-title`): `row-when-0` = "Same as the thing (<phase label>)", then
     the live timeline (`PHASES`, his own steps if he changed them). One choice.
  4. **"Section of this template"** (band, `row-section-title`) — only when the template has sections:
     `row-section-0` = "No section", then the sections in order. One choice.
  5. **"A new section"** (band, `row-heading-section-new`): field "e.g. Lights" (`row-section-new`) and "Add"
     (`row-section-add`); `needsLine` `row-section-add-needs`.
  6. **"How many"** (band, `row-heading-qty`): field "e.g. 2, or 2 pairs" (`row-qty`).
  7. **"Note"** (band, `row-heading-note`): field "e.g. with the red filter" (`row-note`).
  8. "Blank means the same as the thing itself, so a change to the thing still reaches this template." — 14 muted.
  9. **"Only on some trips"** (band, `row-heading-some`), then "Leave these off and it always comes along. Pick one
     or more and it comes only on trips that match — on this template." (15 medium muted, pulled 6 pt up), then
     four pill rows with a smaller heading each (`HeadingTitle`, 20 heavy violet after a 4 × 18 violet capsule),
     several choices each; this block's parts are 14 pt apart:
     - "Season" (`row-seasons-title`): Summer `row-seasons-0`, Winter `row-seasons-1`.
     - "Context" (`row-contexts-title`) — **only on a WET template** (`contextApplies(list)`: group == "WET"):
       Indoor, Outdoor, Race (`row-contexts-0…2`).
     - "Transport" (`row-transports-title`): Car, Plane, RV (`row-transports-0…2`).
     - "Food" (`row-catering-title`): Self-sufficient, Eating out, Mix of both (`row-catering-0…2`; stored ids
       `self`, `eatout`, `mixed`).
- Field look: 17 medium ink, min height 44, card fill, 10-radius hairline border. Heading band: a 5 × 26 capsule in
  violet, the title 22 heavy violet, on a 13 % violet strip (radius 10). Pills: 15 (bold when on), min height 36,
  white on violet when on, ink on `Theme.bg` with a hairline when off; ids are `<id>-<position>`, never words.

### Behaviour
- On appear the state is loaded from the **membership itself** (not the resolved row): bag = `m.container`, when =
  `m.phase`, qty, note, section, seasons, contexts, transports, catering. A blank membership value selects the
  "Same as the thing" / "No section" pill. A stored bag, When or section that is not among the pills selects
  none, and is kept unchanged on Save. A stored **condition** value that is not one of the app's own words
  (exactly `Summer`/`Winter`, `Indoor`/`Outdoor`/`Race`, `Car`/`Plane`/`RV`, `self`/`eatout`/`mixed` — case
  matters) also selects nothing, but is **dropped** on Save, because Save rebuilds each list by filtering the
  vocabulary (see open questions).
- **Add a section**: blank (after `jsTrim`) → "Type the section's name first."; else
  `addSection(templateId:name:)` — **written immediately** (a section of the same `normName` returns the existing one
  instead of adding a second); the new/existing section becomes the chosen one in the editor; the field empties. The
  section stays on the template even if the editor is then cancelled. Adding the first section makes the "Section of
  this template" pills appear.
- **Save**: `updateMembership(memId:)` sets `container = bag`, `phase = when`, `qty = jsTrim(qty)`,
  `note = jsTrim(note)`, `section`, and the four condition lists **in the app's own order** (SEASONS, CONTEXTS,
  TRANSPORTS, CATERING order) "so the stored lists read the same every time"; then `coerceMembership`; then
  dismiss. `weather`, `kit`, `itemType` and `order` are left as they were (no UI for them). Contexts stay stored on
  a non-WET template even though their pills are hidden there (and ignored there when a trip is built).
  Save closes the sheet even when `updateMembership` finds no such row (deleted meanwhile); nothing is said.
- With the row gone (deleted on the other device while open) the editor shows an empty `Item()`: a blank name,
  "Same as the thing ()" for the bag and "Same as the thing (Unsorted)" for When.
- The thing itself, and the same thing's rows on other templates, are untouched.
- A row change does **not** reach trips already made (only a change to the THING follows to trips, §17); it reaches
  new trips and a trip's rebuild (Trip settings → Save).
- How the conditions act on a trip (`itemMatchesEvent`): a dimension with no values always matches; a trip with no
  value for that dimension matches; otherwise the trip's value must be one of the row's. Context only counts on a
  WET template, and a trip may pin several contexts (any overlap matches).
- The row on the template page then says `Only on: <seasons · contexts · transports · food>` (food in the short
  words) — `TemplatesScreen.tags(_:)`; contexts are listed even on a non-WET template.

### Data
Reads `library.row(templateId:memId:)` (membership + thing + resolved row), `templates` (the shell, for name,
sections, group), `resolvedTemplates()` (bag names). Writes `memberships[n]` via `updateMembership`, and
`templates[t].sections` via `addSection`.

### Tests
- UI: `testARowOfAListHasItsOwnAnswers` (Hiking's first row is the sectioned Headlamp and shows "Carry-on"; picking
  `row-bag-4` and a note "with the red filter" → the row shows the note and no longer "Carry-on"; Season Summer kept
  and the row says "Only on: Summer"; Context not offered on Hiking; the thing's own bag unchanged in Your things);
  `testTheEditorsLeadWithTheirHeadings` (all ten heading ids exist); `testEveryAddButtonIsReadyAndSaysWhatIsMissing`
  (`row-section-add` → `row-section-add-needs`).
- Model: `RowEditingTests.testThisListsOwnAnswersStayThisListsOwn` (addSection trims and de-duplicates;
  updateMembership sets bag/When/qty/note/section on THIS row only; blank again = follow the thing; unknown id →
  false); `testTheRowsOfATemplateGroupIntoItsSections`; `RowTagsTests.testATaggedRowComesOnlyOnTripsThatMatch`
  (Summer+Plane row, Outdoor row on a WET template; Indoor+Outdoor takes both; untagged always comes; tags survive
  records).
- The model classes `TemplateEditingTests`, `ThingEditingTests` and `RowEditingTests` live in
  `PackingLibraryTests/CreateTripTests.swift`.
- **Not covered:** Food tags; Transport-only tags on their own; Cancel after Add-a-section; a section from another
  template; an unknown condition value being dropped on Save.

### Traps
- 🪤 The Pills' heading must be bigger than the pills (field test 3 Oct): bands 22, inner headings 20, pills 15.
- "Same as the thing (X)" names the thing's own bag, but a blank bag actually resolves **template default first**,
  then the thing (§12) — see open questions.

---

## 8. Choose from your things (`PickThingsScreen`, `PickThingsDoor`, `FoldAllMark`)

### Purpose and origin
His test H.9 (28 Sep 2026, "the one red box"): "How do we add things to a template? We need the list of things. We
need to be able to choose from existing ones and also define new ones … order, sort and group the things to pick
from in a variety of ways, the same as when packing." Shipped 0.42. Folding: field test 3 Oct 2026 ("It is an
extremely long list when adding, so we need toggles everywhere … collapsible and expandable … Collapse All or
Expand All"), shipped 0.56.

### How it is reached and left
"Choose from your things" (`template-pick`) at the foot of a template page. Left by "Cancel" (`pick-cancel`,
ticks lost), "Add N" (puts them on and closes), swipe down. Making a new thing from here does NOT close it.
Container id `pick-screen`. Mac: min 520 × 620.

### What is on screen
- Top row (padding 16): "Cancel" (outlined muted) · `"Add to <template name>"` (or "Add things" if the template is
  gone) 17 heavy ink, 1 line, shrinks to 80 %, id `pick-title` · the add button (filled violet): "Add" with
  nothing ticked, `"Add <n>"` with n ticked; id `pick-add`.
- Under it (side 16, bottom 8), spacing 10:
  - Search field "Search your things, or type a new one" (17 medium, min height 44, card fill, hairline) with the ✕:
    ids `pick-search`, `pick-search-clear`.
  - "Group" (14 heavy muted) and five pills (14; heavy white on violet when on, semibold ink on card off; min
    height 32): Kind · From where · Into · When · A–Z; ids `pick-group-kind`, `-fromWhere`, `-into`, `-when`,
    `-name`. No Section here.
  - Count row (min height 34): `"1 thing"` / `"<n> things"` (15 bold monospaced muted, id `pick-count`; the things
    shown after the search) · spacer · **"Fold all" / "Unfold all"** (drawn arrow 24 + word 15 bold violet, 10 %
    violet capsule with a 1.2 violet stroke, min height 34; id `pick-fold-all`) — only when not searching and there
    is at least one group. It reads "Unfold all" when every group of the current grouping is folded.
- The list (`KeyboardAwayScroll`, side 16, bottom 24, spacing 4):
  - When a query is typed and **no thing has exactly that name** (by `normName`): a button
    `+  A new thing: “<query trimmed>”` (+ 22 heavy, words 17 bold, all violet, on 10 % violet with a 1.2 stroke,
    radius 10); id `pick-new`.
  - Each group: a **heading** — the fold arrow (drawn chevron 24, stroke 2.4, ink; pointing right when folded,
    down when open; 30 × 36 hit area; id `pick-group-<g>-fold`; label "Open <title>" / "Fold <title>"; replaced by
    an empty 30 × 36 space while searching), the title in capitals (16 heavy violet, kerning 0.6, 1 line; id
    `pick-heading-<g>`; a tap on it also folds/opens, not while searching), and the count
    `"1 thing"`/`"<n> things"`, plus `" · <k> ticked"` in violet when k > 0 (14 bold monospaced muted; id
    `pick-heading-<g>-count`). A folded group keeps its heading and counts.
  - Unless folded, its **rows**: a 24-pt circle (violet outline; filled violet with a white tick when ticked;
    filled `Theme.line` with a white tick when already on the template), the name (17 medium; muted when already on
    it, else ink; 1 line), and on the right either "already on it" (14 semibold muted) or the thing's *other*
    answer (14 regular muted): grouped by From where → its bag; any other grouping → its storage place, or its bag
    when no place is set. Vertical padding 9, hairline under. id `pick-row-<n>` with n numbered as read across
    **all** groups, folded ones included (so numbers do not shift when a group folds). Trait `isSelected` when
    ticked or already on it; accessibility value "already on it" or "".
  - Nothing owned and nothing typed: "You have no things yet. Type a name above to make one." (16 medium muted).

### Behaviour
- The things listed are **all** catalogue items (`library.items`, bags included, retired included), filtered by
  `normName(name)` containing the query; grouped with `ThingGrouping.groups(things)` (§9) — values are each
  thing's OWN bag/place/kind/When, not any template's.
- Grouping stored in `@AppStorage("ams.pick.grouping")`, default "kind"; a stored value not offered falls back to
  Kind.
- Folds stored in `@AppStorage("ams.pick.folded")`: one `"<grouping raw>|<group title>"` per line, so "a fold made
  under From where does not fold a group of the same name under Into". Device-wide, shared by all templates; kept
  across closing/reopening. Fold all = add every current group's key; Unfold all = remove them.
- **A search opens every group** ("what he typed for must never sit in a folded one"); the folds come back when the
  search is emptied. Fold all is hidden while searching.
- A row already on the template (`thingIds(onTemplate:)` = item ids of its memberships) cannot be ticked. Ticks
  (`picked`, a set of item ids) survive folding, regrouping and searching.
- **Add N** (`putOn`): nothing ticked → nothing happens and nothing is said (see open questions); else
  `putOnTemplate(templateId:itemIds: Array(picked))` and close. Each new row brings the thing's own defaults
  (blank bag/When on the membership); already-on things, repeats and unknown ids are skipped.
- **A new thing** (`makeNew`): `addToTemplate(templateId:name: jsTrim(query))` — a brand-new thing straight onto the
  template — then the query is emptied; the screen stays open; the new thing now shows as "already on it".

### Data
Reads `items`, `memberships`, `resolvedTemplate(id:)`. Writes via `putOnTemplate` / `addToTemplate`. AppStorage:
`ams.pick.grouping`, `ams.pick.folded`.

### Tests
UI `testThingsHeOwnsArePickedOntoATemplate` (A–Z regroups to one "A–Z" heading; Hiking's 4 things say "already on
it"; ticking two → "Add 2"; Add closes and rows 4–5 arrive, not 6; "Gaiters" via `pick-new` lands as row 6; Care
says "11 things" — no copies); `testAGroupOfThingsToChooseFoldsAndSaysWhatItHolds`;
`testEveryGroupOfThingsToChooseFoldsAndOpensAtOnce`; `testTheFoldsOfThingsToChooseAreRemembered`;
`testASearchOpensAFoldedGroupOfThingsToChoose`; `testATickSurvivesFolding` ("2 things · 1 ticked");
`testTheCrossEmptiesASearch` (`pick-count` "10 things" → "1 thing" → back). Model
`TemplatePickingTests.testThingsHeOwnsArePutOnATemplateOnceEach`.
**Not covered:** Add with nothing ticked; Kind/When/Into grouping of the picker; the order in which picked things
land.

### Traps
- 🪤 The fold arrow is its own button and the name a separate text: "the Mac folds a button's texts into the
  button".
- 🪤 Fold all's mark is the groups' own arrow, as the groups will be after the press: "Two arrows meeting read as
  an ✕ beside the search's ✕ (seen on the screen, 3 Oct 2026)".
- 🪤 `PickThingsDoor` owns its sheet so the template page keeps one sheet.
- "Just added" is **not** part of this screen — it belongs to Care → Your things (`ThingsScreen`).

---

## 9. Grouping a set of things (`ThingGrouping` in `TemplatePicking.swift`; `PackingCore/Grouping.swift`)

### `ThingGrouping` (raw values `section`, `when`, `into`, `fromWhere`, `kind`, `name`; labels Section, When, Into, From where, Kind, A–Z — "the same words as the trip's sorting")
`groups(items, sections:) -> [(title, items)]`; A–Z inside a group = stable `jsLocaleCompare(…, .base)` (case- and
accent-insensitive):
- `.section` → `groupItemsBySection(items, sections)`: sections in the template's order, empty ones omitted, rows
  whose section is blank **or not one of this template's** in a last group "Everything else"; rows keep template
  order (no A–Z).
- `.when` → `entriesByPhase`; A–Z inside.
- `.into` → `groupByContainer`: key = the bag, blank = "Other"; built-in bag names first in `CONTAINERS` order,
  every other name after them A–Z (`localeCompare`); A–Z inside.
- `.fromWhere` → `byWords(storage, notSaid: "No place set")`; `.kind` → `byWords(category, notSaid: "No kind set")`:
  a group per trimmed word, merged by `normName` (the first spelling seen is the title), groups A–Z (.base), the
  "not said" group last; A–Z inside.
- `.name` → one group titled "A–Z" (none for no items).

### `PackingCore/Grouping.swift` (port of the web app)
- `entriesByPhase(entries) -> [PhaseGroup]`: known phases in timeline order (empty ones dropped); entries with an
  unknown phase id each get a group at the END in first-seen order, phase = `phaseOrFallback(id)` (label = the id,
  or "Unsorted" for "", slate `#64748b`) — "rather than being dropped into '≥1 week ahead'".
- `groupByContainer`, `groupByCategory` (fallback `CATEGORY_DEFAULT` "Comfort & misc", `CATEGORIES` order first)
  via `groupByKey(entries, key, order, fallback)`: named keys rank by position (a repeated name: last index wins),
  others rank 999 then `jsLocaleCompare`.
- `groupItemsBySection(items, sections) -> [SectionItemsGroup]` (section nil = the trailing bucket). Walks the
  sections, so a section id defined twice shows twice.
- `groupBySection(entries)` (trip lines carry a section NAME): first-appearance order, "Everything else" last.
- `groupByStorage(entries)`: places A–Z, "No place set" last.
- `groupBy(mode, entries) -> [EntryGroup]`: "category" | "container" | "section" | "stored" | anything else = When
  (only When carries a `hint`).
- `sortRowsBy(rows, valueOf, dir:, num:, tie:)`: blanks always sink (text: trimmed empty; number: not > 0), ties go
  to `tie` and never flip, text compared with `.base` sensitivity, numbers arithmetically; stable; input not
  mutated. `groupRowsBy(rows, keyOf, order:, emptyLabel: "Not set")`: named buckets first (case-insensitive), the
  rest A–Z, the empty bucket ALWAYS last, row order kept inside. (Used by Care's table, not by templates.)

### Tests
`TemplatePickingTests.testThingsGroupTheWaysTheTripSorts` (one "Kitchen" however spelt, "No place set" last, A–Z
inside, labels list); `GroupingTests` — `testEntriesByPhaseOnlyReturnsNonEmptyPhasesInTimelineOrder`,
`testEntriesByPhaseAnUnknownPhaseGetsItsOwnGroupAtTheEnd`, `testGroupByContainerOrdersKnownContainersFirst`,
`testGroupByCategoryGroupsByCategoryInCategoriesOrder`, `testGroupByDispatcherReturnsLabelledGroups`,
`testGroupItemsBySectionTemplateOrderEmptySectionsOmittedUngroupedLast`,
`testGroupItemsBySectionIgnoresASectionIdFromAnotherTemplate`, `testGroupBySectionFirstAppearanceOrderEverythingElseLast`,
`testGroupByStorageAlphabeticalNoPlaceSetLast`, the five `testSortRowsBy*`, the three `testGroupRowsBy*`,
`testGroupByContainerUnknownBagsFollowTheKnownOnesAlphabeticallyAndBlankIsOther`,
`testGroupByWhenCarriesThePhaseHintAndTheOtherModesDoNot`, `testSortRowsByReadsAJSONValueTheWayJSReadsAnyValue`.

---

## 10. Model: a template and its sections (`PackingCore/Lists.swift`)

`PackList` (named so because `List` is SwiftUI's):

| Field | Meaning / rule |
|---|---|
| `id` | String; fresh `PackingEnv.makeId()`. |
| `name` | Free text (no trimming in `coerceList`; `newList` from the UI trims). |
| `emoji` | Cover glyph; trimmed, cut to 4 UTF-16 units; non-string → "". "" = no glyph (the web app shows 📋 `TEMPLATE_DEFAULT_EMOJI` via `listEmoji`; this app shows the first letter). No UI sets it here. |
| `color` | Cover colour; kept only if a hex colour, else "" (= hashed pick, §3). No UI sets it here. |
| `sections` | Ordered `[TemplateSection {id, name}]`; `normalizeSections`: unnamed (after trim) dropped, a missing id invented, a repeated id dropped, names trimmed. |
| `group` | "GA" / "WET" / "OE" or "" (any other value → ""). The activity area. Set only when the template is made. |
| `role` | "base" (always on every trip), "transport" (only when the trip's transport equals `transport`), "loose" (retired bin, never fed to a trip), "container" (the bag list, never fed to a trip), "" (an activity template the user ticks). Unknown → "". |
| `transport` | "Car" / "Plane" / "RV" or "" (only meaningful for role transport). |
| `defaultContainer` | One bag for everything on this template ("" = none); sits between the thing's own bag and the row's exception. No UI sets it here (imported data only). |
| `builtin` | Shipped with the app; JS truthiness. |
| `items` | Resolved rows in memory; **always [] in the stored shell**. |
| `createdAt`, `updatedAt` | ISO strings. |
| `extra` | Unknown keys (e.g. `iconKey`), minus `owner`/`realmId`. |

- `coerceList` applies the rules above (+ `coerceItem` on each row). `newList(…)` = construct + coerce; `newList(json:)`
  lays a partial over the defaults.
- `listColor`, `jsHash31`, `listEmoji` — §3.
- `orderActivities(groupId, lists)` — §1.
- `containerNames(lists)`: `CONTAINERS` (17 built-in names) + the trimmed names of the rows on any role-`container`
  list, skipping case-insensitive repeats, in first-seen order. 🪤 It must be given **resolved** lists.
- `newSection(name)` → fresh id, trimmed name.

Tests: `ListsTests` — `testCoerceListKeepsTheLooseRole`, `testNewListGroupIsAValidGroupIdOrEmpty`,
`testNormalizeSectionsDropsBlankNamesKeepsIdsDedups`, `testCoerceListSectionsNormalizeAndDefaultToEmpty`,
`testCoerceListCleansCoverEmojiAndColour`, `testListEmojiCustomEmojiElseTheDefaultGlyph`,
`testListColorCustomColourWinsElseAStablePalettePick`, `testCoerceListATemplateCanCarryItsOwnDefaultContainer`,
the four `testOrderActivities*`, `testContainerNamesMergesBuiltInNamesWithTheUserContainerRecords`,
`testAListRoundTripsThroughJSONAndCarriesUnknownKeys`, `testTheSmallLookups`.

---

## 11. Model: a row = a membership (`PackingCore/Memberships.swift`)

Three layers, each owning its own fields: **ITEM** (the thing: name, Swedish name, category, flags, weight, photos,
home storage, care, its own default bag and When), **MEMBERSHIP** (thing ↔ template: the conditions and optional
overrides), **TRIP LINE** (thing ↔ trip: a frozen copy).

| Membership field | "" / [] means | Rule |
|---|---|---|
| `id` | — | Random id; the record key. |
| `itemId` | — | The thing. |
| `templateId` | — | The template; the record's `parent`. |
| `seasons`, `contexts`, `transports`, `catering` | always comes (no restriction) | Any strings kept (not checked against the vocabularies); on resolve they **replace** the thing's own. |
| `weather` | not conditional gear | Only `rain`, `cold`, `hot`, `wind`, `snow` kept. A tagged row is held back from a trip unless the trip forces that weather on. No UI here. |
| `container` | the template's `defaultContainer`, then the thing's own bag | Non-string → "". |
| `section` | no section | A section id of THIS template; no item default. Not carried between templates by id (only by name). |
| `kit` | no kit | A kit NAME; no item default. No UI here. |
| `phase` | the thing's own When | Trimmed, cut to 40 UTF-16 units; an unknown id is **kept** (likely a phase made on the other device); non-string → "". |
| `itemType` | the thing's own | "item" / "reminder" / "" (anything else → ""). No UI here. |
| `qty` | the thing's own qty | Text; a JSON number becomes JS number text ("3", "0.5", "1e+21"); 0 → "". |
| `note` | the thing's own note | Text. |
| `order` | — | Position on the template (a Double, never floored); non-finite or a numeric string → 0. |
| `extra` | — | Unknown keys kept, `owner`/`realmId` dropped. |

Field lists: `INTRINSIC_FIELDS` (name, swedish, category, charging, chargeType, liquid, restricted, perNight,
consumable, shortList, weight, storage, packer, sub, photos, thumb, maintenance, stats, color, size, manufacturer,
model, ownedBy, acquired, price, currency, purchaseLink, expiry, condition, retired, retiredReason, keep, serial,
qtyOwned, warranty, capacityL, maxKg) — belong to the THING, "the single source of truth" for pushing edits onto it;
`DEFAULT_FIELDS` — container via `_defContainer`, phase via `_defPhase` (an item's own default reaches it only through
this channel, so "in Hiking, use the hiking backpack" never leaks out); `CONTEXTUAL_FIELDS` (seasons, contexts,
transports, catering, weather, kit, qty, note, itemType) — per template. `section` is deliberately in none of them
(it travels by name, `mapSectionAcrossTemplates`).

Tests: `MembershipsTests` — `testCoerceMembershipNormalizesConditionsAndKeepsOverrideSentinels`,
`testANumericQtyBecomesTextTheWayJSWritesNumbers`, `testIntrinsicFieldsCarriesOwnedByAndNoLongerTheReservedOwner`,
`testNewMembershipDefaultsAndRoundTrip`, `testEveryFieldListNamesARealItemKey`.

---

## 12. Model: resolving a template (`PackingCore/Resolve.swift`, `Library.resolveOne`)

- `resolveMembership(item, m, tplDefaults)` → a row: the thing's fields, then
  `seasons/contexts/transports/catering/weather` = the membership's (replacing the thing's);
  **container = m.container, else the template default, else the thing's own** (and the three parts handed back as
  `ovContainer`, `tplContainer`, `defContainer`); `section`, `kit` = the membership's; phase = m.phase else the
  thing's (`ovPhase`, `defPhase`); itemType, qty, note = the membership's when not blank, else the thing's. The
  result keeps the **thing's id**; the core functions do not stamp `itemId`/`memId`.
- `resolveItemAlone(thing)` (web app v175): the thing against an empty membership — per-template answers blank, its
  own answers kept; `itemId` = the thing, `memId` = "". Used to put a thing on a template with its own defaults, and
  for things on no template.
- `resolveTemplateItems` / `resolveTemplate`: the template's memberships, **stable-sorted by `order`**, each joined
  to its thing (a membership whose thing is missing is skipped; a repeated catalogue id → the last wins); then
  `coerceList`.
- `Library.resolveOne` does the same and stamps each row's `itemId` and `memId` (the web app's `resolveOne`). Views:
  `resolved(_:)`, `resolvedTemplate(id:)`, `resolvedTemplates()` (all, **A–Z by name**), `thingsOnNoList()`.
- 🪤 "The same item can sit on ONE template more than once … Whoever needs to tell the rows of a template apart keys
  them by MEMBERSHIP id, never by item id."

Tests: `ResolveTests` (8 tests: overrides win / blanks fall back; membership order; same item, different section per
template; kit flows; container exception → template default → item default; every part handed back; resolve alone;
skips missing items and keeps the same item twice); `LibraryTests.testOneThingOnTwoTemplatesIsOneItemWithTwoMemberships`,
`testTheSameThingTwiceOnOneTemplateKeepsBothRows`, `testTakingAThingOffItsLastListKeepsTheThing`.

---

## 13. Model: editing a template (`Library.saveTemplate` and the operations built on it)

### `saveTemplate(list, keepingMembershipIds = true)` — "the web app's saveList, v176"
Takes an edited **resolved** template apart:
1. For each row in order (rows with a blank name are skipped — so dropped):
   - Find its thing: by `row.itemId`; else by `normName(row.name)` (first thing with that name); else new.
   - Found → `items[n] = applyIntrinsic(items[n], row)` (the row's intrinsic fields and `_defContainer`/`_defPhase`
     written onto the thing; a **link** row carries only its name).
   - Not found and the row is a link → skipped ("never invent an item from a link whose target has vanished").
   - Not found → `catalogItemFromResolved(row)` (its bag/When become the thing's defaults; contextual fields stay
     off), keeping `row.itemId` as the id when it has one.
   - Its membership: the row's `memId` if that membership belongs to this template; else the first membership of
     this template for this thing not already used in this save; else (with `keepingMembershipIds`) a new
     membership under the row's `memId`; else a fresh one. Then `membershipFromResolved(thing, templateId, row,
     order, existing)`: conditions from the row; `container` = the row's `ovContainer` verbatim when present, else
     an exception only if it differs from the fallback (`containerOverrideFor`); `section`, `kit` always stored;
     `phase` = `ovPhase` when present, else an exception if different from the thing's; `itemType` only if
     different; **`qty` and `note` = the row's (resolved) values**; `order` = 0, 1, 2… in row order.
2. Memberships of this template not seen in this save are deleted. **Things are never deleted.**
3. The shell is stored with `items = []`, coerced, `updatedAt = now` (added if new).

### Operations
- `addToTemplate(templateId:name:container:phase:) -> Item?` — blank → nil; unknown template → nil. An existing thing
  of that `normName` → its `resolveItemAlone` row (memId cleared); else a new row (bag default "Carry-on / hand
  luggage", When `defaultPhaseId()` = the first non-task phase). Appended, `saveTemplate`, returns the last resolved
  row. No duplicate check. Either way the new membership stores no bag or When exception (a new thing's
  bag and When become the THING's defaults; a known thing's row arrives with `ovContainer` = "").
- `removeFromTemplate(templateId:memId:) -> Bool` — false if the template or row is missing; removes that one row
  and saves.
- `putOnTemplate(templateId:itemIds:) -> Int` (`TemplatePicking.swift`) — skips ids already on the template, repeats
  and unknown ids; appends `resolveItemAlone` rows; saves only if something was added; returns how many.
- `thingIds(onTemplate:) -> Set<String>`.
- `setOnTemplate(itemId:templateId:on:) -> Bool` — used by the thing editor ("On these templates"), the table's
  per-template columns, the bag list, Refine's Drop: on = append a blank membership with `order = max + 1` (or 0)
  unless the thing is already there; off = remove **every** membership of that thing on that template. Does not
  touch `updatedAt`.
- `row(templateId:memId:)` → (resolved row, thing, membership) or nil.
- `updateMembership(memId:_:)` → applies the closure, `coerceMembership`; false for an unknown id. Does not touch the
  template's `updatedAt`, and does not follow to trips.
- `addSection(templateId:name:) -> TemplateSection?` — trims; blank or unknown template → nil; an existing section of
  the same `normName` is returned instead of a second; else appended. Does not touch `updatedAt`.
- There are **no** operations for renaming, reordering or deleting a section, reordering rows, or changing a
  template's group/role/transport/cover/default bag.

### Tests
`TemplateEditingTests.testAddingANewNameMakesANewThingAndAKnownNamePutsTheSameThingOn` (" Gaiters " → new thing
"Gaiters"; "headlamp" → the existing Headlamp, which brings its own packer; blank → nil);
`testRemovingARowKeepsTheThing`; `ThingEditingTests.testAThingIsPutOnAListAndTakenOff`; `RowEditingTests` (2);
`TemplatePickingTests.testThingsHeOwnsArePutOnATemplateOnceEach`; `LibraryTests.testRecordsRoundTrip`,
`testTheStoreOnlyEverSeesTheDifference`; `ThingFollowsTests.testABagChosenForOneTemplateStillWins` (a row's
`ovContainer` saved through `saveTemplate`).

### Traps
- 🪤 Three silent data bugs in the web app were "a producer writing the right value into the wrong one" of item
  default / template default / membership exception (Catalogue.swift header). `containerOverrideFor` is the one
  place that decides whether an exception is needed.
- 🪤 A thing twice on one template: each save applies both rows' intrinsic fields to the one thing; the review
  therefore writes history straight onto things, not through `saveTemplate` (Library.swift, found 2026-09-22).

---

## 14. Renaming and deleting a template (`PackingLibrary/EditLists.swift`)

His ask: "You don't need to merge the content of the two templates — I can add items later on. Just delete one and
rename the existing."
- `renameTemplate(id:to:) -> Bool`: trims; refuses blank, an unknown id, or a name another template (any role) has
  by `normName`; sets the name and `updatedAt`. The icon choice (in `extra`) is kept.
- `deleteTemplate(id:) -> Bool`: false for an unknown id; removes the template's memberships and the template. Things
  stay (also things that were on no other template — they become things on no template). Trips built from it are
  untouched ("a trip's lines stand on their own"); a rebuild never drops lines whose template is gone
  (`docs/store.md` rule 9, `Library.regenerated`).

Tests: `EditListsTests` — `testARenameSticksAndRefusesANameHeAlreadyHas`,
`testADeleteTakesTheListAndItsRowsButNeverTheThings`, `testTheOtherListIsUntouchedByTheDelete`,
`testItRefusesAListThatIsNotThere`; `LibraryTests.testRegeneratingNeverDropsTheLinesOfADeletedTemplate`,
`testRegeneratingStillDropsWhatALivingTemplateNoLongerHas`; UI `testAListIsRenamedAndAnotherIsDeleted`.

---

## 15. The bag list: a template with role "container" (`PackingLibrary/Bags.swift`, template parts)

- 🚨 Words (his ask, 2026-09-27): the app says **Bags** everywhere, never "containers". The stored data keeps the
  web app's names — the role `container`, the list named `CONTAINER_LIST_NAME` "Containers", the `container`
  fields — "renaming stored keys is how data gets lost".
- `bagList` = the first template with role `container`. `shownName(list)` = "Bags" for it, else the name; used by
  Your things' "on these templates" names (`thingRows`, `listsOf`) and the table's column names.
- A bag is an ordinary thing on that list; bags are joined to things **by name** (`container` strings).
- `addBag(name:)` makes the bag list (`saveTemplate(newList(name: "Containers", role: "container"))`) if he has none,
  then puts the thing (existing by name, or new via `addThing`) on it with `setOnTemplate`.
- `bags()` = the resolved bag list's rows; `bagLimits()` must be given RESOLVED lists ("the first Bags card did
  exactly that; its test caught it").
- The bag list never shows on the Templates tab, never in Search's templates, never as a choice in the thing
  editor's "On these templates", is never fed to a trip, and is never offered as "Replace" for a shared template.
  Its rows feed `containerNames` (the bag pills of the row editor).
- Renaming/deleting bags and what a bag knows (`renameBagEverywhere`, `deleteBag`, `bagFacts`…) — see the Bags spec.

Tests: `BagsTests.testABagGetsMadeAndItsListWithIt`, `testTheBagListIsShownAsBags` (stored name stays "Containers",
shown "Bags", Your things never says "Containers"), and the other 15 Bags tests (Bags spec).

---

## 16. When a template was last taken (`PackingLibrary/TemplateUse.swift`)

"A list nobody has packed in a year is worth knowing about; so is the one that goes everywhere."
`templateUse() -> [templateId: TemplateUse(lastTrip, lastDate, trips)]`, counted from the trips: for each trip, the
set of template ids = its `activities` plus every line's `sourceListId` (so a base template counts through its lines,
and a template since deleted or replaced still counts by the lines that name it). Each id: `trips += 1`; if the
trip has a start date later (string compare of `YYYY-MM-DD`) than the stored one, it becomes `lastDate`/`lastTrip`
(the trip's name). A trip with no date counts but never wins. A trip in the future counts and can win.

Tests: `TemplateUseTests` — `testAListNobodyHasTakenSaysNothing`, `testTheMostRecentTripWins` (base counted on 3 trips
through its lines), `testATripWithNoDateStillCountsButNeverWins`.

---

## 17. A change to a thing follows to trips still ahead (`PackingLibrary/ThingFollows.swift`)

His decision on test I.7 (1 Oct 2026), released 0.45.
- `tripStillAhead(trip, today)`: status not "done", not reviewed, and either no start date or the end date (or the
  start when there is no end) ≥ today.
- `followThing(id:today:)` (called by `updateThing` and `renameThing`): on every trip still ahead, the lines of this
  thing that are not ticked, not added by hand (`custom`) and not changed on the trip (`edited`) are rebuilt the way a
  new trip would build them (`buildTotalEntries(trip, resolvedTemplates())` filtered to this thing) — "so a bag
  chosen for that one template still wins over the thing's own bag". Each old line takes a fresh line from the same
  template first, else any unused one; it keeps its `id`, `checked`, `skipped` (set aside) and `used`. A line with no
  fresh counterpart is left as it is. The trip's `updatedAt` is set when something changed. Returns how many lines
  changed. `today` defaults to the UTC date of `nowISO()`.
- A change to a ROW (membership) or to a template's rows does not call this.

Tests: `ThingFollowsTests` — `testAChangeToAThingReachesOnlyWhatIsStillUndecided` (ahead and undated trips follow;
ticked line, over trip, reviewed trip keep theirs; ids and line count kept),
`testARenameAndAnEditedOrSetAsideLineAreHandledRightly`, `testABagChosenForOneTemplateStillWins`; UI
`testAChangeToAThingReachesATripStillAhead`.

---

## 18. Kits (`PackingCore/Kits.swift`)

A kit is a bundle of things always packed together, by stable thing ids. `Kit {id, name, emoji, note, itemIds,
createdAt, updatedAt, extra}`; `coerceKit` trims the emoji and de-duplicates `itemIds` (blank ids dropped, order
kept); `kitEmoji` = its emoji or 🧰; `clusterByKit(entries)` groups a list's lines by kit name at the first
appearance, loose lines staying in place. **In this app kits are data only**: they are imported from a backup, kept
in the `kits` table, carried in backups, and a deleted thing is removed from every kit (`deleteThing`); a row's
`kit` name travels on the membership into trip lines and share codes. No screen shows, makes or edits a kit, and
`clusterByKit` is not used by any screen. The only trace on screen is the number of kit records among
Settings' per-table device counts ("Kits").

Tests: `KitsTests` — `testCoerceKitDeDupsMemberIdsAndNormalisesFields`, `testNewKitSaneDefaultsAndTimestamps`,
`testKitEmojiOwnEmojiWinsElseTheDefault`, `testClusterByKitLooseEntriesStayInPlace`, `testAKitRoundTripsThroughJSON`;
`ImporterTests` (kit names survive an import).

---

## 19. Sharing a template (`PackingCore/ListSharing.swift`, `PackingLibrary/Sharing.swift`, the template parts of `Share.swift`)

Released 0.38 (27 Sep 2026). A template travels as a code inside a link `<web app address>#/l/<code>` that also
becomes a QR code; it opens in the web app for anyone, and in this app via Settings → Open a shared link.
- **Share** (template page → `template-share`): `shareLink(templateId:)` = the resolved template encoded with
  `encodeListShare`, or nil when encoding throws. The share sheet shows the QR code (when the link fits), the link,
  "Send…", "Copy link" ("Copied"), and "The link opens in the web app, and in this app under Settings → Open a shared
  link." (Share sheet details: Sharing spec.)
- **What the code carries** (short keys, empties left out): kind `tpl`, version 1, name (≤ 60), rows (≤ 400; a row
  with a blank name is skipped): name (≤ 60), flags bitfield (shortList 1, charging 2, liquid 4, restricted 8,
  perNight 16, consumable 32), Swedish name (≤ 60), qty (≤ 20), category, When, bag, note (≤ 200), charge type,
  section **by name** (≤ 40), kit (≤ 40), storage (≤ 60), packer (≤ 40), whose it is (`ownedBy`, ≤ 40, never an
  address — never the sync field `owner`), reminder flag, weight (rounded, if > 0), the condition lists and `sub`;
  then cover emoji (4 units), colour, group, role, transport, default bag (≤ 60), section names. Packed with an LZW
  "z." form when that is shorter. Photos, care and history are "deliberately left behind". The icon choice
  (`extra.iconKey`) does **not** travel. An empty template throws "This template has nothing on it to share."
- **Opening** (`Library.readShared` tries grab list, then template, then trip): the preview says "A TEMPLATE", the
  name and "<n> things"; **"Add as a new template"** (`shared-add`) → `importTemplate(shared)` → "Added. It is under
  Templates. Things you already had keep your details."; when he has a role-"" template of the same `normName`
  (`templateNamed`), also "Replace your <name> instead" (`shared-replace`) → "Replace your <name>?" with "Keep mine"
  / "Replace" → `importTemplate(shared, replacing: id)` → "Replaced your <name>. Trips that use it keep working."
- `listFromShare`: fresh ids (sections, rows, then the list), sections rebuilt and rows pointed at them by name
  (case-insensitive), roles `loose`/`container` arrive as ordinary templates, never `builtin`; a blank name becomes
  "Shared template"; a `partial` (`id`, `createdAt`) keeps a replaced template's identity. The roles `base` and
  `transport` (and the group, transport, colour, emoji and default bag) are KEPT: "Add as a new template" of a
  shared always-packed template gives him a second base template, which every new trip then packs.
- "Replace" is offered only against a template of role "" (`templateNamed`), so a base, transport or bag list
  is never replaced; "Add as a new template" is always offered, whatever the name. The shared role wins on
  Replace too: replacing his activity template with a shared base template turns his into a base template.
- `importTemplate`: each row whose name matches a thing he has (`normName`) is made a **link** to that thing ("his
  weight, bag, brand and notes stay his; only things new to him take the sender's details"), then `saveTemplate`.

Tests: `ListSharingTests` (18: round trip; whole link / bare code / link in a message; rejects non-templates and grab
codes; empty template; `listFromShare` rebuild; the two system bins; partial identity; five address tests; big
template squeezed; byte-for-byte against the web app; a web-app code opens here; id order; junk inside a code; a name
cut inside an emoji); `SharingTests.testATemplateArrivesWithoutTouchingHisThings` (his Towel keeps weight and bag,
Fins arrives with 700 g, Replace keeps the id); UI `testATemplateAndAGrabListAreSharedAndOpenedAgain`.

---

## 20. Your choices (`ListsScreen`)

### Purpose and origin
"The lists he authors himself: storage places, owners, packers, conditions and the 'When' timeline. They belong to
the account, so both devices show the same; an entry still in use cannot be removed by accident." Renamed from "Your
lists" in 0.34 so it never clashes with Your templates; the explanations are his test K.3 (1 Oct 2026: "a line or
two of explanations for each choice … so that this is totally clear to the user").

### How it is reached and left
Settings → "Your choices" card ("Storage places, owners, packers, conditions, \"When\" steps"; id `settings-lists`).
Left by "Done" (`lists-done`, filled slate) or swipe down. Container `lists-detail`. Mac: min 520 × 600.

### What is on screen
- "Your choices" (22 heavy ink, `choices-title`) · Done.
- Intro (15 medium muted, `choices-intro`): "The words the app offers you as buttons. Add your own with the field under
  each part; one that is still in use somewhere cannot be removed."
- A problem line when a removal was refused (15 semibold red, `lists-problem`).
- Five parts, in order, each: a heading band in slate (`choices-heading-<kind>`), a hint (15 medium, ink 85 %,
  `choices-hint-<kind>`), the entries, and an add row.
  | kind | heading | hint (exact) |
  |---|---|---|
  | `places` | Storage places | "Where a thing is kept at home — a cupboard, the garage, the basement. You give a thing its place under Kept at home; a trip sorted by From where then lists what to fetch room by room." |
  | `owners` | Owners | "Whose a thing is — you, your partner, a child. You pick it under Whose it is on a thing, so on a shared trip everyone sees which things are theirs." |
  | `people` | Packers | "Who packs a thing. You set it in the All your things table (Packed by), so you can see who is in charge of what." |
  | `conditions` | Item conditions | "How worn a thing is: New, Good, Worn, Needs replacing. You set it under Condition on a thing; a thing that needs replacing is suggested on To buy." |
  | `phases` | "When" steps | "The steps of packing, from a week ahead to the day you leave. Every thing has its When, and a trip shows its list in this order, step by step." |
- Entry row (`list-<kind>-row-<n>`, hairline under): the label (17 medium ink), the number of uses when > 0 (14 bold
  monospaced muted), a ✕ (40 × 40, `list-<kind>-remove-<n>`, "Remove <label>").
- Add row: field "Add to <heading in lower case>" (`list-<kind>-add-name`; Return = Add) and "Add" (slate,
  `list-<kind>-add`); `needsLine` "Type a name first." (`list-<kind>-add-needs`).
- Footer: "These belong to your account, so both your devices show the same." (14 muted).

### Behaviour (`PackingLibrary/SettingsLists.swift`)
- Entries: places = his stored order, or the 12 `DEFAULT_STORAGE_LOCATIONS`; owners = his list A–Z (empty by
  default); packers = his, or the factory two (`DEFAULT_PEOPLE`); conditions = his, or New/Good/Worn/Needs replacing;
  When = his timeline, or the factory seven.
- Uses (`usesOf`): things' storage / ownedBy / packer / condition / phase by `normName`; for When also every trip
  line's and every membership's phase.
- Add: places/owners → `setNames(kind, list + [name])` (trimmed, de-duplicated by `normName`, so a repeat silently
  vanishes); packers → a person with colour `PERSON_COLORS[count % 8]`; conditions → `newCondition`; When →
  `newPhase` appended, `setTimeline`. A list that equals the factory one is stored as **no rows**.
- Remove: in use → "<label> is still used by <n> thing(s), so it stays." and nothing changes; else removed. Removing
  the last entry of a kind brings the factory list back (no rows = defaults).

### Tests
UI `testHisOwnListsAreAddedAndProtectedWhileInUse` (title "Your choices", each hint > 80 characters, "Garage shelf"
added as place row 12, used on a thing, then refused with `lists-problem`); `testEveryAddButtonIsReadyAndSaysWhatIsMissing`
(`list-places-add`); `testTheEditorsLeadWithTheirHeadings` (five headings). Model `SettingsListsTests` (5).

---

## 21. Every other place that puts things on, or takes them off, a template (cross-references)

| Where | Function | Spec |
|---|---|---|
| Template page: type a name / Choose from your things / ✕ | `addToTemplate`, `putOnTemplate`, `removeFromTemplate` | here |
| Row editor | `updateMembership`, `addSection` | here |
| Thing editor "On these templates" (all templates but the bag list) | `setOnTemplate` on save | Things spec |
| Care table: "On these templates" columns; "How many" / "Section" per template (editable only when the thing is on exactly one template) | `setOnTemplate`, `updateMembership` | Table spec |
| Review: a missed thing onto a chosen template (skipped if a row of that name is already there) | `addToTemplate` | Review spec |
| Refine: Drop | `setOnTemplate(on: false)` | Refine spec |
| Bags: add / delete a bag | `setOnTemplate` on the bag list | Bags spec |
| Shared template import | `importTemplate` → `saveTemplate` | §19 |
| Backup import | `saveTemplate` per list | Backup spec |

---

## Open questions / discrepancies

Found by reading the code; none of these is covered by a test unless said. Tags: **[bug]** the code does
something wrong or surprising; **[rule-break]** it breaks one of his standing rules; **[doc]** a comment or
document disagrees with the code; **[untested]** behaviour that matters and no test pins; **[idea]** worth
deciding before a rewrite.

**Data and behaviour.**

1. [bug] **The thing's own note (and qty) gets frozen into rows**: `membershipFromResolved` stores the
   *resolved* `qty` and `note` (which fall back to the thing's own when the row is blank). So putting a thing
   with a note on a template (`putOnTemplate`/`addToTemplate` via `resolveItemAlone`), or ANY later
   `saveTemplate` of that template (adding or taking off any row, a shared-template import), copies the
   thing's note and qty into every membership of the template — after which a change to the thing's note
   no longer reaches those rows, contrary to "Blank means the same as the thing itself". The thing's note is
   editable (thing editor, On site). Untested.
2. [bug] **The row editor drops condition values it does not know.** Save rebuilds seasons / contexts /
   transports / food by filtering `SEASONS`, `CONTEXTS`, `TRANSPORTS` and the `CATERING` ids, so a stored
   value spelt differently (from the web app or an import, e.g. "summer") is silently removed, although the
   membership model keeps any string. Untested.
3. [bug] **Order of picked things**: `putOnTemplate` gets `Array(picked)` from a `Set`, so several picked
   things land on the template in an unpredictable order. Untested.
4. [bug] **Typing an existing thing's name on a template that already has it** adds a second row (no guard
   in `addToTemplate`), while the picker and the review both guard against it. Intended "same thing twice"
   support, or a slip? Untested.
5. [bug] **"Add as a new template"** with a name he already has creates a second template of that name —
   the very thing `NewList` and Rename refuse, and that the health check reports as "… appear(s) twice. Two
   libraries may have met on this account." (`Health.swift`). The UI test
   `testATemplateAndAGrabListAreSharedAndOpenedAgain` does exactly this (a second "Hiking").
6. [bug] **Importing links takes the sender's spelling**: a linked row (`link == true`) still carries its
   name, and `applyIntrinsic` writes it onto his thing. The names already match by `normName`, so only case
   and spacing can change (a shared "towel" turns his "Towel" into "towel"). Untested.
7. [bug] **Sharing an empty template**: `shareLink` is nil, and the share sheet then says "This is too big
   for a link. Share it as a file instead." — the wrong reason, and there is no file for a template.
8. [bug] **`suggestedIcon`'s "train" rule** is a substring test, so "Strength training", "Swim training" etc.
   get the **train** icon (rule 7 runs before strength and swim). Likewise "camp" (rule 13) catches any name
   containing it once the camper rule has passed.
9. [bug] **"Same as the thing (X)"** in the row editor names the thing's own bag, but a blank row bag
   resolves to the template's `defaultContainer` first. Only matters for templates imported with a default
   bag (no UI sets one here).
10. [bug] **"Only on:" lists contexts on a non-WET template**, where the editor hides Context and a trip
    build ignores it — the row claims a limit that has no effect.
11. [bug] **`TableColumns` calls `containerNames(library.templates)`** — the unresolved shells — so his own
    bags are never offered in the table's bag column (the trap `Bags.swift` warns about). Outside these
    files; flagged because it is `containerNames`.
12. [bug] **Your choices' refusal** says "<label> is still used by <n> thing(s)", but for When steps n also
    counts trip lines and template rows.
13. [bug] **`followThing`'s "today"** is the UTC date (`nowISO()`), while the screens use the device's local
    date: around midnight a trip that ended "yesterday" locally can still be followed, or one ending today
    skipped.
14. [untested] **A shared base or transport template keeps its role.** "Add as a new template" gives him a
    second always-packed (or transport) template that every matching new trip packs; Replace can turn his
    activity template into a base one.
15. [untested] **Three `.sheet` modifiers on the Templates tab's scroll view** (template, Search, New),
    although the code elsewhere calls several sheets on one view "a trap met in Search".

**What to decide.**

16. [idea] **Replace drops his icon choice and his row exceptions**: the shared list has no `extra`, so the
    stored `iconKey` is lost; linked rows get blank bag/When exceptions and the sender's
    conditions/qty/note/section; his rows not in the shared list are taken off.
17. [idea] **`TemplateUse` counts future trips** as "last taken": the card can say "in 30 days · <trip>".
18. [idea] **Template summary**: "<N> things" counts every thing (bags and things on no template too) and
    "<K> trips packed from them" counts every trip. (The code comment's example still says "lists".)
19. [idea] **Row editor's Add-a-section** writes the section immediately; Cancel leaves an empty section on the
    template. There is no UI to rename, reorder or delete a section, to reorder rows, or to change a
    template's activity area, role, transport, colour, emoji or default bag after creation; no UI for a
    row's weather tags, kit or reminder type.
20. [idea] **A row change does not reach trips already made** (`followThing` runs only for thing edits); only
    a rebuild (Trip settings → Save) applies it.
21. [idea] **Search can open a role-"loose" template** (it excludes only the bag list), which the Templates
    tab never shows.
22. [idea] **Device-wide memories**: the template page's grouping (`ams.template.grouping`) and the picker's
    folds/grouping are one setting for all templates; fold keys of renamed places/kinds stay in
    `ams.pick.folded` for ever.
23. [idea] **`NewList`**: `canMake` is unused; the `newlist-needs` line does not clear on typing (other needs
    lines do); the bag list "Containers" counts as a taken name although he never sees that name.
24. [idea] **`groupBy("container")`'s "Unpacked"** label is dead code: `groupByKey` already turned a blank bag
    into "Other".

**Comments and documents.**

25. [doc] **ThingGrouping's doc** says things read A–Z inside a group; `.section` keeps template order, and the
    template page's **When** grouping uses `entriesByPhase` directly (template order), while the picker's
    When sorts A–Z.
26. [doc] **Picker row "aside"** comment says "never the one it is grouped by" — under Into, a thing with no
    storage place shows its bag (the thing it is grouped by).
27. [doc] **Release log**: the row editor's "Only on some trips" pills (2 Oct 2026) have no "What's new" entry;
    only 0.55's "Only on: Summer" line mentions them.
28. [doc] The `Cover` comment "the app adds no art of its own" predates the suggested icons.

**His standing rules.**

29. [rule-break] **Choose from your things, "Add" with nothing ticked**: the comment says it "says so under
    the title instead of doing nothing silently"; the code (`putOn`) just returns — nothing is shown. His
    rule: a main button pressed too early says what is missing. Untested.
30. [rule-break] **Cover "Letter" with an emoji**: when a template carries an emoji (imported), choosing
    Letter (or having no suggestion) shows the **emoji**, while the picker's Letter tile shows the first
    letter. Breaks the "no emoji" rule stated in `TemplateIcons.swift`.
31. [rule-break] **`TEMPLATE_COLORS`** (web app parity) contains teal `#14b8a6` and cyan `#06b6d4`;
    `docs/colours.md` says "Not teal … Do not use teal for anything new". Any template without its own colour
    may get teal.
32. [rule-break] **Text under 15 pt** in this area — card "used" line 12, icon labels 12, "WHAT IS IT CALLED"
    12, row qty/note and tags 13, Delete template 13, "You already have a template called that." 14, the
    delete question's text 14, the row editor's "Blank means…" 14, picker pills/aside/counts 14, Your
    choices counts and footer 14 — while `Headings.swift` says "Nothing under 15, so it still reads without
    glasses".
33. [rule-break] **`DEFAULT_PEOPLE`** (factory packers, `SharedRows.swift`) holds two real first names in a
    public repository.
