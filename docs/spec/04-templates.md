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
much better."). **Since 0.89 the areas are HIS** (§1a; 18 Oct 2026: "I would like the ability to add and adjust
activity areas so that I can organize templates"): made, renamed, moved and removed on the Templates tab's
Activity areas page; the three above are where every library starts.

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
`CoverDoor`, `IconPickerScreen`, `TemplateColourSwatches` (0.90), `TemplateDetail`, `RowEditor`, `Color(hexString:)`),
`App/Sources/TemplateIcons.swift`, `App/Sources/Screens/NewList.swift` (and, 0.90, `NewTemplateDoor` — a thing's page's
door to it, spec 05 item 6b), `App/Sources/Screens/PickThings.swift`, `App/Sources/Screens/ListsScreen.swift`,
`App/Sources/Screens/AreasScreen.swift` (his activity areas and a template's Activity area, 0.89);
model: `PackingCore/Lists.swift`, `Memberships.swift`, `Resolve.swift`, `Grouping.swift`, `Kits.swift`,
`ListSharing.swift`; `PackingLibrary/Library.swift` (template parts, and arranging a template's headings and
rows — §13a), `EditLists.swift`, `Bags.swift` (list role and
`shownName`), `TemplateIcon.swift`, `TemplateIconCatalog.swift`, `TemplateIconKeywords.swift` (the icon search's other words, 0.91, §3), `TemplateColour.swift` (0.90, §3a), `TemplatePicking.swift`, `TemplateUse.swift`, `ThingFollows.swift`,
`Sharing.swift` (template parts), `ActivityAreas.swift` (his activity areas, 0.89), `TemplateRows.swift` (a row's own answers, the row editor's Save, covers'
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
- Its chosen colour (0.90) is the template's own `color` — the web app's cover-colour field, a first-class field of
  every template record, backup and shared template — a hex from the palette, or blank = Automatic (see §3a).
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
   - Heading — `AreaBlock.title`: `Library.areaWords` (0.89; `areaHeading`/`groupHeading` until then) =
     `"<CODE> · <Name>"` for a built-in under its own name, otherwise his words alone ("Mountains", or a built-in he
     renamed); the fixed headings just their title — **as he writes them, not in capitals** (0.78): "Always Packed", "By Transport", "GA · Goal Activity",
     "WET · Workout, Exercise & Training", "OE · Other Events", "Other Templates" (his code GA / WET / OE stays in
     capitals). His words on the iPhone (13 Oct 2026): "GA · Goal Activity — not all caps", "WET · Workout,
     Exercise & Training — not all caps", "Other Templates — not all caps". Until 0.78 `groupHeading` upper-cased
     the words ("GA · GOAL ACTIVITY", "ALWAYS PACKED"). Headline, `Theme.ink`, top padding 16 (until 0.62: 18
     heavy, kerning 0.8, "Much larger headings", his H.13). id `templates-area-<testId>` where testId is `base`,
     `transport`, a built-in's code `GA`, `WET`, `OE` (renamed or not), `own-<n>` for an area he made (n = its
     place in HIS list of areas, 0.89 — his ids are random) or `other`.
   - A `LazyVGrid` of two flexible columns (spacing 8 both ways) of **cards** (§2). Each card is a plain Button;
     id `template-row-<n>` where n = the template's index in the flattened list of all areas, top to bottom
     (so with the sample library: 0 = Common base, 1 = Hiking, 2 = Swim). Tap → opens `TemplateDetail` (§6).
4. **Activity areas** (0.89, `areasDoor`, id `templates-areas`): the quiet violet pill with the pen that opens his
   areas (§1a) — **at the foot of the tab, after the last area's cards** (0.91), 20 above it, left-aligned. It sits
   OUTSIDE the lazy stack of headings and cards (a plain `VStack` holds the `LazyVStack` and then the pill, the side
   padding 16 and bottom 24 moved onto it), so it is always built: the Mac builds only what is on screen, and the pill is
   often below the window's edge. Until 0.91 it stood at the head of the headings, under the Refine card and the
   small-core news card (2a). His words (19 Oct 2026, the test sheet of 0.89): **"Please move the activity pill button
   to the bottom of the page."**
- No empty-state text: a ready library with no templates shows the header, the summary "0 templates · …", the
  Refine door and the Activity areas pill.

### Behaviour
- **One sheet with a destination** (`opened: Opened?` — `.template(id)`, `.search`, `.new`): a card, the
  magnifier and "+ New" each set it. Not three `.sheet` modifiers: "SwiftUI does not reliably present a second
  sheet on a view while the first is still closing" — the trap met in Search (0.17), tidied here by the spec pass
  (5 Oct 2026).
- `activityAreas(all, library)` takes `library.shownTemplates()` (every template but the bag list and the loose bin,
  resolved, sorted A–Z with `jsLocaleCompare` default sensitivity) and builds, **omitting empty areas**:
  1. `base` "Always Packed" — templates with `role == "base"` (A–Z).
  2. `transport` "By Transport" — `role == "transport"` (A–Z). (The area titles in his casing since 0.78.)
  3. For each of HIS areas in his order (0.89, `Library.listsByArea`, §1a; until 0.89 the `GROUPS` order GA, WET,
     OE): templates with `role == ""` whose `areaOf` is that area, ordered by `orderActivities(areaId, …)` — only
     WET has a fixed order (`ACTIVITY_ORDER["WET"]` = Swim, Bike, Run, Strength, Mobility, Breath work, matched by
     `normName`); unknown names follow A–Z; every other area keeps the A–Z input.
  4. `other` "Other Templates" — `role == ""` and in no area of his (`areaOf` "": no area, or one that is gone).
  - Templates with role `container` (the bag list, "Containers"/"Bags") and `loose` (the web app's retired "Loose
    items" bin) appear in **no** area: "Bags are not an activity: they have their own screen, on Care".
  - A base or transport template that also has a group is shown only under Always packed / By transport.
- The template's stored field is still `group` for a built-in area; one he made rides in `extra["area"]` (§1a).
- Home's Templates count tile uses the same `activityAreas(templates, library)` sum.
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
  `templates-area-GA` reads "GA · Goal Activity" and `templates-area-base` "Always Packed" — red with the capitals
  planted back in `groupHeading`: `("GA · GOAL ACTIVITY") is not equal to ("GA · Goal Activity")`; summary contains "templates"; a card opens `template-detail`,
  Done closes it); `testAnEmptyDeviceShowsTheTwoDoors`; `testHeMakesAListOfHisOwn` (heading reads "Your templates");
  `testRefineOffersWhatTheReviewsFoundAndKeepAndDropSettleIt` and `testTheLoopShowsWhereATripStands` (use
  `refine-open` here); `testEveryTabsHeaderIsOnOneCentreLine` (0.67: `search-open` and `templates-new` within
  1.5 pt of the centre line of `templates-heading`; on 0.66 the magnifier was 10.2 pt and + New 2.5 pt off).
- Model: `ListsTests.testOrderActivities*` (4 tests); `CreateTripTests.testTheChoicesAreHisGroupsInHisOrder`;
  `TemplateFacesTests.testTheTemplatesLineCountsWhatItSays` (the bag list and the loose bin are not shown; things
  on them counted once; a trip packed from none of them not counted).
- 0.89: `testHeMakesAnActivityAreaAndFilesATemplateInIt` (the pill, his area's heading `templates-area-own-0` above
  WET), `testAnAreaIsRenamedAndOnlyAnEmptyOneIsRemoved` (a renamed WET heading) — §1a.
- 0.91: `testTheActivityAreasPillIsAtTheFootOfTheTemplatesTab` — `templates-areas` stands below the last area's
  heading (`templates-area-WET` in the sample), below its last card (`template-row-2`, Swim) and below every other
  heading, and still opens `areas-detail` (pictures `tmpl91-pill-templates`, day and night). Seen RED with the pill
  planted back at the head: `XCTAssertGreaterThan failed: ("224.0") is not greater than ("608.9999999999999") - the pill
  is not under the last area's heading: pill 224.0, heading 608.9999999999999`.
- **Not covered:** the "By Transport" and "Other Templates" areas, the exact summary wording on screen.

---

## 1a. His own activity areas (0.89, `AreasScreen`, `TemplateAreaField`; model `PackingLibrary/ActivityAreas.swift`)

### Purpose and origin
His words, 18 Oct 2026: **"I would like the ability to add and adjust activity areas so that I can organize
templates."** Until 0.89 an area was one of three codes fixed in the web app's model (`GROUPS`: GA · Goal
Activity, WET · Workout, Exercise & Training, OE · Other Events), stored in a template's `group`. Since 0.89 they
are his list, changed the way his other lists are (Your choices, a drop-down's tools, 0.69/0.70): a pen renames
an area and everything in it follows, the grip ≡ (on the Mac also ↑ ↓) moves it, a new one is typed at the foot,
Remove asks — or, while templates are in it, says which and keeps it; nothing changes until Save. A template is
moved into any of his areas from its own page (§6, Activity area, a drop-down since 0.89).

### How it is reached and left
- **Activity areas** — a quiet pill on the Templates tab, at the foot of the headings it changes, after the last
  area's cards (0.91, his "Please move the activity pill button to the bottom of the page."; until then at their head,
  under the Refine card and the small-core news card, above "Always Packed"): the hand-drawn pen (16) and "Activity areas"
  (Subheadline semibold) in violet, on a 10 % violet capsule with a 1-pt violet ring, `Metrics.chip` tall, side
  padding 12; id `templates-areas`, label "Activity areas", hint "Make, rename, move or remove your activity
  areas". It opens the page as the tab's one sheet (`Opened.areas`). Why there: the areas are the Templates tab's
  headings, so the control that changes them sits with them — the same place on both devices; Settings → Your
  choices holds the lists a THING uses. At the foot (0.91) it no longer stands between the Refine card and his
  templates: the cards come first, the tool to rearrange their headings after them.
- Left by **Cancel** (`areas-cancel`, outlined muted; Escape too) — nothing changes — or **Save** (`areas-save`,
  violet, filled, always in colour: with nothing changed it simply closes), or a swipe down on the iPhone (= Cancel).

### What is on screen (container `areas-detail`; Mac min 480 × 520)
- Top row (padding 16): Cancel · "Activity areas" (Title 3 bold violet, one line, scales to 80 %, `areas-title`) ·
  Save.
- In a `KeyboardAwayScroll` (side 16, bottom 24):
  - The intro (Subheadline muted, `areas-intro`): "Your templates are grouped under these areas on Templates and on
    Create new trip, in this order. Hold the grip ≡ and drag an area to its place; the pen renames it. A template
    moves to another area on its own page (Activity area). Nothing changes until Save." On the Mac "…to its place,
    or use the arrows; the pen renames it…".
  - One row per area, in his order as the page holds it (n = its place on the page): row `areas-row-<n>` (min
    height `Metrics.tap`, hairline under): the grip ≡ (`areas-row-<n>-grip`, `ReorderGrip`, not on a struck-out
    row), the area's words (Body ink, wraps; `areas-row-<n>-label`) — a built-in under its own name with its code
    ("GA · Goal Activity"), otherwise his words — then, when templates are in it, their number (Footnote semibold
    monospaced muted, label "1 template" / "N templates", `areas-row-<n>-count`); at the right the pen
    (`areas-row-<n>-rename`, label "Rename …", muted), on the Mac ↑ ↓ (`-up`, `-down`; violet, faint where there is
    no place to go) and **Remove** (Subheadline semibold red, `-remove`). A row taken away on the page is struck
    out and muted, with **Put back** (`-putback`) instead of its tools.
  - The pen: the row becomes a field (`areas-row-<n>-name`, his words without the code, violet ring) with **OK**
    (`-rename-ok`); Return takes the name too, Escape (Mac) leaves it. What is wrong is said under it
    (`-name-needs`, Subheadline semibold red): "Type a name first.", "You already have <name>." (as the page
    shows the list, struck-out rows aside), "<Heading> is a heading of its own on Templates. Pick another name."
    for Always Packed, By Transport and Other Templates.
  - Remove: inside the list, a card (red 1-pt ring, card fill, radius 10): for an empty area "Remove <area> from
    your activity areas? No template is in it." (`-ask`) with **Remove** (white on red, `-remove-yes`) and
    **Keep** (`-remove-no`); for an area that holds templates the reason instead (`-refused`) with **OK**
    (`-remove-no`): "<area> still holds Hiking, so it stays. Move it to another area on its page first." (two or
    three names "A and B" / "A, B and C"; more: "A, B, C and N more"; "them … their page" for more than one); for
    the workout area always "<area> is where your workouts live — each gets its own Context on a trip — so it
    stays." (`Library.areaRemoveProblem`).
  - The foot (12 above): field "A new area" (`areas-add-name`; Return = Add) and **Add** (violet,
    `areas-add`); pressed with nothing typed, or with a name he has or a reserved one, the line under it says
    so (`areas-add-needs`, the shared `needsLine`). An added area is the last row, movable, renamable and
    removable like the rest, made on Save.
  - The footer (Footnote muted, `areas-footer`): "Your areas belong to your account, so both your devices show the
    same. Always Packed and By Transport stay where they are: those templates are filed by what they do."

### Behaviour
- The page holds a `ChoiceEdits(kind: "areas")` (ChoiceEdits.swift, the drop-downs' own mechanism): names by
  key, the order, the removed, the added. Rows are `choicesAsEdited`. Save writes them with
  `applyChoiceEditsNow` — names (a swap parks each first), then the added (each made by `addChoice("areas")` →
  `addArea`: id `"area-" + PackingEnv.makeId()`), then the order (one step at a time by `moveChoice("areas")`),
  then the removals (`removeChoice` — an area that gained a template meanwhile on the other device stays).
- **An area is pointed at by its id**, never its name: a rename changes the list only, and every template in it
  follows by itself (as a "When" step's).
- **Which areas exist** (`Library.activityAreas()`): his list from `meta["activityAreas"]` (`[{id, name}]`), or
  the three the app ships with when there is none (never seeded). Read cleanly: trimmed, names cut to 60 UTF-16
  units, rows without id or name and repeated ids skipped, and the workout area ("WET") always there (put last
  should a list ever lack it). Written only while it differs from the three as shipped (`setActivityAreas`; the
  list back as shipped removes the record).
- **The built-ins** keep their ids "GA", "WET", "OE" and their roles. Renamed, they show his name alone; back
  under their own name they show their code again (`Library.areaWords`). **GA and OE can be removed once no
  template is in them; WET never** — it is the workout area: each workout's own Context on a trip
  (`contextApplies`, PackingCore), the workout colours on Create new trip, Swim/Bike/Run order
  (`ACTIVITY_ORDER`). Moving a template OUT of WET makes it no workout (no own Context); Counts as (Apple Health)
  is the template's own and does not change.
- **Which area a template is in** (`areaOf`): "" for an always-packed or transport template (filed by what it
  does); else its `group` when that is a built-in area of his; else its `extra["area"]` when that names an area
  of his; else "" — **Other Templates**. So a template whose area went (removed on the other device while this
  one moved it in) is never lost: it falls under Other Templates.
- **Where it is stored, and why** (parity with the web app's data, 211/211): the list is ONE `meta` record —
  like his kinds of thing (0.69) — not shared rows, because a NEW shared-row kind is blanked by PackingCore
  (`coerceSharedRow`). A built-in area stays the template's `group` (what the web app and PackingCore read); one
  of his goes in `extra["area"]` with `group` "" (`coerceList` would blank any other `group`; the web app shows
  such a template under its "Other lists"). Both ride through the store (iCloud), a backup (`prefs.activityAreas`
  and the template's own row) and a restore exactly — `ActivityAreasTests.testTheAreasSurviveTheStoreABackupAndARestore`.
  One record for the list means the later of two offline edits of the LIST wins (spec 01 §1.11).
- **Headings** (Templates tab §1, Create new trip and Trip settings spec 03): his areas in his order, each only
  while a template is in it (as before 0.89 — an empty area has no heading; the page lists it with no number),
  then Other Templates. Inside an area: `orderActivities` (Swim/Bike/Run in WET, stored order elsewhere).
- **A template's page** (`TemplateAreaField`, §6): picking an area files the template at once
  (`setTemplateArea`). "A new area" at the foot of that drop-down makes the area at the end of his list and files
  the template in it in ONE change (one he already has, compared as names, is simply chosen; a reserved name is
  refused under the field, `template-area-needs`) — at once, because a template's page saves as it goes (as a
  reminder's When does, 0.73).
- **New** (§5) and **Make a small core** (§14b) offer his areas in his order too.

### iPhone vs Mac
Same page. The Mac has ↑ ↓ on each row (Tab reaches them) besides the grip; the iPhone moves a row by its grip
only (0.72) and VoiceOver by the grip's "Move up" / "Move down". Escape = Cancel; in a name field it leaves the name.

### Tests
- UI `testHeMakesAnActivityAreaAndFilesATemplateInIt` (0.89): the page lists GA, WET, OE with GA's "1 template";
  Add with nothing typed says so; "Mountains" added last, moved first (the iPhone drags its grip, the Mac its ↑),
  Save; no heading while empty; Hiking's drop-down offers it as row 1 and files Hiking there; the tab shows
  `templates-area-own-0` "Mountains" above WET and GA gone; Create new trip's first group heading is "Mountains".
  Seen RED with the template page's list planted as the factory three: `XCTAssertEqual failed: ("GA · Goal
  Activity") is not equal to ("Mountains") - the new area is not offered first`.
- UI `testAnAreaIsRenamedAndOnlyAnEmptyOneIsRemoved` (0.89): WET renamed "Training" with the pen and OK; GA's
  Remove refused, exactly "GA · Goal Activity still holds Hiking, so it stays. Move it to another area on its page
  first."; OE's asks and is struck out; Save: `templates-area-WET` reads "Training"; reopened, two rows. Seen RED
  with the refusal planted away: `XCTAssertTrue failed - Remove on an area in use asked instead of refusing`.
- Model `ActivityAreasTests` (8): the three as shipped, nothing stored, headings as before; a new area in his order
  and a template filed in it (`group` "", `extra["area"]`), back to a built-in, unknown area and transport refused,
  Always packed clears it; a rename followed, a built-in keeps its role (WET still `contextApplies`, Swim/Bike/Run
  order), a swap of names, the list back as shipped stores nothing; names refused (one he has, the three reserved
  headings, blank); an area in use stays naming its templates, WET always stays, an empty built-in goes, held
  removals on Save, a template whose area went falls under Other Templates, WET always read back; moving;
  **the store, a backup and a restore bring both the list and each template's area back exactly** (the web model
  reads `group` "" and keeps the key) — seen RED with the backup's `prefs.activityAreas` planted away: `… is not
  equal to … - a backup lost his areas`, `- a restore did not bring his areas back exactly`; and with his own area
  planted into `group`: `XCTAssertEqual failed: ("area-id-7") is not equal to ("") - his own area went into the web
  app's field`; a shared template replacing his keeps his area, a new template made in one.
- Parity: `tools/parity/run.sh --invented` 211 of 211 identical (PackingCore unchanged).

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

## 3. The cover and the template icons (`Cover`, `IconMark`, `CoverDoor`, `TemplateIcons`, `TemplateIconCatalog.swift`, `TemplateIcon.swift`)

### Purpose and origin
His test H.1. 50 icons "of my own, drawn in the app's style (one stroke, round ends, a 24-point box)"; he saw them
on a sample sheet in day and night mode and said (2 Oct 2026): "Your suggestions are fine. Please implement."
Released in 0.46. No stock art, no emoji in the icon set.

**0.92: 41 more (132 icons).** His words (19 Oct 2026): **"Could we add some icons again. Love the one we have."**
41 new drawings in the same hand as the 91 (one stroke 1.9 wide on the 24-point grid, round caps and joins, no fill,
nothing closer than about 2 points; checked at 30, 20 and 14 points, day and night, beside old ones — the contact
sheets of the build), none a near-copy of an old one (a cross-country skier beside the Skiing skis, a stopwatch beside
the Watch, a heart with its pulse beside Health, a trophy beside the Triathlon medal), chosen for his life: Sweden
(the stuga, midsummer's pole, skates, the pulka, cross-country, mushrooms, mittens), training (the erg, a stopwatch,
heart rate, a trophy, the bike helmet and pump, a wetsuit, a yoga mat), the water (scuba tank, paddleboard, life
jacket, anchor), the beach (ice cream, sand toys), city and business trips (pizza, museum, cinema, fun fair, name
badge, notes, suit), family days (birthday, wedding, Christmas, pram) and the bag (neck pillow, toothbrush, battery).
No alcohol among them (the Wine of 0.74 stays; nothing new to drink). **The Rowing icon is the rowing machine he named
at sight in AMS Workout Sync's blind test (E7, 30 Sep 2026)** — the same drawing (fan, monorail, seat, front foot,
floor, monitor arm; without the arm he could not name it there). **The Battery is the app's own** (`ToChargeCard.battery`,
the To charge card), so the app has one battery. Each new icon stands at the **END of its heading**, so every icon he
knows keeps its place (`TemplateIconCatalog.firstNinetyOne`, pinned by a test); each has its hidden other words (§ Other
words); and a few have words to be suggested by — at the very end, so no template that had a suggestion is given
another (§ Which icon, rule 49b). No new heading: all 41 fit the six (decided by the build). Nothing is chosen for him.

**0.78: the weekend bag (91 icons).** His ask (13 Oct 2026, the picker on the iPhone): his small always-packed
template showed the same suitcase as his big Travel one — "a nice unique icon — not the same as Travel". One new
drawing in the same hand, `weekendbag` "Weekend bag", right after Travel, suggested by a short trip's words (§ Which
icon, rules 45a and 49a). Nothing is chosen for him: a template he gave an icon keeps it.

**0.74: 90 icons.** His request (12 Oct 2026, a picture of the Mac's picker open on his template "On the Beach",
whose Suggested was the plain umbrella): "Add approximately 40 new icons, specifically one that is related to
'On the beach'." 40 more drawings in the same hand — one stroke 1.9 wide on the 24-point grid, round caps and joins,
no fill, no two lines closer than about 2 points so a mark still reads at 14 points (the size a trip line will use) —
checked at 30, 16 and 14 points and on a 26-point cover, day and night, iPhone and Mac. "On the beach" is a sun
lounger under a parasol on a line of sand (key `lounger`), and a template whose name says beach is now given it
(§ Which icon). The drawings moved from the app into the model package (`PackingLibrary/TemplateIconCatalog.swift`)
so the model's tests can check every one; the app's `TemplateIcons` (`all`, `icon(_:)`, `Icon` with `key`, `label`,
`path`; since 0.74 also `grouped`) reads them from there unchanged. **A key is what a template stores and never
changes; a label may** — 0.74 relabelled `gift` from "Party" to "Gift", "Party" being its own icon now.

### `Cover(list, size = 40)` — what is drawn
- A rounded square (`cornerRadius = size × 0.28`) filled with **`Cover.fill(list)`** = **`Library.coverColour(list)`**:
  the template's own `color` if it is a valid hex colour (his choice since 0.90, §3a — or a colour the web app gave
  it, kept whatever it is), else (Automatic) a stable pick by `jsHash31(id)`
  (`h = h*31 + utf16 unit`, wrapping at 32 bits; falls back to the name when the id is empty) modulo 10 from
  **`COVER_COLOURS`** — the web app's `TEMPLATE_COLORS` (`#7c5cd6 #3b82f6 #06b6d4 #22c55e #f59e0b #ef4444 #ec4899
  #14b8a6 #8b5cf6 #64748b`, kept as they are for the parity check) with cyan `#06b6d4` → orange `#f97316` and teal
  `#14b8a6` → indigo `#4f46e5` ("Not teal … Do not use teal for anything new", `docs/colours.md`; the spec pass,
  5 Oct 2026). Every other template keeps the colour the web app gives it (`listColor`, pinned: id "fixed-id" →
  `#8b5cf6`).
