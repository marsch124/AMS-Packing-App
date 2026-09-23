import Foundation

/// Today as a YYYY-MM-DD string in HIS time zone. The model's date helpers take
/// "today" as a parameter; given nothing they use the UTC date, which in Sweden
/// is yesterday until 01:00 (02:00 in summer) — the web app's countdown lags
/// exactly that way. The app always passes this.
enum Today {
    static var local: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static var plain: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    /// A YYYY-MM-DD string as a date at midnight here, or nil if it is not one.
    static func date(_ iso: String) -> Date? { plain.date(from: iso) }
    /// The other way about.
    static func iso(_ d: Date) -> String { plain.string(from: d) }
}
