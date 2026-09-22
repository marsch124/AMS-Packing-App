# AMS Packing App — iPhone and Mac, in sync

A SwiftUI rebuild of the AMS Packing List web app: **one app for the iPhone and
the Mac that keeps the two in sync** — in Martin's words, "that sync function is
very important". One target for both devices, like AMS Coffee. The web app stays live at https://marsch124.github.io/AMS-Packing/
— with its tests still gating every release — until this one has been through a
real trip. Do not retire it early.

## The specification is already written

- [`../AMS Packing/docs/porting-to-xcode.md`](../AMS%20Packing/docs/porting-to-xcode.md)
  — the plan, the data bridge, the traps on this Mac.
- [`../AMS Packing/docs/behaviour-contract.md`](../AMS%20Packing/docs/behaviour-contract.md)
  — 334 rules this app must satisfy: the web app's own test names, in plain English.
- `../AMS Packing/js/model.js` — the logic being ported. It is a plain ES module,
  so Node loads it directly for the parity checks; no browser needed.

## Order of work

1. **`Core/`** — a Swift package holding the model, with the model tests ported
   before any screen exists.
2. **A parity checker** — the Swift model and `js/model.js` over his *real* data,
   compared answer by answer, until it ends "differences: none". This is how AMS
   Workout Sync iOS was proved: 0 differences on his real plans.
3. **A store that syncs between the Mac and the iPhone** — iCloud is the natural
   route. It must sync from the first commit that stores anything; see
   `porting-to-xcode.md` §5.
4. **Import** — from the web app's backup JSON, the only data bridge, done ONCE on
   ONE device and carried to the other by sync. The three things an importer gets
   wrong are in `porting-to-xcode.md` §2.
5. **The screens**, last.

## His real data never enters this repository

This repository is **public**. His backups — item names, storage places, people —
go in `private/`, which git ignores. The parity checker reads them from there.

## Where it stands

- ✅ The app exists: one target for the iPhone and the Mac (`project.yml`, XcodeGen),
  the six sections of the web app as a tab bar with the web app's own hand-drawn
  marks, light and dark.
- ✅ CI on every push: the model's tests, the UI tests on an iPhone simulator, the
  UI tests on the Mac.
- ✅ `Core/PackingCore` — the whole of `js/model.js` in Swift (the rules of the
  port: [`Core/PORTING.md`](Core/PORTING.md)), held to the web app by
  `tools/parity/` — both models answer 200-odd questions about a backup and every
  answer must be identical; on his real data: differences: none. A change to the
  web app's model turns the CI job red until the Swift model follows.
- ✅ `Core/PackingLibrary` — the library in memory, the records it is stored and
  synced as, the one-time import (self-checking), backups. [`docs/store.md`](docs/store.md).
- ✅ iCloud sync, proved end to end on his Mac (1,438 records up, wiped, all back).
- 🔨 Screens: Templates (read-only), Events, Packing Mode (tick, "not this time"),
  Home (build a trip), Settings (backup, device check). Care, Actions and editing
  are next.
- 🔜 TestFlight: [`TESTFLIGHT.md`](TESTFLIGHT.md) — two browser steps remain.

## Building

`tools/build.sh [build|test] [iphone|mac]` and `tools/test-core.sh` (the model's
tests alone, a few seconds). Anything under `~/Documents` collects extended
attributes that `codesign` refuses ("detritus not allowed"); the scripts clear them
(never inside `.git`) and keep every build folder outside `~/Documents`.

## Tests

His standing rule, from the first commit: UI tests in CI on every push, every
control found by its `accessibilityIdentifier` and never by its words, starting
with two and growing one at a time. A red run blocks a release. The web app's UI
suite also runs at Mac size — this one should test both devices from the start.
