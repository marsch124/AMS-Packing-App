# 07 — Beyond the list

> Written 7 Oct 2026 (app 0.67), BEFORE the features below are built — the owner's rule for these ideas:
> "please document this very thoroughly so that we have that locked down". Each part is updated from the code in
> the version that builds it; until then it is the agreed design, and where the code later differs, the code wins
> and the difference is listed under *Open questions*.

This chapter covers the ideas the owner chose on 7 Oct 2026 from a set of "out of the box" proposals, in the
order they are built, and the ones he turned down (so no one proposes them again). Features that change existing
screens are ALSO described in those screens' chapters (03 trips, 04 templates, 05 things and Care, 06 settings);
this chapter holds the parts that span several screens and the decisions behind them.

| Part | Version | Status |
|---|---|---|
| 1. The keyboard on a thing's page (Mac) | 0.68 | building |
| 2. Sections renamed, reordered and removed from a thing's page | 0.68 | building |
| 3. Places opened by a printed code (no stickers — his word, 7 Oct) | 0.69 | building |
| 4. Search finds words in notes | 0.69 | building |
| 5. Bag pockets and "Where is my …?" | 0.69 | building |
| 6. The door check | 0.69 | building |
| 7. Apple Health fills in the review | 0.70 | built (written from the code) |
| 8. A trip page in his Obsidian vault | 0.70 | designed here |
| 9. Kits — things that hold things | 0.70 | built (0.70) |
| 10. Hands-free packing (a test version) | 0.71 | built (a test, iPhone only) — specified below from the code |
| 11. Decision log | — | kept here |

Parts 1–6 are specified in their screens' chapters by the version that builds them; their summaries here point
there. Parts 7–10 are specified in full below.

---

## 1–6. Summaries (details in the screens' chapters)

1. **The keyboard on a thing's page (Mac only).** Tab / Shift-Tab walk every field in reading order; lists answer
   type-ahead, Space opens, ↑/↓ move, Return chooses inside an open list; Return SAVES the page from anywhere
   except Notes (new line) and an open list (his choice, 7 Oct 2026); ⌘S saves, Esc cancels; ⌘N saves and opens a
   new thing carrying over Kind of thing, Whose it is, Kept at home, Usually packed in, When and the templates;
   ⌘↓ / ⌘↑ save and open the next / previous thing of the list the page came from; ⌘J jumps to a field by name;
   a "Thing" menu lists them. Keys chosen to work on a Swedish keyboard (no ⌥ letters, no [ or ]). → spec 05.
2. **Sections from a thing's page.** In the Section list of each template on a thing's page: rename (pen), order
   (up/down), remove (asks first; the things stay, with no section). Applied on Save; Cancel undoes. → spec 04/05.
3. **Places opened by a code.** A place (Your choices → Places) can be shown as a printed square code; the iPhone's
   Camera opens it, and it opens the trip on that place's lines (or what goes back there on the way home, or
   everything kept there). NFC stickers were planned and dropped the same day ("let's skip the NFC"). → spec 05/06.
4. **Search finds notes.** Your things and Search match a thing's own Notes and the notes its templates keep for
   it; the matching note shows under the name. → spec 05.
5. **Bag pockets and "Where is my …?"** Bags have pockets; a thing a usual pocket; a trip line the pocket it went
   into; Siri and Search answer bag + pocket. → spec 03/05.
6. **The door check.** "I leave at" on a trip's first (and last) day; 15 minutes before, one notification names
   what is still unticked (on the way home: not yet in a bag). His choice of trigger: a time he sets (7 Oct 2026),
   not location and not the car. → spec 03/06.

---

## 7. Apple Health fills in the review

> **Built in 0.70** (helper "health", 7 Oct 2026) — this part is now written from the code. Where the code
> differs from the design agreed the same morning, the difference is marked **(differs)** and listed under
> *Open questions*. Code: `Core/Sources/PackingLibrary/AppleHealthReview.swift` (every rule — the model),
> `App/Sources/Store/AppleHealth.swift` (reading Apple Health; the invented one for the tests),
> `App/Sources/Screens/ReviewHealth.swift` (the block and the template's "Counts as"), `ReviewScreen.swift`
> (where it sits), `TemplatesScreen.swift` (where "Counts as" sits).

### What he sees

After a trip, the review (Trips → a trip → Review) opens, on the iPhone, with a card **"From Apple Health"**
(id `review-health`) above everything else: the workouts that STARTED between the trip's first and last day, one
row per kind (`review-health-row-<n>`, top to bottom), for example

- "Swim · indoor · 3 times"
- "Run · outdoor · 2 times"
- "No bike" (only for a workout template that is on the trip and had no workout)

and a button **"Use these"** (`review-health-use`; green, always in full colour). Row words, from
`Library.rowWords`: the kind's name; then "indoor" or "outdoor" when every workout of the kind had that context,
"2 indoor, 1 outdoor" when they differ, nothing when Apple Health could not tell any; then "once" or "N times".
Kinds done come first in the kinds' order (Swim, Bike, Run, Strength, Mobility & breath work, Hiking, Golf,
Climbing, Diving), then the "No …" rows in the same order — "No " + the kind's name in lower case ("No bike",
"No mobility & breath work"). Done rows are Callout semibold ink, "No …" rows Callout regular muted.

Pressing "Use these" reads Apple Health again and marks the review's lines:

- lines from a workout template whose workout WAS done → used (as the review already assumes);
- lines from a workout template whose workout was NOT done at all → "didn't use";
- lines from a workout template done only in the OTHER context (only indoor swims, but the line's place on the
  template is for Outdoor only) → "didn't use";
