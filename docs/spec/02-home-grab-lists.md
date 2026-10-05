# Home, grab lists, Shortcuts, packing reminders and Search

> Verified against the code on 5 Oct 2026 (app 0.61), and brought up to date with the fixes marked 0.6x.

Home is the first tab and the screen the app always opens on. In the owner's terms it has two jobs:
**"Grab and go"**, a grid of up to eight *grab lists* (short lists for a quick outing such as a swim,
a bike ride or a run, ticked as each thing is picked up), and **"Create new trip"**. Create new trip
is covered by another file. This file covers everything else on Home and everything reached from it:

- the frame of the app (the tab bar, the version marker, the work done whenever the app returns
  to the front);
- the empty-device screen (the two "doors");
- the grab lists: the tiles on Home, one open list (ticking, skipping, "Ready to go" / "Not yet",
  Start over), editing a list (and deleting one of his own), "only sometimes", the **Grab Lists** screen
  (Home's eight, the waiting ones, making a list, putting one on Home or taking it off, "Which one steps
  back?"), the Action
  button's menu **"Which grab list?"**, and sharing a grab list;
- the countdown card to the next trip;
- the **This Device** count tiles;
- the three Shortcuts actions (App Intents);
- packing reminders (Settings → **Remind me to pack**; its code lives in `Countdown.swift` and
  `Store/Reminders.swift`);
- **Search** (the magnifier), which opens from Home and from four other tabs.

How Home is reached: the **Home** tab (`tab-home`); app launch (the app always starts on Home); a
tapped packing reminder; any of the three Shortcuts actions (each switches to Home first).

Source files: `App/Sources/RootView.swift`, `AMSPackingApp.swift`, `Sections.swift`, `Theme.swift`,
`Buttons.swift`, `Screens/FirstRunView.swift`, `Screens/HomeScreen.swift` (all but Create new trip),
`Screens/Countdown.swift`, `Screens/GrabScreen.swift`, `Screens/GrabCollectionScreen.swift`,
`Screens/GrabMenu.swift`, `Screens/SearchScreen.swift`, `Screens/Share.swift` (the grab-list parts),
`Store/LibraryModel.swift` (the open-requests and test launch modes), `Store/Shortcuts.swift`,
`Store/Reminders.swift`, `Store/Today.swift`, `Store/ShopReminders.swift` (only its read-back on return);
model: `PackingLibrary/GrabLists.swift`, `GrabCollection.swift`, `GrabSometimes.swift`, `Countdown.swift`,
`Sharing.swift` (grab parts), `Backup.swift` / `Importer.swift` (grab parts); `PackingCore/GrabSharing.swift`,
`PackingCore/SharedRows.swift` (grab rows).

Colours are named by token; the hex values are in `docs/colours.md` (section colours: Home blue
`#2f6fe0`, Trips green `#2f9e63`, Templates violet `#7c5cd6`, Care orange `#dd7324`, To do red
`#dc3d43`, Settings slate `#64748b`; Theme `bg`, `card`, `ink`, `muted`, `line`, each a light/dark
pair). How records are stored and synced is in `docs/store.md`. This file does not repeat either.

Words used below: **factory list** = one of the six grab lists defined in code (`GRAB_FACTORY`);
**own list** = a grab list the owner made (or received by sharing), stored in `meta`; **session** =
this device's ticks and skips for one list (`GrabState`), never synced.

---

## 1. The frame: RootView, the tab bar and the version marker

**Purpose and origin.** One screen at a time with the tab bar under it, the same six sections in the
same order and colours as the web app's tab bar (`Sections.swift`). The "Actions" tab has been labelled
**"To do"** since test G.4 (2026-09-30, the owner's choice, release 0.43). The version marker has its own
thin row "so it can never sit on top of a tab's label".

**How it is reached and left.** It is the root of the only window (`WindowGroup { RootView() }`). The
selected section is `@State section: AppSection = .home`, so **every launch starts on Home**. The choice
is not remembered.

**What is on screen** (top to bottom):

1. The section's screen (`SectionScreen`), limited to **720 pt wide** (the web app's column) and centred
   in the window. The whole screen is an accessibility container named `screen-<rawValue>`
   (`screen-home`, `screen-events`, `screen-templates`, `screen-care`, `screen-actions`,
   `screen-settings`) with `.accessibilityElement(children: .contain)`.
2. The tab bar: one row of six equal-width buttons, also limited to 720 pt and centred. It has a `card`
   background that runs into the bottom safe area and a 1-pt `line` hairline along its top. It has
   6 pt padding above and 2 pt below.
3. Under the buttons, the version marker in a row of its own.

The page behind everything is `Theme.bg`, ignoring the safe area.

The tabs, in order. `rawValue` builds the identifiers and never changes when a label is reworded:

| # | case | Label | Identifier | Colour | Mark (24-unit box) |
|---|------|-------|-----------|--------|--------------------|
| 1 | `home` | "Home" | `tab-home` | blue `#2f6fe0` | a suitcase |
| 2 | `events` | "Trips" | `tab-events` | green `#2f9e63` | a calendar |
| 3 | `templates` | "Templates" | `tab-templates` | violet `#7c5cd6` | a list (three lines with dots) |
| 4 | `care` | "Care" | `tab-care` | orange `#dd7324` | a spanner |
| 5 | `actions` | "To do" | `tab-actions` | red `#dc3d43` | a ticked box |
| 6 | `settings` | "Settings" | `tab-settings` | slate `#64748b` | a hexagon nut |

The marks are stroked SVG paths (the web app's own drawings) with round caps and joins (`SectionMark`;
paths are in `AppSection.mark`).

Each tab button (`TabButtonLabel`):
- The mark at 24 pt, centred in a **46 × 30 capsule**. Active: a white mark (stroke 2.2) on a capsule
  filled with the section colour. Inactive: the mark in the section colour (stroke 1.9) on the section
  colour at 14 % opacity.
- Under it, 3 pt apart, the label: **12.5 pt**, `.heavy` and `ink` when active, `.semibold` and `muted`
  otherwise. One line, scaling down to 80 %.
- Minimum height 54. The whole rectangle is tappable. Plain button style, no focus ring
  (`.focusEffectDisabled()`). Accessibility label = the label; the active tab has the `.isSelected` trait.

The version marker (`app-version`): text `AppInfo.version` = `"<CFBundleShortVersionString> (<CFBundleVersion>)"`,
e.g. "0.61 (130)". The short version is `MARKETING_VERSION` in `project.yml` ("0.61"); the build number is
`CURRENT_PROJECT_VERSION` ("2" for a local build), which the TestFlight workflow overrides with its own run
number. Each part falls back to "?" when missing. **11 pt semibold**, `muted` at 70 %
opacity, right-aligned with 8 pt trailing padding, so it sits under the Settings tab. It does not take
taps (`allowsHitTesting(false)`). Because it reads the bundle, the number on screen and the number
TestFlight shows can never disagree. `AppInfo.marketing` (the short version alone) is what What's new
marks "On this device".

**Which screen shows** (`SectionScreen`) depends on the library state and the tab:

| `model.state` | Tab | Shows |
|---|---|---|
| `.failed(why)` | any | `why` in red `#dc3d43`, 17 pt semibold, centred, 24 pt padding; id `library-problem` |
| `.empty` | Home | `FirstRunView` (section 2) |
| `.empty` | Settings | `SettingsScreen` |
| `.ready` | each | `HomeScreen`, `EventsScreen` (Trips; its to-do chip can switch to To do), `TemplatesScreen`, `CareScreen`, `ActionsScreen`, `SettingsScreen` |
| anything else (`.loading`; `.empty` on Trips/Templates/Care/To do) | — | placeholder: the section mark at 96 pt (stroke 1.6) in the section colour, then the label at 34 pt heavy `ink` (id `screen-title`), centred between spacers |

**Behaviour.** The root view does this work:
- **On appear:** sets `PackingReminders.shared.open` to a closure that switches to Home and sets
  `model.tripToOpen = id` (always, also under UI tests). Then calls `PackingReminders.shared.start()`, which
  makes the reminders object the notification delegate; under UI tests `start()` returns at once, so no
  delegate is set.
- **Whenever the library settles:** `onReceive(model.$library.debounce(for: 2 s))`. The published library
  also emits its current value on subscription, so this runs about 2 s after launch as well. Each run
  (a) reschedules the packing reminders for the new library (`PackingReminders.reschedule`, section 14) and
  (b) calls `PackingShortcuts.updateAppShortcutParameters()`, so the grab lists offered by name in
  Shortcuts/Siri follow the owner's lists.
- **Whenever the app comes to the front** (`scenePhase` becomes `.active`, which includes launch):
  `PackingReminders.reschedule` (since 0.6x: he may just have allowed reminders again in the device's
  Settings, and they are put back at once rather than at the next library change), and
  `ShopReminders.shared.readBack(into: model)`. This is field test 8.4 (3 Oct 2026): reminders ticked in
  Apple Reminders at the shop tick their To buy lines here. It looks only at buy lines that were sent and
  are not yet done. If there are none, or the app may not read Reminders, it does nothing and never asks
  for access. Ticked ones go through `Library.takeBought(reminderIds:)` in one `model.change`. The details
  belong to the To buy file.
- **A request to open something from outside:** `onChange(of: model.grabToOpen / model.grabMenuOpen /
  model.tripToOpen, initial: true)`. When a grab-list id, the grab menu flag or a trip id is set, the
  section switches to `.home`. HomeScreen then does the opening (section 3). `initial: true` matters: a
  request set before the view exists (a Shortcut that launched the app) is still acted on.
- **A tab asked for from inside a window** (0.6x): `onChange(of: model.tabToOpen)` switches to that
  section and sets it back to nil. Search sets it to `.actions` for a to-do (section 15).
- **Under UI tests only**, when the app comes back to the front after being in the background
  (`wasAway`), `playWhatHappenedWhileAway` plays what would reach the app from outside meanwhile:
  `-openGrabOnReturn <word>` sets `grabToOpen` (as a Shortcut does), `-openNextTripOnReturn` calls
  `PackingReminders.open` with the next trip (as a tapped reminder does), `-dropOwnGrabListsOnReturn`
  removes `meta["grabOwnLists"]` (as a later write from the other device that no longer holds them).

**Data.** Reads `model.state`, `model.library`. Writes nothing itself (the test-only
`-dropOwnGrabListsOnReturn` aside).

**iPhone vs Mac.**
- Mac: the window has `minWidth 480, idealWidth 760, minHeight 600, idealHeight 900` and
  `.defaultSize(760 × 900)`. Under UI tests (`AMSPackingApp.testing` = any launch argument starting
  `-uiTesting`) every titled window is **set** to 760 × 674 on appear, keeping its top edge. That is
  GitHub's runner size, so a control below the fold there is below the fold here too.
- Mac: a second scene, the window "All your things" (`ThingsTable`), opens only from Care, has window
  restoration disabled and is suppressed at launch. It is not part of this area.
- Mac: the `WindowGroup` can show several windows (File ▸ New Window; the UI tests press ⌘N when the Mac
  comes up with no window). Each window has its own `section`. The open-requests live on the shared model,
  so every window switches to Home. The **last** window to appear owns `PackingReminders.open`.
- Colours resolve light/dark through `NSColor(name:)` on the Mac and `UIColor { traits in … }` on the
  iPhone (`Theme.swift`).
- No keyboard shortcuts are wired anywhere in the app (no `.keyboardShortcut`, `onExitCommand` or
  `onKeyPress`). Tabs are changed by click or tap.

**Tests.**
- UI `testStartsOnHomeAndNamesItsVersion`: launches on `screen-home`; `app-version` contains a digit.
- UI `testEveryTabOpensItsScreen`: every `tab-*` opens `screen-*` and Home is gone behind the others;
  `tab-actions` reads "To do".
- UI `testWhatsNewStartsWithThisVersion`: the number before the space in `app-version` equals the top
  release in What's new (`guide-release-0-version`); a second release is listed; How it works opens with at
  least two topics.
- UI `testWhatWasTickedInTheShopIsTickedOnReturn` (iPhone only, `-pretendShopTicks`): Home button,
  `app.activate()`, and the To buy count reads "All bought." with no tab change.
- **Not covered:** the `.failed` screen (`library-problem`); the placeholder for `.loading` or `.empty`
  tabs; the 2-s debounce; tab colours, sizes and the selected trait; several Mac windows.

**Traps and history.**
- 🪤 A named container must declare `.accessibilityElement(children: .contain)`, or it swallows its
  children's identifiers and the tests cannot find anything inside it (comment in `SectionScreen`).
- 🪤 `.focusEffectDisabled()` on every tab: otherwise the Mac draws a keyboard focus ring round a tab.
- The UI tests hold the Mac window at 760 × 674 because macOS restores a window's last size and ignores
  size limits on content.

---

## 2. The empty device: `FirstRunView` (the two doors)

**Purpose and origin.** `docs/store.md` rule 2: "An empty store is not a verdict." A fresh device cannot
tell "nothing has arrived yet" from "there is nothing". So it never decides by itself and never plants
starter lists. It offers two doors instead.

**How it is reached and left.** It shows on the Home tab while `model.state == .empty`, i.e.
`Library.isEmpty`: items, memberships, templates, trips, actions, kits, phases, shared rows, photos and
`meta` are all empty — a device's check-in (`syncCheck.*`, `Library.isDeviceNote`) aside (0.6x). It leaves by itself when the state becomes `.ready`:
- after a successful import (`LibraryModel.importBackup` commits, and the state is recomputed); or
- when iCloud delivers records (`store.onRemoteChange` → `reload()`).

Any one record of his ends the empty state. A Sync now check-in made from Settings on this empty device, or the
other device's check-in arriving, does not (0.6x; until then it did: Home showed the ordinary empty `HomeScreen`
instead of the doors and the import was refused as "already imported" — the storage file's open questions, item 3;
UI `testSyncNowOnAnEmptyDeviceKeepsTheTwoDoors`).

While empty, the Trips, Templates, Care and To do tabs show their placeholder. Settings works.

**What is on screen** (a vertical stack, 22 pt spacing, centred between spacers, 20 pt side padding):
1. The Home suitcase mark at **84 pt** (stroke 1.6) in Home blue.
2. "No templates on this device yet": 26 pt heavy, `ink`, centred.
3. Two "doors", 12 pt apart, together at most **420 pt** wide. Each door is a card: title 19 pt heavy,
   detail 16 pt medium at 85 % opacity, 16 pt padding, corner radius 14, left-aligned.
   - Door 1 (`first-run-wait`), **not a button**: outlined (`card` fill, 1-pt `line` stroke, `ink`
     text). Title "My other device has my templates". Detail "Leave this open. They arrive through
     iCloud." when `model.usesICloud`, else "This build does not use iCloud."
   - Door 2 (`first-run-import`), a button: filled Home blue with white text. Title "This is my first
     device". Detail "Bring in a backup file from the web app."
4. When an import failed, the reason (`first-run-problem`): 16 pt semibold red `#dc3d43`, centred.

**Behaviour.** Door 2 opens the system file picker (`.fileImporter`, allowed type `.json` only). The
chosen file is read under security-scoped access, then `model.importBackup(data)` runs:
- not JSON or not a backup → "That is not an AMS Packing backup file.";
- the library is not empty → "This library has already been imported into.";
- the imported library does not round-trip faithfully → "The import did not come back the same
  (N rows differ), so nothing was stored." and nothing is stored;
- any read error → its `localizedDescription`.

The problem text stays until the view goes away or the next failure replaces it (a new attempt does not
clear it first). Success replaces the view with Home: the import always writes a `meta["import"]` record, so
the library is never empty afterwards. The import itself
(`Importer.library(from:)`, the `meta` import record) belongs to the backup file.

