# AMS Packing — the functional specification

This folder describes, in plain English, everything the app does: every screen, every button and its exact
words, every rule, limit and stored key, and how the data travels between the iPhone, the Mac, iCloud and a
backup file. It exists because of the owner's request of 4 Oct 2026:

> "Please remember to document everything thoroughly and how it works. I would like every nit and
> nitty-bitty documented. This is very important for the future. Maybe I will ask you to rewrite the code to
> make it even more hardened. Then it is vital to have all the functionality described in very, very great
> detail."

So the aim is twofold: a competent developer can **rebuild** the app from these files without guessing, and
a reviewer can tell from them whether a rewrite **behaves the same**. The app is one SwiftUI target that
runs on the iPhone and on the Mac; every difference between the two is written down where it occurs.

## How it is kept

- **Written from the code and the tests**, never from memory or from comments alone. Where a comment, a
  document or the in-app guide disagrees with the code, the code wins and the disagreement is listed under
  the file's *Open questions*.
- **Updated in every release, in the same commit.** A change that alters behaviour updates the section that
  describes it, its tests list and its open questions. `tools/check-spec.sh` enforces it: the TestFlight
  workflow runs it before anything is built, and refuses a release whose last *What's new* change
  (`App/Sources/Guide/Releases.swift`) did not change this folder in the same commit.
- When a file is checked against the code, the line under its title records the date and the app version,
  for example `> Verified against the code on 5 Oct 2026 (app 0.61).`
- **The repository is public.** No real person, place, trip, item name or e-mail address appears here.
  Examples use the invented sample library the UI tests run on (`App/Sources/Store/SampleLibrary.swift`:
  templates "Common base", "Hiking" and "Swim"; things such as Passport, Hiking boots and Headlamp; owners
  Kim and Robin; the trip "Weekend in the hills") or other invented names.

## The seven files

**[01 — Storage, sync and backup](01-storage-sync-backup.md).** The foundation. The data model — `Library`
and every collection it holds, every field of a thing, a place on a template, a template, a trip and its
lines, a to-do, a kit, a "When" step, a Settings entry and a photo — with every `meta` key and every `extra`
key the app writes. How a template is resolved for the screens and taken apart again on Save, and how a
trip's list is regenerated. How the library is cut into small records, stored with SwiftData and carried by
iCloud (CloudKit), the one way the library changes (`LibraryModel`), the launch modes the tests use, the
iCloud sync card, the empty device and the one-time import, the backup file and what it holds, Restore and
the copies kept before a restore, This device holds, Worth a look, Save as Excel, share links and QR codes,
and the helpers that decide when two names, dates or numbers are "the same".

**[02 — Home, grab lists, Shortcuts, packing reminders and Search](02-home-grab-lists.md).** The frame of the
app (tab bar, version marker, what happens when it comes back to the front) and the empty-device screen.
Home: the grab tiles, one grab list open for ticking ("Ready to go", "Not yet", Start over), editing a grab
list and "only sometimes", deleting one of his own, the Grab Lists screen (Home's eight, the waiting ones,
Make, Off Home, "Which one steps back?"), the Action button's "Which grab list?" menu and sharing a grab
list. Also the countdown card to the next trip, the This Device tiles, the three Shortcuts actions, the
"Remind me to pack" notifications and Search.

**[03 — Trips](03-trips.md).** The whole life of a trip. Create new trip (name, Full trip | Quick, dates,
templates, context per workout, transport, season, food, laundry) and how its list is built from the templates; the Trips tab; the
trip screen (ticking, "not this time", sorting and folding, adding a thing, Tick everything); Trip settings
and Start a new trip from this one; Check before you go, the weather card and the Bags card (luggage scale,
cabin, bag photos); On site, Pack to go home, the review and Refine, and the loop that joins them; Save as
Excel, sharing and deleting a trip.

**[04 — Templates](04-templates.md).** The building blocks a trip's list is made from, and how things sit on
them. The Templates tab, a template's card, cover and icon, making a template, one template open, a row of a
template (its bag, "When", section, quantity, note and "only on some trips" conditions), Choose from your
things, grouping, the model of a template and its rows, renaming and deleting, the bag list, when a template
was last taken, a change to a thing following to trips still ahead, kits, sharing a template, and Your
choices.