- every other line (common base, transport, a template that is no workout, a line added by hand on the trip,
  someone else's thing, a Race line) → unchanged.

Under the button it then says what it did: "Marked 3 didn't use, 6 used." (+ "; your own answer stays." / "your
own 2 answers stay." when it skipped lines he had answered) — Subheadline muted, `review-health-said`. With
nothing it could mark, it says why instead, in the warning colour (`review-health-use-needs`): "None of this
trip's lines come from a workout template." or "You have answered every line Apple Health could." **(differs:**
the design did not say what the button says; his rule is that a main button never does nothing silently.)

Every mark stays his to change before Save; nothing is saved by "Use these" alone — Cancel throws its marks away
like any other. A line he had already answered by hand (tapped, either way — `answered` in `ReviewScreen`) keeps
his answer, on every press. Without workouts on those days, the card says "No workouts in Apple Health for these
days." (`review-health-none`) and offers nothing; workouts the review ignores (a walk) do not count as workouts
here. While reading: "Reading Apple Health…" (`review-health-reading`).

### Which workout meets which template

Each template meets at most one kind of workout (`Library.workoutKind(of:)`): his link, if he made one, else its
NAME. Only an activity template (role "") can meet one — whatever its activity area (Hiking and Golf are GA, Swim
is WET); the common base and the transport templates never do.

**By its name** (`WorkoutKind.named`): the name compared the way the workout colours compare it (`WorkoutTone`:
`normName`, then every space removed), as a WHOLE — "Swim training" meets nothing:

| Kind (row name) | Template names that meet it by themselves |
|---|---|
| Swim | swim, swimming |
| Bike | bike, biking, cycling, cycle |
| Run | run, running |
| Strength | strength, strength training, gym |
| Mobility & breath work | mobility, breath work, breath, Mobility & Breath work, Mobility and Breath work, Mobility & breath, yoga, stretching |
| Hiking | hiking, hike |
| Golf | golf |
| Climbing | climbing, climb |
| Diving | diving, freediving, Diving and Freediving, Diving & Freediving, scuba diving, dive |

**By his link — "Counts as"** on the template's page (an activity template, iPhone and Mac; above "Activity area"
and "Delete template"): a drop-down (`template-counts-as`) of the nine kinds plus **Nothing**
(`template-counts-as-0…8`, `-9` = Nothing), showing the kind it meets now (his pick, else its name's, else
Nothing). Stored on the template (`extra["countsAs"]`: the kind's id `swim`, `bike`, `run`, `strength`,
`mobility`, `hiking`, `golf`, `climbing`, `diving`, or `none`), so it is synced and backed up like its other
fields; `setCountsAs(templateId:to:)` refuses any other value, and nil goes back to the name (no button offers
that — picking the name's own kind stores it). "Nothing" = the template is no workout whatever its name says: its
lines are left alone and it never gets a "No …" row.

**From Apple Health** (`WorkoutKind.of(activityType:)`, `metWorkouts`) — Apple's workout type numbers
(`HKWorkoutActivityType`) are written out in `HealthActivity` and pinned by a test:

| Apple Health workout (type number) | Kind it is | Context from the workout |
|---|---|---|
| Swimming (46) | Swim | pool → Indoor; open water → Outdoor (Apple Health's swimming location); not said or unknown → either **(differs:** not in the design) |
| Cycling (13) | Bike | indoor workout → Indoor; otherwise (also not said) Outdoor |
| Running (37) | Run | indoor workout → Indoor; otherwise Outdoor |
| Traditional strength training (50), functional strength training (20), core training (59) | Strength | Indoor |
| Yoga (57), mind and body (29), flexibility (62), cooldown (80), preparation and recovery (33) | Mobility & breath work | — (either) |
| Hiking (24) | Hiking | Outdoor |
| Golf (21) | Golf | Outdoor |
| Climbing (9) | Climbing | indoor workout → Indoor; otherwise Outdoor |
| Underwater diving (84) | Diving | Outdoor |
| Swim-bike-run, a multisport workout (82) | its parts, each as above; the change-overs (83) are nothing **(differs:** the design ignored it — a triathlon is a swim, a ride and a run) | each part's own |
| anything else (a walk, tennis, rowing, "other"…) | — (ignored, and not counted as a workout) | — |

"Indoor workout" is Apple Health's `HKMetadataKeyIndoorWorkout`; the swimming location `HKMetadataKeySwimmingLocationType`
— each from the workout's metadata, else (a workout of one activity) from its own configuration's location /
swimming location; a multisport part from its own metadata, else its configuration. The day is the day it
STARTED, on this device's clock.

"Race" cannot be read from Apple Health: a line for Race only is left as it is.

### Which lines a mark touches (`healthVerdict`, `healthReview`)

Only the lines the review asks about (`reviewLines(…).packed` — when anything was ticked, only what went). For
each line, the templates that put its THING on this trip are found: the trip's feeding templates
(`listsForEvent`: the base, the transport template, the ticked ones — none of the base on a Quick trip) that hold
the thing and would bring it (not retired, `itemMatchesEvent`, its weather condition on), always including the
line's own `sourceListId` (if its row has gone from that template since, the template still counts, for either
context). Then:

1. a line added by hand on the trip (no template) → unchanged;
2. someone else's thing → unchanged (see *Whose things* below);
3. any of those templates is no workout (the common base, a transport or holiday template, one linked to
   Nothing) → unchanged — "the common base wins", generalised;
4. otherwise each workout template answers, by the CONTEXTS of the thing's row on it (Indoor / Outdoor / Race;
   none = any):
   - no context, or a workout of its kind with no known context (a mobility session, a swim without a location),
     or a workout in one of the row's contexts → **used** — one template saying used is enough (a gel belt on
     Run and Bike: a run is enough);
   - Race only → no answer from this template;
   - Indoor/Outdoor (with Race too): only workouts of the other context → no answer (it may have been the race);
   - no workout of its kind at all → didn't use (no run, no race either);
   - Indoor/Outdoor without Race: only the other context → didn't use;
5. no "used", and any "no answer" → unchanged; else → **didn't use**.

### Rules and edge cases

- **Days:** from the trip's first day 00:00 to its last day 23:59, in the time zone of the device — the query
  asks for workouts STARTING in [first day 00:00, last day + 1 00:00); the model keeps only those whose start day
  lies within the days too. No last day (or one before the first) = the first day only. An undated trip gets no
  block (`healthDays` = nil).
