import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import PackingCore
import PackingLibrary

/// Settings: iCloud sync on this device — his field test, 3 Oct 2026 ("we need to get
/// the sync going because I need to work from the Mac"). When this device last sent
/// and received, what iCloud does not have yet, and why a send failed, in plain
/// words. Sync now checks in from this device; the OTHER device then shows it — a
/// direct test of each road.
struct SyncCard: View {
    @EnvironmentObject var model: LibraryModel
    /// What the store's record said at the last look (0.92: shared with Home's sync light).
    @State private var seen: SyncWatch.Seen? = SyncWatch.last
    @State private var said = ""
    @Environment(\.colorScheme) private var scheme

    static var device: String {
        #if os(macOS)
        return "Mac"
        #else
        return "iPhone"
        #endif
    }
    static var other: String { device == "Mac" ? "iPhone" : "Mac" }

    var body: some View {
        let on = seen?.on ?? SyncWatch.on(model)
        let c = seen?.check
        let now = seen?.now ?? Date()
        // It says what Home's light says (0.92): the same rules, words and colours.
        let state = SyncCheck.light(usesICloud: on, check: c, now: now, awake: SyncWatch.awake)
        let stuck = state == .stuck
        // Compact, as Settings' cards are (8 points between its lines, 14 inside, until 0.67).
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("iCloud sync").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                // 0.101 — his words (26 Oct 2026): "should not look as a pill. Please design it." Home's
                // own sync dot (8 points, `SyncLight`) and the words after it in its colour — made
                // readable as words on this card (`SyncLight.words`) — no capsule, no fill. A white word
                // on a coloured capsule until 0.101.
                HStack(spacing: 6) {
                    Circle().fill(SyncLight.color(state.colour))
                        .frame(width: SyncLight.dot, height: SyncLight.dot)
                        .accessibilityElement()
                        .accessibilityAddTraits(.isImage)
                        .accessibilityLabel("iCloud sync")
                        #if DEBUG
                        // The tests' only way to see the dot's colour, as Home's dot.
                        .accessibilityValue(state.colour.rawValue)
                        #endif
                        .accessibilityIdentifier("sync-state-dot")
                    Text(state.word)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(SyncLight.words(state.colour, scheme))
                        .accessibilityIdentifier("sync-state")
                }
            }
            if !on {
                quiet("This copy of the app keeps its library on this device only.", id: "sync-off")
            } else if let c {
                quiet("Sent: \(SyncCard.when(c.lastSent)) \u{00B7} received: \(SyncCard.when(c.lastReceived))", id: "sync-times")
                if c.notSentTotal > 0 {
                    // Orange while it is on its way; red once it has waited too long (0.92).
                    let late = c.waitedTooLong(now: now)
                    line("Not in iCloud yet: \(c.notSentWords).", id: "sync-notsent",
                         tone: late ? AppSection.actions.color : AppSection.care.color)
                    if let w = c.waitedWords(now: now) { loud(w, id: "sync-waited") }
                }
                if let p = c.problem {
                    loud("The last \(p.sending ? "send" : "receive") failed \(SyncCard.when(p.at)): \(SyncCheck.plain(domain: p.domain, code: p.code)).",
                         id: "sync-problem")
                }
                // A send or receive with no end (0.92): running is quiet; hung (ten minutes) is loud and
                // says what to do. Until 0.92 a receive that never ended said "failed".
                if let r = c.runningWords(now: now, awake: SyncWatch.awake) {
                    if r.hung { loud(r.words, id: "sync-running") } else { quiet(r.words, id: "sync-running") }
                }
            } else {
                // iCloud is on, but this device cannot read its own record of it: say
                // so, rather than a green "Working" over nothing (the spec pass, 2026-10-05).
                quiet("This device cannot tell right now how the sync is going.", id: "sync-unknown")
            }
            quiet(model.library.lastCheckIn(device: SyncCard.other).map { "The \(SyncCard.other) last checked in \(SyncCard.when(iso: $0))." }
                  ?? "The \(SyncCard.other) has not checked in yet \u{2014} press Sync now there.", id: "sync-other")
            quiet(model.library.lastCheckIn(device: SyncCard.device).map { "This \(SyncCard.device) checked in \(SyncCard.when(iso: $0))." }
                  ?? "This \(SyncCard.device) has not checked in yet.", id: "sync-self")
            HStack(spacing: 10) {
                Button { syncNow() } label: {
                    Text("Sync now").font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                        .background(Capsule().fill(AppSection.events.color))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("sync-now")
                Button("Copy details for Claude") { copyDetails() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.settings.color)
                    .accessibilityIdentifier("sync-copy")
            }
            if !said.isEmpty { quiet(said, id: "sync-said") }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(stuck ? AppSection.actions.color : Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sync-card")
        // A fresh look now and every 30 s while the card is shown (0.92), after a change of the
        // library and when the store says it changed — as Home's light.
        .task { await SyncWatch.keepLooking(model) { seen = $0 } }
        .onReceive(model.$library.debounce(for: .seconds(1), scheduler: RunLoop.main)) { _ in refresh() }
        .onReceive(SyncWatch.storeChanged) { _ in refresh() }
    }

    private func line(_ text: String, id: String, tone: Color) -> some View {
        Text(text).font(.system(.subheadline, weight: .semibold)).foregroundStyle(tone)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(id)
    }

    private func quiet(_ text: String, id: String) -> some View {
        Text(text).font(.system(.subheadline)).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(id)
    }

    private func loud(_ text: String, id: String) -> some View {
        Text(text).font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(id)
    }

    private func refresh() {
        Task { seen = await SyncWatch.look(model) }
    }

    /// Check in: a small note that travels like everything else. Then look again.
    private func syncNow() {
        model.change { $0.checkIn(device: SyncCard.device) }
        said = "Checked in. On the \(SyncCard.other), Settings shows it within a minute or so if the road is open."
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            model.reload()
            refresh()
        }
    }

