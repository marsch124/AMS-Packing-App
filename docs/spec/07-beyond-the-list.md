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
| 7. Apple Health fills in the review | 0.70 | designed here |
| 8. A trip page in his Obsidian vault | 0.70 | built |
| 9. Kits — things that hold things | 0.70 | designed here |
| 10. Hands-free packing (a test version) | 0.71 | designed here |
| 11. Decision log | — | kept here |

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

### What he sees

After a trip, the review (Trips → a trip → Review) opens with a block **"From Apple Health"** above the lines:
the workouts logged between the trip's first and last day, one row per kind, for example

- "Swim · indoor · 3 times"
- "Run · outdoor · 2 times"
- "No bike" (shown only for a workout template that is on the trip and had no workout)

and a button **"Use these"**. Pressing it marks the review's lines:

- lines from a workout template whose workout WAS done → used (as the review already assumes);
- lines from a workout template whose workout was NOT done at all → "didn't use";
- lines from a workout template done only in the OTHER context (only indoor swims, but the line's place on the
  template is for Outdoor only) → "didn't use";
- every other line (common base, transport, a non-workout template) → unchanged.

Every mark stays his to change before Save; nothing is saved by "Use these" alone. A line he had already
answered by hand keeps his answer. Without workouts on those days, the block says "No workouts in Apple Health
for these days" and offers nothing.

### Which workout meets which template

Each workout template is matched by its name (the same normalised name rule as the workout colours,
`WorkoutTone`), unless he links it himself on the template's page ("Counts as: Swim" — a drop-down of the kinds
below plus "Nothing"; stored on the template, synced and backed up like its other fields).

| Apple Health workout | Template it meets | Context from the workout |
|---|---|---|
| Swimming | Swim | pool → Indoor; open water → Outdoor (Apple Health's swimming location) |
| Cycling | Bike | indoor workout → Indoor; otherwise Outdoor |
| Running | Run | indoor workout → Indoor; otherwise Outdoor |
| Traditional / functional strength training, core training | Strength | Indoor |
| Yoga, mind and body, flexibility, breathing-type workouts | Mobility & Breath work | — |
| Hiking | Hiking | Outdoor |
| Golf | Golf | Outdoor |
| Climbing | Climbing | indoor workout → Indoor; otherwise Outdoor |
| Underwater diving | Diving and Freediving | Outdoor |
| anything else | — (ignored) | — |

"Race" cannot be read from Apple Health: a line for Race only is left as it is.

### Rules and edge cases

- **Days:** from the trip's first day 00:00 to its last day 23:59, in the time zone of the device. An undated trip
  gets no block.
- **Two trips on the same days:** each review reads the same workouts; that is correct (he was on both).
- **A workout without its gear** (a run on the treadmill of a hotel): it still marks the Run template's things as
  used — the app cannot know; he corrects the few lines by hand.
- **Things for someone else** (Whose it is ≠ him): left unchanged — his workouts say nothing about hers.
- **Things on two templates** (a towel on Swim and on the common base): the common base wins — unchanged.
- **Workouts logged later** (a watch synced after the review opened): "Use these" reads again each time it is
  pressed.
- **Permission:** asked the first time the block would show, with the words "AMS Packing reads your workouts
  during a trip to suggest what you used. It never writes to Apple Health." Refused → the block says "Apple Health
  is not allowed — Settings → Privacy → Health" and nothing else changes.
- **Read only.** The app never writes to Apple Health. Nothing read leaves the device; only the review answers
  (used / didn't use) are synced, as today.
- **iPhone only.** The Mac has no Apple Health: its review shows no block; a review answered on the iPhone reaches
  the Mac as any other review.

### Release

An app that reads Apple Health carries the HealthKit entitlement. Workout Sync showed (30 Sep 2026) that GitHub's
cloud-signed archive can lose it; the owner allowed (7 Oct 2026) that such versions are archived and uploaded from
his Mac when GitHub cannot sign them. The release step checks the archived app's entitlements and stops if
`com.apple.developer.healthkit` is missing — a version without it would show no block and say nothing.

### Tests (planned)

- Model (PackingLibrary, with invented workouts — no Apple Health in tests): mapping table above, contexts, the
  "Counts as" link, done / not done / other context, his own answers kept, someone else's things unchanged, the
  common base unchanged, an undated trip.
- UI (`-uiTestingHealth` launch argument feeding invented workouts): the block's rows by id
  (`review-health-row-N`), "Use these" (`review-health-use`) marking the expected lines, and nothing saved until
  Save; each seen red with a planted fault.

---

## 8. A trip page in his Obsidian vault

**Built in 0.70** (`PackingLibrary/VaultPage.swift` — the page and the marks; `App/Sources/Store/Vault.swift` —
`VaultShelf`, the folder and the writing, Mac only; `App/Sources/Screens/VaultCard.swift` — the card on the trip;
spec 03 "The trip's page in his vault" has the card's every size and id).

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
| `healthWorkouts` (`TRIP_WORKOUTS_KEY`) | `["Swim · indoor · 3 times", …]` | 🔌 **HOOK for part 7** — nothing writes it yet; part 7 is to write the rows of its "From Apple Health" block here when the review is saved with workouts read (the Mac has no Apple Health: this key is how its page learns them) |

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
with a planted fault (0.70 report).
**Not covered:** the real system folder picker and the bookmark across launches (no test can drive the panel);
a folder that has gone away; a sync bringing the iPhone's wish to an open Mac (the same `didSet` path the review
test drives).

### Open questions

- His edits INSIDE the markers are replaced on a resend (by design: that is the app's part).
- **A renamed trip** gets a page of its new name; the old page stays (the app never deletes his files). The same
  for a removed bag photo: its old copy stays in `attachments/`.
- **Workouts** wait for part 7 to write `healthWorkouts` (the hook above).
- The vault folder is chosen on the trip's card only — there is no row for it in Settings.

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

- "Change" for sections (part 2) was taken as the ORDER of the sections; if he meant something else, change part 2.
- "The road to 1.0" (all web-app features in, a real trip, a real restore, a quiet week): kept or dropped — his word
  is pending.
