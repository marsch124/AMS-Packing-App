import Foundation

/// A sync that hangs heals itself (0.104 — his "can we harden this?", 28 Oct 2026).
///
/// Twice on his Mac (21 Oct on 0.96, 28 Oct on 0.103) one exchange with iCloud never finished right
/// after a launch, and since iCloud's side of the store does ONE exchange at a time, nothing was
/// received again ("Stuck — Receiving has hung since …") until he quit Packing and opened it again.
/// The log of 28 Oct: TestFlight had opened the new build behind his other windows; the system took
/// the app for one in the background and held its first send back — not a byte sent in 387 s — and
/// every later request was turned away because one was pending. Opened again in front, it fetched in 2 s.
///
/// So the app now does what quitting and opening did, by itself: it restarts its connection to iCloud
/// (`StoreConnection`) when an exchange has run with no end for `restartAfter` — or, begun while the app
/// was not in front, still runs `behindAfter` after it came to the front. Only when it is safe, only in
/// front, a few times an hour at most; each restart is noted on this device (`Restart`) and said on the
/// sync card and in Home's sync dot. The rules here; the doing in the app (`SyncHealer`).
public enum SyncHeal {
    /// An exchange running this long with no end is restarted (5 minutes). His healthy exchanges end in
    /// seconds (a reopened app fetched in 2 s; his whole library — 1,438 records — came back in 10 s);
    /// one network request gives up after 60 s, and iCloud tries again on its own. Five minutes is far
    /// past all of that, and still half the ten minutes after which the card says Stuck — so a hang is
    /// usually mended before he could see it. A restart costs one read of the store (about 1.4 s on his
    /// library), so restarting a slow but healthy exchange costs little and loses nothing.
    public static let restartAfter: TimeInterval = 5 * 60
    /// An exchange that began while the app was NOT in front (held back by the system, as on 28 Oct) and
    /// still has no end this long after the app came to the front (1 minute: one request's own limit).
    public static let behindAfter: TimeInterval = 60
    /// Restarts by itself at most this often in an hour (no loops); Restart sync is never refused.
    public static let triesPerHour = 3

    /// One restart, as this device keeps it (the newest last).
    public struct Restart: Codable, Equatable {
        public enum Why: String, Codable { case receiving, sending, pressed }
        public var at: Date
        public var why: Why
        /// False: the store could not be opened again in place, or iCloud refused the new connection —
        /// only quitting Packing helps then.
        public var ok: Bool
        public init(at: Date, why: Why, ok: Bool = true) { self.at = at; self.why = why; self.ok = ok }
    }

    /// Why a restart that is due waits.
    public enum Wait: Equatable {
        /// A page holds changes not confirmed with Done (`OpenPages`) — or a save is under way.
        case page
        /// The app is not in front: a request made now would be held back again.
        case behind
        /// `triesPerHour` restarts in the last hour; the next is allowed at `until`.
        case tooOften(until: Date)
        /// The last restart did not take: only quitting and opening Packing helps.
        case didNotHelp
    }

    public enum Decision: Equatable {
        case nothing
        case restart(SyncCheck.Running)
        case wait(Wait, SyncCheck.Running)
    }

    /// The exchange stuck long enough to restart for — the one running longest — counted from its start,
    /// from `awake` (the iPhone pauses an exchange with the app) and from the last restart, whichever is
    /// latest; or, begun before the app last came to the front (`cameForward`), `behindAfter` after that.
    public static func stuck(_ check: SyncCheck?, now: Date, awake: Date = .distantPast, cameForward: Date? = nil,
                             lastRestart: Date? = nil, after: TimeInterval = restartAfter,
                             behind: TimeInterval = behindAfter) -> SyncCheck.Running? {
        guard let check else { return nil }
        let restarted = lastRestart ?? .distantPast
        return [check.receiving, check.sending].compactMap { $0 }.filter { r in
            if now.timeIntervalSince(max(r.since, awake, restarted)) >= after { return true }
            if let front = cameForward, r.since < front, now.timeIntervalSince(max(front, restarted)) >= behind { return true }
            return false
        }.min { $0.since < $1.since }
    }

