import SwiftUI
import PackingCore
import PackingLibrary

/// What a column of the things table IS: which field it shows, how wide, and how
/// it is edited. Keeping this beside the screen means a new column is one line
/// here and nothing anywhere else.
enum TableColumns {
    static let rowHeight: CGFloat = 34

    /// Where a choice column gets its list of answers — his own Settings lists,
    /// never a list this app invented.
    enum Answers { case places, containers, owners, people, conditions }

    enum Kind {
        case number(WritableKeyPath<Item, Double>)
        case words(WritableKeyPath<Item, String>)
        case choice(WritableKeyPath<Item, String>, Answers)
        case flag(WritableKeyPath<Item, Bool>)
        /// A tick per list: on means the thing is on that list.
        case onList(String)
        /// An answer that belongs to the thing's place ON A LIST, not to the thing:
        /// how many of it that list wants, and which section of that list it sits in.
        /// Only answerable when the thing is on exactly one list — with two, there
        /// are two answers and the row cannot show which is meant.
        case perList(PerList)
    }

    enum PerList { case qty, section }

    struct Column: Identifiable {
        let id: String
        let title: String
        let width: CGFloat
        let kind: Kind
        /// Which heading band it sits under.
        var group = "The thing itself"
    }

    /// A run of neighbouring columns that share a band, so the band is drawn over
    /// exactly the columns he is showing.
    struct Band: Identifiable {
        let id: String
        let title: String
        let width: CGFloat
        /// How far from the left of the grid this run of columns begins, so its
        /// title can hold still inside it while the grid travels.
        let start: CGFloat
    }

    static func bands(_ columns: [Column]) -> [Band] {
        var out: [Band] = []
        var x: CGFloat = 0
        for column in columns {
            if let last = out.last, last.title == column.group {
                out[out.count - 1] = Band(id: last.id, title: last.title,
                                          width: last.width + column.width, start: last.start)
            } else {
                out.append(Band(id: "\(out.count)-\(column.group)", title: column.group,
                                width: column.width, start: x))
            }
            x += column.width
        }
        return out
    }

    /// Everything about the thing itself — changing one of these changes the thing
    /// on every list it is on.
    static let intrinsic: [Column] = [
        Column(id: "weight", title: "Weight", width: 74, kind: .number(\Item.weight)),
        Column(id: "storage", title: "Storage", width: 150, kind: .choice(\Item.storage, .places)),
        Column(id: "container", title: "Packed in", width: 140, kind: .choice(\Item.container, .containers)),
        Column(id: "ownedBy", title: "Owner", width: 110, kind: .choice(\Item.ownedBy, .owners)),
        Column(id: "packer", title: "Packed by", width: 110, kind: .choice(\Item.packer, .people)),
        Column(id: "condition", title: "Condition", width: 120, kind: .choice(\Item.condition, .conditions)),
        Column(id: "color", title: "Colour", width: 100, kind: .words(\Item.color)),
        Column(id: "size", title: "Size", width: 84, kind: .words(\Item.size)),
        Column(id: "manufacturer", title: "Maker", width: 120, kind: .words(\Item.manufacturer)),
        Column(id: "model", title: "Model", width: 120, kind: .words(\Item.model)),
        Column(id: "serial", title: "Serial", width: 120, kind: .words(\Item.serial)),
        Column(id: "note", title: "Note", width: 180, kind: .words(\Item.note)),
        Column(id: "liquid", title: "Liquid", width: 62, kind: .flag(\Item.liquid)),
        Column(id: "charging", title: "Charges", width: 68, kind: .flag(\Item.charging)),
        Column(id: "restricted", title: "Restricted", width: 78, kind: .flag(\Item.restricted)),
        Column(id: "consumable", title: "Runs out", width: 72, kind: .flag(\Item.consumable)),
        Column(id: "perNight", title: "Per night", width: 74, kind: .flag(\Item.perNight)),
    ]

    /// What belongs to the thing's PLACE on a list rather than to the thing. Kept
    /// apart from `intrinsic` on purpose: changing one of these for many things at
    /// once has no meaning, so the batch sheet — which offers `intrinsic` — cannot
    /// offer them.
    static let perListColumns: [Column] = [
        Column(id: "listQty", title: "How many", width: 92, kind: .perList(.qty), group: "On this list"),
        Column(id: "listSection", title: "Section", width: 140, kind: .perList(.section), group: "On this list"),
    ]

