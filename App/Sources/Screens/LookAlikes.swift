import SwiftUI
import PackingCore
import PackingLibrary

/// Look-alikes (0.125 — his pick of 12 Nov 2026: "spots two entries that are probably the same thing and
/// offers to merge them"). Opened from the Inventory tab's "Look-alikes" row. One card per pair: both things
/// side by side (photo, name, brand and model, room, the lists they are on) with "Keep this one" under each,
/// and "Not the same" under the pair. Keep asks first — a merge cannot be undone on the other device — then
/// the other thing is folded into the kept one (`Library.mergeThing`). The model's undo (⌘Z) still works here.
struct LookAlikesPage: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var asking: Ask?

    struct Ask: Identifiable { let keep: Item; let from: Item; var id: String { keep.id + from.id } }
    private var tint: Color { AppSection.inventory.color }

    var body: some View {
        let pairs = model.library.lookAlikePairs()
        VStack(spacing: 0) {
            HStack {
                BackArrow(title: "Inventory", tint: tint, id: "lookalike-back") { dismiss() }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold))
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("lookalike-done")
            }
            .padding(.horizontal, 16).padding(.top, 8)
            Text("Look-alikes").font(.system(.largeTitle, weight: .bold)).foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                .accessibilityIdentifier("lookalike-title")
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(pairs.isEmpty ? "Nothing looks alike any more."
                                       : "Same thing twice? Keep one \u{2014} the other is folded into it.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("lookalike-left")
                    ForEach(Array(pairs.enumerated()), id: \.element.a.id) { n, pair in
                        card(n, pair)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .confirmationDialog(asking.map { "Merge \($0.from.name) into \($0.keep.name)?" } ?? "",
                            isPresented: Binding(get: { asking != nil }, set: { if !$0 { asking = nil } }),
                            titleVisibility: .visible, presenting: asking) { ask in
            Button("Merge", role: .destructive) {
                model.change(named: "Merge \(ask.from.name)") { _ = $0.mergeThing(keep: ask.keep.id, from: ask.from.id) }
                asking = nil
            }
            .accessibilityIdentifier("lookalike-merge-yes")
            Button("Cancel", role: .cancel) { asking = nil }
        } message: { ask in
            Text("\(ask.keep.name) keeps its name and details and takes what it lacks from the other: photos, papers, lists, kits and trips. \(ask.from.name) is then gone.")
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 520)
        #endif
    }

    private func card(_ n: Int, _ pair: LookAlikePair) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pair.why).font(.system(.footnote, weight: .semibold)).foregroundStyle(tint)
            HStack(alignment: .top, spacing: 10) {
                side(n, 0, pair.a, other: pair.b)
                Divider()
                side(n, 1, pair.b, other: pair.a)
            }
            Button {
                model.change(named: "Not the same") { _ = $0.markNotSame(pair.a.id, pair.b.id) }
            } label: {
                Text("Not the same").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).frame(minHeight: Metrics.compact).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("lookalike-notsame-\(n)")
        }
        .padding(12)
        .bCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lookalike-group-\(n)")
    }

    private func side(_ n: Int, _ m: Int, _ it: Item, other: Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                ThingPhotoThumb(item: it, id: "lookalike-photo-\(n)-\(m)") {}
                Text(it.name).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(2)
                    .accessibilityIdentifier("lookalike-name-\(n)-\(m)")
            }
            let facts = [jsTrim(it.manufacturer + " " + it.model), it.storage,
                         it.serial.isEmpty ? "" : "Serial \(it.serial)"].filter { !$0.isEmpty }
            if !facts.isEmpty {
                Text(facts.joined(separator: " \u{00B7} ")).font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
            let lists = model.library.listsOf(itemId: it.id)
            Text(lists.isEmpty ? "On no list" : lists.joined(separator: ", "))
                .font(.system(.footnote)).foregroundStyle(Theme.muted).lineLimit(2)
            Button { asking = Ask(keep: it, from: other) } label: {
                Text("Keep this one").font(.system(.subheadline, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                    .background(Capsule().fill(tint)).contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("lookalike-merge-\(n)-\(m)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
