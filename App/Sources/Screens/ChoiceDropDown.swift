import SwiftUI
import PackingCore
import PackingLibrary

// His own lists changed from inside their drop-downs (0.69) — his ask (7 Oct 2026): "work
// on all the drop-downs so that they can be edited, changed, added, and deleted from within
// the drop-downs." The Section list of 0.68 showed the way: each row of his own a pen, ↑ ↓
// and a quiet red Remove that asks first, "A new …" at the foot, everything held until the
// page is saved. This is the same for every pick-one list whose choices are his own — Kind
// of thing, Whose it is, Kept at home, Usually packed in, a bag's Pocket, When, Condition —
// on a thing's page and on a template's row: ONE mechanism (DropDown's row tools), fed by
// the page's held `ChoiceEdits` and written on Save by the lists' own functions
// (ChoiceEdits.swift). An entry still in use is not removed: the list says what uses it.

/// One of his lists as a drop-down shows it while the page holds its edits.
struct ChoiceDrop {
    let library: Library
    let edits: ChoiceEdits
    /// The page keeps what was done.
    let keep: (ChoiceEdits) -> Void
    /// What the list is called in its question ("your places").
    let listWords: String
    /// The page's thing: its saved choice is not counted as a use — the page's choice is.
    var except: String? = nil
    /// The page's choice now (a key).
    var chosen: String = ""
    /// Two values the same entry (names compare as names).
    var same: (String, String) -> Bool = { normName($0) == normName($1) }
    /// Under a refusal: where the entry can be dealt with (a bag's page).
    var open: DropDownOpen? = nil

    var rows: [ChoiceRow] { library.choicesAsEdited(edits) }
    var options: [(value: String, label: String)] { rows.map { ($0.key, $0.label) } }

    private func label(_ key: String) -> String { rows.first { $0.key == key }?.label ?? key }

    /// The pen, ↑ ↓ and Remove on each of his entries (none on one the app reads by its
    /// words, nor on a row that is not his list's — "No bag", "Not said").
    var tools: DropDownRowTools {
        let lib = library, e = edits, keep = keep
        let kind = e.kind
        let mine = Set(rows.map(\.key))
        func order() -> [String] { lib.choicesAsEdited(e).map(\.key) }
        return DropDownRowTools(
            applies: { mine.contains($0) && lib.choiceFixed(kind, $0) == nil },
            rename: { key, name in
                if let problem = lib.choiceNameProblem(e, key: key, name: name) { return problem }
                var next = e
                let clean = jsTrim(name)
                let was = lib.choiceRows(kind, bag: e.bag).first { $0.key == key }?.label
                    ?? (ChoiceEdits.isAdded(key) ? e.added[Int(key.dropFirst(2)) ?? 0] : nil)
                next.names[key] = clean == was ? nil : clean
                keep(next)
                return ""
            },
            move: { key, by in
                var keys = order()
                guard let at = keys.firstIndex(of: key), keys.indices.contains(at + by) else { return }
                keys.swapAt(at, at + by)
                var next = e
                next.order = keys == lib.choicesAsEdited(ChoiceEdits(kind: kind, bag: e.bag)).map(\.key)
                    + e.added.indices.map(ChoiceEdits.addedKey) ? nil : keys
                keep(next)
            },
            canMove: { key, by in
                let keys = order()
                guard let at = keys.firstIndex(of: key) else { return false }
                return keys.indices.contains(at + by)
            },
            isRemoved: { e.removed.contains($0) },
            remove: { key in var next = e; next.removed.insert(key); keep(next) },
            putBack: { key in var next = e; next.removed.remove(key); keep(next) },
            question: { key in "Remove \(label(key)) from \(listWords)? Nothing uses it." },
            orders: Library.choiceOrders(kind),
            refusal: { key in
                lib.choiceRemoveProblem(kind, key: key, label: label(key), bag: e.bag, except: except,
                                        pageSays: !chosen.isEmpty && same(chosen, key))
            },
            open: open,
            nameHint: "Name")
    }

