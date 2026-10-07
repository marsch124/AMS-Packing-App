import Foundation
import PackingCore

// Hands-free packing — spec 07 part 10, A TEST VERSION (his yes of 7 Oct 2026, in English,
// his choice). On a trip, "Pack by voice" walks the lines still to pack in "From where"
// order — the place, then the thing ("Garage. Goggles.") — and listens for five words:
// packed, skip, later, where, stop. Everything the walk DECIDES is here, with no speech
// in it, so the model tests hold it: which words are understood, in which order the
// lines come, what is said after each word. Speaking and listening are the app's
// (`App/Sources/Voice`), behind a protocol the UI tests replace.
//
// It is a test: kept only if, on a real trip, it understands him at least 9 times in 10,
// beats tapping, and he wants to use it again. Otherwise it is removed and the decision
// log (spec 07 part 11) says so.

/// The five words.
public enum VoiceWord: String, CaseIterable, Sendable {
    case packed, skip, later, `where`, stop

    /// Every way of saying each word that the walk accepts — THE list, in one place
    /// (spec 07 part 10). Lower case, no punctuation, an apostrophe left out ("that's" is
    /// "thats"): what `normalised` makes of what was heard. A phrase of several words is
    /// matched whole. No phrase is in two lists (`VoiceWalkTests` holds that).
    ///
    /// Forgiving on purpose: a recogniser often writes a short word as its neighbour
    /// ("packet", "pact" for packed; "wear" for where), and he says what comes naturally
    /// ("got it", "next", "not this time"). Left out on purpose: a bare "no" (too often a
    /// start of something else — "no wait, packed"), "back", and "wait" (he is looking for
    /// it: the walk should wait, not move on).
    public static let accepted: [(word: VoiceWord, says: [String])] = [
        (.packed, ["packed", "pack", "packs", "packed it", "pack it", "packet", "pact", "backed",
                   "got it", "have it", "done", "yes", "yeah", "yep", "ok", "okay", "check", "tick", "ticked", "in the bag"]),
        (.skip, ["skip", "skipped", "skips", "skipping", "skip it", "not this time", "set aside", "aside",
                 "leave it", "nope", "not needed", "dont need it", "not taking it"]),
        (.later, ["later", "later on", "next", "next one", "not yet", "after", "afterwards", "pass",
                  "come back", "move on"]),
        (.where, ["where", "wheres", "where is it", "where is that", "wear", "were", "ware",
                  "repeat", "again", "say again", "pardon", "sorry", "what", "which place"]),
        (.stop, ["stop", "stop it", "stopped", "end", "quit", "finish", "finished", "enough", "cancel",
                 "all done", "im done", "thats all", "thats it", "halt"]),
    ]

    /// The words for the recogniser to expect (its contextual strings): every phrase above.
    public static var expected: [String] { accepted.flatMap(\.says) }

    /// What was heard, as the lists are written: lower case, an apostrophe left out, every
    /// other mark a space, one space between words.
    public static func normalised(_ text: String) -> [String] {
        let quiet = text.lowercased().replacingOccurrences(of: "\u{2019}", with: "").replacingOccurrences(of: "'", with: "")
        let spaced = String(quiet.map { $0.isLetter || $0.isNumber ? $0 : " " })
        return spaced.split(separator: " ").map(String.init)
    }

    /// The word in what was heard, or nil. The FIRST phrase in it wins ("where did I pack
    /// it" asks where) — the recogniser reports a few words at a time and the walk acts on
    /// the first word it understands — and at each place the longest phrase ("all done"
    /// is stop, "done" alone is packed).
    public static func heard(_ text: String) -> VoiceWord? {
        let words = normalised(text)
        guard !words.isEmpty else { return nil }
        let longest = accepted.flatMap(\.says).map { $0.split(separator: " ").count }.max() ?? 1
        for i in words.indices {
            for n in stride(from: min(longest, words.count - i), through: 1, by: -1) {
                let phrase = words[i..<(i + n)].joined(separator: " ")
                if let hit = accepted.first(where: { $0.says.contains(phrase) }) { return hit.word }
            }
        }
        return nil
    }
}

/// What a word does to the trip's line.
public enum VoiceAction: Equatable, Sendable {
    /// Packed: the line is ticked.
    case tick(entryId: String)
    /// Skip: the line is set aside — "not this time", as ⊘ does (its tick goes too).
    case setAside(entryId: String)
    /// Later, where, stop: the trip is left as it is.
    case none
}

/// One walk over a trip's lines. A value: the app holds it while the walk runs and
/// nothing of it is stored — a walk lives as long as its panel.
public struct VoiceWalk: Equatable, Sendable {
    /// One line to ask about.
    public struct Step: Equatable, Sendable {
        public let entryId: String
        public let name: String
        /// Its heading sorted From where: the place it is kept, or "No place set".
        public let place: String
        /// "Wool socks, 4" — what is said for it: the name as written, and how many when
        /// more than one.
        public let says: String
    }