- If `TemplateIcons.icon(Library.icon(of: list))` exists → that icon drawn at `size × 0.66` (`IconMark`, stroke
  1.9 × size/24, round caps and joins) in **`Library.coverInk(list)`**: the palette colour's own ink when the fill is
  one of the palette (§3a — dark on Bike's yellow, Run's green, Strength's orange, Breath work's lavender,
  Mobility's pink), else **white** (every Automatic colour, and a web-app colour; white as every cover was until 0.90).
- Otherwise its letter, in the same ink, heavy, font `size × 0.46`: `Library.coverLetter(list)` = the first character of the
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
  name; *word* = a whole word, words split on any non-letter). Since 0.74 (marked ✱) the new icons have their words,
  in English and in Swedish; rules that are new for an OLD icon stand at the end, so a template that had a suggestion
  keeps it unless a new icon fits it better (a beach, a motorbike, a sailing boat, yoga, a business trip):
  1. role `container` → `box`
  2. has "freediv" or ✱"fridyk" → `fin`
  3. has "diving", word "dive", has "scuba", "snorkel" or ✱"dykning" → `diving`
  4. word "car" → `car`
  5. has "plane", "flight" or word "fly" → `plane`
  6. word "rv", has "camper", "motorhome", "caravan" → `rv`
  7. ✱ has "motorbike", "motorcycl", "motorcykel" or word "mc" → `motorbike` (before "bike" and "cycl": until 0.74 a
     motorbike was given the bicycle)
  8. word "train" or "trains", or has "railway" → `train` (whole words since the spec pass, 5 Oct 2026:
     "Strength training" and "Swim training" were given a train)
  9. ✱ has "sail", "segl", "segel" or "yacht" → `sail` (before "boat": a sailing boat was a ferry)
  10. has "ferry" or "boat" → `ferry`
  11. ✱ word "bus", "buses", "buss" or "coach" → `bus`
  12. has "golf" → `golf`
  13. has "hik" or "trek" → `hiking`
  14. has "climb" → `climb`
  15. word "ski" or has "skiing" → `ski`
  16. word "camp", "camping" or "camps", or has "campsite", "campground", "campfire" → `tent` (whole words since
      the spec pass: "Campus" was a tent)
  17. ✱ has "triathlon", "ironman" or word "tri" → `triathlon` (before swim, bike and run)
  18. has "bike" or "cycl" → `bike`
  19. word "run" or has "running" → `run`
  20. ✱ has "ice bath", "icebath", "isbad", "cold plunge", "kallbad" → `icebath` (before swim)
  21. has "swim" → `swim`
  22. has "strength" or word "gym" → `strength`
  23. has "breath" → `breath` ("his 'Mobility & Breath work' is breath")
  24. ✱ has "yoga" → `lotus` (the seated Yoga; until 0.74 yoga gave `mobility`)
  25. has "mobility" or "stretch" → `mobility`
  26. has "padel" or "tennis" → `racket`
  27. ✱ has "kite" → `kite` (before "surf": kitesurfing is the kite)
  28. ✱ has "surf" → `surf`
  29. has "beach", ✱word "strand", ✱has "sunbath" or "solsemester" → ✱**`lounger`** ("On the beach"; until 0.74 the
      umbrella `beach`, which no name suggests any more — it stays in the picker)
  30. ✱ has "tropic", word "palm", "palms" or "island" → `palm`
  31. has "fish" → `fishing`
  32. has "business", ✱"conference", ✱"konferens" or ✱"tjänsteresa" → ✱`briefcase` (until 0.74 business was `laptop`)
  33. word "work", ✱"jobb" or ✱"arbete" → `laptop`
  34. ✱ has "hotel" → `hotel`
  35. ✱ has "city", word "town" or "stad", has "storstad" → `city`
  36. ✱ has "restaurant", "restaurang", "dinner", "middag" → `restaurant`
  37. ✱ has "wine", word "vin", has "vingård" → `wine`
  38. ✱ has "concert", "konsert", "festival", "music", "musik" → `music`
  39. ✱ has "party", word "fest", has "kalas", "wedding", "bröllop" → `party`
  40. ✱ has "birthday", "födelsedag", "christmas", word "jul" → `gift`
  41. ✱ has "shopping", word "shop", has "shoppa", "handla" → `shopping`
  42. ✱ has "picnic", "picknick" → `picnic`
  43. ✱ has "bbq", "barbecue", "grill" → `bbq`
  44. ✱ word "kids" or "barn", has "children", "family", "barnen", "familj" → `kids`
  45. ✱ has "walk" or "promenad" → `walk` ("City walk" is the city — rule 35 comes first)
  45a. ✚ (0.78) a short trip that also says travel: a SHORT word — word "short", has "weekend", has "small core",
      word "kort", has "kortresa", word "helg", has "helgresa" — together with has "travel" or word "resa"/"resor" →
      `weekendbag` ("Short travel kit" is the weekend bag, not the big Travel suitcase). Only such names are taken
      here; every other short name waits for rule 49a, so no name that had a suggestion loses it.
  46. has "travel" → `suitcase`
  47. ✱ old icons that had no words: has "summer"/"sommar" → `sun`; "winter"/"vinter" → `snow`; "sauna"/"bastu" →
      `sauna`; "kayak", "canoe", "paddl", "kajak", "kanot" → `kayak`; "orienteer"/"orientering" → `compass`; word
      "dog", "dogs", "hund" → `paw`; has "coffee", "kaffe", word "fika" → `coffee`; has "photo"/"foto" → `camera`;
      "kettlebell" → `kettlebell`
  48. ✱ Swedish names for old icons: word "bil"/"bilen" → `car`; has "flyg" → `plane`; word "tåg"/"tåget" → `train`;
      has "färja", word "båt"/"båten" → `ferry`; has "vandr" → `hiking`; "skidor"/"skidåkning" → `ski`;
      "cykel"/"cykling" → `bike`; "löpning", word "löp" → `run`; "simning", word "sim" → `swim`; "styrka" →
      `strength`; "fiske" → `fishing`; word "resa"/"resor" → `suitcase`
  49. ✱ has "mountain", "summit" or "fjäll" → `mountain` (after "vandr": "Fjällvandring" is a hike)
  49a. ✚ (0.78) any SHORT word of rule 45a → `weekendbag` ("Weekend", "Short trip", "Small core", "Helg",
      "Weekendresa"; "Summer weekend" stays `sun`, "Weekend hike" `hiking`; "Shorts" is no short trip).
  49b. ◆ (0.92) the new icons' words, last of all — they reach only a name that suggested nothing until now, so no
      icon he sees changes ("Längdskidor" keeps the skis, "Sommarstuga", "Midsommar" and "Midsummer" the sun, "Wedding"
      the balloons, "Christmas" and "Birthday" the gift, "Paddleboard" the paddle, "Weekend cabin" the weekend bag):
      has "rowing", "rodd" or word "erg"/"row" → `rowing`; has "skating"/"skridsko" → `skate`; has "sled", "pulka",
      "kälk", "toboggan" → `sled`; has "cross-country", "langlauf", "längdåkning" → `xcski`; has "wetsuit"/"våtdräkt"
      → `wetsuit`; word "sup" → `sup`; word "race", has "tävling", "competition", "wettkampf" → `trophy`; has
      "mushroom"/"svamp" → `mushroom`; has "cottage", "cabin", "stuga" → `cottage`; has "abroad"/"utomlands" →
      `globe`; has "museum"/"museer" → `museum`; has "cinema", "movie", "kino", word "bio" → `cinema`; has "tivoli",
      "theme park", "amusement park", "nöjespark", "liseberg", "gröna lund" → `ferriswheel`; has "pram", "stroller",
      "barnvagn" → `pram`.
  50. none matched: role `base` → `suitcase`, else nil (the letter).