    /// One tick column per list of his, so a thing joins or leaves a list here.
    /// Taking it off a list drops only that list's own answers for it — the thing,
    /// its weight, its care and its photos stay.
    static func listColumns(_ library: Library) -> [Column] {
        library.templates.map { list in
            Column(id: "list:\(list.id)", title: list.name, width: 100,
                   kind: .onList(list.id), group: "On these lists")
        }
    }

    static func all(_ library: Library) -> [Column] { intrinsic + perListColumns + listColumns(library) }

    /// What he sees before he has chosen anything: the gaps he actually has.
    static let startingColumns = ["weight", "storage", "container", "ownedBy", "packer", "condition", "listQty"]

    /// His chosen columns, in his order; unknown ids (a list he deleted) fall away.
    static func chosen(_ stored: String, library: Library) -> [Column] {
        let ids = stored.isEmpty ? startingColumns : stored.split(separator: ",").map(String.init)
        let byId = Dictionary(uniqueKeysWithValues: all(library).map { ($0.id, $0) })
        return ids.compactMap { byId[$0] }
    }

    /// The name of the column the rows are sorted by, for the little sort button.
    static func sortName(_ key: String, _ library: Library) -> String {
        if key == "name" { return "Name" }
        return all(library).first { $0.id == key }?.title ?? "Name"
    }

    /// One comparable value per thing, so any column can be the order. Numbers are
    /// padded so that 90 sorts under 1500 rather than over it, and a blank always
    /// sorts last — the gaps belong at the end, not scattered through, because the
    /// point of sorting by a column here is usually to fill it in.
    static func sortValue(_ thing: Item, key: String, library: Library) -> String {
        if key == "name" { return normName(thing.name) }
        if key.hasPrefix("list:") {
            let listId = String(key.dropFirst(5))
            let on = library.memberships.contains { $0.itemId == thing.id && $0.templateId == listId }
            return on ? "0" : "1"
        }
        guard let column = (intrinsic + perListColumns).first(where: { $0.id == key }) else { return normName(thing.name) }
        switch column.kind {
        case .number(let path):
            return thing[keyPath: path] > 0 ? String(format: "%012.2f", thing[keyPath: path]) : "~"
        case .words(let path), .choice(let path, _):
            let text = normName(thing[keyPath: path])
            return text.isEmpty ? "~" : text
        case .flag(let path):
            return thing[keyPath: path] ? "0" : "1"
        case .onList, .perList:
            return ""
        }
    }

    /// His Settings lists and which things are on which list, worked out ONCE per
    /// redraw and handed to every cell.
    ///
    /// 🪤 Each cell used to ask the library itself: a screenful is twenty rows, so
    /// five dropdown columns meant a hundred walks of his Settings rows per frame,
    /// and a tick column meant twenty rescans of all 538 memberships. One test went
    /// from 21 seconds to 151. Working it out once costs nothing.
    struct Answers2: Equatable {
        var places: [String] = []
        var containers: [String] = []
        var owners: [String] = []
        var people: [String] = []
        var conditions: [String] = []
        /// "itemId|listId" for every membership there is.
        var onLists: Set<String> = []
        /// Every membership a thing has, so a per-list answer knows whether there is
        /// exactly one of it and which list it belongs to.
        var byThing: [String: [Membership]] = [:]
        /// A list's own sections, by list id.
        var sectionsOf: [String: [TemplateSection]] = [:]
        /// A list's name, for saying which one a per-list answer belongs to.
        var listNamed: [String: String] = [:]

        init() {}
        init(_ library: Library) {
            places = library.storagePlaces()
            containers = containerNames(library.templates)
            owners = library.owners()
            people = library.people().map(\.name)
            conditions = library.conditions().map(\.label)
            onLists = Set(library.memberships.map { "\($0.itemId)|\($0.templateId)" })
            byThing = Dictionary(grouping: library.memberships, by: \.itemId)
            for list in library.templates {
                sectionsOf[list.id] = list.sections
                listNamed[list.id] = list.name
            }
        }

        func list(_ which: Answers) -> [String] {
            switch which {
            case .places: return places
            case .containers: return containers
            case .owners: return owners
            case .people: return people
            case .conditions: return conditions
            }
        }
    }
}

/// One cell: shows the field and changes it where it stands.
struct Cell: View {
    let thing: Item
    let n: Int
    let column: TableColumns.Column
    let answers: TableColumns.Answers2
    @EnvironmentObject var model: LibraryModel
    @State private var typed = ""
    @FocusState private var writing: Bool

    private var id: String { "table-\(n)-\(column.id)" }

