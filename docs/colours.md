# Colours

Every colour the app uses, and why. He runs everything in **dark mode**, so a
colour is only settled once it has been seen on the dark card as well as the
light one.

## The six sections — `App/Sources/Sections.swift`

| Section   | Colour | Hex       |
|-----------|--------|-----------|
| Home      | blue   | `#2f6fe0` |
| Events    | green  | `#2f9e63` |
| Templates | violet | `#7c5cd6` |
| Care      | orange | `#dd7324` |
| Actions   | red    | `#dc3d43` |
| Settings  | slate  | `#64748b` |

Red `#dc3d43` is also the colour of a problem message (first run, a failed
restore, a grab list that cannot be saved — "Put at least one thing on the list
first.", under its Save).

## Page and text — `App/Sources/Theme.swift`

Each is a light / dark pair, never a single hex.

| Name  | Light     | Dark      | Used for                  |
|-------|-----------|-----------|---------------------------|
| bg    | `#f4f6f7` | `#0e1416` | the page behind the cards |
| card  | `#ffffff` | `#161f22` | cards and sheets          |
| ink   | `#16232a` | `#e7edee` | text                      |
| muted | `#5f7078` | `#94a6ac` | secondary text            |
| line  | `#e2e8ea` | `#26343a` | hairlines                 |

## Grab list tones — `App/Sources/Screens/GrabScreen.swift`

Mid-tones on purpose, so they read on the light card and the dark one alike.
They are the workout colours' FAMILY (Swim blue, Bike yellow, Run green), not
their exact fills: a tile is a coloured drawing and outline on the card, and the
bright pill fills — the yellow above all — would not read as a line on the light
card (decided 5 Oct 2026). A list received with a tone not listed here becomes
blue, the tone Make gives.

| Tone   | Hex       | The built-in lists wearing it |
|--------|-----------|-------------------------------|
| blue   | `#3a86d4` | Swim (indoor and outdoor)     |
| yellow | `#c99700` | Bike (indoor and outdoor)     |
| green  | `#2e9e6b` | Run (indoor and outdoor)      |
| red    | `#cf5b52` |                               |
| purple | `#8a63c9` |                               |
| teal   | `#17969b` |                               |
| other  | `#64748b` | (none arrives since 5 Oct 2026; a factory row from the web app could carry one) |

## Workout pills (WET) — decided 28 September 2026, not built yet

WET = workout, exercise, training. On **Create new trip** and **Trip
settings**, each WET template gets its own colour, so a sport is recognised by
its colour before its name is read. The same sport keeps the same colour in
AMS Workout Sync, and the same colour family in the grab lists (their mid-tones,
above).

| Pill        | Colour      | Fill      | Text on it |
|-------------|-------------|-----------|------------|
| Swim        | blue        | `#0a84ff` | white      |
| Bike        | yellow      | `#ffd60a` | dark — `#3d3000` (white is unreadable on yellow) |
| Run         | green       | `#30d158` | dark green `#0b3a17` |
| Strength    | deep orange | `#ff8c1a` | dark orange `#4a2300` |
| Breath work | lavender    | `#bf9cff` | dark violet `#2e1a5c` |
| Mobility    | rose pink   | `#ff6fa8` | dark rose `#5a0f2e` |

**Context** (Indoor, Outdoor, Race) sits **indented under** the WET row, so it
reads as belonging to the workouts, in **neutral grey** — it describes the
workouts rather than being one.

Bike and Strength are the same hexes AMS Workout Sync uses.

**Not teal.** He does not like teal as a colour (28 September 2026). Teal was
offered for Mobility and turned down; rose pink was picked from rose,
raspberry and warm sand. Do not use teal for anything new.

Status: decided during his test round of 0.39 and built after he says he is
done testing, with photos in day and night mode before it ships.
