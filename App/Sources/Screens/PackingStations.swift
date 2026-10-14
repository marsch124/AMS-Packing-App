import SwiftUI
import PackingCore
import PackingLibrary

// Packing Stations (0.81) — his decisions of 14 Oct 2026 on 0.79's Packing day, from the
// screenshots of a Mac trip (spec 07 part 17, "0.81"): the Tags station's happier bag cards with
// "Remind me", Ready's "Add a reminder" (both write a To do on the trip, which shows in Before you
// go), Bags out's "+ Add a bag", and the trip header's own colours. The model of it is
// `PackingLibrary/PackingStations.swift`; the sheet that holds these is `PackingDay.swift`.

// MARK: - The drawings

/// The drawings the Tags station's rows and bag cards wear — the station's own (the Tags mark is
/// a luggage tag and an AirTag side by side), each taken out and centred on the 24-point grid, and
/// the template icons' bags. One 1.9 stroke, no fill, as every mark in the app.
enum StationDrawings {
    /// The luggage tag on its string — the Tags mark's left half, centred.
    static let nameTag = "M7.75 10.5 12 6.5 16.25 10.5V19.5c0 .6-.4 1-1 1H8.75c-.6 0-1-.4-1-1Z M12 10h.01 M12 10c0-3 1.5-5.5 4.5-6 M10.25 15h3.5 M10.25 17.5h2.5"
    /// The AirTag — the Tags mark's round disc and its dot, twice the size, centred.
    static let airTag = "M5 12a7 7 0 1 0 14 0a7 7 0 1 0 -14 0 M12 12h.01"
    /// A bell, for Remind me.
    static let bell = "M6.5 16.5V11a5.5 5.5 0 0 1 11 0v5.5l1.5 2h-14Z M10 20.5a2 2 0 0 0 4 0 M12 4V5.5"
    /// A plus, for Add a bag and Add a reminder.
    static let plus = "M12 5.5v13 M5.5 12h13"
    /// A cross, for taking an added bag off the trip.
    static let cross = "M7 7l10 10 M17 7 7 17"

    /// A bag's own drawing by its name: a backpack for a pack or rucksack, the soft holdall for a
    /// duffel or weekend bag, else the suitcase — the template icons' own.
    static func bag(_ name: String) -> String {
        let n = normName(name)
        let key: String
        if ["pack", "rucksack", "ryggsäck", "ryggsack"].contains(where: { n.contains($0) }) { key = "backpack" }
        else if ["duffel", "duffle", "holdall", "weekend", "sports bag", "gym bag"].contains(where: { n.contains($0) }) { key = "weekendbag" }
        else { key = "suitcase" }
        return TemplateIconCatalog.icon(key)?.path ?? ""
    }
}

/// A drawing in a round badge — the Tags rows' tick (0.81: "the tag and AirTag drawings instead of
/// bare circles"): off, the drawing in the station's green on the card, in a hairline ring; on,
/// the drawing white on the green, as a done station chip.
struct DrawnTick: View {
    let path: String
    let on: Bool
    let tint: Color
    @Environment(\.colorScheme) private var scheme

    #if os(macOS)
    static let size: CGFloat = 20
    #else
    static let size: CGFloat = 26
    #endif

    var body: some View {
        let s = DrawnTick.size
        IconMark(path: path, size: s * 0.72, weight: 2)
            .foregroundStyle(on ? Color.white : Library.LoopStep.pack.words(scheme))
            .frame(width: s, height: s)
            .background(Circle().fill(on ? tint : tint.opacity(0.08)))
            .overlay(Circle().stroke(on ? tint : tint.opacity(0.55), lineWidth: 1.4))
            .accessibilityHidden(true)
    }
}

// MARK: - Tags: one bag

/// One bag in the Tags station (0.81, his decision of 14 Oct 2026 — "a happier, less white look"):
/// a soft green edge down its left side, the bag's drawing by its name; the Name tag and AirTag
/// rows wear the tag's and the AirTag's drawings; done, the card turns a light green with a ✓.
/// Under the rows the bag's tag number on a plane trip (0.80), Has an AirTag, and Remind me — a To
/// do on the trip ("Name tag for the Day pack"), ready to change before it is added.
struct TagsBagCard: View {
    let tripId: String
    let bag: PackingDay.Bag
    let n: Int
    @EnvironmentObject var model: LibraryModel
    @Environment(\.colorScheme) private var scheme
    /// Remind me is open, and what it added (shown under the card until the sheet closes).
    @State private var reminding = false
    @State private var added = ""