    /// Restart now, wait, or nothing to do. `pageOpen`: a page holds unconfirmed changes, or a save is
    /// under way; `inFront`: the app is the one in front (Mac) or active (iPhone); `launched`: when this
    /// run of the app began — a restart that did not take stops the restarts of its own run only (the
    /// next launch is the fresh start that helps).
    public static func decide(_ check: SyncCheck?, now: Date, awake: Date = .distantPast, cameForward: Date? = nil,
                              inFront: Bool, pageOpen: Bool, restarts: [Restart], launched: Date = .distantPast,
                              after: TimeInterval = restartAfter, behind: TimeInterval = behindAfter) -> Decision {
        guard let r = stuck(check, now: now, awake: awake, cameForward: cameForward, lastRestart: restarts.last?.at,
                            after: after, behind: behind) else { return .nothing }
        if let last = restarts.last, !last.ok, last.at >= launched { return .wait(.didNotHelp, r) }
        let lastHour = restarts.filter { $0.why != .pressed && now.timeIntervalSince($0.at) < 3600 }
        if lastHour.count >= triesPerHour, let oldest = lastHour.map(\.at).min() {
            return .wait(.tooOften(until: oldest.addingTimeInterval(3600)), r)
        }
        if !inFront { return .wait(.behind, r) }
        if pageOpen { return .wait(.page, r) }
        return .restart(r)
    }

    /// Did the restart at `at` take? False once iCloud's setting-up of the new connection, begun after
    /// it, ended without success; nil while that is not known yet.
    public static func took(_ restart: Restart, check: SyncCheck?) -> Bool? {
        guard let s = check?.setup, s.unfinished == false, s.at >= restart.at else { return nil }
        return s.ok
    }

    // MARK: Words — plain, no computer talk

    /// What the last restart says, on the card and after Home's line: today's only.
    /// "Receiving was stuck — restarted the connection at 07:51."
    public static func words(_ restart: Restart?, now: Date, calendar: Calendar = .current) -> String? {
        guard let restart, calendar.isDate(restart.at, inSameDayAs: now) else { return nil }
        let at = SyncCheck.since(restart.at, now: now, calendar: calendar)
        guard restart.ok else { return "Restarting the connection at \(at) did not help \u{2014} quit Packing and open it again." }
        switch restart.why {
        case .receiving: return "Receiving was stuck \u{2014} restarted the connection at \(at)."
        case .sending: return "Sending was stuck \u{2014} restarted the connection at \(at)."
        case .pressed: return "Restarted the connection at \(at)."
        }
    }

    /// Why a restart waits, in his words (nil: nothing to say — the app is not in front, so not seen).
    public static func words(_ wait: Wait, now: Date, calendar: Calendar = .current) -> String? {
        switch wait {
        case .page: return "Restarts the connection as soon as the open page is closed."
        case .behind: return nil
        case .tooOften: return "It restarted \(triesPerHour) times in the last hour \u{2014} press Restart sync to try again."
        case .didNotHelp: return nil                                          // the restart's own words say it
        }
    }

    /// Home's line with the last restart after it (today's): "In sync · today 07:52. Receiving was
    /// stuck — restarted the connection at 07:51."
    public static func line(_ base: String, restart: Restart?, now: Date, calendar: Calendar = .current) -> String {
        guard let said = words(restart, now: now, calendar: calendar) else { return base }
        return base.hasSuffix("\u{2026}") ? "\(base) \(said)" : "\(base). \(said)"
    }

    /// For Copy details: every restart kept, newest first.
    public static func details(_ restarts: [Restart]) -> [String] {
        let f = ISO8601DateFormatter()
        return restarts.reversed().map { r in
            let why = r.why == .pressed ? "Restart sync pressed" : "\(r.why.rawValue) stuck"
            return "  restarted the connection \(f.string(from: r.at)) (\(why))\(r.ok ? "" : " \u{2014} DID NOT TAKE")"
        }
    }

    /// The restarts kept on a device: the newest `keep`.
    public static let keep = 20
    public static func noting(_ r: Restart, in restarts: [Restart]) -> [Restart] { Array((restarts + [r]).suffix(keep)) }
}
