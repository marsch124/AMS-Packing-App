import Foundation
import PackingCore

// 0.120 (his picks of 12 Nov 2026): a reminder 30 days before a warranty ends and on the day a thing's
// care is due, both at 9:00 · the insurance list as a PDF, room by room with totals, each thing in
// full (photo, brand, model, serial, bought on, shop, price, value today, warranty until) and the
// receipt photos at the end · a "No receipt yet" list on the Inventory tab.
// WHAT is said and WHEN is decided here; the app only puts it in the device's list and draws the PDF.

/// Days before a warranty ends that its reminder comes (his pick: 30).
public let WARRANTY_REMINDER_DAYS = 30
/// At most this many waiting reminders from the inventory (the device keeps 64 in all, shared with
/// the packing reminders, door checks and trip messages).
public let INVENTORY_REMINDERS_MAX = 40

/// One reminder about a thing he owns, at 9:00 on `day`.
public struct InventoryReminder: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable { case warranty, care }
    /// "inv-warranty-<item id>-<day>" / "inv-care-<item id>-<day>" — also the device's identifier.
    public var id: String
    public var kind: Kind
    public var itemId: String
    /// YYYY-MM-DD.
    public var day: String
    public var title: String
    public var body: String
}

/// One line of facts about a thing in the insurance list.
public struct InsuranceFact: Equatable, Sendable {
    public var label: String
    public var value: String
}

/// One thing in the insurance list.
public struct InsuranceLine: Equatable, Sendable {
    public var itemId: String
    public var name: String
    /// Only the facts he filled in, in a fixed order.
    public var facts: [InsuranceFact]
    /// Its first photo's id ("" = none).
    public var photoId: String
    /// Its receipt photos' ids, in the order kept.
    public var receiptIds: [String]
}

/// One room of the insurance list ("" = no room).
public struct InsuranceRoom: Equatable, Sendable {
    public var room: String
    public var lines: [InsuranceLine]
    public var totals: InventoryTotals
}

/// The whole insurance list.
public struct InsuranceList: Equatable, Sendable {
    public var rooms: [InsuranceRoom]
    public var totals: InventoryTotals
    /// "12 Nov 2026".
    public var madeOn: String
    /// What went this calendar year, newest first (0.123 — for an insurance claim), and its year line.
    public var gone: [InsuranceLine] = []
    public var goneYear: GoneYear?
    /// How many receipt photos it carries in all.
    public var receipts: Int {
        rooms.reduce(0) { $0 + $1.lines.reduce(0) { $0 + $1.receiptIds.count } } + gone.reduce(0) { $0 + $1.receiptIds.count }
    }
}

extension Library {
    // MARK: Reminders

    /// The waiting reminders from today on, soonest first, at most `INVENTORY_REMINDERS_MAX`:
    /// 30 days before each warranty ends (none when that day has passed), and each thing's next
    /// care day. Things "not in use" never remind.
    public func inventoryReminders(today: String) -> [InventoryReminder] {
        guard isYMD(today) else { return [] }
        var out: [InventoryReminder] = []
        for it in ownThings() where !it.retired && isYMD(it.warranty) {
            let day = addDays(it.warranty, -WARRANTY_REMINDER_DAYS)
            guard isYMD(day), day >= today else { continue }
            out.append(InventoryReminder(id: "inv-warranty-\(it.id)-\(day)", kind: .warranty, itemId: it.id, day: day,
                                         title: "Warranty ends in \(WARRANTY_REMINDER_DAYS) days",
                                         body: "\(it.name) \u{2014} warranty until \(Library.dayWords(it.warranty))"))
        }
        for row in careRows(today: today) where row.status.scheduled && isYMD(row.status.nextDue) && row.status.nextDue >= today {
            let it = row.item
            let day = row.status.nextDue
            out.append(InventoryReminder(id: "inv-care-\(it.id)-\(day)", kind: .care, itemId: it.id, day: day,
                                         title: "Care due today", body: it.name))
        }
        return Array(out.sorted { ($0.day, $0.id) < ($1.day, $1.id) }.prefix(INVENTORY_REMINDERS_MAX))
    }

    // MARK: No receipt yet

    /// Has a paper of the kind Receipt.
    public static func hasReceipt(_ it: Item) -> Bool { papers(it).contains { $0.kind == .receipt } }

