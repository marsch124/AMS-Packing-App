import SwiftUI
import PackingCore
import PackingLibrary

/// The Inventory tab (0.117 — his words of 11 Nov 2026: "I cannot find an entry point for the new items
/// perspective… Can we make an inventory page?"; his pick: a tab of its own). What he owns, what it cost
/// and is worth today, room by room; the warranties that end soon; and the room walk. Each room opens
/// Your things with only that room's things.
struct InventoryScreen: View {
    @EnvironmentObject var model: LibraryModel
    @State private var opening: Opening?
    @State private var walking = false

    struct Opening: Identifiable { let id = UUID(); let room: String?; let search: String }
    private var tint: Color { AppSection.inventory.color }

    var body: some View {
        let today = Today.local
        let rooms = model.library.inventoryRooms()
        let totals = Library.totals(model.library.ownThings(), today: today)
        let ending = model.library.warrantiesEndingSoon(today: today)
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Inventory").font(.system(.largeTitle, weight: .bold)).foregroundStyle(tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .accessibilityIdentifier("inventory-title")
                totalsCard(totals)
                BPartTitle(title: "Rooms", count: rooms.count, tint: tint)
                VStack(spacing: 0) {
                    ForEach(Array(rooms.enumerated()), id: \.offset) { n, r in
                        Button { opening = Opening(room: r.room, search: "") } label: {
                            BRow(title: r.room.isEmpty ? "No room" : r.room, count: "\(r.count)")
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("inventory-room-\(n)")
                        Divider().padding(.leading, 12)
                    }
                    Button { opening = Opening(room: nil, search: "") } label: {
                        BRow(title: "All things", count: "\(totals.things)")
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("inventory-all")
                }
                .bCard()
                if !ending.isEmpty {
                    BPartTitle(title: "Warranty ends soon", count: ending.count, tint: tint)
                    VStack(spacing: 0) {
                        ForEach(Array(ending.enumerated()), id: \.element.id) { n, it in
                            Button { opening = Opening(room: nil, search: it.name) } label: {
                                BRow(title: it.name, detail: Library.timeLeft(until: it.warranty, today: today)
                                     + " \u{00B7} " + Library.dayWords(it.warranty))
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("inventory-warranty-\(n)")
                            if n < ending.count - 1 { Divider().padding(.leading, 12) }
                        }
                    }
                    .bCard()
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 140)
        }
        .overlay(alignment: .bottomTrailing) {
            BFloatingButton(title: "Room walk", tint: tint, id: "inventory-walk-open") { walking = true }
                .padding(.bottom, 64)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $opening) { o in
            ThingsScreen(searching: o.search, room: o.room).environmentObject(model)
        }
        .sheet(isPresented: $walking) { RoomWalkScreen().environmentObject(model) }
    }

    private func totalsCard(_ t: InventoryTotals) -> some View {
        let kr: (Double) -> String = { v in
            let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = "\u{00A0}"; f.maximumFractionDigits = 0
            return (f.string(from: NSNumber(value: v)) ?? "\(Int(v))") + " kr"
        }
        return HStack(spacing: 0) {
            stat("\(t.things)", t.things == 1 ? "thing" : "things")
            Divider()
            stat(kr(t.paid), "paid")
            Divider()
            stat(kr(t.today), "worth today")
        }
        .padding(.vertical, 10)
        .bCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("inventory-totals")
    }

    private func stat(_ value: String, _ words: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.headline).monospacedDigit()).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(words).font(.footnote).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
