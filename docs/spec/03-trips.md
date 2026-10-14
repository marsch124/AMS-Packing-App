# Trips — from creating one to after it

> Verified against the code on 5 Oct 2026 (app 0.60). Every open question of this area was then
> settled on branch `work/trips` (release 0.62); the sections below say what the code does now.

A **trip** (the code and the web app call it an *event*, Swift type `TripEvent`) is one journey: a
name, optional dates and place, the templates it is built from, and the **list he packs from** — a
set of self-contained *lines* (`Item` values in `trip.entries`) copied from those templates when the
trip is made. This file covers the whole life of a trip:

- **Plan** — *Create new trip* on the Home tab (name, Full trip | Quick, Dates, templates, Context per
  workout, Travelling by — Plane or RV, both off for an ordinary trip — and, folded under *More choices*,
  Season, Food, Laundry) and how the list is built from the templates.
- **Pack** — the Trips tab (`EventsScreen`), the trip screen (`TripScreen`): ticking, "not this
  time", sorting When / Into / From where / Category / Section (Section and the Sorting drop-down since
  0.64), folding, Set place, adding a thing,
  a heading's tick and its Undo (0.79; Tick everything is gone and Clear every tick is in Trip settings since
  0.79), Before you go (until 0.77 Check before you go and To charge), the weather card, the Bags card (luggage
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
| `transport` | "Car" (default) \| "Plane" \| "RV" (`TRANSPORTS`) | Since 0.76 the screens offer only Plane and RV (*Travelling by*); "Car" is stored when neither is on — an ordinary trip. The stored words are unchanged, so old trips, backups, sync, the web app and every "Only on some trips → Transport" rule read as before |
| `season` | "Summer" (default) \| "Winter" (`SEASONS`) | Since 0.76 Create new trip sets it from the first day (`Library.seasonFor(firstDay:)`) until he picks one himself |
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
| `travel` | `TRIP_TRAVEL_KEY` | `{ "flights": [{ "number", "date", "from", "to" }], "destination", "stay": { "name", "address", "phone", "until" } }` (0.80) — each part only when it holds something; absent = none | Create trip, Trip settings ("Flights and stay", plane trips) |
| `bagTags` | `BAG_TAGS_KEY` | `{ "<bag name>": "<tag number>" }` (0.80) | the Packing day's Tags, the Bags card (plane trips) |

Neither leave time is copied by Start again (a new trip has no dates); both travel in a shared trip (the
people he shares a trip with leave with him). See "The door check".

`travel` and `bagTags` (0.80, spec 07 part 18 B — the lost-luggage information): neither is copied by Start again
(other flights, another stay, new tags); in a shared trip `travel` goes along (they fly with him, to the same stay)
and `bagTags` is dropped (`justTheList`: the tags are on HIS bags). `bagTags` follows a bag's rename as the scale
reading does.

`breakUntil` (`BREAK_UNTIL_KEY`, 0.77) — "yyyy-MM-dd HH:mm", Take a break's moment to go back to packing (spec 07
part 16): written by the break sheet, removed by Just pause and when everything is packed; NOT copied by Start
again and dropped in a shared trip (`justTheList` — the people he shares with must not be called back to HIS
packing).

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
could be outdoors Run and indoors Swim."). **0.76** (his decisions of 13 Oct 2026, after he deleted his Car
transport template — "the car is just go and drive"; he travels mostly by car, every weekend by RV, by plane
a couple of times a year): Transport's three pills Car / Plane / RV became **Travelling by** with two, Plane
and RV, both off for an ordinary trip; Season follows the trip's first day until he picks one (he lives in
Sweden: winter is November to March); Season, Food and Laundry fold away under **More choices**.

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
   is picked), one quiet line (Footnote, muted, id `trip-kind-note`), `Library.quickNote()` (0.78), naming his
   always-packed templates (role "base", template order, an unnamed one "Untitled template", joined "A", "A and
   B", "A, B and C" — read from the library each time, like Travelling by's line): **"Quick packs only what
   you tick — not <names>, no Plane or RV template. Plane still turns on the airport checks."**; with no
   always-packed template the "not <names>, " part is left out. As short as it can be: with one name it is
   three lines on the iPhone SE (375 points) at the default text size. Trip settings says the same
   (`tripset-kind-note`). His point (13 Oct 2026): he did not understand "…no plane or RV template. Plane and RV
   still count." (0.76), and "Always" alone is cryptic — he thinks of his always-packed template by its own name.
   (The airport-checks sentence: field test 5.1/6.1, 3 Oct 2026 — Transport had looked switched off; until 0.76
   the line said "…no transport kit. Transport still counts.") Until 0.67: a "Quick" switch at the
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
   last, **"Other Templates"** for templates with no activity area (0.62; see "Templates offered").
   Heading: `groupHeading(id, label)` = "GA · Goal Activity", "WET · Workout, Exercise & Training",
   "OE · Other Events" (code, " · ", the label as written — **not in capitals since 0.78**, his "GA · Goal
   Activity — not all caps", 13 Oct 2026; until then the label was upper-cased) as `HeadingTitle` (20 heavy violet with a
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
7. **Travelling by** (`TravellingBy`, 0.76 — until then **Transport** with three pills Car, Plane, RV,
   `trip-transport-0…2`). Heading "Travelling by" (`HeadingTitle`, Subheadline semibold blue), id
   `trip-transport-title` (kept). Then ONE row of two pills:
   - **Plane** (id `trip-transport-1`) and **RV** (id `trip-transport-2`) — the numbers are their places
     in `TRANSPORTS` (Car, Plane, RV), so both keep the ids they had before 0.76; `trip-transport-0` (Car) is
     gone. Each pill: a small drawing from the template icons (`TemplateIconCatalog` "plane" and "rv" — the
     Camper), `Metrics.glyph` square (iPhone 20, Mac 16), stroke 1.8, then the word; Subheadline, semibold
     when lit; lit = filled blue, icon and word white; off = `Theme.bg` fill, ink, 1 pt `Theme.line` stroke;
     capsule, padding 12 sideways, min height `Metrics.chip`; the lit one carries `.isSelected` (and the
     value "On", else "Off"); the drawing is hidden from VoiceOver.
   - **Both OFF to begin with.** At most one is on: tapping an off pill lights it (the other goes off);
     tapping the LIT pill turns it off — back to neither (`Library.travelling(_:tapped:)`).
   - **Storage unchanged** — `trip.transport`: neither on = **"Car"** (exactly what an ordinary trip stored
     before 0.76), Plane = "Plane", RV = "RV". So the transport templates (`listsForEvent`: role "transport"
     whose `transport` is the trip's), "Only on some trips → Transport" rules (a rule of Car = trips with
     neither on), the cabin check (Plane only), old trips, backups, sync and the web app (parity) all read it
     as before. A pill is lit only for its own word (`Library.travelLit`): "Car", "" or a word the app does
     not know light neither.
   - Under them, one quiet line (Footnote, muted, wraps; id `trip-transport-note`) —
     `Library.travelNote(quick:)`: **"Leave both off for an ordinary trip. Plane adds the airport checks ·
     RV adds <name>."**, where <name> is read from the library at the moment the line is drawn (a renamed,
     added or deleted template shows at once) — every template with role "transport" and that transport, in
     template order, an unnamed one "Untitled template", joined "A", "A and B", "A, B and C"
     (`Library.transportTemplateNames`). The airport checks are Before you go's cabin check (below,
     `transport == "Plane"` only). The parts:
     - A **Plane** transport template: "Plane adds <name> and the airport checks"; none: "Plane adds the
       airport checks".
     - **No RV transport template: the RV part is left out** ("… Plane adds the airport checks.") —
       decided 13 Oct 2026: "RV adds your RV template" would promise a template that is not there (an RV
       trip still packs the things whose rule says RV, as every rule does).
     - A **Car** transport template (he deleted his; an old backup or the web app can still hold one):
       "Leave both off for an ordinary trip — it adds <name>." — it does come on every ordinary Full trip,
       so the line says so rather than hide it.
     - **Quick** picked: no template names at all — Quick packs no transport template (the line under Full
       trip | Quick says so) — so the line is "Leave both off for an ordinary trip. Plane adds the airport
       checks." (the cabin check runs on a Quick plane trip too).
7a. **Flights and stay** (`FlightsAndStay`, 0.80 — spec 07 part 18 B), only while **Plane** is lit, directly under
   Travelling by's line: the framed block of "I leave at" (item 3a: corner 12, 1.5-pt blue border over 6 % blue),
   ids `trip-flights-*` (`trip-flights-frame`, `-title`, `-what`, `-leg-<n>-label/number/date/date-add/from/to/remove`,
   `-add`, `-destination`, `-stay-name`, `-stay-address`, `-stay-phone`, `-stay-until`, `-stay-until-add`, `-note`).
   The plane drawing, "Flights and stay", "for a lost bag"; the flights — **Out** and **Home** to begin with, **Add a
   flight** puts a **Connection** before Home (a connection has a ✕) — each a flight number, a day (the trip's first day
   for Out, its last for Home until he picks one; no dates: Add a day) and From → To; **Destination** (the Place as
   placeholder); **Where you stay**: Hotel or flat, Address, Phone, Until (the last day until he picks one); the note
   "Optional. What the airline's desk asks when a bag does not arrive. Each checked bag's tag number goes in on the Packing
   day, under Tags." Optional: never in the still-needed line. Create stores it only with Plane lit
   (`Library.setFlightsAndStay`, cleaned — empty legs go); the form starts over with Out and Home empty.
8. **More choices** (`MoreChoices`, 0.76 — his ask of 13 Oct 2026: Dates, the templates, Travelling by and
   "I leave at" stay in sight; the rest folds). One row after Travelling by: a button (id `trip-more`, min
   height 28) holding a chevron (pointing right when closed, down when open; ink, `Metrics.glyph`) and
   "More choices" (Subheadline semibold blue); its value is "Open" or "Closed". While CLOSED, under it, a
   muted summary of what is picked (Footnote, id `trip-more-summary`, set in under the words; a tap on it
   opens the fold too): **"<Season> · <Food> · <Laundry>"** — the season's word, the food's short words,
   then "No laundry" or "Laundry, <n> nights" (`HomeScreen.moreSummary`), e.g. "Summer · Mix · No
   laundry", "Winter · Eating out · Laundry, 4 nights". Words only — the Season drawings are on the pills. While OPEN the summary is not shown — the pills
   below say the same — and Season, Food and Laundry follow, with their ids unchanged:
   - **Season** pills Summer, Winter (`trip-season-0…1`); heading id `trip-season-title`. Set from the
     dates until he taps one (Behaviour, "Season from the dates"). Each pill carries a drawing before its
     word (0.78, his "same idea as Travelling by"): Summer the catalog's `sun`, Winter its `snow` —
     `HomeScreen.seasonIcon`, drawn by `Pills(icons:)` exactly as Travelling by draws Plane and RV
     (`IconMark`, `Metrics.glyph`, weight 1.8, 5 pt before the word, hidden from VoiceOver, in the pill's
     word colour); the pill's accessibility value is the drawing's key ("sun", "snow"). The same on Trip
     settings (`tripset-season-*`) and on Only on some trips → Season (`row-seasons-*`, `thing-seasons-*`); a
     stored season the app does not know has no drawing (and no value).
   - **Food** pills (`trip-catering-0…2`) with his short words: "Self-sufficient" (self),
     "Eating out" (eatout), "Mix" (mixed) (`HomeScreen.shortFood`; the model keeps the web app's
     longer labels). Heading id `trip-catering-title`. "Mix" since 0.78 — his words (13 Oct 2026):
     "Self-sufficient, Eating out & Mix — keep short so that it all fits on one line" ("Mix of both" wrapped
     to a second line on the iPhone). The three fit on one line on the smallest iPhone the app runs on
     (iPhone SE, 375 points) at the default text size, padding unchanged. The same short words on Trip
     settings and on Only on some trips → Food (`TripLimit.label`, which `onlyOnWords` now uses too).
   - **Laundry switch** — see "Laundry" below; id prefix `trip-laundry`.

   **Closed to begin with**; open or closed is remembered on this device (`@AppStorage("ams.create.more")`,
   for every trip made there; cleared when the UI tests launch the app). The answers inside count whether
   it is open or not — a closed fold still makes a winter trip winter.
9. **"Create trip"** button (under More choices, open or closed): 18 bold white on BLUE, full width, min height 52, corner 12, id
    `trip-create`. Never disabled, never grey.
10. **Still-needed line** (only after a press with something missing), 15 bold red, centred — every line of
    it when it wraps (`multilineTextAlignment(.center)`, 0.73: two sentences often take two lines), id
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

- **Still needed** (`needs(flat)`), sentences joined by a space: name blank (jsTrim) → "Give the trip a
  name."; then the template rule (`Library.templateMissing(draft)`, 0.73 — below); then "Tap the trip's
  last day — the same day again for a day trip." while only the first day is tapped (0.67: Create never
  makes a day trip by accident; the grid tells Home through `onWaiting`); else "". The line appears only
  after a press of Create; from then on it follows every change of the name, the template pills, the
  grid, Full trip | Quick, Travelling by, Season and Food (0.73: those decide whether Always packed alone has
  something to pack), and disappears when nothing is missing.
- **Season from the dates** (0.76, his ask of 13 Oct 2026 — he lives in Sweden). Until he taps a Season
  pill himself on this form, Season FOLLOWS the dates: the trip's first day in November, December, January,
  February or March → **Winter**; any other month → **Summer**; no dates (none tapped yet, or Clear dates) →
  **Summer**, today's default. `Library.seasonFor(firstDay:)` takes the first day as "YYYY-MM-DD" (`ymd`, the
  device's own date) and reads its month; "" or anything it cannot read → "Summer". It follows at once: the
  first day tapped (before the last), a new first day, Clear dates. A tap on EITHER Season pill — the lit
  one too — makes his choice stick for this form (`seasonByHand`): new dates no longer change it. It works
  the same whether More choices is open or closed (closed, the summary shows the season the dates chose).
- **The template rule** (`Library.templateMissing(_ draft:)`, 0.73 — his must-fix: Create refused a short
  trip of his small always-packed core alone with "Pick at least one template."). A ticked template is
  always enough (nil). With NONE ticked, the draft is built as `createTrip` builds it (`coerceEvent`,
  nights from the dates, `builtLines`): any line → nil — a Full trip brings every always-packed template
  and its transport's kit without a tick, so those alone make the trip. Only a trip with nothing to pack
  at all is asked for a template, in words that say why: Quick → "Pick a template — Quick packs only the
  templates you tick."; an always-packed template holds a thing (named, not "Not in use") but none fits
  this trip (season, transport or food rule it out) → "Pick a template — nothing always packed fits this
  trip."; else → "Pick a template — nothing is always packed yet." With no name too, e.g. "Give the trip
  a name. Pick a template — nothing is always packed yet." (Until 0.73: no template → "Pick at least one
  template.", with no name "Give the trip a name and pick at least one template.")
- **Create** with something missing: nothing is made; the line says what; a missing name focuses the
  name field.
