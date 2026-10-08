# Trips — from creating one to after it

> Verified against the code on 5 Oct 2026 (app 0.60). Every open question of this area was then
> settled on branch `work/trips` (release 0.62); the sections below say what the code does now.

A **trip** (the code and the web app call it an *event*, Swift type `TripEvent`) is one journey: a
name, optional dates and place, the templates it is built from, and the **list he packs from** — a
set of self-contained *lines* (`Item` values in `trip.entries`) copied from those templates when the
trip is made. This file covers the whole life of a trip:

- **Plan** — *Create new trip* on the Home tab (name, Full trip | Quick, Dates, templates, Context per
  workout, Transport, Season, Food, Laundry) and how the list is built from the templates.
- **Pack** — the Trips tab (`EventsScreen`), the trip screen (`TripScreen`): ticking, "not this
  time", sorting When / Into / From where / Category / Section (Section and the Sorting drop-down since
  0.64), folding, Set place, adding a thing,
  Tick everything / Clear every tick, Check before you go, the weather card, the Bags card (luggage
  scale, cabin, photos), Trip settings, Start a new trip from this one, Save as Excel, Share, Delete —
  and, on the iPhone, Pack by voice (0.71, a test; spec 07 part 10).
- **On site** — the On site page (bought, left, maintenance notes) and Pack to go home.
- **Review** and **Refine** — the trip review and the Refine screen that learns from several reviews.
- The **loop** strip and picture (Plan › Pack › On site › Review › Refine).

The app is ONE SwiftUI target for iPhone and Mac. Every screen opened from a trip is a `.sheet`
(a sheet on the iPhone, a sheet window on the Mac).

**Ways in:** Home → *Create trip* opens the new trip; Trips tab → a trip row; Home → the countdown
card (next trip); a tapped packing reminder; the Shortcut "Open my next trip" (and the Action
button); Search (a trip result). See "Other ways into a trip" below.

Conventions in this file: "green" = `AppSection.events.color` #2f9e63, "blue" = `AppSection.home.color`
#2f6fe0, "violet" = `AppSection.templates.color` #7c5cd6, "orange" = `AppSection.care.color` #dd7324,
"red" = `AppSection.actions.color` #dc3d43; `Theme.ink/muted/line/card/bg` are the light/dark pairs in
`App/Sources/Theme.swift` — all listed in `docs/colours.md`, not repeated here. "HeaderButtonStyle
filled" = capsule filled with the tint, white 17 pt bold text (16 until 0.62, spec 06 §20); "outlined" = tint text on 10 % tint,
1.4 pt tint stroke (`App/Sources/Buttons.swift`). Font sizes are points, `.system` font.
Text comparison "normName" = trimmed, lower-cased, inner whitespace collapsed (PackingCore).
"jsTrim" = JavaScript `trim()` semantics.

The invented sample library (`App/Sources/Store/SampleLibrary.swift`) is used in examples: templates
*Common base* (base: Passport, Phone charger, Toothbrush, Headlamp), *Hiking* (GA: Hiking boots,
Rain jacket, Headlamp, Map), *Swim* (WET: Goggles, Swim cap, Towel — Towel is per night), and the
trip *Weekend in the hills* (Hiking + base, always 30–32 days from the day the tests run, 7 lines).

---

## The data a trip is made of

**Purpose.** The model behind every screen in this file. Shape ported from the web app's
`js/model.js` (`coerceEvent`, `newEvent`) — `Core/Sources/PackingCore/Events.swift`.

### `TripEvent` fields (all JSON keys; defaults are `newEvent`'s)

