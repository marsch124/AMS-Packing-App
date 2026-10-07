#if os(iOS)
import SwiftUI
import PackingCore
import PackingLibrary

/// The trip's Sorting row with "Pack by voice" at its end (iPhone only — the Mac has no
/// such button). On a narrow iPhone the button says "Voice", so Sorting's field keeps
/// room for "From where". Pressed when it cannot start, the reason is said under the row
/// (`voice-start-needs`) — the button itself is never grey (his rule).
struct VoiceSortingRow<Sorting: View>: View {
    let tripId: String
    /// Start the walk at this place (a place opened by its printed code, spec 07 part 3).
    var startAt: String? = nil
    @ViewBuilder var sorting: () -> Sorting
    @EnvironmentObject var model: LibraryModel
    @StateObject private var walker = VoiceWalker()
    @State private var open = false
    @State private var needs = ""
    @State private var starting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { sorting(); door("Pack by voice") }
                HStack(spacing: 8) { sorting(); door("Voice") }
            }
            if !needs.isEmpty {
                Text(needs)
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("voice-start-needs")
            }
        }
        .sheet(isPresented: $open, onDismiss: { walker.close() }) {
            VoicePanel(walker: walker, tripId: tripId) { open = false }
                .environmentObject(model)
        }
    }

    private func door(_ title: String) -> some View {
        Button { begin() } label: {
            HStack(spacing: 6) {
                MicMark().frame(width: 18, height: 18)
                Text(title).font(.system(.subheadline, weight: .semibold)).lineLimit(1)
            }
            .fixedSize()
            .foregroundStyle(AppSection.events.color)
            .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
            .background(Capsule().fill(AppSection.events.color.opacity(0.10)))
            .overlay(Capsule().stroke(AppSection.events.color, lineWidth: 1.4))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("voice-start")
        .accessibilityLabel("Pack by voice")
    }

    private func begin() {
        guard !starting else { return }
        starting = true
        needs = ""
        Task {
            let missing = await walker.start(tripId: tripId, at: startAt, model: model)
            starting = false
            if let missing { needs = missing } else { open = true }
        }
    }
}