**[05 — Things, Care, the things table and To do](05-things-care-table-todo.md).** A thing — one physical
object, kept once however many templates it sits on — and every operation on it. The Care tab (care records,
the care calendar, the kit dashboard), Your things and a thing's page, Bags and a bag's page, the All your
things table (columns, editing cells, filters, sort levels, Change all and Undo, its own window on the Mac),
and the To do tab with its two sides, To do and To buy, including sending buy lines to Apple Reminders.

**[06 — Settings, the guide, the conventions, and how the app is built](06-settings-guide-conventions.md).**
The Settings screen from top to bottom, Your choices, the in-app guide (What's new, How it works, Your first
real trip, Words). The conventions every screen follows: colours in light and dark, drawn marks instead of
stock icons, buttons and the rule that a main button is never grey, headings and type sizes, scrolling and
the keyboard, accessibility identifiers, the Mac rules. And the machinery: windows and launch modes, the
sample library, the project, CI on every push, shipping to TestFlight, crash reports, local tools, the parity
check against the web app, the UI-test harness and the test inventory.

**[07 — Beyond the list](07-beyond-the-list.md).** The ideas chosen on 7 Oct 2026 that span several screens:
the keyboard on a thing's page (Mac), sections edited from a thing's page, places with stickers, search in notes,
bag pockets and "Where is my …?", the door check, Apple Health filling in the review, a trip page in his Obsidian
vault, kits (things that hold things) and hands-free packing — written BEFORE they were built, at his request —
and the decision log of what he turned down.

Some subjects are seen from two sides: the backup and Restore (storage in 01, the Settings screen in 06),
Save as Excel and sharing (the file and the codes in 01, the trip screen in 03), Your choices (04 and 06),
Search (02, reached from several tabs). Read both where it matters.

## How to read it

1. Start with **01 §1, the data model**: what a thing, a place on a template, a template and a trip line
   are, and which fields belong to which. Every other file assumes it.
2. Then open the file of the area you need. Each one begins with an overview — what the part is for, in
   the owner's terms, and every way to reach it — followed by one section per screen, sheet or feature,
   each in the same order: **Purpose and origin**, **How it is reached and left**, **What is on screen**,
   **Behaviour**, **Data**, **iPhone vs Mac**, **Tests** (and what no test covers), **Traps and history**.
3. Each file ends with **Open questions / discrepancies**: what is ambiguous, contradictory, unused or
   surprising. Read it before changing that area.

Words as the app uses them: a **template** is a building block (Hiking, Swim, the Common base); a **list**
is what he packs from — a trip's list or a grab list; a **thing** is one object he owns; a **place** is a
thing's row on one template. Sizes: since 0.62 the app uses Apple's text styles and the `Metrics` heights (spec 06, §21); where a chapter still gives a size in points, it is the size before 0.62, and §21's table says which style replaced it. Colours are named by token, never by hex alone.

## Tags in the open questions

| Tag | Meaning |
|---|---|
| **[bug]** | the code does something wrong or surprising for the owner |
| **[rule-break]** | it breaks one of his standing rules (a main button is never grey; no stock icons or emoji as icons …) |
| **[doc]** | a comment, a document or the in-app guide disagrees with the code |
| **[untested]** | behaviour that matters and that no test pins |
| **[idea]** | worth deciding before a rewrite: a design question, a possible improvement, ported but unused code |

An item can carry two tags. An item fixed in a release stays in place with its number, marked **Resolved
in <version>**, so that references to it stay valid; it carries no tag and is not counted as open.

## Related documents

- [`../store.md`](../store.md) — how the library is kept and how it syncs: one small record per thing, the
  ten rules (each bought with a bug in the web app), the layers, the proof run on a real Mac, what it needs
  from the project, and what this design gives up. The spec links to it and does not repeat it.
- [`../colours.md`](../colours.md) — every colour the app uses and why: the six section colours, the page and
  text pairs for light and dark, the grab-list tones. The spec names colours by these tokens.