    private func copyDetails() {
        var text = seen?.check?.details(device: SyncCard.device, version: AppInfo.version)
            ?? "Sync details · \(SyncCard.device) · \(AppInfo.version)\nNo iCloud record on this device."
        text += "\nThis device holds: " + model.library.records().reduce(into: [String: Int]()) { $0[$1.table.rawValue, default: 0] += 1 }
            .sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        said = "Copied. Paste it into the chat with Claude."
    }

    /// "today 13:52", "2 Oct 22:10", "never" (`SyncCheck.when`, held by the model tests).
    static func when(_ date: Date?) -> String { SyncCheck.when(date) }

    static func when(iso: String) -> String { SyncCheck.when(iso: iso) }
}

/// What the store's own record of iCloud says, looked at for the sync card and Home's sync light
/// (0.92). Read-only, off the main thread — about 8 ms on a library of his size (measured on a copy
/// of his Mac's store, 19 Oct 2026).
enum SyncWatch {
    /// One look: iCloud on or not, the record (nil = it could not be read), and when.
    struct Seen: Equatable {
        var on: Bool
        var check: SyncCheck?
        var now: Date
    }

    /// The last look, app-wide: a screen that comes back shows it at once, and looks again.
    static var last: Seen?

    /// When the app last came to the front. The iPhone pauses the app in the background, and a
    /// receive it was in the middle of waits with it: its ten minutes before "hung" count from
    /// here (`SyncCheck.hung`). The Mac's app is never paused, so there it is its first look.
    /// The UI tests' invented record is judged as it is (`-syncLight`).
    static var awake: Date = {
        #if os(iOS)
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                               object: nil, queue: .main) { _ in awake = Date() }
        #endif
        return invented != nil ? .distantPast : Date()
    }()

    /// The store says it changed — a save, iCloud sending or bringing something (a second's calm first).
    static let storeChanged = NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
        .debounce(for: .seconds(1), scheduler: RunLoop.main)

    /// Does this copy of the app sync through iCloud?
    static func on(_ model: LibraryModel) -> Bool { invented?.on ?? model.usesICloud }

    /// A look, the reading done off the main thread.
    @MainActor
    static func look(_ model: LibraryModel) async -> Seen {
        let on = on(model)
        _ = awake
        let check = on ? await Task.detached(priority: .utility) { SyncWatch.read() }.value : nil
        let seen = Seen(on: on, check: check, now: Date())
        last = seen
        return seen
    }

    /// A look now, and every 30 s until the screen goes (the task is cancelled with it).
    @MainActor
    static func keepLooking(_ model: LibraryModel, _ show: @escaping (Seen) -> Void) async {
        while !Task.isCancelled {
            show(await look(model))
            try? await Task.sleep(for: .seconds(30))
        }
    }

    private static func read() -> SyncCheck? { invented.map { $0.check } ?? SyncCheck.read() }

    /// This device checks in by itself while it syncs (0.101, `Library.checkInIfDue` — his Mac said
    /// "This Mac checked in 10 Oct 19:11" while it sent and received every day: only Sync now wrote a
    /// check-in). With iCloud on and the library read, once its last check-in is a quarter of an hour
    /// old. Asked as the app opens, when it comes to the front, and every minute while it runs
    /// (`RootView`); a page's copy never checks in. With iCloud off there is no other device to tell.
    @MainActor
    static func checkInIfDue(_ model: LibraryModel) {
        guard on(model), !model.isDraft, model.state == .ready,
              model.library.checkInDue(device: SyncCard.device, now: Date()) else { return }
        model.change { _ = $0.checkInIfDue(device: SyncCard.device, now: Date()) }
    }

    /// UI tests only (`-syncLight insync|sending|receiving|hung|failed|waited|unknown|off`, with a
    /// `-uiTesting…` library): an invented record, its times counted back from the launch. The tests'
    /// libraries keep everything on the device, so without it the light never shows there.
    static let invented: (on: Bool, check: SyncCheck?)? = {
        let args = ProcessInfo.processInfo.arguments
        guard AMSPackingApp.testing, let n = args.firstIndex(of: "-syncLight"), n + 1 < args.count else { return nil }
        let now = Date()
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        let good = [SyncCheck.Event(type: 2, ok: true, at: ago(3)), SyncCheck.Event(type: 1, ok: true, at: ago(2))]
        switch args[n + 1] {
        case "insync": return (true, SyncCheck(events: good))
        case "sending": return (true, SyncCheck(events: good, notSent: ["trips": 1, "entries": 3], waitingSince: ago(0.5)))
        case "receiving": return (true, SyncCheck(events: [SyncCheck.Event(type: 1, ok: false, at: ago(1), unfinished: true)] + good))
        case "hung":
            // The last good ones came before it: a later good receive would leave this one behind.
            return (true, SyncCheck(events: [SyncCheck.Event(type: 1, ok: false, at: ago(12), unfinished: true),
                                             SyncCheck.Event(type: 2, ok: true, at: ago(14)), SyncCheck.Event(type: 1, ok: true, at: ago(13))]))
        case "failed":
            return (true, SyncCheck(events: [SyncCheck.Event(type: 2, ok: false, at: ago(1), domain: "CKErrorDomain", code: 25)] + good))
        case "waited":
            return (true, SyncCheck(events: [SyncCheck.Event(type: 2, ok: true, at: ago(90)), SyncCheck.Event(type: 1, ok: true, at: ago(2))],
                                    notSent: ["items": 2], waitingSince: ago(45)))
        case "unknown": return (true, nil)
        default: return (false, nil)
        }
    }()
}

