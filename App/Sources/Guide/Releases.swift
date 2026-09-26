import Foundation

/// Every version, newest first, in his words — what was added, changed, fixed and
/// removed. His standing rule from the web apps: the version log and "How it works"
/// are updated on EVERY release. The UI test `testWhatsNewStartsWithThisVersion`
/// fails the build when the top entry is not the version being built, so a release
/// cannot slip out without its line here.
struct Release: Identifiable {
    let version: String
    let date: String
    let title: String
    var new: [String] = []
    var changed: [String] = []
    var fixed: [String] = []
    var removed: [String] = []
    var id: String { version }
}

enum Releases {
    static let all: [Release] = [
        Release(version: "0.23", date: "26 Sep 2026", title: "The app explains itself",
                new: ["Settings → What's new: every version, with what was added, changed, fixed and removed.",
                      "Settings → How it works: the whole app in plain words, screen by screen.",
                      "On a trip, the arrow before a section's name folds it away; tap again to open. Remembered per trip and per Sorting."],
                changed: ["The thing editor's buttons are a little smaller, so the headings stand out.",
                          "Arrived together with everything from 0.21 and 0.22, which the Mac tests had held back."]),
        Release(version: "0.22", date: "26 Sep 2026", title: "Two bugs from your screenshots",
                fixed: ["Whose it is showed your name once for every thing you own. Each person now appears once.",
                        "A row on a trip could keep showing \u{201C}not ticked\u{201D} while the trip had it ticked. Rows now redraw whenever their tick changes."]),
        Release(version: "0.21", date: "26 Sep 2026", title: "Dates like Booking, Today, bag headings",
                new: ["Create new trip: one date field and a month grid. Tap the first day, then the last. Two months side by side on the Mac.",
                      "Care calendar: Today, back to this month with today picked."],
                changed: ["Your bags: MAX KG · LITRES · EMPTY G stay at the top while the bags scroll."],
                removed: ["The two separate From and To date wheels."]),
        Release(version: "0.20", date: "26 Sep 2026", title: "Into and From where",
                new: ["From where: a trip sorted by where each thing is kept at home, so you can empty one cupboard at a time."],
                changed: ["Where is now called Into: the bag a thing goes into.",
                          "On a narrow screen the sorting buttons get a little slimmer so all four fit on one line."]),
        Release(version: "0.19", date: "25 Sep 2026", title: "Sorting",
                changed: ["On a trip, \u{201C}Sorting\u{201D} stands to the left of its buttons, on the same line."]),
        Release(version: "0.18", date: "25 Sep 2026", title: "The maintenance calendar",
                new: ["Care: List or Calendar. Each service sits on the day it falls due, coloured red, orange or green; tap a day to see what is due, with Done today.",
                      "\u{201C}N overdue · show in List\u{201D} above the grid."]),
        Release(version: "0.17", date: "25 Sep 2026", title: "Containers",
                new: ["Care → Containers: your bags, each with its max weight, litres and empty weight.",
                      "A Bags card on every trip: how full each bag is, red when over."],
                fixed: ["Choosing a list in Search opens it."],
                removed: ["The Containers shelf on Your lists (it lives in Care now)."]),
        Release(version: "0.16", date: "25 Sep 2026", title: "Search, list edits, your year",
                new: ["Search: the magnifier on Home, Trips, Your lists, Care and Actions finds things, lists, trips and to-dos.",
                      "Rename a list where its name is written; delete one (it asks first; your things stay).",
                      "Trips: Your year, month by month."],
                changed: ["Grab Lists, bigger suns, \u{201C}Create new trip\u{201D}, Dates and Quick on one line, short food words, group codes (GA, WET).",
                          "This Device down the side, Trips first. The tab is called Trips.",
                          "Reviewed trips fold away; thicker progress lines.",
                          "Greyed-out buttons can be read in daylight."],
                removed: ["The hint line under Create Event."]),
        Release(version: "0.15", date: "25 Sep 2026", title: "A list of your own",
                new: ["Your lists → + New: name a list and choose its shelf."]),
        Release(version: "0.14", date: "24 Sep 2026", title: "How many and Section, per list",
                changed: ["How many and Section belong to each list, as in the web app, not to the thing."]),
        Release(version: "0.13", date: "24 Sep 2026", title: "Colour is the message",
                changed: ["A ticked box is filled with colour."],
                removed: ["The mark inside a ticked box."]),
        Release(version: "0.12", date: "24 Sep 2026", title: "Change all",
                new: ["All your things: tick several, Change all, one answer for all of them, and Undo puts them back."]),
        Release(version: "0.11", date: "24 Sep 2026", title: "A real spreadsheet",
                new: ["All your things is a spreadsheet: sort, filter chips, choose and order the columns."]),
        Release(version: "0.10", date: "23 Sep 2026", title: "The table reads",
                changed: ["Places shown in full; cards quiet but visible."]),
        Release(version: "0.9", date: "23 Sep 2026", title: "The web app's look",
                new: ["Coloured headings, lists two across, and the table of all your things."]),
        Release(version: "0.8", date: "23 Sep 2026", title: "What your kit adds up to",
                new: ["Care: how many things, the total weight, the heavy end, and where it all lives."]),
        Release(version: "0.7", date: "23 Sep 2026", title: "More grab lists",
                new: ["Grab lists: things you take only sometimes.", "More than six grab lists; Home holds your six."]),
        Release(version: "0.6", date: "23 Sep 2026", title: "Where a trip stands",
                new: ["A trip says when everything is packed.", "Trips: Planned, Packing or Ready on every trip.",
                      "Your lists show how they are used."]),
        Release(version: "0.5", date: "23 Sep 2026", title: "Worth a look",
                new: ["Settings says when something in the library looks wrong."]),
        Release(version: "0.4", date: "23 Sep 2026", title: "Weather",
                new: ["A trip's weather for its place, and only the rain or cold gear you have not packed, each with a +."]),
        Release(version: "0.3", date: "23 Sep 2026", title: "Your lists, restore, the buy list",
                new: ["Settings → Your lists: storage places, owners, packers, conditions and \u{201C}When\u{201D} steps.",
                      "Restore from a backup file; a copy of what was here is kept first, and you can go back to it.",
                      "Actions has two sides: To do and To buy, with things worth buying suggested."]),
        Release(version: "0.2", date: "22 Sep 2026", title: "The app does the job",
                new: ["Your library on iPhone and Mac, kept in step through iCloud.",
                      "Home builds a trip; six grab lists.", "Packing: tap to tick, ⊘ not this time, When / Where / Category.",
                      "Things typed while packing join the trip.", "Care, Your things, the trip review, To do.",
                      "Edit a list and a thing; lists read in their sections.", "A backup with a real Save window."]),
        Release(version: "0.1", date: "21 Sep 2026", title: "The app exists",
                new: ["One app for the iPhone and the Mac."]),
    ]
}