**Data.** Reads `model.usesICloud`. Writes through `LibraryModel.importBackup`.

**iPhone vs Mac.** The same view. The file picker is the system one: Files on the iPhone, an Open panel
on the Mac.

**Tests.**
- UI `testAnEmptyDeviceShowsTheTwoDoors` (`-uiTestingEmpty`): `first-run-import` exists, no
  `count-templates` tile, and the Templates tab shows no `template-row-0` (nothing seeded).
- **Not covered:** the import itself from this screen (no test can drive the system file picker), the
  three error texts, the iCloud/no-iCloud wording of door 1, and the automatic switch to Home when
  records arrive.

**Traps.** Debug builds only: `-importFile <path>` imports a backup into an empty library at launch, so a
build can be looked at with real data without any of it entering the public repository. On the Mac
the path must lie inside the app's sandbox container (`docs/store.md`).

---

## 3. Home screen: layout and everything it opens

**Purpose and origin.** "Home: build a trip." Since the field test of 3 Oct 2026 its two parts lead with
real headings: "the headings … dominant". They had been small and grey.

**How it is reached and left.** The Home tab with the state `.ready`. It is a vertical scroll
(`KeyboardAwayScroll`: dragging the scroll puts the keyboard away). Content is in a stack with 14 pt
spacing, 16 pt side padding and 24 pt bottom padding.

**What is on screen** (top to bottom):
1. A row, aligned on the first text baseline, 14 pt top padding:
   - "Grab and go": **22 pt heavy** (`HeadingSize.band`), `ink`; id `home-grab-heading`.
   - A spacer.
   - The magnifier `SearchButton` (`search-open`; section 15).
   - "Grab Lists": a plain button, 14 pt bold, Home blue, no focus ring; id `grab-lists`. It opens the
     Grab Lists sheet (section 8). The code comment notes that this door opens the grab lists, not the
     templates ("Your templates"), and that the owner's note on the Mac asked for "Your Grab Lists".
2. The grab tiles (`GrabButtons`, section 4) for `library.homeGrabLists()`. When that is empty (every list
   taken off Home), a button in their place instead (0.6x, `home-grab-none`): "No grab lists on Home. They
   wait in Grab Lists — tap here to put one back." (16 pt semibold Home blue, 14 pt padding, `card` fill,
   radius 12, a 1.5-pt Home-blue stroke at 50 %). It opens Grab Lists.
3. The countdown card (section 11), only when `library.nextTrip(today: Today.local)` is not nil;
   4 pt extra top padding.
4. "Create new trip" (`home-create-heading`, 22 pt heavy, 8 pt top padding) and its card. See the Create
   new trip file.
5. The **This Device** row (section 12), 8 pt top padding.

**Sheets attached to Home** (all on the one `HomeScreen` view):

| Opens | Trigger | Content |
|---|---|---|
| Search | magnifier | `SearchScreen()` (no `go:` passed; see section 15) |
| A trip | countdown tap; `model.tripToOpen`; Create trip | `TripScreen(tripId:)` |
| Grab Lists | "Grab Lists" | `GrabCollectionScreen()` |
| Which grab list? | `model.grabMenuOpen` set (the request, cleared at once) → the local `menuShown` | `GrabMenuScreen()` |
| One grab list | a tile tap; `model.grabToOpen` | `GrabScreen(listId:)` |

Open-requests from outside are handled in `HomeScreen` with `onChange(…, initial: true)`:
- `grabToOpen`: it is set back to `nil` at once. If `library.allGrabLists()` holds that id, the list
  opens. An unknown id does nothing.
- `tripToOpen`: it is set back to `nil` at once. If `library.trips` holds that id, the trip opens. An
  unknown id does nothing.
- `grabMenuOpen`: set back to `false` at once; the menu opens unless it is already up.
- Each opening goes through `whenFree` (0.6x): if one of Home's own sheets is up (Search, a trip, Grab
  Lists, a grab list, the menu), all of them are closed first and the asked-for one opens **0.8 s** later;
  otherwise it opens at once. Until then a Shortcut or a tapped reminder that arrived while, say, Grab
  Lists was open could open nothing.

**iPhone vs Mac.** All of these are `.sheet`s. On the iPhone a sheet can also be swiped down (no
`interactiveDismissDisabled` anywhere). On the Mac each sheet sets its own minimum size (given per
screen below).

**Tests.**
- UI `testTheEditorsLeadWithTheirHeadings` checks that `home-grab-heading` and `home-create-heading`
  exist.
- UI `testAShortcutOrReminderOpensItsPlaceWhileAnotherWindowIsUp` (iPhone only): with Grab Lists open, a
  Shortcut for Bike arriving on return opens `grab-detail` and Grab Lists is gone; with Search open, a
  tapped reminder for the next trip opens `trip-detail` "Sunny weeks".
- UI `testHomeWithEveryGrabListOffSaysWhereTheyAre`: all six off → `home-grab-none`, which opens Grab
  Lists.
- **Not covered:** a request arriving while a sheet of ANOTHER tab is up (the tab switch removes that
  screen and its sheet; not seen to fail).

**Traps.** 🪤 Five sheets hang off one view. SwiftUI does not reliably present a second sheet from a view
while another is open or still closing; `SearchScreen`'s own comment records that this lost a tap on
GitHub's runner. Requests from outside therefore go through `whenFree` (above).

---

## 4. The grab tiles on Home (`GrabButtons`) and how a list is drawn

**Purpose and origin.** The grab lists are "his most-used thing on the iPhone". They are big targets he
can hit with his glasses off. The tiles are four in a row in two rows, his ask of 2 Oct 2026: "compress
the buttons a bit so they are thinner … four on each row … two rows". They were 3 × 2 before
(release 0.46).

**What is on screen.**
- Rows of **4** (`perRow = 4`) with 8 pt between tiles and 8 pt between rows. Home passes at most
  **8 lists** (`GRAB_HOME_SLOTS`), so at most two rows. It can pass fewer than 8 even when he has more
  lists: a list he took off Home leaves its place free (section 5), so Home simply shows one tile fewer.
  With every list taken off, Home shows the "Grab and go" row and, instead of tiles, the
  `home-grab-none` line that leads to Grab Lists (section 3; 0.6x).
- A short last row is padded with invisible equal-width spacers, so every tile has the same width.
- Each tile is a plain button:
  - the list's drawing (`GrabDoodle`) at **36 pt** in the list's tone colour;
  - 3 pt below it, `label` at **14 pt bold** `ink`, one line, scaling to 75 %;
  - 4 pt side padding, full width, minimum height **68**, `card` fill, corner radius 12;
  - a 1.5-pt stroke in the tone colour at 50 % opacity.
- Identifier `grab-<n>`, where n is the **position** (0…7), never the name.
- Accessibility label = `title` (for example "Indoor swim"); the visible word is `label` ("Swim"). The
  two Swim tiles differ on screen only by the sun in the drawing. Each tile passes its `label` to
  `GrabDoodle` as `initial`, so a list without a drawing shows the label's first letter.
- The view takes `prefix` (default `"grab"`) so the Action-button menu can reuse it as `grab-menu-<n>`.

**Behaviour.** A tap opens that list (section 6).

**The tones** (`GrabTone.color`):

| Tone | Hex |
|---|---|
| `blue` | `#3a86d4` |
| `yellow` | `#c99700` |
| `green` | `#2e9e6b` |
| `red` | `#cf5b52` |
| `purple` | `#8a63c9` |
| `teal` | `#17969b` |
| anything else | `#64748b` |

These are mid-tones on purpose, so they read on the light card and the dark one.

**The drawings** (`GrabDoodle`): the web app's own path data in a 64-unit box, stroked at 4.5 units,
round caps and joins.

| `icon` | Drawing |
|---|---|
| `swim` | the swimmer |
| `bike` | the bike |
| `run` | the runner with three speed lines |
| `swim-sun` | the swimmer + sun at (12, 12), scale 1.2 |
| `bike-sun` | the bike + sun at (11.5, 11.5), scale 1.2 |
| `run-sun` | the runner with only the two lower speed lines + sun at (11, 12), scale 1.15 |
| `""` with a non-empty `initial` | the **first character of the label, upper-cased**, at half the size, heavy, in the tone colour |
| **any other key**, or `""` with no initial | the runner (the `default` case). Since 0.6x a received list cannot bring an unknown key (`importGrab` keeps only `GRAB_ICONS`, section 10); only a factory row written by the web app could |

The sun is the web app's GRAB_SUN: a closed curve plus 8 rays reaching 9.6 units from its middle. It was
made bigger at the owner's ask, which meant moving its middle inwards so it does not clip the box or
touch the swimmer's head, the bike frame or the speed lines. Lists of his own have no hand-drawn mark and
wear their initial, the way he chose template covers to work (2026-09-22). "The app never adds stock
art."

**iPhone vs Mac.** The same. 🪤 These are plain `HStack` rows, not a lazy grid: "the Mac builds only what
is on screen."

**Tests.**
- UI `testMoreGrabListsThanHomeHolds`: `grab-4` exists; `grab-3` is on the same row as `grab-0` (mid-Y
  within 4 pt); `grab-4` is below `grab-0`.
- UI `testATemplateAndAGrabListAreSharedAndOpenedAgain`: an imported list appears as `grab-6`.
- UI `testAGrabListTakenOffHomeStaysOff`: after Off Home, `grab-5` no longer exists and the first tile's
  words are on no tile; put back, the list is `grab-5` (the last place).
- UI `testHisOwnGrabListIsDeletedAfterAsking`: after the delete, `grab-6` no longer exists.
- UI `testHisOwnGrabListIsFilledAndStaysFilled`, `testTicksOnHisOwnGrabListSurviveClosingIt`: a list made
  with Make opens as `grab-6`.
- UI `testHomeWithEveryGrabListOffSaysWhereTheyAre`: no `grab-0`, and `home-grab-none` instead.
- **Not covered:** tone colours, the initial letter, the runner fallback for unknown icons, the
  accessibility label being the title.

**Template icons are not used here.** The 50 template icons (`TemplateIcons.swift`,
`PackingLibrary/TemplateIcon.swift`) belong to templates only. The grab tiles, the grab screen header,
the Grab Lists rows and the menu all use `GrabDoodle`. Template icons appear on Your templates and in
Check before you go, which are other files.

---

## 5. Grab lists: the data model

**Purpose and origin.** The factory six live in the **code** (web app v163 rule; `docs/store.md` rule 1).
An account that has never edited a list stores no row. A `grab` row in the shared store carries an edited
factory list to both devices, and the web app reads the same row. His own lists, the Home arrangement (the
lists on Home and, since 0.61, the lists he sent off it) and the "only sometimes" marks live in the
library's own `meta`. The reason: PackingCore keeps only the shared-row kinds the web app knows
(`SHARED_KINDS`) and blanks anything else on the way back from storage, so a new kind would be silently
erased. The round-trip test caught that. Ticks and skips are the
device's own working state.

**`GrabDefinition`** (`PackingLibrary/GrabLists.swift`):
- `id`
- `label`: the word on the tile, e.g. "Swim"
- `title`: the screen heading, e.g. "Indoor swim"
- `tone`
- `icon`
- `items: [String]`: thing names. **Plain strings, not links to things in the library.**

**The factory six** (`GRAB_FACTORY`, in Home order):

| id | label | title | tone | icon | items |
|---|---|---|---|---|---|
| `swim` | Swim | Indoor swim | blue | swim | Swim trunks, Goggles, Swim cap, Towel, Drink / water bottle, Sports watch, Flip-flops |
| `bike` | Bike | Indoor bike | yellow | bike | Headband, AirPods, Drink / water bottle, Towel, Sports watch, Shoes, Heart-rate strap |
| `run` | Run | Indoor run | green | run | Headband, AirPods, Drink / water bottle, Towel, Sports watch, Shoes, Heart-rate strap |
| `swim-out` | Swim | Outdoor swim | blue | swim-sun | Swim trunks, Goggles, Wetsuit, Safety buoy, Towel, Drink / water bottle, Sports watch |
| `bike-out` | Bike | Outdoor bike | yellow | bike-sun | Helmet, Sunglasses, Cycling gloves, Drink / water bottle, Spare tube & pump, iPhone, Sports watch |
| `run-out` | Run | Outdoor run | green | run-sun | Shoes, Cap, Sunglasses, Sunscreen, iPhone, Drink / water bottle, Sports watch |

**Functions** (`extension Library`):
- `grabLists()`: the six factory lists, each with its `grab` row laid over it where one exists. Each of
  the row's non-empty `items`, `label`, `icon` and `tone` replaces the factory value. `title` is never
  overridden (the row has no title). Always exactly six, in factory order. Rows for ids that are not
  factory ids are ignored here.
