import SwiftUI
import PackingCore
import PackingLibrary

/// Unpack (0.126, his idea 1 of 12 Nov 2026): back home, each thing ticked back into the room it lives
/// in — by room, with its spot, "All back" per room, "Still in the bag · N". Bought on site: Give it a
/// room. Every tick is written at once (like the way home's), so the page has Done only; Escape is Done.
struct UnpackScreen: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss

    private var tint: Color { AppSection.events.color }

    var body: some View {
        let groups = model.library.unpackGroups(tripId: tripId)
        let p = model.library.unpackProgress(tripId: tripId)
        let left = p.total - p.done
        let all = groups.flatMap(\.lines)
        let number = Dictionary(all.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        let stopped = model.library.trip(tripId)?.extra[UNPACK_DONE_KEY]?.boolValue == true
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold))
                    .keyboardShortcut(.cancelAction)
                    .commandS { dismiss() }
                    .accessibilityIdentifier("unpack-done")
            }
            .frame(minHeight: Metrics.tap)
            .padding(.horizontal, 16).padding(.top, 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("Unpack").font(.system(.largeTitle, weight: .bold)).foregroundStyle(tint)
                Text(left == 0 ? "Everything is back \u{00B7} \(p.total)" : "Still in the bag \u{00B7} \(left)")
                    .font(.system(.subheadline, weight: .semibold).monospacedDigit())
                    .foregroundStyle(left == 0 ? tint : Theme.muted)
                    .accessibilityIdentifier("unpack-left")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.bottom, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if all.isEmpty {
                        Text("Nothing to unpack: nothing was ticked on the way out.")
                            .font(.system(.callout)).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("unpack-empty")
                    }
                    ForEach(Array(groups.enumerated()), id: \.element.room) { g, group in
                        heading(group, g)
                        ForEach(group.lines, id: \.id) { line in row(line, number[line.id] ?? 0) }
                    }
                    if left > 0 && !stopped {
                        // Home's quiet line goes; the ticks stay here to finish later.
                        Button {
                            model.change { $0.setUnpackDone(true, tripId: tripId) }
                        } label: {
                            Text("Stop reminding me on Home")
                                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(tint)
                                .frame(minHeight: Metrics.tap)
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .padding(.top, 14)
                        .accessibilityIdentifier("unpack-stop")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unpack-screen")
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 600)
        #endif
    }

    private func heading(_ group: Library.UnpackGroup, _ g: Int) -> some View {
        let open = group.lines.contains { !Library.isUnpacked($0) }
        return HStack(spacing: 8) {
            Text(group.room)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(group.room == UNPACK_NO_ROOM ? Theme.muted : AppSection.inventory.color)
            Text("\(group.lines.filter(Library.isUnpacked).count)/\(group.lines.count)")
                .font(.system(.footnote).monospacedDigit()).foregroundStyle(Theme.muted)
            Spacer(minLength: 8)
            if open && group.room != UNPACK_NO_ROOM {
                Button {
                    let room = group.room
                    model.change { _ = $0.setRoomUnpacked(room: room, tripId: tripId) }
                } label: {
                    Text("All back").font(.system(.footnote, weight: .semibold)).foregroundStyle(tint)
                        .padding(.horizontal, 10).frame(minHeight: Metrics.compact)
                        .overlay(Capsule().stroke(tint, lineWidth: 1.2))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("unpack-room-\(g)-all")
            }
        }
        .padding(.top, 14).padding(.bottom, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unpack-room-\(g)")
    }

    private func row(_ line: Item, _ n: Int) -> some View {
        let back = Library.isUnpacked(line)
        let spot = model.library.unpackSpot(line)
        let needsRoom = model.library.unpackRoom(line).isEmpty
        return HStack(spacing: 0) {
            Button {
                let id = line.id
                model.change { _ = $0.setUnpacked(!back, tripId: tripId, entryId: id) }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(tint, lineWidth: 2).frame(width: 26, height: 26)
                        if back {
                            Circle().fill(tint).frame(width: 26, height: 26)
                            Tick().stroke(Color.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                                .frame(width: 26, height: 26)
                        }
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(line.name).font(.system(.body))
                            .foregroundStyle(back ? Theme.muted : Theme.ink).lineLimit(2)
                        if !spot.isEmpty {
                            Text(spot).font(.system(.footnote)).foregroundStyle(Theme.muted)
                        } else if Library.isBoughtOnSite(line) {
                            Text("Bought on site").font(.system(.footnote, weight: .semibold)).foregroundStyle(tint)
                        }
                    }
                    Spacer(minLength: 4)
                }
                .padding(.vertical, 5).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("unpack-line-\(n)")
            .accessibilityAddTraits(back ? .isSelected : [])
            if needsRoom { roomMenu(line, n) }
        }
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }

    /// "Give it a room": one of his rooms; the thing (made for something bought on site) is kept there.
    private func roomMenu(_ line: Item, _ n: Int) -> some View {
        Menu {
            ForEach(model.library.roomChoices(), id: \.self) { room in
                Button(room) {
                    let id = line.id
                    model.change { _ = $0.giveRoom(room, tripId: tripId, entryId: id) }
                }
            }
        } label: {
            Text("Give it a room").font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.inventory.color)
                .padding(.horizontal, 7).frame(minHeight: Metrics.compact)
        }
        .menuStyle(.button).buttonStyle(.plain).fixedSize()
        .accessibilityIdentifier("unpack-line-\(n)-room")
    }
}
