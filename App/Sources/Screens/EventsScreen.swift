import SwiftUI
import PackingCore
import PackingLibrary

/// The Events tab: his trips, the nearest upcoming first, then the past ones.
struct EventsScreen: View {
    @EnvironmentObject var model: LibraryModel
    @State private var openId: String?

    var body: some View {
        let trips = sortEventsForList(model.library.trips, Today.local)
        KeyboardAwayScroll {
            LazyVStack(alignment: .leading, spacing: 8) {
                if trips.isEmpty {
                    Text("No trips yet.")
                        .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.muted)
                        .padding(.top, 24)
                }
                ForEach(Array(trips.enumerated()), id: \.element.id) { n, trip in
                    Button { openId = trip.id } label: { TripRow(trip: trip) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("trip-row-\(n)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .sheet(item: Binding(get: { openId.map { Opened(id: $0) } }, set: { openId = $0?.id })) { opened in
            TripScreen(tripId: opened.id).environmentObject(model)
        }
    }

    private struct Opened: Identifiable { let id: String }
}

struct TripRow: View {
    let trip: TripEvent

    var body: some View {
        let p = progress(trip.entries)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(trip.name.isEmpty ? "Untitled event" : trip.name)
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text(TripRow.when(trip))
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("\(p.done)/\(p.total)")
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundStyle(p.total > 0 && p.done == p.total ? AppSection.events.color : Theme.muted)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 60)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .contentShape(Rectangle())
    }

    /// "3–5 Oct · in 12 days", or what there is of it.
    static func when(_ trip: TripEvent) -> String {
        var parts: [String] = []
        if !trip.startDate.isEmpty {
            let end = tripEndDate(trip)
            parts.append(end.isEmpty || end == trip.startDate ? day(trip.startDate) : "\(day(trip.startDate)) – \(day(end))")
            parts.append(countdownLabel(daysUntil(trip.startDate, Today.local)))
        }
        if !trip.destination.isEmpty { parts.append(trip.destination) }
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