    /// One answer, for the panel's log — and for his count of how often it understood.
    public struct Turn: Equatable, Sendable {
        public let name: String
        public let word: VoiceWord
        /// What the recogniser heard; nil when the word was TAPPED.
        public let heard: String?
    }

    /// Progress is said after this many answers in one place.
    public static let progressEvery = 5
    /// What a line with no place sits under, as the trip's From where heading says.
    public static let noPlace = "No place set"

    public let tripId: String
    public private(set) var steps: [Step]
    /// The step being asked about; `steps.count` once the walk is over.
    public private(set) var at = 0
    /// Answers (packed, skip, later) since progress was last said.
    public private(set) var sinceProgress = 0
    public private(set) var packed = 0
    public private(set) var setAside = 0
    public private(set) var leftForLater: [String] = []
    /// The lines left for later, for the second round.
    private var laterSteps: [Step] = []
    /// 1, or 2 once he said yes to "once more?" (his yes of 7 Oct 2026). Only one more round.
    public private(set) var round = 1
    /// The walk reached the end with things left for later and asks "once more?":
    /// packed (or yes, ok …) starts the second round; where asks again; any other word ends it.
    public private(set) var askingOnceMore = false
    /// Words heard and understood, and things heard that were none of the five — his
    /// measure: at least 9 of 10 understood.
    public private(set) var understood = 0
    public private(set) var missed = 0
    public private(set) var tapped = 0
    public private(set) var log: [Turn] = []
    public private(set) var stopped = false

    /// The walk over `trip`'s lines still to pack, starting at `place` when one is given
    /// (a place opened by its printed code, part 3).
    public init(trip: TripEvent, startAt place: String? = nil) {
        tripId = trip.id
        steps = VoiceWalk.steps(trip.entries, nights: qtyNights(trip), startAt: place)
    }

    /// The lines to ask about, in the trip's "From where" order (`groupByStorage`: places
    /// A–Z, "No place set" last; inside a place the trip's own order), ticked and set-aside
    /// lines left out. Given a place, the walk starts at it and goes on round: that place,
    /// the ones after it, then the ones before. A place the trip does not have (or that has
    /// nothing left) is no start: the walk begins where it always does.
    public static func steps(_ entries: [Item], nights: Int = 0, startAt place: String? = nil) -> [Step] {
        var groups = groupByStorage(entries.filter { !$0.checked && !isSetAside($0) })
        if let place, !Library.choiceKey(place).isEmpty,
           let n = groups.firstIndex(where: { Library.choiceKey($0.label) == Library.choiceKey(place) }) {
            groups = Array(groups[n...] + groups[..<n])
        }
        return groups.flatMap { g in
            g.entries.map { e in
                let name = jsTrim(e.name)
                let qty = effectiveQty(e, nights)
                let many = qty > 1 ? ", \(qty.rounded() == qty ? String(Int(qty)) : String(qty))" : ""
                return Step(entryId: e.id, name: name, place: g.label, says: "\(name)\(many)")
            }
        }
    }

    public var current: Step? { at < steps.count ? steps[at] : nil }
    public var isOver: Bool { stopped || (at >= steps.count && !askingOnceMore) }

    /// What the word does to the line being asked about.
    public func action(for word: VoiceWord) -> VoiceAction {
        guard let step = current, !stopped else { return .none }
        switch word {
        case .packed: return .tick(entryId: step.entryId)
        case .skip: return .setAside(entryId: step.entryId)
        case .later, .where, .stop: return .none
        }
    }

    /// The first words: how many, and the first thing with its place.
    /// "7 to pack. Bathroom cabinet. Toothbrush."
    public func opening() -> String {
        guard let step = current else { return "Nothing left to pack." }
        return "\(steps.count) to pack. \(step.place). \(step.says)."
    }

    /// "12 of 40" — the trip's own count, as its screen shows it (set-aside lines out).
    public static func count(_ trip: TripEvent?) -> String {
        let p = progress(trip?.entries ?? [])
        return "\(p.done) of \(p.total)"
    }

    /// Something heard that was none of the five words: counted, and asked again.
    public mutating func notUnderstood() -> String {
        missed += 1
        return "Sorry?"
    }