    var body: some View {
        Group {
            switch column.kind {
            case .number(let path): box(text: thing[keyPath: path] > 0 ? String(Int(thing[keyPath: path].rounded())) : "",
                                        blank: thing[keyPath: path] <= 0) { commitNumber($0, path) }
            case .words(let path): box(text: thing[keyPath: path], blank: false) { commitWords($0, path) }
            case .choice(let path, let which): choice(path, which)
            case .flag(let path): tick(thing[keyPath: path]) { on in
                    model.change { _ = $0.updateThing(id: thing.id) { it in it[keyPath: path] = on } }
                }
            case .onList(let listId): tick(onList(listId)) { on in
                    model.change { _ = $0.setOnTemplate(itemId: thing.id, templateId: listId, on: on) }
                }
            case .perList(let which): perList(which)
            }
        }
        .frame(width: column.width, height: TableColumns.rowHeight)
        .overlay(alignment: .trailing) { Theme.line.frame(width: 1) }
    }

    // A box he types in. It takes the change when he presses Return or leaves it.
    private func box(text: String, blank: Bool, commit: @escaping (String) -> Void) -> some View {
        TextField("", text: $typed)
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(blank && !writing ? AppSection.care.color.opacity(0.10) : Color.clear)
            .focused($writing)
            .onSubmit { commit(typed) }
            .onChange(of: writing) { _, nowWriting in if !nowWriting { commit(typed) } }
            .onAppear { typed = text }
            .onChange(of: text) { _, fresh in if !writing { typed = fresh } }
            .accessibilityIdentifier(id)
    }

