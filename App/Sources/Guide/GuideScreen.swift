import SwiftUI
import PackingCore
import PackingLibrary

/// The doors in Settings: What's new and How it works — his standing rule from the
/// web apps, missing here until 0.23 — and the first real trip in six steps, which
/// they asked to keep where they can read it again (field test, 3 Oct 2026:
/// "Please save this in the app … so that we can choose to read that later as
/// well"). They own their sheet, so Settings keeps the sheets it already has
/// (several sheets on one view is a trap met in Search).
struct GuideDoors: View {
    enum Page: String, Identifiable { case whatsNew, howItWorks, firstTrip; var id: String { rawValue } }
    @State private var page: Page?

    var body: some View {
        // Rows of one card in Settings, a hairline between them (0.67; until then each
        // door was a card of its own, 10 points from the next).
        VStack(spacing: 0) {
            door("What's new", Releases.all.first.map { "\($0.version) · \($0.title)" } ?? "", "settings-whatsnew") { page = .whatsNew }
            CardHairline()
            door("How it works", "The whole app in plain words, screen by screen", "settings-howitworks") { page = .howItWorks }
            CardHairline()
            door("Your first real trip", "In 6 steps, from a backup to the review", "settings-firsttrip") { page = .firstTrip }
        }
        .sheet(item: $page) { p in
            switch p {
            case .whatsNew: WhatsNewScreen()
            case .howItWorks: HowItWorksScreen()
            case .firstTrip: FirstTripScreen()
            }
        }
    }

    private func door(_ title: String, _ line: String, _ id: String, _ open: @escaping () -> Void) -> some View {
        Button(action: open) {
            SettingsDoorLabel(title: title, line: line)
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }
}

/// A sheet's top line: the title in the section's colour, and Done.
private struct GuideHeader: View {
    let title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HStack {
            Text(title).font(.system(.title3, weight: .bold)).foregroundStyle(AppSection.settings.color)
                .accessibilityIdentifier("guide-title")
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(HeaderButtonStyle(tint: AppSection.settings.color, filled: true)).focusEffectDisabled()
                .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.settings.color)
                .keyboardShortcut(.cancelAction)            // Escape closes it, as Done does (Escape everywhere, 5 Oct 2026)
                .accessibilityIdentifier("guide-done")
        }
        .padding(16)
    }
}

