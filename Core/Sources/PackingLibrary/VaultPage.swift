import Foundation
import PackingCore

// A trip page in his Obsidian vault — spec 07, part 8 (0.70). His yes of 7 Oct 2026:
// when a trip's review is saved, and whenever he presses "Send to Obsidian" on a
// reviewed trip, the trip becomes ONE Markdown page in the folder he picked once (his
// choice: the vault's Areas/Travel), named "<yyyy-mm> <trip name>.md". Sending again
// replaces the page.
//
// The folder lives on the Mac, so the Mac writes the page. This file is the part that
// needs no folder: the page's words (a pure function of the library), and the three
// marks on the trip that let the iPhone ask and the Mac answer. Everything is kept in
// the trip's extra keys, so the web app's model is untouched (it keeps keys it does not
// know through a round trip, as it keeps every other native key).

/// The trip's extra key: what the review added as MISSED, as it was saved —
/// `[{ "name": "Power bank", "template": "Hiking" }]`, `template` "" = on no template.
/// Written by `saveReview` from 0.70 on; an older review has no such key, and the page
/// says so rather than claiming nothing was missed.
public let MISSED_AT_REVIEW_KEY = "missedAtReview"
/// The trip's extra key: the moment a page was asked for (a review saved, or "Send to
/// Obsidian" pressed on the iPhone). The Mac writes the page and takes the key away.
public let VAULT_WAITING_KEY = "vaultWaiting"
/// The trip's extra key: what the Mac wrote last — `{ "file": "2026-07 Weekend.md",
/// "at": "<ISO moment>" }` — so both devices can say so.
public let VAULT_WRITTEN_KEY = "vaultWritten"
/// 🔌 HOOK for spec 07 part 7 (Apple Health fills in the review — the "health" helper).
/// The trip's extra key the page reads its **Workouts** section from: a list of the
/// rows the review's "From Apple Health" block showed, exactly as shown, for example
/// `["Swim · indoor · 3 times", "Run · outdoor · 2 times", "No bike"]`. Part 7 writes it
/// when the review is saved with workouts read (iPhone only — the Mac has no Apple
/// Health, so this key is how the Mac's page learns them). Nothing here writes it; with
/// no such key the page has no Workouts section.
public let TRIP_WORKOUTS_KEY = "healthWorkouts"
/// The folder beside the page that holds the bags' photos.
public let VAULT_ATTACHMENTS_FOLDER = "attachments"

/// One photo the page shows: the file it is copied to (inside `attachments`) and the
/// photo record it comes from.
public struct VaultAttachment: Equatable, Sendable {
    public var fileName: String
    public var photoId: String
    public init(fileName: String, photoId: String) { self.fileName = fileName; self.photoId = photoId }
}

/// A trip's page: its file name, its Markdown, and the photos to copy beside it.
public struct VaultPage: Equatable, Sendable {
    public var fileName: String
    public var text: String
    public var attachments: [VaultAttachment]
    public init(fileName: String, text: String, attachments: [VaultAttachment]) {
        self.fileName = fileName; self.text = text; self.attachments = attachments
    }
}

extension Library {
    // MARK: - The marks on the trip

    /// Is a page wanted for this trip, and not written yet?
    public static func isWaitingForVault(_ trip: TripEvent) -> Bool {
        !(trip.extra[VAULT_WAITING_KEY]?.stringValue ?? "").isEmpty
    }

    /// The reviewed trips whose page the Mac still has to write, in the library's order.
    public func tripsWaitingForVault() -> [String] {
        trips.filter { Library.isReviewed($0) && Library.isWaitingForVault($0) }.map(\.id)
    }

