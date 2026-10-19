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
| 16. Take a break and messages when a trip moves on | 0.77 | built (branch work/break077); Charge tonight 0.87 (branch work/charge087) |
| 17. Packing day — the stations of the Pack step | 0.79 | built (branch work/day079) |
| 18. Lost luggage — A: a bag's details for the desk | 0.80 | built (branch work/baginfo080) |
| 18. Lost luggage — B. Flights and stay, bag-tag numbers | 0.80 | built (branch work/flight080) |
| 18. Lost luggage — C. The Lost bag page (and his details for the desk) | 0.80 | built (branch work/lostbag080) |
| 19. Before you start — what to buy and get ready, in one place | 0.82 | built (branch work/beforestart082) |
| 20. Progress you can see — green groups and what's left | 0.82 | built (branch work/progress082) |

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
Kinds done come first in the kinds' order (Swim, Bike, Run, Strength, Mobility & breath, Hiking, Golf,
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
| Mobility & breath | mobility, breath work, breath, Mobility & Breath work, Mobility and Breath work, Mobility & breath, yoga, stretching |
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
| Yoga (57), mind and body (29), flexibility (62), cooldown (80), preparation and recovery (33) | Mobility & breath | — (either) |
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
  kit's own tick is refused until all inside are ticked (a section's tick-all too; Tick everything until 0.79); the last
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
    opens; after every line is ticked (Tick everything until 0.79): "Everything on this trip is packed or set aside." and no panel.
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
- **The things table** (0.86, his "Battery column: yes", 15 Oct 2026): a **Battery** column — the drawn battery mark
  in the row of each thing that has one, an empty cell for one that has none; a tap gives or takes it; it sorts,
  filters and takes Change all like every column. Spec 05, Table columns, "Battery".
- **Charge tonight** (0.87, his yes of 15 Oct 2026): at 20:00 the evening before the trip, the iPhone names what on
  To charge is not charged yet — only while something is left. It is one of the trip's messages: part 16, "0.87".
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
   ticking the line (packing it, a section's tick, Tick everything until 0.79, the kit's checked ticks) never marks charged.
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
- **The things table** (0.86, spec 05 "Table columns and cells", "Battery"): the column `battery`, "Battery", 68 wide,
  among the thing's own columns right before Charges, a starting column after Condition, and put ONCE among the
  columns he had chosen before it came (`ams.table.batteryArrived`). Its cell `table-<n>-battery`: the drawn battery
  mark (`ToChargeCard.battery`, 20 pt on the Mac, 24 on the iPhone, orange) when the thing has a battery, nothing
  when not; a tap turns it round (`Item.hasBattery` → `Library.setBattery`). Value "yes" / "no", selected trait when
  yes. Filter "Yes" / "No", Sort yes first ▲, Change all "Battery: yes" / "Battery: no" with an Undo that puts the key
  back or takes it away again.
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
packing, a section's tick and Clear every tick (Tick everything until 0.79) charge nothing; "2 of 3"; unticked, the keys go; only what is inside the kit now can be
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

- ~~The table has no column for "Has a battery" (its **Charges** column is the web app's `charging`). Worth one?~~
  Answered 15 Oct 2026 (0.86, his "Battery column: yes"): the table's **Battery** column (spec 05, Table columns,
  "Battery"). Charges stays the web app's flag, beside it.
- ~~Should a battery thing in a cabin bag on a plane trip say anything in Check before you go (spare batteries and
  power banks must travel in the cabin)? Not asked for; not built.~~ Answered 13 Oct 2026 (0.76, his yes): a thing
  with a battery in a CHECKED bag is a red line in Check before you go (rule 8); one in a cabin bag says nothing.
- Some airlines limit power banks by watt-hours, or want them out of the cabin bag at the gate; the app knows no
  capacity and says only where it goes. His word welcome.

## 16. Take a break and messages when a trip moves on

> **0.87** (his yes of 15 Oct 2026): one more message, **"Charge tonight"** — the evening before a trip, what still
> needs charging — see "0.87 — Charge tonight" at the end of this part.

> **0.84** (his asks of 15 Oct 2026): the header's door is a round cup (a compact capsule with the time while a break
> waits), Add to Calendar is filled once a time is chosen, and the reminder starts with 🎒 — see "0.84" at the end of
> this part. The sections below keep the words of 0.77 / 0.81 where they describe what was built then.

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
   true — a tick, a section's tick, Pack by voice, the other device; Tick everything until 0.79), removes the key. Unticking a
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
      app, and the packing reminders may take 48); every break waits. Since 0.87 Charge tonight is one of the six.
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
  word to review it." (since 0.87 it begins "On this iPhone: "Charge tonight" at 20:00 the evening before a trip, if
  something still needs charging; "Have a good trip" …"). The card's red "does not allow" line now sits under both
  switches (it holds for every message).

### Where it is kept

| Holder | Key | Value | Meaning |
|---|---|---|---|
| trip | `breakUntil` (`BREAK_UNTIL_KEY`) | "yyyy-MM-dd HH:mm" / absent | the break waiting: back to packing then. Synced, backed up, restored |
| device (`UserDefaults`) | `ams.movesOn` (`TripMessages.onKey`) | Bool, absent = on | Messages when a trip moves on, this device's own; cleared at launch under the UI tests |

The notifications live in the system's list, ids `break-<trip>`, `moves-onsite-<trip>`, `moves-review-<trip>`
(and since 0.87 `charge-<trip>`); `userInfo` `tripId` + `trip` = `break` / `onsite` / `review` (/ `charge`).
`TripMessages.reschedule` removes every pending id starting `break-` or `moves-` (or `charge-`, 0.87 —
`TripMessages.prefixes`) and adds the plan — run from `RootView` whenever the library settles (debounced 2 s),
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
tomorrow 18:00; Just pause → "Paused…", "Take a break", no message; a break again, every line ticked (Tick everything until 0.79) → no message, and
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
alert at the time of the event, the note "0 of 7 packed · 7 things left" — and no permission question. On GitHub's
Mac (a probe running these five with `testTheTripsPenSitsBesideItsNameAndReviewedBesideDone` and
`testSettingsTurnsOnPackingReminders`): all seven green — the sheet says "your iPhone will remind you", the Settings
card has no Messages switch (pictures of the Mac look, day; the runner's night setting did not reach the app).

### 0.84 — the cup, Add to Calendar that pops, and the backpack: his asks of 15 Oct 2026

> From his screenshots of a Mac trip at Pack ("Torren 2026 Rev 1", 15 Oct 2026), numbered as he gave them (2, 3, 4;
> his 5 is part 17 "0.84"). Built on branch `work/trims084`, written from the code: the button and the sheet
> `App/Sources/Screens/TakeABreak.swift`; the title `Core/Sources/PackingLibrary/TakeABreak.swift`
> (`BREAK_TITLE`); the filled amber `Core/Sources/PackingLibrary/PackingStations.swift`
> (`TripHeaderTone.breakFilled`). Where this section and the ones above differ, this one is the newer.

**2. Take a break → icon only.** The trip header's door to the break is a ROUND button that is only the drawn cup
(`CupMark`) — the same round button as the trip's pen beside its name (`RoundIconLabel`: `Metrics.tap` across, 36 on
the iPhone and 26 on the Mac; the cup at `Metrics.glyph`, 20 / 16; the amber at 10 % with a 1.4-pt amber ring,
`TripHeaderTone.takeABreak` as since 0.81). Label "Take a break", no value (VoiceOver says it once). **While a break
waits** it is a compact capsule just as tall: the cup (the same size), 4 apart, and the time **small** — Footnote
semibold, monospaced digits, the amber's words colour — "19:00" when the break is today, "Fri 18:00" (the day's
three letters, English) on another day (`TakeABreakButton.short`; a break is at most tomorrow when it is taken);
padding 8 / 5 before the cup (so the cup sits where it sat in the circle) and 10 after the time, the same fill and
ring. Its value then says it whole: "Back at 19:00", "Back tomorrow 18:00" (`TakeABreakButton.words`, rule 7) — the
words the pill showed until 0.84. The id `trip-break` is kept; it opens the same sheet. Decided by the build: the
weekday rather than "Tomorrow" keeps the capsule compact (his word "the time small"), and the value carries the
full words for VoiceOver.

**3. Add to Calendar pops once a time is chosen.** In the sheet, Add to Calendar (`break-calendar`, shown while a
break is waiting, rule 13) is **FILLED** — the break's amber `#a8651a`, day and night (`TripHeaderTone.breakFilled`:
white on it reads 4.6 : 1; the night ring `#e0a458` would be 2.2 : 1), the calendar mark and "Add to Calendar" white
— whenever one of the TIMES shows as chosen: picked on this visit (In an hour, This evening, Tomorrow), or the
waiting break recalled as This evening or Tomorrow when the sheet opens (rule 8). **Outlined** otherwise: the amber
at 10 % with a 1.4-pt amber ring, its words and mark in the amber's words colour (`#8a5215` by day, `#e0a458` at
night) — a break waiting from before that is none of the choices (In an hour, taken earlier: nothing shows as
chosen). Wide as before (`Metrics.tap` tall, corner 12, Body semibold, the 22-pt mark 10 before the words). Decided
by the build: it is in the break's amber in both looks (it was in the sheet's green until 0.84, as `WideButtonLabel`)
so filling it is the only change he sees; Just pause shows no Add to Calendar (no break waits). Under the UI tests
(DEBUG builds only) its value says "filled" / "outlined" — the tests' only way to see the look.

**4. The reminder starts with 🎒.** The break's notification title is **"🎒 Back to packing <trip>"**
(`BREAK_TITLE` = "\u{1F392} Back to packing"; body unchanged, "22 things left"), and the calendar entry's title the
same (`Library.breakEvent`; in the Mac's calendar file `SUMMARY` and the alert's `DESCRIPTION`, UTF-8 as RFC 5545
allows). His explicit ask, and the ONLY emoji in the app (his rule otherwise: no stock art) — not in the sheet's "Back
to packing at 19:00 — …" line, not in the moves-on messages, not in the calendar file's name (`Back to packing.ics`).

#### Tests (0.84)

- Model (`tools/test-core.sh`): `TakeABreakTests.testTheBreakSaysWhatIsLeftAndGoesWhenEverythingIsPacked` (the title
  "🎒 Back to packing Sun week") and `testTheBreakGoesInTheCalendarAsAFile` (the entry's title, `SUMMARY` and the
  alarm's `DESCRIPTION` with the backpack); `PackingStationsTests.testTheHeaderButtonsWearTheirOwnColoursAndReadDayAndNight`
  (the filled amber is an amber, white on it ≥ 4.5 : 1 by day and by night).
- UI (iPhone and the Mac): `testTheBreakIsACupAndTheStationChipsAreShort` (new; also part 17 "0.84") — the cup's
  label "Take a break", no value, its frame the pen's (± 1 pt) both ways; after This evening `break-calendar` is
  "filled" and would hand over "🎒 Back to packing …"; back on the trip the value "Back at 19:00", as tall as the pen,
  wider than it by more than 10 and narrower than 3.2 pens; `trip-message-break` "… 19:00 · 🎒 Back to packing …"; In
  an hour taken, the sheet opened again: "outlined", nothing selected. `testTakeABreakSaysHowFarHeHasCome`,
  `testABreakRemindsHimOnceAndGoesWhenEverythingIsPacked` and `testABreakIsOnlyWhileTheTripIsBeingPacked` now expect
  no value without a break (was "Take a break") and the backpack in the calendar entry and the message.
- **Seen red first** with planted faults (one planted build, every test run to its end): the model — the title
  without the backpack ("Back to packing Sun week" is not equal to "🎒 Back to packing Sun week"), the night fill
  `#e0a458` ("white on the filled amber by night: 2.18"); the iPhone — the old pill ("Take a break is not round like
  the pen: … 121.3 … against … 36.0"; "the capsule is not compact: … 130.3 …"), its words as the value ("Take a break"
  is not equal to ""), Add to Calendar never filled ("Add to Calendar after a choice is 'outlined'"), no backpack
  ("the calendar entry is 'Back to packing Weekend in the hills · …'", "the break's reminder: '… 19:00 · Back to
  packing Weekend in the hills 7 things left'"). Then green: the model 451 of 451 and parity 211 of 211; the iPhone
  ("Packing CI trims", iOS 27) 16 of 16 by day — the six above, the How it works test and the nine review tests of
  part 17 "0.84" — and the new test with the Packing Stations and the break-and-message tests by night; on GitHub's
  Mac (a probe branch, deleted after) ten green by day (the new test, the five break / stations / On site tests, Escape,
  the vault's saved review, the loop, How it works) and four again with the runner set to dark — whose setting did not
  reach the app, as before (the pictures are light). The Release build compiles for the iPhone and the Mac.

### 0.87 — Charge tonight: his yes of 15 Oct 2026

> The idea put to him on 15 Oct 2026, and his yes: "Charge-tonight reminder: the evening before you leave, your
> iPhone says what still needs charging — 'Charge tonight: Garmin, power pack, bike computer' — only if something
> is left to charge." Built on branch `work/charge087` and written from the code: the model
> `Core/Sources/PackingLibrary/ChargeTonight.swift` (`chargeTonight`, `chargeTonightNames`, the constants) and one line
> in `tripMessages` (`TakeABreak.swift`); the notifications `App/Sources/Store/TripMessages.swift` (the `charge-`
> prefix); the tap `RootView` (`TripMessages.open`), `LibraryModel.TripFocus.charge`, `TripScreen.takeFocus` and the
> scroll id on `ToChargePart` (`TripChecks.swift`). Where this section and the ones above differ, this one is the newer.

**What he gets.** On the iPhone, at **20:00 the evening before a trip's first day**, a notification titled **"Charge
tonight"** whose words are the names of the things on the trip still to charge — "Toothbrush, Power bank" — in To
charge's own order. A tap opens the trip with To charge in view. With everything charged (or nothing on the trip with a
battery) there is no message at all.

**The rules** (`Library.chargeTonight(tripId:now:)`, called by `tripMessages` for each trip):

1. **When**: the day before the trip's start date (`addDays(start, -1)` — the first of a month goes back to the last of
   the month before) at **20:00** (`CHARGE_TONIGHT_AT`). Decided by the build: home by then and in time to charge
   overnight, and not the minute of a break's "This evening" (19:00), so two messages never come at once. A time he
   leaves ("I leave at") does not move it.
2. **What**: title `CHARGE_TONIGHT_TITLE` = "Charge tonight" (his words; no trip name, as he put it). Body: the names of
   To charge's rows that evening (`chargeCard(tripId:today:)` with today = that evening — the very list the Before you
   go card, Take a break's overview and What's left read; part 15 rule 3: lines not set aside and not reminders whose
   thing has a battery, the things inside a kit by their own name, each thing once) that are **not charged**, in the
   card's order, joined ", "; more than four → the first four and "and N more" (`chargeTonightNames`,
   `CHARGE_TONIGHT_NAMES` = 4 — "A, B, C, D and 1 more"; the door check's way with names, at four).
3. **Only when something is left to charge**: no row, or every row charged → none. Charging and packing stay apart
   (part 15 rule 4): a packed line still to charge is still named.
4. **Not**: when the trip is reviewed, has no start date, or has no lines (at Plan); when the evening's moment is not
   ahead of now (20:00 itself has come — and a trip starting today has none); with the device's switch off.
5. **The switch**: it is one of the app's own trip messages, so it goes with the iPhone's **"Messages when a trip moves
   on"** (on until he turns it off; its words now name it first). Decided by the build: one switch for the app's own
   messages rather than a third switch; a break is his own ask and still needs none.
6. **Kept up to date** as every trip message is: the plan is made again whenever the library settles (a charge tick,
   a thing given a battery, new dates, a trip deleted or reviewed) and when the app comes to the front, so the names
   are those at the last change and the message goes the moment the last thing is charged. A charge ticked on the Mac
   reaches the iPhone's plan by sync; if the iPhone is not opened in between, the message can still come — opening it
   shows To charge as it is (All set, folded, when all is charged).
7. **Among the six soonest** (`MOVES_ON_LIMIT`): it is put with the moves-on messages, soonest first, so the iPhone's
   64-notification budget holds (spec 06 §3c). One per trip; id `charge-<trip id>`, so a new plan replaces it.
