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
        .sheet(item: $open) { list in TemplateDetail(list: list) }
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

/// One template, read-only for now: its things in the order he packs them.
struct TemplateDetail: View {
    let list: PackList
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let groups = entriesByPhase(list.items).filter { !$0.entries.isEmpty }
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
                            HStack {
                                Text(item.name).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                                Spacer(minLength: 8)
                                Text(item.container).font(.system(size: 15)).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                            .padding(.vertical, 6)
                            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("template-detail")
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 600)
        #endif
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