### The 132 icons (`TemplateIconCatalog.all`, read by `TemplateIcons.all`; key → label shown in the picker; path data in the file, a 24-pt box, only the SVG commands M L H V C S Q A Z that `SVGPath` draws)
In the picker's order, under its six headings (`TemplateIconGroup`, 0.74); ✱ = new in 0.74, ✚ = new in 0.78, ◆ = new
in 0.92 (always the last of their heading, in this order).
- **Travel** (`travel`): car Car · plane Plane · rv Camper · train Train · ✱bus Bus · ✱motorbike Motorbike · ferry
  Ferry · suitcase Travel · ✚weekendbag Weekend bag (a soft holdall: a round-ended body, a zip along the top with
  its pull, two handles — the back one over the front one) · backpack Backpack · box Boxes · passport Passport · ✱ticket Tickets · ✱map Map · ✱hotel
  Hotel (a building with a door and its awning) · ◆cottage Cottage (a house with a pitched roof, a door and a
  chimney — the stuga) · ◆globe Abroad (a globe: equator, two latitudes, one meridian) · ◆pillow Neck pillow (a U with
  round ends) · ◆scooter E-scooter (two small wheels, a deck, the stem and handlebar).
- **Outdoors** (`outdoors`): hiking Hiking · ✱walk Walking · mountain Summit · compass Orienteering · tent Camping ·
  fire Campfire · headlamp Headlamp · ski Skiing · snow Winter · rain Rain · fishing Fishing · ◆xcski Cross-country
  (a skier striding, two poles, the ski's tip turned up) · ◆skate Ice skating (a skate boot on its blade) · ◆sled Sled
  (a seat on two posts, the runner curling up in front) · ◆sleepingbag Sleeping bag (a mummy bag, the face's opening,
  two quilted seams) · ◆binoculars Binoculars · ◆thermos Thermos (a flask with its cup-lid, a cup with steam) ·
  ◆mittens Mittens (a mitten with its thumb, the cuff) · ◆jacket Jacket (hood, zip, long sleeves) · ◆mushroom
  Mushrooms.
- **Sport** (`sport`): run Run · bike Bike · swim Swim · ✱triathlon Triathlon (a medal on its ribbon) · diving
  Diving · fin Freediving · kayak Paddling · climb Climbing · golf Golf · racket Racket sports · strength Strength ·
  kettlebell Kettlebell · mobility Mobility · yoga Stretch · ✱lotus Yoga (seated, legs crossed) · breath Breath work ·
  sauna Sauna · ✱icebath Ice bath (a head in a tub, two ice cubes) · ✱watch Watch · ✱bottle Water bottle · ◆rowing
  Rowing (the rowing machine of AMS Workout Sync, E7) · ◆stopwatch Stopwatch · ◆pulse Heart rate (the Health heart with
  a pulse line in it) · ◆trophy Trophy (a cup with handles on its foot) · ◆helmet Bike helmet (side view, three vents,
  the chin strap) · ◆pump Bike pump (a floor pump: T handle, barrel, foot, hose) · ◆wetsuit Wetsuit (a full suit, arms
  out, the zip) · ◆tank Scuba tank (the bottle, its valve, the hose to a regulator) · ◆yogamat Yoga mat (rolled, the
  end lying flat) · ◆sup Paddleboard (the board upright, a single paddle beside it) · ◆lifejacket Life jacket (a vest
  with two straps).
- **Beach and summer** (`beach`): sun Summer · ✱lounger On the beach (a lounger under a parasol, a line of sand) ·
  beach Beach (the umbrella) · ✱palm Palm tree · glasses Sunglasses · ✱sunhat Sun hat · ✱suncream Sun cream ·
  ✱flipflops Flip-flops · ✱towel Towel (two folded) · ✱beachball Beach ball · ✱swimring Swim ring · ✱shell Shell
  (a scallop) · ✱surf Surfing (a curling wave) · ✱sail Sailing · ✱kite Kite · ◆icecream Ice cream (a cone, one
  scoop) · ◆bucket Sand toys (a bucket and a spade) · ◆anchor Anchor · ◆midsummer Midsummer (the midsommarstång: the
  pole with its leaves, the cross-bar, a ring at each end).
- **City, food and fun** (`city`): ✱city City · ✱restaurant Restaurant (fork, plate, knife) · food Food · coffee
  Coffee · ✱wine Wine · ✱picnic Picnic · ✱bbq Barbecue · ✱shopping Shopping · ✱party Party (two balloons) · gift
  Gift (was labelled "Party" until 0.74) · ✱music Music · camera Camera · book Reading · ◆pizza Pizza (a slice) ·
  ◆museum Museum (a pediment on four columns) · ◆cake Birthday (a cake, three candles) · ◆rings Wedding (two rings) ·
  ◆xmastree Christmas (a fir on its trunk) · ◆cinema Cinema (a clapperboard) · ◆ferriswheel Fun fair (a Ferris wheel
  on its legs).
- **Everyday** (`everyday`): laptop Work · ✱briefcase Business · ✱phone Phone · plug Electronics · ✱headphones
  Headphones · ✱wallet Money · ✱keys Keys · ✱clothes Clothes · ✱shoes Shoes · ✱laundry Laundry · toiletry Toiletries ·
  pill Medicine · firstaid First aid · heart Health · sleep Sleeping · ✱kids Kids · paw Dog · ◆toothbrush Toothbrush ·
  ◆battery Battery (the To charge card's own battery) · ◆badge Name badge (a card on its lanyard) · ◆notebook Notes (a
  ring-bound notebook) · ◆suit Suit (a collar and a tie) · ◆pram Pram.
`TemplateIconCatalog.firstFifty` lists the 50 keys of 0.46, which must never go; `TemplateIconCatalog.firstNinetyOne`
(0.92) the 91 keys of 0.78–0.91 in their picker order, which the 41 new ones never break into. `TemplateIconCatalog.icon(key)` /
`TemplateIcons.icon(key)` → the icon or nil (unknown key → nil → the cover falls back to the letter).
`TemplateIconCatalog.grouped` → the headings in order with their icons (a heading with none is left out).

**Other words for each icon (0.91, `PackingLibrary/TemplateIconKeywords.swift`).** His words (19 Oct 2026, the test
sheet of 0.90): **"Also add the possibility to search for icons, and also add alternative names so that the search is
easier to perform. But I don't know if the alternative names need to be visible, but it would be good to get more hits
when searching."** `TemplateIconCatalog.keywords: [String: [String]]`, by icon key: for every one of the 132, three or
more other words in English, Swedish and German, written lower-case as they are matched — e.g. plane: flight, fly,
airport, air travel, flyg, flyga, flygplan, flygplats, flug, flugzeug, fliegen, flughafen; car: auto, drive, road trip,
rental car, bil, hyrbil, köra, autofahrt, mietwagen, pkw; rv (Camper): motorhome, campervan, caravan, van, husbil,
husvagn, wohnmobil, wohnwagen; bike: cycling, bicycle, mtb, cykel, cykla, fahrrad, radfahren; swim: swimming, pool,
open water, simma, simning, bad, simhall, schwimmen, schwimmbad; hiking: hike, trek, trail, vandring, vandra,
fjällvandring, wandern; lounger (On the beach): beach, sunbathing, sunbed, strand, sola, solstol, liegestuhl; the rest
in the file. **The 41 of 0.92 have theirs too** (under "// 0.92" in each heading of the file) — e.g. skate: skates,
skridskor, skridsko, långfärdsskridsko, Schlittschuh; sled: sledge, toboggan, kälke, pulka, Schlitten; xcski:
längdskidor, längdåkning, Vasaloppet, Langlauf; rowing: erg, rowing machine, Concept2, rodd, roddmaskin, rudern;
midsummer: maypole, midsommar, midsommarstång, majstång, Maibaum; cottage: cabin, stuga, sommarstuga, Ferienhaus;
pram: stroller, buggy, barnvagn, Kinderwagen; ferriswheel: theme park, tivoli, Liseberg, Gröna Lund, Riesenrad.
**None widens a search he relies on** (decided by the build): "flyg" still finds the Plane alone, "båt" the Ferry and
Sailing, "strand" the four beach icons, "fahrrad" the Bike alone — so the bike helmet's German is "radhelm" and the
pump's "luftpumpe", and no "strand…" or "…båt" word was added; a word several icons share is fine where it means
each ("cykel" finds the Bike and, since 0.92, the e-scooter's "elsparkcykel", the bike pump's "cykelpump", the helmet's
"cykelhjälm"). **Decided: not visible** — he did not know whether they need to be; they are there to be found by, so the
picker stays as he liked it (a tile says only its label). They are stored nowhere (a key never changes; these words
may). Matching (`TemplateIconCatalog.matches(icon, query)`): the query as How it works reads it
(`GuideSearch.needle` — `normName`: trimmed, lower-case, runs of spaces one; curly quotes straight), found as ONE
phrase anywhere in the label or in any of the words (as the app's other searches: "sim" finds "simma", "bad" "bad",
"badring", "badminton" …), case never counting; **accents: one LEFT OUT does not count, one TYPED does** — "fjall"
finds "fjäll", "schlussel" "Schlüssel", but "båt" finds only the Ferry and Sailing, not "bath" (Swim) or "sunbathing"
(On the beach) as How it works' rule (accents never count) would: in Swedish å, ä and ö are letters of their own.
(`plain` = the needle unchanged by `folding(.diacriticInsensitive)` → `[.caseInsensitive, .diacriticInsensitive]`, else
`[.caseInsensitive]`.) The headings (Travel, Sport …) are NOT searched: "food" would otherwise bring all thirteen of
City, food and fun. `find(query)` → the icons found, in the picker's order (all for a blank query);
`grouped(matching: query)` → the headings with the icons found under each, a heading with none left out (as Find a
thing on a template leaves a heading out); the app reads it through `TemplateIcons.grouped(matching:)`.
`IconMark` is also used by `TripChecks.swift` — and (0.74) by every trip line, which shows the icon of each template
it comes from, small and violet, before its bag (`TemplateMarks`; spec 03, "A line" → "Where it comes from"); a
template showing its letter is its name's first word there.
**The loop's five step marks (0.77) are drawn in the same hand but are NOT template icons:** not in the picker, not in
`TemplateIconCatalog`, never stored on a template. They live with the loop (`Library.LoopStep.mark` in
`PackingLibrary/Loop.swift`, drawn by `StepMark` through `IconMark`): Plan — a map with a route to an X (`routeMap`, the
Map icon's outline with a dotted route); Pack — a suitcase with a tick (`packedCase`, Home's suitcase without its
straps); On site — a pin on a folded map (`pinOnMap`); Review — a magnifier over a list (`listLens`); Refine — a sprout
(`sprout`). His pick of 13 Oct 2026; paths and tests in spec 03, The loop. Their model test reuses this chapter's
drawing rules (`TemplateIconTests.drawingFault`).

### 3a. A template's colour (0.90, `PackingLibrary/TemplateColour.swift`, `TemplateColourSwatches`)

**Purpose and origin.** His words (19 Oct 2026): "I would like the ability to change the color of the table template
icons. That way, I can more easily find the templates if they have the color that I connect to a specific template."
("Table" is how the dictation heard "template"/the Templates tab; the things table shows no template icons.) Until
0.90 a template's colour was the app's stable pick only (`color` was kept from the web app but nothing here set it).

**0.91: fifteen colours, still two rows.** His words (19 Oct 2026, the test sheet of 0.90): **"Please add some more
colors, but keep them on two lines. This was very nice."** Four more — Plum, Navy, Olive, Sand — so Automatic and the
palette are 16 = two rows of eight (§4). Each sits in a gap the eleven left on the colour wheel (purple-red, a dark
blue, a yellow-green, a pale warm one); no teal, no cyan, no mint (his colour notes, "Do not use teal for anything
new"). The eleven of 0.90 keep their keys and fills — a template stores the FILL, so a changed hex would ring nothing
— and keep their places but for Violet, Indigo, Brown and Grey, which moved one to four places on to let the new ones
in among them (Red, Plum, Violet, Indigo, Navy, Olive, Sand, Brown, Grey: round the wheel, the greys last).
`TemplateColour.pickerRows` = 2 and `pickerColumns` = (palette + 1) / 2 rounded up = 8: the picker's rows come from
the model, and the model's test holds the palette to a size that fills both.

**Storage.** The template's own **`color`** field (§10) — not a new `extra` key and not a new shared-row kind (a new
kind is blanked by PackingCore, spec 02 🪤). `color` is a field of the web app's model, so it already travels with
every template: the store's `templates` record and iCloud, the backup file and Restore, a shared link (the web app's
key `c`, ≤ 9 characters — a template "Add as a new template" from a link arrives in the sender's colour; **Replace**
keeps HIS colour, because `replaceTemplate` keeps his template whole, §19) and the web app, whose cover reads the same
field. The parity check is untouched (no model.js change). Blank = **Automatic**. Stored lower-case.

