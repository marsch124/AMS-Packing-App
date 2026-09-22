# The store — how the library is kept, and how it syncs

Decided 2026-09-21: **Apple's iCloud (CloudKit, the private database)**. His Apple ID
is on both devices already; there is no other account and no server. The web app
needed six releases to get sync right because its store was designed without it.
This one syncs from the first commit that stores anything.

## The shape: one small record per thing, and one table for all of them

SwiftData with CloudKit behind it, and exactly **one** model:

```
Record
  table      "items" | "memberships" | "templates" | "trips" | "entries" |
             "actions" | "kits" | "phases" | "shared" | "photos" | "meta"
  key        the thing's own id (an item id, "prep", "places:garage"…)
  parent     the id it belongs to, where that is how it is fetched
             (an entry's trip, a membership's template) — else ""
  json       the thing itself, as PackingCore writes it (`Item.json`…)
  blob       a photo's bytes (external storage → a CloudKit asset), else nil
  updatedAt  when this device last wrote it
```

Why one generic model rather than forty-five typed columns:

- **The CloudKit schema never has to change.** A production CloudKit schema is
  additive for ever — a field can be added, never renamed or removed. A new field
  on an item is then a change to PackingCore only, not a schema deployment that a
  TestFlight build silently depends on.
- **PackingCore is already the schema.** Decoding is coercion: an old record, a
  record from a newer build, a record with a field this build has never heard of
  all read correctly, and unknown keys are written back untouched.
- **The unit of sync is the unit of change.** A tick is one `entries` record. Two
  devices ticking different lines of the same trip both win, because they wrote
  different records. (The web app's v120 lesson: one row per entry, never one row
  per list — a whole list in one record makes the last device to save win outright.)
  What this gives up is merging two edits to the SAME record made on two devices
  while both were offline: the later write wins. For one person with two devices
  that is the right trade.

The whole library is a few thousand small records; it is loaded into memory at
launch as PackingCore values (`Library`) and written through on every change,
which is how the web app works too.

## The rules, each one bought with a bug in the web app

1. **Nothing is ever seeded into the store.** Factory phases, conditions, people,
   storage places and grab lists live in the CODE; a table with no records means
   "use the defaults". A device that joins an account must never plant starter
   templates — that is how every template came to exist twice on 31 August 2026.
2. **An empty store is not a verdict.** A fresh device cannot tell "nothing has
   arrived yet" from "there is nothing", so it says so and offers two doors:
   *my other device has my lists → wait for iCloud* and *this is my first device →
   import a backup file*. It never decides by itself.
3. **The import happens once, on one device**, and writes a `meta` record saying
   so (when, from which file, how many of each thing). A device that sees that
   record refuses a second import unless told "replace everything", loudly.
4. **The import does not go through `buildCatalog`.** The web app's rebuild drops
   consumable, packer, review history, "not in use" and kit membership (found by
   the port, 2026-09-21). The importer carries every intrinsic field and the
   membership's kit, and counts them before and after.
5. **Same key, two records → one survives, by rule.** CloudKit cannot enforce a
   unique key, and two devices can create `phases/prep` independently. On load,
   records are grouped by (table, key); the newest `updatedAt` wins, the rest are
   deleted, and the key is the tiebreak so both devices pick the same one.
6. **Stable keys for things that are the same thing.** A phase is `prep`, a shared
   row is `places:garage`. Random ids only for things that are genuinely new.
7. **No field is ever called `owner` or `realmId`** (PackingCore already refuses).
8. **A restore never quietly overwrites a newer copy on the other device.** It
   takes a snapshot first, says what it will replace, and is one deliberate act.
9. **Regenerating a trip never drops lines whose template no longer exists.** One
   of his real trips names three templates deleted long ago.
10. **Backups are files he can see.** Save window on the Mac, Files on the iPhone
    (`.fileExporter`), the same JSON the web app writes, so either app can read
    the other's file during the change-over.

## Layers

```
PackingCore        pure values and rules (done; parity-checked against the web app)
Library            the in-memory library: PackingCore values + the operations the
                   screens need (add a thing, tick a line, save a template…)
LibraryStore       protocol: load everything / write records / delete records /
                   observe remote changes
  CloudStore       SwiftData + CloudKit                      — the app
  MemoryStore      a dictionary                              — unit + UI tests
```

UI tests launch with `-uiTesting` → `MemoryStore`, so they never touch iCloud and
run the same on the simulator, the Mac and GitHub. Sync itself cannot be tested in
CI (no iCloud account there); it is proved on his two devices through TestFlight,
with a Settings screen that shows what this device holds, table by table, so two
devices can be compared by eye — the web app's "this device has everything" check.

## Proved on his Mac, 2026-09-22

A development build signed for this Mac pushed his whole library (1,438 records)
to the CloudKit **Development** environment; the local store was then deleted
and the app, started with nothing, pulled every record back within 10 seconds —
table for table the same counts. `tools/build.sh build mac icloud` is that build.

What it took, each one found in a log rather than guessed:
- `Sandbox: AMSPacking deny(1) file-read-data …` — a sandboxed app cannot read a
  file outside its container, so the debug `-importFile` path must point INSIDE
  `~/Library/Containers/com.schabbauer.AMSPacking/Data/` (copy the file there).
- `Sandbox: AMSPacking deny(1) mach-lookup com.apple.cloudd` — the app sandbox
  did not let the app talk to the CloudKit daemon at all; CloudKit reported it
  as "Error connecting to CloudKit daemon". Nothing in the entitlements, the
  profile, the Mac's registration or the launch path changed it. The fix is the
  temporary sandbox exception for `com.apple.cloudd` in the iCloud entitlements.
  (Of the shipped sandboxed CloudKit apps on this Mac, Fantastical carries the
  very same exception for `com.apple.cloudd`; Drafts does not. So it may or may
  not be needed in a Production-signed build — check on the first TestFlight
  build; if it is, it stays, and it has passed App Review for others.)
- The Development environment is a TEST copy. The real import happens once more,
  into Production, on the first TestFlight build — after the schema is deployed.

## What it needs from the project

- Capabilities: iCloud → CloudKit, container `iCloud.com.schabbauer.AMSPacking`;
  Background Modes → remote notifications (that is how a change on the other
  device arrives); push (`aps-environment`).
- 🪤 The Mac CI job signs ad hoc (`-`). An ad-hoc app carrying iCloud entitlements
  is refused at launch, so CI builds with a second entitlements file without them.
- The CloudKit schema has to be deployed to Production once (CloudKit Console)
  before a TestFlight build can sync. With one model it is deployed once.
