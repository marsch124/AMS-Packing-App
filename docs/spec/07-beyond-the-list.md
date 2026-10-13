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
| 8. A trip page in his Obsidian vault | 0.70 | built |
| 9. Kits — things that hold things | 0.70 | built (0.70) |
| 10. Hands-free packing (a test version) | 0.71 | built (a test, iPhone only) — specified below from the code |
| 11. Decision log | — | kept here |
| 12. Reminders on a template | 0.70 | built (branch work/reminders070) |
| 13. His lists changed inside their drop-downs | 0.69 | built (branch work/ddedit069) |
| 14. Only on some trips, set once on the thing | 0.73 | built (branch work/cond073) |
| 15. Batteries and To charge | 0.75 | built (branch work/battery075) |
| 16. Take a break and messages when a trip moves on | 0.77 | built (branch work/break077) |

Parts 1–6 are specified in their screens' chapters by the version that builds them; their summaries here point
there. Parts 7–10 are specified in full below (part 8 from the code since 0.70).

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
   everything kept there). NFC stickers were planned and dropped the same day ("let's skip the NFC"). On the iPhone
   a code that opens a trip being packed also starts Pack by voice at that place (part 10). → spec 05/06.
4. **Search finds notes.** Your things and Search match a thing's own Notes and the notes its templates keep for
   it; the matching note shows under the name. → spec 05.