/// The big panel while the walk runs: the thing being asked about and its place, what
/// was said and heard, and the five words as buttons — a tap does what the word does.
/// Stop is always on it. When the walk is over: what it did, how often it understood
/// him and how long it took — his measure for this test (≥ 9 in 10, faster than tapping).
struct VoicePanel: View {
    @ObservedObject var walker: VoiceWalker
    let tripId: String
    let close: () -> Void
    @EnvironmentObject var model: LibraryModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let running = walker.phase == .running
        VStack(spacing: 0) {
            header(running)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 14) {
                    if running { now } else { over }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.bottom, 16)
            }
            if running { words }
        }
        .background(Theme.bg.ignoresSafeArea())
        .interactiveDismissDisabled(running)
        // Put away, the iPhone can no longer listen: the walk stops and says why.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { walker.cut("Stopped when Packing was put away.") }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice-panel")
    }

    private func header(_ running: Bool) -> some View {
        HStack(spacing: 10) {
            Text("Pack by voice").font(.system(.title3, weight: .bold)).foregroundStyle(AppSection.events.color)
            // It is a test (his yes of 7 Oct 2026): kept only if it earns its place.
            Text("A test").font(.system(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .overlay(Capsule().stroke(Theme.muted, lineWidth: 1))
            Spacer()
            if !running {
                Button("Done") { close() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: true)).focusEffectDisabled()
                    .accessibilityIdentifier("voice-done")
            }
        }
        .padding(16)
    }

    /// While it runs: the count, the place, the thing, what was said and heard.
    @ViewBuilder private var now: some View {
        let trip = model.library.trip(tripId)
        HStack(spacing: 8) {
            Circle().fill(walker.listening ? AppSection.events.color : Theme.line).frame(width: 10, height: 10)
            Text(walker.listening ? "Listening" : "Speaking")
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("voice-listening")
            Spacer()
            Text("\(VoiceWalk.count(trip)) packed")
                .font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("voice-progress")
        }
        VStack(alignment: .leading, spacing: 6) {
            Text(walker.walk?.current?.place ?? "")
                .font(.system(.title3, weight: .semibold)).foregroundStyle(AppSection.events.color)
                .accessibilityIdentifier("voice-place")
            Text(walker.walk?.current?.says ?? "")
                .font(.system(.largeTitle, weight: .bold)).foregroundStyle(Theme.ink)
                .lineLimit(3).minimumScaleFactor(0.6)
                .accessibilityIdentifier("voice-current")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppSection.events.color, lineWidth: 1.2))
        said
    }

    /// What it said last, and what it heard — so a word it misheard can be seen.
    private var said: some View {
        VStack(alignment: .leading, spacing: 4) {
            line("Said", walker.said, "voice-said")
            line("Heard", walker.heard.isEmpty ? "" : "\u{201C}\(walker.heard)\u{201D}", "voice-heard")
        }
    }

    private func line(_ label: String, _ words: String, _ id: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                .frame(width: 44, alignment: .leading)
            Text(words).font(.system(.callout)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(id)
        }
    }

    /// When it is over: what it did, how often it understood, how long it took, and every
    /// answer in a list — his measure for this test.
    @ViewBuilder private var over: some View {
        let w = walker.walk
        VStack(alignment: .leading, spacing: 8) {
            if !walker.cutShort.isEmpty {
                Text(walker.cutShort).font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .accessibilityIdentifier("voice-cut")
            }
            Text(walker.said).font(.system(.title3, weight: .semibold)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("voice-said")
            Text(w?.summary ?? "").font(.system(.body)).foregroundStyle(Theme.ink)
                .accessibilityIdentifier("voice-summary")
            Text(w?.understoodLine ?? "").font(.system(.body)).foregroundStyle(Theme.ink)
                .accessibilityIdentifier("voice-understood")
            Text(walker.timeLine).font(.system(.body).monospacedDigit()).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("voice-time")
            if let later = w?.leftForLater, !later.isEmpty {
                Text("Left for later: " + later.joined(separator: ", "))
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("voice-later")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
        if let log = w?.log, !log.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(log.enumerated()), id: \.offset) { n, turn in
                    Text(VoiceWalk.line(turn))
                        .font(.system(.subheadline)).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: Metrics.line, alignment: .leading)
                        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        .accessibilityIdentifier("voice-log-\(n)")
                }
            }
        }
    }

    /// The five words as buttons, under everything and always there while it runs: Packed
    /// the widest and filled, Stop last on a line of its own.
    private var words: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                word(.packed, "Packed", filled: true)
                word(.skip, "Skip")
            }
            HStack(spacing: 10) {
                word(.later, "Later")
                word(.where, "Where")
            }
            word(.stop, "Stop", tint: AppSection.actions.color)
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
        .background(Theme.bg)
        .overlay(alignment: .top) { Theme.line.frame(height: 1) }
    }

    private func word(_ w: VoiceWord, _ title: String, filled: Bool = false, tint: Color = AppSection.events.color) -> some View {
        Button { walker.answer(w, heard: nil) } label: {
            Text(title).font(.system(.title3, weight: .semibold))
                .foregroundStyle(filled ? Color.white : tint)
                .frame(maxWidth: .infinity, minHeight: VoicePanel.wordHeight)
                .background(RoundedRectangle(cornerRadius: 12).fill(filled ? tint : tint.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: filled ? 0 : 1.4))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("voice-word-\(w.rawValue)")
    }

    /// The word buttons: Apple's large button height — to be hit while carrying things.
    static let wordHeight: CGFloat = 50
}

/// A microphone, drawn on the 24-point grid — no stock icons (his rule).
struct MicMark: View {
    var body: some View {
        GridShape(d: "M12 3.5a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0v-5a3 3 0 0 1 3-3ZM6.5 11.5a5.5 5.5 0 0 0 11 0M12 17v3.5M8.5 20.5h7")
            .stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
            .accessibilityHidden(true)
    }
}
#endif
