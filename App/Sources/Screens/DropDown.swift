import SwiftUI
import PackingCore

// A drop-down: a field-like button that opens its choices as a list beside it, a
// popover on the iPhone as on the Mac. His word (6 Oct 2026), after Kept at home was
// made one: "I like the dropdown for 'kept in'. Well done. Can we please make these
// kinds of drop-downs everywhere? I think it would lend itself perfectly for 'usually
// packed in', 'Kind of thing' etc." So every PICK-ONE list on the thing's page and on
// a template's row is one of these; lists where several may be picked stay pills.

/// The names a drop-down gives its parts, for the tests and VoiceOver. Made from one
/// prefix they are the ids its pills had, so a test that named a pill still finds the
/// same row: the field `<prefix>`, the open list `<prefix>-list`, its rows
/// `<prefix>-<n>` (and `-none`, `-other`, `-new`, `-add`, `-add-needs`), the heading
/// `<prefix>-title`. Kept at home names its parts its own way (they came first).
struct DropDownIds: ExpressibleByStringLiteral {
    var field: String
    var list: String
    var row: String
    var title: String

    init(field: String, list: String, row: String, title: String) {
        self.field = field; self.list = list; self.row = row; self.title = title
    }

    init(stringLiteral prefix: String) {
        self.init(field: prefix, list: "\(prefix)-list", row: prefix, title: "\(prefix)-title")
    }
}

/// A new entry typed at the foot of the list — Kept at home's "A new place", a row's
/// "A new section". Add with nothing typed says `needs` under the field (never a grey
/// button); otherwise `add` gets the words, trimmed, and the list closes.
struct DropDownNew {
    let placeholder: String
    var button = "Add"
    let needs: String
    let add: (String) -> Void
}

/// How a drop-down's heading reads. A band of its own over the field (the thing's
/// page, a template's row); a heading inside a block that already has one (a thing's
/// Section on each of its templates, under "On these templates"); or a word to the
/// LEFT of the field on the same line (the trip's Sorting — his marks of 2026-09-25,
/// "Sorting" on the left, kept when its pills became a drop-down, 6 Oct 2026).
enum DropDownHeading { case band, title, beside }

struct DropDown: View {
    let title: String?
    let heading: DropDownHeading
    let options: [(value: String, label: String)]
    let selected: String
    let ids: DropDownIds
    let tint: Color
    /// A first row that means "nothing said" (value ""), named `<row>-none`. Kept at
    /// home has one, and a thing's Section on each template ("No section", 0.64 — no
    /// pills came before it, so its sections are counted from 0); elsewhere such a row
    /// is simply the first option, as its pill was.
    let blank: String?
    /// A chosen value that is none of the rows (kept from before, or from the web app)
    /// gets a row of its own at the end, `<row>-other`, ticked — so it is seen and can
    /// be left as it is. For lists whose values are words; an id would read as nonsense.
    let other: Bool
    /// When two values are the same choice: exact, unless the list says otherwise
    /// (his places compare as names, ignoring capitals and spaces).
    let same: (String, String) -> Bool
    let newEntry: DropDownNew?
    /// The 2-point ring of the field in focus on a thing's page (Mac, 0.68); nil = none.
    let ring: Color?
    let choose: (String) -> Void

    @State private var open = false
    @State private var typed = ""
    @State private var needs = ""
    #if os(macOS)
    /// The Mac's keys on a thing's page (0.68): given by the page; nil elsewhere.
    @Environment(\.dropDownKeys) private var keys
    /// The row the arrows are on in the open list (an index into `keyRows`; one past the
    /// last = the offer of a new entry).
    @State private var lit: Int?
    /// The letters typed, and when the last came: a pause of a second starts afresh.
    @State private var ahead = ""
    @State private var aheadAt = Date.distantPast
    /// Words typed that are none of the rows, on a list that takes a new entry: offered
    /// as "A new place: …" at the list's foot.
    @State private var offer = ""
    /// The list was opened by the keys: its foot offers what is typed instead of a field.
    @State private var byKeys = false
    #endif

