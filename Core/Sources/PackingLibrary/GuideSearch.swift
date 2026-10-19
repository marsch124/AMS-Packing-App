import Foundation
import PackingCore

// Search in How it works (0.90) — his ask of 19 Oct 2026: "Search function in How-it-works.
// There is a lot of information in how it works, and I really like that. Keep up the good
// work in making it extensive. The search function will make it even better."
//
// The guide's words live in the app (they are its screens' words); what a search matches,
// and what of a part it shows, is decided here, where the model's tests can hold it.
//
// Words are matched as the app's other searches match them (`normName`: case and runs of
// spaces do not count) — and, the guide being prose he did not type himself, accents and
// the curly and straight forms of ' and " do not count either: "trip's" typed on the Mac
// (straight) finds "trip’s" written with the curly one, and the iPhone's curly one finds a
// straight one; "cafe" finds "café". The words are one
// phrase, as everywhere in the app: "bag weight" finds "bag weight", not "bag … weight".

public enum GuideSearch {
    /// One part of the guide as the search reads it: its heading and its paragraphs, in order.
    public struct Part: Equatable, Sendable {
        public let title: String
        public let paragraphs: [String]
        public init(title: String, paragraphs: [String]) {
            self.title = title
            self.paragraphs = paragraphs
        }
    }

    /// A part the words are in, and what of it to show.
    public struct Found: Equatable, Sendable {
        /// Which part: its place in the list searched.
        public let part: Int
        /// Its heading holds the words.
        public let titleHolds: Bool
        /// The paragraphs to show, in the guide's order: the ones holding the words — or,
        /// when only the heading holds them, every paragraph of the part (the part is ABOUT
        /// them: "iPhone and Mac" shows that whole part, though no paragraph says it).
        public let paragraphs: [Int]
        /// How many places the words are in: the heading, if it holds them, and each
        /// paragraph that does (a paragraph holding them twice is one place).
        public let places: Int
    }

    /// The query as the guide is searched for it; "" = no search (the whole guide shows).
    public static func needle(_ query: String) -> String { straightened(normName(query)) }

    /// ‘ ’ ‛ ′ become ' and “ ” „ ″ become " — each ONE UTF-16 unit for one, so a place
    /// found in the straightened words is at the same offset in the words as written.
    static func straightened(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            switch u.value {
            case 0x2018, 0x2019, 0x201B, 0x2032: out.append("'")
            case 0x201C, 0x201D, 0x201E, 0x2033: out.append("\"")
            default: out.append(u)
            }
        }
        return String(out)
    }

    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// Does `text` hold `needle` (already `needle(_:)`-ed)?
    public static func holds(_ text: String, _ needle: String) -> Bool {
        !needle.isEmpty && straightened(text).range(of: needle, options: options) != nil
    }

    /// Every place `needle` (already `needle(_:)`-ed) stands in `text`, in order, none
    /// overlapping — as ranges of `text` itself, for the screen to mark.
    public static func ranges(of needle: String, in text: String) -> [Range<String.Index>] {
        guard !needle.isEmpty else { return [] }
        let hay = straightened(text)
        guard hay.utf16.count == text.utf16.count else { return [] }
        var out: [Range<String.Index>] = []
        var from = hay.startIndex
        while from < hay.endIndex, let r = hay.range(of: needle, options: options, range: from..<hay.endIndex) {
            guard !r.isEmpty else { break }
            let lo = r.lowerBound.utf16Offset(in: hay), hi = r.upperBound.utf16Offset(in: hay)
            out.append(String.Index(utf16Offset: lo, in: text)..<String.Index(utf16Offset: hi, in: text))
            from = r.upperBound
        }
        return out
    }

    /// The parts the words are in, in the guide's order. One pass over a few hundred
    /// paragraphs: it runs on every key press.
    public static func find(_ query: String, in parts: [Part]) -> [Found] {
        let n = needle(query)
        guard !n.isEmpty else { return [] }
        var out: [Found] = []
        for (i, part) in parts.enumerated() {
            let title = holds(part.title, n)
            let hits = part.paragraphs.indices.filter { holds(part.paragraphs[$0], n) }
            if hits.isEmpty && !title { continue }
            out.append(Found(part: i, titleHolds: title,
                             paragraphs: hits.isEmpty ? Array(part.paragraphs.indices) : hits,
                             places: hits.count + (title ? 1 : 0)))
        }
        return out
    }

    /// The count line: "1 place", "4 places".
    public static func placesWords(_ found: [Found]) -> String {
        let n = found.reduce(0) { $0 + $1.places }
        return n == 1 ? "1 place" : "\(n) places"
    }
}
