import SwiftUI
import PackingCore
import PackingLibrary

/// The six tones a grab list can wear — the web app's, mid-tones on purpose so
/// they read on the light card and the dark one alike.
enum GrabTone {
    static func color(_ tone: String) -> Color {
        switch tone {
        case "blue": return Color(hex: 0x3a86d4)
        case "yellow": return Color(hex: 0xc99700)
        case "green": return Color(hex: 0x2e9e6b)
        case "red": return Color(hex: 0xcf5b52)
        case "purple": return Color(hex: 0x8a63c9)
        case "teal": return Color(hex: 0x17969b)
        default: return Color(hex: 0x64748b)
        }
    }
}

/// The web app's own doodles — swim, bike, run, each with or without the sun —
/// read straight from their path data, so they are the same drawings.
struct GrabDoodle: View {
    let icon: String
    var size: Double = 40

    static let swim = "M35,16.6 C38.2,16.4 40.8,19 40.7,22.1 C40.6,25.3 38,27.8 34.8,27.7 C31.7,27.6 29.2,25 29.3,21.9 C29.4,18.9 31.9,16.7 35.5,16.9 M40,24 C45.5,18 51.5,15.5 56.5,17 C58.7,17.8 59.7,19.8 59.4,22 M29.5,24.5 C24,27 19,31 15.5,35.5 M6,42.5 C11,40 16,45 21,42.5 C26,40 31,45 36,42.5 C41,40 46,45 51,42.5 C54.5,40.8 58,43.5 60,42.8 M10,51.5 C15,49 20,54 25,51.5 C30,49 35,54 40,51.5 C45,49 50,54 55,51.5"
    static let bike = "M15,35.4 C20.6,35 25.3,39.6 25,45.2 C24.7,50.6 20.1,54.9 14.7,54.6 C9.4,54.3 5.2,49.7 5.5,44.4 C5.8,39.2 10.2,35.2 15.9,35.8 M49,35.2 C54.7,35 59.2,39.5 58.9,45 C58.6,50.5 54,54.8 48.6,54.4 C43.3,54 39.2,49.5 39.5,44.2 C39.8,39 44.3,35 49.8,35.7 M15,45 C18.5,38.5 22.5,32 27,27.5 M27,27.5 C29.5,33 31.5,38.5 33,43.5 M15,45 C21,44.6 27,44.2 33,43.8 M27.5,27.2 C33,26.2 38.5,25.8 43.6,26.2 M49,45 C47.5,38.6 46,32.3 44.3,26.3 M44.3,26.3 C43.5,23.2 41,21.6 38.4,22.3 M23.5,25.6 C26,24.8 28.6,24.8 30.8,25.5"
    static let runBody = "M38,7.6 C41.2,7.4 43.8,10 43.7,13.1 C43.6,16.3 41,18.8 37.8,18.7 C34.7,18.6 32.2,16 32.3,12.9 C32.4,9.9 34.9,7.7 38.5,7.9 M36,19.5 C33.5,25.5 31.5,30.5 29.5,36 M34,24 C38.5,26 42.5,28.5 46,32 M33.5,25 C29.5,26.5 25.5,26 22,24 M29.5,36 C33.5,39 37.5,43 40,48.5 M40,48.5 C41.5,50 43.5,50.8 45.5,50.6 M30,36.5 C26,38.5 22.8,42.3 21.5,47 M21.5,47 C20.2,48.8 18,49.6 15.8,49.3"
    static let runLineTop = "M8,20 C10,19.6 12,19.5 14,19.7"
    static let runLines = "M6,27.5 C8.4,27.4 10.8,27.4 13,27.6 M8,35 C10,34.8 12,34.9 14,35.2"

    /// The sun, drawn at (x, y) at scale s — the web app's GRAB_SUN.
    static func sun(_ x: Double, _ y: Double, _ s: Double = 1) -> String {
        func f(_ v: Double) -> String { String(format: "%.2f", v) }
        var d = "M\(f(x)),\(f(y - 4.2*s)) C\(f(x + 2.4*s)),\(f(y - 4.4*s)) \(f(x + 4.4*s)),\(f(y - 2.4*s)) \(f(x + 4.3*s)),\(f(y)) C\(f(x + 4.2*s)),\(f(y + 2.4*s)) \(f(x + 2.2*s)),\(f(y + 4.3*s)) \(f(x - 0.2*s)),\(f(y + 4.2*s)) C\(f(x - 2.5*s)),\(f(y + 4.1*s)) \(f(x - 4.4*s)),\(f(y + 2.1*s)) \(f(x - 4.3*s)),\(f(y - 0.1*s)) C\(f(x - 4.2*s)),\(f(y - 2.3*s)) \(f(x - 2.3*s)),\(f(y - 4.1*s)) \(f(x + 0.4*s)),\(f(y - 4*s))"
        let rays: [(Double, Double, Double, Double)] = [
            (-0.1, -9.6, 0.2, -6.9), (6.7, -6.7, 4.9, -4.9), (9.5, 0.2, 6.8, 0), (6.5, 6.8, 4.8, 5),
            (-6.8, -6.5, -5, -4.8), (-9.4, 0.1, -6.7, -0.1), (-6.4, 6.7, -4.8, 4.9), (0.1, 9.4, -0.1, 6.7),
        ]
        for r in rays { d += " M\(f(x + r.0*s)),\(f(y + r.1*s)) L\(f(x + r.2*s)),\(f(y + r.3*s))" }
        return d
    }

