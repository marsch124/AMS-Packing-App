import Foundation
import PackingCore

// Lost luggage, part A — a bag's details for the airline's baggage desk (0.80, his yes of
// 13 Oct 2026; spec 07 part 18 A). Entered ONCE, on the bag's own page, and read by every
// trip — the Lost bag page and its PDF (part 18 B) read them from here.
//
// The desk asks five things about a missing bag: its brand, its colour, its type, its size
// and what makes it stand out. They belong to the BAG (one of his things on Your bags), not
// to a trip, so they are kept on the bag's thing and follow it everywhere — a rename keeps
// them (they live on the thing, whose id a rename keeps), sync, backups and restores carry
// them with its record.
//
// WHERE EACH IS KEPT. Brand and colour are the thing's OWN fields — `manufacturer` and `color`,
// which a thing's page shows as "Brand" and "Colour" ("for bags above all", his bag page of 26 Sep 2026) — so the
// bag page and "Its details" are the same value, never two. The size's note is the thing's own
// `size` (the table's "Size" column). What the web model has no field for is in extra keys,
// so the web model — and the parity check — see nothing new:
//   bagType   "hard" | "soft" | "duffel" | "backpack" | "holdall" | "garment" | "other"
//   bagSize   "cabin" | "medium" | "large"
//   bagMarks  free text — "red strap, sticker on the side"
// Each is absent when not said (never an empty string). None reaches a trip line (a line copies
// only the fields `entryFromItem` names), a shared template or a shared trip.

/// On a bag: its kind, in the baggage desk's words (`BagType`).
public let BAG_TYPE_KEY = "bagType"
/// On a bag: its size class (`BagSize`).
public let BAG_SIZE_KEY = "bagSize"
/// On a bag: what makes it stand out — free text.
public let BAG_MARKS_KEY = "bagMarks"
/// Every extra key the bag details write on a bag's thing.
public let BAG_DETAIL_KEYS = [BAG_TYPE_KEY, BAG_SIZE_KEY, BAG_MARKS_KEY]

/// The kind of bag — the airlines' baggage-desk categories, in plain words.
public enum BagType: String, CaseIterable, Sendable, Identifiable {
    case hardCase = "hard", softCase = "soft", duffel, backpack, holdall, garment, other

    public var id: String { rawValue }

    /// As the bag page's pills and the Lost bag page say it.
    public var name: String {
        switch self {
        case .hardCase: return "Hard case"
        case .softCase: return "Soft case"
        case .duffel: return "Duffel"
        case .backpack: return "Backpack"
        case .holdall: return "Holdall / weekend bag"
        case .garment: return "Garment bag"
        case .other: return "Other"
        }
    }
}

/// The bag's size — the three an airline desk asks for; the exact measure goes in the note.
public enum BagSize: String, CaseIterable, Sendable, Identifiable {
    case cabin, medium, large

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .cabin: return "Cabin"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

/// One of the colour pills: a short label on the pill, the word it writes.
public struct BagColourPill: Equatable, Sendable, Identifiable {
    public var label: String
    public var value: String
    public var id: String { label }
}

/// A bag's details for the baggage desk. Text is trimmed; "" = not said.
public struct BagDetails: Equatable, Sendable {
    /// The thing's own Brand (`manufacturer`).
    public var brand: String
    /// The thing's own Colour (`color`) — typed, or one of the pills.
    public var colour: String
    /// nil = not said (or a kind a later version wrote that this one does not know).
    public var type: BagType?
    /// nil = not said.
    public var size: BagSize?
    /// The thing's own Size (`size`): "55 × 40 × 20 cm", "75 litres".
    public var sizeNote: String
    /// "red strap, sticker on the side".
    public var marks: String

    public init(brand: String = "", colour: String = "", type: BagType? = nil, size: BagSize? = nil,
                sizeNote: String = "", marks: String = "") {
        self.brand = brand; self.colour = colour; self.type = type; self.size = size
        self.sizeNote = sizeNote; self.marks = marks
    }

    /// Nothing said at all.
    public var isEmpty: Bool { trimmed == BagDetails() }

    /// The same with every text trimmed — as it is kept.
    public var trimmed: BagDetails {
        BagDetails(brand: jsTrim(brand), colour: jsTrim(colour), type: type, size: size,
                   sizeNote: jsTrim(sizeNote), marks: jsTrim(marks))
    }

