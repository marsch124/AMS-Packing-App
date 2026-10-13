import Foundation

/// Today as a YYYY-MM-DD string in HIS time zone. The model's date helpers take
/// "today" as a parameter; given nothing they use the UTC date, which in Sweden
/// is yesterday until 01:00 (02:00 in summer) — the web app's countdown lags
/// exactly that way. The app always passes this.
enum Today {
    /// The app's clock: the device's — or, under the UI tests with `-clockAt HH:mm:ss`, today
    /// at that time when the app opened, running on from there (0.75: a trip sets off at the
    /// time he leaves, and a test cannot wait for 08:00).
    static var now: Date { shift.map { Date().addingTimeInterval($0) } ?? Date() }

    /// How far the UI tests' clock is from the device's; nil = not moved. Read once.
    private static let shift: TimeInterval? = {
        let args = ProcessInfo.processInfo.arguments
        guard AMSPackingApp.testing, let n = args.firstIndex(of: "-clockAt"), n + 1 < args.count else { return nil }
        let t = args[n + 1].split(separator: ":").compactMap { Int($0) }
        guard t.count >= 2, let at = Calendar.current.date(bySettingHour: t[0], minute: t[1], second: t.count > 2 ? t[2] : 0, of: Date())
        else { return nil }
        return at.timeIntervalSince(Date())
    }()

    static var local: String { plain.string(from: now) }

    /// The time of day now, "HH:mm" — what a trip's "I leave at" is compared with.
    static var time: String { time(of: now) }
    /// A moment's time of day, "HH:mm".
    static func time(of d: Date) -> String { String(stamp(d).suffix(5)) }

    private static var plain: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private static var minutes: DateFormatter {
        let f = plain
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }

    /// A YYYY-MM-DD string as a date at midnight here, or nil if it is not one.
    static func date(_ iso: String) -> Date? { plain.date(from: iso) }
    /// The other way about.
    static func iso(_ d: Date) -> String { plain.string(from: d) }
    /// A moment in the model's words, "2026-10-14 08:00" (this device's time zone).
    static func stamp(_ d: Date) -> String { minutes.string(from: d) }
    /// The other way about; nil if it is not one.
    static func moment(_ s: String) -> Date? { minutes.date(from: s) }
}
