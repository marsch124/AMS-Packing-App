#if os(iOS)
import Foundation
import PackingCore

// Hands-free packing (spec 07 part 10, a TEST version, 0.71) — iPhone only. The walk's
// decisions are the model's (`VoiceWalk`); speaking and listening are behind this
// protocol, so the UI tests drive the walk with a fake that "hears" words given by a
// launch argument, and never open the microphone.

/// The voice of the walk: what speaks and what listens.
@MainActor
protocol VoiceIO: AnyObject {
    /// Called when the walk can no longer go on by itself — a call came in, the microphone
    /// was lost — with the words the panel says.
    var interrupted: ((String) -> Void)? { get set }
    /// Asks for the microphone and speech recognition (the first time only) and opens
    /// them. nil = ready; otherwise what is missing, in his words, for under the button.
    func prepare() async -> String?
    /// Says `text` — it stops listening first — and calls `done` once it has been said.
    func say(_ text: String, done: @escaping () -> Void)
    /// Listens. `heard` gets what was heard so far each time it grows, and once more with
    /// `final` true when he paused (or the recogniser finished). Listening ends with the
    /// next `say` or `finish`.
    func listen(_ heard: @escaping (_ text: String, _ final: Bool) -> Void)
    /// Everything off: speech cut, the microphone closed, the sound given back.
    func finish()
}

enum VoiceIOs {
    /// The real voice — or, under the UI tests, ALWAYS the scripted one (no test opens a
    /// microphone):
    ///  -uiTestingVoice "packed it,skip,next"  → hears those, one after each thing it says
    ///  -uiTestingVoice ""                     → hears nothing (the buttons drive the walk)
    ///  -uiTestingVoiceRefused                 → the microphone is not allowed
    @MainActor static func forThisLaunch() -> VoiceIO {
        guard AMSPackingApp.testing else { return DeviceVoice() }
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiTestingVoiceRefused") { return ScriptedVoice(words: [], refused: DeviceVoice.micRefused) }
        var words: [String] = []
        if let n = args.firstIndex(of: "-uiTestingVoice"), n + 1 < args.count, !args[n + 1].hasPrefix("-") {
            words = args[n + 1].split(separator: ",").map { jsTrim(String($0)) }.filter { !$0.isEmpty }
        }
        return ScriptedVoice(words: words, refused: nil)
    }
}

/// The UI tests' voice: says nothing aloud (a beat per line), and "hears" its words one at
/// a time, each a moment after it starts listening — as he would answer.
@MainActor
final class ScriptedVoice: VoiceIO {
    var interrupted: ((String) -> Void)?
    private var words: [String]
    private let refused: String?
    /// Each say/listen/finish starts a new round; a word due in an older one is not heard.
    private var round = 0

    init(words: [String], refused: String?) {
        self.words = words
        self.refused = refused
    }

    func prepare() async -> String? { refused }

    func say(_ text: String, done: @escaping () -> Void) {
        round += 1
        let mine = round
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.round == mine else { return }
            done()
        }
    }

    func listen(_ heard: @escaping (String, Bool) -> Void) {
        round += 1
        let mine = round
        guard !words.isEmpty else { return }          // nothing more to hear: a quiet room
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, self.round == mine, !self.words.isEmpty else { return }
            heard(self.words.removeFirst(), true)
        }
    }

    func finish() { round += 1 }
}
#endif