    private var tint: Color { AppSection.events.color }

    var body: some View {
        let done = PackingDay.tagsDone(bag)
        let words = Library.LoopStep.pack.words(scheme)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                IconMark(path: StationDrawings.bag(bag.name), size: 20).foregroundStyle(words)
                    .accessibilityHidden(true)
                // The name is the card's heading; "done" a text of its own — a plain text is a text on
                // the iPhone AND the Mac (a combined element's value did not reach the Mac's tree).
                Text(bag.name).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityValue(done ? "done" : "open")
                    .accessibilityIdentifier("day-tag-\(n)-bag")
                Spacer(minLength: 8)
                if done {
                    HStack(spacing: 4) {
                        Tick().stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                            .frame(width: 13, height: 11)
                            .accessibilityHidden(true)
                        Text("done").font(.system(.footnote, weight: .semibold))
                            .accessibilityIdentifier("day-tag-\(n)-done")
                    }
                    .foregroundStyle(words)
                }
            }
            .padding(.bottom, 4)
            row("Name tag", drawing: StationDrawings.nameTag, on: bag.nameTag, id: "day-tag-\(n)-name") {
                let t = tripId, name = bag.name, on = !bag.nameTag
                model.change { _ = $0.setNameTag(on, tripId: t, bag: name) }
            }
            if bag.hasAirTag {
                row("AirTag in it", drawing: StationDrawings.airTag, on: bag.airTag, id: "day-tag-\(n)-air") {
                    let t = tripId, name = bag.name, on = !bag.airTag
                    model.change { _ = $0.setAirTagIn(on, tripId: t, bag: name) }
                }
            }
            // A checked bag of a plane trip (0.80, spec 07 part 18 B): the number on its tag from
            // check-in — a cabin bag gets no tag at the desk.
            if model.library.asksBagTag(tripId: tripId, bag: bag.name) {
                BagTagField(tripId: tripId, bag: bag.name, id: "day-tag-\(n)-number")
                    .padding(.top, 4)
            }
            HStack(alignment: .center, spacing: 8) {
                Toggle(isOn: Binding(get: { bag.hasAirTag },
                                     set: { on in let name = bag.name; model.change { _ = $0.setAirTag(container: name, on) } })) {
                    Text("Has an AirTag").font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                .tint(tint)
                #if os(iOS)
                .controlSize(.mini)
                #else
                .controlSize(.small)
                #endif
                .fixedSize()
                .accessibilityIdentifier("day-tag-\(n)-has")
                Spacer(minLength: 8)
                // Remind me: not on a bag whose every tag is on — nothing left to remember.
                if !done && !reminding {
                    Button { reminding = true; added = "" } label: {
                        HStack(spacing: 4) {
                            IconMark(path: StationDrawings.bell, size: 15, weight: 2)
                            Text("Remind me").font(.system(.footnote, weight: .semibold))
                        }
                        .foregroundStyle(words)
                        .padding(.horizontal, 8).frame(minHeight: Metrics.compact)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("day-tag-\(n)-remind")
                    .accessibilityLabel("Remind me")
                }
            }
            .padding(.top, 4)
            if reminding {
                TripTodoComposer(tripId: tripId, prefill: PackingDay.reminder(for: bag), id: "day-tag-\(n)-remind",
                                 lead: "A To do on this trip \u{2014} it shows in Before you go:",
                                 placeholder: "What to remember") { words in
                    added = words
                    reminding = false
                } cancel: { reminding = false }
                .environmentObject(model)
                .padding(.top, 6)
            }
            if !added.isEmpty {
                TripTodoComposer.said(added, id: "day-tag-\(n)-remind-said", tint: words)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).padding(.leading, 4)
        .background {
            // The soft green edge down the left; done, the whole card a light green.
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12).fill(Theme.card)
                if done { RoundedRectangle(cornerRadius: 12).fill(tint.opacity(scheme == .dark ? 0.20 : 0.12)) }
                RoundedRectangle(cornerRadius: 12).fill(done ? tint : tint.opacity(0.45))
                    .mask(alignment: .leading) { Rectangle().frame(width: 5) }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(done ? tint.opacity(0.65) : Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("day-tag-\(n)")
    }

    /// A tick row: the drawing in its badge, the words, and a ✓ at the right when on.
    private func row(_ title: String, drawing: String, on: Bool, id: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 10) {
                DrawnTick(path: drawing, on: on, tint: tint)
                Text(title).font(.system(.body)).foregroundStyle(Theme.ink).lineLimit(2)
                Spacer(minLength: 8)
                if on {
                    Tick().stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .frame(width: 14, height: 12)
                        .foregroundStyle(Library.LoopStep.pack.words(scheme))
                }
            }
            .padding(.vertical, 3)
            .frame(minHeight: Metrics.line)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityLabel(title)
        .accessibilityValue(on ? "on" : "off")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - A To do on the trip

/// Write a To do on the trip — Tags' Remind me (prefilled "Name tag for …") and Ready's Add a
/// reminder (empty). Add is ALWAYS in full colour (his rule): pressed with nothing written it
/// says so under it. Added, the To do is on the trip's list (a reminder line, due at once) and in
/// Before you go's To do. Ids from `id`: `<id>-text`, `<id>-add`, `<id>-cancel`, `<id>-needs`.
struct TripTodoComposer: View {
    let tripId: String
    let prefill: String
    let id: String
    let lead: String
    let placeholder: String
    let added: (String) -> Void
    let cancel: () -> Void
    @EnvironmentObject var model: LibraryModel
    @State private var text = ""
    @State private var needs = ""
    @State private var loaded = false
    @FocusState private var typing: Bool

    private var tint: Color { AppSection.events.color }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lead).font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    .focused($typing)
                    .onSubmit(add)
                    .accessibilityIdentifier("\(id)-text")
                Button(action: add) { FieldButtonLabel(title: "Add", tint: tint) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("\(id)-add")
                Button("Cancel") { typing = false; cancel() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                    .frame(minHeight: Metrics.tap).contentShape(Rectangle())
                    .accessibilityIdentifier("\(id)-cancel")
            }
            .needsLine($needs, typed: text, id: "\(id)-needs")
        }
        .onAppear {
            guard !loaded else { return }
            text = prefill
            loaded = true
            typing = true
        }
    }

    private func add() {
        switch model.library.tripTodoProblem(tripId: tripId, name: text) {
        case .blank?: needs = "Write what to remember."
        case .alreadyThere?: needs = "That is on this trip\u{2019}s To do already."
        case nil:
            let t = tripId, words = jsTrim(text), today = Today.local
            model.change { _ = $0.addTripTodo(tripId: t, name: words, today: today) }
            typing = false
            added(words)
        }
    }

    /// What was added, in the station's green: "Added to To do: “…” — see Before you go."
    static func said(_ words: String, id: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Tick().stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 13, height: 11)
            Text("Added to To do: \u{201C}\(words)\u{201D} \u{2014} see Before you go.")
                .font(.system(.subheadline, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(tint)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}

/// The small outlined button of a station: a drawn mark and its words, in the station's green —
/// "+ Add a bag", "+ Add a reminder".
struct StationAddLabel: View {
    let title: String
    var mark = StationDrawings.plus
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let tint = AppSection.events.color
        HStack(spacing: 6) {
            IconMark(path: mark, size: 15, weight: 2.2)
            Text(title).font(.system(.subheadline, weight: .semibold)).lineLimit(1).fixedSize()
        }
        .foregroundStyle(Library.LoopStep.pack.words(scheme))
        .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
        .background(Capsule().fill(tint.opacity(0.10)))
        .overlay(Capsule().stroke(tint, lineWidth: 1.2))
        .contentShape(Capsule())
    }
}

// MARK: - Bags out: "+ Add a bag"

/// "+ Add a bag", opened (0.81, his decision of 14 Oct 2026): one of his bags not yet on this trip
/// — a tap puts it on — or a new one: its name, Goes in the cabin (by its name until he says),
/// and its max weight if he likes. Added, the bag is on the trip, empty: Bags out, Weigh, Tags,
/// Photos and the Bags card ask about it. Container `day-addbag-panel`. The SAME panel at the foot
/// of the trip's Bags card (0.83, his report of 14 Oct 2026: he looked for it there), its ids
/// under `bags-addbag` (`prefix`).
struct AddBagPanel: View {
    let tripId: String
    /// The ids' start: "day-addbag" in Bags out, "bags-addbag" on the Bags card.
    var prefix = "day-addbag"
    let close: () -> Void
    @EnvironmentObject var model: LibraryModel
    @Environment(\.colorScheme) private var scheme
    @State private var name = ""
    /// nil = as its name says ("Cabin bag" goes in the cabin), until he switches it.
    @State private var cabin: Bool?
    @State private var maxText = ""
    @State private var needs = ""
    @FocusState private var typing: Bool

    private var tint: Color { AppSection.events.color }

    var body: some View {
        let mine = model.library.bagsToAdd(tripId: tripId)
        let words = Library.LoopStep.pack.words(scheme)
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a bag to this trip").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            if !mine.isEmpty {
                heading("One of your bags")
                VStack(spacing: 0) {
                    ForEach(Array(mine.enumerated()), id: \.element.id) { k, bag in
                        Button {
                            let t = tripId, b = bag.name
                            model.change { _ = $0.addBagToTrip(tripId: t, bag: b) }
                            close()
                        } label: {
                            HStack(spacing: 8) {
                                IconMark(path: StationDrawings.bag(bag.name), size: 18).foregroundStyle(words)
                                Text(bag.name).font(.system(.body)).foregroundStyle(Theme.ink).lineLimit(1)
                                Spacer(minLength: 8)
                                IconMark(path: StationDrawings.plus, size: 15, weight: 2.2).foregroundStyle(words)
                            }
                            .frame(minHeight: Metrics.row)
                            .contentShape(Rectangle())
                            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("\(prefix)-pick-\(k)")
                        .accessibilityLabel("Add \(bag.name)")
                    }
                }
            }
            heading(mine.isEmpty ? "A new bag" : "Or a new one")
            TextField("Its name \u{2014} e.g. Duffel", text: $name)
                .textFieldStyle(.plain)
                .font(.system(.body)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                .focused($typing)
                .onSubmit(addNew)
                .accessibilityIdentifier("\(prefix)-name")
            Toggle(isOn: Binding(get: { cabin ?? Library.cabinByItsName(name) }, set: { cabin = $0 })) {
                Text("Goes in the cabin").font(.system(.subheadline)).foregroundStyle(Theme.ink)
            }
            .tint(tint)
            #if os(iOS)
            .controlSize(.mini)
            #else
            .controlSize(.small)
            #endif
            .accessibilityIdentifier("\(prefix)-cabin")
            HStack(spacing: 8) {
                Text("Max weight").font(.system(.subheadline)).foregroundStyle(Theme.ink)
                TextField("optional", text: $maxText)
                    .textFieldStyle(.plain)
                    .font(.system(.body).monospacedDigit()).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 8).frame(width: 90).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .accessibilityIdentifier("\(prefix)-max")
                Text("kg").font(.system(.subheadline)).foregroundStyle(Theme.muted)
                Spacer(minLength: 0)
            }
            HStack(spacing: 12) {
                Button(action: addNew) { FieldButtonLabel(title: "Add the bag", tint: tint) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("\(prefix)-add")
                Button("Cancel") { typing = false; close() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                    .frame(minHeight: Metrics.tap).contentShape(Rectangle())
                    .accessibilityIdentifier("\(prefix)-cancel")
                Spacer(minLength: 0)
            }
            .needsLine($needs, typed: name + "|" + maxText, id: "\(prefix)-needs")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.7), lineWidth: 1.2))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(prefix)-panel")
    }

    private func heading(_ words: String) -> some View {
        Text(words).font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
            .padding(.top, 2)
            .accessibilityAddTraits(.isHeader)
    }

    private func addNew() {
        if let problem = model.library.newTripBagProblem(tripId: tripId, name: name) {
            switch problem {
            case .blank: needs = "Type the bag\u{2019}s name."
            case .notABag: needs = "\u{201C}Other\u{201D} means things in no bag \u{2014} give it another name."
            case .yours(let had): needs = "You have a bag called \(had) \u{2014} pick it above."
            case .onTheTrip(let had): needs = "\(had) is on this trip already."
            }
            return
        }
        let clean = jsTrim(maxText).replacingOccurrences(of: ",", with: ".")
        var maxKg: Double?
        if !clean.isEmpty {
            guard let kg = Double(clean), kg.isFinite, kg > 0 else {
                needs = "Type the max in kg \u{2014} or leave it empty."
                return
            }
            maxKg = kg
        }
        let t = tripId, n = jsTrim(name), c = cabin
        model.change { _ = $0.addNewBagToTrip(tripId: t, name: n, cabin: c, maxKg: maxKg) }
        typing = false
        close()
    }
}

// MARK: - The trip header's colours

extension TripHeaderTone {
    private static func colour(_ pair: (day: String, night: String)) -> Color {
        func hex(_ s: String) -> UInt32 { UInt32(s.dropFirst(), radix: 16) ?? 0 }
        return Color(light: hex(pair.day), dark: hex(pair.night))
    }
    /// The ring and the 10 % fill (Done: the fill).
    var ringColour: Color { TripHeaderTone.colour(ring) }
    /// The words on the outlined button.
    var wordsColour: Color { TripHeaderTone.colour(words) }
}