**The palette** (`TemplateColour.palette`, 15 since 0.91 (11 in 0.90), in the picker's order; key → word, fill, ink):

| Key | Word | Fill | Ink (the icon on it) | Why |
|---|---|---|---|---|
| `blue` | Blue | `#0a84ff` | white | Swim's workout colour |
| `yellow` | Yellow | `#ffd60a` | `#3d3000` | Bike's |
| `green` | Green | `#30d158` | `#0b3a17` | Run's |
| `orange` | Orange | `#ff8c1a` | `#4a2300` | Strength's |
| `lavender` | Lavender | `#bf9cff` | `#2e1a5c` | Breath work's |
| `pink` | Pink | `#ff6fa8` | `#5a0f2e` | Mobility's |
| `red` | Red | `#dc3d43` | white | the To do red |
| `plum` | Plum | `#9c3d8c` | white | 0.91 — the purple-red between Red and Violet |
| `violet` | Violet | `#7c5cd6` | white | the Templates violet |
| `indigo` | Indigo | `#4f46e5` | white | the cover pick that replaced teal |
| `navy` | Navy | `#2a5194` | white | 0.91 — a dark blue, far darker than Blue (2.2 : 1 on the dark card, its icon 7.8 : 1) |
| `olive` | Olive | `#6e7b1f` | white | 0.91 — the yellow-green no colour had |
| `sand` | Sand | `#d9b98c` | `#3d2a10` | 0.91 — a pale warm one (dark words, as on Yellow) |
| `brown` | Brown | `#8b5e3c` | white | a calm earth tone |
| `slate` | Grey | `#64748b` | white | the Settings slate |

The first six are his workout colours (`docs/colours.md`, decided 28 Sep 2026) with the dark words of their pills —
"the color that I connect to a specific template". No teal. Every ink reads on its fill at 3.6 : 1 or better (Swim's
blue with white is the lowest, 3.65); every fill made readable as a mark (`readableHex`, text mode) reads at 4.5 : 1
or better on the light card and on the dark one. A fill is one shade for day and night, as the section colours are.
Every two colours are at least ΔE 20 apart (CIE 1976, D65; Violet–Indigo 23.7 is the closest pair, the 0.91 four are
31 or more from all) and none has a teal or cyan hue (160°–200° at saturation above 0.2) — both in the model's test.

**Where the colour shows** — everywhere a template's icon is drawn (found by grepping `Cover(` and `IconMark` with a
template icon):
- `Cover` — the Templates tab's cards (34), the cover on the template's page (`CoverDoor`, 40), the picker's own
  header (40) and its swatches (34): fill and ink as above.
- The icon picker's ringed tile (Suggested, Letter or an icon): filled with the cover colour, its mark and label in
  the cover's ink (white until 0.90 — unreadable on yellow).
- `TemplateMarks` (spec 03) — a trip line's "from" icons, Before you go's To do lines and Before you start's To prepare
  lines: a template he gave a colour draws its mark in **`Library.markColour(list, dark:)`** = `readableHex(color,
  dark:)` (his hue, darkened on a light screen, lightened on a dark one, until it reads as text does); a template
  with Automatic keeps the Templates violet it had (0.74). The "+N" stays violet.