- `ownGrabLists()`: reads `meta["grabOwnLists"]`, an array of objects. Entries without a non-empty `id`
  are dropped. Missing fields default to `label ""`, `title ""`, `tone "blue"`, `icon ""`, `items []`;
  only string items are kept. Nothing else is checked: an entry restored from a backup can have an empty
  title (the grab screen's heading is then blank) or repeated names.
- `allGrabLists()` = `grabLists() + ownGrabLists()`: factory first, then own lists in the order made.
  Every "waiting" order below follows this.
- `grabList(id:)` (0.61): any one list by id, factory or own = the first of `allGrabLists()` with that
  id; nil for an unknown id. The grab screen, `setSometimes` and `openingState` find their list through
  it.
- `offHomeIds()` (0.61): the string ids in `meta["grabOff"]` (`GRAB_OFF_META`), in stored order: the
  lists he left off Home when he last arranged it.
- `homeGrabLists()`: what Home shows.
  1. Take the ids in `meta["grabHome"]` that name a known list, in that order, at most 8.
  2. **Then fill the free places up to 8** from `allGrabLists()` in order, skipping lists already placed
     **and every list in `grabOff`**. So only a list that is in neither key — a list that is NEW since he
     last arranged Home (made here, made on the other device, received as a link) — takes a free place by
     itself. "NEVER one he sent to wait — that is the 'Off Home' that did nothing until 4 Oct 2026."
  3. With no arrangement saved (neither key), Home is simply the first 8 of `allGrabLists()`.
  4. A library arranged before 0.61 has `grabHome` but no `grabOff`: until he next arranges Home (any
     move, Off Home, swap or putting a list on), every list not in `grabHome` counts as new and fills a
     free place, exactly as before (this is how Home grew from his six to eight on 2 Oct 2026; pinned by
     `testHisArrangedSixAreJoinedByTheNextTwo`, which writes `grabHome` directly as that version did).
- `waitingGrabLists()`: every list in `allGrabLists()` not on Home, in that order. It is non-empty when
  Home holds 8 and more lists exist, **and also while Home has room** whenever he has sent lists to wait
  (since 0.61).
- `setHomeGrabLists(_ ids)`: unknown ids and repeats are dropped. **More than 8 is refused (returns
  false, nothing stored)** rather than trimmed. Otherwise `meta["grabHome"] = ids` **and**
  `meta["grabOff"]` = every other known list id, in `allGrabLists()` order ("Put these lists on Home …
  and ONLY these": every list not chosen — taken off, stepped back for another, or simply not chosen —
  waits until he puts it on Home himself). An empty remainder removes the `grabOff` key (`writeOff`); an
  empty `ids` stores `grabHome = []` and sends every list to wait.
- `grabListNameTaken(_ name)` (0.6x): true when the name, by `normName`, is the `label` or the `title` of
  any list (factory or own); false for a blank name. Make refuses such a name (section 8); receiving a
  shared list does not (it goes through `addGrabList` directly).
- `addGrabList(label:title:tone:icon:items:)`:
  - the label is `jsTrim`med; an empty label returns nil;
  - id `own-` + `PackingEnv.makeId()` (0.6x, so a model test can pin it; lists made before keep their
    `own-<milliseconds since 1970>-<random 100…999>`);
  - `title` = the trimmed title, or the label when that is blank;
  - `tone` defaults to "blue" and `icon` to "";
  - items are trimmed and blanks dropped, but **repeats are not removed here**;
  - the list is appended to `meta["grabOwnLists"]`. It is added to neither `grabHome` nor `grabOff`, so
    it is new: it takes the first free place on Home through the fill (a place freed by Off Home
    included) and waits only when Home holds 8.
- `saveOwnGrabList(_:)`: replaces an own list by id (false for an id that is not an own list). Trims the
  label (empty → false). Items are trimmed, blanks dropped, repeats removed by `normName` (first kept).
  Called by `saveGrabList` for an own list (since 0.61).
- `deleteOwnGrabList(id:)`: false for an id that is not an own list. Otherwise it removes the own list,
  removes its id from `grabHome`, removes it from `grabOff` (0.6x; it stayed there, unread, before — and
  rode in every backup's `off`), and removes its "sometimes" marks. If the remaining arrangement is
  empty, `grabHome` is left as it was; the stale id is harmless because unknown ids are skipped.
  The place a deleted list held on Home stays free unless a new list exists. Called by the grab editor's
  "Delete the grab list" (section 7, since 0.61).
- `saveGrabList(id:items:)`: any list (section 7): a factory list as a `grab` row, an own list through
  `saveOwnGrabList`. False for an unknown id or when nothing is left after cleaning.
- `saveGrabEdit(id:items:sometimes:)` (0.6x): what the editor's Save calls — `saveGrabList`, and only
  when that succeeds, `setSometimes`. Refused whole (false, nothing changed) when no name is left.
- `writeOwn`, `writeOff`: an empty array removes the key altogether.

**Session state, `GrabState`** (`Codable`, per list, this device only):
- `done: [String]`, `skipped: [String]` (names exactly as the list spells them, compared by exact
  string, so two identical names on one list tick and skip together), and `at: Date` (`distantPast` = no
  session).
- `GrabState.resetHours = 6`.
- `current(for: items, now:)`: if `now − at > 6 h`, an empty `GrabState()`. Otherwise `done` and
  `skipped` are filtered to names still on the list, and `at` is kept. The 6 hours count from the **last
  tap or skip**, because each of those stamps `at = now`, not from the start of the workout. That is on
  purpose (decided 0.6x: a list he is still ticking is still the same outing and must not empty itself
  under his hand), and the screen's footer says so (section 6).
- `active(items)` = items not skipped.
- `isComplete(items)` = `active` is not empty **and** every active name is in `done`. Nothing to take is
  not "all there".
- `missing(items)` = active names not in `done`, in list order.
- `inHand(items)` (0.6x) = active names that are in `done`; `skippedCount(items)` = the list's names that
  are in `skipped`. The counter uses these, so it reads the list as it stands, never a name edited away.
- `tapped(name)`: stamps `at`. A skipped name comes back (un-skipped, **not** ticked); a ticked name is
  unticked; anything else is ticked (appended to `done`).
- `skipToggled(name)`: stamps `at`. A skipped name is un-skipped. Otherwise it is skipped **and unticked**.

**Where the state is kept** (`GrabStore`, in `GrabScreen.swift`):
- `UserDefaults` key **`ams.grab.<listId>`**, holding the JSON of `GrabState` (`Date` in Foundation's
  default encoding).
- Under any `-uiTesting…` launch it lives **in memory only**, so one test's ticks cannot reach the next.
- `held(id)` returns the raw stored state. `save(id, state)` writes memory and (when persistent)
  `UserDefaults`. `forget(id)` (0.61) removes both; it runs after one of his lists is deleted ("A deleted
  list's ticks go with it"). Only this device forgets: the other device keeps its own stored state for a
  list deleted elsewhere, unread (a few bytes, meaningless after 6 hours; see Open questions 36).
- The grab screen always reads and saves under its own `listId` (0.6x), never under the id of a list it
  fell back to.
- (`state(_:items:)`, never called, was removed in 0.6x.)

**Storage and sync of the list definitions.**
- A factory edit is **one shared row** (`SharedRow`), kind `"grab"`:
  - key = the factory id; the row id is `grab:<normalised id>`, e.g. `grab:swim`;
  - name = the label, or the id when there is no label;
  - `order` = the factory index;
  - `data` = `{gid, items, label, icon, tone}`; `gid` carries the id verbatim (so `run-out` survives
    normalisation); each item is cut to 80 UTF-16 units and the label to 24.
  - It travels as one `shared` record (`docs/store.md`). Saving again replaces it and never doubles it.
- The keys `meta["grabOwnLists"]`, `meta["grabHome"]`, `meta["grabOff"]` and `meta["grabSometimes"]` are
  each **one `meta` record**. So **all own lists together are one record**. Two devices changing different
  own lists while both are offline: the later write wins for all of them (`docs/store.md`, "What this
  gives up").
- The Home arrangement is **two** records, `grabHome` and `grabOff`, always written together by
  `setHomeGrabLists`. Each settles on its own (the later write wins per record), so after offline
  arranging on both devices one device's `grabHome` can meet the other's `grabOff`: a list in both is on
  Home (`grabHome` is read first; `grabOff` only stops the fill), a list in neither counts as new and
  takes a free place.
- Backup (`Library.backupFile`): `prefs.grab` = `{ items: {gid: [names]}, meta: {gid: {label, icon, tone}} }`
  for the factory rows (the web app's shape), plus our own keys `sometimes: {listId: [names]}`,
  `own: [{id,label,title,tone,icon,items}]`, `home: [ids]` and (0.61) `off: [ids]` ("or a restore would
  put them straight back"; since 0.6x it never names a deleted list). Each of our keys is written only when non-empty. When there are no factory
  rows but there are marks, own lists, an arrangement or off ids, `prefs.grab` holds only those keys.
- Import (`Importer`): rebuilds the factory rows from the union of `items` and `meta` ids, **sorted**
  (so row order is alphabetical, which is harmless because `grabLists()` uses factory order). It
  restores the marks for whatever list ids the file names (not checked against any list, unlike
  `setSometimes`), writes `own` back into `meta` as it stands, and restores `home` and `off` (each only
  when non-empty, string entries only, not checked against the lists). A file from before 0.61 (or the
  web app's) has no `off`, so its arrangement behaves as described in `homeGrabLists()` point 4.

**Tests** (model).
- `GrabListsTests.testTheFactorySixAreTheWebAppsAndInItsOrder`: the ids and order; `run-out` starts with
  Shoes; an empty library gives exactly the factory list.
- `GrabListsTests.testAnEditedListLiesOverTheFactoryOne`: a row overrides items and label; the title and
  icon stay factory; the other lists are untouched.
- `GrabListsTests.testTicksAndSkipsCountTheWayTheWebAppCounts`: tap, skip, active, missing, complete; a
  tap on a skipped name brings it back; skipping unticks; all skipped is not complete.
- `GrabListsTests.testTicksClearThemselvesAfterSixHoursAndFollowTheItems`: a name edited away is dropped;
  after 7 h the state is empty.
- `GrabListsTests.testTheSixHoursCountFromTheLastTap` (0.6x): taps at 0 h and 5 h are still there at 10 h,
  gone at 12 h.
- `GrabListsTests.testTheCountIsOfTheListAsItStands` (0.6x): a ticked or skipped name no longer on the list
  is not counted.
- `GrabEditingTests` (a second class in `GrabListsTests.swift`, section 7).
- `GrabCollectionTests` (Home slots, `grabOff` and own lists, sections 7 and 8; since 0.6x also
  `testADeletedListLeavesNoTraceInTheArrangement`, `testANameAlreadyInUseIsTaken`,
  `testEveryListCanWaitOffHome`).
- `GrabSometimesTests` (marks, opening state, own lists' marks and ticks, section 7).
- `PackingCore` `SharedRowsTests`:
  - `testGrabToRowsGrabFromRowsAListSurvivesTheRoundTripHyphenAndAll`
  - `testGrabToRowsTheRowIdIsStableSoTwoDevicesMergeInsteadOfDoubling`
  - `testGrabToRowsTheCodeIdSurvivesNormalisingVerbatimInDataGid`
  - `testGrabToRowsNothingIsInventedJunkAndDuplicatesBuildNoRows`
  - `testGrabIsAKindOfTheExistingSharedTableNotANewTable`
  - `testGrabToRowsKeepsTheJSQuirkOfTwoSpellingsOnOneRowId`

**Traps.**
- 🪤 A new shared-row kind does not survive PackingCore (it keeps only the web app's kinds). That is why
  own lists, the arrangement and the marks are in `meta`.
- 🪤 Until 4 Oct 2026 a free place on Home was always filled from the waiting lists, so "Off Home" put
  the very list he had taken off straight back at the end and the button seemed to do nothing; a model
  test even expected that refill. The arrangement now remembers what it left out (`grabOff`).
- 🪤 Until 4 Oct 2026 `saveGrabList`, `setSometimes` and `openingState` looked among the factory six
  only: a list of his own could not be filled, could not have a "1 in 10", and lost its ticks on every
  opening (the empty state was saved over the real one).
- 🪤 `grabToRows` keeps the JS quirk: `seen` holds the id as written while the row id is normalised, so
  'Bike' and 'bike' build two rows with one id.

---

## 6. One grab list open: `GrabScreen` (ticking)

**Purpose and origin.** "Tap each thing as you pick it up, ⊘ to leave one behind just this once;
'Ready to go' refuses until everything not skipped is in hand." Later changes:
- Test B.2: the count stays at the top while the list scrolls ("When scrolling, the counter moves out of
  sight").
- Test B.4: "Not yet" is a red card in the middle of the screen ("even more distinctive — maybe a pop-up
  window at the center of the screen").
- Both shipped in release 0.40 (28 Sep 2026).

**How it is reached and left.**
- **In:**
  - a Home tile;
  - the Open a grab list Shortcut (`grabToOpen`);
  - a tile in the Which grab list? menu, where the list replaces the menu inside the same sheet.
- **Out:**
  - "Done" (`grab-done`) → `dismiss()`;
  - "Ready to go" on a complete list (it closes itself after 0.35 s);
  - "Delete the grab list" in the editor of one of his own lists (section 7);
  - the list going while it is open (0.6x): deleted on the other device, or lost to a later write from
    there — the sheet closes by itself;
  - on the iPhone, swiping the sheet down.
- Opened from the menu, Done (and Delete) closes the **whole** menu sheet; there is no way back to the
  menu.
- The screen finds its list with `leaving ?? library.grabList(id: listId) ?? lastSeen ?? GRAB_FACTORY[0]`.
  `lastSeen` is the list as last found (kept by `onChange(of: grabList(id:), initial: true)`). When the
  list goes while open, that same `onChange` sets `leaving = lastSeen` and dismisses the sheet, so the
  screen closes still showing it. `leaving` is also set by Delete (section 7). Until 0.6x a list that
  went while open turned the screen into Indoor swim (`GRAB_FACTORY[0]`), and the next tick was saved under
  the swim list's key. `GRAB_FACTORY[0]` is now only reached for an id that never existed (Home never
  opens one).

**What is on screen** (not editing):
1. Header row (16 pt padding, 8 pt spacing):
   - the drawing at 36 pt in the tone;
   - `title`, 22 pt heavy `ink`, one line, scaling to 70 %;
   - a spacer;
   - **"Edit"** (`grab-edit`): an outlined capsule in the tone;
   - **Share** (`grab-share`): the drawn share mark only, outlined in the tone, accessibility label
     "Share";
   - **"Done"** (`grab-done`): a capsule filled with the tone, white text.
   - The buttons use `HeaderButtonStyle`: 17 pt bold (16 until 0.6x, which overrode the `.font(17 bold)`
     written on them — spec 06 §20), minimum 36 tall, 14 pt side padding, 70 % opacity while pressed, words
     never cut.
2. The pinned counter (outside the scroll; 16 pt side and 10 pt bottom padding; a hairline under it):
   - **Not complete:**
     - `"<inHand> of <active> in hand"`, plus `" · <skipped> skipped"` when any of the list's names is
       skipped (`grab-count`), at 18 pt heavy monospaced digits, `ink`. Both numbers are counted against
       the list as it stands (`inHand`, `skippedCount`, 0.6x);
     - under it an 8-pt progress bar: a `line` capsule with a tone capsule filling
       `inHand / active` of the width (0 when nothing is active). The bar is hidden from accessibility.
   - **Complete:** a 52-tall tone-filled rounded bar saying **"All there — go!"** (20 pt heavy white,
     `grab-allthere`) replaces both.
3. The scrolling list, one row per item in list order (6 pt spacing, 16 pt side and 24 pt bottom
   padding), with a hairline under each row. A list with nothing on it (one just made) shows instead
   "Nothing on this list yet. Press Edit to put things on it." (17 pt semibold `ink`, 12 pt above and
   below, `grab-empty`; 0.6x).
   - The row button (`grab-item-<n>`, the `.isSelected` trait when ticked):
     - a 26-pt circle: tone outline, or a `line` outline when skipped; ticked = filled tone with a
       white tick (stroke 2.4);
     - the name at 18 pt, semibold, or regular when ticked; `muted` when ticked or skipped, else `ink`;
       struck through in `muted` when skipped;
     - when skipped, at the right: **"only sometimes"** if the name (by `normName`) is marked only
       sometimes for this list, else **"not this time"** (13 pt semibold `muted`);
     - 11 pt vertical padding.
   - The skip button (`grab-skip-<n>`), 40 × 40: `AsideMark` (shared with the trip screen), a 24-pt
     drawing stroked 1.8 in `muted`: the ⊘ (a circle with a slash); when skipped, the ↻ (an arrow round).
     Accessibility label "Leave <name> behind, just this once" or "Take <name> along after all".
   - Rows are keyed by their position (`id: \.offset`).
4. **"Ready to go"** (`grab-ready`), 14 pt above: full width, 52 tall, a radius-12 rounded rectangle
   filled with the tone, 18 pt bold white. **Never grey.**
5. **"Start over"** (`grab-reset`): only when the list differs from how it opens — something ticked, or
   the skipped names not exactly the "only sometimes" ones (0.6x; before, whenever anything was ticked or
   skipped). 16 pt semibold `muted`, 44 tall.
6. A footer, **15 pt** medium `muted`, 8 pt above: "Tap each thing as you pick it up — or tap ⊘ to leave
   something behind, just this once. Ticks and skips clear themselves 6 hours after your last tap."
   (0.6x: it said "after 6 hours", 14 pt.)

The whole screen is the container `grab-detail` on a `bg` background.

**Behaviour.**
- **Opening:** `state = library.openingState(listId:, held: GrabStore.held(listId))`, then it is saved
  straight away. A session still under way (`at` within 6 h) is kept exactly as it is. Otherwise a fresh
  session starts with `at = now` and the list's "only sometimes" names already skipped (section 7). The
  held ticks are filtered against the list's own names for every list, factory or own (`openingState`
  reads `grabList(id:)`; until 0.61 it read the factory six only, so an own list's ticks were lost on
  every opening and the empty state was saved over them). Opening and every later save use the screen's
  own `listId` (0.6x; it used `list.id`, which was Indoor swim's when the list had vanished).
- **A tap on a row** → `tapped(name)`. **A tap on ⊘/↻** → `skipToggled(name)`. Each change:
  1. records whether the list was complete;
  2. applies the change;
  3. clears any "Not yet" message;
  4. saves to `GrabStore`;
  5. if the list has **just become complete**, sets the flash on and turns it off again after **1.2 s**.
- **The flash:** the whole screen is overlaid with the tone at 35 % opacity (it does not take taps),
  animated ease-out over 0.6 s. "You are usually at the bottom of a long list when it lands."
- **"Ready to go":**
  - complete → flash on (it is not switched off again; the sheet closes under it), and `dismiss()` after
    **0.35 s**;
  - otherwise the "Not yet" card shows, with a message:
    - the list is empty (0.6x): **"Nothing on this list yet. Press Edit to put things on it."** (it said
      "everything is skipped");
    - nothing missing (every item skipped): **"Nothing left to take — everything is skipped."**;
    - 1 to 3 missing: **"Still missing: A, B, C."** (comma-separated, list order);
    - 4 or more: **"<N> things still missing."**
- **The "Not yet" card** (overlay):
  - the screen dimmed with black at 35 %; tapping the dim closes the card;
  - a card at most 340 wide, 24 pt padding, `card` fill, corner radius 20, 2-pt red stroke, shadow;
  - in it: a red 56-pt circle with a white "!" (30 pt black weight, hidden from accessibility);
    **"Not yet"** (28 pt heavy red, `grab-notyet`); the message (18 pt semibold `ink`, centred,
    `grab-message`); **"Keep packing"** (a red filled capsule stretched to the card width,
    `grab-message-ok`), which closes it.
  - Red is the To do colour `#dc3d43`.
  - The card appears and goes without animation (a plain `if` in an overlay); the content under it keeps
    its state.
- **"Start over"** (0.6x) replaces the state with the list's opening state —
  `openingState(listId:, held: nil)`: nothing ticked, the "only sometimes" names skipped again, `at = now`
  — and saves it. (Until 0.6x it was an empty `GrabState()`, so the "only sometimes" things counted as to
  take until the list was opened again, and only if nothing had been tapped since.)
- The counter is counted against the list as it stands (`inHand`, `skippedCount`), so a list whose names
  change while it is open (an edit arriving from the other device) can no longer read "8 of 7".
- **The list goes while open** (0.6x): the screen closes, still showing the list as last seen (see "How
  it is reached and left"). Nothing is saved under another list's key.

**Data.** Reads the list definition and `sometimes(listId:)`. Reads and writes `UserDefaults
ams.grab.<listId>`. Nothing about ticking is synced or backed up.

**iPhone vs Mac.** The Mac sheet is at least **480 × 600**. Everything else is the same.

**Tests.**
- UI `testAGrabListCountsRefusesAndClears`:
  - `grab-0` opens `grab-detail`; the count starts "0 of";
  - `grab-item-0` → "1 of"; `grab-skip-1` → the count contains "skipped";
  - `grab-ready` shows `grab-message` and `grab-notyet` and the screen stays open;
  - `grab-message-ok` closes the card;
  - `grab-reset` → "0 of" with no "skipped"; `grab-done` closes.
- UI `testAShortcutOpensAGrabListOrTheNextTrip`: `-openGrab Bike` opens `grab-detail`.
- UI `testTheActionButtonMenuOpensTheChosenGrabList`: a menu tile opens `grab-detail`.
- UI `testTicksOnHisOwnGrabListSurviveClosingIt`: a list made with Make ("Golf": Clubs, Balls) is filled
  and saved ("0 of 2 in hand"); `grab-item-0` → "1 of 2 in hand"; Done, reopen `grab-6` → still "1 of 2 in
  hand" and `grab-item-0` is selected.
- UI `testSaveKeepsTodaysTicksAndStartOverSetsAsideWhatIsTakenOnlySometimes` (0.6x): Indoor swim, tick
  item 0 → "1 of 7 in hand"; Edit, mark `grab-sometimes-1`, Save → "1 of 6 in hand · 1 skipped" with item
  0 still selected; Start over → "0 of 6 in hand · 1 skipped", item 1 "only sometimes", and `grab-reset`
  gone.
- UI `testAnEmptyGrabListSaysHowToFillIt` (0.6x): a list made with Make shows `grab-empty`; Ready to go's
  message does not say "skipped"; Share says `share-empty`; Save with nothing on it says
  `grab-save-needs` and stays in the editor; after adding "Board" and saving, "0 of 1 in hand".
- UI `testAGrabListGoneWhileOpenClosesInsteadOfBecomingAnother` (0.6x, iPhone only,
  `-dropOwnGrabListsOnReturn`): his "Kayak" open with a tick; the own lists go while the app is away; on
  return `grab-detail` has closed, `grab-6` is gone, and Indoor swim reads "0 of 7 in hand".
- Model: `GrabListsTests` (counting), `GrabSometimesTests` (opening state;
  `testTicksOnHisOwnListSurviveClosingIt`: a tick on an own list survives `openingState` with the held
  state, and `at` is unchanged).
- **Not covered:**
  - the "All there — go!" bar and the flash;
  - Ready to go closing a complete list;
  - the "Still missing" and "N things still missing" wordings;
  - tapping the dim to close "Not yet";
  - ticks surviving close and reopen on a FACTORY list (only an own list is reopened in a UI test);
  - the 6-hour expiry in the app (the model test pins it);
  - "8 of 7" on screen (it needs an edit from another device; the model test pins the counting).

---

## 7. Editing a grab list, and "only sometimes"

**Purpose and origin.**
- Editing is the web app's v163: "the iPhone is where he edits them". The edits are saved for the account,
  so the other device has the same list. The hint says "Saved for both your devices."
- **"Only sometimes"** came in release 0.7 (23 Sep 2026): things that belong on a list but that he takes
  perhaps one time in ten (the safety buoy belongs to open-water swimming). They start **skipped**, greyed
  and out of the count, and one tap brings one into today's session. Only the **default** is stored; the
  skip itself is the device's session state and still clears after 6 hours.
- **His own lists** (release 0.61, 5 Oct 2026; the code comments date the fix 4 Oct 2026): "Grab lists you
  make yourself can now be filled: Edit, add things, mark one “1 in 10”, Save — it all stays." Until then
  Save took the factory six only and his additions to a list he had made were silently thrown away.
- **Deleting one of his own** (the same release, under New): "A grab list you made yourself can be
  deleted: Edit, then Delete grab list at the bottom. It asks first." The code comment: "4 Oct 2026: there
  was no way to." The factory six "can be taken off Home, never thrown away."

**How it is reached and left.**
- **In:** "Edit" (`grab-edit`) on an open list.
- **Out:** "Save" (the same button, now filled) — unless nothing is left on the list, when the editor stays
  open and says so (0.6x). Swiping the iPhone sheet down while editing throws the draft away (nothing is
  saved). On one of his own lists, "Delete the grab list" closes the sheet and the list is gone.
- While editing, the counter, Share and Done are hidden. The button's identifier stays `grab-edit`
  whether it reads "Edit" or "Save".

**What is on screen** (editing):
1. The header with **"Save"** (a capsule filled with the tone). Under the header, after a refused Save
   (0.6x): **"Put at least one thing on the list first."** (`grab-save-needs`, 15 pt bold red — the
   shared `NeedsLine`). It goes as soon as the draft changes (a name typed, a thing added or removed) and
   when editing starts again.
2. A scroll (4 pt spacing, 16 pt side padding):
   - The hint "Tap a name to change it · ▲▼ move · ✕ remove. Saved for both your devices." (14 pt
     medium `muted`).
   - One row per draft name:
     - a text field (`grab-rename-<n>`, placeholder "Name", 17 pt medium `ink`, a radius-8 `card`
       background with no border, minimum 44 tall);
     - **up** (`grab-up-<n>`, accessibility label "Move up"), disabled on the first row;
     - **down** (`grab-down-<n>`, "Move down"), disabled on the last row;
     - **"1 in 10"** (`grab-sometimes-<n>`, accessibility label "Take <name> only sometimes", the
       `.isSelected` trait when marked): a 30-tall capsule, 12 pt heavy. Marked = tone fill and white
       text; unmarked = `card` fill and `muted` text; `line` stroke either way;
     - **✕ remove** (`grab-remove-<n>`, "Remove"), disabled when only one name is left.
     - The up, down and remove marks are 22-pt drawn glyphs in a 38 × 44 hit area: `ink` when enabled,
       `line` colour and disabled when not.
3. The bottom bar (outside the scroll, so it stays in place): a field (`grab-add-name`, placeholder "Add a
   thing", 17 pt, 44 tall, outlined) and **"Add"** (`grab-add`): always full colour, white 16 pt bold on
   the tone, 44 tall. Under the bar, when Add was pressed with nothing typed: **"Type a thing first."**
   (`grab-add-needs`, 15 pt bold red). It goes as soon as the field changes (`NeedsLine`). The bar has
   16 pt side and 10 pt vertical padding.
4. **Only on one of his own lists** (`isOwn` = the id is among `ownGrabLists()`, so a list received by
   sharing counts too), last on the screen, under the bar, with 16 pt side and 10 pt bottom padding:
   - **"Delete grab list"** (`grab-delete`): the shared `SmallDeleteButton` at **15 pt** (its `size`
     parameter, added in 0.61: "13 where it began; a new one is read at 15 (his floor: nothing under 15)";
     Delete trip, template, thing and bag still use the default 13): semibold text in To do red, 12 pt
     side padding, minimum 30 tall, a 1-pt capsule outline in red at 60 % opacity, pushed to the right
     edge. "Quiet until wanted; it only ever
     OPENS the question, never deletes by itself."
   - Pressed, it is replaced by the **question card** (padding 14, `card` fill, radius 12, a 1-pt red
     stroke; 10 pt spacing):
     - **"Delete “<label>”?"** (curly quotes; 17 pt heavy `ink`; `grab-delete-question`);
     - "It goes from Home and from Grab Lists, with everything on it. Your templates, things and trips stay
       as they are." (15 pt medium `ink`, wraps);
     - a row: **"Keep it"** at the left (`grab-delete-no`, a plain text button, 16 pt bold `ink`) and
       **"Delete the grab list"** at the right (`grab-delete-yes`, 16 pt heavy white on a red capsule,
       14 pt side padding, minimum 40 tall).
   - The factory six show no delete control at all.

**Behaviour.**
- **Start editing:**
  - `draft = list.items` (empty for a list just made with Make: no rows, only the hint and the add bar);
  - any "Put at least one thing" line is cleared;
  - `draftSometimes` = the list's marked names, as `normName` (trimmed, lower-cased, runs of whitespace
    collapsed to one space);
  - the add field is cleared;
  - any open delete question is closed.
- **Rename:** edits `draft[n]` in place.
- **Up/down:** `swapAt`.
- **Remove:** `draft.remove(at:)`, refused while only one name is left. It does not unmark: a mark on a
  removed name is dropped at Save because the name is gone.
- **"1 in 10":** toggles `normName(name)` in `draftSometimes`; ignored when the name is blank. The mark
  follows the **spelling at the time of the tap**: rename a marked thing afterwards and the mark no longer
  matches it, so it is lost at Save.
- **Add** (button or Return):
  - trims the field; empty → "Type a thing first.";
  - when the name matches an existing draft name by `normName`, it is **silently not added**, and the
    field is still cleared;
  - otherwise it is appended at the end.
- **Save:**
  1. `items = draft`, raw (untrimmed);
  2. `sometimes` = the draft names whose `normName` is marked; the list's marks before the save are noted;
  3. one `model.change`: `saveGrabEdit(id:items:sometimes:)` — `saveGrabList(id:items:)`, and only if
     that succeeds `setSometimes(listId:names:)`, which validates against the new items. "One door for
     every list, his own ones too."
  4. **Refused** (nothing left on the list): nothing is stored, the editor stays open, and
     `grab-save-needs` says "Put at least one thing on the list first." (0.6x).
  5. Otherwise editing ends and the delete question closes.
  6. **Today's session is kept** (0.6x): `stateAfterEdit(listId:held:markedBefore:)` — ticks and skips on
     names still on the list stay; a name just marked "1 in 10" is set aside unless it is already ticked;
     a name just unmarked comes back into the count; a session not under way (or older than 6 h) starts
     from the defaults as an opening does. It is saved. (Until 0.6x every Save restarted the session —
     all ticks gone — even with nothing changed.)
- **`saveGrabList(id:items:)`** (the one door for an edit of a list's things, whichever kind it is):
  1. trims every name, drops blanks, drops repeats by `normName` (first kept);
  2. refuses an empty result (returns false and changes nothing), for any id;
  3. a **factory** id: keeps the existing row's label, icon and tone ("what he did not change keeps
     whatever it was") and writes **one** `grab` row with `order` = the factory index, replacing any
     earlier row;
  4. an **own** id: that own list with its `items` replaced by the cleaned names goes through
     `saveOwnGrabList` (label, title, tone and drawing unchanged; the label is trimmed again and an empty
     label refused; the items are cleaned again, which changes nothing), so it is written into
     `meta["grabOwnLists"]` — never as a `grab` row, which the web app would read;
  5. any other id: false.
- **When a save is refused** (every name blanked, or a list just made with nothing added) — since 0.6x —
  nothing is stored at all, the marks included, and the line under Save says what is missing. (Until then
  the editor closed silently and `setSometimes` still ran with no names, deleting every "only sometimes"
  mark of the list.)
- **On a list of his own** (since 0.61) both calls work exactly as on a factory list; only where the
  result is stored differs (step 4 above).
- **`setSometimes(listId:names:)`:**
  - any list `grabList(id:)` finds, factory or own (false for an unknown id; until 0.61 factory ids only,
    so his marks on his own lists were silently refused);
  - keeps the trimmed names that are on the list (by `normName`), each once;
  - an empty answer removes that list's entry, and an empty map removes the `meta` key.
- **`setSometimes(listId:name:on:)`:** adds or removes one name by `normName`, then calls the above.
  Used by the tests only.
- **`openingState(listId:held:now:)`:**
  - the items are those of `grabList(id:)`, i.e. **every list**, factory or own ([] for an unknown id);
  - `live = (held ?? empty).current(for: items)`;
  - when `live.at != distantPast` (a session within 6 h), it is returned untouched. "A session already
    under way is HIS: whatever he ticked or brought in today stays exactly as it is."
  - otherwise a fresh state with `at = now` and `skipped` = the list's items, **as the list spells them**,
    whose `normName` is marked.
- **What a rebuild must keep:** the edit changes only the **things**. The list's label, title, drawing and
  tone cannot be changed in this app, for his own lists too. They change only through a `grab` row written
  by the web app or a restored backup.
- **"Delete grab list"** only opens the question. **"Keep it"** closes the question; the editor stays
  open with its draft. **"Delete the grab list"** (`deleteIt`), in this order:
  1. `leaving` = the list as shown (the screen keeps drawing it while the sheet slides away);
  2. `dismiss()` closes the sheet (opened from the Action-button menu, the whole menu sheet);
  3. one `model.change`: `deleteOwnGrabList(id:)` — the list, its id in `grabHome` and its "only
     sometimes" marks go; its place on Home stays free unless a new list exists (section 5);
  4. `GrabStore.forget(id)`: this device's ticks for it go.
  The unsaved draft is dropped. Nothing else in the library changes ("Your templates, things and trips stay
  as they are"). There is no undo. The other device loses the list when the `grabOwnLists` record arrives.

**Data.**
- The `grab` shared row (factory lists); `meta["grabOwnLists"]` (his own lists, edited and deleted here).
- `meta["grabSometimes"]` = `{listId: [names]}`, carried in the backup as `prefs.grab.sometimes`.
- `meta["grabHome"]` and `meta["grabOff"]` (a deleted list's id is removed from both).
- `UserDefaults ams.grab.<id>` for the session after a Save (kept, 0.6x), removed by Delete.

**iPhone vs Mac.** The same. The add field's Return submits on both.

**Tests.**
- UI `testAGrabListIsEditedAndStaysEdited`: rename row 0 to "Swim shorts", remove row 1, add "Nose clip"
  (appears as `grab-rename-6`), Save; then the count is exactly "0 of 7 in hand", item 0 says "Swim
  shorts" and item 6 says "Nose clip"; after Done and reopening, item 0 still says "Swim shorts".
- UI `testAThingTakenOnlySometimesStartsSkipped`: mark `grab-sometimes-1`, Save; the count now contains
  "skipped" and differs; item 1 reads "only sometimes"; `grab-skip-1` brings it back.
- UI `testEveryAddButtonIsReadyAndSaysWhatIsMissing`: an empty Add shows `grab-add-needs`. It then saves
  unchanged.
- UI `testHisOwnGrabListIsFilledAndStaysFilled`: Make "Padel" (it goes onto Home as `grab-6`), open it,
  Edit, add Racket, Balls, Spare grip, mark `grab-sometimes-2`, Save → "0 of 2 in hand · 1 skipped"; Done,
  reopen → `grab-item-0` says "Racket", `grab-item-2` says "only sometimes", the count is the same.
- UI `testHisOwnGrabListIsDeletedAfterAsking`: the editor of `grab-0` (a factory list) has no
  `grab-delete`; Make "Kayak", open it, Edit, add Paddle (not saved); `grab-delete` →
  `grab-delete-question`; `grab-delete-no` closes the question and the list stays open; `grab-delete` +
  `grab-delete-yes` → `grab-detail` closes, `grab-6` is gone, and Grab Lists says "6 of 8" and Waiting "0".
- Model `GrabEditingTests.testAnEditedListIsOneSharedRecordAndTheOthersStayFactory`: trims, drops blanks
  and repeats; exactly one record `grab:swim`; saving again replaces; all-blank refused; unknown id
  refused; his label survives an items edit.
- Model `GrabEditingTests.testARefusedSaveKeepsTheMarks` (0.6x): an all-blank `saveGrabEdit` changes
  nothing — the marks stay — on a factory list and on his own.
- Model `GrabSometimesTests.testSavingAnEditKeepsTodaysTicks` (0.6x): `stateAfterEdit` with nothing changed
  is the state itself; a new mark is set aside but a ticked thing stays ticked; an unmarked thing comes
  back; a thing edited off goes; no session or a stale one gives the defaults.
- UI `testSaveKeepsTodaysTicksAndStartOverSetsAsideWhatIsTakenOnlySometimes`, `testAnEmptyGrabListSaysHowToFillIt`
  (section 6).
- Model `GrabCollectionTests`:
  - `testAListOfHisOwnIsFilledThroughTheSameDoorAsTheOriginals`: Make gives an empty list;
    `saveGrabList` on it trims, drops blanks and repeats ("Racket", " Balls ", "", "balls", "Grip" →
    Racket, Balls, Grip); label and title unchanged; the factory six untouched; **no `shared` record**;
    the things survive the store; an all-blank save and an unknown id are refused.
  - `testAListOfHisOwnIsEditedAndKeepsItsThings` (`saveOwnGrabList` directly: blanks and twins go, the
    label is trimmed);
  - `testDeletingHisOwnListTakesItOffHomeToo` (section 8).
- Model `GrabSometimesTests`:
  - `testNothingIsOnlySometimesToBeginWith`
  - `testAThingCanBeMarkedAndUnmarked`
  - `testOnlyThingsActuallyOnTheListCount`
  - `testTheyStartSkippedAndOutOfTheCount`
  - `testASessionUnderWayIsNotReset`
  - `testAStaleSessionStartsOverWithTheDefaultsBack`
  - `testTheDefaultsSurviveTheStoreRoundTrip`
  - `testHisOwnListsTakeThingsOnlySometimesToo`: a mark on an own list is kept, a name not on it is
    dropped, the opening state starts it skipped, it survives the store; an unknown id is refused.
  - `testTicksOnHisOwnListSurviveClosingIt` (section 6)
  - `testTheDefaultsTravelInABackup`
- **Not covered:**
  - moving rows up or down;
  - a duplicate Add being dropped;
  - a refused save of a list whose names were all blanked (the UI test uses a list with none; the model
    test covers blanks);
  - marks lost by renaming;
  - Delete from the Action-button menu's sheet; the question being closed by Start editing or Save.

**Traps.**
- 🪤 The marks once used a new shared-row kind and were silently erased on the way back from storage. The
  round-trip test (`testTheDefaultsSurviveTheStoreRoundTrip`) caught it; they live in `meta` now.
- 🪤 Until 4 Oct 2026 the editor's Save "took the original six only": a list he made was saved nowhere,
  silently, and "1 in 10" on it was refused. `saveOwnGrabList` existed and was tested but no screen called
  it.
- 🪤 Delete keeps the deleted list on screen (`leaving`) while the sheet closes, "so the screen does not
  turn into another list on the way out" (the fallback is Indoor swim).

---

## 8. Grab Lists (`GrabCollectionScreen`) and "Which one steps back?" (`SwapScreen`)

**Purpose and origin.**
- Release 0.7 (23 Sep 2026): "More than six grab lists; Home holds your six." The lists themselves are
  unlimited. The ones on Home are his choice, in his order, and the rest wait here "with all its things".
- Release 0.46 (2 Oct 2026): Home grew to **eight** (4 × 2, "I need four of them × 2 rows"), and free
  places filled from the waiting ones. His arranged six were joined by the next two.
- Release 0.61 (5 Oct 2026; code comments 4 Oct): "Off Home now really takes a grab list off Home: it
  waits in Grab Lists until you put it back, and Home shows one tile fewer." Only a list new since he last
  arranged Home takes a free place by itself. And: "After Make, Grab Lists says where the new list went —
  on Home, or waiting because Home is full." (It used to say "<name> is waiting", in red, even when the
  list had gone straight onto Home.)
- The waiting area was called "the shelf" until the field test of October 2026 (release 0.56).
- "Nothing is ever deleted by making room." A list is deleted only in its own editor (section 7).

**How it is reached and left.**
- **In:** Home → "Grab Lists" (`grab-lists`).
- **Out:** "Done" (`grablists-done`, a capsule filled with Home blue), or a swipe down on the iPhone.
- Swap sheet: opened by a waiting list's "On Home" while Home is full. It closes on "Cancel"
  (`swap-cancel`, an outlined capsule) or after a pick.
- A waiting list's own screen (`GrabScreen`, section 6): opened by tapping the waiting row (0.6x); its
  Done (or Delete) comes back here.
- Both open through ONE sheet with a destination (`Window`: `.swap(id)` or `.open(id)`), as Search does.

**What is on screen.**
1. Header: "Your grab lists", 22 pt heavy `ink`, and Done.
2. A scroll (8 pt spacing, 16 pt side padding):
   - **The "made" line** (`grablists-made`), 15 pt semibold **`ink`** (said plainly, not as a problem;
     until 0.61 it was the red `grablists-problem`), wrapping over as many lines as it needs, when set
     (only after Make, see Behaviour).
   - **"On Home · <n> of 8"** (`grablists-home-heading`, 15 pt heavy `muted`); n can be anything from 0 to
     8.
   - One row per list on Home (container `grablists-home-<n>`):
     - drawing 30 pt;
     - label (17 pt semibold, one line; the label, not the title, so the two "Swim" lists read alike);
     - "<k> thing" or "<k> things" (13 pt medium `muted`);
     - **up chevron** (`grablists-up-<n>`, label "Move <label> earlier"), disabled on the first row;
     - **down chevron** (`grablists-down-<n>`, label "Move <label> later"), disabled on the last row;
       the chevrons are `muted` when enabled and `line` when disabled, in a 34 × 36 hit area;
     - **"Off Home"** (`grablists-off-<n>`, label "Take <label> off Home; it waits with everything on
       it"): an outlined pill, 13 pt heavy `muted` on `bg`, 28 tall.
     - The row is minimum 54 tall, `card` fill, radius 12, hairline stroke.
   - **"Waiting · <n>"** (`grablists-waiting-heading`), 15 pt heavy `muted`, 14 pt above.
   - If none are waiting (15 pt medium `muted`), worded by whether Home has room: fewer than 8 on Home →
     "Nothing waiting. A new list goes straight onto Home."; 8 on Home → "Nothing waiting. A new list waits
     here while Home is full."
   - One row per waiting list, same size and look as a Home row, holding **two buttons** (0.6x):
     - the drawing, the label and "<k> thing(s)" (`grablists-waiting-<n>`, accessibility label
       "<label>, <k> things. Open it" — always "things", even for 1): **opens the list** to tick, fill or
       delete it, and it stays waiting;
     - a filled Home-blue pill reading **"On Home"** (`grablists-on-<n>`, label "Put <label> on Home";
       13 pt heavy white, 28 tall): puts it on Home.
     (Until 0.6x the whole row was the "On Home" button, and a waiting list could not be opened here.)
   - Both row kinds say "1 thing" / "<k> things" on screen (singular for one).
   - Footer: "A list that steps back off Home keeps everything on it — nothing here throws a list away."
     (14 pt medium `muted`).
3. A bottom bar:
   - a field (`grablists-new-name`, placeholder "A new grab list");
   - **"Make"** (`grablists-new`): always full colour, Home blue;
   - under it, after an empty Make: **"Type a name first."** (`grablists-new-needs`), which goes once the
     field changes.

**Behaviour.**
- **Make** (button or Return):
  1. trims the name; empty → "Type a name first.";
  2. a name a list already has, on its tile or as its title (`grabListNameTaken`, 0.6x) → **"You have a
     grab list called <name> already. Give this one another name."** under the bar
     (`grablists-new-needs`); nothing is made and the field keeps the name;
  3. otherwise `addGrabList(label: name)`: **no things**, tone blue, no drawing (so its tile shows the
     initial), title = the name; no length limit;
  4. clears the field;
  5. sets the made line by where the list actually went (it asks `homeGrabLists()` after the change):
     - on Home: **"<name> is on Home now. Open it there and press Edit to put things on it."**
     - waiting: **"<name> waits below, as Home is full. Tap it to put things on it, or press On Home."**
     (`<name>` is the trimmed name typed.)
- **The new list's place:** it is new (in neither `grabHome` nor `grabOff`), so it lands on Home in the
  first free place if there is one — a place freed by Off Home or by a delete included. Otherwise it waits.
  A new list can wait only while Home holds 8 (the fill takes it the moment a place is free), so the made
  line is true when it is shown.
- **Up/down** (`move`):
  1. takes the **current displayed** Home ids (fill-ins included);
  2. swaps the neighbours;
  3. saves them with `setHomeGrabLists`, which also stores every other list in `grabOff`. From then on the
     arrangement is stored, and a list that was waiting only because Home was full now counts as sent to
     wait: it is no longer pulled in when a place frees;
  4. clears the made line.
- **Off Home** (`takeOff`):
  1. saves the displayed Home ids without this one with `setHomeGrabLists`, so the list goes into
     `grabOff`;
  2. clears the made line.
  - The list now **waits, whole, until he puts it back**; Home shows one tile fewer, and its place stays
    free: no waiting list is pulled in, only a list made (or received) later takes it. ("Until 4 Oct 2026
    the free place pulled it straight back.")
- The made line is cleared by Up/Down, Off Home, `bringOn`'s "room on Home" branch and (0.6x) a pick in
  the swap sheet (`SwapScreen`'s `picked`); an empty or refused Make and Cancel on the swap sheet leave it
  as it was.
- **Tap a waiting list** (0.6x): its screen opens (section 6) over Grab Lists; nothing moves.
- **"On Home" on a waiting list** (`bringOn`):
  - with fewer than 8 on Home (since 0.61 the normal case after Off Home or a delete): it is added at the
    **end** of Home with `setHomeGrabLists` (so it leaves `grabOff`), no question asked, and the made line
    is cleared;
  - otherwise the swap sheet opens for it.
- A waiting list can be **opened** from here (0.6x) — also through the Action-button menu (section 9) or
  the "Open a grab list" Shortcut.
- **Swap sheet:**
  - title "Which one steps back?" (20 pt heavy);
  - "Home holds eight. <coming label, or "The new list"> takes the place of the one you pick — and the
    one that steps back keeps everything on it." (15 pt medium `muted`);
  - one row per Home list (`swap-<n>`): drawing 28 pt, label 17 pt semibold, the thing count
    right-aligned (15 pt bold monospaced `muted`), minimum 52 tall;
  - picking row n: the arrangement is the displayed Home ids with **position n replaced** by the coming
    list (the newcomer takes exactly that place); `setHomeGrabLists`; `picked()` (Grab Lists clears its
    made line); the sheet closes.
  - The swapped-out list now waits, whole (it is in `grabOff`).
- Grab Lists has no delete control: one of his own lists is deleted in its editor (section 7).

**Data.** `meta["grabHome"]` and `meta["grabOff"]` (the arrangement: on Home, in order; sent to wait),
`meta["grabOwnLists"]` (lists made here). All are synced as `meta` records and carried in backups
(`prefs.grab.home`, `.off`, `.own`; section 5).

**iPhone vs Mac.** Mac minimum sizes: Grab Lists **460 × 560**, swap sheet **420 × 480**.

**Tests.**
- UI `testMoreGrabListsThanHomeHolds`:
  - the heading starts "6 of 8";
  - Make "Padel" → "7 of 8", Make "Golf" → "8 of 8"; after each, `grablists-made` contains "is on Home";
  - Make "Kayak" → the waiting heading contains "1", Home stays "8 of 8", and `grablists-made` contains
    "Home is full";
  - tapping `grablists-on-0` opens `swap-detail`; `swap-0` closes it, and `grablists-made` is gone (0.6x);
  - Home is still 8 of 8; the list that stepped back is `grablists-waiting-0` and does not say
    "0 things";
  - the list now waiting carries the first four characters of `swap-0`'s words (it is the one he picked);
  - after Done, a Home tile says "Kayak".
- UI `testAGrabListTakenOffHomeStaysOff`: "6 of 8"; `grablists-off-0` → "5 of 8" and Waiting contains "1";
  after Done, Home has no `grab-5` and the list's tile is gone; Grab Lists opened again still says "5 of 8";
  tapping `grablists-waiting-0` opens `grab-detail` and, after its Done, Home is still "5 of 8" (0.6x);
  `grablists-on-0` → "6 of 8" with **no** `swap-detail`; after Done the list is `grab-5`.
- UI `testAnEmptyGrabListSaysHowToFillIt`: Make "swim" → `grablists-new-needs`, still "6 of 8".
- UI `testHomeWithEveryGrabListOffSaysWhereTheyAre`: `grablists-off-0` six times → "0 of 8".
- UI `testHisOwnGrabListIsDeletedAfterAsking` (section 7): after the delete Grab Lists says "6 of 8" and
  Waiting "0".
- UI `testEveryAddButtonIsReadyAndSaysWhatIsMissing`: an empty Make shows `grablists-new-needs`.
- Model `GrabCollectionTests`:
  - `testAFreshLibraryShowsTheOriginalSix` (also pins `GRAB_HOME_SLOTS == 8`)
  - `testNewListsFillHomeThenWaitInGrabLists`
  - `testHisArrangedSixAreJoinedByTheNextTwo`: an arrangement as a version before 0.61 stored it
    (`grabHome` only) is joined by the next two lists;
  - `testHeChoosesTheEightAndTheirOrder`: his eight in his order; the one left out waits whole; taking
    another off leaves **seven** on Home and both wait (until 4 Oct 2026 this test expected the refill);
  - `testAListHeTakesOffHomeStaysOff`: a list taken off stays off, also through the store and through a
    backup; a list made afterwards takes the free place while the one taken off keeps waiting; put back,
    it is last on Home and no longer in `offHomeIds()`;
  - `testThePlaceHeFreesStaysFree`: a list that was waiting because Home was full is not pulled into a
    place he frees;
  - `testNineOnHomeIsRefused`
  - `testAListOfHisOwnIsEditedAndKeepsItsThings`, `testAListOfHisOwnIsFilledThroughTheSameDoorAsTheOriginals`
    (section 7)
  - `testDeletingHisOwnListTakesItOffHomeToo`: the deleted list leaves Home; the rest of his arrangement
    stands; the freed place stays free (the list he had left off, Outdoor run, is not pulled in); a list
    made next takes it;
  - `testHisOwnListsTravelInABackup`
  - `testItAllSurvivesTheStoreRoundTrip`
- **Not covered in the UI:**
  - the up/down chevrons;
  - Cancel on the swap sheet;
  - the two "Nothing waiting" texts.

---

## 9. "Which grab list?": the Action button's menu (`GrabMenuScreen`)

**Purpose and origin.** Field test 2.3 (3 Oct 2026): "change the app so that I can get a menu and, from
the Action button, choose what grab list I want this time." Shipped in 0.55. The Action button's "Choose a
grab list" opens the app here: every grab list as a big tile, and one tap opens it, ready to tick.

**How it is reached and left.**
- **In:** the `ChooseGrabListIntent` Shortcut (section 13) sets `model.grabMenuOpen = true`. RootView
  switches to Home; Home clears the flag at once and opens the menu (its own `menuShown`) through
  `whenFree`, so it opens even over another Home sheet (0.6x). Under UI tests the launch argument
  `-openGrabMenu` sets the same flag.
- **Out:** "Close" (`grab-menu-close`, a `muted` outlined capsule; `HeaderButtonStyle` makes it 17 pt
  bold — 16 until 0.6x — overriding the 17 pt semibold written on it) or a swipe down.

**What is on screen.**
- "Which grab list?" (24 pt heavy, Home blue) and Close; 14 pt between this row and the tiles.
- Then a plain `ScrollView` (not the keyboard-dismissing one) of `GrabButtons` with prefix `grab-menu`, so
  tiles are `grab-menu-0…`. The tiles hold
  **Home's lists first (in Home order), then all the others in `allGrabLists()` order**, four per row,
  with no limit on the number. So a waiting list — one sent off Home, or made while Home was full — can be
  opened (ticked, edited, deleted) here without first being put on Home (as, since 0.6x, in Grab Lists).
- 16 pt padding all round, `bg` background, container id `grab-menu`.

**Behaviour.** A tile tap sets `chosen`. The sheet's content is then replaced by
`GrabScreen(listId: chosen.id)` (section 6) inside the same sheet. Its Done closes the whole sheet.

**iPhone vs Mac.** Mac minimum **520 × 520** for the menu (480 × 600 once a list is shown). The Action
button exists only on iPhones that have one. The intent also runs from Shortcuts on the Mac, Siri and a
Home Screen shortcut.

**Tests.**
- UI `testTheActionButtonMenuOpensTheChosenGrabList`: `-openGrabMenu` shows `grab-menu`; `grab-menu-5`
  exists (all six sample lists); tapping `grab-menu-1` opens `grab-detail`.
- **Not covered:** Close; lists beyond Home appearing after Home's.

---

## 10. Sharing a grab list (sending and receiving)

**Purpose and origin.** The web app's share links and QR codes (gap list, 2026-09-27; release 0.38 "Share", 27 Sep 2026):
a grab list travels as a compact code inside a link `<web app address>#/g/<code>`. The link opens in the
web app for anyone, and in this app under Settings → Open a shared link.

**Sending.**
- Share (`grab-share`) on an open grab list builds a `ShareOffer`:
  - title "Share “<label>”";
  - link `library.shareLink(grabId:)` = `SHARE_WEB_BASE + "#/g/" + encodeGrabShare(name: label, icon:,
    tone:, items:)`.
- **Only the `label` is sent as the name** (not the title), cut to **14** UTF-16 units
  (`GRAB_SHARE_NAME_MAX`).
- Items are trimmed, blanks and case-insensitive repeats dropped, each cut to **60** units, at most
  **100** items.
- A list with nothing on it cannot be encoded ("This list has nothing on it to share."), so the link is
  nil.
- The Share screen (`ShareScreen`, its own sheet owned by `ShareDoor`; container `share-screen`; Mac
  minimum 480 × 560) shows:
  - a header: the title (20 pt heavy, one line) and "Done" (`share-done`, filled Trips green);
  - a QR code at most 260 wide on a white radius-12 card (`share-qr`, accessibility label "QR code"), or
    "Too long for a QR code. Send the link instead." (`share-qr-toolong`, 15 pt medium `muted`);
  - the link (`share-link`, 13 pt monospaced `muted`, three lines at most, middle-truncated, selectable);
  - **"Send…"** (`share-send`, the system share sheet, Trips-green fill, 48 tall) and **"Copy link"**
    (`share-copy`, outlined Trips green, 48 tall), which then reads "Copied" (accessibility value
    "copied");
  - with no link and a file to offer (a trip): "This is too big for a link. Share it as a file instead."
    (`share-toolong`);
  - with no link and no file — an **empty** grab list (a list just made with Make, before anything is
    saved on it) or an empty template: **"There is nothing on it to share yet."** (`share-empty`, 15 pt
    medium `muted`; 0.6x — it used to give the "too big" reason, and there is no file for these);
  - a footer, 14 pt `muted`: "The link opens in the web app, and in this app under Settings → Open a
    shared link."
- Codes are byte for byte the web app's (PackingCore `GrabSharing.swift`: short keys `k`, `v`, `n`, `x`,
  `i`, `c`; optional "z." squeezed form).

**Receiving.**
- Settings → "Open a shared link" → paste or type → `Library.readShared(text)`. It tries a grab list
  first, then a template, then a trip.
- A grab list shows "A GRAB LIST" (`shared-kind`, 12 pt heavy `muted`, kerning 0.6), its name
  (`shared-name`, 18 pt bold) and "<n> things" (14 pt medium `muted`; always "things", also for 1).
  `decodeGrabShare` refuses a code with no items ("The shared list is empty."), and `readShared` then tries
  a template and a trip, so such a code ends as `shared-bad`.
- **"Add it to your grab lists"** (`shared-add`, Trips-green fill, 48 tall) runs `importGrab`, which is
  `addGrabList`:
  - label = the shared name, or "Shared" when empty;
  - icon = the shared icon when this app draws it (`GRAB_ICONS`: the six doodle keys), else `""`, so the
    tile wears the list's initial (0.6x; an unknown key used to show as the **runner**);
  - tone = the shared tone when it is one of `GRAB_TONES` (blue, yellow, green, red, purple, teal), else
    "blue" (0.6x; an unknown tone used to show as slate `#64748b`);
  - items as decoded.
- The result line (`shared-result`, 15 pt bold Trips green; the preview and the typed text are cleared):
  - "Added — it is on Home, in a free place." when the fill put it on Home (a received list is new, so it
    takes any free place, one freed by Off Home included);
  - otherwise "Added — it waits in Grab Lists, as Home is full. Put it on Home when you want it there."
- Bad input → "This is not an AMS Packing link or code." (`shared-bad`).

**Tests.**
- UI `testATemplateAndAGrabListAreSharedAndOpenedAgain`: Share from `grab-0`, Copy, then Settings →
  paste: kind "A GRAB LIST"; Add → the result contains "on Home"; Home shows `grab-6`. (Earlier in the same
  test "hello there" is refused with `shared-bad`.)
- Model `SharingTests.testAGrabListWaitsInGrabLists`: a full Home is unchanged and the list waits;
  rubbish and blank text read as nothing.
- Model `SharingTests.testAReceivedGrabListGetsTheStandardLookForWhatIsUnknown` (0.6x): a known drawing and
  colour are kept; "kite" and "magenta" become "" and "blue".
- UI `testAnEmptyGrabListSaysHowToFillIt`: Share on an empty list shows `share-empty`, not `share-toolong`.
- PackingCore `GrabSharingTests`:
  - `testRoundTripOfNameLookAndItems`
  - `testAcceptsAWholeLinkOrTextWithTheLinkPastedInsideIt`
  - `testTidiesTheItems`
  - `testRefuseAnEmptyListAndAnythingThatIsNotAGrabList`
  - `testSurvivesNamesWithAccentsAndEmoji`
  - `testTheCodesAreByteForByteTheWebApps`
  - `testCodesMadeByTheWebAppOpenHere`
  - `testJunkInsideACode`
  - The last one also pins the limits 14 / 60 / 100.
- **Not covered:** an empty TEMPLATE's Share screen in the UI (the same `ShareScreen` branch as the empty
  grab list).

---

## 11. The countdown card (`CountdownCard`) and the packing steps behind it

**Purpose and origin.** Pre-trip idea 6 (2 Oct 2026, release 0.49): the trip he leaves on next, counted
down on Home **under** the grab lists, which keep their place at the top. It shows the days in big figures
("readable without glasses"), the trip's name, and the next packing step with when it falls due. A tap
opens the trip.

**How it is reached and left.** It is part of Home. It shows only when `library.nextTrip(today:
Today.local)` returns a trip. A tap opens `TripScreen(tripId:)` as a Home sheet. The Open my next trip
Shortcut opens the same trip without the card.

**What is on screen.** One plain button (`home-countdown`), 14 pt padding, `card` fill, corner radius 12,
a 1.2-pt stroke in Trips green:
- **Left**, minimum 72 wide:
  - days = 0: **"Today"** at 26 pt heavy;
  - otherwise the number at **44 pt heavy** monospaced digits;
  - in Trips green, one line, scaling to 60 %;
  - under the number (days > 0 only), "day" for 1, else "days" (14 pt bold `muted`).
- **Middle:** the trip name (18 pt heavy `ink`, one line). Under it the **step line** (15 pt medium
  `muted`, wraps).
- **Right:** a drawn chevron (20 pt, `muted`).

**The step line** (`CountdownCard.stepLine(next, today:)`):
- With a step: `"<step.says>, <when>"`.
  - `says` = `"<phase label>: <left> to do"` for a task phase (Preparations), else `"… to pack"`.
  - `when` = `"from <d Mon>"` while today is before the step's date (string comparison of YYYY-MM-DD),
    else **"now"** (due today, or overdue).
  - Example: "≥1 week ahead: 12 to pack, from 14 Oct".
- With no step: "All packed" when nothing is left, else "<left> to pack". This happens when everything
  left sits in phases with negative lead days (After / recovery) or in phases unknown to the timeline.
- `shortDay("2026-10-14")` = "14 Oct", with English month abbreviations Jan…Dec. Anything that is not three
  numbers with a month of 1–12 is shown as it is.

**Behaviour: which trip** (`Library.nextTrip(today:)`, `PackingLibrary/Countdown.swift`):
- "Still to leave" = `status != "done"` **and** `reviewedAt` empty **and** `startDate` is YYYY-MM-DD
  **and** `startDate >= today`.
- **A trip under way is no countdown**: from the day after it starts it is gone. A trip without dates
  never counts. (Kept on purpose, 0.6x: every packing step falls due on or before the first day, so a trip
  under way has no step left to remind of; its On site page is on the Trips tab.)
- The soonest by `startDate`. The sort is stable, so on equal dates the library's trip order wins.
- `days` = `daysUntil(startDate, today)`, whole calendar days (UTC day arithmetic on the date strings);
  0 on the start day.
- `left` = all lines not ticked and not set aside (`isSetAside` = the line's ⊘ "not this time"), in every
  phase.
- `step` = the first of `packingSteps(tripId:)`.

**The packing steps** (`Library.packingSteps(tripId:)`):
- For each phase of the current timeline (`PHASES`: the library's own phases, or the factory seven) with
  `leadDays >= 0`, in timeline order:
  - `left` = that phase's lines not ticked and not set aside; phases with 0 left are skipped;
  - `date` = start date minus `leadDays` (`Library.ymd(_:plusDays:)`, Gregorian calendar in UTC;
    invalid input is returned unchanged).
- Then a stable sort by date, so steps due the same day keep timeline order.
- **The first step can be overdue**, e.g. Preparations (lead 30) for a trip 20 days away. The card then
  says "now".
- Factory lead days: Preparations 30 (task); ≥1 week ahead 7; Day before 1; Morning list 0; At the front
  door 0; Wear / carry on the day 0; After / recovery −1, which is never a step or a reminder.

**Data.** Reads `trips` (`status`, `reviewedAt`, `startDate`, `name`, entries' `phase`, `checked`,
`skipped`) and the phase timeline. Writes nothing. `Today.local` is today's YYYY-MM-DD in **the device's
time zone**. The model defaults to the UTC date, which in Central European time is yesterday until 01:00 (02:00 in
summer); the web app's countdown lags exactly that way. The app always passes `Today.local`.

**iPhone vs Mac.** The same.

**Tests.**
- UI `testHomeCountsDownToTheNextTrip` (`-uiTestingChecks`: "Sunny weeks", 20 days out): the card contains
  "20", "Sunny weeks" and "week ahead"; a tap opens `trip-detail` with `trip-name` "Sunny weeks".
- Model `CountdownTests`:
  - `testTheNextTripIsTheSoonestStillToLeave`: soonest; days 20; left 7; step `prep` dated 30 days ahead
    even though already due; a reviewed trip is skipped; day 0 on the start day; nil the day after.
  - `testAStepFallsDueItsLeadDaysAheadAndGoesWhenPacked`: five steps with their dates; `says` wording for
    pack and do; a step all ticked or set aside drops out.
  - `testOneReminderPerTripPerDayFromTodayOn` (section 14).
  - `testDaysAreCountedOnTheCalendar`: −7 days, month ends, leap day, year change.
- **Not covered:**
  - `stepLine` and `shortDay` (no test reads "from 14 Oct" or "now");
  - "Today" instead of a number;
  - "1 day";
  - the "All packed" and "N to pack" fallbacks;
  - ties on the start date.
- Model `CountdownTests.testATripMarkedDoneIsNoCountdownEvenUnreviewed` (0.6x): `status == "done"` without
  `reviewedAt` gives no next trip and no reminders.

---

## 12. "This Device": the count tiles on Home

**Purpose and origin.** How many trips, things and templates this device holds. On the Mac the owner
marked the heading to be struck out and written **down the side** instead (and Trips and Templates
swapped over).

**What is on screen.** A row with 10 pt spacing:
- **"This Device"**: 12 pt heavy `muted`, kerning 0.5, rotated −90° in a 16-pt-wide column
  (`device-heading`).
- Three `CountTile`s of equal width, each minimum 76 tall, `card` fill, radius 14, hairline stroke. Each
  shows the number (30 pt heavy monospaced) and under it a 14 pt semibold `muted` label:

| Tile | Number | Identifier (on the number) | Colour |
|---|---|---|---|
| Trips | `library.trips.count` (every trip, done ones included) | `count-trips` | Trips green |
| Things | `library.items.count` | `count-things` | Care orange |
| Templates | the templates Your templates shows: `TemplatesScreen.activityAreas(library.templates)`, all areas together | `count-templates` | Templates violet |

**Behaviour.** Display only; no taps.

Since 0.6x "Templates" is the same number as Your templates' summary: the hidden bags list (role
`container`) and any `loose` list (the web app's retired bin) are not counted. (It counted every template
record, so it was one higher with a bag list.) Settings' "This device holds" still counts every record.

**Tests.** UI `testAnEmptyDeviceShowsTheTwoDoors` asserts `count-templates` is **absent** on an empty
device (Home is not shown at all there). UI `testHomeCountsTheTemplatesYourTemplatesShows`
(`-uiTestingChecks`, whose bag makes a bags list): the tile equals the first number of `templates-summary`.
**Not covered:** the Trips and Things numbers. Settings has its own per-table counts (`device-count-*`),
tested elsewhere.

---

## 13. Shortcuts and the Action button (App Intents)

**Purpose and origin.** Pre-trip idea 10 (2 Oct 2026, release 0.51): a grab list, or the next trip, one
press away from the iPhone's Action button, a Shortcut on the Home Screen, Siri, or Shortcuts on the Mac.
The menu action came from field test 2.3 (3 Oct 2026, release 0.55). "Each opens the app at that place;
nothing is changed."

**The actions** (`Store/Shortcuts.swift`). All three have `openAppWhenRun = true`. Each only sets a request
on the shared `LibraryModel.shared`, the same object the app's window uses.

| Intent | Title (as Shortcuts shows it) | Description | Parameter | What it sets |
|---|---|---|---|---|
| `ChooseGrabListIntent` | "Choose a grab list" | "Opens Packing on all your grab lists, to pick the one for today." | none | `grabMenuOpen = true` → section 9 |
| `OpenGrabListIntent` | "Open a grab list" | "Opens one of your grab lists in Packing, ready to tick." | `list: GrabListEntity`, title "Grab list" | `grabToOpen = list.id` → section 6 |
| `OpenNextTripIntent` | "Open my next trip" | "Opens the trip you leave on next, at its packing list." | none | `tripToOpen = nextTrip(today: Today.local)?.id`; with no next trip it only opens the app, says nothing and leaves the current tab |

**`GrabListEntity`:**
- type name "Grab list";
- `id` = the list id;
- title = the list's `title`, or its `label` when the title is empty, so factory lists show "Indoor swim",
  "Outdoor run" and so on;
- synonyms (0.6x) = the word on its tile (`label`) when it differs from the title, so "Swim" can find the
  indoor and the outdoor swim (Siri asks which) — the guide's example says "Swim".

**`GrabListQuery`:**
- `suggestedEntities` = **Home's lists in Home order, then the waiting ones** in `allGrabLists()` order;
- `entities(for:)` = the same list filtered to the asked ids;
- it reads the library in memory at the time of asking. A list deleted since (in its editor on this
  device, or on the other device) is simply not returned.

**App Shortcuts** (`PackingShortcuts`). `\(.applicationName)` is the app's name, "Packing" per the guide:

| Intent | Phrases | Short title | System image |
|---|---|---|---|
| Choose | "Choose a grab list in Packing", "Grab lists in Packing" | "Choose a grab list" | `square.grid.2x2` |
| Open a grab list | "Open <list> in Packing", "Grab <list> with Packing" | "Open a grab list" | `checklist` |
| Next trip | "Open my next trip in Packing" | "My next trip" | `suitcase` |

`updateAppShortcutParameters()` runs after every settled library change (section 1). The system images are
SF Symbols shown only by Shortcuts/Siri, never inside the app.

**Flow inside the app.**
1. The request is set.
2. RootView switches to Home (`onChange … initial: true`).
3. HomeScreen clears `grabToOpen` / `tripToOpen` / `grabMenuOpen` and opens the sheet — at once, or, when
   one of Home's sheets is up, after closing it (`whenFree`, section 3; 0.6x).
4. An unknown list or trip id is cleared without opening anything.
5. On an **empty** device Home shows the doors, and the request waits unhandled.

**How the guide tells him to set it up** (How it works → "Shortcuts and the Action button"): iPhone
Settings → Action Button → swipe to Shortcut → Choose a Shortcut → Packing → Choose a grab list. "If
Packing is not in the list there: open Packing once, then look again."

**UI-test stand-ins** (`LibraryModel.shared`, only under `-uiTesting…`):
- `-openGrab <word>` sets `grabToOpen` to the first list whose **label or title** equals the word, so
  "Bike" finds the indoor bike;
- `-openGrabMenu` sets `grabMenuOpen`;
- `-openNextTrip` sets `tripToOpen` to the next trip.
- (0.6x) the same requests arriving while the app is in the background, played on its return:
  `-openGrabOnReturn <word>`, `-openNextTripOnReturn` (section 1).

**Tests.**
- UI `testAShortcutOpensAGrabListOrTheNextTrip`: `-openGrab Bike` → `grab-detail`; `-uiTestingChecks
  -openNextTrip` → `trip-detail` "Sunny weeks".
- UI `testTheActionButtonMenuOpensTheChosenGrabList`.
- UI `testAShortcutOrReminderOpensItsPlaceWhileAnotherWindowIsUp` (section 3).
- **Not covered:** the intents themselves (no test runs Shortcuts); entity titles, synonyms and order;
  Siri phrases; a next trip that does not exist.

---

## 14. Packing reminders ("Remind me to pack")

**Purpose and origin.** Pre-trip idea 7 (2 Oct 2026, release 0.49): at **9 in the morning** of the day a
packing step falls due, a notification with the trip's name and what is left in each step due that day.
It is **per device and off until he turns it on**: "his iPhone and his Mac both reminding him would be the
same news twice." Tapping one opens the trip.

**Where it is switched on.** Settings → the **RemindersCard** (`settings-reminders-card`, defined in
`Screens/Countdown.swift`, placed on `SettingsScreen`):
- **A Toggle** (`settings-reminders`): a switch on the iPhone, a check box on the Mac; tinted Trips
  green ("green when on, like every switch he knows: the Settings slate read as 'off'").
  - Title "Remind me to pack" (18 pt bold `ink`).
  - Detail "On this device, at 9 in the morning of the day each packing step is due — a week ahead, the
    day before, the morning." (14 pt regular `muted`).
  - The switch's state is `@AppStorage("ams.reminders")`; its setter does not store the wanted value
    directly but runs the permission check first (below).
- **Refused or blocked:** "This device does not allow the app to remind you. Allow it in the device's
  Settings, under Notifications." (15 pt semibold red, `settings-reminders-refused`). Shown when the
  permission was just refused, **and** (0.6x) whenever the switch is on but the device's Settings have the
  app's notifications switched off — the switch stays on (his choice), and no "Next" line is shown.
- **On, and allowed:** (15 pt semibold Settings slate, `settings-reminders-next`)
  - `"Next: <d Mon> · <trip name> — <says>"` for the first upcoming reminder, e.g.
    "Next: 14 Oct · Weekend in the hills — ≥1 week ahead: 4 to pack";
  - or "Nothing to remind you of yet: no trip with dates ahead."
- The card: 14 pt padding, `card` fill, radius 12, hairline stroke.

**Behaviour of the switch.** Turning it on asks the system for permission (`askToShow`):
- authorised or provisional → yes;
- denied → no;
- anything else (not decided yet) → the system question (alert + sound); its answer, or no when it
  throws.

Then `on = want && ok`, `refused = want && !ok`, and the reminders are rescheduled. Turning it off never
asks, then reschedules (which removes them all). `refused` is view state: it is forgotten when the screen
is rebuilt — but `blocked` (0.6x) is looked up again every time the card is shown (`.task`) and every time
the app comes back to the front: `PackingReminders.allowed()` asks the system for the current status
without asking him anything (authorised or provisional → allowed). `blocked = on && !allowed`.

**The plan** (`Library.reminderPlan(today:limit: 48)`):
- for every trip still to leave (the countdown's rule), every packing step dated today or later;
- grouped into **one reminder per trip per day**, with steps in timeline order;
- `says` = the steps' `says` joined with " · ", e.g. "Morning list: 1 to pack · At the front door: 1 to
  pack";
- all trips together, stably sorted by date, at most **48** (an iPhone keeps 64 waiting notifications
  per app).

**`PackingReminders.upcoming(library, now:)`** takes `reminderPlan(today: Today.local)` and keeps only
reminders whose 9:00 on the device's clock (`Calendar.current`) is still in the future. A reminder for
today is kept only before 9:00. The Settings card computes it when it is drawn; it does not redraw by
itself at 9:00.

**Scheduling** (`reschedule`):
1. Remove every pending notification whose identifier starts `packing-`.
2. Stop if switched off (`UserDefaults` bool **`ams.reminders`**) or not authorised.
3. Add each upcoming reminder:
   - a calendar trigger at year/month/day **09:00**, not repeating, in the device's calendar;
   - title = the trip name; body = `says`; default sound; `userInfo["tripId"]`;
   - identifier `packing-<tripId>-<YYYY-MM-DD>`.

It runs at launch and 2 s after every library change (section 1), every time the app comes back to the
front (0.6x; reminders allowed again in the device's Settings come back at once), and on every flip of the
switch.

**Presentation and taps.**
- While the app is open a reminder still shows (banner, list, sound).
- A tap calls `PackingReminders.open(tripId)`. RootView switches to Home and sets `tripToOpen`, and Home
  opens the trip if it still exists.

**Data.** `UserDefaults ams.reminders` (per device, never synced, not in backups). The plan is computed
from the library each time; nothing about reminders is stored in the library.

**iPhone vs Mac.** Both can remind. Each device has its own switch and permission. 🪤 The status
`.ephemeral` is deliberately not named: it exists only for iPhone App Clips, and naming it broke the Mac
build (0.49 on GitHub).

**Under UI tests:** no delegate is set, permission is always "yes" without asking (the system's question
is a window no test can answer), `reschedule` does nothing, and `ams.reminders` is cleared at launch.
`-pretendRemindersBlocked` (0.6x) plays "switched on here earlier, then blocked in the device's
Settings": `start()` sets `ams.reminders` on, and both `askToShow` and `allowed` say no.

**Tests.**
- UI `testSettingsTurnsOnPackingReminders` (`-uiTestingChecks`): off at first with no "next" line; on →
  the next line names "Sunny weeks" and "week ahead"; off → the line goes.
- Model `CountdownTests.testOneReminderPerTripPerDayFromTodayOn`: dates per trip; the two steps due the
  same day joined in one reminder; soonest first; `limit` respected; a reviewed trip gives no reminders.
- UI `testRemindersSayWhenTheDeviceBlocksThem` (0.6x, `-pretendRemindersBlocked`): the switch is on,
  `settings-reminders-refused` shows and `settings-reminders-next` does not; after Home and back to
  Settings the line is still there.
- UI `testAShortcutOrReminderOpensItsPlaceWhileAnotherWindowIsUp`: a reminder's trip opens over Search.
- **Not covered:**
  - real scheduling and identifiers;
  - the 9:00 cut-off for today;
  - the message at the moment the system's question is refused.

---

## 15. Search everything (`SearchScreen`)

**Purpose and origin.** Release 0.16 (25 Sep 2026): "the magnifier on Home, Trips, Your lists, Care and
Actions finds things, lists, trips and to-dos." It deliberately improves on the web app in two places:
- the web app stops at thirty things and says nothing; this one says how many more there are;
- the web app jumps from a thing to whichever list holds it first (or to Care); this one opens the
  **thing** itself.

The ✕ that empties the field came from the field test of 3 Oct 2026 (release 0.56).

**How it is reached and left.**
- **In:** the magnifier (`search-open`, a drawn magnifier 24 pt in a 40 × 36 area, `muted`,
  accessibility label "Search everything") on Home (beside "Grab Lists"), Trips, Templates, Care and
  To do. Each opens its own sheet.
- **Out:** "Done" (`search-done`, Home-blue filled capsule) or a swipe down.

**What is on screen.**
1. "Search" (20 pt heavy `ink`) and Done; 16 pt side and top padding, 8 below.
2. The field: placeholder "Things, templates, trips, to-dos…", 17 pt medium, 44 tall, a radius-10 `card`
   fill with a hairline, 16 pt side margins. It is **focused on appear**, so the iPhone keyboard comes up.
   - The field is named `search-field`.
   - While it holds text, an ✕ at its end (`search-field-clear`, label "Clear the search": a 24-pt `muted`
     disc with the cross cut out in `card`, in a 36 × 36 hit area — the shared `clearButton` modifier).
     The ✕ only empties the text; the field keeps focus, so the keyboard stays (pinned by
     `testTheCrossKeepsTheKeyboard` for Your things' field, not for this one).
3. The results scroll:
   - **Nothing typed** (after trimming): "Type to search across everything — your things, your
     templates, your trips and your to-dos." (15 pt medium `muted`, 24 pt above).
   - **No match:** "Nothing matches “<typed, trimmed>”." (`search-none`, same style).
   - **Otherwise** up to four parts, always in this order, each with a heading in capitals (12 pt heavy
     `muted`, kerning 0.6; 18 pt above, 4 below) followed by its total (12 pt heavy monospaced digits):
     - each row: name (16 pt semibold, one line), an under-line (13 pt medium `muted`, one line, only
       when non-empty), a chevron, minimum 48 tall, a hairline under it;
     - row identifiers `search-<part>-<n>`, with part = `things`, `lists`, `trips`, `todos`.

**Matching.** `needle = normName(query)` (trimmed, lower-cased, whitespace runs collapsed). A hit is a
**substring** of the same `normName` of a field:

| Part | Heading | Searched fields | Order | Shown | Under-line |
|---|---|---|---|---|---|
| things | "THINGS" | name, Swedish name | library item order | first **30**; then "…and <N> more. Say more of the name." (`search-things-more`) | storage place (if any) · the Swedish name (only when the Swedish name matched) · "on no template" or "on <k> template(s)"; k = the thing's membership records, the bags list included |
| lists | "TEMPLATES" | name | `shownTemplates()` — the templates the Templates tab shows: bags list and the web app's loose bin excluded (the loose bin since spec 04's pass, 5 Oct 2026) | all | "<k> thing(s)" |
| trips | "TRIPS" | name, destination | library trip order | all | destination · `countdownLabel(daysUntil(start, today))`: "Today", "Tomorrow", "Yesterday", "in N days", "N days ago"; empty parts dropped |
| todos | "TO-DOS" | text, the linked thing's name | `sortedActions()` | all | "done" or "still to do" |

**Choosing a row.**
- One sheet with a destination, not three sheets:
  - a thing → `ThingEditor(itemId:)`;
  - a template → `TemplateDetail(listId:)`;
  - a trip → `TripScreen(tripId:)`.
- A **to-do** closes Search and sets `model.tabToOpen = .actions`; the frame switches to the To do tab
  (section 1), whichever tab Search was opened from (0.6x; it asked a `go` no screen passed, so it only
  closed Search). The to-do itself is not singled out on the To do tab.
- The "more" line is 13 pt medium `muted` with 8 pt above and below; only the things part is ever capped.

**iPhone vs Mac.** Mac minimum **460 × 560**.

**Tests.**
- UI `testOneSearchReachesEverything`, opened from **Care**: "zzzz" → `search-none`; "Headlamp" →
  `search-things-0` opens `thing-detail`; "Hiking" → `search-lists-0` opens `template-detail`.
- UI `testTheCrossEmptiesASearch`: `search-field-clear` empties the field and `search-none` goes.
- UI `testASearchedToDoOpensTheToDoTab` (0.6x): a to-do added on To do, Search opened from **Home**,
  "ferry" → `search-todos-0` → Search closes and `screen-actions` shows.
- **Not covered:**
  - trip hits;
  - the 30 cap and its "more" line;
  - Swedish matches;
  - under-line wording.

**Traps.** 🪤 "ONE sheet with a destination, not three sheets": SwiftUI does not reliably present a
second sheet on a view while the first is still closing. "Open a thing, close it, tap a list" opened
nothing on GitHub's slower runner, and would have on the phone too.

---

## 16. Not reached from Home

- **The world map** (`Screens/WorldMap.swift`, `PackingLibrary/WorldMap.swift`) opens from the Trips tab
  only (`WorldMapDoor`, `MiniWorldMap` in `EventsScreen`). Nothing on Home or in its sheets reaches it,
  so it belongs to the Trips file.
- **Template icons** (section 4): not used by grab lists.
- The trip, thing and template screens that Home's sheets open (`TripScreen`, `ThingEditor`,
  `TemplateDetail`) and Settings → Open a shared link are described in their own files. Only their entry
  points are given here.

---

## 17. Accessibility identifiers in this area (index)

- Frame: `tab-home`, `tab-events`, `tab-templates`, `tab-care`, `tab-actions`, `tab-settings`;
  `screen-<section>`; `screen-title`; `app-version`; `library-problem`.
- First run: `first-run-wait`, `first-run-import`, `first-run-problem`.
- Home: `home-grab-heading`, `grab-lists`, `search-open`, `grab-<0…7>`, `home-grab-none` (0.6x), `home-countdown`,
  `home-create-heading`, `device-heading`, `count-trips`, `count-things`, `count-templates`.
- Grab list:
  - `grab-detail`, `grab-edit`, `grab-share`, `grab-done`, `grab-count`, `grab-allthere`;
  - `grab-item-<n>`, `grab-skip-<n>`, `grab-ready`, `grab-reset`, `grab-empty` (0.6x);
  - `grab-notyet`, `grab-message`, `grab-message-ok`;
  - editing: `grab-rename-<n>`, `grab-up-<n>`, `grab-down-<n>`, `grab-sometimes-<n>`, `grab-remove-<n>`,
    `grab-add-name`, `grab-add`, `grab-add-needs`, `grab-save-needs` (0.6x);
  - deleting one of his own (0.61): `grab-delete`, `grab-delete-question`, `grab-delete-no`,
    `grab-delete-yes`.
- Grab Lists: `grablists-detail`, `grablists-done`, `grablists-made` (replaced `grablists-problem` in
  0.61), `grablists-home-heading`,
  `grablists-home-<n>`, `grablists-up-<n>`, `grablists-down-<n>`, `grablists-off-<n>`,
  `grablists-waiting-heading`, `grablists-waiting-<n>` (opens the list since 0.6x), `grablists-on-<n>`
  (0.6x, puts it on Home), `grablists-new-name`, `grablists-new`,
  `grablists-new-needs`.
- Swap: `swap-detail`, `swap-cancel`, `swap-<n>`.
- Menu: `grab-menu`, `grab-menu-close`, `grab-menu-<n>`.
- Reminders card: `settings-reminders-card`, `settings-reminders`, `settings-reminders-refused`,
  `settings-reminders-next`.
- Search: `search-detail`, `search-done`, `search-field`, `search-field-clear`, `search-none`,
  `search-<things|lists|trips|todos>-<n>`, `search-things-more`.
- Sharing a grab list: `share-screen`, `share-done`, `share-qr`, `share-qr-toolong`, `share-link`,
  `share-send`, `share-copy`, `share-toolong`, `share-empty` (0.6x); receiving: `settings-openshared`, `shared-screen`,
  `shared-input`, `shared-paste`, `shared-open`, `shared-bad`, `shared-preview`, `shared-kind`,
  `shared-name`, `shared-add`, `shared-result`, `shared-done`.

Every per-row identifier is built from the **position**, never from the words.

---

## Open questions / discrepancies

Found by reading the code; none of these is covered by a test unless said. Tags: **[bug]** the code does
something wrong or surprising; **[rule-break]** it breaks one of his standing rules; **[doc]** a comment or
document disagrees with the code; **[untested]** behaviour that matters and no test pins; **[idea]** worth
deciding before a rewrite. Items marked **Resolved** (in 0.61 or 0.6x) or **Decided** keep their number so
that references stay valid; they carry no tag and are not counted as open. Items marked **Left in 0.6x**
keep their tag and say why they were left.

**What the screens promise and the code does not do.**

1. **Resolved in 0.61** — ~~Lists he makes himself cannot be filled or edited.~~ `saveGrabList` now saves an
   own list through `saveOwnGrabList`, and `setSometimes` accepts any list (section 7). Pinned by
   `testAListOfHisOwnIsFilledThroughTheSameDoorAsTheOriginals`, `testHisOwnListsTakeThingsOnlySometimesToo`
   and the UI test `testHisOwnGrabListIsFilledAndStaysFilled`.
2. **Resolved in 0.61** — ~~Ticks on his own lists do not survive closing the list.~~ `openingState` reads
   `grabList(id:)` (section 6). Pinned by `testTicksOnHisOwnListSurviveClosingIt` and the UI test
   `testTicksOnHisOwnGrabListSurviveClosingIt`.
3. **Resolved in 0.61** — ~~"Off Home" only moves the list to the last place on Home.~~ The arrangement
   stores what it left out (`grabOff`) and the fill never pulls one of those in (sections 5 and 8). The
   model test that expected the refill now expects seven on Home; pinned also by
   `testAListHeTakesOffHomeStaysOff`, `testThePlaceHeFreesStaysFree` and the UI test
   `testAGrabListTakenOffHomeStaysOff`.
4. **Resolved in 0.61** — ~~Own lists cannot be deleted in the app.~~ "Delete grab list" at the foot of the
   editor, after a question (section 7). Pinned by the UI test `testHisOwnGrabListIsDeletedAfterAsking`.
5. **Resolved in 0.6x** — ~~A to-do found by Search goes nowhere.~~ Search sets `model.tabToOpen = .actions`
   and the frame opens the To do tab from any tab (section 15). Pinned by `testASearchedToDoOpensTheToDoTab`.
6. **Resolved in 0.61** — ~~After Make, Grab Lists says "<name> is waiting" in red, even when the list went
   onto Home; "Nothing waiting. A new list starts here." is untrue while Home has room.~~ The made line now
   says where the list went, in `ink`, and the empty-waiting text depends on Home's room (section 8).
   Pinned by `testMoreGrabListsThanHomeHolds` ("is on Home", "Home is full"); the empty-waiting texts are
   not.
7. **Resolved in 0.6x** — ~~A refused grab-list save deletes the list's "only sometimes" marks.~~ Save goes
   through `saveGrabEdit`: things and marks together or not at all; refused, the editor stays open and says
   "Put at least one thing on the list first." (section 7). Pinned by `testARefusedSaveKeepsTheMarks` and
   `testAnEmptyGrabListSaysHowToFillIt`.
8. **Resolved in 0.6x** — ~~The Share screen for an empty grab list says "too big for a link".~~ With no link
   and no file it says "There is nothing on it to share yet." (`share-empty`) — for an empty template too
   (section 10). Pinned by `testAnEmptyGrabListSaysHowToFillIt`.
9. **Resolved in 0.6x** — ~~Save on an unchanged grab list restarts the session.~~ `stateAfterEdit` keeps
   today's ticks and applies only what the edit changed (section 7). Pinned by
   `testSavingAnEditKeepsTodaysTicks` and `testSaveKeepsTodaysTicksAndStartOverSetsAsideWhatIsTakenOnlySometimes`.
10. **Resolved in 0.6x** — ~~"Start over" does not re-apply "only sometimes".~~ It goes back to the opening
    state, those things set aside (section 6). Pinned by the same UI test.
11. **Resolved in 0.6x** — ~~"Ready to go" on an empty list says "everything is skipped".~~ It says "Nothing on
    this list yet. Press Edit to put things on it.", and the empty list says so too (`grab-empty`). Pinned
    by `testAnEmptyGrabListSaysHowToFillIt`.
12. **Resolved in 0.6x** — ~~Home's "Templates" tile includes the hidden bags list.~~ It counts what Your
    templates shows (section 12). Pinned by `testHomeCountsTheTemplatesYourTemplatesShows`.
13. **Resolved in 0.6x** — ~~Switched off in the system's notification settings, the card still names the next
    reminder.~~ The card looks the permission up whenever it shows and whenever the app returns, and then
    says reminders are blocked instead of naming one; reminders are put back on return once allowed
    (section 14). Pinned by `testRemindersSayWhenTheDeviceBlocksThem`.

**Comments and documents that disagree with the code.**

14. **Resolved in 0.6x** — ~~"Six" left over in `Backup.swift` and `Importer.swift`.~~ Both say eight.
15. **Resolved in 0.6x** — ~~`importGrab`'s comment says a shared list waits.~~ It says a received list is new,
    takes a free place on Home and waits only while Home is full.
16. **Resolved in 0.6x** — ~~HomeScreen's comment calls the Templates screen "Your lists".~~ It says "Your
    templates".
17. **Resolved in 0.6x** — ~~`docs/colours.md` promises a red message for a grab list that cannot be saved.~~
    The editor now shows one (`grab-save-needs`, item 7); `docs/colours.md` names it.
18. **Resolved in 0.6x** — ~~`docs/colours.md` and `WorkoutTone` say a sport keeps the same colour in the grab
    lists.~~ Decided: the grab tiles keep their mid-tones (the workout fills, a bright yellow above all,
    would not read as a stroke on the light card); both notes now say the grab lists wear the same colour
    FAMILY in mid-tones.
19. **Resolved in 0.6x** — ~~The `GrabSharing.swift` header promises a fallback this app did not make.~~ Decided
    for the fallback: `importGrab` keeps only a drawing and a colour this app has; anything else becomes a
    new list's look — its initial, in blue (section 10). Pinned by
    `testAReceivedGrabListGetsTheStandardLookForWhatIsUnknown`; the header says so.
20. **Resolved in 0.6x** — ~~The guide's Siri example says "Swim", and no list is titled so.~~ The Shortcuts
    entity carries the word on its tile as a synonym, so "Swim" can find both swim lists (Siri asks which).
    A How it works line naming a list by its full title ("Open Indoor swim in Packing") is proposed for
    the release; until it is written there, the guide still says "Swim". (Siri itself cannot be tested.)

**Behaviour to decide.**

21. **Decided in 0.6x** — the 6 hours count from the last tap, on purpose (a list he is still ticking is the
    same outing); the footer now says "6 hours after your last tap" (section 6). Pinned by
    `testTheSixHoursCountFromTheLastTap`.
22. **Decided in 0.6x: kept** — a trip under way leaves the countdown and the reminders. Every packing step
    falls due on or before the first day, so there is nothing left to remind of; the trip's On site page
    is on the Trips tab (section 11).
23. **Resolved in 0.6x** — Make refuses a name any grab list already has, on its tile or as its title, and says
    so (section 8). Pinned by `testANameAlreadyInUseIsTaken` and `testAnEmptyGrabListSaysHowToFillIt`. No
    length limit: the tile shrinks a long word to fit, and only a share cuts it (to the web app's 14).
24. [idea] **Left in 0.6x** — **All own lists share one `meta` record**, as do all "only sometimes" marks; the
    Home arrangement is two records (item 34). Offline edits on two devices: the later device wins for all of
    them (the web app's v120 lesson in `docs/store.md`). Storing them one by one would change how both
    devices store and back up his lists (a migration on each, while the other may still run the old build),
    for a case that needs both devices editing grab lists while both are offline.
25. **Resolved in 0.6x** — ~~Dead code: `GrabStore.state(_:items:)`.~~ Removed. (`bringOn`'s "fewer than 8"
    branch is the normal way back onto Home since 0.61.)
26. [idea] No keyboard shortcuts anywhere: Escape closing a sheet on the Mac is neither wired nor tested.

**Untested and unguarded.**

27. **Resolved in 0.6x** — ~~A trip with `status == "done"` but no `reviewedAt` is excluded untested.~~ Pinned by
    `testATripMarkedDoneIsNoCountdownEvenUnreviewed`.
28. **Resolved in 0.6x** — ~~Sheet collisions: a Shortcut or a tapped reminder fired while another Home sheet is
    open may not present.~~ Home closes its sheets first (`whenFree`, section 3). Pinned by
    `testAShortcutOrReminderOpensItsPlaceWhileAnotherWindowIsUp`.
29. **Resolved in 0.6x** — ~~`GrabScreen` falls back to Indoor swim when its list disappears while open.~~ It
    closes, still showing the list, and never saves under another list's key (section 6). Pinned by
    `testAGrabListGoneWhileOpenClosesInsteadOfBecomingAnother`.
30. **Resolved in 0.6x** — ~~The grab counter can exceed the list ("8 of 7").~~ It counts against the list as it
    stands (`inHand`, `skippedCount`). Pinned by `testTheCountIsOfTheListAsItStands`.

**His standing rules.**

31. [rule-break] **Text sizes under the 15-pt reading floor** stated in `Headings.swift` ("Nothing under 15"):
    - "1 in 10" 12;
    - "only sometimes" / "not this time" 13;
    - the Grab Lists pills 13, and "<k> things" 13;
    - Search's headings 12, under-lines 13 and "more" line 13;
    - the tile labels 14, "Grab Lists" 14, "This Device" 12, the count-tile labels 14;
    - the tab labels 12.5, and the version 11.
    (The new "Delete grab list" button is 15, through `SmallDeleteButton`'s `size`.)

**Added in 0.61 (the grab-list fixes).**

32. **Resolved in 0.6x** — ~~A waiting list cannot be opened from Grab Lists.~~ A tap on the waiting row opens
    it; "On Home" is its own button (`grablists-on-<n>`), and the made line says both (section 8). Pinned by
    `testAGrabListTakenOffHomeStaysOff`.
33. [idea] **Left in 0.6x** — **Arrangements stored before 0.61 are not migrated.** They have `grabHome` but no
    `grabOff`, so until he next arranges Home (a move, Off Home, a swap, putting a list on) every list not in
    `grabHome` counts as new and fills a free place the old way — for example the place a deleted list
    leaves. Pinned as intended by `testHisArrangedSixAreJoinedByTheNextTwo`. Left because such an
    arrangement cannot tell a list that waited only because Home was full from one made since; guessing
    could hide a list he expects to see, and one rearrangement settles it for good.
34. [idea] **Left in 0.6x** — **Two devices: the Home arrangement and the off list are separate `meta` records**,
    settled one by one (later write wins per record). Offline arranging on both devices can pair one device's
    `grabHome` with the other's `grabOff`: a list in neither then counts as new and is pulled into a free
    place, a list in both stays on Home. No test covers two devices. Left because joining them into one
    record changes the stored shape that the other device's older build reads; the worst case is one list
    on or off Home, which one press settles.
35. **Resolved in 0.6x** — ~~The made line outlives a swap.~~ A pick in the swap sheet clears it. Pinned by
    `testMoreGrabListsThanHomeHolds`.
36. **Partly resolved in 0.6x** — `deleteOwnGrabList` now also removes the id from `grabOff`, so neither the
    library nor a later backup keeps it (`testADeletedListLeavesNoTraceInTheArrangement`). [idea] Left: the
    OTHER device keeps its stored ticks (`ams.grab.<id>`) — a few bytes, never read, meaningless after 6
    hours; removing them safely needs a moment when that device's library has certainly arrived in full.
37. **Resolved in 0.6x** — ~~Home can end up with no grab tiles, the heading over nothing.~~ Kept his choice
    (every list may go off Home), but Home then says where they are, and that line opens Grab Lists
    (`home-grab-none`, section 3). Pinned by `testHomeWithEveryGrabListOffSaysWhereTheyAre` and
    `testEveryListCanWaitOffHome`.