- **Two trips on the same days:** each review reads the same workouts; that is correct (he was on both).
- **A workout without its gear** (a run on the treadmill of a hotel): it still marks the Run template's things as
  used where their context allows — the app cannot know; he corrects the few lines by hand.
- **Things for someone else** (Whose it is ≠ him): left unchanged — his workouts say nothing about hers. "Him" is
  the owner he marked **"This is me"** in Your choices → Owners (his answer of 7 Oct 2026 to "whose things?": "My
  things."; `me()`, stored in `meta["me"]`, synced and in a backup's `prefs.me`, one at most, a small "Me" tag on
  the row — spec 06 §2). "Both have one" (no name) counts as his. While nobody is marked, `mainOwner` GUESSES: the
  name on the most of his things (a tie → the first A–Z; names compared as names; nobody named anywhere → every
  thing is his) — and the card says, under Use these, "Who are you? Mark yourself in Your choices → Owners."
  (Subheadline muted, `review-health-who`).
- **Things on two templates** (a towel on Swim and on the common base): the common base wins — unchanged. On a
  Quick trip the base is not packed, so Swim alone brought the towel and it is marked.
- **Workouts logged later** (a watch synced after the review opened): "Use these" reads again each time it is
  pressed; a line marked by an earlier press (and not touched by him) is put right by a later one.