- (0.91) **The template pills on Create new trip and in Trip settings** (spec 03, Create new trip item 5): a template
  he gave a colour has it on its pill — **picked: filled with it, the words in its ink; not picked: outlined in it
  (1.8 pt), ink words on `Theme.bg`** — exactly the look the workout pills have had since 0.40, so the lit/unlit
  difference is the one he knows, and the pill keeps its size (no icon is added: the pills carry words, every pill on
  both screens is a word pill, and an icon on some would make the rows uneven and wrap sooner). Fill and words =
  **`Library.pillColour(list)`** (below), drawn by the app's `TemplateTone.of(list, workout:)`. **His colour wins over
  a workout's colour** — it is the colour that template's cover and marks already wear; a workout with Automatic
  keeps its workout colour (`WorkoutTone`, by name), and its Context name follows the pill (spec 03 item 6).
  **Automatic templates look as before** — unlit grey line, violet when picked: the Automatic colour is the app's
  stable pick, not his, and painting every pill with it would turn the rows into colours he never chose (an
  Automatic orange or green would also look like a workout's). His words, 19 Oct 2026: "Yes, show the template colours
  on the Create new trip pills too — put it in 0.91." (Open questions 34, answered.) Not changed: the template pills
  elsewhere — a thing's On these templates, the review's "Put it on which template" — which stay in their tint.

**Model.** `chosenColour(templateId:)` → the stored hex or nil. `setTemplateColour(id:hex:)` → nil/blank = Automatic;
false for an unknown template or a value that is not a hex colour (nothing changes); sets `updatedAt`.
`TemplateColour.of(hex:)` (capitals ignored). `Library.automaticColourKey = "auto"`. A colour from the web app that is
none of the palette is kept, drawn with white and rings no swatch.
**`Library.pillColour(list)`** (0.91) → `(fill, ink)` or nil: nil when `color` is no hex colour (Automatic); a palette
colour (capitals ignored) → its hex and its own `ink` (the cover's — dark on the six light ones); any other colour (from
the web app) → that colour lower-cased and **white or `Library.pillDarkInk` `#16232a`** (`Theme.ink` by day),
whichever has the higher contrast ratio on it (ties → white) — a pill carries words, so unlike a cover's icon (always
white on a web colour) they must read: `#f59e0b` → dark, `#123456` → white.

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
- Model (0.74): `testOnTheBeachSuggestsTheLoungerUnderItsParasol` ("On the beach", "On the Beach", "Beach", "Beach
  week", "Strand", "Sunbathing" → `lounger`; its label is "On the beach") — seen red with the beach rule planted
  back on the umbrella ("Optional("beach") is not equal to Optional("lounger") - On the beach");
  `testTheNewIconsAreSuggestedByTheirWords` (63 names: each ✱ rule in English and Swedish, motorbike/sailing/
  triathlon/yoga/kite ordering, "City walk" → city, "Fjällvandring" → hiking, and six names that still suggest
  nothing); `testEveryIconHasADrawingALabelAndItsOwnKey` (90 icons, keys and labels unique, the 50 keys of 0.46
  all there, no key "letter" or blank, no emoji in a label, every path starts with M, uses only M L H V C S Q A Z
  with their numbers and arc flags 0/1 and keeps every point inside 1…23 of the 24 box, the headings hold every
  icon once in `all`'s order) — seen red with a planted duplicate key and a `T` command ("a key used twice:
  ["shell"]", "cannot draw 'T'"); `testEverySuggestionIsAnIconThatExists` (67 probe names, each suggestion has a
  drawing, at least 50 different ones reached; "Weekend" added in 0.78).
- Model (0.78): `testAShortTripSuggestsTheWeekendBagNotTheTravelSuitcase` (the catalog has `weekendbag` "Weekend bag"
  under Travel right after `suitcase`, its key once, a drawing of its own — no two icons share one — that the app can
  draw; "Short travel kit" (base), "Short trip", "Short", "Weekend", "Weekend away" (base), "Small core" (base), "Kort
  resa", "Helg", "Helgresa", "Weekendresa" → `weekendbag`; "Travel" (base), "Common base" (base), "Resa" → `suitcase`;
  "Shorts" → nil; "Summer weekend" → `sun`; "Weekend hike" → `hiking`) — seen red with rule 45a planted out:
  `("Optional("suitcase")") is not equal to ("Optional("weekendbag")") - Short travel kit` (and "Kort resa");
  `testEveryIconHasADrawingALabelAndItsOwnKey` counts 91 (132 since 0.92). His own template's icon is his to pick in
  the picker — the app's Suggested offers the weekend bag; his data is not changed.
- Model (0.92): `testTheFortyOneIconsOf092CloseTheirHeadingsAndTheOldOnesKeepTheirPlaces` (`firstNinetyOne` is 91 keys
  and `all` holds them in that order; the 41 new keys with their labels and headings, none an old key; 91 + 41 = 132;
  under each heading the old ones first in their order, then the new ones in the catalog's order; no two icons share a
  drawing; each new drawing passes `drawingFault`); `testTheNewIconsOf092OnlyReachANameThatSuggestedNothing` (28 names
  → their new icon — Rowing, Rodd, Erg, Ice skating, Skridskor, Långfärdsskridsko, Pulka, Sledding, Cross-country,
  Langlauf, Wetsuit, SUP, Race day, Tävling, Svampplockning, Mushroom picking, Stuga, Cottage, Utomlands, Abroad,
  Museum, Cinema, Bio, Tivoli, Liseberg, Gröna Lund, Barnvagn, Stroller; and 17 that keep what they had: Längdskidor
  and Cross-country skiing → ski, Sommarstuga, Midsommar, Midsummer → sun, Wedding → party, Christmas and Birthday →
  gift, Bike race → bike, Paddleboard → kayak, Ice bath → icebath, Weekend cabin → weekendbag, Electronics, Snowshoe,
  Brunch, Carry-on things, Shorts, Program and Brain training → nil); `TemplateIconSearchTests
  .testTheNewIconsAreFoundByTheirOtherNamesAndNoOldSearchGrows` (50 words → their new icon, 43 of them Swedish:
  skridskor, pulka, längdskidor, vasaloppet, sovsäck, kikare, termos, vantar, regnjacka, svamp, stuga, utomlands,
  nackkudde, elsparkcykel, roddmaskin, erg, stoppur, puls, tävling, cykelhjälm, cykelpump, våtdräkt, dykflaska,
  yogamatta, sup, flytväst, glass, hink, skärgård, midsommar, pizzeria, utställning, tårta, bröllop, julgran, bio,
  tivoli, tandborste, powerbank, namnbricka, anteckningar, slips, barnvagn; Schlittschuh, Riesenrad, Kinderwagen,
  Neoprenanzug, rowing machine, heart rate, maypole, lanyard; "skridskor", "midsommar", "barnvagn" each find their
  icon ALONE; "flyg" → the plane alone, "båt" → ferry and sail, "fahrrad" → the bike alone, "strand" → lounger, beach,
  towel, beachball). The 0.91 coverage test holds the 41 to its rules (≥ 3 words, none twice, written as matched,
  each finding its icon). Seen RED with faults planted: "skridskor" taken out of the skate's words — `XCTAssertTrue
  failed - 'skridskor' does not find skate: []`; a "strandhink" added to the sand toys — `("["lounger", "beach",
  "towel", "beachball", "bucket"]") is not equal to ("["lounger", "beach", "towel", "beachball"]") - strand`; the
  Rowing moved to the head of Sport — `("["bottle", "stopwatch", …]") is not equal to …` and `("["rowing", "run", "bike",
  …]") is not equal to …` (an old icon moved); the rowing rule taken out — `("nil") is not equal to
  ("Optional("rowing")") - Rowing` (and Rodd, Erg).
- **Not covered:** an unknown stored key.
- Model (0.91, `TemplateIconSearchTests`): `testHisWordsFindTheIconInEnglishSwedishAndGerman` (48 words → their
  icons: flyg/Flug/airport/flight → plane, bil/Auto → car, husbil/Wohnmobil/camper → rv, cykel/Fahrrad/cycling → bike,
  simma/schwimmen/pool/bad → swim, vandring/wandern/trek → hiking, strand → lounger and beach, tåg, Zug, färja, tält,
  Zelt, skidor, löpning, styrka, gym, bastu, isbad, solkräm, Sonnencreme, kaffe, fika, hund, dog, barn, laddare,
  charger, medicin, tvätt, jobb, work, helg, weekend; "FLYG" and "  flyg  " as "flyg"; "flyg" finds the plane ALONE;
  "fjall" → mountain, "schlussel" → keys; "båt" and "Båt" → exactly ferry and sail; labels still found ("on the beach",
  "Racket"); "zzz" → nothing; "" and spaces → all 91 (132 since 0.92) in order; "food" does not bring the Camera);
  `testTheResultsKeepTheirHeadingsInThePickersOrder` ("strand" → Beach and summer only: lounger, beach, towel,
  beachball; "båt" → Travel then Beach and summer: ferry, sail; "zzz" → no heading; "" → every heading);
  `testEveryIconHasItsOtherWordsAndNoneIsLost` (every list belongs to an icon, every icon has ≥ 3 words, none twice,
  none blank, each written as it is matched (`normName`), no emoji, and each word finds its own icon). Seen red with
  the other words planted out of the search: `XCTAssertTrue failed - 'flyg' does not find plane: []`, `… - backpack:
  its word 'daypack' does not find it`; and with accents typed planted not to count: `XCTAssertEqual failed:
  ("["ferry", "swim", "icebath", "lounger", "sail"]") is not equal to ("["ferry", "sail"]") - båt found a bath or
  sunbathing`.
- Model (0.90, `TemplateColourTests`): `testThePaletteReadsDayAndNightAndHasNoTeal` (≥ 10 colours, keys and hexes
  unique, none keyed "auto", the six workout colours first, Bike's ink `#3d3000`, every ink ≥ 3.5 : 1 on its fill,
  every mark ≥ 4.5 : 1 on the light and the dark card, no teal or cyan) — seen red with Bike's ink planted as white:
  `("Optional("#ffffff")") is not equal to ("Optional("#3d3000")") - Bike's yellow carries dark words` and
  `("1.4117637713407472") is less than ("3.5") - yellow: its icon does not read on it`;
  `testHisColourIsKeptThroughEditsRecordsBackupsAndAShareAndAutomaticGivesTheOldOneBack` (blue → cover, resolved
  templates and the trip-line mark wear it; yellow → dark ink; survives `addToTemplate`, `renameTemplate`,
  `setTemplateIcon`, `setTemplateArea`; the stored records, `backupFile`, the backup's bytes as Restore reads them, a
  shared link imported by someone else; Replace keeps his; nil → the automatic colour again and white ink, also in the
  records; "blue" and an unknown id refused) — seen red with `setTemplateColour` planted not to store: `("#64748b") is
  not equal to ("#0a84ff") - the cover does not wear his colour`, `… - the stored records lost the colour`, `… - a
  backup lost the colour`, `… - Restore lost the colour`; `testAWebAppColourIsKeptAsItIs` (`#123456` kept, white ink).
- UI (0.90): `testATemplatesColourIsChosenAndAutomaticGivesItsOwnBack` — see §4.
- Model (0.91): `TemplateColourTests.testAPillWearsHisColourWithWordsThatRead` (Automatic → nil; yellow chosen → the
  template as `activityChoices` offers it gives `#ffd60a` / `#3d3000`; every palette colour stored upper-case → its own
  hex and ink; web colours `#f5e6a0` and `#f59e0b` → `pillDarkInk`, `#123456` → white, each ≥ 4.5 : 1; Automatic again
  → nil) — seen red with the palette's ink planted out (white for every palette colour): `XCTAssertEqual failed:
  ("#ffffff") is not equal to ("#3d3000") - white words on Bike's yellow` (and the five other light colours, "… the
  pill's words are not the cover's ink").
- UI (0.91): `testATemplatesColourIsWornByItsPillOnCreateNewTrip` — a pill says its colour as its accessibility
  **value**, DEBUG only (`#if DEBUG`; the release build keeps the old value: a drawing's key or nothing), read from the
  very tone it is drawn with: `"<fill>/<ink>"`, e.g. `#ffd60a/#3d3000`; a pill with a drawing (Season) still says its
  key. The sample's Hiking (`trip-activity-0`, Automatic) says "" and Swim (`trip-activity-1`) `#0a84ff/#ffffff`
  (its workout blue); on the iPhone, Swim ticked, its Context name (`trip-context-1-name`, whose DEBUG-only value on
  the iPhone is the colour it is written in — not on the Mac, which reports a text's words as its value) is bluish.
  Hiking given Yellow and Swim Red in the picker (`template-colour-yellow`, `-red`): Hiking's pill says
  `#ffd60a/#3d3000`, unticked and ticked; Swim's `#dc3d43/#ffffff` (his red over the workout blue) and, on the iPhone,
  its Context name turns reddish (more red than green and blue, day and night); in the sample trip's Trip settings
  `tripset-activity-0` is ticked and says `#ffd60a/#3d3000`, `tripset-activity-1` `#dc3d43/#ffffff`. Pictures
  `pills091-create`, `pills091-tripset`. Seen red with `TemplateTone.of` planted to skip his colour: `XCTAssertTrue
  failed - Hiking's pill does not wear its yellow: ''`. Green on the iPhone 17 Pro simulator (iOS 26.5) day and
  night, with its neighbours (the 0.90 colour test, Context, Trip settings, Other Templates, Always packed alone,
  laundry, the editors' headings — 12 tests), and on GitHub's Mac (the probe workflow, 19 Oct 2026: green day and
  night with the 0.90 colour test, Context, Trip settings and the Mac's arrow keys on template pills).
- Model (0.91, `TemplateColourTests`): `testMoreColoursStillFillTwoRowsAndTheOldOnesStayAsTheyWere` (15 colours,
  `pickerRows` 2, `pickerColumns` 8, two FULL rows; the eleven of 0.90 with their keys and fills; plum, navy, olive,
  sand there; every pair ΔE ≥ 20; no teal or cyan hue) — seen red with Sand left out, Navy planted teal and Blue's fill
  changed: `("14") is not equal to ("15") - Automatic and fifteen: two rows of eight`, `("1") is not equal to ("0") - a
  short second row`, `XCTAssertNotNil failed - no sand in the palette`, `XCTAssertFalse failed - navy is teal or cyan
  (hue 184)`, `("Optional("#0a7aff")") is not equal to ("Optional("#0a84ff")") - blue changed or went: a stored colour
  would ring nothing`.
- UI (0.91): `testTheColoursSitInTwoRowsAndANewOneApplies` — see §4.

---

## 4. The icon picker (`IconPickerScreen`)

### How it is reached and left
Tap the cover on a template's page (`template-cover`). Left by: "Cancel" (`icon-cancel`; Escape too, 0.62 — on the
Mac, while the icon search holds words, the first Escape empties it and the second closes, 0.91), by any
pick — an icon or (0.90) a colour; each pick saves and closes — or a swipe down on the iPhone.

### What is on screen
- Top row (padding 16): the template's cover (40), its name (20 heavy ink, 1 line, shrinks to 80 %), spacer,
  "Cancel" (outlined `HeaderButtonStyle`, muted tint).
- Scroll (side 16, bottom 24), spacing 10:
  - (0.90) **"Colour"** (`SectionTitle`, id `template-colour-title`), then `TemplateColourSwatches`: **Automatic** and
    the palette's 15 (§3a) in exactly **two** plain rows of **`TemplateColour.pickerColumns` = 8** (16 swatches = two
    full rows; a short row would be filled with empty cells, min 60 high) — his "keep them on two lines" (0.91; until
    then the eleven in two rows of 6, 6 apart, covers 34, min height 64). The swatches stand **edge to edge** (row
    spacing 0), rows 6 apart, so each swatch's whole share of the row takes the tap: 370 / 8 = 46 points on a 402-point
    iPhone (iPhone 17 Pro) — Apple's 44 or more; on the Mac (sheet ≥ 520) about 61. Each swatch: the template's OWN cover
    drawn in that colour at **32** (its icon or letter in that colour's ink — a preview of the Templates tab) with 3 pt
    of air, and under it the colour's word (Caption 2, 1 line, shrinks to 70 %, 1 pt of air each side; muted, or bold
    ink when in force — "Automatic" and "Lavender" shrink a little at eight to a row); min height 60, full width share.
    Automatic shows the colour the app picks for this template. The swatch in force has a 2-pt `Theme.ink` ring round
    its square (radius 32 × 0.28 + 3) and the trait `isSelected`: Automatic when no colour is stored, else the palette
    colour stored (a web-app colour outside the palette rings none). Ids `template-colour-auto`,
    `template-colour-<key>` — deliberately not `icon-…`, which the icon count (132 since 0.92) reads; accessibility label = the word.
  - (0.90) **"Icon"** (`SectionTitle`, id `template-icon-title`) over the rest — until 0.90 the tiles had no heading.
  - (0.91) **Find an icon** — the app's search-field look (as Find a thing on a template and How it works' search):
    `TextField("Find an icon")`, Body ink, `Metrics.compact` tall, side padding 12, card fill, 1-pt line ring, radius
    10, the shared ✕ (`clearButton`, id `iconsearch`, the ✕ `iconsearch-clear` — ids deliberately not `icon-…`, which
    the icon count reads — 132 since 0.92). No autocorrection ("flyg" or "cykel" typed on an English keyboard must stay as typed); on
    the iPhone no capitals and the keyboard's key says Search. On the Mac ⌘F puts the cursor in it (a hidden button
    with the shortcut, as How it works, 0.90) and Escape — which a text field keeps for itself — empties it, then
    closes the picker as Cancel does (`onExitCommand`). On every key press the icons below are
    `TemplateIcons.grouped(matching: query)` (§3, Other words): only those found, each under its own heading, a
    heading with none left out. **While words are typed** (spaces alone are no search) Suggested and Letter step aside
    (they are no drawn icons), and when nothing is found the line **"No icon is called that."** (Callout muted, 8 above,
    wraps; `iconsearch-none`) stands where the icons were. The ✕ (or the words deleted) gives every heading, every icon,
    Suggested and Letter back. A found icon is chosen as any other (it saves and closes); the words are not kept.
  - Two tiles side by side (not while searching, 0.91): **"Suggested"** (id `icon-suggested`; shows the suggested icon at 30, or the letter
    (`coverLetter`) 22 heavy when there is no suggestion; selected when no choice is stored) and **"Letter"** (id
    `icon-letter`; the letter 22 heavy; selected when the stored choice is "letter").
  - Since 0.74 one `SectionTitle` per heading of `TemplateIcons.grouped` — "Travel", "Outdoors", "Sport", "Beach and
    summer", "City, food and fun", "Everyday" (`.headline`, ink, 12 above; id `icon-group-<group>`: `travel`,
    `outdoors`, `sport`, `beach`, `city`, `everyday`). Until 0.74 one title, "All icons", over all 50.
  - Under each heading its icons in rows of **5** (plain `HStack` rows, not a lazy grid: "the Mac builds only what is
    on screen"). A heading's last row, when short, is filled with empty cells (`Color.clear`, full width share, min
    74 high) so its tiles keep the width of the others. Each tile: icon at 30 + its label; id `icon-<key>`; selected
    when a choice is stored and the icon in force is this key.
