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
| 12. Reminders on a template | 0.70 | built (branch work/reminders070) |

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
- Each reminder is a line (`template-reminder-<n>`, `Metrics.line` high, hairline under it): its name, and on the
  right its When in the step's own colour (made readable for day or night). A press opens it in place:
  - the name, a field (`template-reminder-name`; what was missing said under it, `template-reminder-name-needs`);
  - **When**, a drop-down (`template-reminder-when`) — applied at once; its open lines on trips still ahead follow;
  - ↑ and ↓ (`template-reminder-up` / `-down`, 36-pt squares) — move it one place among the reminders, at once;
    at the top (bottom) the arrow is drawn in the hairline colour and does nothing;
  - **Done** (`template-reminder-done`, the template's violet, never grey) — saves a changed name and closes;
  - last, quiet and red, **Remove reminder** (`template-reminder-remove`), which asks first: "Remove “…” from this
    template?" Keep it (`-remove-no`) / Remove (`-remove-yes`).
  - Pressing the line again closes it without saving the name; Esc closes it on the Mac.
- The foot: **Add a reminder** field (`template-reminder-add-name`) and **Add** (`template-reminder-add`), then
  **When** (`template-reminder-add-when`). Add with nothing typed says "Type the reminder first."
  (`template-reminder-add-needs`). A new reminder's When starts as the last reminder's on this template, else the
  first step one day ahead ("Day before"), else the step a new thing gets.
- While Find holds a word, the block is hidden (Find looks for things). The template's card on the Templates tab,
  the "3 of 40" of Find, Group, Arrange and the Templates tab's summary count the THINGS only.
- **On a trip**, a reminder is a line like the others, at its When, ticked the same way (and set aside with ⊘). In
  place of the bag it says **To do**, and it has no count. Sorted by Into, the reminders stand under a heading
  "To do", never under a bag. The bag weights, the cabin check and the review leave them out (as before).
- **Check before you go** (top of the trip) lists the reminders that are due — their step's day (the trip's start
  less the step's lead days) is today or past — and not ticked: a tick circle, the name, "To do · <step>"
  (`trip-check-todo-<n>`). A press ticks the line, and it leaves the card. With only reminders, the card is in the
  trip's green, not a warning's colour; its count includes them.
- **Home's countdown** says the step as before, now with things and reminders apart — "≥1 week ahead: 7 to pack,
  1 to do, now" (a Preparations step says all of it "to do") — and, when reminders are due, a green line
  "To do: Check the forecast · …" (accessibility value "<n> to do"). The packing notifications (Remind me to pack)
  read the same words.

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
  tick; Check before you go, Home and the packing notifications bring it to him when it is due.

### Model (PackingLibrary/TemplateReminders.swift, Countdown.swift)

`REMINDER_TYPE`, `REMINDERS_CATEGORY`; `Library.isReminder(_:)`; `reminders(templateId:)`;
`reminderNameProblem(templateId:name:except:)` → `.blank` / `.alreadyHere` / `.aThing` / nil;
`whenForNewReminder(templateId:)`; `addReminder(templateId:name:when:)`; `renameReminder(templateId:memId:to:)`;
`setReminderWhen(templateId:memId:when:)`; `moveReminder(templateId:memId:by:)`; `removeReminder(templateId:memId:)`;
`remindersOnTemplates()`, `ownThings()` (also used by `thingRows()`); `templateSummary` counts non-reminders.
`PackingStep.todo` (reminders left on the step; `left` is things only) and its `says`; `NextTrip.left` (things only)
and `NextTrip.due` (names); `dueReminders(tripId:today:)` — every step of the timeline (the After step too: its day is
the start plus one), unticked, not set aside, in timeline then trip order; none for a trip without a start date.
The UI-test library `-uiTestingReminders` (`SampleLibrary.reminders()`): Hiking with "Check the forecast" (≥1 week
ahead) and "Leave a route note" (Day before), its trip three days ahead.

### Tests

Model `TemplateRemindersTests` (9): the web app's own kind of item; refused names; a new reminder's When; rename per
template; order, When and remove; not among his things nor arranged; on a trip ticked but never packed, weighed or
reviewed; due reminders; a step's words. Planted fault: `ownThings()` returning every item → red "Your things lists
things only". UI (iPhone, light and dark): `testATemplateKeepsItsReminders` (planted: Add not adding → "the reminder
was not added"), `testATripsRemindersShowWhenTheyAreDue` (planted: `dueReminders` empty → "the countdown does not
name the reminder due"). Not covered by a UI test: Into's "To do" heading, the When drop-down on a reminder, Remove's
"Keep it", the Mac (built, not run).

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

- Part 12: renaming a reminder that also sits on another template leaves the lines already on trips with the old
  name. Progress still counts reminders (so "All packed" waits for them) — if "never counted as things to pack" was
  meant to include the trip's x/y, that is a change to spec 03's decision of 5 Oct.

- "Change" for sections (part 2) was taken as the ORDER of the sections; if he meant something else, change part 2.
- "The road to 1.0" (all web-app features in, a real trip, a real restore, a quiet week): kept or dropped — his word
  is pending.