    /// "A new …" at the foot: one he already has is simply chosen; a new one waits for Save
    /// (Cancel leaves the list as it was) and is chosen now.
    func newEntry(_ placeholder: String, needs: String, choose: @escaping (String) -> Void) -> DropDownNew {
        let lib = library, e = edits, keep = keep
        return DropDownNew(placeholder: placeholder, needs: needs) { typed in
            let want = Library.choiceKey(typed)
            if let have = lib.choicesAsEdited(e).first(where: { !$0.removed && Library.choiceKey($0.label) == want }) {
                choose(have.key)
                return
            }
            var next = e
            next.added.append(jsTrim(typed))
            keep(next)
            choose(ChoiceEdits.addedKey(next.added.count - 1))
        }
    }
}

extension Library {
    /// The page's held lists written on Save, in the one safe order: a bag's pockets before
    /// the bags (they find their bag by its name), then everything but the removals. Answers
    /// each list's map (`applyChoiceEdits`) by its page key.
    mutating func applyPageChoices(_ held: [String: ChoiceEdits]) -> [String: [String: String]] {
        var maps: [String: [String: String]] = [:]
        let order = held.keys.sorted { a, b in
            let pa = a.hasPrefix("pockets"), pb = b.hasPrefix("pockets")
            return pa != pb ? pa : a < b
        }
        for key in order { maps[key] = applyChoiceEdits(held[key]!) }
        return maps
    }

    /// …and the removals, once the page's thing or row is written.
    mutating func applyPageRemovals(_ held: [String: ChoiceEdits], _ maps: [String: [String: String]]) {
        for (key, e) in held.sorted(by: { $0.key < $1.key }) {
            var e = e
            // A bag renamed on the same page: its pockets are found under its new name.
            if e.kind == "pockets" { e.bag = Library.choiceValue(e.bag, after: maps["bags"] ?? [:]) }
            applyChoiceRemovals(e, renamed: maps[key] ?? [:])
        }
    }
}

/// A bag's page opened from a drop-down (a sheet takes an Identifiable).
struct BagPageId: Identifiable { let id: String }

extension DropDownRowTools {
    /// A template's Section list with its tools (0.68 on a thing's page; 0.69 on a
    /// template's row too): rename, move and remove its sections, held until Save in
    /// `edits` and written then by `Library.applySectionEdits`. `removed` hears of a
    /// section taken away (the page's choice in it goes to no section).
    static func sections(_ lib: Library, template t: PackList, edits: SectionEdits,
                         keep: @escaping (SectionEdits) -> Void, removed: @escaping (String) -> Void) -> DropDownRowTools {
        let id = t.id
        func order() -> [String] { lib.sectionsAsEdited(templateId: id, edits).map(\.id) }
        return DropDownRowTools(
            applies: { value in t.sections.contains { $0.id == value } },
            rename: { value, name in
                let clean = jsTrim(name)
                guard !clean.isEmpty else { return "Type the section's name first." }
                guard !lib.sectionNameTaken(templateId: id, name: clean, except: value, edits) else {
                    return "\(t.name) already has a section called that."
                }
                var e = edits
                let stored = lib.templates.first { $0.id == id }?.sections.first { $0.id == value }?.name
                e.names[value] = clean == stored ? nil : clean
                keep(e)
                return ""
            },
            move: { value, by in
                var ids = order()
                guard let at = ids.firstIndex(of: value), ids.indices.contains(at + by) else { return }
                ids.swapAt(at, at + by)
                var e = edits
                let stored = lib.templates.first { $0.id == id }?.sections.map(\.id)
                e.order = ids == stored ? nil : ids
                keep(e)
            },
            canMove: { value, by in
                let ids = order()
                guard let at = ids.firstIndex(of: value) else { return false }
                return ids.indices.contains(at + by)
            },
            isRemoved: { edits.removed.contains($0) },
            remove: { value in
                var e = edits
                e.removed.insert(value)
                keep(e)
                removed(value)
            },
            putBack: { value in
                var e = edits
                e.removed.remove(value)
                keep(e)
            },
            question: { value in
                let name = lib.sectionsAsEdited(templateId: id, edits).first { $0.id == value }?.name ?? ""
                return "Remove \(name) from \(t.name)? Its things stay, with no section."
            })
    }
}
