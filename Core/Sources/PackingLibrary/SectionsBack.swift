import Foundation
import PackingCore

// A section given back (0.97, his check 6 of 21 Oct 2026). A template's sections are ONE field of
// ONE record; a line's section is its own record (the membership), naming the section by id. When
// both devices save the template before either has the other's save — each adding a section —
// iCloud keeps one of the two template records whole: the other device's section was gone, its line
// still named it, and the row's Section showed the id ("mvho3cjj-0-r6dbge").
//
// So each line's record also carries its section's NAME (`sectionCopyKey`, written by `records()`),
// and a load gives a template back every section one of its lines names: under the name a line
// carries — or, for a line stored before 0.97, the name the same line has on a trip still ahead —
// joining a section of that name if the template has one. A line whose section's name is nowhere
// reads under no section. Nothing is written for it: the template is stored with the section the
// next time it is saved for any reason, so a template still on its way from the other device is
// never overwritten by this repair.

extension Library {
    /// The key a line's record carries its section in: {"id": …, "name": …}. Never kept in memory.
    static let sectionCopyKey = "sectionCopy"

    /// Every line naming a section its template does not have gets it back (see above). `copies`: the
    /// section each line's record carried, by the line's id.
    mutating func giveSectionsBack(_ copies: [String: JSONValue]) {
        var byTemplate: [String: [Int]] = [:]
        for (n, m) in memberships.enumerated() where !m.section.isEmpty { byTemplate[m.templateId, default: []].append(n) }
        guard !byTemplate.isEmpty else { return }
        var aheadNames: [String: String]?
        func ord(_ m: Membership) -> Double { m.order.isNaN ? 0 : m.order }
        for t in templates.indices {
            let have = Set(templates[t].sections.map(\.id))
            // The template's lines that name a section it lacks, in the template's own order.
            let lost = (byTemplate[templates[t].id] ?? []).filter { !have.contains(memberships[$0].section) }
                .stableSorted(compare: { a, b in jsSign(ord(memberships[a]) - ord(memberships[b])) })
            guard !lost.isEmpty else { continue }
            if aheadNames == nil { aheadNames = sectionNamesOnTripsAhead() }
            var named: [String: String] = [:]          // section id → its name, where any line knows it
            var order: [String] = []
            for n in lost {
                let m = memberships[n], sid = m.section
                if !order.contains(sid) { order.append(sid) }
                guard named[sid] == nil else { continue }
                let copy = copies[m.id]
                if copy?["id"]?.stringValue == sid, let name = copy?["name"]?.stringValue, !jsTrim(name).isEmpty {
                    named[sid] = jsTrim(name)
                }
            }
            for n in lost where named[memberships[n].section] == nil {
                if let name = aheadNames?[templates[t].id + "|" + memberships[n].itemId] { named[memberships[n].section] = name }
            }
            var into: [String: String] = [:]           // section id → the id the line now names
            for sid in order {
                guard let name = named[sid] else { into[sid] = ""; continue }
                if let same = templates[t].sections.first(where: { normName($0.name) == normName(name) }) {
                    into[sid] = same.id
                } else {
                    templates[t].sections.append(TemplateSection(id: sid, name: name))
                    into[sid] = sid
                }
            }
            for n in lost { memberships[n].section = into[memberships[n].section] ?? "" }
        }
    }

    /// The section names on lines of trips still ahead that follow their template (not added by hand,
    /// not changed on the trip), by template and thing ("<template>|<thing>").
    private func sectionNamesOnTripsAhead() -> [String: String] {
        let today = Library.localToday()
        var out: [String: String] = [:]
        for trip in trips.sorted(by: { $0.id < $1.id }) where tripStillAhead(trip, today: today) {
            for e in trip.entries where !e.custom && !e.edited && !jsTrim(e.section).isEmpty {
                guard let list = e.sourceListId, let thing = e.sourceItemId else { continue }
                let key = list + "|" + thing
                if out[key] == nil { out[key] = jsTrim(e.section) }
            }
        }
        return out
    }
}