    static func path(_ icon: String) -> String {
        switch icon {
        case "swim": return swim
        case "bike": return bike
        case "run": return runBody + " " + runLineTop + " " + runLines
        case "swim-sun": return swim + " " + sun(11, 11)
        case "bike-sun": return bike + " " + sun(12, 12)
        case "run-sun": return runBody + " " + runLines + " " + sun(11, 12, 0.9)
        default: return runBody + " " + runLineTop + " " + runLines
        }
    }

    var body: some View {
        let k = size / 64
        SVGPath.path(GrabDoodle.path(icon))
            .applying(CGAffineTransform(scaleX: k, y: k))
            .stroke(style: StrokeStyle(lineWidth: 4.5 * k, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

/// This device's ticks and skips, list by list. In a UI test they live in memory
/// only, so one test's ticks cannot reach the next.
final class GrabStore {
    static let shared = GrabStore(persistent: !ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uiTesting") })
    private let persistent: Bool
    private var memory: [String: GrabState] = [:]
    init(persistent: Bool) { self.persistent = persistent }

    func state(_ id: String, items: [String]) -> GrabState {
        let raw: GrabState?
        if persistent, let data = UserDefaults.standard.data(forKey: "ams.grab.\(id)") {
            raw = try? JSONDecoder().decode(GrabState.self, from: data)
        } else { raw = memory[id] }
        return (raw ?? GrabState()).current(for: items)
    }
    func save(_ id: String, _ s: GrabState) {
        memory[id] = s
        if persistent, let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: "ams.grab.\(id)") }
    }
}

/// The six Home buttons — indoor row, outdoor row beneath (his order).
struct GrabButtons: View {
    let lists: [GrabDefinition]
    let open: (GrabDefinition) -> Void

    var body: some View {
        let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        LazyVGrid(columns: cols, spacing: 10) {
            ForEach(Array(lists.enumerated()), id: \.element.id) { n, d in
                Button { open(d) } label: {
                    VStack(spacing: 4) {
                        GrabDoodle(icon: d.icon, size: 44).foregroundStyle(GrabTone.color(d.tone))
                        Text(d.label).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 84)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(GrabTone.color(d.tone).opacity(0.5), lineWidth: 1.5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("grab-\(n)")
                .accessibilityLabel(d.title)
            }
        }
    }
}

/// One grab list: tap each thing as you pick it up, ⊘ to leave one behind just
/// this once; "Ready to go" refuses until everything not skipped is in hand.
/// Edit: rename, move, remove and add things — saved for the account, so the
/// other device has the same list.
struct GrabScreen: View {
    let listId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var state = GrabState()
    @State private var message = ""
    @State private var flash = false
    @State private var editing = false
    @State private var draft: [String] = []
    @State private var newThing = ""

    private var list: GrabDefinition {
        model.library.grabLists().first { $0.id == listId } ?? GRAB_FACTORY[0]
    }
    private var tint: Color { GrabTone.color(list.tone) }

    var body: some View {
        let items = list.items
        let complete = state.isComplete(items)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                GrabDoodle(icon: list.icon, size: 36).foregroundStyle(tint)
                Text(list.title).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink).lineLimit(1)
                Spacer()
                Button(editing ? "Save" : "Edit") { editing ? saveEdits() : startEditing() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(tint)
                    .accessibilityIdentifier("grab-edit")
                if !editing {
                    Button("Done") { dismiss() }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(tint)
                        .accessibilityIdentifier("grab-done")
                }
            }
            .padding(16)
            if editing { editor } else { KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 6) {
                    if complete {
                        Text("All there — go!")
                            .font(.system(size: 20, weight: .heavy)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 12).fill(tint))
                            .accessibilityIdentifier("grab-allthere")
                    } else {
                        Text("\(state.done.count) of \(state.active(items).count) in hand" + (state.skipped.isEmpty ? "" : " · \(state.skipped.count) skipped"))
                            .font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("grab-count")
                    }
                    ForEach(Array(items.enumerated()), id: \.offset) { n, name in
                        let ticked = state.done.contains(name)
                        let skipped = state.skipped.contains(name)
                        HStack(spacing: 4) {
                            Button { change { $0.tapped(name) } } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().stroke(skipped ? Theme.line : tint, lineWidth: 2).frame(width: 26, height: 26)
                                        if ticked {
                                            Circle().fill(tint).frame(width: 26, height: 26)
                                            Tick().stroke(Color.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)).frame(width: 26, height: 26)
                                        }
                                    }
                                    Text(name)
                                        .font(.system(size: 18, weight: ticked ? .regular : .semibold))
                                        .foregroundStyle(skipped || ticked ? Theme.muted : Theme.ink)
                                        .strikethrough(skipped, pattern: .solid, color: Theme.muted)
                                    Spacer(minLength: 8)
                                    if skipped { Text("not this time").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted) }
                                }
                                .padding(.vertical, 11).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("grab-item-\(n)")
                            .accessibilityAddTraits(ticked ? .isSelected : [])
                            Button { change { $0.skipToggled(name) } } label: {
                                AsideMark(back: skipped).frame(width: 40, height: 40).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("grab-skip-\(n)")
                            .accessibilityLabel(skipped ? "Take \(name) along after all" : "Leave \(name) behind, just this once")
                        }
                        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                    }
                    Button {
                        if complete { flash = true; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { dismiss() }; return }
                        let missing = state.missing(items)
                        if missing.isEmpty { message = "Nothing left to take — everything is skipped." }
                        else if missing.count <= 3 { message = "Not yet — still missing: \(missing.joined(separator: ", "))." }
                        else { message = "Not yet — \(missing.count) things still missing." }
                    } label: {
                        Text("Ready to go")
                            .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 12).fill(tint))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .padding(.top, 14)
                    .accessibilityIdentifier("grab-ready")
                    if !message.isEmpty {
                        Text(message).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: 0xdc3d43))
                            .accessibilityIdentifier("grab-message")
                    }
                    if !state.done.isEmpty || !state.skipped.isEmpty {
                        Button { change { _ in GrabState() } } label: {
                            Text("Start over").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.muted)
                                .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("grab-reset")
                    }
                    Text("Tap each thing as you pick it up — or tap ⊘ to leave something behind, just this once. Ticks and skips clear themselves after 6 hours.")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted).padding(.top, 8)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            } }
        }
        .background(Theme.bg.ignoresSafeArea())
        // The moment the last thing is ticked, the whole screen blinks the list's
        // colour — you are usually at the bottom of a long list when it lands.
        .overlay { if flash { tint.opacity(0.35).ignoresSafeArea().allowsHitTesting(false) } }
        .animation(.easeOut(duration: 0.6), value: flash)
        .onAppear { state = GrabStore.shared.state(list.id, items: items) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("grab-detail")
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 600)
        #endif
    }

    // MARK: Editing

    private var editor: some View {
        VStack(spacing: 0) {
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tap a name to change it · ▲▼ move · ✕ remove. Saved for both your devices.")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
                    ForEach(draft.indices, id: \.self) { n in
                        HStack(spacing: 2) {
                            TextField("Name", text: Binding(get: { n < draft.count ? draft[n] : "" },
                                                            set: { if n < draft.count { draft[n] = $0 } }))
                                .textFieldStyle(.plain)
                                .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                                .padding(.horizontal, 10).frame(minHeight: 44)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                                .accessibilityIdentifier("grab-rename-\(n)")
                            mark("M6 14l6-6 6 6", id: "grab-up-\(n)", enabled: n > 0, label: "Move up") { draft.swapAt(n, n - 1) }
                            mark("M6 10l6 6 6-6", id: "grab-down-\(n)", enabled: n < draft.count - 1, label: "Move down") { draft.swapAt(n, n + 1) }
                            mark("M7 7L17 17M17 7L7 17", id: "grab-remove-\(n)", enabled: draft.count > 1, label: "Remove") { draft.remove(at: n) }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            HStack(spacing: 8) {
                TextField("Add a thing", text: $newThing)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { addToDraft() }
                    .accessibilityIdentifier("grab-add-name")
                Button { addToDraft() } label: {
                    Text("Add").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(jsTrim(newThing).isEmpty ? Theme.line : tint))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .disabled(jsTrim(newThing).isEmpty)
                .accessibilityIdentifier("grab-add")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private func mark(_ d: String, id: String, enabled: Bool, label: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            SVGPath.path(d).stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 22, height: 22).foregroundStyle(enabled ? Theme.ink : Theme.line)
                .frame(width: 38, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .disabled(!enabled)
        .accessibilityIdentifier(id)
        .accessibilityLabel(label)
    }

    private func startEditing() {
        draft = list.items
        newThing = ""
        editing = true
    }

    private func addToDraft() {
        let name = jsTrim(newThing)
        guard !name.isEmpty else { return }
        if !draft.contains(where: { normName($0) == normName(name) }) { draft.append(name) }
        newThing = ""
    }

    private func saveEdits() {
        let items = draft
        model.change { _ = $0.saveGrabList(id: listId, items: items) }
        editing = false
        state = GrabStore.shared.state(listId, items: list.items)
    }

    private func change(_ body: (GrabState) -> GrabState) {
        let was = state.isComplete(list.items)
        state = body(state)
        message = ""
        GrabStore.shared.save(list.id, state)
        if !was && state.isComplete(list.items) {
            flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { flash = false }
        }
    }
}
