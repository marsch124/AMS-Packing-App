# Templates — the building blocks, and how things sit on them

> Verified against the code on 5 Oct 2026 (app 0.60); the spec pass's fixes of spec 04 (the same day,
> release 0.62) are written in, and Arrange (§6a, his layout "C", 0.63) with its model (§13a).

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
deleting a template **never deletes a thing**. A row's section is set on the row (§7), by dragging it under a
heading (§6a, Arrange) and — since 0.64 — from the thing's own page, one Section per template it is on (spec 05,
item 6a: the FIRST place when it is on a template twice). Since 0.68 a template's sections themselves can also be
renamed, moved and removed from that Section list on a thing's page (his ask, 7 Oct 2026: "I would like to be able to
Rename, Change and Delete Sections from this here as well"), held until the thing is saved and written by Arrange's
own functions (§13a, `applySectionEdits`).

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
`ListSharing.swift`; `PackingLibrary/Library.swift` (template parts, and arranging a template's headings and
rows — §13a), `EditLists.swift`, `Bags.swift` (list role and
`shownName`), `TemplateIcon.swift`, `TemplatePicking.swift`, `TemplateUse.swift`, `ThingFollows.swift`,
`Sharing.swift` (template parts), `TemplateRows.swift` (a row's own answers, the row editor's Save, covers'
letter and colours, which templates are shown and what they add up to, free names — the spec pass). Storage and
sync are in `docs/store.md`; colours in `docs/colours.md` (both linked, not repeated).

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
- Its "Counts as" (0.70 — which Apple Health workout it meets in the trip review) is stored in the template's
  `extra["countsAs"]` (`Library.countsAsKey`): a `WorkoutKind` raw value (`swim` … `diving`) or `"none"`; absent =
  the name decides (see §6 and chapter 07 part 7).

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
1. **Header** — the shared tab header `ScreenHeader` (spec 06, "The tab header"; 0.67), bottom padding 4 — on the
   Mac pinned in the window's title bar strip, after the window buttons, the page scrolling under it. Its
   first line holds the title and, on the SAME centre line at the right, 8 pt apart, the magnifier and + New;
   until 0.67 the row was aligned on the title's baseline with 14 pt above it, and the magnifier stood 10 pt
   higher than the title (his note on 0.63, "Overall, icons are not aligned"):
   - "Your templates" — Title 2 bold, violet (`AppSection.templates.color`), one line (scales to 80 %), id
     `templates-heading`.
   - Under that line the **summary** — Subheadline, `Theme.muted`, id `templates-summary`:
     `"<T> template(s) · <N> thing(s)"` plus `" · <K> trip(s) packed from them"` only when K > 0. Singular when the
     number is 1. `Library.templateSummary(shown)`: T = the templates shown on this screen (bag list and "loose"
     lists excluded); N = the things ON them, each once however many templates it sits on (bags, the loose bin's
     things and things on no template are not counted); K = the trips packed from them — a trip that names one of
     them as an activity or has a line from one of them. "The words should match the numbers" (the spec pass,
     5 Oct 2026; until then N was every thing he owns and K every trip). Separator " · " (U+00B7).
   - The magnifier `SearchButton` (24 pt drawn magnifier in a (`Metrics.tap` + 4) × `Metrics.tap` hit area —
     40 × 36 iPhone, 30 × 26 Mac — muted, id `search-open`, label "Search everything") → opens `SearchScreen`
     as a sheet.
   - "+ New" — Subheadline semibold white on a violet capsule, `Metrics.chip` tall, horizontal padding 12, id
     `templates-new` → opens `NewList` (§5) as a sheet.
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
     (so with the sample library: 0 = Common base, 1 = Hiking, 2 = Swim). Tap → opens `TemplateDetail` (§6).
- No empty-state text: a ready library with no templates shows the header, the summary "0 templates · …" and the
  Refine door only.

### Behaviour
- **One sheet with a destination** (`opened: Opened?` — `.template(id)`, `.search`, `.new`): a card, the
  magnifier and "+ New" each set it. Not three `.sheet` modifiers: "SwiftUI does not reliably present a second
  sheet on a view while the first is still closing" — the trap met in Search (0.17), tidied here by the spec pass
  (5 Oct 2026).
- `activityAreas(all)` takes `library.shownTemplates()` (every template but the bag list and the loose bin,
  resolved, sorted A–Z with `jsLocaleCompare` default sensitivity) and builds, **omitting empty areas**:
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
- Every render recomputes `shownTemplates()` and `templateUse(today: Today.local)` (§16).
- `NewList` hands back the new template → `model.change { saveTemplate(list) }` and its id is kept; when New's
  sheet has closed (`onDismiss`) the new template's page opens straight away ("a list he cannot see the inside of
  is not made yet") — never on top of New.

### Data
Reads `library.templates`, `memberships`, `items`, `trips`. Writes only via `saveTemplate` (new template). One
sheet: template page, Search or New.

### iPhone vs Mac
Same layout on both. On the Mac the whole app column is at most 720 wide (`RootView`), so cards are wider; sheets
appear as Mac sheets with the minimum sizes given per screen below. Escape (⌘. on an iPhone keyboard) presses each
sheet's Cancel — or its Done where it has none — and never a Save, a Make or an Add (`.keyboardShortcut(.cancelAction)`,
0.62; spec 06 §20) — on a template's page while arranging, Escape ends Arrange first (§6a, 0.63); Return has no
app-defined meaning beyond a text field's `onSubmit` (no `.defaultAction`, no `.onExitCommand`). On the iPhone every
sheet here can be swiped down, except a template's page while arranging (`interactiveDismissDisabled`, §6a, 0.63).

### Tests
- UI: `testEveryTabOpensItsScreen`; `testEveryDoorOfTheTemplatesTabOpens` (twice in a row: a card, Done, the
  magnifier, Done, + New, Cancel — each opens the moment the one before has closed; the Hiking card says
  "Next: in 30 days"); `testATemplateOpensAndCloses` (row-0 and row-2 exist — three sample templates;
  `templates-area-GA` reads "GA · GOAL ACTIVITY"; summary contains "templates"; a card opens `template-detail`,
  Done closes it); `testAnEmptyDeviceShowsTheTwoDoors`; `testHeMakesAListOfHisOwn` (heading reads "Your templates");
  `testRefineOffersWhatTheReviewsFoundAndKeepAndDropSettleIt` and `testTheLoopShowsWhereATripStands` (use
  `refine-open` here); `testEveryTabsHeaderIsOnOneCentreLine` (0.67: `search-open` and `templates-new` within
  1.5 pt of the centre line of `templates-heading`; on 0.66 the magnifier was 10.2 pt and + New 2.5 pt off).
- Model: `ListsTests.testOrderActivities*` (4 tests); `CreateTripTests.testTheChoicesAreHisGroupsInHisOrder`;
  `TemplateFacesTests.testTheTemplatesLineCountsWhatItSays` (the bag list and the loose bin are not shown; things
  on them counted once; a trip packed from none of them not counted).
- **Not covered:** the "By transport" and "Other templates" areas, the exact summary wording on screen.

---

## 2. A template card (`TemplateCard`)

### What is on screen
A card (`RoundedRectangle(12)` filled `Theme.card`, 1-pt `Theme.line` stroke, padding 10, min height 104, full
column width, whole card tappable):
1. Row: the **cover** (§3) at 34 pt · spacer · the number of rows on the template (`list.items.count`, i.e.
   memberships whose thing exists — a thing twice counts twice) 15 heavy monospaced digits, muted.