- **Permission:** asked the first time the block would show (the review of a dated trip, on the iPhone), by
  Apple's own sheet, with his words (`NSHealthShareUsageDescription`): "AMS Packing reads your workouts during a
  trip to suggest what you used. It never writes to Apple Health." Apple also wants a text for writing, though
  nothing is written (`NSHealthUpdateUsageDescription`: "AMS Packing never writes to Apple Health. Apple requires
  this text all the same.") **(differs:** not in the design.)
- **Refused:** the block says "Apple Health is not allowed — Settings → Privacy & Security → Health → AMS
  Packing." (`review-health-refused`) and nothing else changes. **(differs:** the design's words were "Settings →
  Privacy → Health"; the iPhone's real path is used.) Apple NEVER tells an app that reading was refused — it
  simply sees no workouts. So "refused" is shown when asking for permission fails, or when the trip's days hold no
  workout AND Apple Health gives not a single workout of any day ever (he logs workouts every week); an account
  that truly has none would read "not allowed" too. **(differs:** the design assumed the refusal could be read.)
- **Read only.** The app never writes to Apple Health: permission is asked to read workouts and nothing else
  (`requestAuthorization(toShare: [], read: [workouts])`). Nothing read leaves the device or is stored; only the
  review answers (used / didn't use) are saved and synced, as today.
- **iPhone only.** The Mac has no Apple Health: its review shows no block (`NoHealth`, `available` = false); a
  review answered on the iPhone reaches the Mac as any other review. The "Counts as" drop-down is on both.
- **Under the UI tests** the real Apple Health is never asked (its sheet would stop every review test):
  `-uiTestingHealth` feeds invented workouts (`InventedHealth`: three pool swims and two outdoor runs on the
  sample trip's days, a walk, and an open-water swim the week before), `-healthRefused` answers "not allowed",
  `-healthNone` has nothing; every other test mode has no Apple Health.

### Release

An app that reads Apple Health carries the HealthKit entitlement — on the iPhone only:

- `project.yml`: an iPhone build (device or simulator) signs with `App/Config/AMSPacking-iOS.entitlements`
  (`CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]` / `[sdk=iphonesimulator*]`) — the generated file's keys plus
  `com.apple.developer.healthkit` = true and `com.apple.developer.healthkit.access` = []; the Mac keeps the
  generated `AMSPacking.entitlements` without it. Why not the Mac: it has no Apple Health, and an ad-hoc signed Mac
  app (the tests on GitHub and here) carrying a `com.apple.developer` entitlement is refused at launch, as with
  iCloud.
- `.github/workflows/testflight.yml`: the shipped iPhone entitlements (`AMSPacking-Ship-iOS.entitlements`, made
  from the iCloud file) get the two HealthKit keys (PlistBuddy) — the Mac's ship file does not. After the
  archive, the step **"The iPhone archive must carry the HealthKit entitlement"** reads the archived app's
  entitlements (`codesign -d --entitlements -`) and FAILS the run if `com.apple.developer.healthkit` is missing —
  a version without it would show "not allowed" and say nothing else.
- Workout Sync showed (30 Sep 2026) that GitHub's cloud-signed archive can lose it; the owner allowed (7 Oct
  2026) that such versions are archived and uploaded from his Mac when GitHub cannot sign them. The App ID
  `com.schabbauer.AMSPacking` has HealthKit switched on (7 Oct 2026).
- `tools/build.sh … icloud` signs with the iCloud file, which has no HealthKit: a local iCloud build to his
  iPhone shows "not allowed" in the review.

### Tests

- Model — `AppleHealthReviewTests` (PackingLibrary, 20, invented workouts only):
  `testEveryAppleHealthWorkoutTypeMeetsItsKind` (every row of the table; a walk, tennis, rowing, "other" and a lone
  change-over ignored; Apple's numbers pinned), `testEachWorkoutGetsItsContextFromAppleHealth` (every context
  rule), `testATriathlonCountsAsItsSwimRideAndRun`, `testATemplateMeetsAWorkoutByItsName` (names, whole-name rule,
  base and transport never), `testCountsAsIsHisLinkAndTravelsWithTheTemplate` (kept through edits, the sync
  records and a backup; Nothing; back to the name; nonsense refused),
  `testALinkedTemplateIsMarkedAndANothingTemplateIsLeftAlone`, `testOnlyTheTripsDaysCountAndAnUndatedTripHasNoBlock`,
  `testTwoTripsOnTheSameDaysReadTheSameWorkouts`, `testTheRowsNameEachKindItsContextAndHowOftenThenWhatWasNotDone`,
  `testNoWorkoutsMeansNoRowsAndNoMarks`, `testDoneNotDoneAndTheOtherContext`, `testRaceAndAnyContextLines`,
  `testThingsForSomeoneElseAndBothHaveOneAndThingsOnTwoTemplates`, `testWhoHeIsIsTheNameOnMostOfHisThings`,
  `testLinesWithoutATemplateAndLinesThatNeverWentAreLeftAlone`, `testARowTakenOffItsTemplateSinceStillCountsForItsTemplate`,
  `testAWatchThatSyncsLaterIsReadAgain`, `testUseTheseKeepsHisOwnAnswersAndSavesNothing`,
  `testTheSavedReviewTeachesTheThingsWhatAppleHealthMarked`, `testThisIsMeDecidesWhoseThingsAppleHealthMarks`.
- UI (`-uiTestingHealth`, `SampleLibrary.health()`: the trip "Training camp", six to two days ago, Swim + Run + Bike
  + the base, 13 lines): `testAppleHealthFillsInTheReview` (the three rows and no fourth; his own mark kept; after
  Use these exactly lines 5 Goggles (his), 7 Wetsuit, 9 Treadmill towel, 12 Bike helmet "didn't use"; Cancel keeps
  nothing; Use these + Save → Reviewed; the Mac: no block), `testATemplateCountsAsWhatHeLinksItTo` (the base has
  no "Counts as"; Bike → Nothing, kept; then no "No bike" and the helmet unmarked),
  `testAppleHealthSaysWhenItIsNotAllowedOrHasNothing` (iPhone only), `testThisIsMeDecidesWhoseThingsAppleHealthMarks`
  (asks who he is; Robin marked in Owners → tag, no question, Robin's cap marked too; red with `mainOwner` planted
  to ignore the mark — the model test too). Each seen red with a planted fault (7 Oct
  2026): his taps not remembered as answers → "line 5 should be didn't use"; the "No …" rows read by the name,
  not the link → "still “No bike”, though Bike counts as Nothing" (the model's
  `testALinkedTemplateIsMarkedAndANothingTemplateIsLeftAlone` went red on the same fault); a refusal read as "no
  workouts" → "a refusal is not said". Then all three green, with the review's and the template page's 18 other
  tests, day and night, on an iPhone 17 (iOS 26.5); the Mac builds.
- **Not covered:** the real Apple Health (permission sheet, query, a real multisport workout) — only on his
  iPhone; "Reading Apple Health…"; the refusal guess for an account with no workouts ever.

---

## 8. A trip page in his Obsidian vault

### What he gets

When a trip's review is saved — and whenever he presses **"Send to Obsidian"** on a reviewed trip — the trip
becomes one Markdown page in the folder he picked once (his choice, 7 Oct 2026: the vault's `Areas/Travel`),
named `<yyyy-mm> <trip name>.md`. Writing it again replaces the page (the same name).

### The page

- Front matter: `type: trip`, `start`, `end`, `nights`, `place`, `transport`, `season`, `templates` (names),
  `packed` (lines packed / lines), `weight` (all bags, kg), `reviewed` (date).
- Sections: **Weather** (as the trip recorded it), **Workouts** (from part 7, when read), **Bags** (each bag with
  its weight and its packed photos, copied into an `attachments` folder beside the page and linked),
  **Didn't use**, **Missed** (added at the review), **Bought on site**, **Notes** (maintenance notes like "zip
  broken", each with its thing's name).
- Plain Markdown, no plug-ins needed. No personal data beyond what he typed into the trip.

### Where it is written

The folder lives on the Mac, so the **Mac** writes the page: on the Mac's next launch (or at once, when the Mac app
is open) for a review saved on the iPhone, and at once for "Send to Obsidian". The folder is chosen with the
system's folder picker and remembered as a security-scoped bookmark, the same way as WatchLater's export. Without
a folder, the button asks for one. A folder that has gone away → the button says so and asks again.

### Tests (planned)

Model: the page's text for the sample trip (front matter, sections, names in invented data). UI on the Mac (probe):
the button, the picker answered by a test folder (`-uiTestingVault <path>`), the file written.

---

## 9. Kits — things that hold things

> Built in 0.70 (`PackingLibrary/ThingKits.swift`, `App/Sources/Screens/ThingKitPart.swift`,
> `App/Sources/Screens/TripKitLine.swift`). Written from the code; where it differs from the design of 7 Oct, the
> difference is under *Open questions*. Details per screen: spec 01 §1.12 (the keys), 03 ("Kits", "A kit's
> line"), 05 (a thing's page item 11b, Care, the table).

His words (7 Oct 2026): some things are "already existing as a permanently packed item consisting of items" —
a pouch of cables and chargers, a pouch of small tools. He said yes to kits on 7 Oct.

### What a kit is

- **A kit is a thing that holds at least one thing.** Its contents are real things with their own weight, care,
  condition and Valid until; they stay in Your things, the table and Care like any other.
- **One level deep.** A kit can go in a bag; a kit never goes inside a kit; a thing is in one kit at most; a bag
  is never a kit nor inside one (a bag holds its things by name); a to-do is never inside one.
- **Taken out** (for now): a thing taken out of its kit is still its content, but not in it — "1 missing: Lighter"
  until it is put back. Taken out on the thing's page, on the kit's page, or from the kit's fold on a trip — it is
  the thing's, so every trip and both pages follow.
- **Check before each trip** (on the kit's page): the contents show as small ticks under the kit's line, and the
  kit counts as packed only when all inside it are ticked.

### Where it is kept

On the KIT, in three `extra` keys — `kitContents` (ids, his order), `kitOut` (ids taken out), `kitCheck` (true) —
and, on a trip's kit line, `kitTicked` (the ticked ids while the line is not ticked). So the web app's model sees a
plain thing (parity 211/211), and a kit is stored, synced through iCloud, backed up and restored with the thing,
as every `extra` key is. Which kit holds a thing is read from the kits (`kitIndex`): in id order, a thing in the
first kit that lists it.

### On a thing's page (spec 05, item 11b)

Under Weight: **Inside** — the things in it (name, weight, what is worth saying: out of date, runs out within 60
days, care due), each with Take out / Put back and ✕ (out for good); **Add from your things** (an inline list:
search, the first 8 that can go in, A–Z; one in another kit says so and moves); **Check before each trip**; **With
what is inside: 170 g**. A thing inside a kit shows **In a kit** instead: "Inside the Wash bag", **Taken out for
now**, and — when it is ALSO on a template on its own — "Also on Common base on its own — a trip packs the Wash
bag instead." Everything waits for Save; Cancel leaves the kit as it was.

### On a trip (spec 03)

- **ONE line**: "Camp pouch · 3 inside", with a fold arrow beside its ⊘ showing what is inside, muted, each with
  Take out / Put back. Ticking the kit packs it.
- With **Check before each trip**: open until packed, small ticks, "Tick what is inside first: 2 to go."; the
  kit's own tick is refused until all inside are ticked (a section's tick-all and Tick everything too); the last
  tick packs it; unticking one unpacks it.
- **"1 missing: Lighter"** under the line while something is taken out.
- What is worth saying about what is inside, for this trip, under the line ("Plasters runs out in 10 days").
- **Trip building never adds a content as a line.** Templates hold the kit. A thing inside a kit that is ALSO on a
  template on its own: on a template with its kit, it is left out; on one without, the KIT comes in its place. Each
  kit is one line per trip.
- **Check before you go** looks inside kits: "Lighter, in the Camp pouch" in a cabin bag is not allowed on board;
  "Plasters, in the Camp pouch" runs out before you are home.

### Weight and Care

A kit weighs its own weight plus what is inside it now (each content × its how-many; taken out not counted): on
the Bags card and a bag's trips, in Care's heaviest things and what each template weighs, and in the table's
Weight column (read only there; its own weight is set on its page; sorting and filtering by Weight go by it). Care's
total counts each thing once. A care row of a thing inside a kit says "inside the Camp pouch".

### Tests

Model `ThingKitsTests` (15): his order and one kit at most (moving between kits; out for good; empty = a plain
thing, no keys left); the refusals (itself, a kit into a kit, a content holding things, a bag either way, a to-do)
and what is offered; two kits listing one thing settle on the first by id and the other drops it at its save;
taken out and missing words; the weight on the bag bars, Care's heaviest, template weights, the table's sort and
filter; one line and never a content (the kit in a content's place); a kit with its content on one template, a kit
on two templates; a rebuild and a change to a thing never bring a content back (a ticked line stays); the checked
kit's ticking; warnings (dates and care, before the trip ends, taken out not said) and Care's row naming the kit;
the checks before you go looking inside; "also on" a template; stored / synced / backed up (as stored and rebuilt
from rows) / restored, and plain to the web model; deleting a content or a kit; a shared trip and a trip started
again carry no ticks inside a kit.

UI (`-uiTestingKits`: the sample + a Camp pouch on Hiking with a Lighter, Spare cord and Plasters, and a Wash bag on
no template, checked before each trip, with the Toothbrush — still on Common base — and Soap):
`testAKitsPageHoldsItsThingsTakesOneOutAndAddsAnother` (190 g; the cord taken out → 110 g; the Map added → 170 g;
kept after Save; the trip says "1 missing: Spare cord"), `testAKitIsOneLineOnATripAndWeighsWhatIsInside`,
`testAKitCheckedBeforeEachTripIsPackedWhenAllInsideIsTicked`, `testAThingInsideAKitSaysSoAndIsTakenOutFromItsPage`.
Each was seen red with a planted fault: Save not writing the kit ("Save did not keep the map inside"), the bags not
weighing the contents ("… '2.1 kg'"), the kit's tick not refused ("the kit was packed before what is inside it was
ticked"), Save not writing taken out ("taken out on its page, it is not missing on the trip: ''"). The thing page's
kit part also ran on the Mac (probe).

### Open questions

- **No `insideKitId` on a content** (the design had it): ONE record holds a kit's whole state, so the two sides
  can never disagree; a content's kit is read from the kits.
- **A content on a template whose kit is not on the trip** brings its KIT (the design said only "never a separate
  line"). Leaving it out would have lost it silently. His word welcome.
- **A trip made before a thing went into its kit** keeps that thing's line until a rebuild (Trip settings → Save).
- **"Where is my …?"** (part 5) should answer "Camp pouch, in the backpack" for a thing inside a kit:
  `Library.kitHolding(thingId:)` gives the kit; joining it to the pockets' answer is left for the merge with 0.69.
- **The Mac's keys** (part 1): the kit part's buttons and switches are not in the page's Tab order yet.
- **Past trips** show what is inside their kits as it is NOW (a trip line is a copy; its contents are not).
- **The table's kit weight** is not typed in; its own weight is on its page. Not covered by a UI test (the model's
  sort and filter are).

---

## 10. Hands-free packing (a test version)

His yes of 7 Oct 2026, in English (his choice). Built in 0.71 from this design; what follows is the code.
Files: the walk's decisions in `Core/Sources/PackingLibrary/VoiceWalk.swift` (no speech in it — the model
tests hold it); speaking and listening in `App/Sources/Voice/` — `VoiceIO.swift` (the protocol and the UI
tests' fake), `DeviceVoice.swift` (the iPhone's own voice and ears), `VoiceWalker.swift` (runs one walk),
`VoicePanel.swift` (the button and the panel). All of `App/Sources/Voice` is `#if os(iOS)`: **the Mac has no
button and none of this code** (the Mac app is built without it).

### The button

On a trip (`TripScreen`), at the END of the Sorting row — "Sorting", its drop-down, then **Pack by voice**
(`VoiceSortingRow` wraps the row): an outlined green capsule (green words and a drawn microphone `MicMark`,
18 pt, on 10 % green, 1.4 pt green stroke), `Metrics.tap` tall (36) like the drop-down's field, the words
Subheadline semibold; id **`voice-start`**, accessibility label "Pack by voice". On an iPhone too narrow for
"Sorting", the drop-down showing "From where" and "Pack by voice" on one line, the button says **Voice**
(`ViewThatFits`: the first of the two rows that fits). The drop-down's field takes what the button leaves.

Never grey (his rule): pressed when the walk cannot start, the reason is said under the row in red
(Subheadline semibold, id **`voice-start-needs`**), and nothing opens:
- nothing to pack — every line ticked or set aside: "Everything on this trip is packed or set aside.";
- speech recognition not allowed: "Packing may not understand speech. Allow it in Settings → Privacy &
  Security → Speech Recognition.";
- microphone not allowed: "Packing may not use the microphone. Allow it in Settings → Privacy & Security →
  Microphone.";
- no English recognised on this iPhone by itself: "This iPhone cannot yet understand English by itself. Add an
  English keyboard with Dictation on (Settings → General → Keyboard), then try again.";
- the recogniser busy: "Speech recognition is not ready just now. Try again in a moment.";
- the microphone cannot be opened: "The microphone could not be opened just now. Try again in a moment."
The next press clears the line first. The first press asks for both permissions (the system's own questions,
with the usage texts below); a later press asks nothing.

**Usage texts** (Info.plist, from project.yml): microphone — "Pack by voice listens for packed, skip, later,
where and stop while you pack. What you say stays on this iPhone."; speech recognition — "Pack by voice
understands your five words on this iPhone itself, without the internet. Nothing you say leaves it."

### The walk (`VoiceWalk`)

- **Which lines, in which order:** the trip's lines NOT ticked and NOT set aside, in the trip's **From where**
  order (`groupByStorage`: places A–Z, "No place set" last; inside a place the trip's own line order) —
  whatever sorting the trip screen shows. The walk is fixed when it starts; a line ticked or set aside
  meanwhile (by the other device) is passed over without being asked.
- **A start place** (`VoiceWalk(trip:startAt:)`, `VoiceSortingRow(startAt:)`, `VoiceStarts`): the walk begins at that place
  and goes round — that place, the places after it, then the ones before. Compared by `Library.choiceKey`
  ("garage" is the Garage). A place the trip does not have, or one with nothing left, is no start: the walk
  begins at the first place.
- **A place opened by its printed code STARTS the walk by itself** at that place (his yes of 7 Oct 2026). The
  entry point is `VoiceStarts.shared.startVoiceAt(place:tripId:)` (`App/Sources/Voice/VoiceStarts.swift`, iPhone
  only): a request held until the trip's Sorting row takes it — at once when that trip is open, or when it opens
  (`tripId` nil = whichever trip screen is open or opens next). The row (`VoiceSortingRow`,
  `.onChange(of: starts.request, initial: true)`) takes the request, and — when the setting below is on and no
  walk is running — starts exactly as the button does (permissions, "nothing to pack" said under the row).
  **To wire at the merge:** where part 3's link handler opens a trip on a place (`Library.PlaceVisit.packing(tripId:)`,
  branch work/places069), add `#if os(iOS) VoiceStarts.shared.startVoiceAt(place: <the place's name>, tripId: <that
  trip>) #endif` right after it sets the trip to open; nothing for `.goingBack` or `.keptThere`.
- **The setting** "Start Pack by voice when a place code opens a trip" — a switch on the panel (under Said/Heard
  while it runs, under the log when over; Subheadline, green tint; id `voice-autostart`), stored on this device
  (`ams.voice.autostart`), **on by default**. Off: a place code opens the trip as part 3 says and nothing starts.
- **What it says** (an English voice; names as written; "Name, 4" when a line counts more than one —
  `effectiveQty` with the trip's laundry-capped nights):
  - first: "7 to pack. Bathroom cabinet. Toothbrush." — how many, the place, the thing;
  - the next thing in the same place: just the thing, "Phone charger.";
  - the first thing of a new place: the count, then the place: "Bathroom cabinet done, 1 of 7. Chest of
    drawers. Passport." The count is the trip's own — ticked / lines not set aside, as `trip-progress` shows;
  - after every **5** answers in one place (`VoiceWalk.progressEvery`; packed, skip and later count): the
    count first, "5 of 7. Thing 6.";
  - **where**: the place and the thing again, "Garage. Headlamp." (nothing moves on);
  - **stop**: "Stopped. 2 of 6 packed." — and the walk ends;
  - the end of the list: "That was everything. 6 of 7 packed." — and, when lines were left for later that still
    wait (not ticked or set aside meanwhile), **once more** (his yes of 7 Oct 2026): "That was everything. 6 of 7
    packed. 1 left for later — once more?" and it waits. **packed** (and every word of its list: yes, ok, done …)
    walks those lines again — "Once more. Bathroom cabinet. Toothbrush." — in the same order; **where** asks the
    question again; **skip, later or stop** end the walk: "Stopped. 6 of 7 packed. 1 left for later." Only ONE more
    round: at the end of the second the walk ends ("That was everything. 7 of 8 packed. 1 left for later."). The
    summary counts both rounds (packed and set aside added up; later = what is still left at the end);
  - something heard that is none of the words: "Sorry?" — and it listens again.
- **The five words** and what they do to the line being asked about (`VoiceWalk.action`, applied by
  `Library.apply` — one `model.change`, exactly as a tap does):
  | Word | The line | Then |
  |---|---|---|
  | packed | ticked (`setChecked(true)`) | the next thing |
  | skip | set aside — "not this time", as ⊘ does (`setAside(true)`, its tick goes too) | the next thing |
  | later | left as it is, unticked | the next thing; named under "Left for later" at the end |
  | where | left as it is | the place and the thing are said again |
  | stop | left as it is | the walk ends |
- **Forgiving words** — ONE list, `VoiceWord.accepted`, which is also what the recogniser is told to expect
  (`contextualStrings`):
  - packed: packed, pack, packs, packed it, pack it, packet, pact, backed, got it, have it, done, yes, yeah,
    yep, ok, okay, check, tick, ticked, in the bag;
  - skip: skip, skipped, skips, skipping, skip it, not this time, set aside, aside, leave it, nope, not needed,
    dont need it, not taking it;
  - later: later, later on, next, next one, not yet, after, afterwards, pass, come back, move on;
  - where: where, wheres, where is it, where is that, wear, were, ware, repeat, again, say again, pardon,
    sorry, what, which place;
  - stop: stop, stop it, stopped, end, quit, finish, finished, enough, cancel, all done, im done, thats all,
    thats it, halt.
  Matching (`VoiceWord.heard`): lower case, an apostrophe left out ("that's" → "thats"), every other mark a
  space; then the FIRST phrase in what was heard wins ("where did I pack it" is where), and at one place the
  longest ("all done" is stop, "done" alone packed). Left out on purpose: a bare "no" (often the start of
  something else — "no wait, packed"), "back", and "wait" (he is looking for it: the walk should wait, not move
  on). "Next" is **later** (it moves on and leaves the line unticked).

### Speaking and listening (`DeviceVoice`, iPhone)

- **Voice:** `AVSpeechSynthesizer`, the system's English voice for the chosen English (`AVSpeechSynthesisVoice`),
  default rate.
- **Ears:** `SFSpeechRecognizer` with **`requiresOnDeviceRecognition`** — it works offline, and nothing he says
  leaves the iPhone; partial results on, punctuation off, task hint "confirmation" (short answers).
- **Which English:** his iPhone's own when it is US or British English; otherwise British, then American — the
  first this iPhone recognises by itself (`supportsOnDeviceRecognition`).
- **It never listens while it speaks** (so it cannot hear its own "Garage done …"): each line is said, and only
  when it has been said does listening start. A word is acted on as soon as it is heard (from the partial
  result); words that are none of the five count as said when he pauses for **1.2 s** (or the recogniser
  finishes) — then "Sorry?". When the recogniser gives up on silence it listens again without a word; after
  more than 5 such rounds in a row it stops: "Listening stopped working. Start again in a moment."
- **Sound:** the audio session is play-and-record: the loudspeaker when nothing is plugged in, **AirPods**'
  microphone allowed in (Bluetooth hands-free), other sound (music) quieter while it runs. AirPods put in or
  taken out: the microphone is started again on the new route.
- **Ended without his word:** a call, Siri or another app taking the sound — "Stopped by a call or another
  app."; the microphone lost — "The microphone could not be opened just now. Try again in a moment."; Packing
  put away (the iPhone stops listening in the background) — "Stopped when Packing was put away." Said on the
  panel in red (id `voice-cut`). **The screen stays on** while a walk runs (`isIdleTimerDisabled`), so it is not
  locked by itself mid-walk.

### The panel (`VoicePanel`, a sheet over the trip, id `voice-panel`)

While it runs (a swipe down does not close it — Stop does):
- Header: "Pack by voice" (Title 3 bold, green) and a small outlined "A test" (Caption semibold, muted).
- A line: a dot (green while listening, `Theme.line` while speaking) and "Listening" / "Speaking" (Subheadline
  semibold muted, id `voice-listening`); at the right the trip's count "1 of 7 packed" (id `voice-progress`).
- The big card (card fill, 1.2 pt green border, radius 14, padding 16): the place (Title 3 semibold green, id
  `voice-place`) and the thing as said (Large Title bold ink, up to 3 lines, shrinking to 60 %; id
  `voice-current`).
- **Said** — the last line it spoke (Callout, id `voice-said`) — and **Heard** — what it heard, in quotes (id
  `voice-heard`): a word it misheard can be seen.
- At "once more?" the card says "That was everything" over "1 left for later — once more?", and the Packed button
  reads **Once more** (same id).
- At the bottom, outside the scroll, always there: the five words as buttons, 50 pt tall (Apple's large button
  — to be hit while carrying things), Title 3 semibold, radius 12: **Packed** (filled green) and **Skip**;
  **Later** and **Where** (outlined green); **Stop** (outlined red) on a line of its own. Ids
  `voice-word-packed`, `-skip`, `-later`, `-where`, `-stop`. A tap does what the word does (and counts as tapped,
  not heard).

When it is over (Stop, the end of the list, or cut short): the word buttons go; **Done** (filled green, header,
id `voice-done`) closes the panel (and so does a swipe down). The card says the last words it spoke (Title 3,
id `voice-said`), what it did — "Packed 2 · set aside 1 · later 1" (id `voice-summary`), **his measure** —
"Understood 6 of 7 times" (heard words understood / everything heard that was taken as an answer or a miss;
"· 2 tapped" when buttons were used; "Nothing heard" when none; id `voice-understood`), and the time — "Took 2
min 10 s · 3.1 things a minute" (packed + skip + later per minute; id `voice-time`); then "Left for later: …"
(id `voice-later`, only when some were) and, under the card, every answer in order, one line each:
"Toothbrush · packed · “packed it”", "Passport · skip · tapped" (ids `voice-log-0…`). Nothing of a walk is
stored: it lives as long as its panel.

### How he evaluates it (the test)

It is kept only if, on a real trip: it understands him **at least 9 times in 10** (the panel's "Understood N
of M times", and the log shows each miss), it is **faster than tapping** (the panel's time and things a
minute, against packing the same kind of list by hand), and **he wants to use it again**. Otherwise it is
removed and the decision log says so. Until then it is labelled a test on the panel, in How it works and in
What's new.

### Tests

- Model (`Core/Tests/PackingLibraryTests/VoiceWalkTests.swift`, 15, invented things):
  `testEachOfTheFiveWordsIsUnderstoodAsItIsWritten`, `testWhatIsHeardIsMatchedForgivingly` (31 sayings),
  `testOtherWordsAreNotUnderstood` (incl. "no", "wait", "back"), `testTheFirstWordWinsAndTheLongestPhrase`,
  `testTheListIsOneListAndEveryPhraseCanBeHeard` (no phrase in two lists, each written as heard, each
  understood), `testTheWalkGoesFromWhereAndLeavesOutWhatIsDone`, `testAWalkCanStartAtAPlace`,
  `testAThingOfSeveralSaysHowMany`, `testTheWalkSaysThePlaceThenTheThingAndTheCountAtEachNewPlace`,
  `testEveryFiveThingsInOnePlaceItSaysTheCount`, `testTheEndOfTheListSaysSo`, `testALineTickedMeanwhileIsPassedOver`,
  `testItCountsWhatItUnderstoodAndWhatWasTapped`, `testWhatWasLeftForLaterIsAskedOnceMore`,
  `testOnceMoreCanBeDeclinedAndOnlyAsksForWhatStillWaits` (planted fault: never ask once more → both red, and
  `testEveryFiveThingsInOnePlaceItSaysTheCount`).
- UI (iPhone only — each skips on the Mac, which has no button): the speech is a fake (`ScriptedVoice`), chosen
  under ANY `-uiTesting…` launch, so no test opens a microphone. `-uiTestingVoice "a,b,c"` makes it hear those
  words, one after each thing said (a beat each); `-uiTestingVoice ""` hears nothing (the buttons drive);
  `-uiTestingVoiceRefused` refuses the microphone; `-uiTestingVoiceStartAt <place>` plays a place code opened —
  at launch and each time the app comes back to the front (under the tests the setting starts on).
  - `testPackByVoiceWalksTheTripByTheWordsItHears` — heard "Packed it, hello, skip, next, where is it, pack,
    stop": the panel ends "Stopped. 2 of 6 packed.", "Packed 2 · set aside 1 · later 1", "Understood 6 of 7
    times", "Left for later: Phone charger", the six log lines; Done; the trip "2/6 · 1 set aside", the
    Toothbrush and the Headlamp ticked, the Passport set aside, the Phone charger neither.
  - `testPackByVoiceButtonsDoWhatTheWordsDo` — `voice-start` after the Sorting field on its line, as tall (±4),
    on the screen; the Toothbrush in the Bathroom cabinet first, "7 to pack.
    Bathroom cabinet. Toothbrush.", "0 of 7 packed", five word buttons; Packed → the Passport, "Bathroom cabinet
    done, 1 of 7. Chest of drawers. Passport."; Skip → "Phone charger."; Later → "Chest of drawers done, 1 of 6.
    Garage. Headlamp."; Where → "Garage. Headlamp." and no move; Stop → over, no word buttons, "Stopped. 1 of 6
    packed.", "Nothing heard · 5 tapped"; Done; the trip "1/6 · 1 set aside". Pictures `voice-trip-button`,
    `voice-panel`, `voice-over`.
  - `testPackByVoiceSaysWhyItCannotStart` — refused: `voice-start-needs` names the microphone and no panel
    opens; after Tick everything: "Everything on this trip is packed or set aside." and no panel.
  - `testPackByVoiceGoesOnceMoreOverWhatWasLeft` — heard later + six packed: "…6 of 7 packed. 1 left for later —
    once more?", the card says the question, Stop still there; Once more → "Once more. Bathroom cabinet.
    Toothbrush."; Packed → "That was everything. 7 of 7 packed.", "Packed 7 · set aside 0 · later 0", the trip 7/7.
    Planted fault: never ask once more → "it did not offer once more". Picture `voice-once-more`.
  - `testAPlaceCodeStartsPackByVoiceAtThePlace` — `-uiTestingVoiceStartAt garage`: opening the trip opens the panel
    by itself at Garage · Headlamp, "7 to pack. Garage. Headlamp.", `voice-autostart` on; Stop, switch it off, Done;
    away and back (the code again): no panel. Planted faults: the place ignored → "…'Toothbrush'"; the switch
    ignored → "switched off, a place code still started Pack by voice". Picture `voice-place-start`.
- Not covered by any test (judged on his iPhone): the real voice and recognition, AirPods, a call cutting in,
  Packing put away, a narrow iPhone's "Voice".

### Open questions (part 10)

- "Next" was made **later** (moves on, unticked); "done" and "yes" are **packed**. If he uses a word the list
  does not have, the log shows it — add it to `VoiceWord.accepted` (one place).
- Wiring part 3's link to `VoiceStarts` is left for the merge (described above); until then only the tests play it.

## 11. Decision log

| Date | Decision | His words / reason |
|---|---|---|
| 7 Oct 2026 | No PackPoint-style features (trips from the calendar, a daily weather strip, starter lists, trip types, several places per trip, country basics, per-traveller views, Lock Screen progress) | "None of these ideas are good enough for our splendid app." |
| 7 Oct 2026 | No race trips made from the training plan | Races happen too seldom. |
| 7 Oct 2026 | No bag balancer (moving things between bags to meet airline limits) | Not worth it. |
| 7 Oct 2026 | No gear wear counted from Apple Health (kilometres per pair of shoes) | He runs in different shoes. |
| 7 Oct 2026 | No Home Screen widget | His "No" on the timeline. |
| 7 Oct 2026 | No second shared field test ("Packing Quest 2") | Not needed; move on. |
| 7 Oct 2026 | No NFC stickers on places (the printed code stays) | "Let's skip the NFC." |
| 7 Oct 2026 | Door check by a time he sets | Chosen over location and the car. |
| 7 Oct 2026 | Return saves a thing's page; ⌘N carries over the choices; the keyboard work is Mac only | His three answers. |
| 7 Oct 2026 | Voice in English; vault folder `Areas/Travel`; Apple Health versions may be uploaded from his Mac | His answers. |

## Open questions

- Part 7 (Apple Health), where the code differs from the design or decides what it left open: (1) who "him" is —
  SETTLED the same day: "This is me" in Your choices → Owners; only while nobody is marked, the name on most of his
  things, and the card asks; (2) a refusal cannot be read from Apple Health, so "not allowed"
  is shown when no workout of any day is readable; (3) the settings path is the iPhone's real one, "Settings →
  Privacy & Security → Health → AMS Packing"; (4) a triathlon counts as its swim, ride and run; (5) a swim
  without a location counts for either context; (6) a line for Outdoor-or-Race with only workouts of the other
  context is left as it is (it may have been the race), and with no workout of its kind at all is "didn't use";
  (7) any template that is no workout wins as the common base does; (8) "Use these" says under it what it marked;
  (9) Apple's write-permission text is there although nothing is written.

- "Change" for sections (part 2) was taken as the ORDER of the sections; if he meant something else, change part 2.
- "The road to 1.0" (all web-app features in, a real trip, a real restore, a quiet week): kept or dropped — his word
  is pending.
