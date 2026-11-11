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
    /// Warranty and care reminders on this device (0.120), off until he turns them on.
    @AppStorage(InventoryReminders.onKey) private var remind = false
    @State private var refused = false
    /// Under the tests: what the insurance PDF wrote ("PDF ready — 3 pages").
    @State private var pdfSaid = ""
    #if os(iOS)
    @State private var sharing: SharedFile?
    struct SharedFile: Identifiable { let id = UUID(); let url: URL }
    #else
    @State private var anchor = ShareAnchorBox()
    #endif

    struct Opening: Identifiable { let id = UUID(); let room: String?; let search: String; var noReceipt = false }
    private var tint: Color { AppSection.inventory.color }

    var body: some View {
        let today = Today.local
        let rooms = model.library.inventoryRooms()
        let totals = Library.totals(model.library.ownThings(), today: today)
        let ending = model.library.warrantiesEndingSoon(today: today)
        let noReceipt = model.library.noReceiptRows().count
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
                insurance(noReceipt: noReceipt)
            }
            .padding(.horizontal, 16).padding(.bottom, 140)
        }
        .overlay(alignment: .bottomTrailing) {
            BFloatingButton(title: "Room walk", tint: tint, id: "inventory-walk-open") { walking = true }
                .padding(.bottom, 64)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $opening) { o in
            ThingsScreen(searching: o.search, room: o.room, noReceipt: o.noReceipt).environmentObject(model)
        }
        #if os(iOS)
        .sheet(item: $sharing) { f in ShareSheet(url: f.url) }
        #endif
        .sheet(isPresented: $walking) { RoomWalkScreen().environmentObject(model) }
    }

    // MARK: Papers, reminders and the insurance list (0.120)

    private func insurance(noReceipt: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BPartTitle(title: "Papers and reminders", count: nil, tint: tint)
            VStack(spacing: 0) {
                Button { opening = Opening(room: nil, search: "", noReceipt: true) } label: {
                    BRow(title: "No receipt yet", count: "\(noReceipt)")
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("inventory-noreceipt")
                Divider().padding(.leading, 12)
                Toggle(isOn: Binding(get: { remind }, set: { want in
                    Task {
                        let ok = want ? await PackingReminders.shared.askToShow() : false
                        remind = want && ok
                        refused = want && !ok
                        await InventoryReminders.shared.reschedule(model.library)
                    }
                })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Remind me at 9:00").font(.system(.body)).foregroundStyle(Theme.ink)
                        Text("30 days before a warranty ends, and when care is due \u{2014} on this device")
                            .font(.system(.footnote)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(tint)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .accessibilityIdentifier("inventory-remind")
                if refused {
                    Text("This device does not allow the app to remind you. Allow it in the device's Settings, under Notifications.")
                        .font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12).padding(.bottom, 6)
                        .accessibilityIdentifier("inventory-remind-refused")
                }
            }
            .bCard()
            Button { sharePDF() } label: {
                Text("Insurance list (PDF)").font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 12).fill(tint))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            #if os(macOS)
            .background(ShareAnchor(box: anchor))
            #endif
            .padding(.top, 4)
            .accessibilityIdentifier("inventory-pdf")
            if !pdfSaid.isEmpty {
                Text(pdfSaid).font(.system(.footnote, weight: .semibold)).foregroundStyle(tint)
                    .accessibilityIdentifier("inventory-pdf-said")
            }
        }
    }

    /// Draw the PDF, then hand it to the share sheet (iPhone) or the sharing menu (Mac). Under the UI
    /// tests no share sheet opens: the page says what was written instead.
    private func sharePDF() {
        guard let made = InsurancePDF.write(model.library) else { pdfSaid = "The PDF could not be made."; return }
        if AMSPackingApp.testing {
            pdfSaid = "PDF ready \u{2014} \(made.pages) page\(made.pages == 1 ? "" : "s")"
            return
        }
        pdfSaid = ""
        #if os(iOS)
        sharing = SharedFile(url: made.url)
        #else
        if let view = anchor.view {
            NSSharingServicePicker(items: [made.url]).show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
        #endif
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