- Tile look: mark 32 high; label 12 bold, 1 line, shrinks to 70 %; min height 74, full width share; selected =
  filled with the template's own colour (`coverColour`), mark and label in the cover's ink (`coverInk` — white until
  0.90, dark on the light palette colours since), 2-pt stroke in that colour, trait
  `isSelected`; not selected = `Theme.card`, ink mark, muted label, 1-pt `Theme.line` stroke.
- Container id `icon-picker` (`children: .contain`). Mac: min 520 × 620.

### Behaviour
- A swatch → `model.change { setTemplateColour(id:, hex:) }` then dismiss; Automatic = nil (blanks `color`). The
  colour and the icon are independent: one does not change the other.
- `pick(key)` → `model.change { setTemplateIcon(id:, key:) }` then dismiss. Suggested = nil (removes the key),
  Letter = "letter", an icon = its key. Picking the very icon that is suggested **stores** it, so it no longer
  follows later renames.
- The icon search (0.91) filters what is shown, nothing more: it changes no choice, and a choice made from its results
  is the same `pick(key)`. The colour swatches above it stay as they are while it is used.
- When the stored key is not one of the 91 (e.g. from a newer build), no tile is ringed and the cover shows the
  letter. A build before 0.74 that meets a 0.74 key (a template's icon synced from a newer device) shows the letter
  the same way; its own 50 keys are all still drawn by 0.74.

### Tests
UI `testATemplatesIconIsSuggestedAndCanBeChosen`: Hiking's cover value "hiking"; Suggested is selected; picking
`icon-tent` closes the picker and the value becomes "tent"; it survives closing/reopening; Letter → "letter";
Suggested → "hiking".

UI `testThePickerHoldsNinetyIconsAndKeepsANewOne` (0.74; the name kept): Hiking's picker has exactly 91 buttons (90
until 0.78) whose id starts
`icon-` apart from `icon-suggested`, `icon-letter` and `icon-cancel`; the six `icon-group-<group>` headings exist;
`icon-lounger`, `icon-palm`, `icon-hotel`, `icon-triathlon`, `icon-kids` exist; picking `icon-lounger` closes the
picker and the cover's value becomes "lounger"; it survives closing and reopening the template; reopened, the picker
rings `icon-lounger` (`isSelected`); Cancel closes it. `testATemplatesIconIsSuggestedAndCanBeChosen` (0.78) also finds
`icon-weekendbag` beside `icon-suitcase` when the picker opens.

UI `testATemplatesColourIsChosenAndAutomaticGivesItsOwnBack` (0.90): the Templates tab's Hiking card
(`template-row-1`) says its cover's colour as its accessibility **value** — a DEBUG-only value (`#if DEBUG`, "the
tests' only way to see the colour its cover is drawn in"; the release build has none) read from `Cover.fill`, the very
function the cover is filled by — a hex, not Blue; the picker shows `template-colour-auto` ringed and 12
`template-colour-` buttons (picture `tmpl-colours-picker`); `template-colour-blue` closes the picker and the card says
`#0a84ff`; reopened, Blue is ringed and Automatic is not; `template-colour-auto` gives back the colour the card said
first (16 `template-colour-` buttons since 0.91 — "Automatic and fifteen colours"). Seen red three ways: `Cover.fill` planted to ignore the chosen colour — `Hiking's cover is not blue:
'#22c55e'`; the Automatic swatch planted to keep the chosen colour — `Automatic did not give back #f97316:
'#0a84ff'` (the automatic colour differs per launch: the sample's ids are fresh each time). Day and night on the
iPhone 17 Pro simulator (iOS 26.5), and on the Mac (the probe workflow).

UI `testTheColoursSitInTwoRowsAndANewOneApplies` (0.91): Hiking's picker has 16 `template-colour-` buttons; grouped by
where they stand (a swatch more than 8 points lower starts a new row) they are exactly two rows of 8, Automatic first;
none runs off the window; on the iPhone each is 44 points wide or more; `template-colour-navy` closes the picker and the
Hiking card says `#2a5194`; reopened, Navy is ringed (pictures `tmpl91-colours-picker`, `tmpl91-colours-navy`, day and
night). Seen RED with the rows planted back to six: `XCTAssertEqual failed: ("[6, 6, 4]") is not equal to ("[8, 8]") -
the colours are not on two lines of eight`.

UI `testTheIconSearchFindsAnIconByItsOtherNames` (0.91): Hiking's picker has the field `iconsearch` and 91 tiles (132
since 0.92);
"flyg" leaves exactly one tile, `icon-plane`, under `icon-group-travel`, no `icon-group-sport`, no `icon-suggested`,
no nothing line (picture `tmpl91-iconsearch-flyg`); "zzz" shows `iconsearch-none` and no tile (picture
`tmpl91-iconsearch-none`); `iconsearch-clear` brings every tile (91; 132 since 0.92) and Suggested back, the line gone, the field empty;
"fahrrad" leaves the Bike alone, a tap takes it (cover value "bike"). On the Mac: reopened, ⌘F and "flyg" leave one
tile, Escape brings all of them back with the picker still open, a second Escape closes it. Seen RED with the picker
planted to search the labels only: `XCTAssertTrue failed - flyg shows 0 icons, not the Plane alone`.

UI `testTheNewIconsCloseTheirHeadingsAndAreFoundInSwedish` (0.92): Hiking's picker holds 132 tiles; read in ONE
accessibility snapshot of `icon-picker` (132 element queries are slow on GitHub's machines), `icon-skate` stands two
after `icon-fishing` (Cross-country between), `icon-rowing` right after `icon-bottle`, and `icon-pram` is the last
tile; `icon-cottage`, `icon-xcski`, `icon-midsummer`, `icon-ferriswheel`, `icon-toothbrush` are there (pictures
`icons92-outdoors`, `icons92-sport`, `icons92-everyday`, scrolled to the new tiles); "skridskor" (Swedish, typed in
`iconsearch`) leaves exactly one tile, `icon-skate`, under `icon-group-outdoors`, no `icon-group-travel` (picture
`icons92-search-skridskor`); a tap takes it (cover value "skate"), kept after Done and reopening Hiking. The count of
`testThePickerHoldsNinetyIconsAndKeepsANewOne` (name kept for its known timing) is 132.
---

## 5. A new template (`NewList`)

### Purpose and origin
"Make a new list of his own." Shipped 0.15 (25 Sep 2026); the area question is his test H.6; reworded to
"activity area" in 0.56. The web app asks only a name (and leaves the list in "Other"); here the area is asked at
the same time "because it is one tap". It **refuses a name he already has** because the health check reads two
templates sharing a name as "two libraries have met on one account" (31 August 2026).

### How it is reached and left
"+ New" on the Templates tab (`templates-new`) — and since 0.90 "+ New template…" on a thing's page
(`thing-lists-new`, spec 05; `NewTemplateDoor`), where the same sheet asks the same questions with two differences:
its button says **"Add the template"** (`makeWords`) and a line under it (`madeWhen`, footnote muted, id
`newlist-made-when`) says "It is made, with this thing on it, when you save the thing."; the name is checked against
his templates AND the ones made on that page so far. Left by "Cancel" (`newlist-cancel`; Escape too, 0.62 — nothing is
made, a typed name included), swipe down (iPhone), or
"Make the template" succeeding (closes and the new template's page opens; from a thing's page: closes, and the new
template is a lit pill there).

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
  - One row per area of HIS, in his order under his words (0.89, `Library.areaWords`; until 0.89 the three
    GROUPS): "GA · Goal Activity", "WET · Workout, Exercise & Training", "OE · Other Events" as shipped, then
    "No activity area". Rows are full-width buttons, min height 44, a hairline under each; the chosen one is 16
    heavy violet with trait `isSelected`, the others 16 medium ink. ids `newlist-area-<code>` for a built-in
    (`-GA`, `-WET`, `-OE`), `newlist-area-own-<n>` for one he made (n = its place in his list), `-none`.
    Default: "No activity area".
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
  yet."; else clears needs, calls `made(Library.filed(newList(name: jsTrim(name)), in: chosen))` and dismisses
  (0.89: a built-in in `group`, one of his in `extra["area"]`). The new list: role "", no items, no sections, no
  cover, fresh id, `createdAt`/`updatedAt` now; `coerceList` keeps the group only if it is a GROUP id.
- The caller saves it (`saveTemplate`) and opens it.
- The needs line is the shared `needsLine`: it clears as soon as the name changes (until the spec pass it stayed
  until the next press).
- There is no way here (or anywhere in this app) to make a `base` or `transport` template, or to set an emoji or
  default bag. Its colour is Automatic; it is chosen afterwards in the icon picker (§3a, 0.90).

### Tests
UI `testANewTemplateIsMadeFromAThingsPageWithTheThingOnIt` (0.90, spec 05) opens this sheet from a thing's page and
finds `newlist-made-when`. UI `testHeMakesAListOfHisOwn` (title "A new template"; Make enabled; empty press says "…name…" and the line goes
once a name is typed; "Hiking" shows `newlist-taken` and a press says "…do not have…"; "Mushroom picking" + GA →
page opens; summary changes; the
"Other Templates" area does not appear); `testANewTemplateAsksForItsActivityArea` (question text, "No activity
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
`ReviewHealth.swift`). Only on an activity template (role ""), on both devices, above the Activity area field, side
16, bottom 6, left-aligned: a drop-down (`DropDown`, heading `.beside`, violet) — "Counts as" (15 semibold muted,
id `template-counts-as-title`) then the field (id `template-counts-as`) showing the kind it meets now: his pick
(`extra["countsAs"]`), else the one its NAME meets (`WorkoutKind.named`, compared as `WorkoutTone` compares:
`normName`, no white space — "Swim", "Breath work", "Mobility & Breath work", "Diving and Freediving"…), else
"Nothing". Its list (`template-counts-as-list`): rows `template-counts-as-0…8` = Swim, Bike, Run, Strength,
Mobility & breath, Hiking, Golf, Climbing, Diving, and `template-counts-as-9` = Nothing. A choice →
`setCountsAs(templateId:to:)` (stored even when it is what the name says; "none" = meets nothing whatever its name).
The common base and transport templates have no field and never meet a workout.

**While the iPhone's keyboard is up** (`keyboardUp`, from the keyboard's show/hide notices; iPhone only) Counts as and
Activity area and the Delete row are not shown, so the list keeps room for the field being typed in — a reminder's
Add field at the list's top was hidden under them once Counts as joined the foot (`testATemplateKeepsItsReminders`,
the 0.68–0.71 merge). The Delete question, once open, stays.