    /// The pills under Colour: seven common bag colours, "Multi" for a bag of several.
    public static let colourPills: [BagColourPill] = [
        .init(label: "Black", value: "Black"), .init(label: "Grey", value: "Grey"),
        .init(label: "Blue", value: "Blue"), .init(label: "Red", value: "Red"),
        .init(label: "Green", value: "Green"), .init(label: "Beige", value: "Beige"),
        .init(label: "Multi", value: "Multicoloured"),
    ]

    /// Is this pill the colour said? By its word or its label, as `normName` compares.
    public func lit(_ pill: BagColourPill) -> Bool {
        let c = normName(colour)
        return !c.isEmpty && (c == normName(pill.value) || c == normName(pill.label))
    }

    /// The size in words: "Large", "Large, 75 × 50 × 30 cm", "75 × 50 × 30 cm", "".
    public var sizeWords: String {
        [size?.name ?? "", jsTrim(sizeNote)].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// The whole description on one line, for the desk: "Black · Samsonite · Hard case ·
    /// Large, 75 cm · red strap" — what is not said left out; "" when nothing is.
    public var summary: String {
        [jsTrim(colour), jsTrim(brand), type?.name ?? "", sizeWords, jsTrim(marks)]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

extension Library {
    // MARK: - Reading

    /// A bag's details, from its thing.
    public static func bagDetails(_ bag: Item) -> BagDetails {
        BagDetails(brand: jsTrim(bag.manufacturer), colour: jsTrim(bag.color),
                   type: bag.extra[BAG_TYPE_KEY]?.stringValue.flatMap(BagType.init(rawValue:)),
                   size: bag.extra[BAG_SIZE_KEY]?.stringValue.flatMap(BagSize.init(rawValue:)),
                   sizeNote: jsTrim(bag.size),
                   marks: jsTrim(bag.extra[BAG_MARKS_KEY]?.stringValue ?? ""))
    }

    /// One of his bags by its id, or nil.
    public func bagDetails(id: String) -> BagDetails? {
        guard bags().contains(where: { $0.id == id }), let thing = items.first(where: { $0.id == id }) else { return nil }
        return Library.bagDetails(thing)
    }

    /// A bag's details by its NAME, as a trip's lines name it (compared by `normName`). A name
    /// that is not one of his bags (only a name on the lines, or "Other") has none: empty.
    public func bagDetails(bag name: String) -> BagDetails {
        guard let bag = bags().first(where: { normName($0.name) == normName(name) }) else { return BagDetails() }
        return bagDetails(id: bag.id) ?? BagDetails()
    }

    // MARK: - Writing

    /// Write a bag's details. Only what DIFFERS from what is kept is written — so a kind or a
    /// size a later version wrote (read here as nil) is not wiped when another detail changes.
    /// Text is trimmed; an empty answer removes its key (never an empty string). Only a bag
    /// takes them: false for anything else.
    @discardableResult
    public mutating func setBagDetails(_ details: BagDetails, id: String) -> Bool {
        guard bags().contains(where: { $0.id == id }), let thing = items.first(where: { $0.id == id }) else { return false }
        let now = Library.bagDetails(thing), want = details.trimmed
        guard now != want else { return true }
        return updateThing(id: id) { bag in
            if now.brand != want.brand { bag.manufacturer = want.brand }
            if now.colour != want.colour { bag.color = want.colour }
            if now.sizeNote != want.sizeNote { bag.size = want.sizeNote }
            if now.type != want.type { bag.extra[BAG_TYPE_KEY] = want.type.map { .string($0.rawValue) } }
            if now.size != want.size { bag.extra[BAG_SIZE_KEY] = want.size.map { .string($0.rawValue) } }
            if now.marks != want.marks { bag.extra[BAG_MARKS_KEY] = want.marks.isEmpty ? nil : .string(want.marks) }
        }
    }

    /// The same by the bag's NAME. A name that is not a bag yet BECOMES one when something is
    /// said (as "Has an AirTag" does from a trip); with nothing said it stays a name. "Other"
    /// and "" are no bag: false.
    @discardableResult
    public mutating func setBagDetails(_ details: BagDetails, bag name: String) -> Bool {
        let wanted = jsTrim(name)
        guard Library.isRealBag(wanted) else { return false }
        if let bag = bags().first(where: { normName($0.name) == normName(wanted) }) { return setBagDetails(details, id: bag.id) }
        guard !details.isEmpty else { return true }
        guard let bag = addBag(name: wanted) else { return false }
        return setBagDetails(details, id: bag.id)
    }
}
