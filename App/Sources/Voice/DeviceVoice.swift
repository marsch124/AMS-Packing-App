#if os(iOS)
import AVFoundation
import Speech
import PackingLibrary

/// The iPhone's own voice and ears for Pack by voice: an English voice speaks
/// (AVSpeechSynthesizer), and the five words are recognised ON THE DEVICE
/// (SFSpeechRecognizer with `requiresOnDeviceRecognition` — it works offline, in a garage,
/// and nothing he says leaves the iPhone). It works with AirPods: their microphone is
/// allowed in (Bluetooth hands-free) and the voice comes out where he hears it.
///
/// It never listens while it speaks, so it cannot hear itself ("Garage done …").
/// Not under the UI tests (`VoiceIOs.forThisLaunch`) — no simulator test opens it; it is
/// judged on his iPhone, on a real trip (spec 07 part 10).
@MainActor
final class DeviceVoice: NSObject, VoiceIO, AVSpeechSynthesizerDelegate {
    // What the button says when something is missing — his words, no computer talk.
    nonisolated static let speechRefused = "Packing may not understand speech. Allow it in Settings \u{2192} Privacy & Security \u{2192} Speech Recognition."
    nonisolated static let micRefused = "Packing may not use the microphone. Allow it in Settings \u{2192} Privacy & Security \u{2192} Microphone."
    nonisolated static let noEnglish = "This iPhone cannot yet understand English by itself. Add an English keyboard with Dictation on (Settings \u{2192} General \u{2192} Keyboard), then try again."
    nonisolated static let notReady = "Speech recognition is not ready just now. Try again in a moment."
    nonisolated static let noMicrophone = "The microphone could not be opened just now. Try again in a moment."
    nonisolated static let interruptedWords = "Stopped by a call or another app."
    nonisolated static let stoppedListening = "Listening stopped working. Start again in a moment."

    /// The English to understand and speak: his iPhone's own when it is US or British
    /// English, otherwise British, then American — whichever this iPhone recognises by itself.
    static var locales: [String] {
        let mine = Locale.preferredLanguages.map { $0.replacingOccurrences(of: "_", with: "-") }
            .first { $0 == "en-US" || $0 == "en-GB" }
        var out: [String] = []
        for l in [mine, "en-GB", "en-US"].compactMap({ $0 }) where !out.contains(l) { out.append(l) }
        return out
    }

    var interrupted: ((String) -> Void)?

    private let synth = AVSpeechSynthesizer()
    private let engine = AVAudioEngine()
    private let tap = VoiceTap()
    private var recognizer: SFSpeechRecognizer?
    private var voice: AVSpeechSynthesisVoice?
    private var open = false
    private var observers: [NSObjectProtocol] = []
    // Speaking
    private var utterance: ObjectIdentifier?
    private var spoken: (() -> Void)?
    // Listening
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var heard: ((String, Bool) -> Void)?
    private var lastText = ""
    private var pause: DispatchWorkItem?
    /// Times in a row the recogniser gave up without a word — after a few, it is not
    /// coming back, and the walk stops and says so.
    private var emptyRounds = 0

    /// How long a pause after words means he has finished saying them.
    private static let pauseAfterWords = 1.2

    override init() {
        super.init()
        synth.delegate = self
    }