    private func choice(_ path: WritableKeyPath<Item, String>, _ which: TableColumns.Answers) -> some View {
        let now = jsTrim(thing[keyPath: path])
        return Menu {
            ForEach(answers.list(which), id: \.self) { answer in
                Button(answer) {
                    model.change { _ = $0.updateThing(id: thing.id) { it in it[keyPath: path] = answer } }
                }
            }
            Divider()
            Button("Leave blank") {
                model.change { _ = $0.updateThing(id: thing.id) { it in it[keyPath: path] = "" } }
            }
        } label: {
            Text(now.isEmpty ? "—" : now)
                .font(.system(size: 13, weight: now.isEmpty ? .bold : .medium))
                .foregroundStyle(now.isEmpty ? AppSection.care.color : Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.75)
                .padding(.horizontal, 7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(now.isEmpty ? AppSection.care.color.opacity(0.10) : Color.clear)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .accessibilityIdentifier(id)
        .accessibilityValue(now)
    }

    private func tick(_ on: Bool, _ set: @escaping (Bool) -> Void) -> some View {
        Button { set(!on) } label: {
            // Filled = on, the same as the box that ticks a row. No mark inside it:
            // the colour is the message.
            RoundedRectangle(cornerRadius: 5)
                .fill(on ? AppSection.care.color : Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 5)
                    .stroke(on ? AppSection.care.color : Theme.line, lineWidth: 1))
                .frame(width: 20, height: 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// An answer that belongs to the thing's place on a list. With exactly one
    /// membership it is edited here; with several there is no single answer, so it
    /// says how many lists and points at the thing itself — the same rule the web
    /// app follows, and for the same reason.
    @ViewBuilder
    private func perList(_ which: TableColumns.PerList) -> some View {
        let mine = answers.byThing[thing.id] ?? []
        if mine.count == 1, let only = mine.first {
            switch which {
            case .qty:
                box(text: only.qty, blank: jsTrim(only.qty).isEmpty) { typed in
                    let clean = jsTrim(typed)
                    model.change { _ = $0.updateMembership(memId: only.id) { $0.qty = clean } }
                }
            case .section:
                let sections = answers.sectionsOf[only.templateId] ?? []
                let now = sections.first { $0.id == only.section }?.name ?? ""
                Menu {
                    ForEach(sections, id: \.id) { section in
                        Button(section.name) {
                            model.change { _ = $0.updateMembership(memId: only.id) { $0.section = section.id } }
                        }
                    }
                    Divider()
                    Button("No section") {
                        model.change { _ = $0.updateMembership(memId: only.id) { $0.section = "" } }
                    }
                } label: {
                    Text(now.isEmpty ? (sections.isEmpty ? "—" : "Where?") : now)
                        .font(.system(size: 13, weight: now.isEmpty ? .bold : .medium))
                        .foregroundStyle(now.isEmpty ? (sections.isEmpty ? Theme.muted : AppSection.care.color) : Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .padding(.horizontal, 7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .accessibilityIdentifier(id)
                .accessibilityValue(now)
            }
        } else {
            Text(mine.isEmpty ? "—" : "\(mine.count) lists")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .accessibilityIdentifier(id)
                .accessibilityValue(mine.isEmpty ? "" : "\(mine.count) lists")
                .help(mine.isEmpty ? "On no list" : "Different on each list — open the thing to set it")
        }
    }

    private func onList(_ listId: String) -> Bool {
        answers.onLists.contains("\(thing.id)|\(listId)")
    }

    private func commitNumber(_ text: String, _ path: WritableKeyPath<Item, Double>) {
        let clean = jsTrim(text).replacingOccurrences(of: ",", with: ".")
        if clean.isEmpty {
            model.change { _ = $0.updateThing(id: thing.id) { it in it[keyPath: path] = 0 } }
            return
        }
        guard let value = Double(clean), value >= 0 else { return }
        model.change { _ = $0.updateThing(id: thing.id) { it in it[keyPath: path] = value } }
    }

    private func commitWords(_ text: String, _ path: WritableKeyPath<Item, String>) {
        let clean = jsTrim(text)
        guard clean != jsTrim(thing[keyPath: path]) else { return }
        model.change { _ = $0.updateThing(id: thing.id) { it in it[keyPath: path] = clean } }
    }
}

/// Which columns he wants, and in which order.
struct ColumnPicker: View {
    @Binding var chosen: String
    let library: Library
    @Environment(\.dismiss) private var dismiss

    private var ids: [String] { chosen.isEmpty ? TableColumns.startingColumns : chosen.split(separator: ",").map(String.init) }

    var body: some View {
        let all = TableColumns.all(library)
        let shown = ids
        VStack(spacing: 0) {
            HStack {
                Text("Columns").font(.system(size: 20, weight: .heavy)).foregroundStyle(AppSection.care.color)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("columns-done")
            }
            .padding(16)

            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 0) {
                    Text("SHOWING, IN THIS ORDER")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.muted).kerning(0.6)
                        .padding(.top, 4).padding(.bottom, 6)
                    ForEach(Array(shown.enumerated()), id: \.element) { n, id in
                        if let column = all.first(where: { $0.id == id }) {
                            HStack(spacing: 10) {
                                Text(column.title)
                                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                                Spacer()
                                Button { move(n, by: -1) } label: { arrow("M18 15l-6-6-6 6") }
                                    .buttonStyle(.plain).focusEffectDisabled().disabled(n == 0)
                                    .accessibilityIdentifier("columns-\(column.id)-up")
                                Button { move(n, by: 1) } label: { arrow("M6 9l6 6 6-6") }
                                    .buttonStyle(.plain).focusEffectDisabled().disabled(n == shown.count - 1)
                                    .accessibilityIdentifier("columns-\(column.id)-down")
                                Button { hide(id) } label: {
                                    Text("Hide").font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(AppSection.actions.color)
                                }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .accessibilityIdentifier("columns-\(column.id)-hide")
                            }
                            .frame(minHeight: 44)
                            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        }
                    }

                    Text("NOT SHOWING")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.muted).kerning(0.6)
                        .padding(.top, 18).padding(.bottom, 6)
                    ForEach(all.filter { !shown.contains($0.id) }) { column in
                        Button { show(column.id) } label: {
                            HStack {
                                Text(column.title)
                                    .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.muted)
                                Spacer()
                                Text("Show").font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(AppSection.care.color)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        .accessibilityIdentifier("columns-\(column.id)-show")
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("columns-detail")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 540)
        #endif
    }

    private func arrow(_ path: String) -> some View {
        SVGPath.path(path)
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: 22, height: 22).foregroundStyle(Theme.muted)
    }

    private func move(_ n: Int, by step: Int) {
        var order = ids
        let to = n + step
        guard order.indices.contains(n), order.indices.contains(to) else { return }
        order.swapAt(n, to)
        chosen = order.joined(separator: ",")
    }

    private func hide(_ id: String) {
        var order = ids
        order.removeAll { $0 == id }
        // An empty list would mean "he has chosen nothing" and bring the starting
        // columns back, so the last column stays.
        guard !order.isEmpty else { return }
        chosen = order.joined(separator: ",")
    }

    private func show(_ id: String) {
        var order = ids
        guard !order.contains(id) else { return }
        order.append(id)
        chosen = order.joined(separator: ",")
    }
}