/// The sync light on Home (0.92) — his yes of 19 Oct 2026 to "a small dot — green when both devices
/// are in step, orange while changes are waiting. A tap opens Sync details, so you see problems like
/// last week's without digging." Then, from four drawings, his pick B: "put the sync dot under the
/// This Device label" — his words before it: "it shall take up absolutely minimal space in the app
/// and not push anything downwards … Maybe just a small dot, and when you press it, you can get more
/// information." (The first 0.92 build had a line of its own under the three numbers.)
///
/// So: an 8-point dot at the foot of "This Device", in its narrow column, no words beside it —
/// green in sync, orange on its way, red stuck, grey can't tell (`SyncCheck.light`); none at all when
/// this copy keeps its library on the device. A tap — anywhere in 44 points round it — opens a small
/// bubble with one line (`SyncCheck.line`) and Details, which opens Sync details. It looks again
/// every 30 s while Home is shown, when the app comes back, and a second after the store changed.
struct SyncLight: View {
    @EnvironmentObject var model: LibraryModel
    @State private var seen: SyncWatch.Seen? = SyncWatch.last
    @State private var bubble = false
    /// Details was pressed in the bubble: Sync details opens once the bubble has gone.
    @State private var detailsNext = false
    @State private var details = false

    /// The dot's size, and the points a tap may land away from it on every side (8 + 2 × 18 = 44).
    static let dot: CGFloat = 8
    static let reach: CGFloat = 18
    /// The bubble's width: its line wraps inside it.
    static let bubbleWidth: CGFloat = 270

    /// The dot's colour — the section colours the app already uses for good (Trips green), on its
    /// way (Care orange) and wrong (To do red); grey in `muted`.
    static func color(_ c: SyncCheck.Light.Colour) -> Color {
        switch c {
        case .green: return AppSection.events.color
        case .orange: return AppSection.care.color
        case .red: return AppSection.actions.color
        case .grey: return Theme.muted
        }
    }

    /// The same colour as words on a card (0.101, the sync card's "In sync"): darkened by day and
    /// lightened by night until it reads as text does (`readableHex`); grey is `muted`, which reads.
    static func words(_ c: SyncCheck.Light.Colour, _ scheme: ColorScheme) -> Color {
        let hex: String
        switch c {
        case .green: hex = "#2f9e63"
        case .orange: hex = "#dd7324"
        case .red: hex = "#dc3d43"
        case .grey: return Theme.muted
        }
        return Color(hexString: readableHex(hex, dark: scheme == .dark))
    }