5. **Bag pockets and "Where is my …?"** Bags have pockets; a thing a usual pocket; a trip line the pocket it went
   into; Siri and Search answer bag + pocket — for a thing inside a kit, the kit and where the kit is (0.73: "In the
   Camp pouch, in the Day pack (front pocket)."). → spec 03/05/06.
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
  a version without it would show "not allowed" and say nothing else. The fast lane (`tools/quick-release.sh`,
  12 Oct 2026, spec 06 §28) makes the same ship file and stops the same way — on the archive, and in a dry run on
  the exported app too.
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

**Built in 0.70** (`PackingLibrary/VaultPage.swift` — the page and the marks; `App/Sources/Store/Vault.swift` —
`VaultShelf`, the folder and the writing, Mac only; `App/Sources/Screens/VaultCard.swift` — the button on the trip;
spec 03 "The trip's page in his vault" has its every size and id).

**Where the button is** (0.73, his ask of 12 Oct 2026): **Send to Obsidian** is at the FOOT of a reviewed trip,
under Save as Excel and Share and in their style (`WideButtonLabel`, the whole width, a drawn stone as its mark),
with its status line — and on the Mac the folder and Change — small under it; only Delete trip comes after it.
From 0.70 until then it was a card FIRST on a reviewed trip, above Check before you go. What it does did not
change.

### What he gets

When a trip's review is saved — and whenever he presses **"Send to Obsidian"** on a reviewed trip — the trip
becomes one Markdown page in the folder he picked once (his choice, 7 Oct 2026: the vault's `Areas/Travel`),
named `<yyyy-mm> <trip name>.md`. Writing it again replaces the APP'S PART of the page — what he wrote on it himself
stays (his answer, 7 Oct 2026; "Keeping his own words" below). The bags' photos are copied
into `attachments/` in that same folder, beside the page. Only a REVIEWED trip has a page (`Library.isReviewed`,
the one rule: marked done or a review time on it); before the review there is nothing to write.

### The file name — `Library.vaultFileStem(trip, zone:)` + ".md"

- The month the trip began (`monthKey(startDate)`, "2026-07"); an undated trip takes the month of its review
  (the device's day of `reviewedAt`); with neither, no month at all.
- Then the trip's name made safe (`vaultSafe`): each of `/ \ : * ? " < > | # ^ [ ]` and every line break becomes
  "-" (a file name or an Obsidian link cannot hold them), runs of white space become one space, leading dots go
  (a hidden file), at most 100 characters; an empty name is "Trip". Example: "  .Hut / Lake: *wet* #2  " →
  "2026-07 Hut - Lake- -wet- -2.md".

### The page — `Library.vaultPage(tripId:zone:)`, a pure function

The same library gives the same page, word for word (no clock is read; `zone` — the device's own — only decides
the DAY a moment fell on). For the model test's sample trip it reads:

```
---
type: trip
start: 2026-07-03
end: 2026-07-05
nights: 2
place: "Testville"
transport: "Car"
season: "Summer"
templates:
  - "Common base"
  - "Hiking"
packed: "6/6"
weight: 1.9
reviewed: 2026-07-07
---

<!-- AMS Packing: start -->
# Weekend in the hills

3 Jul 2026 – 5 Jul 2026 · 2 nights · Testville

## Weather

Testville, SE · 9–21°C · rain
- Fri 3 Jul 2026: Partly cloudy · 12–19°C · rain 40 % · wind 20 km/h
…

## Bags

### Carry-on / hand luggage · 533 g · max 8 kg

![Carry-on / hand luggage, photo 1](attachments/2026-07%20Weekend%20in%20the%20hills%20-%20Carry-on%20-%20hand%20luggage%201.jpg)

### Day pack · 1.4 kg weighed · max 8 kg
…

## Didn't use

- Map

## Missed

- Power bank — onto Hiking
- Sit mat — a thing of its own, on no template

## Bought on site

- Sun hat

## Notes

- **Rain jacket**: zip broken

*Written by AMS Packing. Sending the trip again replaces what is between its markers; what you write above or below them stays.*
<!-- AMS Packing: end -->
```

- **Front matter** (YAML, what Obsidian shows as Properties): `type: trip`; `start` / `end` (the trip's dates, an
  empty value when undated — `start:`); `nights`; `place` (the trip's place, quoted); `transport`; `season`;
  `templates` (the shown names of the templates the trip's lines came from, `tripTemplates` — base and
  transport included, in the order the lines first name them; `[]` when none); `packed` ("done/total" of
  `progress`, set-aside lines left out — as the trip card counts); `weight` (all bags, kg to one decimal, "2"
  not "2.0": each bag's scale reading where weighed, else what its things add up to — `weighedBags`); `reviewed`
  (the device's day of `reviewedAt`; empty for a web-app trip marked done with no time). Free text is always in
  double quotes with `\` and `"` escaped and line breaks turned into spaces (a place like `Nice: old town` would
  break bare YAML).
- **Heading**: `# <trip name>` ("Trip" when empty), then one line: the dates ("3 Jul 2026 – 5 Jul 2026", one day
  alone when start = end, "No dates" when undated) · "N nights" (left out at 0; "1 night") · the place.
- **Weather** (always): from the forecast the trip kept (`deriveWeather`): a line "place · range · conditions"
  (the forecast's own place name, the range left out when a temperature is missing, conditions as the model
  names them — rain, snow, cold, hot, wind), then one line per day "- Fri 3 Jul 2026: label · lo–hi°C · rain N %
  · wind N km/h" (rain left out at 0 %, wind at 0). No forecast: "No forecast was kept on this trip." When
  conditions were switched on for the trip (`weatherOn`): "Packed for: rain, cold (switched on for the trip)".
- **Workouts** — only when part 7 left rows on the trip (see the hook below): "- Swim · indoor · 3 times", one
  per row, as the review showed them. No rows → no section.
- **Bags** (always): one `### <bag>` per bag of `weighedBags` (CONTAINERS order, then his own; "Other" is "Not in
  a bag"), then any bag that has photos but no lines. The heading adds " · <weight> weighed" (a scale reading)
  or " · <weight>" (the things' sum, when above 0), " · max N kg" when the bag has a limit, " · over" when over.
  Weights: under 1000 g "533 g", else "2.4 kg". Under it, each packed photo (`bagPhotos`, up to three, in the
  order taken) as a plain Markdown image, `![<bag>, photo k](attachments/<file>)` — the link percent-encoded
  (spaces and everything but plain letters, digits and `- . _ ~ /`), which Obsidian reads back. The photo's
  file: `<stem> - <bag made safe> <k>.<jpg|png|heic|gif|webp>` (from the photo's own kind); a clash gets "-2".
  A photo whose record is missing or unreadable is left out. No bags at all: "No bags on this trip."
- **Didn't use**: the lines the review marked "didn't use" (`used == false`), reminders left out, each name
  once; none → "Nothing — everything that went was used."
- **Missed**: what the review added as missed (`MISSED_AT_REVIEW_KEY`, below): "- Power bank — onto Hiking" or
  "- Sit mat — a thing of its own, on no template"; an empty list → "Nothing."; a review saved before 0.70 has
  no such record → "Not recorded: this trip was reviewed before version 0.70."
- **Bought on site**: `boughtOnSite`, each name once; none → "Nothing."
- **Notes**: the maintenance notes made on site or on the way home (`onSiteNotes`), "- **<line name>**: <note>";
  none → "No notes."
- After the front matter and a blank line, the app's part sits between two markers Obsidian does not show:
  `<!-- AMS Packing: start -->` (just before the heading) and `<!-- AMS Packing: end -->` (the last line).
- Last line inside the markers: "*Written by AMS Packing. Sending the trip again replaces what is between its
  markers; what you write above or below them stays.*"
- **His words are escaped** (`md`): `\ ` * _ [ ] < > # $ | ~` get a backslash and "==" becomes "=\=", so a
  name like "C# notes" is not a tag and "*spare*" is not emphasis. Plain Markdown: no plug-in is needed, and
  nothing goes on the page beyond what he typed into the trip.

### Keeping his own words — `Library.vaultMerge` / `vaultWrite` (his answer, 7 Oct 2026)

His words: keep his own edits on the page "if it is uncomplicated and safe". Before writing, the Mac reads the page
already there (and the side file, below) and `vaultWrite(page, onDisk:, besideOnDisk:)` decides:
- **No page yet** → the whole fresh page.
- **His page has both markers, start before end** → `vaultMerge`: everything ABOVE the start marker (after the
  front matter) and everything BELOW the end marker is kept byte for byte; the markers and what is between them are
  the fresh part. Front matter: the app's keys (`VAULT_KEYS` — type, start, end, nights, place, transport, season,
  templates, packed, weight, reviewed — each with its indented or list lines) are replaced WHERE THEY STAND; an app
  key his page lacks is added at the end; every other key, comment or line of his stays as it was, in its place (a
  key the app writes, written twice by him, is kept once). A page with markers but no front matter gets the app's in
  front of his text (then a blank line). Merging the same page again changes nothing.
- **His page has no pair of markers** (written by a version before the markers, his own page of that name, or a
  marker he deleted) → it is **never overwritten**: the app's page goes into `<name> (AMS Packing).md` beside it
  (`vaultBesideName`) — itself merged the same way when it already has markers (so his notes in it stay too), else
  replaced (it is the app's own file). The trip records `vaultWritten.beside = true` and the card says "Written
  beside your page, as <side file> · <day> — your page has no AMS Packing markers, so it is left as it is." (iPhone:
  "Written by the Mac beside your page, as …").
- Line breaks are read as "\n" (what the app and Obsidian write). The photos in `attachments/` are still replaced
  by name.

### The marks on the trip (trip extra keys — native only; synced with the trip's own record)

| Key | Holds | Written by |
|---|---|---|
| `missedAtReview` (`MISSED_AT_REVIEW_KEY`) | `[{ "name", "template" }]` — the missed things as the review saved them, each name once; `template` = the template's SHOWN name ("" = on no template) — a name, not an id: the page is read years later | `saveReview` (0.70 on), before the missed things are filed |
| `vaultWaiting` (`VAULT_WAITING_KEY`) | the ISO moment a page was asked for | `saveReview` (the review's own moment); the iPhone's Send (`askForVaultPage` — refused for a trip not reviewed) |
| `vaultWritten` (`VAULT_WRITTEN_KEY`) | `{ "file", "at", "beside"? }` — what the Mac wrote last; `beside: true` when it went into the side file | the Mac after a write (`vaultPageWritten`, which also takes `vaultWaiting` away) |
| `healthWorkouts` (`TRIP_WORKOUTS_KEY`) | `["Swim · indoor · 3 times", …]` | Written by Save review on the iPhone (`setHealthWorkouts`, since the merge of parts 7 and 8): the rows its "From Apple Health" block showed, exactly as shown (`ReviewHealth` hands them to `ReviewScreen`); nothing read (the Mac, a refusal, no workouts) writes nothing and keeps an earlier save's rows (the Mac has no Apple Health: this key is how its page learns them; `testTheReviewsAppleHealthRowsFillTheWorkoutsSection`) |

`tripsWaitingForVault()` = the reviewed trips carrying `vaultWaiting`. A shared trip leaves all four behind
(`justTheList` — his review and his vault are his). Start a new trip from this one never copies them (it builds a
fresh trip). They are trip-level keys, so they travel on the trip's head record — a tick never touches them.

### Where it is written — the Mac (`VaultShelf`)

The folder lives on the Mac, so the **Mac** writes the page:
- **On the Mac, Send to Obsidian** writes at once. Without a folder it opens the system's folder picker
  (`.fileImporter`, folders only) and writes as soon as one is picked. The folder is kept as a security-scoped
  bookmark (`ams.vault.bookmark`, its name in `ams.vault.name`, this Mac only), as AMS WatchLater keeps its
  vault; the Mac app carries `com.apple.security.files.bookmarks.app-scope` for it (both entitlements files and
  project.yml). **Change** (beside "Folder: <name>") picks another.
- **Automatically**: whenever the library changes on the Mac — at launch, when a sync brings the iPhone's review
  or its Send, and right after a review saved on the Mac — every waiting trip's page is written, on the next turn
  of the main loop (`LibraryModel.library`'s `didSet` → `VaultShelf.libraryChanged`). Only with a folder chosen;
  without one the trips stay waiting and the card says so.
- **A write**: the photos first (`attachments/`, created when needed), then the page, each written whole
  (`.atomic`) through an `NSFileCoordinator` (Obsidian or a sync service may be reading the folder) — the page as
  `vaultWrite` merged it with what was on the disk; then the trip is marked written (with `beside`). Nothing else in
  the folder is touched or deleted.
- **A folder that has gone away** (the bookmark cannot be resolved, or the folder is not there): the folder is
  forgotten, the card says "<name> can no longer be found. Choose the folder again.", and Send asks for one —
  then writes. Any other failure: "The page could not be written into <name>." — the trip stays waiting and is
  not tried again until the library changes (no loop).
- **The iPhone never writes**: its Send marks the trip waiting for the Mac (see spec 03 for the words).
- **Under the tests** nothing of his is read or written: no bookmark, no remembered folder. `-uiTestingVault
  <name>` = a throwaway folder of that NAME (no "/", no leading dot) in the app's own temporary folder, emptied
  at launch, not chosen until the picker is "answered" by it (no test can drive the system's panel);
  `-uiTestingVaultChosen` = chosen from the start. After a write the app reads the folder back from the disk
  into `trip-vault-check` (the files A–Z, "===", the page's lines before its start marker) — the Mac's test
  runner is sandboxed apart from the app and cannot look into the app's folder.

### Tests

Model `VaultPageTests` (20, invented data — the sample trip "Weekend in the hills", 3–5 Jul 2026, Testville):
`testTheSampleTripsPageHasItsNameFrontMatterAndSections` (file name, the whole front matter, the order of the
sections), `testEachSectionSaysWhatTheTripRecorded` (every section line for line),
`testTheBagsPhotosAreCopiedBesideThePage`, `testThePageIsTheSameEveryTime`, `testOnlyAReviewedTripHasAPage`
(a web-app "done" counts), `testTheDayOfTheReviewIsTheDevicesDay` (23:30 UTC is the next day in Sweden),
`testAnUndatedTripIsNamedByTheMonthOfItsReview`, `testNamesAreMadeSafeForAFileAndForMarkdown`,
`testAnOlderReviewSaysMissedWasNotRecorded`, `testWorkoutsFromAppleHealthGetASectionOfTheirOwn` (the hook),
`testATripWithNothingOnSiteSaysSo`, `testASavedReviewAsksForThePageAndKeepsWhatWasMissed`,
`testTheMacWritingThePageAnswersTheWish`, `testOnlyAReviewedTripCanAskForAPage`,
`testTheMarksTravelWithTheTripButNotWhenItIsShared`; keeping his words (5, each seen red with a planted fault):
`testAResendKeepsHisWordsAboveAndBelowByteForByte` (fault: the text below the end marker dropped),
`testHisOwnFrontMatterKeysAreKept` (fault: his keys dropped), `testAPageWithoutMarkersIsNeverOverwritten` (fault:
a page without markers written over — also an end or a start marker deleted, and his notes in the side file kept),
`testAPageWrittenBesideHisSaysSo`, `testAPageWithNoFrontMatterGetsTheAppsInFront`. 20 in all.
UI (`-uiTestingReviewed`: the sample's trip been and reviewed, nothing asked for): iPhone
`testOnTheIPhoneSendToObsidianWaitsForTheMac` (`trip-vault-status` → Send → `trip-vault-waiting`, the button
still enabled); Mac (GitHub's Mac, probe) `testSendToObsidianWritesTheTripPageOnTheMac` (`trip-vault-nofolder` →
Send → the test folder answers the picker → `trip-vault-written` names "<yyyy-mm> Weekend in the hills.md";
read back from the disk: the page, `attachments/… Carry-on - hand luggage 1.jpg`, and the front matter lines);
both `testASavedReviewAsksForTheTripsPage` (a review saved through the screen: the iPhone shows
`trip-vault-waiting`; the Mac, folder chosen, `trip-vault-written` and the page on the disk). Each was seen red
with a planted fault (0.70 report). Both, 0.73: `testSendToObsidianIsAtTheFootOfAReviewedTrip` (under the lowest
line, under Save as Excel and Share, as tall as Save as Excel and on its left edge, Delete trip under it; seen red
with the card back at the top).
**Not covered:** the real system folder picker and the bookmark across launches (no test can drive the panel);
a folder that has gone away; a sync bringing the iPhone's wish to an open Mac (the same `didSet` path the review
test drives).

### Open questions

- His edits INSIDE the markers are replaced on a resend (by design: that is the app's part).
- **A renamed trip** gets a page of its new name; the old page stays (the app never deletes his files). The same
  for a removed bag photo: its old copy stays in `attachments/`.
- **Workouts** come from `healthWorkouts`, which the review's Save writes on the iPhone (the key above).
- The vault folder is chosen at the trip's foot only (under Send to Obsidian, on the Mac) — there is no row for it
  in Settings.

---

## 9. Kits — things that hold things

> Built in 0.70 (`PackingLibrary/ThingKits.swift`, `App/Sources/Screens/ThingKitPart.swift`,
> `App/Sources/Screens/TripKitLine.swift`); 12 Oct 2026 (0.73): the kit part in the Mac's keyboard order, and a
> reviewed trip keeps what was inside its kits; 13 Oct 2026 (0.76): a NEW kit starts with Check before each trip on
> (below, "A new kit starts checked"). Written from the code; where it differs from the design of 7 Oct, the
> difference is under *Open questions*. Details per screen: spec 01 §1.12 (the keys), 03 ("Kits", "A kit's
> line"), 05 (a thing's page item 11b and its Keyboard (Mac), Care, the table).

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
  kit counts as packed only when all inside it are ticked. A NEW kit starts with it ON (0.76, below).

### A new kit starts checked (0.76, 13 Oct 2026)

His ask: he was surprised that he could not tick what was inside a kit while packing — the switch was off. So:
- **The moment a thing becomes a kit** — it held nothing, and its first thing goes in: on its page (Add from your
  things, the Mac's Return in Find a thing), by "Make a small core" / Paste a list (a line with lines indented under
  it), or any other way (`addToKit`, `setKit`) — `kitCheck` is written **true**. One rule in one place,
  `Library.writeKit`: `check` nil (no word from him) and the thing listed no contents before → on.
- **Unless he switched it off on that thing before.** His "off" is kept as `kitCheck: false` — written whenever he
  switches it off (the page's switch, Space on the Mac, `setKitCheck(false)`, `setKit(check: false)`) — and it stays
  on the thing even when it is emptied (the other kit keys go), so a kit made of it again starts OFF. Switched on
  again by him, it is on.
- **Kits made before 0.76 are left exactly as they are** (his data): their switch is off with no word stored
  (absent), and adding to them, taking out, putting back or taking a thing out for good changes nothing. Only an
  old kit emptied completely and filled again counts as a new kit (it then starts on). Nothing is migrated.
- **On the page** (`KitDraft`): a thing that held nothing when the page opened shows the switch ON as its first
  thing goes in (`KitDraft.add`) — before Save, so he sees what Save will keep — unless it carries his off, or he
  pressed the switch on this page already. His press goes through `KitDraft.setCheck` (the switch's binding, Space
  on the Mac); Save passes the switch as his word when he pressed it or it changed (a new kit's ON), else nil (the kit
  keeps its own). He can switch it off before or after Save, as before.
- On the trip nothing new: a checked kit shows its things with small ticks, open until packed, "Tick what is inside
  first: N to go." (below, "On a trip").

### Where it is kept

On the KIT, in three `extra` keys — `kitContents` (ids, his order), `kitOut` (ids taken out), `kitCheck` (true; since
0.76 also false = he switched it off himself, kept when the thing is emptied; absent = never said) —
and, on a trip's kit line, `kitTicked` (the ticked ids while the line is not ticked). So the web app's model sees a
plain thing (parity 211/211), and a kit is stored, synced through iCloud, backed up and restored with the thing,
as every `extra` key is. Which kit holds a thing is read from the kits (`kitIndex`): in id order, a thing in the
first kit that lists it. Since 0.73 a reviewed trip keeps a copy too (below, "A past trip"): on each kit line
`kitThen`, and on the trip `kitsKept` — trip and line keys, so they travel in the trip's own records.

### On a thing's page (spec 05, item 11b)

Under Weight: **Inside** — the things in it (name, weight, what is worth saying: out of date, runs out within 60
days, care due), each with Take out / Put back and ✕ (out for good); **Add from your things** (an inline list:
search, the first 8 that can go in, A–Z; one in another kit says so and moves); **Check before each trip**; **With
what is inside: 170 g**. A thing inside a kit shows **In a kit** instead: "Inside the Wash bag", **Taken out for
now**, and — when it is ALSO on a template on its own — "Also on Common base on its own — a trip packs the Wash
bag instead." Everything waits for Save; Cancel leaves the kit as it was.

**The Mac's keys (0.73, 12 Oct 2026).** The kit part is in the page's Tab order like every other field (spec 05,
Keyboard (Mac)): after Weight, each thing inside — its **Take out / Put back**, then its **✕** — then **Add from
your things**, the list's **Find a thing** while it is open, **Check before each trip**; then Brand. Space presses a
button or switches a switch; Space on Add from your things opens the list with the cursor in Find a thing, where
typing finds, ↑ ↓ light a thing (the page's orange at 18 % behind it), **Return adds the lit one** (the list stays,
the search empties, the page is not saved) and **Esc closes the list** only (the focus back on Add). ✕ by Space
keeps the focus where it was: the ✕ of the thing that came up into its place, else the one before, else Add. A
click on any of them moves the page's focus there, as on the other fields.

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
- **Before you go**'s flags look inside kits: "Lighter, in the Camp pouch" in a cabin bag is not allowed on board;
  "Plasters, in the Camp pouch" runs out before you are home; on a plane trip, "Power bank, in the Camp pouch" in a
  CHECKED bag must go in the cabin (0.76, part 15).

### A past trip — what was inside then (0.73, 12 Oct 2026)

A trip line is a copy, and since 0.73 what is inside a kit line is too. **The moment** is the trip's review
(`saveReview`) — the moment the rest of a trip is kept for good (what was missed, the vault page asked for, the
lists' history; `followThing` stops at a reviewed trip). At the FIRST review (`keepKitsAtReview`, only when the trip
was not reviewed before) each kit line keeps what is inside its kit now — `kitThen`: `[{id, name, qty (how many),
weight (grams each), out: true (taken out)}]`, his order — and the trip is marked `kitsKept: true`. From then on:
- the trip shows what was inside THEN (`kitOnLine(kept:)`, `kitLines`): "3 inside", "1 missing: Lighter" as at the
  review, whatever the kit holds now, even when the kit is renamed, changed or deleted (the line is the kit then);
- the fold says **"As it was when the trip was reviewed"** (Footnote muted, `trip-line-<n>-kit-then`) and shows
  each thing's name (`trip-line-<n>-kit-<k>-name`), muted, struck through when it was taken out — no Take out /
  Put back (they would change the kit as it is now), no ticks (`check` false; `setKitContentTicked` refuses), no
  warnings (they are about now); the kit's own tick is a plain tick;
- the Bags card, a bag's trips and the vault page weigh the kit as it was (`linesWithKitWeights(trip:)`);
- a line of that trip that kept nothing held nothing then: a thing that became a kit later is a plain line there;
- a second review keeps what the first kept.
Live trips (not reviewed) keep following the kit. **A trip reviewed before 0.73** has no mark and no copy: it
shows the kits as they are now, as it always did — and a later review keeps nothing for it. **Before you go**
still reads what is inside each kit NOW (as it reads every thing now, `thingNow`). A shared trip arrives not
reviewed (`justTheList` drops `kitsKept` and every `kitThen`); "Start a new trip from this one" drops `kitThen`
(the new trip follows the kits). Back up, restore and iCloud carry both keys with the trip's and the line's own
records, as every `extra` key.

### Weight and Care

A kit weighs its own weight plus what is inside it now (each content × its how-many; taken out not counted) — on a
reviewed trip, what was inside it then (above): on the Bags card and a bag's trips, in Care's heaviest things and what each template weighs, and in the table's
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
again carry no ticks inside a kit. Since 0.73 (18): `testAReviewedTripKeepsWhatWasInsideItsKitsAndALiveTripFollowsThem`
(the review keeps names, how many and taken out; the live trip follows a rename, a removal, an addition and a new
how-many; the bag weighs 518 g then, 798 g now, and a bag's trips agree; a checked kit asks for no ticks; a thing
made a kit later held nothing then; a second review keeps the first copy; a deleted kit still says what was in it),
`testATripReviewedBeforeKitsWereKeptShowsThemAsTheyAreNow`,
`testWhatAPastTripKeptIsStoredSyncedBackedUpAndRestoredButNeverSentOrStartedAgain`. Each seen red with a planted
fault: the review keeping nothing (two of the three red, e.g. "("["Lighter", "Paracord", "Map"]") is not equal to
("["Lighter", "Spare cord", "Plasters"]") - what was inside then, in his order"), and the shared trip and the trip
started again keeping the copy (3 failures, e.g. "("["Lighter", "Spare cord", "Plasters"]") is not equal to
("["Lighter", "Spare cord"]")").

UI (`-uiTestingKits`: the sample + a Camp pouch on Hiking with a Lighter, Spare cord and Plasters, and a Wash bag on
no template, checked before each trip, with the Toothbrush — still on Common base — and Soap):
`testAKitsPageHoldsItsThingsTakesOneOutAndAddsAnother` (190 g; the cord taken out → 110 g; the Map added → 170 g;
kept after Save; the trip says "1 missing: Spare cord"), `testAKitIsOneLineOnATripAndWeighsWhatIsInside`,
`testAKitCheckedBeforeEachTripIsPackedWhenAllInsideIsTicked`, `testAThingInsideAKitSaysSoAndIsTakenOutFromItsPage`.
Each was seen red with a planted fault: Save not writing the kit ("Save did not keep the map inside"), the bags not
weighing the contents ("… '2.1 kg'"), the kit's tick not refused ("the kit was packed before what is inside it was
ticked"), Save not writing taken out ("taken out on its page, it is not missing on the trip: ''"). The thing page's
kit part also ran on the Mac (probe). Since 0.73 (the sample has a second trip, "Autumn in the hills", two months
ahead, `trip-row-1`): `testAReviewedTripShowsWhatWasInsideItsKitThen` (the first trip reviewed; then the cord taken
out and the plasters ✕'d on the pouch's page; the reviewed trip still "3 inside", nothing missing, its fold "As it
was…" with the Plasters and no Take out; the trip ahead "1 missing: Spare cord", "1 inside") and, Mac only,
`testTheKitPartIsWalkedByTheKeys` (Weight → Tab → row 0's Take out, ✕, row 1's Take out; Space takes the cord out;
Tab → row 1's ✕, row 2's Take out, ✕; Space removes the plasters and the focus stays on row 1's ✕; Tab → Add; Space
opens the list with the cursor in Find a thing; "map" lights the Map, Return adds it, the page stays, the search
empties; Esc closes the list, focus on Add; Tab → Check before each trip, Space on; Tab → Brand, Shift-Tab back;
Return saves; reopened, all kept). Both seen red with a planted fault: the review keeping nothing (iPhone: "the
reviewed trip shows the pouch as it is now: 'Camp pouch · 1 inside, Carry-on / hand luggage'"), and the kit rows
left out of the Tab order (GitHub's Mac probe: "Tab did not go on to thing-kit-row-0-out"); green on GitHub's Mac
with `testTheThingPageTabsThroughEveryFieldInOrder` and the kits tests. 0.73 also: `-uiTestingKits -kitsUnderWay` (the trip under way, the Camp pouch
usually in a Day pack's Front pocket — pockets Main, Front pocket) for
`testWhereIsAThingInsideAKitNamesTheKitAndWhereTheKitIs` (spec 03).

**A new kit starts checked (0.76).** Model `ThingKitsTests.testANewKitStartsCheckedBeforeEachTripUnlessHeSwitchedItOff`
(the Map made a kit by `addToKit` → `kitCheck` true, its trip line `check` true and its own tick refused; more in, one
taken out → still on; switched off → false, kept when emptied, filled again → still off, and kept by the stored
records; switched on by him → on; a thing made a kit with `check: false` (his word on the page) → off; a kit with no
word (made before 0.76) given a thing, one taken out, removed → no key, its trip line unchecked) and
`SmallCoreTests.testANestedLineMakesAKit` (the pasted "Cable pouch" is checked). `testAKitHoldsThingsInHisOrderAndAThingIsInOneKitOnly`
now asserts that an emptied kit keeps his off and that one that was on leaves no key. The fixtures whose kits are NOT
checked say so (`check: false`: the Camp pouch of `ThingKitsTests` and of the `-uiTestingKits` sample, both kits of
`BatteriesTests`, the pouch of `PocketsTests`' trip). Seen RED with a planted fault: `writeKit` not starting a new
kit on ("("nil") is not equal to ("Optional(PackingCore.JSONValue.bool(true))") - a new kit does not start checked
before each trip", "the new kit packed before what is inside was ticked", "a new kit from a pasted list is not
checked before each trip (0.76)"); and his off forgotten when the kit is emptied ("emptied, his off was forgotten",
"he switched it off, and it came back on"). UI `testANewKitStartsCheckedBeforeEachTrip` (plain sample: the Rain
jacket's page offers no switch while it holds nothing; the Map added from Add from your things → `thing-kit-check`
on before Save; kept after Save; the trip a month ahead shows `trip-line-5-kit-0-tick` under the jacket and "1 to
go"; pictures `kit-new-checked`, `kit-new-trip-ticks`, day and night on the iPhone). Seen RED with the page's
`KitDraft.add` not switching it on: "the new kit does not start with Check before each trip on". Green on GitHub's
Mac too (the probe of part 15), with `testTheKitPartIsWalkedByTheKeys` — Space on the switch now goes through
`KitDraft.setCheck`.

### Open questions

- **No `insideKitId` on a content** (the design had it): ONE record holds a kit's whole state, so the two sides
  can never disagree; a content's kit is read from the kits.
- **A content on a template whose kit is not on the trip** brings its KIT (the design said only "never a separate
  line"). Leaving it out would have lost it silently. His word welcome.
- **A trip made before a thing went into its kit** keeps that thing's line until a rebuild (Trip settings → Save).
- ~~**"Where is my …?"** (part 5) should answer "Camp pouch, in the backpack" for a thing inside a kit~~ — CLOSED
  in 0.73 (his ask: "in <the kit>, in the <bag>"): Siri and Search name the kit and where the
  KIT is — its line on the trip under way, else its Usually packed in and pocket: "In the Camp pouch, in the Day
  pack (front pocket)."; taken out: "Taken out of the Camp pouch." and the thing's own place, if it has one. Search's
  card names the kit on a line of its own (`search-where-kit`). Details: spec 03, "Bag pockets on a trip, and Where
  is my …?"; spec 06 §3b.
- **Resolved 12 Oct 2026 (0.73)** — ~~**The Mac's keys** (part 1): the kit part's buttons and switches are not in
  the page's Tab order yet.~~ (Taken out for now, Add from your things and Check before each trip had joined it in
  the merge of 0.69/0.70.) Each thing inside — Take out / Put back, then ✕ — and the list's Find a thing are in it
  too; Space presses, and in Find a thing ↑ ↓ light a thing, Return adds it, Esc closes the list (above, "The Mac's
  keys"; spec 05, Keyboard (Mac)). Pinned by `testTheKitPartIsWalkedByTheKeys` (GitHub's Mac).
- **Resolved 12 Oct 2026 (0.73)** — ~~**Past trips** show what is inside their kits as it is NOW (a trip line is a
  copy; its contents are not).~~ The review keeps a copy on each kit line (`kitThen`, the trip marked `kitsKept`):
  a reviewed trip shows what was inside then; live trips follow the kit; a trip reviewed before 0.73 keeps today's
  behaviour (above, "A past trip").
- **A trip over but not reviewed** still follows its kits until it is reviewed (the review is the moment a trip is
  kept for good; a trip's end date writes nothing). Reviewed weeks later, it keeps the kits as they are at the
  review. His word welcome if the day the trip ended should count instead.
- **The table's kit weight** is not typed in; its own weight is on its page. Not covered by a UI test (the model's
  sort and filter are).
- **A kit made before 0.76 that he had switched off** cannot be told from one never switched (both stored as
  absent): emptied completely and filled again, it starts ON. Left so on purpose — his kits are not migrated.

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
  **Wired to part 3's link** (merged in 0.71; made reliable, and the decision moved into the model, in 0.73):
  `HomeScreen`'s `onChange(of: model.placeToOpen)` asks `PlaceOpening.of(code:in:today:)`
  (`PackingLibrary/PlaceLinks.swift`). When the code opens a trip being packed (`packingTrip`), it sets, inside
  `whenFree`, `openedPlace` + `opened` (the trip, on the place) and `voiceAsked` = `PlaceOpening.voiceStart`
  (`VoiceStartAt`: that trip, and the place as his list spells it today). Home's trip window, as it appears
  (`TripScreen(...).onAppear` → `startVoiceAsked(on:)`), takes `voiceAsked` once (it is cleared there and when the
  window closes) and — iPhone only, `#if os(iOS)`, and only for that trip with `openedPlace` set — calls
  `VoiceStarts.shared.startVoiceAt(place:tripId:)`; that window's Sorting row then takes the request.
  `voiceStart` is nil — nothing starts — for a code that shows what goes back there (`.goingBack`), everything kept
  there (`.keptThere`), a label whose place is gone, and for **Open** on the place's page in Your choices (not a
  code: `byCode` false; it opens the trip on the place and nothing more).
  **Why not at once** (0.71–0.72 asked as the code came in): with that trip already on screen — opened from Trips,
  or as Home's own window, which `whenFree` closes and opens again 0.8 s later — the trip window on its way out
  took the request and lost it with itself: the trip opened on the place and no walk started (and on the device a
  walk could begin in the closing window). Asked from the window that will stay, it always starts. The Mac has none
  of this (no `VoiceStarts`): a code opens the trip on the place, as part 3 says.
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
  - The link itself (0.73, part 3's wiring): `testAPlacesCodeStartsPackByVoiceWithItsTripAlreadyOpen` —
    `-uiTestingPlaces soon -uiTestingVoice "" -uiTestingOpenOnReturn AMSPACKING://P/G4R` (the link handed to the
    RUNNING app each time it comes back to the front after being put away — as the Camera hands it over;
    `XCUIApplication.open` launches the app afresh, so it cannot play a trip already open). The trip opened from
    Trips, no panel; away and back: the panel opens by itself at Garage · Headlamp, "7 to pack. Garage.
    Headlamp."; Stop, Done, the trip on the Garage (`trip-place-filter` "Garage"); away and back again (the trip
    now Home's own window, closed and opened again): the same; Stop, switch `voice-autostart` off, Done; away and
    back: the trip on the Garage, and no panel. Run day and night. Picture `voice-place-code-trip-open`. Planted
    faults: the request made as the code comes in (0.71–0.72) → "the place code did not start Pack by voice on its
    trip already open (from Trips)"; the switch ignored → "switched off, the place code still started Pack by
    voice". And
    `testAPlacesCodeOpensTheTripBeingPackedOnItsLines` (part 3, `-uiTestingOpen` at launch) sees the panel start at
    the Garage on the iPhone before it checks the trip's place lines.
  - Model: `PlaceLinksTests.testAPlacesCodeStartsPackByVoiceOnlyOnTheTripBeingPacked` — a code (any case) opening
    the trip being packed → `voiceStart` = that trip at "Garage", and the walk from there begins with the
    Garage's lines; Open on the place's page → the same trip, no `voiceStart`; everything kept there, an unknown
    label, what goes back there → none. Planted faults: `byCode` ignored → "Open on the place's page started
    Pack by voice: it is not a code"; a trip being unpacked counted → "what goes back to the place started Pack by
    voice".
- Not covered by any test (judged on his iPhone): the real voice and recognition, AirPods, a call cutting in,
  Packing put away, a narrow iPhone's "Voice".

### Open questions (part 10)

- "Next" was made **later** (moves on, unticked); "done" and "yes" are **packed**. If he uses a word the list
  does not have, the log shows it — add it to `VoiceWord.accepted` (one place).
- ~~Wiring part 3's link to `VoiceStarts` is left for the merge~~ — **closed (0.73):** wired as described under
  "A start place" above (`PlaceOpening.voiceStart`, asked once Home's trip window is up), held by a model test and
  a UI test that hands the link to the running app with the trip already open.

## 12. Reminders on a template

His idea, 7 Oct 2026: "Add a list of simple reminders for each Template" — for a run, prepare the course, prepare
napkins, charged glasses and watch; for a bike the same plus the gear changer, the power bank and the crank sensor.

### Built on what was there

The web app has always known a reminder: a catalogue item whose `itemType` is `"reminder"` (a membership may also
say `"reminder"` for one template only), put on a template by a membership, copied onto a trip as a line by
`buildTotalEntries`. The model already treated such a line as something to DO: counted in the trip's progress, but
not in the bag loads, the cabin check or the review (spec 03, Counting). The native app had no way to make one and
showed the web app's as ordinary things. So nothing new is stored: a reminder made here is that same item, and the
web app (and the parity check, 211/211 unchanged — PackingCore is not touched) read it as their own.

### What he sees

- **On a template's page**, above the things (under Find), a block **Reminders** (`template-reminders`; heading
  `template-reminders-title`, count `template-reminders-count`). With none yet it is one line: "Reminders" and a small
  outlined **Add a reminder** (`template-reminders-start`), which opens the foot.
- Each reminder is a line (`template-reminder-<n>`, `Metrics.line` high, hairline under it): with two or more, a
  **grip ≡** at its left (0.72, both devices; `template-reminder-<n>-grip`, `ReorderGrip`: hold and drag, each place
  passed one `moveReminder` at once), its name, and on the right its When in the step's own colour (made readable for day or night). A press opens it in place:
  - the name, a field (`template-reminder-name`; what was missing said under it, `template-reminder-name-needs`);
  - **When**, a drop-down (`template-reminder-when`) — applied at once; its open lines on trips still ahead follow.
    Its rows are his steps (`timeline()`) with their tools and "A new step" since 0.73 — each change made at once
    (part 13, "A reminder's When");
  - ↑ and ↓ (`template-reminder-up` / `-down`, 36-pt squares; the Mac only since 0.72) — move it one place among the
    reminders, at once; at the top (bottom) the arrow is drawn in the hairline colour and does nothing;
  - **Done** (`template-reminder-done`, the template's violet, never grey) — saves a changed name and closes;
  - last, quiet and red, **Remove reminder** (`template-reminder-remove`), which asks first: "Remove “…” from this
    template?" Keep it (`-remove-no`) / Remove (`-remove-yes`).
  - Pressing the line again closes it without saving the name; Esc closes it on the Mac.
- The foot: **Add a reminder** field (`template-reminder-add-name`) and **Add** (`template-reminder-add`), then
  **When** (`template-reminder-add-when`; the same list and tools, 0.73). Add with nothing typed says "Type the reminder first."
  (`template-reminder-add-needs`). A new reminder's When starts as the last reminder's on this template, else the
  first step one day ahead ("Day before"), else the step a new thing gets.
- While Find holds a word, the block is hidden (Find looks for things). The template's card on the Templates tab,
  the "3 of 40" of Find, Group, Arrange and the Templates tab's summary count the THINGS only.
- **On a trip**, a reminder is a line like the others, at its When, ticked the same way (and set aside with ⊘). In
  place of the bag it says **To do**, and it has no count. Sorted by Into, the reminders stand under a heading
  "To do", never under a bag. The bag weights, the cabin check and the review leave them out (as before).
- **Before you go** (top of the trip; until 0.77 **Check before you go**) lists the reminders that are due — their
  step's day (the trip's start less the step's lead days) is today or past — and not ticked, in its part **To do**
  (`trip-beforego-part-todo`, under the flags, above To charge; spec 03, "Before you go"): a tick circle, the name,
  the step under it (`trip-check-todo-<n>`; "To do · <step>" until 0.77, when the part got the heading "To do"). A
  press ticks the line, and it leaves the card. The card's count includes them. (Until 0.77 a card holding only
  reminders was the trip's green; since then green means All set, and reminders due are orange like anything left.)
  **0.75** (his yes of 13 Oct 2026: he "could not tell which template each comes from"): at the right of each, the
  icons of the templates it comes from — the trip lines' own `TemplateMarks` (spec 03, "A line" → "Where it comes
  from"), small and violet, up to three else "+N", a template without an icon as its name's first word; VoiceOver
  and the Mac's tooltip "From <names>"; id `trip-check-todo-<n>-from`; beside the button, not in it (spec 03,
  Before you go). The reminder's line in the trip's list has shown them since 0.74, before "To do".
- **Home's countdown** says the step as before, now with things and reminders apart — "≥1 week ahead: 7 to pack,
  1 to do, now" (a Preparations step says all of it "to do") — and, when reminders are due, a green line
  "To do: Check the forecast · …" (accessibility value "<n> to do"). The packing notifications (Remind me to pack)
  read the same words. That green line is ONE run of words, not reminder lines, so it carries no template icons
  (0.75: checked and left so — the card opens the trip, where each reminder shows its template).

### Rules and edge cases

- **Names.** Trimmed; blank refused; a name this template has as a reminder already (any capitals) refused ("This
  template has that reminder already."); the name of one of his THINGS refused ("That is the name of one of your
  things.") — one catalogue name is one item, and a reminder is no thing to pack.
- **The same reminder on two templates** is ONE item with two memberships, as a thing is. Adding a name he has as a
  reminder elsewhere reuses it.
- **Rename is for this template only.** A reminder that sits on this template alone is renamed in place (its open
  lines on trips still ahead follow). One that also sits on another template keeps its name there; this
  template's membership moves to a reminder of the new name (one he has, or a new one), keeping its When and its
  place. Lines already on trips keep the old name in that case.
- **When** is the template's own answer (membership `phase`; blank when it equals the reminder's own).
- **Order.** Up/down swaps the two reminders' places in the template's row order (the order a trip reads); the
  rows are numbered 0, 1, 2… again and only changed numbers are written. Things keep their places. Arrange shows
  things only (`arrangeLines` leaves reminders out); a reminder keeps its relative place when things are dragged.
- **Remove** takes the membership away; a reminder on no other template is deleted with it. Trips keep their line.
- **A new reminder item:** kind "Reminders", no bag (`container` ""), no weight, `shortList` true — so a Quick trip
  brings it too. Its line on a template with its own bag carries that bag's name, but no screen shows it.
- **Adding to a template does not reach trips already made** — as for things: Trip settings → Save rebuilds.
- **Not among his things.** A reminder that sits on a template is left out of Your things, the table, Search,
  Choose from your things and the Things counts on Home and Care (`Library.ownThings()`). A reminder on NO template
  (left by the web app) still shows in Your things, so it can be seen and deleted.
- **Progress still counts reminders** (spec 03's decision of 5 Oct, kept: they must be done before leaving), so
  "All packed" waits for them. "To pack" counts (countdown, steps) do not.
- **To do (the Actions tab) is NOT used.** Chosen 7 Oct 2026: the To do ↔ Apple Reminders link exists only for To
  buy, and a copy in To do would be a second tick to keep in step with the trip's line. The trip line is the one
  tick; Before you go (its To do), Home and the packing notifications bring it to him when it is due.

### Model (PackingLibrary/TemplateReminders.swift, Countdown.swift)

`REMINDER_TYPE`, `REMINDERS_CATEGORY`; `Library.isReminder(_:)`; `reminders(templateId:)`;
`reminderNameProblem(templateId:name:except:)` → `.blank` / `.alreadyHere` / `.aThing` / nil;
`whenForNewReminder(templateId:)`; `addReminder(templateId:name:when:)`; `renameReminder(templateId:memId:to:)`;
`setReminderWhen(templateId:memId:when:)`; `moveReminder(templateId:memId:by:)`; `removeReminder(templateId:memId:)`;
`remindersOnTemplates()`, `ownThings()` (also used by `thingRows()`); `templateSummary` counts non-reminders.
`PackingStep.todo` (reminders left on the step; `left` is things only) and its `says`; `NextTrip.left` (things only)
and `NextTrip.due` (names); `dueReminders(tripId:today:)` — every step of the timeline (the After step too: its day is
the start plus one), unticked, not set aside, in timeline then trip order; none for a trip without a start date.
Where a reminder comes from is a thing's answer, unchanged (0.75, `Library.lineTemplates(tripId:)`, spec 03 "Sorting
and grouping" → Template): a reminder is a catalogue item on its templates by memberships, its line carries
`sourceListId` and `sourceItemId`, so it maps to the template it was made from and to every other trip template
that has the same reminder; taken off a template later, the line names only the templates that still have it.
The UI-test library `-uiTestingReminders` (`SampleLibrary.reminders()`): Hiking with "Check the forecast" (≥1 week
ahead) and "Leave a route note" (Day before), its trip three days ahead.

### Tests

Model `TemplateRemindersTests` (10): the web app's own kind of item; refused names; a new reminder's When; rename per
template; order, When and remove; not among his things nor arranged; on a trip ticked but never packed, weighed or
reviewed; due reminders; a step's words; `testADueRemindersLineKnowsTheTemplatesItComesFrom` (0.75: Base's "Book a
taxi" → Base; "Charge the watch" on Running and Rowing → one line, "Running, Rowing" in the trip's order; "Check the
course" → Running with its icon "run"; Sorted by Template under Base, Running, Rowing; taken off Rowing → Running
only). Planted faults: `ownThings()` returning every item → red "Your things lists things only"; `lineTemplates`
skipping reminder lines → red "a reminder of the base template", "a reminder on two templates does not name both,
in the trip's order". UI (iPhone, light and dark): `testATemplateKeepsItsReminders` (planted: Add not adding → "the
reminder was not added"), `testATripsRemindersShowWhenTheyAreDue` (planted: `dueReminders` empty → "the countdown
does not name the reminder due"; 0.75, soft failures: `trip-check-todo-0-from` says "Hiking", and after the tick
`trip-line-7` — "Check the forecast" — names Hiking too; pictures `reminders-home`, `reminders-trip`,
`reminders-trip-line`; planted: the card given no templates and the reminder line's icons taken out → red "the
reminder due does not name its template: ''" and "the reminder's line does not name its template: ''"). The test
reads a `TemplateMarks` by its id with `marksWords` (value, else label less "From "; an Other, Group, image or
text), and a trip line's on the Mac from the line's own words as before (`fromWords`). Not covered by a UI test: Into's "To do" heading, Remove's "Keep it", the Mac (built, not
run). The When drop-down on a reminder: `testAReminderWhenIsChangedInsideItsList` (0.73, part 13).

## 13. His lists changed inside their drop-downs

> **Built in 0.69** (helper "ddedit", 7 Oct 2026) — written from the code. Screen details are in spec 05 ("His lists
> inside their drop-downs", A thing's page), spec 04 §7 (a template's row) and spec 06 §21 (`DropDown`).

His ask, 7 Oct 2026: "work on all the drop-downs so that they can be edited, changed, added, and deleted from within
the drop-downs." Part 2 (0.68) had given a Section list a pen, ↑ ↓ and Remove; this part gives the same to every
pick-one list whose choices are his own.

### Which lists

| Drop-down | Where | His list (`kind`) | Order of his | New at the foot |
|---|---|---|---|---|
| Kind of thing | thing's page | `categories` — NEW: his own list (below) | yes | A new kind |
| Whose it is | thing's page | `owners` | no — A–Z, no arrows | A new owner |
| Kept at home | thing's page | `places` | yes | A new place |
| Usually packed in | thing's page | `bags` (his own bags only) | yes (Your bags) | A new bag |
| Pocket | thing's page | `pockets` of the chosen bag | yes | A new pocket |
| When | thing's page | `phases` | yes | A new step |
| Condition | thing's page | `conditions` | yes | A new condition |
| Bag on this template | template's row | `bags` | yes | A new bag |
| When, on this template | template's row | `phases` | yes | A new step |
| When, of a reminder (0.73) | template's page, Reminders (open reminder and the foot) | `phases` — made AT ONCE | yes | A new step |
| Section of this template | template's row | the template's sections (part 2's tools) | yes | A new section (as before) |

Not included: **Care** (its choices are numbers of days, not a list of his); the trip's Sorting, Counts as (the
review) and the table's menus. (A reminder's When was left out until 0.73 — below.)

### How it works (one mechanism)

- `DropDown` keeps ONE set of row tools (`DropDownRowTools`, spec 06 §21) — the Section list's look and ids — with
  four additions: `orders` (no arrows for owners), `refusal` (what still uses an entry, said in place of the question,
  with OK), `open` (Open the bag) and `nameHint`. The tools a row shows, and the order Tab reaches them on the Mac,
  come from one function (`toolsOf`).
- `ChoiceDrop` (App `Screens/ChoiceDropDown.swift`) turns one held `ChoiceEdits` into a drop-down's options, tools
  and foot; the thing's page and the template's row each hold theirs (`choiceLists`) until Save.
- The model (`Core/Sources/PackingLibrary/ChoiceEdits.swift`): `ChoiceEdits` (names by key, order, removed, added —
  an added entry keyed `addedKey(n)` so it can be renamed, moved or taken back like any other), `choiceRows`,
  `choicesAsEdited`, `choiceFixed`, `choiceNameProblem`, `choiceUse`, `choiceRemoveProblem`, `addChoice`,
  `removeChoice`, `moveBag`, `applyChoiceEdits` (renames — two that swap names are parked on the way — then new
  entries, then the order, each step by the list's OWN one-step move), `applyChoiceRemovals`, `choiceValue`.
- **No second way.** Every change is the one the list's own screen makes: `renameChoice` / `moveChoice` (Your
  choices), `addChoice` / `removeChoice` (Your choices now calls these too — they were its own code until 0.69),
  `renameThing` → `renameBagEverywhere` and `addBag` / `deleteBag` (a bag), Arrange's `moveRow` (a bag's place on Your
  bags), `renamePocket` / `movePocket` / `addPocket` / `removePocket`, `applySectionEdits`.
- **Held until Save; Cancel undoes.** Save: sections, then `applyPageChoices` (pockets before bags), then the thing or
  row with its choices followed (`choiceValue`), then `applyPageRemovals`. A new place made at Kept at home's foot is
  now held too (until 0.69 it joined Your choices at once, and stayed after Cancel).
- **Remove is refused while the entry is in use** — Your choices' words (`ChoiceUse.refusal`); the page's own thing
  counts by what the page says. A pocket in use is refused too (the bag's page can still remove it — the things then
  go just in the bag). A bag is removed here only when its page would let it go without a question; otherwise the
  list says so and offers **Open the bag**.
- Rename follows everywhere, as from Your choices: things, trip lines (places, owners, kinds), "This is me" (an
  owner), a place's printed code (`renameChoice` now gives the place its code before the rename, so a code never
  given yet does not change with the name), a bag's things, rows, trips, scale readings, photos and pockets, a pocket's
  usual-pocket marks and trip lines. Steps and conditions are kept by id: only their words change.

### Kinds of thing become his list

`Library.categories()` — the app's twelve (`CATEGORIES`) until he changes one, then his own, kept in `meta["categories"]`
(a record of its own, so it syncs; in a backup as `prefs.categories`; the web app has no such list and keeps its
own words, showing a renamed kind as an unknown one). `setCategories` stores nothing while the list is the app's.
**Documents & money** and **Reminders** keep their names and have no tools (`fixedCategory`): Before you go and
a template's reminders read them by their words. PackingCore is untouched (parity unchanged).

### The Mac

The keys reach the tools as in a Section list (spec 05, Keyboard): Tab through the lit row's pen, ↑, ↓, Remove (Remove
and Keep while asked; OK and Open the bag when refused), Space or Return presses, a name typed from the keys. Every
list that takes a new entry goes by a name's START when letters are typed — now also Kind of thing, Whose it is,
Usually packed in, When and Condition ("rink" is offered as a new kind; it no longer finds Food & drink inside a word).

### Tests

Model `ChoiceEditsTests` (14): per list — a rename follows (places with their code, owners with This is me, kinds on
things and trip lines and in records and a backup, steps and conditions by id, bags with things and pockets, pockets
with their marks), a removal refused while in use (and the page's own thing counted by what the page says), the order
kept (places, bags, pockets, kinds, steps), an added entry renamed or taken back, two places swapping names, the two
fixed kinds. Planted: `choiceRemoveProblem` always nil → 11 red ("Garage is still used by 2 things" expected, nil
got); the kind's rename not carried to things → red "a thing kept the old kind".
UI (iPhone, light and dark): `testKindOfThingIsChangedInsideItsList`, `testKeptAtHomeIsChangedInsideItsListAndCancelUndoes`,
`testUsuallyPackedInIsChangedInsideItsListAndABagInUseOpensItsPage`, `testWhenIsChangedInsideItsListOnATemplatesRow`;
Mac `testHisListsAnswerTabAndSpaceOnTheMac`. Planted: (A) `ChoiceDrop`'s
`refusal` always nil → all four red "an entry in use was not refused"; (B) `applyPageChoices` writing nothing → all
four red ("the Headlamp's kind did not follow the rename", "… did not follow the rename", "the rename was not kept",
"the rename did not reach the thing's When"). Green on the iPhone in light and dark; the Mac probe (GitHub's Mac) ran
the Mac test and the Kind/Kept at home tests, the Section keys test and the two changed type-ahead tests — green
(`testADropDownPicksAsHeTypesAndOpensWithSpace` once its new name started with a letter no kind has: "rink" first
picked Reminders on its "r", as a closed list does).

### Drag and drop (0.70)

> **Built in 0.70** (helper "drag", 8 Oct 2026) — written from the code; details in spec 06 §21 (`DropDown`, "Drag and
> drop") and §2 (Your choices).

His ask, testing 0.69 (8 Oct 2026): "I like all the lists now. One can add, rename and reorder. Can we make the
reordering easier for a human by introducing drag and drop?"

- Every list of this part that has ↑ ↓ — Kind of thing, Kept at home, Usually packed in, Pocket, When, Condition, a
  thing's Section on each template, and a template row's Bag, When and Section — gets a **grip ≡** at each row's left
  (`<row>-grip`), Arrange's own hand-drawn `GripMark` (the thin grey one). So does every list of Settings → Your
  choices whose order is his (`list-<kind>-grip-<n>`). Owners stay A–Z: no grip, no arrows.
- **Hold and drag** (iPhone: hold 0.2 s first, so a swipe over a grip still scrolls; Mac: drag with the mouse). The row
  follows the finger, lifted on the card colour; each row-height passed is ONE step by the list's own `move(±1)` —
  the very call ↑ / ↓ make. So a drag changes nothing an arrow could not: in a drop-down it is held until Save (Cancel
  undoes), in Your choices it is made at once (`moveChoice`), as the arrows there are.
- The arrows stay — for the keys (Tab reaches ↑ ↓ on the Mac; the grip is not one of Tab's tools) and for VoiceOver.
  **Since 0.72 on the Mac only** — see "The iPhone drags only (0.72)" below.
- `Screens/Reorder.swift`: `ReorderGrip` (the gesture), `reorderLift` (the carried row), `reorderStep` (each row's
  height). Not a `List` with `.onMove` as Arrange: see spec 06 §21.
- Two traps found on the way: a row named for scrolling with `.id(<row id>)` (a name by its PLACE) became a new view at
  each step and dropped the drag — the row stayed lifted half a row low; the name now sits behind the row. And the
  gesture's end is also caught when the system cancels it (`@GestureState`), not only by `onEnded`.

**Tests** (iPhone, light and dark): `testAKindOfThingIsDraggedIntoPlace` (Comfort & misc dragged above the row over
it; it settles right under Documents & money; saved, the order is kept; Documents & money has no grip),
`testASectionIsDraggedOnATemplatesRow` (`-uiTestingSections`, Hiking's first row: Clothes dragged above Lights; Cancel
leaves Lights first on the template; again and Save → the template reads Clothes first; No section has no grip),
`testAChoiceIsDraggedInYourChoices` (Hall closet dragged from the third place to the first, at once, and kept after
Done; owners have no grip). Planted: `ReorderGrip` never calling `move` → all three red ("the kind dragged up did not
move: 'Charging'", "the section dragged up did not move: 'Lights'", "the place dragged up did not move: 'Bedroom
wardrobe'"). Mac probe (GitHub's Mac, 8 Oct 2026): the three drag tests, the violet test, `testHisListsAnswerTabAndSpaceOnTheMac`
and `testKindOfThingIsChangedInsideItsList` — 6 of 6 green (the Mac's drag aims at a row's edge, the helper `drag`).

### The iPhone drags only (0.72)

> **Built in 0.72** (helper "noarrows", 8 Oct 2026) — written from the code; spec 06 §21 ("↑ ↓ are the Mac's only")
> and §2, spec 05 (His lists inside their drop-downs; a bag's Pockets).

His answer, 8 Oct 2026, to the open question below ("should the ↑ ↓ come off the iPhone?"): **"Drag and drop on the
phone as well."**

- On the iPhone no list he orders shows ↑ ↓: every drop-down with row tools (Kind of thing, Kept at home, Usually
  packed in, Pocket, When, Condition, a thing's Section on each template, a template row's Bag, When and Section),
  Your choices' pen, a bag's pockets, a template's reminders — and, the same evening (his rule again), a grab list's
  things while edited, Grab Lists' Home order and the table's Columns. One switch, `ReorderArrows.shown`
  (`Screens/Reorder.swift`): false on the iPhone, true on the Mac.
- Nothing lost a way to move: the drop-downs and Your choices had their grip since 0.70; a bag's pockets
  (`bag-pocket-<n>-grip`), a template's reminders (`template-reminder-<n>-grip`), a grab list's things
  (`grab-grip-<n>`), Grab Lists' Home order (`grablists-grip-<n>`) and Columns (`columns-<key>-grip`) got one now
  (on both devices).
  VoiceOver moves a row by the grip's own actions, **Move up** / **Move down**.
- The arrows' room goes to the name: a drop-down row on the iPhone is grip · name · pen · Remove, and "Pharmacy /
  meds" and "Comfort & misc" are one line (two in 0.70).
- The Mac keeps the arrows (Tab reaches them; the grip it does not) and the grip.
- Your choices' pen on the iPhone says instead: "To move it, hold the grip ≡ at its left and drag it."
  (`list-<kind>-drag-hint`; the steps' line names the timeline). The page's intro drops "or moves it up or down".

**Tests.** New: `testTheIPhoneMovesByDragOnlyAndLongNamesStayOnOneLine` (iPhone: the Map's kinds — "Pharmacy / meds"
and "Comfort & misc" each as tall as row 0's within 2 pt and with a grip; no `thing-category-<n>-up`/`-down` on any
row; Mac: row 10 still has ↑, ↓ and its grip). Planted: `ReorderArrows.shown = true` on the iPhone → red
("Pharmacy / meds is not on one line: its row is 54.3 tall, a short kind's 36.0"). Changed to drag on the iPhone, arrows kept on the Mac (helper `moveInList`, which taps
`<list>-<n>-up|down` on the Mac and drags `<list>-<n>-grip` onto its neighbour's on the iPhone):
`testASectionIsMovedFromAThingsPageAndANewTripReadsIt`, `testCancelLeavesTheSectionsAsTheyWere`,
`testKindOfThingIsChangedInsideItsList` (its tools: rename + remove + a grip on the iPhone; + up, down on the Mac),
`testKeptAtHomeIsChangedInsideItsListAndCancelUndoes`, `testUsuallyPackedInIsChangedInsideItsListAndABagInUseOpensItsPage`,
`testABagsPageListsItsPockets`; `testAChoiceIsRenamedAndMovedAndItsThingsFollow` and `testATemplateKeepsItsReminders`
drag on the iPhone and press ▲ / ↑ on the Mac. Second new test, for the three older lists:
`testTheOlderListsMoveByGripOnTheIPhone` (Indoor swim's second thing dragged to the top while editing; Grab Lists'
second Home list dragged first; Storage dragged below the next column — no ↑ ↓ on any of them on the iPhone, the
Mac presses them). Planted: the arrows put back in the three screens → red "a grab list's thing has ↑ on the
iPhone". `testTheTableTakesTheColumnsHeChooses` sizes the arrows on the Mac only. Columns' order is read by position on screen
(the Mac's probe handed the Hide buttons back in another order and was red once: "Storage did not move down"). Green
on the iPhone (light and dark) and on the Mac probe (GitHub's Mac, 8 Oct 2026: the test and
`testTheTableTakesTheColumnsHeChooses`). Green on the iPhone in light (14 tests) and dark (12); the Mac probe (GitHub's Mac, 8 Oct 2026) ran the new test,
the Section, Your choices and reminders tests on the Mac's arrows — 4 of 4 green.

**Template names in violet (0.70, spec 05 Your things).** His ask the same day: "Let's make the Templates text on each
row Lilac (the same color as the Templates) so that the list pops a bit." `ThingDetailLine`: the template names in the
Templates violet made readable (`readableHex`), " · place" muted, "On no template" orange. UI
`testYourThingsShowTheirTemplatesInViolet` reads the row's colour off the screen (pixels where blue is well over green
and red over green): the Map's row (Hiking · Garage) has violet; a thing on no template has none. Planted: the names in
`Theme.muted` → red "("0") is not greater than ("20") - the Map's templates are not in the Templates violet".

### The last three lists (0.73)

> **Built in 0.73** (helper "ddfirst", 12 Oct 2026) — written from the code. His wish (8 Oct 2026): every pick-one list
> of his own can be changed — added to, renamed, reordered, removed — from inside its drop-down. Three were still
> short of it (the open questions below).

- **A reminder's When** (spec 07 part 12; `Screens/TemplateReminders.swift`). Both its drop-downs — the open
  reminder's (`template-reminder-when`) and the block foot's (`template-reminder-add-when`) — list his steps
  (`timeline()`; until 0.73 the app's `PHASES`, which follow it) with the tools of every other list: the pen, the grip
  ≡ (the Mac's ↑ ↓ too), Remove and "A new step" ("Type the step first."); ids as everywhere, `<id>-<n>`,
  `-<n>-rename`, `-<n>-grip`, `-<n>-remove`, `-new`, `-add`. **Made at once, not held** — the decision: the
  template's page has no Save (Done only closes it) and everything on the Reminders block is made the moment it is
  done — the When picked, a reminder dragged, a reminder removed — as Your choices, the list's own home, makes
  these very changes. Holding the list until the open reminder's Done would have meant holding the When pick too
  (a step made at the foot does not exist before), and pressing the line again — which closes it without the
  name — would then have thrown away a When that has always been made at once. So: the same `ChoiceDrop`
  (`ChoiceDrop.atOnce`, `Screens/ChoiceDropDown.swift`) with nothing held: each change is written as it is made by
  the writes a page's Save makes (`Library.applyChoiceEditsNow` = `applyChoiceEdits` then `applyChoiceRemovals`).
  A rename shows at once (also on every reminder's line and every thing — steps are kept by id); a removal, after
  its question, takes the step away at once (no struck-out row, no Put back); one in use — the reminder's own step
  counts, as its thing and on its template — is refused with Your choices' words and OK; a drag moves it at once;
  "A new step" is made and chosen at once (`ChoiceDrop.made` finds the key it was made under): for the open reminder
  that is its When at once; for the foot, the new reminder's When. A step picked at the foot and then removed gives
  way to the one a new reminder would get.
- **Whose it is with nobody named** (spec 05 item 5): the drop-down is always there — "Both have one" and the foot
  "A new owner", so the FIRST owner is made right there (held until Save like any new entry; Save makes it the first
  of his Owners list, `addChoice("owners")`, and the thing says it). The line "Nobody is named yet. Add the names in
  Settings, under Your choices." (`thing-owner-none`, 0.62) is gone. The Mac's Tab reaches Whose it is always.
- **A bag with no pockets** (spec 05 item 9a): Pocket shows for any bag of his own (`Library.takesPockets(bag:)` — the
  bag has its record), pockets or not: "Just in the bag" and the foot "A new pocket", where its FIRST pocket is made
  (held until Save; Save adds it to the bag, `addPocket`, and the thing's usual pocket follows). Not for No bag, a
  built-in name he does not have, or a bag made at Usually packed in's foot and not saved yet.

**Tests.** Model (`ChoiceEditsTests`, now 17): `testAReminderStepIsChangedAtOnce` (renamed, made and given to a
reminder, moved, an unused one removed — each at once; the reminder's own step refused, "At the gate is still used on
1 template, so it stays."), `testABagWithNoPocketsTakesItsFirstPocketFromAThingsPage`, `testTheFirstOwnerIsMadeFromWhoseItIs`.
Planted: `applyChoiceEditsNow` without its removals → red "an unused step was not removed at once"; `takesPockets` as
the 0.69 rule (`!pockets(bag:).isEmpty`) → red "a bag of his with no pockets offers no Pocket list"; `addChoice`
refusing an owner → red "the first owner was not made". UI (iPhone, light and
dark), each seen red first with its fault planted: `testAReminderWhenIsChangedInsideItsList` (`-uiTestingReminders`:
the open reminder's When — a pen and Remove and a grip on a step; Day before renamed "The evening before"; ≥1 week
ahead refused; Wear removed at once, no Put back; ≥1 week ahead dragged first; "At the trailhead" made at the foot is
the reminder's When; closed without Done it all stays; the foot's When has the pen and the new name; a thing's When
reads the same order, names and new step, without Wear — planted: `ChoiceDrop.atOnce` keeping nothing → red
"Return did not take the new name: 'Day before (stage / move to RV)'"); `testTheFirstOwnerIsMadeInsideWhoseItIs`
(replaces `testWhoseItIsSaysWhereNamesComeFromWhenNobodyIsNamed` — planted: the drop-down shown only while somebody
is named → red "with nobody named, Whose it is is no list"); `testABagWithNoPocketsMakesItsFirstPocketOnAThingsPage`
(planted: the 0.69 rule → red "no Pocket list for a bag of his with no pockets").

### Open questions

- ~~A reminder's When (on a template's page) has no tools: it is applied at once, with nothing to hold changes
  until.~~ Done 12 Oct 2026 (0.73): its steps' tools, made at once — "The last three lists" above.
- ~~With nobody named anywhere, Whose it is still shows its line instead of a list, so the first owner is made in Your
  choices, not from the list.~~ Done 12 Oct 2026 (0.73): the list with its foot; the first owner is made there.
- ~~A bag with no pockets shows no Pocket list, so its first pocket is made on the bag's page.~~ Done 12 Oct 2026
  (0.73): the Pocket list with its foot for any bag of his.
- The row's own stored bag counts as a use when its Bag list refuses a remove, even after the row picked another.
- ~~(0.70) Now that a row can be dragged, the ↑ ↓ could leave the iPhone — his call.~~ Answered 8 Oct 2026: "Drag and
  drop on the phone as well" — done in 0.72 (above).
- ~~(0.72) The older reorderable lists (Grab lists' editor and order, Columns) keep their arrows on the iPhone.~~
  His rule again — done in 0.72: grips, arrows on the Mac only.
- (0.70) Search ("on 2 templates", a count) and Choose from your things (a place only) show no template NAMES, so
  they are not violet; say if the count should be.

---

## 14. Only on some trips, set once on the thing

> His words (10 Oct 2026, item 2 of his 0.73 list): "if I have an item on five templates, I need to change this in
> five places. Doesn't seem optimal." Designed here BEFORE it was built (branch `work/cond073`), then brought in line
> with the code by the same branch: the model `Core/Sources/PackingLibrary/OnlySomeTrips.swift`, the pills
> `App/Sources/Screens/OnlySomeTrips.swift` (`OnlySomeTripsPills`, used by both pages). Per screen: spec 04 §7 (a template's row), §11–§13
> (the membership, resolving, saving a template), spec 05 item 7 (a thing's page), spec 01 §1.12 (the keys).

Until 0.73 "Only on some trips" — Season (Summer, Winter), Context (Indoor, Outdoor, Race — on a workout template
only), Transport (Car, Plane, RV), Food (Self-sufficient, Eating out, Mix — "Mix of both" until 0.78) — lived on each template's ROW
(the membership) only: a thing on five templates needed the same Winter five times.

### What he gets

- **A thing's page has the same "Only on some trips" block as a template's row**, under the Section drop-downs
  (where a grey line used to say "is set per template: open the template and tap this thing"). What is picked there
  is the THING's answer: every template it is on follows it — the same idea as How many and Note on a row ("Blank
  means the same as the thing itself, so a change to the thing still reaches this template").
- **A template's row still has the block**, and each of the four kinds says where its answer comes from: "Same as
  the thing: Winter" while it follows the thing, or "Own choice on this template. The thing says: Winter." while the
  row has its own — with a small button **Same as the thing** that goes back.
- His own example (2 Oct 2026, "a towel can be summer-only on Beach and always on Swim"): Summer is picked once on
  the towel's page → summer-only on Beach and on every other template; on Swim's row Summer is tapped off → always
  on Swim, whatever the towel says.

### The rules (decided 10 Oct 2026)

1. **Per kind.** Season, Context, Transport and Food are decided separately: a row with its own Season still follows
   the thing's Transport and Food. Chosen as the least surprising — a row overrides only what it says.
2. **A row's kind is its own** when its stored list is not empty, OR its `onlyAnyHere` key names that kind (below).
   Otherwise the kind **follows the thing**.
3. **What a trip reads** (the row's *effective* answer): its own list when the kind is its own (an own empty list =
   any season / any transport … on this template), else the thing's list (empty = any).
4. **A choice equal to the thing's IS "the same as the thing"** — as How many and Note are stored blank when they
   equal the thing's (`saveRow`). On the row's page a kind whose pills come back to exactly the thing's answer shows
   "Same as the thing" again (undoing a tap goes back), and Save stores it as following. So an own answer that
   happens to equal the thing's is not kept as a separate choice: a later change on the thing reaches that row.
   The same when the THING is saved (`setThingLimits`): every row of it whose own answer is now the thing's goes
   back to following it — the five rows he once set to Winter one by one follow the thing as soon as its page says
   Winter, so his next change is made in one place. (A row's own "any" while the thing now has no limit either is
   the same as the thing too.) Hence, everywhere: "this row has its own answer" = "this row says something other
   than the thing".
5. **"Any" on one template while the thing has a limit** (Swim's towel) is the row's own "any": stored as the kind's
   empty list plus the kind named in `onlyAnyHere`.
6. **Rows stored before 0.73 keep their answers as their own choice** (their lists are not empty). Rows with nothing
   stored follow the thing — and since no thing has an answer yet, nothing changes on any template or trip until
   he sets one on a thing.
7. **Context on the thing counts only where Context counts on a row**: on a workout (WET) template
   (`contextApplies`). On any other template a thing's Context is ignored, as a row's is. The thing's page shows the
   Context pills only while the thing is on a workout template (one lit in On these templates) or already has a
   Context, with the line "Context counts on workout templates only."
8. **Trips.** A new trip and Trip settings → Save (the rebuild, `Library.regenerated`) pack by the effective answers.
   A change on the thing's page reaches the open lines of trips still ahead the way every change to a thing does
   (`followThing`, spec 04 §17): a line that is still built is refreshed; a line is neither added to nor taken off a
   trip already made — that stays Trip settings → Save's job, exactly as for a row's own Season before 0.73.
9. **Kits** (part 9): a kit that takes a content's place on a template packs by the CONTENT's effective answers there
   (the content's row, or the content thing's when the row follows it).
10. **What the screens say.** A template's page says "Only on: Winter" under a row for what the row really does —
    the same words whether the answer is the row's own or the thing's. A thing's page names the templates that set
    their own: "Set on the template instead: Swim (Season)." Nothing else changes: the table has no column for
    these (its Condition column is the thing's wear), nor Search, nor the web app.
11. **Unknown words** (a web-app "summer", a word from a newer build) are kept as they are on the thing too: shown as
    a lit pill of their own after the app's words, kept on Save unless switched off (`Library.keptConditions`).

### Where it is kept (the web model sees nothing new)

- On the THING, four `extra` keys — `onlySeasons`, `onlyContexts`, `onlyTransports`, `onlyCatering` — each a list of
  the stored words (`Summer`/`Winter`, `Indoor`/`Outdoor`/`Race`, `Car`/`Plane`/`RV`, `self`/`eatout`/`mixed`), the
  app's own words in the app's order, then any unknown word. Absent = no limit; never written empty.
- On a template's ROW (the membership): its own `seasons`, `contexts`, `transports`, `catering` as before, plus ONE
  `extra` key `onlyAnyHere` — the kinds ("seasons", "contexts", "transports", "catering") for which this row comes
  on ANY trip whatever the thing says. Absent = none. Only ever names a kind whose list is empty.
- **Effective answers are worked out in one place**, `Library.resolveOne` (every resolved template the app shows or
  builds from: `resolvedTemplates()`, `resolvedTemplate(id:)`, `templatesForTrips()`, `row(templateId:memId:)`): each
  row's `seasons`/`contexts`/`transports`/`catering` are its effective answers. PackingCore's `resolveMembership` (the
  web app's) is unchanged, so the parity check stays 211/211.
- The keys ride as every `extra` key does: in the thing's and the membership's records (store and iCloud), in a
  backup's `items` and `memberships` (§10 of spec 01), back through a restore. A backup's `lists` (what the web app
  reads) carries each row's EFFECTIVE answers, so the web app, restoring our file, packs the same. A shared template
  carries effective answers too (what the template really does).
- An older file rebuilt from its rows (the web app's, or one of ours from before 0.61): rows come in with the
  answers they show; a thing's keys carried from its rows (`carryRowExtras`) are then settled so that each row reads
  exactly what the file said (a row equal to its thing's answer follows it; an empty row while the thing has a limit
  is that row's own "any") — `Library.settleRowsOnThingsLimits`.

### Saving a template never freezes the thing's answers onto its rows

`saveTemplate` (every way a template is saved from its resolved rows: a thing typed or picked onto it, a row taken
off, a template made, imported or replaced) used to store each row's resolved Season etc. as the row's own. With the
thing's answers in the resolved rows that would have copied them onto every row and cut the rows off from the thing
— the bug How many and Note had until the spec pass of 5 Oct 2026. So, per kind, after `membershipFromResolved`:
- a row whose answer is UNCHANGED from what it resolved to keeps exactly what it stored (its list and its
  `onlyAnyHere`);
- a NEW row (no membership yet) whose answer is empty or equal to the thing's follows the thing; any other answer is
  its own;
- a CHANGED row: equal to the thing's → follows; empty while the thing has a limit → its own "any"; else its own list.

### On the screens

- **A thing's page** (spec 05 item 7): band "Only on some trips" (`thing-heading-some`, in the Templates violet like
  On these templates and the Section drop-downs above it); "Leave these off and it always comes along. Pick one or
  more and it comes only on trips that match — on every template it is on, unless a template sets its own."
  (`thing-some-hint`); four pill rows as on a row: Season `thing-seasons-<n>`, Context `thing-contexts-<n>` (rule
  7), Transport `thing-transports-<n>`, Food `thing-catering-<n>` (headings `thing-<kind>-title`); then, when a lit
  template's row sets its own, `thing-some-own`: "Set on the template instead: Hiking (Season), Swim (Food)." Held
  until Save like everything on the page; Save writes the four keys (`Library.setThingLimits`, through
  `updateThing`, so trips still ahead follow); Cancel leaves the thing as it was.
- **A template's row** (spec 04 §7, block 8): the pills of each kind show its effective answer. While the kind
  follows the thing its lit pills are drawn "borrowed" — outlined in the violet with violet words on a faint violet
  wash, instead of filled — and under the pills `row-<kind>-from` says "Same as the thing: Winter" (or "Same as the
  thing: any season" / "any context" / "any transport" / "any food" when the thing has none). A tap on any pill
  makes the kind this template's own, starting from what was shown (so tapping the lit Winter off = any season on
  this template); its lit pills are then filled, `row-<kind>-from` says "Own choice on this template. The thing says:
  Winter." and **Same as the thing** (`row-<kind>-same`, an outlined violet capsule, Footnote semibold) puts the
  thing's answer back. Save (`saveRow`) stores per kind by rules 4 and 5.

### Tests (from the code)

Model `OnlySomeTripsTests` (9, `Core/Tests/PackingLibraryTests/OnlySomeTripsTests.swift`; a Towel on the base
template, Hiking and Swim, a Lamp on the base template and Hiking): `testEveryRowFollowsTheThingPerKindUnlessItSetsItsOwn`
(Summer + Car once on the thing → every row says "Only on: Summer · Car" and stores nothing; Hiking's own Transport and
Swim's own any season stay through a change on the thing; `ownLimitWords`; `limitFromWords`),
`testRowsFromBeforeKeepTheirOwnAndAThingWithNoAnswerChangesNothing`, `testARowSavedFromItsPageFollowsOwnsOrIsAnyHere`
(`saveRow`: the thing's answer → follows, nothing → `onlyAnyHere`, Winter → own, back; an unknown word on the thing
kept), `testRowsThatSayWhatTheThingNowSaysFollowIt` (rule 4 on the thing's Save), `testSavingATemplateNeverFreezesTheThingsAnswersOntoItsRows`
(typed on, taken off, picked onto a new template), `testATripAndItsRebuildPackByWhatEachRowReallySays` (a summer trip
without the winter-only Lamp, a winter one with it once; `changeTrip` both ways; Hiking's own any wins; a trip ahead
keeps its line until rebuilt), `testTheThingsContextCountsOnWorkoutTemplatesOnly`, `testAKitInAContentsPlacePacksByTheContentsAnswer`,
`testTheAnswersAreStoredSyncedBackedUpAndRestoredAndTheWebModelSeesAPlainThing` (records, a backup as written and the
older kind rebuilt from rows — both faithful, every row reading as before and still following the thing — the
backup's `lists` carrying effective answers, PackingCore's resolve unchanged). Each seen RED with a planted fault:
resolve without the thing's answers (34 failures, e.g. "an outdoor swim took the indoor towel"); `saveTemplate`
storing resolved answers ("Hiking: the Season was frozen onto the row"); no own "any" ("older: template 3, row 2:
seasons" — the older file refused); the thing's Save not folding rows ("Common base still keeps its own Winter");
a kit taking no content answers ("the pouch came for a winter-only lamp"); the older file not settled ("older: the
rows no longer follow the thing"); a row's stored list not counting as its own ("a row's answer from before is its
own"); the trip builder reading the bare rows ("a summer trip has the winter lamp"). Parity: 211/211.

UI (`-uiTesting`; the sample's Headlamp is on Common base and Hiking; a trip from Hiking packs 7 lines with the base
template): `testOnlyOnSomeTripsSetOnceOnAThingReachesBothItsTemplates` (the thing's page has `thing-heading-some`,
Season, Transport and Food and no Context; Winter `thing-seasons-1` set once and saved → both templates' Headlamp rows
say "Only on: Winter"; a summer trip made from Home counts "0/6"; Trip settings → Winter → Save counts "0/7") and
`testATemplatesOwnOnlyOnSomeTripsWinsOverTheThings` (Hiking's row shows `row-seasons-1` lit and `row-seasons-from` "Same
as the thing: Winter", no `row-seasons-same`; Winter tapped off → "Own choice on this template…" and the button; saved,
the row says no "Only on"; a summer trip counts "0/7"; `row-seasons-same` puts Winter back and the row says "Only on:
Winter" again). Run on the iPhone simulator in light and dark (pictures `thing-only-some`, `row-only-some-follows`,
`row-only-some-own`). Seen RED with a planted fault: the thing's page not saving its answers → "Common base's Headlamp
does not say it is only on winter trips: 'Headlamp, Carry-on / hand luggage'"; a row's own "any" lost on Save →
"Hiking's own any season still says a limit: 'Headlamp, Only on: Winter, Carry-on / hand luggage'". Not covered on
screen: Context and Food on the thing's page, `thing-some-own`, unknown words (the model tests hold them).

### Open questions

- **Trips already made.** A changed answer on a thing (or a row) does not take the thing off, or put it on, a trip
  already made; Trip settings → Save does. Should it? (Rule 8 keeps today's behaviour for rows.)
- The template page's "Only on: Winter" does not say whether the answer is the row's own or the thing's. Worth a
  mark?
- ~~On the Mac the new pills are not in a thing's page's Tab order yet (as the kit part's buttons).~~ Answered in
  0.75: each row — Season, Context (where shown), Transport, Food — is a Tab stop after the Sections, answering ← →,
  Space and letters as On these templates (spec 05, Keyboard (Mac));
  `testOnlyOnSomeTripsPillsAreReachedByTabAndSwitchedBySpace`, proven on GitHub's Mac.

---

## 15. Batteries and To charge

> His words (13 Oct 2026): "Add a tick box for each item: Contains battery. And maybe implement a view where I can
> check all items that need charging." He said yes to the design (a picture: the switch on a thing's page, the To
> charge card on a trip) the same day. Written here BEFORE it was built (branch `work/battery075`), then brought in
> line with the code by the same branch: the model `Core/Sources/PackingLibrary/Batteries.swift`, the card
> `App/Sources/Screens/ToCharge.swift` (`ToChargeCard`, and the drawn battery mark `ToChargeCard.battery`), the
> switch and the Your things filter in `App/Sources/Screens/ThingsScreen.swift`. Per screen: spec 03 ("Before you
> go" — To charge is its last part since 0.77), spec 05 (a thing's page item 15a, Your things, Keyboard (Mac)), spec 01
> §1.12 (the keys).
>
> **0.77** (his yes of 13 Oct 2026, a picture approved): the To charge card and Check before you go became ONE card,
> **Before you go**, with To charge as its last part — `ToChargePart` in `ToCharge.swift` (the battery mark is still
> `ToChargeCard.battery`), the card `BeforeYouGoCard` in `TripChecks.swift`, the model
> `Core/Sources/PackingLibrary/BeforeYouGo.swift`. The rules of this part did not change; where it stands and how it
> looks did (rule 6, "On the screens").

### What he gets

- **A thing's page**: under On a plane, a band **Battery** with ONE switch, the small drawn battery mark beside its
  words: **"Has a battery — charge before a trip"**. Held until Save like everything on the page.
- **A trip**: **To charge** — a card of its own in 0.75–0.76, since 0.77 the last part of Before you go — from the DAY
  BEFORE the trip starts until its last day — every thing on the trip
  that has a battery, the ones inside a kit on the trip too ("In the Camp pouch"), each with a CHARGE tick of its
  own. Ticking charged does not pack it; packing it does not mark it charged.
- **Your things**: a filter **Has a battery** beside On no template — the things to charge, at a glance.
- **Check before you go** (0.76, his yes of 13 Oct 2026; Before you go's flags since 0.77): on a PLANE trip, a thing
  with a battery in a CHECKED bag is a red line — "Battery: carry it in the cabin · in Checked luggage" — because airlines want lithium batteries and
  power banks in the cabin. Rule 8 below.

### The rules (decided 13 Oct 2026, by the build)

1. **The thing says it, once.** "Has a battery" belongs to the THING, as Liquid does: every template and trip reads
   it from the thing as it is now (`thingNow`, the same rule as Check before you go). A switch turned on today shows
   on a trip made last week; a line typed on the trip only (no thing behind it) never has a battery.
2. **NOT the web app's "Charging" flag.** The web model has `charging` (with a connector, `chargeType`) — "needs
   charging OR a charging cable": a USB-C cable carries it, and a cable has no battery to charge. It is the table's
   **Charges** column and stays exactly as it was. "Has a battery" is a key of its own (`battery`), so a cable never
   lands on To charge, and the parity check is untouched (211/211). The two are independent: neither sets the other.
3. **Which things are on the card** (`Library.toCharge(tripId:)`), in the trip's line order: each line that is not
   set aside ("not this time" — it is not going) and not a reminder, whose thing has a battery; and for a KIT line
   (part 9, the kit as it is NOW, `liveKitOnLine`), each thing inside it — in the kit's order, right after the kit's
   own row when the kit itself has a battery — that has a battery and is not taken out (taken out, it is not in the
   kit, so it is not on this trip). A thing is listed once: the first place it is met wins (a trip made before a thing
   went into its kit may still hold its own line).
4. **The CHARGE tick is the trip's, not the thing's** — charged for this trip. Kept on the trip LINE, each line its
   own small record, so the iPhone and the Mac can tick two things at the same moment and both survive:
   `charged: true` on a line (its own thing charged); `kitCharged: [ids]` on a kit's line (the things inside it
   charged). Unticking removes the mark (an empty list is never stored). Ticking charged never ticks the line, and
   ticking the line (packing it, Tick everything, a section's tick, the kit's checked ticks) never marks charged.
5. **When the card shows** (`Library.chargeWindow(trip, today:)`): from the day BEFORE the start date through the
   END date (the end = the start when it is blank) — through the last day because he may charge again on site. A
   trip with no start date shows it whenever it has things to charge (there is no day to wait for). Never on a
   reviewed trip (`Library.isReviewed`). Never when nothing on the trip has a battery. Not when the trip was opened
   from a place's code (the page shows only that place's lines, as for the other cards).
6. **Where on the trip.** In the scroll area, above the weather: what would stop him at the airport (red) stays
   first; To charge, with its own deadline (the night before), comes straight after it; the weather and the bags
   follow. 0.75–0.76: a card of its own right UNDER Check before you go. Since 0.77 (his yes of 13 Oct 2026): the LAST
   part of the one Before you go card — after the flags and To do — whose count adds the things not charged yet; with
   everything charged and nothing else left, the card says "All set", green, and folds to its one line (spec 03,
   "Before you go").
7. **What travels.** The thing's `battery` key goes wherever the thing goes: the store and iCloud (the thing's
   record), a backup (as stored, and the older kind rebuilt from rows, `carryRowExtras`), a restore. The charge ticks
   are the trip's: they ride in the line records, a backup and a restore; a rebuild (Trip settings → Save) and a
   change to a thing reaching a trip ahead (`followThing`) keep them; **"Start a new trip from this one" and a shared
   trip drop them** (`startAgain`, `justTheList`), as they drop every packing mark.
8. **A battery in the hold** (0.76, his yes of 13 Oct 2026; `Library.cabinCheck`, spec 03 "Check before you go"). Only
   when the trip's transport is "Plane". A line is judged when it is not set aside, not a reminder, and IN A BAG
   (`Library.inABag`: its bag is not blank and not "Other" — a thing in no bag yet has nothing to judge, so it says
   nothing). A bag is CHECKED when it is not a cabin bag by the very rule the cabin's side uses (`isCabin(container:)`:
   the bag's own Goes in the cabin, else its name — "carry-on", "carry on", "carryon", "hand luggage", "cabin"). In a
   checked bag, the line's thing as it is NOW (`thingNow`, `BATTERY_KEY`) with a battery is flagged (`CabinFlag.Why
   .battery`); so is each thing inside the line's kit as it is now (`insideLines`, which since 0.76 carries the
   thing's own `battery`, never the kit line's), not taken out: "Power bank, in the Camp pouch", the kit's bag after
   "in". A thing with a battery in a cabin bag says nothing; a thing not allowed on board or a liquid in a checked bag
   says nothing (the hold takes them). Order on the card: **not allowed, then the batteries, then the liquids** —
   red before orange, and a battery is as hard a stop as a knife (decided by the build). Not de-duplicated, as the
   cabin's side is not: a thing on two lines is said twice (only a trip made before the thing went into its kit can
   hold that). Put right by moving the thing (or its kit) to a cabin bag, by saying the bag goes in the cabin (its
   page, or the trip's Bags card), or — if it has none — by switching Has a battery off; the line goes at once.

### On the screens

- **A thing's page** (spec 05 item 15a): band "Battery" (`thing-heading-battery`), the switch
  (`thing-battery`, orange tint like Liquid): the drawn battery mark (18 pt, orange) and "Has a battery — charge
  before a trip" (Callout semibold ink). On the Mac it is in the Tab order after Not allowed in the cabin, before
  Valid until; Space switches it; the foot line says "Has a battery   Space turns it on or off · Tab next · Return
  saves"; ⌘J finds it as "Has a battery".
- **Your things** (spec 05): beside "On no template N", a pill **"Has a battery N"** with the drawn mark
  (`things-battery`; the same look: orange words on the card, white on orange when on, selected trait) — there while
  any thing has a battery, or while the filter is on. N counts every such thing, whatever the search. On, the list
  keeps only things with a battery; with the search and On no template, all must hold. ⌘↓ ⌘↑ on the Mac go through
  the things as so filtered. When the count and the pills do not fit on one line (an iPhone), the pills go on a line
  of their own under the count.
- **To charge, the last part of Before you go** (0.77; spec 03, "Before you go"; id `trip-beforego-part-charge`): the
  heading line — the drawn battery mark (16 pt), "To charge" (Footnote semibold muted), "·" and "1 of 3" — charged of
  all (Footnote semibold; id `trip-charge-count`, label "1 of 3 charged"); the mark and the count orange
  (`AppSection.care.color`) while something is left to charge, the trip's green once all are charged. The card's own
  count capsule (`trip-beforego-count`) adds the things not charged to the flags and reminders due. (0.75–0.76: a card
  of its own, id `trip-charge`, in Check before you go's frame, with the battery mark at 22 pt, "To charge" in
  Subheadline and "1 of 3" in a capsule of the tint, the border in the tint.) Then one row per thing (`trip-charge-<n>`, a button, min
  height `Metrics.tap`): a tick circle (22 pt; orange and filled when charged), the name (Callout semibold ink) and,
  for a thing inside a kit, "In the Camp pouch" under it (Subheadline muted). Charged: the name struck through and
  muted. A tap ticks or unticks it. Label "<name>" or "<name>, in the <kit>"; value "charged" / "not charged";
  selected trait when charged.
- **Check before you go** (spec 03, 0.76): a battery in the hold is one of the card's cabin lines,
  `trip-check-cabin-<n>` (after the not-allowed lines, before the liquids): the drawn battery mark
  (`ToChargeCard.battery`, 22 pt) in red (`AppSection.actions.color`), the name ("Power bank" or "Power bank, in the
  Camp pouch", Callout semibold ink), the reason in red "Battery: carry it in the cabin · in <bag>", the chevron; a
  tap opens the thing itself (inside a kit: that thing, not the kit). It makes the card's count capsule and border red.
  Since 0.77 it is in Before you go's first part, the flags (`trip-beforego-part-flags`).

### Where it is kept (the web model sees nothing new)

| Holder | Key | Value | Meaning |
|---|---|---|---|
| item | `battery` (`BATTERY_KEY`) | true / absent | has a battery: charge before a trip. Never written false |
| trip line | `charged` (`CHARGED_KEY`) | true / absent | its thing is charged for this trip |
| trip line (a kit's) | `kitCharged` (`KIT_CHARGED_KEY`) | `[item id]` / absent | the things inside the kit charged for this trip; only ids inside it now are written |

### Tests (from the code)

Model `BatteriesTests` (5, `Core/Tests/PackingLibraryTests/BatteriesTests.swift`; a Toothbrush, a Passport and a Phone
charger — the web app's Charging flag, no battery — on the base template; a Camp pouch, a Headlamp and a Map on Hiking;
the pouch holds a Power bank, a GPS watch taken out and a Lighter; the Wash bag, on no template, the Toothbrush and
Soap; with a battery: Headlamp, Power bank, GPS watch, Toothbrush):
`testAThingSaysItHasABatteryAndThatIsNotTheWebAppsChargingFlag` (the key true, never written false; the charger's web
flag puts nothing on To charge; `batteryThings` A–Z), `testToChargeListsEveryBatteryThingOnTheTripTheOnesInsideItsKitsToo`
("Toothbrush in Wash bag", "Power bank in Camp pouch", "Headlamp" — the watch taken out is not there; a thing switched on
after the trip was made shows; put back, the watch comes; a kit with a battery of its own first; set aside, a reminder
from a rebuild and a line typed on the trip never), `testTheChargeTickIsApartFromPacking` (charging packs nothing;
packing, Tick everything and Clear charge nothing; "2 of 3"; unticked, the keys go; only what is inside the kit now can be
marked), `testToChargeShowsFromTheDayBeforeTheTripThroughItsLastDay` (two days before no, the day before yes, the last
day yes, the day after no; a one-day trip; no dates; reviewed; nothing with a battery),
`testBatteriesAndChargeTicksAreStoredSyncedBackedUpRestoredAndKeptByARebuildButNeverSentOrStartedAgain` (records, a
backup as written and the older kind rebuilt from rows — both faithful —, `Item(json:)` and `coerceItem`, Trip settings'
rebuild and `followThing` keep the ticks, `justTheList` and `startAgain` drop them, the trip itself keeps its own). Each
seen RED with a planted fault: the kit contents left out ("("1 of 1") is not equal to ("2 of 3")"); a charge tick that
packs ("XCTAssertFalse failed - charging it packed it"); the card from the start day ("XCTAssertTrue failed - the day
before"); a shared trip and Start again keeping the ticks ("("[… "Power bank in Camp pouch ✓", "Headlamp ✓"]") is not
equal to ("[… "Power bank in Camp pouch", "Headlamp"]")"); the web app's Charging flag read as a battery ("("["GPS watch",
"Headlamp", "Phone charger", …]") is not equal to …"). Parity: 211/211.

UI (`-uiTestingBattery`, `SampleLibrary.battery()`: the kits sample with its first trip starting TOMORROW, a Power bank in
the Camp pouch and the Toothbrush — in the Wash bag — with a battery; the Headlamp without one):
`testABatterySwitchOnAThingPutsItOnTheTripsToCharge` (the trip's card "0 of 2", "Toothbrush, in the Wash bag" and "Power
bank, in the Camp pouch"; Your things' `things-battery` says 2 and keeps "2 things", on; off, all again; the Headlamp's
`thing-battery` switched on and saved → the filter says 3; the trip "0 of 3" with the Headlamp) and
`testToChargeIsTickedApartFromPacking` (the power bank charged → "1 of 2", selected, the trip's count unchanged; the
pouch's line not ticked; the pouch packed → the count moves, still "1 of 2", the toothbrush not charged; the last one
charged → since 0.77 Before you go says "All set" and folds (`trip-beforego-part-charge` goes, `trip-beforego` stays;
picture `trip-beforego-allset`), `trip-beforego-fold` opens it, "2 of 2"; the power bank unticked → "1 of 2", the card's
count "1", the pouch still packed; the trip two months ahead has no To charge). Since 0.77 they find the part by
`trip-beforego-part-charge` (until then the card `trip-charge`). Run on the iPhone
simulator in light and dark (pictures `battery-thing-battery-switch`, `battery-things-battery-filter`,
`battery-trip-to-charge`, `-one`, `-all`). Each seen RED with a planted fault: Save not writing the key → "the
Headlamp's battery was not kept: 'Has a battery 2'"; the filter not applied → "Has a battery does not keep the two: '17
things'"; a charge tap that also ticks the line → "charging the power bank packed something: '1/8'". The Mac:
`testTheThingPageTabsThroughEveryFieldInOrder` walks Has a battery between Not allowed in the cabin and Valid until,
Shift-Tab from Valid until lands on it and Space switches it on; `testAThingsPageReadsInHisOrderAndKeptAtHomeIsChosen`
reads the Battery band between On a plane and Valid until. On GitHub's Mac (a probe running just these four): with Has a
battery left out of the Tab order, red — "Tab did not go on to thing-battery"; without the fault, all four green, and the
two battery tests green again (pictures of the Mac look, day).

**A battery in the hold (0.76).** Model `TripChecksTests.testABatteryInACheckedBagIsToldToGoInTheCabin` (on the plane
trip: a Power bank in the Suitcase, a Phone in the Cabin bag, a Torch moved to no bag, a Camera set aside, a reminder
with a battery in the Suitcase, and a Tech pouch in the Suitcase holding a Spare battery, a Cable and a Lighter →
"Pocket knife", "Power bank", "Spare battery, in the Tech pouch", "Sun cream" — not allowed, battery, battery, liquid;
both batteries "in Suitcase"; the flags open the power bank and the spare battery, not the pouch; "Other" is no bag
either; the power bank's battery off → only the spare battery; the Suitcase said to go in the cabin → no battery, and
the pouch's Lighter and the shampoo now stopped in the cabin; by car nothing). Seen RED with a planted fault: no "in a
bag" rule ("("["Pocket knife", "Power bank", "Torch", …]") is not equal to …", "a thing in no bag was judged"); the
kit's contents not carrying the battery ("("["Pocket knife", "Power bank", "Sun cream"]") is not equal to …"); the
hold and the cabin swapped (seven failures across the four cabin tests, e.g. "his word that it goes in the hold is not
taken"). UI `testABatteryInACheckedBagIsToldToGoInTheCabin` (`-uiTestingBattery -batteryByPlane`, `SampleLibrary
.battery(byPlane:)`: the first trip by plane, the Camp pouch in the Checked luggage; `trip-check-cabin-0` "Power bank,
in the Camp pouch … Battery: carry it in the cabin · in Checked luggage" and nothing else — the Toothbrush in the Wash
bag is in the carry-on, the pouch's Lighter in the hold; a tap opens the power bank, its `thing-battery` on; switched
off and saved, the flags go — `trip-checks` until 0.77; since then `trip-beforego-part-flags`, while the card stays
for To charge). Seen RED with the card leaving battery lines out: "the plane trip does not check
the battery in the hold". Pictures `battery-trip-check-hold`, iPhone day and night. On GitHub's Mac (a probe running
just this test, `testANewKitStartsCheckedBeforeEachTrip`, `testTheKitPartIsWalkedByTheKeys` and
`testATripChecksTheCabinAndTheDatesBeforeYouGo`): all four green.

**Before you go, one card (0.77).** Model `BeforeYouGoTests`, UI `testBeforeYouGoIsOneCardWithItsPartsInOrder`
(`-uiTestingBattery -batteryByPlane -batteryToDo`: the battery-by-plane sample with Hiking's "Check the forecast" a
week ahead, so all three parts show, 4 left) — what they pin and the red they were seen with: spec 03, "Before you go",
Tests.

### Open questions

- The table has no column for "Has a battery" (its **Charges** column is the web app's `charging`). Worth one?
- ~~Should a battery thing in a cabin bag on a plane trip say anything in Check before you go (spare batteries and
  power banks must travel in the cabin)? Not asked for; not built.~~ Answered 13 Oct 2026 (0.76, his yes): a thing
  with a battery in a CHECKED bag is a red line in Check before you go (rule 8); one in a cabin bag says nothing.
- Some airlines limit power banks by watt-hours, or want them out of the cabin bag at the gate; the app knows no
  capacity and says only where it goes. His word welcome.

## 16. Take a break and messages when a trip moves on

> His words (13 Oct 2026), from his own packing walk-through: "then I get tired and just want to relax… if it is the
> day after I would like a reminder or a calendar event so that I feel calm. In this state I would like an overview
> of how far I have come"; and "I would like a message from the app when the Phase changes". He said yes to both the
> same day. Built on branch `work/break077` (0.77) and written from the code: the model
> `Core/Sources/PackingLibrary/TakeABreak.swift`; the button, the sheet, the calendar hand-over and the Settings switch
> `App/Sources/Screens/TakeABreak.swift`; the notifications `App/Sources/Store/TripMessages.swift`. Per screen: spec 03
> (the trip header's count line), spec 06 §3 and §3c (Settings and the notifications), spec 01 §1.12 (the key).

### What he gets

- **Take a break**, on a trip being packed: a small outlined pill at the end of the trip header's count line
  ("1/7 … ☕ Take a break") opens a sheet. On it: **how far he has come** — "41 of 63 packed", a bar, each group of
  his Sorting as a pill, done (a drawn tick) or "3 left", and, when the trip has them, "To charge: 2 left" and "To
  do: 1 left" — then **Continue when?** — In an hour · This evening (19:00) · Tomorrow (18:00, or the time beside it)
  · Just pause. A time keeps ONE break on the trip: at that moment the iPhone says "Back to packing <trip>" / "22
  things left", and a tap opens the trip. The pill then says when he comes back: "Back at 19:00". **Add to
  Calendar** puts the break in his calendar too, if he wants. Ticking the last thing takes the break away.
- **Messages when a trip moves on** (the iPhone): "Have a good trip — <trip>" when the trip sets off (Pack → On
  site), and "Welcome home — review <trip> in two minutes?" the morning after its last day (On site → Review); a tap
  on that one opens the trip on its review. A switch in Settings, on until he turns it off.

### The rules (decided 13 Oct 2026, by the build)

1. **Only at Pack.** The pill shows while the trip's step is Pack (`loopStep` on the trip screen's clock — the same
   reading as the loop strip, so it goes the moment the trip sets off, 0.75) AND something is left (`allPacked` is
   false). Never at Plan (no lines), On site, Review or Refine. A trip opened from a place's code has the same header,
   so the pill is there too.
2. **The overview is the trip's own counts.** "N of M packed" is the header's `progress(trip.entries)` — every line
   not set aside, its reminders too (spec 07 part 12: "All packed" waits for them) — so the sheet and the "1/7" above
   it never disagree. The groups are the trip's groups in HIS Sorting on this device (`@AppStorage("ams.view")`,
   the trip's own key) through the ONE rule the trip screen uses (`Library.linesGrouped`, moved from
   `TripScreen.grouped` for this: Template = `linesByTemplate`, others the web app's `groupBy`, Into puts a reminder
   under "To do"); each group counts its lines not set aside, as its heading's "2/5" does; a group whose every line is
   set aside is not shown. A line on two templates counts under both (it is under both on the trip). To charge is
   exactly the To charge card's (`chargeCard(tripId:today:)` — from the day before the trip through its last day;
   no card, no line): "To charge: N left" (orange) / "all charged" (green). To do counts the trip's reminders not set
   aside: "To do: N left" / "all done"; no reminders, no line.
3. **The choices**, read from the moment the sheet opened (the app's clock, `Today.now` — the tests' `-clockAt`
   too): **In an hour** = now + 60 minutes (over midnight to the next day), its time shown; **This evening** = today
   19:00, offered only while that is at least 30 minutes ahead (`BREAK_EVENING_LEAD_MINUTES`; nearer, In an hour says
   it); **Tomorrow** = tomorrow at the time beside it, 18:00 to start (a compact time picker; a new time is taken at
   once while Tomorrow is the choice); **Just pause** = no reminder (it takes away a break waiting).
4. **Refused, with why** (`breakRefusal`, said in red under the choices, id `break-needs`; nothing is kept): the
   moment has passed — "That time has passed — pick a later one."; the trip has set off by then (`hasSetOff` at that
   minute, the minute he leaves included; with no time he leaves, from the start of the first day) — "You leave
   before then — pick an earlier time."; everything is packed — "Everything is packed." (the pill is hidden then, so
   only the model sees it). Every choice button stays in full colour (his rule: never grey).
5. **One break per trip.** Kept on the TRIP, extra key `breakUntil` = "2026-10-13 19:00" (`BREAK_UNTIL_KEY`, this
   device's clock, as "I leave at" is) — so it is synced: a break taken on the Mac is the iPhone's to remind him of.
   Backed up and restored with the trip. A new choice replaces it; Just pause removes the key (`setBreak(until:
   nil)`). The web app's model sees an unknown key and keeps it (parity untouched, 211/211).
6. **It goes when everything is packed.** The trip screen, seeing the trip become all packed (`allPacked` turning
   true — a tick, a section's tick, Tick everything, Pack by voice, the other device), removes the key. Unticking a
   line afterwards does NOT bring it back. And whatever the key says, no message is planned for a trip with nothing
   left (rule 9), so a trip packed on the other device while this one was closed stays quiet too.
7. **The pill's words** (`TakeABreakButton.words`): "Take a break"; with a break still ahead "Back at 19:00" (today),
   "Back tomorrow 18:00", "Back 15 Oct 18:00". A break whose moment has passed reads "Take a break" again.
8. **What the sheet says after a choice** (id `break-said`, green): "Back to packing at 19:00 — the iPhone will
   remind you." ("tomorrow 18:00", "15 Oct 18:00"); on the Mac "— your iPhone will remind you."; after Just pause:
   "Paused — no reminder. The list waits for you." On the iPhone, a time asks the app's one notification question
   (`PackingReminders.askToShow`); refused, it says in red "This device does not allow the app to remind you. Allow
   it in the device's Settings, under Notifications — or put the break in your calendar." (id `break-refused`).
   Opening the sheet with a break waiting shows its line, and This evening or Tomorrow (at its time) as chosen.
9. **The break's message** (`Library.tripMessages`): at `breakUntil`, while that is still ahead of now, the trip is
   at Pack now, not reviewed, not set off by then and has something left: title "Back to packing <trip name>" (else
   "your trip"), body "22 things left" / "1 thing left" (the overview's `left`). Id `break-<trip id>`. Recomputed at
   every change of the library, so the count is the one at the last change, as the door check's names are.
10. **Messages when a trip moves on** (with the device's switch on), for every trip not reviewed, with a start date
    and lines:
    - **Pack → On site**: "Have a good trip — <trip>" / "The trip is On site now: what you buy, use up or want to fix
      goes there.", on the first day at the time he leaves (`leaveAt`), else at **08:00** (`SET_OFF_MESSAGE_AT` —
      never at midnight, when the loop itself turns), while the trip is at Pack now (not yet set off, nothing bought on
      site). Id `moves-onsite-<trip id>`. Fifteen minutes after the door check, never the same minute.
    - **On site → Review**: "Welcome home — review <trip> in two minutes?" / "What did you use, what did you miss? The
      next list learns from it.", the day after the last day (the end date, else the start) at **10:00**
      (`REVIEW_MESSAGE_AT`). Id `moves-review-<trip id>`.
    - **Review → Refine: nothing.** He saves the review in the app; the app is in front of him.
    - A moment already past has none; a reviewed or deleted trip has none; new dates or a new time he leaves move them
      at the next change. Only the six soonest wait (`MOVES_ON_LIMIT`; an iPhone keeps 64 waiting notifications per
      app, and the packing reminders may take 48); every break waits.
11. **Where they come: the iPhone only.** He packs and travels with his iPhone; the Mac at home saying the same would
    be the same news twice (his word on the packing reminders, 2 Oct 2026; the door check is the same). The Mac shows
    Take a break whole — the overview, the choices, the break kept — and says it is the iPhone that reminds him; it
    has no "Messages when a trip moves on" switch and schedules nothing.
12. **The permission** is the app's one notification permission (shared with Remind me to pack and the door check;
    the system asks only once). Asked when he picks a break time, when he switches the messages on, or — with the
    switch on and the iPhone never asked — the first time a trip at Pack is opened (`TripMessages.askOnce`, from the
    pill's `.task`). Refused, nothing comes; Settings' red line (§06 3) says so.
13. **Add to Calendar** (shown while a break is waiting; a wide outlined button with a drawn calendar, id
    `break-calendar`). An entry "Back to packing <trip>", at the break, **30 minutes** (`BREAK_CALENDAR_MINUTES`), an
    alert at the start, its note "1 of 9 packed · 8 things left" (`Library.breakEvent`). **No calendar permission and
    no new entitlement:** on the **iPhone** the system's own New Event window, filled in (`EKEventEditViewController`;
    since iOS 17 it runs outside the app, and an app that only hands it an event needs no access — the app's iOS 18
    floor covers it); he taps Add or Cancel. On the **Mac** (no such window there) a calendar file, `Back to
    packing.ics` in the app's temporary folder (`Library.breakCalendarFile`: RFC 5545, floating local times, CRLF,
    text escaped, UID `break-<trip id>-<start>@ams-packing`, `DTSTAMP` = now in UTC, a `VALARM` at the start), handed
    to the app that opens calendar files (Calendar, unless he chose another) — which asks which calendar first. The
    Mac's existing `personal-information.calendars` entitlement (for To buy → Reminders) is NOT used: EventKit would
    need its own usage words and a permission question — more intrusive for one entry he confirms anyway. Nothing is
    added until he says so, on either device; the entry is not kept in step with the break afterwards (a new break
    is a new entry if he adds it).

### On the screens

- **The trip header** (spec 03): the count line is an `HStack`: "done/total" at the left, a `Spacer`, and at its end
  the pill `TakeABreakButton` (id `trip-break`): the drawn cup (`CupMark`, 16 pt) and "Take a break" (Footnote
  semibold), green, padding 10 sideways, min height `Metrics.chip` (28 / 22), a capsule of green at 10 % with a 1.2-pt
  green ring. Label "Take a break", value its words (rule 7) — the Mac folds a button's texts into the button.
- **The sheet** (`TakeABreakSheet`, id `break-sheet`; on the Mac at least 460 × 560): header "Take a break" (Title 3
  bold green) with the trip's name under it (Subheadline semibold muted), **Done** (filled green, Escape, id
  `break-done`). Then the overview card (id `break-overview`; padding 14, corner 12, `Theme.card`, 1.2-pt green
  border): "How far you have come" (Subheadline semibold muted), "41 of 63 packed" (Title 2 bold mono green, id
  `break-packed`), an 8-pt bar (green on green at 15 %), the group pills (`FlowRow`, 6 apart; each `break-group-<n>`, one
  element whose label is its words "Bike ✓" / "Golf 3 left": a done group green on green at 14 % with a green ring and
  a drawn tick, one with something left ink on `Theme.bg` with a hairline and "3 left" muted), then "To charge: …"
  (id `break-charge`) and "To do: …" (id `break-todo`), Callout semibold. Then "Continue when?" (Headline, id
  `break-when`) and the four choices, full-width rows 6 apart (`Metrics.tap` high, corner 10, a 1.2-pt green ring on
  green at 6 %; the chosen one filled green with white words, selected trait): ids `break-hour` (value "15:20"),
  `break-evening` (value "19:00"), `break-tomorrow` beside its time picker `break-tomorrow-time`, `break-pause` (value
  "no reminder"). Then `break-needs`, `break-said`, `break-refused` and Add to Calendar (`break-calendar`).
- **Settings** (spec 06 §3): inside the Remind me to pack card on the iPhone, under its own lines and a hairline, a
  second switch **"Messages when a trip moves on"** (id `settings-moves-on`, green) with "On this iPhone: "Have a
  good trip" when a trip sets off — at the time you leave, else at 8 — and the morning after its last day, at 10, a
  word to review it." The card's red "does not allow" line now sits under both switches (it holds for every message).

### Where it is kept

| Holder | Key | Value | Meaning |
|---|---|---|---|
| trip | `breakUntil` (`BREAK_UNTIL_KEY`) | "yyyy-MM-dd HH:mm" / absent | the break waiting: back to packing then. Synced, backed up, restored |
| device (`UserDefaults`) | `ams.movesOn` (`TripMessages.onKey`) | Bool, absent = on | Messages when a trip moves on, this device's own; cleared at launch under the UI tests |

The notifications live in the system's list, ids `break-<trip>`, `moves-onsite-<trip>`, `moves-review-<trip>`;
`userInfo` `tripId` + `trip` = `break` / `onsite` / `review`. `TripMessages.reschedule` removes every pending id
starting `break-` or `moves-` and adds the plan — run from `RootView` whenever the library settles (debounced 2 s),
when the app comes to the front, after a choice in the sheet and after the Settings switch. A tapped one goes through
the shared delegate (`PackingReminders`) to `TripMessages.open`: Home, then the trip (`model.tripToOpen`); for
`review` also `model.tripFocus.review`, and the trip opens its Review 0.7 s after it arrives (unless it is reviewed by
then).

### Tests (from the code)

Model `TakeABreakTests` (10, `Core/Tests/PackingLibraryTests/TakeABreakTests.swift`; a base template with a Passport, a
Charger and a Toothbrush, Bike with a Helmet, a Pump and the reminder "Book the bike rack", Golf with Clubs, Balls and
Tees; the trip "Sun week", 14–20 Oct 2026): `testTheOverviewSaysHowFarHeHasComeInTheTripsOwnSorting` ("4 of 8 packed",
"Common base 2 left · Bike 1 left · Golf 1 left" → "Bike ✓" once the reminder is ticked; Into: the bag and "To do";
When: the headings' counts; To do), `testToChargeIsCountedAsTheTripsCardShowsIt` (none two days before, "2 left", "1
left", "all charged"), `testTheChoicesAreAnHourThisEveningOrTomorrow` (over midnight, the 30-minute edge, tomorrow at a
picked time, pause), `testABreakIsKeptOnTheTripReplacedAndTakenAway` (replaced; records and a backup keep it; pause
leaves no key), `testABreakPastItsTimeOrAfterHeLeavesIsRefused`, `testTheBreakSaysWhatIsLeftAndGoesWhenEverythingIsPacked`,
`testATripSaysWhenItSetsOffAndWhenToReviewIt` (08:00 / the time he leaves / new dates / set off / bought on site /
switch off / reviewed / deleted), `testATripWithoutDatesOrLinesSaysNothing`,
`testOnlyTheSixSoonestMovesOnMessagesWaitButEveryBreakDoes`, `testTheBreakGoesInTheCalendarAsAFile` (the whole .ics,
escaping, over midnight). Each seen RED with a planted fault: no set-off rule for a break ("("nil") is not equal to
("Optional("You leave before then — pick an earlier time.")")"); the set-off message at midnight ("("2026-10-14 00:00")
is not equal to ("2026-10-14 08:00")"); the overview counting things only ("("4 of 7 packed") is not equal to ("4 of 8
packed")"); no limit ("("12") is not equal to ("6")"); a comma not escaped in the .ics; a break with nothing left still
coming ("XCTAssertTrue failed - a break with nothing left"). Parity: 211/211.

UI (`-showTripMessages` shows on the trip, under Sorting, what the device would schedule — no test can see a
notification — `trip-message-break` / `-onsite` / `-review`, `trip-message-none`; `-tapTripMessage break|onsite|review`
plays a tapped one for the first trip with lines; under the tests Add to Calendar shows what it would hand over,
`break-calendar-said`, instead of the system's window or Calendar):
`testTakeABreakSaysHowFarHeHasCome` (`-clockAt 14:00:00`; sorted by Template, the Passport ticked: `trip-break` "Take a
break"; the sheet "1 of 7 packed", the pills "Common base 3 left" and "Hiking 4 left" and no third, no To charge a month
ahead; In an hour "15:0…", This evening "19:00", Tomorrow, Just pause, no Add to Calendar yet; everything ticked → no
pill), `testABreakRemindsHimOnceAndGoesWhenEverythingIsPacked` (This evening → "Back to packing at 19:00…", chosen;
Add to Calendar would hand over "Back to packing Weekend in the hills · <today> 19:00–19:30 · 1 of 7 packed · 6
things left"; the pill "Back at 19:00"; `trip-message-break` "<today> 19:00 · Back to packing Weekend in the hills 6
things left"; reopened, This evening still chosen; Tomorrow replaces it — "Back tomorrow 18:00", the message
tomorrow 18:00; Just pause → "Paused…", "Take a break", no message; a break again, Tick everything → no message, and
a line unticked → still "Take a break"), `testABreakIsOnlyWhileTheTripIsBeingPacked` (`-uiTestingLeaving -clockAt
07:00:00`: In an hour → "You leave before then — pick an earlier time.", nothing kept; at 08:30 the trip is On site
and has no pill), `testATripSaysWhenItMovesOn` (the sample trip: "<day 30> 08:00 · Have a good trip — Weekend in the
hills" and "<day 33> 10:00 · Welcome home — review Weekend in the hills in two minutes?"; I leave at 07:30 → the
set-off message at 07:30; iPhone: Settings' `settings-moves-on` on, switched off → `trip-message-none`; Mac: no such
switch), `testATappedTripMessageOpensItsTrip` (`review` → the trip and `review-detail`; `break` → the trip, no review).
All five seen RED on the iPhone simulator, each by its own planted fault (one build): the pill at any step — "Take a
break on a trip that has set off"; the overview always by When — "("["≥1 week ahead 6 left", ""]") is not equal to
("["Hiking 4 left", "Common base 3 left"]")"; the break not taken away when everything is packed — "the break came back
with a line unticked: 'Back at 19:00'"; the switch ignored — "switched off, still: 'moves-onsite-… 07:30 · Have a good
trip — …'"; the review focus ignored — "Welcome home did not open the review". Green again without them, light and
dark (pictures `break-trip-door`, `break-sheet`, `break-chosen`, `break-trip-waiting`, `break-refused`,
`moves-on-messages`, `moves-on-settings`, `moves-on-tapped-review`), with 16 neighbouring tests (Settings' reminders
and their red line, the door check and its tap, On site from the time he leaves, every sorting's ticks, Template
sorting, the trip's header lines, reminders due) green too. By hand on the simulator (`-breakRealCalendar`): Add to
Calendar brings up the system's New Event window filled in — "Back to packing Weekend in the hills", 19:00–19:30, an
alert at the time of the event, the note "0 of 7 packed · 7 things left" — and no permission question.

### Open questions

- The break is on the trip, so a break taken on one device shows on the other; two devices choosing at the same
  moment: the later write wins (one key). Fine for one person; worth a word if two people pack one trip.
- A calendar entry added is not changed or removed when the break changes or everything is packed — the app has no
  calendar access to do it (by design: no permission asked). His word welcome if he wants it kept in step (that
  needs the calendar permission).
- The Mac never shows the messages. If he wants a Mac-only day (packing at the Mac with the iPhone elsewhere), a
  per-device switch for the Mac would be the way.

---

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
| 8 Oct 2026 | Always packed becomes a small core he makes; the big always-packed template becomes one he ticks for longer trips. A template moves into and out of Always packed on its page (several or none allowed; By transport unchanged). "Make a small core from this…" does the move in one step — with a pasted list (kits from indented lines; a thing in one kit only, a second one on request) and a copy kept first | "Always packed will be a small core, and [the big one] becomes a big kit that I tick." / "I would like you to move stuff around for me, so that the complete solution is served to me." Spec 04 (Activity area, §14, §14b), spec 03. |
| 10 Oct 2026 | "Only on some trips" is set once on the THING; each template's row follows it per kind (Season, Context, Transport, Food) unless the row sets its own, and goes back with one tap | "If I have an item on five templates, I need to change this in five places. Doesn't seem optimal." Part 14. |
| 12 Oct 2026 | A reminder's When list is changed AT ONCE, not held until a Save: the template's page has none, and the Reminders block makes everything at once (the When pick, a drag, a removal), as Your choices does | The open question of part 13 left it to the build ("if that page saves at once, the least surprising equivalent"); part 13, "The last three lists". |
| 13 Oct 2026 | "Has a battery" is a switch on the THING (its own key, not the web app's Charging flag, which a charging cable carries too); a trip lists those things on a To charge card from the day before it starts through its last day, kit contents included, with a charge tick of its own apart from packing; Your things filters by it | "Add a tick box for each item: Contains battery. And maybe implement a view where I can check all items that need charging." Part 15. |
| 13 Oct 2026 | On a plane trip, a thing with a battery in a CHECKED bag (any bag not a cabin bag, by the cabin's own rule; kit contents too) is a red line in Check before you go, after "not allowed" and before the liquids; a thing in no bag yet is not judged | His yes (0.76): airlines want lithium batteries and power banks in the cabin. Part 15, rule 8. |
| 13 Oct 2026 | A NEW kit starts with Check before each trip ON, unless he switched it off on that thing before (his off is remembered); kits made before 0.76 are not changed | He could not tick what was inside a kit while packing — the switch was off (0.76). Part 9, "A new kit starts checked". |
| 13 Oct 2026 | Check before you go and To charge become ONE card at the top of a trip, **Before you go**: the flags, then To do (the reminders due), then To charge, each part only when it has something and by its own rules; one count of everything left (flags + reminders due + things not charged), red if a flag will stop him, else orange, green "All set"; all set, the card folds to its one line and its chevron opens it (the fold decided by the build: a trip all charged keeps no list of struck-through rows at its top) | His yes to the picture (0.77). Spec 03 "Before you go"; part 15 rule 6. |
| 13 Oct 2026 | Take a break on a trip at Pack: an overview of how far he has come (the trip's own counts, his Sorting's groups, To charge, To do) and "Continue when?" — In an hour, This evening (19:00), Tomorrow (18:00 or his time), Just pause; ONE break per trip, kept on the trip (synced), gone when everything is packed; refused past its time or after he leaves; Add to Calendar with no permission (the system's New Event window on the iPhone, a calendar file on the Mac) | "Then I get tired and just want to relax… a reminder or a calendar event so that I feel calm… an overview of how far I have come." Part 16. |
| 13 Oct 2026 | Messages when a trip moves on, on the iPhone: "Have a good trip" at the time he leaves (else 08:00 on the first day), "Welcome home — review it" at 10:00 the day after the last; nothing for Review → Refine (he is in the app); a Settings switch, on until he turns it off; the Mac shows none | "I would like a message from the app when the Phase changes." Part 16. |
| 13 Oct 2026 | The activity-area headings are not in capitals: "GA · Goal Activity", "WET · Workout, Exercise & Training", "OE · Other Events", "Other Templates", "Always Packed", "By Transport" — his code stays in capitals; Create new trip, Trip settings and the Templates tab say them so (0.78) | "GA · Goal Activity — not all caps", "WET · Workout, Exercise & Training — not all caps", "Other Templates — not all caps" (his notes on the iPhone screenshots) |
| 13 Oct 2026 | A short trip's template has an icon of its own, the weekend bag (`weekendbag`), suggested by "short", "weekend", "small core", "kort", "helg"; he picks his own template's icon himself (0.78) | "a nice unique icon — not the same as Travel" |
| 13 Oct 2026 | Food's third answer reads "Mix" (stored `mixed` unchanged), so the three fit on one line (0.78) | "Self-sufficient, Eating out & Mix — keep short so that it all fits on one line." |
| 13 Oct 2026 | The Season pills carry the sun and the snowflake, as Travelling by carries its drawings — on Create new trip, Trip settings and Only on some trips; the More choices line stays words (0.78) | "same idea as Travelling by" |
| 13 Oct 2026 | The Quick line names his always-packed templates and says the airport checks plainly: "Quick packs only what you tick — not <names>, no Plane or RV template. Plane still turns on the airport checks." (0.78) | He did not understand "Plane and RV still count", and "Always" alone is cryptic — he thinks of his short-trip template by its name |

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
- Part 12: renaming a reminder that also sits on another template leaves the lines already on trips with the old
  name. Progress still counts reminders (so "All packed" waits for them) — if "never counted as things to pack" was
  meant to include the trip's x/y, that is a change to spec 03's decision of 5 Oct.

- "Change" for sections (part 2) was taken as the ORDER of the sections; if he meant something else, change part 2.
- "The road to 1.0" (all web-app features in, a real trip, a real restore, a quiet week): kept or dropped — his word
  is pending.