    func prepare() async -> String? {
        let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard speech == .authorized else { return DeviceVoice.speechRefused }
        guard await AVAudioApplication.requestRecordPermission() else { return DeviceVoice.micRefused }
        var found: (SFSpeechRecognizer, String)?
        for l in DeviceVoice.locales {
            if let r = SFSpeechRecognizer(locale: Locale(identifier: l)), r.supportsOnDeviceRecognition { found = (r, l); break }
        }
        guard let (r, language) = found else { return DeviceVoice.noEnglish }
        guard r.isAvailable else { return DeviceVoice.notReady }
        recognizer = r
        voice = AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "en-GB")
        do {
            let session = AVAudioSession.sharedInstance()
            // Speaker when nothing is plugged in; AirPods' microphone allowed in; music ducked.
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP, .duckOthers])
            try session.setActive(true)
            try startEngine()
        } catch {
            finish()
            return DeviceVoice.noMicrophone
        }
        open = true
        watch()
        return nil
    }

    // MARK: Speaking

    func say(_ text: String, done: @escaping () -> Void) {
        endListening()
        spoken = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        utterance = ObjectIdentifier(u)
        spoken = done
        synth.speak(u)
    }

    private func said(_ id: ObjectIdentifier) {
        guard id == utterance, let done = spoken else { return }
        utterance = nil
        spoken = nil
        done()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.said(id) }
    }

    // MARK: Listening

    func listen(_ heard: @escaping (String, Bool) -> Void) {
        endListening()
        guard open, let recognizer else { return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.requiresOnDeviceRecognition = true
        req.shouldReportPartialResults = true
        req.taskHint = .confirmation
        req.contextualStrings = VoiceWord.expected
        req.addsPunctuation = false
        request = req
        self.heard = heard
        lastText = ""
        tap.set(req)
        task = DeviceVoice.recognise(recognizer, req) { [weak self] text, final, failed in
            self?.got(text, final: final, failed: failed, from: req)
        }
    }

    /// Formed outside the main actor: the recogniser calls back on its own queue.
    nonisolated private static func recognise(_ r: SFSpeechRecognizer, _ req: SFSpeechAudioBufferRecognitionRequest,
                                              _ back: @escaping @MainActor (String, Bool, Bool) -> Void) -> SFSpeechRecognitionTask {
        r.recognitionTask(with: req) { result, error in
            let text = result?.bestTranscription.formattedString ?? ""
            let final = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in back(text, final, failed) }
        }
    }

    private func got(_ text: String, final: Bool, failed: Bool, from req: SFSpeechAudioBufferRecognitionRequest) {
        guard req === request, let heard else { return }
        if final || failed {
            let words = text.isEmpty ? lastText : text
            endListening()
            if words.isEmpty {
                // The recogniser gave up on the quiet (it does after a while): listen again,
                // without a word — unless it keeps giving up at once.
                emptyRounds += 1
                if emptyRounds > 5 { interrupted?(DeviceVoice.stoppedListening); return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self, self.open, self.request == nil, self.spoken == nil else { return }
                    self.listen(heard)
                }
            } else {
                emptyRounds = 0
                heard(words, true)
            }
            return
        }
        guard text != lastText else { return }
        emptyRounds = 0
        lastText = text
        heard(text, false)
        // A pause after words: what he said is complete.
        pause?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.request === req else { return }
            let words = self.lastText
            self.endListening()
            heard(words, true)
        }
        pause = item
        DispatchQueue.main.asyncAfter(deadline: .now() + DeviceVoice.pauseAfterWords, execute: item)
    }

    private func endListening() {
        pause?.cancel()
        pause = nil
        tap.set(nil)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
    }

    // MARK: The microphone

    private func startEngine() throws {
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw VoiceTrouble.noInput }
        DeviceVoice.install(on: input, format: format, tap: tap)
        engine.prepare()
        try engine.start()
    }

    /// Formed outside the main actor: the tap runs on the audio thread.
    nonisolated private static func install(on input: AVAudioInputNode, format: AVAudioFormat, tap: VoiceTap) {
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in tap.feed(buffer) }
    }

    /// A call, Siri, or AirPods put in or taken out.
    private func watch() {
        let centre = NotificationCenter.default
        observers.append(centre.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            guard began else { return }
            Task { @MainActor in self?.interrupted?(DeviceVoice.interruptedWords) }
        })
        observers.append(centre.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.interrupted?(DeviceVoice.interruptedWords) }
        })
        // The sound went another way (AirPods in or out): the engine stops; start it again
        // on the new microphone.
        observers.append(centre.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.restart() }
        })
    }

    private func restart() {
        guard open else { return }
        do { try startEngine() } catch { interrupted?(DeviceVoice.noMicrophone) }
    }

    func finish() {
        endListening()
        heard = nil
        spoken = nil
        utterance = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        for o in observers { NotificationCenter.default.removeObserver(o) }
        observers = []
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        open = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

enum VoiceTrouble: Error { case noInput }

/// What the microphone's tap hands the recogniser: set on the main thread, read on the
/// audio thread — so behind a lock.
final class VoiceTap: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func set(_ r: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock(); request = r; lock.unlock()
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); let r = request; lock.unlock()
        r?.append(buffer)
    }
}
#endif
