# Inventory — the plan (draft, 11 Nov 2026)

**Goal:** AMS Packing knows everything you own — what it is, where it is, what it cost, when the warranty ends, its receipt and manual, and when it needs care. Packing stays exactly as it is; the inventory grows out of **Care ▸ Your things**.

**Good news:** the app already *stores* most details (brand, model, serial, bought on, price, currency, shop link, warranty, how many you own, colour, size, condition, photos up to 5, care log). Most of them simply have **no place on the thing's page yet**. Step 1 is mostly giving them one.

---

## Step 1 — Details for each thing (0.115)

**1. A "Details" card on every thing's page** (grouped, Apple's way, in Care orange), below the photos:

| Line | Example | Already stored? |
|---|---|---|
| Brand · Model | Sony · WH-1000XM5 | yes (Brand shows today) |
| Serial number | 4512 0877 | yes |
| Bought on | 3 Mar 2025 | yes |
| Bought at (shop) | Elgiganten | new (only a link today) |
| Price | 3 490 kr | yes |
| Warranty until | 3 Mar 2027 — "1 year 4 months left" | yes |
| How many you own | 2 | yes |
| Kept at home (room/place) | Bedroom ▸ Wardrobe | yes, as words |

Empty lines are folded under "Add details" so a sparse thing stays short.

**2. Things that never travel** — a "Stays at home" mark (sofa, drill, TV): never offered on a trip, template or ＋ Add, but in the inventory.

**3. Your things grows views** — All · Travel · At home, a search that also finds brand, model and serial, and sorting by room, by value or by warranty ending.

**4. Totals** — "214 things · 86 400 kr" at the top; per room when grouped by room.

**5. Adding many things fast** — photo first (take a photo, type a name, done); details later.

## Step 2 — Receipts and manuals (0.116)