- **Create** with nothing missing: the draft (`draft(flat)` — the same one `needs` asks about)
  `newEvent(name: jsTrim(name), mode: quick ? "quick" : "trip")` gets transport, season, catering, laundry, `extra.laundryNights = laundryNights`,
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
  to Full trip), Laundry and laundry nights are reset — and (0.76) Season starts over too: his own pick no
  longer sticks and, with the dates gone, Season follows them back to Summer;
  **Travelling by, Food and the two dates are NOT reset** (they stay as last chosen until the
  view is rebuilt). The new trip opens as a sheet. Kept so on purpose (the spec pass, 5 Oct 2026):
  the next trip is usually travelled the same way, and the pills show the answers before
  Create is pressed. (Until 0.76 Season was kept too; since the dates choose it, the next trip's dates do.)
  More choices stays as it was, open or closed.
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
no ticked template still gets the base and transport templates. Since 0.73 the screen agrees: it asks for
a template only when the trip would have nothing to pack at all (`templateMissing`, above); until then it
always required one.

**Templates offered** (`Library.activityChoices()`): resolved templates with `role == ""` whose
`group` is one of GA, WET, OE, grouped and ordered as above — then, last, every `role == ""` template
whose group is empty or unknown, A–Z, as a group with id "" and label "Other Templates" (heading
"Other Templates", violet — his casing, 0.78; pills numbered on from the others). The web app offers such lists last
("Other lists"); until 0.62 they were never offered here although A new template offers "No activity
area" (the spec pass, 5 Oct 2026). The base, transport, container ("Bags") and loose roles are never
offered.

**Always packed is a choice, not a fixed template (0.71).** Every template with role "base" comes on every Full
trip (`listsForEvent`: all of them, in template order, before the transport template and the ticked ones; the first
wins a name+bag clash); Quick leaves them all out. A template is moved into or out of Always packed on its page
(spec 04, Activity area; `setTemplateArea`): moved out, it is offered here like any activity template and comes only
when ticked; moved in, it is no longer offered. None always packed is allowed. With something always packed, a Full
trip needs no ticked template (0.73, `templateMissing`); with nothing always packed, Create asks for one ("Pick a
template — nothing is always packed yet."). Trips already made keep their lines; their next Trip settings Save rebuilds them by the new roles. "Make a
small core from this…" (spec 04 §14b) makes a new always-packed template from part of a big one and moves the big
one out in one step. Tests: `TemplateFacesTests.testATemplateMovesIntoAndOutOfAlwaysPacked`, UI
`testATemplateMovesOutOfAndIntoAlwaysPacked`.

### Data
Writes one `trips` record and one `entries` record per line. AppStorage: none.

### iPhone vs Mac
Same view. On the Mac the screen column is at most 720 pt wide (`RootView`). The new trip opens as
a sheet window.

### Tests
**0.80:** `testFlightsAndStayOnlyOnAPlaneTrip` — Flights and stay only with Plane lit, Out and Home, a connection added
and removed, kept through Plane off and on, stored by Create and shown (trimmed) by Trip settings, kept unseen when
saved with Plane off; `testABagTagNumberAtTheTagsStation` (the Packing day's Tags and the Bags card). Model
`TripTravelTests` (9). Spec 07 part 18 B.
**0.76:** `testTravellingByIsPlaneOrRVOrNeither` (`-uiTestingTravel`: "Travelling by", Plane `trip-transport-1` and
RV `trip-transport-2`, no `trip-transport-0`, both off; the line "Leave both off for an ordinary trip. Plane adds the
airport checks · RV adds Camper kit.", Quick → no name, Full trip → the name again; RV then Plane → only Plane, the lit
Plane tapped → both off; an RV Hiking trip is 0/9 (the Camper kit's two); Trip settings shows RV and names it, RV
tapped off and saved → 0/7, reopened both off; the sample's "Car" trip opens with both off — red with a tap on the lit
pill planted to keep it lit: "trip-transport-1 did not go off"; with the line planted as "…RV adds your RV template.":
"the line does not name the RV template"; with a Car trip loaded as RV in Trip settings: "the trip saved without Plane
or RV shows one lit"), `testMoreChoicesFoldSeasonFoodAndLaundry` (closed to begin with — no Season, Food or Laundry;
templates, Travelling by and the dates outside it; "Summer · Mix · No laundry"; opened, the line goes; Eating
out + Laundry, closed → "Summer · Eating out · Laundry, 4 nights"; a tap on the line opens it; a trip made with it
closed keeps Eating out and the laundry; Trip settings has no `tripset-more` — red with the fold open to begin with:
"More choices is open to begin with"; with the line planted on "mixed": "the line does not follow the choices: 'Summer ·
Mix of both · Laundry, 4 nights'"; with "Mix of both" planted back (0.78): "the line does not say what is picked: 'Summer ·
Mix of both · No laundry'"), **0.78:** `testTheFoodPillsFitOnOneLine` (More choices opened: `trip-catering-0…2` have the
same top within 2 points and the third says "Mix"; the same for `tripset-catering-*` in the sample trip's Trip settings —
red with "Mix of both" planted back: on the iPhone SE (375 points) "the Food pills wrap: ["Self-sufficient at 489.5",
"Eating out at 489.5", "Mix of both at 523.5"]"; on the wider iPhone 18 Pro the three still fit, so there it is the
words that go red: "("Mix of both") is not equal to ("Mix") - the third Food pill does not say Mix"),
`testTheSeasonPillsCarryTheSunAndTheSnowflake` (the value of Summer is "sun" and of Winter "snow" on `trip-season-*`,
`tripset-season-*`, Hiking's first row `row-seasons-*` and the Headlamp's `thing-seasons-*`; the More choices line still
starts "Summer · " — red with the drawings planted out of `Pills`: "("Optional("")") is not equal to
("Optional("sun")") - trip-season: Summer has no sun"), `testSeasonFollowsTheFirstDayUntilHePicksOne` (the 15th of the nearest winter and
summer months, whatever day the tests run: no dates Summer; a winter first day alone → Winter; a summer one → Summer; a
winter day trip → Winter; Clear dates → Summer; Summer by hand, then a new winter range → still Summer; the trip keeps
Summer, and new dates in Trip settings leave it; the next trip starts over, a winter first day → Winter — red with the
dates never read: "a first day in winter did not make the trip Winter"; with his pick not sticking: "new dates
overwrote the season he picked"; with Trip settings following its new dates: "new dates in Trip settings changed the
trip's season"; with the hand pick not cleared by Create: "his pick for the last trip still sticks on the next"). Model:
`TravellingByTests` — a tap lights one, the lit one goes back to "Car", only a pill's own word lights it; neither on is
still a Car trip and brings no RV template, RV brings it; the line names one, two and a Car template, none in Quick,
leaves the RV part out without an RV template, never names a non-transport template; Winter for 11–3, Summer otherwise
and for "" or junk — red with March planted out ("2027-03-31 is not Winter"), with a tap always lighting ("tapping the
lit RV did not turn it off"), and with "your RV template" planted ("no RV template: the RV part is not left out").
Updated for 0.76: `testABagOnTheTripSaysWhetherItGoesInTheCabin` reads "Plane and RV still count" (red with the old
line planted: "Quick does not say that Plane and RV still count: '…Transport still counts.'"),
`testContextSitsUnderTheWorkouts` measures against Plane (`trip-transport-1`), and the tests that use Season, Food or
Laundry on Create new trip open More choices first (`openMoreChoices`: `testLaundryCountsPerNightThingsFourNightsAtMost`,
`testTheEditorsLeadWithTheirHeadings`, `summerTripFromHiking` in the Only on some trips tests). Green on the iPhone
(13 Oct 2026: the 20 tests that touch Create new trip's or Trip settings' answers in light, the three new ones and the
headings test in dark) and on GitHub's Mac (a probe running the three new ones and six of the updated ones).
UI: `testHomeBuildsATrip` (Create never greyed; early press says "Give the trip a name." — the sample's
Common base is always packed, so no template is missing; the line goes once the name is typed; the trip opens
with lines; it is listed as `trip-row-1`), `testAlwaysPackedAloneMakesATrip` (0.73: Trip settings saves the
sample trip with Hiking unticked → 0/4, the Common base alone; Create with a name and Quick says "Pick a template
— Quick packs only the templates you tick." and makes nothing; Full trip → the line goes and the trip opens at
0/4 — red with the old rule planted in Trip settings: "Save with no template ticked was refused: 'Pick at least
one template.'", and planted on Home only: "the line stayed on a Full trip that Always packed fills: 'Pick at
least one template.'"), `testDatesArePickedLikeBooking` (0.67: the grid open at once,
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
(the Quick line is there with Full trip AND with Quick picked; since 0.78 it says "not Common base, no Plane or RV
template" and "airport checks", and the template groups read "GA · Goal Activity", none in capitals — red with the
0.76 line planted: "'Quick packs only the templates you tick — no common base, no plane or RV template. Plane and RV
still count.'", and with the capitals planted back: "the template groups are in capitals: [\"GA · GOAL ACTIVITY\"]"), `testABagOnTheTripSaysWhetherItGoesInTheCabin`
(`trip-kind-note` contains "Plane still turns on the airport checks" since 0.78; "Plane and RV still count" in 0.76, "Transport still counts" before), **0.67:** `testFullTripOrQuickIsChosenUnderTheName`
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
`testAQuickTripSkipsTheBase`, `testTheChoicesAreHisGroupsInHisOrder` (GA, WET, then "Other Templates"),
`testAlwaysPackedAloneIsEnoughForAFullTrip` (0.73: `templateMissing` — nothing always packed → "…nothing is
always packed yet."; a base template → nil and the trip is its two things; `changeTrip` with every template
unticked → rebuilt to the base alone; Quick → "…Quick packs only the templates you tick."; a ticked template →
nil; a winter-only base on a summer trip → "…nothing always packed fits this trip.", on a winter trip nil — red
with the old rule planted, `templateMissing` returning "Pick at least one template." for no ticked template:
"a Full trip of Always packed alone was refused", "Save with no template ticked was refused");
`WorkoutContextsTests` (PackingCore, 0.67: each workout narrowed by its own; the fallback to the trip's
`contexts`; an empty entry narrows nothing; an entry for a non-WET template changes nothing; the JSON round
trip, no key when empty, junk read as nothing; a shared file and link carry it) and
`WorkoutContextsLibraryTests` (made, changed in Trip settings with 1 added / 1 removed, kept by the sync
records and a backup, copied by Start again).
**Not covered:** that Travelling by and Food survive a create; that a workout's picks are dropped when it
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
   while the trip has dates (a time on a day needs the day). **One framed block** (0.75, his yes of 13 Oct 2026:
   so he sees which lines belong to that function): a rounded frame (corner 12, as the app's cards and wide
   buttons; padding 12) with a 1.5-pt border in the screen's tint (blue here, green in Trip settings) over a very
   light fill of it (6 %), id `trip-leave-frame` (an accessibility container: everything below is inside it and
   keeps its own id). Its header row: a small hand-drawn **door** (`DoorMark`, a door in its frame on a floor
   line with a knob — the app's own stroked drawing on the 24-grid, 1.8 pt, never a stock symbol; `Metrics.glyph`
   square, in the tint, hidden from VoiceOver), the heading "I leave at" (Subheadline semibold blue,
   id `trip-leave-title`) and, pushed to the right, **"the door check"** (Footnote muted, id `trip-leave-what`) —
   what the block is for. Then a `Grid` of two rows so the times line up: **First day** and **Last day**
   (Subheadline ink). A row with no time: **Add a time** (Footnote semibold blue capsule outline,
   `Metrics.chip` tall, id `trip-leave-out-add` / `trip-leave-home-add`) — it sets 07:30 (first day) or 10:00
   (last day) and, on the iPhone, asks the system's notification question once (`PackingReminders.askToShow`).
   A row with a time: the compact system time picker (id `…-time`), **"Check 07:15"** (Footnote mono muted —
   the time minus 15 minutes; id `…-check`) and a small quiet ✕ (drawn, muted, `Metrics.glyph` in a
   `Metrics.compact` square, id `…-remove`, label "Remove the time") that takes the time away. Under the rows a
   hairline (1 pt, `Theme.line`), then (Footnote muted, id `trip-leave-note`): "Optional. 15 minutes before, the
   iPhone names what is still unticked — on the last day, what is not in a bag yet. Before this time the trip is
   still at Pack." (Mac: "…your iPhone names…"; the last sentence since 0.75 — the first day's time is when the
   trip turns to On site, "When a trip sets off" under The loop). On the iPhone, with a time set
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
`expiry`, `consumable`, `keep`, retired. (That is why Before you go reads the THING, not the
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

**What was inside, kept at the review (0.73, 12 Oct 2026; spec 07 part 9, "A past trip").** `saveReview`, at a
trip's FIRST review, has each kit line keep what is inside its kit then (`keepKitsAtReview` → line key `kitThen`:
id, name, how many, grams each, taken out — his order) and marks the trip `kitsKept: true` (spec 01 §1.12). Such a
trip shows what was inside then; a line of it without `kitThen` held nothing then. A trip not reviewed follows the
kit; a trip reviewed before 0.73 (no mark) shows the kit as it is now, and a later review keeps nothing for it.
`justTheList` (a shared trip) drops both keys; `startAgain` drops `kitThen`; a rebuild keeps a matched line whole,
its copy with it.

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
wash bag open with two ticks and "2 to go"; its own tap does not tick it; the second tick does). A past trip (0.73):
model `testAReviewedTripKeepsWhatWasInsideItsKitsAndALiveTripFollowsThem`,
`testATripReviewedBeforeKitsWereKeptShowsThemAsTheyAreNow`,
`testWhatAPastTripKeptIsStoredSyncedBackedUpAndRestoredButNeverSentOrStartedAgain`; UI
`testAReviewedTripShowsWhatWasInsideItsKitThen` (the sample's first trip reviewed, then the pouch changed: still
"3 inside" with the Plasters and no Take out; the second trip, `trip-row-1`, "1 missing: Spare cord").

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
  sorted by Into, and shows under To do in Before you go and on Home's countdown once its step is due; the
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
   box "No trip under way today." (16 medium muted, min height 48, id `events-now-empty`). A reviewed
   trip is always in Done (0.73, see Pile), so Now and Coming up hold only trips still to finish.
4. Each trip a `TripRow` button, id **`trip-row-<n>` where n is the trip's index in the WHOLE sorted
   list**, not within its pile.
5. In Done: reviewed trips are folded under a toggle row — a 38 pt circle (14 % green) with a 22 pt
   chevron (rotates 90° when open), "Reviewed" (17 heavy) and the count (17 heavy mono muted); id
   `events-reviewed`, `.isSelected` when open. Starts folded every time the screen is built (not
   remembered). Every reviewed trip is here, whatever its dates (0.73 — until then a reviewed trip with no
   dates, or today's or later ones, stayed unfolded in Coming up or Now, among his active trips). Inside
   the fold the rows keep the whole list's order, so a reviewed trip without dates (sort rank 1) or with
   dates still ahead (rank 0) comes before the past ones.
6. When there is any trip: **Your year** and **All your trips** (below).

### `TripRow` (one trip)

- Left: name (18 semibold ink, one line; "Untitled event" when empty); under it the when-line (15
  medium muted, up to 2 lines) = parts joined " · ": the dates (a single day, or "start – end"), the
  countdown label for the start ("in 12 days", "Today", "3 days ago"…), the place (`destination`), the
  forecast's temperature range ("4–11°C") — or "No dates" when there is nothing. Dates are written
  "3 Oct 2026" — fixed English words on every device (`TripChecksCard.day`, 0.62), as the date grid,
  Before you go and the map write them; until then they followed the device ("Oct 3, 2026").
- Right: the state badge (13 heavy, capsule, min height 22, id `trip-state`): **Planned** (muted on
  `Theme.line`), **Packing** (white on orange), **Ready** (white on green), **Reviewed** (muted on
  `Theme.line`) — ONE view, `TripStateBadge` (EventsScreen.swift), which the trip screen's header shows too
  for Reviewed since 0.73; under it "done/total" or "done/total · N set aside" (15 bold mono; green when Ready,
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
- **Pile** (`Library.tripWhen(trip, today:)`, 0.73 — ONE rule, also "still ahead" for a change to a
  thing): **reviewed (`isReviewed`) → Done, whatever the dates** (his must-fix, 12 Oct 2026: a trip he
  reviewed stayed among his active trips); else, string comparison of YYYY-MM-DD (trimmed) with today:
  no start → Coming up; start > today → Coming up; start ≤ today ≤ end (end = start when empty) → Now;
  else → Done. The countdown and the packing reminders already leave a reviewed trip out
  (`stillToLeave`), as do the place codes and the door check.
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
packed; reviewed → been; today and the last day → now, the day after → been; open to-dos counted;
0.73 `testAReviewedTripIsDoneWhateverItsDates`: reviewed undated / today / later → been and not still ahead,
an undated trip not reviewed → coming up and still ahead, the pile and "still ahead" never disagree — red with
the reviewed rule planted out of `tripWhen`: "the reviewed trip 'No dates' is not in Done"),
UI 0.73 `testAReviewedTripWithoutDatesIsDone` (`-uiTestingReviewedUndated`: Done counts 1, no Coming up, the
row folded until `events-reviewed` is tapped, then under it),
`TripEventsTests.testSortEventsForListOrdersNearestUpcomingFirstThenUndatedThenPast`,
`testSortEventsForListAnUnreadableStartDateCountsAsUndated`, `TravelYearTests` (all 4).
**Not covered:** "N set aside" on a row, the weather words on a row.

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
(0.36 — Tick everything removed and Clear every tick moved into Trip settings in 0.79, his decision of 13 Oct
2026), Excel (0.35) and Share (0.38) side by side (his test D.22), Bought on site (0.52/0.56), On site
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

**Header** (padding 16) — since 0.73 ONE centre line, then the count under it (his picture of a reviewed
trip, 12 Oct 2026: the bare pen on the count's line did not read as a button, and "Reviewed" stood in grey
words on the line's top, off Done's centre). An `HStack(alignment: .center, spacing: 8)`:
- Trip name — Title 3 bold ink, up to 2 lines, scales to 0.85 (the whole name, not "Weekend in the…"),
  "Untitled event" when empty; id `trip-name`; `layoutPriority(1)`, so it takes the line's room before the
  space between. Its centre for the line is the middle of its FIRST line (`TripScreen.firstLineCentre`:
  height less the distance between the first and last baselines, halved): a name on two lines keeps the pen,
  the badge and Done on its first line, Done where the thumb expects it.
- Right after it, 8 pt away, the **pen** (Trip settings door, `TripSettingsDoor`): a round button
  (`RoundIconLabel`, Buttons.swift) — `Metrics.tap` across (36 on the iPhone, 26 on the Mac), green at 10 %
  inside a 1.4-pt green ring (the outlined header buttons' look, round), the drawn pen at `Metrics.glyph`
  (20 / 16) in green; id `trip-settings`, label "Trip settings". Until 0.73: a bare 24-pt pen in a 36×34
  target, on the count's line.
- Then the space, and at the right: the **Reviewed** badge when `Library.isReviewed(trip)` (0.62: a trip with
  only a review time, from the web app, offered Review again here) — since 0.73 the Trips row's own badge,
  `TripStateBadge(state: .reviewed)` (Footnote semibold muted on a `Theme.line` capsule, padding 10 sideways,
  min height 22 — see `TripRow`), never squeezed (`fixedSize`), id `trip-reviewed` (a text); until 0.73
  "Reviewed" in Subheadline semibold muted words. Otherwise, if the trip has lines, **Review** (outlined, id
  `trip-review`) — offered at ANY time, before the trip too. Since 0.81 (his pick of variant A, 14 Oct 2026) in the
  Templates / Refine violet — ring and 10 % fill `#7c5cd6`, words `#6548c0` by day, `#a58ce6` at night
  (`TripHeaderTone.review`; `HeaderButtonStyle(words:)`); green until then. Spec 07 part 17, "0.81" item 5.
  Then **Done** (filled green, id `trip-done`; **Escape** presses it — `.keyboardShortcut(.cancelAction)`,
  ⌘. on an iPhone keyboard — 0.62). Both buttons use `HeaderButtonStyle`, whose own font wins over the
  one the call site sets — 17 pt bold since 0.62, the size the call sites ask for (16 until then; the same
  everywhere in this area: Done, Cancel, Next, Close). Badge (22) and Done (`Metrics.header`, 30 / 24) share
  the line's centre.
- Under the line, 2 pt away, at the left: the progress "done/total" or "done/total · N set aside" (Callout
  semibold mono; green when all packed, else muted; id `trip-progress`; accessibility value "all packed" when
  all packed, else "").
- At the right end of that count line (0.77, his yes of 13 Oct 2026): **Take a break** — a small outlined pill,
  since 0.81 in a warm coffee amber (ring and 10 % fill `#a8651a` by day, `#e0a458` at night; the cup and words
  `#8a5215` / `#e0a458` — `TripHeaderTone.takeABreak`; green until then), the drawn cup and "Take a break" (or, with
  a break waiting, "Back at 19:00", "Back tomorrow 18:00"), id `trip-break` — only while
  the trip is at Pack (the loop strip's own reading) with something left. It opens the break sheet: how far he has
  come, and "Continue when?". Everything about it: spec 07 part 16.
- **What's left** (0.82, his yes of 14 Oct 2026; spec 07 part 20), under the count, 1 pt away, in the count's
  column (Take a break stays at the right, centred on the two lines): ONE line, id `trip-left` (a plain
  text) — only while the trip is at Pack (the strip's own reading, as Take a break) and has a line not set
  aside. "23 left · 2 to charge · about 25 min": the lines not set aside and not ticked (reminders too — the count's
  own total − done), the To charge card's things not charged (only while that card would show), and the time the rest
  takes at his own pace (`Library.whatsLeft`, `Library.packingPace`, `Library.aboutWords` — "less than a minute",
  to the minute under 10 min, then to 5 min, "about 1 h 25 min"). Footnote, monospaced digits, muted, up to two
  lines (scaling to 85 % first). Nothing left: "All packed" in Footnote semibold, the done heading's readable green
  (#227147 by day, #2f9e63 at night), then " · N to charge" while something is still to charge. Never "0 left".

**Loop strip** (`LoopDoor`, id `trip-loop`, value = the step's name) — see "The loop".

**Packing Stations row** ("Packing day" until 0.81; 0.79, his yes of 13 Oct 2026; spec 07 part 17) — only while the
trip is at Pack (the strip's own reading) and not opened from a place's code: right under the strip, fixed above the
scroll area, ONE slim row (container `day-row`) — the day's mark and "Packing Stations" (`day-title`), then six
station chips (since 0.81 slimmer than a pill: 22 pt on the iPhone, 18 on the Mac, 2 / 1 more above and below taking
the tap), **Bags out · Pack ·
Weigh · Tags · Photos · Ready** (`day-station-<key>`: `bags`, `pack`, `weigh`, `tags`, `photos`, `ready`; value =
"done", "no bags yet" or the station's words; the next one to do selected). Done = green with white words; the next
one lit; Pack carries "12/40". A tap on Pack scrolls to the list (the Sorting row); any other opens the Packing
Stations sheet on that station. Too wide for the iPhone it scrolls sideways, keeping the next station in view. When the trip
turns all packed while open here, Weigh opens by itself once per trip, 1.5 s later (part 17, rule 9).

**What the last settings save did** (only after one; 15 bold green, id `trip-rebuilt`):
`TripScreen.saying`: (0 added, 0 removed) "Saved. The list is the same."; (a, 0) "Saved: a new on the
list."; (0, g) "Saved: g no longer on the list."; (a, g) "Saved: a new, g no longer on the list."; after
Start again: "New trip from “<old name>”: N things, nothing ticked. Its dates are under the pen."
It stays until the sheet is closed.

**Sorting row** (0.64; padding 16 sideways) — since 0.74 in the SCROLL AREA, directly above the first heading of
the list (item 5 below; his ask of 12 Oct 2026: the choices sat far above the list, "disconnected from it", under
the loop strip with the cards between them and the lines); top padding 10. "Sorting" on the left and, on the SAME
line to its right, ONE drop-down (`DropDown`, spec 06 §21, with `heading: .beside`) holding the six sortings —
**When**, **Into**, **From where**, **Category**, **Section**, **Template** (0.74). Five pills did not fit an
iPhone's line, and he asked for drop-downs everywhere (6 Oct 2026); his marks of 2026-09-25 ("Sorting" on the
left, the choice beside it) are kept.
- "Sorting": Subheadline semibold, muted, one line, never squeezed (`fixedSize`); id `trip-view-label`.
- The field, 10 to its right, takes the rest of the line: the chosen sorting's words in Body ink and a drawn ▾
  (`Metrics.tap` tall, card fill, radius 10, a hairline border); id `trip-view`; accessibility label "Sorting",
  value = the chosen sorting's words (what tests read). A stored value that is none of the six (it cannot be,
  but a device keeps it) shows and ticks When, which is what `groupBy` does with it.
- A tap opens the list as a popover beside the field (on the iPhone too; the system puts it above or below,
  wherever it fits): container `trip-view-list`, six rows `trip-view-0…5` (When, Into, From where, Category,
  Section, Template — the ids the pills had, Section the new 4 in 0.64, Template 5 in 0.74), the
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
0. **Before you start** door (0.82, his yes of 14 Oct 2026; spec 07 part 19) — only while the trip is at Plan or
   at Pack with nothing packed yet, and one of its parts has something: what to buy and get ready ahead, a tap
   opens its sheet. Top padding 10. Own section below, "Before you start".
1. **Before you go** card (0.77: ONE card where two stood — Check before you go, and To charge since 0.75; only
   when one of its parts has something) — own section below. Top padding 10, as the weather card under it.
2. **Weather card** (always) — own section below.
3. **Bags card** (only when some bag has lines; FOLDED to one line by default since 0.74) — own section below.
4. **On site door** (only once On site has begun) — see "On site".
4a. **The Sorting row** (above), then — opened on a place — the place's chip, the debug door-check list (tests
   only), and "Only what is still unticked" with Show all (a tapped door check). Until 0.74 all of these sat above
   the scroll area, under the loop strip.
5. **The groups** (a lazy stack with **no spacing** — 4 until 0.67), one per non-empty group of
   `groupBy(view, trip.entries)`; `g` = the group's position in that list:
   - Heading row (top padding **6** — 12 until 0.67, his words of 6 Oct 2026, "Far too much space between the
     lines"; with a line above it, the heading's words stand about 12 pt under that line, 25 until 0.67):
     fold arrow (drawn chevron at `Metrics.glyph`, 20 / 16, with `onGrid`, in a `Metrics.lineButton` − 6 ×
     `Metrics.line` target — 34×36 and 20 pt until 0.67; pointing right when folded,
     down when open; id `trip-group-<g>-fold`, label "Open <heading>" / "Fold <heading>"); the heading
     (15 heavy; sorted When: the colour of the FIRST line's phase made readable; otherwise green; id
     `trip-group-<g>-label`; tapping the words folds too); since 0.82 the **progress mark** (spec 07 part 20 —
     `GroupProgressMark`, not a button, id `trip-group-<g>-progress`, its label "<ticked> of <packable> packed" /
     "all packed"): 14 pt across on the iPhone, 11 on the Mac, 8 pt after the words — a hairline track
     with a green arc from the top, clockwise, as long as ticked ÷ packable; when every packable line is ticked a
     filled green circle with a white tick, the words and the count in the trip's green made readable (#227147 by
     day, #2f9e63 at night — `GroupProgressMark.words`), and a soft green band behind
     the heading row (10 % by day, 18 % at night, corner 8, 6 pt past the row each side); becoming done while he
     looks, the check springs in (from 30 %, response 0.35, damping 0.55) and the colours ease in over 0.3 s — a 0.2 s
     fade with Reduce Motion; not drawn when every line is set aside; a folded group shows it too. Then the count
     "ticked/packable" (13 bold mono muted — green when done — set-aside lines excluded), 5 pt after the mark; and
     at the right the **whole-section tick** (unchanged — bigger, at the other end, and a button: the two never
     look alike in one place): a `TickCircle` of
     `Metrics.mark` (18 / 14; 20 until 0.67) — a `Theme.line` ring, or filled green with a white tick when
     every packable line of the section is ticked — in a `Metrics.lineButton` × `Metrics.line` target (40 × 30
     on the iPhone, 30 × 22 on the Mac; 40×36 until 0.67), so it sits above the lines' ⊘; id
     `trip-group-<g>-all`, label "Tick all of <heading>" / "Untick <heading>", `.isSelected` when done. When
     every line of the section is set aside there is nothing to tick: the button is not drawn (an empty target
     of the same size keeps the heading still) — 0.62; until
     then it sat there switched off and faded, against his rule. A press sets EVERY packable line of the section to "ticked" — or, when
     all were ticked, to "unticked" — in one `model.change`, one `setChecked` per line
     (`Library.setChecked(_:tripId:entryIds:)` since 0.79), and the trip then offers **Undo** for what it
     changed (the Undo bar, below; "The heading's tick, its Undo, and Clear every tick").
   - When not folded, its lines (see "A line" below).
6. *(Until 0.79: **Tick everything / Clear every tick** (`TickAllRow`, ids `trip-tickall`, `trip-clearall`), 18 pt
   under the list. Removed — his decision of 13 Oct 2026; see "The heading's tick, its Undo, and Clear every
   tick". Nothing stands between the list and Save as Excel now.)*
7. **Save as Excel** and **Share** side by side, equal width (ids `trip-excel`, `trip-share`), 12 pt under the
   list — own sections.
8. **Send to Obsidian** (`VaultCard`, only on a REVIEWED trip — `Library.isReviewed`; padding 16 sideways, 12 on
   top) — the whole width, in Save as Excel's style; see "The trip's page in his vault". At the top of the
   scroll area, as a card, from 0.70 until 0.73 (his ask, 12 Oct 2026: to the very bottom, like Save as Excel).
9. **Delete trip** — small red button at the right, own section; still LAST (his rule for removing anything),
   so the only thing after Send to Obsidian.

**Undo bar** (0.79, `TickUndoBar`): for 6 seconds after a heading's round tick or Clear every tick (in Trip
settings), BETWEEN the scroll area and the add bar — a row of the screen, never over a line: the list is shorter
while it shows. See "The heading's tick, its Undo, and Clear every tick".

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
  washtub at `Metrics.glyph` when laundry washes and the line is per night; then **where it comes from** (0.74,
  below); then the bag name (Footnote muted, one line, max 150 pt wide) — except when sorted Into. **0.69:** a ticked line with a pocket says
  **"Backpack · Front pocket"** there instead (max 200 wide); sorted Into (the heading names the bag), just
  "Front pocket". An unticked or set-aside line never shows a pocket. 2 pt above and below the words (5 until 0.67), at
  least `Metrics.line` tall, a hairline under it.
  Tap: toggles `checked` (`Library.setChecked`) — **a set-aside line does not tick**. **0.69:** ticking a line
  whose bag has pockets (`Library.pocketsByBag()`, asked once per screen) opens its **pocket pills** under it —
  see "Bag pockets on a trip".
- **Where it comes from** (0.74, his ask of 12 Oct 2026: "When I pack, it is valuable to know from which template
  the item comes — run, swim, bike, golf…"; of three looks he picked the template's own icon). On the line, just
  BEFORE the bag (before "To do" on a reminder), on the iPhone and the Mac alike (`TemplateMarks`, TripScreen.swift):
  the ICON of each template the line comes from — `Library.lineTemplates(tripId:)`, the same templates "Sorted by
  Template" puts it under (a line made from one template and brought by another shows both) — drawn by the app's own
  template icons (`TemplateIcons`, `IconMark`, the icon the template's cover shows: his pick or the suggestion;
  never an SF Symbol or emoji), in the Templates violet made readable day and night (`ThingDetailLine.violet`),
  **15 pt on the iPhone, 12 on the Mac** (about Footnote), stroke 1.9 at that scale, 3 pt apart, in the trip's
  template order. Up to THREE icons; four or more = the first two and "+N" (Footnote semibold violet). A template
  without an icon (its cover shows a letter) is its name's FIRST WORD in Footnote semibold violet instead. Never
  squeezed (`fixedSize`): the icons and the bag's words are laid out together (`MarksBeforeBag`, 6 apart, at the
  line's right): the words at most 150 wide (200 with a pocket) and cut first when the line is short of room, the
  icons right beside them — the bag's own frame of 150 left a gap between them on a short bag name.
  - Nothing at all on a line added on the trip (typed, Bought on site, sent) — and nothing while the trip is sorted
    by **Template** (the heading says it already).
  - A kit's line shows its own templates like any line.
  - One element for VoiceOver and the tests: label "From <names joined by ", ">" (never icon ids), value = the
    names joined by ", ", id **`trip-line-<n>-from`**; the Mac shows the same words as a tooltip (`.help`). 🪤 On
    the Mac the line's button folds the element into its own words (label "… From Common base, Hiking …"), so a
    test reads it there.
  - The line keeps its height (`Metrics.line`, 30 / 22): the icons are no taller than the bag's words.
  - A reminder's line (spec 07, part 12) shows them too, before "To do" — and so does each reminder due on
    **Before you go**'s To do (0.75, his yes of 13 Oct 2026; that section): the same `TemplateMarks` from the same
    `lineTemplates`, a reminder on two templates showing both.
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
  this holds for a section's tick-all too (and held for Tick everything until 0.79) — a refused kit is no change,
  so its Undo leaves it alone. `setKitContentTicked`: the last one ticked ticks
  the line (and forgets the list); unticking one unticks the line, the rest stay ticked. Unticking the line
  itself starts its ticks over. Taken out = not asked for; with nothing left inside, the kit ticks as any line.
  A set-aside kit's things do not tick. **Weight:** the Bags card and a bag's trips add each kit line as its own
  weight plus what is inside it now (`linesWithKitWeights`: each content's weight × its how-many, the taken out
  not counted). **Before you go** looks inside each kit line (`insideLines`): "Lighter, in the Camp pouch"
  in a cabin bag is not allowed on board; "Plasters, in the Camp pouch" runs out before you are home — each opens
  that thing. It always reads the kit as it is NOW (`liveKitOnLine`), like every thing it reads.
  **A reviewed trip (0.73):** its kit lines show what was inside at the review (`KitOnLine.kept`; spec 07 part 9,
  "A past trip"): the count, "1 missing" and the fold as then; open, the fold starts with "As it was when the trip
  was reviewed" (Footnote muted, `trip-line-<n>-kit-then`), each thing's name muted (struck through when it was
  taken out; `trip-line-<n>-kit-<k>-name` — on a live kit's plain rows too), and NO Take out / Put back, no ticks
  ("Check before each trip" is not asked: `check` false, `setKitContentTicked` refuses) and no warnings; it opens
  folded. The kit's own tick is a plain tick. Its weight on the Bags card is the weight then
  (`linesWithKitWeights(trip:)`). A trip reviewed before 0.73 shows the kits as they are now, as before.

Each row view is keyed by "id|checked|aside|group|placing|qtyNights|pocketing|pocket" (the last two 0.69), so it is rebuilt whenever its
tick, set-aside, group, place panel or night count changes (bug B1, his Mac 2026-09-26: a row showed no
tick while the trip had it; and a moved lazy row kept "Set place").

### Sorting and grouping (`groupBy`, `Grouping.swift`)

The groups come from ONE rule in the library, `Library.linesGrouped(tripId:sorting:lines:)` (0.77; until then
`TripScreen.grouped` + the call in `TripScreen.groups`): Template = `linesByTemplate`, every other sorting the
web app's `groupBy`, Into with a reminder under "To do". Take a break's overview (spec 07 part 16) reads the same
groups, so its pills and the trip's headings never disagree.

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
| Template (0.74) | `template` | EVERY template of the trip the line comes from — a line can be under several (below) | the trip's template order (`listsForEvent`: base, transport, ticked); then templates no longer on the trip; "Added on the trip" last | template name (violet) |

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

**Template** (0.74, his ask of 12 Oct 2026: "pack focused on e.g. Bike, Run or Golf") —
`Library.linesByTemplate(tripId:lines:)` (PackingLibrary/TripByTemplate.swift), NOT the web app's `groupBy` (which
knows no such mode and stays as the parity check holds it). It is built on ONE function, `Library.lineTemplates(tripId:)`
— each line's id → the templates it comes from, in the trip's template order (none for a line added on the trip) —
which the line's template icons read too ("Where it comes from", under "A line"). What it reads:
- **Which templates.** The trip's templates are `listsForEvent(trip, templatesForTrips())` — the common base
  ("Always packed": the template whose role is `base`), the transport's, then the ticked ones in their order; Quick
  mode: the ticked ones only. A template BRINGS a thing when one of its rows would come onto this trip as Trip
  settings' Save builds it: a name, not retired, `itemMatchesEvent` (season, transport, catering, its Context), and
  no weather tag unless the trip forces that condition on (`buildTotalEntries`' own rules, without the
  de-duplication).
- **A line's headings.** A line stands under the template it was made from (`sourceListId`) AND under every other
  trip template that brings the SAME thing (`sourceItemId`) — the sample's Headlamp, made from the base template,
  is also on Hiking, so it stands under both. A line whose own template is no longer on the trip (unticked later,
  its line kept because it was ticked or changed) stands under that template's name after the trip's templates, as
  long as the template exists. A line typed on the trip, Bought on site, or sent (a shared trip's lines carry no
  template) — and a line whose template is gone — stands under **"Added on the trip"**, last. Weather gear added
  from the forecast carries its template (`sourceListId`) and stands under it.
- **One line, one tick.** A line under two headings is the SAME line shown twice: ticking it under one ticks it
  under the other (the screen re-reads the trip; `trip-line-<n>` names both copies), setting it aside sets both
  aside. The trip's count (`trip-progress`) counts it ONCE; each heading's count "ticked/packable" counts its own
  lines, so the headings' counts can add up to more than the trip's. A heading's whole-section tick ticks its own
  lines — a shared line is then ticked under its other heading too.
- **Kits** stay one line: a kit is a line like any other (its things are shown under it, `KitLineParts`), under the
  templates that bring the kit. The pocket pills of the line just ticked show under the copy that was tapped only.
- **Headings** in the Templates violet made readable day and night (`ThingDetailLine.violet`, the colour a thing's
  template names have in Your things); "Added on the trip" in the trip's green (it is the trip's own). Two templates
  of the same name are two headings with the same words (their folds share a key — `<trip>|template|<name>`).
- **Elsewhere, unchanged:** Pack to go home (On site) keeps its own order, by bag; the voice walk walks the trip by
  place (spec 07 part 10), whatever the sorting; a place's code opens the trip sorted From where (it sets
  `ams.view` to `stored`), and the place filter and "Only what is still unticked" narrow the lines BEFORE they are
  grouped, under this sorting too. Set place shows only under From where.

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
  opens showing only what to take from the garage"): no Before you go, weather, Bags card or On site door
  above; no Excel, Share or Delete trip below (no Tick everything either, until 0.79); no "Add a thing" bar (a line typed there has no
  place and would vanish). When nothing on the trip is kept there: "Nothing on this trip is kept here. Tap the
  place above to see every line." (Subheadline muted; id `trip-place-none`).
- The header, the loop strip and the progress ("done/total" of the WHOLE trip) stay.

UI `testAPlacesCodeOpensTheTripBeingPackedOnItsLines` (`-uiTestingPlaces soon -uiTestingOpen AMSPACKING://P/G4R`:
the trip opens, chip value "Garage", sorting From where, ONE heading "Garage", two lines on screen — Headlamp and
Map — no add bar; the heading's tick-all → "2/…"; the chip → its own heading `trip-group-1-label` and the add bar
come back; on the iPhone the code first starts Pack by voice at the Garage, stopped and closed by the test).
On the iPhone such a code also starts Pack by voice at the place — even with the trip already open (from Trips,
or as Home's own window) (`testAPlacesCodeStartsPackByVoiceWithItsTripAlreadyOpen`; spec 07 part 10).

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
Section/Template (0.74) with no seventh, When ticked, every row on the screen; Into re-sorts, From where headings are the sample's
places), `testATripSortedBySectionReadsUnderItsSections` (0.64, `-uiTestingSections`: 0/9; Section chosen; the
headings Clothes, Lights, Everything else and no fourth; Lights' one press ticks its line (1/9, `trip-line-7`, the
spare batteries, ticked); folding Lights hides the line and opening shows it), `testAThingsPageSetsItsSectionOnATemplate`
(0.64, spec 05: the Map put under Lights on Hiking from its page → the trip, sorted by Section, has it under
Lights), `testAWholeSectionIsTickedInOnePress`, `testTheScreenSaysSoWhenEverythingIsPacked`,
`testAThingTypedWhilePackingJoinsTheTrip` (Add never disabled, `trip-add-needs`), `testSomethingBoughtOnSiteGoesOnTheList`
(the button appears only after typing, "1/8", "Bought on site" on line 7), `testAChangeToAThingReachesATripStillAhead`,
`testASetAsideLineIsNotPacked` (⊘ takes the tick, a set-aside line does not tick, ↻ brings it back unticked,
a section with every line set aside has no `trip-group-0-all`), `testSetPlaceAndTheReviewSayWhatIsMissingAndNoTemplateIsChosen`
(`trip-place-save-needs`), `testEscapeClosesTheTripsWindows`,
`testTheSortingSitsDirectlyAboveTheList` (0.74: the first heading at most 24 pt under the Sorting field, the
weather line and the Bags card above the field; picture `trip-sorting-above-list`; seen red with the row above the
cards: "Sorting is 204.0 pt above the first heading — not directly above the list"),
`testATripSortedByTemplateShowsAThingUnderBothItsTemplates` (0.74: Template is row 5; headings "Common base" then
"Hiking" and no third; `trip-line-3`, the Headlamp, twice; a tap → 1/7 and both copies selected; pictures
`trip-by-template`, `trip-by-template-ticked`; seen red with the "same thing" rule taken out: "the Headlamp stands
under 1 template(s), not both"), `testATripsLineShowsTheTemplatesItComesFrom` (0.74: the Headlamp's
`trip-line-3-from` names "Common base, Hiking", the Passport only "Common base", the Hiking boots "Hiking"; the line
at most 36 tall; a line typed on the trip (Tripod, `trip-line-7`) names none; sorted by Template, none; picture
`trip-line-templates`; on the Mac read from the line's own words after "From " — from every copy of the line:
sorted by Template it is two buttons of one name, and a plain query for one was a hard failure on GitHub's Mac
probe, 12 Oct 2026; seen red with the "same thing" rule
taken out: "the Headlamp does not name both its templates: 'Common base'"),
`testTheTripsPenSitsBesideItsNameAndReviewedBesideDone` (0.73, `-uiTestingReviewed`, both devices: the pen's
middle on the name's first line, after it (at most 16 pt away) and above the count; the pen round (as wide as
tall, within 0.5); the badge, the pen and Done on ONE centre line (within 1.5 pt); the badge before Done and at
least 21.5 tall; pictures `trip-header-reviewed`. Seen red on 0.72's header: "the pen is on the count's line",
"the pen is not a round button" (36 wide, 34 tall), "Reviewed sits -6.0 pt off Done's centre line", "Reviewed is
bare words, not the Trips row's badge"), `testSendToObsidianIsAtTheFootOfAReviewedTrip` (0.73: Send to Obsidian
under the trip's first line, then — scrolled to — under the lowest line, under Save as Excel and Share, as tall
as Save as Excel and on its left edge, with Delete trip under it; picture `trip-foot-obsidian`. Seen red with the
card back at the top: "Send to Obsidian is above the trip's lines").
Model: `TripByTemplateTests` (7, invented templates Always packed / Run / Bike):
`testEachLineKnowsItsTemplatesInTheTripsOrder` (`lineTemplates`: the Headlamp → Always packed, Bike, Run; a typed
line none; the icon read from the resolved template), `testALineStandsUnderEveryTemplateThatBringsIt`, `testOneTickShowsUnderEveryHeading`,
`testLinesAddedOnTheTripComeLast`, `testATemplateThatWouldNotBringTheThingDoesNotClaimIt` (a summer-only row in
winter), `testQuickAndATemplateNoLongerOnTheTrip`, `testOnlyTheLinesGivenAreGroupedAndEmptyHeadingsGo`; seen red
with the "same thing" rule taken out ("the Headlamp is not under Bike too") and with the season check taken out
("Run claims a summer-only Headlamp in winter").
Model: `CustomLineTests.testATypedThingJoinsTheTripAndSurvivesARegenerate`, `SetPlaceTests.testAPlaceSetOnTheTripReachesTheThingAndItsTwin`,
`TripCardsTests.testEverythingDecidedIsPacked`, `OnTheTripTests.testABoughtOnSiteLineIsInHandMarkedAndKept`,
`testTheStoredMarkKeepsItsFirstName`, `CountingTests.testProgress*`, `GroupingTests` (groupBy, container, category, storage).
Model: `TripEditsTests.testATripsFoldsGoWithIt`, `ReviewTests.testASetAsideLineNeverCountsAsPacked`.
UI (0.82, spec 07 part 20): `testAGroupTurnsGreenWhenItsLinesArePacked` (sorted From where: the Bathroom
cabinet's `trip-group-0-progress` "0 of 1 packed", its line ticked → "all packed"; the Garage "0 of 2 packed", one
line → "1 of 2 packed", folded → still "1 of 2 packed"; the round tick `trip-group-2-all` still there, to the
right of the mark, bigger, a button; Toothbrush unticked → "0 of 1 packed"; picture `trip-group-progress`),
`testTheTripSaysWhatIsLeft` (the sample at Pack: `trip-left` "7 left · about 5 min" under the count, in its column;
one tick → "6 left · about 5 min", every line ticked → "All packed"; `-uiTestingBattery`: "… · 2 to charge · …";
pictures `trip-whats-left`, `trip-whats-left-all-packed`, `trip-whats-left-charge`). Model `PackingPaceTests` (10;
see spec 07 part 20, with the planted faults each was seen red with).
**Not covered by any test:** the gradient sweep/Reduce Motion; the done moment's spring (an animation); the
placeholder for a vanished trip; a stored sorting that is none of the five.

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
`testPackByVoiceSaysWhyItCannotStart`, `testPackByVoiceGoesOnceMoreOverWhatWasLeft`, `testAPlaceCodeStartsPackByVoiceAtThePlace`,
`testAPlacesCodeStartsPackByVoiceWithItsTripAlreadyOpen` (0.73, the real link) (iPhone; skipped on the Mac); model
`VoiceWalkTests` (15), `PlaceLinksTests.testAPlacesCodeStartsPackByVoiceOnlyOnTheTripBeingPacked` (0.73). At the end, what was left for later is offered once more;
a place opened by its printed code starts the walk there by itself (switch `voice-autostart`, on by default).

---

## The heading's tick, its Undo, and Clear every tick (`TickAll.swift`, `TripBulk.swift`)

**Purpose and origin.** 0.36 brought the web app's "Mark everything packed" / "Clear every tick" (gap list
2026-09-27) to the foot of the trip as two big buttons, **Tick everything** and **Clear every tick**. **0.79 — his
decision of 13 Oct 2026:** they were "two very risky buttons — in a stressful situation half way packed, pressed by
mistake: catastrophe". So:
1. **Tick everything is gone** from the trip — no button, no shortcut (the Mac never had one). `Library.setAllChecked`
   stays in the model (its tests and the Batteries tests use it). Pack to go home's own Tick everything /
   Clear the ticks (`wayhome-tickall`) went with it — the same reasoning, decided the same day (see Pack to go
   home).
2. **Clear every tick is in Trip settings**, a quiet row last on the sheet, only while something is ticked; it still
   asks first.
3. **Undo** after a heading's round tick — which ticks (or unticks) a whole group in one press — and after Clear every
   tick: for 6 seconds the trip offers to put back exactly the ticks that press changed.

### The heading's round tick
As described under "The list" (id `trip-group-<g>-all`): a press ticks every packable line of the group, or — when
all are ticked — unticks them. Since 0.79 it is `Library.setChecked(on, tripId:, entryIds: <the group's lines not set
aside>)`, which returns a `TicksChanged`, and the trip shows the Undo bar for it (nothing changed — e.g. only a kit
still waiting for what is inside — no bar).

### The Undo bar (`TickUndoBar`, held by the trip screen as `@State undo: TickUndo?`)
- **Where:** a row of the trip screen BETWEEN the scroll area and the add bar (padding 16 sideways, 8 on top; with a
  place's lines shown, where there is no add bar, 10 under it too) — never over a line: the list is shorter while it
  shows. The same place as the to-do list's Undo (`LineUndoBar`, between its list and its add field).
- **Look:** a card (`Theme.card`, corner 12, 1 pt `Theme.line` border, padding 14 × 8): the words (Subheadline
  semibold ink, up to two lines, id `trip-undo-said`) and at the right **Undo** (Subheadline semibold green, 1.4 pt
  green capsule outline, min height `Metrics.chip`; id `trip-undo`, its value the words).
- **The words** (`TickUndo`): a heading's tick "Ticked N in <heading>" / "Unticked N in <heading>" — N the lines it
  CHANGED; Clear every tick "Cleared N ticks" ("Cleared 1 tick").
- **6 seconds**, then it goes by itself (`.task(id:)`: a new press is a new id with its own 6 seconds). Under the UI
  tests `-undoSeconds N` sets the time (`TickUndoBar.seconds`): on GitHub's Mac a test took longer than 6 seconds to
  reach the button (0.79's probe) — the flow tests use 600, one test 8 and watches it go.
- **One at a time:** a new press — another heading, the same heading again, Clear every tick — replaces it; the
  older one can no longer be undone.
- **Undo** writes back what the press changed (`Library.undo`, one `model.change`) and the bar goes.
- Not shown for another trip: Start a new trip from this one changes the trip on the screen, and an Undo held for
  the old one is not offered there.

### Clear every tick in Trip settings (`ClearTicksRow`)
- **Where:** the last thing in Trip settings' scroll area, under Start a new trip from this one (14 pt above it); only
  while something is ticked (`progress().done > 0`, set-aside lines not counted).
- **Closed:** a quiet row — at the left "N of M ticked" (Footnote mono-digit muted, id `tripset-clearall-count`), at
  the right a small red **Clear every tick** (Footnote semibold red, a 1 pt red capsule outline at 60 %, min height 30
  — `SmallDeleteButton`'s look; id `tripset-clearall`, value "N"). Never a big button.
- **Asking** (a card with a red border, as before): "Clear all N tick(s)?" (Callout semibold ink), "The list stays as
  it is. Only the ticks go." (Footnote muted); when other answers on Trip settings are changed and not saved, also
  "Your other changes here are not saved." (Footnote semibold red, id `tripset-clearall-unsaved`); **Keep them**
  (Callout semibold ink, id `tripset-clearall-no`) closes the question; **Clear the ticks** (red capsule, white
  Callout semibold, id `tripset-clearall-yes`).
- **Clear the ticks** clears at once (`Library.setEveryTick(false, tripId:)`), hands what it changed to the trip
  (`TripSettingsDoor.cleared`) and closes Trip settings — WITHOUT saving any other change on the sheet, as Start it
  does (hence the red line). The trip then shows "Cleared N ticks" with Undo. (Decided by the build: the Undo is the
  trip's, the same bar as a heading's — it is cheap, and a Cancel left on the sheet after the ticks were already
  cleared would read as if it could take the clear back.)

### Behaviour (model, `TripBulk.swift`)
- `setChecked(_ checked:, tripId:, entryIds:) -> TicksChanged`: one `setChecked` (one small write) per line, in order;
  a line already so is skipped, a line set aside is never ticked, a kit checked before each trip refuses a tick while
  something inside is unticked (`kitAllowsTick`) — none of these is in the result. `TicksChanged` = the trip, what
  the lines were set to, and per CHANGED line its id and its pocket key before (`POCKET_KEY`: a tick brings the
  usual pocket, `prechoosePocket`).
- `setEveryTick(_:tripId:)`: the same over every line not set aside whose tick differs (what Clear every tick
  does). `setAllChecked(_:tripId:) -> Int` is its count — unchanged for its callers, except that a refused kit is no
  longer counted.
- `undo(_ change:) -> Int`: each changed line still standing as the press left it goes back — its tick and its pocket
  WRITTEN back, not ticked again: a kit checked before each trip that Clear unpacked has lost what was ticked inside
  it (unticking a kit starts it over), so `setChecked(true)` would refuse it; written back it is packed again, and a
  packed kit counts all inside as ticked (it keeps no list). A line changed again since (by hand, on the other
  device) is left as he left it; one set aside since is not ticked underneath; one gone (a rebuild) is skipped.
  Returns how many went back. Each line is its own record, as a tick by hand is.
- Set-aside lines are untouched both ways (setting a line aside takes its tick, so none is ticked underneath since
  0.62; one from older data counts nowhere — see Counting).

### Tests
UI `testEveryTickIsClearedFromTripSettingsAndCanBeUndone` (the foot has no `trip-tickall` / `trip-clearall`; nothing
ticked → no `tripset-clearall`; two ticked → its value "2", below Start a new trip; it asks, Keep them keeps; Clear
the ticks closes Trip settings, 0/7, "Cleared 2 ticks", Undo → 2/7 with the same two; a changed name → the red
line), `testAHeadingsTickIsTakenBackByUndo` (sorted From where: the Passport by hand, the heading ticks the Phone
charger, "Ticked 1 in Chest of drawers", the bar above the add field, Undo → 1/7 with the Passport still ticked; the
Garage then the Hall closet, Undo takes back the Hall closet only; "Unticked 2 in Garage", Undo ticks it again),
`testTheUndoGoesByItself` (`-undoSeconds 8`: the Bathroom cabinet's tick, the bar comes and goes by itself, 1/7 kept).
The first two run with `-undoSeconds 600`. All seen red first with planted faults (no bar after a heading's tick; the row with
nothing ticked; a bar that never goes; no Undo after Clear; the Passport counted as changed; Tick everything back on
the foot; a newer press not replacing the older; no unsaved-line; Undo ignoring an untick). Until 0.79: `testEverythingIsTickedAndClearedAtOnce`. The tests that
needed everything ticked (Pack by voice with nothing left, the way home's photos, the door check, both Take a break
tests) tick every line by hand (`tickEveryLine`). Model `TripBulkTests`:
`testEverythingIsTickedAndClearedButWhatIsSetAside`, `testAHeadingsTickIsUndoneLineForLine`,
`testClearingEveryTickIsUndoneButNotWhatHeChangedSince`, `testUndoingAClearPacksAKitAgainWithWhatWasInside`,
`testUndoTakesAwayThePocketTheTickChose`.

---

## Trip settings (`TripSettings.swift`, `TripEdits.swift` → `changeTrip`, `Library.regenerated`)

**Purpose and origin.** "A trip's settings, changed after it is made — the gap list's first High item
(2026-09-27)" (0.32). A pen, not a gear (tests C.3, D.1; 0.40). The place added for his test G.6 ("the
place is not shown in the edit view", 0.40). Save in a bar at the bottom, always in sight (0.34; "the
cloud test lost it" 2026-09-27). 0.67: the same three changes as Create new trip — Full trip | Quick under
the name, the date picker always there (Clear dates instead of a Dates switch), Context per workout. 0.76:
Travelling by (Plane / RV) instead of Transport, as on Create new trip; Season does NOT follow the dates here,
and nothing folds (below).

**How it is reached and left.** The pen beside the trip's name (`trip-settings`, a round button since 0.73;
beside the count until then) opens it as a sheet
(`TripSettingsDoor` owns the sheet because the trip screen already has one for the review). Left with
**Cancel** (no change; **Escape** too, ⌘. on an iPhone keyboard — 0.62), **Save changes** (when nothing
is missing), **Start it** (Start again), **Clear the ticks** (0.79, Clear every tick — below), or a swipe down on the iPhone (= Cancel) — but only while
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
- **I leave at** (0.69), only while the trip has dates: as on Create new trip ("I leave at") — the same framed
  block since 0.75, door, "the door check", hairline and note — GREEN (border, light fill, door, heading), ids
  `tripset-leave-*` (`tripset-leave-frame`, `tripset-leave-what`, `tripset-leave-out-add`,
  `tripset-leave-out-check`, `tripset-leave-note`, `tripset-leave-refused`…). Loaded from
  `extra.leaveAt` / `extra.leaveHomeAt`; part of the sheet's snapshot (a changed time stops the swipe from
  closing it); Save writes them with `Library.setLeaveTime` inside `changeTrip` ("" takes one away). A trip open
  behind the sheet takes a new first-day time at once: its step and On site door follow it (The loop, "Turning
  while the trip is open").
- The template pill groups (ids `tripset-activity-<n>`, same numbering as Create new trip, "OTHER
  TEMPLATES" last; heading id `tripset-activity-title`), Context per workout (`WorkoutContexts`, 0.67:
  `tripset-context-title`, a line per ticked workout `tripset-context-<n>-name` with its pills
  `tripset-context-<n>-0…2`, n = its `tripset-activity-<n>`), **Travelling by** (0.76, `TravellingBy` as on
  Create new trip, blue like the sheet's other pills: heading `tripset-transport-title`, Plane `tripset-transport-1`, RV
  `tripset-transport-2`, the line `tripset-transport-note` — `Library.travelNote(quick:)` for the sheet's
  own Full trip | Quick; until 0.76 Transport, Car / Plane / RV `tripset-transport-0…2`), **Flights and stay**
  (0.80, only while Plane is lit; as on Create new trip, item 7a, in the sheet's own colour, ids `tripset-flights-*`;
  loaded from `extra.travel` (`Library.travel`, padded to Out and Home); part of the sheet's snapshot; Save writes it
  with `Library.setFlightsAndStay` inside `changeTrip` — only while Plane is lit: saved with Plane off, what was stored
  stays, unseen; the bag-tag numbers are never touched here),
  Season, **Pack weather gear anyway** (0.62: pills Rain, Cold, Heat, Wind, Snow — `WEATHER_CONDITIONS`,
  ids `tripset-weather-0…4`, heading `tripset-weather-title`, blue, several at once — the trip's
  `weatherOn`: his gear tagged for a picked condition comes onto the list whatever the forecast; the
  web app's "pack anyway"), Food (`tripset-season-*`, `tripset-catering-*`,
  headings `…-title`), Laundry (`tripset-laundry`, `-says`, `-nights-*`). **No More choices fold here**
  (decided 13 Oct 2026): Trip settings is where an existing trip's answers are changed, so they all stay in
  sight — and "Pack weather gear anyway" sits between Season and Food, so the same fold would not hold the
  same three.
- "Save rebuilds the list: what you ticked, added yourself or were sent stays; new things arrive; things
  no longer asked for go." (14 muted), a divider, and **Start a new trip from this one** (next section).
- Last, only while something is ticked (0.79): **Clear every tick** — "N of M ticked" and a small red button,
  asking first (`ClearTicksRow`, ids `tripset-clearall*`; "The heading's tick, its Undo, and Clear every tick").
- Bottom bar (top hairline, `Theme.bg`): the still-needed line (15 bold red, centred also when it wraps —
  0.73, id `tripset-needs`) and
  **Save changes** (18 bold white on green, min height 52, id `tripset-save`), never disabled.

### Behaviour
- **Load** (once, on appear): name, place = `destination`, dated iff `startDate` non-empty, start =
  start date (or today), end = end date (or the start), Quick iff mode "quick", laundry, laundry nights
  (`laundryNights(trip)`), templates = `trip.activities`, each template's contexts = its own entry in
  `activityContexts`, else the trip-wide `contexts` (0.67: what its things are narrowed by now — so a trip
  made before 0.67 shows its one Context on every workout, and a Save without a change rebuilds the same
  list), the trip's own `activityContexts` kept aside for the templates not shown, transport/season/food (empty →
  "Car"/"Summer"/"mixed"; 0.76: a trip by "Car" — every ordinary trip, old ones included — opens with Plane
  and RV both off, and keeps "Car" on Save unless a pill is tapped), weather anyway = `trip.weatherOn`; the trip's template ids this screen does
  not offer (a template deleted since, or the sender's templates on a trip someone sent) are noted
  (`unshown`). An undated trip's field says "Add dates"; its grid opens on this month.
- **Still needed** (same words and the same template rule as Create new trip, `needs(flat)`: the trip as
  Save would store it — `edited(&trip, flat)` — asked `Library.templateMissing`; 0.73: none ticked is fine
  when Always packed or the transport kit puts a line on it) is computed on Save; after that it follows the
  template pills, Full trip | Quick, Travelling by, Season, Food and Pack weather gear anyway (not the name field).
- **Season does not follow the dates here** (0.76, decided 13 Oct 2026): a trip's season was picked, or set
  from its first day, when it was made; moving its dates in Trip settings leaves Season as it is — a changed
  range must not quietly swap the winter gear. Season changes only when he taps it.
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
  templates (a Full trip with none is rebuilt from Always packed and the transport kit — the screen asks
  first whether that packs anything, 0.73); `nights = nightsBetween ?? 0`; `entries = regenerated(trip)`; `updatedAt = now`; returns
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
`testATripChecksTheCabinAndTheDatesBeforeYouGo` (Car via Trip settings removes cabin checks — since 0.76 the lit
Plane `tripset-transport-1` tapped off, `unselect`); 0.76: `testTravellingByIsPlaneOrRVOrNeither` (RV shown, tapped off
and saved → the camper things go; a "Car" trip opens with both off), `testSeasonFollowsTheFirstDayUntilHePicksOne`
(new dates here leave the season), `testMoreChoicesFoldSeasonFoodAndLaundry` (no fold here); 0.67:
`testFullTripOrQuickIsChosenUnderTheName` (Quick shown; Full trip saved brings the common base, 0/4 → 0/7),
`testDatesAreAlwaysThereAndCanBeCleared` (no `tripset-dates` switch; dates given and saved; Clear dates and
saved → "No dates"), `testEachWorkoutHasItsOwnContext` (each workout's picks shown; Swim changed alone);
0.73: `testAlwaysPackedAloneMakesATrip` (Hiking unticked and saved → rebuilt to the Common base alone, 0/7 → 0/4).
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

### What is on screen (at the bottom of Trip settings — only Clear every tick comes after it, since 0.79)
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
`homeNote` (and since 0.75 the charge ticks `charged` and `kitCharged`, spec 07 part 15) removed — and no trip
key but `laundryNights` is copied, so the flights and stay and the bag-tag numbers (0.80) stay behind (0.62: a copied bought-on-site mark made the new trip stand at On site at once);
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
- A trip is still ahead when the Trips tab does not put it in Done (`Library.tripWhen(…) != .been`, 0.73 —
  one rule): not reviewed (`Library.isReviewed`) AND (undated, or its start after today, or its end — the
  start when no end — ≥ today). (Until 0.73 its own copy of the rule; the one difference: a start after
  today with an end before it — broken dates — was not ahead here.) `today` defaults to `Library.localToday()`, the date in the device's time zone
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

## Before you start (`BeforeYouStart.swift` screens; `PackingLibrary/BeforeYouStart.swift`)

**Purpose and origin.** His words of 14 Oct 2026, from his own packing walk-through: "Think if there is anything I
need to buy or prepare well in advance." ONE door, first in the scroll area (item 0 above), on a trip that is not
being packed yet, to a sheet that gathers what was in three places: **To buy** (the trip's things on To buy, needing
replacing, running out before he is home, used up the last time they went), **To prepare** (the trip's reminders and
Preparations lines that fall due before the day he leaves, and the To dos written on the trip) and **To charge** (the
names of the things with a battery not charged yet). Every rule, word and id: **spec 07 part 19**.

**How it is reached and left.** The door (`trip-beforestart`, a button; value "2 to buy · 3 to prepare · 4 to
charge") shows while `Library.beforeStartTime` holds — the loop step, on the screen's clock, Plan or Pack, and
nothing packed yet (`hasStartedPacking`: a reminder, a trip To do, a Preparations line, ⊘ and a charge tick are not
packing; something ticked inside a kit is) — and one part has something. Not on a place's view. A tap opens
`BeforeYouStartSheet` (`beforestart-sheet`; Done / Escape closes it). The door goes with the first thing packed — the
trip's own tick, a heading's round tick, Pack by voice, a kit's inside ticks — and comes back when it is unticked.
Before you go, under it, is unchanged: a reminder due or a date running out shows in both (in the sheet as
something to buy or prepare ahead, in Before you go as something that needs him now).

**Tests.** Model `BeforeYouStartTests` (5), UI `testBeforeYouStartGathersWhatToBuyAndGetReadyUntilPackingBegins`
(`-uiTestingBeforeStart`) — spec 07 part 19, "Tests". `testATripsRemindersShowWhenTheyAreDue` reads the countdown's
value from its start since 0.82 ("1 to do", then Before you start's line).

---

## Before you go (`TripChecks.swift` + `ToCharge.swift` screens; `PackingLibrary/BeforeYouGo.swift`, `TripChecks.swift`, `Countdown.swift`, `Batteries.swift`)

**Purpose and origin.** ONE card at the top of the trip for everything to see to before leaving — 0.77, his yes of
13 Oct 2026 (a picture approved): until then two cards stood there, **Check before you go** (0.48) and **To charge**
(0.75), one under the other. Now they are the three PARTS of one card, in this order, each shown only when it has
something, and each by exactly the rules it had as a card of its own:
1. **The flags** — his pre-trip ideas 4 and 5 (2 Oct 2026, 0.48): on a plane trip, what in a CABIN bag the airport
   stops (not allowed on board; liquids); since 0.76 (his yes of 13 Oct 2026, spec 07 part 15 rule 8) a thing with a
   BATTERY in a CHECKED bag — airlines want lithium batteries and power banks in the cabin; and what runs out before
   he is home — a document (passport, ID card) within six months of coming home. "Colour is the message: red will
   stop him; orange wants a look."
2. **To do** — his reminders whose step has come (0.70, spec 07 part 12), with the icons of the templates they come
   from (0.75).
3. **To charge** — his ask of 13 Oct 2026: "Add a tick box for each item: Contains battery. And maybe implement a view
   where I can check all items that need charging." The whole design, its rules and keys: spec 07 part 15.

**How it is reached and left.** First card in the trip's scroll area (item 1 above), above the weather, only while
one of its parts has something (`BeforeYouGo.isEmpty` false). Not when the trip was opened from a place's code (the
page shows only that place's lines, as for the other cards). A flag opens the thing's editor as a sheet
(`ThingEditor`, Care spec) and goes as soon as it is put right; a reminder ticked leaves the card; a thing charged
stays, ticked. The card goes when the last part is empty.

### The model — `Library.beforeYouGo(tripId:today:)` → `BeforeYouGo`
`today` is the YYYY-MM-DD in his time zone (`Today.local`). The four lists, each from the function the part always
used: `cabin` = `cabinCheck(tripId:)`, `dates` = `dateCheck(tripId:todayISO:)`, `due` = `dueReminders(tripId:today:)`,
`charge` = `chargeCard(tripId:today:)` (all rows, charged or not; [] outside its days). Then:
- `left` = every flag (cabin + dates — each stays until put right) + every reminder due (a ticked one is not due) +
  every row of To charge NOT charged.
- `isEmpty` = all four lists empty → no card. `allSet` = not empty and `left` 0 — which only To charge can reach
  (every thing charged; flags and reminders due are always "left").
- `red` = any flag that is red (`CabinFlag.isRed`: not allowed, battery — a liquid is not; `DateFlag.isRed`: already
  out of date or running out before home — a document short of six months is not).
- `tone` = red if `red`, else orange while `left` > 0, else green. `countWords` = "<left>", or "All set".

### What is on screen
Card (padding 14 — folded, 6 above and below, so its one line is about as slim as the Bags card's; corner 12,
`Theme.card`, 1.2 pt border in the card's tone), id **`trip-beforego`** (a container).
The tone's colours: red `AppSection.actions.color`, orange `AppSection.care.color`, green `AppSection.events.color`.

**The header** (one line, 8 apart): "Before you go" (Subheadline semibold ink) and ONE count capsule — `countWords`
(Footnote semibold, monospaced digits, white on the tone; padding 8 × 2), id **`trip-beforego-count`**, label "<n>
left" or "All set". (Until 0.77 Check before you go had "Check before you go" and a capsule `trip-checks-count`;
To charge had the battery mark, "To charge" and "<charged> of <all>" in its own capsule, `trip-charge-count`.)

**All set — folded** (decided by the build, 0.77): with nothing left the card shows ONLY its header, green — "Before
you go [All set]" — so a trip whose things are all charged does not keep a list of struck-through rows at its top
through the days of the trip. At the header's right, only then, a drawn chevron (22 pt in a `Metrics.tap` square,
muted; right when folded, down when open, as Care's sections), id **`trip-beforego-fold`**, label "Show what is
charged" / "Fold", value "folded" / "open". A press on it — or anywhere on the header line — opens the card and
shows To charge with its ticks (to take one back); a second press folds it again. Open is not kept: the trip opens
folded each time (`@State`). With something left there is no chevron and the header does nothing; a charge taken
back while open makes something left again, and the card simply stays open.

**The parts**, under the header, each its own container (`.contain`), with a hairline (`Theme.line`, 1 pt, 2 above
and below) between two parts that both show:

1. **The flags** — id **`trip-beforego-part-flags`**, no heading of their own (they explain themselves). One button
   per flag (min height `Metrics.tap`): a drawn icon 22 pt in the line's tint (the plane icon for cabin lines; the
   drawn battery mark `ToChargeCard.battery` for a battery in the hold, 0.76; the passport icon for documents; a
   drawn hourglass, `TripChecksCard.hourglass`, for other dates), the line's name (Callout semibold ink), the reason
   (Subheadline, tint, wraps) and a chevron when there is a thing to open. The line's tint: red
   (`AppSection.actions.color`) or orange (`AppSection.care.color`). Ids: cabin lines **`trip-check-cabin-<n>`** first
   (not allowed, then batteries, then liquids), then date lines **`trip-check-date-<n>`** (the ids they had).
2. **To do** — id **`trip-beforego-part-todo`**: the heading "To do" (Footnote semibold muted, header trait), then one
   row per reminder due, **`trip-check-todo-<n>`** (the id it had): a tick circle 22 pt in the trip's green, the name
   (Callout semibold ink) and under it the step it belongs to (Subheadline green) — "A week ahead" (until 0.77 "To do ·
   A week ahead": the part's heading says it now); a To do written on the trip (Packing Stations' Remind me and Add a
   reminder, 0.81) says **"Added on the trip"** there instead (`Library.addedOnTheTrip`). A press ticks the line — on the trip's list too, it is the same
   line — and it leaves the card. Label "<name>, to do. Tick it".
   **Where a reminder comes from** (0.75, his yes of 13 Oct 2026 — he "could not tell which template each comes
   from"): at the right of each reminder due, the icons of the templates it comes from, exactly as on the trip's
   lines ("A line" → "Where it comes from"): `TemplateMarks`, read from `Library.lineTemplates(tripId:)` (asked only
   when a reminder is due) — small, in the Templates violet (15 pt on the iPhone, 12 on the Mac), the trip's template
   order, up to three else the first two and "+N", a template without an icon as its name's first word; one element
   for VoiceOver, label "From <names>", value the names, a tooltip on the Mac; id **`trip-check-todo-<n>-from`**. The
   icons sit BESIDE the reminder's button (an `HStack`, 8 apart), not inside it: the button's own label would swallow
   their "From …" for VoiceOver and on the Mac. A press on the icons does nothing. A reminder whose template is gone
   (or that was typed on the trip) shows none.
3. **To charge** — id **`trip-beforego-part-charge`** (`ToChargePart`): the heading line (6 apart) — the drawn battery
   mark (`ToChargeCard.battery`, 16 pt, hidden from VoiceOver), "To charge" (Footnote semibold muted, header trait), "·"
   (muted) and "<charged> of <all>" (Footnote semibold, monospaced digits; id **`trip-charge-count`**, label "<charged>
   of <all> charged"). The mark and the count orange while anything is left to charge, green once all are. Then one
   button per thing, in the trip's order (**`trip-charge-<n>`**, min height `Metrics.tap`): a `TickCircle` (22 pt;
   orange, filled with a white tick when charged; a `Theme.line` ring otherwise), the name (Callout semibold; ink, or
   muted and struck through when charged) and, for a thing inside a kit, "In the <kit>" under it (Subheadline muted).
   Accessibility: label "<name>" or "<name>, in the <kit>"; value "charged" / "not charged"; selected trait when
   charged.

Reasons of the flags (`TripChecksCard.says`), dates as "3 Mar 2027" (fixed English months, `TripChecksCard.day`):
- not allowed (red): "Not allowed in the cabin · in <bag>"
- a battery in a checked bag (red, 0.76): "Battery: carry it in the cabin · in <bag>" — for a thing inside a kit the
  name says the kit ("Power bank, in the Camp pouch") and <bag> is the kit's bag
- liquid (orange): "Liquid: 100 ml at most, in the clear bag · in <bag>"
- out of date already (red): "Out of date since <day>"
- runs out before home (red): "Runs out <day>, before you are home"
- document short of six months (orange): "Valid until <day>: less than 6 months after you are home"

### Behaviour — the flags
- **Cabin** (`cabinCheck`): only when `transport == "Plane"` (Quick trips too — Quick drops the
  transport kit, not the transport). Lines: not reminders, not set aside, IN A BAG (`Library.inABag`: the
  bag is not blank and not "Other"; a line in no bag yet is never judged). Judged by the THING as it is
  now (`thingNow`: the catalogue item with the line's `sourceItemId`, else the line), and by each thing
  inside a kit line as it is now (`insideLines`, not taken out, in the kit's bag). In a cabin bag:
  restricted → not allowed; else liquid → liquid. In any other bag — a CHECKED bag (0.76) — only a
  battery (`BATTERY_KEY`, spec 07 part 15) → battery; the hold takes knives and liquids. All "not
  allowed" first, then the batteries, then the liquids, each in list order. Any "not allowed" or battery
  line makes the card red.
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

### Behaviour — To do
- `dueReminders`: the trip's reminder lines, not ticked, not set aside, whose step's day — the trip's start less the
  step's lead days — is today or past; in the timeline's order, then the trip's. A trip without a start date has none
  due. (Spec 07 part 12.) Then (0.81) every To do written on the trip itself (`tripTodo`, Packing Stations' Remind me
  and Add a reminder) not ticked nor set aside — due at once, whatever its When or the trip's dates, in the order
  written (spec 07 part 17, "0.81"). Until 0.77 a card holding only reminders was the trip's green; now it is orange like
  anything else left — green means All set.

### Behaviour — To charge
- **When it shows** (`Library.chargeCard(tripId:today:)` has rows): the trip is not reviewed; today is from the day
  before its start through its end (the end = the start when blank; no start date = always); something on it has a
  battery.
- A tap: `Library.setCharged(_:tripId:lineId:contentId:)` — the line's `charged`, or the content's id in the kit
  line's `kitCharged` — one line record. Nothing else changes: the line is not ticked, the trip's count stays.
- Rows (`Library.toCharge(tripId:)`): lines not set aside and not reminders whose thing as it is now has a battery;
  for a kit line, the kit as it is now — its own row first when it has a battery, then each thing inside it (not
  taken out) that has one; each thing once. A thing switched on or off on its page shows or goes at once.
- Kept by a rebuild and by `followThing`; dropped by Start a new trip from this one and in a shared trip (above).

### Tests
Model `BeforeYouGoTests.testOneCardHoldsTheFlagsTheRemindersDueAndToChargeAndCountsWhatIsLeft` (0.77; the batteries'
library, Hiking with a reminder a week ahead and one the day before, a trip 20–22 Oct: two weeks ahead no card; a week
ahead one reminder, no To charge, 1 left, orange; the day before two reminders and three things to charge, 5 left; one
ticked and two charged, 2 left; all done, "All set", green, still shown; by plane with the pouch in the hold, a battery
flag, red, 1 left; a passport short of six months, orange; after the trip no To charge; nothing at all, no card). Seen
RED with charged things counted as left: "("4") is not equal to ("2") - charged things are counted as left".
The flags: model `TripChecksTests` (8: cabin bags only, the thing as it is now, a bag's own word, a bag name on the
trip, a Quick trip by plane, dates + six months, `ymd(plusMonths:)` incl. 31 Aug → 28 Feb and leap
years; since 0.76 a battery in a checked bag). To charge: model `BatteriesTests`. To do: spec 07, part 12, Tests
(`TemplateRemindersTests`).
UI `testBeforeYouGoIsOneCardWithItsPartsInOrder` (0.77; `-uiTestingBattery -batteryByPlane -batteryToDo`: the power
bank in the hold, Hiking's "Check the forecast" due, the toothbrush and the power bank to charge): the three parts
`trip-beforego-part-flags`, `-todo`, `-charge` top to bottom, no `trip-checks` or `trip-charge` card, the count "4";
the reminder ticked → To do goes, "3"; both charged → "1", still open, no chevron; the power bank's battery switched
off from its flag → no flags, "All set", folded (no To charge part), the card still there; `trip-beforego-fold` opens
it, "1 of 1"; the toothbrush's charge taken back → "1", no chevron. Pictures `beforego-trip`, `beforego-allset`,
`beforego-allset-open`, iPhone day and night; on GitHub's Mac (a probe running just this test,
`testToChargeIsTickedApartFromPacking`, `testATripChecksTheCabinAndTheDatesBeforeYouGo`,
`testABatteryInACheckedBagIsToldToGoInTheCabin`, `testATripsRemindersShowWhenTheyAreDue`,
`testABatterySwitchOnAThingPutsItOnTheTripsToCharge` and `testABagSaysWhetherItGoesInTheCabin`): all seven green, with
the pictures of the Mac look (day). Seen RED twice: To charge drawn above To do → "the parts are not flags,
To do, To charge, top to bottom: [251.99999999999997, 441.0, 327.5]"; the card never folding → "all set, the card did not fold".
`testATripChecksTheCabinAndTheDatesBeforeYouGo` (order knife, sun cream; dates sun cream, passport; the count "4";
Liquid off removes one; clearing the passport's date removes it; Car removes cabin checks),
`testABagSaysWhetherItGoesInTheCabin`, `testABagOnTheTripSaysWhetherItGoesInTheCabin`. A battery in the hold (0.76):
UI `testABatteryInACheckedBagIsToldToGoInTheCabin` (`-uiTestingBattery -batteryByPlane`; switched off, the FLAGS part
goes — the card stays for To charge) — spec 07 part 15, Tests. To charge: UI
`testABatterySwitchOnAThingPutsItOnTheTripsToCharge`, `testToChargeIsTickedApartFromPacking` (since 0.77 the last one
charged makes the card "All set" and folds it — `trip-beforego-part-charge` goes; the chevron opens it, "2 of 2";
picture `trip-beforego-allset`) — spec 07 part 15, "Tests". To do: `testATripsRemindersShowWhenTheyAreDue`
(`trip-beforego-part-todo`; ticked, the whole card goes) — spec 07 part 12.

---

## The weather card (`WeatherCard.swift`, `Store/Forecast.swift`, `ForecastAsk.swift`, `TripWeather.swift`, `PackingCore/Weather.swift`)

**Purpose and origin.** "The weather on a trip: one line of what it will be like, and under it the
gear that weather calls for which is not on the trip yet — each with one press to take it along"
(0.4). Add all (0.36). A place without a forecast still reaches the map (his G.6, 0.40). Open-Meteo,
"the same two calls the web app makes". A trip past the forecast's reach is not asked at all and the card says when
its forecast comes (0.75).

### What is on screen (card, padding 12, corner 12, id `weather-card`)
**Without a forecast:** a field "Where is this trip?" (16 medium; prefilled with the trip's
`destination`; Return looks it up), id `weather-place`; **Weather** (15 bold white on green; "Looking…"
while busy), id `weather-look`, never disabled; after a press with a blank field "Type a place first."
(15 bold red, id `weather-look-needs`, goes when typing).
A look (Weather or Return) first puts the keyboard away (`@FocusState typing = false`): the field leaves the
card when the forecast arrives, and leaving with the keyboard still up froze the iPhone on "Looking…" (iOS 26.5;
`testTheWeatherSaysWhatItWillBeLikeAndWhatIsMissing` timed out — found at the 0.68–0.71 merge, already in 0.67).
**No forecast yet** (0.75; under the field, Footnote semibold muted, wraps, id `weather-notyet`): "No forecast yet — it
comes about 15 days before the trip (from 29 Oct 2026)." (`WeatherCard.notYet(from:)`; "15" is
`ForecastAsk.reachDays`; the date = the trip's start − 15 days, `ForecastAsk.comesFrom`, in the app's date words
`TripChecksCard.day`, "3 Oct 2026"). Shown while the card holds no forecast, the trip has a place (`destination` not
blank — kept by a Weather press or typed in Trip settings) and it starts past the service's last day (below). Read
from the trip each time the card is drawn — memory holds nothing — so it goes by itself once the dates move into
reach, or 15 days before the trip. A trip with no place yet shows nothing (nothing was asked).

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

**Trouble** (either state; 14 semibold red, id `weather-trouble`; `ForecastTrouble` in PackingLibrary, all four words
model-tested): "No place found for “<name>”." / "Could not reach the weather service — check the connection." (no
answer at all, only) / "No forecast for those dates yet." / "The weather service could not answer just now — try
again later." (0.73)

### Behaviour
- **Looking up** (`LibraryModel.lookUpWeather`): name = trimmed typed place (or the trip's); blank or
  already busy for this trip → nothing. Clears trouble; (1) geocode → keeps the place AT ONCE: trip
  `destination` = the typed name, `geo` = the service's spot and label (map pin) — even if no forecast
  follows; (1b, 0.75) a trip that starts PAST the service's last day (`ForecastAsk.comesFrom` not nil) stops here:
  no forecast is asked for, and a forecast the trip still holds is let go (`Library.dropWeather`: `weather` = nil,
  `updatedAt` stamped, place and pin kept; nothing written when it holds none) — one held there can only be of
  other days; the card then says when the forecast comes (above). (2) forecast for the trip's start and nights →
  `setWeather` (destination = place, weather = snapshot, geo with the snapshot's place). Any error → the trouble
  line. Weather, Return and Look again all look up this way.
- **Open-Meteo** (`OpenMeteo`): geocoding `…/v1/search?name=<n>&count=1&language=en&format=json`; label
  "<name>, <country_code>". Forecast `…/v1/forecast?latitude&longitude&timezone=auto&daily=weathercode,
  temperature_2m_max,temperature_2m_min,precipitation_probability_max,windspeed_10m_max`. The days asked
  for (`ForecastAsk.days`, pure, model-tested): the service forecasts today and the 15 days after it
  (`ForecastAsk.reachDays = 15`) — its LAST DAY (`ForecastAsk.lastDay`) is 15 days after the earlier of the
  phone's date (`Today.local`) and the UTC date (`todayYMD()`), because the service's "today" is the UTC date wherever
  the place is (same last day at UTC−10, 0 and +14, checked 12 Oct 2026) and in Sweden the phone's date is a
  day ahead of it from midnight to 01:00 (02:00 in summer). When the trip starts between the phone's today
  and that last day, `start_date` = start and `end_date` = start + nights, cut at the last day. A trip that
  started already, or has NO dates, is asked with no dates — the service's default days, today on, as the web app
  does: for an undated trip today's weather where it goes is the best there is (decided 13 Oct 2026, 0.75). A trip
  that starts PAST the last day is never asked (0.75, `ForecastAsk.comesFrom`: start − 15 days when the start is
  after the last day, else nil — an undated, a running or a past trip included): `lookUpWeather` stops after the
  place, and `OpenMeteo.forecast` refuses such a trip itself as a second lock (`ForecastTrouble.nothingYet`, never
  sent to the service). Until 0.75 it was asked with no dates, the service answered with THIS week, and the card
  showed this week's weather as the trip's (his report, 13 Oct 2026). A trip already over still gets the default
  days if he presses Weather (open question below).
- **What an answer means** (`ForecastAsk.trouble`, pure, model-tested): no answer at all (the request
  throws) → offline, "check the connection" — the ONLY case. An answer with HTTP ≥ 400 is never offline: its
  `{"error": true, "reason": …}` saying "out of allowed range" for `start_date`/`end_date` → "No forecast for
  those dates yet."; any other (400 of another kind, 429, 5xx, an unreadable body) → "The weather service
  could not answer just now — try again later." A 2xx answer that is not JSON → the same. The service's own
  reason is never shown (his rule: no computer talk). No days in a forecast → "No forecast for those dates
  yet."
- 🪤 **0.73, his report 12 Oct 2026** (a trip to Spain about two weeks ahead said "check the connection" with
  a working internet): the reach was 16, so a trip running past it asked for `end_date` = today + 16; the
  service refuses that with HTTP 400 ("Parameter 'end_date' is out of allowed range from … to <today + 15>"),
  and every HTTP ≥ 400 was read as offline. Both fixed. The web app (`js/weather.js`, `MAX_AHEAD_DAYS = 16`,
  "Could not fetch the forecast — check your connection.") still has the same day too many and the same
  words — the native app deliberately differs there.
- **Automatic look-up** (`forecastWorthFetching`, unchanged in 0.75 — it never looked a trip past the reach
  up): the trip has a place AND a start date AND a forecast can
  exist for it (`ForecastAsk.inReach`: it started at most `nights` days before the phone's today, i.e. it is not
  over, and starts no later than the service's last day above — whole civil days) AND the held forecast
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
"Lateville, SE" with no forecast; "nowhere" → not found. The sample's trip is a month ahead — past the reach, so
since 0.75 its card says when the forecast comes and asks for none; the tests that need a forecast launch with
`-uiTestingSoon` (`SampleLibrary.soon()`: the same trip 10 days ahead, two nights).

### Tests
UI `testTheWeatherSaysWhatItWillBeLikeAndWhatIsMissing`, `testWeatherAddAllTakesEverything`,
`testTheMapShowsWhereTheTripsWent` (no-forecast place still on the map) — these three on `-uiTestingSoon` since 0.75 —,
`testATripPastTheForecastsReachSaysWhenItsForecastComes` (0.75: the sample's trip a month ahead, Testville + Return →
`weather-notyet` says "No forecast yet — it comes about 15 days before the trip (from <today + 15>)." exactly, no
`weather-line`, no `weather-trouble`, the field stays; the map then has "1 place · 1 trip", Testville, SE; picture
`weather-not-yet`; seen RED on the iPhone with `comesFrom` planted to answer nil — the 0.74 behaviour — "the card
does not say when the forecast comes: '' — its weather line says 'Rain and cold, 2–8°C'"; the four weather tests green
on the iPhone simulator, light and dark, and on GitHub's Mac, 13 Oct 2026),
`testEveryAddButtonIsReadyAndSaysWhatIsMissing` (`weather-look`). Model `TripWeatherTests` (6: kept and read back, missing gear, staleness incl. a
different place, survives a backup, `testRetiredGearIsNeverOfferedAndTheBasesOwnGearIs`,
`testTwoTripsWithOneIdAreReadAsTheFirst`), `TripBulkTests.testAddAllTakesEveryWeatherSuggestionOnce`,
`testHisOwnWeatherGearKeepsItsSource`, `TripWeatherTests.testAForecastLetGoLeavesThePlaceAndThePin` (0.75,
`dropWeather`: the forecast goes, place and pin stay, `updatedAt` stamped, no gear asked for, nothing written with none
held; seen RED with the forecast kept and with `updatedAt` left), `WeatherTests` (all 19), `ForecastAskTests` (9; 0.75
`testATripPastTheReachIsNotAskedAndSaysWhenItsForecastComes`: a month ahead → start − 15, a day past the reach →
tomorrow, the last day itself / today / under way / long over / undated / not a date → nil, after midnight counted
from the UTC date, and `comesFrom` and `days` never both answer; seen RED with `comesFrom` planted to answer the start
and to answer nil. 0.73's eight: the reach is 15;
a trip starting on the last day / a day past it; a trip running past it is cut; after midnight the reach counts
from the UTC date, west of UTC from the phone's; a trip under way is in reach until its last day; the service
refusing the days → "No forecast for those dates yet."; any other HTTP "no" → the service-trouble words, never
"check the connection"; all four trouble words).
**Not covered:** the staleness half of the automatic look-up as the card appears; "Look again" (on a trip past the
reach it lets a held forecast go — `dropWeather` is model-tested, the press is not); the network
call itself (`OpenMeteo.read` — no real network in tests; its rules are `ForecastAsk`'s, tested); `OpenMeteo`'s own
refusal of a trip past the reach (the second lock: `lookUpWeather` never gets there).

**Open question (0.75).** A trip already OVER (and not under way) still gets the service's default days — this
week's weather — if Weather is pressed (the automatic look-up never asks for it). The service also answers for past
days (`start_date` up to about three months back — its refusal on 12 Oct 2026 named "from 2026-07-11"), so the trip's
own past weather could be asked for instead; or such a trip could say nothing. Not decided.

---

## The Bags card, the luggage scale, the cabin switch and bag photos (`BagsCard.swift`, `BagCabin.swift`, `BagPhoto.swift`, `Weighing.swift`, `OnTheTrip.swift`)

**Purpose and origin.** "How heavy each bag on this trip is, against what it may carry" — the web
app's "Bags & weight" (0.17). Colour key ⓘ (his ask 2026-09-26, 0.25); "no max" (0.25); luggage scale
(his idea 8, 2 Oct 2026, 0.50); one thick bar per bag (their choice 3 Oct 2026, 0.57: "we would like one
bar"); Goes in the cabin on the trip (field test 7.3/6.1, 0.55); photos of the packed bag (idea 11,
0.52) — up to three (field test 3 Oct 2026, 0.56: "sometimes you would like a photo from different
angles").

### What is on screen (card id `bags-card`; corner 12; border red when any bag is over)
**Folded to ONE line by default** (0.74, his ask of 12 Oct 2026: the overview "is good but takes too much space"):
only the header line shows, padding 14 sideways and 6 above and below; a tap on the fold (or anywhere else on the
line) opens the card — padding 14 all round, as before — and a second folds it. Open or folded is remembered on the
device in AppStorage **`ams.trip.bags`** (default folded; the same for every trip; cleared at launch under the
tests, like `ams.view`). Until 0.74 the card was always open.
- Header: the **fold** — a button (id `bags-toggle`; label "Open the bags" / "Fold the bags"; value "folded" /
  "open"): a drawn chevron at `Metrics.glyph` (pointing right when folded, down when open; ink, 2.4 stroke) and
  "Bags" (Subheadline semibold ink), at least 28 tall; then, only while open, ⓘ (a drawn circle with "i", id
  `bags-key-open`, label "What the colours mean") toggling the key; "N over" (Footnote semibold white on a red
  capsule, id `bags-over`) when any bag is over — on the folded line too: it is a warning; at the right the total
  weight of the shown bags (Footnote semibold mono muted, id `bags-total`), folded or not. The badge and the total
  stay texts of their own, outside the fold button (the Mac folds a button's texts into it).
- Everything below — the key and the bag rows — only while open.
- Its bags (`weighedBags`): every bag a line not set aside packs into, in `bagLoads`' order, "Other" ("Not in a
  bag") among them; since 0.81 then every bag Packing Stations' "+ Add a bag" put on the trip that nothing is packed
  in yet — last, in the order added, 0 things ("Tap to weigh"), its limit (spec 07 part 17, "0.81" item 7).
- Key (id `bags-key`): "Blue — well within its max", "Orange — nine tenths of its max or more", "Red,
  “over” — more than its max", and "No bar: no max set. Set one in Care → Bags. Tap a bag for the luggage
  scale, and a photo of it packed."
- One row per bag (a button, id `bag-<n>`, accessibility value = the gauge in words): the name ("Not in a
  bag" for "Other"; 15 semibold); at the right "<weight> / <max> kg", or "<weight> · no max", or only the
  weight for "Not in a bag" (14 bold mono; red when over); weight = "<kilos> weighed" once weighed. Only
  a bag WITH a max has a bar: 16 pt capsule, `Theme.line` track, fill = min(1, kg/max) of the width (at
  least 16 pt) in blue (fine), orange (close) or red (over). Weighed: "The things in it add up to
  <kilos>" (13 medium muted).
- **How the bag looks** (0.80, spec 07 part 18 A rule 10): beside the row, at its left, the bag's own first photo
  (`BagLookThumb`, 32 × 32, corner 6, a button `bag-<n>-look`, label "How the <bag> looks", a tap shows it large) —
  only for one of his bags that has a photo of its own, and only while this trip has no photo of it packed. Beside the
  row, not inside it (a button inside a button never reaches the tree).
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
  4. **Bag-tag no.** (0.80, a plane trip's CHECKED bags only — not a cabin bag, not "Not in a bag",
     `asksBagTag`; spec 07 part 18 B): the label (Footnote semibold
     muted) and a field (monospaced, placeholder "from check-in", capitals; id `bag-<n>-tagno`) for the number on the
     tag the airline put on the bag at check-in — kept on Return, when the field loses focus and when the bag closes
     (`BagTagField`, shared with the Packing day's Tags, where it is `day-tag-<n>-number`).
- A thumbnail opens **BigPhoto** (sheet): "k of N" (15 bold mono muted, id `bag-photo-count`) when
  more than one, a caption when given (17 heavy green, up to 2 lines, `bag-photo-caption`), **Next**
  (outlined, only with more than one, id `bag-photo-next`) and **Done** (filled, id `bag-photo-done`);
  the photo fills the space (scaled to fit); a drag of ≥ 30 pt that is more horizontal than vertical
  steps — leftwards = next, rightwards = previous; it wraps both ways (after the last the first, before
  the first the last). Opening at an index outside the photos clamps it. Mac minimum 520 × 600.
- Thumbnails show only photos whose record is on this device and decodes; "full" (no add pills) counts
  the STORED ids, so a photo still syncing in takes its place.
- **All your bags** (0.79, spec 07 part 17): when the trip has a photo of all its bags together (taken in the Packing
  day's Photos), the opened card's first row is its thumbnail (44 pt, corner 6, id `bags-group-thumb`, label "Photo of
  all your bags") and "All your bags" (Subheadline semibold ink); a tap shows it large (`BigPhoto`). At every step —
  for the airline desk when a bag is lost, after he has left. Taken and removed only in the Packing day.
- The bag rows are ONE view since 0.79 (`BagWeightRow`), shared with the Packing day's Weigh station: the same
  words, bar and colours in both places.
- **Lost bag?** (0.80, spec 07 part 18 C): under each bag's row but "Not in a bag", at the right, a small capsule
  (Footnote semibold green, 1.2-pt green outline, at least 26 tall; id `bag-<n>-lost`) opens that bag's Lost bag page —
  everything a baggage desk asks for, Share as PDF, Copy as text. The card owns the sheet. The key's last line adds
  "Lost bag? under a bag: everything a baggage desk asks for."

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
UI `testTheTripsBagsAreOneFoldedLineUntilOpened` (0.74: `bags-toggle` "folded" at first, no `bag-0`, the total on
the folded line (±1.5), the card at most 48 tall; a tap opens it — `bag-0`, "open" — and a second folds it; pictures
`trip-bags-folded`, `trip-bags-open`; seen red with the card open by default: "the Bags card is not folded to begin
with", "a bag's row shows on the folded card", "the folded card is not one slim line"); every test below opens the
card first (`openBags`); `testABagsLimitReachesTheTrip` reads "N over" on the FOLDED line.
`testABagWithNothingWeighedIsOnTheTrip` (a thing moved to another bag with no weight: that bag is on the
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
0.40). **Each step's own mark (0.77).** The tab marks on the strip (a suitcase, calendars, a list — three steps
alike) looked stock; his ask (13 Oct 2026): "not stock but cool", in the app's own hand. On a sample sheet (three
hand-drawn candidates per step in the real pill, lit and unlit, day and night, branch `work/phaseicons`, never
shipped) he picked **Plan A, Pack A, On site C, Review B, Refine C** — the drawings below, unchanged. The tab's
mark stays only on the picture's "on <Tab>" line.

### The five steps and when a trip stands at each — `Library.loopStep(tripId:today:time:)`
Checked in this order:
1. no such trip → **Plan**;
2. `status == "done"` or `reviewedAt` set → **Refine**;
3. its end (end date, else start) is before today → **Review**;
4. no lines → **Plan**;
5. the trip has **set off** (`Library.hasSetOff`, below — on its first day only from the time he leaves, 0.75)
   → **On site**; any trip with something bought on site → **On site**, whatever its dates or the time say
   (0.62: a dated trip still ahead stayed at Pack while its On site door showed; the door and the loop now go
   by one rule);
6. otherwise → **Pack** (ticked or not, until it sets off).

### When a trip sets off — the time he leaves (0.75, `Library.hasSetOff(trip, today:time:)`)

His report (13 Oct 2026): at 07:30 on the first day, with "I leave at 08:00", the trip already stood at On
site — until 0.75 the loop went by the date alone. Now "now" is a day AND a time of day (this device's local
clock), and a trip has set off:
- **before its first day**: no; **on a later day**: yes (also after the trip — the On site door stays);
- **on its first day**: from the time he leaves on the first day (`extra.leaveAt`, "HH:mm", read with
  `Library.leaveTime`), the minute itself included — at 08:00 with "08:00" it has set off; with no time set,
  from the start of the day (as before 0.75);
- **without a valid start date**: never by the clock (something bought on site still says he is there).

The model takes now as `today` ("YYYY-MM-DD") and `time` ("HH:mm"). `time` defaults to `END_OF_DAY` ("23:59"),
so a caller that gives only the day sees what the loop always said (on the first day: set off); a time that is
not one (`Library.cleanTime` refuses it) counts as the end of the day too. `loopStep` and `onSiteBegun` both
take `time` with that default; the trip screen passes its clock's.

**Which places go by the time, and which by the date** (decided one by one, 0.75):

| Place | Goes by | Why |
|---|---|---|
| The loop strip on a trip (`LoopDoor`, `loopStep`) and the picture it opens | the time | it says "On site" |
| The On site door on the trip (`onSiteBegun`) | the time | it is On site; the door and the loop keep one rule (0.62) |
| The Trips tab's piles (`tripWhen`): **Now** | the date | the trip IS today: on its first day it is in Now all day, before and after he leaves — "Now" is not "On site" |
| A trip row's when-line ("Today", "in 3 days") | the date | it counts days |
| Home's countdown (`nextTrip`) and "Open my next trip" | the date | it counts to the day: on the first day it says Today all day — the quickest way into the trip on the day he travels |
| Packing reminders (`reminderPlan`) and reminders due (`dueReminders`) | the date | a step falls due on a day |
| A place's code (`placeVisit`) | the date | a trip starting today is still being packed; a code is scanned at home |
| Where is my …? (`tripUnderWay`: Search's where card, Siri) | the date | on the morning he leaves, the trip's lines say where he has just packed a thing — what he asks then |
| The door check (`doorChecks`) | the time, already | the way-out check comes 15 minutes before the time he leaves, while the trip is still at Pack; unchanged |
| The weather card ("in reach until its last day") | the date | a forecast is by day |
| Pack by voice | neither | it walks the list, whatever the day |

**Turning while the trip is open.** The trip screen reads the step and the door from a clock it keeps
(`TripScreen.clock`, read when the trip opens). It wakes itself at the next moment the step turns by the clock
alone — `Library.clockTurns(trip)`: the moment it sets off ("<first day> <time he leaves>", else "<first day>
00:00") and the day after its last at 00:00 (→ Review); for a reviewed or undated trip none — the first one
still ahead of the clock: ONE sleeping task (`.task(id:)` on that moment, `Task.sleep` on the continuous clock,
so a device that slept past it wakes it at once), then the clock is read again and the next moment taken. The
clock is also read again whenever the app comes back to the front (`scenePhase` → active). A new time saved in
Trip settings moves the wake to the new moment; a moment already passed wakes it at once. So a trip left open
at 07:59 stands at On site, with its On site door, at 08:00. Nothing else on the screen changes with it.

**For the UI tests** (`-clockAt HH:mm:ss`, only under a `-uiTesting…` mode): the app's clock (`Today.now`) is
today at that time when the app opened and runs on from there; `Today.local`, `Today.time` and the trip screen's
clock read it. `-uiTestingLeaving`: the sample trip starts today, ends in two days, "I leave at" 08:00 on the
first day.

| Step | rawValue | Name | About | Tab mark | Short words | Explained |
|---|---|---|---|---|---|---|
| plan | 0 | Plan | lists (violet) | Home | "Make templates, create a trip" | "Your templates hold what each kind of trip needs. A new trip gathers what its templates hold." |
| pack | 1 | Pack | one trip (green) | Trips | "Tick things as they go in" | "Tick each thing as it goes in. The count says when nothing is left." |
| onSite | 2 | On site | one trip | Trips | "Bought, left, notes, and packing for home" | "While you are away: what you bought, what you left on site, a note on a thing that needs care, and packing to go home. It opens on the trip once the trip has begun." |
| review | 3 | Review | one trip | Trips | "After it: unused, missed" | "After the trip: tap what you did not use, add what you missed. This looks back at one trip." |
| refine | 4 | Refine | lists | Templates | "Keep or drop, from reviews" | "When two or more reviews agree, Refine offers to take a thing off a template — or keep it for good. Your templates get better, and the next trip starts from them." |

### Each step's own mark — `Library.LoopStep.mark` (`PackingLibrary/Loop.swift`, 0.77)
A `LoopStepMark` (`key`, `label`, `path`): SVG path data on the 24-point grid, drawn by `StepMark(step, size)`
(`Screens/Loop.swift`) through `IconMark` — ONE stroke 1.9 × size/24, round caps and joins, no fill, in the colour
around it (white on the lit pill, the readable tint elsewhere). Never an SF Symbol or emoji, never the tab's mark.
As data in the model, like the template icons, so the model's tests hold each step to his pick.

| Step | key | label (VoiceOver, tests) | The drawing | path |
|---|---|---|---|---|
| Plan | `routeMap` | "A map with a route to an X" | a sketch map (the Map template icon's outline), three dots of a route, an X | `M3.5 6.5 9 4.5l6 2 5.5-2v13l-5.5 2-6-2-5.5 2Z M6.6 15.6h.01 M9.4 14.1h.01 M12.3 13h.01 M14.3 8.6l3 3 M17.3 8.6l-3 3` |
| Pack | `packedCase` | "A suitcase with a tick" | Home's suitcase without its two straps, a tick on it | `M6.2 7.5h11.6a2.2 2.2 0 0 1 2.2 2.2v8.1a2.2 2.2 0 0 1-2.2 2.2H6.2A2.2 2.2 0 0 1 4 17.8V9.7a2.2 2.2 0 0 1 2.2-2.2Z M9 7.5V5.6A1.6 1.6 0 0 1 10.6 4h2.8A1.6 1.6 0 0 1 15 5.6V7.5 M8.8 13.9l2.2 2.2 4.2-4.4` |
| On site | `pinOnMap` | "A pin on a folded map" | the trip map's pin standing on a folded map | `M3 17.5 8 16l8 2 5-1.5v3.5l-5 1.5-8-2-5 1.5Z M12 15s-4.6-4.2-4.6-7.8a4.6 4.6 0 0 1 9.2 0c0 3.6-4.6 7.8-4.6 7.8Z M12 5.9a1.3 1.3 0 1 0 0 2.6a1.3 1.3 0 1 0 0-2.6` |
| Review | `listLens` | "A magnifier over a list" | three lines getting shorter, a magnifier over the short ones | `M3.5 6h11 M3.5 10.5h6.5 M3.5 15h4.5 M11.5 14a4 4 0 1 0 8 0a4 4 0 1 0 -8 0 M18.4 16.9l2.6 2.6` |
| Refine | `sprout` | "A sprout" | a stem, two leaves, a line of ground — the templates grow better, trip after trip | `M12 20.5V11.2 M12 11.2c0-3.6 2.6-6 7-6 0 3.6-2.6 6-7 6Z M12 14.5c0-2.9-2.1-4.8-5.6-4.8 0 2.9 2.1 4.8 5.6 4.8Z M7.5 20.5h9` |

Where a step's mark is shown: the strip (13 pt) and the picture (17 pt, before "n · Name") — the trip, its review,
Refine, the loop screen and How it works. Home shows no step of the loop (its countdown's "step" is a packing step,
spec 02). The unchosen candidates and the sample sheet are not in the app.

### The strip (`LoopDoor`)
A button (ids: `trip-loop` on a trip, `review-loop` on the review — always Review — and `refine-loop`
on Refine — always Refine; label "The loop", value = the step's name) showing the five names with
small drawn chevrons between them. The current step: white heavy words on a capsule in its tint, with
the step's own mark (`StepMark`, 13 pt; until 0.77 the tab's mark); the others: semibold words in the readable tint on a `Theme.card` capsule with a 70 %
tint outline (min height 28). It slims down until it fits (`ViewThatFits`): every mark, 14 pt, padding
8, chevron room 14; then only the current step's mark, 14 pt, padding 7, 10; then 13 pt, padding 5, 8.
A tap opens **LoopScreen** (sheet: "The loop" 22 heavy, Done filled green id `loop-done`, the picture
and the words; id `loop-screen`; Mac minimum 520 × 640).

### The picture (`LoopPicture`, also on How it works as `guide-loop`)
Two boxes per row: Plan → Pack on top; down the right side Pack ↓ On site ↓ Review; Refine ← Review at
the bottom; one long arrow up the left from Refine to Plan; a key "About your templates" / "About one
trip". Each box (id `loop-step-<n>`): the step's own mark (0.77, `StepMark`, 17 pt, readable tint, 5 pt before
the name) and "n · Name" (18 heavy, readable tint), the short words (14 medium
ink), the tab mark + "on <Tab>" (13 bold, tab colour), and "You are here" (13 heavy white on the tint)
on the trip's step; fill 24 %/12 % tint, border 3/1.2 pt. Accessibility label "Name: short, on Tab"
plus ". You are here" (the Mac drops a non-control's value). The box is ONE element (`children: .ignore`), so its
mark is drawn from outside it: the title row holds a clear 17-pt spot (`anchorPreference`, key `MarkSpot`) and the
box, after its accessibility modifiers, lays the mark over that spot (`overlayPreferenceValue`) — an element of its
own, id `loop-step-<n>-mark`, label = the mark's `label` ("A sprout"). The strip is one button: its marks are no
elements. `LoopWords`: each name (16 heavy, 72 pt
column) with its explanation (16), then "Review looks back at one trip. Refine uses several reviews to
make your templates better." (16 bold).

### Tests
Model `LoopTests` (6: every case above incl. a one-day trip, empty trips, undated; bought on site
begins a trip, dated or not; names/order/aboutOneTrip; 0.77's `testEachStepHasTheMarkHePicked` — the five keys
and labels in order, five different paths, each drawable (`TemplateIconTests.drawingFault`: only M L H V C S Q A Z,
inside the box), and each drawing's tell-tale stroke (Plan's X, Pack's tick and no straps, On site's map, Review's
handle, Refine's ground); red with Plan's unchosen candidate B planted: "XCTAssertTrue failed - Plan's route does
not end in an X"; and 0.75's
`testOnItsFirstDayATripIsOnSiteOnlyFromTheTimeHeLeaves` — 07:30/07:59 Pack and 08:00 On site with "I leave at
08:00", the door alike, the day before and the second day, just after midnight with 00:10, no time = from the
day, the day alone or an unreadable time = the end of it, bought on site at 07:30 = On site, undated never;
`testATripTurnsByTheClockAtTheMomentsItSays` — the set-off and Review moments with and without a time, a
one-day trip, none undated or reviewed, and the step really turning at each). Red with the date alone
planted in `hasSetOff`: "XCTAssertEqual failed: ("onSite") is not equal to ("pack") - 07:30 on the first day,
leaving at 08:00"; with the minute itself excluded: "("pack") is not equal to ("onSite") - the minute he leaves
is not On site"; with the turn at 00:00 whatever the time: "… - the time he leaves is not the turn".
UI `testTheLoopShowsWhereATripStands` (five
steps, labels with tabs, no "You are here" in the guide, trip at Pack or Review, the picture marks it,
review at Review, after saving the review the trip is at Refine, Refine at Refine; since 0.77 each step's
`loop-step-<n>-mark` says its mark's label, in the guide's picture and in the one the strip opens — red with the
tab marks planted back (main's `Loop.swift`): "XCTAssertEqual failed: ("no mark of its own") is not equal to ("A map
with a route to an X") - the guide's picture: step 1 does not wear the mark he picked"; shots `loop-review` and
`loop-refine` show those strips),
`testATripUnderWayStandsAtOnSite` (strip fits the screen width), `testATripIsOnSiteOnlyFromTheTimeHeLeaves`
(0.75, `-uiTestingLeaving -clockAt 07:59:30`: the trip leaving today at 08:00 is at Pack with no `trip-onsite`
— checked only when the trip opened within 25 s of launch, so a slow runner cannot make it lie — and, left
open, at On site with its door once 08:00 has passed, within 60 s; about 40 s. Red with the step read by the
day alone: "XCTAssertEqual failed: ("On site") is not equal to ("Pack") - at 07:59, leaving at 08:00, the trip
is at 'On site'"; with the wake taken out: "08:00 passed and the open trip is at 'Pack'").

---

## On site (`OnSiteScreen.swift`, `OnSite.swift`)

**Purpose and origin.** The step after Pack (field test 3 Oct 2026, mission 9.1, 0.57): "During this
phase, we could add stuff as: items bought there; items discarded there (not more needed); maintenance
or other actions." He chose that it holds all four: Bought on site · Left on site · Maintenance notes ·
Pack to go home. Nothing new is stored on the trip; a maintenance note ALSO lands on the thing, dated,
for Care.

**How it is reached and left.** The **On site door** on the trip screen (after the Bags card): shown
when `onSiteBegun(tripId:today:time:)` — the trip has set off (`hasSetOff`, "When a trip sets off" above: a
valid start date, today after it, or on the first day from the time he leaves — since 0.75; until then from the
day alone) and it then stays for good, also after the trip — OR any line is bought on site, whatever the dates
or the time say: buying on site says he is there. The loop's On site step goes by the same rule since 0.62 (a
dated trip still ahead with something bought on site showed this door while the loop said Pack), and both read
the trip screen's one clock, so they turn together while the trip is open. The door: "On site" (17 heavy) over the summary (14
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
since 0.57. **0.79:** Tick everything / Clear the ticks is gone — his decision of 13 Oct 2026 on the trip's two
("two very risky buttons — in a stressful situation half way packed, pressed by mistake: catastrophe") holds here
too: this one, pressed again, cleared every home tick without asking. The bag headings here are words only, with
no round tick, so there is no Undo to offer (decided by the build); each line is ticked by hand.

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
- *(Until 0.79, at the end, only when not searching and there was something to bring home: **Tick everything**
  (16 bold white on green with a drawn 22 pt tick, min height 52) — or **Clear the ticks** (16 bold ink, 1.4 pt
  `Theme.line` outline) once all were packed — one id `wayhome-tickall` for both. Removed, see above; nothing
  follows the last line now.)*

### Behaviour (model)
- `homeLines` = lines ticked on the way out and not set aside, plus every bought-on-site line, in list
  order.
- `homeProgress` = (packed home, total) over home lines not used up. `homeUsedUp` = home lines used up.
- Tapping a line toggles `packedHome` (not on a used-up line). **Used up** → `setUsedUp(true)` (and the
  home tick goes); **Undo** → `setUsedUp(false)`.
- `setAllPackedHome(true/false)` (what Tick everything / Clear the ticks did until 0.79) stays in the model,
  tested by `WayHomeTests`, with no button: true ticks every home line not used up and not packed; false clears
  EVERY home tick on the trip, also on a line no longer on the way home.
- **Note Save** → `noteOnSite` (as On site: it also reaches the thing — his choice of 3 Oct 2026, now
  also what the code comment on `HOME_NOTE_KEY` says); an empty note removes it (no needs line here).
- **Open** → the thing's editor; Save or Cancel returns to the way home as it was.
- The way-out ticks are never touched.

### Data
Line extra keys `packedHome`, `usedUp`, `homeNote`; every mark also bumps the trip's `updatedAt` (head
record rewritten).

### Tests
Model `WayHomeTests` (7, with `testLooseThingsAreOneBagAndKeepTheirPhotos`). UI `testTheWayHomeIsPackedFromWhatWent`, `testTheWayHomeIsSearched`,
`testUsedUpIsCountedInTheHeadingAndUndone`, `testTheWayHomeIsTickedLineByLine` (0.79, was
`testEverythingIsTickedForTheWayHomeAtOnce`: no `wayhome-tickall` before or after every line is ticked by hand —
`tickEveryHomeLine` — and the used-up line takes no tick; seen red with the button planted back, and with only
Clear the ticks planted back), `testALineKeepsANoteForTheWayHome` (also listed under On site's notes),
`testAThingOpensFromTheWayHomeAndComesBack`, `testAPackedBagKeepsItsPhoto` (photos on the way home).
**Not covered:** the screen's heading for loose things (the model's `homeBags` is tested).

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

**Where.** The FOOT of the trip screen's scroll area, only on a reviewed trip: under Save as Excel and Share,
above Delete trip (still last — his rule for removing anything); padding 16 sideways, 12 on top. Since 0.73 (his
ask, 12 Oct 2026: "Send to Obsidian" to the very bottom of the trip page, styled like Save as Excel); from 0.70 a
card FIRST in the scroll area (above Check before you go, now Before you go), "Obsidian" on its left and a filled Send button at its
right.

### What is on screen (a column, 6 pt apart, no card of its own; id `trip-vault`, children contained)
- **Send to Obsidian** — `WideButtonLabel`, exactly Save as Excel's: the whole width, `Metrics.tap` tall, Body
  semibold green words beside a drawn mark (22 pt), green at 8 % inside a 1.4-pt green outline, corner 12; plain
  button style, id `trip-vault-send`. The mark is `VaultMark` (VaultCard.swift): a stone — obsidian is one — a
  crystal's outline and its faces' edges, drawn on the 24 grid with a 1.8-pt round stroke; never the vault
  app's own logo. Never grey, never switched off (his rule). Until 0.73: a `FieldButtonLabel` (white on green,
  Callout semibold, corner 8) at the right of the card, and the word **"Obsidian"** (Body semibold, ink; id
  `trip-vault-title`, used by no test, gone since) at its left.
- Under it, ONE status line (Footnote, muted, wraps — as `trip-excel-status` sits under Save as Excel), whose id
  says the state:
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
(Mac, GitHub's), `testASavedReviewAsksForTheTripsPage` (both: iPhone waiting, Mac written at once),
`testSendToObsidianIsAtTheFootOfAReviewedTrip` (0.73, both: where it is and its size — see the trip screen's
tests). Model
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
  maintenance note, bought on site and packing time — and (0.75) its charge ticks (`charged`, a kit line's
  `kitCharged`; spec 07 part 15). The sender's own trip keeps them all.
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
- **Inside a kit** (0.70; worded 0.73 — his ask: "in <the kit>, in the <bag>";
  `kitHolding(thingId:)`, not taken out of it): the KIT's own answer — its line on the trip under way (packed for
  home, ticked, not ticked), else its usual bag + usual pocket — with the thing's name kept and `kit` = the kit's
  name. `shown` is where the kit is ("Day pack · Front pocket"; "Not in a bag"); `kitWords` = "In the Camp pouch";
  `said`: packed → "In the Camp pouch, in the Day pack (front pocket)."; not ticked → "In the Camp pouch, not
  packed yet. It goes in the Day pack (front pocket)."; usual → "In the Camp pouch, usually in the Day pack (front
  pocket)." The bag gets "the", the pocket goes in brackets (softened as below); a kit in no bag: "In the Camp
  pouch." / "…, packed but not in a bag." / "…, not packed yet." (a pocket with no bag says nothing).
- **Taken out of its kit** (0.73): its OWN answer (its line on the trip under way — normally none, since what is
  inside a kit is never a line — else its usual bag + pocket) with `takenOutOf` = the kit's name: `kitWords` =
  "Taken out of the Camp pouch"; `said` = "Taken out of the Camp pouch." followed by its own words ("Usually in
  Tote."), or nothing more when it has no usual bag. `kit` and `takenOutOf` are never both set.
- A trip made before a thing went into its kit keeps the thing's own line until a rebuild: asked by name
  (`whereIs(words)`), that line answers as the thing does — with its kit — so Search and Siri agree.
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
<trip>." / "On <trip>, not packed yet — it goes there." A thing inside a kit (0.73): the place is where the KIT is,
and between the two a line of its own (Subheadline semibold, ink, wraps, `search-where-kit`) names the kit: "In
the Camp pouch". A thing taken out of its kit gets the card too, even with no line on the trip: its own place, "Taken
out of the Camp pouch", and "Where it usually goes." ("It has no usual bag." without one). Card: padding 12 × 8,
corner 10, card fill, green 1-pt border at 60 %, 10 above, id `search-where`. No trip under way: no card.

### Tests
UI `testTickingALineOffersItsBagsPockets` (`-uiTestingPockets`: ticking the charger shows `trip-line-1-pocket-*`,
Front pocket selected, the line says "Backpack · Front pocket"; Lid tapped → the row goes and the line says
"Backpack · Lid"; the Toothbrush in the carry-on shows none — red with `pocketing` never set: "ticking the charger
did not offer the Backpack's pockets"), `testPackToGoHomeKeepsItsPockets` (the way home's pills, the way-out pocket
first, Main kept — red with `prechooseHomePocket` not called: "the pocket it went out in was not chosen first"),
`testSearchShowsWhereAThingIsOnTheTripUnderWay` ("Backpack · Front pocket" above the things; none with no trip
under way — red with the card's condition turned round: "Search does not say where it is: ''"),
`testWhereIsAThingInsideAKitNamesTheKitAndWhereTheKitIs` (0.73, `-uiTestingKits -kitsUnderWay`: the Lighter's
card says "Day pack · Front pocket" and "In the Camp pouch"; taken out on its page, "Taken out of the Camp pouch" —
red with the kit line never drawn: "XCTAssertEqual failed: ("") is not equal to ("In the Camp pouch") - Search
does not name the kit", and with a taken-out thing's card not shown: "taken out, Search does not say so: ''"; green on
the iPhone in light and dark).
Model `PocketsTests` (10: a bag's list, add/rename/move/remove and their refusals; the usual pocket comes with a tick and
his choice stands; records and a backup keep all three keys; a usual pocket only while its bag has it; a rename
reaches things and lines, a remove leaves them in the bag; a bag deleted into another; the way home's own
pocket, Start again and a share without pockets; Where is my charger in every case; an absent key changes nothing;
a thing inside a kit with no trip under way, taken out with and without a place of its own, put back, a kit in no
bag (`testWhereIsAThingInsideAKit`); on the trip under way by the kit's line — not packed, packed in the pocket
chosen, packed for home — taken out with no line, and an old trip's own line answering with the kit
(`testWhereIsAThingInsideAKitOnTheTripUnderWay`). Red with a planted fault: the bag without "the" and brackets
("In the Camp pouch, usually in Day pack, front pocket." is not equal to "… in the Day pack (front pocket)."),
`takenOutOf` never set ("It has no usual bag." is not equal to "Taken out of the Camp pouch."), and the old trip's
line not routed through the thing ("Not packed yet. It goes in Backpack." is not equal to "In the Camp pouch, in
the Backpack (lid).")).

---

## The door check (`PackingLibrary/DoorCheck.swift`, `Store/DoorChecks.swift`, `LeaveTimes` in `Screens/Pockets.swift`)

**Purpose and origin.** Idea 4 of his idea plan; his choice (7 Oct 2026): "c, a time" — "'I leave at 07:30' on
the trip; the check comes 15 minutes before." "On the day you leave, at the moment you set off, one message names
what is still unticked … A tap opens the trip on just those lines. On the last day away, the same when you leave
the place."

**Where it is set.** "I leave at" on Create new trip and in Trip settings (above), stored as `leaveAt` /
`leaveHomeAt` ("HH:mm"; `Library.cleanTime` takes "7:30", "0730"; anything else is refused). Since 0.75 the
first day's time does one more thing: it is when the trip sets off — before it the trip is still at Pack, from it
On site, with its On site door (The loop, "When a trip sets off"). So the way-out check, 15 minutes before, always
comes while the trip is at Pack. The checks themselves are unchanged (they already went by the time).

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
unticked: Passport, Phone charger, Toothbrush, Headlamp, Hiking boots and 2 more"; every line ticked (by Tick
everything until 0.79) → none — red
with ticked lines counted: "a door check with everything ticked"), `testATappedDoorCheckOpensTheTripOnWhatIsLeft`
(out: the ticked Passport hidden, Show all brings it back; home: Pack to go home on what is left — red with the
focus not applied: "the trip did not open on just what is left"), `testCreateNewTripTakesTheTimeHeLeaves` (above),
`testTheDoorCheckSaysWhenTheDeviceDoesNotAllowIt` (-pretendRemindersBlocked: no line before a time, the red line
after Add a time — red with the line switched off: "nothing says the device does not allow the check").
`testILeaveAtIsOneFramedBlock` (0.75: on Create new trip, before and after Add a time, and in Trip settings —
`<id>-frame` is there and the heading, "the door check", the first day's Add a time or check, the last day's
Add a time and the note all lie inside its rectangle; "the door check" says so; the note ends "Before this time
the trip is still at Pack." Red with the frame's id taken away: "no frame round I leave at (trip-leave-frame)";
with the frame round the header and times only: "trip-leave-note at (30.0, 898.3, 337.3, 51.7) is outside the
frame (29.25, 766.6, 343.5, 115.5)". A first plant, the note moved by `.offset(y: 300)`, left it green: an
offset only draws the note elsewhere, its accessibility frame stays in the block — the plant was in the wrong
place, the test was right). Model
`DoorCheckTests` (6: times kept, synced and backed up; 15 minutes before, set-aside and ticked lines left out,
nothing to say = none; five names then "and 3 more"; midnight; the way home; no time no check; reviewed or
deleted = none). **Not covered:** the real scheduling and a real tap (the system's), the Mac's "your iPhone" line.

---

## Other ways into a trip

- **Countdown card on Home** (`CountdownCard`, id `home-countdown`; Home spec): the next trip still to
  leave (`nextTrip`: not reviewed, dated, starting today or later; soonest) — tap opens it on Home. Since 0.82 it
  also says "Before you start: 2 to buy, 3 to prepare" while that trip is not being packed (spec 07 part 19).
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

**UI (UITests/AMSPackingUITests.swift):** (0.76) testTravellingByIsPlaneOrRVOrNeither,
testMoreChoicesFoldSeasonFoodAndLaundry, testSeasonFollowsTheFirstDayUntilHePicksOne; (0.75) testILeaveAtIsOneFramedBlock, testATripIsOnSiteOnlyFromTheTimeHeLeaves;
(0.69) testTickingALineOffersItsBagsPockets, testPackToGoHomeKeepsItsPockets,
testSearchShowsWhereAThingIsOnTheTripUnderWay, testTheDoorCheckNamesWhatIsStillUnticked,
testATappedDoorCheckOpensTheTripOnWhatIsLeft, testCreateNewTripTakesTheTimeHeLeaves,
testTheDoorCheckSaysWhenTheDeviceDoesNotAllowIt; testATickCountsAndStays, testHomeBuildsATrip,
testDatesArePickedLikeBooking, testEveryRowShowsTheTickTheTripHolds, testASectionFoldsAndStaysFolded,
testATripIsDeletedOnlyAfterAsking, testWorthALookRemovesAPhotoLeftBehind, testAPlaceIsSetFromTheTrip,
testRefineOffersWhatTheReviewsFoundAndKeepAndDropSettleIt, testTheLoopShowsWhereATripStands,
testATripsSettingsAreChangedAfterItIsMade, testANewTripStartsFromThisOne, (0.73) testAlwaysPackedAloneMakesATrip,
testAReviewedTripWithoutDatesIsDone,
testLaundryCountsPerNightThingsFourNightsAtMost, testHomeCountsDownToTheNextTrip,
testATripChecksTheCabinAndTheDatesBeforeYouGo, testABagSaysWhetherItGoesInTheCabin,
testABagIsWeighedOnTheLuggageScale, testAShortcutOpensAGrabListOrTheNextTrip, testAPackedBagKeepsItsPhoto,
testSomethingBoughtOnSiteGoesOnTheList, testTheWayHomeIsPackedFromWhatWent, testTheWayHomeIsSearched,
testUsedUpIsCountedInTheHeadingAndUndone, testTheWayHomeIsTickedLineByLine,
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
testPackByVoiceSaysWhyItCannotStart, testPackByVoiceGoesOnceMoreOverWhatWasLeft, testAPlaceCodeStartsPackByVoiceAtThePlace;
0.73: testAPlacesCodeStartsPackByVoiceWithItsTripAlreadyOpen.
— and 0.70: testOnTheIPhoneSendToObsidianWaitsForTheMac, testSendToObsidianWritesTheTripPageOnTheMac,
testASavedReviewAsksForTheTripsPage.
UI launch modes used: `-uiTesting` (sample), `-uiTestingChecks` (a plane trip "Sunny weeks" 20–34 days
out, pocket knife + sun cream in the carry-on, sun cream expiring day 25, passport day 180),
`-uiTestingOnSite` (the sample trip began yesterday), `-uiTestingOldPhoto`, `-uiTestingSections` (Hiking in
two sections, its trip packed from Hiking as it now reads — 0.64 — so Section has headings),
`-uiTestingWorkouts` (0.67: the sample plus a WET template Run — Trail shoes Outdoor, Treadmill towel Indoor,
Running cap — and a Wetsuit Outdoor on Swim; `SampleLibrary.workouts`), `-uiTestingTravel` (0.76: the sample plus an
RV transport template "Camper kit" — Levelling blocks, Wheel chocks — and no Plane or Car one; `SampleLibrary.travel`),
with `-uiTesting`
0.71's `-uiTestingVoice "<words, by commas>"` / `-uiTestingVoiceRefused` / `-uiTestingVoiceStartAt <place>` (and 0.73's `-uiTestingOpenOnReturn <link>`, a place's link handed to the running app as it comes back to the front) (Pack by voice's fake speech; under any
`-uiTesting…` launch the fake is used, so no test opens a microphone), `-uiTestingReviewed` (0.70: the
sample's trip six to three days ago, everything ticked, the carry-on weighed 2.4 kg and photographed, a sun hat
bought on site, "zip broken" on the rain jacket, the map not used, a power bank missed onto Hiking; reviewed
yesterday, no page asked for; `SampleLibrary.reviewed`), `-uiTestingReviewedUndated` (0.73: the same with
the trip's dates taken away — a reviewed trip goes to Done whatever its dates; `SampleLibrary.reviewedUndated`),
`-uiTestingVault <name>` / `-uiTestingVaultChosen`
(0.70, Mac: a throwaway vault folder — spec 07 part 8), `-uiTestingPackingDay` (0.79: the sample plus a Day pack, one
of his bags with an AirTag, holding the Hiking boots and the Rain jacket — a trip with two bags; with
`-packingDayAlmost` every Packing day station done but the Map unticked; `SampleLibrary.packingDay`, spec 07 part
17), `-openNextTrip`. Under the
tests the stored sorting and folds (`ams.view`, `ams.trip.folded`) and, since 0.76, More choices' open or closed
(`ams.create.more`) are cleared at launch.

**The Packing day (0.79, spec 07 part 17):** UI `testThePackingDayLeadsFromBagsOutToTheList`,
`testWeighOpensByItselfOnceAndWeighsOneBagAfterAnother`, `testTagsAskForTheAirTagOnlyInABagThatHasOne`,
`testPhotosAskForAllTheBagsTogetherAndEachBag`, `testReadySaysWhatIsLeftAndPairsWithTheDoorCheck`; model
`PackingDayTests` (10).

**Model (PackingLibraryTests):** TravellingByTests (0.76), PocketsTests, DoorCheckTests (0.69), VoiceWalkTests (0.71), WorkoutContextsLibraryTests (0.67), CreateTripTests, CustomLineTests, ReviewTests, LaundryNightsTests,
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
    are offered (last, "Other Templates") on Create new trip and in Trip settings, and Save keeps the ids
    it does not show.
26. [idea] **Create new trip keeps Transport, Season and Food; no Place field.** Resolved in 0.62
    (decided, nothing changes): the next trip is usually the same car and season and the pills show it;
    the weather card asks for the place as soon as the trip opens. (0.76: Travelling by and Food are still
    kept; Season starts over, because the next trip's dates set it.)
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
33. [bug] **On site before he has left.** His report (13 Oct 2026): at 07:30 on the first day, with "I leave at
    08:00", the trip already said On site — the loop and the On site door went by the date alone. Resolved in
    0.75: on the first day a trip with a time to leave is On site from that time (`hasSetOff`; The loop, "When a
    trip sets off"), the trip screen turns by itself when the time passes, and every other place that asks
    "is it today / under way" was decided one by one (the table there). Something bought on site is still On
    site at any time.
34. [idea] **Car on the rule pages, once the trip screens no longer say Car** (0.76, decided 13 Oct 2026,
    minimal). A thing's page and a template's row keep "Only on some trips → Transport" with Car, Plane and RV
    exactly as before (ids `thing-transports-0…2`, `row-transports-0…2`): they set RULES, not a trip, and a rule
    of Car still means what it always meant — the trips stored as "Car", which since 0.76 are exactly the trips
    with Plane and RV both off. For him an ordinary trip IS a car trip ("the car is just go and drive"), so the
    word stays true; relabelling it ("Ordinary (no plane, no RV)") would also change the words he reads back
    ("Same as the thing: Car"), the Mac's type-to-jump letter and the web app's word. How it works says it
    instead: "Transport Car there means an ordinary trip — Plane and RV both off."
35. [idea] **The RV part of Travelling by's line when he has no RV template** (0.76, decided 13 Oct 2026): left
    out, not "RV adds your RV template" — that would promise a template that is not there. The same for Plane
    ("Plane adds the airport checks" alone). The names are read from the library each time the line is drawn,
    never written into the app (his RV template's name is his).
36. [idea] **Season from the dates, and More choices, in Trip settings** (0.76, decided 13 Oct 2026): neither.
    A made trip's season changes only when he taps it (moving the dates must not swap the winter gear), and
    Trip settings keeps every answer in sight — it is where they are changed, and Pack weather gear anyway
    sits between Season and Food.
