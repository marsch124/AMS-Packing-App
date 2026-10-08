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
struct BagPockets: View {
    let bagId: String
    @EnvironmentObject var model: LibraryModel
    @State private var newName = ""
    @State private var addNeeds = ""
    /// What is typed into a pocket's field, by its place, until Rename.
    @State private var typed: [Int: String] = [:]
    @State private var problem = ""
    /// The pocket carried by its grip, and each row's height — one place (0.72).
    @State private var carried: ReorderDrag?
    @State private var heights: [String: CGFloat] = [:]

    var body: some View {
        let pockets = model.library.pockets(bagId: bagId)
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
                            step: heights[pocket] ?? Metrics.tap, drag: $carried,
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
        let list = model.library.pockets(bagId: bagId)
        guard let n = list.firstIndex(of: pocket) else { return false }
        return list.indices.contains(n + by)
    }

    private func step(_ pocket: String, _ by: Int) {
        let list = model.library.pockets(bagId: bagId)
        guard let n = list.firstIndex(of: pocket), list.indices.contains(n + by) else { return }
        typed = [:]
        model.change { _ = $0.movePocket(bagId: bagId, from: n, to: n + by) }
    }

    private func add() {
        let name = jsTrim(newName)
        guard !name.isEmpty else { addNeeds = "Type a pocket first."; return }
        var ok = false
        model.change { ok = $0.addPocket(bagId: bagId, name: name) }
        if ok { newName = ""; typed = [:] } else { addNeeds = "The bag already has a pocket called that." }
    }

    private func rename(_ n: Int, _ pocket: String) {
        guard let wanted = typed[n] else { return }
        var ok = false
        model.change { ok = $0.renamePocket(bagId: bagId, from: pocket, to: wanted) }
        if ok { typed = [:]; problem = "" }
        else { problem = jsTrim(wanted).isEmpty ? "A pocket needs a name." : "The bag already has a pocket called that." }
    }

    private func move(_ n: Int) {
        typed = [:]
        model.change { _ = $0.movePocket(bagId: bagId, from: n, to: n - 1) }
    }

    private func remove(_ pocket: String) {
        typed = [:]
        model.change { _ = $0.removePocket(bagId: bagId, name: pocket) }
    }
}

// MARK: - "I leave at" (Create new trip, Trip settings)

/// The door check's times: when he leaves on the first day, and on the last day for home
/// — both optional, in a grid so the times line up ("First day", "Last day"). Each is
/// "Add a time" until set; then the time, when the check comes, and a small quiet ✕
/// ("Remove" in words wrapped on Create new trip's narrower card). Ids, from `id`: the heading `<id>-title`; per time (`out`, `home`)
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
        VStack(alignment: .leading, spacing: 6) {
            HeadingTitle(title: "I leave at", tint: tint, id: "\(id)-title")
            // A grid, so the two times line up under each other.
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                row("First day", $out, kind: "out", start: "07:30")
                row("Last day", $home, kind: "home", start: "10:00")
            }
            #if os(macOS)
            Text("Optional. 15 minutes before, your iPhone names what is still unticked \u{2014} on the last day, what is not in a bag yet.")
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(id)-note")
            #else
            Text("Optional. 15 minutes before, the iPhone names what is still unticked \u{2014} on the last day, what is not in a bag yet.")
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
/// in Search: the bag and pocket show first"). Ids: `search-where` (the card),
/// `search-where-name`, `search-where-place`, `search-where-says`.
struct WhereCard: View {
    let query: String
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        let today = Today.local
        if model.library.tripUnderWay(today: today) != nil,
           let a = model.library.whereIs(query, today: today), a.kind != .usual {
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
        case .usual: return "Usually."
        }
    }
}