2. The template's **name** — 16 semibold, ink, at most 2 lines, wraps.
3. The **"used" line** (`Library.TemplateUse.line(use, today: Today.local)`) — 12 medium, one line, id
   `template-used`; muted, or muted at 65 % opacity when the template has never been used ("Quiet, not invisible:
   the divider colour could not be read on either a white or a black background").

### Behaviour — `TemplateUse.line(use, today:)` (PackingLibrary, `TemplateUse.swift`)
- No use record, or `use.trips == 0` → "Never taken along".
- A trip that drew on it has BEGUN (start date ≤ today, §16): `ago = countdownLabel(daysUntil(lastDate, today))`
  (today = the device's local `yyyy-MM-dd`): "Today", "Yesterday", "<d> days ago". The line is
  `"<ago> · <trip name>"` ("the WHEN first: it is the part that is always worth reading, and the part that still
  shows when a long trip name is cut off"), or `"Last: <trip name>"` if `ago` is empty (unreadable date).
- Else, a trip still AHEAD: `"Next: <when> · <trip name>"` with when = "in <d> days" or "tomorrow" (first letter
  small); `"Next: <trip name>"` if the date cannot be read. The sample shows "Next: in 30 days · Weekend in the
  hills". (Until the spec pass a trip still ahead counted as "last": the card said "in 30 days · …".)
- Else (no trip with a date, or the winning trip has no name) → "Taken on <n> trip(s)".

### Tests
- Model: `TemplateUseTests` (§16), `testATripStillAheadIsNextNotLast` pins the wording. UI
  `testEveryDoorOfTheTemplatesTabOpens` reads "Next: in 30 days" on the Hiking card. **Not covered:** the 65 %
  opacity, the count.

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
- A rounded square (`cornerRadius = size × 0.28`) filled with **`Library.coverColour(list)`**: the template's own
  `color` if it is a valid hex colour (his data, kept whatever it is), else a stable pick by `jsHash31(id)`
  (`h = h*31 + utf16 unit`, wrapping at 32 bits; falls back to the name when the id is empty) modulo 10 from
  **`COVER_COLOURS`** — the web app's `TEMPLATE_COLORS` (`#7c5cd6 #3b82f6 #06b6d4 #22c55e #f59e0b #ef4444 #ec4899
  #14b8a6 #8b5cf6 #64748b`, kept as they are for the parity check) with cyan `#06b6d4` → orange `#f97316` and teal
  `#14b8a6` → indigo `#4f46e5` ("Not teal … Do not use teal for anything new", `docs/colours.md`; the spec pass,
  5 Oct 2026). Every other template keeps the colour the web app gives it (`listColor`, pinned: id "fixed-id" →
  `#8b5cf6`).
- If `TemplateIcons.icon(Library.icon(of: list))` exists → that icon drawn white at `size × 0.66`
  (`IconMark`, stroke 1.9 × size/24, round caps and joins).
- Otherwise its letter, white, heavy, font `size × 0.46`: `Library.coverLetter(list)` = the first character of the
  trimmed name, upper-cased. **Never the template's `emoji`** (a web-app template may carry one): no emoji in this
  app (until the spec pass the emoji showed here).
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
  7. word "train" or "trains", or has "railway" → `train` (whole words since the spec pass, 5 Oct 2026:
     "Strength training" and "Swim training" were given a train)
  8. has "ferry" or "boat" → `ferry`
  9. has "golf" → `golf`
  10. has "hik" or "trek" → `hiking`
  11. has "climb" → `climb`
  12. word "ski" or has "skiing" → `ski`
  13. word "camp", "camping" or "camps", or has "campsite", "campground", "campfire" → `tent` (whole words since
      the spec pass: "Campus" was a tent)
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
  `testATrainAndATentNeedTheirWholeWord` ("Strength training" → strength, "Swim training" → swim, "Brain
  training" → nil, "Night train" → train, "Campus visit" → nil, "Training camp" → tent);
  `TemplateFacesTests.testACoverShowsALetterNeverAnEmoji`, `testNoTemplateIsGivenTealOrCyan` (200 ids: never teal
  or cyan, every colour that was never teal unchanged, his own teal kept).
- **Not covered:** an unknown stored key.

---

## 4. The icon picker (`IconPickerScreen`)

### How it is reached and left
Tap the cover on a template's page (`template-cover`). Left by: "Cancel" (`icon-cancel`; Escape too, 0.62), by any
pick (each pick saves and closes), or a swipe down on the iPhone.

### What is on screen
- Top row (padding 16): the template's cover (40), its name (20 heavy ink, 1 line, shrinks to 80 %), spacer,
  "Cancel" (outlined `HeaderButtonStyle`, muted tint).
- Scroll (side 16, bottom 24), spacing 10:
  - Two tiles side by side: **"Suggested"** (id `icon-suggested`; shows the suggested icon at 30, or the letter
    (`coverLetter`) 22 heavy when there is no suggestion; selected when no choice is stored) and **"Letter"** (id
    `icon-letter`; the letter 22 heavy; selected when the stored choice is "letter").
  - `SectionTitle` "All icons" (shown in capitals, 18 heavy, kerning 0.8, 16 above).
  - The 50 icons in rows of **5** (plain `HStack` rows, not a lazy grid: "the Mac builds only what is on screen").
    Each tile: icon at 30 + its label; id `icon-<key>`; selected when a choice is stored and the icon in force is
    this key.
- Tile look: mark 32 high; label 12 bold, 1 line, shrinks to 70 %; min height 74, full width share; selected =
  filled with the template's own colour (`coverColour`), white mark and label, 2-pt stroke in that colour, trait
  `isSelected`; not selected = `Theme.card`, ink mark, muted label, 1-pt `Theme.line` stroke.
- Container id `icon-picker` (`children: .contain`). Mac: min 520 × 620.

### Behaviour
- `pick(key)` → `model.change { setTemplateIcon(id:, key:) }` then dismiss. Suggested = nil (removes the key),
  Letter = "letter", an icon = its key. Picking the very icon that is suggested **stores** it, so it no longer
  follows later renames.
- When the stored key is not one of the 50 (e.g. from a newer build), no tile is ringed and the cover shows the
  letter.

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
"+ New" on the Templates tab (`templates-new`). Left by "Cancel" (`newlist-cancel`; Escape too, 0.62 — nothing is
made, a typed name included), swipe down (iPhone), or
"Make the template" succeeding (closes and the new template's page opens).

### What is on screen
- Top row (padding 16): "A new template" — 20 heavy violet, id `newlist-title`; spacer; "Cancel" (outlined,
  muted; the style's own 17 bold — 16 until 0.62, spec 06 §20).
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
  - When pressed too early, a line under it (the shared `needsLine`): 15 bold red, at the left, id
    `newlist-needs`; it goes as soon as the name changes.
- Container id `newlist-detail`. Mac: min 440 × 480.

### Behaviour
- `taken` = `Library.templateNameTaken(name)`: `normName(name)` is not empty AND a template **other than the bag
  list** has the same `normName` (trimmed, lower-cased, whitespace runs collapsed). The bag list's stored name
  "Containers" is never shown ("Bags"), so it is not taken (the spec pass, 5 Oct 2026); Worth a look counts the bag
  list apart, so a template he calls "Containers" is not read as two libraries meeting.
- `make()`: blank (after `jsTrim`) → needs "Give the template a name."; taken → "Pick a name you do not have
  yet."; else clears needs, calls `made(newList(name: jsTrim(name), group: chosen))` and dismisses. The new list:
  role "", no items, no sections, no cover, fresh id, `createdAt`/`updatedAt` now; `coerceList` keeps the group only
  if it is a GROUP id.
- The caller saves it (`saveTemplate`) and opens it.
- The needs line is the shared `needsLine`: it clears as soon as the name changes (until the spec pass it stayed
  until the next press).
- There is no way here (or anywhere in this app) to make a `base` or `transport` template, or to set a colour,
  emoji or default bag.

### Tests
UI `testHeMakesAListOfHisOwn` (title "A new template"; Make enabled; empty press says "…name…" and the line goes
once a name is typed; "Hiking" shows `newlist-taken` and a press says "…do not have…"; "Mushroom picking" + GA →
page opens; summary changes; the
"Other templates" area does not appear); `testANewTemplateAsksForItsActivityArea` (question text, "No activity
area").

Model `TemplateFacesTests.testANameIsTakenOnlyByATemplateHeCanSee` (the bag list's "Containers" is free;
renaming to it is allowed and is no worry; two bag lists still are).

---

## 6. One template (`TemplateDetail`)

### Purpose and origin
"One template: its things under his headings; a thing can be added at the foot and taken off with ✕ (the thing
itself survives)." Grew through: rename/delete (0.16), headings in capitals (0.40, H.13), ✕ asks first (0.40,
H.5), Group pills (0.42, H.3: "group and sort the items in a template in the same way as when you pack"), Choose
from your things (0.42, H.9), icon (0.46), "Only on:" line (0.55, field test 4.4), Find (0.60, 4 Oct 2026: "add a
search function so that the user can find a specific item without the need to scroll"), Arrange (0.63, §6a: his
pick "C" of three pictured layouts, 5 Oct 2026).

### How it is reached and left
- Reached: a card on the Templates tab; a Search result; straight after "Make the template".
- Left: "Done" (`template-detail-done`; Escape too, 0.62 — while arranging Escape ends Arrange instead, §6a),
  "Delete the template", swipe down on the iPhone (not while arranging). A rename typed but not confirmed (Rename /
  Return) is **discarded** on leaving — by Escape too.
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
- **Share** — `ShareDoor(id: "template-share")`: outlined violet capsule (`HeaderButtonStyle`, centred on the
  icon's line like Done) with the drawn share mark and "Share", 6 pt apart; label "Share". The mark is
  `ShareMark` framed 22 × 22 and drawn through `GridShape`, so it is centred on the word's line (0.67: measured
  in the day picture, the mark's middle and the capitals' middle are 0.2 pt apart). Until 0.67 it was framed at
  18 while drawn on its 24-pt grid: it hung 3 pt low and right, its box through the pill's lower edge — his
  note on 0.63, "The share buttons is not aligned with the icon". Opens the share sheet with title
  `Share “<name>”` and `link = library.shareLink(templateId:)` (§19).
- **"Done"** — `HeaderButtonStyle` filled violet (white 17 bold on a capsule, min height 36; 16 until 0.62).
- Under the row, `needsLine` id `template-rename-needs` (15 bold red), cleared as soon as the typed name changes.

**Group pills** (`FlowRow` spacing 6, side 16, bottom 4): the word "Group" (15 heavy muted, min height 36), then
one capsule per way: on = 15 heavy white on violet; off = 15 medium ink on `Theme.card` with a `Theme.line`
stroke; min height 36; ids `template-grouping-<raw>` (`section`, `when`, `into`, `fromWhere`, `kind`, `name`);
trait `isSelected` on the chosen one. Labels: Section · When · Into · From where · Kind · A–Z.
- "Section" is offered **only when at least one row has a non-empty section** (even an id that belongs to another
  template). His lists are built in sections ("511 of his 538 rows sit in one").
- A tap on any Group pill also ends Arrange (§6a). While arranging, only Section can be lit (on a template with no
  headings no pill is lit: the page then shows his own order, not a grouping).

**Arrange** (§6a) — a pill on its own row under the Group pills, offered while the page reads by Section, or on a
template with no section in use, and only when the template has a row or a heading.

**Find** is not shown while arranging (§6a).

**Find** (shown when the template has at least one row, or while something is typed — and not while arranging;
side 16, top 6):
- TextField "Find a thing on this template" — 17 regular ink, min height 40, card fill, 10-radius hairline border;
  with the shared ✕ (`clearButton`): field id `template-find`, ✕ id `template-find-clear` ("Clear the search"),
  the ✕ shown only while the field holds text; one tap empties it and keeps the keyboard.
- Beside it, **"<found> of <all>"** — 15 bold monospaced muted, id `template-find-count` — only while the query is
  not blank AND finds something ("'0 of 4' would say again what the line under it says").

**The rows** (`KeyboardAwayScroll` + `LazyVStack(spacing: 0)` — 6 until 0.67 — side 16, bottom 24) — while
arranging, the arranging list (§6a) stands in their place. **A row is as tall as its words** (0.67): at least
**`Metrics.line` — 30 pt on the iPhone, 22 on the Mac** — top to top, no space between rows (42 until 0.67). His
words, 6 Oct 2026, testing 0.63: "Far too much line spacing between the items in a template … Change this
dramatically, not only a bit."
- A query that finds nothing: "Nothing on this template is called that." — 16 medium muted, 16 above, id
  `template-find-none`.
- For each group, its **heading**: the title in Headline (not capitals since 0.62), **10 above and 2 below** (16
  above, and 6 between it and each neighbour, until 0.67 — so the heading's words now stand 10 pt under the row
  above, 22 until then); colour = the phase's
  colour made readable (When grouping) or violet (other groupings); id `template-group-<g>` (g = position of the
  group on screen).
- Under it each **row** (HStack spacing 4, a hairline under it):
  - A button (id `template-item-<n>`) holding: the thing's name (Body ink); right under it (0 apart — 2 until
    0.67) a second line when it has a quantity or note: `"×<qty>"` and the note joined by " · " (Footnote muted, 1
    line); a third line when the row is limited: **`"Only on: <tags>"`** (Footnote semibold violet, 1 line;
    `Library.onlyOnWords(row, on: template)` — Context listed only on a WET template, where a trip reads it); and on
    the right the bag the row resolves to (`item.container`, Subheadline muted, 1 line). 2 pt above and below the
    words (3 until 0.67), at least `Metrics.line` tall; a row with a second or third line grows. Tap → the row
    editor (§7) as a sheet.
  - The **✕** — a drawn cross on the 24-pt grid (stroke 1.8, muted) shown at `Metrics.glyph` — 20 / 16 — with
    `onGrid` (22 pt until 0.67), in a **`Metrics.lineButton` × `Metrics.line`** hit area — 40 × 30 on the iPhone,
    30 × 22 on the Mac (40 × 36 until 0.67) — so it is never taller than its row and sits beside the bag, on the
    row's own line; id `template-item-<n>-remove`; label "Take <name> off this template". Tap → the take-off
    question (below), with a 0.15 s ease-out.
  - n = the row's position **as read**, top to bottom across all shown groups (keyed by membership id).
  - Each row view is given the identity `"<memId>#<n>"` (see Traps).

The foot below — Choose from your things, Type a new thing, Activity area and Delete — steps aside while a
heading's name is being changed in Arrange (the keyboard is up; seen on the screen, 5 Oct 2026: the list was left
a sliver and Remove heading was out of sight). It stays while arranging otherwise, as his picture had it.

**Choose from your things** — `PickThingsDoor` (side 16, top 10): wide outlined button (drawn list mark 22,
"Choose from your things" 17 bold violet, min height 48, 8 % violet fill, 1.4 stroke, radius 12); id
`template-pick`; owns its own sheet → `PickThingsScreen` (§8).

**Type a new thing** (side 16, vertical 10): TextField "Or type a new thing" (17 medium ink, min height 44, card
fill, hairline border; id `template-add-name`; Return = Add) and **"Add"** (`FieldButtonLabel`: 16 bold white on
violet, radius 10, min height 44; id `template-add`). `needsLine` id `template-add-needs`.

**Counts as** (0.70, chapter 07 part 7 — Apple Health in the trip review; `CountsAsField` in
`ReviewHealth.swift`). Only on an activity template (role ""), on both devices, above the Activity area row, side
16, bottom 6, left-aligned: a drop-down (`DropDown`, heading `.beside`, violet) — "Counts as" (15 semibold muted,
id `template-counts-as-title`) then the field (id `template-counts-as`) showing the kind it meets now: his pick
(`extra["countsAs"]`), else the one its NAME meets (`WorkoutKind.named`, compared as `WorkoutTone` compares:
`normName`, no white space — "Swim", "Breath work", "Mobility & Breath work", "Diving and Freediving"…), else
"Nothing". Its list (`template-counts-as-list`): rows `template-counts-as-0…8` = Swim, Bike, Run, Strength,
Mobility & breath work, Hiking, Golf, Climbing, Diving, and `template-counts-as-9` = Nothing. A choice →
`setCountsAs(templateId:to:)` (stored even when it is what the name says; "none" = meets nothing whatever its name).
The common base and transport templates have no field and never meet a workout.

**Activity area and Delete** (one row, side 16, bottom 8):
- Only on an activity template (role ""): at the left, **"Activity area: <GA / WET / OE / none>"** — 15 semibold
  violet plain text button, min height 36, id `template-area`, accessibility value the area id or "none". Tap →
  in place of the row, a card (padding 14, card fill, violet 1-pt border, radius 12, side 16, bottom 10): "In which
  activity area should it live?" (16 heavy ink) with "Cancel" (outlined muted, `template-area-cancel`), then the
  rows New offers — "GA · Goal Activity", "WET · Workout, Exercise & Training", "OE · Other Events", "No activity
  area" (min height 44, hairline under; the current one 16 heavy violet with `isSelected`, else 16 medium ink; ids
  `template-area-GA`, `-WET`, `-OE`, `-none`). A press files it (`setTemplateArea`, §14) and the card goes. The
  spec pass (5 Oct 2026): New asked for the area and nothing could put a wrong answer right.
- At the right, when not asking: `SmallDeleteButton` "Delete template" (13 semibold red text in a red 60 %
  outlined capsule, min height 30; id `template-delete`). When asking, in place of the row a card
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
  another template (`templateNameTaken(except: itself)` — any role but the bag list, compared by `normName`)
  already has the name → "You already have a template called that."; else `renameTemplate(id:to:)` (§14), the
  typed state is dropped and the field loses focus. Only a case change of its own name is allowed (it is not
  "another" template).
- **Take off** ("Take it off"): `removeFromTemplate(templateId:memId:)` → the template resolved, the row with that
  `memId` removed, `saveTemplate` (§13). The thing survives in Your things and on its other templates; past and
  current trips are not touched.
- **Add** (`add()`): blank after `jsTrim` → needs "Type a thing first."; a thing of that name already ON this
  template (`isOnTemplate`, by `normName`) → needs "“<name>” is already on this template." and nothing changes (the
  typed text stays; the spec pass, 5 Oct 2026 — it used to add a second row); else
  `addToTemplate(templateId:name:)` (§13), the field emptied, and **Find emptied** too ("A search left on would
  hide the new thing… and then Add looks as if it did nothing"). A name he already owns (by `normName`) puts THAT
  thing on (one thing, one more place, bringing its own defaults); a new name makes a new thing (bag "Carry-on /
  hand luggage", When = the first non-task phase, by default "≥1 week ahead").
- **Delete template** ("Delete the template"): `deleteTemplate(id:)` (§14) then dismiss. Things stay; trips keep
  their lines.

### Data
Reads `resolvedTemplate(id:)`, `templateNameTaken`, `isOnTemplate`, `shareLink(templateId:)`, and while arranging
`arrangeLines(templateId:)` and `sectionNameTaken`. Writes through `renameTemplate`, `removeFromTemplate`,
`addToTemplate`, `deleteTemplate`, `setTemplateArea`, `setCountsAs` (0.70), `setTemplateIcon` (cover), while arranging `dropLine`
(→ `moveSection` / `moveRow`), `renameSection` and `removeSection` (§13a), and through the sheets. AppStorage:
`ams.template.grouping` (Arrange itself is not remembered: the page always opens with it off).

### iPhone vs Mac
Same content; Mac min size 480 × 600. The header holds cover, name field, Rename, Share and Done in one row on
both.

### Tests
- UI: `testATemplatesRowsSitTight` (0.67, `-uiTestingSections`, Hiking: the rows `template-item-0…5` on screen at
  most `Metrics.line` — 30 / 22 — top to top and at least 8 less; `template-item-0-remove` centred on its row's line
  (within 2 pt) and no taller than a line; the second heading `template-group-1` at most 12 pt under the row above;
  picture `tight-template`; seen red on 0.66's sizes: "a row takes 41.67 points, top to top; at most 30.0");
  `testATemplateOpensAndCloses`; `testAThingAddedToATemplateStays` (Hiking has 4 rows; "Gaiters" added →
  `template-item-4`, survives close/reopen; ✕ asks first, Keep it keeps, Take it off removes, the other rows stay);
  `testATemplatesThingsGroupTheWaysATripSorts` (a sectioned template starts on Section, first heading "Lights";
  A–Z is one group "A–Z"; Into's first heading "Carry-on / hand luggage" — headings in Headline, not capitals, since 0.62);
  `testATemplateFindsAThingWithoutScrolling` ("map" → the Map first and alone, "1 of 4", no none-line; "mapzz" →
  none-line, no count, no rows; ✕ brings all back and hides count and none-line; Add while searching clears the
  search and shows the new row); `testAListIsRenamedAndAnotherIsDeleted` (rename via `template-rename`, reread from
  `template-name`; delete asks (`template-delete-yes` exists), closes, summary changes, Care still says
  "10 things"); `testEveryAddButtonIsReadyAndSaysWhatIsMissing` (`template-add` → `template-add-needs`; name
  replaced by "Swim" → `template-rename` → `template-rename-needs`); `testATripReviewIsSavedAndTheMissedThingIsFiled`
  (a missed thing lands on the base template: `template-item-4`); `testOneSearchReachesEverything` (a Search
  result opens `template-detail`); `testATemplateAndAGrabListAreSharedAndOpenedAgain` (`template-share`);
  `testShareSitsOnItsHeadersCentreLine` (0.67: on Hiking, `template-share` and `template-detail-done` sit within
  1.5 pt of the centre line of `template-cover`; seen red with the header row planted as `.top`-aligned: "template-share
  sits -5.0 pt off the icon's centre line"; the mark inside the pill is checked in the pictures);
  `testTypingAThingAlreadyOnTheTemplateSaysSo` ("map" on Hiking → `template-add-needs` says "already", no fifth
  row); `testATemplateMovesToAnotherActivityArea` (Common base offers no `template-area`; Hiking's reads "GA",
  `template-area-OE` → "OE", and on the tab OE appears and GA goes); `testATemplateCountsAsWhatHeLinksItTo` (0.70,
  `-uiTestingHealth`: the Common base has no `template-counts-as`; Bike reads "Bike" by its name, `template-counts-as-9`
  → "Nothing", kept after Done and reopening; on the iPhone the review then has no "No bike" row and "Use these"
  leaves the Bike helmet alone); Arrange — §6a.
- Model: `TemplateEditingTests`, `EditListsTests`, `RowEditingTests` (§13–14), `ArrangeTests` (§13a);
  `AppleHealthReviewTests.testCountsAsIsHisLinkAndTravelsWithTheTemplate` (kept through edits, the records and a
  backup; "none"; back to the name; nonsense refused), `testATemplateMeetsAWorkoutByItsName`;
  `TemplateRowsTests.testTypingAThingAlreadyOnTheTemplateDoesNotAddItTwice`,
  `testOnlyOnSaysWhatATripReadsOnThisTemplate`; `TemplateFacesTests.testATemplateMovesToAnotherActivityArea`.
- **Not covered:** the device-wide grouping memory; When's colours; Delete's "Keep it"; a rename discarded by Done;
  Return in the name field; the area card's Cancel.

### Traps and history
- 🪤 **Row identity.** "A row whose number changes is built afresh: kept, it kept its OLD number — the Map, the only
  row a search left, still said 'template-item-1' (4 Oct 2026), as the Mac did on Your things." Hence
  `.id("<memId>#<n>")`.
- 🪤 The page keeps **one** sheet of its own (the row editor); the cover and Choose doors own theirs ("several
  sheets on one view is a trap met in Search").
- 🪤 The rows are in a lazy stack: rows far down are not built until scrolled near — the UI tests scroll to reach
  `template-item-4` ("since the Find field … the fifth row sits past what a lazy list builds").

## 6a. Arrange — a template's headings and the order of its things (on `TemplateDetail`)

### Purpose and origin
Open item 19 left "renaming, reordering or deleting a section and reordering rows" for him to decide, "worth a
picture first". On 5 Oct 2026 he was shown three layouts on the real page (today's, A: arrow buttons on every line,
B: a pen on each heading and a heading card, C: grips to hold and drag) and chose **C** ("Hold ≡ and drag a heading
or a thing to its place"). Built for 0.63 with Apple's text styles and the slim heights of the 0.62 look.

### How it is reached and left
- Reached: the **Arrange** pill on a template's page (`template-arrange`).
- Offered (`canArrange`) while the page is grouped by **Section**, or when the template has **no section in use**
  (Section is not among the Group pills: such a template is arranged as one list, the order a trip reads) — and only
  when the template has at least one row or one heading.
- Left: a second tap on Arrange; **Escape** (⌘. on an iPhone keyboard: the Arrange pill carries
  `.keyboardShortcut(.cancelAction)` while on, and Done gives it up meanwhile) — the page stays open, a second Escape
  closes it as Done does. On the Mac a text field and a list take Escape for themselves before any shortcut, so the
  heading's name field and the arranging list (`arrange-list`) also end Arrange with `.onExitCommand` (0.63, found on
  GitHub's Mac run: Escape typed in the name field left Arrange on); a tap on any Group pill; the pill ceasing to be offered (`onChange(of: canArrange)`);
  Done (Arrange is not remembered — the page always opens with it off). Leaving drops a heading's name typed and
  not saved: never saved, by Escape least of all (Escape everywhere: never a save).
- While arranging the page cannot be swiped away on the iPhone (`interactiveDismissDisabled(arranging)`): a drag
  that strays to the top would close it mid-move, and the iPhone's own ⌘. closes an untouched sheet by itself,
  which would beat Escape to Arrange. Done still closes it.

### What is on screen
- **The pill** — on its own row under the Group pills (side 16, bottom 4): "Arrange", Subheadline semibold, side
  padding 12, height `Metrics.chip`; off = violet words on 10 % violet with a 1-pt violet stroke (a button, not a
  grouping choice); on = white on filled violet, trait `isSelected`. id `template-arrange`.
- While on, under it (4 apart): **"Hold ≡ and drag a heading or a thing to its place."** — Footnote, muted, wraps;
  id `template-arrange-hint`. (≡ is the character U+2261 in the words; the marks on the lines are drawn.)
- Find (`template-find`) is hidden and emptied when Arrange starts: every heading and thing is in view, in its place.
- In place of the rows, **one list** (`List`, plain, no separators, row insets side 16, rows on `Theme.bg`, minimum
  row height 1; id `arrange-list`), top to bottom (`Library.arrangeLines`, §13a):
  - each **heading** of the template in its order — even one with nothing under it, so a thing can be dragged into
    it: its name (Headline, violet; a button, id `arrange-heading-<k>` with k = the heading's position, label = the
    name, hint "Rename or remove this heading"; height `Metrics.tap`; 10 above) and at the right the heading's
    **grip** — violet, bold, on a soft violet capsule (`arrange-heading-<k>-grip`, label "Move the heading <name>");
  - under it its **things**, in the template's order: the name (Body, ink, one line; a text, id `arrange-item-<n>`
    with n = position as read across the whole list, 0 first) and the thing's grip — thin, light grey
    `Theme.faint`, on nothing (`arrange-item-<n>-grip`, label "Move <name>"); height `Metrics.row`, a hairline under each. The bag, the "×qty · note" line, "Only on:" and
    the ✕ are not shown while arranging (his picture: name and grip only);
  - when the template has headings: **"Everything else"** (Headline, muted — not his heading, so not violet; id
    `arrange-heading-rest`; no grip, cannot be moved or renamed), then the things under no heading (a section id
    the template does not have counts as none, as on the page). A template with no headings shows only its things.
- **The grip** (`GripMark`): three strokes `M5 8h14M5 12h14M5 16h14`, round caps, drawn 24 × 24 through
  `GridShape` (centred), in a 36 × `Metrics.compact` area; an accessibility element with trait image. Drawn by
  hand — no SF Symbol, no emoji, and not the system's edit-mode grip. The two kinds look clearly different (0.67,
  his note on 0.63: "Too little difference between the lilac grab handle and the black grab handle. The colors
  are too similar"):
  - a **heading's** grip (`heading: true`) — it carries the heading and all its things: stroke 2.2 in the
    template violet, on a capsule of 16 % violet, 34 × `Metrics.chip`;
  - a **thing's** grip — stroke 1.6 in `Theme.faint` (light `#a9b5ba`, dark `#5a6a71`), no capsule.
  Until 0.67 both were bare strokes of 1.8 — violet and `muted` (`#5f7078`, which read as black) — framed at 20
  while drawn on the 24-pt grid, so they sat 2 pt low and right. Colour cannot be read by a UI test: the
  difference is checked in the day and night pictures of `testArrangeTurnsOnAndOff` ("arrange-on").
- **Renaming a heading** — a tap on its name puts, in place of that heading line, a card (padding 10, `Theme.card`,
  radius 12, 1-pt violet stroke, 6 above and below):
  - a field holding the name (Body, ink; `Theme.bg` fill, radius 10, hairline — red while a problem is said; height
    `Metrics.tap`; focused at once; Return = Save; placeholder "Heading"; id `arrange-heading-field`) and **Save**
    (`FieldButtonLabel`, violet, always in colour; id `arrange-heading-save`);
  - under them, when Save could not take it (`needsLine`, Subheadline semibold red, id `arrange-heading-needs`,
    gone as he types): "Type a name first." (blank) or **"This template already has a heading called that."**
    (another heading of this template has the name, by `normName`; a change of case of its own name is allowed);
  - **"Remove heading"** — Subheadline semibold red words, no frame (quiet), height `Metrics.compact`; id
    `arrange-heading-remove` — with "Its things stay, under no heading." (Footnote, muted) beside it. It asks
    nothing: nothing is lost.
  - Only one heading is renamed at a time (tapping another moves the card there; the typed name is dropped); while
    the card is open that heading cannot be dragged, and the page's foot steps aside (§6).

### Behaviour
- **Why `List` with `onMove`.** It is SwiftUI's own way of carrying rows, and it works the same with a finger on
  the iPhone (hold, then drag — no edit mode needed) and with the mouse on the Mac (press and drag), scrolls the
  list while a row is carried, and animates the gap. Edit mode was not used: its grips and red delete circles are
  Apple's drawings, not the app's (his rule: no stock icons). `.draggable` / `.dropDestination` were not used:
  they carry text between apps (any dragged text would land on the page) and leave working out "above or below
  this row" to the app. The grip is the app's mark of where to hold; the list itself lifts the line, so a hold
  elsewhere on a line lifts it too (the grip is the sure place: a heading's name is a button).
- **All headings and things are lines of ONE list**, so a single drag can carry a thing from under one heading to
  under another. SwiftUI hands over "line `from` dropped at `to`" (`to` counted before the move); the model reads it
  (`Library.dropLine`, §13a, model-tested) and the page redraws from the library:
  - a **heading** takes all its things along and lands before the next heading below where it was dropped (or as
    the last heading when there is none) — dropped among another heading's things, it comes after them and takes
    none of them;
  - a **thing** goes under the nearest heading above where it was dropped (the "Everything else" line = under no
    heading), just before the thing that follows it there, else last under that heading; dropped above every
    heading, it goes to the top of the first one;
  - "Everything else" never moves (`moveDisabled`), nor a heading whose name is being changed.
- **Saved like every template edit**: each drop, rename and removal is one `model.change { … }` — only the records
  that changed are written (the template's `sections` and `updatedAt`; the memberships whose `section` or `order`
  changed), so it syncs to the other device and is in the next backup. A drop that changes nothing writes nothing.
- **Rename** → `renameSection` (trimmed). **Remove heading** → `removeSection`: the heading goes, its things stay on
  the template under no heading — together, in their order, first among the things there.
- **Trips.** A trip already made is not touched by arranging (its lines are copies; their heading words too). A NEW
  trip, or one rebuilt (Trip settings → Save, `Library.regenerated`), takes the template's rows in the new order
  and so lists its headings in the new order — see §13a for why every move renumbers the rows. A rebuilt trip keeps
  each existing line as it was (its tick, and the heading NAME it was made with: a thing moved under another
  heading keeps its old heading on a trip already made until a fresh line is made for it); only the line order is
  new. Nothing in Arrange calls `followThing`.

### Data
Reads `arrangeLines(templateId:)`, the resolved template (names), `sectionNameTaken`. Writes `dropLine` (→
`moveSection` / `moveRow`), `renameSection`, `removeSection`. No AppStorage.

### iPhone vs Mac
The same list on both; the heights follow `Metrics` (iPhone: row 40, tap 36, compact 32, chip 28; Mac: 30, 26, 24,
22). iPhone: hold a line, then drag. Mac: press and drag with the mouse (List rows on the Mac carry with a plain
press-and-drag). The UI tests drive both with `press(forDuration: 1.0, thenDragTo:, withVelocity: .slow,
thenHoldForDuration: 0.8)` on the grips; they were run on the iPhone simulator only (the Mac UI tests run in CI).

### Tests
- UI (`-uiTestingSections`: the sample with Hiking under Lights (Headlamp, Spare batteries) and Clothes (Hiking
  boots, Rain jacket, Wool socks), the Map under no heading — `SampleLibrary.sectioned()`; since 0.64 its trip is
  packed from Hiking as it then reads, 9 lines, so a trip sorted by Section has headings — spec 03):
  `testArrangeTurnsOnAndOff` (offered by Section and off; on = selected, the hint, headings "Lights"/"Clothes",
  "Everything else", the six things in order, grips on headings and things, no ✕, no Find; a second tap ends it and
  the ✕ comes back; When hides Arrange, Section brings it back; Swim, with no headings, is arranged as one list of
  three with no heading lines); `testAThingIsDraggedUnderAnotherHeading` (the Map's grip dragged onto the
  Headlamp's: the Map is among the first three — under Lights; ended, the page has no third group, and it is kept
  after closing and opening the template); `testAHeadingIsDraggedWithItsThings` (Clothes' grip onto Lights': Clothes
  first with its three things, then Lights; the page reads Clothes first); `testAHeadingIsRenamed` (the field holds
  "Clothes"; "lights" → the needs line says "already"; it goes as he types; "Clothing" saved; the page reads
  "Clothing"); `testAHeadingIsRemovedAndItsThingsStay` (Lights removed: Clothes is heading 0, no heading 1, the six
  things in order with Headlamp and Spare batteries under no heading; the page reads Clothes, Everything else);
  `testEscapeEndsArrangingWithoutSavingAHeading` ("Clothing" typed over Clothes, not saved; Escape ends Arrange, the
  page stays, the heading still reads "Clothes"; a second Escape closes the page).
- Model: `ArrangeTests` (§13a).
- **Not covered:** a drag on the Mac (built, not run here; CI runs the Mac UI tests); the heading editor's focus;
  a drag that scrolls a long list.

### Traps
- 🪤 Edit mode would have shown Apple's grips and delete circles; it is not used — `onMove` alone lets a List carry
  rows on the iPhone (hold first) and the Mac.
- 🪤 The headings' and things' lines are numbered as READ (`arrange-item-<n>` across headings), like the page's rows.
- 🪤 With the keyboard up the list is short: the foot steps aside while a heading's name is being changed.

---

## 7. A row of a template (`RowEditor`)

### Purpose and origin
"What THIS list says about the thing — its bag and 'When' here, how many, a note, which section it sits in. Blank
means 'the same as the thing itself', so a change to the thing still reaches this list." How many and Section
became per-template in 0.14 (24 Sep 2026). "Only on some trips" is his ask of 2 Oct 2026 ("a towel can be
summer-only on Beach and always on Swim"). Heading bands: field test 3 Oct 2026 (the headings had been 14 grey,
smaller than the pills). Bag, When and Section are drop-downs since 0.64 (his word, 6 Oct 2026: "I like the dropdown
for 'kept in'. Well done. Can we please make these kinds of drop-downs everywhere?"). The same Section can be set
from the thing's page since 0.64 (his ask, 6 Oct 2026, "already in this view"; spec 05 item 6a) — it stores exactly
what this editor's Save stores for it, and the trips still ahead follow the same way.

### How it is reached and left
Tap a row on a template page. Left by "Cancel" (`row-cancel`, nothing saved; Escape too, 0.62 — the template's page
behind it stays open), "Save" (`row-save`, saves then closes; no key presses it), swipe down (= Cancel). Container id
`row-detail`. Mac: min 520 × 600.

### What is on screen
- Top row (padding 16): "Cancel" (outlined, muted) · spacer · "Save" (filled violet).
- Scroll (side 16, bottom 24), blocks 20 apart, each field right under its heading:
  1. The thing's name — 26 heavy ink, wraps, id `row-thing-name`; "On <template name>" — 15 semibold muted.
  Items 2–4 are **drop-downs** (0.64, `DropDown`, spec 06 §21) in violet: under the heading band a field-like
  button (`row-bag`, `row-when`, `row-section`; value = the words of the choice that stands, label = the heading;
  Body, `Metrics.tap` tall, card fill, hairline, a ▾) that opens its list beside it — a popover on the iPhone as on
  the Mac, placed by the system above or below its field, wherever it fits (Bag, near the top, opens downwards) — container `row-bag-list`,
  `row-when-list`, `row-section-list`; one row per choice named as its pill was (`row-bag-<n>` …), the chosen row
  ticked in violet (selected trait); a tap on a row takes it and closes the list (nothing is stored before Save).
  A blank choice ("Same as …", "No section") is in grey on the field and in the list. Until 0.64 each was a row of
  pills; the "Only on some trips" lists, where several may be picked, stay pills.
  2. **"Bag on this template"** (heading band, id `row-bag-title`; field `row-bag`): `row-bag-0` = what a blank bag
     really means (`sameBagWords`): "Same as the template (<its own bag>)" on a template that came with a default
     bag, else "Same as the thing (<the thing's own bag>)"; then `row-bag-1…` = `bagNames()` — his own bags, in his
     bag list's order (the 17 built-in names only while he has none; 0.64 — until then always the built-in names
     first, then his own). One choice. A bag the row names that is none of these (a bag since renamed or deleted)
     is shown on the field and on a row of its own at the end, ticked (`row-bag-other`; 0.64 — no pill was lit
     before); left alone it is kept on Save.
  3. **"When, on this template"** (band, `row-when-title`; field `row-when`): `row-when-0` = "Same as the thing
     (<phase label>)", then the live timeline (`PHASES`, his own steps if he changed them). One choice. A stored step
     this device does not know ticks no row; the field shows its raw id.
  4. **"Section of this template"** (band, `row-section-title`; field `row-section`) — ALWAYS there since 0.64 (it
     was hidden on a template without sections): `row-section-0` = "No section", then the sections in order, then
     the section typed at the foot and not made yet (the last row). One choice. At the foot of its list (0.64; until
     then a block of its own, "A new section", band `row-heading-section-new`, under the pills): a field "A new
     section" (`row-section-new`; it said "e.g. Lights" under the band) and "Add" (`row-section-add`); Add with
     nothing typed → "Type the section's name first." under it (`row-section-add-needs`); otherwise the section is
     chosen (see Behaviour) and the list closes. What was typed and not added is dropped when the list closes.
  5. **"How many"** (band, `row-heading-qty`): field `row-qty`; its grey words (placeholder) "Same as the thing:
     <the thing's own how-many>" when the thing has one, else "e.g. 2, or 2 pairs".
  6. **"Note"** (band, `row-heading-note`): field `row-note`; placeholder "Same as the thing: <the first line of
     the thing's note>" when it has one, else "e.g. with the red filter" — so a blank field never looks as if the
     thing's note had gone.
  7. "Blank means the same as the thing itself, so a change to the thing still reaches this template." — 14 muted.
  8. **"Only on some trips"** (band, `row-heading-some`), then "Leave these off and it always comes along. Pick one
     or more and it comes only on trips that match — on this template." (15 medium muted, pulled 6 pt up), then
     four pill rows with a smaller heading each (`HeadingTitle`, 20 heavy violet after a 4 × 18 violet capsule),
     several choices each; this block's parts are 14 pt apart:
     - "Season" (`row-seasons-title`): Summer `row-seasons-0`, Winter `row-seasons-1`.
     - "Context" (`row-contexts-title`) — **only on a WET template** (`contextApplies(list)`: group == "WET"):
       Indoor, Outdoor, Race (`row-contexts-0…2`).
     - "Transport" (`row-transports-title`): Car, Plane, RV (`row-transports-0…2`).
     - "Food" (`row-catering-title`): Self-sufficient, Eating out, Mix of both (`row-catering-0…2`; stored ids
       `self`, `eatout`, `mixed`).
     - After the app's own words, each a stored word the app does not know (a web-app "summer", "Boat") as a pill
       of its own, as stored, lit — so it can be seen and switched off (`Library.unknownConditions`).
- Field look: 17 medium ink, min height 44, card fill, 10-radius hairline border. Heading band: a 5 × 26 capsule in
  violet, the title 22 heavy violet, on a 13 % violet strip (radius 10). Pills (Only on some trips): 15 (bold when
  on), min height 36, white on violet when on, ink on `Theme.bg` with a hairline when off; ids are `<id>-<position>`,
  never words — as are a drop-down's rows. (Sizes here are the old points; read them through spec 06 §21.)

### Behaviour
- On appear the state is loaded from the **membership itself** (not the resolved row): bag = `m.container`, when =
  `m.phase`, qty, note, section, seasons, contexts, transports, catering. A blank membership value selects the
  "Same as the thing" / "No section" pill (and leaves How many / Note blank, showing the thing's own in grey). A
  stored When or section that is not among the rows ticks none, and is kept unchanged on Save; a stored bag that is
  not among them has its own ticked row (`row-bag-other`, 0.64) and is kept the same way. A stored
  **condition** value that is not one of the app's own words (exactly `Summer`/`Winter`, `Indoor`/`Outdoor`/`Race`,
  `Car`/`Plane`/`RV`, `self`/`eatout`/`mixed` — case matters) shows as a lit pill of its own and is **kept** on
  Save unless switched off (until the spec pass, 5 Oct 2026, Save silently dropped it).
- **Add a section** (the Section list's foot, 0.64): blank (after `jsTrim`) → "Type the section's name first."
  under it, the list stays open; a section of this template with the same `normName` → that one is chosen; else the
  name **waits for Save** as the last, chosen row (the field shows it) — nothing is written yet. The field empties
  and the list closes. Cancel therefore leaves the template as it was (until the spec pass the section was written
  at once and stayed behind, empty).
- **Save** → `Library.saveRow(templateId:memId:_:)` (`TemplateRows.swift`), then dismiss:
  - a section waiting for Save is made (`addSection`: trimmed, an existing one of the same `normName` reused) and
    the row put in it, if its pill is still the chosen one;
  - `updateMembership` sets `container = bag`, `phase = when`, `section`, `qty = jsTrim(qty)` and
    `note = jsTrim(note)` — **each stored as "" when it equals the thing's own** ("the same as the thing", so a
    later change to the thing reaches the row; the spec pass) — and the four condition lists: the app's own words
    **in the app's own order** (SEASONS, CONTEXTS, TRANSPORTS, CATERING order) "so the stored lists read the same
    every time", then any stored word it does not know that is still switched on (`keptConditions`);
    `coerceMembership`. `weather`, `kit`, `itemType` and `order` are left as they were (no UI for them). Contexts
    stay stored on a non-WET template even though their pills are hidden there (and ignored there when a trip is
    built);
  - then `followThing(id: the thing)` (§17): the thing's open lines on trips still ahead are rebuilt, so the row's
    new bag, When, how many, note or conditions reach them (the spec pass, carrying his I.7 decision to a row).
  Save closes the sheet even when the row is gone (deleted meanwhile; `saveRow` answers false); nothing is said.
- With the row gone (deleted on the other device while open) the editor shows an empty `Item()`: a blank name,
  "Same as the thing ()" for the bag and "Same as the thing (Unsorted)" for When.
- The thing itself, and the same thing's rows on other templates, are untouched.
- A row change reaches the open lines of trips still ahead (above); ticked, hand-added and trip-edited lines, and
  trips over or reviewed, keep theirs. (Until the spec pass only a change to the THING followed, §17.)
- How the conditions act on a trip (`itemMatchesEvent`): a dimension with no values always matches; a trip with no
  value for that dimension matches; otherwise the trip's value must be one of the row's. Context only counts on a
  WET template, and a trip may pin several contexts (any overlap matches).
- The row on the template page then says `Only on: <seasons · contexts · transports · food>` (food in the short
  words) — `Library.onlyOnWords(row, on: template)`; contexts only on a WET template, where a trip reads them
  (until the spec pass they were listed everywhere, claiming a limit that did nothing).

### Data
Reads `library.row(templateId:memId:)` (membership + thing + resolved row), `templates` (the shell, for name,
sections, group), `resolvedTemplates()` (bag names), `sameBagWords`. Writes through `saveRow` only: `memberships[n]`
(`updateMembership`), `templates[t].sections` (`addSection`, on Save) and the lines of trips still ahead
(`followThing`).

### Tests
- UI: `testThePickOneListsAreDropDownsThatChooseAndKeep` (0.64; on Hiking's Headlamp: Bag, When and Section are
  fields whose rows are not out before opening, Season is still pills, Section shows "Lights"; the Bag list opened
  and photographed; `row-bag-3` and `row-when-2` chosen — each list closes and its field shows the row's words;
  saved and reopened, both fields still say them, `row-bag-3` and Lights (`row-section-1`) are the ticked rows);
  `testARowOfAListHasItsOwnAnswers` (Hiking's first row is the sectioned Headlamp and shows "Carry-on"; choosing
  `row-bag-4` and a note "with the red filter" → the row shows the note and no longer "Carry-on"; Season Summer kept
  and the row says "Only on: Summer"; Context not offered on Hiking; the thing's own bag, `thing-bag-1`, still the
  ticked row in Your things); `testTheEditorsLeadWithTheirHeadings` (all nine heading ids exist — "A new section"'s
  band went with 0.64); `testEveryAddButtonIsReadyAndSaysWhatIsMissing` (the Section list opened, its
  `row-section-add` → `row-section-add-needs`); `testASectionTypedInARowIsMadeOnlyOnSave` (Lights offered as
  `row-section-1` and nothing after it; "Rig" typed at the list's foot and Added → the list closes, the field says
  "Rig", `row-section-2` is Rig and ticked; Cancel → gone on reopening; typed again and Saved → a "Rig" heading, the
  row in it, and `row-section-2` ticked); `testEscapeLeavesHomeAndTemplatesWindowsWithoutSaving` (Mac only: "Rig"
  added at the foot, Escape cancels the row, and reopened the list has no `row-section-2`); `testAThingsNoteIsNotCopiedOntoATemplate` (-uiTestingOnSite: the Passport, with the note "Keep it dry",
  picked onto Hiking → the row shows the note, its `row-note` is empty with the grey words "Same as the thing: Keep
  it dry").
- Model: `RowEditingTests.testThisListsOwnAnswersStayThisListsOwn` (addSection trims and de-duplicates;
  updateMembership sets bag/When/qty/note/section on THIS row only; blank again = follow the thing; unknown id →
  false); `testTheRowsOfATemplateGroupIntoItsSections`; `RowTagsTests.testATaggedRowComesOnlyOnTripsThatMatch`
  (Summer+Plane row, Outdoor row on a WET template; Indoor+Outdoor takes both; untagged always comes; tags survive
  records); `TemplateRowsTests` — `testARowSavedFromTheEditorKeepsWhatItDoesNotKnow` ("summer", "Boat", "picnic"
  kept; switched off, gone; equal-to-the-thing answers blank), `testARowsNewSectionIsMadeWhenTheRowIsSaved`,
  `testARowChangeReachesATripStillAhead` (bag and note reach the open line, which keeps its id; a ticked line
  does not change), `testOnlyOnSaysWhatATripReadsOnThisTemplate`, `testABlankBagNamesWhereItReallyGoes`.
- The model classes `TemplateEditingTests`, `ThingEditingTests` and `RowEditingTests` live in
  `PackingLibraryTests/CreateTripTests.swift`.
- **Not covered:** Food tags on screen; Transport-only tags on their own; a section from another template on
  screen (the model reads it as none: `ThingSectionTests.testASectionFromElsewhereReadsAsNone`); an unknown
  condition's pill on screen (no sample row has one).
- The same section set from the thing's page (0.64): UI `testAThingsPageSetsItsSectionOnATemplate`,
  `testAThingsPageMakesANewSectionOnSave` — they read Hiking's page by its headings afterwards (spec 05).

### Traps
- 🪤 The Pills' heading must be bigger than the pills (field test 3 Oct): bands 22, inner headings 20, pills 15.
- 🪤 A drop-down's rows exist only while its list is open: a test opens it first (`openDropDown`, `choose`,
  `isChosen`) and closes it on the ticked row before tapping anything behind it — on the iPhone a tap outside an
  open popover only closes the popover.
- 🪤 A blank bag resolves **template default first**, then the thing (§12) — so the first pill names the template's
  bag when it has one ("Same as the template (X)"); until the spec pass it always named the thing's.

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
ticks lost; Escape too, 0.62), "Add N" (puts them on and closes), swipe down. Making a new thing from here does NOT close it.
Container id `pick-screen`. Mac: min 520 × 620.

### What is on screen
- Top row (padding 16): "Cancel" (outlined muted) · `"Add to <template name>"` (or "Add things" if the template is
  gone) 17 heavy ink, 1 line, shrinks to 80 %, id `pick-title` · the add button (filled violet, always in colour):
  "Add" with nothing ticked, `"Add <n>"` with n ticked; id `pick-add`. Under the row, when Add was pressed with
  nothing ticked: "Tick the things to put on first." (the shared `needsLine`, 15 bold red, id `pick-add-needs`),
  gone as soon as a tick changes.
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
    it, else ink; 1 line), and on the right either "already on it" (14 semibold muted) or (14 regular muted):
    grouped by From where → its bag; any other grouping → its storage place, or its bag when no place is set (so
    under Into a thing with no place shows the bag it is grouped by — better than saying nothing; the code's
    comment says so since the spec pass). Vertical padding 9, hairline under. id `pick-row-<n>` with n numbered as read across
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
  (`picked`, the item ids **in the order he ticked them**; untick removes one) survive folding, regrouping and
  searching.
- **Add N** (`putOn`): nothing ticked → "Tick the things to put on first." under the title, the screen stays (his
  rule: a main button pressed too early says what is missing; until the spec pass it did nothing and said
  nothing); else `putOnTemplate(templateId:itemIds: picked)` and close — the things land at the bottom of the
  template **in the order ticked** (a set put them on in no particular order until the spec pass). Each new row
  brings the thing's own defaults (blank bag/When/how many/note on the membership); already-on things, repeats
  and unknown ids are skipped.
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
`testTheCrossEmptiesASearch` (`pick-count` "10 things" → "1 thing" → back); `testThingsPickedLandInTheOrderTicked`
(Add with nothing ticked → `pick-add-needs`, the picker stays; Towel, Goggles, Passport ticked in that order →
the line goes, rows 4–6 read Towel, Goggles, Passport). Model
`TemplatePickingTests.testThingsHeOwnsArePutOnATemplateOnceEach`, `TemplateRowsTests.testThingsPutOnLandInTheOrderGiven`.
**Not covered:** Kind/When/Into grouping of the picker.

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
accent-insensitive) — except by Section, which keeps the template's order. (The template page groups When with
`entriesByPhase` itself, so its rows keep the template's order there too; only the picker's When is A–Z, to find a
thing among all he owns. The type's comment says so since the spec pass.)
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
| `emoji` | Cover glyph; trimmed, cut to 4 UTF-16 units; non-string → "". The web app shows it (📋 `TEMPLATE_DEFAULT_EMOJI` when ""); this app never does — its cover shows the first letter (§3). Kept for round trips; no UI sets it here. |
| `color` | Cover colour; kept only if a hex colour, else "" (= hashed pick from `COVER_COLOURS`, §3). No UI sets it here. |
| `sections` | Ordered `[TemplateSection {id, name}]`; `normalizeSections`: unnamed (after trim) dropped, a missing id invented, a repeated id dropped, names trimmed. |
| `group` | "GA" / "WET" / "OE" or "" (any other value → ""). The activity area. Set when the template is made, and changed on its page (`setTemplateArea`, §14). |
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
| `section` | no section | A section id of THIS template; no item default. Not carried between templates by id (only by name). Written by the row editor's Save (`saveRow`, §7), by Arrange (`moveRow`/`removeSection`, §13a) and, since 0.64, from the thing's page (`setThingSection`, below) — the first place only when the thing is on the template twice. An id that is not one of this template's sections reads as none everywhere (`groupItemsBySection`, `thingSection`) and is kept until something else is chosen. |
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
     different; `order` = 0, 1, 2… in row order. `membershipFromResolved` (the web app's, kept as the copy the parity
     check holds) stores the row's RESOLVED `qty` and `note` — the thing's own when the row has none — so the save
     then puts them right with `Library.placeAnswer(shown:stored:thing:)`: a row whose value is what its place
     resolved to before keeps what the place stored ("" stays "", a real exception stays one even when it equals
     the thing's); a changed or new value is stored only where it differs from the thing's own, else "". (Until the
     spec pass, 5 Oct 2026, putting a thing on a template — or any later save of it — copied the thing's note and
     how-many into every row, and a change to the thing's note never reached them again.)
2. Memberships of this template not seen in this save are deleted. **Things are never deleted.**
3. The shell is stored with `items = []`, coerced, `updatedAt = now` (added if new).

### Operations
- `addToTemplate(templateId:name:container:phase:) -> Item?` — blank → nil; unknown template → nil. An existing thing
  of that `normName` → its `resolveItemAlone` row (memId cleared); else a new row (bag default "Carry-on / hand
  luggage", When `defaultPhaseId()` = the first non-task phase). Appended, `saveTemplate`, returns the last resolved
  row. A thing of that name already ON the template → nil, nothing changes (`isOnTemplate(templateId:name:)`;
  "never twice by typing" — the spec pass; the picker and the review refuse it too; a thing can still sit twice on
  one template where the data says so). Either way the new membership stores no bag, When, how-many or note of its
  own (a new thing's bag and When become the THING's defaults; a known thing's row arrives with `ovContainer` = "").
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
- `saveRow(templateId:memId:_ RowAnswers) -> Bool` (`TemplateRows.swift`) — the row editor's Save (§7): a section
  typed there made now, how many / note "" when equal to the thing's, conditions kept with words unknown to the
  app, then `followThing`. false when that row is not on that template.
- (0.64, `ThingSections.swift`, for the thing's page — spec 05 item 6a) `firstPlace(itemId:templateId:) ->
  Membership?` — the thing's first place on that template by `order` (NaN = 0; equal numbers keep the stored
  order), nil when it is not on it. `thingSection(itemId:templateId:) -> String` — that place's section when it is
  one of THIS template's, else "". `setThingSection(itemId:templateId:section:newSection: = "") -> Bool` — puts the
  first place under `section` (an id of this template, or "" = none) or, when `newSection` is not blank after
  `jsTrim`, under the template's section of that `normName` or a new one (`addSection`); then `followThing(id:)`,
  as `saveRow` does. Returns whether anything changed; a no-op (nothing written, no section made, no trip touched)
  when the place is already there, `section` is not one of the template's, the thing is not on it, or the template
  is unknown. Only `section` changes — not `order` (as in `saveRow`; Arrange is what renumbers). Does not touch the
  template's `updatedAt` (neither does `addSection`). Model tests `ThingSectionTests` (6; spec 05).
- `letCopiedAnswersFollowTheirThings() -> Int` — the clean-up of the rows an older build froze: a membership whose
  non-empty `qty` or `note` is EXACTLY its thing's own is set back to "" (nothing on screen changes; a row of his
  own that says something else is kept). Run by `LibraryModel.reload()` on every load, after duplicate records are
  settled; only the changed membership records are written, so it is idempotent and both devices agree.
- `setTemplateArea(id:area:)` — §14. The cover's icon: `setTemplateIcon` (§3).
- Renaming, moving and removing a section and moving a row: §13a (Arrange, 0.63). There are still **no**
  operations for changing a template's role/transport/colour/emoji/default bag (see open question 19).

### Tests
`TemplateRowsTests.testAThingsNoteIsNeverFrozenOntoItsRows` (picked, typed, saved again: the membership's note and
how-many stay "", the row shows the thing's, a change to the thing reaches every row; a row's own answer — even
one equal to the thing's — survives a save), `testTheCopiesAnOlderBuildMadeFollowTheirThingsAgain` (a copy goes
back to "", his own note kept, nothing a row says changes, a second run changes nothing);
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

## 13a. Model: arranging a template's headings and rows (`PackingLibrary/Library.swift`, after `addSection`)

His layout "C" (5 Oct 2026; the screen is §6a). Where the order lives: a template's **headings** are its `sections`
(an ordered list on the template record); its **rows** are memberships, read in `order` (a Double; resolving
stable-sorts by it, §12). How a **trip** reads them (`buildTotalEntries`, `PackingCore/TripBuilding.swift`): the
templates in priority order (always-packed, the matching transport, then the ticked activities in the order
ticked), and inside each its rows **in `order`**, skipping a name+bag already taken; each line carries its heading's
NAME (`sectionName`), and the trip's By-section view (`groupBySection`) lists the headings by the **first line under
each** — it never reads `sections`' own order. So a heading moved in `sections` alone would not move on a trip:
**every move renumbers the template's rows 0, 1, 2… in the order the page reads by Section** — each heading's rows
in turn, then the rows under no heading — and a new or rebuilt trip then reads as he arranged it. Numbers stay small
whole numbers however often he drags (as `saveTemplate` keeps them, §13), and only memberships whose number or
heading really changes are touched, so the store writes only those records.

- `sectionNameTaken(templateId:name:except:) -> Bool` — another heading of this template (not `except`) has this
  `normName`; a blank name is never taken; an unknown template → false.
- `renameSection(templateId:sectionId:to:) -> Bool` — trims; refuses (false) blank, an unknown template or heading,
  or a name another heading has (`sectionNameTaken`); a change of case of its own name is allowed; the same name →
  true, nothing written; else the name and the template's `updatedAt`. Rows untouched; trips already made keep the
  old words on their lines.
- `moveSection(templateId:sectionId:before:) -> Bool` — the heading goes just before `before` (nil = after the last
  heading) with all its rows; false for an unknown template, heading or `before`; `before` = itself → true, no
  change. Then the rows are renumbered; `updatedAt` is set only when the headings' order or a number changed.
- `removeSection(templateId:sectionId:) -> Bool` — false for an unknown template or heading. The rows are first
  renumbered as the page reads; the heading leaves `sections`; every membership of this template with that section
  id gets `section = ""`; renumbered again — so its rows sit together, in their order, first under no heading. No
  thing and no membership is deleted. `updatedAt` set.
- `moveRow(templateId:memId:section:before:) -> Bool` — the row goes under `section` ("" = no heading), just before
  the row `before` when that row is under the same heading, else last there; its other answers (bag, When, how
  many, note, conditions) are untouched. A row whose stored section id the template does not have, moved, is filed
  under `section` for real. False for an unknown template or row (a row of another template counts as unknown) or
  a `section` the template does not have. `updatedAt` only when its heading or a number changed.
- `arrangedRows(templateId:) -> [(sectionId, rows)]` — the membership ids as the page reads them: per heading, then
  a last group "" (no heading or an unknown id); rows in `order`, ties as stored. Includes rows whose thing is gone
  (they are numbered where they sit, never shown).
- `ArrangeLine` (`.heading(id)`, `.rest`, `.row(memId)`) and `arrangeLines(templateId:)` — the page while arranging
  as one list: every heading (even empty), its rows; `.rest` and the rows under no heading when the template has
  headings; a template with none is just its rows; rows whose thing is gone left out; unknown template → [].
- `dropLine(templateId:from:to:) -> Bool` — a drag on that list, with SwiftUI's `onMove` counting (`to` is a place
  in the list before the move; the line lands at `to - 1` when moving down): a heading → `moveSection(before:` the
  next heading below the drop, or nil when the next non-row line is `.rest` or there is none`)`; a row → `moveRow`
  under the nearest heading line above (`.rest` = "", none above = the first heading, at its top), `before` = the
  row right after it. `.rest` and out-of-range offsets → false, nothing changes.

**From a thing's page (0.68, `PackingLibrary/SectionEdits.swift`)** — the same changes, held by the page until Save
(spec 05 item 6a) and handed over in one go; no second way of doing any of them:
- `SectionEdits(names: [sectionId: name], order: [sectionId]?, removed: Set<sectionId>)` — what a page did to ONE
  template's sections; `isEmpty` when nothing.
- `sectionsAsEdited(templateId:_:) -> [TemplateSection]` — the sections as the page shows them while it holds the
  edits: in the new order (ids it no longer has dropped, ones it gained since last), under the new names, the removed
  ones still there (the page strikes them out).
- `sectionNameTaken(templateId:name:except:_:)` — would this name be a second one of that `normName` among the sections
  as shown (the removed ones' names are free; blank never taken; its own name allowed).
- `applySectionEdits(templateId:_:) -> Bool` — the REMOVED first (`removeSection` each: its rows stay, under no
  heading, and its name is free), then the NAMES (`renameSection`, trimmed; a blank one or the same name skipped;
  retried while any succeeds, and two that swap names are each parked under a name nobody has — U+2063 and the id —
  then given theirs), then the ORDER (`moveSection(before: nil)` each in turn, only when it differs from the stored
  order — so the rows are renumbered and a new trip reads it). Answers whether the sections or the template's rows
  changed; false for an unknown template or empty edits.
Tests: `SectionEditsTests` (6) — a renamed section keeps its things (the same id); the order is the template's and a
new trip reads Clothes before Lights; a removed section's things stay on the template under none (the row count kept);
all three at once with two names swapped; nothing to do writes nothing (the same names and order, an unknown template —
the library equal before and after); the page's view of the edits and the name check.

Tests: `ArrangeTests` — `testAHeadingIsRenamedButNeverToANameItAlreadyHas`, `testAHeadingMovesWithAllItsThings`
(rows renumbered 0–4 in the page's order; nil = last; unknown ids refused), `testARemovedHeadingLeavesItsThingsOnTheTemplate`,
`testAThingMovesUnderItsOwnHeadingOrAnother` (its own note and bag go with it; whole numbers from 0),
`testThePageWhileArrangingIsOneListOfHeadingsAndRows`, `testADropMovesWhatWasDraggedToWhereItWasDropped` (eight drops
read the way SwiftUI hands them over, and four refusals), `testATemplateWithNoHeadingsIsOneList`,
`testArrangingIsSavedLikeAnyTemplateEditAndOnlyWhatChanged` (one row moved one place: two membership records and the
template written; the same move again, a day later: nothing written; the arrangement survives the records and a
backup), `testANewOrRebuiltTripFollowsTheNewOrderAndAnOldOneIsUntouched` (the jumbled template made a trip read
Clothes before Lights; after arranging a new trip reads Lights, Clothes, Everything else; a rebuild takes the new
order and keeps every line's id; the old trip is unchanged).

---

## 14. Renaming and deleting a template (`PackingLibrary/EditLists.swift`)

His ask: "You don't need to merge the content of the two templates — I can add items later on. Just delete one and
rename the existing."
- `renameTemplate(id:to:) -> Bool`: trims; refuses blank, an unknown id, or a name another template has by
  `normName` (`templateNameTaken(except:)` — any role but the bag list, whose stored "Containers" he never sees);
  sets the name and `updatedAt`. The icon choice (in `extra`) is kept.
- `setTemplateArea(id:area:) -> Bool` (the spec pass, 5 Oct 2026): moves an ACTIVITY template (role "") to "GA",
  "WET", "OE" or "" (none) and sets `updatedAt` (not when the area is already that one). Refused (false) for an
  unknown id, an always-packed or transport template (filed by what they do) and an area that is not one of his.
- `deleteTemplate(id:) -> Bool`: false for an unknown id; removes the template's memberships and the template. Things
  stay (also things that were on no other template — they become things on no template). Trips built from it are
  untouched ("a trip's lines stand on their own"); a rebuild never drops lines whose template is gone
  (`docs/store.md` rule 9, `Library.regenerated`).

Tests: `TemplateFacesTests.testATemplateMovesToAnotherActivityArea`, `testANameIsTakenOnlyByATemplateHeCanSee`;
`EditListsTests` — `testARenameSticksAndRefusesANameHeAlreadyHas`,
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
`templateUse(today:) -> [templateId: TemplateUse(lastTrip, lastDate, trips, nextTrip, nextDate)]`, counted from the
trips: for each trip, the set of template ids = its `activities` plus every line's `sourceListId` (so a base
template counts through its lines, and a template since deleted or replaced still counts by the lines that name
it). Each id: `trips += 1` (trips still ahead included); a trip that has BEGUN (start ≤ `today`, string compare of
`YYYY-MM-DD`) and is later than the stored one becomes `lastDate`/`lastTrip` (the trip's name); a trip starting
after `today` becomes `nextDate`/`nextTrip` when it is the soonest such. A trip with no date counts but never wins
either. `today` "" (the default) counts every dated trip as begun. The screen passes the device's local date. (The
spec pass, 5 Oct 2026: before, a trip in the future counted as "last" — "in 30 days" on a card meant to say when
it was last taken.) The card's words: `TemplateUse.line(_:today:)`, §2.

Tests: `TemplateUseTests` — `testAListNobodyHasTakenSaysNothing`, `testTheMostRecentTripWins` (base counted on 3 trips
through its lines), `testATripWithNoDateStillCountsButNeverWins`, `testATripStillAheadIsNextNotLast` (the soonest
ahead is next; "Next: in 30 days · …", "Next: tomorrow · …", "2 days ago · …", "Never taken along"; begun today
counts as taken).

---

## 17. A change to a thing follows to trips still ahead (`PackingLibrary/ThingFollows.swift`)

His decision on test I.7 (1 Oct 2026), released 0.45.
- `tripStillAhead(trip, today)`: status not "done", not reviewed, and either no start date or the end date (or the
  start when there is no end) ≥ today.
- `followThing(id:today:)` (called by `updateThing` and `renameThing`): on every trip still ahead, the lines of this
  thing that are not ticked, not added by hand (`custom`) and not changed on the trip (`edited`) are rebuilt the way a
  new trip would build them (`buildTotalEntries(trip, resolvedTemplates())` filtered to this thing) — "so a bag
  chosen for that one template still wins over the thing's own bag". Each old line takes a fresh line from the same
  template first, else any unused one; it keeps its `id`, `checked`, `skipped` (set aside), `used` and its own
  `extra` marks (way home, used up, maintenance note — 0.62). A line with no
  fresh counterpart is left as it is. The trip's `updatedAt` is set when something changed. Returns how many lines
  changed. `today` defaults to `Library.localToday()`, the device's own date (0.62; it was the UTC date).
- A row saved in the row editor calls this too (`saveRow`, §7 — the spec pass, 5 Oct 2026), so a row's own bag,
  When, how many, note or conditions reach the open lines of trips still ahead. Other changes to a template's rows
  (typed on, picked on, taken off, the table's per-template columns, `setOnTemplate`, Arrange §6a) do not.

Tests: `ThingFollowsTests` — `testAChangeToAThingReachesOnlyWhatIsStillUndecided` (ahead and undated trips follow;
ticked line, over trip, reviewed trip keep theirs; ids and line count kept),
`testARenameAndAnEditedOrSetAsideLineAreHandledRightly`, `testABagChosenForOneTemplateStillWins`;
`TemplateRowsTests.testARowChangeReachesATripStillAhead`; UI `testAChangeToAThingReachesATripStillAhead`.

---

## 18. Kits (`PackingCore/Kits.swift`)

A kit is a bundle of things always packed together, by stable thing ids. `Kit {id, name, emoji, note, itemIds,
createdAt, updatedAt, extra}`; `coerceKit` trims the emoji and de-duplicates `itemIds` (blank ids dropped, order
kept); `kitEmoji` = its emoji or 🧰; `clusterByKit(entries)` groups a list's lines by kit name at the first
appearance, loose lines staying in place. **In this app kits are data only**: they are imported from a backup, kept
in the `kits` table, carried in backups, and a deleted thing is removed from every kit (`deleteThing`); a row's
`kit` name travels on the membership into trip lines and share codes. No screen shows, makes or edits a kit, and
`clusterByKit` is not used by any screen. The only trace on screen is the number of kit records among
Settings' per-table device counts ("Groups of things" since 0.62, "Kits" before — spec 06 §16).

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
- **Opening** (`Library.readShared` tries grab list, then template, then trip): the preview says what it is —
  "A TEMPLATE", "AN ALWAYS-PACKED TEMPLATE" (role base) or "A TRANSPORT TEMPLATE" (role transport), so he knows
  before he adds it — the name and "1 thing" / "<n> things" (`shared-count`; "1 things" until 0.62).
  - When he already has a template of that name (`templateNameTaken`, the bag list aside): "You already have a
    template called “<name>”. This one needs a name of its own:" (15 medium muted, `shared-name-taken`) and a field
    (`shared-new-name`, 17 semibold, placeholder "A name you do not have yet") holding a free name
    (`freeTemplateName`: "<name> 2", "3"…).
  - **"Add as a new template"** (`shared-add`, always in colour) → `importTemplate(shared, named:)` (the field's
    name when his name was taken). Pressed with a blank name → "Give the template a name."; with a name he has →
    "Pick a name you do not have yet." (`needsLine`, `shared-add-needs`, gone as he types). Added → "Added. It is
    under Templates. Things you already had keep your details." — for an always-packed one "Added. It is under
    Templates, Always packed: every new trip packs it. …", for a transport one "…, By transport: every new <Car>
    trip packs it. …". (The spec pass, 5 Oct 2026: it used to make a second template of a name he had, which Worth
    a look then reported as "Two libraries may have met".)
  - When he has a role-"" template of the same `normName` (`templateNamed`), also "Replace your <name> instead"
    (`shared-replace`) → "Replace your <name>?" with "Keep mine" / "Replace", and under it what Replace does
    (`shared-replace-says`, 0.62) → `replaceTemplate(id:with:)` (0.62: the sender's things in the sender's order; his
    template — look, sections, bag, icon, role, activity area and transport — and the answers on the things he had
    stay his; storage chapter §16.4) → "Replaced your <name>. Trips that use it keep working."
- `listFromShare`: fresh ids (sections, rows, then the list), sections rebuilt and rows pointed at them by name
  (case-insensitive), roles `loose`/`container` arrive as ordinary templates, never `builtin`; a blank name becomes
  "Shared template"; a `partial` (`id`, `createdAt`) keeps a replaced template's identity. The roles `base` and
  `transport` (and the group, transport, colour, emoji and default bag) are KEPT by `listFromShare`: "Add as a new
  template" of a shared always-packed template gives him a second base template, which every new trip then packs —
  the preview and the "Added" line say so.
- "Replace" is offered only against a template of role "" (`templateNamed`), so a base, transport or bag list
  is never replaced. `importTemplate(shared, replacing:)` keeps HIS template's role, activity area and transport,
  so it stays where it was (the spec pass: replacing his activity template with a shared always-packed one turned
  his into one that every trip packs). Colour, emoji and default bag are the shared one's.
- `importTemplate(_:replacing:named:)`: as a NEW template it refuses (nil, nothing changes) a name he has
  (`templateNameTaken`) — `named` gives it another (trimmed; ignored on Replace). Each row whose name matches a
  thing he has (`normName`) is made a **link** to that thing ("his weight, bag, brand and notes stay his; only
  things new to him take the sender's details") and takes HIS spelling of the name — the save writes a link's
  name onto the thing, so a shared "towel" used to turn his "Towel" into "towel" (the spec pass) — then
  `saveTemplate` (a sender's how-many or note equal to his thing's own is stored blank, §13).

Tests: `ListSharingTests` (18: round trip; whole link / bare code / link in a message; rejects non-templates and grab
codes; empty template; `listFromShare` rebuild; the two system bins; partial identity; five address tests; big
template squeezed; byte-for-byte against the web app; a web-app code opens here; id order; junk inside a code; a name
cut inside an emoji); `SharingTests.testATemplateArrivesWithoutTouchingHisThings` (his Towel keeps weight and bag,
Fins arrives with 700 g, as "Swim 2" beside his Swim; Replace keeps the id), `testASharedTemplateIsNotAddedUnderANameHeHas`
(refused and nothing changes; "Swim club" taken; then that name is taken too; no worry),
`testALinkedThingKeepsHisSpelling`, `testASharedAlwaysPackedTemplateStaysOneButReplaceKeepsHisPlace` (as new: role
base, a new trip packs its Fins; Replace: his Swim stays role "" in WET with the shared rows); UI
`testATemplateAndAGrabListAreSharedAndOpenedAgain` (his Hiking: `shared-name-taken`, `shared-new-name` holds
"Hiking 2"; "Hiking" → `shared-add-needs` "…do not have…", nothing added; "Hiking club" → "Added…").

---

## 20. Your choices (`ListsScreen`)

### Purpose and origin
"The lists he authors himself: storage places, owners, packers, conditions and the 'When' timeline. They belong to
the account, so both devices show the same; an entry still in use cannot be removed by accident." Renamed from "Your
lists" in 0.34 so it never clashes with Your templates; the explanations are his test K.3 (1 Oct 2026: "a line or
two of explanations for each choice … so that this is totally clear to the user").

### How it is reached and left
Settings → "Your choices" card ("Storage places, owners, packers, conditions, \"When\" steps"; id `settings-lists`).
Left by "Done" (`lists-done`, filled slate; Escape too, 0.62) or swipe down. Container `lists-detail`. Mac: min 520 × 600.

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
- Entries: places = his stored order, or the 12 `DEFAULT_STORAGE_LOCATIONS`; owners = his list A–Z, or (0.62) the
  owners his things name, A–Z (empty only when no thing names one); packers = his, or (0.62) the packers his things name, or the factory two (`DEFAULT_PEOPLE`, the
  invented Kim and Robin since 0.62); conditions = his, or New/Good/Worn/Needs replacing; When = his timeline, or the
  factory seven. The full behaviour, with rename and reorder (0.62), is spec 06 §2.
- Uses (`usesOf`, a `ChoiceUse` since 0.62): things' storage / ownedBy / packer / condition / phase by `normName`;
  for When also, counted apart, the trips with a line in it and the templates with a place in it.
- Add: one he already has → "You already have <name>." and nothing added (0.62; until then a repeat silently
  vanished); places/owners → `setNames(kind, list + [name])`; packers → a person with colour `PERSON_COLORS[count % 8]`; conditions → `newCondition`; When →
  `newStep(named:)` appended, `setTimeline` — `newPhase` with its colour from `COVER_COLOURS` (§3) by the number of
  steps, so the eighth is indigo, never teal as the web app's pick made it (the spec pass, 5 Oct 2026). A list that
  equals the factory one is stored as **no rows**.
- Remove: in use → the reason under that entry, naming things, trips and templates ("<label> is still used by 3
  things and on 1 trip, so it stays.", 0.62) and nothing changes; else removed. Removing the last entry of a kind
  brings the factory list back (no rows = defaults).

### Tests
UI `testHisOwnListsAreAddedAndProtectedWhileInUse` (title "Your choices", each hint > 80 characters, "Garage shelf"
added as place row 12, used on a thing, then refused with `lists-problem`); `testEveryAddButtonIsReadyAndSaysWhatIsMissing`
(`list-places-add`); `testTheEditorsLeadWithTheirHeadings` (five headings); 0.62 `testYourChoicesSaysWhyRightWhereItWasPressed`,
`testAChoiceIsRenamedAndMovedAndItsThingsFollow`; 0.62 `testOwnersAreTheNamesHisThingsCarry`. Model `SettingsListsTests` (14);
`TemplateFacesTests.testNoTemplateIsGivenTealOrCyan` (the eighth step's colour).

---

## 21. Every other place that puts things on, or takes them off, a template (cross-references)

| Where | Function | Spec |
|---|---|---|
| Template page: type a name / Choose from your things / ✕ | `addToTemplate`, `putOnTemplate`, `removeFromTemplate` | here |
| Row editor (Save) | `saveRow` → `updateMembership`, `addSection`, `followThing` | here |
| Template page: activity area | `setTemplateArea` | here |
| Template page: Arrange (a heading moved, renamed or removed; a thing moved) | `dropLine` → `moveSection` / `moveRow`, `renameSection`, `removeSection` | §6a, §13a |
| Every load of the library | `letCopiedAnswersFollowTheirThings` (`LibraryModel.reload`) | §13 |
| Thing editor "On these templates" (all templates but the bag list) | `setOnTemplate` on save | Things spec |
| Care table: "On these templates" columns; "How many" / "Section" per template (editable only when the thing is on exactly one template) | `setOnTemplate`, `updateMembership` | Table spec |
| Review: a missed thing onto a chosen template (skipped if a row of that name is already there) | `addToTemplate` | Review spec |
| Refine: Drop | `setOnTemplate(on: false)` | Refine spec |
| Bags: add / delete a bag | `setOnTemplate` on the bag list | Bags spec |
| Shared template import | `importTemplate(_:replacing:named:)` → `saveTemplate` | §19 |
| Backup import | `saveTemplate` per list | Backup spec |

---

## Open questions / discrepancies

Found by reading the code; none of these is covered by a test unless said. Tags: **[bug]** the code does
something wrong or surprising; **[rule-break]** it breaks one of his standing rules; **[doc]** a comment or
document disagrees with the code; **[untested]** behaviour that matters and no test pins; **[idea]** worth
deciding before a rewrite.

**Data and behaviour.**

1. [bug] **The thing's own note (and qty) gets frozen into rows** — Resolved in 0.62: a row stores how many and a
   note only where they differ from the thing's own (`saveTemplate` → `placeAnswer`), and on load every place an
   older build froze goes back to blank (`letCopiedAnswersFollowTheirThings`) — so a change to the thing's note
   reaches every row again (`TemplateRowsTests`, UI `testAThingsNoteIsNotCopiedOntoATemplate`).
2. [bug] **The row editor drops condition values it does not know.** — Resolved in 0.62: Save keeps a word it does
   not know (shown as a lit pill of its own, switched off like any) — `saveRow` → `keptConditions`
   (`testARowSavedFromTheEditorKeepsWhatItDoesNotKnow`).
3. [bug] **Order of picked things** — Resolved in 0.62: the picker keeps the order he ticked, and that is the order
   they land in (UI `testThingsPickedLandInTheOrderTicked`).
4. [bug] **Typing an existing thing's name on a template that already has it** — Resolved in 0.62: decided — typing
   never makes a second row (a slip, never a wish); the page says "“<name>” is already on this template." and
   `addToTemplate` refuses it. A thing twice on one template stays possible where the data says so (UI
   `testTypingAThingAlreadyOnTheTemplateSaysSo`, model `testTypingAThingAlreadyOnTheTemplateDoesNotAddItTwice`).
5. [bug] **"Add as a new template"** — Resolved in 0.62: as a new template a name he has is refused; the screen
   offers a free name ("Hiking 2") in a field and says what is missing when pressed with a taken one
   (`importTemplate(…named:)`; `testASharedTemplateIsNotAddedUnderANameHeHas`, the share UI test).
6. [bug] **Importing links takes the sender's spelling** — Resolved in 0.62: a linked row takes HIS spelling of the
   thing's name before the save (`testALinkedThingKeepsHisSpelling`).
7. **Resolved in 0.62** — ~~Sharing an empty template says "too big for a link".~~ With no link and no file
   the share sheet says "There is nothing on it to share yet." (`share-empty`; the Home spec's fix for the
   empty grab list, the same screen). Not pinned for a template in the UI.
8. [bug] **`suggestedIcon`'s "train" rule** — Resolved in 0.62: train and tent are whole words now ("Strength
   training" → strength, "Campus" → nothing; `testATrainAndATentNeedTheirWholeWord`).
9. [bug] **"Same as the thing (X)"** — Resolved in 0.62: the first pill says "Same as the template (<its bag>)" on a
   template with a default bag (`sameBagWords`; `testABlankBagNamesWhereItReallyGoes`).
10. [bug] **"Only on:" lists contexts on a non-WET template** — Resolved in 0.62: "Only on:" lists Context only on a
    WET template (`onlyOnWords`; `testOnlyOnSaysWhatATripReadsOnThisTemplate`).
11. [bug] Resolved in 0.62 (Things spec, item 1): the table and Change all offer `Library.bagNames()`, over the
    RESOLVED bag list, so his own bags are offered.
12. Resolved in 0.62 (the settings area, F061): the number is things only, and a refusal names what else holds a step — "by 3 things, on 2 trips and on 1 template" (`ChoiceUse`, spec 06). Was: [bug] **Your choices' refusal** says "<label> is still used by <n> thing(s)", but for When steps n also
    counts trip lines and template rows.
13. [bug] **`followThing`'s "today"** was the UTC date. Resolved in 0.62 (the trips area, F036): it goes by
    `Library.localToday()`, the device's own date, as the screens do.
14. [untested] **A shared base or transport template keeps its role.** — Resolved in 0.62: pinned by
    `testASharedAlwaysPackedTemplateStaysOneButReplaceKeepsHisPlace` — as a new template it stays always packed (the
    preview and the "Added" line now say so); Replace now keeps HIS template's role, area and transport, so his
    activity never becomes always packed.
15. [untested] **Three `.sheet` modifiers on the Templates tab's scroll view** — Resolved in 0.62: the tab has one
    sheet with a destination; `testEveryDoorOfTheTemplatesTabOpens` opens a template, Search and New one after
    another, twice. (Settings' two sheets are spec 06's.)

**What to decide.**

16. Resolved in 0.62 (the storage area): `replaceTemplate(id:with:)` keeps his icon, sections, bags and his answers on the things he had, and says first what comes in and what leaves (spec 01 §16.4; `ReplaceTemplateTests`). Was: [idea] **Replace drops his icon choice and his row exceptions**: the shared list has no `extra`, so the
    stored `iconKey` is lost; linked rows get blank bag/When exceptions and the sender's
    conditions/qty/note/section; his rows not in the shared list are taken off.
17. [idea] **`TemplateUse` counts future trips** — Resolved in 0.62: a trip that has not begun is no longer "last":
    the card says "Next: in 30 days · <trip>" for a template only ever planned (`templateUse(today:)`,
    `TemplateUse.line`; `testATripStillAheadIsNextNotLast`).
18. [idea] **Template summary** — Resolved in 0.62: the line counts the things ON the templates shown (each once)
    and the trips packed from them (`templateSummary`; `testTheTemplatesLineCountsWhatItSays`); the comment says
    "templates".
19. [idea] **Row editor's Add-a-section** — Partly resolved in 0.62: a section typed in the row editor is made only
    on Save (UI `testASectionTypedInARowIsMadeOnlyOnSave`), and a template's activity area can be changed on its
    page (`setTemplateArea`, UI `testATemplateMovesToAnotherActivityArea`). Resolved in 0.63 for renaming,
    reordering and deleting a section and reordering rows: he was shown three layouts and chose "C" — Arrange on
    the template's page, hold ≡ and drag a heading or a thing; a heading's name tapped to rename or remove it
    (§6a, model §13a; `ArrangeTests`, UI `testArrangeTurnsOnAndOff`, `testAThingIsDraggedUnderAnotherHeading`,
    `testAHeadingIsDraggedWithItsThings`, `testAHeadingIsRenamed`, `testAHeadingIsRemovedAndItsThingsStay`).
    Still left, for him to decide: changing a template's role or transport changes what EVERY trip packs; colour,
    emoji and default bag are web-app data he has never asked to set here (no emoji in this app); a row's weather
    tags, kit and reminder type have no use on any screen of this app.
20. [idea] **A row change does not reach trips already made** — Resolved in 0.62: a row saved in the row editor
    reaches the open lines of trips still ahead, as a change to the thing does (`saveRow` → `followThing`;
    `testARowChangeReachesATripStillAhead`). Rows typed on, picked on or taken off still reach a trip only through
    its Trip settings (adding or dropping a line is a bigger step than updating one).
21. [idea] **Search can open a role-"loose" template** — Resolved in 0.62: Search lists the same templates as the
    tab (`shownTemplates()`: not the bag list, not the loose bin).
22. [idea] **Device-wide memories** — Left: kept as one memory per device — one way of reading every template is
    what he asked for ("the same way as when you pack"), as the trip's sorting is remembered; a fold kept for a
    renamed place costs a few bytes, and forgetting it could unfold a group he folded on purpose.
23. [idea] **`NewList`** — Resolved in 0.62: the needs line goes as he types (the shared `needsLine`), `canMake` is
    gone, and the bag list's hidden "Containers" is not a taken name (`templateNameTaken`; Worth a look counts the
    bag list apart).
24. [idea] **`groupBy("container")`'s "Unpacked"** — Left: a comment now says it is never reached; the line stays
    because `Grouping.swift` is the web app's copy, held to it by the parity check, and removing it would change
    nothing he sees.

**Comments and documents.**

25. [doc] **ThingGrouping's doc** — Resolved in 0.62: decided — a template page keeps HIS order inside a group
    (Section and When), the picker's When reads A–Z to find a thing among all he owns; the `ThingGrouping` comment
    says so.
26. [doc] **Picker row "aside"** — Resolved in 0.62: the comment now says what the row shows (under Into a thing
    with no place shows its bag — better than nothing).
27. [doc] **Release log** — Resolved in 0.62: a What's new line for the "Only on some trips" choices is proposed for
    the release notes (written at release time, not in this branch).
28. [doc] The `Cover` comment "the app adds no art of its own" predates the suggested icons — Resolved in 0.62: the
    comment now says the cover shows his icon or the suggested one, drawn in the app's hand, else the letter.

**His standing rules.**

29. [rule-break] **Choose from your things, "Add" with nothing ticked** — Resolved in 0.62: Add with nothing ticked
    says "Tick the things to put on first." under the title (`pick-add-needs`, UI
    `testThingsPickedLandInTheOrderTicked`).
30. [rule-break] **Cover "Letter" with an emoji** — Resolved in 0.62: the cover shows the letter, never the emoji
    (`coverLetter`; `testACoverShowsALetterNeverAnEmoji`).
31. [rule-break] **`TEMPLATE_COLORS`** — Resolved in 0.62: covers and new "When" steps take `COVER_COLOURS` — the
    web app's ten with cyan → orange and teal → indigo (`testNoTemplateIsGivenTealOrCyan`); `TEMPLATE_COLORS` itself
    stays for the parity check. Not changed: the factory "When" steps' own colours (Day before is cyan, After /
    recovery teal — his familiar steps, used across the trip screens).
32. Withdrawn (his word, 5 Oct 2026): there is no 15-pt floor in this app — it uses Apple's standard text styles (spec 06, "Type"). Was: [rule-break] **Text under 15 pt** in this area — card "used" line 12, icon labels 12, "WHAT IS IT CALLED"
    12, row qty/note and tags 13, Delete template 13, "You already have a template called that." 14, the
    delete question's text 14, the row editor's "Blank means…" 14, picker pills/aside/counts 14, Your
    choices counts and footer 14.
33. **Resolved in 0.62** — ~~`DEFAULT_PEOPLE` holds two real first names in a public repository.~~ They are the
    invented Kim and Robin (spec 06, item 29).
