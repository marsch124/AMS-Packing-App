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

/// Tools on the rows of a list whose rows are themselves changed — a thing's Section on
/// each template (0.68, his ask with a picture of that list open: "I would like to be able
/// to Rename, Change and Delete Sections from this here as well"). Each row it `applies`
/// to gets a pen (rename: the row becomes a field; Return takes the name, Esc leaves it),
/// two small arrows (its place in the order) and a quiet red Remove at the far right,
/// which asks inside the list first. The page holds every change until it is saved and
/// gives the list its options as they stand; a removed row is struck out, with Put back.
struct DropDownRowTools {
    /// The rows that take tools (by value).
    let applies: (String) -> Bool
    /// A new name for a row: "" when taken, otherwise what is wrong with it.
    let rename: (_ value: String, _ name: String) -> String
    /// One place up (−1) or down (1); and whether there is a place to go.
    let move: (_ value: String, _ by: Int) -> Void
    let canMove: (_ value: String, _ by: Int) -> Bool
    let isRemoved: (String) -> Bool
    let remove: (String) -> Void
    let putBack: (String) -> Void
    /// The question before a row is removed ("Remove Nutrition from Business trip? …").
    let question: (String) -> String
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
    /// Rename, move and remove on its rows (a thing's Section list, 0.68); nil = none.
    let tools: DropDownRowTools?
    /// The 2-point ring of the field in focus on a thing's page (Mac, 0.68); nil = none.
    let ring: Color?
    let choose: (String) -> Void

    @State private var open = false
    @State private var typed = ""
    @State private var needs = ""
    /// The row being renamed (its value), what its field says, and what was wrong.
    @State private var renaming: String?
    @State private var newName = ""
    @State private var nameNeeds = ""
    @FocusState private var naming: Bool
    /// The foot's field (A new place …) has the keys.
    @FocusState private var footTyping: Bool
    /// The row whose removal is being asked (its value).
    @State private var asking: String?
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
    /// The tool of the lit row that Tab has reached (`tool(for:)`), nil = the row itself.
    @State private var tool: Int?
    /// The open list's own window (a popover is one): a name typed in it needs that window
    /// to have the keys, which the keys alone never gave it (GitHub's Mac, 7 Oct 2026).
    @State private var listWindow = ListWindow()
    final class ListWindow { weak var window: NSWindow? }
    #endif

