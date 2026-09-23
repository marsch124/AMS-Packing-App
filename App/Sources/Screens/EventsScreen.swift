import SwiftUI
import PackingCore
import PackingLibrary

/// The Events tab: his trips in the piles they belong to — what is happening now,
/// what is coming, what has been — each saying where it is in its life without
/// making him read numbers.
struct EventsScreen: View {
    @EnvironmentObject var model: LibraryModel
    @State private var openId: String?
    /// Set by the Actions chip; the tab bar owns which tab shows.
    var goToActions: () -> Void = {}

    private static let piles: [(Library.TripWhen, String)] =
        [(.now, "Now"), (.comingUp, "Coming up"), (.been, "Been")]

    var body: some View {
        let cards = model.library.tripCards(today: Today.local)
        let toDos = model.library.openToDoCount()
        KeyboardAwayScroll {
            LazyVStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trips").font(.system(size: 28, weight: .heavy)).foregroundStyle(AppSection.events.color)
                            .accessibilityIdentifier("events-heading")
                        Text(EventsScreen.summary(cards))
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("events-summary")
                    }
                    Spacer()
                    if toDos > 0 {
                        Button(action: goToActions) {
                            HStack(spacing: 6) {
                                Text("\(toDos)").font(.system(size: 16, weight: .heavy).monospacedDigit())
                                Text(toDos == 1 ? "to do" : "to do").font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(minHeight: 34)
                            .background(Capsule().fill(AppSection.actions.color))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("events-todos")
                        .accessibilityLabel("\(toDos) to do, open the Actions tab")
                    }
                }
                .padding(.top, 14).padding(.bottom, 4)

                if cards.isEmpty {
                    Text("No trips yet. Build one on the Home tab.")
                        .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.muted)
                        .padding(.top, 24)
                        .accessibilityIdentifier("events-none")
                }

                ForEach(EventsScreen.piles, id: \.0) { pile, title in
                    let mine = cards.filter { $0.when == pile }
                    if !mine.isEmpty {
                        Text(title).font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted)
                            .padding(.top, 10)
                            .accessibilityIdentifier("events-pile-\(pile.rawValue)")
                        ForEach(mine, id: \.id) { card in
                            Button { openId = card.id } label: { TripRow(card: card) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("trip-row-\(cards.firstIndex { $0.id == card.id } ?? 0)")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .sheet(item: Binding(get: { openId.map { Opened(id: $0) } }, set: { openId = $0?.id })) { opened in
            TripScreen(tripId: opened.id).environmentObject(model)
        }
    }

    /// "4 trips · 1 being packed" — the state of things in one line.
    static func summary(_ cards: [Library.TripCard]) -> String {
        guard !cards.isEmpty else { return "Nothing planned" }
        var parts = ["\(cards.count) trip\(cards.count == 1 ? "" : "s")"]
        let packing = cards.filter { $0.state == .packing }.count
        let ready = cards.filter { $0.state == .packed }.count
        if packing > 0 { parts.append("\(packing) being packed") }
        if ready > 0 { parts.append("\(ready) ready to go") }
        return parts.joined(separator: " · ")
    }

    private struct Opened: Identifiable { let id: String }
}

/// One trip: its name, when and where, how far the packing has got — and a bar
/// along the bottom whose colour IS the state, so it reads with his glasses off.
struct TripRow: View {
    let card: Library.TripCard

    private var tint: Color {
        switch card.state {
        case .planned: return Theme.muted
        case .packing: return AppSection.care.color        // amber: started, not finished
        case .packed: return AppSection.events.color       // green: nothing left to decide
        case .reviewed: return Theme.muted
        }
    }

    private var badge: String {
        switch card.state {
        case .planned: return "Planned"
        case .packing: return "Packing"
        case .packed: return "Ready"
        case .reviewed: return "Reviewed"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.name.isEmpty ? "Untitled event" : card.name)
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text(TripRow.when(card))
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    // Narrow on purpose: the trip's own words matter more.
                    Text(badge)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(card.state == .planned || card.state == .reviewed ? Theme.muted : .white)
                        .padding(.horizontal, 10).frame(minHeight: 22)
                        .background(Capsule().fill(card.state == .planned || card.state == .reviewed
                                                   ? Theme.line : tint))
                        .accessibilityIdentifier("trip-state")
                    Text(card.aside > 0 ? "\(card.done)/\(card.total) · \(card.aside) set aside"
                                        : "\(card.done)/\(card.total)")
                        .font(.system(size: 15, weight: .bold).monospacedDigit())
                        .foregroundStyle(card.state == .packed ? AppSection.events.color : Theme.muted)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            // How far it has got, as a line rather than a number.
            GeometryReader { space in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.line)
                    Rectangle().fill(tint).frame(width: max(0, min(1, card.part)) * space.size.width)
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
    }

    /// "3–5 Oct · in 12 days · Göteborg · 4–11°C", or what there is of it.
    static func when(_ card: Library.TripCard) -> String {
        var parts: [String] = []
        if !card.startDate.isEmpty {
            let end = card.endDate.isEmpty ? card.startDate : card.endDate
            parts.append(end == card.startDate ? day(card.startDate) : "\(day(card.startDate)) – \(day(end))")
            parts.append(countdownLabel(daysUntil(card.startDate, Today.local)))
        }
        if !card.place.isEmpty { parts.append(card.place) }
        if !card.weather.isEmpty { parts.append(card.weather) }
        return parts.isEmpty ? "No dates" : parts.joined(separator: " · ")
    }

    /// "2026-10-03" → "3 Oct 2026" in his locale's words.
    static func day(_ ymd: String) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: ymd) else { return ymd }
        let out = DateFormatter(); out.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return out.string(from: d)
    }
}