    init(title: String?, heading: DropDownHeading = .band, options: [(value: String, label: String)],
         selected: String, id: DropDownIds,
         tint: Color = AppSection.care.color, blank: String? = nil, other: Bool = false,
         same: @escaping (String, String) -> Bool = { $0 == $1 }, newEntry: DropDownNew? = nil,
         ring: Color? = nil, choose: @escaping (String) -> Void) {
        self.title = title; self.heading = heading
        self.options = options; self.selected = selected; self.ids = id
        self.tint = tint; self.blank = blank; self.other = other; self.same = same
        self.newEntry = newEntry; self.ring = ring; self.choose = choose
    }

    /// The words of the choice that stands — what the field shows and says.
    private var shown: String {
        if blank != nil, same("", selected) { return blank ?? "" }
        if let hit = options.first(where: { same($0.value, selected) }) { return hit.label }
        return selected.isEmpty ? "Not said" : selected
    }

    /// The chosen value is none of the rows, and the list shows it on a row of its own.
    private var otherRow: Bool {
        other && !same("", selected) && !options.contains { same($0.value, selected) }
    }

    @ViewBuilder var body: some View {
        switch heading {
        case .beside:
            HStack(spacing: 10) {
                if let title {
                    Text(title)
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                        .lineLimit(1).fixedSize()
                        .accessibilityIdentifier(ids.title)
                }
                field
            }
        case .band, .title:
            VStack(alignment: .leading, spacing: 6) {
                if let title {
                    if heading == .title { HeadingTitle(title: title, tint: tint, id: ids.title) }
                    else { HeadingBand(title: title, tint: tint, id: ids.title) }
                }
                field
            }
        }
    }

