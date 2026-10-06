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

struct DropDown: View {
    let title: String?
    let options: [(value: String, label: String)]
    let selected: String
    let ids: DropDownIds
    let tint: Color
    /// A first row that means "nothing said" (value ""), named `<row>-none`. Only
    /// Kept at home has one; elsewhere such a row is simply the first option, as its
    /// pill was.
    let blank: String?
    /// A chosen value that is none of the rows (kept from before, or from the web app)
    /// gets a row of its own at the end, `<row>-other`, ticked — so it is seen and can
    /// be left as it is. For lists whose values are words; an id would read as nonsense.
    let other: Bool
    /// When two values are the same choice: exact, unless the list says otherwise
    /// (his places compare as names, ignoring capitals and spaces).
    let same: (String, String) -> Bool
    let newEntry: DropDownNew?
    let choose: (String) -> Void

    @State private var open = false
    @State private var typed = ""
    @State private var needs = ""

    init(title: String?, options: [(value: String, label: String)], selected: String, id: DropDownIds,
         tint: Color = AppSection.care.color, blank: String? = nil, other: Bool = false,
         same: @escaping (String, String) -> Bool = { $0 == $1 }, newEntry: DropDownNew? = nil,
         choose: @escaping (String) -> Void) {
        self.title = title; self.options = options; self.selected = selected; self.ids = id
        self.tint = tint; self.blank = blank; self.other = other; self.same = same
        self.newEntry = newEntry; self.choose = choose
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title { HeadingBand(title: title, tint: tint, id: ids.title) }
            field
        }
    }

    /// The field: the choice in words and a ▾, looking like the text fields around it.
    /// A blank choice ("Not said", "Same as the thing …") is in grey, as a field's own
    /// grey words are.
    private var field: some View {
        Button { open = true } label: {
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
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        // Read as "Kind of thing, Electronics": the heading names it, the value is the choice.
        .accessibilityLabel(title ?? shown)
        .accessibilityValue(shown)
        .accessibilityIdentifier(ids.field)
        // No arrow edge given: the list goes where there is room — under a field near the
        // top of the page, over one near the bottom. (Kept at home's list was fixed ABOVE
        // its field, and on a row's Bag, near the top, it was squeezed to three rows.)
        .popover(isPresented: $open) {
            list.presentationCompactAdaptation(.popover)
        }
        .onChange(of: open) { _, now in
            if !now { typed = ""; needs = "" }
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let blank { row(blank, value: "", id: "\(ids.row)-none") }
                    ForEach(Array(options.enumerated()), id: \.offset) { n, o in
                        row(o.label, value: o.value, id: "\(ids.row)-\(n)")
                    }
                    if otherRow { row(selected, value: selected, id: "\(ids.row)-other") }
                    if let newEntry { foot(newEntry) }
                }
                .padding(12)
            }
            // A long list opens at the choice that stands, so the tick is seen.
            .onAppear { if let at = chosenRowId { proxy.scrollTo(at, anchor: .center) } }
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
    private func row(_ label: String, value: String, id: String) -> some View {
        let on = same(value, selected)
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
            .background(Theme.bg)
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

    private func add(_ new: DropDownNew) {
        let words = jsTrim(typed)
        guard !words.isEmpty else { needs = new.needs; return }
        new.add(words)
        typed = ""
        open = false
    }
}
