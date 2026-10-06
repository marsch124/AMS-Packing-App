import SwiftUI

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
            "Grab and go: eight grab lists, four in a row, for a quick outing. Tap one, then tick what is in your hand. The count stays at the top while you scroll; Ready to go too early says Not yet in the middle of the screen, with what is missing. Ticks clear themselves 6 hours after your last tap.",
            "Grab Lists, at the top: the ones on Home (up to eight), in your order, and the ones waiting, each with everything on it. Make a new one at the bottom: it goes onto Home if there is room; then open it and press Edit to put things on it. Off Home sends a list to wait until you put it back. Tap a waiting one to open it; On Home puts it on Home \u{2014} when Home is full, you pick which one steps back. Make refuses a name you already use.",
            "Your own grab lists: Edit works as on the others (things, \u{25B2}\u{25BC}, 1 in 10). At the bottom of Edit, Delete grab list removes it after asking. The six that come with the app cannot be deleted, only taken off Home.",
            "Under the grab lists: the countdown to your next trip \u{2014} the days, the trip, and the next packing step with when it is due. Tap it to open the trip.",
            "Create new trip: a name, Dates (tap the first day, then the last; the line under the calendar says the range and the nights; OK keeps it, Cancel puts the dates back), Quick if only the templates you tick should come along — it says so in green while it is on.",
            "Create trip is always ready: if a name or a template is missing, it says so right under it.",
            "So is every button that takes what you typed \u{2014} Add, New, Make, Weather: pressed with an empty field it adds nothing, and a short red line under the field says what is missing. The line goes as soon as you type.",
            "Pick the templates, then Transport, Season and Food, and Create trip. The trip gathers everything those templates hold. The workouts have their own colours (Swim blue, Bike yellow, Run green, Strength orange, Breath work lavender, Mobility pink), and picking one brings Context (Indoor, Outdoor, Race) set in under them. Templates without an activity area come last, under Other templates.",
            "Laundry: wash and wear again, so per-night things count only the nights you pack for before a wash — 4 unless you pick 3, 5, 7, 10 or 14 under the switch (Trip settings has it too). It shows as \u{00D7}4 \u{00B7} laundry with a washtub.",
            "This Device: how many trips, things and templates this device holds."]),
        Topic(section: .events, title: "Packing a trip", lines: [
            "Tap a line to tick it; tap again to take it back. The round button by a heading ticks the whole section.",
            "Check before you go, at the top when something needs you: on a plane trip, what in a cabin bag is not allowed on board (red) or is a liquid (orange: 100 ml at most, in the clear bag); and what runs out before you are home \u{2014} a passport or ID card (Documents & money) six months ahead. Tap a line to open the thing and put it right.",
            "The pen beside the count: Trip settings. Change the name, dates, place, templates, Quick, Context, transport, season, food, laundry or Pack weather gear anyway; Save rebuilds the list, and what you ticked, added yourself or were sent stays. A swipe down closes it only when nothing is changed.",
            "At the bottom of Trip settings: Start a new trip from this one. The same list as it ended up, nothing ticked, no dates.",
            "Near the end of the list: Tick everything, and Clear every tick (it asks first). Lines set aside stay out of both.",
            "Save as Excel and Share, side by side near the end of the list. Excel: the trip as a spreadsheet, by When and bag, with From where, Into, Category, how many and what is packed. Share: the trip as a link (and a QR code when it is short enough) that opens in the web app and in this one, or as a file.",
            "The arrow before a section's name folds it away; tap it again to open. A trip remembers its folds.",
            "⊘ means not this time: it stays on the list, is not packed \u{2014} any tick goes \u{2014} and leaves the count. ↻ brings it back, unticked.",
            "Sorting, one drop-down: When (by the packing timeline), Into (by bag), From where (by where it is kept at home), Category, Section (under the sections of your templates).",
            "Weather: type the place; you get one line and only the rain or cold gear you have not packed yet, each with a +, and Add all when there are several.",
            "Tap a bag on a trip for Goes in the cabin: switched on, a plane trip checks that bag for liquids and things not allowed on board. A bag that was only a name on your lines becomes one of your Bags.",
            "Bags: how full each bag is against its max weight; the ⓘ explains the colours (blue fine, orange close, red over). Tap a bag to type what the luggage scale says \u{2014} from then on that is its weight; Clear takes it away \u{2014} and up to three photos of it packed, kept with the trip; each has its own Remove. A bag with nothing weighed yet says Tap to weigh.",
            "Sorted From where, Set place gives a thing under \u{201C}No place set\u{201D} its place in two taps.",
            "Type a thing at the bottom to add it to this trip only. Bought it on site? Press Bought on site: it goes on ticked, marked so.",
            "At the very end of the list, Delete trip asks first, then removes the trip. Your things and templates stay.",
            "A trip someone sent you arrives Quick: tick one of your templates to add to it, or switch Quick off to bring your always-packed things. Sharing a trip sends just the list \u{2014} your marks, notes and scale readings stay with you."]),
        Topic(section: .events, title: "On site", lines: [
            "On site is the step after Pack: the trip's On site door appears once the trip has begun, or as soon as something is bought on site. Its line says what it holds \u{2014} 2 bought \u{00B7} 1 left \u{00B7} 3 notes \u{00B7} home 4/9.",
            "Bought on site: what you bought while away. Type it and press Bought on site \u{2014} it goes on the list ticked, marked so, and comes home with you.",
            "Left on site: what was used up or stays behind; it does not come home. Leave something here picks it from what went (type to find it); Undo brings it back.",
            "Maintenance notes: a note per thing \u{2014} \u{201C}zip broken\u{201D}, \u{201C}wash before next trip\u{201D}. Add a note picks the thing; Change rewrites it. The note also goes onto the thing itself, dated (On site 3 Oct 2026: zip broken), so Care has it after the trip.",
            "Pack to go home: what went (ticked on the way out) and what you bought on site, bag by bag, with ticks of its own; the way-out ticks stay for the review.",
            "On the way home, Used up takes a thing off \u{2014} the same as leaving it on site; the heading counts it. Undo puts it on again.",
            "Search the way home at the top; the \u{2715} empties it. Tick everything ticks all that still comes home; pressed again it clears the ticks.",
            "Note on the way home is the same maintenance note. Open opens the thing to change it; Save or Cancel brings you back where you were.",
            "The photos of every packed bag are at the top of the way home; tap one to see it large, Next steps through them."]),
        Topic(section: .events, title: "After a trip", lines: [
            "Review: tap what you did not use; type what you missed, pick the template it goes onto, and Add it; then Save.",
            "Under a trip's name: where it stands in the loop, Plan · Pack · On site · Review · Refine, the step it is at filled in with the mark of the tab where it is done. Tap it for the whole picture.",
            "Nothing is removed. \u{201C}Didn't use\u{201D} adds to each thing's history; what you missed goes onto a template for next time."]),
        Topic(section: .events, title: "Trips", lines: [
            "Now, Coming up and Done — Now is always there, even when no trip is under way. Each trip says Planned, Packing or Ready.",
            "Reviewed trips fold away. Your year shows when you travel, month by month; All your trips counts everything, ever, with the map of where they went under it.",
            "The pin at the top: Where you have been. A map with a pin per place (a number when you went more than once), a line through your trips oldest first, and a card per place. A trip joins the map as soon as it has a place (in Trip settings or on its weather line), forecast or not."]),
        Topic(section: .templates, title: "Your templates", lines: [
            "Templates are the building blocks of every trip, in their activity areas (GA, WET and so on). The list you pack from is made from them.",
            "Each template has an icon: the one its name suggests, or tap the square on its page to pick from 50 drawn ones (or Letter).",
            "+ New makes a template and asks in which activity area it should live. Open one to rename it, take a thing off with ✕ (it asks first; the thing stays in Your things), and set How many and Section for this template. A blank How many or Note means \u{201C}the same as the thing\u{201D} \u{2014} the grey words show what the thing says.",
            "Find a thing on this template, above the list: type part of a name and only the things that hold those letters stay, each under its heading, with \u{201C}3 of 40\u{201D} beside the field. The \u{2715} shows everything again; adding a thing clears the search so you see it arrive.",
            "Adding: Choose from your things, at the foot of a template — everything you own, grouped as you like, ticked and added in one go, in the order you ticked them. Or type a new thing beside it; one already on the template is not added twice.",
            "In Choose from your things, the arrow before a group folds it; Fold all / Unfold all does every group. A folded group says how many things it holds and how many you ticked. A search opens them all while you type.",
            "On a row, Bag, When and Section are drop-downs: tap one, tap your choice. A new section is made at the foot of Section.",
            "Group, at the top of a template: its sections, When, Into, From where, Kind or A–Z.",
            "Delete template asks first. Your things stay. Beside it, Activity area moves the template to GA, WET, OE or none.",
            "Arrange, under Group (while it groups by Section): hold \u{2261} and drag a heading \u{2014} its things come along \u{2014} or a thing to its place, under any heading. Tap a heading's name to rename it, or Remove heading (its things stay). Tap Arrange again, or press Escape, when done. New trips pack in the new order.",
            "Share, at the top of a template: a link and a QR code. A grab list has Share at its top too.",
            "Refine (the violet card under the heading): after two or more reviewed trips, what a template carries for nothing. Keep settles it; Drop takes it off that one template."]),
        Topic(section: .care, title: "Care", lines: [
            "Your things: every thing you own; open one to change it, put it on a template, or delete it (it asks first). A change reaches the trips still ahead, on the lines you have not ticked yet. A name you already have is not added again.",
            "A thing you add in Your things stays at the top, under Just added, until you leave the screen. The \u{2715} in any search field empties it.",
            "On a thing's page: On a plane (Liquid, Not allowed in the cabin) and Valid until \u{2014} what a trip's Check before you go reads. Under the date: how far away it is (red once it has run out); +1 month \u{2026} +10 years sets it in one tap.",
            "A thing's page reads: Name, Notes, Kind of thing, Whose it is, On these templates, Kept at home, Usually packed in, When, then Weight, Brand, Colour, Condition, Care, On a plane and Valid until.",
            "Kind of thing, Whose it is, Kept at home, Usually packed in, When, Condition and Care each open a list: tap your choice. Kept at home lists your places, and a new place made there joins Your choices; Usually packed in offers your own bags and No bag.",
            "Under Notes, what your templates say about the thing (change that on the template). Under On these templates, each lit template has its own Section list \u{2014} with A new section at its foot \u{2014} and trips still ahead follow. Care \u{2014} how often, and what to do \u{2014} then shows on Care, where Done today moves it on.",
            "Bags: your bags with max weight, litres and empty weight. Tap a bag's name for its own page: rename it, say whether it goes in the cabin, see what usually goes in it and its trips, or delete it (its things move to a bag you choose).",
            "All your things · table: a spreadsheet. Sort, filter, choose columns; tick several and Change all: the line under it says what changed, and Undo puts back just that. If a search or filter hides some ticked things, the bar says how many. On the Mac it is a window of its own: drag it as wide as you like, or make it full screen.",
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
            "iCloud sync: when this device last sent and received, and what is not in iCloud yet. Sync now checks in from here; the other device shows it within a minute or so \u{2014} if it does not, the card says why. Copy details for Claude gives me the full story. \u{201C}Can't tell\u{201D} means this device cannot check right now \u{2014} not that something is wrong.",
            "Save a backup to a file, or restore from one. Before a restore, a copy of what was here is kept, and you can go back to it. A backup holds every thing exactly as it is on this device, so Restore puts back exactly that \u{2014} cabin answers and notes included. Under Save a backup: when you last saved one on this device; This device holds says when your library came from a backup file.",
            "Your first real trip in 6 steps has its own door in Settings, to read again any time.",
            "Your choices: storage places, owners, packers, conditions and the \u{201C}When\u{201D} steps. The pen beside an entry renames it \u{2014} everything that said the old name follows \u{2014} and its arrows move it up or down; owners always stay A to Z \u{2014} and if you never made an Owners list, it shows the names your things already carry. A name you already have is not added again, and something still in use cannot be removed: the reason appears right under it.",
            "Worth a look appears only when something in the library seems wrong. Where it can, it puts it right in one press \u{2014} a photo left behind by a deleted trip has Remove it; a photo with no date that nothing shows is listed on its own and goes only when you press Remove.",
            "Open a shared link: paste a link or code from the web app or this one. A trip arrives unticked; a template links to things you already have without changing them \u{2014} with a name you already have, it asks for one of its own, or Replace takes the shared things into yours and keeps your look, sections and bags (it says first what comes in and leaves); a grab list takes a free place on Home, or waits in Grab Lists when Home is full."]),
        Topic(section: .home, title: "Shortcuts and the Action button", lines: [
            "Packing offers three actions to Shortcuts and the Action button: Choose a grab list (a menu of them all, every time), Open a grab list (always the same one) and Open my next trip.",
            "The Action button: iPhone Settings \u{2192} Action Button \u{2192} swipe to Shortcut \u{2192} Choose a Shortcut \u{2192} Packing \u{2192} Choose a grab list. Press it: your grab lists appear; tap the one for today.",
            "If Packing is not in the list there: open Packing once, then look again.",
            "Or add the Shortcut to the Home Screen, or say \u{201C}Open Swim in Packing\u{201D} to Siri."]),
        Topic(section: .settings, title: "iPhone and Mac", lines: [
            "Both hold the same library through iCloud. A change on one reaches the other within a minute or so.",
            "The magnifier at the top of most screens searches everything at once.",
            "On the Mac, Escape closes the window you are in, as its Cancel (or Done) does \u{2014} it never saves. The All your things window closes with Done or \u{2318}W."]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            GuideHeader(title: "How it works")
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
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
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
    static let steps: [(title: String, says: String)] = [
        ("Save a backup", "Settings → Save a backup. Do it again once the trip is set up — your safety net."),
        ("Tidy your things", "Care → All your things · table: the No weight and No place chips find what is missing. Weights make the bag bars honest; places make From where one walk through the house."),
        ("Build your templates", "One per activity or need (Beach, Long stay…). On a template: Choose from your things, or type a new one. Tap a thing there for Only on some trips."),
        ("Create the trip", "Home → Create new trip: name, Dates, the templates, Transport, Season, Food, Laundry and its nights. Then the pen: type the Place — the map pin and the weather follow."),
        ("Pack", "Sorting: When for the timeline, From where to fetch room by room, Into to fill each bag. ⊘ is not this time. Watch the bag bars, and Check before you go when it shows. Settings \u{2192} Remind me to pack tells you when each step is due."),
        ("Go, use, review", "On site, the trip's On site page keeps what you buy, leave and note, and packs you home; the grab lists on Home are for each outing. Back home: Review — tap what you did not use, add what you missed. Refine learns from it."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your first real trip in 6 steps").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
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

