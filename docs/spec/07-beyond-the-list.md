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
| 9. Kits — things that hold things | 0.70 | designed here |
| 10. Hands-free packing (a test version) | 0.71 | designed here |
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

His words (7 Oct 2026): some things are "already existing as a permanently packed item consisting of items" —
"a TechPouch with power bank, some cables, a microphone, an iPhone stand", "a Hiking-Pouch consisting of a screw
driver inside, a knife, a light, a Leatherman, some tape". He said yes to kits on 7 Oct.

- **A kit is a thing** with a list of the things inside it (its contents), set on its page ("Inside: …" — a list
  with Add from your things). Its contents are real things with their own weight, care, condition and Valid until.
- **One level deep.** A kit can go in a bag; a kit cannot go inside another kit; a thing is in at most one kit.
- **On a trip** a kit is ONE line: "Tech pouch · 6 inside", with a fold arrow showing the contents (muted, not
  ticked separately). Ticking the kit packs it. Its contents are never separate lines on a trip.
- **Check before each trip** (optional, on the kit's page): the contents then show as small ticks under the kit's
  line, and the kit counts as packed only when all are ticked.
- **Taken out.** A thing taken out of its kit (on the thing's page or from the kit's fold) is marked "taken out";
  the kit's line then says "1 missing: knife" until it is put back.
- **Weight** of a kit = its own + its contents. **Care**: a content's Valid until or care warning also shows on the
  kit ("plasters expire in May").
- **Templates hold the kit**, not its contents. A content that is ALSO on a template on its own is pointed out on
  the thing's page ("Also inside the Hiking pouch").
- **"Where is my …?"** answers "Hiking pouch, in the backpack".
- Model: a kit is an item with `kitContents` (ids) and `kitCheck` (bool); a content has `insideKitId`; stored,
  synced and backed up with the item. The web app knows nothing of kits: parity must treat them as plain items.

---

## 10. Hands-free packing (a test version)

His yes of 7 Oct 2026, in English (his choice): on a trip, **"Pack by voice"** reads the unticked lines in "From
where" order — the place, then the thing ("Garage. Goggles.") — and listens for five words: **packed**, **skip**
(set aside, "not this time"), **later** (moves on, keeps it unticked), **where** (repeats the place), **stop**. Every
few things it says the progress ("Garage done, 12 of 40"). Speech is recognised on the device (works offline);
thing names are read as written. A place opened by its code (part 3) can start the walk at its place.

It is a TEST: kept only if, on a real trip, it understands him at least 9 times in 10 and beats tapping, and he
wants to use it again. Otherwise it is removed and recorded in the decision log.

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
