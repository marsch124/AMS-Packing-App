import SwiftUI
import PackingCore
import PackingLibrary

/// Pack to go home — his pre-trip idea 13 (2 Oct 2026). What went, and what was
/// bought on site, bag by bag, with ticks of its own; Used up takes a thing off. The
/// photos of the packed bags sit at the top, to repack from.
struct WayHomeScreen: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var large: CGImage?

    var body: some View {
        let lines = model.library.homeLines(tripId: tripId)
        let p = model.library.homeProgress(tripId: tripId)
        let bags = lines.reduce(into: [String]()) { if !$0.contains($1.container) { $0.append($1.container) } }
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Way home").font(.system(size: 24, weight: .heavy)).foregroundStyle(AppSection.events.color)
                    Text("\(p.done)/\(p.total)")
                        .font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("wayhome-progress")
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold))
                    .accessibilityIdentifier("wayhome-done")
            }
            .padding(16)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    photos(bags)
                    if lines.isEmpty {
                        Text("Nothing to bring home yet: tick what you pack on the way out, and add what you buy on site with Bought on site.")
                            .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("wayhome-empty")
                    }
                    ForEach(bags, id: \.self) { bag in
                        Text(bag.isEmpty || bag == "Other" ? "Not in a bag" : bag)
                            .font(.system(size: 15, weight: .heavy)).foregroundStyle(AppSection.events.color)
                            .padding(.top, 12)
                        ForEach(lines.filter { $0.container == bag }, id: \.id) { line in
                            let n = lines.firstIndex { $0.id == line.id } ?? 0
                            row(line, n)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: Binding(get: { large.map(Large.init) }, set: { large = $0?.image })) { BigPhoto(image: $0.image) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wayhome-screen")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }

    private struct Large: Identifiable { let image: CGImage; var id: ObjectIdentifier { ObjectIdentifier(image) } }

    /// The packed bags' photos, to repack from.
    @ViewBuilder private func photos(_ bags: [String]) -> some View {
        let shots = bags.compactMap { bag in
            model.library.bagPhoto(tripId: tripId, bag: bag).flatMap { JPEG.image(dataURL: $0.data) }.map { (bag, $0) }
        }
        if !shots.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(shots.enumerated()), id: \.offset) { n, shot in
                        Button { large = shot.1 } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(decorative: shot.1, scale: 1).resizable().scaledToFill()
                                    .frame(width: 120, height: 90).clipShape(RoundedRectangle(cornerRadius: 10))
                                Text(shot.0).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                            .frame(width: 120)
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("wayhome-photo-\(n)")
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func row(_ line: Item, _ n: Int) -> some View {
        let used = Library.isUsedUp(line)
        let packed = Library.isPackedHome(line)
        let tint = AppSection.events.color
        return HStack(spacing: 4) {
            Button {
                guard !used else { return }
                model.change { _ = $0.setPackedHome(!packed, tripId: tripId, entryId: line.id) }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(used ? Theme.line : tint, lineWidth: 2).frame(width: 26, height: 26)
                        if packed {
                            Circle().fill(tint).frame(width: 26, height: 26)
                            Tick().stroke(Color.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                                .frame(width: 26, height: 26)
                        }
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(line.name)
                            .font(.system(size: 17, weight: packed ? .regular : .medium))
                            .foregroundStyle(used || packed ? Theme.muted : Theme.ink)
                            .strikethrough(used, pattern: .solid, color: Theme.muted)
                            .lineLimit(2)
                        if used {
                            Text("Used up").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.muted)
                        } else if Library.isBoughtOnSite(line) {
                            Text("Bought on site").font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
                        }
                    }
                    Spacer(minLength: 8)
                }
                .padding(.vertical, 9).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wayhome-line-\(n)")
            .accessibilityAddTraits(packed ? .isSelected : [])
            Button(used ? "Back" : "Used up") {
                model.change { _ = $0.setUsedUp(!used, tripId: tripId, entryId: line.id) }
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
            .padding(.horizontal, 8).frame(minHeight: 40)
            .accessibilityIdentifier("wayhome-line-\(n)-usedup")
        }
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }
}
