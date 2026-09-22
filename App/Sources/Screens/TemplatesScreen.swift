import SwiftUI
import PackingCore
import PackingLibrary

/// The Templates tab: every template, grouped the way he organises his life —
/// always packed, by transport, then his activity groups.
struct TemplatesScreen: View {
    @EnvironmentObject var model: LibraryModel
    @State private var open: PackList?

    struct Shelf: Identifiable { let id: String; let title: String; let lists: [PackList] }

    static func shelves(_ all: [PackList]) -> [Shelf] {
        var out: [Shelf] = []
        func add(_ id: String, _ title: String, _ lists: [PackList]) { if !lists.isEmpty { out.append(Shelf(id: id, title: title, lists: lists)) } }
        add("base", "Always packed", all.filter { $0.role == "base" })
        add("transport", "By transport", all.filter { $0.role == "transport" })
        for g in GROUPS { add(g.id, g.label, orderActivities(g.id, all.filter { $0.role.isEmpty && $0.group == g.id })) }
        add("other", "Other lists", all.filter { $0.role.isEmpty && $0.group.isEmpty })
        add("containers", "Containers", all.filter { $0.role == CONTAINER_ROLE })
        return out
    }

    var body: some View {
        let shelves = TemplatesScreen.shelves(model.library.resolvedTemplates())
        let flat = shelves.flatMap(\.lists)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(shelves) { shelf in
                    Text(shelf.title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 14)
                    ForEach(shelf.lists, id: \.id) { list in
                        Button { open = list } label: { TemplateRow(list: list) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("template-row-\(flat.firstIndex { $0.id == list.id } ?? 0)")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .sheet(item: $open) { list in TemplateDetail(listId: list.id).environmentObject(model) }
    }
}

extension PackList: Identifiable {}

struct TemplateRow: View {
    let list: PackList

    var body: some View {
        HStack(spacing: 12) {
            Cover(list: list, size: 40)
            Text(list.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text("\(list.items.count)")
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

/// A template's face: ITS colour, and the cover HE chose if he chose one —
/// otherwise its initial. (His covers are his data; the app adds no art of its own.)
struct Cover: View {
    let list: PackList
    var size: Double = 40

    var body: some View {
        let glyph = list.emoji.isEmpty ? String(list.name.prefix(1)).uppercased() : list.emoji
        Text(glyph)
            .font(.system(size: size * (list.emoji.isEmpty ? 0.46 : 0.52), weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.28).fill(Color(hexString: listColor(list))))
            .accessibilityHidden(true)
    }
}

/// One template: its things under his "When" headings; a thing can be added
/// at the foot and taken off with ✕ (the thing itself survives).
struct TemplateDetail: View {
    let listId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""

    var body: some View {
        let list = model.library.resolvedTemplate(id: listId) ?? newList()
        let groups = entriesByPhase(list.items).filter { !$0.entries.isEmpty }
        let index: [String: Int] = Dictionary(list.items.enumerated().map { ($1.memId ?? "\($0)", $0) }, uniquingKeysWith: { a, _ in a })
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Cover(list: list, size: 36)
                Text(list.name).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppSection.templates.color)
                    .accessibilityIdentifier("template-detail-done")
            }
            .padding(16)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        Text(group.phase.label)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(Color(hexString: group.phase.color))
                            .padding(.top, 12)
                        ForEach(group.entries, id: \.memId) { item in
                            let n = index[item.memId ?? ""] ?? 0
                            HStack(spacing: 4) {
                                HStack {
                                    Text(item.name).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                                    Spacer(minLength: 8)
                                    Text(item.container).font(.system(size: 15)).foregroundStyle(Theme.muted).lineLimit(1)
                                }
                                .padding(.vertical, 6)
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("template-item-\(n)")
                                Button {
                                    if let mid = item.memId { model.change { _ = $0.removeFromTemplate(templateId: listId, memId: mid) } }
                                } label: {
                                    SVGPath.path("M6 6L18 18M18 6L6 18")
                                        .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                        .frame(width: 22, height: 22).foregroundStyle(Theme.muted)
                                        .frame(width: 40, height: 36).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .accessibilityIdentifier("template-item-\(n)-remove")
                                .accessibilityLabel("Take \(item.name) off this list")
                            }
                            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            HStack(spacing: 8) {
                TextField("Add a thing to this list", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("template-add-name")
                Button { add() } label: {
                    Text("Add").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(jsTrim(newName).isEmpty ? Theme.line : AppSection.templates.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .disabled(jsTrim(newName).isEmpty)
                .accessibilityIdentifier("template-add")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("template-detail")
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 600)
        #endif
    }

    private func add() {
        let name = newName
        guard !jsTrim(name).isEmpty else { return }
        model.change { _ = $0.addToTemplate(templateId: listId, name: name) }
        newName = ""
    }
}

extension Color {
    /// "#7c5cd6" → a colour. Anything unreadable → slate.
    init(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        self.init(hex: UInt32(s.prefix(6), radix: 16) ?? 0x64748b)
    }
}