    var body: some View {
        if SyncWatch.on(model) {
            Group {
                if let seen, seen.on { dot(seen) }
                else { Color.clear.frame(width: SyncLight.dot, height: SyncLight.dot) }   // its place, before the first look
            }
            .task { await SyncWatch.keepLooking(model) { seen = $0 } }
            .onReceive(SyncWatch.storeChanged) { _ in Task { seen = await SyncWatch.look(model) } }
            .sheet(isPresented: $details) { SyncDetailsSheet().environmentObject(model) }
        }
    }

    private func dot(_ seen: SyncWatch.Seen) -> some View {
        let light = SyncCheck.light(usesICloud: true, check: seen.check, now: seen.now, awake: SyncWatch.awake)
        let tone = SyncLight.color(light.colour)
        let line = SyncCheck.line(light, check: seen.check, now: seen.now, awake: SyncWatch.awake)
        // The dot is drawn 8 points across; the button over it is 44 × 44 and invisible — an overlay, so the
        // column stays 16 wide and the block as tall. (A tap shape drawn wider than the dot worked on the
        // iPhone and not on the Mac: GitHub's Mac, 19 Oct 2026, a click 16 points above it opened nothing.)
        return Circle().fill(tone)
            .frame(width: SyncLight.dot, height: SyncLight.dot)
            .accessibilityHidden(true)
            .overlay {
                Button { bubble = true } label: {
                    Color.clear
                        .frame(width: SyncLight.dot + 2 * SyncLight.reach, height: SyncLight.dot + 2 * SyncLight.reach)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityLabel("iCloud sync")
                #if DEBUG
                // The tests' only way to see the dot's colour: the colour it is drawn in, then the words.
                .accessibilityValue("\(light.colour.rawValue) \u{00B7} \(line)")
                #else
                .accessibilityValue(line)
                #endif
                .accessibilityHint("Shows how the sync is going.")
                .accessibilityIdentifier("home-sync-light")
            }
            // To the dot's right, over the tiles: the dot is at the page's left edge. The iPhone (iOS 26) puts
            // the bubble on the side away from `arrowEdge` — `.trailing` there put it off the screen to the
            // left; the Mac reads it as the dot's edge the arrow points from.
            #if os(macOS)
            .popover(isPresented: $bubble, arrowEdge: .trailing) { bubbleView(light, line: line, tone: tone) }
            #else
            .popover(isPresented: $bubble, arrowEdge: .leading) { bubbleView(light, line: line, tone: tone) }
            #endif
    }

    /// The bubble: the dot again, the one line, and Details.
    private func bubbleView(_ light: SyncCheck.Light, line: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle().fill(tone).frame(width: SyncLight.dot, height: SyncLight.dot)
                Text(line)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(light == .stuck ? tone : Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home-sync-line")
            }
            Button {
                detailsNext = true
                bubble = false
            } label: {
                Text("Details").font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.settings.color)
                    .frame(minHeight: Metrics.compact).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .padding(.leading, SyncLight.dot + 8)
            .accessibilityIdentifier("home-sync-details")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        // A width of its own: a bubble takes its content's ideal width, and wrapping words have
        // none — at the screen's edge it shrank to a sliver (seen on the iPhone).
        .frame(width: SyncLight.bubbleWidth, alignment: .leading)
        .presentationCompactAdaptation(.popover)           // a bubble on the iPhone too, not a sheet
        .presentationBackground(Theme.card)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-sync-popover")
        // Sync details opens once the bubble has gone (two windows at once, SwiftUI shows neither),
        // a beat later: the bubble says it is gone while it is still fading.
        .onDisappear {
            guard detailsNext else { return }
            detailsNext = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { details = true }
        }
    }
}

/// Sync details, opened from Home's sync light (0.92): the sync card of Settings — the same card,
/// the same lines, Sync now and Copy details for Claude — in a sheet, with Done.
struct SyncDetailsSheet: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Sync details").font(.system(.title3, weight: .bold)).foregroundStyle(AppSection.settings.color)
                    .accessibilityIdentifier("sync-details-title")
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.settings.color, filled: true)).focusEffectDisabled()
                    .keyboardShortcut(.cancelAction)            // Escape closes it, as Done does
                    .commandS { dismiss() }                         // ⌘S = Done (0.103)
                    .accessibilityIdentifier("sync-details-done")
            }
            .padding(16)
            ScrollView {
                SyncCard().environmentObject(model)
                    .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sync-details")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 380)
        #else
        .presentationDetents([.medium, .large])
        #endif
    }
}
