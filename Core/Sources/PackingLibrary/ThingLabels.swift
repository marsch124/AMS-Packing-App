import Foundation
import CoreGraphics
import PackingCore

// 0.124 — labels for things (his pick of 12 Nov 2026), as places have had since 0.69: a 12 mm P-touch
// label with a square code and the name. The code holds AMSPACKING://T/<code> — the thing's own four
// letters and digits, kept in `extra["labelCode"]` so a printed label keeps meaning that thing (a rename
// keeps it, both devices see it). 19 characters: the smallest square code still holds it.

public let LABEL_CODE_KEY = "labelCode"

public enum ThingLink {
    public static func text(code: String) -> String { "AMSPACKING://T/\(code.uppercased())" }
    /// The thing code a link carries, or nil when it is not a thing's link.
    public static func code(in url: URL) -> String? {
        guard url.scheme?.lowercased() == PlaceLink.scheme, url.host?.lowercased() == "t" else { return nil }
        let parts = url.path.split(separator: "/")
        guard parts.count == 1, let c = parts.first.map({ String($0).uppercased() }), c.count == 4,
              c.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return c
    }
}

extension Library {
    public static func labelCode(_ it: Item) -> String { it.extra[LABEL_CODE_KEY]?.stringValue ?? "" }

    /// The thing's code — its own, or the one it WILL get: four base-36 characters from its id, moved on
    /// past any code another thing has.
    public func thingLabelCode(id: String) -> String? {
        guard let it = items.first(where: { $0.id == id }) else { return nil }
        let have = Library.labelCode(it)
        if !have.isEmpty { return have }
        let taken = Set(items.map(Library.labelCode).filter { !$0.isEmpty })
        var n = Int(Library.fnv1a(id) % 1_679_616)
        for _ in 0..<1_679_616 {
            let c = Library.base36(n, width: 4)
            if !taken.contains(c) { return c }
            n = (n + 1) % 1_679_616
        }
        return nil
    }

    @discardableResult
    public mutating func giveThingLabelCode(id: String) -> String? {
        guard let c = thingLabelCode(id: id) else { return nil }
        if items.first(where: { $0.id == id }).map(Library.labelCode)?.isEmpty == true {
            _ = updateThing(id: id) { $0.extra[LABEL_CODE_KEY] = .string(c) }
        }
        return c
    }

    /// The thing a label's code names.
    public func thingWithLabel(_ code: String) -> Item? {
        items.first { Library.labelCode($0).uppercased() == code.uppercased() }
    }
}

extension PlaceLabel {
    /// A thing's label: the same tape and drawing as a place's, its own link.
    public static func thingImage(code: String, name: String) -> CGImage? {
        image(link: ThingLink.text(code: code), name: name)
    }
}