    init(title: String?, heading: DropDownHeading = .band, options: [(value: String, label: String)],
         selected: String, id: DropDownIds,
         tint: Color = AppSection.care.color, blank: String? = nil, other: Bool = false,
         same: @escaping (String, String) -> Bool = { $0 == $1 }, newEntry: DropDownNew? = nil,
         tools: DropDownRowTools? = nil, ring: Color? = nil, choose: @escaping (String) -> Void) {
        self.title = title; self.heading = heading
        self.options = options; self.selected = selected; self.ids = id
        self.tint = tint; self.blank = blank; self.other = other; self.same = same
        self.newEntry = newEntry; self.tools = tools; self.ring = ring; self.choose = choose
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
            if !now { typed = ""; needs = ""; renaming = nil; asking = nil; nameNeeds = "" }
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
        // A field in the list typed in has every key but Esc (the page asks this, not the window).
        .onChange(of: renaming) { _, now in keys?.typingInList = now != nil || footTyping }
        .onChange(of: footTyping) { _, now in keys?.typingInList = now || renaming != nil }
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
        #if os(macOS)
        .background(WindowReader { w in listWindow.window = w })
        #endif
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
    @ViewBuilder private func row(_ label: String, value: String, id: String, n: Int) -> some View {
        if let tools, tools.applies(value) {
            toolRow(tools, label, value: value, id: id, n: n)
        } else {
            plainRow(label, value: value, id: id, n: n)
        }
    }

    private func plainRow(_ label: String, value: String, id: String, n: Int) -> some View {
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

    /// A row with its tools — or its name being changed, or its removal being asked.
    @ViewBuilder private func toolRow(_ tools: DropDownRowTools, _ label: String, value: String, id: String, n: Int) -> some View {
        #if os(macOS)
        let arrows = lit == n
        #else
        let arrows = false
        #endif
        if renaming == value {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Section name", text: Binding(get: { newName }, set: { newName = $0; nameNeeds = "" }))
                    .textFieldStyle(.plain)
                    .font(.body).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(nameNeeds.isEmpty ? tint : AppSection.actions.color, lineWidth: 1.5))
                    .focused($naming)
                    .onSubmit { takeName(tools, value) }
                    #if os(macOS)
                    .onExitCommand { leaveName() }          // a text field keeps Escape for itself
                    #endif
                    .accessibilityIdentifier("\(id)-name")
                if !nameNeeds.isEmpty {
                    Text(nameNeeds).font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("\(id)-name-needs")
                }
            }
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
            .id(id)
        } else if asking == value {
            // Asked inside the list, as a thing's Delete asks on its page.
            VStack(alignment: .leading, spacing: 8) {
                Text(tools.question(value))
                    .font(.system(.subheadline)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(id)-ask")
                HStack(spacing: 12) {
                    Button { tools.remove(value); asking = nil; keyTool(nil) } label: {
                        Text("Remove").font(.system(.subheadline, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                            .background(Capsule().fill(AppSection.actions.color))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .focusRing(toolLit(n, 0), tint: tint, radius: 12, gap: 2)
                    .accessibilityIdentifier("\(id)-remove-yes")
                    Button { asking = nil; keyTool(nil) } label: {
                        Text("Keep").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 8).frame(minHeight: Metrics.compact)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .focusRing(toolLit(n, 1), tint: tint, radius: 6, gap: 2)
                    .accessibilityIdentifier("\(id)-remove-no")
                    Spacer(minLength: 0)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppSection.actions.color, lineWidth: 1))
            .padding(.vertical, 4)
            .id(id)
        } else {
            let on = same(value, selected)
            let gone = tools.isRemoved(value)
            HStack(spacing: 2) {
                Button { if !gone { choose(value); open = false } } label: {
                    HStack(spacing: 8) {
                        Text(label).font(.body).strikethrough(gone)
                            .foregroundStyle(gone ? Theme.muted : Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 6)
                        if on {
                            Tick().stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .frame(width: 18, height: 18)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.vertical, 6).frame(minHeight: Metrics.tap)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier(id)
                .accessibilityAddTraits(on ? .isSelected : [])
                if gone {
                    toolButton(id: "\(id)-putback", lit: toolLit(n, 0), label: "Put back") {
                        tools.putBack(value); keyTool(nil)
                    } face: {
                        Text("Put back").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                    }
                } else {
                    toolButton(id: "\(id)-rename", lit: toolLit(n, 0), label: "Rename") { startName(value, label) } face: {
                        glyph("M4 20h4L18.5 9.5a2.1 2.1 0 0 0-3-3L5 17v3zM13.5 7.5l3 3", Theme.muted)
                    }
                    toolButton(id: "\(id)-up", lit: toolLit(n, 1), label: "Move up") { move(tools, value, -1) } face: {
                        glyph("M6 15l6-6 6 6", tools.canMove(value, -1) ? tint : Theme.faint)
                    }
                    toolButton(id: "\(id)-down", lit: toolLit(n, 2), label: "Move down") { move(tools, value, 1) } face: {
                        glyph("M6 9l6 6 6-6", tools.canMove(value, 1) ? tint : Theme.faint)
                    }
                    toolButton(id: "\(id)-remove", lit: toolLit(n, 3), label: "Remove") { asking = value; keyTool(0) } face: {
                        Text("Remove").font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    }
                }
            }
            .background(arrows ? AnyShapeStyle(tint.opacity(0.18)) : AnyShapeStyle(Theme.bg))
            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
            .id(id)
        }
    }

    /// One of a row's tools: a mark or a word, pressed — never the row behind it.
    private func toolButton<Face: View>(id: String, lit: Bool, label: String, _ action: @escaping () -> Void,
                                        @ViewBuilder face: () -> Face) -> some View {
        Button(action: action) {
            face()
                .frame(minWidth: Metrics.compact, minHeight: Metrics.tap)
                .padding(.horizontal, 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .focusRing(lit, tint: tint, radius: 6, gap: 1)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    /// A small hand-drawn mark on the 24-point grid.
    private func glyph(_ d: String, _ color: Color) -> some View {
        SVGPath.path(d)
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .foregroundStyle(color)
            .onGrid(16)
            .accessibilityHidden(true)
    }

    private func startName(_ value: String, _ label: String) {
        asking = nil
        nameNeeds = ""
        newName = label
        renaming = value
        #if os(macOS)
        keys?.typingInList = true
        let home = listWindow
        DispatchQueue.main.async {
            home.window?.makeKey()
            naming = true
        }
        #else
        DispatchQueue.main.async { naming = true }
        #endif
    }

    private func takeName(_ tools: DropDownRowTools, _ value: String) {
        let said = tools.rename(value, newName)
        guard said.isEmpty else { nameNeeds = said; return }
        leaveName()
    }

    private func leaveName() {
        renaming = nil
        nameNeeds = ""
        naming = false
        #if os(macOS)
        keys?.typingInList = footTyping
        #endif
    }

    private func move(_ tools: DropDownRowTools, _ value: String, _ by: Int) {
        guard tools.canMove(value, by) else { return }
        tools.move(value, by)
        #if os(macOS)
        // The arrows' row goes with the section it moved.
        if let n = lit { lit = n + by }
        #endif
    }

    /// Is this tool of row `n` the one Tab has reached (Mac)?
    private func toolLit(_ n: Int, _ k: Int) -> Bool {
        #if os(macOS)
        return lit == n && tool == k
        #else
        return false
        #endif
    }

    private func keyTool(_ k: Int?) {
        #if os(macOS)
        tool = k
        #endif
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
                .focused($footTyping)
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
        case .tab(let by):
            return tab(by)
        case .letters(let s):
            tool = nil
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
            if !open { openByKeys() } else if !pressTool() { chooseLit() }
        case .back:
            guard open, !ahead.isEmpty else { return true }
            ahead.removeLast()
            aheadAt = Date()
            follow()
        case .down:
            if !open { openByKeys(); return true }
            let last = keyRows.count - (offer.isEmpty ? 1 : 0)
            tool = nil; asking = nil
            lit = min((lit ?? -1) + 1, last)
        case .up:
            guard open else { return true }
            tool = nil; asking = nil
            lit = max((lit ?? 1) - 1, 0)
        case .choose:
            guard open else { return false }
            if !pressTool() { chooseLit() }
        case .close:
            guard open else { return false }
            // Esc leaves a name being changed, or a question, before the list.
            if renaming != nil { leaveName(); return true }
            if asking != nil { asking = nil; tool = nil; return true }
            close()
        }
        return true
    }

    /// The tools of the lit row Tab steps through: its pen, ↑, ↓ and Remove (Put back once
    /// removed; Remove and Keep while asked). Answers false past the last (or before the
    /// row, going back): the page then closes the list and goes on.
    private func tab(_ by: Int) -> Bool {
        guard open, let tools, let n = lit, keyRows.indices.contains(n), tools.applies(keyRows[n].value) else { return false }
        let value = keyRows[n].value
        let count = asking == value ? 2 : (tools.isRemoved(value) ? 1 : 4)
        guard let at = tool else {
            if by < 0 { return false }
            tool = 0
            return true
        }
        let next = at + by
        if asking == value { tool = (next + count) % count; return true }   // the question keeps Tab
        if next < 0 { tool = nil; return true }
        if next >= count { tool = nil; return false }
        tool = next
        return true
    }

    /// Space or Return on a tool Tab reached: it is pressed. False when no tool is lit.
    private func pressTool() -> Bool {
        guard let tools, let n = lit, let k = tool, keyRows.indices.contains(n), tools.applies(keyRows[n].value) else { return false }
        let value = keyRows[n].value
        if asking == value {
            if k == 0 { tools.remove(value) }
            asking = nil
            tool = nil
        } else if tools.isRemoved(value) {
            tools.putBack(value)
            tool = nil
        } else {
            switch k {
            case 0: startName(value, keyRows[n].label)
            case 1: move(tools, value, -1)
            case 2: move(tools, value, 1)
            default: asking = value; tool = 0
            }
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