/// Every version, newest first: what was added, changed, fixed and removed.
struct WhatsNewScreen: View {
    var body: some View {
        let here = AppInfo.marketing
        VStack(spacing: 0) {
            GuideHeader(title: "What's new")
            KeyboardAwayScroll {
                // Every card built at once (a plain VStack, 0.62): the newest entry can be
                // longer than the screen, and a lazy list then left the next card unbuilt —
                // on the Mac no scroll in the test reached it. Sixty-odd text cards are light.
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(Releases.all.enumerated()), id: \.element.id) { n, r in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(r.version).font(.system(.title3, weight: .bold).monospacedDigit())
                                    .foregroundStyle(AppSection.settings.color)
                                    .accessibilityIdentifier("guide-release-\(n)-version")
                                Text(r.title).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                                Spacer(minLength: 6)
                                if r.version == here {
                                    Text("On this device").font(.system(.caption, weight: .semibold))
                                        .foregroundStyle(AppSection.events.color)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .overlay(Capsule().stroke(AppSection.events.color, lineWidth: 1.2))
                                }
                            }
                            Text(r.date).font(.system(.footnote)).foregroundStyle(Theme.muted)
                            kind("New", r.new, AppSection.events.color)
                            kind("Changed", r.changed, AppSection.home.color)
                            kind("Fixed", r.fixed, AppSection.care.color)
                            kind("Removed", r.removed, Theme.muted)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("guide-release-\(n)")
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-whatsnew")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }

    @ViewBuilder private func kind(_ label: String, _ lines: [String], _ tint: Color) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased()).font(.system(.caption, weight: .semibold)).kerning(0.6).foregroundStyle(tint)
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(tint).frame(width: 6, height: 6).offset(y: -2)
                        Text(line).font(.system(.callout)).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// The whole app in plain words, one screen at a time, with each tab's own mark.
struct HowItWorksScreen: View {
    struct Topic { let section: AppSection; let title: String; let lines: [String] }

    static let topics: [Topic] = [
        Topic(section: .home, title: "Home", lines: [
            "Grab and go, Home\u{2019}s first frame: its heading with Grab Lists at the right (and on the iPhone the search; the Mac\u{2019}s search is at the top of the window), then eight grab lists, four in a row, for a quick outing. Tap one, then tick what is in your hand. Your own small grey headings group it: in Edit, hold a thing (right-click on the Mac) and choose Heading above \u{2014} a heading goes in right above it, ready for its name (one left without a name is dropped on Save); or type one in A new heading and press Add \u{2014} it goes last; hold a heading\u{2019}s grip \u{2261} and drag it (on the Mac \u{25B2}\u{25BC} too) to its place. A thing belongs to the heading above it, so move things under the heading you want. Tap a heading\u{2019}s name to change it; \u{2715} removes it, and its things stay, joining what is above. Headings are never ticked or counted; a list without them stays one plain list. Beside each heading a small ring fills as its things are ticked; once everything under it is in hand (a thing left behind with \u{2298} counts too), the heading turns green with a check and folds to that one line, so you scroll less at the door. Tap a folded heading to open it again; untick a thing under it and it stays open until everything is in hand again. Start over opens them all. The count stays at the top while you scroll; Ready to go too early says Not yet in the middle of the screen, with what is missing. Ticks clear themselves 6 hours after your last tap.",
            "Grab Lists, at the right of Grab and go: the ones on Home (up to eight), in your order \u{2014} hold a list\u{2019}s grip \u{2261} and drag it to change it \u{2014} and the ones waiting, each with everything on it. Make a new one at the bottom: it goes onto Home if there is room; then open it and press Edit to put things on it. Off Home sends a list to wait until you put it back. Tap a waiting one to open it; On Home puts it on Home \u{2014} when Home is full, you pick which one steps back. Make refuses a name you already use.",
            "Your own grab lists: Edit works as on the others (things \u{2014} hold a thing\u{2019}s grip \u{2261} and drag it to its place, on the Mac \u{25B2}\u{25BC} too \u{2014}, headings, and 1 in 10). At the bottom of Edit, Delete grab list removes it after asking. The six that come with the app cannot be deleted, only taken off Home.",
            "Under the grab lists: the countdown to your next trip \u{2014} the days, the trip, and the next packing step with when it is due; until you start packing it, also what to buy and get ready (Before you start: 2 to buy, 3 to prepare). Tap it to open the trip.",
            "Right under it (under Grab and go when no trip is ahead), This Device: how many trips, things and templates this device holds.",
            "Create new trip, in a frame of its own with its heading at the top: a name, then Full trip or Quick (as wide as the name) \u{2014} Quick packs only the templates you tick \u{2014} not your Always packed templates, no Plane or RV template; picking Plane still turns on the airport checks (the line under it names your Always packed templates). Then the dates, in the calendar that is always open: tap the first day, then the last \u{2014} that is all. The line under it says the range and the nights; Clear dates beside it leaves the trip without any. No day tapped = no dates. (In Trip settings, tap the dates to open the calendar; OK keeps them, Cancel puts them back.)",
            "Create trip is always ready: if a name or the trip's last day is missing, it says so right under it. A Full trip needs no template ticked when Always packed has something for it \u{2014} a short trip can be your always-packed things alone. Only when there would be nothing to pack at all does it ask you to pick a template, and says why.",
            "So is every button that takes what you typed \u{2014} Add, New, Make, Weather: pressed with an empty field it adds nothing, and a short red line under the field says what is missing. The line goes as soon as you type.",
            "Travelling by, under the templates: Plane or RV, each with its drawing \u{2014} leave both off for an ordinary trip. One at a time; tap the lit one again to turn it off. The line under them says what each adds: Plane the airport checks (and your plane template, if you have one), RV your RV template by its name.",
            "Flights and stay, on a plane trip only \u{2014} it comes right under Travelling by once Plane is lit: the flight Out and the flight Home (Add a flight puts a connection between them; its \u{2715} takes it away), each with its number, its day and from \u{2192} to; the destination; and where you stay \u{2014} hotel or flat, address, phone, and until when. A day you leave alone is the trip\u{2019}s first (Out) or last (Home). All of it is optional: it is what the airline\u{2019}s desk asks when a bag does not arrive. Trip settings has the same block; Plane off keeps what you typed, out of sight. Start a new trip from this one leaves it behind; a trip you share takes the flights and the stay along, not your bags\u{2019} tag numbers.",
            "More choices, under Travelling by, folds Season, Food and Laundry away; while it is closed, one line says what is picked (\u{201C}Summer \u{00B7} Mix \u{00B7} No laundry\u{201D}) \u{2014} tap it to open. Summer and Winter carry the sun and the snowflake, as Plane and RV carry theirs; Food is Self-sufficient, Eating out or Mix. Season follows the dates: a first day from November to March makes it Winter, any other month Summer, until you pick one yourself. Your device remembers whether More choices is open.",
            "Pick the templates, Travelling by and More choices, and Create trip. The trip gathers everything those templates hold. A template you gave a colour shows it on its pill \u{2014} filled with it once picked, outlined in it until then; the others are violet once picked. The workouts have their own colours (Swim blue, Bike yellow, Run green, Strength orange, Breath work lavender, Mobility pink) until you give one a colour of your own, and each workout you pick gets its own Context line set in under them \u{2014} Indoor, Outdoor or Race for that workout only, so Run can be outdoors and Swim indoors on the same trip. Templates without an activity area come last, under Other Templates.",
            "Laundry: wash and wear again, so per-night things count only the nights you pack for before a wash — 4 unless you pick 3, 5, 7, 10 or 14 under the switch (Trip settings has it too). It shows as \u{00D7}4 \u{00B7} laundry with a washtub."]),
        Topic(section: .events, title: "Packing a trip", lines: [
            "Tap a line to tick it; tap again to take it back. The round button by a heading ticks the whole section \u{2014} or, all ticked, unticks it. For 6 seconds after, just above Add a thing, it says what it did (\u{201C}Ticked 3 in Toiletries\u{201D}) and Undo puts back exactly those ticks. A newer press replaces it.",
            "Green as you go: beside each heading\u{2019}s count a small ring fills green as its lines are ticked \u{2014} whatever the Sorting, folded too. The last one ticked turns it into a green check and the heading green; the round button at the right end still ticks or unticks the whole section.",
            "Under the trip\u{2019}s count, while it is being packed: what is left \u{2014} \u{201C}23 left \u{00B7} 2 to charge \u{00B7} about 25 min\u{201D}, then All packed. The time is your own pace: the app keeps when each line is ticked and takes the middle time between your ticks over your last packings (a pause of more than 10 minutes is a break, not packing). Until it has 20 of them it counts 45 seconds a thing.",
            "A kit is one line: \u{201C}Camp pouch \u{00B7} 3 inside\u{201D}. The arrow beside it shows what is inside; Take out there marks one as out, and the line then says \u{201C}1 missing\u{201D}. A kit you check before each trip shows small ticks and is packed when the last one is ticked. Things inside a kit are never lines of their own: your templates hold the kit.",
            "A bag with pockets: ticking a line shows the bag's pockets in one short row under it, the thing's usual pocket already chosen \u{2014} tap another, or ignore it. The line then says \u{201C}Backpack \u{00B7} Front pocket\u{201D}.",
            "I leave at, the framed block with the door on Create new trip and in Trip settings: a time on the first day, and one on the last for home. 15 minutes before, the iPhone names what is still unticked \u{2014} on the last day, what is not in a bag yet; nothing if all is done. Tap the message: the trip opens on just those lines, and Show all brings the rest. Until the first day\u{2019}s time the trip is still at Pack; from it, On site \u{2014} an open trip turns by itself.",
            "Take a break, the round cup at the end of the count\u{2019}s line while a trip is being packed: how far you have come \u{2014} 41 of 63 packed, each group of your Sorting done (\u{2713}) or how many are left, To charge and To do \u{2014} then Continue when? In an hour, This evening (19:00), Tomorrow (18:00, or the time beside it) or Just pause. A time puts \u{201C}\u{1F392} Back to packing\u{201D} on the iPhone at that moment, with how much is left, and the cup shows when, small beside it (19:00; on another day, Fri 18:00); Add to Calendar \u{2014} filled once a time is chosen \u{2014} puts it in your calendar too \u{2014} nothing is added until you say so. One break per trip: a new choice replaces it, and it goes when the last thing is ticked. Taken on the Mac, it is your iPhone that reminds you.",
            "Where is my \u{2026}? On a trip under way, Search shows where a thing is first: \u{201C}Backpack \u{00B7} Front pocket\u{201D}. Or ask Siri, on the iPhone or the Mac: \u{201C}Where is my charger in Packing?\u{201D} With no trip under way, it says where the thing usually goes. A thing inside a kit names the kit and where the kit is: \u{201C}In the Camp pouch, in the Backpack (front pocket)\u{201D} \u{2014} or that it is taken out of it.",
            "Before you start, at the very top of a trip until you pack the first thing: one door with what to buy and get ready well ahead \u{2014} 2 to buy \u{00B7} 3 to prepare \u{00B7} 4 to charge. Tap it. To buy: the trip\u{2019}s things on your To buy list, needing replacing, running out before you are home, or used up the last time they went \u{2014} tap one to open it. To prepare: the reminders (and Preparations) that fall due before the day you leave, each with its step and day \u{2014} tap one to tick it; its arrow opens the template it comes from. To charge: just the names \u{2014} tick them in Before you go from the day before. Ticking a reminder is not packing: the door stays until the first thing goes in.",
            "Before you go, one card at the top when something needs you, and one number for all that is left: red when something will stop you, orange while anything is left, green All set once nothing is \u{2014} then it folds to one line, and its arrow opens it again. It has up to three parts, each only when it has something:",
            "First what would stop you: on a plane trip, what in a cabin bag is not allowed on board (red) or is a liquid (orange: 100 ml at most, in the clear bag), and anything with a battery in a checked bag (red: carry it in the cabin \u{2014} things inside a kit too); and what runs out before you are home \u{2014} a passport or ID card (Documents & money) six months ahead. Tap a line to open the thing and put it right.",
            "Then To do: your reminders whose step has come, each with the small violet icon of the template it comes from. Tap one to tick it.",
            "Last To charge, from the day before the trip until its last day: everything on the trip with a battery \u{2014} the things inside a kit too (In the Camp pouch) \u{2014} with how many are charged (1 of 2). Tap one once it is charged: a tick of its own, apart from packing \u{2014} charging does not pack it, packing does not charge it. At 20:00 the evening before the trip, the iPhone says \u{201C}Charge tonight\u{201D} with the names not charged yet (four, then how many more) \u{2014} only while something is left to charge; tap it and the trip opens at To charge.",
            "The pen beside the count: Trip settings. Change the name, Full trip or Quick, place, dates (Clear dates in the calendar takes them away), templates, each workout's Context, Plane or RV (Travelling by), Flights and stay on a plane trip, season, food, laundry or Pack weather gear anyway \u{2014} all in sight, nothing folded, and new dates there leave the season as it is; Save rebuilds the list, and what you ticked, added yourself or were sent stays. A swipe down closes it only when nothing is changed.",
            "At the bottom of Trip settings: Start a new trip from this one. The same list as it ended up, nothing ticked, no dates.",
            "Last in Trip settings, while something is ticked: Clear every tick (\u{201C}2 of 7 ticked\u{201D}). It asks first; Clear the ticks closes Trip settings \u{2014} anything else changed there is not saved, and it says so \u{2014} and the trip offers Undo for 6 seconds. Lines set aside stay out of it. There is no Tick everything: tick the lines, or a heading\u{2019}s round button.",
            "Save as Excel and Share, side by side near the end of the list. Excel: the trip as a spreadsheet, by When and bag, with From where, Into, Category, how many and what is packed. Share: the trip as a link (and a QR code when it is short enough) that opens in the web app and in this one, or as a file.",
            "The arrow before a section's name folds it away; tap it again to open. A trip remembers its folds.",
            "⊘ means not this time: it stays on the list, is not packed \u{2014} any tick goes \u{2014} and leaves the count. ↻ brings it back, unticked.",
            "A reminder on the list says To do instead of a bag. When its step has come, it shows under To do in Before you go at the top of the trip, with the small violet icon of the template it comes from \u{2014} tap it to tick it \u{2014} and on Home's countdown.",
            "Sorting, one drop-down right above the list: When (by the packing timeline), Into (by bag), From where (by where it is kept at home), Category, Section (under the sections of your templates), Template (under the templates each thing comes from \u{2014} pack Bike, Run or Golf on its own; a thing on two templates shows under both, and one tick ticks it everywhere).",
            "Each line shows the small icon of the template it comes from, just before its bag (up to three; more say +N) \u{2014} violet, or in the colour you gave that template. Hover on the Mac, or VoiceOver, says the names.",
            "Weather: type the place; you get one line and only the rain or cold gear you have not packed yet, each with a +, and Add all when there are several. A forecast reaches about 15 days ahead: a trip further off keeps its place and says from which day its forecast comes. A trip with no dates gets today\u{2019}s weather.",
            "Tap a bag on a trip for Goes in the cabin: switched on, a plane trip checks that bag for liquids and things not allowed on board. A bag that was only a name on your lines becomes one of your Bags.",
            "Bags: folded to one line \u{2014} the total and how many are over \u{2014} until you tap it; it remembers open or closed on this device. Opened: how full each bag is against its max weight; the ⓘ explains the colours (blue fine, orange close, red over). Tap a bag to type what the luggage scale says \u{2014} from then on that is its weight; Clear takes it away \u{2014} and up to three photos of it packed, kept with the trip; each has its own Remove. A bag with nothing weighed yet says Tap to weigh. At its foot, + Add a bag \u{2014} the same as in the Packing Stations\u{2019} Bags out: one of your bags not on the trip yet, or a new one. A bag added with nothing in it says nothing in it yet; its \u{2715} takes it off again. A bag of yours has a round pen at the end of its row: it opens the bag\u{2019}s page to change it while you pack, and Done brings you back to the trip.",
            "Sorted From where, Set place gives a thing under \u{201C}No place set\u{201D} its place in two taps.",
            "Opened from a place\u{2019}s label, the trip shows only what is kept there. Tap the place\u{2019}s name under Sorting to see every line again.",
            "Type a thing at the bottom to add it to this trip only. Bought it on site? Press Bought on site: it goes on ticked, marked so.",
            "At the very end of the list, Delete trip asks first, then removes the trip. Your things and templates stay.",
            "A trip someone sent you arrives Quick: tick one of your templates to add to it, or pick Full trip to bring your always-packed things. Sharing a trip sends just the list \u{2014} your marks, notes and scale readings stay with you."]),
        // Spec 07 part 10 (0.71) — a test version, iPhone only.
        Topic(section: .events, title: "Pack by voice (iPhone, a test)", lines: [
            "Pack by voice, at the end of a trip's Sorting row, walks you through what is still to pack, place by place as From where sorts them. It says the place, then the thing \u{2014} \u{201C}Garage. Goggles.\u{201D} \u{2014} and listens for one of five words.",
            "Packed ticks it. Skip sets it aside for this trip, as \u{2298} does. Later moves on and leaves it unticked. Where says the place again. Stop ends the walk.",
            "It also takes a few other ways of saying them \u{2014} packed it, next, not this time, that\u{2019}s all. At each new place, and after every five things, it says how far you are: \u{201C}Garage done, 12 of 40.\u{201D}",
            "It speaks and listens in English, and understands you on the iPhone itself, without the internet: nothing you say leaves it. AirPods work. The first time, it asks for the microphone and speech recognition; if they are not allowed, the button says where to allow them.",
            "While it runs, a big panel shows the thing and its place, what it said and what it heard, and the five words as buttons \u{2014} a tap does the same as the word. The screen stays on; put Packing away and it stops.",
            "At the end, if you left something for later, it asks \u{201C}once more?\u{201D} \u{2014} say packed (or yes) to go through those again, stop to finish.",
            "A place code you scan starts it by itself, at that place. Don\u{2019}t want that? Switch off \u{201C}Start Pack by voice when a place code opens a trip\u{201D} on the panel.",
            "When it ends: what it did, how often it understood you, how long it took, and each answer. It is a test: it stays only if it understands you at least 9 times in 10 and is quicker than tapping."]),
        Topic(section: .events, title: "On site", lines: [
            "On site is the step after Pack: the trip's On site door appears once the trip has begun \u{2014} on its first day from the time you leave, when I leave at has one \u{2014} or as soon as something is bought on site. Its line says what it holds \u{2014} 2 bought \u{00B7} 1 left \u{00B7} 3 notes \u{00B7} home 4/9.",
            "Bought on site: what you bought while away. Type it and press Bought on site \u{2014} it goes on the list ticked, marked so, and comes home with you.",
            "Left on site: what was used up or stays behind; it does not come home. Leave something here picks it from what went (type to find it); Undo brings it back.",
            "Maintenance notes: a note per thing \u{2014} \u{201C}zip broken\u{201D}, \u{201C}wash before next trip\u{201D}. Add a note picks the thing; Change rewrites it. The note also goes onto the thing itself, dated (On site 3 Oct 2026: zip broken), so Care has it after the trip.",
            "Pack to go home: what went (ticked on the way out) and what you bought on site, bag by bag, with ticks of its own; the way-out ticks stay for the review.",
            "On the way home, Used up takes a thing off \u{2014} the same as leaving it on site; the heading counts it. Undo puts it on again.",
            "Search the way home at the top; the \u{2715} empties it. Tick each thing as it goes into its bag \u{2014} there is no Tick everything here either.",
            "Pockets on the way home too: packing a thing for home shows its bag's pockets, the one it went out in already chosen.",
            "Note on the way home is the same maintenance note. Open opens the thing to change it; Save or Cancel brings you back where you were.",
            "The photos of every packed bag are at the top of the way home; tap one to see it large, Next steps through them."]),
        // Lost luggage, part C (0.80, spec 07 part 18 C): the Lost bag page.
        Topic(section: .events, title: "If a bag goes missing", lines: [
            "Every bag of a trip has a Lost bag page with everything a baggage desk asks for: about you (name, phone, e-mail, home address), the trip (where you are going, where you stay and until when, the flights, the bag-tag number), the bag (type, brand, colour, size, distinctive marks, AirTag), its photos and a few things in it.",
            "Open it with Lost bag? under a bag in the trip\u{2019}s Bags card, under a bag\u{2019}s photos in the Packing Stations, or from Ready, which also says how much of each bag\u{2019}s page is still not filled in. Not in a bag and On body (what you wear) have none \u{2014} no desk can lose them.",
            "Not filled in, in orange, is a tap away from where it is filled in: your details open For the lost-luggage desk, the flights and the stay open Trip settings, the bag\u{2019}s type, brand, colour, size and marks open the bag\u{2019}s page. The bag-tag number is typed right on the page \u{2014} it is on the stub the check-in desk gave you. A missing photo is taken right there too.",
            "With an AirTag in the bag: in Find My, Share Item Location gives the airline a link to where it is.",
            "Share as PDF hands a printable page (and a page of photos) to mail, AirDrop, print or save; Copy as text puts the same words on the clipboard for a web form or a message to the airline.",
            "Your name, phone, e-mail and home address are kept once, in Settings \u{2192} For the lost-luggage desk (or under This is me in Your choices \u{2192} Owners), on both your devices and in your backup. With no full name typed, the owner marked This is me is the name."]),
        Topic(section: .events, title: "After a trip", lines: [
            "Review: the violet button beside Done at the top of a trip, there once the trip has started \u{2014} On site, or after it (a trip with no dates has it all along). Tap what you did not use; type what you missed, pick the template it goes onto, and Add it; then Save.",
            "On the iPhone the review opens with From Apple Health: the workouts of the trip\u{2019}s days, one line per kind (Swim \u{00B7} indoor \u{00B7} 3 times), and No bike for a workout template that had none. Use these marks the workout things: done \u{2192} used, not done or only in the other context (Indoor or Outdoor) \u{2192} didn\u{2019}t use. What you marked yourself, the common base, someone else\u{2019}s things (mark yourself: Your choices \u{2192} Owners, the pen, This is me) and Race-only things stay as they are, and nothing is kept until Save. The app only reads Apple Health, never writes to it. The Mac has no Apple Health, so no block there.",
            "Under a trip's name: where it stands in the loop, Plan · Pack · On site · Review · Refine, the step it is at filled in with its own mark \u{2014} a map, a suitcase with a tick, a pin on a map, a magnifier, a sprout. Tap it for the whole picture.",
            "Nothing is removed. \u{201C}Didn't use\u{201D} adds to each thing's history; what you missed goes onto a template for next time.",
            "Obsidian: a reviewed trip becomes one page in your Obsidian vault, named by its month and name (2026-07 Weekend in the hills), with its weather, bags and their weights and photos, what you did not use, missed, bought on site, and your notes. Sending it again replaces only the app's part \u{2014} what you write above or below it, and your own properties, stay. A page of yours without the app's markers is never overwritten: the app's page goes beside it, as \u{201C}\u{2026} (AMS Packing)\u{201D}.",
            "The Mac writes the page. On the Mac, Send to Obsidian asks once for the folder (your vault's Areas/Travel) and writes at once; Change picks another folder. On the iPhone, Send to Obsidian marks the trip waiting for the Mac, which writes it the next time it is open. Saving a review asks for the page by itself."]),
        Topic(section: .events, title: "Trips", lines: [
            "Now, Coming up and Done — Now is always there, even when no trip is under way. Each trip says Planned, Packing or Ready.",
            "A reviewed trip goes to Done and folds away under Reviewed, whatever its dates. Your year shows when you travel, month by month; All your trips counts everything, ever, with the map of where they went under it.",
            "The pin at the top: Where you have been. A map with a pin per place (a number when you went more than once), a line through your trips oldest first, and a card per place. A trip joins the map as soon as it has a place (in Trip settings or on its weather line), forecast or not."]),
        Topic(section: .templates, title: "Your templates", lines: [
            "Templates are the building blocks of every trip, in their activity areas (GA, WET and so on). The list you pack from is made from them.",
            "The activity areas are yours. Activity areas, the pill at the foot of the Templates tab (after the last area), opens them: + Add makes a new one (only a name \u{2014} no code to type), the pen renames one (its templates follow), hold its grip \u{2261} and drag it to its place (on the Mac its arrows also move it), and Remove takes an empty one away (it asks first). An area that still holds templates stays, and says which; Workout, Exercise & Training always stays, because each workout gets its own Context on a trip. Nothing changes until Save. Templates and Create new trip show your areas in your order, under your names \u{2014} an area shows once a template is in it. Both your devices show the same areas.",
            "Each template has an icon: the one its name suggests (a beach template gets the lounger under its parasol), or tap the square on its page to pick from 132 drawn ones, under Travel, Outdoors, Sport, Beach and summer, City, food and fun, and Everyday (or Letter); the newest close each heading, so the ones you know keep their places. Find an icon, above them, finds one by its name or by other words for it, in English, Swedish or German \u{2014} flyg or airport finds the plane, cykel or Fahrrad the bike \u{2014} each under its heading; the \u{2715} shows them all again. On the Mac \u{2318}F puts the cursor there.",
            "+ New makes a template and asks in which of your activity areas it should live. Open one to rename it, take a thing off with ✕ (it asks first; the thing stays in Your things), and set How many and Section for this template. A blank How many or Note means \u{201C}the same as the thing\u{201D} \u{2014} the grey words show what the thing says.",
            "Reminders, above a template's things: what to DO for this activity (\u{201C}charge the watch\u{201D}). Add a reminder, pick its When, Add. Hold a reminder\u{2019}s grip \u{2261} and drag it to its place. Tap one to rename it, change its When (on the Mac, move it up or down), or Remove it (it asks first). Its When list has your steps\u{2019} pen, grip and Remove, and a new step at its foot \u{2014} each change made at once, as everything on Reminders is (kept by the template\u{2019}s Done, put back by its Cancel). A trip made from the template gets them as lines at their When \u{2014} ticked like the rest, but never in a bag, never weighed and never asked about in the review.",
            "Find a thing on this template, above the list: type part of a name and only the things that hold those letters stay, each under its heading, with \u{201C}3 of 40\u{201D} beside the field. The \u{2715} shows everything again; adding a thing clears the search so you see it arrive.",
            "Adding: Choose from your things, at the foot of a template — everything you own, grouped as you like, ticked and added in one go, in the order you ticked them. Or type a new thing beside it; one already on the template is not added twice.",
            "In Choose from your things, the arrow before a group folds it; Fold all / Unfold all does every group. A folded group says how many things it holds and how many you ticked. A search opens them all while you type.",
            "On a row, Only on some trips shows what the thing itself says (\u{201C}Same as the thing: Winter\u{201D}, the lit pills outlined). Tap a pill to make it this template\u{2019}s own \u{2014} tap the lit Winter off and it comes on every trip from this template; Same as the thing goes back. Season, Context, Transport and Food each on their own. Transport Car means an ordinary trip \u{2014} Plane and RV both off.",
            "On a row, Bag, When and Section are drop-downs: tap one, tap your choice. Each list has its pen and Remove; hold a row\u{2019}s grip \u{2261} and drag it to its place (on the Mac its arrows also move it one step) \u{2014} and a new bag, step or section is made at its foot \u{2014} kept when you press Save.",
            "Group, at the top of a template: its sections, When, Into, From where, Kind or A–Z.",
            "Activity area, above Delete template, is a drop-down: Always packed, your areas, or No activity area (Other Templates). A new area typed at its foot is made and the template goes into it. Always packed comes on every full trip by itself (Quick leaves it out); the others come only when you tick them. A template moved out of Workout, Exercise & Training is no longer a workout: no Context of its own on a trip. Delete template asks first; your things stay. You can have several always-packed templates, or none. A template you move keeps all its things, sections and settings; a trip already made changes only when you save its Trip settings.",
            "Make a small core from this\u{2026}, on a big always-packed template: tick what really comes on every trip (clothes, toiletries and per-night things are ticked to begin with; Tick all per heading), or paste your own list and press Tick these \u{2014} lines indented under a line become a kit holding them. Name it, say where the big one goes, and Make the small core: the small one is always packed from then on, the big one keeps all its things and comes when you tick it. A copy of everything is kept first (Settings, under the restore); Cancel changes nothing.",
            "Counts as, above them, says which Apple Health workout the template meets in a trip\u{2019}s review \u{2014} Swim, Bike, Run, Strength, Mobility & breath, Hiking, Golf, Climbing, Diving, or Nothing. Until you pick, the name decides: Swim counts as Swim, a name that is no workout as Nothing. The always-packed and transport templates have none.",
            "Arrange, under Group (while it groups by Section): hold \u{2261} and drag a heading \u{2014} its things come along \u{2014} or a thing to its place, under any heading. A heading's \u{2261} sits on a lilac patch; a thing's is light grey. Tap a heading's name to rename it, or Remove heading (its things stay). Tap Arrange again, or press Escape, when done. New trips pack in the new order.",
            "Each template has a colour too, so you find it by the colour you connect with it: tap the square on its page, and Colour leads the picker \u{2014} Automatic (the colour the app gave it) or one of fifteen, in two rows: the workout colours (Swim blue, Bike yellow, Run green, Strength orange, Breath work lavender, Mobility pink), then Red, Plum, Violet, Indigo, Navy, Olive, Sand, Brown and Grey. Each swatch shows the square as it will look. A tap chooses and closes; the square wears it on the Templates tab and on the template\u{2019}s page, and its small icon on a trip\u{2019}s lines, and its pill on Create new trip and in Trip settings too. It is kept on both your devices and in your backup.",
            "Share, at the top of a template: a link and a QR code. A grab list has it at the bottom right, under Ready to go: the round button with the share mark.",
            "Refine (the violet card under the heading): after two or more reviewed trips, what a template carries for nothing. Keep settles it; Drop takes it off that one template."]),
        Topic(section: .care, title: "Care", lines: [
            "Your things: every thing you own, with the templates it is on in violet and where it is kept; open one to change it, put it on a template, or delete it (it asks first). A change reaches the trips still ahead, on the lines you have not ticked yet. A name you already have is not added again.",
            "A template that is not there yet: on a thing\u{2019}s page, + New template\u{2026} under On these templates. Name it, pick its activity area (or none \u{2014} Other Templates) and Add the template: it is ticked on the page at once, and made, with the thing on it, when you Save. Cancel the page and no template is made; untick it before Save and it is not made either.",
            "A thing you add in Your things stays at the top, under Just added, until you leave the screen. The \u{2715} in any search field empties it.",
            "Searching Your things also finds words in a thing\u{2019}s notes, and in the notes its templates keep for it: the line that matched shows under the thing.",
            "Photos, on a thing\u{2019}s page under Notes: a photo or two of it \u{2014} Take a photo on the iPhone, Choose a photo from Photos, or Choose a file\u{2026} for a picture kept in a folder or a screenshot (the Files app on the iPhone, an Open window on the Mac \u{2014} where you can also drag a picture from Finder onto the photos). The same three ways take a bag\u{2019}s own photos and the photos of a packed bag on a trip. It is kept the moment you take it; tap it to see it large; Remove asks first. Its first photo shows small at the end of its row in Your things and in Search. A bag\u{2019}s photos on its own page are the same two.",
            "On a thing's page: On a plane (Liquid, Not allowed in the cabin) and Valid until \u{2014} what a trip's Before you go reads. Under the date: how far away it is (red once it has run out); +1 month \u{2026} +10 years sets it in one tap.",
            "Duplicate this thing, near the end of a thing\u{2019}s page above Delete thing \u{2014} for a second charger or a spare cable: the page is saved, then a copy named \u{201C}Charger 2\u{201D} with its details and its templates (on each right after the original, in the same section) \u{2014} not its photos or trips \u{2014} opens at once with the name selected: type the new name, change what differs, Save.",
            "Battery, on a thing's page: Has a battery \u{2014} charge before a trip. A trip then lists it under To charge in Before you go, and Has a battery, beside On no template in Your things, shows only the things with one.",
            "In All your things \u{00B7} table, the Battery column shows the battery mark in the row of each thing that has one; a thing without one has an empty cell. Tap the cell to give a thing a battery or take it away. It sorts, filters and takes Change all like every other column. Hidden in Columns, it stays hidden.",
            "A kit \u{2014} a pouch or a wash bag that stays packed with things in it: on its page, under Weight, Inside lists them; Add from your things puts one in (a thing is in one kit at most, and a kit never goes inside another). Take out marks one as out for now; \u{2715} takes it out for good. Check before each trip makes you tick what is inside before the kit counts as packed \u{2014} a new kit starts with it on; switch it off for a kit you never check, and it stays off. It weighs itself and what is inside, everywhere. A thing inside a kit says so on its page, with Taken out for now.",
            "A thing's page reads: Name, Notes, Photos, Kind of thing, Whose it is, On these templates, Only on some trips, Kept at home, Usually packed in, When, then Weight, Inside, Brand, Colour, Condition, Care, On a plane, Battery and Valid until.",
            "Kind of thing, Whose it is, Kept at home, Usually packed in, When, Condition and Care each open a list: tap your choice. Kept at home lists your places; Usually packed in offers your own bags and No bag. In your own lists, hold a row\u{2019}s grip \u{2261} and drag it to its place (on the Mac the arrows do the same, one step at a time). At the foot of each list (not Care) you make a new one \u{2014} a new place joins Your choices, a new bag Your bags \u{2014} when you press Save.",
            "Under Notes, what your templates say about the thing (change that on the template). Under On these templates, each lit template has its own Section list \u{2014} with A new section at its foot \u{2014} and trips still ahead follow. Care \u{2014} how often, and what to do \u{2014} then shows on Care, where Done today moves it on.",
            "Only on some trips, on a thing\u{2019}s page: Season, Transport and Food (and Context, on a workout template) \u{2014} set once, every template it is on follows. Transport Car there means an ordinary trip \u{2014} Plane and RV both off. A template can still set its own on its row; the page names those (\u{201C}Set on the template instead: Swim (Season)\u{201D}). New trips and Trip settings\u{2019} Save pack by it.",
            "In a Section list, each section has a pen (rename it), arrows (move it up or down in the template) and Remove (it asks first; its things stay on the template, with no section). Nothing changes on the template until you press Save \u{2014} Cancel leaves it as it was.",
            "Kind of thing, Whose it is, Kept at home, Usually packed in, Pocket, When and Condition work the same way: the pen renames an entry and everything that said the old name follows; its grip \u{2261} moves it \u{2014} on the Mac its arrows too (owners always stay A to Z); Remove asks first \u{2014} or, while something still uses the entry, says what does and keeps it. A bag with things in it is removed on its own page: Open the bag. Documents & money and Reminders keep their names (the app reads them). Nothing changes until Save. With nobody named yet, Whose it is still opens: make the first owner at its foot \u{2014} and a bag of yours with no pockets yet has Pocket too, to make its first one there.",
            "On the Mac, a thing's page from the keyboard alone: Tab goes from field to field, every one; in a list, type to pick or Space to open it; on a row of pills (the templates, Only on some trips), \u{2190} \u{2192} move and Space switches one; Return saves (in Notes it starts a new line). \u{2318}N saves and starts the next thing with the same choices, \u{2318}\u{2193} and \u{2318}\u{2191} go to the next or previous thing, \u{2318}J jumps to a field by name. The line at the foot of the page names the keys, and the Thing menu lists them all.",
            "Bags: your bags with max weight, litres and empty weight. Tap a bag's name (the small arrow after it says it opens) for its own page: rename it, say whether it goes in the cabin, see what usually goes in it and its trips, or delete it (its things move to a bag you choose). Numbers typed into the rows are saved when you leave Your bags, open a bag or choose another sort \u{2014} moving from field to field never waits.",
            "Sort, above your bags: Own order \u{2014} your order, the same as in a thing\u{2019}s Usually packed in list: hold a bag\u{2019}s grip \u{2261} and drag it to its place (on the Mac the arrows also move it, one step at a time); A\u{2013}Z, Last used (the newest trip a bag went on \u{2014} one still ahead counts; never used comes last), Last added, or Last edited (the bag you changed most recently first). Under any of those there is no grip: choose Own order to arrange your bags. The sort is remembered on this device. A number you type into a row does not move the row; the list sorts again when you open it.",
            "On a bag's page, Notes come right under its name \u{2014} the same Notes as under Its details, and Search finds the bag by them.",
            "Everything you change on a bag\u{2019}s page \u{2014} its numbers, Notes, the desk\u{2019}s words and pills, the switches and a new name \u{2014} is kept as you go and saved when you leave the page with Done (\u{2318}S on the Mac), or the moment the app goes to the background; Duplicate and Its details save it first. So typing, moving to the next field and scrolling never wait.",
            "Cancel, top left on a bag\u{2019}s page as on a thing\u{2019}s: the page closes and nothing you changed there is kept \u{2014} the pockets go back as they were too. Photos you took stay, as on a thing\u{2019}s page. Escape is Cancel.",
            "Duplicate this bag, near the end of a bag's page: a copy with its sizes, max weight, brand, colour, type, marks, pockets, cabin and AirTag settings and notes \u{2014} not its photos, its trips or what is packed in it \u{2014} named \u{201C}Duffel 2\u{201D} and opened at once with the name selected: type the new name, change the colour, Done. It stands right after the original. Done also keeps a name you typed without pressing Rename.",
            "On a bag's page, Pockets: name them once with Add; type over one to rename it, hold its grip \u{2261} and drag it to its place (on the Mac \u{2303} also moves it up), the red \u{2715} removes it. A thing in one of your bags has Pocket under Usually packed in \u{2014} its usual pocket; a new pocket can be made there too.",
            "On a bag's page, For the lost-luggage desk: what an airline\u{2019}s desk asks when a bag goes missing \u{2014} its brand, colour (type it, or tap a pill: Black \u{2026} Multi), type (Hard case, Soft case, Duffel \u{2026}), size (Cabin, Medium or Large, and its measures) and distinctive marks (a red strap, a sticker), and up to two photos of how the bag looks. Said once, saved when you leave the page; every trip uses it. Brand and colour are the same as under Its details. A pill tapped again is taken off. On a trip, the bag\u{2019}s photo shows small beside it in Bags and the Packing Stations\u{2019}s Photos until it has a photo of it packed.",
            "All your things · table: a spreadsheet. Sort, filter, choose columns (in Columns, hold a column\u{2019}s grip \u{2261} and drag it to its place; on the Mac its arrows also move it); tick several and Change all: the line under it says what changed, and Undo puts back just that. If a search or filter hides some ticked things, the bar says how many. On the Mac it is a window of its own: drag it as wide as you like, or make it full screen.",
            "A column too narrow or too wide: drag the short line at the right edge of its heading \u{2014} Thing too. Each keeps its width on this device; a double tap on the line gives it its own width again.",
            "Filter: every column filters \u{2014} Owner, Packed by, Storage, each template and its sections, and the rest. Open a column and tick the answers your things have (the number says how many). Ticks in one column mean any of them; filtered columns must all hold. A pill above the table shows each filter; its \u{2715} takes it off, Clear takes them all.",
            "Sort: up to three levels \u{2014} Sort by, then by, then by, each \u{25B2} or \u{25BC}. A template sorts by being on it, or by its sections in the template's own order (\u{201C}Travel \u{00B7} section\u{201D}). A blank always goes last. A heading still sorts by its column in one tap.",
            "The arrow beside a thing's name opens the thing itself; Save or Cancel brings you back to the same spot in the table.",
            "Services: List or Calendar. Done today moves a service on; Today brings the calendar back to this month.",
            "Under the services: your things in numbers — how many, the total weight, the heaviest things, where it all lives, what each template weighs, the year ahead, and what is worth knowing."]),
        Topic(section: .actions, title: "To do", lines: [
            "To do: things to sort out before you go.",
            "To buy: what to get, with worn-out or run-down things suggested. Removed a line by mistake? Undo under the list brings it back.",
            "Send to Reminders, at the top of To buy: the open lines go into the Reminders list \u{201C}To buy \u{00B7} Packing\u{201D}, each once, dated the day you send them (all day, no alarm). Tick them there in the shop; they are ticked here as soon as you come back to the app. Tick or remove a line here and its reminder follows; delete a reminder in Reminders and Send offers that line again."]),
        Topic(section: .settings, title: "Settings", lines: [
            "Remind me to pack: on this device, at 9 in the morning of the day each packing step is due, the trip and what is left. Each device asks for itself; under it, the next reminder and what it will say. If the iPhone does not allow the app's notifications, it says so in red, switch on or off \u{2014} allow them in the iPhone's Settings \u{2192} Notifications \u{2192} Packing.",
            "Messages when a trip moves on, under it on the iPhone (on until you switch it off): \u{201C}Have a good trip\u{201D} when a trip sets off \u{2014} at the time you leave on its first day, else at 8 \u{2014} and \u{201C}Welcome home \u{2014} review it in two minutes?\u{201D} at 10 the morning after its last day; tap it and the review opens. The same switch holds \u{201C}Charge tonight\u{201D}, at 20:00 the evening before a trip, while something on it is still to charge. Nothing for a trip with no lines or no dates, or once it is reviewed.",
            "Show my things in Spotlight (on unless you switch it off, each device its own): type a thing\u{2019}s name in Spotlight on the iPhone or the Mac and it shows where the thing is \u{2014} on a trip under way the bag and pocket it is packed in, otherwise where it usually goes and where it is kept at home \u{2014} with its photo. Tap it and its page opens. It is also found by its kind, owner, templates and brand; never by its notes. Nothing shows while the iPhone is locked, and switched off, your things leave Spotlight at once.",
            "iCloud sync: when this device last sent and received, and what is not in iCloud yet. Sync now checks in from here; the other device shows it within a minute or so \u{2014} if it does not, the card says why. Copy details for Claude gives me the full story. \u{201C}Can't tell\u{201D} means this device cannot check right now \u{2014} not that something is wrong.",
            "Save a backup to a file, or restore from one. Before a restore, a copy of what was here is kept, and you can go back to it. A backup holds every thing exactly as it is on this device, so Restore puts back exactly that \u{2014} cabin answers and notes included. Under Save a backup: when you last saved one on this device; This device holds says when your library came from a backup file.",
            "Your first real trip in 6 steps has its own door in Settings, to read again any time.",
            "How it works has a search field at its top: type a word and only what says it shows \u{2014} each paragraph under its part, with the word marked, and at the top how many places say it (\u{201C}4 places\u{201D}). Capitals and accents do not count; a part whose heading alone says it shows whole. The \u{2715} brings the whole guide back, where you were reading. On the Mac \u{2318}F puts the cursor in the field, and Escape empties it.",
            "Your choices: storage places, owners, packers, conditions and the \u{201C}When\u{201D} steps. The pen beside an entry renames it \u{2014} everything that said the old name follows \u{2014} hold the grip \u{2261} at its left and drag it to its place (on the Mac the pen\u{2019}s arrows also move it up or down); owners always stay A to Z \u{2014} and if you never made an Owners list, it shows the names your things already carry. A name you already have is not added again, and something still in use cannot be removed: the reason appears right under it.",
            "Each storage place has a square code. Tap the square beside a place: its label for the P-touch (12 mm tape) \u{2014} on the iPhone Share, then Save Image, and Brother\u{2019}s app takes it from Photos; on the Mac it is saved as a picture. Labels for P-touch, all places, makes them all at once. Stick the label where the things are kept.",
            "Point the iPhone\u{2019}s Camera at a place\u{2019}s label and tap the link: packing for a trip, the trip opens with only what to take from there; back from a trip, what goes back there; otherwise, everything kept there. On the Mac, Open on the place\u{2019}s page shows the same.",
            "Worth a look appears only when something in the library seems wrong. Where it can, it puts it right in one press \u{2014} a photo left behind by a deleted trip has Remove it; a photo with no date that nothing shows is listed on its own and goes only when you press Remove.",
            "Open a shared link: paste a link or code from the web app or this one. A trip arrives unticked; a template links to things you already have without changing them \u{2014} with a name you already have, it asks for one of its own, or Replace takes the shared things into yours and keeps your look, sections and bags (it says first what comes in and leaves); a grab list takes a free place on Home, or waits in Grab Lists when Home is full."]),
        Topic(section: .home, title: "Shortcuts and the Action button", lines: [
            "Packing offers four actions to Shortcuts and the Action button: Choose a grab list (a menu of them all, every time), Open a grab list (always the same one), Open my next trip, and Where is my thing? \u{2014} it answers with the bag and pocket, and opens nothing.",
            "The Action button: iPhone Settings \u{2192} Action Button \u{2192} swipe to Shortcut \u{2192} Choose a Shortcut \u{2192} Packing \u{2192} Choose a grab list. Press it: your grab lists appear; tap the one for today.",
            "If Packing is not in the list there: open Packing once, then look again.",
            "Or add the Shortcut to the Home Screen, or say \u{201C}Open Swim in Packing\u{201D} to Siri.",
            "Hold the Packing icon on the Home Screen for the four grab lists you opened last \u{2014} tap one and it opens, ready to tick; on the Mac, right-click Packing in the Dock for all of them."]),
        Topic(section: .settings, title: "iPhone and Mac", lines: [
            "Both hold the same library through iCloud. A change on one reaches the other within a minute or so.",
            "The magnifier at the top of most screens searches everything at once \u{2014} a thing\u{2019}s notes too.",
            "Every page where you change something has Cancel at the top left and Save (or Done) at the top right \u{2014} a thing, a bag, a template and its rows, Trip settings, Your choices, Activity areas, a grab list while you edit it, For the lost-luggage desk. Cancel puts back everything you changed on that page since you opened it; Save or Done keeps it. A swipe down on the iPhone closes a page you changed nothing on; with something changed it asks first \u{2014} Discard changes? \u{2014} Discard puts everything back, Keep editing stays. What one tap does on a list \u{2014} a tick, Done today \u{2014} is done at once.",
            "On the Mac, Escape closes the window you are in, as its Cancel (or Done) does \u{2014} it never saves; \u{2318}S is Save (or Done). The All your things window closes with Done or \u{2318}W."]),
    ]

    /// What is typed in the search field at the top (0.90).
    @State private var query = ""
    @FocusState private var writing: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let searching = !GuideSearch.needle(query).isEmpty
        VStack(spacing: 0) {
            GuideHeader(title: "How it works")
            // Search (0.90, his ask of 19 Oct 2026): the app's search-field look, its ✕ empties it;
            // on the Mac ⌘F puts the cursor in it, and Escape — which a text field keeps for
            // itself — empties it, then closes How it works as Done does.
            TextField("Search How it works", text: $query)
                .textFieldStyle(.plain)
                .font(.system(.body)).foregroundStyle(Theme.ink)
                .focused($writing)
                #if os(macOS)
                .onExitCommand { if query.isEmpty { dismiss() } else { query = "" } }
                #endif
                .clearButton($query, id: "guide-search")
                .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                #if os(macOS)
                .background {
                    Button("Search How it works") { writing = true }
                        .keyboardShortcut("f", modifiers: .command)
                        .opacity(0).accessibilityHidden(true)
                }
                #endif
                .padding(.horizontal, 16).padding(.top, -4).padding(.bottom, 12)
            ZStack(alignment: .top) {
                // The whole guide stays built under a search, only out of sight: emptied, the
                // field gives it back exactly as it was — scrolled to where it was.
                HowItWorksGuide()
                    .opacity(searching ? 0 : 1)
                    .allowsHitTesting(!searching)
                    .accessibilityHidden(searching)
                if searching { GuideSearchResults(query: query) }
            }
        }
        .background(Theme.bg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-howitworks")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }
}

/// How it works itself, every card — a view of its own with nothing to watch, so a key
/// pressed in the search field never builds it again.
private struct HowItWorksGuide: View {
    var body: some View {
        KeyboardAwayScroll {
            VStack(alignment: .leading, spacing: 12) {
                FirstTripCard()
                LoopGuideCard()
                WordsCard()
                ForEach(Array(HowItWorksScreen.topics.enumerated()), id: \.offset) { n, t in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            SectionMark(section: t.section, size: 24, weight: 1.9).foregroundStyle(t.section.color)
                            Text(t.title).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                        }
                        ForEach(t.lines, id: \.self) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Circle().fill(t.section.color).frame(width: 6, height: 6).offset(y: -2)
                                Text(line).font(.system(.callout)).foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("guide-topic-\(n)")
                    // The Packing day's own part, right after packing a trip (0.79, his ask of 13 Oct
                    // 2026: "write about the Packing-Day-Stations in the How-this-works").
                    if t.title == HowItWorksScreen.stationsAfter { PackingDayGuideCard() }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
    }
}

// MARK: - Search in How it works (0.90)

/// One paragraph of How it works as its search reads and shows it: a lead — a step's, a word's
/// or a station's name, set semibold — and the words after it.
struct GuideParagraph {
    let lead: String?
    let text: String
    /// As it is searched and shown: "Kit — All your things together …".
    var said: String { lead.map { "\($0) \u{2014} \(text)" } ?? text }
}

/// One part of How it works — a card — as its search reads it: the heading the card shows, and
/// everything it says, in order.
struct GuidePart {
    enum Kind { case quickstart, loop, words, stations, topic(AppSection) }
    /// The ids' part: "quickstart", "loop", "words", "stations", "topic-<n>" (the topic's
    /// `guide-topic-<n>`).
    let key: String
    let kind: Kind
    let title: String
    let paragraphs: [GuideParagraph]

    /// The dot before each paragraph, and the card's own colour where it has one.
    var tint: Color {
        switch kind {
        case .quickstart: return AppSection.home.color
        case .loop: return AppSection.templates.color
        case .words: return AppSection.settings.color
        case .stations: return Library.LoopStep.pack.tint
        case .topic(let s): return s.color
        }
    }
}

extension HowItWorksScreen {
    /// The Packing Stations card comes right after this topic, in the guide and in its search.
    static let stationsAfter = "Packing a trip"

    /// Everything How it works says, card by card, in the order it says it — read from the
    /// same words the cards show (`FirstTripCard`, `LoopGuideCard`, `LoopWords`, `Words`,
    /// `PackingDayGuideCard`, `topics`), so the search can never miss a sentence the guide has.
    /// Not searched: the loop's picture (its boxes repeat the five steps' words) and the
    /// stations' drawn marks. A new card in How it works joins this list.
    static let parts: [GuidePart] = {
        var out = [
            GuidePart(key: "quickstart", kind: .quickstart, title: FirstTripCard.title,
                      paragraphs: FirstTripCard.steps.enumerated().map {
                          GuideParagraph(lead: "\($0.offset + 1) \u{00B7} \($0.element.title)", text: $0.element.says)
                      }),
            GuidePart(key: "loop", kind: .loop, title: LoopGuideCard.title,
                      paragraphs: [GuideParagraph(lead: nil, text: LoopGuideCard.intro)]
                        + Library.LoopStep.allCases.map { GuideParagraph(lead: $0.name, text: $0.explained) }
                        + [GuideParagraph(lead: nil, text: LoopWords.footer)]),
            GuidePart(key: "words", kind: .words, title: WordsCard.title,
                      paragraphs: Words.all.map { GuideParagraph(lead: $0.term, text: $0.meaning) }),
        ]
        for (n, t) in topics.enumerated() {
            out.append(GuidePart(key: "topic-\(n)", kind: .topic(t.section), title: t.title,
                                 paragraphs: t.lines.map { GuideParagraph(lead: nil, text: $0) }))
            if t.title == stationsAfter {
                out.append(GuidePart(key: "stations", kind: .stations, title: PackingDayGuideCard.title,
                                     paragraphs: [GuideParagraph(lead: nil, text: PackingDayGuideCard.intro)]
                                        + PackingDayStation.allCases.enumerated().map {
                                            GuideParagraph(lead: "\($0.offset + 1) \u{00B7} \($0.element.name)",
                                                           text: PackingDayGuideCard.says($0.element))
                                        }
                                        + PackingDayGuideCard.more.map { GuideParagraph(lead: nil, text: $0) }))
            }
        }
        return out
    }()

    /// The same, as the model's search takes it.
    static let searchParts = parts.map { GuideSearch.Part(title: $0.title, paragraphs: $0.paragraphs.map(\.said)) }
}

/// What How it works says about the words typed (0.90): each card that says them under its own
/// heading, with only its paragraphs that do (a card whose heading alone says them shows whole:
/// it is about them); the words marked. A count line on top ("4 places"); nothing found, one
/// calm line. Container `guide-search-results`.
private struct GuideSearchResults: View {
    let query: String

    var body: some View {
        let found = GuideSearch.find(query, in: HowItWorksScreen.searchParts)
        let needle = GuideSearch.needle(query)
        KeyboardAwayScroll {
            // Lazy: one letter typed can find most of the guide, and only the cards in sight
            // are built — the next key press is not kept waiting.
            LazyVStack(alignment: .leading, spacing: 12) {
                if found.isEmpty {
                    Text("Nothing in How it works says that.")
                        .font(.system(.callout)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("guide-search-none")
                } else {
                    Text(GuideSearch.placesWords(found))
                        .font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("guide-search-count")
                    ForEach(found, id: \.part) { f in
                        GuideHitCard(part: HowItWorksScreen.parts[f.part], found: f, needle: needle)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .background(Theme.bg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-search-results")
    }
}

/// One card the words were found in: its heading as the guide shows it (the topic's mark, the
/// Words' "Aa", the stations' own mark), then the paragraphs, each after a dot in the card's
/// colour. Container `guide-hit-<key>`; heading `guide-hit-<key>-title`; paragraph
/// `guide-hit-<key>-<n>` (n = its place in the card), its value how many places are marked.
private struct GuideHitCard: View {
    let part: GuidePart
    let found: GuideSearch.Found
    let needle: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        let heading = GuideMarks.text(part.title, lead: nil, needle: needle, style: .body, weight: .semibold, dark: dark)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                mark
                Text(heading.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("guide-hit-\(part.key)-title")
                    .accessibilityValue(GuideMarks.value(heading.marks))
            }
            ForEach(found.paragraphs, id: \.self) { n in
                let said = GuideMarks.text(part.paragraphs[n].said, lead: part.paragraphs[n].lead, needle: needle,
                                           style: .callout, weight: .regular, dark: dark)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(part.tint).frame(width: 6, height: 6).offset(y: -2)
                    Text(said.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("guide-hit-\(part.key)-\(n)")
                        .accessibilityValue(GuideMarks.value(said.marks))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ring, lineWidth: ringWidth))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-hit-\(part.key)")
    }

    /// The heading's mark, as the card in the guide wears it (the first-trip and loop cards wear none).
    @ViewBuilder private var mark: some View {
        switch part.kind {
        case .topic(let s):
            SectionMark(section: s, size: 24, weight: 1.9).foregroundStyle(s.color)
        case .words:
            Text("Aa").font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.settings.color)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
        case .stations:
            StationMark(mark: PackingDayStation.dayMark, size: 24).foregroundStyle(Library.LoopStep.pack.words(scheme))
        case .quickstart, .loop:
            EmptyView()
        }
    }

    // The card's look, as in the guide: the first trip's blue, the stations' green ring.
    private var fill: Color {
        if case .quickstart = part.kind { return AppSection.home.color.opacity(0.08) }
        return Theme.card
    }
    private var ring: Color {
        switch part.kind {
        case .quickstart: return AppSection.home.color
        case .stations: return Library.LoopStep.pack.tint.opacity(0.7)
        default: return Theme.line
        }
    }
    private var ringWidth: CGFloat {
        switch part.kind {
        case .quickstart, .stations: return 1.2
        default: return 1
        }
    }
}

/// The words searched for, marked where they stand — semibold, in How it works' own colour (its
/// title's slate), as a found note's line marks them in Search (`NoteHitLine`), on a band of the
/// same slate: on the guide's ink a slate word alone reads lighter, not marked. At night the word
/// keeps the text's own colour on a stronger band — slate words on the dark card read dimmer than
/// the words around them (seen on the first night picture, 19 Oct 2026).
enum GuideMarks {
    static let tint = AppSection.settings.color

    /// `said` in ink, its lead semibold, and every place of `needle` marked; with how many.
    static func text(_ said: String, lead: String?, needle: String, style: Font.TextStyle,
                     weight: Font.Weight, dark: Bool) -> (text: AttributedString, marks: Int) {
        var s = AttributedString(said)
        s.font = .system(style, weight: weight)
        s.foregroundColor = Theme.ink
        if let lead, said.hasPrefix(lead),
           let r = Range(said.startIndex..<said.index(said.startIndex, offsetBy: lead.count), in: s) {
            s[r].font = .system(style, weight: .semibold)
        }
        var marks = 0
        for place in GuideSearch.ranges(of: needle, in: said) {
            guard let r = Range(place, in: s) else { continue }
            s[r].foregroundColor = dark ? Theme.ink : tint
            s[r].font = .system(style, weight: .semibold)
            s[r].backgroundColor = tint.opacity(dark ? 0.55 : 0.16)
            marks += 1
        }
        return (s, marks)
    }

    /// What VoiceOver (and a test) hears after the words: "2 places marked".
    static func value(_ marks: Int) -> String { marks == 1 ? "1 place marked" : "\(marks) places marked" }
}

/// The six steps on a page of their own, opened from Settings — the same card as at
/// the top of How it works, so the two can never say different things.
struct FirstTripScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            GuideHeader(title: "First real trip")
            KeyboardAwayScroll {
                FirstTripCard()
                    .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-firsttrip")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }
}

/// "Your first real trip in 6 steps" — his idea 13 (2 Oct 2026), before his first real trip:
/// the whole app as one path, numbered, at the top of How it works.
struct FirstTripCard: View {
    static let title = "Your first real trip in 6 steps"
    static let steps: [(title: String, says: String)] = [
        ("Save a backup", "Settings → Save a backup. Do it again once the trip is set up — your safety net."),
        ("Tidy your things", "Care → All your things · table: the No weight and No place chips find what is missing. Weights make the bag bars honest; places make From where one walk through the house."),
        ("Build your templates", "One per activity or need (Beach, Long stay…). On a template: Choose from your things, or type a new one. Only on some trips (a winter jacket, say) is set once on the thing's own page; tap a thing on a template to make it different there."),
        ("Create the trip", "Home → Create new trip: name, Dates, the templates, Travelling by (Plane, RV or neither), then More choices: Season, Food, Laundry and its nights. Then the pen: type the Place — the map pin and the weather follow."),
        ("Pack", "Sorting: When for the timeline, From where to fetch room by room, Into to fill each bag. ⊘ is not this time. Watch the bag bars, and Before you go when it shows. Settings \u{2192} Remind me to pack tells you when each step is due."),
        ("Go, use, review", "On site, the trip's On site page keeps what you buy, leave and note, and packs you home; the grab lists on Home are for each outing. Back home: Review — tap what you did not use, add what you missed. Refine learns from it."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(FirstTripCard.title).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                .accessibilityIdentifier("quickstart-title")
            ForEach(Array(FirstTripCard.steps.enumerated()), id: \.offset) { n, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(n + 1)").font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(AppSection.home.color))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text(step.says).font(.system(.callout)).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("quickstart-step-\(n)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.home.color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.home.color, lineWidth: 1.2))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-quickstart")
    }
}