| Field | Type / default | Meaning |
|---|---|---|
| `id` | String, `PackingEnv.makeId()` | stable id |
| `name` | String, "" | shown name ("Untitled event" is drawn when empty) |
| `mode` | "trip" (default) \| "quick" | quick = only ticked templates, no base, no transport kit. `coerceEvent` turns anything not "quick" into "trip" |
| `activities` | [String] | template ids ticked for this trip, in the order offered |
| `transport` | "Car" (default) \| "Plane" \| "RV" (`TRANSPORTS`) | |
| `season` | "Summer" (default) \| "Winter" (`SEASONS`) | |
| `contexts` | [String] ⊆ "Indoor","Outdoor","Race" (`CONTEXTS`) | the trip-wide Context: narrows a WET template that has NO entry in `activityContexts` (every trip made before 0.67, and the web app's). Since 0.67 the screens write here every context picked for ANY workout (`WorkoutContexts.union`) — what a device still on 0.66, or the web app, reads |
| `activityContexts` | [String: [String]], [:] — **native only (0.67)** | Context PER WORKOUT, template id → its contexts (his ask, 6 Oct 2026: "it could be outdoors Run and indoors Swim"). A WET template with an entry is narrowed by ITS entry (an empty entry narrows nothing); without one, by `contexts` (`contextsFor`). JSON key `activityContexts` (`ACTIVITY_CONTEXTS_KEY`), an object of lists; written ONLY when not empty, so a trip without it reads and writes exactly as before (the parity checker stays 211/211). Read by `coerceActivityContexts`: anything but an object = no entries; an empty id is dropped; a value that is not a list = an empty list. Carried by the sync records (the trip head is its JSON), backups, a shared link or file, and Start again |
| `weatherOn` | [String] ⊆ rain/cold/hot/wind/snow | conditions "forced on": weather-tagged gear is packed regardless of forecast. Filtered to `WEATHER_CONDITION_IDS` by `coerceEvent`. Set in Trip settings, "Pack weather gear anyway" (0.62) |
| `catering` | "mixed" (default) \| "self" \| "eatout" (`CATERING`) | the "Food" pills |
| `startDate`, `endDate` | "YYYY-MM-DD" or "" | |
| `nights` | Int ≥ 0 | derived from the dates on create / settings save (`nightsBetween`); 0 when undated |
| `laundry` | Bool | Laundry switch |
| `destination` | String | the trip's place ("Place" in Trip settings, the weather field) |
| `weather` | `WeatherSnapshot?` | cached forecast: `{place, lat, lon, fetchedAt, daily:[{date, code, tmax, tmin, precipProb, wind}]}`; `coerceWeather` drops days without a date and a snapshot with no days |
| `geo` | `GeoFix?` `{lat, lon, place}` | map pin; nil unless both coordinates are finite and in range |
| `entries` | [Item] | the lines, in list order |
| `status` | "active" \| "done" | "done" = reviewed |
| `reviewedAt`, `generatedAt`, `createdAt`, `updatedAt` | ISO strings | |
| `extra` | [String: JSON] | every unknown key, kept on round trips |

**Extra keys on a trip** (kept in `extra` so the web app's model is untouched):

| Key | Constant | Value | Written by |
|---|---|---|---|
| `laundryNights` | `LAUNDRY_NIGHTS_KEY` | number 1…60 | Create trip, Trip settings, Start again |
| `weighed` | `WEIGHED_KEY` | `{ "<bag name>": grams }` | luggage scale (`setWeighed`) |
| `bagPhotos` | `BAG_PHOTOS_KEY` | `{ "<bag name>": ["<photo id>", …] }` (0.52/0.53 wrote one plain string id; read as a list of one) | bag photos |
| `leaveAt` | `LEAVE_AT_KEY` | "HH:mm" (0.69) — the time he leaves on the first day; absent = none | Create trip, Trip settings ("I leave at") |
| `leaveHomeAt` | `LEAVE_HOME_AT_KEY` | "HH:mm" (0.69) — the time he leaves for home on the last day | Create trip, Trip settings |

Neither leave time is copied by Start again (a new trip has no dates); both travel in a shared trip (the
people he shares a trip with leave with him). See "The door check".

| `missedAtReview` | `MISSED_AT_REVIEW_KEY` | `[{ "name", "template" }]` — the missed things as the review saved them; `template` = the template's shown name, "" = on no template (0.70) | `saveReview` |
| `vaultWaiting` | `VAULT_WAITING_KEY` | ISO moment a page in his Obsidian vault was asked for (0.70) | `saveReview`; the iPhone's Send to Obsidian (`askForVaultPage`); taken away by `vaultPageWritten` |
| `vaultWritten` | `VAULT_WRITTEN_KEY` | `{ "file", "at" }` — the page the Mac wrote last (0.70) | the Mac (`vaultPageWritten`) |
| `healthWorkouts` | `TRIP_WORKOUTS_KEY` | `["Swim · indoor · 3 times", …]` — the review's "From Apple Health" rows as shown (0.70) | Save review on the iPhone (`setHealthWorkouts`; nothing read writes nothing) |

The four 0.70 keys are his: a shared trip leaves them behind (`justTheList`), Start again never copies them.
Spec 07 part 8 has the page they serve.

### A line (`Item` used as a trip entry)

The same `Item` struct serves catalogue items, resolved template rows and trip lines
(`Core/Sources/PackingCore/Items.swift`). Fields that matter on a line: `id`, `name`, `swedish`,
`qty` (free text), `category`, `container` (the bag, by NAME), `phase` (the "When" id), `itemType`
("item" \| "reminder"), `charging`, `chargeType`, `shortList`, `sub`, `note`, `weight` (grams per
unit), `liquid`, `restricted`, `perNight`, `section` (the section's DISPLAY NAME), `kit` (kit name),
`packer`, `storage` (where it is kept at home), and the trip-only fields `sourceListId`,
`sourceItemId` (the catalogue item's id), `custom` (typed on the trip), `checked` (packed), `skipped`
(set aside — "not this time"), `used` (review answer, nil = not answered), `edited` (JSON `_edited`).

**Extra keys on a line:**

| Key | Constant | Meaning |
|---|---|---|
| `boughtThere` | `BOUGHT_ON_SITE_KEY` | true = bought on site. The STORED key keeps its first name ("Bought there" until the 3 Oct 2026 field test) so older marks still read |
| `packedHome` | `HOME_KEY` | ticked for the way home |
| `usedUp` | `USED_UP_KEY` | used up / left on site |
| `homeNote` | `HOME_NOTE_KEY` | maintenance note on this line |
| `packedAt` | — | the web app's packing time; removed by Start again, left out of a share |
| `pocket` | `POCKET_KEY` | (0.69) the pocket of the line's bag it went into on the way out; removed by Start again, left out of a share |
| `homePocket` | `HOME_POCKET_KEY` | (0.69) the pocket it went into for the way home; removed by Start again, left out of a share |

**Extra keys on a bag (a thing on the bag list):** `cabin` (`CABIN_KEY`, Bool) — "Goes in the cabin";
`pockets` (`POCKETS_KEY`, 0.69) — its pockets' names, in his order (absent = no pockets).
**Extra key on a thing:** `usualPocket` (`USUAL_POCKET_KEY`, 0.69) — the pocket of its usual bag it usually goes
in. All of these are absent until he uses pockets, and an absent key changes nothing (`PocketsTests.testAnAbsentPocketChangesNothing`).

### How a trip is stored and synced

`Library.records()` (`Core/Sources/PackingLibrary/LibraryRecords.swift`; the store itself is in
`docs/store.md`):

- table **`trips`**, key = trip id: the trip's JSON WITHOUT `entries`, plus `entryOrder`: the line
  ids in order.
- table **`entries`**, key = `"<tripId>|<entryId>"`, parent = trip id: one record per line.
- photos (bag photos) are `photos` records with the JPEG bytes as the blob.

So **a tick is one small record** (`testATickIsOneSmallRecord`): `setChecked` and `setAside` change
only the line, never the head, so two devices ticking different lines both win. On load
(`Library(records:)`), lines are placed in `entryOrder` order; a line missing from the order (added
on the other device while this one wrote the head) is appended, sorted by record key
(`testALineTheTripHeadHasNotHeardOfIsStillShown`). A line whose trip head has not arrived yet is not
shown. Duplicate (table, key) records are settled by newest `updatedAt`, then content
(`settleDuplicates`). Writes that also touch the head (because they set `trips[t].updatedAt` or a
trip field): `addCustomLine`, `setPlace`, every way-home mark, `setWeighed`, bag photos,
`changeTrip`, `setWeather`, `setPlace(tripId:lat:lon:label:)`, `followThing`.

🪤 **One id twice on a trip is fatal**: the entry record key would collide and the Mac app stopped on
it (E.6 crash, 28 Sep 2026). `Library.regenerated` re-ids any duplicate; `TripScreen` builds its
index with "first wins" so it never traps.

### Tests
`EventsTests` (coerceEvent/newEvent/laundry flag/round trip), `LibraryTests.testRecordsRoundTrip`,
`testATickIsOneSmallRecord`, `testALineTheTripHeadHasNotHeardOfIsStillShown`,
`testTwoRecordsWithOneKeySettleTheSameWayOnBothDevices`, `testTheStoreOnlyEverSeesTheDifference`.

---

## Create new trip (Home)

**Purpose and origin.** "Home: build a trip. Name it, add the dates, pick what it is — press
Create." (`App/Sources/Screens/HomeScreen.swift`). Dates like Booking.com (his example, 2026-09-26,
0.21); Dates and Quick on one line (0.16); short food words (0.16); the Create button always in full
colour (his words 2026-09-26: "The create button is something that is central to the whole app, and
you make it grayed out.", 0.26); workout colours and Context set in under them (2026-09-28, 0.40);
Laundry (0.35) with a nights choice (0.47); headings dominant (field test 3 Oct 2026, 0.57). **0.67**
(his test of 0.63, 6 Oct 2026): the date picker always there, no Dates switch ("I would like the date
picker to be present all the time, and then take away the Dates checkbox."); Quick as Full trip | Quick
under the name ("I would like the Quick check box to be placed somewhere else - more thought
through."); Context per workout ("the same context menu is needed for all WET activities. Example: it
could be outdoors Run and indoors Swim.").

**How it is reached and left.** Home tab, under the grab lists and the countdown card. It is not a
sheet; *Create trip* makes the trip and opens it at once as a sheet (`opened = made.id`).

### What is on screen (top to bottom, inside one card: padding 14, corner 14, `Theme.card`, 1 pt `Theme.line` stroke)

Above the card: heading **"Create new trip"** (Title 3 bold, ink — 22 heavy before 0.62), id `home-create-heading`.

1. **Name field** — placeholder "Name your trip", 20 semibold ink, min height 48, `Theme.bg` fill,
   corner 10; a 2 pt red border only while the "still needed" message mentions "name". Id `trip-name`.
   Gets keyboard focus when Create is pressed without a name.
2. **Full trip | Quick** (`TripKindChoice`, 0.67) — a two-way choice in one capsule track (`Theme.bg`
   fill, 1 pt `Theme.line` stroke, 2 pt inner padding, at most 360 wide): two equal segments "Full
   trip" (id `trip-kind-full`) and "Quick" (id `trip-kind-quick`), Subheadline — semibold white on a
   blue capsule when picked, regular ink on nothing when not; min height `Metrics.chip` (28 / Mac 22);
   the picked one carries `.isSelected`. Full trip is picked to begin with. Under it, always (whichever
   is picked), one quiet line (Footnote, muted, id `trip-kind-note`): "Quick packs only the templates
   you tick — no common base, no transport kit. Transport still counts." (The last sentence: field
   test 5.1/6.1, 3 Oct 2026 — Transport had looked switched off.) Until 0.67: a "Quick" switch at the
   end of the Dates line (id `trip-quick`) and, only while it was on, a green framed note
   (`QuickNote`, id `trip-quick-note`, his test C.7) — both gone.
3. **Dates: the month grid itself, always OPEN** (`DateRangePicker(inline: true, grid: "trip-range")`,
   0.67 — his words: "I would like the date picker to be present all the time, and then take away the
   Dates checkbox", then the same evening "always having the date picker OPEN in Create new Trip").
   No field, no OK, no Cancel: the heading "Dates" (Subheadline semibold blue, id `trip-dates-title`),
   the month (two side by side when ≥ 600 wide — the Mac), only the weeks the month needs, day cells
   `Metrics.compact` tall (32 / Mac 24), 2 pt between rows; under it one line — "No dates" (muted),
   "Now tap the last day" (muted) or "9 Oct – 11 Oct · 2 nights" (ink; Subheadline semibold mono, id
   `trip-range-summary`) — with **Clear dates** beside it on the right while there are dates (id
   `trip-range-clear`). The first tap is the first day, the second the last — set at once. Grid ids
   `trip-range-day-YYYY-MM-DD`, `trip-range-title-<n>`, `trip-range-prev`, `trip-range-next` (Trip
   settings' grid keeps `range-*`; the two would otherwise share names while Trip settings is open over
   Home). Until 0.67: a "Dates" switch (`trip-dates`) showing the field and its grid. See the next
   section.
5. **One block of pills per activity group** that has templates, in `GROUPS` order (GA, WET, OE) — and,
   last, **"OTHER TEMPLATES"** for templates with no activity area (0.62; see "Templates offered").
   Heading: `groupHeading(id, label)` = "GA · GOAL ACTIVITY", "WET · WORKOUT, EXERCISE & TRAINING",
   "OE · OTHER EVENTS" (code, " · ", label upper-cased) as `HeadingTitle` (20 heavy violet with a
   4×18 violet capsule mark). Every group heading has the SAME id `trip-activity-title`.
   Pills: one per template, label = template name; ids `trip-activity-<n>` where n counts across ALL
   groups in the order offered (so "trip-activity-0" names one pill). Order inside a group:
   `orderActivities` — for WET the names Swim, Bike, Run, Strength, Mobility, Breath work first (in
   that order, matched by normName), everything else after, A–Z. WET pills carry `WorkoutTone`
   colours by normName with spaces removed: swim #0a84ff/white text, bike #ffd60a/#3d3000,
   run #30d158/#0b3a17, strength #ff8c1a/#4a2300, breathwork #bf9cff/#2e1a5c,
   mobility #ff6fa8/#5a0f2e; others (and GA/OE) use violet. Multi-select toggles.
6. **Context, per workout** (`WorkoutContexts`, 0.67; only when at least one WET template is ticked),
   placed DIRECTLY under the WET pill block — so above the OE block when there is one, not after all
   the groups — set in 18 pt with a 3 pt `Theme.line` bar down its left side (10 pt gap): question
   heading "Context" (Subheadline semibold ink), id `trip-context-title`; then ONE LINE PER TICKED
   WORKOUT, in the order offered: the workout's name (Subheadline semibold, in its `WorkoutTone`
   colour made readable — darkened on a light screen, lightened on a dark one, `readableHex` — or ink
   for a workout with no colour; up to 2 lines, scales to 0.8; a column `Metrics.contextName` wide,
   72 / Mac 64), id `trip-context-<n>-name`, then its own pills Indoor, Outdoor, Race (Subheadline,
   semibold when picked; padding 10 sideways, min height `Metrics.chip`; picked = slate
   `AppSection.settings.color` #64748b fill and white words; not picked = `Theme.bg`, 1 pt line), ids
   `trip-context-<n>-0…2`, several at once, picked = `.isSelected`. **n = the workout's own number
   among the template pills** (`trip-activity-<n>`), so Swim's line in the sample is
   `trip-context-1-*`. Each line's picks are its own. Until 0.67 one set of pills
   (`trip-context-0…2`, `ContextPills`) narrowed every workout.
7. **Transport** pills Car, Plane, RV (`trip-transport-0…2`), single choice, blue; heading id
   `trip-transport-title`.
8. **Season** pills Summer, Winter (`trip-season-0…1`); heading id `trip-season-title`.
9. **Food** pills (`trip-catering-0…2`) with his short words: "Self-sufficient" (self),
   "Eating out" (eatout), "Mix of both" (mixed) (`HomeScreen.shortFood`; the model keeps the web app's
   longer labels). Heading id `trip-catering-title`.
10. **Laundry switch** — see "Laundry" below; id prefix `trip-laundry`.
11. **"Create trip"** button: 18 bold white on BLUE, full width, min height 52, corner 12, id
    `trip-create`. Never disabled, never grey.
12. **Still-needed line** (only after a press with something missing), 15 bold red, centred, id
    `trip-create-needs`.

Pills (`Pills` view, shared with Trip settings): 15 pt, bold when picked / medium when not; picked =
filled with the tint (or tone) and white (or tone ink) words; not picked = `Theme.bg` fill, ink words,
1 pt `Theme.line` stroke (a toned pill: 1.8 pt stroke in its tone). Min height 36, horizontal padding
12, they wrap (`FlowRow`, spacing 6). A picked pill carries the `.isSelected` trait. Identifier =
`<id>-<position>`, never words.

Below the card: "This Device" (written so, not upper-cased; 12 heavy muted, kerning 0.5, rotated −90°,
id `device-heading`) and three count tiles — Trips, Things, Templates (ids `count-trips`,
`count-things`, `count-templates`) — belong to the Home spec.

### Behaviour

- **Still needed** (`needs()`): name blank (jsTrim) AND no template → "Give the trip a name and pick
  at least one template."; name blank → "Give the trip a name."; no template → "Pick at least one
  template."; else "" — and, after any of these, "Tap the trip's last day — the same day again for a
  day trip." while only the first day is tapped (0.67: Create never makes a day trip by accident; the
  grid tells Home through `onWaiting`). The line appears only after a press of Create; from then on it
  follows every change of the name, the template pills or the grid, and disappears when nothing is
  missing.
- **Create** with something missing: nothing is made; the line says what; a missing name focuses the
  name field.
- **Create** with name + ≥1 template: a draft `newEvent(name: jsTrim(name), mode: quick ? "quick" :
  "trip")` gets transport, season, catering, laundry, `extra.laundryNights = laundryNights`,
  `activities` = the ticked template ids **in the order offered** (not tap order),
  `activityContexts` = an entry for EVERY ticked WET template (`WorkoutContexts.stored`: its picks in
  `CONTEXTS` order, Indoor, Outdoor, Race; nothing picked = an empty entry, which narrows nothing) —
  picks for a workout ticked off again are not saved — and `contexts` = every context picked for any
  workout (`WorkoutContexts.union`, for a device still on 0.66 and the web app). With dates picked:
  `startDate = ymd(start)`, `endDate = ymd(max(start, end))`, and (0.69) the "I leave at" times as
  `extra.leaveAt` / `extra.leaveHomeAt` ("" = none); with none, both stay "" and no time is kept.
  `Library.createTrip(draft)` then: `coerceEvent`, an id if empty, `nights = nightsBetween(start,
  end) ?? 0`, `entries = buildTotalEntries(trip, resolvedTemplates())`, `generatedAt = createdAt =
  updatedAt = now`, appended to `trips`.
- After creating: name, templates, each workout's contexts, the dates (back to "No dates"), Quick (back
  to Full trip), Laundry and laundry nights are reset;
  **Transport, Season, Food and the two dates are NOT reset** (they stay as last chosen until the
  view is rebuilt). The new trip opens as a sheet. Kept so on purpose (the spec pass, 5 Oct 2026):
  the next trip is usually the same car and the same season, and the pills show the answers before
  Create is pressed.
- There is **no Place field** on Create new trip, on purpose (same decision): the trip opens at once
  and its weather card asks "Where is this trip?" first thing; Trip settings has Place too.
- Date strings: `HomeScreen.ymd` formats in the device's time zone, Gregorian, en_US_POSIX — the
  picker's dates are local midnights, so the day picked is the day stored.
- Initial dates (before any pick): NONE — the line under the grid says "No dates" and a trip created
  without a tapped day has no dates (0.67; the same as the old Dates switch left off). The grid opens
  on this month. The two `Date`s behind it
  start at now and now + 2 × 86 400 s but are stored only once a day has been tapped. The date picker
  here uses the default tint (blue, `AppSection.home.color`); Trip settings passes green.

**Model rule vs screen rule.** The model (`createTrip`) needs no template: a full ("trip") trip with
no ticked template still gets the base and transport templates. The screen always requires one.

**Templates offered** (`Library.activityChoices()`): resolved templates with `role == ""` whose
`group` is one of GA, WET, OE, grouped and ordered as above — then, last, every `role == ""` template
whose group is empty or unknown, A–Z, as a group with id "" and label "Other templates" (heading
"OTHER TEMPLATES", violet; pills numbered on from the others). The web app offers such lists last
("Other lists"); until 0.62 they were never offered here although A new template offers "No activity
area" (the spec pass, 5 Oct 2026). The base, transport, container ("Bags") and loose roles are never
offered.

**Always packed is a choice, not a fixed template (0.71).** Every template with role "base" comes on every Full
trip (`listsForEvent`: all of them, in template order, before the transport template and the ticked ones; the first
wins a name+bag clash); Quick leaves them all out. A template is moved into or out of Always packed on its page
(spec 04, Activity area; `setTemplateArea`): moved out, it is offered here like any activity template and comes only
when ticked; moved in, it is no longer offered. None always packed is allowed — the screen still asks for one ticked
template. Trips already made keep their lines; their next Trip settings Save rebuilds them by the new roles. "Make a
small core from this…" (spec 04 §14b) makes a new always-packed template from part of a big one and moves the big
one out in one step. Tests: `TemplateFacesTests.testATemplateMovesIntoAndOutOfAlwaysPacked`, UI
`testATemplateMovesOutOfAndIntoAlwaysPacked`.

### Data
Writes one `trips` record and one `entries` record per line. AppStorage: none.

### iPhone vs Mac
Same view. On the Mac the screen column is at most 720 pt wide (`RootView`). The new trip opens as
a sheet window.

### Tests
UI: `testHomeBuildsATrip` (Create never greyed; early press says "Give the trip a name and pick at
least one template.", then "Pick at least one template." after typing; the line goes; the trip opens
with lines; it is listed as `trip-row-1`), `testDatesArePickedLikeBooking` (0.67: the grid open at once,
no field, "No dates"; first day → "Now tap the last day", last day → "<d> – <d> · 2 nights" with no OK; a
tap after a range starts a new one, an earlier day becomes the first; Create with only the first day says
"last day" and makes nothing; the last day tapped, the line goes and the trip keeps its dates — red with
the grid hidden until a tap: "the month grid is not open on Create new trip", and with Create not waiting
for the last day: "Create with only a first day did not ask for the last: ''"),
**0.69:** `testCreateNewTripTakesTheTimeHeLeaves` (no "Add a time" without days; two days picked → both
times added, "Check 07:15" / "Check 09:45"; the trip made shows them again in Trip settings — red with the two
`setLeaveTime` lines planted out of `create`: "the trip made did not keep the time he leaves"),
`testContextSitsUnderTheWorkouts` (Context absent until a WET pill, below the workouts,
above Transport, Swim's pills `trip-context-1-*` set in > 24 pt), `testTheDateGridCanBeLeftAndQuickSaysSo`
(the Quick line is there with Full trip AND with Quick picked), `testABagOnTheTripSaysWhetherItGoesInTheCabin`
(`trip-kind-note` contains "Transport still counts"), **0.67:** `testFullTripOrQuickIsChosenUnderTheName`
(Full trip picked to begin with, no `trip-quick` switch, the choice under the name and before the dates
with its line under it; a Quick Hiking trip is 0/4; Trip settings shows Quick, and Full trip there makes
it 0/7 — red with Quick ignored on Create: "Quick did not leave out the common base: '0/7'"),
`testDatesAreAlwaysThereAndCanBeCleared` (below), `testEachWorkoutHasItsOwnContext` (`-uiTestingWorkouts`:
a Quick trip of Swim indoors and Run outdoors is 0/5 — Goggles, Swim cap, Towel, Trail shoes, Running cap;
each line keeps its own picks; Trip settings shows them, Swim outdoors brings the Wetsuit, 0/6, and does
not touch Run — red with every workout given all the picks: "each workout was not packed by its own
Context: '0/7'"),
`testLaundryCountsPerNightThingsFourNightsAtMost`, `testTheEditorsLeadWithTheirHeadings` (heading ids
exist), `testATemplateWithNoActivityAreaGoesOnATrip` (a "No activity area" template is `trip-activity-2`,
a Quick trip is made of it). Model: `CreateTripTests.testATripIsBuiltFromItsTemplatesAndTheBase`,
`testAQuickTripSkipsTheBase`, `testTheChoicesAreHisGroupsInHisOrder` (GA, WET, then "Other templates");
`WorkoutContextsTests` (PackingCore, 0.67: each workout narrowed by its own; the fallback to the trip's
`contexts`; an empty entry narrows nothing; an entry for a non-WET template changes nothing; the JSON round
trip, no key when empty, junk read as nothing; a shared file and link carry it) and
`WorkoutContextsLibraryTests` (made, changed in Trip settings with 1 added / 1 removed, kept by the sync
records and a backup, copied by Start again).
**Not covered:** that Transport/Season/Food survive a create; that a workout's picks are dropped when it
is ticked off before Create; the trip-wide `contexts` written as the union; the red name border.

### Traps and history
- The heading of every group shares one identifier (`trip-activity-title`); tests use `firstMatch`.
- 🪤 The Mac folds a button's texts into the button: identifiers that must be read sit on texts
  outside buttons, or the words are given as the button's value.

---

## The date range picker (`DateRangePicker.swift`)

**Purpose and origin.** "The trip's dates, the way Booking.com picks them — his example
(2026-09-26): one field saying "Sat 26 Sep — Sun 27 Sep · 1 night", and under it a month grid,
Monday first: tap the first day, then the last." Cancel added for his test C.2 (0.40: "I do not come
out of this date"); OK/Cancel and staying open after the last day from the field test, Oct 2026
("When I choose the end date, don't just pop out back, but stay there and present an OK button or a
cancel button", 0.56). Replaced the two From/To date wheels (0.21). **Always on the form since 0.67**
— his words (6 Oct 2026): "I would like the date picker to be present all the time, and then take away
the Dates checkbox." — with a no-dates state and **Clear dates**, which took over the one thing the
switch did that nothing else could: take a trip's dates away. The same evening, for Create new trip:
"always having the date picker OPEN in Create new Trip" — the **inline** grid.

**How it is reached and left.** Two forms of one view:
- **Inline** (`inline: true`, Create new trip, under Full trip | Quick): the grid itself, always open —
  no field, no OK or Cancel; described under Create new trip, item 3. It shares the month, the day
  cells and the tapping rules below; it adds `onWaiting` (Home's Create waits for the last day).
- **With a field** (Trip settings, under Place): the field below, its grid CLOSED (`open` defaults to
  false). The field toggles the grid; OK, Cancel and Clear dates close it. (Until 0.67 Create new trip
  had this form too, its grid opened at once under a Dates switch.)

### What is on screen

1. **The field** (the field form only — Trip settings; a button, id `<id>-field` = `tripset-dates-field`:
   the parameter `id`, default "trip-dates", which the inline grid uses only for its heading
   `trip-dates-title`. Until 0.67 the field was `trip-dates-field` in both places): calendar mark (24 pt, tint), a small caption "Dates" — or "Now tap the last day"
   while waiting for the last day — (Footnote semibold muted), then (Body semibold, one line, scales to
   0.8; id `<id>-label`): **"Add dates" in the tint while the trip has none** (0.67), else
   "Sat 26 Sep — Sun 27 Sep" in ink (em dash with spaces), or only the first day while waiting; on the
   right the nights "1 night" / "N nights" (Subheadline semibold muted, id `<id>-nights`), shown only
   with whole dates. Min height 56, `Theme.bg`, corner 10; border 2 pt tint while open, 1 pt
   `Theme.line` closed. Accessibility **value** = "No dates" (none yet), "Sat 26 Sep — Sun 27 Sep · 1
   night", or only the first day while waiting — the Mac folds the texts into the button, so tests read
   the value.
2. **The grid** (when open), a card (padding 12, corner 12) — ids `<grid>-…`, `grid` = "range" here:
   - One month, or **two side by side when the grid is at least 600 pt wide** (measured with
     `onGeometryChange`; in practice the Mac). With one month both arrows sit on it; with two, ‹ on
     the first and › on the second.
   - Month header: ‹ (id `range-prev`), title "September 2026" (17 heavy, id `range-title-<index>`),
     › (id `range-next`); arrows are drawn chevrons 22 pt in 40×36.
   - Weekday row "Mon Tue Wed Thu Fri Sat Sun" (12 heavy muted).
   - Day cells (min height 40), Monday first: blanks before the 1st; the month's days only (no days
     of the neighbouring months). Every month is drawn as **six rows** (`DateRangePicker.sixWeeks`: the
     blanks after the last day fill the rest), so the grid keeps one height from month to month and OK
     and Cancel never move under his finger (0.62; until then 4–6 rows, and the panel jumped). Day number 16 pt mono, bold when it is an end, in
     the range, or today. First and last day: filled tint rounded rectangle (corner 8), white
     number. Days between: a 14 % tint band edge to edge (the ends carry half-bands so the range
     reads as one stretch). Today (not an end): a 1.5 pt tint ring. Past days: muted number but
     still tappable. Id `range-day-YYYY-MM-DD`; ends carry `.isSelected`. With no dates yet no day is
     marked (only today's ring).
   - Under the grid one line (id `range-summary`, Body semibold mono, one line): "3 Nov – 5 Nov · 2 nights"
     (en dash, middle dot), "Now tap the last day" (muted) while waiting, or "Tap the first day, then
     the last" (muted) while the trip has no dates (0.67). When OK was pressed while
     waiting, this line is REPLACED by "Tap the last day first — the same day again for a day trip."
     (16 bold red, id `range-needs`).
   - Left, only while there are dates (0.67): **Clear dates** (Subheadline semibold muted, plain, min
     height `Metrics.header`, id `range-clear`) — quiet, and away from OK: Airbnb's place for it.
   - Right-aligned: **Cancel** (outlined, id `range-cancel`) and **OK** (filled, min width 44, id
     `range-ok`). OK is never disabled.

### Behaviour

- Opening (field tap): `month = ""` (shows the month of the first day) — or, with no dates yet, this
  month (0.67) — remembers the dates as they were AND whether there were any (`before`), clears the
  OK-too-soon state. (A picker made with `open: true` takes `before` on appear; neither form does
  since 0.67.)
- **Tap a day** (`pick`): clears OK-too-soon; the trip has dates from now on (`dated = true`). If waiting for the last day and the day ≥ the first day
  → it becomes the last day, waiting ends. Otherwise (no range yet, a day BEFORE the first while
  waiting, or any tap after a whole range) → start = end = that day, waiting for the last day.
  Tapping the first day again while waiting = a day trip (0 nights).
- **OK**: while waiting → stays open, shows the `range-needs` line; otherwise closes, keeping the
  dates.
- **Cancel**: puts back the dates from when the grid opened (even after a whole new range) — and an
  undated trip stays undated — stops waiting, closes.
- **Clear dates** (0.67): no dates at all (`dated = false`), stops waiting, closes; the field says "Add
  dates" again, and Create / Save stores none ("" and "", 0 nights). What switching Dates off did.
- **Field tap while open**: the same as **OK** (0.62) — with only the first day picked the grid stays
  open and shows `range-needs`; with a whole range it closes, keeping it. (Until then it closed at once,
  leaving a one-day trip and "Now tap the last day" on the field.)
- **Arrows**: shift the shown month by ±1 from the shown month (or the first day's month).
- Nights: whole calendar days between the local midnights of start and end (DST-safe), never below 0;
  "1 night" singular.
- Words are fixed English on every device ("Sat 26 Sep", "January"…), not the device language.
- With no Dates switch (0.67) the picker lives as long as its form; Create new trip resets only its
  `dated` after a create (the two `Date`s stay, unseen until a day is tapped).
- **Inline:** a tap is final at once (no OK); Clear dates leaves the grid open; the first month shown is
  the first day's, or this month with no dates; the arrows page from there.

### Data
Binds two `Date`s and `dated` (Bool: whether the trip has dates at all, 0.67) owned by the parent. A tapped day is the local midnight of that day; the parent's
initial values may carry a clock time (Home: now / now + 2 days; Trip settings on an undated trip:
now), which is harmless because only the day is ever compared (`startOfDay`) or stored
(`HomeScreen.ymd`). Writes nothing itself. Calendar: Gregorian, Monday first (`firstWeekday = 2`),
device time zone. Tint: a parameter (default blue; Trip settings passes green).

### iPhone vs Mac
Two months when ≥ 600 pt wide (Mac windows — Create new trip's inline grid too), one on the iPhone. Day
cells `Metrics.compact`: 32 / Mac 24. Otherwise identical.

### Tests
UI: `testDatesAreAlwaysThereAndCanBeCleared` (0.67: on Create new trip the grid open from the start —
red with it hidden until a tap: "the month grid is not open on Create new trip" — no switch, no field,
"No dates", no Clear dates; picked then Clear dates → "No dates" and the grid still open; a trip made so
has none in Trip settings, which has no `tripset-dates` switch; dates given there and saved, then
Clear dates and saved → "No dates" — red with Clear dates not clearing: "Clear dates did not take them
away: …'" — seen with the field form, before the grid on Home became inline), `testDatesArePickedLikeBooking`
(the inline grid: first then last day, "2 nights", "1 night", a day before the first becomes the first,
Create waits for the last day, the trip keeps the dates — its row writes them "27 Sep 2026" although the app
runs American-set (`-AppleLocale en_US`). **The four tests below run in Trip settings since 0.67** (the field,
OK and Cancel live there; `openTripSettingsDates` opens the sample trip's): `testTheDateGridCanBeLeftAndQuickSaysSo`
(OK before the last day keeps the grid and shows `range-needs`; Cancel restores the trip's dates),
`testTheDateGridWaitsForOK` (after the last day the grid stays, summary "3 Nov – 13 Nov · 10 nights"
form, OK keeps), `testTheDateGridStartsOverAndCancelPutsItBack`, `testTheDateGridClosesOnlyOnAWholeRangeAndStaysStill`
(the field with only the first day keeps the grid and shows `range-needs`; with a whole range it closes;
OK keeps its distance from the month title over six months of different week counts). The model's
`monthGrid`, `rangeCellState`, `orderRange` are tested in `DatesTests` but **the app does not use them**
— they are the web app's, held to it by the parity checker; the app draws its own steady six rows.
**Not covered:** two-month layout, past-day tapping.

### Traps and history
- Plain rows, not a lazy grid: a lazy grid builds only what is on screen (the care calendar's lesson
  on the Mac, 0.18).
- The field's words travel as its accessibility value (Mac UI test on GitHub, 0.21).

---

## Laundry (`Laundry.swift`, `Counting.swift`)

**Purpose and origin.** The web app's "Laundry available on this trip": wash and wear again, so
per-night things (socks, underwear, tees) count a cycle's worth instead of one per night (0.35). The
nights choice is his idea of 2 Oct 2026 (0.47): "a two-month stay may want 7".

### What is on screen (`LaundrySwitch`, used on Create new trip with id `trip-laundry` and in Trip settings with id `tripset-laundry`)

- Toggle with a drawn washtub (24 pt, green) and "Laundry" (16 semibold ink), id `<id>`.
- Under it, its own text (14 muted, indented 34), id `<id>-says`: on → "Wash and wear again:
  per-night things count N nights at most."; off → "Wash and wear again, so you pack fewer per-night
  things." (A separate text because the Mac folds a switch's words into the switch.)
- Only while on: question heading "Pack for this many nights, then wash" (17 heavy ink, id
  `<id>-nights-title`, indented 34) and pills **3, 4, 5, 7, 10, 14** (`LaundrySwitch.choices`,
  `<id>-nights-0…5`, green), single choice. Default 4 (`LAUNDRY_CAP_NIGHTS`). A trip whose stored
  `laundryNights` is not one of the six (e.g. 6 from the web app or a backup) shows NO pill lit until
  one is tapped; Save then writes the shown value unchanged.

### Behaviour (model)

- `laundryNights(trip)` = `extra.laundryNights` if it is a finite number with 1 ≤ n ≤ 60 (taken as
  Int), else 4.
- `qtyNights(trip)` = the nights used for counting: `laundry && nights > laundryNights` ?
  laundryNights : nights. A short trip is never raised to the cap.
- `laundryWashes(trip)` = `laundry && nights > laundryNights` — judged against the trip's OWN nights:
  a 6-night trip packing for 7 washes nothing and shows no washtub.
- `effectiveQty(line, n)`: a per-night line with n > 0 counts n; otherwise `qty` read with JS
  `Number()` semantics (`jsParseNumber`: "2" → 2, "2.5" → 2.5, "0x10" → 16, "1 pair" → NaN); a
  finite number > 0 is used, anything else counts 1. So "0" counts 1.
- Every count, bag weight and the Excel file use `qtyNights` (the trip's real `nights` stay as they
  are).
- On a line: "×4" (15 bold mono muted) and, when the trip washes and the line is per night, the washtub
  (18 pt, muted) next to it; accessibility value "×4 · laundry". Only shown when the quantity > 1;
  "×2.5" for a fractional quantity.

### Data
`trip.laundry`, `trip.extra.laundryNights` (always written on create and on settings save, even with
laundry off).

### Tests
Model: `LaundryNightsTests.testTheTripsChoiceCapsThePerNightCount` (60 nights: 60 / 4 / 7; 6 nights
with 7 → no wash; 3 nights stays 3; 0, −2, 100, NaN → 4),
`testAStartedAgainTripAndTheStoredRecordsKeepTheChoice`; `CountingTests.testQtyNightsNoLaundryFullTripLength`,
`testQtyNightsLaundryCapsLongTripsButNeverRaisesShortOnes`, `testLaundryFeedsEffectiveQty`,
`testEffectiveQtyPerNightScalesWithNightsElseExplicitQtyOr1`, `testEffectiveQtyReadsFreeTextTheWayNumberDoes`;
`WorkbookTests.testATripBecomesASoundWorkbook` (socks ×4 with laundry, ×7 without).
UI: `testLaundryCountsPerNightThingsFourNightsAtMost` (7-night Quick Swim trip: 3 lines, towel
"×4 · laundry"; Trip settings 5 nights → "×5 · laundry", the says-line contains "5 nights"; laundry
off → "×7").

---

## How the list is built (`TripBuilding.swift`, `Resolve.swift`, `Counting.swift`)

**Purpose.** Turn the trip's answers and its templates into the lines he packs from. Ported from the
web app's "Filtering" and "Total List generation".

### Which templates feed a trip — `listsForEvent(event, lists)`

1. Only templates with `role == ""` can be TICKED; ids in `activities` that are not such a template
   (base, transport, container, loose, deleted) contribute nothing. Of two templates with one id the
   last wins.
2. **Quick** (`mode == "quick"`): exactly the ticked templates, in `activities` order.
3. **Trip**: every `role == "base"` template, then every `role == "transport"` template whose
   `transport` equals the trip's transport, then the ticked templates.
3a. **I leave at** (0.69, the door check; `LeaveTimes(id: "trip-leave")` in `Screens/Pockets.swift`) — only
   while the trip has dates (a time on a day needs the day). A heading "I leave at" (Subheadline semibold blue,
   id `trip-leave-title`), then a `Grid` of two rows so the times line up: **First day** and **Last day**
   (Subheadline ink). A row with no time: **Add a time** (Footnote semibold blue capsule outline,
   `Metrics.chip` tall, id `trip-leave-out-add` / `trip-leave-home-add`) — it sets 07:30 (first day) or 10:00
   (last day) and, on the iPhone, asks the system's notification question once (`PackingReminders.askToShow`).
   A row with a time: the compact system time picker (id `…-time`), **"Check 07:15"** (Footnote mono muted —
   the time minus 15 minutes; id `…-check`) and a small quiet ✕ (drawn, muted, `Metrics.glyph` in a
   `Metrics.compact` square, id `…-remove`, label "Remove the time") that takes the time away. Under the rows
   (Footnote muted, id `trip-leave-note`): "Optional. 15 minutes before, the iPhone names what is still unticked
   — on the last day, what is not in a bag yet." (Mac: "…your iPhone names…"). On the iPhone, with a time set
   and the device not allowing the app to notify him: **"This device does not allow the app to remind you. Allow
   it in the device's Settings, under Notifications."** (Subheadline semibold red, id `trip-leave-refused`) —
   looked up whenever a time changes (`PackingReminders.permission`). Created with the trip; reset after Create.
4. Duplicates removed, first occurrence kept. Earlier templates win a name+bag clash, so the base has
   priority.

### Which rows come along — `buildTotalEntries(event, lists)`

For each template in that order, for each RESOLVED row (see below):

1. skip a blank name (jsTrim);
2. skip a retired thing ("Not in use");
3. skip unless `itemMatchesEvent(row, event, template)`: each of seasons, transports, catering —
   an empty tag list = always; otherwise the trip's value must be in it (a trip with no value passes);
   contexts — ONLY for a template whose group is "WET": the contexts asked for are THAT template's
   entry in `activityContexts` when it has one, else the trip-wide `contexts` (`contextsFor`, 0.67);
   empty row contexts = always, no contexts asked for = always, otherwise any overlap. (So Indoor+Outdoor
   takes both; Run outdoors and Swim indoors on one trip each take their own.)
4. **weather gear**: a row with weather tags is held back unless one of its tags is in the trip's
   `weatherOn`; it is offered by the weather card instead.
5. de-duplicate by key `normName(name) + "|" + container` (bag compared exactly, case-sensitive):
   the same thing from two templates INTO THE SAME BAG gives one line (first wins); into two bags,
   two lines (e.g. Underwear in a swim bag and in a duffel).
6. make the line with `entryFromItem` (below).

These row tags ("Only on some trips", his ask 2 Oct 2026) live on the template ROW (membership), not on
the thing: `resolveMembership` REPLACES the thing's seasons/contexts/transports/catering/weather with
the membership's. They are edited in the template's row editor (Templates spec).

### What a line carries — `entryFromItem(row, template)`

A new id; `name, swedish, qty, category` (empty → "Comfort & misc"), `container, phase, itemType`
(empty → "item"), `charging, chargeType, shortList, sub, note, weight` (non-finite → 0), `liquid,
restricted, perNight`, `section` = the section's DISPLAY NAME on that template (so same-named sections
of two templates merge), `kit` (kit name), `packer`, `storage`, `sourceListId` = template id,
`sourceItemId` = the catalogue thing's id, `custom = false`, `checked = false`. Constraint lists are
emptied. **Not carried:** photos, thumb, care record, stats, brand/model/colour/size, owner, price,
`expiry`, `consumable`, `keep`, retired. (That is why Check before you go reads the THING, not the
line.)

### What a resolved row is — `resolveMembership(thing, membership, templateDefaults)`

Bag: the row's own exception, else the template's default bag, else the thing's own bag. When: the
row's, else the thing's. Kind (`itemType`), how many (`qty`) and note: the row's when non-empty, else
the thing's. Section and kit: the row's. Everything else is the thing's.

### Per-night quantities
`perNight` is the THING's (intrinsic); `qty` may be overridden per template row. Counting is
`effectiveQty(line, qtyNights(trip))` — see Laundry.

### Kits
A line keeps its web-app kit NAME (`kit`), and its `packer`, but the native trip screen does not show either
(no kit clusters; `clusterByKit` is ported but unused — decided so, see Open questions 16).

**Things that hold things (0.70, spec 07 part 9, `ThingKits.swift`).** A trip is built from
`Library.templatesForTrips()`, not the plain resolved templates, and through `Library.builtLines(trip)`
(`createTrip`, `regenerated`; `followThing` reads the same templates): a thing inside a kit is NEVER a line
of its own. On a template that holds its kit too, the thing's row is left out; on one that does not, the
KIT takes its place — once per template, the row resolved from the thing's place there with its bag, When,
how many, note and kind cleared (so the kit's own bag and When), keeping its section and its "only on some
trips" answers. Then `buildTotalEntries` as before, and each kit's line once per trip (a kit on two templates
in two bags is still one line). A trip made BEFORE a thing went into its kit keeps that thing's line until a
rebuild (Trip settings → Save) takes it away — unless it is ticked, edited or added by hand, as for every line.

### Tests
`TripBuildingTests` (all): empty constraints, season, transport + catering, context only on WET,
combine + filter, de-dup by name+container, only chosen activities, the loose bin never feeds a trip,
weather-tagged items stay out, storage carried, retired excluded, section display name, kit carried,
packer carried, base + matching transport, RV trip with no activities still gets base + RV kit,
switching away from RV drops it, quick = only ticked, quick smaller than trip, the exact fields a
built line carries, regenerate keeps checked/custom/edited. `RowTagsTests.testATaggedRowComesOnlyOnTripsThatMatch`.
`CreateTripTests` (above). `ResolveTests`. Kits (0.70): `ThingKitsTests` — one line per kit and never what is
inside (the kit in the place of a thing that is on a template on its own), a kit with its contents on one
template or on two templates still one line, a rebuild and a change to a thing never bring a content back, the
checked kit's ticking rules, the checks before you go looking inside. UI (0.70, `-uiTestingKits`):
`testAKitIsOneLineOnATripAndWeighsWhatIsInside` (8 lines, "3 inside", no ninth line; Bags 2.4 kg; the arrow opens
three rows; the plasters' warning; Take out → "1 missing: Lighter", "2 inside"; Put back; Care's heaviest:
Wash bag then Camp pouch at rows 2 and 3), `testAKitCheckedBeforeEachTripIsPackedWhenAllInsideIsTicked` (the
wash bag open with two ticks and "2 to go"; its own tap does not tick it; the second tick does).

---

## Counting: progress, set aside, bag loads (`Counting.swift`)

- `isSetAside(line)` = `line.skipped`. `packable(lines)` = not set aside.
- `progress(lines)` → `done` = packable lines checked, `total` = packable lines (reminders INCLUDED),
  `aside` = lines set aside, `pct` = round(done/total×100) (0 when total 0). Set aside leaves the
  total, so a trip can reach 100 % with things set aside (his choice 2026-09-23).
- **Reminder lines** (`itemType == "reminder"`, a thing to DO — "book the ferry") count in the trip's
  progress, because they must be done before leaving; they are NOT in the bag loads (nothing to weigh),
  the cabin check (nothing to carry) or the review (nothing to use). Written down by the spec pass,
  5 Oct 2026, and kept so.
  Since 0.70 (spec 07, part 12) a reminder line says "To do" instead of its bag, stands under "To do" when
  sorted by Into, and shows in Check before you go and on Home's countdown once its step is due; the
  countdown's "to pack" counts leave reminders out ("7 to pack, 1 to do").
- **Set aside means not packed** (0.62): `setAside(true)` also takes the line's tick away, so a line is
  never ticked and set aside at once. (Older data can still hold both; the review, Your year and All
  your trips count such a line as not packed.)
- A trip is **all packed** when `total > 0 && done == total`.
- `bagLoads(lines, nights, limits)`: per bag (empty container → "Other"), set-aside lines and
  reminders skipped; `items` = count of lines; `grams` = Σ weight × effectiveQty; `kg` = grams rounded
  to 0.1 kg; `limitKg` from `limits[bag]` (0 = none); `over` = limit > 0 && grams/1000 > limit. Order:
  the `CONTAINERS` order first ("Toiletry bag", "Carry-on / hand luggage", "Checked luggage", …,
  "Other"), every other bag after in first-appearance order.
- Limits (`Library.bagLimits()` = `containerLimits(resolvedTemplates())`): the built-in airline
  ceilings — Carry-on / hand luggage 8, Checked luggage 23, the branded backpack in `CONTAINERS` 8, Day pack 8 kg —
  overlaid by each of his bags' own `maxKg` (> 0). 🪤 Must be given RESOLVED templates; the first Bags
  card used the template shells and saw none of his limits.
- `packingFlags` (counts liquids/restricted over every line, set aside or not) is ported but unused by
  the native app.

Tests: `CountingTests` (23: progress ×3, bag loads and limits ×5 — one of them also checks
`packingFlags` —, `packingFlags` alone ×1, quantities ×5 (`effectiveQty` ×2, `qtyNights` ×2, laundry
×1), `applyReview` ×4, `pruneSuggestions` ×5), `BagsTests.testALimitSetHereIsTheLimitATripUses`.

---

## The "When" steps on a trip (`Phases.swift`)

- A line's `phase` is a phase id. The live list `PHASES` is his edited list from Settings → Your
  choices, or the factory seven: `prep` Preparations (task, lead 30), `week` ≥1 week ahead (7),
  `daybefore` Day before (stage / move to RV) (1), `morning` Morning list (0), `door` At the front
  door (0), `wear` Wear / carry on the day (0), `after` After / recovery (−1), each with emoji and
  colour (`DEFAULT_PHASES`).
- Sorted "When", a trip shows one group per phase that has lines, in timeline order; a line whose phase
  this device does not know gets its OWN group at the END (label = the raw id, "Unsorted" if blank,
  emoji ❓, colour #64748b) — never folded into another step (`entriesByPhase`, `phaseOrFallback`).
- The group heading's colour is the phase colour made readable for the screen
  (`readableHex(colour, dark:)`: darkened on light screens until luminance ≤ 0.15, lightened on dark
  until ≥ 0.25; a line's tick circle uses the "graphic" thresholds 0.35/0.15). His "Bad text color
  twice" (2026-09-26).
- A thing typed on a trip, and weather gear without a phase, gets `defaultPhaseId()` = the first
  non-task phase ("week" by default).
- `leadDays` drive the Home countdown's "next step" and packing reminders (`Countdown.swift`, Home spec).

Tests: `PhasesTests` (all 12), `GroupingTests.testEntriesByPhaseOnlyReturnsNonEmptyPhasesInTimelineOrder`,
`testEntriesByPhaseAnUnknownPhaseGetsItsOwnGroupAtTheEnd`, `ContrastTests`.

---

## Dates in the model (`Dates.swift`)

- All model date arithmetic is UTC day counts on "YYYY-MM-DD" strings — no `Calendar`, no time zone.
- `daysUntil(start, today)` — whole days (negative = past); nil without a start or an unreadable date.
  With no `today` the UTC date of the clock is used; the app always passes `Today.local` (the
  device-time-zone date, `App/Sources/Store/Today.swift`).
- `countdownLabel(d)`: 0 "Today", 1 "Tomorrow", −1 "Yesterday", d > 0 "in d days", else "N days ago".
- `nightsBetween(start, end)`: end − start in days; nil if either missing/unreadable or end before
  start; same day = 0 (a day trip).
- `endFromNights`, `monthKey`, `shiftMonth`, `monthGrid`, `rangeCellState`, `orderRange` are ported
  (parity-checked) but not used by the native app.

Tests: `DatesTests` (all 16).

---

## The Trips tab (`EventsScreen.swift`, `TripCards.swift`, `TripYear.swift`)

**Purpose and origin.** "His trips in the piles they belong to — what is happening now, what is
coming, what has been — each saying where it is in its life without making him read numbers."
Planned/Packing/Ready badges (0.6); the tab called Trips, reviewed trips fold away, thicker progress
lines (0.16); Now / Coming up / Done (was "Been", his test G.1), Now always there, larger Reviewed
arrow (G.2) (0.40); Your year (0.16); All your trips + map (G.3, 0.42).

**How it is reached and left.** The Trips tab (`tab-events`, screen id `screen-events`; the section's
raw value is "events"). A row opens the trip as a sheet; closing the trip returns here.

### What is on screen (a lazy vertical stack, horizontal padding 16)

1. Header line — the shared tab header `ScreenHeader` (spec 06, "The tab header"; 0.67), 4 pt bottom
   padding; on the Mac pinned in the window's title bar strip, after the window buttons (the page scrolls under it): **"Trips"** (Title 2 bold, green, id `events-heading`) and, on the SAME centre line at the
   right, 8 pt apart: the map pin (`WorldMapDoor`, id `events-map`: the drawn pin at 24 × 24 — 26 until
   0.67, which on its 24-pt grid sat 1 pt up and left — green, in a `Metrics.tap` square; its sheet *Where
   you have been* closes with **Done**, `map-done` — Escape too since 0.62), the magnifier (`search-open`),
   and — only when there are open to-dos — a red capsule "N" (Callout semibold, monospaced) + "to do"
   (Footnote semibold), white, `Metrics.chip` tall (34 until 0.67), id `events-todos`, label "N to do,
   open the To do tab"; it switches to the To do tab. Count = open actions of kind "todo"
   (`openToDoCount`, shopping lines not counted). Under that line the summary (Subheadline, muted, id
   `events-summary`): "Nothing planned" with no trips; else "N trip(s)" + " · N being packed" (state
   packing) + " · N ready to go" (state packed).

   0.67 (his note on 0.63, "Overall, icons are not aligned", a picture of this header): the line was
   aligned on the title's first text baseline with 14 pt above it, so the 36-pt pin and magnifier stood up
   from the baseline, 10 pt higher than "Trips". `testEveryTabsHeaderIsOnOneCentreLine` checks the pin, the
   magnifier and (when there) the chip within 1.5 pt of the title's centre line.
2. No trips: "No trips yet. Build one on the Home tab." (17 medium muted, id `events-none`), and none
   of the piles below.
3. Three **piles**, in order Now, Coming up, Done (`events-pile-now`, `events-pile-comingUp`,
   `events-pile-been`): heading `SectionTitle` (UPPER CASE 18 heavy, 0.8 kerning; Now in green, the
   others ink) with the count (18 heavy mono muted, id `events-pile-<x>-count`). A pile is shown when
   it holds trips; **Now is always shown when there is any trip**; an empty Now shows a dashed green
   box "No trip under way today." (16 medium muted, min height 48, id `events-now-empty`).
4. Each trip a `TripRow` button, id **`trip-row-<n>` where n is the trip's index in the WHOLE sorted
   list**, not within its pile.
5. In Done: reviewed trips are folded under a toggle row — a 38 pt circle (14 % green) with a 22 pt
   chevron (rotates 90° when open), "Reviewed" (17 heavy) and the count (17 heavy mono muted); id
   `events-reviewed`, `.isSelected` when open. Starts folded every time the screen is built (not
   remembered). Reviewed trips in Now or Coming up are NOT folded.
6. When there is any trip: **Your year** and **All your trips** (below).

### `TripRow` (one trip)

- Left: name (18 semibold ink, one line; "Untitled event" when empty); under it the when-line (15
  medium muted, up to 2 lines) = parts joined " · ": the dates (a single day, or "start – end"), the
  countdown label for the start ("in 12 days", "Today", "3 days ago"…), the place (`destination`), the
  forecast's temperature range ("4–11°C") — or "No dates" when there is nothing. Dates are written
  "3 Oct 2026" — fixed English words on every device (`TripChecksCard.day`, 0.62), as the date grid,
  Check before you go and the map write them; until then they followed the device ("Oct 3, 2026").
- Right: the state badge (13 heavy, capsule, min height 22, id `trip-state`): **Planned** (muted on
  `Theme.line`), **Packing** (white on orange), **Ready** (white on green), **Reviewed** (muted on
  `Theme.line`); under it "done/total" or "done/total · N set aside" (15 bold mono; green when Ready,
  else muted).
- Bottom edge: an 8 pt bar, `Theme.line` track, filled to done/total in the state colour (Planned
  and Reviewed muted, Packing orange, Ready green). Card corner 12, 1 pt line stroke.

### Behaviour — `Library.tripCards(today:)`

- Order: `sortEventsForList(trips, today)`: rank 0 = start today or later (soonest first); rank 1 =
  undated or unreadable start (newest `createdAt` first); rank 2 = start before today (most recent
  first). A trip under way therefore sorts with the past ones.
- **State**: `Library.isReviewed(trip)` (`status == "done"` or `reviewedAt` set — ONE rule for every
  screen since 0.62) → reviewed; else total > 0 and done == total →
  packed ("Ready"); else done > 0 or anything set aside → packing; else planned.
- **Pile** (string comparison of YYYY-MM-DD with today): start > today → Coming up; start ≤ today ≤ end
  (end = start when empty) → Now; no start → Coming up; else → Done.
- **Weather** words: the forecast's `rangeLabel` when the trip has a forecast with days, "" if it
  contains "NaN".

### Your year (`TravelYearBand`, `Library.travelYear(today:)`)

`SectionTitle` "Your year" (id `events-year-heading`); 12 columns for the last twelve months ending with
today's month, oldest first: the count above (10 heavy green, blank when 0), a bar (height max(4, 54 ×
count / busiest month), green or `Theme.line`), the month "Sep" (10 bold muted); the bars are one
accessibility element, id `events-year`, label "Trips month by month over the last year". Under it three
figure tiles: trips ("trip"/"trips", id `year-trips`), nights ("night away"/"nights away", `year-nights`),
packed ("things packed", `year-packed`) — 20 heavy green numbers over 12 bold muted words.
A trip counts when its start's YYYY-MM is one of those months; nights = days between start and end
(both ≥ 10 characters; same day or no end = 0); packed = its ticked lines that are not set aside
(`Library.packedCount`, 0.62 — before, a line ticked and then set aside counted).

### All your trips (`AllTimeBand`, `Library.travelAllTime()`)

`SectionTitle` "All your trips" (id `events-alltime-heading`); four tiles: trips, nights, places
(= pins on the map, `mapPlaces().count`; one place visited twice = one), things packed (ids
`alltime-trips/-nights/-places/-packed`); under them the small map (`events-minimap`, Map spec).

### Tests
UI: `testATickCountsAndStays` (Now pile with "0" and the empty box), `testEachTripSaysWhereItHasGotTo`
(summary contains "trip", "Planned" → "Packing", the to-do chip opens To do),
`testHomeBuildsATrip`, `testTheMapShowsWhereTheTripsWent` (All your trips heading, mini map value).
Model: `TripCardsTests` (planned/coming up; one tick → packing and part; set aside counts as decided →
packed; reviewed → been; today and the last day → now, the day after → been; open to-dos counted),
`TripEventsTests.testSortEventsForListOrdersNearestUpcomingFirstThenUndatedThenPast`,
`testSortEventsForListAnUnreadableStartDateCountsAsUndated`, `TravelYearTests` (all 4).
**Not covered:** the Reviewed fold, "N set aside" on a row, the Done pile, the weather words on a row.

### Traps and history
- 🪤 Read a row's words through the ROW button: the Mac folds children into the button's label, the
  iPhone keeps them separate.

---

## The trip screen (`TripScreen.swift`)

**Purpose and origin.** "One trip, in Packing Mode: its lines under his "When" headings, a tap ticks a
line — and that tick is ONE small record." Origins: 0.2 (tap to tick, ⊘ not this time,
When/Where/Category), "Sorting" left of its buttons (0.19), Where → **Into** and the new **From where**
(his words 2026-09-25, 0.20), folding (his ask 2026-09-26 "the list is extremely long", 0.23), Set place
(0.25), Delete trip (0.24), Trip settings (0.32, a pen since 0.40), Tick everything / Clear every tick
(0.36), Excel (0.35) and Share (0.38) side by side (his test D.22), Bought on site (0.52/0.56), On site
door (0.57), Sorting as ONE drop-down with a fifth sorting, **Section** (0.64 — his ask of 6 Oct 2026: he
likes sections because "it gives a visual structure to the packing", and asked for drop-downs everywhere).

**How it is reached and left.** Opened as a sheet from a Trips row, from Home after Create trip, the
countdown card, a reminder, a Shortcut, Search, or (0.69) a place's printed code while the trip is being packed —
then on that place's lines ("Opened on a place", below). Left with **Done** (`trip-done`) or by swiping the
sheet down (iPhone). Screen id `trip-detail`. Mac: minimum 520 × 640.

The screen shows `startedId ?? openedId`: after *Start a new trip from this one* the NEW trip takes the
place of the opened one on the same sheet. If the trip disappears (deleted on the other device), the
screen shows an empty placeholder trip ("Untitled event", 0/0).

### What is on screen (top to bottom)

**Header** (padding 16):
- Trip name — 22 heavy ink, up to 2 lines, scales to 0.85 (the whole name, not "Weekend in the…"),
  "Untitled event" when empty; id `trip-name`.
- Under it, one line: the progress "done/total" or "done/total · N set aside" (16 bold mono; green when
  all packed, else muted; id `trip-progress`; accessibility value "all packed" when all packed, else
  ""), and the **pen** (Trip settings door: drawn pen 24 pt green in a 36×34 target, id
  `trip-settings`, label "Trip settings").
- Right: "Reviewed" (15 bold muted, id `trip-reviewed`) when `Library.isReviewed(trip)` (0.62: a trip with
  only a review time, from the web app, offered Review again here); otherwise, if the trip
  has lines, **Review** (outlined green, id `trip-review`) — offered at ANY time, before the trip too.
  Then **Done** (filled green, id `trip-done`; **Escape** presses it — `.keyboardShortcut(.cancelAction)`,
  ⌘. on an iPhone keyboard — 0.62). Both use `HeaderButtonStyle`, whose own font wins over the
  one the call site sets — 17 pt bold since 0.62, the size the call sites ask for (16 until then; the same
  everywhere in this area: Done, Cancel, Next, Close).

**Loop strip** (`LoopDoor`, id `trip-loop`, value = the step's name) — see "The loop".

**What the last settings save did** (only after one; 15 bold green, id `trip-rebuilt`):
`TripScreen.saying`: (0 added, 0 removed) "Saved. The list is the same."; (a, 0) "Saved: a new on the
list."; (0, g) "Saved: g no longer on the list."; (a, g) "Saved: a new, g no longer on the list."; after
Start again: "New trip from “<old name>”: N things, nothing ticked. Its dates are under the pen."
It stays until the sheet is closed.

**Sorting row** (0.64; padding 16 sideways): "Sorting" on the left and, on the SAME line to its right, ONE
drop-down (`DropDown`, spec 06 §21, with `heading: .beside`) holding the five sortings — **When**, **Into**,
**From where**, **Category**, **Section**. Five pills do not fit an iPhone's line, and he asked for drop-downs
everywhere (6 Oct 2026); his marks of 2026-09-25 ("Sorting" on the left, the choice beside it) are kept.
- "Sorting": Subheadline semibold, muted, one line, never squeezed (`fixedSize`); id `trip-view-label`.
- The field, 10 to its right, takes the rest of the line: the chosen sorting's words in Body ink and a drawn ▾
  (`Metrics.tap` tall, card fill, radius 10, a hairline border); id `trip-view`; accessibility label "Sorting",
  value = the chosen sorting's words (what tests read). A stored value that is none of the five (it cannot be,
  but a device keeps it) shows and ticks When, which is what `groupBy` does with it.
- A tap opens the list as a popover beside the field (on the iPhone too; the system puts it above or below,
  wherever it fits — under the field, near the top of the screen): container `trip-view-list`, five rows
  `trip-view-0…4` (When, Into, From where, Category, Section — the ids the pills had, Section the new 4), the
  chosen one with a green tick and the selected trait. A tap on a row sorts the trip at once (stored in
  `ams.view`) and closes the list; the ticked row closes it unchanged.
- Until 0.64: four capsule pills on the line (`ViewThatFits`: full size; slimmer; or "Sorting" above them), the
  chosen one white on green with the selected trait.
- **Pack by voice** (0.71, iPhone only — a test; spec 07 part 10): at the END of the row, 8 to the right of the
  field, an outlined green capsule with a drawn microphone, `Metrics.tap` tall, id `voice-start` — "Voice" on an
  iPhone too narrow for both (`VoiceSortingRow`, `ViewThatFits`); the field takes what the button leaves. Pressed
  when it cannot start, the reason is said under the row in red (`voice-start-needs`). The Mac's row is the
  drop-down alone, as before. See "Pack by voice" below.

**The scroll area** (`KeyboardAwayScroll`, dragging puts the keyboard away):
0. **Obsidian** card (`VaultCard`, only on a REVIEWED trip — `Library.isReviewed`; 0.70, top padding 10) — see
   "The trip's page in his vault".
1. **Check before you go** card (only when something needs him) — own section below.
2. **Weather card** (always) — own section below.
3. **Bags card** (only when some bag has lines AND weight or a scale reading) — own section below.
4. **On site door** (only once On site has begun) — see "On site".
5. **The groups** (a lazy stack with **no spacing** — 4 until 0.67), one per non-empty group of
   `groupBy(view, trip.entries)`; `g` = the group's position in that list:
   - Heading row (top padding **6** — 12 until 0.67, his words of 6 Oct 2026, "Far too much space between the
     lines"; with a line above it, the heading's words stand about 12 pt under that line, 25 until 0.67):
     fold arrow (drawn chevron at `Metrics.glyph`, 20 / 16, with `onGrid`, in a `Metrics.lineButton` − 6 ×
     `Metrics.line` target — 34×36 and 20 pt until 0.67; pointing right when folded,
     down when open; id `trip-group-<g>-fold`, label "Open <heading>" / "Fold <heading>"); the heading
     (15 heavy; sorted When: the colour of the FIRST line's phase made readable; otherwise green; id
     `trip-group-<g>-label`; tapping the words folds too); the count "ticked/packable" (13 bold mono
     muted, set-aside lines excluded); and at the right the **whole-section tick**: a `TickCircle` of
     `Metrics.mark` (18 / 14; 20 until 0.67) — a `Theme.line` ring, or filled green with a white tick when
     every packable line of the section is ticked — in a `Metrics.lineButton` × `Metrics.line` target (40 × 30
     on the iPhone, 30 × 22 on the Mac; 40×36 until 0.67), so it sits above the lines' ⊘; id
     `trip-group-<g>-all`, label "Tick all of <heading>" / "Untick <heading>", `.isSelected` when done. When
     every line of the section is set aside there is nothing to tick: the button is not drawn (an empty target
     of the same size keeps the heading still) — 0.62; until
     then it sat there switched off and faded, against his rule. A press sets EVERY packable line of the section to "ticked" — or, when
     all were ticked, to "unticked" — in one `model.change`, one `setChecked` per line.
   - When not folded, its lines (see "A line" below).
6. **Tick everything / Clear every tick** (`TickAllRow`) — own section.
7. **Save as Excel** and **Share** side by side, equal width (ids `trip-excel`, `trip-share`) — own
   sections.
8. **Delete trip** — small red button at the right, own section.

**Add bar** (fixed under the scroll area, padding h16 v10; `Theme.bg` behind it, transparent when all
packed so the green reaches it):
- Field "Add a thing to this trip" (17 medium, min height 44, card fill, corner 10), id
  `trip-add-name`; Return adds.
- **Add** (16 bold white on green, `FieldButtonLabel`), id `trip-add`; never disabled.
- **Bought on site** (16 bold green words, 1.4 pt green outline, corner 10), id `trip-add-bought` —
  only while something is typed.
- Under the row, after Add with nothing typed: "Type a thing first." (15 bold red), id
  `trip-add-needs`; it goes as soon as anything is typed.

**All packed**: the whole screen background gets a 34 % green layer (animated 0.5 s), and on the moment
it becomes all packed ONE green gradient sweeps down from the top (0.45 s in, 0.55 s out) — never a
blink; skipped with Reduce Motion. The progress text turns green and carries the value "all packed".

### A line

`HStack` of two buttons, 4 pt apart (top-level row id is the line's button). **A line is as tall as its
words** (0.67): at least **`Metrics.line` — 30 pt on the iPhone, 22 on the Mac** — top to top, no space between
lines; a name on two lines grows it. His words, 6 Oct 2026, testing 0.63: "Far too much space between the lines"
(44 top to top until 0.67: a 40-pt ⊘ and 4 pt between lines; 5 Oct he had asked for "slimmer rows in the trip,
smaller tick circles and less space between lines").
- **The line** (`PackLine`), id **`trip-line-<n>` where n is the line's index in `trip.entries`** (the
  list order, independent of sorting); accessibility value = "×4 · laundry" / "×7" / ""; `.isSelected`
  when ticked. Content, 8 pt apart (10 until 0.67): a `TickCircle` of **`Metrics.mark` — 18 pt on the
  iPhone, 14 on the Mac** (20 until 0.67; 26 before 0.62) — a 1.6-pt ring in the line's phase colour
  (graphic-readable), or `Theme.line` when set aside; filled with a white tick when ticked and not set aside;
  the name (Body; muted when ticked; muted and struck through — 3 px his call in the comment, drawn with
  `.strikethrough` — when set aside; up to 2 lines); "Bought on site" (Footnote semibold green) right under
  the name when marked; at the right "×N" (Subheadline semibold mono muted) when the quantity > 1, plus the
  washtub at `Metrics.glyph` when laundry washes and the line is per night; then the bag name (Footnote muted,
  one line, max 150 pt wide) — except when sorted Into. **0.69:** a ticked line with a pocket says
  **"Backpack · Front pocket"** there instead (max 200 wide); sorted Into (the heading names the bag), just
  "Front pocket". An unticked or set-aside line never shows a pocket. 2 pt above and below the words (5 until 0.67), at
  least `Metrics.line` tall, a hairline under it.
  Tap: toggles `checked` (`Library.setChecked`) — **a set-aside line does not tick**. **0.69:** ticking a line
  whose bag has pockets (`Library.pocketsByBag()`, asked once per screen) opens its **pocket pills** under it —
  see "Bag pockets on a trip".
- **⊘ / ↻** (`AsideMark`, drawn on the 24-pt grid, stroked 1.8, muted, shown at `Metrics.glyph` — 20 / 16 —
  with `onGrid`), in a **`Metrics.lineButton` × `Metrics.line`** target — 40 × 30 on the iPhone, 30 × 22 on
  the Mac (24 pt in 40 × 40 until 0.67): as tall as the line, no taller, generous across; id
  `trip-line-<n>-aside`, label "Not this time" / "Take it this time": one tap toggles `skipped`
  (`Library.setAside`), no confirmation (his call). Setting aside also takes the line's tick (0.62); taken
  back, it is unticked.
- Sorted **From where**, under each line of the group **"No place set"**: **Set place** (Footnote semibold
  green capsule outline, `Metrics.chip` tall, indented `Metrics.mark` + 8 so it starts under the name — 44 and
  30 tall until 0.67), 4 pt under the line (6 until 0.67), id `trip-line-<n>-place` — see "Set place". The
  place panel is indented the same.

- **A kit's line (0.70, `TripKitLine.swift`).** A line whose thing holds things (`Library.kitLines(tripId:)`,
  read once for the screen) is ONE line: its name says "Camp pouch · 3 inside" (`PackLine.kitWords`, the
  count muted, after a middle dot: what is inside and not taken out). Between the line and its ⊘, a fold arrow
  (`KitFoldButton`, the section fold's chevron at `Metrics.glyph`, muted, `Metrics.lineButton` − 10 wide;
  id `trip-line-<n>-kit`, value "open" / "folded"). Under the line, indented `Metrics.mark` + 8 like Set place
  (`KitLineParts`): "1 missing: Lighter" / "2 missing: Lighter, Spare cord" (Footnote semibold red,
  `trip-line-<n>-kit-missing`) while something is taken out; with Check before each trip, while neither ticked
  nor set aside, "Tick what is inside first: 2 to go." (Footnote semibold green, `trip-line-<n>-kit-togo`);
  what is worth saying about what is inside for this trip (`kitWarnings(kitId:today:before: trip's last day)`:
  out of date, runs out before the trip ends, care overdue or due soon; Footnote semibold orange,
  `trip-line-<n>-kit-warning-<k>`); and, when open, one row per thing inside in his order
  (`trip-line-<n>-kit-<k>`, value "taken out" / "ticked" / ""): its name, Subheadline muted (struck through when
  taken out) — or, for a checked kit, a small tick circle (the mark at 0.8) and the name as a button
  (`trip-line-<n>-kit-<k>-tick`, selected when ticked) — and at the right "Take out" / "Put back" (Footnote
  semibold green, `trip-line-<n>-kit-<k>-out`, `Library.setTakenOut` — on the thing itself, so every trip and
  the thing's page follow). A kit is open while it is checked before each trip and not yet packed, else folded;
  the arrow changes that for this visit (`@State kitOpen`, not remembered). The parts are keyed by their own
  state, so a lazy row never shows old ticks.
  **Ticking a kit:** without the check, as any line. With it, `Library.setChecked(true)` is REFUSED while
  something inside is not ticked (`kitAllowsTick`) — the tap does nothing, and "2 to go" is already under it;
  this holds for a section's tick-all and Tick everything too. `setKitContentTicked`: the last one ticked ticks
  the line (and forgets the list); unticking one unticks the line, the rest stay ticked. Unticking the line
  itself starts its ticks over. Taken out = not asked for; with nothing left inside, the kit ticks as any line.
  A set-aside kit's things do not tick. **Weight:** the Bags card and a bag's trips add each kit line as its own
  weight plus what is inside it now (`linesWithKitWeights`: each content's weight × its how-many, the taken out
  not counted). **Check before you go** looks inside each kit line (`insideLines`): "Lighter, in the Camp pouch"
  in a cabin bag is not allowed on board; "Plasters, in the Camp pouch" runs out before you are home — each opens
  that thing.

Each row view is keyed by "id|checked|aside|group|placing|qtyNights|pocketing|pocket" (the last two 0.69), so it is rebuilt whenever its
tick, set-aside, group, place panel or night count changes (bug B1, his Mac 2026-09-26: a row showed no
tick while the trip had it; and a moved lazy row kept "Set place").

### Sorting and grouping (`groupBy`, `Grouping.swift`)

The chosen sorting is remembered on the device in AppStorage **`ams.view`** (default "when"), the same
for every trip — kept so (the spec pass, 5 Oct 2026): it is a way of looking, not part of a trip, and
each device keeps its own. Within every group the lines keep the trip's list order (no inner sorting).

| Button | `ams.view` | Groups | Group order | Heading |
|---|---|---|---|---|
| When | `when` | phase | timeline; unknown phases last | phase label |
| Into | `container` | bag (empty → "Other") | `CONTAINERS` order, then others A–Z (localeCompare) | bag name |
| From where | `stored` | `storage` (trimmed, exact text) | A–Z (localeCompare); "No place set" last | place |
| Category | `category` | category (empty → "Comfort & misc") | `CATEGORIES` order, then others A–Z | category |
| Section (0.64) | `section` | the line's `section` (trimmed): the section's NAME on the template the line came from | first appearance in the trip's list order; "Everything else" (lines with no section) last | section name |

**Section** (0.64; until then the model's `groupBy` knew "section" and the app did not offer it) uses
PackingCore's `groupBySection`, unchanged. What it reads:
- A line carries its section's display NAME, copied when the line was made (`entryFromItem`: the section of the
  line's place on the template it came FROM), so same-named sections of two templates are ONE heading ("Lights"
  on Hiking and on Camping), and the headings come in the order their first lines come in the trip — which is the
  order of the templates (`listsForEvent`: base, transport, then the ticked ones) and, within one, the template's
  row order (`order`; Arrange renumbers the rows so that this reads as the template's page does).
- A thing on two templates feeds ONE line — the first template wins the de-duplication (`buildTotalEntries`,
  name + bag) — so its heading is its section on THAT template: the sample's Headlamp, on the base template and
  under Lights on Hiking, sits under "Everything else".
- Lines added on the trip (typed, Bought on site) have no section: "Everything else".
- A trip made before a section was given keeps its lines' words: a section set later — on a row (`saveRow`) or on
  the thing's page (`setThingSection`, 0.64, spec 05) — reaches only the lines `followThing` rebuilds: on trips
  still ahead (not reviewed, not over), lines not ticked, not added by hand and not changed on the trip; ticked
  lines and past trips keep their old heading. A section RENAMED on the template does not reach a trip
  (`renameSection`: a line's words are frozen like everything else on it), and Trip settings' Save keeps every
  line it already had as it was (`regenerated`); an open line takes the new name only when `followThing` rebuilds
  it — after a change to its thing or its row.
- Everything else on the screen behaves as under any sorting: green headings, the count, the whole-section tick,
  folding (keys `<trip>|section|<name>`), the bag name on each line.

### Folding

Folded headings are remembered on the device in AppStorage **`ams.trip.folded`**: newline-separated keys
`"<tripId>|<view>|<heading>"` — per trip and per sorting (`TripFolds`, PackingLibrary/TripEdits.swift).
A folded group keeps its heading, count and whole-section tick. Since 0.62 the keys are cleaned up:
deleting a trip removes its folds (`TripFolds.without`), and every fold made drops the folds of trips this
device no longer has (deleted on the other one too, `TripFolds.toggled`).

### Set place (From where)

His ask (2026-09-26): "No place set … I want to define a place for these items with one click or two".
Tapping **Set place** opens a panel under that line (only one at a time; `placing` = the line id),
indented 44, card with a 50 % green border, id `trip-place-panel`:
"Where is <name> kept?" (13 heavy muted) and **Close** (outlined muted, id `trip-place-close`; closes
and empties the field); one pill per storage place (`Library.storagePlaces()`: his own "places" list
from Settings, or the 12 `DEFAULT_STORAGE_LOCATIONS` "Bedroom wardrobe" … "RV / camper" while he has
none; 14 semibold ink on a `Theme.bg` capsule with a 1 pt line, min height 32, wrapping, id
`trip-place-<i>`) — one tap sets it; a field "A new place" (15 medium, min height 36, id
`trip-place-new`, Return saves — Return on a blank field does nothing) and **Save** (15 bold white on
green, id `trip-place-save`) — always in colour, never switched off (0.62); pressed with the field
blank it says "Type a place first, or tap one above." under the row (15 bold red, id
`trip-place-save-needs`), gone as soon as something is typed. Opening Set place on another line moves
the one panel there and empties the field.
`Library.setPlace(place, tripId:, entryId:)`: trims; refuses blank; if the line comes from a template
row that still exists (`thingId(of:)`), the THING's `storage` is set (`updateThing`, so other trips
still ahead follow) and so is every line of that thing on this trip (a thing on a trip twice); a line
with no thing behind it changes alone. A place not in his list (normName) is appended to his places
(`setNames("places", …)`). The panel closes; the line moves under its place.

### Opened on a place (0.69)

A place's printed code, read while this trip is being packed (spec 05, "A place's code"), opens the trip on that
place: `TripScreen(tripId:, place:)` — from Home (`openedPlace`) or from Open on a place's page in Your choices. The
same happens nowhere else (a trip opened any other way shows every line).
- As it appears the sorting becomes **From where** (`ams.view` = "stored", so it is remembered like a sorting he
  chose).
- Under the Sorting row, the place's chip (`placeChip`, id `trip-place-filter`): the place's name (Subheadline
  semibold, one line) and a drawn ✕ (`M7 7L17 17M17 7L7 17`, stroke 2.2, `onGrid(14)`), white on a green capsule,
  `Metrics.chip` tall, 12 sideways, 6 above, 16 in from the screen's sides; accessibility label "Only <place>. Show
  every line", value = the place's name (what tests read — the Mac folds the button's words into it). A tap shows
  every line again (`placeFilter = nil`); the sorting stays From where.
- Only the lines kept at the place (`Library.isKept(line.storage, at: place)`, by choice key) go into `groupBy`, so
  with From where there is ONE heading, the place's. Line ids stay their positions in the whole trip
  (`trip-line-<n>`), so ticks, ⊘ and the heading's tick-all work as ever — the heading's tick-all ticks only that
  place's lines.
- Nothing else is on the page while it shows one place, so its lines are what he sees first (his plan: "the trip
  opens showing only what to take from the garage"): no Check before you go, weather, Bags card or On site door
  above; no Tick everything, Excel, Share or Delete trip below; no "Add a thing" bar (a line typed there has no
  place and would vanish). When nothing on the trip is kept there: "Nothing on this trip is kept here. Tap the
  place above to see every line." (Subheadline muted; id `trip-place-none`).
- The header, the loop strip and the progress ("done/total" of the WHOLE trip) stay.

UI `testAPlacesCodeOpensTheTripBeingPackedOnItsLines` (`-uiTestingPlaces soon -uiTestingOpen AMSPACKING://P/G4R`:
the trip opens, chip value "Garage", sorting From where, ONE heading "Garage", two lines on screen — Headlamp and
Map — no add bar; the heading's tick-all → "2/…"; the chip → its own heading `trip-group-1-label` and the add bar
come back).

### Add a thing / Bought on site

- **Add** → `Library.addCustomLine(tripId:, name:)`: jsTrim; blank → nothing. A new line `custom =
  true`, unticked, bag "Carry-on / hand luggage", When = `defaultPhaseId()`, category "Comfort & misc";
  appended at the end; `updatedAt` set. No check for duplicates: the same name twice gives two lines.
  The field empties.
- **Bought on site** (his idea 12, 2 Oct 2026; "on site" not "there", field test Oct 2026) →
  `addBoughtOnSite`: the same custom line, **ticked** (in hand) and `extra.boughtThere = true`. It
  counts at once ("1/8"), shows "Bought on site", goes on the way home, and begins On site.

### Tests (the trip screen)
UI: `testATripsLinesSitTightUnderTheirHeadings` (0.67, `-uiTestingSections`, sorted by Section: the lines on screen
`trip-line-0…8` at most `Metrics.line` — 30 on the iPhone, 22 on the Mac — top to top and at least 8 less, so the
words still fit; the Lights heading `trip-group-1-label` at most 14 pt under the line above it; `trip-line-0-aside`
no taller than a line and at least 28 wide; picture `tight-trip`; seen red on 0.66's sizes: "a line takes 44.0
points, top to top; at most 30.0"), `testATickCountsAndStays`, `testEveryRowShowsTheTickTheTripHolds` (every sorting — Section too since 0.64,
each chosen from the drop-down — every row shows its tick), `testASectionFoldsAndStaysFolded`,
`testAPlaceIsSetFromTheTrip` (From where chosen from the drop-down), `testTheTripSaysSortingBesideItsDropDown`
(0.64; until then `testTheTripSaysSortingBesideItsThreeButtons`: "Sorting" left of the field `trip-view` on the
same line, neither off the screen; no row out before it is opened; the list reads When/Into/From where/Category/
Section with no sixth, When ticked, every row on the screen; Into re-sorts, From where headings are the sample's
places), `testATripSortedBySectionReadsUnderItsSections` (0.64, `-uiTestingSections`: 0/9; Section chosen; the
headings Clothes, Lights, Everything else and no fourth; Lights' one press ticks its line (1/9, `trip-line-7`, the
spare batteries, ticked); folding Lights hides the line and opening shows it), `testAThingsPageSetsItsSectionOnATemplate`
(0.64, spec 05: the Map put under Lights on Hiking from its page → the trip, sorted by Section, has it under
Lights), `testAWholeSectionIsTickedInOnePress`, `testTheScreenSaysSoWhenEverythingIsPacked`,
`testAThingTypedWhilePackingJoinsTheTrip` (Add never disabled, `trip-add-needs`), `testSomethingBoughtOnSiteGoesOnTheList`
(the button appears only after typing, "1/8", "Bought on site" on line 7), `testAChangeToAThingReachesATripStillAhead`,
`testASetAsideLineIsNotPacked` (⊘ takes the tick, a set-aside line does not tick, ↻ brings it back unticked,
a section with every line set aside has no `trip-group-0-all`), `testSetPlaceAndTheReviewSayWhatIsMissingAndNoTemplateIsChosen`
(`trip-place-save-needs`), `testEscapeClosesTheTripsWindows`.
Model: `CustomLineTests.testATypedThingJoinsTheTripAndSurvivesARegenerate`, `SetPlaceTests.testAPlaceSetOnTheTripReachesTheThingAndItsTwin`,
`TripCardsTests.testEverythingDecidedIsPacked`, `OnTheTripTests.testABoughtOnSiteLineIsInHandMarkedAndKept`,
`testTheStoredMarkKeepsItsFirstName`, `CountingTests.testProgress*`, `GroupingTests` (groupBy, container, category, storage).
Model: `TripEditsTests.testATripsFoldsGoWithIt`, `ReviewTests.testASetAsideLineNeverCountsAsPacked`.
**Not covered by any test:** the gradient sweep/Reduce Motion; the placeholder for a vanished trip; a stored
sorting that is none of the five.

### iPhone vs Mac
Same view. Mac minimum 520 × 640. The Sorting row is one line on both (since 0.64 there are no fall-backs:
the field takes what the word leaves). The Sorting list is a popover on both.

### Traps and history
- 🪤 The cards (checks, weather, bags) sit OUTSIDE the lazy stack: a lazy row is thrown away and rebuilt
  as it scrolls off, which lost what he had typed into it (2026-09-23).
- 🪤 Lazy list on the Mac's short window: lines far down are not in the tree until scrolled near; tests
  scroll line by line (`scrollUntil`).
- 🪤 The fold arrow is its own button so the heading's words stay a text of their own (Mac folding).
- 🪤 Never trap on a repeated line id (E.6): the screen's index keeps the first.

---

## Pack by voice (iPhone, a test — `App/Sources/Voice/`, `PackingLibrary/VoiceWalk.swift`)

His yes of 7 Oct 2026, in English; built in 0.71 as a TEST, kept only if on a real trip it understands him at
least 9 times in 10 and beats tapping. **Specified in full in spec 07 part 10**; in short:
- `voice-start` at the end of the Sorting row (above) opens a panel (`voice-panel`) that walks the lines still
  to pack (not ticked, not set aside) in **From where** order — whatever the screen is sorted by — saying the
  place, then the thing ("Garage. Goggles."), and listening ON the iPhone for **packed** (ticks the line, as a
  tap: `setChecked`), **skip** (sets it aside, as ⊘: `setAside`), **later** (leaves it), **where** (says the
  place again) and **stop**. At each new place and after every 5 answers it says the trip's own count ("Garage
  done, 12 of 40"). The five words are also buttons on the panel (`voice-word-<word>`); a tap does the same.
- What it changes on the trip is only those ticks and set-asides, each one `model.change` like a tap — so they
  sync, and the trip screen shows them when the panel closes. Nothing of the walk itself is stored.
- Not on the Mac (no button; the code is iPhone-only).

Tests: UI `testPackByVoiceWalksTheTripByTheWordsItHears`, `testPackByVoiceButtonsDoWhatTheWordsDo`,
`testPackByVoiceSaysWhyItCannotStart`, `testPackByVoiceGoesOnceMoreOverWhatWasLeft`, `testAPlaceCodeStartsPackByVoiceAtThePlace`
(iPhone; skipped on the Mac); model `VoiceWalkTests` (15). At the end, what was left for later is offered once more;
a place opened by its printed code starts the walk there by itself (switch `voice-autostart`, on by default).

---

## Tick everything / Clear every tick (`TickAll.swift`, `TripBulk.swift`)

**Purpose and origin.** The web app's "Mark everything packed" / "Clear every tick" (gap list
2026-09-27, 0.36). "Ticking all needs no asking — it is what he is there to do; clearing asks first,
as the web app does, because it throws away the packing so far."

### What is on screen (only when the trip has packable lines)
- **Tick everything** (only while something is unticked): green filled, a drawn tick 22 pt + "Tick
  everything" (16 bold), under it "N still unticked" (13 semibold, 85 % opacity), white, min height 52,
  corner 12; id `trip-tickall`, value "N".
- **Clear every tick** (only while something is ticked): 16 bold ink, 1.4 pt `Theme.line` outline, min
  height 52; id `trip-clearall`. The two share the line equally.
- Asking: a card with a red border: "Clear all N tick(s)?" (16 heavy), "The list stays as it is. Only
  the ticks go." (14 medium muted), **Keep them** (16 bold ink, id `trip-clearall-no`) and **Clear the
  ticks** (red capsule, white 16 heavy, id `trip-clearall-yes`).

### Behaviour
`Library.setAllChecked(checked, tripId:)`: every line NOT set aside whose tick differs is set, one
`setChecked` (one record) per line; returns how many changed. Set-aside lines are untouched both ways
(setting a line aside takes its tick, so none is ticked underneath since 0.62; one from older data
counts nowhere — see Counting).

### Tests
UI `testEverythingIsTickedAndClearedAtOnce` (value "6" after one tick, 7/7, Tick everything disappears,
Clear asks, Keep them keeps, Clear the ticks → 0/7, Clear disappears). Model
`TripBulkTests.testEverythingIsTickedAndClearedButWhatIsSetAside`.

---

## Trip settings (`TripSettings.swift`, `TripEdits.swift` → `changeTrip`, `Library.regenerated`)

**Purpose and origin.** "A trip's settings, changed after it is made — the gap list's first High item
(2026-09-27)" (0.32). A pen, not a gear (tests C.3, D.1; 0.40). The place added for his test G.6 ("the
place is not shown in the edit view", 0.40). Save in a bar at the bottom, always in sight (0.34; "the
cloud test lost it" 2026-09-27). 0.67: the same three changes as Create new trip — Full trip | Quick under
the name, the date picker always there (Clear dates instead of a Dates switch), Context per workout.

**How it is reached and left.** The pen beside the trip's count (`trip-settings`) opens it as a sheet
(`TripSettingsDoor` owns the sheet because the trip screen already has one for the review). Left with
**Cancel** (no change; **Escape** too, ⌘. on an iPhone keyboard — 0.62), **Save changes** (when nothing
is missing), **Start it** (Start again), or a swipe down on the iPhone (= Cancel) — but only while
nothing has been changed: once anything differs from what the sheet opened with, the swipe no longer
closes it (`interactiveDismissDisabled`, 0.62) and Cancel or Save must be pressed. Screen id
`tripset-screen`; Mac minimum 540 × 600.

### What is on screen
- Header: **Cancel** (outlined muted, id `tripset-cancel`), title "Trip settings" (22 heavy ink), an
  empty 56 pt spacer.
- Name field (placeholder "Name your trip", 20 semibold, card fill, line stroke), id `tripset-name`.
- **Full trip | Quick** (`TripKindChoice`, 0.67) as on Create new trip but GREEN: ids `tripset-kind-full`,
  `tripset-kind-quick`, the line `tripset-kind-note`. (Until 0.67 a "Quick" switch `tripset-quick` and a
  green note `tripset-quick-note` while on.)
- Heading **"Place"** (`HeadingTitle`, green, id `tripset-heading-place`) and a field with an example
  placeholder ("Where the trip goes, e.g. <a town>", 18 medium), id `tripset-place`.
- The date picker, always (0.67; until then only under a **Dates** switch, id `tripset-dates`, gone), green,
  its grid CLOSED: field id `tripset-dates-field` (value "No dates" for an undated trip), grid ids `range-*`.
  **Clear dates** (`range-clear`) in the grid is how a trip's dates are taken away now — the switch was the
  only way before, so it is kept as a small action rather than lost.
- **I leave at** (0.69), only while the trip has dates: as on Create new trip ("I leave at"), GREEN, ids
  `tripset-leave-*` (`tripset-leave-out-add`, `tripset-leave-out-check`, `tripset-leave-refused`…). Loaded from
  `extra.leaveAt` / `extra.leaveHomeAt`; part of the sheet's snapshot (a changed time stops the swipe from
  closing it); Save writes them with `Library.setLeaveTime` inside `changeTrip` ("" takes one away).
- The template pill groups (ids `tripset-activity-<n>`, same numbering as Create new trip, "OTHER
  TEMPLATES" last; heading id `tripset-activity-title`), Context per workout (`WorkoutContexts`, 0.67:
  `tripset-context-title`, a line per ticked workout `tripset-context-<n>-name` with its pills
  `tripset-context-<n>-0…2`, n = its `tripset-activity-<n>`), Transport,
  Season, **Pack weather gear anyway** (0.62: pills Rain, Cold, Heat, Wind, Snow — `WEATHER_CONDITIONS`,
  ids `tripset-weather-0…4`, heading `tripset-weather-title`, blue, several at once — the trip's
  `weatherOn`: his gear tagged for a picked condition comes onto the list whatever the forecast; the
  web app's "pack anyway"), Food (`tripset-transport-*`, `tripset-season-*`, `tripset-catering-*`,
  headings `…-title`), Laundry (`tripset-laundry`, `-says`, `-nights-*`).
- "Save rebuilds the list: what you ticked, added yourself or were sent stays; new things arrive; things
  no longer asked for go." (14 muted), a divider, and **Start a new trip from this one** (next section).
- Bottom bar (top hairline, `Theme.bg`): the still-needed line (15 bold red, id `tripset-needs`) and
  **Save changes** (18 bold white on green, min height 52, id `tripset-save`), never disabled.

### Behaviour
- **Load** (once, on appear): name, place = `destination`, dated iff `startDate` non-empty, start =
  start date (or today), end = end date (or the start), Quick iff mode "quick", laundry, laundry nights
  (`laundryNights(trip)`), templates = `trip.activities`, each template's contexts = its own entry in
  `activityContexts`, else the trip-wide `contexts` (0.67: what its things are narrowed by now — so a trip
  made before 0.67 shows its one Context on every workout, and a Save without a change rebuilds the same
  list), the trip's own `activityContexts` kept aside for the templates not shown, transport/season/food (empty →
  "Car"/"Summer"/"mixed"), weather anyway = `trip.weatherOn`; the trip's template ids this screen does
  not offer (a template deleted since, or the sender's templates on a trip someone sent) are noted
  (`unshown`). An undated trip's field says "Add dates"; its grid opens on this month.
- **Still needed** (same words as Create new trip) is computed on Save; after that it follows the
  template pills (not the name field).
- **Save**: nothing missing → `Library.changeTrip(id:)` with: name, place (trimmed; **a NEW place
  — compared trimmed — sets `destination` and clears `weather` and `geo`**, so the weather line looks
  the new place up), mode, `activities` = the ticked ids that are offered templates, in the order
  offered, THEN the trip's ids this screen does not show, as they were (0.62: they were dropped — a Quick
  trip whose template was deleted lost its Save without a word, `changeTrip` refusing a Quick trip with
  no template), `activityContexts` (0.67: an entry for every ticked offered WET template —
  `WorkoutContexts.stored`, nothing picked = empty — plus, as they were, the entries of the ticked
  templates this screen does not show), `contexts` = every context in those entries (`WorkoutContexts.union`),
  transport, season, catering, `weatherOn` (`WEATHER_CONDITION_IDS` order), laundry, `extra.laundryNights`,
  dates (no dates — never picked, or Clear dates — → both "").
  `changeTrip`: trims the name; refuses (nil, nothing changed) a blank name, or a QUICK trip with no
  templates; `nights = nightsBetween ?? 0`; `entries = regenerated(trip)`; `updatedAt = now`; returns
  `TripRebuilt(added:removed:)` = line ids new / gone. The sheet then closes and the trip says what
  changed (`trip-rebuilt`).
- **`Library.regenerated(trip)`** (the web app's `regenerateEntries`, with two fixes):
  1. Build the fresh list (`buildTotalEntries`).
  2. Each fresh line takes an OLD line with the same `sourceItemId` if one is left — preferring one in
     the same bag (normName) — and the old line (its id, tick, edits) is kept as it was. Each old line
     is taken at most once (the E.6 fix: a thing on the trip twice keeps both lines and their own
     ticks). Unmatched fresh lines are new.
  3. Old lines not taken are KEPT when: custom (typed, Bought on site, weather gear); or ticked or
     edited and no fresh line has their `sourceItemId`; or their template no longer exists
     (docs/store.md rule 9 — one of his real trips would have gone from 88 lines to none); or they have
     NOTHING behind them — no `sourceListId`, no `sourceItemId`, not custom: a line someone SENT (a
     share travels without those links). 0.62: the first Save threw a received trip's whole list away,
     ticks too. A fresh line with the same `normName(name)|container` as such a sent line is not added
     beside it. Everything else goes (unticked lines no longer asked for).
  4. Any id seen twice gets a new id ("belt and braces").
  Order: fresh lines in build order, then kept old lines in their old order.
- Effects of what is kept: a line's own tick, set-aside, notes and marks survive with its id; a line
  that moved to another template under the same thing is matched by `sourceItemId`.

### Data
Rewrites the trip head and the changed/new lines; deleted line records are removed.

### Tests
UI: `testATripSomeoneSentKeepsItsListOnSave` (a trip sent and received, ticked, saved: "Saved. The list
is the same.", still 1/7), `testWeatherGearCanBePackedAnyway` (Rain picked, saved, still picked),
`testATemplateWithNoActivityAreaGoesOnATrip` (its template deleted, a Quick trip's rename is still saved),
`testASwipeDownKeepsWhatIsNotSavedYet` (iPhone), `testEscapeClosesTheTripsWindows`,
`testATripsSettingsAreChangedAfterItIsMade` (starts from the trip; rename to "Hills and lake",
place kept, adding Swim → "1/10" with the tick kept and "Saved: 3 new"; blank name refused under Save
with "name" in the message; Cancel changes nothing), `testLaundryCountsPerNightThingsFourNightsAtMost`,
`testATripChecksTheCabinAndTheDatesBeforeYouGo` (Car via Trip settings removes cabin checks); 0.67:
`testFullTripOrQuickIsChosenUnderTheName` (Quick shown; Full trip saved brings the common base, 0/4 → 0/7),
`testDatesAreAlwaysThereAndCanBeCleared` (no `tripset-dates` switch; dates given and saved; Clear dates and
saved → "No dates"), `testEachWorkoutHasItsOwnContext` (each workout's picks shown; Swim changed alone).
Model: `WorkoutContextsLibraryTests` (a change of one workout's Context rebuilds 1 added / 1 removed),
`ChangeTripTests.testAChangedTripRebuildsAndKeepsWhatHeDid` ((2 added, 1 removed), ticked and
typed lines stay, name trimmed, nights 3, refusals),
`testAThingOnTheTripTwiceKeepsBothLinesAndTheirTicks`, `testATripSomeoneSentKeepsItsListOnSave` (kept, not
doubled, his templates join only when ticked or Quick goes off), `testWeatherGearForcedOnComesWithTheList`,
`LibraryTests.testRegeneratingNeverDropsTheLinesOfADeletedTemplate`,
`testRegeneratingStillDropsWhatALivingTemplateNoLongerHas`, `OnTheTripTests.testABoughtOnSiteLineIsInHandMarkedAndKept`
(a rebuild keeps bought-on-site lines), `TripChecksTests.testABagNameOnTheTripCanBeSaidToGoInTheCabin`.
**Not covered:** a new place clearing weather/geo; Food changes through the screen; the entries of a
template this screen does not show being kept on Save.

### Traps and history
- 0.39 crash fix (E.6): see regenerated step 2/4.
- The pen's sheet is owned by its own view because SwiftUI does not reliably stack two sheets on one view.

---

## Start a new trip from this one (`TripSettings.swift`, `TripAgain.swift`)

**Purpose and origin.** The web app's trip menu "Start a new trip from this one — same list, fresh
ticks" (0.33): "A preset only remembers the answers on Create; this copies the LIST as it finally
ended up, after a week of corrections."

### What is on screen (at the bottom of Trip settings)
- Closed: an outlined green button (1.4 pt, corner 12, min height 56): "Start a new trip from this one"
  (17 bold green) / "Same list, nothing ticked" (14 muted); id `tripset-again`.
- Open: a card with a green border: "Name the new trip" (16 heavy); a field prefilled with
  `Library.againName(<the trip's SAVED name>)` = "<name> (again)" ("Trip (again)" for an empty name),
  id `tripset-again-name`, Return = Start it; "The same list as this trip, nothing ticked, no dates."
  (14 muted); **Not now** (16 bold ink, id `tripset-again-no`) closes it; **Start it** (green capsule,
  16 heavy white, id `tripset-again-yes`); with a blank name: "Give the new trip a name." (15 bold red,
  id `tripset-again-needs`).

### Behaviour
`Library.startAgain(from:name:)`: trims the name (blank → nil); copies mode, activities, transport,
season, contexts, `activityContexts` (each workout's Context, 0.67), weatherOn, catering, laundry, destination and `extra.laundryNights`; NOT the dates,
weather, map point, status or review. Every line copied with a new id, `checked = false`,
`skipped = false`, `used = nil`, and its marks `packedAt`, `boughtThere`, `packedHome`, `usedUp`,
`homeNote` removed (0.62: a copied bought-on-site mark made the new trip stand at On site at once);
`custom` and `_edited` stay — what the line IS comes along, what happened on the old trip does not.
The new trip is appended (not via `createTrip`: no `generatedAt`, nights 0). Trip settings
closes WITHOUT saving any other edits made in the sheet, and the trip screen switches to the new trip
with "New trip from “<old name>”: N things, nothing ticked. Its dates are under the pen."

### Tests
UI `testANewTripStartsFromThisOne` (name offered "Weekend in the hills (again)", the screen switches,
0/7, "New trip from" note; blank name refused; Cancel starts nothing; the old trip keeps 1/7). Model
`TripAgainTests.testANewTripStartsFromThisOnesList`, `testANewTripLeavesWhatHappenedOnTheOldOneBehind`,
`LaundryNightsTests.testAStartedAgainTripAndTheStoredRecordsKeepTheChoice`.

---

## A change to a thing reaches the trips still ahead (`ThingFollows.swift`)

**Purpose and origin.** His decision on test I.7 (1 Oct 2026, 0.45): a change to a THING — its bag,
weight, place, name — reaches the trips already made, but only where nothing has been decided yet.

### Behaviour
`Library.followThing(id:today:)` runs after every `updateThing`, `renameThing` (and so after setPlace,
Keep in Refine, cabin changes):
- A trip is still ahead when not reviewed (`Library.isReviewed`) AND (undated, or its end — the start
  when no end — ≥ today). `today` defaults to `Library.localToday()`, the date in the device's time zone
  as every screen goes by (0.62; it was the UTC date, so just after midnight in Sweden a trip that
  ended yesterday still took a change).
- Only lines with that `sourceItemId` that are not ticked, not custom and not edited.
- Each such line is rebuilt as a new trip would build it (`buildTotalEntries` for that trip, the
  fresh line from the same `sourceListId` first, else any unused fresh line of that thing), keeping
  its id, `checked`, `skipped`, `used` AND its own `extra` marks (`packedHome`, `usedUp`, `homeNote`,
  `packedAt` — 0.62: they were wiped); everything else is the fresh line's. A bag
  chosen on a template row still wins. A line no fresh build produces any more (e.g. its row's tags no
  longer match the trip) is left as it is. Only lines that actually differ are written; changed lines
  bump the trip's `updatedAt`. `resolvedTemplates()` is computed once per call, only when some trip
  has an open line of the thing.
- Ticked lines, edited lines, typed lines and finished or reviewed trips keep what they were packed with.
- A row of a template saved in its row editor runs it too (`saveRow`, spec 04 §7 — the spec pass, 5 Oct 2026):
  the row's own bag, When, how many, note and "Only on" reach the same open lines.

### Tests
Model `ThingFollowsTests` (5 tests, with `testStillAheadGoesByTheDayWhereHeIs` and
`testALineKeepsItsOwnMarksWhenItsThingChanges`), `TemplateRowsTests.testARowChangeReachesATripStillAhead`, `ThingsTests.testYourThingsListsEverythingAndARenameReachesEveryList`
(a past trip keeps the old name). UI `testAChangeToAThingReachesATripStillAhead`.

---

## Check before you go (`TripChecks.swift` screen + `PackingLibrary/TripChecks.swift`)

**Purpose and origin.** His pre-trip ideas 4 and 5 (2 Oct 2026, 0.48): on a plane trip, what in a
CABIN bag the airport stops (not allowed on board; liquids); and what runs out before he is home — a
document (passport, ID card) within six months of coming home. "Colour is the message: red will stop
him; orange wants a look."

**How it is reached and left.** First card in the trip's scroll area, only when something needs him.
A line opens the thing's editor as a sheet (`ThingEditor`, Care spec); the card disappears as soon as
the last line is put right.

### What is on screen
Card (padding 14, corner 12, 1.2 pt border in the tint), id `trip-checks`: "Check before you go" (15
heavy) and a count capsule (13 heavy white on red if any line is red, else orange), id
`trip-checks-count`. Then one button per flag (min height 44): a drawn icon 22 pt in the line's tint
(the plane icon for cabin lines; the passport icon for documents; a drawn hourglass for other dates),
the line's name (16 bold ink), the reason (15 medium, tint), and a chevron when there is a thing to
open. Ids: cabin lines `trip-check-cabin-<n>` first, then date lines `trip-check-date-<n>`.

Reasons (`TripChecksCard.says`), dates as "3 Mar 2027" (fixed English months):
- not allowed (red): "Not allowed in the cabin · in <bag>"
- liquid (orange): "Liquid: 100 ml at most, in the clear bag · in <bag>"
- out of date already (red): "Out of date since <day>"
- runs out before home (red): "Runs out <day>, before you are home"
- document short of six months (orange): "Valid until <day>: less than 6 months after you are home"

### Behaviour
- **Cabin** (`cabinCheck`): only when `transport == "Plane"` (Quick trips too — Quick drops the
  transport kit, not the transport). Lines: not reminders, not set aside, in a cabin bag. Judged by the
  THING as it is now (`thingNow`: the catalogue item with the line's `sourceItemId`, else the line):
  restricted → not allowed; else liquid → liquid. All "not allowed" first, then liquids, each in list
  order.
- **Cabin bag** (`isCabin(container:)`): if one of his bags has that name (normName), the bag's own
  `extra.cabin` when set, else its name; a bag he never made: its name. By name = normName contains
  "carry-on", "carry on", "carryon", "hand luggage" or "cabin".
- **Dates** (`dateCheck`): only when `endDate` is a YYYY-MM-DD. Lines not set aside, each given its
  thing's current `expiry`, `category` and retired flag. Documents (category exactly "Documents &
  money") are judged against end + 6 months (`ymd(plusMonths:)`: same day, or the month's last day);
  other things against the end. The core `expiringOnTrip` keeps lines that are not reminders, not
  retired, have a YYYY-MM-DD expiry ≤ the judge date, one per thing (`sourceItemId` or line id).
  `alreadyOut` = expiry < today; `beforeHome` = expiry ≤ end. All flags sorted by expiry, soonest first.
- Tapping a line with a thing opens its editor; a line typed on the trip has no thing (no chevron, tap
  does nothing).

### Tests
Model `TripChecksTests` (7: cabin bags only, the thing as it is now, a bag's own word, a bag name on the
trip, a Quick trip by plane, dates + six months, `ymd(plusMonths:)` incl. 31 Aug → 28 Feb and leap
years). UI `testATripChecksTheCabinAndTheDatesBeforeYouGo` (order knife, sun cream; dates sun cream,
passport; Liquid off removes one; clearing the passport's date removes it; Car removes cabin checks),
`testABagSaysWhetherItGoesInTheCabin`, `testABagOnTheTripSaysWhetherItGoesInTheCabin`.

---

## The weather card (`WeatherCard.swift`, `Store/Forecast.swift`, `TripWeather.swift`, `PackingCore/Weather.swift`)

**Purpose and origin.** "The weather on a trip: one line of what it will be like, and under it the
gear that weather calls for which is not on the trip yet — each with one press to take it along"
(0.4). Add all (0.36). A place without a forecast still reaches the map (his G.6, 0.40). Open-Meteo,
"the same two calls the web app makes".

### What is on screen (card, padding 12, corner 12, id `weather-card`)
**Without a forecast:** a field "Where is this trip?" (16 medium; prefilled with the trip's
`destination`; Return looks it up), id `weather-place`; **Weather** (15 bold white on green; "Looking…"
while busy), id `weather-look`, never disabled; after a press with a blank field "Type a place first."
(15 bold red, id `weather-look-needs`, goes when typing).
A look (Weather or Return) first puts the keyboard away (`@FocusState typing = false`): the field leaves the
card when the forecast arrives, and leaving with the keyboard still up froze the iPhone on "Looking…" (iOS 26.5;
`testTheWeatherSaysWhatItWillBeLikeAndWhatIsMissing` timed out — found at the 0.68–0.71 merge, already in 0.67).

**With a forecast:**
- The line (17 bold ink, id `weather-line`): the conditions in his words — rain "Rain", snow "Snow",
  cold "Cold", hot "Heat", wind "Wind" — none: "Nothing to watch out for"; one: "Rain"; two: "Rain and
  cold"; three or more: "Rain, Cold and wind" (later words lower-cased only for the last) — then ",
  2–8°C" unless the range contains "NaN".
- The place as the service named it (14 semibold muted, e.g. "Testville, SE") and **Look again** /
  "Looking…" (15 bold green both ways, never switched off — 0.62, his rule; a press while it looks does
  nothing more, one look at a time), id `weather-again`.
- One row per missing piece of gear (id `weather-gear-<n>`): "+" (22 heavy green), the name (16 medium),
  why (13 semibold muted): "for the <condition word lower-cased>" — "for the rain", "for the snow",
  "for the cold", "for the heat", "for the wind" — plus " · yours" for his own gear. A tap adds it.
  Rows are keyed by the gear's name.
- **Add all N** (green capsule, 15 bold white; value N), id `weather-addall` — only when 2 or more are
  missing.
- Nothing missing: "You have what this weather asks for." (14 semibold muted, id
  `weather-nothing-missing`).

**Trouble** (either state; 14 semibold red, id `weather-trouble`): "No place found for “<name>”." /
"Could not reach the weather service — check the connection." / "No forecast for those dates yet."

### Behaviour
- **Looking up** (`LibraryModel.lookUpWeather`): name = trimmed typed place (or the trip's); blank or
  already busy for this trip → nothing. Clears trouble; (1) geocode → keeps the place AT ONCE: trip
  `destination` = the typed name, `geo` = the service's spot and label (map pin) — even if no forecast
  follows; (2) forecast for the trip's start and nights → `setWeather` (destination = place, weather =
  snapshot, geo with the snapshot's place). Any error → the trouble line.
- **Open-Meteo** (`OpenMeteo`): geocoding `…/v1/search?name=<n>&count=1&language=en&format=json`; label
  "<name>, <country_code>". Forecast `…/v1/forecast?latitude&longitude&timezone=auto&daily=weathercode,
  temperature_2m_max,temperature_2m_min,precipitation_probability_max,windspeed_10m_max`; when the trip
  starts 0…16 days ahead, `start_date` = start and `end_date` = start + nights (cut at today + 16);
  otherwise the service's default days. No days → "No forecast for those dates yet."; HTTP ≥ 400 or
  any network/parse failure → offline.
- **Automatic look-up** (`forecastWorthFetching`): the trip has a place AND a start date AND starts
  between −nights and +16 days from today (`OpenMeteo.days`, rounded whole days) AND the held forecast
  is stale (`forecastIsStale`: none or no days; or the forecast's place name does NOT begin with the
  first three letters of the trip's place, both lower-cased (only when both are non-empty); or
  `fetchedAt` older than 6 hours or unreadable). Asked (a) once when the card first appears on the open
  trip screen (`asked`), and (b) when the trip's `destination` changes (e.g. saved in Trip settings) —
  but only while the trip holds NO forecast and the new place is non-blank; when (b) finds no forecast
  can exist and the trip has no map point yet, the place is only put on the map (`placeOnMap`). On
  (b) the card's field also takes the new place; on appear the field is prefilled with the
  `destination` only if it is empty.
- **What the forecast means** (`deriveWeather`, thresholds `WEATHER_THRESHOLDS`): WMO codes → icon/label/
  wet (51–67 drizzle/rain, 71–77 snow, 80–82 showers, 85–86 snow showers, ≥ 95 thunderstorm); a day is
  rainy when wet or rain chance ≥ 50 % (unrounded); conditions in order rain (a rainy day that is not
  snow), snow, cold (lowest min ≤ 5 °C, or a Summer trip whose lowest max < 14 °C), hot (highest max ≥
  27 °C), wind (a rounded max wind ≥ 35 km/h). A day without a temperature makes the range "NaN–NaN°C"
  and trips no temperature condition.
- **What it asks for** (`Library.weatherMissing`, which hands the web app's `weatherSuggestions` its
  input — the parity-checked function itself is unchanged): (1) his own weather-tagged rows of EVERY
  template the trip is built from — the always-packed and transport ones too, not only those he ticked
  (`listsForEvent`; a Quick trip: only the ticked) — whose tags meet a condition, that match the trip
  (season/transport/food/context), whose thing is not "Not in use", and whose name is not on the trip;
  (2) the curated add-ons for EVERY active condition (not only for conditions his own gear left open) —
  rain: Rain jacket, Waterproof / pack cover; cold: Warm mid-layer, Beanie + gloves, Long tights; hot:
  Sun hat / cap, Sunscreen (liquid), Extra water bottle; wind: Windbreaker; snow: Warm gloves, Traction
  spikes — each unless its name is on the trip or already suggested. Own gear: the FIRST of a row's
  weather tags that is an active condition is its reason; of two templates with one id the last is used.
  All names compared with normName. (0.62, the spec pass: a retired rain jacket was offered and Add all
  put it on; tagged gear on the base was held back from the list AND never offered.)
- **Taking one** (`addWeatherGear`): a custom line (survives rebuilds) with the gear's bag and When
  (else the defaults), and for his own gear its `sourceListId`/`sourceItemId` (so the review credits the
  thing), category, Swedish name, kind, liquid flag, weight. **Add all** (`addAllWeatherGear`) adds each
  missing one once.

### Data
`trip.destination`, `trip.weather`, `trip.geo`; new lines. `LibraryModel.lookingUpWeather` (per trip),
`weatherTrouble[tripId]` — memory only. The card reads its trip through `Library.trip(_:)` — the FIRST
trip with that id, as everywhere else (0.62; it took the last).

### iPhone vs Mac
Identical. Under the UI tests the forecast is invented (`InventedForecast`): any place → "Testville,
SE" with rain (code 61), 2–8 °C, 90 %, wind 24 for days 0…max(1, nights); a name containing "late" →
"Lateville, SE" with no forecast; "nowhere" → not found.

### Tests
UI `testTheWeatherSaysWhatItWillBeLikeAndWhatIsMissing`, `testWeatherAddAllTakesEverything`,
`testTheMapShowsWhereTheTripsWent` (no-forecast place still on the map), `testEveryAddButtonIsReadyAndSaysWhatIsMissing`
(`weather-look`). Model `TripWeatherTests` (6: kept and read back, missing gear, staleness incl. a
different place, survives a backup, `testRetiredGearIsNeverOfferedAndTheBasesOwnGearIs`,
`testTwoTripsWithOneIdAreReadAsTheFirst`), `TripBulkTests.testAddAllTakesEveryWeatherSuggestionOnce`,
`testHisOwnWeatherGearKeepsItsSource`, `WeatherTests` (all 19).
**Not covered:** the automatic look-up rules; "Look again"; the trouble words for offline.

---

## The Bags card, the luggage scale, the cabin switch and bag photos (`BagsCard.swift`, `BagCabin.swift`, `BagPhoto.swift`, `Weighing.swift`, `OnTheTrip.swift`)

**Purpose and origin.** "How heavy each bag on this trip is, against what it may carry" — the web
app's "Bags & weight" (0.17). Colour key ⓘ (his ask 2026-09-26, 0.25); "no max" (0.25); luggage scale
(his idea 8, 2 Oct 2026, 0.50); one thick bar per bag (their choice 3 Oct 2026, 0.57: "we would like one
bar"); Goes in the cabin on the trip (field test 7.3/6.1, 0.55); photos of the packed bag (idea 11,
0.52) — up to three (field test 3 Oct 2026, 0.56: "sometimes you would like a photo from different
angles").

### What is on screen (card id `bags-card`; padding 14, corner 12; border red when any bag is over)
- Header: "Bags" (15 heavy ink); ⓘ (a drawn circle with "i", id `bags-key-open`, label "What the colours
  mean") toggles the key; "N over" (13 heavy white on red capsule, id `bags-over`) when any bag is over;
  the total weight of the shown bags (14 heavy mono muted, id `bags-total`).
- Key (id `bags-key`): "Blue — well within its max", "Orange — nine tenths of its max or more", "Red,
  “over” — more than its max", and "No bar: no max set. Set one in Care → Bags. Tap a bag for the luggage
  scale, and a photo of it packed."
- One row per bag (a button, id `bag-<n>`, accessibility value = the gauge in words): the name ("Not in a
  bag" for "Other"; 15 semibold); at the right "<weight> / <max> kg", or "<weight> · no max", or only the
  weight for "Not in a bag" (14 bold mono; red when over); weight = "<kilos> weighed" once weighed. Only
  a bag WITH a max has a bar: 16 pt capsule, `Theme.line` track, fill = min(1, kg/max) of the width (at
  least 16 pt) in blue (fine), orange (close) or red (over). Weighed: "The things in it add up to
  <kilos>" (13 medium muted).
- Tapping a row opens (and a second tap closes) under it — only one bag open at a time:
  1. **The scale**: field "kg on the scale" (17 semibold mono, decimal pad on the iPhone, id
     `bag-<n>-scale`, Return saves), **Save** (green capsule, id `bag-<n>-scale-save`), **Clear** (15
     semibold muted, only when weighed, id `bag-<n>-scale-clear`).
  2. **Goes in the cabin** switch (id `bag-<n>-cabin`), not for "Not in a bag".
  3. **Photos** (`BagPhotoRow`): thumbnails 80×80 (corner 8, id `bag-<n>-photo-thumb-<k>`, label "Photo
     k of the packed bag") each with **Remove** under it (15 semibold muted, id
     `bag-<n>-photo-remove-<k>`, no confirmation); then, while fewer than three are stored, the add
     pills (15 bold green, 1.4 pt green outline): on the iPhone "Take a photo"/"Take another" when a
     camera exists (id `bag-<n>-photo`) and "Choose a photo"/"Choose another" (PhotosPicker, id
     `bag-<n>-photo-pick`); on the Mac only Choose; under the UI tests one pill "Photo of the packed
     bag"/"Another photo" (id `bag-<n>-photo`) that keeps a drawn picture. At three: "Three photos —
     remove one to add another" (15 medium muted, id `bag-<n>-photo-full`).
- A thumbnail opens **BigPhoto** (sheet): "k of N" (15 bold mono muted, id `bag-photo-count`) when
  more than one, a caption when given (17 heavy green, up to 2 lines, `bag-photo-caption`), **Next**
  (outlined, only with more than one, id `bag-photo-next`) and **Done** (filled, id `bag-photo-done`);
  the photo fills the space (scaled to fit); a drag of ≥ 30 pt that is more horizontal than vertical
  steps — leftwards = next, rightwards = previous; it wraps both ways (after the last the first, before
  the first the last). Opening at an index outside the photos clamps it. Mac minimum 520 × 600.
- Thumbnails show only photos whose record is on this device and decodes; "full" (no add pills) counts
  the STORED ids, so a photo still syncing in takes its place.

### Behaviour
- Bags shown: `Library.weighedBags(tripId:)` = `bagLoads(lines, qtyNights, bagLimits())` with each bag's
  scale reading (`weighed`, only finite readings > 0). The Bags CARD keeps every bag with at least one
  line, weighed or not (0.62: a bag whose things weigh nothing was left off, and its scale, cabin switch
  and photos could not be reached), and is not drawn at all when there is none. A bag with nothing
  weighed (0 g, no scale reading) says **"Tap to weigh"** where the weight goes, draws no bar, and its
  value is "not weighed". Order: CONTAINERS order, then his own in first-appearance order. `bag-<n>`
  numbers the shown bags.
- Weight that counts: the scale reading when there is one (`WeighedBag.grams`), else the things' sum.
  `over` = max > 0 and kg > max; **close** = max > 0 and kg ≥ 0.9 × max; gauge "fine, 25% of its max" /
  "close, 94% of its max" / "over, 119% of its max" (percentage rounded) / "no max".
- `kilos(g)`: under 1000 g → "N g" (rounded), else "%.1f kg". Max shown as an integer when whole, else
  one decimal.
- Scale **Save**: trims, comma → point, `Double` (unreadable → 0); > 0 → `setWeighed(grams: kg × 1000)`
  (stored rounded to whole grams); otherwise the reading is REMOVED (no message). Opening prefills the
  reading in kg (one decimal). `setWeighed` with nil/0/negative/NaN/∞ removes the bag's entry, and the
  `weighed` key when empty.
- **Cabin switch** (`setCabin(container:on)`): refuses "" and "Other"; a bag name that is not one of his
  bags BECOMES a bag (on his bag list, created if he has none; also visible in Care → Bags) and its
  thing gets `extra.cabin`. The cabin check follows at once.
- **Photos**: a picked or camera image is made JPEG, at most 1600 pixels on the long side, quality 0.75,
  orientation applied (`JPEG.make`; the camera's image is first encoded at 0.9). `addBagPhoto` refuses
  an empty picture, an unknown trip, an empty bag name and a fourth photo; stores a `PhotoRecord {id,
  data: "data:image/jpeg;base64,…", createdAt}` and appends its id to `bagPhotos[bag]` (always written
  as a list). `removeBagPhoto` takes the id off (the bag entry and the key go when empty) and deletes the
  photo record unless a thing, a trip line or another bag (any trip) still shows it (`photoInUse`).
  Photos are kept per trip and per bag NAME (the bag's displayed container string, "Other" for loose
  things).

### Tests
UI `testABagWithNothingWeighedIsOnTheTrip` (a thing moved to another bag with no weight: that bag is on the
card, "not weighed", and its scale opens), `testABagIsWeighedOnTheLuggageScale` (25 % fine → 7.5 kg close 94 % → 9.5 kg over 119 % with
"9.5 kg weighed" and "N over" → Clear), `testABagsLimitReachesTheTrip` (his own limit reaches the trip;
the ⓘ opens and closes the key), `testAPackedBagKeepsItsPhoto` (three photos, no fourth, "2 of 3", Next
→ "3 of 3", Remove → add again, the way home shows two), `testABagOnTheTripSaysWhetherItGoesInTheCabin`,
`testATripIsDeletedOnlyAfterAsking` (photo taken, then deleted with the trip).
Model `WeighingTests` (2), `OnTheTripTests` (photos ×5), `BagNotesTests` (rename/delete carry readings
and photos), `BagsTests.testALimitSetHereIsTheLimitATripUses`, `TripChecksTests.testABagNameOnTheTripCanBeSaidToGoInTheCabin`.
**Not covered:** comma decimal input; unreadable scale input clearing the reading; the camera.

### Traps and history
- 🪤 `containerLimits` must get resolved templates (see Counting).
- A photo still on its way from the other device counts against the three (ids are counted as stored).
- 🪤 Production CloudKit lacked the blob fields until the first bag photo (3 Oct 2026) — one refused
  record failed the whole batch (docs/store.md).

---

## The loop (`Screens/Loop.swift`, `PackingLibrary/Loop.swift`)

**Purpose and origin.** His picture (2026-09-27, 0.31): "Phase 1 is the planning, making the lists, and
performing, packing, and later on reviewing, and then refining and so on." On site joined after Pack
(field test 3 Oct 2026, 0.57: "add a phase (in the graphics as well)… immediately after Pack"). Tab
marks on the strip (his F.7, 0.41). The round arrow after Refine removed (it read as a reload button,
0.40).

### The five steps and when a trip stands at each — `Library.loopStep(tripId:today:)`
Checked in this order:
1. no such trip → **Plan**;
2. `status == "done"` or `reviewedAt` set → **Refine**;
3. its end (end date, else start) is before today → **Review**;
4. no lines → **Plan**;
5. a valid start date ≤ today → **On site**; any trip with something bought on site → **On site**,
   whatever its dates say (0.62: a dated trip still ahead stayed at Pack while its On site door showed;
   the door and the loop now go by one rule);
6. otherwise → **Pack** (ticked or not, until it begins).

| Step | rawValue | Name | About | Tab mark | Short words | Explained |
|---|---|---|---|---|---|---|
| plan | 0 | Plan | lists (violet) | Home | "Make templates, create a trip" | "Your templates hold what each kind of trip needs. A new trip gathers what its templates hold." |
| pack | 1 | Pack | one trip (green) | Trips | "Tick things as they go in" | "Tick each thing as it goes in. The count says when nothing is left." |
| onSite | 2 | On site | one trip | Trips | "Bought, left, notes, and packing for home" | "While you are away: what you bought, what you left on site, a note on a thing that needs care, and packing to go home. It opens on the trip once the trip has begun." |
| review | 3 | Review | one trip | Trips | "After it: unused, missed" | "After the trip: tap what you did not use, add what you missed. This looks back at one trip." |
| refine | 4 | Refine | lists | Templates | "Keep or drop, from reviews" | "When two or more reviews agree, Refine offers to take a thing off a template — or keep it for good. Your templates get better, and the next trip starts from them." |

### The strip (`LoopDoor`)
A button (ids: `trip-loop` on a trip, `review-loop` on the review — always Review — and `refine-loop`
on Refine — always Refine; label "The loop", value = the step's name) showing the five names with
small drawn chevrons between them. The current step: white heavy words on a capsule in its tint, with
the tab's mark; the others: semibold words in the readable tint on a `Theme.card` capsule with a 70 %
tint outline (min height 28). It slims down until it fits (`ViewThatFits`): every mark, 14 pt, padding
8, chevron room 14; then only the current step's mark, 14 pt, padding 7, 10; then 13 pt, padding 5, 8.
A tap opens **LoopScreen** (sheet: "The loop" 22 heavy, Done filled green id `loop-done`, the picture
and the words; id `loop-screen`; Mac minimum 520 × 640).

### The picture (`LoopPicture`, also on How it works as `guide-loop`)
Two boxes per row: Plan → Pack on top; down the right side Pack ↓ On site ↓ Review; Refine ← Review at
the bottom; one long arrow up the left from Refine to Plan; a key "About your templates" / "About one
trip". Each box (id `loop-step-<n>`): "n · Name" (18 heavy, readable tint), the short words (14 medium
ink), the tab mark + "on <Tab>" (13 bold, tab colour), and "You are here" (13 heavy white on the tint)
on the trip's step; fill 24 %/12 % tint, border 3/1.2 pt. Accessibility label "Name: short, on Tab"
plus ". You are here" (the Mac drops a non-control's value). `LoopWords`: each name (16 heavy, 72 pt
column) with its explanation (16), then "Review looks back at one trip. Refine uses several reviews to
make your templates better." (16 bold).

### Tests
Model `LoopTests` (3: every case above incl. a one-day trip, empty trips, undated; bought on site
begins a trip, dated or not; names/order/aboutOneTrip). UI `testTheLoopShowsWhereATripStands` (five
steps, labels with tabs, no "You are here" in the guide, trip at Pack or Review, the picture marks it,
review at Review, after saving the review the trip is at Refine, Refine at Refine),
`testATripUnderWayStandsAtOnSite` (strip fits the screen width).

---

## On site (`OnSiteScreen.swift`, `OnSite.swift`)

**Purpose and origin.** The step after Pack (field test 3 Oct 2026, mission 9.1, 0.57): "During this
phase, we could add stuff as: items bought there; items discarded there (not more needed); maintenance
or other actions." He chose that it holds all four: Bought on site · Left on site · Maintenance notes ·
Pack to go home. Nothing new is stored on the trip; a maintenance note ALSO lands on the thing, dated,
for Care.

**How it is reached and left.** The **On site door** on the trip screen (after the Bags card): shown
when `onSiteBegun` — the trip has a valid start date and today ≥ start (it then stays for good, also
after the trip), OR any line is bought on site, whatever the dates say: buying on site says he is there.
The loop's On site step goes by the same rule since 0.62 (a dated trip still ahead with something bought
on site showed this door while the loop said Pack). The door: "On site" (17 heavy) over the summary (14
medium mono muted, one line, scales to 0.85) and a chevron; card with a 1.2 pt green border, min height
58; id `trip-onsite`, accessibility value = the summary. It opens the page as a sheet; **Done** (filled
green, id `onsite-done`) closes it. Screen id `onsite-screen`; Mac minimum 520 × 640.

**Summary** (`onSiteSummary`): only what there is, joined " · ": "N bought", "N left", "1 note"/"N
notes", and always "home D/T" (the way home) — e.g. "2 bought · 1 left · 3 notes · home 4/9".

### What is on screen
Header "On site" (24 heavy green) with the summary under it (15 bold mono muted, id `onsite-summary`)
and Done. Then four parts (each a `SectionTitle`, upper case 18 heavy):

1. **BOUGHT ON SITE** (green, title id `onsite-bought-title`, container `onsite-bought`): "Nothing bought
   yet." (16 medium muted, id `onsite-bought-none`) or the names (17 semibold, ids `onsite-bought-<n>`);
   a field "What did you buy?" (id `onsite-bought-name`, Return adds) and **Bought on site** (16 bold
   white on green, id `onsite-bought-add`); pressed with nothing typed: "Type what you bought first."
   (16 bold red, id `onsite-bought-needs`, goes when typing). Adds with `addBoughtOnSite`.
2. **LEFT ON SITE** (ink, `onsite-left-title`, container `onsite-left`): "Nothing left on site."
   (`onsite-left-none`) or the names (`onsite-left-<n>`) each with **Undo** (15 semibold muted,
   `onsite-left-<n>-undo` → `setUsedUp(false)`); **Leave something here** (wide, green outline, id
   `onsite-leave`) opens a line picker "What stays on site?" over the way-home lines not used up; a pick
   → `setUsedUp(true)` and the picker closes. Empty: "Nothing to leave: what went is ticked on the way out."
3. **MAINTENANCE NOTES** (orange, `onsite-notes-title`, container `onsite-notes`): "No notes yet. A note
   goes onto the thing too, for Care." (`onsite-notes-none`, hidden while writing); each line WITH a note
   (any line of the trip): its name (17 semibold, `onsite-note-<n>`), the note (16 semibold orange,
   `onsite-note-<n>-text`) and **Change** (`onsite-note-<n>-change`) which opens the editor in place.
   **Add a note** (wide, orange outline, `onsite-note-add`; hidden while a note is being written) opens
   a picker "A note for which thing?" over ALL way-home lines (used up included; empty words "Nothing to
   note yet: what went is ticked on the way out."); a pick opens the editor under the list with the
   line's name (`onsite-note-for`). Editor: field "e.g. Zip broken" (17 medium, focused at once,
   prefilled with the line's note, `onsite-note-field`, Return saves), **Save** (16 bold white on
   orange, `onsite-note-save`), "Type the note first." (16 bold red, `onsite-note-needs`, goes when
   typing) for an empty NEW note, a hint "Also goes onto the thing, for Care." or "Kept with this
   trip." (14 medium muted; no thing behind it), **Cancel** (`onsite-note-cancel`, nothing saved).
4. **PACK TO GO HOME** (green, `onsite-wayhome-title`, container `onsite-wayhome`): "Nothing to bring
   home yet." or "D of T packed" (17 bold mono; green when complete, else ink;
   `onsite-wayhome-progress`) and **Pack to go home ›** (17 bold white on green with a drawn chevron,
   min height 52, `onsite-wayhome-open`) → the way home sheet (owned by the On site page).

Small side buttons (Undo, Change, Cancel): 15 semibold muted words, min height 40. Wide buttons
(Leave something here, Add a note): 16 bold words in the tint, 1.4 pt tint outline, corner 12, min
height 48. Lines: 17 semibold ink, up to 2 lines, a hairline under each.

**The line picker** (`LinePicker`, Leave and Add a note): title (17 heavy), **Close** (outlined muted,
`<prefix>-close`), a search field "Search what went" (17 medium) with a round ✕ while typed
(`ClearButton`: ids `<prefix>-search` and `<prefix>-search-clear`, label "Clear the search"; the field
only when there are lines), then the first **8** matches — a line matches when `normName(name)`
CONTAINS `normName(typed text)` as one piece (not word by word) — each a button with the name (17
medium) and its bag (14 muted; blank for "Other"/""), ids `<prefix>-pick-<n>`; then "N more — type a
word to find them" (15 medium muted, `<prefix>-more`) or, with no match, the empty words (no lines at
all) or "Nothing that went is called “<q>”." (`<prefix>-none`). Card with a 1.2 pt border in the tint
at 60 %, id `<prefix>-picker`. Prefixes `onsite-leave`, `onsite-note`. Opening one closes the other.
The typed search is lost when the picker closes.

### Behaviour (model)
- `leftOnSite` = way-home lines marked used up. `onSiteNotes` = every line of the trip with a non-empty
  `homeNote`, in list order.
- `noteOnSite(text, tripId:, entryId:, today:)`: sets the line's `homeNote` (trimmed; empty removes it);
  then, when non-empty and the line has a thing in the library (`thingBehind`: its `sourceItemId` is a
  catalogue item), appends ONE line to the thing's `note`: "On site 3 Oct 2026: <note>" (fixed English
  months; "On site: <note>" without a usable day), on a new line under what was there — unless the thing's
  note already has a line saying the same words (normName), on its own or after any "On site <day>:".
  Emptying a note clears the trip line only; what reached the thing stays. `today` is `Today.local`.
- Save on the editor: an empty draft for a line WITHOUT a note → the needs line; for a line WITH a note →
  the note is removed.

### Tests
Model `OnSiteTests` (6: the door's beginning incl. after the trip, and bought on site on a dated trip
ahead — `loopStep` agreeing; summary words;
note on the line and the thing, once, new lines appended; his own words not repeated; no thing → trip
only, clearing keeps the thing's; the dated line). UI `testOnSiteHoldsBoughtLeftNotesAndTheWayHome`,
`testANoteMadeOnSiteReachesTheThing` (the thing's Notes become "Keep it dry\nOn site <today>: Zip
broken"), `testATripUnderWayStandsAtOnSite`.

---

## Pack to go home (`WayHomeScreen.swift`, `WayHome.swift`)

**Purpose and origin.** His pre-trip idea 13 (2 Oct 2026, 0.53): "The way out is the list; the way home
is what actually went, plus what was bought on site, less what was used up or left behind. Its own
ticks (the way-out ticks stay as they were, for the review)." Field test 3 Oct 2026 (0.56) added search,
"1 used up" in the heading, Tick everything, Undo, a note per line, and Open. It opens from On site
since 0.57.

**How it is reached and left.** On site → **Pack to go home**. Sheet; **Done** (filled green,
`wayhome-done`; Escape too, 0.62). Screen id `wayhome-screen`; Mac minimum 520 × 640. ONE sheet with a destination
(photos or a thing) — SwiftUI does not reliably present a second sheet while the first closes; closing it
leaves the search as it was.

**0.69:** a tapped door check for the way home opens it by itself (the trip, then On site with
`openHome`, then this with `onlyLeft`, each 0.7 s after the one before has arrived): **"Only what is not in a
bag yet"** (Subheadline semibold green, id `wayhome-left-only`) and **Show all** (green capsule outline,
`Metrics.chip`, id `wayhome-show-all`) under the search; the list holds only lines not packed for home and not
used up until Show all. Packing a line whose bag has pockets opens that bag's **pocket pills** under it
(`wayhome-line-<n>-pocket`, pills `…-pocket-<k>`, indented 38): the pocket it went out in chosen first
(`prechooseHomePocket`: its way-out pocket while the bag still has it, else its usual one); a tap keeps another
(`setHomePocket`) and closes the row. A packed line with a home pocket says it under its name (Footnote muted).

### What is on screen
- Header "Way home" (24 heavy green); "D/T" or "D/T · N used up" (15 bold mono muted, `wayhome-progress`).
- Search field "Search the way home" (17 medium, ✕ at its end only when typed: `wayhome-search-clear`,
  label "Clear the search" — since 0.62 the shared round `.clearButton` ✕, 36 points, like every other search;
  until then a plain cross of its own in 44 points), id `wayhome-search` — only when the way home has lines.
- Photos of the packed bags (only when not searching): every photo of every bag that has way-home lines
  (`Library.homeBags`), bag by bag, each bag's in the order taken: 120×90 thumbnails (corner 10) with the
  bag name (13 semibold muted; "Not in a bag" for "Other") in a horizontal strip, ids `wayhome-photo-<n>`;
  a tap opens BigPhoto at that photo with captions. A bag is named as the Bags card names it
  (`Library.homeBag`: a line in no bag — "" — is "Other"), so the photos of a bag deleted with "no bag",
  which moved to "Other", show here (0.62: they were looked up under "" and never found).
- Empty: "Nothing to bring home yet: tick what you pack on the way out, and add what you buy on site with
  Bought on site." (`wayhome-empty`). No match: "Nothing on the way home is called “<q>”."
  (`wayhome-search-none`).
- Bag headings (15 heavy green; "Not in a bag" for "Other"), bags in the order they first appear in the
  list; "" and "Other" are ONE bag, one heading (0.62: two "Not in a bag" headings); under each its lines.
- A line: the tick button (id **`wayhome-line-<n>` — n = index in the UNFILTERED way home**, so a line
  keeps its number while searching; `.isSelected` when packed): a 26 pt circle (green stroke, `Theme.line`
  when used up; filled green with a white tick when packed), the name (17; muted when used up or packed;
  struck through when used up), under it "Used up" (13 bold muted) or "Bought on site" (13 bold green).
  At the side, small quiet words (14 semibold muted, min height 40), always in the same places:
  **Note** (`wayhome-line-<n>-note`), **Open** (`wayhome-line-<n>-open`; only when a thing is behind
  the line, else an invisible placeholder keeps the column), **Used up** / **Undo**
  (`wayhome-line-<n>-usedup`; keeps the width of "Used up"). The note (15 semibold orange,
  `wayhome-line-<n>-notetext`) sits under the name outside the button (indented 38). **Note** opens an
  editor under the line (prefilled with the note; the note text is hidden meanwhile): field "e.g. Zip
  broken" (17 medium, `wayhome-note-field`, focused, Return saves) and **Save** (16 bold white on green,
  `wayhome-note-save`). There is no Cancel: pressing **Note** on the same line again closes the editor
  without saving; Note on another line moves the one editor there.
- At the end (only when not searching and there is something to bring home): **Tick everything**
  (16 bold white on green with a drawn 22 pt tick, min height 52) — or **Clear the ticks** (16 bold ink,
  1.4 pt `Theme.line` outline) once all are packed — one id `wayhome-tickall` for both.

### Behaviour (model)
- `homeLines` = lines ticked on the way out and not set aside, plus every bought-on-site line, in list
  order.
- `homeProgress` = (packed home, total) over home lines not used up. `homeUsedUp` = home lines used up.
- Tapping a line toggles `packedHome` (not on a used-up line). **Used up** → `setUsedUp(true)` (and the
  home tick goes); **Undo** → `setUsedUp(false)`.
- **Tick everything** → `setAllPackedHome(true)`: every home line not used up and not packed.
  **Clear the ticks** (no confirmation) → `setAllPackedHome(false)`: EVERY home tick on the trip, also on
  a line no longer on the way home.
- **Note Save** → `noteOnSite` (as On site: it also reaches the thing — his choice of 3 Oct 2026, now
  also what the code comment on `HOME_NOTE_KEY` says); an empty note removes it (no needs line here).
- **Open** → the thing's editor; Save or Cancel returns to the way home as it was.
- The way-out ticks are never touched.

### Data
Line extra keys `packedHome`, `usedUp`, `homeNote`; every mark also bumps the trip's `updatedAt` (head
record rewritten).

### Tests
Model `WayHomeTests` (7, with `testLooseThingsAreOneBagAndKeepTheirPhotos`). UI `testTheWayHomeIsPackedFromWhatWent`, `testTheWayHomeIsSearched`,
`testUsedUpIsCountedInTheHeadingAndUndone`, `testEverythingIsTickedForTheWayHomeAtOnce`,
`testALineKeepsANoteForTheWayHome` (also listed under On site's notes), `testAThingOpensFromTheWayHomeAndComesBack`,
`testAPackedBagKeepsItsPhoto` (photos on the way home).
**Not covered:** the "Clear the ticks" state of the button; the screen's heading for loose things (the
model's `homeBags` is tested).

---

## The trip review (`ReviewScreen.swift`, `ReviewHealth.swift`, `Library.reviewLines/tripTemplates/saveReview/healthReview`, `Counting.applyReview`)

**Purpose and origin.** "After a trip. Tap anything you didn't use; add what you wished you'd had — it
goes onto one of the trip's lists, so next time it comes along. Saving teaches every thing its history."
Since the web app's v162 only what went in the bag counts as packed. The order of the missed part (his
test F.3, 0.41); WHERE a thing went, and fixing a thing mid-review (his asks). Apple Health fills it in on the
iPhone since 0.70 (his choice of 7 Oct 2026; the whole design, the table and every edge case: chapter 07 part 7).

**How it is reached and left.** The trip's **Review** button (while not reviewed and with lines; at any
date). Sheet; **Cancel** (outlined muted, `review-cancel`; Escape too, 0.62) closes without saving;
**Save review** saves and closes. A swipe down on the iPhone closes it only while nothing is marked,
added or typed (0.62: marks made in an unsaved review were lost to a swipe). Screen id `review-detail`;
Mac minimum 520 × 600.

### What is on screen
- Header "Trip review" (22 heavy) and Cancel; the loop strip at Review (`review-loop`).
- **From Apple Health** (0.70; iPhone only — nothing at all on the Mac, and nothing for an undated trip): the
  first thing in the list, a card (padding 12, corner 12, `Theme.card`, 1 pt `Theme.line`, 12 below it; id
  `review-health`). "From Apple Health" (Headline, ink, `review-health-title`), then ONE of:
  - "Reading Apple Health…" (Callout muted, `review-health-reading`) while it reads;
  - "Apple Health is not allowed — Settings → Privacy & Security → Health → AMS Packing." (Callout muted,
    `review-health-refused`);
  - "No workouts in Apple Health for these days." (Callout muted, `review-health-none`);
  - the rows (`review-health-row-<n>`, top to bottom): each kind done, "Swim · indoor · 3 times" (Callout
    semibold ink), then "No bike" for each workout template on the trip with none (Callout regular muted); and
    **Use these** (Callout semibold white on a green capsule, min height `Metrics.compact` 32 / 24, padding 16
    sideways, 6 above; `review-health-use`). Under it, after a press: "Marked N didn't use, M used." (+ "; your own
    answer stays." / "your own K answers stay." when it skipped lines he answered) — Subheadline muted,
    `review-health-said`; or, when there was nothing to mark, Subheadline semibold red (`review-health-use-needs`):
    "None of this trip's lines come from a workout template." / "You have answered every line Apple Health could."
    While nobody is marked "This is me" (Your choices → Owners), under that: "Who are you? Mark yourself in Your
    choices → Owners." (Subheadline muted, `review-health-who`).
- "Anything you wished you'd had?" (20 heavy). Field "e.g. Power bank" (`review-miss-input`, Return
  adds). When the trip has templates: question pills "Put it on which template, for next time?" (heading
  id `review-miss-where-title`) — one per template the trip's lines came from (`tripTemplates`: in the
  order the lines first name them, existing templates only — the base and transport templates included),
  plus "No template" (`review-miss-where-<n>`, violet; default = the first). The button (16 bold white on
  green, `review-miss-add`): "Add it to <template>" or "Add it, on no template"; pressed with nothing
  typed it says "Type what you wished you'd had first." under it (15 bold red, `review-miss-add-needs`,
  gone when typing — 0.62; it did nothing and said nothing).
- The missed things listed: name (16 semibold), its template or "no template" (14 muted,
  `review-missed-<n>-where`), ✕ (`review-missed-<n>-remove`); row id `review-missed-<n>`.
- "Tap anything you didn't use." or "N marked “didn't use”" (20 heavy, `review-summary`).
- One row per PACKED line (`review-line-<n>`, `.isSelected` when marked): name (17 medium; muted and
  struck through when marked), where it went "Bag · When label" (13 semibold muted,
  `review-line-<n>-where`), and "Used" (green) / "Didn't use" (red) (14 bold). A pen
  (`review-line-<n>-fix`, label "Change <name>") opens the thing (via `sourceItemId`, else `itemId`);
  the review stays as it was.
- "Never went in the bag: N" (15 semibold muted) and the names joined " · " (14 muted), when any.
- Bottom: **Save review** (18 bold white on green, min height 52, `review-save`).

### Behaviour
- `reviewLines`: lines that are not reminders; a line WENT when it is ticked and not set aside. If any
  went, packed = those and never packed = the rest; if none went, every line NOT set aside counts as
  packed (the list itself is the evidence) and the set-aside ones are "never packed" (0.62: set-aside
  lines were asked about as packed).
- **Apple Health** (0.70, `ReviewHealth` + `PackingLibrary/AppleHealthReview.swift`; rules in full in chapter 07
  part 7): when the block first shows (`.task`), `AppleHealth.source.workouts(firstDay:lastDay:)` — the first
  time Apple's permission sheet with his words — then `healthReview(tripId:workouts:)` gives the rows and the
  marks (line id → used / didn't use). **Use these** reads Apple Health AGAIN (a watch synced since counts), then
  `unused = Library.unusedAfterHealth(marks, unused:, answeredByHand: answered)`: a "didn't use" mark inserts the
  line, a "used" mark removes it, a line he tapped himself (`answered`, filled by every tap on a line, either way)
  is never changed. Nothing is saved: only Save review writes, as before; Cancel throws the marks away.
- Which template: `target` = the picked pill; while nothing is picked (`missWhere == nil`) the FIRST
  template. "No template" is the pill with value "" and can really be chosen (0.62: "" also meant
  "nothing picked", so the target fell straight back to the first template and its pill never lit).
- Adding a missed thing: trimmed; blank → the needs line; already in the missed list (normName) → nothing
  (the field empties). The keyboard goes away after adding.
- **Save** → `saveReview(tripId:, unused:, missed:, when: now)`:
  0. (0.70) the missed things are kept on the trip (`missedAtReview`: each name once, with its template's shown
     name, "" for no template) and the trip's page in his vault is asked for (`vaultWaiting` = `when`) — on the
     Mac it is written at once when a folder is chosen; see "The trip's page in his vault";
  1. each missed thing: "no template" → a new thing on no list, unless a thing of that name exists;
     a template → `addToTemplate` unless the template already has that name (an existing thing of that
     name is put on, not duplicated);
  2. a set-aside line is unticked first (it did not go, whatever an older tick says); then every
     non-reminder line gets `used = !unused.contains(id)` (never-packed lines get `true`) — except that on
     a trip where nothing went, a set-aside line gets `used = nil`, so it is left out of the history
     rather than counted packed (0.62);
  3. `applyReview` over the resolved templates: for each line with `used`, `sourceListId` and
     `sourceItemId` whose template and row exist: if any line was ticked and this one was not →
     `stats.skipped += 1`; else `packed += 1` and `used` or `unused += 1`; `lastReviewed = when`;
  4. the new stats are written straight onto the THING (only rows stamped with `when` — a thing twice on
     one template must not be overwritten by its stale twin, found 2026-09-22);
  5. `status = "done"`, `reviewedAt = updatedAt = when`.
- The trip then shows "Reviewed", is at Refine in the loop, and the Trips tab folds it under "Reviewed"
  once its dates are past.

### Tests
UI `testSetPlaceAndTheReviewSayWhatIsMissingAndNoTemplateIsChosen` (`review-miss-add-needs`; "No template"
picked, the missed thing says "no template"), `testASwipeDownKeepsWhatIsNotSavedYet`,
`testATripReviewIsSavedAndTheMissedThingIsFiled` (only the ticked line asked; marked; "Add it to …";
saved → "Reviewed", no Review button; the base template gets a 5th thing), `testTheReviewSaysWhereAThingWentAndLetsHimFixIt`,
`testTheLoopShowsWhereATripStands`, `testTheEditorsLeadWithTheirHeadings`. Model
`ReviewTests.testAReviewTeachesTheThingsAndFilesWhatWasMissed`, `testASetAsideLineNeverCountsAsPacked`,
`testASetAsideLineOnATripWithNoTicksIsLeftOutOfTheHistory`, `CountingTests.testApplyReview*` (4),
`TripCardsTests.testAReviewedTripSaysSoWhateverItsTicks`, `testReviewedIsOneRuleEverywhere`.
Apple Health (0.70): UI `testAppleHealthFillsInTheReview` (`-uiTestingHealth`: rows "Swim · indoor · 3 times", "Run
· outdoor · 2 times", "No bike", no fourth; his own mark on the Goggles kept; after Use these exactly lines 5, 7,
9, 12 marked; Cancel keeps nothing; Use these + Save → Reviewed; the Mac: no `review-health`),
`testATemplateCountsAsWhatHeLinksItTo`, `testAppleHealthSaysWhenItIsNotAllowedOrHasNothing` (`-healthRefused` →
`review-health-refused`, `-healthNone` → `review-health-none`, neither with `review-health-use`). Model
`AppleHealthReviewTests` (20, chapter 07).
**Not covered:** removing a missed thing, the no-ticks-at-all case in the UI; the real Apple Health (only on his
iPhone — the tests feed invented workouts); "Reading Apple Health…" (the invented source answers at once).

---

## The trip's page in his vault (`VaultCard.swift`, `Store/Vault.swift`, `PackingLibrary/VaultPage.swift`)

**Purpose and origin.** Spec 07 part 8, his yes of 7 Oct 2026: a reviewed trip becomes one Markdown page in
his Obsidian vault — the folder he picks once (his choice: the vault's `Areas/Travel`), named
`<yyyy-mm> <trip name>.md`, its bags' photos in `attachments/` beside it; sending again replaces only the app's part
between its markers and its own front-matter keys — what he wrote himself stays, and a page of his without the
markers is never overwritten (the app's goes beside it as `<name> (AMS Packing).md`; his answer, 7 Oct 2026). The page
itself (front matter, sections, file names, escaping), the marks on the trip and the Mac's writing are in spec
07 part 8; this is the card on the trip (0.70).

**Where.** The trip screen's scroll area, FIRST (above Check before you go), only on a reviewed trip; padding
16 sideways, 10 on top.

### What is on screen (card: padding 14, corner 12, `Theme.card`, 1 pt `Theme.line` stroke; id `trip-vault`, children contained)
- Left: **"Obsidian"** (Body semibold, ink; id `trip-vault-title`) and under it, 2 pt apart, ONE status line
  (Footnote, muted, wraps), whose id says the state:
  - iPhone: `trip-vault-status` "The Mac writes this trip's page into your vault." · `trip-vault-waiting`
    "Waiting for the Mac — it writes the page the next time it is open." (while `vaultWaiting` is set) ·
    `trip-vault-written` "Written by the Mac: <file> · 7 Oct 2026" (once written, nothing waiting).
  - Mac, first that applies: `trip-vault-trouble` (the last write's trouble, in red — `AppSection.actions`:
    "<folder> can no longer be found. Choose the folder again." / "The page could not be written into
    <folder>." / "That folder cannot be used. Choose another.") · `trip-vault-nofolder` (no folder chosen:
    "Send asks for the folder once — your vault's Areas/Travel.", or, while a page waits, "Waiting for a
    folder. Send asks for it once — your vault's Areas/Travel.") · `trip-vault-waiting` "Writing the page…"
    (the moment between a wish and its write) · `trip-vault-written` "Written: <file> · 7 Oct 2026" ·
    `trip-vault-status` "Not in your vault yet." When the page went into the side file (`vaultWritten.beside`),
    `trip-vault-written` says "Written beside your page, as <file> · <day> — your page has no AMS Packing markers, so
    it is left as it is." (iPhone: "Written by the Mac beside your page, as …").
  - The day is the device's day of the write, in fixed English words.
- Right, 12 pt away: **Send to Obsidian** — `FieldButtonLabel` (Callout semibold, white on green, `Metrics.tap`
  tall, corner 8), plain button style, id `trip-vault-send`. Never grey, never switched off (his rule).
- Mac only, under them (6 pt): "Folder: <name>" (Footnote, muted, one line, cut in the middle; id
  `trip-vault-folder-name`) and **Change** (Footnote semibold, green words; id `trip-vault-folder`) — only
  once a folder is chosen.
- Mac, test runs with `-uiTestingVault` only: the folder read back from the disk (Caption 2 monospaced, muted;
  id `trip-vault-check`) — see spec 07 part 8.

### Behaviour
- **iPhone, Send** → `askForVaultPage` (the trip gets `vaultWaiting`; pressed again it is simply asked again).
  The iPhone never writes a file.
- **Mac, Send** → `VaultShelf.write`: with a folder, the page and its photos are written at once and the trip
  is marked written (`vaultWritten`, `vaultWaiting` taken away); without one — or when it has gone away — the
  system's folder picker opens (`.fileImporter`, folders only) and the page is written as soon as a folder is
  picked; cancelled, nothing happens. **Change** opens the picker without writing.
- **By itself, on the Mac**: every trip waiting (a review saved here or on the iPhone, the iPhone's Send) is
  written whenever the library changes — at launch, on a sync, after a save — as long as a folder is chosen.
- Under the tests the picker is answered by the `-uiTestingVault` folder (no test can drive the system panel).

### Tests
UI `testOnTheIPhoneSendToObsidianWaitsForTheMac` (iPhone; `-uiTestingReviewed`), `testSendToObsidianWritesTheTripPageOnTheMac`
(Mac, GitHub's), `testASavedReviewAsksForTheTripsPage` (both: iPhone waiting, Mac written at once). Model
`VaultPageTests` (20). **Not covered:** the system folder picker, Change, a folder that has gone away, night
mode on the Mac (looked at on the iPhone only).

---

## Refine (`RefineScreen.swift`, `Refine.swift`, `Counting.pruneSuggestions`)

**Purpose and origin.** Roadmap stop E (0.30): "what his trip reviews say a list carries for nothing.
Over at least two trips: a thing packed and never used, or listed and never packed. Keep settles it for
good; Drop takes it off that ONE list (it asks first)." `minTrips` stays 2 (web app v162): "One trip is
not evidence".

**How it is reached and left.** Templates tab → the violet **Refine your templates** card (`RefineDoor`,
id `refine-open`, value = waiting count or ""; Templates spec). Sheet; **Done** (filled violet,
`refine-done`; Escape too, ⌘. on an iPhone keyboard — 0.62). Screen id `refine-screen`; Mac minimum 520 × 600.

### What is on screen
- "Refine" (22 heavy violet) and the count (15 heavy mono muted, `refine-count`); the loop strip at
  Refine (`refine-loop`).
- None: "Nothing to trim yet. After two trip reviews, anything you keep packing and never use — or keep
  listing and never pack — shows up here. One trip is not enough to judge by." (`refine-empty`).
- Some: "Each of these has earned its place here over at least two trips. Keep settles it for good. Drop
  takes it off that one template — it stays your thing, and on your other templates." and one card per
  suggestion (`refine-row-<n>`): the name (17 semibold, `-name`), "<template> · packed N× · used 0×" or
  "<template> · on the list N× · never packed" (14 muted, `-why`), **Keep** (green outline,
  `refine-row-<n>-keep`) and **Drop** (red outline, `refine-row-<n>-drop`) → in place "Drop it from
  <template>?" with **Keep it** (`-drop-no`) and **Drop** (red capsule, `-drop-yes`).

### Behaviour
- `refineSuggestions`: resolved templates except his bag list → `pruneSuggestions(minTrips: 2)`: skip a
  thing marked keep; "never-used" when packed ≥ 2 and used = 0 (times = packed); else "never-packed" when
  skipped ≥ 2 and packed = 0 (times = skipped); most times first; one per template per thing. Stats are
  the THING's, so a thing on two templates is offered on each.
- **Keep** → `keepThing` (`keep = true` on the thing: gone from every template's suggestions).
- **Drop** → `dropFromList` (the membership only; the thing stays, also on other templates).

### Tests
Model `RefineTests` (2). UI `testRefineOffersWhatTheReviewsFoundAndKeepAndDropSettleIt` (door "3"; Map
first; Hiking boots never offered; Keep → 2; Drop asks; Keep it keeps; Drop → 1 and the Headlamp still
offered on its other template; the door follows; things still 10).

---

## Save as Excel (`Laundry.swift` → `TripExcelButton`, `Workbook.swift`)

**Purpose and origin.** The web app's Excel button (0.35); From where and Into columns (his test D.23,
0.40); a Category column (field test 3 Oct 2026, 0.56).

### What is on screen
A wide outlined green button (drawn sheet mark, "Save as Excel" 17 bold, min height 48), id
`trip-excel`, left of Share; under it a status (14 medium muted, `trip-excel-status`): "Choosing where
to save…" → "Saved: <file name>" or "Not saved.". The system Save window (Mac) / Files (iPhone) opens.

### Behaviour
`Library.tripWorkbook(tripId:)`: one sheet named after the trip (Excel rules: `[ ] : * ? / \` → spaces,
trimmed, ≤ 31 characters, "Trip" when empty), a bold coloured frozen header row, columns **When** (22),
**From where** (20), **Into** (20), **Thing** (30), **Category** (20), **How many** (10), **Packed**
(10), **Note** (30). Rows by When (timeline), then by bag (`groupByContainer` order), then list order:
phase label, storage, bag, name, category (blank → "Comfort & misc"), `effectiveQty(line, qtyNights)` as
a number, "set aside" / "yes" / "", the line's note. File name `workbookFileName`: "<name> packing
list.xlsx" with `/ : \ ? * " < > |` replaced by spaces, trimmed, "Trip" when empty. Words XML-escaped;
the zip is "store" (no compression) with standard CRC-32.

### Tests
UI `testATripIsSavedAsExcel` (button on the same line as Share, left of it; status "Choosing…"; the Mac
Save window, closed with Escape). Model `WorkbookTests` (3).

---

## Sharing a trip (`Share.swift`, `Sharing.swift`, `PackingCore/TripSharing.swift`)

**Purpose and origin.** The web app's share links and QR codes (gap list 2026-09-27, 0.38): "a link
that opens in the web app (for anyone) and in this app (Settings → Open a shared link); a QR code when
the link is short enough; a trip also as a file."

### What is on screen
**Share** — wide outlined green with a drawn box-and-arrow, id `trip-share`, label "Share" — opens the
share sheet (id `share-screen`, Mac minimum 480 × 560): title "Share “<name>”", **Done**
(`share-done`; Escape too, 0.62); the QR code (white card, max 260 pt, id `share-qr`) or "Too long for a QR code. Send the
link instead." (`share-qr-toolong`); the link (13 monospaced, 3 lines, middle-truncated, selectable,
`share-link`); **Send…** (system share, `share-send`) and **Copy link** → "Copied" (`share-copy`, value
"copied"); without a link (a trip offers a file) "This is too big for a link. Share it as a file instead." (`share-toolong`);
**Share as a file** (`share-file`); "The link opens in the web app, and in this app under Settings → Open
a shared link."

### Behaviour
- What travels is **just the list** (`Library.justTheList`, 0.62): the trip's luggage-scale readings
  (`weighed`) and bag photo ids (`bagPhotos` — the photos never travel) are left out, and so is every
  line's "not this time" (`skipped`), "changed on the trip" (`_edited`), way-home tick, used up,
  maintenance note, bought on site and packing time. The sender's own trip keeps them all.
- Link = `SHARE_WEB_BASE` (the web app's address) + `#/t/` + the bundle squeezed by `packShare`; nil when
  the fragment exceeds **30 000** UTF-16 units (`TRIP_LINK_MAX`).
- Bundle (`buildTripBundle`): `{app: "ams-packing-list", kind: "trip", version: 1, exportedAt, event}`,
  keys in the web app's order; each line "slimmed": drops `id, sourceListId, sourceItemId, stats,
  checked, used, custom` and the sync keys `owner`/`realmId`, drops default values, keeps `ownedBy` only
  when it is a name, sub-items as words. The trip's own fields and extra keys travel as they are —
  `activityContexts` too (0.67; after the web app's keys, which is where a key it does not know is
  written), so the receiver's Trip settings shows each workout's Context and a rebuild keeps it. Its ids
  are the SENDER's templates, like `activities`; a received trip's entries for templates the receiver does
  not have are kept as they came on Save.
- File: the bundle pretty-printed, named "<name> trip.json" (via `workbookFileName`), written to the
  temporary folder when the sheet appears.
- Receiving (Settings → Open a shared link, Settings spec): `parseTripBundle` gives a new trip id,
  status active, no review, new timestamps, new line ids, nothing ticked, `used` cleared;
  `Library.importTrip` takes `justTheList` again (a link made before 0.62 still carries the marks) and
  appends it **Quick** (0.62) — its list is what was sent: Trip settings' Save keeps it as it came (see
  `regenerated`), his own always-packed and transport templates do not pour in on top, a template he ticks
  adds to it, and picking Full trip brings in the rest. Only `updatedAt` is re-set; no duplicate check —
  adding the same link twice gives two trips. A pasted text is tried as a grab list, then a template, then a trip (a
  `#/t/<code>` found anywhere in the text, else the whole text as the code). The card reads "A TRIP"
  (12 heavy muted, `shared-kind`), the name ("Untitled trip" when empty; 18 bold, `shared-name`),
  "1 thing" / "N things" (15 medium muted, `shared-count`; "1 things" until 0.62 — the same words for a
  template and a grab list), **Add this trip** (17 bold white on
  green, `shared-add`) → "Added. It is under Trips, nothing ticked." (15 bold green, `shared-result`).

### Tests
UI `testATripIsSharedAndOpenedAgain`, `testATripSomeoneSentKeepsItsListOnSave` ("7 things"),
`testASharedListOfOneSaysOneThing` ("1 thing"). Model `SharingTests.testATripTravelsAsALink` (link prefix,
read from a message, no ticks, new ids, file name "Swim week trip.json"), `testASharedTripIsJustTheList`,
`TripSharingTests` (all 17).

---

## Deleting a trip, and the photos it leaves (`TripScreen.swift`, `TripEdits.swift`)

**Purpose and origin.** "His two test trips had no way out" (gap list 2026-09-26, 0.24); small and at the
side (his mark 2026-09-26, 0.26); the photos go too (his ask 4 Oct 2026, 0.59: "the practice trip was
gone, its bag photo stayed behind").

### What is on screen
Last on the trip's list: **Delete trip** — `SmallDeleteButton(title: "Delete trip", id: "trip-delete")`,
a small red outlined capsule at the right (red words, 1 pt outline in red at 60 %, min height 30,
padding 12). Since 40be106 `SmallDeleteButton` takes a `size` parameter, 13 by default; the trip's
button passes none, so it stays **13 semibold** (only "Delete grab list" passes
15). It only opens the question: a card with a red border, "Delete
“<name>”?" (16 heavy), "The trip and its N line(s) go. Your things and your templates stay." (14 medium
muted), **Keep it** (16 bold ink, `trip-delete-no`) and **Delete the trip** (red capsule, white 16 heavy,
`trip-delete-yes`).

### Behaviour
Delete: the sheet closes first, then `Library.deleteTrip(id:)`: the trip and all its lines go (their
records are deleted on every device), and its folds on this device with it (`TripFolds.without`, 0.62); every photo the trip showed — photo ids on its lines and all its
bag photos — is deleted unless a thing, another trip line or another bag still shows it. Things,
templates, to-dos and other trips are untouched. Unknown id → false.
Photos left behind by trips deleted before 0.59: Settings → Worth a look ("1 photo is no longer shown
anywhere — left behind by a deleted trip." / "N photos are no longer shown anywhere — …", **Remove
it** / **Remove them**; fix id `unusedPhotos`) via `Library.unusedPhotos(now:)` — a photo is offered
only when nothing shows it (`photoInUse`: no thing, no trip line, no packed bag on any trip) AND its
`createdAt` reads as an ISO moment (`isoMoment`, with or without fractional seconds) more than 24 h
(86 400 s) before now (a photo can arrive from the other device before its trip). **A photo whose
creation date cannot be read is KEPT and never offered** (0.60; before, it was offered at once,
bypassing the one-day guard). `removeUnusedPhotos(now:)` removes exactly what `unusedPhotos` lists and
returns how many.

### Tests
UI `testATripIsDeletedOnlyAfterAsking` (asks; Keep it keeps and stays on the trip; Delete closes, the row
goes, 10 things stay, the bag photo count is 0), `testWorthALookRemovesAPhotoLeftBehind`. Model
`TripEditsTests.testADeletedTripTakesOnlyItself`, `PhotoTidyTests` (3: a deleted trip takes its bag
photos along; a photo something else still shows stays; Worth a look offers ONLY the two-day-old photo
— not the one an hour old, not the one with `createdAt` "" — says "1 photo is …"/"Remove it", the
repair removes 1, and the worry goes). **Not covered:** the plural words; a `createdAt` that is
non-empty but unreadable.

---

## Bag pockets on a trip, and "Where is my …?" (`Pockets.swift` in PackingLibrary and in Screens, `Store/WhereIsIntent.swift`)

**Purpose and origin.** Stop B of his idea plan, approved 7 Oct 2026 (idea 5, "every bag gets its pockets"):
"Your bags get their own pockets: main, front pocket, lid, shoe compartment. While packing, one tap says which
pocket a thing went into. On site you ask 'Where is my charger?' and the answer comes back: 'Backpack, front
pocket.'" A bag's pockets are named on the bag's page (spec 05); a thing's usual pocket on its page (spec 05).

**The pills** (`PocketPills`): ticking a line (way out) whose bag has pockets sets `pocketing` to that line;
under it, indented `Metrics.mark` + 8, one horizontal row (scrolls sideways if long) of small pills —
Footnote semibold, `Metrics.chip` tall (28 / Mac 22), 6 apart, green: the chosen one filled with white words, the
others outlined 1.2 pt — row id `trip-line-<n>-pocket`, pills `trip-line-<n>-pocket-<k>` (k = the bag's order),
`.isSelected` on the chosen. The tick itself already chose the thing's **usual pocket** (`Library.setChecked` →
`prechoosePocket`: only when the line has no pocket yet, the line is in the thing's usual bag and that bag has
the pocket), so most lines need no tap. A tap on a pill keeps that pocket (`setPocket`) and closes the row;
ticking another line moves the row there; ignoring it leaves the usual one. Unticking keeps the pocket (a tick
again shows it; his choice stands). A bag without pockets: nothing appears, exactly as before.

**Model rules** (PackingLibrary `Pockets.swift`): pockets are matched by `normName`; `addPocket` refuses an empty
name, a thing that is not one of his bags, or a second pocket of the same name; `renamePocket` carries the new name
to every thing whose usual bag it is and every trip line packed in that bag (`carryPocket`, both pocket keys), and
refuses a name another pocket has; `removePocket` leaves those things and lines simply in the bag; `movePocket`
reorders. A thing's usual pocket counts only while its usual bag has it (`usualPocket(thingId:)`). Deleting a bag
into another (or into no bag) forgets the pockets of its things and lines first (`forgetPockets`). Choosing a
pocket (`setPocket`, `setHomePocket`) writes the LINE only — like a tick, one small record. A shared trip and a
new trip from this one leave the line pockets out (`justTheList`, `startAgain`). Everything is in extra keys
(top of this chapter), synced, backed up and restored with the records they sit on.

**"Where is my …?"** — `Library.whereIs(words, today:)` / `whereIs(thingId:today:)` → `WhereAnswer`:
- The **trip under way** (`tripUnderWay(today:)`: started, last day not past — the last day counts; two at once:
  the one that began last). Its line for the thing (by `sourceItemId`; by name for `whereIs(words)`, which also
  finds a line typed on the trip), not set aside: **packed for home** → its bag + home pocket; **ticked** → its bag
  + pocket; **not ticked** → where it goes: its bag + the usual pocket ("Not packed yet. It goes in …").
- No trip under way, or the thing not on it: **usual** — its usual bag + usual pocket ("Usually in …").
- **Inside a kit** (0.70, `kitHolding(thingId:)`, not taken out of it): the kit's own answer, the thing's name kept and
  `kit` = the kit's name — `shown` "Camp pouch, Backpack · Lid" (just "Camp pouch" when the kit is in no bag),
  `said` "Usually in Camp pouch, Backpack, lid." / "Camp pouch, Backpack, lid." Taken out: its own answer
  (`testWhereIsAThingInsideAKit`).
- Names: a whole-name match first, else the shortest name containing the words. Nil = nothing by that name.
- `shown` = "Backpack · Front pocket" ("Not in a bag" for none); `said` = "Backpack, front pocket." (a pocket's
  first capital softened when the second letter is small: "USB pocket" stays).

**Siri / Shortcuts** (`WhereIsIntent`, iPhone and Mac): "Where is my <thing> in Packing", "Where's my <thing> in
Packing", "Ask Packing where something is" (asks "Which thing?"). The thing is a `ThingEntity` (his things not
"Not in use", A–Z; `EntityStringQuery`, so a typed or said part of a name finds it). It answers in words
(`ProvidesDialog` + the words as its value), opens nothing and changes nothing. Shortcut tile "Where is my thing?".
See spec 06 §3b.

**Search** (`WhereCard`, top of the results): while a trip is under way and the search finds a thing (or line) on
it, a card first: the name (Body semibold, `search-where-name`), "Backpack · Front pocket" (Callout semibold green,
`search-where-place`) and a line (Footnote muted, `search-where-says`): "Packed on <trip>." / "Packed for home from
<trip>." / "On <trip>, not packed yet — it goes there." Card: padding 12 × 8, corner 10, card fill, green 1-pt
border at 60 %, 10 above, id `search-where`. No trip under way: no card.

### Tests
UI `testTickingALineOffersItsBagsPockets` (`-uiTestingPockets`: ticking the charger shows `trip-line-1-pocket-*`,
Front pocket selected, the line says "Backpack · Front pocket"; Lid tapped → the row goes and the line says
"Backpack · Lid"; the Toothbrush in the carry-on shows none — red with `pocketing` never set: "ticking the charger
did not offer the Backpack's pockets"), `testPackToGoHomeKeepsItsPockets` (the way home's pills, the way-out pocket
first, Main kept — red with `prechooseHomePocket` not called: "the pocket it went out in was not chosen first"),
`testSearchShowsWhereAThingIsOnTheTripUnderWay` ("Backpack · Front pocket" above the things; none with no trip
under way — red with the card's condition turned round: "Search does not say where it is: ''"). Model
`PocketsTests` (8: a bag's list, add/rename/move/remove and their refusals; the usual pocket comes with a tick and
his choice stands; records and a backup keep all three keys; a usual pocket only while its bag has it; a rename
reaches things and lines, a remove leaves them in the bag; a bag deleted into another; the way home's own
pocket, Start again and a share without pockets; Where is my charger in every case; an absent key changes nothing).

---

## The door check (`PackingLibrary/DoorCheck.swift`, `Store/DoorChecks.swift`, `LeaveTimes` in `Screens/Pockets.swift`)

**Purpose and origin.** Idea 4 of his idea plan; his choice (7 Oct 2026): "c, a time" — "'I leave at 07:30' on
the trip; the check comes 15 minutes before." "On the day you leave, at the moment you set off, one message names
what is still unticked … A tap opens the trip on just those lines. On the last day away, the same when you leave
the place."

**Where it is set.** "I leave at" on Create new trip and in Trip settings (above), stored as `leaveAt` /
`leaveHomeAt` ("HH:mm"; `Library.cleanTime` takes "7:30", "0730"; anything else is refused).

**What is said, and when** — `Library.doorChecks(now: "yyyy-MM-dd HH:mm")` (this device's clock), for every trip
not reviewed:
- **Way out**: on the first day at the leave time minus `DOOR_CHECK_LEAD_MINUTES` (15; past midnight → the day
  before, `Library.before`), if that moment is still ahead and some line is neither ticked nor set aside: id
  `door-out-<trip id>`, title **"Leaving for <place>?"** (the trip's place, else its name), body **"Still unticked:
  Passport, Charger, Goggles"** — up to `DOOR_CHECK_NAMES` (5) names in list order, then " and 3 more".
- **Way home**: on the last day (the first when there is none) at the home time minus 15, if some line of the way
  home (`homeLines`) is neither packed for home nor used up: id `door-home-<trip id>`, **"Going home from
  <place>?"**, **"Not in a bag yet: …"**.
- Nothing to say (all ticked, all in a bag) = no check at all; no time = none.

**Scheduling** (`DoorChecks.reschedule`): on the **iPhone only** — he leaves with it, and the Mac at home saying the
same would be the same news twice (his word on the packing reminders). Every pending notification whose id starts
`door-` is removed, then (only with permission authorized/provisional) one calendar notification per check: title,
body, default sound, `userInfo` `tripId` + `door` ("out"/"home"), id = the check's id. It runs whenever the library
settles after a change (`RootView`, debounced 2 s — so a tick, a new time, a deleted or reviewed trip all put it
right) and whenever the app comes back to the front. Permission is the app's one notification permission (the
same as Remind me to pack); "Add a time" asks for it on the iPhone. The words are those of the LAST change on this
device or arrived by sync: a tick made on the Mac while the iPhone app stays asleep is not in it (open question).

**Tapped** (`PackingReminders` delegate → `DoorChecks.open`): Home, `model.tripFocus` + `tripToOpen`; the trip
opens and takes its focus (`TripScreen.takeFocus`): **out** → only the unticked lines (not ticked, not set
aside), under **"Only what is still unticked"** (Subheadline semibold green, id `trip-unticked-only`) and **Show
all** (green capsule outline, `Metrics.chip`, id `trip-show-all`) between Sorting and the cards; ticking a line
takes it out of the view. **home** → On site, then Pack to go home on "Only what is not in a bag yet" (above).

**For the tests** (no test can see a notification): under the UI tests nothing reaches the system;
`DoorChecks.planned` holds what WOULD be scheduled, and with `-showDoorChecks` (DEBUG builds only) the trip shows it
under Sorting: one Caption muted line per check, "<id> · <day> <time> · <title> <body>", ids `door-check-out` /
`door-check-home`, or "No door check" (`door-check-none`). `-tapDoorCheck out|home` plays a tapped check at launch
for the first trip with that time.

### Tests
UI `testTheDoorCheckNamesWhatIsStillUnticked` (-uiTesting -showDoorChecks: none without a time; Trip settings →
Add a time → "Check 07:15" → Save → `door-check-out` with 07:15, "Leaving for Weekend in the hills?" and "Still
unticked: Passport, Phone charger, Toothbrush, Headlamp, Hiking boots and 2 more"; Tick everything → none — red
with ticked lines counted: "a door check with everything ticked"), `testATappedDoorCheckOpensTheTripOnWhatIsLeft`
(out: the ticked Passport hidden, Show all brings it back; home: Pack to go home on what is left — red with the
focus not applied: "the trip did not open on just what is left"), `testCreateNewTripTakesTheTimeHeLeaves` (above),
`testTheDoorCheckSaysWhenTheDeviceDoesNotAllowIt` (-pretendRemindersBlocked: no line before a time, the red line
after Add a time — red with the line switched off: "nothing says the device does not allow the check"). Model
`DoorCheckTests` (6: times kept, synced and backed up; 15 minutes before, set-aside and ticked lines left out,
nothing to say = none; five names then "and 3 more"; midnight; the way home; no time no check; reviewed or
deleted = none). **Not covered:** the real scheduling and a real tap (the system's), the Mac's "your iPhone" line.

---

## Other ways into a trip

- **Countdown card on Home** (`CountdownCard`, id `home-countdown`; Home spec): the next trip still to
  leave (`nextTrip`: not reviewed, dated, starting today or later; soonest) — tap opens it on Home.
- **A packing reminder** tapped (`PackingReminders.open`) or the Shortcut **Open my next trip**
  (`OpenNextTripIntent`) set `LibraryModel.tripToOpen`; `RootView` switches to Home and Home opens the
  trip sheet (and clears the request). Under UI tests the launch argument `-openNextTrip` plays it.
- **Search** (`SearchScreen`): trip results open `TripScreen`.

Tests: UI `testHomeCountsDownToTheNextTrip`, `testAShortcutOpensAGrabListOrTheNextTrip`; model `CountdownTests`.

---

## Choosing things for a template (`TemplatePicking.swift`) — how it relates to trips

`TemplatePicking.swift` is NOT about choosing templates for a trip: it holds `ThingGrouping` (Section,
When, Into, From where, Kind, A–Z — "the same words as the trip's sorting") and
`Library.putOnTemplate(templateId:itemIds:)` / `thingIds(onTemplate:)` for the Templates tab's "Choose
from your things" (his tests H.9, H.3, 0.42). Templates spec. Tests `TemplatePickingTests` (2).

---

## Test index for this area

**UI (UITests/AMSPackingUITests.swift):** (0.69) testTickingALineOffersItsBagsPockets, testPackToGoHomeKeepsItsPockets,
testSearchShowsWhereAThingIsOnTheTripUnderWay, testTheDoorCheckNamesWhatIsStillUnticked,
testATappedDoorCheckOpensTheTripOnWhatIsLeft, testCreateNewTripTakesTheTimeHeLeaves,
testTheDoorCheckSaysWhenTheDeviceDoesNotAllowIt; testATickCountsAndStays, testHomeBuildsATrip,
testDatesArePickedLikeBooking, testEveryRowShowsTheTickTheTripHolds, testASectionFoldsAndStaysFolded,
testATripIsDeletedOnlyAfterAsking, testWorthALookRemovesAPhotoLeftBehind, testAPlaceIsSetFromTheTrip,
testRefineOffersWhatTheReviewsFoundAndKeepAndDropSettleIt, testTheLoopShowsWhereATripStands,
testATripsSettingsAreChangedAfterItIsMade, testANewTripStartsFromThisOne,
testLaundryCountsPerNightThingsFourNightsAtMost, testHomeCountsDownToTheNextTrip,
testATripChecksTheCabinAndTheDatesBeforeYouGo, testABagSaysWhetherItGoesInTheCabin,
testABagIsWeighedOnTheLuggageScale, testAShortcutOpensAGrabListOrTheNextTrip, testAPackedBagKeepsItsPhoto,
testSomethingBoughtOnSiteGoesOnTheList, testTheWayHomeIsPackedFromWhatWent, testTheWayHomeIsSearched,
testUsedUpIsCountedInTheHeadingAndUndone, testEverythingIsTickedForTheWayHomeAtOnce,
testALineKeepsANoteForTheWayHome, testAThingOpensFromTheWayHomeAndComesBack, testATripUnderWayStandsAtOnSite,
testOnSiteHoldsBoughtLeftNotesAndTheWayHome, testANoteMadeOnSiteReachesTheThing,
testABagOnTheTripSaysWhetherItGoesInTheCabin, testATripIsSavedAsExcel, testTheDateGridCanBeLeftAndQuickSaysSo,
testTheDateGridWaitsForOK, testTheDateGridStartsOverAndCancelPutsItBack, testContextSitsUnderTheWorkouts,
testEverythingIsTickedAndClearedAtOnce, testWeatherAddAllTakesEverything, testTheMapShowsWhereTheTripsWent,
testATripIsSharedAndOpenedAgain, testAThingTypedWhilePackingJoinsTheTrip, testAChangeToAThingReachesATripStillAhead,
testTheTripSaysSortingBesideItsDropDown, testATripSortedBySectionReadsUnderItsSections (0.64),
testAThingsPageSetsItsSectionOnATemplate (0.64), testATripReviewIsSavedAndTheMissedThingIsFiled,
testTheWeatherSaysWhatItWillBeLikeAndWhatIsMissing, testTheScreenSaysSoWhenEverythingIsPacked,
testEachTripSaysWhereItHasGotTo, testAWholeSectionIsTickedInOnePress, testTheReviewSaysWhereAThingWentAndLetsHimFixIt,
testABagsLimitReachesTheTrip, testEveryAddButtonIsReadyAndSaysWhatIsMissing (weather-look),
testTheEditorsLeadWithTheirHeadings (Create new trip, Trip settings, review headings) — and from the
spec pass (0.62, section "Trips: the spec pass" in the file): testEscapeClosesTheTripsWindows,
testATripSomeoneSentKeepsItsListOnSave, testASetAsideLineIsNotPacked,
testSetPlaceAndTheReviewSayWhatIsMissingAndNoTemplateIsChosen, testTheDateGridClosesOnlyOnAWholeRangeAndStaysStill,
testABagWithNothingWeighedIsOnTheTrip, testWeatherGearCanBePackedAnyway, testATemplateWithNoActivityAreaGoesOnATrip,
testASharedListOfOneSaysOneThing, testASwipeDownKeepsWhatIsNotSavedYet (iPhone only) — and 0.67:
testFullTripOrQuickIsChosenUnderTheName, testDatesAreAlwaysThereAndCanBeCleared, testEachWorkoutHasItsOwnContext
— and 0.71 (iPhone only): testPackByVoiceWalksTheTripByTheWordsItHears, testPackByVoiceButtonsDoWhatTheWordsDo,
testPackByVoiceSaysWhyItCannotStart, testPackByVoiceGoesOnceMoreOverWhatWasLeft, testAPlaceCodeStartsPackByVoiceAtThePlace.
— and 0.70: testOnTheIPhoneSendToObsidianWaitsForTheMac, testSendToObsidianWritesTheTripPageOnTheMac,
testASavedReviewAsksForTheTripsPage.
UI launch modes used: `-uiTesting` (sample), `-uiTestingChecks` (a plane trip "Sunny weeks" 20–34 days
out, pocket knife + sun cream in the carry-on, sun cream expiring day 25, passport day 180),
`-uiTestingOnSite` (the sample trip began yesterday), `-uiTestingOldPhoto`, `-uiTestingSections` (Hiking in
two sections, its trip packed from Hiking as it now reads — 0.64 — so Section has headings),
`-uiTestingWorkouts` (0.67: the sample plus a WET template Run — Trail shoes Outdoor, Treadmill towel Indoor,
Running cap — and a Wetsuit Outdoor on Swim; `SampleLibrary.workouts`), with `-uiTesting`
0.71's `-uiTestingVoice "<words, by commas>"` / `-uiTestingVoiceRefused` / `-uiTestingVoiceStartAt <place>` (Pack by voice's fake speech; under any
`-uiTesting…` launch the fake is used, so no test opens a microphone), `-uiTestingReviewed` (0.70: the
sample's trip six to three days ago, everything ticked, the carry-on weighed 2.4 kg and photographed, a sun hat
bought on site, "zip broken" on the rain jacket, the map not used, a power bank missed onto Hiking; reviewed
yesterday, no page asked for; `SampleLibrary.reviewed`), `-uiTestingVault <name>` / `-uiTestingVaultChosen`
(0.70, Mac: a throwaway vault folder — spec 07 part 8), `-openNextTrip`. Under the
tests the stored sorting and folds (`ams.view`, `ams.trip.folded`) are cleared at launch.

**Model (PackingLibraryTests):** PocketsTests, DoorCheckTests (0.69), VoiceWalkTests (0.71), WorkoutContextsLibraryTests (0.67), CreateTripTests, CustomLineTests, ReviewTests, LaundryNightsTests,
LoopTests, OnSiteTests, OnTheTripTests, RefineTests, TripAgainTests, TripBulkTests, TripCardsTests,
TripChecksTests, TripEditsTests, SetPlaceTests, ChangeTripTests, TripWeatherTests, WayHomeTests, VaultPageTests (0.70),
WeighingTests, TravelYearTests, PhotoTidyTests, CountdownTests, ThingFollowsTests, RowTagsTests,
BagsTests/BagNotesTests (trip parts), LibraryTests (records, regenerate), WorkbookTests, SharingTests.
**(PackingCoreTests):** TripBuildingTests, WorkoutContextsTests (0.67), TripEventsTests, CountingTests, ResolveTests, WeatherTests,
DatesTests, PhasesTests, GroupingTests, EventsTests, TripSharingTests.

---

## Open questions / discrepancies

Tags: [bug] the code does something wrong · [rule-break] against one of his standing rules · [doc] a
comment, doc or guide text disagrees with the code, or code that is dead · [untested] behaviour no test
pins · [idea] a gap worth deciding on.

1. [bug] **Imported trips lose their lines on the first Trip settings save.** Resolved in 0.62: a line
   with nothing behind it (a sent one) is kept by `regenerated` and not doubled; a received trip arrives
   Quick, and Trip settings keeps template ids it does not show, so Save keeps the list as it came.
2. [bug] **Start again copies line marks.** Resolved in 0.62: set-aside, bought on site, the way home's
   ticks, used up and notes stay with the old trip; the new one stands at Pack.
3. [bug] **Shares carry trip-private extras.** Resolved in 0.62: `Library.justTheList` leaves the scale
   readings, bag photo ids and every line's own marks out of the link and the file, and off an arriving trip.
4. [bug] **On site door vs loop step disagree.** Resolved in 0.62: the loop now goes by the door's rule —
   a bought-on-site line begins On site whatever the dates say (his field-tested flow uses exactly that).
5. [bug] **Way-home photos of loose things are invisible.** Resolved in 0.62: the way home names bags as the
   Bags card does (`homeBag`: "" is "Other") — one heading, and the photos are found.
6. [bug] **A bag whose things have no weight never appears on the Bags card.** Resolved in 0.62: every bag
   with a line is shown; one with nothing weighed says "Tap to weigh".
7. [doc] **Comment vs code in TripScreen (nesting).** Resolved in 0.62: the comment now says one level of
   groups, lines in list order.
8. [doc] **Comment vs code — WayHome.swift.** Resolved in 0.62: kept as it works — a way-home note also
   reaches the thing (his choice, 3 Oct 2026); the comment on `HOME_NOTE_KEY` now says so.
9. [doc] **Comment above `TickAllRow`.** Resolved in 0.62: the "last, quiet and red" words now sit above
   the Delete button they describe.
10. [doc] **Comment vs code — Weather.swift.** Resolved in 0.62: the comments say the add-ons come for every
    condition; his own gear now comes from every template the trip is built from (`weatherMissing`).
11. [bug] **Retired weather gear is suggested.** Resolved in 0.62: `weatherMissing` leaves things "Not in
    use" out, so neither a row nor Add all offers them.
12. [idea] **`weatherOn` has no native control.** Resolved in 0.62: Trip settings shows "Pack weather gear
    anyway" (Rain, Cold, Heat, Wind, Snow); Create new trip stays as it was (the gentlest version).
13. [rule-break] **Grey/disabled or silent buttons.** Resolved in 0.62: Set place's Save and Look again stay
    green, the review's Add says what is missing, and a section with nothing to tick has no tick at all.
14. [bug] **Field tap closes the date grid without OK.** Resolved in 0.62: the field tap is OK — it waits
    for the last day and says so, and closes only on a whole range.
15. [doc] **Date picker vs model calendar.** Resolved in 0.62: the grid now draws six rows every month itself
    (steady, as `monthGrid` meant); the model's calendar functions stay the web app's, parity-checked, unused.
16. [doc] **Ported but unused in the app.** Resolved in 0.62 (decided, nothing changes): they stay in
    PackingCore, held to the web app by the parity checker; not shown because he chose the four sortings
    (When, Into, From where, Category — 2026-09-25; a fifth, Section, is offered since 0.64, his ask of
    6 Oct 2026, so `groupBySection` is used now), the loop strip already says Review once a trip is over,
    and a line's note, packer and kit would crowd a line.
17. [bug] **Two "first" rules for duplicate trip ids.** Resolved in 0.62: `Library.trip(_:)` takes the
    first, as everything else does.
18. [bug] **Reviewed state is read two ways.** Resolved in 0.62: `Library.isReviewed` (done, or a review
    time) everywhere, the trip screen included.
19. [bug] **A set-aside line that was ticked stays ticked.** Resolved in 0.62: setting aside takes the tick;
    the review, Your year and All your trips never count a set-aside line as packed.
20. [doc] **Reminder lines** count in progress but not in bags, the cabin check or the review. Resolved in
    0.62: written down under Counting, and kept so (a reminder is something to do before leaving).
21. [bug] **`followThing` uses the UTC date.** Resolved in 0.62: it goes by `Library.localToday()`, the
    device's own date.
22. [bug] **`followThing` wipes a line's own marks.** Resolved in 0.62: the line keeps its `extra` marks
    when its thing changes.
23. [doc] **Locale** of the Trips row's dates. Resolved in 0.62: fixed English words, "3 Oct 2026", on
    every device.
24. Withdrawn (his word, 5 Oct 2026): there is no 15-pt floor in this app — it uses Apple's standard text styles (spec 06, "Type"). Was: [rule-break] **Small type**: Your year's labels (10 pt counts and months, 12 pt
    words) and the All-time words (12 pt); "Delete trip" 13 pt (`SmallDeleteButton` default — only the
    grab list's delete passes 15); "Set place" 13; the On site door summary, the Bags key, captions and
    the section counts 13–14 pt; the date grid's weekday row 12 pt; "Dates" caption 13 pt.
25. [bug] **Trip settings drops templates not offered.** Resolved in 0.62: templates with no activity area
    are offered (last, "Other templates") on Create new trip and in Trip settings, and Save keeps the ids
    it does not show.
26. [idea] **Create new trip keeps Transport, Season and Food; no Place field.** Resolved in 0.62
    (decided, nothing changes): the next trip is usually the same car and season and the pills show it;
    the weather card asks for the place as soon as the trip opens.
27. [idea] **Fold keys never removed; one sorting per device.** Resolved in 0.62: a trip's folds go with
    it, and a fold made sweeps out those of trips no longer here; the sorting stays one per device (a way
    of looking, not part of a trip).
28. [doc] **Docs.** Resolved in 0.62: `docs/colours.md` says the workout pills are built; the UI test calls
    the pen a pen; the guide's "Delete this trip" and its Trip settings line are proposed for How it works at
    release (the guide is not edited on this branch); the 16 vs 17 pt of `HeaderButtonStyle` is the
    Look-and-feel area's (file 06).
29. [untested] **Escape on the Mac.** Resolved in 0.62: every window a trip opens has Escape as Cancel or
    Done (⌘. on an iPhone keyboard), tested by `testEscapeClosesTheTripsWindows`. Return is left to the
    fields: it never saves a trip's settings or a review by accident. (0.62: every other sheet of the app
    too — Refine and the world map here among them; spec 06 §20.)
30. [idea] **Swipe-down on the iPhone.** Resolved in 0.62: Trip settings and the review refuse the swipe
    while something is changed or marked; Cancel or Save closes them.
31. [bug] **"1 things".** Resolved in 0.62: "1 thing" on the shared card, for a trip, a template and a grab
    list.
32. [bug] **The review's "No template" cannot be chosen.** Resolved in 0.62: nothing picked and No template
    are two different values now; its pill lights and the thing goes on no template.