**Activity area** (0.89, `TemplateAreaField` in `AreasScreen.swift`; until 0.89 a text button "Activity area:
<code>" beside Delete that opened a card of five rows). On an activity template (role "") and, since 0.71, on an
always-packed one (role "base"), on both devices, under Counts as, side 16, bottom 6, left-aligned: a drop-down
(`DropDown`, heading `.beside`, violet) — "Activity area" (15 semibold muted, id `template-area-title`) then the
field (id `template-area`; its value the words shown) showing where it is: "Always packed", his area's words
(`Library.areaWords`: "GA · Goal Activity", "Mountains"…) or "No activity area" (grey, the drop-down's "nothing
said" look). Its list (`template-area-list`): row 0 **Always packed**, then HIS areas in his order, then **No
activity area** (with the three as shipped: 1 GA, 2 WET, 3 OE, 4 No activity area; ids `template-area-<n>`), the
current one ticked; at its foot **"A new area"** (`template-area-new`) + Add (`template-area-add`; nothing typed →
"Type the new area's name first.", `template-area-add-needs`) — made at the end of his list and the template filed
in it at once (one he has is chosen; a reserved heading name is refused under the field, `template-area-needs`;
§1a). A choice files it at once (`setTemplateArea`, §14). Renaming, moving and removing areas is the Activity areas
page's (§1a), not this list's. The spec pass (5 Oct 2026): New asked for the area and nothing could put a wrong
answer right. 0.71 (8 Oct 2026): his always-packed template had grown too big for a weekend; the agreed way out is
a small always-packed core and the big one a template he ticks for longer trips — so a template moves into and out
of Always packed here. Transport templates still have no field. (The card's footnote "Always packed comes on every
full trip by itself…" went with the card; How it works says it.)
- **"Make a small core from this…"** (0.71, `SmallCoreDoor`, id `template-smallcore`): a line of its own above the
  Delete row (0.89; above the area/Delete row until then) (15 semibold violet plain text, min height 28), only on an always-packed template with more than
  20 things (`offersSmallCore`, `SMALL_CORE_FROM` = 20; reminders do not count), and only where the page was opened
  from the Templates tab (Search opens it without). Opens the small core sheet (§14b). The sheet hangs on the
  page's header, not on the door: once made, the big template is no longer always packed and the door goes.
- **Delete** (side 16, bottom 8; a row of its own since 0.89), at the right, when not asking: `SmallDeleteButton` "Delete template" (13 semibold red text in a red 60 %
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
  row); `testATemplateMovesToAnotherActivityArea` (Hiking's field reads "GA · Goal Activity", row 1 ticked; row 3 →
  "OE · Other Events", and on the tab OE appears and GA goes — a drop-down since 0.89); `testATemplateMovesOutOfAndIntoAlwaysPacked`
  (0.71: Common base's field reads "Always packed", row 0 ticked and not row 4; row 4 → "No activity area": under
  Other Templates, Always Packed gone, offered as `trip-activity-2` on Create new trip; row 0 back: no longer
  offered); 0.89 `testHeMakesAnActivityAreaAndFilesATemplateInIt` (his new area is row 1 of Hiking's list — §1a); `testATemplateCountsAsWhatHeLinksItTo` (0.70,
  `-uiTestingHealth`: the Common base has no `template-counts-as`; Bike reads "Bike" by its name, `template-counts-as-9`
  → "Nothing", kept after Done and reopening; on the iPhone the review then has no "No bike" row and "Use these"
  leaves the Bike helmet alone); Arrange — §6a.
- Model: `TemplateEditingTests`, `EditListsTests`, `RowEditingTests` (§13–14), `ArrangeTests` (§13a);
  `AppleHealthReviewTests.testCountsAsIsHisLinkAndTravelsWithTheTemplate` (kept through edits, the records and a
  backup; "none"; back to the name; nonsense refused), `testATemplateMeetsAWorkoutByItsName`;
  `TemplateRowsTests.testTypingAThingAlreadyOnTheTemplateDoesNotAddItTwice`,
  `testOnlyOnSaysWhatATripReadsOnThisTemplate`; `TemplateFacesTests.testATemplateMovesToAnotherActivityArea`.
- **Not covered:** the device-wide grouping memory; When's colours; Delete's "Keep it"; a rename discarded by Done;
  Return in the name field; "A new area" at the foot of the Activity area list (its model is pinned:
  `ActivityAreasTests.testANewAreaHoldsATemplateInHisOrder`).

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
  first with its three things, then Lights; the page reads Clothes first. On the iPhone the drag is made once more
  if the first moved NOTHING — `dragAgainIfUntouched`, since 0.70: GitHub's busy iPhone runner lifted the row
  without it following the finger; a drag to the wrong place, or one that never moves, still fails); `testAHeadingIsRenamed` (the field holds
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
  **Changed inside their lists (0.69)** — his ask of 7 Oct 2026, "work on all the drop-downs so that they can be
  edited, changed, added, and deleted from within the drop-downs": Bag (his own bags), When (his steps) and Section
  (this template's sections) take the tools a thing's page has (spec 05, "His lists inside their drop-downs" and
  item 6a): a pen, ↑ ↓ and Remove on each of their rows (`row-bag-<n>-rename` …; none on "Same as …" or "No
  section"), Remove asking first or, while the entry is in use, saying what uses it (a bag in use: Open the bag,
  `row-bag-<n>-open`); "A new bag" / "A new step" at the foot as "A new section" is. All of it is held until Save
  (`choiceLists`, `sectionEdits`) and written then — the sections (`applySectionEdits`), the lists
  (`applyPageChoices`), the row with its Bag and When followed to their new names (`choiceValue`), the removals last.
  Cancel leaves them as they were. The row's own stored bag counts as a use of it. No Mac keys here (the page has
  none). UI `testWhenIsChangedInsideItsListOnATemplatesRow`.
  5. **"How many"** (band, `row-heading-qty`): field `row-qty`; its grey words (placeholder) "Same as the thing:
     <the thing's own how-many>" when the thing has one, else "e.g. 2, or 2 pairs".
  6. **"Note"** (band, `row-heading-note`): field `row-note`; placeholder "Same as the thing: <the first line of
     the thing's note>" when it has one, else "e.g. with the red filter" — so a blank field never looks as if the
     thing's note had gone.
  7. "Blank means the same as the thing itself, so a change to the thing still reaches this template." — 14 muted.
  8. **"Only on some trips"** (band, `row-heading-some`) — **since 0.73 each kind FOLLOWS the thing's own answer
     (set on the thing's page, spec 05 item 7) unless this row sets its own** (spec 07 part 14): under each kind's
     pills `row-<kind>-from` says "Same as the thing: Winter" (lit pills drawn "borrowed": outlined, not filled) or
     "Own choice on this template. The thing says: Winter." with **Same as the thing** (`row-<kind>-same`) to go
     back; a tap on a pill makes the kind this row's own, starting from what was shown (`OnlySomeTripsPills`,
     `App/Sources/Screens/OnlySomeTrips.swift`, shared with the thing's page). Then "Each kind follows the thing's own
     answer until you change it here; then it is this template's own. Nothing lit: it comes on every trip." (Subheadline
     muted, pulled 6 pt up; until 0.73 "Leave these off and it always comes along. Pick one or more and it comes only on
     trips that match — on this template."), then
     four pill rows with a smaller heading each (`HeadingTitle`, 20 heavy violet after a 4 × 18 violet capsule),
     several choices each; this block's parts are 14 pt apart:
     - "Season" (`row-seasons-title`): Summer `row-seasons-0`, Winter `row-seasons-1` — with the sun and the
       snowflake before the words since 0.78 (value "sun" / "snow"; spec 03, More choices → Season).
     - "Context" (`row-contexts-title`) — **only on a WET template** (`contextApplies(list)`: group == "WET"):
       Indoor, Outdoor, Race (`row-contexts-0…2`).
     - "Transport" (`row-transports-title`): Car, Plane, RV (`row-transports-0…2`). Unchanged in 0.76, when the trip
       screens' Transport became Travelling by (Plane / RV, both off = an ordinary trip, stored "Car"): a rule of Car
       means the trips with Plane and RV both off — spec 03, open question 34. How it works says so.
     - "Food" (`row-catering-title`): Self-sufficient, Eating out, Mix (`row-catering-0…2`; stored ids
       `self`, `eatout`, `mixed`; "Mix of both" until 0.78 — spec 03, More choices).
     - After the app's own words, each a stored word the app does not know (a web-app "summer", "Boat") as a pill
       of its own, as stored, lit — so it can be seen and switched off (`Library.unknownConditions`; since 0.73 the
       row's own unknown words and the thing's).
     - (0.73) Under each kind's pills: `row-<kind>-from` (Footnote, muted) — "Same as the thing: Winter" / "Same as the
       thing: any season" while the kind is the thing's answer, "Own choice on this template. The thing says: Winter."
       otherwise (`Library.limitFromWords`); and, only while it is the row's own, **Same as the thing**
       (`row-<kind>-same`: Footnote semibold violet in a 1.2-pt violet capsule, `Metrics.chip` tall), which puts the
       thing's answer back. While a kind is the thing's answer its lit pills are drawn BORROWED (`Pills(borrowed:)`):
       a 18 % violet wash, a 1.6-pt violet outline, the words in ink semibold — instead of white on violet. A kind is
       "the thing's" exactly when its pills hold the thing's words (in any order), so undoing a tap goes back.
- Field look: 17 medium ink, min height 44, card fill, 10-radius hairline border. (0.73) Borrowed pills: see block 8. Heading band: a 5 × 26 capsule in
  violet, the title 22 heavy violet, on a 13 % violet strip (radius 10). Pills (Only on some trips): 15 (bold when
  on), min height 36, white on violet when on, ink on `Theme.bg` with a hairline when off; ids are `<id>-<position>`,
  never words — as are a drop-down's rows. (Sizes here are the old points; read them through spec 06 §21.)

### Behaviour
- On appear the state is loaded from the **membership itself** (not the resolved row): bag = `m.container`, when =
  `m.phase`, qty, note, section — and (0.73) seasons, contexts, transports, catering as the row's EFFECTIVE answers
  (`Library.effectiveLimits(m, thing:)`: its own list when the kind is its own, else the thing's — spec 07 part 14). A blank membership value selects the
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
    every time", then any stored word it does not know that is still switched on (`keptConditions`) — since 0.73
    per kind: equal to the thing's answer → stored [] (follows the thing); empty while the thing has a limit →
    [] plus the kind in the membership's `onlyAnyHere` (own "any"); else the list, own (spec 07 part 14, rules 4–5);
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
- (0.73) `testATemplatesOwnOnlyOnSomeTripsWinsOverTheThings` (the row following the thing's Winter, made its own, and
  back) and `testOnlyOnSomeTripsSetOnceOnAThingReachesBothItsTemplates`; model `OnlySomeTripsTests` (spec 07 part 14).
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
| `color` | Cover colour; kept only if a hex colour, else "" (= Automatic: the hashed pick from `COVER_COLOURS`, §3). Since 0.90 set by the colour swatches of the icon picker (§3a, §4) — before, no UI set it here. |
| `sections` | Ordered `[TemplateSection {id, name}]`; `normalizeSections`: unnamed (after trim) dropped, a missing id invented, a repeated id dropped, names trimmed. |
| `group` | "GA" / "WET" / "OE" or "" (any other value → ""). A built-in activity area. Set when the template is made, and changed on its page (`setTemplateArea`, §14). An area HE made (0.89) is not here — `coerceList` would blank it — but in `extra["area"]`, with `group` ""; `Library.areaOf` reads the two together (§1a). |
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
| `seasons`, `contexts`, `transports`, `catering` | (0.73) follows the THING's answer (its `only…` keys); the thing having none = always comes | Any strings kept (not checked against the vocabularies). Non-empty = this row's own answer. PackingCore's resolve copies them as they are; `Library.resolveOne` puts the thing's answer in where the row follows it (spec 07 part 14). |
| `weather` | not conditional gear | Only `rain`, `cold`, `hot`, `wind`, `snow` kept. A tagged row is held back from a trip unless the trip forces that weather on. No UI here. |
| `container` | the template's `defaultContainer`, then the thing's own bag | Non-string → "". |
| `section` | no section | A section id of THIS template; no item default. Not carried between templates by id (only by name). Written by the row editor's Save (`saveRow`, §7), by Arrange (`moveRow`/`removeSection`, §13a) and, since 0.64, from the thing's page (`setThingSection`, below) — the first place only when the thing is on the template twice. An id that is not one of this template's sections reads as none everywhere (`groupItemsBySection`, `thingSection`) and is kept until something else is chosen. |
| `kit` | no kit | A kit NAME; no item default. No UI here. |
| `phase` | the thing's own When | Trimmed, cut to 40 UTF-16 units; an unknown id is **kept** (likely a phase made on the other device); non-string → "". |
| `itemType` | the thing's own | "item" / "reminder" / "" (anything else → ""). No UI here. |
| `qty` | the thing's own qty | Text; a JSON number becomes JS number text ("3", "0.5", "1e+21"); 0 → "". |
| `note` | the thing's own note | Text. |
| `order` | — | Position on the template (a Double, never floored); non-finite or a numeric string → 0. |
| `extra` | — | Unknown keys kept, `owner`/`realmId` dropped. (0.73) `onlyAnyHere`: the kinds ("seasons", "contexts", "transports", "catering") for which this row comes on ANY trip whatever the thing says (spec 07 part 14). |

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
- `Library.resolveOne` does the same and stamps each row's `itemId` and `memId` (the web app's `resolveOne`) — and
  (0.73) makes each row's `seasons`/`contexts`/`transports`/`catering` its EFFECTIVE answer: the row's own list where
  the kind is its own, else the thing's (`only…` keys; spec 07 part 14). Views:
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
     how-many into every row, and a change to the thing's note never reached them again.) (0.73) The same for
     "Only on some trips", per kind: a row whose answer is unchanged from what it resolved to keeps exactly what it
     stored (list and `onlyAnyHere`); a NEW row whose answer is empty or the thing's follows the thing; a changed one
     equal to the thing's follows, empty while the thing has a limit is its own "any", else its own list — so the
     thing's answers are never frozen onto its rows (spec 07 part 14).
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
- `setTemplateArea(id:area:) -> Bool` (the spec pass, 5 Oct 2026): moves an ACTIVITY template (role "") to any of
  HIS areas (0.89; "GA", "WET", "OE" until then) or "" (none) and sets `updatedAt` (not when nothing changes). A
  built-in goes in `group` (and `extra["area"]` is removed); one he made in `extra["area"]` with `group` ""
  (`Library.filed`, §1a). Refused (false) for an unknown id, a transport template (filed by what it does) and an
  area that is not one of his — a built-in he removed included.
  **0.71:** also moves a template INTO Always packed (`area == Library.ALWAYS_PACKED_AREA`, "base": role "base",
  group cleared — and since 0.89 his own area too) and an always-packed one OUT (role "", group = the area picked). Only role and group change —
  its things, sections, notes, reminders and every row's own answers stay (memberships are untouched). Several
  always-packed templates are allowed (every Full trip brings each, in template order, the first winning a name+bag
  clash — `listsForEvent` already did this); so is none (Create new trip then needs a ticked template, as it always
  does). Transport templates are still refused. Trips already made keep their lines (a template change adds or
  takes no lines on a trip already made — only a thing's details follow, ThingFollows); their next Trip settings
  Save rebuilds them from the new roles (a moved-out template's unticked lines then go unless it is ticked). A
  trip's stored `activities` still holds the id of a template moved INTO Always packed; Trip settings keeps it
  unshown, and a Quick trip whose only ticked template became always packed must get another tick to be saved.
- `deleteTemplate(id:) -> Bool`: false for an unknown id; removes the template's memberships and the template. Things
  stay (also things that were on no other template — they become things on no template). Trips built from it are
  untouched ("a trip's lines stand on their own"); a rebuild never drops lines whose template is gone
  (`docs/store.md` rule 9, `Library.regenerated`).

Tests: `TemplateFacesTests.testATemplateMovesToAnotherActivityArea` (0.71: transport refused),
`ActivityAreasTests.testANewAreaHoldsATemplateInHisOrder` (0.89: his own area, back to a built-in, unknown refused),
`testATemplateMovesIntoAndOutOfAlwaysPacked` (0.71: rows, own answers and sections kept; out → offered to tick,
comes only when ticked, a trip made before keeps its lines until its settings are saved; two always packed → both
on a Full trip, neither on Quick; asking for where it is changes nothing), `testANameIsTakenOnlyByATemplateHeCanSee`;
`EditListsTests` — `testARenameSticksAndRefusesANameHeAlreadyHas`,
`testADeleteTakesTheListAndItsRowsButNeverTheThings`, `testTheOtherListIsUntouchedByTheDelete`,
`testItRefusesAListThatIsNotThere`; `LibraryTests.testRegeneratingNeverDropsTheLinesOfADeletedTemplate`,
`testRegeneratingStillDropsWhatALivingTemplateNoLongerHas`; UI `testAListIsRenamedAndAnotherIsDeleted`.


## 14b. A small core from a big always-packed template (0.71, `PackingLibrary/SmallCore.swift`, `SmallCoreSheet.swift`)

His words (8 Oct 2026): "I would like you to move stuff around for me, so that the complete solution is served to
me. Always packed will be a small core, and [the big one] becomes a big kit that I tick." His library lives in his
app, so the app makes the move, with one confirmation.

**The sheet** (`SmallCoreSheet`, id `smallcore-detail`; Mac min 480×640): header "A small core" (title3 bold violet,
`smallcore-title`) with Cancel (outlined muted, Escape, `smallcore-cancel` — changes nothing, keeps no copy). A
footnote: Tick what comes on EVERY full trip…; then:
1. **Paste a list** (`SectionTitle`, `smallcore-paste-title`), a footnote ("One per line or with commas. A line with
   lines indented under it is a kit holding them."), a `TextEditor` (height 96, card fill, hairline, radius 10,
   `smallcore-paste`) and **Tick these** (`FieldButtonLabel`, `smallcore-paste-tick`). Pressed: `planPaste` reads
   the list (nothing changes yet), ticks become the plan's (his paste wins over the first ticks), and the result
   line (footnote semibold ink, `smallcore-paste-result`) says e.g. "16 found · 2 not found: X, Y · matched 3
   things for shirt · Cable pouch: a kit of 3 (new)". Each thing that sits in another kit (or under two kits in
   the paste) gets a line "<thing> is already in <kit> — a thing sits in one kit only" (`smallcore-clash-N`) and
   under it a capsule **"Make a second one"** (`smallcore-second-N`; on: filled, "A second one goes in <kit>",
   `isSelected`).
2. **Its name** (`smallcore-name`), filled with "<template> short" (`freeTemplateName`).
3. "<n> of <N> things" (`smallcore-count`), then the template's things under its own headings in its order
   ("Everything else" last; `smallCoreGroups`): each heading (`smallcore-section-G`, subheadline semibold) with
   "Tick all" / "Untick all" (`smallcore-section-G-all`), each thing a row with a `TickCircle` (`smallcore-row-N`,
   N counted top to bottom, `isSelected` when ticked; min height `Metrics.compact`). Ticked at first
   (`smallCoreSuggestion`): every row under a heading whose name holds clothing, clothes, underwear, toiletries,
   hygiene, wash, bathroom, kläder, hygien or toalett (case and accents aside), and every thing packed per night.
4. **Where should "<template>" go?** — his areas in his order under his words (0.89; GA / WET / OE until then), then
   "No activity area (Other Templates)" (his casing since 0.78) (`smallcore-area-<code>` for a built-in,
   `smallcore-area-own-<n>` for one he made, `smallcore-area-none`; default none). `makeSmallCore` accepts any area
   of his (`bigArea`).
Pinned under the scroll: **Make the small core** (full colour, height 50, `smallcore-make`); pressed too early the
line under it (`smallcore-needs`) says "Give the small core a name." / "You already have a template called that." /
"Tick at least one thing for the small core." The rows sit in a plain VStack (a lazy one dropped the paste answers
once scrolled past).

**Make** (`LibraryModel.makeSmallCore` → `Library.makeSmallCore`): tried on a copy first; if the model accepts, a
**rescue copy** of the whole library is written (`RescueCopies.write`, the copies Settings lists under the restore —
Settings now re-reads them when it appears), then ONE `change`: kits from the paste are made (a new kit thing when
he has none of that name: kind = the most common kind inside, no bag) and filled (`setKit`; "Make a second one"
copies the thing with all its details as "<name> 2" into this kit), the new template is added (role "base", the
big one's default bag, a copy of each heading that holds a ticked row or a kit) with a copy of each ticked
membership (same thing, How many, Note, Only on, When, bag; new id), each kit gets the big one's row if it has one,
else a row of its own under the heading of its first thing; the big template is moved to the area picked
(`setTemplateArea`) and keeps every row. The sheet and the page close; the Templates tab shows a card (callout
semibold, violet border, `templates-news`, OK `templates-news-ok`): "“<core>” is always packed now; “<big>” is
ticked when you need it."

**Pasting** (`pastedLines`): lines by newline, names by comma or semicolon; in front of each, bullets (- – — * •
· + >), "1." / "2)" and "[ ]"/"[x]" are dropped, repeatedly, never a number inside a name ("3-in-1"). A line indented
deeper (spaces; a tab = 4) than the last line at the left is inside it (depth 1; deeper still counts as 1). A
left line with lines under it is a KIT (only when it holds one name). Matching (`matches`), most certain first:
the same name (case/accents aside); else the same without a trailing number or plural s ("Sock" = "Socks",
"Cable" = "Cable 2"); else every thing whose name holds all its words ("T-shirts" → "Spare top / t-shirt").
Left-hand names look among the template's rows; a kit's things among all his things (not bags, not to-dos). A
name that finds nothing is listed, never added. A kit's thing already in another kit, or claimed by an earlier kit
in the paste, is not moved (a clash). A thing that holds things itself cannot go in; a kit that sits inside
another kit is not used (both said in the result line). A kit that would hold nothing is not made.

Kits and trips: a thing inside a kit is never a line of its own (ThingKits) — this holds for the big template
too, where the kit then takes its things' place.

Tests: model `SmallCoreTests` — `testTheDoorShowsOnlyOnABigAlwaysPackedTemplate`,
`testClothesWashingAndPerNightAreTickedAtFirst`, `testHisPastedListTicksWhatItNames` (bullets, plural, several, not found, a whole word),
`testANestedLineMakesAKit`, `testAThingInAnotherKitIsNotMovedButCanBeMadeTwice`,
`testTheSmallCoreIsMadeAndTheBigOneIsTickedFromThen` (rows and own answers equal, headings, refusals leave
nothing, a Full trip brings the core and the big one only when ticked), `testTheBigOneCanGoToAnActivityArea`.
UI (`-uiTestingBigBase`: the sample + "Long trips", 23 things, and a Camp pouch holding a Lighter):
`testASmallCoreIsMadeFromABigAlwaysPackedTemplate` (8 of 23 first, Tick all, untick, OE, made, the card, the core
always packed, a kept copy in Settings), `testCancellingASmallCoreChangesNothing`,
`testAPastedListTicksMakesAKitAndOffersASecondOne`; `testATemplateMovesOutOfAndIntoAlwaysPacked` for the area door.
Planted faults (each red, then restored): the Always packed answer left out of the card ("Always packed is not
marked"); no rescue copy ("no copy was kept before the change"); the paste not winning ("his list did not win over
the first ticks: '8 of 23 things'"); Cancel keeping a copy ("a copy was kept for nothing"); model — the group kept
on the move in, a row's note not copied, the plural/word matching off, nesting ignored, the one-kit rule off.

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
  (`extra.iconKey`) does **not** travel; his colour (`color`, 0.90 §3a) does. An empty template throws "This template has nothing on it to share."
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
  is never replaced. `importTemplate(shared, replacing:)` keeps HIS template's role, activity area (`group`, and
  since 0.89 his own area in `extra["area"]`) and transport, so it stays where it was (the spec pass: replacing his activity template with a shared always-packed one turned
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
His activity areas (0.89) are not here: they are the Templates tab's headings and are changed there, on the
Activity areas page (§1a), with the same tools.

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
| Template page: activity area (a drop-down, 0.89) | `setTemplateArea`; "A new area" → `addChoice("areas")` then `setTemplateArea` | §1a, §6 |
| Templates tab → Activity areas (rename, move, remove, add areas; no template changes) | `applyChoiceEditsNow` (kind "areas") | §1a |
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
34. [idea] **An empty activity area has no heading** (0.89, §1a). An area he made shows on the Templates tab and on
    Create new trip only once a template is in it (as the built-ins always did); the Activity areas page lists it
    with no number. Showing his empty areas as headings would show a new one at once, but also the built-ins he
    never uses. Kept as before; decide if he asks.
35. [idea] **His areas are ONE record** (0.89, spec 01 §1.11): two devices changing the LIST while both offline —
    the later write wins for the whole list (as for his kinds of thing). Which area a template is in is the
    template's own record and settles per template.

**0.90 — a template's colour, and a new template from a thing's page.**

34. **Resolved in 0.91** (his "Yes, show the template colours on the Create new trip pills too — put it in 0.91", 19
    Oct 2026) — ~~The colour on Create new trip and Trip settings: the template pills show no icon, so they keep their
    look.~~ A template he gave a colour has it on its pill there, filled when picked and outlined when not, as the
    workout pills always were; his colour wins over a workout's; Automatic pills look as before (§3a, "Where the
    colour shows").
35. [idea] **Automatic can look like a palette colour.** Automatic is the app's stable pick from `COVER_COLOURS`, three
    of which (violet `#7c5cd6`, indigo `#4f46e5`, slate `#64748b`) are also palette colours — a template whose pick is
    slate shows Automatic and Grey alike in the picker. Only Automatic is ringed, and choosing Grey stores it (it then
    survives a rename that would change nothing anyway — the pick follows the id). Harmless; noted so nobody "fixes" it
    by changing the palette.
36. [untested] The Mac's keys on a thing's page do not reach "+ New template…" (it is no `ThingField`; Tab passes it,
    as it passes every button that is not a field) — it is clicked, and New's sheet then has the keys (its window is
    not the page's, so the page's key monitor lets them through: Return makes, Escape cancels).

## Reminders on a template (0.70)

A block **Reminders** above a template's things (add, rename, When, up/down, remove) — specified in full in
spec 07, part 12. The template's things list, its Find count, Arrange and the template card count leave the
reminders out.
