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
    enum Answers { case places, bags, owners, people, conditions }

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
        Column(id: "container", title: "Packed in", width: 140, kind: .choice(\Item.container, .bags)),
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
        Column(id: "listQty", title: "How many", width: 92, kind: .perList(.qty), group: "On this template"),
        Column(id: "listSection", title: "Section", width: 140, kind: .perList(.section), group: "On this template"),
    ]

    /// One tick column per list of his, so a thing joins or leaves a list here.
    /// Taking it off a list drops only that list's own answers for it — the thing,
    /// its weight, its care and its photos stay. Never his bag list: a tick there
    /// made the thing a bag, and an untick dropped a bag without asking where its
    /// things go (the spec pass, 5 Oct 2026) — a bag is made and deleted on Your bags.
    static func listColumns(_ library: Library) -> [Column] {
        library.templatesForThings().map { list in
            Column(id: "list:\(list.id)", title: library.shownName(list), width: 100,
                   kind: .onList(list.id), group: "On these templates")
        }
    }

    static func all(_ library: Library) -> [Column] { intrinsic + perListColumns + listColumns(library) }

    /// What he sees before he has chosen anything: the gaps he actually has.
    static let startingColumns = ["weight", "storage", "container", "ownedBy", "packer", "condition", "listQty"]

    /// His chosen columns' ids, in his order. Ids that are no longer columns (a
    /// template he deleted) fall away HERE, before anything counts them: they kept
    /// invisible places in the Columns order, so an arrow could move a ghost and every
    /// real column could be hidden (the spec pass, 5 Oct 2026). None left = the start.
    static func ids(_ stored: String, library: Library) -> [String] {
        let known = Set(all(library).map(\.id))
        let mine = stored.split(separator: ",").map(String.init).filter { known.contains($0) }
        return mine.isEmpty ? startingColumns : mine
    }

    /// His chosen columns, in his order.
    static func chosen(_ stored: String, library: Library) -> [Column] {
        let byId = Dictionary(all(library).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids(stored, library: library).compactMap { byId[$0] }
    }

    /// His Settings lists and which things are on which list, worked out ONCE per
    /// redraw and handed to every cell.
    ///
    /// 🪤 Each cell used to ask the library itself: a screenful is twenty rows, so
    /// five dropdown columns meant a hundred walks of his Settings rows per frame,
    /// and a tick column meant twenty rescans of all 538 memberships. One test went
    /// from 21 seconds to 151. Working it out once costs nothing.
    struct Answers2: Equatable {
        /// One answer in a menu: what is STORED, and what he reads. The same for
        /// every list but the conditions, whose id is stored and label read.
        struct Choice: Equatable, Hashable { let value: String; let label: String }

        var places: [String] = []
        var bags: [String] = []
        var owners: [String] = []
        var people: [String] = []
        var conditions: [Choice] = []
        /// A stored condition → its label: by id, and by label (compared as names
        /// are) for a thing still holding one the old way.
        var conditionShown: [String: String] = [:]
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
            // His own bags too — `containerNames(library.templates)` saw only the
            // shells and offered the built-in names alone (the spec pass, 5 Oct 2026).
            bags = library.bagNames()
            // Every owner he uses, as the thing's page offers them — the Settings list
            // alone can be empty while things already name owners (same pass).
            owners = library.ownerChoices()
            people = library.people().map(\.name)
            // The condition's ID is stored, its label is read: the menu stored the
            // label, which To buy, the thing's page and Your choices never recognised.
            for c in library.conditions() {
                conditions.append(Choice(value: c.id, label: c.label))
                conditionShown[c.id] = c.label
                if conditionShown[normName(c.label)] == nil { conditionShown[normName(c.label)] = c.label }
            }
            onLists = Set(library.memberships.map { "\($0.itemId)|\($0.templateId)" })
            byThing = Dictionary(grouping: library.memberships, by: \.itemId)
            for list in library.templates {
                sectionsOf[list.id] = list.sections
                listNamed[list.id] = library.shownName(list)
            }
        }

        func list(_ which: Answers) -> [Choice] {
            switch which {
            case .places: return places.map { Choice(value: $0, label: $0) }
            case .bags: return bags.map { Choice(value: $0, label: $0) }
            case .owners: return owners.map { Choice(value: $0, label: $0) }
            case .people: return people.map { Choice(value: $0, label: $0) }
            case .conditions: return conditions
            }
        }

        /// What a cell shows for what is stored.
        func shown(_ which: Answers, _ stored: String) -> String {
            guard which == .conditions, !stored.isEmpty else { return stored }
            return conditionShown[stored] ?? conditionShown[normName(stored)] ?? stored
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
            case .number(let path): box(text: amountText(thing[keyPath: path]),
                                        blank: thing[keyPath: path] <= 0, number: true) { commitNumber($0, path) }
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
    // A number box that holds no number turns red: what he typed is not taken, and
    // the colour says so (it used to be dropped without a word).
    private func box(text: String, blank: Bool, number: Bool = false, commit: @escaping (String) -> Void) -> some View {
        let wrong = number && readAmount(typed) == nil
        return TextField("", text: $typed)
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(wrong ? AppSection.actions.color.opacity(0.18)
                        : blank && !writing ? AppSection.care.color.opacity(0.10) : Color.clear)
            .focused($writing)
            .onSubmit { commit(typed) }
            .onChange(of: writing) { _, nowWriting in if !nowWriting { commit(typed) } }
            .onAppear { typed = text }
            .onChange(of: text) { _, fresh in if !writing { typed = fresh } }
            .accessibilityIdentifier(id)
    }

    private func choice(_ path: WritableKeyPath<Item, String>, _ which: TableColumns.Answers) -> some View {
        let now = answers.shown(which, jsTrim(thing[keyPath: path]))
        return Menu {
            ForEach(answers.list(which), id: \.self) { answer in
                Button(answer.label) {
                    model.change { _ = $0.updateThing(id: thing.id) { it in it[keyPath: path] = answer.value } }
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
            Text(mine.isEmpty ? "—" : "\(mine.count) templates")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .accessibilityIdentifier(id)
                .accessibilityValue(mine.isEmpty ? "" : "\(mine.count) templates")
                .help(mine.isEmpty ? "On no template" : "Different on each template — open the thing to set it")
        }
    }

    private func onList(_ listId: String) -> Bool {
        answers.onLists.contains("\(thing.id)|\(listId)")
    }

    /// Only a real change is written: leaving the box used to write its rounded
    /// text back, so tapping into 88.7 g and out again made it 89.
    private func commitNumber(_ text: String, _ path: WritableKeyPath<Item, Double>) {
        guard let value = readAmount(text), value != thing[keyPath: path] else { return }
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

    private var ids: [String] { TableColumns.ids(chosen, library: library) }

    var body: some View {
        let all = TableColumns.all(library)
        let shown = ids
        VStack(spacing: 0) {
            HStack {
                Text("Columns").font(.system(size: 20, weight: .heavy)).foregroundStyle(AppSection.care.color)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.care.color, filled: true)).focusEffectDisabled()
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
                            HStack(spacing: 4) {
                                Text(column.title)
                                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                                Spacer()
                                Button { move(n, by: -1) } label: { arrow("M18 15l-6-6-6 6") }
                                    .buttonStyle(.plain).focusEffectDisabled().disabled(n == 0)
                                    .accessibilityIdentifier("columns-\(TableKeys.safe(column.id, library))-up")
                                Button { move(n, by: 1) } label: { arrow("M6 9l6 6 6-6") }
                                    .buttonStyle(.plain).focusEffectDisabled().disabled(n == shown.count - 1)
                                    .accessibilityIdentifier("columns-\(TableKeys.safe(column.id, library))-down")
                                Button { hide(id) } label: {
                                    Text("Hide").font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(AppSection.actions.color)
                                        .frame(minWidth: 52, minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .accessibilityIdentifier("columns-\(TableKeys.safe(column.id, library))-hide")
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
                        .accessibilityIdentifier("columns-\(TableKeys.safe(column.id, library))-show")
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

    /// The arrow drawn at 22, pressed anywhere in a 44 × 44 square around it — his
    /// ask (4 Oct 2026): "These arrows are rather difficult to hit."
    private func arrow(_ path: String) -> some View {
        SVGPath.path(path)
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: 22, height: 22).foregroundStyle(Theme.muted)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
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
