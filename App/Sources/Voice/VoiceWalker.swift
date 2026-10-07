#if os(iOS)
import SwiftUI
import UIKit
import PackingCore
import PackingLibrary

/// Runs one walk of Pack by voice: says a line, listens, applies the word to the trip
/// (`VoiceWalk.action` → `Library.apply`, one `model.change`, as a tap does), says the
/// next. A word tapped on the panel goes the same way as one heard.
@MainActor
final class VoiceWalker: ObservableObject {
    enum Phase: Equatable { case off, running, over }

    @Published private(set) var phase: Phase = .off
    @Published private(set) var walk: VoiceWalk?
    /// The last thing said, and what was heard since — shown on the panel, so a word it
    /// misheard can be seen ("Heard: “pact”").
    @Published private(set) var said = ""
    @Published private(set) var heard = ""
    @Published private(set) var listening = false
    @Published private(set) var began: Date?
    @Published private(set) var ended: Date?
    /// Why the walk ended without his word (a call came in, Packing was put away).
    @Published private(set) var cutShort = ""

    private var io: VoiceIO?
    private weak var model: LibraryModel?
    /// Each say and each listen is a round; an answer from an older round is not used.
    private var round = 0

    /// Start walking `tripId`'s lines still to pack — at `place` when one is given (a place
    /// opened by its printed code). nil = it runs; otherwise what is missing, for the line
    /// under the button (his rule: the button is never grey, it says).
    func start(tripId: String, at place: String?, model: LibraryModel) async -> String? {
        guard let trip = model.library.trip(tripId) else { return "This trip is no longer here." }
        let walk = VoiceWalk(trip: trip, startAt: place)
        guard !walk.isOver else { return "Everything on this trip is packed or set aside." }
        let io = self.io ?? VoiceIOs.forThisLaunch()
        self.io = io
        io.interrupted = { [weak self] why in self?.cut(why) }
        if let missing = await io.prepare() { return missing }
        self.model = model
        self.walk = walk
        heard = ""
        cutShort = ""
        began = Date()
        ended = nil
        phase = .running
        // The screen stays on while it runs: put away, the iPhone stops listening.
        UIApplication.shared.isIdleTimerDisabled = true
        speak(walk.opening())
        return nil
    }

    /// A word — heard (`text`) or tapped on the panel (nil).
    func answer(_ word: VoiceWord, heard text: String?) {
        guard phase == .running, var w = walk, !w.isOver, let model else { return }
        let action = w.action(for: word)
        if action != .none { model.change { $0.apply(action, tripId: w.tripId) } }
        let next = w.answer(word, heard: text, trip: model.library.trip(w.tripId))
        walk = w
        speak(next, thenEnd: w.isOver)
    }

    /// Ended without his word: everything off, and the panel says why.
    func cut(_ why: String) {
        guard phase == .running else { return }
        cutShort = why
        end()
    }

    /// The panel closed: everything off, quietly, and ready for the next walk.
    func close() {
        if phase == .running { end() }
        phase = .off
        walk = nil
        said = ""
        heard = ""
    }

    private func speak(_ text: String, thenEnd: Bool = false) {
        round += 1
        let mine = round
        listening = false
        said = text
        io?.say(text) { [weak self] in
            guard let self, self.round == mine, self.phase == .running else { return }
            if thenEnd { self.end() } else { self.listen() }
        }
    }

    private func listen() {
        round += 1
        let mine = round
        listening = true
        io?.listen { [weak self] text, final in
            guard let self, self.round == mine, self.phase == .running else { return }
            self.heard = text
            if let word = VoiceWord.heard(text) {
                self.answer(word, heard: jsTrim(text))
            } else if final, !jsTrim(text).isEmpty, var w = self.walk {
                let sorry = w.notUnderstood()
                self.walk = w
                self.speak(sorry)
            }
        }
    }

    private func end() {
        round += 1
        io?.finish()
        listening = false
        phase = .over
        ended = Date()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// "Took 2 min 10 s · 3.1 things a minute" — the other half of his measure: faster
    /// than tapping.
    var timeLine: String {
        guard let began, let w = walk else { return "" }
        let seconds = max(1, Int((ended ?? Date()).timeIntervalSince(began).rounded()))
        let things = w.packed + w.setAside + w.leftForLater.count
        let took = seconds >= 60 ? "\(seconds / 60) min \(seconds % 60) s" : "\(seconds) s"
        let rate = Double(things) / (Double(seconds) / 60)
        return "Took \(took) · \(String(format: "%.1f", rate)) things a minute"
    }
}
#endif