- Receipt: scan with the camera (Apple's document scanner, straight edges), or pick a photo/PDF from Files. Several per thing.
- Manual: a link, or a PDF kept with the thing.
- Stored with your other photos (iCloud, both devices). Opens full screen; share/print.

## Step 3 — Warranty and care reminders, and the insurance list (0.117)

- Warranty ending: a reminder before it runs out (e.g. 30 days).
- Care already exists ("Done today", intervals) — it gets a reminder at the due date for home things too.
- Insurance list: one PDF of everything (or a room) with photo, brand, serial, bought on, price — for a claim or the insurer.

---

**Each step ships alone**, with What's new, How it works, the spec, one data test per rule and one screen test for the new card. Nothing you placed moves.

---

## Your answers (interview, 11 Nov 2026)

| Question | Your pick |
|---|---|
| What goes in | **Everything you own** — whole home plus the travel things |
| Where in the app | **Inside Care ▸ Your things** — no new tab; views All · Travel · At home. *(Changed 11 Nov 2026, see below: its own Inventory tab.)* |
| Things that never travel | **"Stays at home" mark** — never offered on trips, templates or ＋ Add |
| Where kept | **Room ▸ spot** — your own list of rooms, optional spot in each |
| Details on the page | **All four:** bought on + shop + price · warranty until · brand, model, serial · value today |
| Adding many at first | **Room walk** — pick a room, then photo + name, photo + name… |
| Whose it is | **Keep the existing field** for home things too |
| Things no longer owned | **"Gone" with a date** — out of the lists, kept with receipt and price |
| Receipts | **Photos with the iPhone camera as you go** — receipt, delivery note, anything on paper |
| Manuals | **Link first, a stored PDF when wanted** |
| Warranty reminder | **30 days before** |
| Insurance list | **PDF with photos**, room by room, with totals |

### What this changes in the plan
- Step 2 becomes **"Papers"**: on a thing, ＋ Paper opens the camera at once; each photo gets a kind — Receipt · Delivery note · Warranty card · Manual · Other. Several per thing, all on both devices.
- Step 1 gets **rooms** (your own list, each with spots) and the **room walk**.
- Details card lines: Brand · Model · Serial · Bought on · Bought at · Price · Value today · Warranty until · How many · Room ▸ spot · Whose it is.

## Round 2 — 20 more answers (11 Nov 2026)

| # | Question | Your pick |
|---|---|---|
| 1 | Starter rooms | **Swedish-home starter**: Hall, Kitchen, Living room, Bedroom, Office, Bathroom, Laundry, Storage, Garage, Attic, Car (editable) |
| 2 | Places outside the flat | **Car · Storage unit / cellar · Office / work** |
| 3 | Your things opens with | **All, grouped by room**; Travel and At home one tap away |
| 4 | Spot inside a room | **Typed, with suggestions** from spots used before in that room |
| 5 | Room walk pace | **Camera straight back**, running count "12 in Kitchen", Done ends the room |
| 6 | Name from the photo | **App suggests (on the device), you confirm** |
| 7 | Sets (6 glasses) | **One thing × count** |
| 8 | Small stuff | **As boxes/groups**, like kits ("Cable box") |
| 9 | Price | **Per piece**; total = piece × count |
| 10 | Value today | **App estimates** (−15 % a year, never below 10 %); your own figure wins |
| 11 | Currency | **SEK by default**, others per thing at a rate you set |
| 12 | Shop | **Typed, with suggestions** of shops used before; link optional |
| 13 | Warranty entry | **Length from bought date** (1 · 2 · 3 · 5 years) |
| 14 | Swedish 3-year complaint right | **Quiet line** on things without a warranty, no reminder |
| 15 | Serial number | **Scan text or barcode** with the camera, or type |
| 16 | Page order | **Details card under the photos, folded when empty**; nothing you placed moves |
| 17 | Anna | **Shared like today's things**; "Whose it is" tells who owns what |
| 18 | Privacy | **No hiding** |
| 19 | Building order | **0.115** Details + rooms + Stays at home + views + totals · **0.116** room walk (BUILT 11 Nov 2026) · **0.117** Inventory tab (his new pick, below) · **0.118** row photos at the start of each thing (11 Nov 2026) · **0.119** Papers (BUILT 11 Nov 2026; a stored PDF manual is not in it yet) · **0.120** reminders + insurance PDF (BUILT 12 Nov 2026) |
| 20 | Marking "Gone" | **Date + how** (Sold · Given away · Broken · Lost · Stolen), sold-for price if sold |

## New pick — its own Inventory tab (11 Nov 2026)

His words: "I cannot find an entry point for the new items perspective — the items not related to packing per se, more inventory related. Can we make an inventory page?" He picked **its own tab**. This replaces his earlier answer "inside Care ▸ Your things, no new tab".

- A 6th tab **Inventory** (teal #0f8b8d, hand-drawn house), between Care and To do; Mac Go ▸ Inventory ⌘7.
- The page: totals card (how many · cost · worth today), **Rooms** card (each room with its count, "No room" last; tap a room → its things), **All things** row, **Warranty ends soon** card (within 60 days, hidden when none), floating **＋ Room walk**.
- Care ▸ Your things stays as it is; the room walk stays there too.

**Build order now:** **0.117** Inventory tab · **0.118** Papers (receipts and manuals, was 0.117) · **0.119** warranty/care reminders + insurance PDF (was 0.118). Step headings above ("Step 2 — Papers", "Step 3 — reminders") keep their content; read 0.116/0.117 there as 0.118/0.119.

**Build order since 0.118 (11 Nov 2026):** **0.118** the small photo at the start of each thing's row (his "bigger, at the start") · **0.119** Papers (receipts and manuals) · **0.120** warranty/care reminders + insurance PDF. Read 0.118/0.119 in the older lines above as 0.119/0.120.

**0.119 Papers (BUILT 11 Nov 2026):** photos of receipt, delivery note, warranty card, manual or other on a thing, up to 12, plus a Manual link. A stored PDF manual is NOT built yet.

**0.120 Reminders + insurance PDF + No receipt yet (BUILT 12 Nov 2026):** switch "Remind me at 9:00" (`inventory-remind`, per device, off at first; warranty 30 days before at 9:00, care due today at 9:00; not-in-use never; max 40; tap opens Inventory), button "Insurance list (PDF)" (`inventory-pdf`, A4 light, totals, room by room, details, receipt photos at the end, share sheet/menu; test line `inventory-pdf-said`), row "No receipt yet" (`inventory-noreceipt`, opens Your things filtered). Full detail in docs/spec/05-things-care-table-todo.md.

**0.121 (BUILT 12 Nov 2026):** serial scan (iPhone, `thing-serial-scan`), Gone (Mark as gone, Gone view, `inventory-gone`), other currencies in totals at today's ECB rates, and a PDF manual in Papers (`thing-paper-pdf`). Full detail in docs/spec/05-things-care-table-todo.md.

**0.122 (BUILT 12 Nov 2026):** Gone by year (`things-gone-year-<yyyy>`), serial read on the room walk (`walk-serial`), five sample things + Settings "Remove the sample things". Detail in docs/spec/05-things-care-table-todo.md.
**0.123 (BUILT 12 Nov 2026):** "Gone this year" part in the insurance PDF (`InsuranceList.gone`, `goneYear`, receipts included), "Sample" tag on the sample things (`thing-row-<n>-sample`, `thing-sample`, "(sample)" in the PDF). Detail in docs/spec/05-things-care-table-todo.md.
**0.124 (BUILT 12 Nov 2026):** Lent to (`LentOut`), spare parts and refills (`SpareParts`, Care every week / 2 weeks), claim letter (`ClaimLetter`), sell ad (`SellAd`), quarterly check (`QuarterlyCheck`), one receipt for several things (`sharePaper`), thing labels (`ThingLabels`). Detail in docs/spec/05-things-care-table-todo.md.