    /// Things in use that have no receipt yet (as Your things lists them).
    public func noReceiptRows() -> [(item: Item, templates: [String])] {
        thingRows().filter { !$0.item.retired && !Library.hasReceipt($0.item) }
    }

    // MARK: The insurance list

    /// "12 500 kr", or "120 EUR" for another currency.
    public static func moneyWords(_ v: Double, currency: String = "") -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal; f.groupingSeparator = "\u{00A0}"; f.maximumFractionDigits = 0
        let n = f.string(from: NSNumber(value: v.rounded())) ?? "\(Int(v))"
        let cur = jsTrim(currency).uppercased()
        return cur.isEmpty || cur == "SEK" || cur == "KR" ? n + " kr" : n + " " + cur
    }

    /// Every thing in use, room by room in the Inventory tab's order (no room last), A–Z inside a
    /// room, each with the facts he filled in, its first photo and its receipts; totals per room
    /// and for all.
    public func insuranceList(today: String) -> InsuranceList {
        let things = thingRows().map(\.item).filter { !$0.retired }
        var rooms: [InsuranceRoom] = []
        for r in inventoryRooms() {
            let k = normName(r.room)
            let mine = things.filter { normName($0.storage) == k }
            guard !mine.isEmpty else { continue }
            rooms.append(InsuranceRoom(room: r.room, lines: mine.map { insuranceLine($0, today: today) },
                                       totals: Library.totals(mine, today: today)))
        }
        var list = InsuranceList(rooms: rooms, totals: Library.totals(things, today: today),
                                 madeOn: isYMD(today) ? Library.dayWords(today) : today)
        // Gone this year (0.123): what went since 1 Jan, in full, with how and what it was worth then.
        let year = String(today.prefix(4))
        let went = goneThings().filter { (Library.gone($0)?.on ?? "").hasPrefix(year + "-") }
        if isYMD(today), !went.isEmpty {
            list.gone = went.map { insuranceGoneLine($0) }
            list.goneYear = Library.goneByYear(went).first
        }
        return list
    }

    func insuranceLine(_ it: Item, today: String) -> InsuranceLine {
        var facts: [InsuranceFact] = []
        func add(_ label: String, _ value: String) {
            let v = jsTrim(value)
            if !v.isEmpty { facts.append(InsuranceFact(label: label, value: v)) }
        }
        add("Brand", it.manufacturer)
        add("Model", it.model)
        add("Serial", it.serial)
        add("Bought on", isYMD(it.acquired) ? Library.dayWords(it.acquired) : "")
        add("Bought at", Library.shop(it))
        let n = max(1, it.qtyOwned)
        if it.price > 0 {
            let each = Library.moneyWords(it.price, currency: it.currency)
            add("Price", n > 1 ? "\(n) \u{00D7} \(each)" : each)
        }
        if let v = Library.valueToday(it, today: today) {
            let each = Library.moneyWords(v, currency: it.currency)
            add("Value today", n > 1 ? "\(n) \u{00D7} \(each)" : each)
        }
        add("Warranty until", isYMD(it.warranty) ? Library.dayWords(it.warranty) : "")
        let spot = Library.spot(it)
        add("Spot", spot)
        let photo = thingPhotoIds(id: it.id).first ?? ""
        let receipts = Library.papers(it).filter { $0.kind == .receipt }.map(\.id)
        // A sample thing says so (0.123).
        let name = Library.isSample(it) ? it.name + " (sample)" : it.name
        return InsuranceLine(itemId: it.id, name: name, facts: facts, photoId: photo, receiptIds: receipts)
    }

    /// A gone thing's line: "Went" first, then its facts, then (lost or stolen) what it was worth that day.
    func insuranceGoneLine(_ it: Item) -> InsuranceLine {
        guard let g = Library.gone(it) else { return insuranceLine(it, today: it.acquired) }
        let day = isYMD(g.on) ? g.on : it.acquired
        var line = insuranceLine(it, today: day)
        line.facts.removeAll { $0.label == "Value today" || $0.label == "Spot" }
        line.facts.insert(InsuranceFact(label: "Went", value: Library.goneLine(it)), at: 0)
        if g.how == .lost || g.how == .stolen, let v = Library.valueToday(it, today: day) {
            let n = max(1, it.qtyOwned), each = Library.moneyWords(v, currency: it.currency)
            line.facts.append(InsuranceFact(label: "Worth when it went", value: n > 1 ? "\(n) \u{00D7} \(each)" : each))
        }
        return line
    }
}