    /// The field: the choice in words and a ▾, looking like the text fields around it.
    /// A blank choice ("Not said", "Same as the thing …") is in grey, as a field's own
    /// grey words are.
    private var field: some View {
        Button {
            putKeyboardAway()
            #if os(macOS)
            keys?.clicked?(ids.field)
            #endif
            open = true
        } label: {
            HStack(spacing: 8) {
                Text(shown)
                    .font(.body).foregroundStyle(same("", selected) ? Theme.muted : Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                SVGPath.path("M6 9l6 6 6-6")
                    .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 16, height: 16).foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ring ?? Theme.line, lineWidth: ring == nil ? 1 : 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        // Read as "Kind of thing, Electronics": the heading names it, the value is the choice.
        .accessibilityLabel(title ?? shown)
        .accessibilityValue(shown)
        .accessibilityIdentifier(ids.field)
        // No arrow edge given: the system puts the list above or below its field, wherever
        // it fits — a field near the top opens downwards. (Kept at home's list was fixed ABOVE
        // its field, and on a row's Bag, near the top, it was squeezed to three rows.)
        .popover(isPresented: $open) {
            list.presentationCompactAdaptation(.popover)
        }
        .onChange(of: open) { _, now in
            if !now { typed = ""; needs = "" }
            #if os(macOS)
            if now {
                if lit == nil { lit = chosenIndex }
            } else {
                lit = nil; ahead = ""; offer = ""; byKeys = false
            }
            keys?.opened(now ? ids.field : (keys?.open == ids.field ? nil : keys?.open), byKeys: now && byKeys)
            #endif
        }
        #if os(macOS)
        .background {
            if let keys { DropDownKeyAnswer(keys: keys, id: ids.field, answer: answer) }
        }
        #endif
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let blank { row(blank, value: "", id: "\(ids.row)-none", n: 0) }
                    ForEach(Array(options.enumerated()), id: \.offset) { n, o in
                        row(o.label, value: o.value, id: "\(ids.row)-\(n)", n: n + (blank == nil ? 0 : 1))
                    }
                    if otherRow { row(selected, value: selected, id: "\(ids.row)-other", n: (blank == nil ? 0 : 1) + options.count) }
                    if let newEntry {
                        #if os(macOS)
                        if byKeys { offerRow(newEntry) } else { foot(newEntry) }
                        #else
                        foot(newEntry)
                        #endif
                    }
                }
                .padding(12)
            }
            // A long list opens at the choice that stands, so the tick is seen.
            .onAppear { if let at = chosenRowId { proxy.scrollTo(at, anchor: .center) } }
            #if os(macOS)
            // …and the arrows' row stays in sight as they move.
            .onChange(of: lit) { _, n in
                guard let n else { return }
                proxy.scrollTo(n < keyRows.count ? keyRows[n].id : "\(ids.row)-offer")
            }
            #endif
        }
        .frame(minWidth: 280, idealWidth: 320, maxHeight: 440)
        .background(Theme.bg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ids.list)
    }

    /// The id of the row that is ticked, to scroll to.
    private var chosenRowId: String? {
        if blank != nil, same("", selected) { return "\(ids.row)-none" }
        if let n = options.firstIndex(where: { same($0.value, selected) }) { return "\(ids.row)-\(n)" }
        return otherRow ? "\(ids.row)-other" : nil
    }

    /// One choice: a tap takes it and closes the list. Filled and shaped as a whole
    /// row — on the Mac a slim whole-row plain button with nothing behind its words
    /// once took no clicks.
    private func row(_ label: String, value: String, id: String, n: Int) -> some View {
        let on = same(value, selected)
        #if os(macOS)
        let arrows = lit == n
        #else
        let arrows = false
        #endif
        return Button { choose(value); open = false } label: {
            HStack(spacing: 8) {
                Text(label).font(.body).foregroundStyle(value.isEmpty ? Theme.muted : Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if on {
                    Tick().stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(width: 18, height: 18)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 6).frame(minHeight: Metrics.tap)
            // The row the arrows are on (Mac keys): lit in the list's colour, as a menu's.
            .background(arrows ? AnyShapeStyle(tint.opacity(0.18)) : AnyShapeStyle(Theme.bg))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(on ? .isSelected : [])
        .id(id)
    }

    private func foot(_ new: DropDownNew) -> some View {
        HStack(spacing: 8) {
            TextField(new.placeholder, text: $typed)
                .textFieldStyle(.plain)
                .font(.body).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                .onSubmit { add(new) }
                .accessibilityIdentifier("\(ids.row)-new")
            Button { add(new) } label: { FieldButtonLabel(title: new.button, tint: tint) }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("\(ids.row)-add")
        }
        .needsLine($needs, typed: typed, id: "\(ids.row)-add-needs")
        .padding(.top, 8)
    }

    #if os(macOS)
    // MARK: The Mac's keys (0.68, a thing's page)

    /// The list's rows in order, as the arrows and the letters see them.
    private var keyRows: [(label: String, value: String, id: String)] {
        var out: [(label: String, value: String, id: String)] = []
        if let blank { out.append((blank, "", "\(ids.row)-none")) }
        for (n, o) in options.enumerated() { out.append((o.label, o.value, "\(ids.row)-\(n)")) }
        if otherRow { out.append((selected, selected, "\(ids.row)-other")) }
        return out
    }

    /// The ticked row's place in `keyRows`.
    private var chosenIndex: Int? { keyRows.firstIndex { same($0.value, selected) } }

    /// The first row whose words start with what was typed (capitals ignored), else the
    /// first with a WORD that does — "hand" finds "Carry-on / hand luggage".
    private func match(_ typed: String) -> Int? {
        let t = typed.lowercased()
        guard !t.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let rows = keyRows.map { $0.label.lowercased() }
        if let n = rows.firstIndex(where: { $0.hasPrefix(t) }) { return n }
        return rows.firstIndex { label in
            label.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains { $0.hasPrefix(t) }
        }
    }

    /// One key from the page. Closed: letters pick the first match at once (a list that
    /// takes a new entry opens to offer what matches nothing); Space or ↓ opens. Open: ↑ ↓
    /// move, letters jump, Return chooses, Esc closes the list only. Answers whether the
    /// key was taken.
    private func answer(_ key: DropDownKey) -> Bool {
        switch key {
        case .open:
            openByKeys()
        case .letters(let s):
            let now = Date()
            // A new name being typed in the open list keeps every letter, pause or not.
            let naming = open && newEntry != nil && !offer.isEmpty
            ahead = (naming || now.timeIntervalSince(aheadAt) <= 1) ? ahead + s : s
            aheadAt = now
            if open {
                follow()
            } else if let n = match(ahead) {
                if !same(keyRows[n].value, selected) { choose(keyRows[n].value) }
            } else if newEntry != nil {
                offer = ahead
                openByKeys(lit: keyRows.count)
            }
        case .space:
            // In the middle of a name (a new place has spaces in it), a space is a letter;
            // otherwise Space opens the list, or chooses in the open one.
            let typing = !ahead.isEmpty && (Date().timeIntervalSince(aheadAt) <= 1 || (open && !offer.isEmpty))
            if newEntry != nil && typing { return answer(.letters(" ")) }
            if !open { openByKeys() } else { chooseLit() }
        case .back:
            guard open, !ahead.isEmpty else { return true }
            ahead.removeLast()
            aheadAt = Date()
            follow()
        case .down:
            if !open { openByKeys(); return true }
            let last = keyRows.count - (offer.isEmpty ? 1 : 0)
            lit = min((lit ?? -1) + 1, last)
        case .up:
            guard open else { return true }
            lit = max((lit ?? 1) - 1, 0)
        case .choose:
            guard open else { return false }
            chooseLit()
        case .close:
            guard open else { return false }
            close()
        }
        return true
    }

    private func openByKeys(lit at: Int? = nil) {
        byKeys = true
        lit = at ?? chosenIndex ?? 0
        open = true
        keys?.opened(ids.field, byKeys: true)
    }

    /// The arrows follow the letters: onto the match, or onto the offer of a new entry.
    private func follow() {
        if let n = match(ahead) {
            lit = n
            offer = ""
        } else if newEntry != nil, !jsTrim(ahead).isEmpty {
            offer = ahead
            lit = keyRows.count
        } else {
            offer = ""
            if let n = lit, n >= keyRows.count { lit = chosenIndex ?? 0 }
        }
    }

    private func chooseLit() {
        if let lit, lit == keyRows.count, let newEntry, !jsTrim(offer).isEmpty {
            newEntry.add(jsTrim(offer))
        } else if let lit, keyRows.indices.contains(lit) {
            choose(keyRows[lit].value)
        }
        close()
    }

    private func close() {
        open = false
        keys?.opened(nil, byKeys: false)
    }

    /// The foot of a list opened by the keys, on a list that takes a new entry: what he
    /// typed that is none of the rows — "A new place: Workbench" — lit, so Return makes it;
    /// before that, a quiet line saying how.
    @ViewBuilder private func offerRow(_ new: DropDownNew) -> some View {
        if offer.isEmpty {
            Text("\(new.placeholder): type its name")
                .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                .padding(.top, 8)
                .accessibilityIdentifier("\(ids.row)-offer-hint")
        } else {
            Button { chooseLit() } label: {
                HStack(spacing: 6) {
                    Text("\(new.placeholder):").foregroundStyle(Theme.muted)
                    Text(jsTrim(offer)).foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                }
                .font(.body).lineLimit(1)
                .padding(.vertical, 6).padding(.horizontal, 6).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 6).fill(lit == keyRows.count ? tint.opacity(0.18) : Color.clear))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .padding(.top, 4)
            .accessibilityIdentifier("\(ids.row)-offer")
            .id("\(ids.row)-offer")
        }
    }
    #endif

    /// A field being typed in (the weight, a new place) keeps the keyboard up on the
    /// iPhone, and a list opened under it was squeezed into the space above the keys —
    /// so opening one puts the keyboard away first, as a choice is made by tapping.
    private func putKeyboardAway() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func add(_ new: DropDownNew) {
        let words = jsTrim(typed)
        guard !words.isEmpty else { needs = new.needs; return }
        new.add(words)
        typed = ""
        open = false
    }
}