    /// After the word is applied to the trip (`action`), move on and say what comes next.
    /// `heard` is what the recogniser heard (nil = the word was tapped); `trip` is the trip
    /// AFTER the word, so the count is right — and a line ticked meanwhile (on the other
    /// device, or by hand) is passed over without being asked.
    public mutating func answer(_ word: VoiceWord, heard: String?, trip: TripEvent?) -> String {
        if askingOnceMore, !stopped { return onceMore(word, heard: heard, trip: trip) }
        guard let step = current, !stopped else { return VoiceWalk.ending(self, trip) }
        if heard == nil { tapped += 1 } else { understood += 1 }
        log.append(Turn(name: step.name, word: word, heard: heard))
        switch word {
        case .where:
            return "\(step.place). \(step.says)."
        case .stop:
            stopped = true
            return "Stopped. \(VoiceWalk.count(trip)) packed."
        case .packed: packed += 1
        case .skip: setAside += 1
        case .later: leftForLater.append(step.name); laterSteps.append(step)
        }
        sinceProgress += 1
        at += 1
        // Passed over: lines no longer waiting (ticked or set aside elsewhere, or gone).
        let waiting = Set((trip?.entries ?? []).filter { !$0.checked && !isSetAside($0) }.map(\.id))
        while at < steps.count, !waiting.contains(steps[at].entryId) { at += 1 }
        guard let next = current else { return endOfRound(trip) }
        if next.place != step.place {
            sinceProgress = 0
            return "\(step.place) done, \(VoiceWalk.count(trip)). \(next.place). \(next.says)."
        }
        if sinceProgress >= VoiceWalk.progressEvery {
            sinceProgress = 0
            return "\(VoiceWalk.count(trip)). \(next.says)."
        }
        return "\(next.says)."
    }

    /// The end of the list. In the first round, with lines left for later that still wait:
    /// "That was everything. 6 of 7 packed. 1 left for later — once more?" — and it waits for
    /// the answer. Otherwise the walk ends.
    private mutating func endOfRound(_ trip: TripEvent?) -> String {
        let waiting = Set((trip?.entries ?? []).filter { !$0.checked && !isSetAside($0) }.map(\.id))
        laterSteps = laterSteps.filter { waiting.contains($0.entryId) }
        leftForLater = laterSteps.map(\.name)
        guard round == 1, !laterSteps.isEmpty else { return VoiceWalk.ending(self, trip) }
        askingOnceMore = true
        return "That was everything. \(VoiceWalk.count(trip)) packed. \(VoiceWalk.onceMoreQuestion(laterSteps.count))"
    }

    /// "1 left for later — once more?"
    public static func onceMoreQuestion(_ n: Int) -> String { "\(n) left for later \u{2014} once more?" }

    /// The answer to "once more?".
    private mutating func onceMore(_ word: VoiceWord, heard: String?, trip: TripEvent?) -> String {
        if heard == nil { tapped += 1 } else { understood += 1 }
        log.append(Turn(name: "Once more?", word: word, heard: heard))
        switch word {
        case .where:
            return VoiceWalk.onceMoreQuestion(laterSteps.count)
        case .packed:
            askingOnceMore = false
            round = 2
            steps = laterSteps
            laterSteps = []
            leftForLater = []
            at = 0
            sinceProgress = 0
            let first = steps[0]
            return "Once more. \(first.place). \(first.says)."
        case .skip, .later, .stop:
            askingOnceMore = false
            stopped = true
            return "Stopped. \(VoiceWalk.count(trip)) packed. \(leftForLater.count) left for later."
        }
    }

    /// The last words of a walk that reached the end of the list.
    /// "That was everything. 6 of 7 packed. 1 left for later."
    static func ending(_ walk: VoiceWalk, _ trip: TripEvent?) -> String {
        let later = walk.leftForLater.count
        return "That was everything. \(count(trip)) packed." + (later > 0 ? " \(later) left for later." : "")
    }

    /// The panel's summary when the walk is over: "Packed 4 · set aside 1 · later 2".
    public var summary: String {
        "Packed \(packed) · set aside \(setAside) · later \(leftForLater.count)"
    }

    /// His measure (≥ 9 in 10): "Understood 9 of 10 times" — what was heard; taps apart.
    public var understoodLine: String {
        let heard = understood + missed
        let taps = tapped > 0 ? " · \(tapped) tapped" : ""
        return heard == 0 ? "Nothing heard\(taps)" : "Understood \(understood) of \(heard) times\(taps)"
    }

    /// One answer in words, for the panel's log: "Toothbrush · packed · “packed it”".
    public static func line(_ turn: Turn) -> String {
        "\(turn.name) · \(turn.word.rawValue)" + (turn.heard.map { " · \u{201C}\($0)\u{201D}" } ?? " · tapped")
    }
}

extension Library {
    /// Apply what a word does to a trip's line (`VoiceWalk.action`). Returns whether
    /// anything changed — later, where and stop change nothing.
    @discardableResult
    public mutating func apply(_ action: VoiceAction, tripId: String) -> Bool {
        switch action {
        case .tick(let id): return setChecked(true, tripId: tripId, entryId: id)
        case .setAside(let id): return setAside(true, tripId: tripId, entryId: id)
        case .none: return false
        }
    }
}
