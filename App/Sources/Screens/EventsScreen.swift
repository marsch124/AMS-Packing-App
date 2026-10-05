import SwiftUI
import PackingCore
import PackingLibrary

/// The Events tab: his trips in the piles they belong to — what is happening now,
/// what is coming, what has been — each saying where it is in its life without
/// making him read numbers.
struct EventsScreen: View {
    @State private var searching = false
    /// Trips he has already reviewed start folded away.
    @State private var showReviewed = false
    @EnvironmentObject var model: LibraryModel
    @State private var openId: String?
    /// Set by the Actions chip; the tab bar owns which tab shows.
    var goToActions: () -> Void = {}

    private static let piles: [(Library.TripWhen, String)] =
        // "Been" was not a good word (his test G.1) — he offered "done".
        [(.now, "Now"), (.comingUp, "Coming up"), (.been, "Done")]

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
                    WorldMapDoor().environmentObject(model)
                    SearchButton { searching = true }
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
                        .accessibilityLabel("\(toDos) to do, open the To do tab")
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
                    // A trip he has been on AND reviewed is finished with. It stays —
                    // nothing is hidden for good — but it folds away, so the trips
                    // that still need him are not pushed down the screen by history.
                    let mine = cards.filter { $0.when == pile && !($0.state == .reviewed && pile == .been) }
                    let done = cards.filter { $0.when == pile && $0.state == .reviewed && pile == .been }
                    // NOW is always there, empty or not, so the three piles read as one
                    // idea — and it is in colour: it is what matters today (his test G.1).
                    if !mine.isEmpty || !done.isEmpty || (pile == .now && !cards.isEmpty) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            SectionTitle(title: title, tint: pile == .now ? AppSection.events.color : Theme.ink,
                                         id: "events-pile-\(pile.rawValue)")
                            Text("\(mine.count + done.count)")
                                .font(.system(size: 18, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.muted)
                                .accessibilityIdentifier("events-pile-\(pile.rawValue)-count")
                        }
                    }
                    if pile == .now && mine.isEmpty && !cards.isEmpty {
                        Text("No trip under way today.")
                            .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(AppSection.events.color.opacity(0.6), style: StrokeStyle(lineWidth: 1.4, dash: [5, 4])))
                            .accessibilityIdentifier("events-now-empty")
                    }
                    if !mine.isEmpty {
                        ForEach(mine, id: \.id) { card in
                            Button { openId = card.id } label: { TripRow(card: card) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("trip-row-\(cards.firstIndex { $0.id == card.id } ?? 0)")
                        }
                    }
                    if !done.isEmpty {
                        Button { showReviewed.toggle() } label: {
                            // A big arrow in a circle (his test G.2: the fold mark was "very,
                            // very, very small").
                            HStack(spacing: 10) {
                                SVGPath.path("M9 6l6 6-6 6")
                                    .stroke(style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                                    .frame(width: 22, height: 22)
                                    .rotationEffect(.degrees(showReviewed ? 90 : 0))
                                    .foregroundStyle(AppSection.events.color)
                                    .frame(width: 38, height: 38)
                                    .background(Circle().fill(AppSection.events.color.opacity(0.14)))
                                Text("Reviewed").font(.system(size: 17, weight: .heavy)).foregroundStyle(Theme.ink)
                                Text("\(done.count)")
                                    .font(.system(size: 17, weight: .heavy).monospacedDigit())
                                    .foregroundStyle(Theme.muted)
                                Spacer()
                            }
                            .padding(.top, 6).frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("events-reviewed")
                        .accessibilityAddTraits(showReviewed ? .isSelected : [])
                        if showReviewed {
                            ForEach(done, id: \.id) { card in
                                Button { openId = card.id } label: { TripRow(card: card) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("trip-row-\(cards.firstIndex { $0.id == card.id } ?? 0)")
                            }
                        }
                    }
                }
                if !cards.isEmpty {
                    TravelYearBand(year: model.library.travelYear(today: Today.local))
                    // All his trips, ever, and where they went — his G.3 (2026-09-28):
                    // "a strip underneath that would be all trips, totally. Under that,
                    // a world map with small indications where the trips have been."
                    AllTimeBand(totals: model.library.travelAllTime()).environmentObject(model)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $searching) { SearchScreen().environmentObject(model) }
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
/// along the bottom whose colour IS the state.
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
            .frame(height: 8)
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

    /// "2026-10-03" → "3 Oct 2026", the same words on every device — as the date grid,
    /// Check before you go and the map write a day (the spec pass, 5 Oct 2026: this one
    /// alone followed the device, "Oct 3, 2026" on an American-set phone).
    static func day(_ ymd: String) -> String { TripChecksCard.day(ymd) }
}


/// His travelling year, under the trips: a column per month for the last twelve,
/// and what those trips came to. It answers a question the list cannot — when does
/// he actually go away — and every mark in it is one of his own numbers.
struct TravelYearBand: View {
    let year: Library.TravelYear

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Your year", id: "events-year-heading")
                .padding(.top, 6)

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(year.byMonth.enumerated()), id: \.offset) { n, count in
                    VStack(spacing: 5) {
                        Text(count > 0 ? "\(count)" : " ")
                            .font(.system(size: 10, weight: .heavy).monospacedDigit())
                            .foregroundStyle(AppSection.events.color)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(count > 0 ? AppSection.events.color : Theme.line)
                            .frame(height: max(4, 54 * (year.most > 0 ? Double(count) / Double(year.most) : 0)))
                        Text(TravelYearBand.month(n < year.months.count ? year.months[n] : ""))
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.muted)
                    }
                }
            }
            .frame(height: 84)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("events-year")
            .accessibilityLabel("Trips month by month over the last year")

            HStack(spacing: 8) {
                figure("\(year.trips)", year.trips == 1 ? "trip" : "trips", "year-trips")
                figure("\(year.nights)", year.nights == 1 ? "night away" : "nights away", "year-nights")
                figure("\(year.packed)", "things packed", "year-packed")
            }
        }
    }

    private func figure(_ number: String, _ word: String, _ id: String) -> some View {
        VStack(spacing: 2) {
            Text(number).font(.system(size: 20, weight: .heavy).monospacedDigit())
                .foregroundStyle(AppSection.events.color)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(word).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    /// "Sep" from "2026-09-01" — his own dates, no calendar arithmetic needed.
    static func month(_ firstOfMonth: String) -> String {
        guard firstOfMonth.count >= 7, let m = Int(firstOfMonth.dropFirst(5).prefix(2)), (1...12).contains(m) else { return "" }
        return ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][m - 1]
    }
}

/// All his trips, ever — four figures — and under them the map of where they went.
/// A tap on the map opens the whole map with its cards.
struct AllTimeBand: View {
    let totals: Library.TravelTotals
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "All your trips", id: "events-alltime-heading")
            HStack(spacing: 8) {
                figure("\(totals.trips)", totals.trips == 1 ? "trip" : "trips", "alltime-trips")
                figure("\(totals.nights)", totals.nights == 1 ? "night away" : "nights away", "alltime-nights")
                figure("\(totals.places)", totals.places == 1 ? "place" : "places", "alltime-places")
                figure("\(totals.packed)", "things packed", "alltime-packed")
            }
            MiniWorldMap().environmentObject(model)
        }
    }

    private func figure(_ number: String, _ word: String, _ id: String) -> some View {
        VStack(spacing: 2) {
            Text(number).font(.system(size: 20, weight: .heavy).monospacedDigit())
                .foregroundStyle(AppSection.events.color)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(word).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}

