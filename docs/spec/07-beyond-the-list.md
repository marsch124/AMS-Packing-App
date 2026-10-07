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

- "Change" for sections (part 2) was taken as the ORDER of the sections; if he meant something else, change part 2.
- "The road to 1.0" (all web-app features in, a real trip, a real restore, a quiet week): kept or dropped — his word
  is pending.