8. **The iPhone only**, with the one notification permission (rules 11 and 12 above): the Mac schedules nothing.
9. **Tapped** (`userInfo` `trip` = `charge`): Home, the trip, every line shown (not a door check's "Only what is still
   unticked"), and 0.7 s after it arrives Before you go's To charge is scrolled to the centre
   (`TripScreen.chargeAnchor` on `ToChargePart`; spec 03).

**On the screens.** Nothing new on a screen: the Settings switch's words (above; spec 06 §3) and How it works — under
*Packing a trip*, after "Last To charge…": "At 20:00 the evening before the trip, the iPhone says "Charge tonight" with
the names not charged yet (four, then how many more) — only while something is left to charge; tap it and the trip
opens at To charge."; under *Settings*, in "Messages when a trip moves on…": "The same switch holds "Charge tonight",
at 20:00 the evening before a trip, while something on it is still to charge."

**Where it is kept.** Nothing new is stored: the message is worked out from the trip's dates, its lines, the things'
`battery` key and the lines' charge ticks (part 15). The notification: id `charge-<trip>`, `userInfo` `tripId` + `trip`
= `charge`; the debug list's line `trip-message-charge`.

#### Tests (0.87)

- Model `ChargeTonightTests` (5, `Core/Tests/PackingLibraryTests/ChargeTonightTests.swift`, on `BatteriesTests.library()`
  and its trip "Weekend in the hills", 17–20 Oct 2026, To charge "Toothbrush", "Power bank" (in the Camp pouch),
  "Headlamp"): `testTheEveningBeforeItNamesWhatIsStillToCharge` (id, kind, "2026-10-16 20:00", "Charge tonight",
  "Toothbrush, Power bank, Headlamp"; soonest first before the set-off message; one charged → two names; all charged →
  none; one unticked → back; every line packed → still named), `testItComesOnlyWhileTheEveningIsAheadAndTheTripIsDated`
  (19:59 yes, 20:00 no, the next morning no; I leave at changes nothing; new dates follow, 1 Nov → 31 Oct; starting
  today none; undated none; the switch off, reviewed, deleted, no such trip none), `testNothingToChargeSaysNothing` (set
  aside not named; no battery → none, the other messages as they were; no lines → nothing),
  `testFourNamesThenHowManyMore` ("A, B, C, D and 1 more", "… and 3 more"; on the trip with the GPS watch put back and
  a Camera in the pouch: "Toothbrush, Power bank, GPS watch, Camera and 1 more"), `testItIsOneOfTheSixSoonestMessages`
  (four trips, three messages each → six, charge / set off / review twice). **Seen red first**, three planted builds,
  every test red by at least one fault: charged things still named ("("Optional("Toothbrush, Power bank, Headlamp")")
  is not equal to ("Optional("Toothbrush, Headlamp")")", "everything charged, still: Charge tonight"); the evening never
  passing ("XCTAssertNil failed: … - the evening has passed"); every name, no "and N more" ("("A, B, C, D, E") is not
  equal to ("A, B, C, D and 1 more")"); the switch ignored ("… - the switch is off"); the start day instead of the
  evening before ("("Optional("2026-10-17 20:00")") is not equal to ("Optional("2026-10-16 20:00")") - not the evening
  before the first day at 20:00"); outside the six ("("10") is not equal to ("6")"); a message with nothing to charge
  ("XCTAssertNil failed: "TripMessage(… body: "")""). Then green: the model 635 + 451 of 635 + 451; parity 211 of 211.
- UI (iPhone and the Mac; `-uiTestingBattery`, the kits sample with its first trip starting tomorrow and To charge
  "Toothbrush" (`trip-charge-0`) and "Power bank" (`trip-charge-1`)): `testChargeTonightNamesWhatIsLeftAndGoesOnceAllIsCharged`
  (`-showTripMessages -clockAt 14:00:00`: `trip-message-charge` "charge-… · <today> 20:00 · Charge tonight Toothbrush,
  Power bank"; the power bank charged → "… Charge tonight Toothbrush"; both charged → no `trip-message-charge`, the
  set-off message still there; the card's chevron `trip-beforego-fold` opened and the toothbrush unticked → back) and
  `testATappedChargeTonightOpensTheTripAtToCharge` (`-tapTripMessage charge`: `trip-detail`, `trip-beforego-part-charge`,
  `trip-charge-0` hittable, no `trip-unticked-only`, no review). **Seen red first** on the iPhone simulator ("Packing CI
  charge", iOS 27), one planted build: charged things still named — "the power bank is charged, still: 'charge-… ·
  <today> 20:00 · Charge tonight Toothbrush, Power bank'"; the tap's focus not handled (it fell to a door check's view)
  — "XCTAssertFalse failed - Charge tonight opened on just the unticked lines". Then green: by day the two with seven
  neighbours (`testATappedTripMessageOpensItsTrip`, `testATripSaysWhenItMovesOn`, `testToChargeIsTickedApartFromPacking`,
  `testABatterySwitchOnAThingPutsItOnTheTripsToCharge`, `testABreakRemindsHimOnceAndGoesWhenEverythingIsPacked`,
  `testTakeABreakSaysHowFarHeHasCome`, `testHowItWorksExplainsThePackingDayStations`) — 9 of 9; by night the two with
  `testATripSaysWhenItMovesOn` and `testToChargeIsTickedApartFromPacking` — 4 of 4 (pictures `charge-tonight-waiting`,
  `charge-tonight-tapped`, `moves-on-settings` with the switch's new words). On GitHub's Mac (a probe branch running the two with `testATappedTripMessageOpensItsTrip`,
  `testATripSaysWhenItMovesOn` and `testToChargeIsTickedApartFromPacking`, deleted after): all five green, by day
  (pictures of the Mac look) — its first run found the test, not the app, wrong: the card's chevron was looked for
  among groups (`appears`) where it is a button; it is tapped as a button now, and "Only what is still unticked" is
  looked for as the text it is. The Release build
  compiles for the iPhone and the Mac.

### Open questions

- The break is on the trip, so a break taken on one device shows on the other; two devices choosing at the same
  moment: the later write wins (one key). Fine for one person; worth a word if two people pack one trip.
- A calendar entry added is not changed or removed when the break changes or everything is packed — the app has no
  calendar access to do it (by design: no permission asked). His word welcome if he wants it kept in step (that
  needs the calendar permission).
- The Mac never shows the messages. If he wants a Mac-only day (packing at the Mac with the iPhone elsewhere), a
  per-device switch for the Mac would be the way.

## 17. Packing Stations (the Packing day until 0.81)

> **0.86** (his yes of 15 Oct 2026: "Yes - no tags inside another bag"): Tags asks only about the bags that travel
> by themselves — a bag packed inside another bag on this trip (a toiletry bag in the suitcase) has no card and does
> not count; one quiet line under the cards names it. See "0.86" at the end of this part.

> **0.84** (his ask of 15 Oct 2026): the row says "Stations" and its chips the short words — Bags, Pack, Weigh, Tag,
> Photo, Ready — Pack without its count; the header's Review only once the trip has started. See "0.84" at the end of
> this part.

> **Renamed in 0.81** — his decision of 14 Oct 2026: "Packing day" became **"Packing Stations"** everywhere he reads
> it (see "0.81" at the end of this part). The sections below keep the words of 0.79 where they describe what was
> built then; the ids, keys and code names never changed.

> His yes (13 Oct 2026), from his own packing walk-through: the bags laid out on the living-room floor for a week;
> pack per kit, then per template, then per place it is kept; take breaks; weigh; name tags and AirTags; photos for
> lost luggage; ready. A guided **Packing day** inside the trip's Pack step: a row of STATIONS — **Bags out → Pack →
> Weigh → Tags → Photos → Ready**. Each turns green when it is done; a tap opens it; the next open one is offered.
> The marks are his picks from the station sheet of 13 Oct 2026 (Packing day B, Bags out A, Pack C, Weigh A, Tags A,
> Photos C, Ready A). Built on branch `work/day079` (0.79); written BEFORE it was built, then brought in line with the
> code the same day (the code wins where they differ). The model:
> `Core/Sources/PackingLibrary/PackingDay.swift`; the row, the sheet and its stations:
> `App/Sources/Screens/PackingDay.swift`. Per screen: spec 03 (the trip screen's station row, the Bags card's photo
> of all the bags), spec 05 (a bag's page: Has an AirTag), spec 01 §1.12 (the keys).

### What he gets

- On a trip being packed, under the loop strip, ONE slim row: the Packing day's mark (a sun rising out of an open
  case) and "Packing day", then six chips — each its own drawn mark and a short name: **Bags out · Pack · Weigh ·
  Tags · Photos · Ready**. A station that is done is filled green with white words; the next one to do (the first not
  done, in that order) is lit in a light green with a stronger ring; the rest wait in a green line on the card. Pack's
  chip carries the count, "12/40". Too wide for the iPhone, the whole row scrolls sideways, from one edge of the
  screen to the other, and keeps the next station (and the one after it) in view; where it fits (the Mac) it stands
  still.
- A tap on **Pack** goes to the list (it IS the trip's list). A tap on any other station opens the **Packing day**
  sheet on it: the same row at the top, the station under it, and at the foot one full-colour button that offers the
  next open station — "Next: Weigh".
- **Bags out** — the trip's bags, each with a tick "out". **Weigh** — the luggage scale, one bag after another.
  **Tags** — per bag a Name tag tick, and an AirTag tick for a bag that has one. **Photos** — one photo of all the
  bags together, and each bag's own photo. **Ready** — every station's state, "Ready to go" once all are green, and
  the trip's "I leave at" (the door check) right there.
- When the last thing is ticked, the app opens **Weigh** by itself — once per trip, a moment after the last tick
  settles (never while he is still ticking).

### The rules (decided 13 Oct 2026, before the build)

1. **Only at Pack.** The row shows while the trip's step is Pack — `loopStep` on the trip screen's clock, the same
   reading as the loop strip and Take a break (part 16) — so it goes the moment the trip sets off (On site), and a
   trip at Plan (no lines), Review or Refine has none. Not while the trip is opened from a place's code (that view
   shows only the place's lines, spec 03). Quick trips have it as Full trips do: Quick decides what is ON the list,
   not how he packs it. The row does not depend on dates: an undated trip with lines is at Pack and has it.
2. **The trip's bags** are the bags its Bags card lists (`weighedBags`, spec 03): every bag that a line not set aside
   is packed in, reminders left out, in the card's order (`bagLoads`: the web app's built-in bag order, then first
   appearance) — WITHOUT "Not in a bag" (lines with no bag, the card's "Other": loose things are not a bag to lay
   out, weigh, tag or photograph). A bag is named as the trip's lines name it; one of his own bags (Care → Bags) or
   only a name on the lines — both count. `Library.dayBags(tripId:)`.
3. **A trip with no bags** (every line "Not in a bag", or nothing left that is not set aside): Bags out, Weigh, Tags
   and Photos cannot be done — their chips are drawn in the muted ink on a dashed hairline ring, their value says "no
   bags yet", and opened, each says why: "No bags on this trip yet. Give its things a bag — Usually packed in, on a
   thing's page — and they show here." (id `day-nobags`). They are left out of what Ready waits for, and out of
   "the next open station"; with no bags, Ready is green once everything is packed.
4. **When each station is done** (`PackingDay.done`):
   - **Bags out**: every bag of the trip is ticked out. Kept on the trip, `dayBagsOut` = the names ticked
     (`DAY_BAGS_OUT_KEY`); compared by `normName`. Words "1 of 2 out".
   - **Pack**: everything packed — the trip header's own rule (`progress(trip.entries)`: total > 0 and done ==
     total; set aside counts as handled; reminders count, as "All packed" waits for them). Words "12 of 40 packed";
     the chip "12/40".
   - **Weigh**: every bag has a luggage-scale reading (`weighed`, the Bags card's key — the same reading, typed in
     either place). A sum of the things' weights is not a weighing. Words "1 of 2 weighed".
   - **Tags**: every bag's Name tag is ticked, and every bag that has an AirTag has its AirTag ticked. Kept on the
     trip: `dayNameTags`, `dayAirTags` = the names ticked. Words "3 of 4 ticked" (the ticks asked for). Since 0.86
     only the bags that travel by themselves (`PackingDay.tagged`) — not one packed inside another bag on this trip
     (see "0.86").
   - **Photos**: every bag has at least one photo of it packed (the Bags card's `bagPhotos`, up to three — the same
     photos), and, with two bags or more, the photo of all the bags together exists. Kept on the trip:
     `dayBagsPhoto` = that photo's id (`DAY_GROUP_PHOTO_KEY`; an ordinary photo record, synced like any other). A
     photo still on its way from the other device counts (its id is stored). Words "1 of 3 photos".
   - **Ready**: every other station that can be done is done. Words "3 of 5 done"; done: "Ready to go".
5. **One bag** (the trip's every line in the same bag): no photo of all the bags together is asked — the bag's own
   photo is that photo. Photos is done with the bag's own.
6. **Has an AirTag** is the BAG's, not the trip's: a switch on the bag's page (spec 05, id `bag-detail-airtag`) and
   the same switch under the bag in the Tags station (id `day-tag-<n>-has`); kept on the bag (its thing's extra key
   `airTag`, `AIRTAG_KEY`, true or absent). Switched on in the Tags station for a bag that is only a name on the
   lines, the name BECOMES one of his bags (and shows in Care → Bags) — as "Goes in the cabin" does from the trip
   (spec 05). Switched off, the AirTag tick is no longer asked (and a tick kept for it is ignored, not removed).
7. **The next station** (`PackingDay.current`): the first, in the row's order, that can be done and is not; when all
   are done, Ready. Highlighted on the trip's row (selected trait). In the sheet the station SHOWN is the highlighted
   one. **Next** (`PackingDay.next(after:)`): the first open station after the one shown, round from the start again,
   never the one shown; Ready only when nothing else is open; none on Ready. "Next: Pack" closes the sheet and goes
   to the list.
8. **Pack goes to the list.** On the trip screen a tap on Pack scrolls the trip to the top of its list (the Sorting
   row); in the sheet, the Pack chip and "Next: Pack" close the sheet first. Nothing else about the list changes.
9. **Weigh opens by itself — once.** When the trip turns all packed while it is open on this device's screen (a tick,
   a heading's tick, Pack by voice, or the other device's ticks arriving), and the trip is at Pack,
   has bags, Weigh is not done and the trip has never shown it (`dayWeighOffered`, `DAY_WEIGH_OFFERED_KEY`, true
   once; `Library.weighOpensItself`), the sheet opens on Weigh **1.5 s** after the moment (the green sweep takes
   1 s) — if all that still holds then, the trip is not opened on a place's code, and none of the trip screen's own
   sheets (the review, a thing opened from Before you go, On site) is up (`TripScreen.weighByItself`). The trip keeps
   that it was offered only once the sheet has REALLY come up (`PackingDaySheet(byItself:)` writes the key in its
   `onAppear`) — synced, so the other device does not offer it again; unticking and ticking again does not bring it
   back. A sheet already up that the trip screen does not own — Pack by voice's panel, whose walk can tick the last
   thing — keeps another from coming: the request lets go 1.5 s later unshown and unmarked, and is made again when
   the panel goes (`VoiceSortingRow`'s `closed`, 0.79) or the next time the trip turns all packed. A trip opened when
   it is already all packed does not open it.
10. **Weigh, one bag after another.** The station lists the bags as the Bags card does (name, weight against its max,
    the bar and its colour — one row, `BagWeightRow`, shared with the card). The first bag without a reading is open,
    its field "kg on the scale" ready; Save keeps the reading and opens the next bag without one. A bag already
    weighed opens on a tap (its reading in the field); Clear takes a reading away. Save with nothing typed says
    under it "Type what the scale says, in kg." (red, id `day-weigh-needs`) — never a grey button. The reading is the
    Bags card's (`setWeighed`): over its max, the row turns red here and there.
11. **Bags out and Tags are ticks of the TRIP**: a tick per bag, at once (no Save), synced with the trip's record.
    A bag no longer on the trip (its lines moved away or set aside) is not asked any more; what was ticked for it
    stays stored, ignored, and counts again if the bag comes back. **A bag renamed** (Care → Bags): its ticks go
    along to the new name on every trip, as its scale reading does (`moveBagNotes`) — only where the new name had
    nothing of its own on that trip; where two bags become one, or the bag is deleted with "No bag", the moved bag's
    ticks are dropped (the bag kept was not laid out or tagged by them).
12. **The photo of all the bags together**: ONE per trip. Take (iPhone camera) or Choose (photo library) — under the
    tests a drawn picture; Remove (asks nothing: the photo goes unless something else shows it); a new one replaces
    it. It is kept with the trip, removed with the trip (`deleteTrip`), counted as in use (`photoInUse`,
    `photoIdsInUse` — so Worth a look never offers it as unused). It also shows in the trip's Bags card (opened), at
    the top, at every step — "All your bags" with the thumbnail, a tap shows it large: for the airline desk when a bag
    is lost, after he has left.
13. **Ready pairs with the door check.** The Ready station lists the five others, each "✓ done" in green or its words
    in the ink ("Weigh — 1 of 2 weighed"), each a button that opens that station (Pack: the list). All green: "Ready
    to go" (Title 2 bold green, id `day-ready-go`). Under it the trip's **I leave at** block — the same one as Trip
    settings (`LeaveTimes`, ids from `day-leave`), its times saved at once: 15 minutes before, the iPhone names what is
    still unticked (part 6).
14. **Afterwards.** From On site on the row is gone; what the day made stays where it is useful: the scale readings
    and every bag's photos in the Bags card (as before), the photo of all the bags there too (rule 12). The ticks of
    Bags out and Tags stay on the trip, unseen.
15. **Not carried**: "Start a new trip from this one" copies none of the day's keys (a new trip starts with no bag
    out, no tag, no photo — `startAgain` copies no trip key but the laundry nights); a SHARED trip drops them all
    (`justTheList`: the ticks, the photo id, the offered mark — his packing, not theirs). A reviewed trip keeps them as
    they were (history; nothing shows them).
16. **Where it lives — one device or both.** Everything is on the trip (or the bag), so the Mac and the iPhone show
    the same day; a tick on one is on the other a moment later. Take and Choose a photo: the iPhone takes one with its
    camera; the Mac chooses one. The Mac shows the row and the sheet whole.

### On the screens

- **The trip screen** (spec 03): under the loop strip (16 sideways, 2 tighter than the strip's own 10 under it, 8
  above the scroll area), fixed — it does not scroll with the list — the row `PackingDayRow` (container id
  `day-row`): the day's mark (17 pt, the Pack step's readable green) and "Packing day" (Footnote semibold, the same
  green; one element `day-title`, a heading), 8 apart, then the chips, 6 apart: each a button `day-station-<key>`
  (`bags`, `pack`, `weigh`, `tags`, `photos`, `ready`), label its name, value its state — "done", "no bags yet", or
  its words (rule 4); the next one selected. A chip (`StationChip`): its mark (15 on the iPhone, 13 on the Mac) and
  its name (Footnote semibold), Pack with "12/40" (monospaced digits) 5 after it, padding 9 sideways, `Metrics.chip`
  tall, a capsule: done = green fill, white; next = green at 14 % with a 2-pt green ring, green words; done AND the
  one highlighted (Ready once everything is green) = the green fill with a white ring 2.5 inside its edge; open = the
  card with a 1.2-pt ring of green at 70 %, green words; cannot = the card, a dashed 1-pt hairline, muted words.
  `ViewThatFits`: the line as it is when it fits (the Mac), else the whole line — title included — in a sideways
  scroll (no indicator) reaching 16 past the margins to the screen's edges, which scrolls only as far as needed to
  show the next station and the one after it (`PackingDayRow.inView`): at the start nothing moves and the title stays
  in view.
- **The sheet** (`PackingDaySheet`, id `day-sheet`, from the row's `.sheet(item:)`; on the Mac at least 460 × 600):
  header (padding 16) — the day's mark (22) and "Packing day" (Title 3 bold, readable green; one element
  `day-heading`), the trip's name under it (Subheadline semibold muted), **Done** (filled green, Escape, id `day-done`).
  The chips again, WRAPPING (`FlowRow`, two lines on the iPhone; ids `day-sheet-station-<key>`; the station shown is
  the highlighted one, a tap shows another, Pack closes the sheet and the trip scrolls to its list 0.45 s later). Then,
  in a scroll, the station (container `day-view-<key>`, 10 apart) and at its foot **Next: <station>** (Body semibold
  white on a full-width green rounded rectangle, radius 12, `Metrics.tap` tall, 8 above; id `day-next`, value = the
  station's key) — none on Ready. Opened on Pack (never: Pack scrolls) it would show Bags out.
  - **Bags out** (`day-view-bags`): "Lay every bag out where you pack, and tick it as it comes out." (Footnote
    muted). Per bag a row button `day-bag-<n>`: a tick circle (green), the bag's name (Body), "6 things" (Footnote
    muted, monospaced); value "out" / "not out", selected when out. All out: "All bags are out." (green, id
    `day-bags-said`).
  - **Weigh** (`day-view-weigh`): "One bag after another: hang it on the luggage scale and type what it says."; per
    bag a card (padding 12, radius 12, `Theme.card`, a hairline — red when the bag is over) holding the button
    `day-weigh-<n>` (the shared `BagWeightRow`, value = the bar in words as on the Bags card: "not weighed", "fine, 80%
    of its max"…; a tap opens or closes the bag's field) and, for the open bag, the field "kg on the scale"
    `day-weigh-<n>-scale` (decimal pad, Return saves), **Save** `day-weigh-<n>-save` (filled green capsule),
    **Clear** `day-weigh-<n>-clear` (Subheadline semibold muted, only with a reading), `day-weigh-needs` under them
    (it goes as soon as anything is typed). Opening the station (or switching to it) opens the first bag without a
    reading, its field empty. All weighed: "Every bag is weighed." (`day-weigh-said`).
  - **Tags** (`day-view-tags`): "A name tag on every bag, and the AirTag in each bag that has one." Per bag a card
    (as Weigh's): the bag's name (Subheadline semibold), the tick rows **Name tag** (`day-tag-<n>-name`) and — when the
    bag has an AirTag — **AirTag in it** (`day-tag-<n>-air`) (a `TickCircle` and the words in Body, `Metrics.line`
    tall, value "on"/"off", selected when on), and the switch **Has an AirTag** (`day-tag-<n>-has`, green, its words
    Footnote semibold muted, a mini switch on the iPhone, a small check box on the Mac). All on: "Every tag is on."
    (`day-tags-said`). On a plane trip (0.80, part 18 B) the lead adds "At check-in, type the number on each checked
    bag's tag." and each CHECKED bag's card (not a cabin bag's) holds, between the ticks and Has an AirTag, **Bag-tag
    no.** and its field (`day-tag-<n>-number`); the number does not count for Tags' green.
  - **Photos** (`day-view-photos`): with two bags or more first a card **All your bags** (Subheadline semibold) — "One
    photo of all of them side by side: for the airline desk if one goes missing." — and its photo (`GroupPhotoRow`:
    `day-group-thumb`, 80 pt, corner 8, a tap shows it large captioned "All your bags"; **Remove** `day-group-remove`
    under it) or the way to take one (`PhotoTakers`, shared with a bag's own photos since 0.79: `day-group-photo` —
    "Photo of all the bags" under the tests; on the iPhone "Take a photo" when it has a camera and "Choose a photo"
    `day-group-photo-pick`; on the Mac Choose only). With one bag instead the line "A photo of the bag packed — to
    repack from, and for the airline desk if it goes missing." Then per bag a card: its name — with, since 0.80, the
    bag's own photo small before it (`day-photo-<n>-look`) while the trip has no photo of it packed (part 18 A rule
    10; never counted here) — and the bag's photos packed on this trip
    (`BagPhotoRow` with the ids `day-photo-<n>-photo`, `-photo-pick`, `-photo-thumb-<k>`, `-photo-remove-<k>`,
    `-photo-full` — the row takes an id prefix since 0.79; on the Bags card it stays `bag-<n>`). All there: "Every
    photo is taken." (`day-photos-said`).
  - **Ready** (`day-view-ready`): the five stations, each a row button `day-ready-<key>` (`Metrics.row` tall, a
    hairline under it: its mark at 18 — green when done, ink when open, muted when it cannot be done — its name in Body,
    and at the right a drawn tick and "done" in green, or its words in Subheadline monospaced ink ("no bags yet"
    muted); label its name, value its state); a tap opens that station (Pack: the list). "Ready to go" (Title 2 bold
    green, `day-ready-go`) when all are green, else "Not yet — 2 stations left." (Subheadline semibold muted,
    `day-ready-left`); then, 4 below, the I leave at block (`LeaveTimes`, ids from `day-leave`: `day-leave-frame`,
    `day-leave-out-add`, `day-leave-out-time`, `day-leave-out-check` …), whose times are written to the trip at once
    (`setLeaveTime`) — the same keys Trip settings shows and saves.
- **The Bags card** (spec 03), opened: when the trip has a photo of all its bags, its first row after the colour key:
  the thumbnail (44 pt, corner 6) and "All your bags" (Subheadline semibold ink), one button `bags-group-thumb`; a tap
  shows it large (`BigPhoto`, captioned "All your bags"). Its bag rows are the shared `BagWeightRow`.
- **How it works** (spec 06 §7): a part of its own, `PackingDayGuideCard` (`guide-packingday`), right after *Packing a
  trip* — what the day is and where it sits, each station in order with its mark and what the mark shows, what it does
  and what turns it green, how to get from one to the next, a trip without bags, afterwards (his ask of 13 Oct 2026:
  "remember to write about the Packing-Day-Stations in the How-this-works"). **Words** (spec 06 §10): "Packing day".
- **A bag's page** (spec 05): under "Goes in the cabin", the switch **Has an AirTag** (`bag-detail-airtag`, orange) —
  "On a Packing day, Tags asks you to check it is in the bag." (since 0.81 "In Packing Stations, Tags asks you to check
  it is in the bag.")

### Where it is kept (the web model sees nothing new)

| Holder | Key | Value | Meaning |
|---|---|---|---|
| trip | `dayBagsOut` (`DAY_BAGS_OUT_KEY`) | `[bag name]` / absent | the bags ticked out (Bags out); removed when empty |
| trip | `dayNameTags` (`DAY_NAME_TAGS_KEY`) | `[bag name]` / absent | name tag on (Tags) |
| trip | `dayAirTags` (`DAY_AIRTAGS_KEY`) | `[bag name]` / absent | AirTag in it (Tags) |
| trip | `dayBagsPhoto` (`DAY_GROUP_PHOTO_KEY`) | photo id / absent | the photo of all the bags together (Photos) |
| trip | `dayWeighOffered` (`DAY_WEIGH_OFFERED_KEY`) | true / absent | Weigh opened by itself once, when everything was packed |
| item (a bag) | `airTag` (`AIRTAG_KEY`) | true / absent | Has an AirTag; never written false |

All synced with their record, backed up and restored with it; the bag-name lists follow a rename (rule 11); every one
dropped in a shared trip and not copied by Start a new trip from this one (rule 15). Parity: 211/211 (only `extra`
keys).

### Tests

Model `PackingDayTests` (10, `Core/Tests/PackingLibraryTests/PackingDayTests.swift`; a base template with a Passport, a
Charger and a Toothbrush in the carry-on, Hike with Boots and a Jacket in the Day pack — one of his bags — and a Water
bottle in no bag; the trip "Hill week", 20–24 Oct 2026): `testEachStationWearsHisPick` (the six keys, the day's label,
Pack's list into the case, Photos' tilted print, Pack's mark not the Pack step's, seven different marks, only the
commands the app draws), `testTheDayAsksAboutTheBagsTheTripsBagsCardLists` (the card's bags without "Other"; a bag
whose lines are all set aside is not asked; one bag: no photo of all of them, "0 of 1 photo"),
`testATripWithoutBagsCannotDoTheBagStationsAndIsReadyWhenPacked` ("no bags yet", Pack next, Ready once packed),
`testEachStationIsDoneWhenEveryBagHasWhatItAsks` (every station's words from "0 of 2 out" to "done"; a tick by another
spelling is one tick; "Other" refused; set aside counts as packed; the scale reading, not the sum; the AirTag asked
only once the bag has one, a tick for a bag without one not counted; the photo of all of them; "Ready to go"; a line
unticked → "4 of 5 done", Pack next), `testTheNextStationIsOfferedRoundTheRow`, `testHasAnAirTagIsTheBagsOwn` (off is
no key; only a bag; a name becomes a bag when switched on, not when off; "Other" refused),
`testThePhotoOfAllTheBagsIsOnePerTripKeptInUseAndGoesWithTheTrip` (in use, never offered by Worth a look, replaced,
removed, gone with the trip), `testWeighOpensItselfOnceWhenEverythingIsPacked` (not before, not On site, not when all
are weighed, never twice), `testTheDaysTicksFollowABagsRenameAndAreDroppedWhenBagsBecomeOne` (rename; deleted into the
carry-on; deleted to no bag), `testTheDayIsSyncedBackedUpAndRestoredButNeitherSharedNorCopied` (records, a backup, the
photo and Has an AirTag through both; `justTheList` and `startAgain` carry none of the keys). Each seen RED with a
planted fault: Pack's mark the step's ("("["bagsOnFloor", "packedCase", …]") is not equal to ("["bagsOnFloor",
"listIntoCase", …]")"); `current` ignoring a station that cannot be done ("("bagsOut") is not equal to ("pack")"); the
AirTag tick counted for a bag without one ("("4") is not equal to ("3")"); the photo of all the bags asked with one bag
("("0 of 2 photos") is not equal to ("0 of 1 photo")"); `justTheList` keeping the keys ("a shared trip carries
dayBagsOut"); the ticks moved when two bags became one ("the deleted bag's name tag tagged the carry-on");
`photoIdsInUse` without the photo ("Worth a look offers the photo of all the bags"); `weighOpensItself` ignoring the
mark ("Weigh offered twice"); `setBagAirTag` writing false ("off is no key, never false"); `next(after:)` ignoring done
("("…weigh") is not equal to ("…tags")"). All model tests 566 + 451 green; parity 211/211.

UI (`-uiTestingPackingDay`, `SampleLibrary.packingDay`: the carry-on with 5 lines and no AirTag, the Day pack with 2
and an AirTag; `-packingDayAlmost`: every station done but the Map; `-dayWeighItself`: under the tests Weigh opens by
itself ONLY with it — older tests tick everything on the sample's trip at Pack, and the sheet covered their next
step, seen on GitHub's Mac in the first probe): `testThePackingDayLeadsFromBagsOutToTheList` (the row, Bags out
"0 of 2 out" and next, Pack "0 of 7 packed"; Bags out's sheet: the two bags and no third, each ticked out, "All bags
are out.", green, Next: Pack goes to the list, Pack next; `-uiTestingOnSite`: no row),
`testWeighOpensByItselfOnceAndWeighsOneBagAfterAnother` (every heading's tick → Weigh by itself; closed, a line unticked and
ticked again → not again; Save with nothing typed says what is missing; 6.4 → "fine, 80% of its max" and the Day pack
next; "Every bag is weighed."; the Bags card says "6.4 kg weighed"), `testTagsAskForTheAirTagOnlyInABagThatHasOne` (no
AirTag tick for the carry-on, one for the Day pack, "0 of 3 ticked" → done; Has an AirTag switched on for the carry-on
→ its tick, "3 of 4 ticked"; both bags' pages say Has an AirTag — the carry-on became one of his bags),
`testPhotosAskForAllTheBagsTogetherAndEachBag` ("0 of 3 photos" → done; Remove → "2 of 3 photos"; the Bags card shows
`bags-group-thumb` and the bag's own photo), `testReadySaysWhatIsLeftAndPairsWithTheDoorCheck` ("Not yet — 1 station
left.", Pack "6 of 7 packed", no Next on Ready, a row opens its station, I leave at → "Check 07:15" here and in Trip
settings; the heading's tick → Ready done and selected, Weigh (all weighed) stays shut, "Ready to go"), and (spec 06 §7)
`testHowItWorksExplainsThePackingDayStations`. Each seen RED on the iPhone simulator with its own planted fault: the
row at any step — "a Packing day on a trip that has set off"; the offered mark never kept — "Weigh opened by itself a
second time"; the AirTag tick for every bag — "the carry-on has no AirTag, yet it is asked for"; the Bags card without
the photo — "the Bags card does not show the photo of all the bags"; Ready's I leave at not saved — "''" (no "Check
07:15"); How it works without the part — "How it works has no Packing day part". Green again without them, day and
night (pictures `day-row`, `day-bags`, `day-row-pack`, `day-weigh-itself`, `day-weigh`, `day-tags`, `day-bag-airtag`,
`day-photos`, `day-bags-card`, `day-ready-left`, `day-ready`, `day-howitworks-1`, `-2`). On GitHub's Mac (a probe
running these six with the luggage scale, the bag photos, the cabin tests and the loop's guide test): all green, the
pictures of the Mac look kept — the first probe also showed the bag-photo test covered by Weigh opening by itself
(hence `-dayWeighItself`) and Ready cut off in the trip's 520-point window (hence the wrap on a narrow Mac window).

Around them, on the iPhone simulator, 132 neighbouring tests (every test that opens a trip, a bag or the guide, every
test using `setSwitch` or `scrollWithin`, and the smoke set): 131 run, 4 skipped (Mac only), none red — after a first run of 120 had found 12 red, every one from the row (the
three causes below). Three of the harness's helpers changed
for the row: `scrollWithin` swipes the TALLEST list in a sheet (the station strip is a scroll view before the trip's
list — five tests swiped it and found nothing); `setSwitch` nudges a switch into view with slow drags (`nudgeIntoView`:
with the row the cabin switch needed scrolling, the swipes flung it past and a tap opened the loop strip); and Weigh by
itself only with `-dayWeighItself` (six tests ticked everything — then by Tick everything, which 0.79 takes off the trip
screen — and found the sheet over their next step). The two tests that pack everything do it by the headings' own ticks
(`tickEveryHeading`), not by Tick everything.

### Traps met building it

- **A sheet's content closure read a separate `@State` stale.** The trip set "opened by itself" and the sheet's item in
  one go, yet the sheet was built with the old `false` — so it never marked Weigh offered and opened it again. The flag
  now travels IN the item (`TripScreen.DayOpen`).
- **A strip of chips is a scroll view too** — see the harness changes above; the README's "row of pills" trap again.

### 0.81 — Packing Stations: his decisions of 14 Oct 2026

> His decisions on 0.79's Packing day, from his screenshots of a Mac trip (14 Oct 2026), numbered as he gave them
> (he gave no 6). Built on branch `work/stations081`, written from the code. The model:
> `Core/Sources/PackingLibrary/PackingStations.swift` (and `PackingDay.swift`, `Weighing.swift`, `Countdown.swift`,
> `TripAgain.swift`, `Sharing.swift`); the screens: `App/Sources/Screens/PackingStations.swift` (and `PackingDay.swift`,
> `TripScreen.swift`, `TakeABreak.swift`, `TripChecks.swift`, `Buttons.swift`). Where this section and the ones above
> differ, this one is the newer.

**1. The name: "Packing Stations".** Everywhere he reads it: the trip row's title (`day-title`, label "Packing
Stations"), the sheet's heading (`day-heading`), How it works' part (its title `guide-day-title` and its words —
spec 06 §7), Words (term "Packing Stations", its meaning ending "(Packing day until 0.81.)" — spec 06 §10), a bag's
page ("In Packing Stations, Tags asks you to check it is in the bag." — spec 05), the flights block ("Each checked bag's
tag number goes in at Packing Stations, under Tags." — part 18 B). Unchanged: every id (`day-…`, `guide-day-…`,
`guide-packingday`), the launch flags (`-uiTestingPackingDay`, `-packingDayAlmost`), the code's names (`PackingDay`,
`PackingDaySheet`, `PackingDayRow`, `PackingDayGuideCard`), the keys (`day…`), and What's new of 0.79 — history, as it
was released.

**2. Slimmer chips — the six station chips only.** The capsule is **22 pt** tall on the iPhone and **18** on the Mac
(`StationChip.height`; until 0.81 `Metrics.chip`, 28 / 22); the mark (15 / 13) and the words (Footnote semibold) keep
their size, so the drawn marks stand out. Above and below the capsule, **2 pt** on the iPhone and **1** on the Mac
still take the tap (`StationChip.reach`; the button's content shape is the rectangle), so each chip — and the row — is
26 / 20 tall. The "done and highlighted" white ring now sits 2 inside the edge (2.5 before). The row's title ("Packing
Stations" and the day's mark) is as tall as a chip with its reach. The loop strip's step pills and every other pill in
the app are unchanged; in the sheet the chips wrap as before, at the new height.

**3. Tags — Remind me, and a happier look.** Each bag is a card of its own (`TagsBagCard`, container `day-tag-<n>`):
- **The card** (padding 12, 4 more on the left; corner 12): on the card colour with a soft green edge down its left
  side — the trip's green at 45 %, 5 pt wide, following the corners (`mask`); a hairline round it. **Done** — every tick
  the bag asks for on (`PackingDay.tagsDone`: its name tag, and its AirTag when it has one) — the whole card turns a
  light green (the green at 12 % by day, 20 % at night), the edge full green, the hairline the green at 65 %.
- **Its head**: the bag's drawing (20 pt,
  the Pack step's readable green) — a backpack for a name holding "pack", "rucksack" or "ryggsäck", the soft holdall
  for "duffel", "holdall", "weekend", "sports bag" or "gym bag", else the suitcase (the template icons' own,
  `StationDrawings.bag`; hidden from VoiceOver) — the name (Subheadline semibold ink, up to two lines; a text with the
  header trait, id `day-tag-<n>-bag`, value "done" / "open"), and, when done, a drawn ✓ and "done" (Footnote semibold
  green; the word a text of its own, `day-tag-<n>-done`) at the right.
- **The ticks** keep their ids, words and values (`day-tag-<n>-name` "Name tag", `day-tag-<n>-air` "AirTag in it",
  value "on" / "off", selected when on, `Metrics.line` tall + 3 above and below). Instead of the bare tick circle each
  wears its drawing in a round badge (`DrawnTick`, 26 pt on the iPhone, 20 on the Mac): the luggage tag on its string,
  and the AirTag — the Tags station mark's two halves, each taken out and centred on the 24 grid
  (`StationDrawings.nameTag`, `.airTag`), stroke 2. Off: the drawing in the readable green on the green at 8 %, a ring
  of the green at 55 %. On: the drawing white on the green, and a drawn ✓ in green at the row's right.
- Then, as before: on a plane trip a checked bag's **Bag-tag no.** (0.80, part 18 B — `day-tag-<n>-number`), and the
  bag's **Has an AirTag** switch (`day-tag-<n>-has`, now hugging its words at the card's left).
- **Remind me** — at the right of Has an AirTag's line, while the bag is NOT done (a bag whose ticks are all on has
  nothing to remember): a drawn bell and "Remind me" (Footnote semibold, readable green, `Metrics.compact` tall), id
  `day-tag-<n>-remind`. It opens, under the line, the To do composer (below) prefilled with what is not ticked yet
  (`PackingDay.reminder(for:)`): "Name tag for <bag>", "AirTag for <bag>", both missing "Name tag and AirTag for
  <bag>" — everything ticked (never shown then) "Name tag for <bag>"; its lead "A To do on this trip — it shows in
  Before you go:". Added: the composer closes and the card says, in green with a drawn ✓, "Added to To do: "<words>"
  — see Before you go." (`day-tag-<n>-remind-said`) until the sheet closes or Remind me opens again.

**4. Ready — Add a reminder.** At the foot of Ready, after I leave at: "+ Add a reminder" (`StationAddLabel`: a drawn
plus and the words, Subheadline semibold readable green, the green at 10 % in a 1.2-pt green capsule,
`Metrics.compact` tall; id `day-ready-remind`). It opens the To do composer empty — lead "Anything last-minute — a To
do on this trip, in Before you go:", placeholder "e.g. Buy euros". Added: "Added to To do: "Buy euros" — see Before you
go." (`day-ready-remind-said`), and the button is back. Switching station closes an open composer (and Add a bag).

**The To do composer** (`TripTodoComposer`, ids from its prefix — `<id>-text`, `<id>-add`, `<id>-cancel`,
`<id>-needs`): the lead (Footnote muted), then one line — the field (Body, `Metrics.tap` tall, `Theme.bg` in a hairline,
corner 8; focused on opening, Return adds), **Add** (`FieldButtonLabel`, always full colour) and **Cancel** (Subheadline
semibold muted). Add with nothing written: "Write what to remember." under it (red, `NeedsLine`, gone as soon as
anything is typed); with the name of a To do of the trip not yet done: "That is on this trip's To do already."
(`Library.tripTodoProblem`: blank / alreadyThere, by `normName`, among the trip's reminder lines not ticked and not set
aside — a ticked one may be written again).

**A To do written on the trip — the rules** (`Library.addTripTodo(tripId:name:today:)`):
1. It is the web app's own reminder line on the trip: `itemType` "reminder", `custom` true (no template behind it —
   a rebuild keeps it, as "Add a thing to this trip" does), not ticked, in no bag (`container` ""), kind "Reminders",
   its name trimmed, appended last — and marked **written on the trip**: the line's extra key `tripTodo` = true
   (`TRIP_TODO_KEY`; never written false). So the trip's list shows it as any reminder ("To do" in the bag's place,
   under "To do" sorted by Into, under "Added on the trip" sorted by Template).
2. **Due at once.** `dueReminders` (part 12) lists, after the reminders due by their steps, every To do written on the
   trip not yet ticked nor set aside — whatever its When and whatever the trip's dates (an undated trip too), in the
   order written. So it is in **Before you go**'s To do straight away (spec 03), where, instead of a step, the line
   under its name says **"Added on the trip"**; a tick there ticks the line. Home's countdown names it as due too.
3. **Its When** (`todoWhen`) only sorts it on the list: of the steps before leaving (lead days 0 or more), the latest
   one already due by the trip's dates — what is being done now (the 13th, for a trip on the 20th: "≥1 week ahead";
   the day before: "Day before"; on the day: the first of the day's steps, the Morning list) — else, with none due
   yet or no dates, the earliest step of all (Preparations); no step before leaving at all: a new thing's step.
4. **It counts** on the list as every reminder does (spec 03 "Counting": "All packed" waits for reminders): the trip's
   count grows by one, Pack's chip and Ready say so ("6 of 8 packed"), and Pack and Ready are not green until it is
   ticked. Weigh opening by itself stays once per trip.
5. **Not carried as due at once.** A shared trip carries the line as a plain reminder (`justTheList` removes
   `tripTodo` — "at once" was his packing); Start a new trip from this one copies the line (what the line IS comes
   along) without the mark, so on the new trip it is due by its When like any reminder. Synced and backed up with its
   line.

**5. The trip header's colours** (variant A, his pick): the three buttons on the trip's name line — only these.
**Review** (outlined, as before) in the Templates / Refine violet: ring and 10 % fill `#7c5cd6`, its words `#6548c0` by
day and `#a58ce6` at night (the violet itself is 3.9 : 1 on its fill by day — too faint for words). **Take a break**
(the count line's capsule — "Take a break", "Back at 18:00", "Back tomorrow 18:00"; outlined as before, its cup mark
and words in the words colour) in a warm **coffee amber**: ring and fill `#a8651a` by day, `#e0a458` at night; words
`#8a5215` by day, `#e0a458` at night. **Done** stays filled in the trip's green with white words. All in the model as
`TripHeaderTone` (`.review`, `.takeABreak`, `.done`: `ring`, `words`, `filled`) — the app makes each pair a light/dark
colour (`ringColour`, `wordsColour`); `HeaderButtonStyle` takes a `words` colour for an outlined button since 0.81.
Contrast (WCAG, words on the button's own 10 % fill, on the page and on a card): Review 5.3–6.1 : 1, Take a break
5.2–7.3 : 1; Done's white on green 3.4 : 1 (bold, unchanged). Until 0.81 Review and Take a break were the trip's
green, their words 2.8 : 1 on their fill by day. The Take a break sheet itself stays green.

**7. Bags out — "+ Add a bag".** At the foot of Bags out, after "All bags are out.": "+ Add a bag" (`StationAddLabel`,
id `day-addbag`) — also under the no-bags words when the trip has no bag at all (`day-nobags`), so a trip can be given
its first bag here. It opens **the panel** (`AddBagPanel`, container `day-addbag-panel`; padding 12, the card colour, a
1.2-pt green ring at 70 %, corner 12): "Add a bag to this trip" (Subheadline semibold, a heading); then, when he has
any, "One of your bags" (Footnote semibold muted) and his bags NOT on this trip yet, in Care → Bags' order
(`Library.bagsToAdd`) — one row button each, `day-addbag-pick-<k>`, label "Add <bag>" (its drawing, its name in Body,
a drawn plus at the right, `Metrics.row` tall, a hairline under it); a tap puts it on the trip and closes the panel.
Then "Or a new one" ("A new bag" when there is no bag to pick): the name field (`day-addbag-name`, "Its name — e.g.
Duffel"), **Goes in the cabin** (`day-addbag-cabin`; it shows what the name says — "Cabin bag", "Carry-on" — until he
switches it), **Max weight** (`day-addbag-max`, "optional", decimal pad, 90 wide) "kg", and **Add the bag**
(`FieldButtonLabel`, `day-addbag-add`) and **Cancel** (`day-addbag-cancel`). What Add the bag says when it cannot
(`day-addbag-needs`, red): blank — "Type the bag's name."; "Other" — ""Other" means things in no bag — give it another
name."; a bag the trip already packs into — "<bag> is on this trip already."; one of his bags — "You have a bag called
<bag> — pick it above."; a max that is not a number above 0 — "Type the max in kg — or leave it empty." A new bag
(`Library.addNewBagToTrip`) becomes one of his bags (Care → Bags, as one made there), with "Goes in the cabin" written
only when he switched it (`cabin` nil = by its name, the airport checks' own rule) and its max when given, and is put
on the trip. **Since 0.83 the same "+ Add a bag" is at the foot of the trip's Bags card** (spec 03), opened, while the
trip is not reviewed — his report of 14 Oct 2026: he looked for it there. The same panel (`AddBagPanel`, given the id
prefix `bags-addbag`: `bags-addbag`, `bags-addbag-panel`, `bags-addbag-pick-<k>`, `bags-addbag-name`, …), the same
model calls and words; the card shows an empty bag added as "nothing in it yet" with its ✕ (`bag-<n>-remove`) and Bags
out's hint (`bags-addbag-hint`), as Bags out does.

**How a bag is on the trip without lines** (decided by the build): the trip keeps the bags added this way in its
extra key `dayAddedBags` (`DAY_ADDED_BAGS_KEY`, `[bag name]`, removed when empty — `Library.addBagToTrip`,
`removeAddedBag`, `addedBags`, `isAddedBag`). The trip's bags (`weighedBags`, so the Bags card, Weigh, the Obsidian
page; and `dayBags`, so Bags out, Tags, Photos, Ready) are the bags its lines pack into, in the card's order, THEN each
added bag nothing on the list is packed in yet — last, in the order added, empty (0 things, 0 g), with its limit
(`bagLimits`); an added bag the list does pack into is simply the list's row (marked `added`). So: never twice; not
"Other"; not a bag the lines already pack into (refused). It is a bag like any other from then on — weighed, tagged,
photographed by its name; the Bags card lists it ("Tap to weigh"), and its card filter no longer drops a bag with
nothing in it. In Bags out an added bag with nothing in it says "nothing in it yet" instead of "N things", has a **✕**
beside its row (not in it: a button inside a button never reaches the tree) — `day-bag-<n>-remove`, label "Take <bag>
off this trip" — which takes it off the trip again (what the day kept for it stays stored, ignored), and under the list
one line (Footnote muted, `day-addbag-hint`): "To fill <bag>, pick it as Usually packed in on its things' pages —
sorted by Into, the list shows what is in each bag." (The trip has no "move this line to another bag" of its own: a
thing's bag is its Usually packed in, which reaches the trips still ahead — spec 03, "A change to a thing reaches the
trips still ahead".) The key is one of the day's bag-name lists (`DAY_BAG_KEYS`): it follows a bag's rename, and is
dropped where two bags become one or the bag is deleted to "No bag" (`moveBagNotes`); a shared trip and Start a new
trip from this one carry none of it (`DAY_TRIP_KEYS`).

#### Where it is kept (0.81)

| Holder | Key | Value | Meaning |
|---|---|---|---|
| trip | `dayAddedBags` (`DAY_ADDED_BAGS_KEY`) | `[bag name]` / absent | the bags "+ Add a bag" put on the trip; follows a rename; not shared, not copied |
| trip line | `tripTodo` (`TRIP_TODO_KEY`) | true / absent | a To do written on the trip (Remind me, Add a reminder): due at once; dropped in a shared trip and by Start again |

Parity: 211/211 (only `extra` keys, and a reminder line the web app knows).

#### Tests (0.81)

Model `PackingStationsTests` (8, `Core/Tests/PackingLibraryTests/PackingStationsTests.swift`, the same invented library
as `PackingDayTests`): `testRemindMeOffersWhatIsNotTickedYet`, `testAToDoWrittenOnTheTripIsDueAtOnceAndShowsInBeforeYouGo`
(a reminder line, custom, no bag, "week" on the 13th for the 20th; due; Before you go 1 left; the count and Pack +1;
no bag; one open To do per name; ticked, it may be written again), `testAToDoIsDueWhateverTheTripsDatesAndSortsUnderASensibleStep`
(tomorrow "daybefore", today "morning", far ahead and undated "prep"; undated and still due),
`testAToDoIsSyncedAndBackedUpButNeitherSharedNorCopiedAsDueAtOnce`, `testAddABagPutsOneOfHisBagsOnTheTripAndEveryStationAsksAboutIt`
(offered, added last and empty, "0 of 3 out" … "0 of 4 photos", weighed, refused twice / Other / blank / a bag of the
lines / no trip; a line moved in — still one bag; ✕), `testANewBagIsMadeHisAndPutOnTheTrip` (the four problems; a
cabin bag by its name with 8 kg; said not to go in the cabin; a max of 0 is none), `testAnAddedBagFollowsARenameAndIsNeitherSharedNorCopied`,
`testTheHeaderButtonsWearTheirOwnColoursAndReadDayAndNight` (Review the Templates violet, Done green and filled, three
different rings, the amber warm, every outlined button's words ≥ 4.5 : 1 on its own 10 % fill on the page and a card,
day and night; Done's white ≥ 3 : 1). Each seen RED with a planted fault: the To dos left out of `dueReminders` —
"("[]") is not equal to ("["Name tag for Day pack"]")"; `todoWhen` taking the earliest step — "("prep") is not equal
to ("daybefore")"; `weighedBags` without the added bags — "("["Carry-on / hand luggage", "Day pack"]") is not equal to
("[…, "Duffel"]")"; `DAY_BAG_KEYS` without the added bags — "("["Duffel"]") is not equal to ("["Holdall"]")";
`justTheList` keeping the mark — "a shared trip carries his To do as due at once"; Review's words the violet itself —
"("3.938590468282447") is less than ("4.5") - review on the day page"; Remind me ignoring the AirTag — "("Name tag for
Day pack") is not equal to ("Name tag and AirTag for Day pack")"; a new bag written "not in the cabin" when nothing was
said — "no word given: the name decides". All model tests 587 + 451 green; parity 211/211.

UI (`-uiTestingPackingDay`): `testPackingStationsIsNamedSoWithSlimChips` (the row's title "Packing Stations"; every
chip lower than a pill — under 28 on the iPhone, 22 on the Mac — and not squashed; Review, a break for tomorrow — "Back
tomorrow 18:00" — and Done in the header; the sheet's heading), `testTagsRemindMeWritesAToDoThatShowsInBeforeYouGo`
(no Before you go at first; the Day pack without "done" and with Remind me, both ticks → `day-tag-1-done` and no Remind me; the carry-on's Remind me offers
"Name tag for Carry-on / hand luggage", changed to "Buy a name tag for the carry-on", added and said; again → "That is
on this trip's To do already."; Before you go's To do has it, the count "0/8"; ticked there "1/8"),
`testReadyAddsALastMinuteReminder` (`-packingDayAlmost`: Add with nothing → "Write what to remember."; "Buy euros" added,
Pack "6 of 8 packed", in Before you go), `testBagsOutAddsANewBagAndOneOfHis` (no bag to pick; "Day pack is on this trip
already."; Duffel, 23 kg → the third bag, "nothing in it yet", "0 of 3 out", a ✕ for it and none for the Day pack;
Weigh, Tags and Photos ask about it; ✕ → gone; offered as "Add Duffel" and put back), and the How it works test
(spec 06 §7) now also asks for "Packing Stations", "Add a bag", "Remind me" and "Add a reminder"; the Bags out test ends
on the trip's Bags card, which lists the Duffel (`bag-2`). Each seen RED on the iPhone simulator with its own planted
fault: the chips back at `Metrics.chip` — "("32.0") is not less than ("28.0") - the bags chip is as tall as a pill";
Remind me with nothing prefilled — "Remind me offers 'What to remember'"; the composer writing nothing — "Pack does not
wait for the To do: '6 of 7 packed'"; the Bags card dropping a bag with nothing in it — "the Bags card does not list
the bag added: ''"; How it works' title left "Packing day" — "How it works still says 'Packing day'"; the "done" left
off a card whose ticks are all on — "every tick on, the Day pack does not say done". Green again
without them, day and night. Around them on the iPhone simulator, 23 neighbouring tests (the six Packing day tests and
the bag-tag one, Take a break ×3, Before you go and the reminders due, the trip's pen and header, the Bags card, the
luggage scale, bag photos and cabin, Start a new trip, the review, the door check, every tab's header): all green.
On GitHub's Mac (a probe branch, deleted after): the four new tests, the How it works test and five neighbours (Bags
out to the list, Ready, Tags' AirTag, Take a break, the reminders due) green by day, the four new ones again with the
system set to dark, and the pill height planted back red — "("24.0") is not less than ("22.0") - the bags chip is as
tall as a pill: 24.0". The first probe found the Mac trap below (the Tags test red, "the Day pack is ''"); the second,
after the fix, was green. (The runner's "dark" pictures came out light — the system switch did not reach the app; the
Mac's night look was not seen there.)
Pictures, iPhone day and night and the Mac: `stations-row` (the slim row, the header's violet Review, amber "Back
tomorrow 18:00" and green Done), `stations-tags`, `stations-tags-beforego`, `stations-ready`, `stations-bagsout`,
`stations-addbag`.

#### Traps met building it (0.81)

- **A combined element's value did not reach the Mac's tree.** The Tags card's head was first ONE element (children
  ignored) carrying the value "done" / "open": the iPhone read it, GitHub's Mac read '' (the first Mac probe, "the Day
  pack is ''"). The name is now a plain text with the header trait, and "done" a text of its own that the tests look
  for — a plain text is a text on both.

### 0.84 — shorter chips, "Stations", and Review once the trip has started: his asks of 15 Oct 2026

> From the same screenshots of a Mac trip at Pack (15 Oct 2026; his 2–4 are part 16 "0.84"). Built on branch
> `work/trims084`, written from the code: the chip words `Core/Sources/PackingLibrary/PackingDay.swift`
> (`PackingDayStation.chip`); the row and the sheet `App/Sources/Screens/PackingDay.swift`; the header's Review
> `Core/Sources/PackingLibrary/Loop.swift` (`Library.offersReview`) and `App/Sources/Screens/TripScreen.swift`.

**5. Shorter station chips.** Each chip — on the trip's row and at the top of the sheet — says its **chip word**
(`PackingDayStation.chip`): **Bags · Pack · Weigh · Tag · Photo · Ready** (Bags out, Tags and Photos until 0.84); the
chip's accessibility label is the same word (what is seen is what Voice Control hears). **Pack carries no count**
("13/289" until 0.84 — the header's count under the trip's name says it; `StationChip` has no `count` any more). The
row's title says **"Stations"** (`day-title`, label "Stations"; "Packing Stations" until 0.84), with the day's mark as
before. Unchanged: every id, the chips' look and height (0.81), the values ("done", "no bags yet", the station's words).

**Where the long names stay** (decided by the build, calmly): where there is room to read them and they name the
thing rather than label a chip — the sheet's heading **"Packing Stations"** (`day-heading`), its foot button "Next:
Bags out" / "Next: Tags" / "Next: Photos" (`PackingDayStation.name`), Ready's list of the stations ("Bags out",
"Tags", "Photos" with their state), How it works' part — its title "Packing Stations" and the numbered stations "1 ·
Bags out" … "5 · Photos", its opening words now "a row sits right under the loop: Stations, then six stations in the
order you go through them, each with a short word on its chip — Bags, Pack, Weigh, Tag, Photo, Ready." and Pack's
words "The trip's own list — how far you are is the count under the trip's name — and a tap takes you straight to
the list." (spec 06 §7) — and Words: the term stays "Packing Stations", its meaning gains "The row itself says
Stations, its chips the short words: Bags, Pack, Weigh, Tag, Photo, Ready." (spec 06 §10). 0.81's What's new, the
code's names and the keys are unchanged.

**The header's Review — only once the trip has started** (his yes, the same day: on a Review button beside Done at
Pack he asked "is that really necessary?", and said yes to "only once the trip has started"). `Library.offersReview`
(model, `Loop.swift`): not reviewed, with lines, and the trip's `loopStep` **On site or later** — so on the first day
from the time he leaves (0.75), or once something was bought on site, and every day after; never at Plan or Pack. A
trip with **no start date** never starts by the clock, so it keeps Review at any time (otherwise it could never be
reviewed) — decided by the build. The loop strip's Review step (`trip-loop`) is unchanged, and a tapped "Welcome home
— review …" still opens the review (it comes the day after the last day, when the trip is at Review anyway). Under
the UI tests `-reviewAtPack` shows it at Pack too, for the tests about the review itself on the sample trip a month
ahead (`TripScreen.reviewAtPack`; spec 03).

#### Tests (0.84)

- Model: `PackingDayTests.testEachStationWearsHisPick` (the chip words; the names unchanged);
  `LoopTests.testTheHeaderOffersReviewOnlyOnceTheTripHasStarted` (a trip ahead no, under way and over yes, reviewed or
  without lines no, undated yes, the first day before / from 08:00 when he leaves at 08:00, a trip ahead with
  something bought on site yes).
- UI: `testTheBreakIsACupAndTheStationChipsAreShort` (new) — `day-title` "Stations", each chip's label its word, Pack
  no wider than Weigh (no count), no `trip-review` on the trip at Pack, then the break (part 16 "0.84");
  `testPackingStationsIsNamedSoWithSlimChips` now expects "Stations" on the row (the sheet still "Packing Stations")
  and NO Review at Pack (it expected one); `testATripUnderWayStandsAtOnSite` now expects `trip-review` on the trip
  under way. The tests that open the review on the `-uiTesting` sample (a month ahead) or `-uiTestingKits` launch with
  `-reviewAtPack`: `testTheLoopShowsWhereATripStands`, `testEscapeClosesTheTripsWindows` (Mac),
  `testSetPlaceAndTheReviewSayWhatIsMissingAndNoTemplateIsChosen`, `testASwipeDownKeepsWhatIsNotSavedYet`,
  `testATripReviewIsSavedAndTheMissedThingIsFiled`, `testTheReviewSaysWhereAThingWentAndLetsHimFixIt`,
  `testTheEditorsLeadWithTheirHeadings`, `testAReviewedTripShowsWhatWasInsideItsKitThen`,
  `testASavedReviewAsksForTheTripsPage`; `-uiTestingHealth`'s trip is over already.
- **Seen red first** with planted faults: the model — `offersReview` always true ("Review on a trip still being
  packed", "Review before he leaves on the first day"), Tag as "Tags" (`["Bags", "Pack", "Weigh", "Tags", "Photo",
  "Ready"]` is not equal to `[… "Tag" …]`); the iPhone — the old title ("Packing Stations" is not equal to
  "Stations"), the full names as labels ("the bags chip says 'Bags out'", "… 'Tags'", "… 'Photos'"), Pack's count back
  ("Pack still carries its count: 93.3 against Weigh's 77.3"), the Review rule inverted ("Review on a trip still being
  packed" — in the new test and in `testPackingStationsIsNamedSoWithSlimChips`; "no Review on a trip under way").
  Green results: part 16 "0.84".

### 0.86 — no tags inside another bag: his yes of 15 Oct 2026

> The idea as put to him: Tags asks for a name tag and an AirTag on every bag that is out; a bag packed INSIDE another
> bag (a toiletry bag or a packing cube inside the suitcase) never goes through the airport on its own, so it needs no
> name tag — leave those out of Tags, so the list holds only the bags that travel by themselves. His answer: **"Yes -
> no tags inside another bag"**. Built on branch `work/tags086`, written from the code. The model:
> `Core/Sources/PackingLibrary/TagsInside.swift` (`Library.bagsInside`, `bagInside`; `PackingDay.tagged`,
> `insideAnother`, `tagsInsideWords`) and `PackingDay.swift` (`PackingDay.Bag.inside`, `counts(.tags)`,
> `packingDay`); the station `App/Sources/Screens/PackingDay.swift` (`tags`, `PackingDayGuideCard.says(.tags)`).

**How the app knows that a bag is inside another on THIS trip** (decided by the build) — `Library.bagsInside(trip,
bags:)`, over the trip's bags as its Bags card names them (`dayBags`):

1. **The trip's own line, and only it.** A bag is inside another when its OWN line on the trip — the line of its thing:
   by the thing's id (`sourceItemId`) when the bag is one of his bags (Care → Bags), else by its name (`normName`) —
   **not set aside and not a reminder**, is packed in ANOTHER of the trip's bags (a real bag: not empty, not "Other",
   not itself). The first such line decides. That line's bag is what he sees on the trip's list (the line stands under
   that bag's heading, sorted by Into); it comes from the thing's Usually packed in through the template's row (a bag
   chosen for that one template wins), and follows a change to it while the line is open (not ticked, not added or
   changed on the trip — `followThing`, spec 03 "A change to a thing reaches the trips still ahead").
2. **The thing's Usually packed in alone is NOT read.** A bag with no line of its own on the trip (only a bag its
   things go in, or one put on by "+ Add a bag") travels by itself. Why: every thing the app makes — a new bag
   included (`addBag` → `addThing` → `newItem`) — and every thing from the web app starts "Usually packed in: Carry-on /
   hand luggage" (the built-in default), so the app cannot tell his choice from the default. Trusting it would drop
   the sample's Day pack, a new Duffel — and his suitcase — from Tags on any trip with a carry-on: planted, exactly
   that happened (below).
3. **A line set aside says nothing** (the bag is "not this time", yet things are packed in it): the bag is asked about.
   A reminder of the bag's name is no line of the bag.
4. **Nested**: a pill pouch in the toiletry bag in the suitcase — the pouch is inside the toiletry bag, the toiletry
   bag inside the suitcase; both left out, each named with the bag it is directly in.
5. **A ring** (A's line in B and B's line in A — nothing outside them): a bag whose chain leads back to itself
   travels by itself, so both are asked about; a bag inside one of them is still inside it.
6. **Taken out again** — its Usually packed in set to No bag (or the bag it really travels as), which reaches its open
   line on a trip still ahead; or its line set aside — it travels by itself and Tags asks about it at once. A line
   already ticked keeps its bag (as every ticked line does).

**What Tags does with it:**
- `PackingDay.Bag.inside` = the bag it is in ("" = travels by itself); `PackingDay.tagged` = the bags with none, in the
  trip's order; `insideAnother` = the others. **`counts(.tags)` counts only `tagged`**: a name tag per such bag, an
  AirTag per such bag that has one. So Tags' chip, its words ("0 of 3 ticked"), its green, Ready's list and Ready
  itself, and the next station offered go by the bags that travel alone.
- **The AirTag follows the same rule** (decided by the build): an inner bag's AirTag is not asked for either, even
  when the bag has one. An AirTag is for finding a bag lost on its own; an inner bag goes where the bag it is in goes,
  and is found with it. Its **Has an AirTag** stays the bag's own (its page in Care → Bags unchanged); taken out, the
  bag's AirTag is asked for again.
- **The station** (`day-view-tags`): a card (`TagsBagCard`) only for each bag that travels by itself. Its ids keep the
  bag's place among the trip's bags (`day-tag-<n>-…`, the same `n` as `day-bag-<n>`, `day-weigh-<n>`,
  `day-photo-<n>`), so with a Toiletry bag first and inside the carry-on the cards are `day-tag-1` and `day-tag-2`.
  Under the cards (after "Every tag is on." when all are on) **one quiet line**, Footnote muted — the station's lead
  style — id `day-tags-inside`, in his own words: **"No tags inside another bag: Toiletry bag (in the Carry-on / hand
  luggage)."**; several: "No tags inside another bag: Toiletry bag (in the Suitcase), Pill pouch (in the Toiletry
  bag)." — in the trip's order; none: no line. It names what was left out and why, so a bag dropped by a wrong line is
  seen (the line's bag is then fixed on the thing's page).
- **What a tick kept for an inner bag does**: nothing while it is inside — kept, ignored, counted again once it is
  taken out (as for a bag no longer on the trip, rule 11).
- **Unchanged** (his ask was Tags only): Bags out, Weigh and Photos still ask about every bag, an inner one too (lay
  it out, weigh it, photograph it packed); the Bags card, the Lost bag pages and the trip's Obsidian page are as
  before. **Nothing new is stored**: the rule reads the trip's lines each time — synced, backed up and shared as
  before; parity 211/211.
- **How it works** (spec 06 §7): Tags' words gain "A bag packed inside another bag on this trip — a toiletry bag in the
  suitcase — never goes through the airport on its own, so it has no card here, nor an AirTag tick: one quiet line
  under the cards names it ("No tags inside another bag: …"). Which bag it is in is what the trip's list says (sorted
  by Into); take it out — its Usually packed in set to No bag — and its card is back."

#### Tests (0.86)

- Model `TagsInsideTests` (4, `Core/Tests/PackingLibraryTests/TagsInsideTests.swift`; PackingDayTests' invented
  library plus a Toiletry bag — one of his bags — on the base template, packed in the carry-on, the Toothbrush in it):
  `testTagsLeaveOutABagPackedInsideAnotherAndAskAgainOnceItTravelsAlone` (three bags, the Toiletry bag first; Bags out
  "0 of 3 out", Weigh "0 of 3", Photos "0 of 4" unchanged; Tags the carry-on and the Day pack, "0 of 2 ticked", the
  line's words; its AirTag not asked; its kept name tag not counted; done with the two; Ready counts Tags; its Usually
  packed in No bag reaches the trip → three cards, "3 of 4 ticked", no line),
  `testOnlyTheBagsOwnLineOnTheTripSaysItIsInside` (the Day pack's own default "Carry-on / hand luggage" and no line →
  travels by itself; set aside → asked; a reminder of its name → no line; found by its thing under another name;
  packed in itself, in no bag, in "Other" → travels by itself; no trip → ""),
  `testABagInsideABagInsideABagAndARingWithNothingOutsideIt`, `testABagAddedToTheTripWithNoLineOfItsOwnIsAskedAbout`.
  Each seen RED with a planted fault: Tags counting every bag again — "("0 of 3 ticked") is not equal to ("0 of 2
  ticked")", "("4") is not equal to ("2") - an AirTag inside an inner bag was asked for", "("1 of 4 ticked") is not
  equal to ("0 of 2 ticked") - the inner bag's tick counted"; the thing's Usually packed in trusted when the bag has no
  line — "("["Carry-on / hand luggage"]") is not equal to ("["Carry-on / hand luggage", "Day pack", "Duffel"]")", and
  in PackingDayTests "("0 of 1 ticked") is not equal to ("0 of 2 ticked")" (the Day pack gone); a set-aside line still
  read — "("["Carry-on / hand luggage", "Day pack"]") is not equal to ("["Toiletry bag", "Carry-on / hand luggage",
  "Day pack"]")"; a reminder read as the bag's line — "("Carry-on / hand luggage") is not equal to ("")"; no ring rule
  — "("["Carry-on / hand luggage"]") is not equal to ("["Blue pouch", "Red pouch", "Carry-on / hand luggage"]")";
  found by name only — "("") is not equal to ("Day pack") - found by name only, not by its thing". All model tests
  634 + 451 green; parity 211/211.
- UI `testTagsLeaveOutABagPackedInsideAnother` (`-uiTestingPackingDay -packingDayInner` — `SampleLibrary.packingDay(inner:)`:
  a Toiletry bag with an AirTag, the Toothbrush in it, itself on Common base packed in the carry-on): Tags has
  `day-tag-1-bag` and `day-tag-2-bag` and no `day-tag-0-…`, its chip "0 of 3 ticked", `day-tags-inside` says the
  line; Bags out "0 of 3 out", `day-bag-0` the Toiletry bag; then the Toiletry bag's page (Care → Your things, search),
  Usually packed in → No bag, Save; back on the trip, Tags has all three cards, `day-tag-0-air`, "0 of 5 ticked" and
  no line. And `testHowItWorksExplainsThePackingDayStations` asks Tags' words for "inside another bag". Each seen RED
  on the iPhone simulator with its own planted fault: every bag's card shown — "Tags asks about a bag packed inside
  another: cards [0, 1, 2]"; the quiet line left out — "no line says which bag was left out, and why"; the thing's
  Usually packed in trusted — "Tags asks about a bag packed inside another: cards [1]" (the Day pack gone too); the
  count of every bag — "the inner bag counts for Tags: '0 of 5 ticked'"; How it works without the words — "Tags does
  not explain that a bag inside another has no card". Green again without them, day and night, with the seven
  neighbours on the iPhone simulator (Tags' AirTag, the bag-tag number, Remind me, Ready's reminder, Add a bag, Bags
  out to the list, Ready and the door check). On GitHub's Mac (a probe branch, deleted after): the new test, How it
  works, Tags' AirTag and Remind me — all four green, light. Pictures `tags-inside`, `tags-inside-out`, iPhone day and
  night and the Mac.

### Open questions

- Two devices with the trip open when it turns all packed may each open Weigh once (the "offered" mark is the trip's
  record, the ticks are the lines' — which arrives first is iCloud's choice). Harmless; his word welcome.
- The photo of all the bags is not on the trip's Obsidian page (part 8) nor at the top of the way home (spec 03 "Pack
  to go home"), where each bag's photos are. Worth adding if he wants it there.
- SETTLED in 0.86 (his yes, "no tags inside another bag"): ~~Tags are asked for EVERY bag, a toiletry bag inside the
  case included~~ — a bag whose own line on the trip is packed in another bag is left out of Tags (see "0.86").
- Bags out, Weigh and Photos still ask about a bag inside another (0.86 changed Tags only, as asked). Weighing the
  toiletry bag on its own is mostly noise once the suitcase is weighed with it inside; his word welcome.
- A bag put on a template as a thing keeps the built-in "Usually packed in: Carry-on / hand luggage" unless he changed
  it — a suitcase on a template that way would be "inside the carry-on" and left out of Tags. The quiet line shows it
  ("No tags inside another bag: Suitcase (in the Carry-on / hand luggage)."), and its Usually packed in → No bag fixes
  it; not seen in the invented data, worth a look on his first real trip.

---

## 18. Lost luggage

> His yes (13 Oct 2026), 0.80: when a bag goes missing, the airline's baggage desk asks what it looks like — and on the
> spot, tired, nobody remembers the brand or how big it is. **Part A** (this section, branch `work/baginfo080`): the
> details are entered ONCE, on each bag's own page, and reused by every trip. **Part C** (branch `work/lostbag080`):
> a trip's Lost bag page and its PDF, which read them. Written BEFORE part A was built, then brought in line with the
> code (the code wins where they differ). The model: `Core/Sources/PackingLibrary/BagDetails.swift`; the block:
> `App/Sources/Screens/BagDetail.swift` (`lostDesk(_:)`). Per screen: spec 05 (a bag's page, item 3c), spec 01 §1.12
> (the keys).

### A. A bag's details for the desk

#### What he gets

- On a bag's page (Care → Bags → a bag), under "Has an AirTag", a block headed **For the lost-luggage desk**: what an
  airline's desk asks about a missing bag — **Brand**, **Colour** (typed, or one tap on a pill: Black, Grey, Blue,
  Red, Green, Beige, Multi), **Type** (one of: Hard case, Soft case, Duffel, Backpack, Holdall / weekend bag, Garment
  bag, Other — the desk's own categories in plain words), **Size** (Cabin, Medium or Large, and a note for the exact
  measure — "55 × 40 × 20 cm") and **Distinctive marks** (free text — "red strap, sticker on the side"); and
  **Photos of the bag** — how it looks, taken empty or any time, two at most (his ask of 14 Oct 2026, the same day:
  the bag's own page had no photo; a bag's photos were only the trip's photos of it PACKED).
- The bag's own photo also shows, small, beside the bag on a trip — in the Bags card and in the Packing day's Photos
  station — until that trip has a photo of it packed.
- Said once, on the bag; every trip the bag goes on uses the same answers (part C shows them on the trip's Lost bag
  page and its PDF). Nothing to fill in per trip.

#### The rules (decided 14 Oct 2026, before the build)

1. **They belong to the BAG** — one of his bags (a thing on Your bags, stored as the web app's "Containers" list),
   not to a trip. A bag that is only a name on a trip's lines has none; it becomes one of his bags (Care → Bags) the
   moment something is said for it by name (`setBagDetails(_:bag:)` — as "Has an AirTag" from the Tags station,
   part 17 rule 6). Part A says them only on the bag's page; part C may say them from the trip.
2. **Brand and colour are the bag's own thing fields** — `manufacturer` and `color`, which a thing's page has
   shown as **Brand** and **Colour** ("for bags above all", his bag page of 26 Sep 2026; "Its details" on the bag's
   page opens that page). One value in two places, never two values: typed on the bag's page, "Its details" shows it,
   and the other way round. The size's note is the thing's own `size` (the table's "Size" column). Type, the size
   class and the marks are new, so they are extra keys on the bag's thing (`bagType`, `bagSize`, `bagMarks`; the web
   model sees nothing new).
3. **Saved as typed**, as the bag's numbers are (the 0.25 lesson: nothing waits for Return or a Save) — 0.4 s after
   the last key (`lostTyped`: a whole save per key would be slow on his big library, `LibraryModel.commit` builds every
   record again), and AT ONCE on Return, a pill, the "Its details" door and leaving the page (Done, Escape, a swipe —
   `onDisappear`), so nothing typed is ever lost or missing from "Its details". Stored trimmed; an emptied field
   removes its answer — an extra key is absent, never an empty string.
4. **A pill row is one choice**, as Travelling by is: a tap lights it, a tap on the lit one turns it off (no answer).
   A colour pill WRITES its word into the Colour field ("Multi" writes "Multicoloured", what a desk's list calls a bag
   of several colours) — the field stays the answer, and typing over it is fine; a pill is lit while the field says
   its word or its label (compared as names are: case, accents and spaces ignored).
5. **Only what changed is written** (`setBagDetails` compares with what is kept): a type or size a later version
   writes, which this one reads as "not said", is not wiped when another answer changes.
6. **A rename keeps them** (they are on the bag's thing, whose id a rename keeps); **a deleted bag** takes them with
   its thing when the thing goes; kept as a thing on a template ("Keep it on Travel"), the thing keeps them and they
   are back if it becomes a bag again.
7. **Synced, backed up, restored** with the bag's record, as every thing field and extra key is. **Not carried**: a
   trip line copies only the fields `entryFromItem` names (so no line, and so no SHARED trip, carries them); a shared
   template carries no brand, colour, size or extra key (`ListSharing`).
8. **Two devices**: the fields follow a change that arrives from the other device (or from "Its details") while the
   page is open (`followLost`, on a change of the kept details) — each field only where what is typed does not already
   say it (trimmed), and none while a write is still waiting (what he typed wins).
9. **Photos of the bag itself** are the thing's own `photos` — ids into the photo store, the web model's field (up
   to `MAX_PHOTOS` = 5 on any thing), so they are synced (the photo records and the thing's record), backed up and
   restored as photos are, counted in use (`photoInUse` / `photoIdsInUse` read every thing's photos: Worth a look never
   offers them), follow a rename, and travel in no share (a trip line copies no photos; a shared template carries
   none). The bag's page takes **two** (`BAG_OWN_PHOTOS_MAX`): a third is refused while two are stored (as stored —
   one on its way from the other device counts) and the page says "Two photos — remove one to add another"; a bag
   that came from the web app with more shows them all and takes none. Removing one removes its record unless
   something else shows it; removing the FIRST also clears the thing's `thumb` (the web app's small inline picture of
   its first photo). They are **never a photo of it packed**: the trip's `bagPhotos`, the Packing day's Photos station
   and its count ("0 of 3 photos") see none of them. A bag deleted completely leaves its photo records as any deleted
   thing does: nothing shows them, and Worth a look offers them a day later.
10. **On a trip, small, until it is packed and photographed**: in the Bags card (opened) beside the bag's row, and in
   the Packing day's Photos station beside the bag's name — the bag's FIRST own photo, 32 × 32 (corner 6), a tap shows
   it large ("<bag> — how it looks") — only while that trip has no photo of the bag packed (`bagPhotoIds` empty) and
   only for one of his bags (a name on the lines has none). Once the trip has a packed photo, that is the trip's
   picture and the thumbnail goes.

#### On the screens

- **A bag's page** (spec 05, item 3c): after "Has an AirTag", 12 below it like every block, the block `lostDesk`
  (container `bag-lost`, 10 apart): the heading **For the lost-luggage desk** (Body semibold ink, as "Usually in it";
  a heading, id `bag-lost-heading`) and under it "What an airline's desk asks when a bag goes missing. Said once,
  here — every trip uses it." (Footnote muted). Then each answer under its small label (Caption 2 semibold, capitals,
  muted — as MAX KG over the numbers):
  - **BRAND**: a field `bag-detail-brand`, "e.g. Samsonite" (Body ink, padding 10 sideways, 40 tall, the card's fill,
    radius 8, a hairline — the numbers' field, in Body regular).
  - **COLOUR**: a field `bag-detail-colour`, "e.g. Dark blue"; under it the seven pills (`FlowRow`, 6 apart), ids
    `bag-detail-colour-<label in lower case>` (`black` … `multi`), selected when lit.
  - **TYPE**: seven pills `bag-detail-type-<key>` — `hard`, `soft`, `duffel`, `backpack`, `holdall`, `garment`,
    `other` (the words above), selected when chosen.
  - **SIZE**: three pills `bag-detail-size-cabin`, `-medium`, `-large`, and under them the note field
    `bag-detail-sizenote`, "Measures, e.g. 55 × 40 × 20 cm".
  - **DISTINCTIVE MARKS**: a field that grows downwards (1 to 4 lines) `bag-detail-marks`, "e.g. red strap, sticker
    on the side".
  - **PHOTOS OF THE BAG** (`BagOwnPhotos`): none yet — "How it looks — taken empty, any time. Two at most." (Footnote
    muted); else the photos, 80 × 80 (corner 8, `bag-detail-photo-thumb-<k>`, label "Photo k of the bag"; a tap shows
    them large, `BigPhoto`, captioned "How the bag looks"), each with **Remove** under it (Subheadline semibold muted,
    `bag-detail-photo-remove-<k>`, asks nothing). Then, under two, the shared `PhotoTakers` (id `bag-detail-photo`:
    on the iPhone "Take a photo" / "Take another" with a camera and "Choose a photo" / "Choose another",
    `bag-detail-photo-pick`; the Mac Choose only; under the tests one pill "Photo of the bag" / "Another photo" that
    keeps a drawn picture) — at two, "Two photos — remove one to add another" (`bag-detail-photo-full`).
  - The pills are the page's own (as "Delete"'s bag choice): Footnote semibold, 32 tall, a capsule — the bag colour
    (orange) with white words when on, else the page's background with a hairline and ink words.
- **The trip** (spec 03, the Bags card; part 17, the Photos station): `BagLookThumb` — a button beside the bag's
  row (`bag-<n>-look`; beside, not inside: a button in a button never reaches the tree) and beside the bag's name in
  the Photos station (`day-photo-<n>-look`), label "How the <bag> looks" (rule 10).
- **The Mac**: Tab walks the page's fields in reading order — the name, MAX KG, LITRES, EMPTY G, then Brand, Colour,
  the size's note, Distinctive marks, then the pockets' fields; Shift-Tab back (the system's own order: nothing is
  added, nothing skipped). The pills are clicked (with Full Keyboard Access, Tab reaches them too, as every button).
- **How it works** (spec 06 §7), Care: a line of its own after the bag page's Pockets line — "On a bag's page, For
  the lost-luggage desk: what an airline's desk asks when a bag goes missing — its brand, colour (type it, or tap a
  pill: Black … Multi), type (Hard case, Soft case, Duffel …), size (Cabin, Medium or Large, and its measures) and
  distinctive marks (a red strap, a sticker). Said once, saved as you type; every trip uses it. Brand and colour are
  the same as under Its details. A pill tapped again is taken off."

#### Where it is kept (the web model sees nothing new)

| Holder | Field / key | Value | Meaning |
|---|---|---|---|
| item (a bag) | `manufacturer` (its own field) | text | Brand — also "Brand" on its thing page |
| item (a bag) | `color` (its own field) | text | Colour — also "Colour" on its thing page; a pill writes its word |
| item (a bag) | `size` (its own field) | text | the size's note ("55 × 40 × 20 cm") — the table's "Size" |
| item (a bag) | `bagType` (`BAG_TYPE_KEY`) | `hard` · `soft` · `duffel` · `backpack` · `holdall` · `garment` · `other` / absent | Type |
| item (a bag) | `bagSize` (`BAG_SIZE_KEY`) | `cabin` · `medium` · `large` / absent | Size |
| item (a bag) | `bagMarks` (`BAG_MARKS_KEY`) | text / absent | Distinctive marks |
| item (a bag) | `photos` (its own field) | `[photo id]` | Photos of the bag itself (two from its page); the records in the photo store |

Parity: 211/211 (only `extra` keys, and fields the web model already has).

#### The model's API (`BagDetails.swift`, for part B)

- `struct BagDetails { brand, colour, type: BagType?, size: BagSize?, sizeNote, marks, photoIds }` — text trimmed,
  "" = not said; `photoIds` the bag's own photos as stored (READ only: `setBagDetails` never writes them); `isEmpty`
  (nothing said and no photo); `sizeWords` ("Large, 75 × 50 × 30 cm"); `summary` — the whole description on one line,
  "Black · Samsonite · Hard case · Large, 75 × 50 × 30 cm · red strap" (what is not said left out; "" when nothing is);
  `colourPills` (label and word) and `lit(_:)`.
- `enum BagType` (`rawValue` stored, `name` shown), `enum BagSize` (the same).
- `Library.bagDetails(bag: name)` — by the name a trip's lines use (`normName`); empty for a name that is no bag of
  his. `Library.bagDetails(id:)` — nil for anything not a bag. `Library.bagDetails(_ thing:)` — from a thing.
- `Library.setBagDetails(_:id:)` (false for anything not a bag) and `setBagDetails(_:bag:)` (a name becomes a bag when
  something is said — photo ids alone say nothing; "Other" and "" refused).
- `Library.bagOwnPhotos(id:)` / `bagOwnPhotos(bag: name)` → `[PhotoRecord]` on this device, in the order taken;
  `addBagOwnPhoto(id:jpeg:)` → the record, or nil (not a bag, two already, the thing full, no bytes);
  `removeBagOwnPhoto(id:photoId:)`. `BAG_OWN_PHOTOS_MAX` = 2.

#### Tests

Model `BagDetailsTests` (6, `Core/Tests/PackingLibraryTests/BagDetailsTests.swift`; Travel with Boots and the Day pack
in the Big case — both the Big case and the Day pack his bags, the Day pack also a thing he packs; the trip "Coast
week", 20–24 Oct 2026): `testTheDetailsAreTheBagsOwnAndBrandAndColourAreItsThingsOwn` (brand, colour and the note are
`manufacturer`, `color`, `size`; the extra keys as stored words; read by the lines' name, trimmed; "Its details"'
writes read back; emptied → no key; only a bag), `testANameOnTheLinesBecomesABagOnlyWhenSomethingIsSaid`,
`testOnlyWhatChangedIsWrittenSoALaterVersionsAnswerStays` (an unknown type and size survive another answer; the
same answers write nothing), `testTheDetailsFollowARenameAndAreSyncedBackedUpButNeverOnATripLine` (rename, records,
backup; no line of an old or new trip, no shared trip carries them; deleted completely, gone),
`testABagsOwnPhotosAreItsThingsPhotosTwoAtMostAndApartFromTheTrips` (the thing's own photos, two at most, in use a
week on, untouched by `setBagDetails`, photo ids alone make no bag, not a packed photo, through rename/records/backup,
Remove takes the record and the first photo's `thumb`), `testTheDeskHearsPlainWords`. Each seen RED with a planted
fault: the brand written to an extra key ("the brand is not the thing's own Brand"); the name guard removed ("nothing
said, yet the name became a bag"); the type written unconditionally ("a later version's type was wiped"); a trip line
copying the thing's extra keys (`entryFromItem`; "a new trip's line carries the bag's bagType", "a shared trip carries
bag details"); the pill compared by its exact spelling ("a pill is lit only by its exact spelling"); the two-photo
limit lifted ("a third photo of the bag was taken"); the photo ids not read ("the details do not show the photo").
All model tests 576 + 451 green; parity 211/211 (invented backup) and 209/209 (his).

UI (`-uiTestingChecks`, the carry-on; `-uiTestingPackingDay`, the Day pack): `testABagKeepsWhatTheLostLuggageDeskAsks`
(both devices — Brand typed, the Black pill writes "Black" and is lit, Hard case, Large, Duffel takes over and is
taken off again, note and marks typed; closed and opened, all kept; "Its details" shows the same brand and colour),
`testTheMacTabsThroughTheLostLuggageFieldsInOrder` (Mac only: Brand → Colour, the note → marks, Shift-Tab back),
`testABagsOwnPhotoIsOnItsPageAndBesideItOnTheTrip` (two photos, "Two photos — remove one…", no third offered, Remove;
the Day pack's photo beside its row in the Bags card, none beside the carry-on; beside it in the Photos station, which
still says "0 of 3 photos"; a packed photo taken → the thumbnail goes). Seen RED: on the iPhone simulator the type pill
writing nothing — "Hard case is not chosen"; the thumbnail shown whatever the trip has — "the bag's own photo still
shows beside a bag with a photo of it packed"; on GitHub's Mac (a probe branch, deleted after) the Colour field out of
the Tab order — "Tab from Brand did not go to Colour: colour '', brand 'Tumi', note 'Navy'". Green without them: the
iPhone day and night (pictures `lost-bag-filled`, `lost-bag-photo`, `bags-card-look`, `day-photos-look`); the Mac probe
ran the three with seven neighbours (cabin, pockets, Your bags' number, rename and delete, the packed bag's photos,
the Photos station, Tags) — all green. Neighbours on the iPhone simulator: every test that opens a bag's page, the Bags
card or the Photos station, and the How it works tests (29 runs) — green; the Ready test once timed out on a tap
while two Release builds shared the machine, and passed alone (52 s).

#### Open questions

- Size **Cabin** and the switch **Goes in the cabin** are separate answers (one describes the bag for the desk, the
  other decides the airport checks); the build does not tie them. His word welcome if Cabin should switch it on.

> His yes (13 Oct 2026), 0.80: when a checked bag does not come off the belt, everything the airline's baggage desk
> asks for is in the app, ready to show or hand over. Three pieces, built side by side: **A** — each bag's own
> details (brand, colour, type, size, what makes it stand out) on the bag's page; **B** — the trip's flights and
> stay, and each bag's tag number (this section); and the Lost bag page with its PDF, which reads A and B.

### B. Flights and stay, and the bag-tag numbers (0.80)

Built on branch `work/flight080`, written before the screens, then brought in line with the code (the code wins where
they differ). The model: `Core/Sources/PackingLibrary/TripTravel.swift` (`TripTravel`, `FlightLeg`, `TripStay`); the
block: `App/Sources/Screens/FlightsAndStay.swift`; per screen: spec 03 (Create new trip item 7a, Trip settings, the
Bags card, Start a new trip from this one), spec 01 §1.12 (the keys).

#### What he gets

- On a **plane trip** — Travelling by = Plane — Create new trip and Trip settings show one more framed block right under
  Travelling by: **Flights and stay**. It is there only while Plane is lit; Plane off, it goes (what was typed is
  kept, unseen — Plane on again, it is all back).
- In it: the **flights** — at least two, **Out** and **Home**, each its flight number, its day and from → to; **Add a
  flight** puts a **Connection** between them (as many as he needs; a connection has a quiet ✕). Then the
  **Destination** (the city), and **Where you stay**: the hotel's or flat's name, its address, its phone, and **Until**
  (the last day there).
- On a plane trip's **Packing day → Tags**, under each CHECKED bag's ticks, a field **Bag-tag no.** — the number on
  the tag the airline puts on the bag at check-in. The same field is on the trip's **Bags card**, when a bag is opened.
  A bag that goes in the cabin gets no tag at the desk, so it has no field.
- All of it is **optional**: nothing here is ever needed for Create trip or Save changes (the main button never
  grey), and it says so ("Optional." in the block's note).

#### The rules (decided 13–14 Oct 2026, by the build)

1. **Only a plane trip** shows the block and the bag-tag field (`Library.isPlaneTrip`: `transport == "Plane"`). An
   RV or ordinary trip has no flights and no tag from a check-in desk.
2. **Plane off keeps it.** Trip settings saved with Plane off leaves the stored flights, stay and tags as they were
   (not shown, not used — `Library.planeTravel` says nil); Plane on again shows them. Create new trip with Plane off
   stores none of it (nothing it shows is stored).
3. **Out and Home always offered.** The block shows his legs, padded with empty ones up to two
   (`TripTravel.legsForEditing`, `FLIGHT_LEGS_SHOWN` = 2). The first is labelled **Out**, the last **Home**, any
   between **Connection**; Add a flight inserts a connection BEFORE Home, so what is typed under Out and Home stays
   under those words (a connection on the way out is typed in the new row as Out's second flight; on the way home,
   Home's first). Only a connection can be removed (✕); Out and Home are emptied instead.
4. **A leg nothing was typed in is not kept** — a number, from or to makes it a leg; a day alone does not. Empty legs
   anywhere in the list go; the rest keep their order (`Library.cleaned`).
5. **A leg's day.** Shown in a compact date picker; one he never set shows (and is saved as) `Library.legDay`: the
   first leg the trip's first day, the last of two or more its last day, a connection the first day. A trip without
   dates: an empty day shows **Add a day** (a capsule; it sets today), and a leg saved without one keeps "" — no day is
   made up.
6. **What is kept, cleaned.** Flight numbers and bag-tag numbers: trimmed, capitals, single spaces ("zz  1234 " →
   "ZZ 1234", `Library.cleanCode`). From, to, destination, the stay's name and phone: trimmed, single spaces. The
   address: each line trimmed, blank lines gone (it may be pasted on three lines). The stay with only a day is no stay;
   a stay with no **Until** gets the trip's last day.
7. **The destination falls back to the Place.** Empty, the desk is given the trip's Place
   (`Library.travelDestination`); the field shows the Place as its placeholder, so he sees what will be said.
8. **A bag-tag number is per bag on the trip**, by the bag's name as the trip's Bags card shows it, compared by
   `normName` (one number per bag). "Other" (loose things) and a blank name take none. Emptied, it goes; the last one
   gone, the key goes. **Only a checked bag is asked** (`Library.asksBagTag(tripId:bag:)`): a plane trip, a real bag,
   and not a cabin bag — his word on the bag's page ("Goes in the cabin"), else its name, the airport checks' own rule
   (`isCabin`). The sample's "Carry-on / hand luggage" is asked nothing. A number kept before the bag went into the
   cabin stays kept, unasked (the Lost bag page decides what it shows).
9. **It does not count for Tags.** Tags turns green on its ticks as before (spec 07 part 17): the tag number comes at
   the airport's check-in desk, after the Packing day.
10. **A renamed bag** takes its tag number along; two bags made one keep the kept bag's own number (or none); a bag
    deleted to no bag loses it — as the scale's reading does (`moveBagTag`, called from `renameBagEverywhere`).
11. **Start a new trip from this one takes none of it** — other flights, another stay, new tags (`startAgain` copies no
    trip key but the laundry nights).
12. **A shared trip** (link or file) **keeps the flights, the destination and the stay** — the people he shares a trip
    with travel with him, on those flights to that hotel — **but not the bag-tag numbers**: those are on HIS bags
    (`justTheList` drops `bagTags`). Decided by the build, 14 Oct 2026; his word welcome.
13. **Synced, backed up, restored** with the trip's own record, like every trip key.

#### On the screens

- **The block** (`FlightsAndStay`, `App/Sources/Screens/FlightsAndStay.swift`), the look of "I leave at" (spec 03 item
  3a): a rounded frame (corner 12, padding 12) with a 1.5-pt border in the screen's tint (Create blue, Trip settings
  the trip's own) over 6 % of it, id `<p>-frame` (an accessibility container; everything inside keeps its own id), where
  `<p>` is `trip-flights` on Create new trip and `tripset-flights` in Trip settings. Placed directly under Travelling
  by's line (Create: above More choices; Trip settings: above Season).
  - Header row: the **plane** drawing of the template icons (`TemplateIcons.icon("plane")`, the one on Travelling
    by's Plane pill; `Metrics.glyph`, stroke 1.8, in the tint, hidden from VoiceOver), **"Flights and stay"**
    (`HeadingTitle`, id `<p>-title`) and, pushed right, **"for a lost bag"** (Footnote muted, id `<p>-what`).
  - **Each leg** `n` (0-based, id prefix `<p>-leg-<n>`), 6 apart: line one — its word (**Out** / **Connection** /
    **Home**; Subheadline semibold ink, id `…-label`), the flight-number field (placeholder "Flight no.", capitals as
    typed, no autocorrect; id `…-number`) and the day (compact date picker, id `…-date`; or **Add a day**, id
    `…-date-add`); line two — From field (placeholder "From"), an arrow "→" (muted), To field (placeholder "To"), ids
    `…-from`, `…-to`; a connection ends the line with a small quiet ✕ (id `…-remove`, label "Remove this flight"). A
    field: Body, padding 8 sideways, `Metrics.tap` tall, the card's colour, 1-pt `Theme.line` border, corner 8.
  - **Add a flight** (Footnote semibold capsule outline in the tint, `Metrics.chip` tall, id `<p>-add`).
  - **Destination**: its word (Subheadline semibold ink) over a field (placeholder the trip's Place, else "City";
    id `<p>-destination`).
  - **Where you stay** (Subheadline semibold ink): **Hotel or flat** (id `<p>-stay-name`), **Address** (one to three
    lines, grows; id `<p>-stay-address`), **Phone** (the phone keypad on the iPhone; id `<p>-stay-phone`), and a line
    **Until** with a compact date picker (id `<p>-stay-until`) or **Add a day** (id `<p>-stay-until-add`).
  - A hairline (1 pt `Theme.line`), then (Footnote muted, id `<p>-note`): **"Optional. What the airline's desk asks
    when a bag does not arrive. Each checked bag's tag number goes in on the Packing day, under Tags."**
- **Create new trip**: the form's flights start as Out and Home, empty; Create stores them (Plane on) and the form
  starts over, as "I leave at" does. **Trip settings**: opens on the trip's own (`Library.travel`), Save keeps them
  (`Library.setFlightsAndStay` — the bag-tag numbers are left as they are); part of what a swipe down guards.
- **Packing day → Tags** (plane trips): the lead adds "At check-in, type the number on each checked bag's tag."
  Under each checked bag's ticks (`asksBagTag`), before Has an AirTag: **Bag-tag no.** (Footnote semibold muted) and a field (monospaced, placeholder "from
  check-in", capitals; id `day-tag-<n>-number`). Kept when Return is pressed, when the field loses focus, and when the
  station closes (`BagTagField`, one model change per number, not per key).
- **The Bags card** (plane trips): a checked bag tapped open shows, after its photo row, the same field (id
  `bag-<n>-tagno`); a cabin bag and "Other" have none.
- **How it works** (spec 06): Create new trip's part says what Flights and stay is; the Packing day's Tags says where the
  tag number goes.

#### Where it is kept (the web model sees nothing new)

| Holder | Key | Value | Meaning |
|---|---|---|---|
| trip | `travel` (`TRIP_TRAVEL_KEY`) | `{ "flights": [{ "number", "date", "from", "to" }], "destination", "stay": { "name", "address", "phone", "until" } }` — each part only when it holds something / absent | the flights, the destination and the stay; written by Create new trip and Trip settings |
| trip | `bagTags` (`BAG_TAGS_KEY`) | `{ "<bag name>": "<tag number>" }` / absent | each bag's tag number; written by the Packing day's Tags and the Bags card |

Dates are "YYYY-MM-DD" (`isYMD`) or "". Nothing typed = no key. Parity: 211/211 (only `extra` keys).

The API the Lost bag page reads: `Library.travel(_ trip:)` / `travel(tripId:)` → `TripTravel { flights: [FlightLeg {
number, date, from, to }], destination, stay: TripStay { name, address, phone, until }, bagTags: [bag name: number] }`,
`TripTravel.bagTag(_ bag:)` (by `normName`), `Library.bagTag(_ trip:, bag:)`, `asksBagTag(tripId:bag:)` (a plane trip's
checked bag), `Library.travelDestination(_:)` (own
destination, else the Place), `Library.planeTravel(_:)` (nil unless Plane), `Library.isPlaneTrip(_:)`. Writing:
`setTravel(_:tripId:)`, `Library.setTravel(&trip, _)`, `Library.setFlightsAndStay(&trip, _)`, `setBagTag(_:tripId:bag:)`.

#### Tests

Model `TripTravelTests` (9, `Core/Tests/PackingLibraryTests/TripTravelTests.swift`; invented flights, hotel and numbers
— the repository is public; the trip "Sun week", 14–20 Oct 2026, by Plane, Place "Seaside", a Passport in the Big case
and a Charger in the Day pack, both his bags): `testFlightsAndStayAreKeptCleanedOnTheTrip` (capitals, Home's day the
last day, the address's lines, Until the last day; records, a backup; emptied = no key),
`testLegsNothingWasTypedInGoAndTheBlockShowsOutAndHome` (two offered; empty legs go; a connection on the first day; Out
left empty, Home still on the last day; no dates no day; his own day kept; a stay with only a day is none),
`testTheDestinationFallsBackToTheTripsPlace`, `testOnlyAPlaneTripShowsItAndPlaneOffKeepsIt`,
`testCreateAndTripSettingsLeaveTheBagTagsAlone`, `testABagTagIsKeptPerBagAndTakenAwayWithNothing` (cleaned; one per
bag by `normName`; "Other" and a blank name refused; the last gone = no key),
`testOnlyACheckedBagOnAPlaneTripIsAskedForItsTag` (a bag, a name on the lines; not "Other", not the carry-on by its
name, not a bag he says goes in the cabin, not an RV trip), `testABagRenamedTakesItsTagAlongTwoMadeOneKeepTheirOwn`
(rename; deleted into the Day pack; deleted to no bag), `testAStartAgainTakesNoneOfItASharedTripKeepsFlightsButNotTags`.
Each seen RED with a planted fault: `cleanCode` without capitals ("flight numbers not in capitals"); `legsForEditing`
padding to one ("("1") is not equal to ("2") - the block did not offer out and home"); a leg's day counted among the
kept legs only ("("["2026-10-14"]") is not equal to ("["2026-10-20"]") - Home alone was put on the first day");
`travelDestination` without the Place ("("") is not equal to ("Seaside")"); `planeTravel` ignoring the transport ("a
trip by car showed flights"); `setFlightsAndStay` dropping the tags ("saving the block lost a bag tag"); `setBagTag`
comparing names exactly ("("["Day pack": "CD 9", "Big case": "ab 123456"]") is not equal to ("["BIG CASE": "EF 7",
"Day pack": "CD 9"]")"); `asksBagTag` without the cabin ("a cabin bag (by its name) was asked for a tag", "a bag he says
goes in the cabin was asked for a tag"); no `moveBagTag` ("a renamed bag lost its tag"); `justTheList` keeping
`bagTags` ("his bag tags went with a shared trip"). All model tests 579 + 451 green; parity 211/211 on the invented
backup (209/209 on his own, on his Mac).

UI (`AMSPackingUITests`): `testFlightsAndStayOnlyOnAPlaneTrip` (`-uiTesting`: no block until Plane; "Flights and stay",
Out and Home, no third; Add a day without dates; Add a flight → Connection before Home, Out and Home have no ✕, the ✕
takes it away; a flight, from → to, the destination, the hotel and a phone typed; Plane off → gone, on → what was typed
is back; Create; Trip settings opens on it, the number trimmed; saved with Plane off → no block, Plane on again → the
flight is still there) and `testABagTagNumberAtTheTagsStation` (`-uiTestingPackingDay -packingDayByPlane`: the Day pack
— checked — has Bag-tag no., the carry-on — a cabin bag by its name — has none; typed + Return → kept trimmed, Tags
still "0 of 3 ticked"; the Bags card's opened Day pack shows it; `-uiTestingPackingDay` alone — not by plane — no
field). Typed in capitals with a space too many: the keyboard may capitalise on its own, so the capitals are the
model's test, the trimming the screen's. Each seen RED on the iPhone simulator with its own planted fault: Create not
storing the block — "the flight was not kept (trimmed): 'Flight no.'"; Tags asking every bag on a plane trip — "the
carry-on goes in the cabin, yet it is asked for a tag number". Green again without them, day and night (pictures
`flights-create-top`, `flights-create`, `flights-tripset-top`, `flights-tripset`, `flights-day-tags`,
`flights-bags-card`). On the iPhone simulator, 43 neighbouring tests (every test that picks Plane, opens Trip settings,
the Bags card, the Packing day or How it works) all green. On GitHub's Mac (a probe: the two tests with Travelling by,
Tags, Trip settings and the cabin switch on a trip, day; the two again at night; then Tags asking every bag planted):
all green, and the plant RED — "the carry-on goes in the cabin, yet it is asked for a tag number". The test helper `fill` keeps a field clear of the status bar and the keyboard before typing (a
field reported on screen under the status bar took no focus).

#### Open questions

- A shared trip carries the hotel's address and phone to whoever he shares it with (rule 12). Right for the people
  he travels with; if he shares trips as lists with others, a "keep my stay to myself" would be the fix.
- The flight's times (departure, arrival) are not asked — the desk asks the flight and the day. Worth adding if the
  Lost bag page wants them.
- The bag-tag number is per trip; a return flight usually gives a new tag — the field holds the latest. Two numbers
  per bag (out, home) if he wants both kept.

### C. The Lost bag page

> His yes (13 Oct 2026) to the lost-luggage information, part C — the page the other two parts feed: on a trip, a
> **Lost bag** page PER BAG with everything a baggage desk asks for, in a calm, readable layout he can hand over or read
> out, with **Share as PDF** and **Copy as text**. Part A keeps a bag's own details (type, brand, colour, size,
> distinctive marks — on the bag's page, `PackingLibrary/BagDetails.swift`); part B keeps a trip's flights, where he
> stays and until when, and each bag's tag number (`PackingLibrary/TripTravel.swift`). This part adds who he is for
> the desk (name, phone, e-mail, home address) and the page itself. Built on branch `work/lostbag080` (0.80); written
> BEFORE it was built, then brought in line with the code (the code wins where they differ). The model:
> `Core/Sources/PackingLibrary/LostBag.swift`; the page, its PDF and his details' sheet:
> `App/Sources/Screens/LostBag.swift`. Per screen: spec 03 (the Bags card's "Lost bag?"), spec 06 §1 and §2 (the
> Settings door and This is me), spec 07 part 17 (the Packing day's Photos and Ready), spec 01 §1.11 and §10 (the key,
> the backup).

#### What he gets

- **Who he is, once.** Settings opens with a door **For the lost-luggage desk** — "Your name, phone, e-mail and home
  address". Its sheet keeps four fields: Full name, Phone, E-mail, Home address (several lines). They belong to the
  library (both devices, the backup), not to a trip. The same sheet opens from Your choices → Owners, under **This is
  me** on the owner marked as him, and from any of those four rows of a Lost bag page that says "not filled in".
- **A Lost bag page per bag** of a trip, reached three ways: each bag of the trip's **Bags card** (opened) has a small
  **Lost bag?** under its row; the Packing day's **Photos** station has the same under each bag's photos; its **Ready**
  station lists "If a bag goes missing" with a row per bag that says how much is still not filled in.
- The page, top to bottom: **About you** (name, phone, e-mail, home address) · **The trip** (the trip and its dates,
  where he is going, where he stays, until when, the flights, the bag-tag number) · **The bag** (type, brand, colour,
  size, distinctive marks, and AirTag yes/no — with yes, "In Find My, Share Item Location gives the airline a link to
  where it is.") · **Photos** (the bag's own, and the photo of all the bags together) · **A few things in it** (the
  trip's lines in that bag, the first eight, and "and N more").
- Anything not known says **not filled in**, and a tap on it opens the page that fills it in. A line at the top says
  how many: "3 not filled in — tap one to fill it in."
- At the foot, always in view: **Share as PDF** (the system share sheet with a PDF of the page — to mail, AirDrop,
  print, or save) and **Copy as text** (the same words, for a web form or a chat with the airline).

#### The rules (decided 13–14 Oct 2026, by the build)

1. **His details** (`DeskDetails`: `name`, `phone`, `email`, `address`) are kept in `meta` under **`lostDesk`**
   (`LOST_DESK_KEY`) as `{name, phone, email, address}` — only the ones said, each trimmed (single spaces inside a
   line), the address line by line with blank lines gone; nothing said = no key. ONE record, synced; in a backup under
   `prefs.lostDesk` and back with an import and a restore. The web app sees nothing (parity 211/211).
2. **The name the desk gets** (`Library.deskName()`): the full name he typed; else the owner marked **This is me**
   (part 7, `me()`); else nothing ("not filled in"). The full name's field shows the This-is-me owner as its
   placeholder, so he sees what is used while it is empty.
3. **Which bags have a page**: any bag a trip's lines name — one of his bags (Care → Bags) or only a name on the lines
   — but never "Not in a bag" (`Other`) or no name (`Library.isRealBag`), and since 0.83 never a bag on him:
   `NOT_LOSABLE_BAGS` = "On body", "On me", "Worn", "Wearing", matched by `normName` (his Bags card of 14 Oct 2026
   offered "Lost bag?" for "On body"; the three others decided by the build, the same idea in other words). The ONE rule
   is `Library.hasLostBagPage(_:)` (real bag and not on him), and every door asks it — the Bags card, Photos and
   Ready. `Library.lostBag(tripId:bag:)` is nil for those bags and for no such trip. Where the page is offered, it is offered for the bags the trip's Bags card shows
   (without "Not in a bag"), the Packing day's bags.
4. **About you** — four rows: Name (`deskName()`), Phone, E-mail, Home address (one line per address line). Each
   missing one: "not filled in", and a tap opens **For the lost-luggage desk** with that field's keyboard focus.
5. **The trip** — first the trip's name and its days ("Weekend in the hills · 14 Nov 2026 – 16 Nov 2026"; one day:
   that day; no dates: the name alone). Then, **on a plane trip** (Travelling by = Plane, part B's `planeTravel`):
   - **Going to**: part B's destination, else the trip's Place (`Library.travelDestination`).
   - **Staying at**: the stay's name, its address lines and its phone, one line each, what is said.
   - **Until**: the stay's last day (part B fills it with the trip's last day when a stay is typed without one), else
     the trip's last day, else not filled in.
   - **Flights**: one line per leg, in his order — "SK 1234 · 14 Nov 2026 · ARN → AGP" (what is not said is left out;
     only a from or only a to: "from ARN" / "to AGP").
   - **Bag-tag number**: this bag's number (part B's `bagTag`, by `normName`) — only for a bag part B asks a tag of
     (`asksBagTag`: a CHECKED bag; a cabin bag, by his word or its name, gets no tag at the desk), or when a number is
     kept anyway (one typed before the bag went into the cabin).
   A missing Going to, Staying at, Until or Flights opens **Trip settings** (part B's Flights and stay block is there).
   A missing **bag-tag number** is typed RIGHT ON THE PAGE: the row opens a field "Number on the bag tag" with
   **Save** — the number is on the stub the check-in desk stuck on his boarding pass, and the desk is where he reads it
   (`setBagTag`, the same number the Tags station keeps). Save with the field empty takes a number away; a filled row
   opens the same field to correct it.
   **Not a plane trip**: only Going to, and the quiet line "Flights, where you stay and the bag-tag number are asked on
   a plane trip — Travelling by, in Trip settings." (A trip by car, train or bus still gets the page: a bag can go
   missing anywhere, and the rest of the page is what a lost-property office asks.)
6. **The bag** — Type, Brand, Colour, Size, Distinctive marks: part A's `bagDetails(bag:)` (Type its name, "Hard
   case"…; Size its words, "Large, 75 × 50 × 30 cm"). Each missing one: not filled in, a tap opens **the bag's page**
   (Care → Bags → the bag, where part A's details are). A bag that is only a name on the lines BECOMES one of his bags
   first (`addBag`), as Goes in the cabin and Has an AirTag do from a trip — its page needs a bag. Then **AirTag**: "Yes"
   (the bag's own switch, part 17 rule 6) with the hint "In Find My, Share Item Location gives the airline a link to
   where it is." (`LOST_AIRTAG_HINT`), or "No" — never "not filled in" (no AirTag is an answer). A tap on AirTag
   opens the bag's page too (its switch is there).
7. **Photos** — the photos of the bag itself (how it looks, from its page — part A's `photoIds`, up to two), then this
   trip's photos of it packed (the Bags card's, up to three, as stored), then the photo of all the trip's bags together
   (part 17), captioned "All your bags". A tap shows one large (`BigPhoto`, captions "Day pack 1
   of 2" … "All your bags", Next steps through all). No photo of the bag at all (neither how it looks nor packed on this
   trip, `LostBagPage.noPhoto`): the row "Photo of the bag — not filled in" and the ways to take one right there (`PhotoTakers`: on the iPhone Take a photo / Choose a photo, on the
   Mac Choose) — kept as the bag's photo on this trip (`addBagPhoto`), as if taken in the Bags card. Only a photo of
   the bag itself counts towards "not filled in"; the photo of all the bags is shown when there is one.
8. **A few things in it** — the trip's lines in this bag (`container` by `normName`), set-aside lines and reminders
   left out, in the trip's own order; when any of them is ticked, ONLY the ticked ones (what went in), else all of
   them (what is meant to). The first **eight** (`LOST_INSIDE_SHOWN`), each "Name" or "Name ×3" (the line's count,
   nights and laundry included, as the trip shows it); then "and N more". None: "Nothing on this trip's list goes in
   this bag." Never "not filled in".
9. **"Not filled in"** (`LostBagPage.missing`): the rows of About you, The trip (on a plane trip: Going to, Staying
   at, Until, Flights, and the Bag-tag number of a checked bag; otherwise Going to) and The bag (five), plus the bag's own photo, that are
   empty. The count heads the page ("1 not filled in — tap it to fill it in." / "3 not filled in — tap one to fill it
   in."); none: nothing is said.
10. **Copy as text** (`LostBagPage.text`) — what a web form or a message needs, plain, one fact per line:

    ```
    LOST BAG: Day pack
    Trip: Weekend in the hills · 14 Nov 2026 – 16 Nov 2026

    ABOUT ME
    Name: Kim Example
    Phone: +46 70 000 00 00
    E-mail: not filled in
    Home address: Exempelgatan 1, 123 45 Exempelstad

    THE TRIP
    Going to: Málaga
    Staying at: Hotel Exempel, Calle Falsa 1, Málaga, +34 900 000 000
    Until: 16 Nov 2026
    Flights: SK 1234 · 14 Nov 2026 · ARN → AGP; SK 1235 · 16 Nov 2026 · AGP → ARN
    Bag-tag number: SK 123456

    THE BAG
    Type: Backpack
    Brand: Exempel
    Colour: Green
    Size: Medium, 55 × 35 × 25 cm
    Distinctive marks: red strap
    AirTag: Yes. In Find My, Share Item Location gives the airline a link to where it is.
    Photos: 2 (in the PDF)

    A FEW THINGS IN IT
    Hiking boots
    Rain jacket
    ```

    Several lines of one fact (an address, the stay) are joined with ", ", flights with "; ". "Photos: none" when
    there is none; "and N more" as the last line of the things. Not a plane trip: THE TRIP holds Going to and the
    plane line's words. The button says **Copied** for a moment after (value "copied").
11. **Share as PDF** — the page drawn again for paper (`LostBagPDF`), A4 (595 × 842 points), always light, black on
    white: **page 1** the title "Lost bag: <bag>", the trip line, and the four blocks in two columns (About you and The
    trip at the left, The bag and A few things in it at the right), "not filled in" where nothing is known; **page 2**
    (only when there are photos) the photos, as large as two to a page allows, each captioned. Written by SwiftUI's
    `ImageRenderer` into a PDF context (no other library), into the device's temporary folder as "Lost bag – <bag>.pdf"
    (characters a file name cannot hold become "-"), then handed to the system share sheet (iPhone:
    `UIActivityViewController`; Mac: the sharing menu at the button). Under the UI tests no share sheet opens: the file is
    written and the page says "PDF ready — 2 pages" (`lost-pdf-said`) — no test can work the system's share sheet.
12. **Live** — the page reads the library on every drawing: a field filled in on the sheet it opened is on the page
    the moment that sheet closes; a change on the other device arrives as it syncs. The trip deleted while the page is
    open: it closes.
13. **Nothing new travels with a trip**: the page keeps nothing of its own. A shared trip carries part B's flights and
    stay (part B) but never his details (they are in `meta`, not the trip); Start a new trip from this one copies none
    of it.

#### On the screens

- **The page** (`LostBagScreen`, a sheet, id `lost-screen`; on the Mac at least 520 × 640):
  - Header (padding 16): "Lost bag" (Title 3 bold, ink) and under it the bag's name (Subheadline semibold muted, one
    line) — one element `lost-heading`; at the right **Done** (filled, the trips' green, Escape, id `lost-done`).
  - In a scroll (`KeyboardAwayScroll`, 16 sideways, 24 below, 12 between the blocks): the lead "Everything a baggage
    desk asks for. Hand it over, read it out, or share it." (Footnote muted, `lost-lead`); when something is missing,
    "3 not filled in — tap one to fill it in." (Subheadline semibold, the Care orange, `lost-missing`).
  - Five cards (padding 12, radius 12, `Theme.card`, hairline), each headed by its name (Subheadline semibold, the
    trips' readable green): **About you** (`lost-you`), **The trip** (`lost-trip`), **The bag** (`lost-bag`),
    **Photos** (`lost-photos`), **A few things in it** (`lost-inside`).
  - A row (`LostBagRowView`): the label (Footnote semibold muted) over the value — each line in Body ink — or "not filled in" (Body, the Care orange); at the right a drawn chevron (muted); at least `Metrics.row`
    tall; a hairline between rows. The whole row is ONE button (id `lost-<card>-<key>`, label = the row's label, value
    = its lines joined with ", " or "not filled in"), opening where it is filled in (rule 4–6). Keys: `you-name`,
    `you-phone`, `you-email`, `you-address`; `trip-going`, `trip-stay`, `trip-until`, `trip-flights`, `trip-tag`;
    `bag-type`, `bag-brand`, `bag-colour`, `bag-size`, `bag-marks`, `bag-airtag` (value "yes" / "no"; the hint under
    "Yes" in Footnote muted, id `lost-bag-airtag-hint`).
  - The trip's first line: the name and days (Subheadline semibold ink, `lost-trip-name`). Not a plane trip: the line
    of rule 5 (Footnote muted, `lost-trip-noplane`).
  - The tag number's field (rule 5): "Number on the bag tag" (`lost-trip-tag-field`, all capitals on the iPhone's
    keyboard), **Save** (filled green capsule, `lost-trip-tag-save`), **Cancel** (Subheadline semibold muted,
    `lost-trip-tag-cancel`); Return saves.
  - Photos: thumbnails 96 pt, corner 8 (`lost-photo-<k>`, label "Photo k of the bag"; the photo of all the bags
    `lost-photo-all`, label "Photo of all your bags", with "All your bags" under it in Footnote muted); none of the bag:
    the row "Photo of the bag" / "not filled in" (`lost-photo-none`, a text, not a button) and the takers
    (`lost-photo-take`, `-pick`; under the tests one pill "Photo of the bag").
  - Things: one line each (Body ink, `lost-inside-<k>`), "and N more" (Footnote muted, `lost-inside-more`); none: the
    rule-8 words (`lost-inside-none`).
  - **The foot**, outside the scroll, always in view (16 sideways, 10 above and below, a hairline over it, the page's
    colour): **Share as PDF** (Body semibold white on the trips' green, rounded 12, `Metrics.tap` tall, half the width,
    `lost-pdf`) and **Copy as text** (the same, outlined green, `lost-copy`, value "copied" after a press).
    `lost-pdf-said` sits above them under the tests.
  - Sheets it opens (one `.sheet(item:)`): **For the lost-luggage desk** (`DeskDetailsScreen`), **Trip settings**
    (`TripSettingsScreen`), **the bag's page** (`BagDetail`), and a photo large (`BigPhoto`).
- **For the lost-luggage desk** (`DeskDetailsScreen`, a sheet, id `desk-screen`; Mac at least 460 × 480): header
  "For the lost-luggage desk" (Title 3 bold), **Cancel** (outlined, Escape, `desk-cancel`) and **Save** (filled, the
  Settings slate, `desk-save`; never grey — with nothing changed it just closes); "What a baggage desk asks about you.
  Kept on your devices and in your backup, and shown only on a bag's Lost bag page." (Footnote muted); four fields,
  each with its label above (Footnote semibold muted): **Full name** (`desk-name`; placeholder the This-is-me owner, or
  "As on your passport"), **Phone** (`desk-phone`, phone keyboard), **E-mail** (`desk-email`, e-mail keyboard, no
  capitals, no corrections), **Home address** (`desk-address`, several lines, 3 to 6 tall). Return moves to the next
  field (the address takes new lines). Swiping the sheet away with something changed is refused (Cancel or Save).
- **Settings** (spec 06 §1): the first card is now TWO door rows — **For the lost-luggage desk** ("Your name, phone,
  e-mail and home address", id `settings-desk`) above **Your choices** (`settings-lists`), a `CardHairline` between —
  first, as the iPhone's own Settings starts with the person. Once a name and a phone are known its line reads
  "<name> · <phone>".
- **Your choices → Owners** (spec 06 §2): in the owner editor, on the owner marked **This is me** only, under its
  button, the door **For the lost-luggage desk…** (Subheadline semibold, the Settings slate, `list-owners-desk`) opens
  the same sheet.
- **The Bags card** (spec 03), opened: under the row of each bag with a page (rule 3 — not "Not in a bag", not "On
  body"), at the right, **Lost bag?** — since 0.83 a quiet text link: Footnote regular in the trips' green for words
  (`Library.LoopStep.pack.words`), no outline, 4 sideways, at least 24 tall, pulled 8 pt up to its own row (0.80–0.82:
  Footnote semibold with a 1.2-pt green capsule outline, 10 sideways, 26 tall — "a column of green outlines"); id
  `bag-<n>-lost` — it opens the page for that bag (the card owns the sheet). `LostBagDoor` draws it everywhere. The
  key's last line adds "Lost bag? under a bag: everything a
  baggage desk asks for."
- **The Packing day** (part 17): in **Photos**, under the photos of each bag with a page (rule 3), the same **Lost
  bag?** at the right (`day-photo-<n>-lost`); in **Ready**, after the stations and before I leave at, while any bag has
  a page, "If a bag goes missing" (Subheadline semibold ink) and a row per such bag (`n` stays the bag's place among the
  day's bags) — "Lost bag: <name>" (Body), at the right "all filled in" (green) or "3 not filled
  in" (orange), a chevron — each a button `day-ready-lost-<n>` (value = those words) opening the page. The day's sheet
  owns that page's sheet.
- **How it works** (spec 06 §7): a topic of its own, **If a bag goes missing** (the trips' section), right after *On
  site* — where the page is, what it holds, not filled in and the tap, the bag-tag number on the page, Share as PDF and
  Copy as text, his details in Settings. **Words** (spec 06 §10): "Lost bag".

#### Where it is kept (the web model sees nothing new)

| Holder | Key | Value | Meaning |
|---|---|---|---|
| meta | `lostDesk` (`LOST_DESK_KEY`) | `{name, phone, email, address}`, each only when said / absent | his details for the baggage desk (rule 1) |
| backup | `prefs.lostDesk` | the same object | carried by a backup; read back by an import and a restore |

Everything else on the page is read from what parts A and B, part 17 and the trip already keep; the page writes only
his details, a bag-tag number (part B's key), a bag photo (the Bags card's) and — when a detail of a bag that was only a
name is filled in — the new bag. Parity: 211/211.

#### Tests

Model `LostBagTests` (8, `Core/Tests/PackingLibraryTests/LostBagTests.swift`; a base template with a Passport and a
Charger in the carry-on, Hike with Boots, a Jacket, Socks ×3 and a Map in the Day pack — one of his bags, with an
AirTag — a Water bottle in no bag and a reminder in the Day pack; the trip "Sun week", 14–20 Nov 2026, by plane):
`testTheDeskDetailsAreKeptForTheLibraryCleanedSyncedAndBackedUp` (trimmed, the address line by line, only what is said
is written, the records, a backup's `prefs.lostDesk` and back, not in a shared trip, nothing said = no key),
`testTheDeskNameIsTheOneTypedElseThisIsMe`, `testThePageGathersYouTheTripAndTheBag` (every row's words, the flights'
lines, Until from the trip, the AirTag, a partial flight "SK 99 · 14 Nov 2026 · to AGP", the photo of all the bags, the
bag's own photo counts as a photo), `testWhatIsNotKnownSaysNotFilledInAndWhereItIsFilledIn` (14 not filled in, the fill
targets, "1 … tap it", the trip's Place as Going to), `testATripNotByPlaneAsksNoFlightsStayOrTag`,
`testAFewThingsInItAreWhatWentInTheFirstEightAndHowManyMore` (all when nothing is ticked, only the ticked once one is,
set aside and reminders out, "Socks ×3", another spelling of the bag, eight and "and 5 more", none),
`testOnlyABagHasAPage` ("Other", blank, no trip → nil; a name-only bag: no details, AirTag "No", the carry-on — a cabin
bag — asked no tag; "/" in the PDF's name), `testTheTextIsWhatADeskReads` (the whole text). Each seen RED with a planted
fault: the backup without the key ("a backup does not carry his details"); `deskName` ignoring This is me ("("") is not
equal to ("Kim")"); the stay without its phone ("[…"Málaga"] is not equal to […"Málaga", "+34 900 000 000"]"); the
photo not counted ("("13") is not equal to ("14") - and the bag's own photo"); every trip a plane trip ("a car trip
asks no flights"); every line inside, ticked or not ("["Boots", "Jacket", "Socks ×3"] is not equal to ["Boots"]");
"Other" given a page ("XCTAssertNil failed: LostBagPage(bag: "Other" …"); flights joined with ", " (the text differs).
All model tests 593 + 451 green; parity 211/211.

UI (`-uiTestingLostBag`, `SampleLibrary.lostBag()`): `testALostBagPageSaysWhatTheDeskAsksAndFillsInWhatIsMissing` (from
the Bags card's `bag-1-lost`; no `bag-2-lost` for Not in a bag; every row's value, the AirTag hint, the photo, the
first thing; "3 not filled in"; the tag typed on the page → "SK 123456", "2 not filled in"; the e-mail through For the
lost-luggage desk → on the page, "1 not filled in — tap it"; Copy → "copied"; Share as PDF → "PDF ready — 2 pages";
Settings then holds the e-mail), `testTheLostBagPageOpensFromThePackingDayAndFillsInTheBag` (Photos' `day-photo-0-lost`
opens the carry-on: type not filled in, AirTag "no" and no hint, `lost-photo-none`, a photo taken on the page is kept,
no bag-tag row for the cabin bag, Colour opens the bag's page; Ready's rows "… not filled in" / "3 not filled in" and
`day-ready-lost-1` opens the Day pack's page), `testSettingsKeepsHisDetailsForTheLostLuggageDesk` (the door above Your
choices in one card, Save, the door names him, This is me's `list-owners-desk` opens the same details, How it works has
the topic). Each seen RED on the iPhone simulator with its own planted fault: the tag not saved ("'not filled in'");
the photo taken on the page not kept ("the photo taken on the page was not kept"); no link under This is me ("no
list-owners-desk to tap"). Green again without them, day and night (pictures `lost-page`, `lost-desk`,
`lost-page-filled`, `lost-bag-page`, `lost-ready`, `desk-settings`). The harness's taps on the page go through
`showOnLostPage`, which scrolls by frames: asking a row scrolled off the top whether it is hittable was a hard failure
once ("Activation point invalid").

#### Traps met building it

- **A text field's binding that opens the field.** The tag's field was shown while an optional held its text; the
  field writes its text back as it loses focus, so Save (which emptied the optional) opened it again at once — the row
  never came back. Two states now: open or not, and the text.

#### Open questions

- The page reads the way OUT: on the way home (Pack to go home) a thing may travel in another bag, and "A few things in
  it" still lists what went out in this one. If he loses a bag on the way home, the home bags' ticks could decide it.
- A trip with several travellers: the page is his (his details, his bags' tags). A shared trip's other traveller gets
  their own page with their own details on their phone.
- The PDF draws the page in English with the app's words, as everything else; an airline abroad may prefer a form of
  its own — Copy as text is for that.

---

## 19. Before you start

> His words (14 Oct 2026), from his own packing walk-through: "Think if there is anything I need to buy or prepare
> well in advance." His yes the same day: ONE place, on a trip that is not being packed yet, for everything to buy
> or get ready ahead — until then it stood in three: To do → To buy, the reminders on his templates, and a thing's
> own Valid until and battery. Written here BEFORE it was built (branch `work/beforestart082`), then brought in line
> with the code by the same branch: the model `Core/Sources/PackingLibrary/BeforeYouStart.swift`; the door and the
> sheet `App/Sources/Screens/BeforeYouStart.swift`; Home's line in `App/Sources/Screens/Countdown.swift`. Per
> screen: spec 03 (the trip screen, scroll area item 0, and "Before you start"), spec 02 §11 (the countdown card).

### What he gets

- **A trip not yet being packed**: first in its scroll area, above Before you go, a slim door **Before you start**
  with what it holds in a few words — "2 to buy · 3 to prepare · 4 to charge". A tap opens a sheet of that name with
  up to three parts: **To buy**, **To prepare**, **To charge**.
- **Home's countdown** (the next trip): under its lines, "Before you start: 2 to buy, 3 to prepare".

### The rules (decided 14 Oct 2026, by the build)

1. **When — the Plan step, and Pack until he has started packing** (`Library.beforeStartTime(trip, today:, time:)`).
   The trip's loop step (`loopStep`, on the screen's clock — the day and the time of day) is **Plan** or **Pack**:
   not reviewed, its last day not passed, not set off, nothing bought on site. And **nothing is packed yet**
   (`Library.hasStartedPacking`): no line is ticked that is a thing to pack. A reminder, a To do written on the trip
   and a line of a step of things to DO (a `task` step — the factory Preparations) are not packing, so ticking one
   here does not end Before you start; neither is a line set aside, nor a thing marked charged. Something ticked
   inside a kit (`kitTicked`) is packing. *Why it ends at the first tick (decided by the build):* from then on the
   trip is being packed and Before you go, right under it, holds what still needs him — the flags, each reminder as
   its step comes, To charge from the day before; the door would be a second list of the same things. A trip at Plan
   has no lines (that is what Plan means on a trip, `loopStep`), so nothing to show: the door comes with the first
   lines.
2. **Not on a place's view.** A trip opened from a place's code shows only that place's lines, as for the other
   cards — no door.
3. **Each part only when it has something; the door only when one part has.**
4. **To buy** (`Library.toBuyBeforeStart(tripId:today:)`) — one row per THING on the trip, in the trip's order, a
   thing once: each line not set aside and not a reminder, its thing as it is now (`thingNow`); and each thing
   inside a kit on the trip, not taken out (`insideLines` — "Lighter, in the Camp pouch"). A line typed on the trip
   only (no thing behind it) is its own row. A row is there for any of these reasons, said in this order:
   - a. **On To buy** — an open line of To buy (`actions`, `kind` "shopping", not done) for it: one made for this
     thing (`itemId`), or one typed without a thing that has its name (`normName`).
   - b. **Needs replacing** — its Condition is one that replaces (`conditionReplaces`, To buy's own suggestion rule).
   - c. **Valid until** — Before you go's date rule, exactly (`dateCheck`): out of date already, running out before he
     is home, a document (Documents & money) within six months of it. The same words as there.
   - d. **Used up last time** — the last trip before this one on which it went (by start date before this trip's;
     before today when this trip has no dates; its line ticked and not set aside, or used up) marked it **Used up**
     on the way home (`usedUp`), and no To buy line for it was ticked bought since that trip began (`doneAt` on or
     after its start date). A later trip on which it went and was not used up clears it.
   Not listed (decided by the build): a consumable alone — the app does not know how much is left, and To buy's own
   "Restock" suggestion stays where it is; "Replace soon" by today's 30 days — the trip's own date rule (c) judges
   it; To buy lines about things not on this trip, and lines typed without a thing whose name is on no line; the To
   do tab's to-dos — they belong to no trip.
5. **To prepare** (`Library.toPrepare(tripId:today:)`) — the trip's lines not ticked and not set aside that are
   things to DO: a reminder (`itemType` "reminder", spec 07 part 12) or a line of a `task` step (Preparations), whose
   When falls due BEFORE the day he leaves — lead days 1 or more (the factory steps: Preparations 30, ≥1 week ahead
   7, Day before 1). Steps on the day itself (lead days 0: the morning, the front door, worn) are no preparation
   "well in advance": they come in Before you go when due. And every **To do written on the trip** (0.81, `tripTodo`;
   due at once, whatever its When). Order: by the day it falls due (most lead days first; the same day in the
   timeline's order), then the trip's order; the trip's To dos last, in the order written. Each row says its When
   ("≥1 week ahead") and, on a dated trip, when it falls due — "from 13 Oct", or "now" once that day has come; a To do
   written on the trip says "Added on the trip".
6. **To charge** — the things on the trip with a battery (`toCharge`, part 15 rule 3) not charged yet: just the
   count and the names (a thing inside a kit "in the Camp pouch"). Charging is ticked in Before you go's To charge,
   from the day before the trip (part 15 rule 5) — the sheet says so; it has no ticks of its own.
7. **The words.** The door: the parts that have something, "<n> to buy · <n> to prepare · <n> to charge"
   (`BeforeYouStart.words`). Home: "Before you start: <n> to buy, <n> to prepare" (`homeWords`) — To charge is left
   out on Home (charging is the day before's work, not weeks ahead); no line when both are none.
8. **Ticks.** A To prepare row's tick is the trip line's own (`setChecked`): the same line ticks on the trip's list
   and leaves Before you go's To do; it leaves the sheet. To buy rows have no tick: what is bought is ticked on To
   buy (which keeps Reminders in step), and a condition or a date is put right on the thing's page.
9. **What a row opens.** To buy: the thing's page (`ThingEditor`); a line typed on the trip only opens nothing (no
   arrow). To prepare: its arrow opens the template a reminder comes from (`TemplateDetail`, the first of
   `lineTemplates`) — or the thing behind a Preparations line; a To do written on the trip, or a reminder whose
   template is gone, has no arrow. To charge: nothing.
10. **Nothing new is stored.** Before you start only reads the trip, the things, To buy and the other trips.

### On the screens

- **The door** (`BeforeYouStartDoor`, id `trip-beforestart`, a button; label "Before you start", value = the
  door's words): first in the trip's scroll area (spec 03 item 0), top padding 10, sideways 16. A card (`Theme.card`,
  corner 12, a 1.2-pt border in the trip's green, as the On site door), at least `Metrics.row` tall (40 / 30):
  "Before you start" (Body semibold ink), the words (Footnote, muted, mono digits) and a drawn chevron — on one line
  when they fit (the Mac, most iPhones with one or two parts), else the words under the name (`ViewThatFits`).
- **The sheet** (`BeforeYouStartSheet`, id `beforestart-sheet`; Mac at least 520 × 560): "Before you start" (Title 3
  bold) and **Done** (filled green, Escape, `beforestart-done`); under it the trip's name and "before you start
  packing" (Subheadline muted, `beforestart-says`). Then each part with its heading — the part's name (Headline) and
  its count (Footnote semibold mono muted): `beforestart-part-buy` / `-prepare` / `-charge`, counts
  `beforestart-buy-count`, `beforestart-prepare-count`, `beforestart-charge-count`.
  - **To buy** rows `beforestart-buy-<n>` (a button, min `Metrics.tap`; label = the name, value = the reasons): the
    name (Callout semibold ink), under it the reasons joined by " · " — "On To buy", "Needs replacing", the date
    words, "Used up on <trip>" (Subheadline; red when one will stop him — Needs replacing, or a red date — else
    orange for a document short of six months or used up, else muted), the chevron when it opens a thing.
  - **To prepare** rows: the tick (`beforestart-prepare-<n>`, a button — a 22-pt ring in the trip's green, the name
    in Callout semibold ink, under it the When and its day in green, Subheadline; label "<name>, to prepare. Tick
    it"), the icons of the templates it comes from (`TemplateMarks`, `beforestart-prepare-<n>-from`) and the arrow
    (`beforestart-prepare-<n>-open`, label "Open <template>" / "Open <thing>").
  - **To charge**: the battery mark beside the heading; one quiet line per thing (`beforestart-charge-<n>`, Callout
    ink, "In the Camp pouch" muted), then "Tick them in Before you go as they are charged, from the day before the
    trip." (Footnote muted, `beforestart-charge-note`).
  - All parts empty while the sheet is open (the last one ticked): "Nothing left to buy or get ready." (`beforestart-none`).
- **Home's countdown** (spec 02 §11): after its To do line, "Before you start: 2 to buy, 3 to prepare"
  (Subheadline semibold ink). The card's accessibility value gains it: "1 to do · Before you start: 1 to buy, 2 to
  prepare" (parts with nothing left out).

### Tests

Model `BeforeYouStartTests` (5, `Core/Tests/PackingLibraryTests/BeforeYouStartTests.swift`; the batteries' library
of part 15 plus Sun cream on the base, a "Hut booking" thing in Preparations on Hiking, and Hiking's reminders a month
ahead ("Ask for leave"), a week ahead ("Check the forecast"), the day before ("Leave a route note") and on the morning
("Water the plants"); the trip 30 Oct – 1 Nov, today 14 Oct):
- `testItShowsUntilTheFirstThingIsPacked` — a reminder, a Preparations line, ⊘ and a charge tick leave it there; a
  thing ticked takes it away (and the parts go), unticked it is back; a Lighter ticked inside the Camp pouch takes it
  away; on the first day before "I leave at" 08:00 yes, at 08:00 no; a later day, after the trip, reviewed, bought on
  site, no such trip: no.
- `testToBuyGathersWhatIsOnToBuyWornOutAndRunningOut` — nothing at first; then the Passport (a document short of six
  months, orange), the Phone charger (a To buy line TYPED with its name), the Sun cream (runs out on the trip, red — a
  consumable, but that is not why), "Lighter, in the Camp pouch" (needs replacing, inside a kit), the Headlamp (a To
  buy line for it), the Map (needs replacing) — in the trip's order, each opening its own thing; NOT the Toothbrush (a
  consumable alone), the GPS watch (on To buy, but taken out of the pouch: not on the trip), "Coffee filters" (no thing,
  no line of that name), the Map's To buy line once ticked bought. Set aside, the pouch and the Map go (and the Lighter
  with its kit); a date moved on and a line ticked bought take theirs away; a line typed on the trip with a To buy
  line's name is its own row with nothing to open.
- `testUsedUpLastTimeIsToBuyUntilBoughtOrGoneAgain` — the Sun cream used up on "Summer hike" (1–3 Aug, reviewed):
  "used up on Summer hike", orange; on To buy "on To buy · used up …"; ticked bought today → gone; its `doneAt` before
  the summer hike → back; a September hike on which it went → gone; set aside on it → back; the summer hike's own list
  (a trip AFTER it does not count) clean; an undated trip looks back from today (14 Oct yes, 31 Jul no).
- `testToPrepareListsWhatFallsDueBeforeTheDayHeLeaves` — "Hut booking", "Ask for leave" (30 Sep), "Check the
  forecast" (23 Oct), "Leave a route note" (29 Oct), then the To do written on the trip "Name tag for the Day pack"
  (no day) — never "Water the plants"; the reminders open Hiking, the Preparations line its thing, the To do nothing;
  ticked or set aside, a line leaves; without dates, the same lines with no day.
- `testThePartsTheWordsAndHomesLine` — To charge = Toothbrush, Power bank, Headlamp; "1 to buy · 4 to prepare · 3 to
  charge"; Home "Before you start: 1 to buy, 4 to prepare" (`nextTrip(today:).beforeStart`); charged → leaves To
  charge; nothing to buy → the words leave it out; only To charge left → no Home line, the door still there; packing
  begun → nothing, on Home too.

Each seen RED with a planted fault: a reminder counted as packing ("XCTAssertFalse failed - a reminder, a Preparations
line, ⊘ or a charge counted as packing"); the kit contents left out of To buy ("("["Passport: document", "Phone
charger: on To buy", "Sun cream: runs out", "Headlamp: on To buy", …]") is not equal to …"); "bought since" ignored
("("["Sun cream"]") is not equal to ("[]") - bought since, still used up"); the FIRST earlier trip kept instead of the
last ("… - gone again since, still used up"); the morning's lead days 0 taken as ahead ("("["Hut booking", "Ask for
leave", "Check the forecast", "Leave a route note", "Water the plants", …]") is not equal to …"); charged things kept
on To charge ("("["Toothbrush", "Power bank", "Headlamp"]") is not equal to ("["Power bank", "Headlamp"]")"). Parity:
211/211 (nothing in the web model changed).

UI `testBeforeYouStartGathersWhatToBuyAndGetReadyUntilPackingBegins` (`-uiTestingBeforeStart`,
`SampleLibrary.beforeStart()`: the sample + Sun cream on the base running out on the trip's last day and used up on a
reviewed "Summer hike" two months ago, the Map needing replacing (the sample's own), the Headlamp with a battery,
Hiking's reminders a week ahead, the day before and on the morning; the trip ten days ahead, nothing ticked): Home's
`home-countdown` value "Before you start: 2 to buy, 2 to prepare"; the trip's `trip-beforestart` "2 to buy · 2 to
prepare · 1 to charge", above `trip-beforego`; the sheet's three parts; `beforestart-buy-0` "Sun cream" (runs out
before he is home · used up on "Summer hike"), `-1` "Map" ("Needs replacing"), no third; `beforestart-prepare-0` "Check
the forecast" ("≥1 week ahead · from …", its icon Hiking), `-1` "Leave a route note", no third (not the plants);
`beforestart-charge-0` "Headlamp"; the forecast ticked → `beforestart-prepare-count` "1"; the Map's row opens
`thing-detail`, the route note's arrow `template-detail`; Done → the door "2 to buy · 1 to prepare · 1 to charge"; the
Passport (`trip-line-0`) ticked → the door goes; unticked → back. Pictures `beforestart-home`, `-trip`, `-sheet`,
`-packing`, iPhone day and night. Seen RED with a planted fault: the door not ending with packing → "the door stayed
once packing began"; the sheet's tick ticking nothing → "the forecast ticked is still to prepare: '2'".
`testATripsRemindersShowWhenTheyAreDue` now reads the countdown's value from its start ("1 to do", then Before you
start's line). On GitHub's Mac (a probe running just this test, `testATripsRemindersShowWhenTheyAreDue`,
`testBeforeYouGoIsOneCardWithItsPartsInOrder`, `testATripChecksTheCabinAndTheDatesBeforeYouGo` and
`testHomeCountsDownToTheNextTrip`): all five green; there the door's words fit beside its name on one line (pictures
of the Mac look, day).

### Open questions

- "Used up" is cleared by a To buy line ticked bought, or by the thing going on a trip again; a thing bought without
  the app keeps saying "Used up on …" until then. A "Bought it" press on the row would clear it on the spot — worth it?
- A reminder on the day he leaves (lead days 0) is not in Before you start; if he keeps last-day reminders that need
  preparing (a taxi to book), move them to the day before — or say so and they come in.
## 20. Progress you can see — green groups and what's left

> His words (14 Oct 2026), from his own packing walk-through: "once a WET, GA, Template is finished I would like to
> enjoy a green checkbox or green colour somewhere showing me a good progress — but also indicating how much is
> left. Both in items, charging, actual packing time etc." He said yes the same day to the two parts below. Written
> BEFORE the build (his rule: the spec first) and then checked against the code of branch `work/progress082` (0.82):
> the model `Core/Sources/PackingLibrary/PackingPace.swift` (the tick's moment, his pace, the words) and
> `Library.setChecked` / `setKitContentTicked` / `undo` (the moment written and taken away); the screen
> `App/Sources/Screens/TripScreen.swift` (`GroupProgressMark`, `WhatsLeftLine`). Per screen: spec 03 (the trip
> header and the heading row), spec 01 §1.12 (the key).

### What he gets

1. **A green ring per group.** On the trip's list every group heading — whatever the Sorting: When, Into, From
   where, Category, Section, Template — has a small ring just left of its count ("◔ 3/12"). It fills green as the
   group's lines are ticked. When the last one is ticked the ring becomes a small **filled green check**, the
   heading's words and count turn the trip's green and a soft green band lies behind the heading — with a short
   "done" moment: the check springs in, a touch larger, and settles (with Reduce Motion: a plain fade). A folded
   group shows the same.
2. **What's left, in one line**, under the trip's count while the trip is being packed: **"23 left · 2 to charge ·
   about 25 min"** — the things not ticked yet, the things not charged yet (only while the To charge card would show)
   and roughly how long the rest takes at HIS pace, measured from his own ticks. Everything packed: a calm green
   **"All packed"** instead (with " · 2 to charge" while something is still to charge).

### The rules — the green groups (decided 14 Oct 2026, by the build)

1. **The heading's own count.** A group's ring reads exactly the heading's "ticked/packable": the group's lines not
   set aside, how many of them are ticked. Its reminders (To do lines, spec 07 part 12) count as lines, as they do
   today — so a group is done only when they are ticked too. Under Template a line on two templates counts in both
   groups (it stands under both). The ring and the count never disagree.
2. **Only where there is something to pack.** A group whose every line is set aside has no ring (its count says
   "0/0"; it has no round tick either). An empty group is not drawn at all (as before).
3. **The ring** (`GroupProgressMark`, not a button): `GroupProgressMark.size` across — 14 pt on the iPhone, 11 on the
   Mac — 8 pt after the heading's words and 5 pt before the count; a track in the hairline colour (`Theme.line`, 2 pt; 1.6 on the Mac) and over it the green arc
   (`AppSection.events.color`, the trip's green), from the top, clockwise, as long as ticked ÷ packable, round ends.
   Nothing ticked: the track alone.
4. **Done** = every line of the group not set aside is ticked (and there is at least one). Then:
   - the ring is replaced by a **filled green circle with a white tick** (the app's drawn tick, as a line's), the same
     size as the ring;
   - the heading's words and its count are the trip's green made readable (`GroupProgressMark.words`:
     `readableHex("#2f9e63")` — #227147 by day, 5.4 : 1 where the green itself gives 3.4 and was hard to read on
     the all-packed screen; #2f9e63 at night), the count semibold as before — under When the heading's own "When"
     colour gives way to the green while the group is done, and comes back when a line is unticked;
   - a **soft green band** lies behind the heading row: the trip's green at 10 % by day, 18 % at night, corner 8,
     reaching 6 pt past the row on each side (so the fold arrow and the round tick sit inside it).
5. **The done moment.** Only when a group BECOMES done while he looks (a tick, the heading's round tick, Pack by
   voice, the other device): the check comes in with a spring (from 30 % of its size and transparent; response
   0.35 s, damping 0.55 — it overshoots a little and settles) and the words' colour and the band ease in over
   0.3 s. With **Reduce Motion**: no scale — the check and the band fade in over 0.2 s. A group already done when
   the trip opens is simply shown done. Unticking a line takes the check away the same way, back to the ring.
6. **Not the round tick.** The heading's round tick (`trip-group-<g>-all`) stays where it is, at the RIGHT end of
   the heading above the lines' ⊘, at `Metrics.mark` (18 / 14), a button that ticks or unticks the whole group, with
   Undo. The progress mark is at the LEFT, right beside the count it belongs to, smaller (14 / 11), and only shows —
   it takes no press and is not a button for VoiceOver. When a group is done both show a filled green circle, at
   opposite ends and in two sizes: one says "done", the other "untick them all".
7. **Accessibility.** The mark is ONE element, id `trip-group-<g>-progress`, its LABEL "<ticked> of <packable>
   packed" or "all packed" when done (what VoiceOver says and the tests read). Not a value: a value on such an
   element never reached the Mac's tests (GitHub's Mac probe, 14 Oct 2026: "the Bathroom cabinet's ring says ''"
   while the iPhone read it). The heading's count stays a plain text.
8. **On a grab list too (0.87).** The same mark beside each of HIS headings in an open grab list (spec 02 §6, "Done
   headings fold"), its `word` "in hand" there — "<in hand> of <to take> in hand" / "all in hand", id
   `grab-group-<g>-progress` (the mark's `word` defaults to "packed", so a trip's words are unchanged). There a done
   heading also FOLDS its things away — a trip's group folds only by its arrow, as before.

### The rules — what's left (decided 14 Oct 2026, by the build)

8. **When it shows.** While the trip is at **Pack** (`loopStep` on the trip screen's clock — the same reading as the
   loop strip and Take a break) and has at least one line not set aside. Never at Plan (no lines), On site, Review or
   Refine. Opened from a place's code it still counts the WHOLE trip (as the count above it does).
9. **Left** = the header's `progress(trip.entries)`: total − done — every line not set aside and not ticked, its
   reminders too. "1 left", "23 left".
10. **To charge** = the To charge card's rows not charged (`chargeCard(tripId:today:)` — from the day before the trip
    through its last day, kit contents included, spec 07 part 15); no card today, or all charged: no part. "1 to
    charge", "2 to charge".
11. **Time** = left × his pace (below), in words (`Library.aboutWords`):
    - under 60 seconds: "less than a minute";
    - under 10 minutes: to the minute — "about 4 min" (9 min 30 s and over rounds to "about 10 min");
    - from 10 minutes: to the nearest 5 — "about 25 min" (12 min 29 s → 10, 12 min 30 s → 15);
    - from an hour: "about 1 h 25 min", "about 2 h".
    Always "about": it is an estimate, measured or not.
12. **The line** (`WhatsLeftLine`, id `trip-left`, a plain text — its label on the iPhone, its value on the Mac): the parts joined by " · "
    — "23 left · 2 to charge · about 25 min" — Footnote, digits monospaced, muted; it sits under the count, 1 pt
    away, in the count's column, and Take a break (when shown) stays at the right, centred on the two lines.
    **All packed** (nothing left, at least one line not set aside): "All packed" in Footnote semibold, in the done
    heading's readable green (#227147 by day, #2f9e63 at night), then
    " · 2 to charge" while the To charge card shows something not charged. The line never shows "0 left".

### His pace — the estimate rule (`Library.packingPace()`)

13. **A tick keeps its moment.** Every tick on a trip's line writes the line's extra key **`tickedAt`**
    (`TICKED_AT_KEY`) = the moment, whole seconds since 1 January 1970 (UTC, a number; this device's clock,
    `PackingEnv.now`) — one number on the line's own record, synced with the tick. Written by `setChecked(true)`
    (a tap, the heading's round tick — all its lines get the same moment —, Pack by voice, a reminder ticked in
    Before you go) and by a kit that becomes packed through what is ticked inside it (`setKitContentTicked`) — only
    when the line TURNS ticked: a line already ticked keeps its first moment.
    **Taken away** by an untick (`setChecked(false)`, a kit no longer complete). **Undo** writes back the moment the
    line had before the press (`TicksChanged.Before.tickedAt`). NOT written by Bought on site (in hand, not packed),
    the review, or a rebuild (a rebuilt line keeps all its marks, `followThing`); **dropped** by "Start a new trip
    from this one" and in a shared trip (his pace is his). A line set aside keeps whatever it had, unread. The web
    app's model sees a key it does not know (parity unchanged).
14. **Timed ticks.** Per trip, the moments of its lines that are ticked, not set aside and carry a valid moment
    (a number > 0) are put in order; lines with the SAME moment (one press of a heading's tick) are one step of k
    lines. The time from the step before to this one is the gap: a gap of **10 minutes or less**
    (`PACE_BREAK_SECONDS` = 600) gives each of the k lines **gap ÷ k** seconds — k timed ticks; a longer gap is a
    **break** and its lines are not timed; the first step of a trip has no step before it and is not timed. Ticks of
    different trips are never compared with each other.
15. **Recent, across trips.** The newest **200** timed ticks of all trips (`PACE_RECENT_TICKS`, by their moment —
    about his last three packings) are kept, and his pace is their **median** (an even number: the mean of the two
    middle ones).
16. **Before there is enough.** Fewer than **20** timed ticks (`PACE_MIN_TICKS`): **45 seconds per thing**
    (`PACE_DEFAULT_SECONDS`), and the line still says "about". `PackingPace.measured` says which it is (the screen
    does not show it).
17. Read on the screen whenever the trip changes (no timer): the pace is the library's, so a tick on the other
    device counts as soon as it arrives.

### Where it is kept (the web model sees nothing new)

| Holder | Key | Value | Meaning |
|---|---|---|---|
| trip line (0.82) | `tickedAt` (`TICKED_AT_KEY`) | number, whole seconds since 1970 (UTC) / absent | when it was ticked (rule 13); removed by an untick; dropped by Start again and in a shared trip |

Nothing else is stored: the rings and the line are read from the trip each time; the pace from the trips' moments.

### Tests

Model `PackingPaceTests` (10): `testATickKeepsItsMomentAndAnUntickTakesIt` (whole seconds; ticked again keeps the
first; Bought on site has none), `testAHeadingsTickGivesItsLinesOneMomentAndUndoPutsBackWhatWasThere`,
`testAKitGetsItsMomentWhenTheLastThingInsideIsTicked`, `testTheGapsBetweenHisTicksAreHisPaceAndALongOneIsABreak`,
`testOnePressOfManyLinesSharesItsGap`, `testBeforeTwentyTimedTicksItIs45SecondsAndTripsAreNeverComparedWithEachOther`,
`testHisPaceIsTheMedianOfTheNewest200TimedTicks`, `testTheTimeIsSaidRoundedToTheMinuteThenToFive` (every band:
59 s, 60 s, 4:29, 9:29, 9:30, 12:29, 12:30, 25 min, 57:29, 57:30, 85 min, 120 min),
`testWhatIsLeftSaysTheThingsTheChargingAndTheTime`, `testTheMomentIsStoredBackedUpAndKeptByARebuildButNeverSentOrStartedAgain`
(records, both kinds of backup file, the web model's `Item(json:)`, a rebuild and a change to the thing keep it;
`justTheList` and Start again drop it). `PocketsTests.testAnAbsentPocketChangesNothing` now expects the moment beside
the tick (and still no pocket). Each seen RED with its own planted fault: no moment on a tick ("Undo did not put back
the first moment", 26 failures); an untick keeping it ("an untick takes the moment away"); Undo ignoring it ("Undo
left the moment of a tick it took back"); a kit given none ("the kit packed by its last thing has no moment"); no
breaks ("25 gaps, one of them a break"); a press not shared ("290 s for 29 things is 10 s each"); every tick instead
of the newest 200 ("not the newest 200": 40 for 20); two trips' ticks compared ("two trips' ticks were compared");
always to 5 minutes ("about 0 min" for 60 s); charged things counted ("5 left · 3 to charge"); Start again and a
shared trip keeping it ("a trip started again carries the old moments", "a shared trip carries his tick moments").

UI (iPhone, the own simulator; both also in the Mac probe): `testAGroupTurnsGreenWhenItsLinesArePacked` (sorted From
where: the Bathroom cabinet's `trip-group-0-progress` "0 of 1 packed", the Garage's "0 of 2 packed"; the ring at
least 40 pt left of the round tick `trip-group-2-all`, smaller than it, and no button; the Toothbrush ticked → "all
packed"; the Headlamp → "1 of 2 packed"; folded, still "1 of 2 packed"; the Toothbrush unticked → "0 of 1 packed";
picture `trip-group-progress`) and `testTheTripSaysWhatIsLeft` (the sample at Pack: `trip-left` "7 left · about 5
min" under the count and in its column, after a tick "6 left · about 5 min", every line ticked "All packed";
`-uiTestingBattery`: "<n> left · 2 to charge · about …"; pictures `trip-whats-left`, `trip-whats-left-all-packed`,
`trip-whats-left-charge`). Seen RED with planted faults in the screen: a done group never done ("a group with every
line ticked is not done: '1 of 1 packed'"); the ring hidden while folded ("folded, the Garage's ring says ''");
"All packed" not said ("everything ticked, the trip says ''"); the line beside the count instead of under it ("what's
left is not under the count"). Green again without them, day and night.

### Open questions

- The pace is one number for every kind of trip; a quick weekend may be packed faster than a big trip with kits. If
  the estimate feels off, a pace per template is the next step.
- A tick made on the other device while this one is offline arrives later with its own moment; the gap is still
  measured on the moments, so the order of arrival does not matter.
- The moment is this device's clock: a Mac and an iPhone a minute apart ticking the same trip in turns would make
  small gaps look larger or smaller; the median keeps such outliers out.

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
| 13 Oct 2026 | "Tick everything" leaves the trip screen (no button, no shortcut — the Mac had none; the model keeps `setAllChecked`); "Clear every tick" moves into Trip settings as a quiet row, last, only while something is ticked, still asking first — and Clear the ticks closes Trip settings without its other unsaved changes, as Start it does, which the question then says; a heading's round tick (a whole group ticked or unticked) and Clear every tick are offered back as **Undo** for 6 seconds, between the list and the add bar, one at a time, putting back exactly the ticks that press changed (a line changed since stays as he left it). Undo for Clear decided by the build: cheap, and the same bar. Pack to go home's own Tick everything / Clear the ticks (which, pressed again, cleared every home tick without asking) goes too, by the same reasoning; its bag headings have no round tick, so no Undo there (0.79) | "Two very risky buttons — in a stressful situation half way packed, pressed by mistake: catastrophe." Spec 03 "The heading's tick, its Undo, and Clear every tick". |
| 13 Oct 2026 | The activity-area headings are not in capitals: "GA · Goal Activity", "WET · Workout, Exercise & Training", "OE · Other Events", "Other Templates", "Always Packed", "By Transport" — his code stays in capitals; Create new trip, Trip settings and the Templates tab say them so (0.78) | "GA · Goal Activity — not all caps", "WET · Workout, Exercise & Training — not all caps", "Other Templates — not all caps" (his notes on the iPhone screenshots) |
| 13 Oct 2026 | A short trip's template has an icon of its own, the weekend bag (`weekendbag`), suggested by "short", "weekend", "small core", "kort", "helg"; he picks his own template's icon himself (0.78) | "a nice unique icon — not the same as Travel" |
| 13 Oct 2026 | Food's third answer reads "Mix" (stored `mixed` unchanged), so the three fit on one line (0.78) | "Self-sufficient, Eating out & Mix — keep short so that it all fits on one line." |
| 13 Oct 2026 | The Season pills carry the sun and the snowflake, as Travelling by carries its drawings — on Create new trip, Trip settings and Only on some trips; the More choices line stays words (0.78) | "same idea as Travelling by" |
| 13 Oct 2026 | The Quick line names his always-packed templates and says the airport checks plainly: "Quick packs only what you tick — not <names>, no Plane or RV template. Plane still turns on the airport checks." (0.78) | He did not understand "Plane and RV still count", and "Always" alone is cryptic — he thinks of his short-trip template by its name |
| 13 Oct 2026 | A guided Packing day inside the Pack step: a row of stations — Bags out, Pack, Weigh, Tags, Photos, Ready — each green when done, a tap opens it, the next open one offered; Weigh opens by itself once when the last thing is ticked; Has an AirTag on the bag; one photo of all the bags per trip; Ready pairs with "I leave at". Marks: his picks of the station sheet (day B, Bags out A, Pack C, Weigh A, Tags A, Photos C, Ready A) | His own packing walk-through (bags out on the floor for a week, pack, weigh, name tags and AirTags, photos for lost luggage, ready). Part 17. |
| 13 Oct 2026 | Lost luggage, part A: each bag's details for the airline's baggage desk — brand, colour (with pills), type (the desk's categories in plain words), size (Cabin, Medium, Large and a note) and distinctive marks — said once on the bag's page and reused by every trip; brand and colour are the thing's own Brand and Colour, never a second copy; and up to two photos of the bag itself (the thing's own photos), shown small beside the bag on a trip until it has a photo of it packed (0.80) | His yes to the lost-luggage information (0.80); the photos his ask of 14 Oct 2026. Part 18 A. |
| 14 Oct 2026 | (1) "Packing day" is renamed **Packing Stations** wherever he reads it — row, sheet, How it works, Words, a bag's page; ids, keys and 0.79's What's new unchanged | His decision on 0.79's screenshots of a Mac trip. Part 17, "0.81". |
| 14 Oct 2026 | (2) Slimmer pills — ONLY the station chips: 22 pt on the iPhone, 18 on the Mac (28 / 22 before), mark and words the same size, so the drawn icons pop; the step pills and other pills unchanged | His decision, the same screenshots. Part 17, "0.81" item 2. |
| 14 Oct 2026 | (3) Tags: "Remind me" per bag adds a To do to the trip ("Name tag for …" / "AirTag for …", prefilled, editable), shown in Before you go; a happier look — a soft green left edge, the bag's drawing by its name, the tag and AirTag drawings on the ticks, a done bag light green with a ✓, day and night | His decision. A To do written on the trip is due at once and says "Added on the trip" (decided by the build: a step not yet come would hide it from Before you go). Part 17, "0.81" item 3. |
| 14 Oct 2026 | (4) Ready: "Add a reminder" — anything last-minute, as a To do on the trip (Before you go) | His decision. Part 17, "0.81" item 4. |
| 14 Oct 2026 | (5) Trip header, variant A: Review in the Templates / Refine violet, Take a break ("Back at 18:00") in a warm coffee amber, Done stays green; only these three; outlined / filled as before; contrast checked day and night | His pick of variant A. Words colours chosen by the build so each reads ≥ 4.5 : 1 on its own fill (`TripHeaderTone`). Part 17, "0.81" item 5. |
| 14 Oct 2026 | (7) Bags out: "+ Add a bag" — one of his bags not on the trip, or a new one (name, cabin yes/no, max weight optional), added to the trip's bags so Weigh, Tags and Photos include it; things go into it by their Usually packed in (a one-line hint) | His decision. How a bag is on the trip without lines decided by the build: the trip's `dayAddedBags` list, the bags its lines pack into first, then the added ones. Part 17, "0.81" item 7. |
| 14 Oct 2026 | The trip's Bags card, opened, gets Bags out's "+ Add a bag" at its foot (same panel, rules and words; an empty bag added says "nothing in it yet" and has its ✕ there too); "On body" has no Lost bag? anywhere; Lost bag? becomes a quiet green text link without an outline (0.83) | His report on a screenshot of a trip's opened Bags card (Mac, night): he looked for "+ Add a bag" there; every row incl. "On body" had a "Lost bag?"; a column of green outlines. "On me", "Worn" and "Wearing" with "On body", the ids under `bags-addbag`, and no Add a bag on a reviewed trip decided by the build. Spec 03; part 17 item 7; part 18 C rule 3. |
| 14 Oct 2026 | On a plane trip, Create new trip and Trip settings keep the flights (Out and Home, connections between), the destination and where he stays until when, in a framed block "Flights and stay" under Travelling by, optional; each bag's tag number from check-in at the Packing day's Tags and on the Bags card. Plane off keeps it unseen; Start again takes none of it; a shared trip keeps flights and stay but not the tag numbers (decided by the build) | His yes of 13 Oct 2026 to the lost-luggage information (0.80). Part 18 B. |
| 14 Oct 2026 | **Before you start**: on a trip at Plan, or at Pack until the first thing is packed (a reminder, a trip To do, a Preparations line, ⊘ and a charge tick are not packing), ONE door first in the scroll area to a sheet with To buy (on To buy, needs replacing, Before you go's date rule, used up the last time it went and not bought since), To prepare (reminders and Preparations lines due before the day he leaves — lead days 1 or more — with their When and day; the To dos written on the trip) and To charge (names only; ticked in Before you go); each part only when it has something; and "Before you start: 2 to buy, 3 to prepare" on Home's countdown. A door with a sheet rather than a card, the end at the first tick, a consumable alone not listed, and To charge left off Home — decided by the build | "Think if there is anything I need to buy or prepare well in advance." His yes (0.82). Part 19. |
| 13 Oct 2026 | Lost luggage, part C: a Lost bag page per bag of a trip — his details (name, phone, e-mail, home address, kept once for the library in Settings), the trip's flights, stay and the bag-tag number, the bag's details, AirTag, photos and a few things in it; "not filled in" opens what fills it; Share as PDF and Copy as text; reached from the Bags card and the Packing day's Photos and Ready. The bag-tag number is typed on the page itself; a trip by car or train still has a page (decided by the build) | His yes to the lost-luggage information (A bag details, B flights and stay, C the page). Part 18 C. |
| 14 Oct 2026 | Each group heading of a trip gets a small ring beside its count that fills green as its lines are ticked; done, a filled green check, the heading green on a soft green band, a short spring (a fade with Reduce Motion); the heading's round tick stays at the right, unchanged. Under the trip's count, while it is at Pack: "23 left · 2 to charge · about 25 min" — the time from HIS pace (the median seconds per tick of his newest 200 timed ticks across trips, gaps over 10 minutes ignored as breaks; 45 s per thing until 20 are timed), rounded to 5 min (to the minute under 10); "All packed" when nothing is left | "Once a WET, GA, Template is finished I would like to enjoy a green checkbox or green colour somewhere showing me a good progress — but also indicating how much is left. Both in items, charging, actual packing time etc." Part 20. |
| 15 Oct 2026 | (2) Take a break becomes a round icon-only button — the drawn cup, amber, the size of the trip's pen — and, while a break waits, a compact capsule with the cup and the time small ("19:00"; "Fri 18:00" on another day); label "Take a break", the full "Back at 19:00" as its value | His ask, from his screenshots of a Mac trip at Pack: "Take a break → icon only", "the time small". The weekday for another day decided by the build (compact). Part 16, "0.84" item 2. |
| 15 Oct 2026 | (3) Add to Calendar pops once a time is chosen: FILLED in the break's amber (#a8651a day and night, white words, 4.6 : 1) while In an hour / This evening / Tomorrow shows as chosen; outlined in the amber otherwise (a break from before that is none of the choices) | His ask: "Add to Calendar pops once a time is chosen". Amber for both looks (it was the sheet's green) decided by the build. Part 16, "0.84" item 3. |
| 15 Oct 2026 | (4) The break's reminder and its calendar entry start with the backpack: "🎒 Back to packing <trip>" — the only emoji in the app | His explicit ask: the reminder's text starts with 🎒. Part 16, "0.84" item 4. |
| 15 Oct 2026 | (5) Shorter station chips: Bags, Pack (no count — the header shows it), Weigh, Tag, Photo, Ready; the row's title "Stations". The long names stay where there is room: the sheet's heading "Packing Stations", "Next: Bags out", Ready's list, How it works' numbered stations, the Words term | His ask: "Bags out → Bags, Pack 13/289 → Pack, Tags → Tag, Photos → Photo", "Packing Stations → Stations". Where the long name stays decided by the build. Part 17, "0.84". |
| 15 Oct 2026 | The trip header's Review only once the trip has started — On site or later (on the first day from the time he leaves); never at Plan or Pack; a trip with no start date keeps it at any time; the loop strip's Review step unchanged | His words on the Review button beside Done at Pack: "is that really necessary?" — then his yes to "only once the trip has started". The undated trip decided by the build (else it could never be reviewed). Part 17, "0.84"; spec 03. |
| 15 Oct 2026 | **REPLACED in 0.85 (the row of his own headings, below).** An open grab list falls under small grey headings, one per **Kind of thing** of its things (a name matched to his thing by its plain name), in HIS order of kinds, then a kind no longer on his list, "Other" last (names that are none of his things, no kind, or a kind he called Other); the list's own order within each; only when its things are of two kinds or more ("Other" does not count), else flat as before; the heading Footnote semibold grey, a hair of letter-spacing, not in capitals, no tick and no count; the editor stays flat; the count, ticks, skips and Ready to go unchanged. No count on a heading, the editor flat and "Other" always last decided by the build (0.84) | On a picture of "Outdoor bike" open on the Mac, "0 of 17 in hand" in one flat run: "a bit more visual with some grouping … only for visuals but important to me" — "small headings in the list … maybe another colour, grey or something like that". Spec 02 §6. |
| 15 Oct 2026 | A grab list's Share leaves its header (Edit and Done stay) for the bottom right, on the line of the words under Ready to go: a quiet ROUND button, the share mark in the list's colour on its 10 % fill with a ring, 38 across on the iPhone, 30 on the Mac, never grey; same id, same sheet (0.84) | Same picture: "Please move the share button down to the bottom right. I almost never use it. Now that we are on it, can we make the share button more rounded?" Spec 02 §6 item 6. |
| 15 Oct 2026 | **A grab list's headings are HIS (0.85), replacing 0.84's grouping by Kind of thing.** In Edit: "A new heading" + Add (a template's "A new section") puts a heading LAST; its grip ≡ (on the Mac ▲▼ too) moves it alone, like a line; a thing belongs to the heading above it, so he groups things by moving them under a heading; tap a heading's name to change it; ✕ removes it, asking nothing — its things stay and join what is above. A heading row is clearly not a thing's: Headline in the list's colour on no box, a heading's grip, no "1 in 10". The open list shows his headings with 0.84's small grey look (Footnote semibold, muted, letter-spaced; `grab-group-<g>`); things above the first heading stand under none; a heading with nothing under it is not shown; a list without headings is flat as before. Headings are never ticked, skipped or counted (`GrabDefinition.items` = the things alone; a list changes through `lines`). STORED among the list's own names in a reserved form — U+2063, "##", a space, the name — because a field of its own survives the store but not the next save (`grabToRows` writes `GrabList`'s five fields) nor the backup (built field by field); the names already travel through store, iCloud, backup, restore and share links, and no keyboard types U+2063, so his "- " and "❄️" names stay things. Share sends headings as their own lines; this app reads them back as headings. GrabKinds, `-uiTestingGrabKinds` and their tests are gone. Spec 02 §5–7, §10 | His question before 0.84 shipped: "How do I define the small headings, and how do I group the items in the various headings? I need to be able to do that, I believe." His verdict on 0.84: "I think you have misunderstood the grab list, and you have made the sections wrong." His lists are free text ("Start fans", "Open windows"), and he already made groups by hand with prefixes in the names. Tests seen RED with planted faults first: model `GrabHeadingsTests` (12) on seven faults, e.g. "XCTAssertEqual failed: (\"7\") is not equal to (\"11\") - the link's lines: 7 things and 4 headings"; UI `testHisOwnHeadingGroupsAGrabList` and `testAGrabListOpensUnderHisHeadings` on six, e.g. "XCTAssertTrue failed - the heading was counted: '0 of 8 in hand'", "XCTAssertTrue failed - its thing went with it" (spec 02 §6 lists them all). |
| 15 Oct 2026 | **"Heading above" (0.85):** in a grab list's Edit, each THING's name has a context menu — held on the iPhone, right-clicked on the Mac — with one entry, "Heading above", which puts a heading with no name right above that thing, the keyboard on it; a heading left unnamed is dropped on Save (nothing he can see changed, so nothing asks). On the iPhone the menu is on the name only, not the whole row: holding the grip still drags. On the Mac a right-click on a text field is the field's own (Cut, Copy, Paste), so a view behind the name catches the right-click first (`RightClickMenu`, a local event monitor; a layer over the field made it "not hittable"), and the rest of the row has the same menu. The foot's "A new heading" stays; the hint adds "Hold a thing (right-click on the Mac) for a heading above it." Spec 02 §7 | Asked before 0.85 shipped: a new heading always went last, a long drag on his 17-thing lists. Test `testAHeadingGoesAboveTheThingHeHolds`, seen RED with planted faults first ("XCTAssertTrue failed - no heading above the thing held", "XCTAssertTrue failed - the new heading does not have the keyboard", "XCTAssertTrue failed - holding a thing offers no Heading above", "XCTAssertEqual failed: (\"Heading\") is not equal to (\"In the bag\") - the unnamed heading was kept, or the named one lost"). |
| 15 Oct 2026 | **No tags inside another bag (0.86):** Packing Stations' Tags lists only the bags that travel by themselves. A bag is inside another when its OWN line on the trip (its thing's line, by id or name; not set aside, not a reminder) is packed in another of the trip's bags; the thing's Usually packed in alone is not read (every new thing starts in the carry-on, so the Day pack — and a suitcase — would drop out). Its AirTag is not asked either (found with the bag it is in); Has an AirTag stays its own. One quiet line under the cards: "No tags inside another bag: Toiletry bag (in the Carry-on / hand luggage)." Taken out (No bag) it is asked again. Bags out, Weigh, Photos, the Bags card and the Lost bag pages unchanged. The rule (the trip's line only), the AirTag, the line's words, rings and nesting decided by the build | His words: "Yes - no tags inside another bag" — his answer to the idea that a bag packed inside another (a toiletry bag or a packing cube in the suitcase) never goes through the airport on its own, so it needs no name tag. Part 17, "0.86". |
| 15 Oct 2026 | The Mobility kind is called **"Mobility & breath"** (was "Mobility & breath work") on the review's rows and in Counts as | His words: "Adjust: “Mobility & Breath work” to “Mobility & Breath”". His template was renamed the same day in his app; a template's Counts as is stored as the kind (`mobility`), not its label, and "Mobility & Breath" already meets the kind by its name, so nothing of his changes. |
| 15 Oct 2026 | The things table gets a **Battery** column (0.86): the drawn battery mark when a thing has a battery, an empty cell when not; a tap changes it; it sorts, filters and takes Change all like Liquid, and Undo puts it back both ways. Only "Has a battery" is shown — the model knows nothing more about a battery, and how a thing charges stays the web app's Charges column. Placed before Charges among the thing's own columns; a starting column; put once among the columns he had already chosen (hidden afterwards, it stays hidden) | His words: "Battery column: yes". Part 15; spec 05, Table columns, "Battery". Tests seen RED with planted faults first: UI `testTheTableShowsWhichThingsHaveABattery` ("XCTAssertTrue failed - the Power bank's row shows no battery: 'no'"; "XCTAssertTrue failed - the Battery column did not arrive among his columns"), model `BatteriesTests.testTheTableFiltersSortsAndChangesAllByBattery` ("XCTAssertEqual failed: ("0") is not equal to ("1") - Undo of Battery: no put nothing back"). |
| 15 Oct 2026 | **Grab lists by holding the app icon (0.86).** On the iPhone, holding the Packing icon on the Home Screen shows up to four grab lists; tapping one opens the app straight on that list, ready to tick (the path Siri's "Open a grab list" takes), from a cold start or while it runs. Which four — the four opened most recently on that iPhone, shown in his Home order so an entry keeps its place, the first ones on Home filling in until four have been opened — decided by the build, as was the record of openings being the device's own. Each entry wears its list's drawing (the doodle, or the initial of a list of his own) as a template picture from the app's own asset catalog, never an SF Symbol; on the Mac, the Dock icon's menu lists every grab list in Home's order (no pictures) and opens one, with a window if none is open | His yes of 15 Oct 2026: "Yes - grab lists by holding the app icon", to the idea put as "hold the AMS Packing icon on your iPhone and tap Outdoor bike or Indoor swim — straight into that list without opening the app first." Spec 02 §13b. Tests seen RED with planted faults first: model `GrabQuickActionsTests` (7) on five faults, e.g. "XCTAssertEqual failed: (\"[\"run-out\", \"bike-out\", \"swim\", \"run\"]\") is not equal to (\"[\"swim\", \"run\", \"bike-out\", \"run-out\"]\") - not the four opened most recently, or not in Home's order"; UI `testAnEntryUnderTheAppIconOpensItsGrabList` on four, e.g. "XCTAssertTrue failed - Outdoor bike, opened just before, is not under the icon — or its entry opened nothing while the app ran" (no scene delegate), "XCTAssertTrue failed - the entry under the icon opened nothing at a cold start"; UI `testTheDockMenuOpensAGrabList` (Mac) on two, "XCTAssertTrue failed - with no window open, choosing in the Dock menu brought no window with the list" and "XCTAssertTrue failed - the Dock menu opened another list: 'Indoor swim'". |
| 15 Oct 2026 | **Charge tonight (0.87):** at 20:00 the evening before a trip's first day, the iPhone says "Charge tonight" with the names of the things on To charge not charged yet (To charge's order; four, then "and N more"); none when nothing is left to charge, the trip is undated, reviewed or without lines, or the evening has passed; a charge tick takes a name off at the next change; a tap opens the trip at To charge. 20:00 (not 19:00, the break's This evening), the iPhone's "Messages when a trip moves on" switch holding it, and its place among the six soonest messages decided by the build | His yes to the idea put to him: "Charge-tonight reminder: the evening before you leave, your iPhone says what still needs charging — 'Charge tonight: Garmin, power pack, bike computer' — only if something is left to charge." Part 16, "0.87". |
| 15 Oct 2026 | **Done headings turn green and fold (0.87):** in an open grab list, each heading of his gets the trip's small ring (`GroupProgressMark`, "x of y in hand"), filling as its things are ticked; once every thing under it is in hand — a skipped ⊘ thing counts as done; a heading of skips alone is NOT done (nothing in hand; it stays open so a skip can be taken back) — the heading turns green with the check on the trip's soft green band and its things fold to that one line, 0.4 s after the tap, in 0.3 s (Reduce Motion: a 0.2 s fade, no movement). A tap on a done heading opens it (or folds it again); a heading not done ignores taps, so nothing still to take is ever hidden; opened by hand it stays open while done, and folds again the next time everything under it is in hand. The things above his first heading never fold; a list without headings is unchanged; the count, Still missing, Start over (opens all) and Ready to go unchanged. Nothing stored: the folds follow the ticks, this device's own | His yes, 15 Oct 2026, to: "Done headings turn green and fold: in a grab list, when everything under a heading is in hand, it turns green and folds to one line, like the groups on a trip. You scroll less at the door." Skips as done, skips alone not done, the delay and the tap rules decided by the build. Spec 02 §6, "Done headings fold". |
| 18 Oct 2026 | A note a template keeps for a thing reads **"Note on <template>: …"** under a thing found by its notes (Your things, Search), his own Notes **"Note: …"**, and the thing's page **"Note on the <template> template: …"** (0.88) | His field report: "Travel: work" under four things (the web app's line notes on Travel) — "I don't understand why the “: work” is there. Where does it come from?", then "make the line clearer". Red first: ("On the Swim template: Rinse after the sea") is not equal to ("Note on the Swim template: Rinse after the sea"). |
| 19 Oct 2026 | **Search in How it works (0.90):** a search field at its top (the app's search-field look and ✕; on the Mac ⌘F puts the cursor there, Escape empties it, a second Escape closes How it works). On every key press, only the parts and paragraphs that hold the words, each under its part's own heading, in the guide's order; the words marked semibold in How it works' slate on a slate band (at night the text's own colour on a stronger band); "N places" on top; "Nothing in How it works says that." when nothing does. Matched as the app's other searches (`normName`, one phrase) with accents and curly or straight quotes not counting either. A part whose heading alone holds the words shows whole. The Words list is searched too (it is part of How it works); the loop's picture and the stations' drawn marks are not. The ✕ gives the whole guide back where he was reading (it stays built, out of sight) | His ask: "Search function in How-it-works. There is a lot of information in how it works, and I really like that. Keep up the good work in making it extensive. The search function will make it even better." The rest decided by the build. Spec 06 §7a. Red first: ("0") is not equal to ("1") - Siri is not marked in paragraph 7 of topic-1; "the guide came back somewhere else, not where it was" with the guide built again after the search. |

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
