import SwiftUI
import PackingCore
import PackingLibrary

// Bag pockets, "Where is my …?" and the door check's "I leave at" (0.69 — stop B of his
// idea plan and idea 4, 7 Oct 2026). The pieces several screens share live here.

/// One short row of small pills under a just-ticked line: the bag's pockets, the one
/// chosen filled. "Ticking a line shows the bag's pockets in one short row; tap one or
/// ignore it." Its row is `<id>`, each pill `<id>-<n>` (n from 0, in the bag's order).
struct PocketPills: View {
    let pockets: [String]
    let chosen: String
    let tint: Color
    let id: String
    let choose: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(pockets.enumerated()), id: \.offset) { n, pocket in
                    let on = normName(pocket) == normName(chosen)
                    Button { choose(pocket) } label: {
                        Text(pocket)
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(on ? Color.white : tint)
                            .lineLimit(1)
                            .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                            .background(Capsule().fill(on ? tint : Color.clear))
                            .overlay(Capsule().stroke(tint, lineWidth: on ? 0 : 1.2))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("\(id)-\(n)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }
}

// MARK: - A bag's pockets (Care → Bags → a bag)

/// "A bag's page lists its pockets; you name them once." Each pocket is its own field —
/// press it, type, Rename (or Return) — with a grip ≡ to drag it to its place (0.72; the Mac
/// also keeps Up) and a small red ✕ last on its line. A bag with no pockets is a bag as it
/// always was.
///
/// Ids: the count `bag-pockets-count`; a pocket's field `bag-pocket-<n>`, its Rename
/// `bag-pocket-<n>-rename`, its grip `bag-pocket-<n>-grip`, Up `bag-pocket-<n>-up` (the Mac
/// only, not on the first), ✕
/// `bag-pocket-<n>-remove`; a refused rename `bag-pockets-problem`; the new pocket's field
/// `bag-pocket-new`, Add `bag-pocket-add`, and what Add was missing `bag-pocket-add-needs`.
///
/// Held, not written (0.98, the Apple way — his decision of 21 Oct 2026): each Add, rename, move and
/// ✕ is a step on the bag page's ledger (`EditDraft.step`), written with the rest of the page by Done
/// (or first by Duplicate and Its details) and forgotten by Cancel or the app swiped away. The pockets
/// shown are the page's own copy of the library with those steps made (`held`) — made by the
/// library's own rules, so a name refused here is refused as it was. Each step finds its pocket by
/// NAME when it is written, so a pocket the other device added meanwhile does not shift a move.
/// Until 0.98 each was written at once and Cancel put back what the page changed (0.92, 0.95).
struct BagPockets: View {
    let bagId: String
    /// The bag page's ledger (0.98).
    let draft: EditDraft
    @EnvironmentObject var model: LibraryModel
    /// The library with this page's pocket steps made; nil = nothing held, the library itself shown.
    @State private var held: Library?
    @State private var newName = ""
    @State private var addNeeds = ""
    /// What is typed into a pocket's field, by its place, until Rename.
    @State private var typed: [Int: String] = [:]
    @State private var problem = ""
    /// The pocket carried by its grip, and each row's height — one place (0.72).
    @State private var carried: ReorderDrag?
    @State private var heights: [String: CGFloat] = [:]

    private var shownPockets: [String] { (held ?? model.library).pockets(bagId: bagId) }

    var body: some View {
        let pockets = shownPockets
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Pockets").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("\(pockets.count)").font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("bag-pockets-count")
            }
            if pockets.isEmpty {
                Text("None yet. Name its pockets \u{2014} main, front pocket, lid \u{2014} and ticking a thing on a trip asks which one it went into.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Followed by its name (unique in a bag), not its place: a pocket carried by its
            // grip keeps its gesture while the others change places (0.72).
            ForEach(Array(pockets.enumerated()), id: \.element) { n, pocket in
                row(n, pocket, count: pockets.count)
            }
            if !problem.isEmpty {
                Text(problem).font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .accessibilityIdentifier("bag-pockets-problem")
            }
            HStack(spacing: 8) {
                TextField("A new pocket, e.g. Front pocket", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("bag-pocket-new")
                // Always in colour (his rule for a main button); pressed with nothing typed,
                // it says so under the field.
                Button { add() } label: { FieldButtonLabel(title: "Add", tint: AppSection.care.color) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("bag-pocket-add")
            }
            .needsLine($addNeeds, typed: newName, id: "bag-pocket-add-needs")
        }
    }

    private func row(_ n: Int, _ pocket: String, count: Int) -> some View {
        HStack(spacing: 6) {
            // The grip (0.72, his "drag and drop on the phone as well"): hold and drag; each
            // place passed is one step, made at once as Up is.
            if count > 1 {
                ReorderGrip(id: "bag-pocket-\(n)-grip", label: "Move \(pocket)", key: pocket,
                            step: (heights[pocket] ?? Metrics.compact) + 6, drag: $carried,   // a row and the gap under it
                            canMove: { by in canStep(pocket, by) }, move: { by in step(pocket, by) })
                    .padding(.leading, -6)
            }
            TextField("", text: Binding(get: { typed[n] ?? pocket }, set: { typed[n] = $0; problem = "" }))
                .textFieldStyle(.plain)
                .font(.system(.callout)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).frame(minHeight: Metrics.compact)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                .onSubmit { rename(n, pocket) }
                .accessibilityIdentifier("bag-pocket-\(n)")
            if let wanted = typed[n], jsTrim(wanted) != pocket {
                Button { rename(n, pocket) } label: {
                    Text("Rename").font(.system(.footnote, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).frame(minHeight: Metrics.compact)
                        .background(Capsule().fill(AppSection.care.color))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("bag-pocket-\(n)-rename")
            }
            // Up (the Mac's; the iPhone drags the grip): the first pocket has none, and its
            // room is kept so the ✕ stay in line.
            if ReorderArrows.shown, n > 0 {
                Button { move(n) } label: {
                    SVGPath.path("M6 15l6-6 6 6")
                        .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .onGrid(Metrics.glyph).foregroundStyle(Theme.muted)
                        .frame(width: Metrics.compact, height: Metrics.compact).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("bag-pocket-\(n)-up")
                .accessibilityLabel("Move \(pocket) up")
            } else if ReorderArrows.shown {
                Color.clear.frame(width: Metrics.compact, height: Metrics.compact)
            }
            // Remove: one small red ✕, quiet, last on the line.
            Button { remove(pocket) } label: {
                SVGPath.path("M7 7l10 10M17 7L7 17")
                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .onGrid(Metrics.glyph).foregroundStyle(AppSection.actions.color)
                    .frame(width: Metrics.compact, height: Metrics.compact).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("bag-pocket-\(n)-remove")
            .accessibilityLabel("Remove \(pocket)")
        }
        .reorderStep(pocket, into: $heights)
        .reorderLift(carried, key: pocket, tint: AppSection.care.color)
    }

    private func canStep(_ pocket: String, _ by: Int) -> Bool {
        let list = shownPockets
        guard let n = list.firstIndex(of: pocket) else { return false }
        return list.indices.contains(n + by)
    }

    private func step(_ pocket: String, _ by: Int) {
        typed = [:]
        changing(BagPockets.moving(bagId, pocket, by: by))
    }

    /// One change of the bag's pockets, held (0.98): made on the page's copy — false, nothing held,
    /// when the library's rules refuse it there — and put on the ledger as a step.
    @discardableResult
    private func changing(_ body: @escaping (inout Library) -> Bool) -> Bool {
        var lib = held ?? model.library
        guard body(&lib) else { return false }
        held = lib
        draft.step { _ = body(&$0) }
        return true
    }

    /// A move by name (0.98): the pocket's place is looked up again when the step is written.
    static func moving(_ bagId: String, _ pocket: String, by: Int) -> (inout Library) -> Bool {
        { lib in
            let list = lib.pockets(bagId: bagId)
            guard let n = list.firstIndex(of: pocket), list.indices.contains(n + by) else { return false }
            return lib.movePocket(bagId: bagId, from: n, to: n + by)
        }
    }

    private func add() {
        let name = jsTrim(newName), id = bagId
        guard !name.isEmpty else { addNeeds = "Type a pocket first."; return }
        let ok = changing { $0.addPocket(bagId: id, name: name) }
        if ok { newName = ""; typed = [:] } else { addNeeds = "The bag already has a pocket called that." }
    }

    private func rename(_ n: Int, _ pocket: String) {
        guard let wanted = typed[n] else { return }
        let id = bagId
        let ok = changing { $0.renamePocket(bagId: id, from: pocket, to: wanted) }
        if ok { typed = [:]; problem = "" }
        else { problem = jsTrim(wanted).isEmpty ? "A pocket needs a name." : "The bag already has a pocket called that." }
    }

    private func move(_ n: Int) {
        let list = shownPockets
        guard list.indices.contains(n) else { return }
        typed = [:]
        changing(BagPockets.moving(bagId, list[n], by: -1))
    }

    private func remove(_ pocket: String) {
        typed = [:]
        let id = bagId
        changing { $0.removePocket(bagId: id, name: pocket) }
    }
}

// MARK: - "I leave at" (Create new trip, Trip settings)

/// The door check's times: when he leaves on the first day, and on the last day for home
/// — both optional, in a grid so the times line up ("First day", "Last day"). Each is
/// "Add a time" until set; then the time, when the check comes, and a small quiet ✕.
/// ONE framed block (0.75, his yes of 13 Oct 2026: "so he sees which lines belong to that
/// function"): a rounded frame in the screen's tint over a very light fill of it, a header
/// with a drawn door, "I leave at" and what it is for ("the door check"), the times, a
/// hairline, and the note — which says too that the first day's time is when the trip
/// leaves Pack for On site (`Library.hasSetOff`). Ids, from `id`: the frame `<id>-frame`,
/// the heading `<id>-title`, "the door check" `<id>-what`; per time (`out`, `home`)
/// `<id>-<kind>-add`, `<id>-<kind>-time` (the picker), `<id>-<kind>-check` ("Check
/// 07:15") and `<id>-<kind>-remove`; the line under them `<id>-note`, and — when the
/// device does not let the app remind him — `<id>-refused`.
struct LeaveTimes: View {
    @Binding var out: String
    @Binding var home: String
    let id: String
    let tint: Color
    @State private var refused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                DoorMark().frame(width: Metrics.glyph, height: Metrics.glyph).foregroundStyle(tint)
                HeadingTitle(title: "I leave at", tint: tint, id: "\(id)-title")
                Spacer(minLength: 8)
                Text("the door check")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .lineLimit(1).fixedSize()
                    .accessibilityIdentifier("\(id)-what")
            }
            // A grid, so the two times line up under each other.
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                row("First day", $out, kind: "out", start: "07:30")
                row("Last day", $home, kind: "home", start: "10:00")
            }
            Rectangle().fill(Theme.line).frame(height: 1)
                .accessibilityHidden(true)
            #if os(macOS)
            Text("Optional. 15 minutes before, your iPhone names what is still unticked \u{2014} on the last day, what is not in a bag yet. Before this time the trip is still at Pack.")
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(id)-note")
            #else
            Text("Optional. 15 minutes before, the iPhone names what is still unticked \u{2014} on the last day, what is not in a bag yet. Before this time the trip is still at Pack.")
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(id)-note")
            if refused && !(out.isEmpty && home.isEmpty) {
                Text("This device does not allow the app to remind you. Allow it in the device's Settings, under Notifications.")
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(id)-refused")
            }
            #endif
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: 1.5))
        // A container of its own: the frame has its id, and every line in it keeps its own.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(id)-frame")
        .task(id: out + "|" + home) { await lookUp() }
    }

    private func row(_ label: String, _ time: Binding<String>, kind: String, start: String) -> some View {
        GridRow {
            Text(label).font(.system(.subheadline)).foregroundStyle(Theme.ink)
                .lineLimit(1).fixedSize()
            if time.wrappedValue.isEmpty {
                Button {
                    time.wrappedValue = start
                    Task { await ask() }
                } label: {
                    Text("Add a time").font(.system(.footnote, weight: .semibold)).foregroundStyle(tint)
                        .lineLimit(1).fixedSize()
                        .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                        .overlay(Capsule().stroke(tint, lineWidth: 1.2))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("\(id)-\(kind)-add")
                .gridCellColumns(3)
            } else {
                DatePicker("", selection: Binding(get: { LeaveTimes.date(time.wrappedValue) },
                                                  set: { time.wrappedValue = LeaveTimes.words($0) }),
                           displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .fixedSize()
                    .accessibilityIdentifier("\(id)-\(kind)-time")
                // When the check comes (any day will do: only the time is shown).
                Text("Check \(Library.before(day: "2026-01-02", time: time.wrappedValue, minutes: DOOR_CHECK_LEAD_MINUTES)?.time ?? "")")
                    .font(.system(.footnote).monospacedDigit()).foregroundStyle(Theme.muted)
                    .lineLimit(1).fixedSize()
                    .accessibilityIdentifier("\(id)-\(kind)-check")
                // Remove: a small quiet ✕, last on the line.
                Button { time.wrappedValue = "" } label: {
                    SVGPath.path("M7 7l10 10M17 7L7 17")
                        .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .onGrid(Metrics.glyph).foregroundStyle(Theme.muted)
                        .frame(width: Metrics.compact, height: Metrics.compact).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("\(id)-\(kind)-remove")
                .accessibilityLabel("Remove the time")
            }
        }
    }

    /// Asked once, when he sets a time (the system's own question; nothing on the Mac).
    private func ask() async {
        #if os(iOS)
        refused = !(await PackingReminders.shared.askToShow())
        #endif
    }

    private func lookUp() async {
        #if os(iOS)
        guard !(out.isEmpty && home.isEmpty) else { refused = false; return }
        refused = await PackingReminders.shared.permission() == .refused
        #endif
    }

    /// "07:30" as a moment today (only its hours and minutes count).
    static func date(_ words: String) -> Date {
        let t = (Library.cleanTime(words) ?? "07:30").split(separator: ":").compactMap { Int($0) }
        return Calendar.current.date(bySettingHour: t[0], minute: t[1], second: 0, of: Date()) ?? Date()
    }

    static func words(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

/// A door, drawn — the head of "I leave at", the door check (0.75): a door standing on the
/// floor, its top corners rounded, its handle on the right. The app's own stroke on the
/// 24-point grid (`GridShape`), never a stock symbol.
struct DoorMark: View {
    var body: some View {
        GridShape(d: "M4 20.5h16M6.5 20.5V4.8A1.3 1.3 0 0 1 7.8 3.5h8.4A1.3 1.3 0 0 1 17.5 4.8V20.5M14 12.5h1.5")
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .accessibilityHidden(true)
    }
}

// MARK: - The door checks, for the tests

#if DEBUG
/// UI tests only (`-showDoorChecks`): what the device would have in its list for this
/// trip — a test cannot see a notification. One line per check, `door-check-out` /
/// `door-check-home`, saying its id, day and time, title and words; `door-check-none`
/// when there is none.
struct DoorCheckList: View {
    let tripId: String
    @ObservedObject private var checks = DoorChecks.shared

    var body: some View {
        let mine = checks.planned.filter { $0.tripId == tripId }
        VStack(alignment: .leading, spacing: 2) {
            if mine.isEmpty {
                Text("No door check").font(.system(.caption)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("door-check-none")
            }
            ForEach(mine) { c in
                Text("\(c.id) \u{00B7} \(c.day) \(c.time) \u{00B7} \(c.title) \(c.body)")
                    .font(.system(.caption)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("door-check-\(c.kind.rawValue)")
            }
        }
    }
}
#endif

// MARK: - Where is it (Search)

/// Search, while a trip is under way: the thing searched for, and where it is on that
/// trip — "Backpack · Front pocket" — first, above every other result ("Ask Siri, or type
/// in Search: the bag and pocket show first"). A thing inside a kit (0.73): where the KIT
/// is, and the kit named on a line of its own — "In the Camp pouch"; one taken out of its
/// kit is shown too, "Taken out of the Camp pouch", with where it usually goes. Ids:
/// `search-where` (the card), `search-where-name`, `search-where-place`, `search-where-kit`
/// (only for a thing in a kit), `search-where-says`.
struct WhereCard: View {
    let query: String
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        let today = Today.local
        if model.library.tripUnderWay(today: today) != nil,
           let a = model.library.whereIs(query, today: today), a.kind != .usual || !a.takenOutOf.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(a.name).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .accessibilityIdentifier("search-where-name")
                    Spacer(minLength: 8)
                    Text(a.shown).font(.system(.callout, weight: .semibold)).foregroundStyle(AppSection.events.color)
                        .lineLimit(1)
                        .accessibilityIdentifier("search-where-place")
                }
                // The kit, on a line of its own: the place above is where the KIT is.
                if !a.kitWords.isEmpty {
                    Text(a.kitWords).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("search-where-kit")
                }
                Text(WhereCard.says(a)).font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("search-where-says")
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppSection.events.color.opacity(0.6), lineWidth: 1))
            .padding(.top, 10)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("search-where")
        }
    }

    static func says(_ a: WhereAnswer) -> String {
        switch a.kind {
        case .packed: return "Packed on \(a.tripName)."
        case .packedHome: return "Packed for home from \(a.tripName)."
        case .notPacked: return "On \(a.tripName), not packed yet \u{2014} it goes there."
        // Shown only for a thing taken out of its kit: where it usually goes, if anywhere.
        case .usual: return a.bag.isEmpty ? "It has no usual bag." : "Where it usually goes."
        }
    }
}
