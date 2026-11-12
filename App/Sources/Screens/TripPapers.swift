import SwiftUI
import PackingCore
import PackingLibrary

/// A trip's Papers (0.125 — his pick of 12 Nov 2026: "booking confirmations, boarding passes and hotel
/// details on the trip page, and they work without internet"). Under Before you go, in the trips' blue.
/// Empty: one "Add trip papers" row. With papers: a one-line summary that opens to the list (kind chips,
/// Remove asks first) and the ways to add one — a photo, a photo from the library, a PDF. A paper is kept
/// the moment it is added, as a thing's papers are; every one is on the device, so it opens offline.
struct TripPapersCard: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @State private var open = false
    @State private var large: Int?
    @State private var removing: String?
    @State private var pdfShown: Int?

    private var tint: Color { AppSection.events.color }
    private static let side: CGFloat = 48

    var body: some View {
        let papers = model.library.tripPapersShown(tripId: tripId)
        Group {
            if papers.isEmpty && !open {
                Button { withAnimation(.easeInOut(duration: 0.2)) { open = true } } label: {
                    HStack(spacing: 6) {
                        SVGPath.path("M12 5v14M5 12h14")
                            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round)).onGrid(Metrics.glyph * 0.8)
                        Text("Add trip papers").font(.system(.body, weight: .semibold))
                        Text("boarding pass, hotel").font(.system(.subheadline)).foregroundStyle(Theme.muted)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .bCard()
                .accessibilityIdentifier("trip-papers-open")
            } else {
                card(papers)
            }
        }
        .onChange(of: papers.map(\.paper.id)) { _, ids in if let r = removing, !ids.contains(r) { removing = nil } }
    }

    private func card(_ papers: [(paper: TripPaper, photo: PhotoRecord?)]) -> some View {
        let full = !model.library.takesTripPaper(tripId: tripId)
        let trip = model.library.trip(tripId)
        return VStack(alignment: .leading, spacing: 8) {
            // The heading row folds the card to its one line (open while he is adding).
            Button { withAnimation(.easeInOut(duration: 0.2)) { open.toggle() } } label: {
                HStack(spacing: 8) {
                    Text("Papers").font(.system(.headline)).foregroundStyle(tint)
                    if !open {
                        Text(Library.tripPapersLine(trip)).font(.system(.subheadline)).foregroundStyle(Theme.muted)
                            .lineLimit(1)
                            .accessibilityIdentifier("trip-papers-line")
                    }
                    Spacer(minLength: 0)
                    SVGPath.path("M9 6l6 6-6 6")
                        .stroke(tint, style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
                        .onGrid(Metrics.glyph * 0.7)
                        .rotationEffect(.degrees(open ? 90 : 0))
                }
                .frame(minHeight: Metrics.compact).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("trip-papers-fold")
            .accessibilityAddTraits(open ? .isSelected : [])
            if !open {
                // Folded: the pictures in a row, one tap from opening big.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(papers.enumerated()), id: \.element.paper.id) { n, p in
                            thumb(n, p.paper, p.photo)
                        }
                    }
                }
            } else {
                ForEach(Array(papers.enumerated()), id: \.element.paper.id) { n, p in
                    row(n, p.paper, p.photo)
                }
                if let removing, let n = papers.firstIndex(where: { $0.paper.id == removing }) {
                    askToRemove(paperId: removing, n: n)
                }
                if full {
                    Text("Twenty papers \u{2014} remove one to add another")
                        .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("trip-papers-full")
                } else {
                    PhotoTakers(id: "trip-paper-take", testTitle: "Photo of a paper",
                                take: papers.isEmpty ? "Take a photo" : "Take another",
                                choose: papers.isEmpty ? "Choose a photo" : "Choose another", tint: tint) { jpeg in
                        guard let jpeg else { return }
                        model.change { _ = $0.addTripPaper(tripId: tripId, jpeg: jpeg) }
                    }
                    AddPDFButton(tint: tint) { pdf, name in
                        model.change { _ = $0.addTripPaperPDF(tripId: tripId, pdf: pdf, name: name) }
                    }
                }
            }
        }
        .padding(12)
        .bCard()
        .takesDroppedPhoto(room: !full, tint: tint) { jpeg in
            guard let jpeg else { return }
            model.change { _ = $0.addTripPaper(tripId: tripId, jpeg: jpeg) }
        }
        .sheet(item: Binding(get: { large.map(Shown.init) }, set: { large = $0?.start })) { shown in
            let shots = papers.filter { !Library.isPDF($0.photo) }
                .compactMap { p in p.photo.flatMap { JPEG.image(dataURL: $0.data) }.map { ($0, p.paper.kind.label) } }
            BigPhoto(images: shots.map(\.0), captions: shots.map(\.1), start: min(shown.start, max(0, shots.count - 1)), tint: tint)
        }
        .sheet(item: Binding(get: { pdfShown.map(Shown.init) }, set: { pdfShown = $0?.start })) { shown in
            if shown.start < papers.count, let bytes = Library.pdfBytes(papers[shown.start].photo) {
                PDFPage(title: papers[shown.start].paper.title, data: bytes)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trip-papers")
    }

    /// Open paper n: a PDF full page, a photo big (the big view holds the photos only).
    private func show(_ n: Int, _ photo: PhotoRecord?) {
        if Library.isPDF(photo) { pdfShown = n; return }
        large = model.library.tripPapersShown(tripId: tripId).prefix(n).filter { !Library.isPDF($0.photo) }.count
    }

    private func picture(_ photo: PhotoRecord?) -> some View {
        Group {
            if Library.isPDF(photo) {
                PDFTile(side: TripPapersCard.side)
            } else if let photo, let small = PhotoThumbs.image(photo, side: TripPapersCard.side) {
                Image(decorative: small, scale: 1).resizable().scaledToFill()
            } else {
                Theme.line.opacity(0.3)               // still on its way from the other device
            }
        }
        .frame(width: TripPapersCard.side, height: TripPapersCard.side)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
    }

    private func thumb(_ n: Int, _ paper: TripPaper, _ photo: PhotoRecord?) -> some View {
        Button { show(n, photo) } label: {
            VStack(spacing: 2) {
                picture(photo)
                Text(paper.kind.label).font(.system(.caption2)).foregroundStyle(Theme.muted).lineLimit(1)
                    .frame(maxWidth: TripPapersCard.side + 16)
            }
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("trip-paper-thumb-\(n)")
        .accessibilityLabel("\(paper.title), paper \(n + 1)")
    }

    private func row(_ n: Int, _ paper: TripPaper, _ photo: PhotoRecord?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button { show(n, photo) } label: { picture(photo) }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("trip-paper-\(n)")
                .accessibilityLabel("\(paper.title), paper \(n + 1)")
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(paper.title)
                        .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                        .accessibilityIdentifier("trip-paper-\(n)-label")
                    Text(ThingPapersCard.day(paper.at)).font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    Spacer(minLength: 0)
                    Button("Remove") { removing = paper.id }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("trip-paper-remove-\(n)")
                }
                kinds(n, paper)
            }
        }
    }

    private func kinds(_ n: Int, _ paper: TripPaper) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TripPaperKind.allCases, id: \.self) { kind in
                    let on = kind == paper.kind
                    Button {
                        guard !on else { return }
                        model.change { _ = $0.setTripPaperKind(tripId: tripId, paperId: paper.id, kind: kind) }
                    } label: {
                        Text(kind.label).font(.system(.subheadline, weight: .semibold)).lineLimit(1)
                            .foregroundStyle(on ? .white : tint)
                            .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                            .background(Capsule().fill(on ? tint : tint.opacity(0.10)))
                            .overlay(Capsule().stroke(tint, lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("trip-paper-\(n)-kind-\(kind.rawValue)")
                }
            }
        }
    }

    /// Remove asks first: a paper is gone from every device once removed.
    private func askToRemove(paperId: String, n: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Remove paper \(n + 1)?")
                .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                .accessibilityIdentifier("trip-paper-remove-ask")
            HStack {
                Button("Keep it") { removing = nil }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                    .frame(minHeight: Metrics.compact).contentShape(Rectangle())
                    .accessibilityIdentifier("trip-paper-remove-no")
                Spacer()
                Button {
                    removing = nil
                    model.change { _ = $0.removeTripPaper(tripId: tripId, paperId: paperId) }
                } label: {
                    Text("Remove paper").font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                        .background(Capsule().fill(AppSection.actions.color))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("trip-paper-remove-yes")
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.actions.color, lineWidth: 1))
    }

    private struct Shown: Identifiable { let start: Int; var id: Int { start } }
}