    /// Ask for the page (the iPhone's "Send to Obsidian", and every saved review). Only a
    /// reviewed trip has a page: false for any other, and for an unknown trip.
    @discardableResult
    public mutating func askForVaultPage(tripId: String, at moment: String = nowISO()) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }), Library.isReviewed(trips[n]) else { return false }
        trips[n].extra[VAULT_WAITING_KEY] = .string(moment.isEmpty ? nowISO() : moment)
        trips[n].updatedAt = nowISO()
        return true
    }

    /// The Mac wrote the page: the wish is answered, and the file and the moment are kept.
    @discardableResult
    public mutating func vaultPageWritten(tripId: String, file: String, at moment: String = nowISO()) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }), !file.isEmpty else { return false }
        trips[n].extra[VAULT_WAITING_KEY] = nil
        trips[n].extra[VAULT_WRITTEN_KEY] = .object(["file": .string(file), "at": .string(moment)])
        trips[n].updatedAt = nowISO()
        return true
    }

    /// What the Mac wrote last for this trip, or nil.
    public func vaultWritten(tripId: String) -> (file: String, at: String)? {
        guard let o = trip(tripId)?.extra[VAULT_WRITTEN_KEY]?.objectValue,
              let file = o["file"]?.stringValue, !file.isEmpty else { return nil }
        return (file, o["at"]?.stringValue ?? "")
    }

    /// What the review added as missed — nil when the review kept no such record (saved
    /// before 0.70, or on the web app).
    public func missedAtReview(tripId: String) -> [(name: String, template: String)]? {
        guard let list = trip(tripId)?.extra[MISSED_AT_REVIEW_KEY]?.arrayValue else { return nil }
        return list.compactMap { v in
            guard let name = v["name"]?.stringValue, !jsTrim(name).isEmpty else { return nil }
            return (name, v["template"]?.stringValue ?? "")
        }
    }

    /// Called by `saveReview` (trip at index `t`), BEFORE the missed things are filed:
    /// keeps what was missed, by name and by the template's shown name, and asks for the
    /// page. (The template's NAME, not its id: the page is read years later, when the
    /// template may be renamed or gone.)
    mutating func noteReviewForVault(trip t: Int, missed: [Missed], when: String) {
        var kept: [JSONValue] = []
        var seen = Set<String>()
        for m in missed {
            let name = jsTrim(m.name)
            guard !name.isEmpty, seen.insert(normName(name)).inserted else { continue }
            let where_ = m.templateId.isEmpty ? "" : (templates.first { $0.id == m.templateId }.map { shownName($0) } ?? "")
            kept.append(.object(["name": .string(name), "template": .string(where_)]))
        }
        trips[t].extra[MISSED_AT_REVIEW_KEY] = .array(kept)
        trips[t].extra[VAULT_WAITING_KEY] = .string(when.isEmpty ? nowISO() : when)
    }

    /// The Workouts rows part 7 left on the trip (`TRIP_WORKOUTS_KEY`), blank ones dropped.
    public static func vaultWorkoutLines(_ trip: TripEvent) -> [String] {
        (trip.extra[TRIP_WORKOUTS_KEY]?.arrayValue ?? []).compactMap(\.stringValue).map(jsTrim).filter { !$0.isEmpty }
    }

    /// A photo's bytes and the file ending its kind asks for — what the Mac copies.
    public func vaultPhoto(_ photoId: String) -> (data: Data, ending: String)? {
        guard let p = photos.first(where: { $0.id == photoId }) else { return nil }
        let (bytes, mime) = Library.bytes(fromDataURL: p.data)
        guard let data = bytes, !data.isEmpty else { return nil }
        return (data, Library.vaultEnding(mime))
    }

    static func vaultEnding(_ mime: String) -> String {
        switch mime.lowercased() {
        case "image/png": return "png"
        case "image/heic": return "heic"
        case "image/gif": return "gif"
        case "image/webp": return "webp"
        default: return "jpg"
        }
    }

    // MARK: - The page

    /// "2026-07 Weekend in the hills" — the page's name without ".md": the month the trip
    /// began (else the month it was reviewed, else none), then its name, made safe for a
    /// file and for an Obsidian link.
    public static func vaultFileStem(_ trip: TripEvent, zone: TimeZone = .current) -> String {
        var month = monthKey(trip.startDate)
        if month.isEmpty { month = monthKey(Library.vaultDay(trip.reviewedAt, zone)) }
        let name = Library.vaultSafe(trip.name)
        let shown = name.isEmpty ? "Trip" : name
        return month.isEmpty ? shown : "\(month) \(shown)"
    }

    /// A name made safe for a file and for Obsidian's links: the characters a file name
    /// or an Obsidian link cannot hold (`/ \ : * ? " < > | # ^ [ ]`) become "-", spaces
    /// are collapsed, leading dots go (a hidden file), at most 100 characters.
    static func vaultSafe(_ s: String) -> String {
        let bad = Set("/\\:*?\"<>|#^[]")
        var out = String(s.map { bad.contains($0) || $0.isNewline ? "-" : $0 })
        out = jsCollapseWhitespace(jsTrim(out))
        while out.hasPrefix(".") { out.removeFirst() }
        out = jsTrim(out)
        if out.count > 100 { out = jsTrim(String(out.prefix(100))) }
        return out
    }

    /// The day an ISO moment fell on, in this time zone ("" when it cannot be read).
    public static func vaultDay(_ iso: String, _ zone: TimeZone) -> String {
        if isYMD(iso) { return iso }
        guard let moment = isoMoment(iso) else { return "" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let c = cal.dateComponents([.year, .month, .day], from: moment)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    /// "3 Jul 2026" — fixed English words, as the app writes dates everywhere.
    public static func vaultDate(_ ymd: String) -> String {
        let p = ymd.split(separator: "-").compactMap { Int($0) }
        guard isYMD(ymd), p.count == 3, (1...12).contains(p[1]) else { return ymd }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(p[2]) \(months[p[1] - 1]) \(p[0])"
    }

    /// "420 g", "2.4 kg".
    static func vaultKilos(_ grams: Double) -> String {
        guard grams.isFinite else { return "0 g" }
        return grams < 1000 ? "\(Int(grams.rounded())) g" : String(format: "%.1f kg", grams / 1000)
    }

    /// A number as YAML and people read it: "2" not "2.0", "2.4".
    static func vaultNumber(_ x: Double) -> String {
        guard x.isFinite else { return "0" }
        return x.rounded() == x ? String(Int(x)) : String(format: "%.1f", x)
    }

    /// A YAML string in double quotes (a place like "Nice: old town" would break bare YAML).
    static func yaml(_ s: String) -> String {
        let one = s.split(whereSeparator: \.isNewline).joined(separator: " ")
        return "\"" + one.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// Words of his as plain Markdown text: the characters Markdown or Obsidian would
    /// read as formatting (emphasis, links, tags, maths, tables, highlights) are escaped,
    /// so "C# notes" or "*spare* socks" read as typed.
    static func md(_ s: String) -> String {
        let special = Set("\\`*_[]<>#$|~")
        var out = ""
        for ch in s.split(whereSeparator: \.isNewline).joined(separator: " ") {
            if special.contains(ch) { out.append("\\") }
            out.append(ch)
        }
        return out.replacingOccurrences(of: "==", with: "=\\=")
    }

    /// A path inside the vault as a Markdown link wants it: every space and every
    /// character beyond plain letters and digits percent-encoded (Obsidian reads them back).
    static func vaultLink(_ path: String) -> String {
        var allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        allowed.insert(charactersIn: "-._~/")
        return path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
    }

    /// The trip's page — nil for a trip that is not there or not reviewed (a page is what
    /// a trip TAUGHT; before the review there is nothing to write). A pure function of the
    /// library: the same library gives the same page, word for word.
    ///
    /// Front matter: type, start, end, nights, place, transport, season, templates,
    /// packed (lines packed / lines), weight (all bags, kg), reviewed. Then the trip's
    /// name, its dates, and the sections Weather, Workouts (only when part 7 left rows),
    /// Bags (each with its weight and its photos), Didn't use, Missed, Bought on site,
    /// Notes. `zone` decides the day the review fell on (the device's own).
    public func vaultPage(tripId: String, zone: TimeZone = .current) -> VaultPage? {
        guard let trip = trip(tripId), Library.isReviewed(trip) else { return nil }
        let stem = Library.vaultFileStem(trip, zone: zone)
        var lines: [String] = []

        // Front matter.
        let p = progress(trip.entries)
        let bags = weighedBags(tripId: tripId)
        let grams = bags.reduce(0.0) { $0 + ($1.grams.isFinite ? $1.grams : 0) }
        let templateNames = tripTemplates(tripId: tripId).map(shownName)
        lines.append("---")
        lines.append("type: trip")
        lines.append("start: \(isYMD(trip.startDate) ? trip.startDate : "")".trimmingTrailingSpace)
        lines.append("end: \(isYMD(trip.endDate) ? trip.endDate : "")".trimmingTrailingSpace)
        lines.append("nights: \(max(0, trip.nights))")
        lines.append("place: \(Library.yaml(jsTrim(trip.destination)))")
        lines.append("transport: \(Library.yaml(trip.transport))")
        lines.append("season: \(Library.yaml(trip.season))")
        if templateNames.isEmpty {
            lines.append("templates: []")
        } else {
            lines.append("templates:")
            lines += templateNames.map { "  - \(Library.yaml($0))" }
        }
        lines.append("packed: \(Library.yaml("\(p.done)/\(p.total)"))")
        lines.append("weight: \(Library.vaultNumber((grams / 100).rounded() / 10))")
        lines.append("reviewed: \(Library.vaultDay(trip.reviewedAt, zone))".trimmingTrailingSpace)
        lines.append("---")
        lines.append("")

        // The name and the days.
        lines.append("# \(Library.md(jsTrim(trip.name).isEmpty ? "Trip" : jsTrim(trip.name)))")
        lines.append("")
        var when: [String] = []
        if isYMD(trip.startDate) {
            let end = isYMD(trip.endDate) && trip.endDate != trip.startDate ? " \u{2013} \(Library.vaultDate(trip.endDate))" : ""
            when.append(Library.vaultDate(trip.startDate) + end)
        } else {
            when.append("No dates")
        }
        if trip.nights > 0 { when.append(trip.nights == 1 ? "1 night" : "\(trip.nights) nights") }
        if !jsTrim(trip.destination).isEmpty { when.append(Library.md(jsTrim(trip.destination))) }
        lines.append(when.joined(separator: " \u{00B7} "))
        lines.append("")

        // Weather, as the trip recorded it.
        lines.append("## Weather")
        lines.append("")
        if let sky = deriveWeather(trip), !sky.days.isEmpty {
            var head: [String] = []
            let place = jsTrim(sky.place.isEmpty ? trip.destination : sky.place)
            if !place.isEmpty { head.append(Library.md(place)) }
            if !sky.rangeLabel.contains("NaN") { head.append(sky.rangeLabel) }
            if !sky.conditions.isEmpty { head.append(sky.conditions.joined(separator: ", ")) }
            if !head.isEmpty { lines.append(head.joined(separator: " \u{00B7} ")); lines.append("") }
            for d in sky.days {
                var parts: [String] = []
                if !d.label.isEmpty && d.label != "\u{2014}" { parts.append(d.label) }
                switch (d.tmin, d.tmax) {
                case let (lo?, hi?): parts.append("\(Library.vaultNumber(lo))\u{2013}\(Library.vaultNumber(hi))\u{00B0}C")
                case let (nil, hi?): parts.append("\(Library.vaultNumber(hi))\u{00B0}C")
                case let (lo?, nil): parts.append("\(Library.vaultNumber(lo))\u{00B0}C")
                default: break
                }
                if d.precipProb > 0 { parts.append("rain \(Library.vaultNumber(d.precipProb)) %") }
                if d.wind > 0 { parts.append("wind \(Library.vaultNumber(d.wind)) km/h") }
                let day = [d.dow, Library.vaultDate(d.date)].filter { !$0.isEmpty }.joined(separator: " ")
                lines.append("- \(day): \(parts.isEmpty ? "\u{2014}" : parts.joined(separator: " \u{00B7} "))")
            }
        } else {
            lines.append("No forecast was kept on this trip.")
        }
        if !trip.weatherOn.isEmpty {
            lines.append("")
            lines.append("Packed for: \(trip.weatherOn.map(Library.md).joined(separator: ", ")) (switched on for the trip)")
        }
        lines.append("")

        // Workouts — part 7's rows, when it left any (`TRIP_WORKOUTS_KEY`).
        let workouts = Library.vaultWorkoutLines(trip)
        if !workouts.isEmpty {
            lines.append("## Workouts")
            lines.append("")
            lines += workouts.map { "- \(Library.md($0))" }
            lines.append("")
        }

        // Bags: each with its weight, and its packed photos copied beside the page.
        lines.append("## Bags")
        lines.append("")
        var attachments: [VaultAttachment] = []
        var used = Set<String>()
        let limits = bagLimits()
        var bagNames = bags.map(\.load.container)
        let photoBags = (trip.extra[BAG_PHOTOS_KEY]?.objectValue ?? [:]).keys.sorted()
        for b in photoBags where !bagNames.contains(b) && !bagPhotos(tripId: tripId, bag: b).isEmpty { bagNames.append(b) }
        if bagNames.isEmpty { lines.append("No bags on this trip."); lines.append("") }
        for name in bagNames {
            let shown = name == "Other" ? "Not in a bag" : name
            var head = "### \(Library.md(shown))"
            if let bag = bags.first(where: { $0.load.container == name }) {
                if bag.scaleGrams != nil { head += " \u{00B7} \(Library.vaultKilos(bag.grams)) weighed" }
                else if bag.grams > 0 { head += " \u{00B7} \(Library.vaultKilos(bag.grams))" }
                let limit = bag.load.limitKg > 0 ? bag.load.limitKg : (limits[name] ?? 0)
                if limit > 0 { head += " \u{00B7} max \(Library.vaultNumber(limit)) kg" }
                if bag.over { head += " \u{00B7} over" }
            }
            lines.append(head)
            lines.append("")
            let shots = bagPhotos(tripId: tripId, bag: name)
            for (k, photo) in shots.enumerated() {
                guard let ending = vaultPhoto(photo.id)?.ending else { continue }
                var file = "\(stem) - \(Library.vaultSafe(shown)) \(k + 1).\(ending)"
                var extra = 2
                while used.contains(file) { file = "\(stem) - \(Library.vaultSafe(shown)) \(k + 1)-\(extra).\(ending)"; extra += 1 }
                used.insert(file)
                attachments.append(VaultAttachment(fileName: file, photoId: photo.id))
                lines.append("![\(Library.md(shown)), photo \(k + 1)](\(Library.vaultLink("\(VAULT_ATTACHMENTS_FOLDER)/\(file)")))")
                lines.append("")
            }
        }

        // Didn't use — what the review marked.
        lines.append("## Didn't use")
        lines.append("")
        let unused = Library.uniqueNames(trip.entries.filter { $0.itemType != "reminder" && $0.used == false }.map(\.name))
        lines += unused.isEmpty ? ["Nothing \u{2014} everything that went was used."] : unused.map { "- \(Library.md($0))" }
        lines.append("")

        // Missed — added at the review.
        lines.append("## Missed")
        lines.append("")
        if let missed = missedAtReview(tripId: tripId) {
            lines += missed.isEmpty ? ["Nothing."] : missed.map { m in
                "- \(Library.md(m.name)) \u{2014} " + (m.template.isEmpty ? "a thing of its own, on no template" : "onto \(Library.md(m.template))")
            }
        } else {
            lines.append("Not recorded: this trip was reviewed before version 0.70.")
        }
        lines.append("")

        // Bought on site.
        lines.append("## Bought on site")
        lines.append("")
        let bought = Library.uniqueNames(boughtOnSite(tripId: tripId).map(\.name))
        lines += bought.isEmpty ? ["Nothing."] : bought.map { "- \(Library.md($0))" }
        lines.append("")

        // Notes — the maintenance notes made on site and on the way home, by thing.
        lines.append("## Notes")
        lines.append("")
        let notes = onSiteNotes(tripId: tripId)
        lines += notes.isEmpty ? ["No notes."] : notes.map { "- **\(Library.md(jsTrim($0.name)))**: \(Library.md(Library.homeNote($0)))" }
        lines.append("")
        lines.append("*Written by AMS Packing. Sending the trip again replaces this page.*")
        lines.append("")
        return VaultPage(fileName: "\(stem).md", text: lines.joined(separator: "\n"), attachments: attachments)
    }

    /// Names in their order, each once (by `normName`), blanks left out.
    static func uniqueNames(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.map(jsTrim).filter { !$0.isEmpty && seen.insert(normName($0)).inserted }
    }
}

private extension String {
    /// "start: " → "start:" — an empty YAML value with no space left after it.
    var trimmingTrailingSpace: String {
        var s = self
        while s.hasSuffix(" ") { s.removeLast() }
        return s
    }
}
