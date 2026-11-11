import SwiftUI
import PackingCore
import PackingLibrary

/// A thing's Papers (0.119 — inventory step "Papers", his answers of 11 Nov 2026): receipts, delivery
/// notes, warranty cards and manuals, photographed with the iPhone as he goes, plus the manual's web
/// address. Right under Details, in Care's orange, folded to one "Add papers" button while the thing
/// has none. A paper is kept the moment it is taken (as the thing's photos are); the manual link is
/// written into the page's draft and kept on Save, as every other field.
struct ThingPapersCard: View {
    /// nil while ⌘N is still making the thing: papers need a thing to sit on, the link does not.
    let thingId: String?
    @Binding var draft: Item
    @EnvironmentObject var model: LibraryModel
    @Environment(\.openURL) private var openURL
    @State private var open = false
    @State private var large: Int?
    @State private var removing: String?

    private var tint: Color { AppSection.care.color }
    private static let side: CGFloat = 56

    var body: some View {
        let papers = thingId.map { model.library.thingPapers(id: $0) } ?? []
        VStack(alignment: .leading, spacing: 6) {
            HeadingBand(title: "Papers", id: "thing-heading-papers")
            if open || !papers.isEmpty || !Library.manualLink(draft).isEmpty {
                card(papers)
            } else {
                Button { withAnimation(.easeInOut(duration: 0.2)) { open = true } } label: {
                    HStack(spacing: 6) {
                        SVGPath.path("M12 5v14M5 12h14")
                            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round)).onGrid(Metrics.glyph * 0.8)
                        Text("Add papers").font(.system(.body, weight: .semibold))
                        Text("receipt, manual, warranty card").font(.system(.subheadline)).foregroundStyle(Theme.muted)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .bCard()
                .accessibilityIdentifier("thing-papers-open")
            }
        }
        .onChange(of: papers.map(\.paper.id)) { _, ids in if let r = removing, !ids.contains(r) { removing = nil } }
    }

    private func card(_ papers: [(paper: Paper, photo: PhotoRecord?)]) -> some View {
        let full = thingId.map { !model.library.takesPaper(id: $0) } ?? false
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(papers.enumerated()), id: \.element.paper.id) { n, p in
                row(n, p.paper, p.photo)
            }
            if let removing, let n = papers.firstIndex(where: { $0.paper.id == removing }) {
                askToRemove(paperId: removing, n: n)
            }
            if let id = thingId {
                if full {
                    Text("Twelve papers \u{2014} remove one to add another")
                        .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("thing-papers-full")
                } else {
                    PhotoTakers(id: "thing-paper-take", testTitle: "Photo of a paper",
                                take: papers.isEmpty ? "Take a photo" : "Take another",
                                choose: papers.isEmpty ? "Choose a photo" : "Choose another", tint: tint) { jpeg in
                        guard let jpeg else { return }
                        model.change { _ = $0.addPaper(id: id, jpeg: jpeg) }
                    }
                }
            } else {
                Text("Save the thing first to add papers")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
            }
            manualLink
        }
        .padding(12)
        .bCard()
        .takesDroppedPhoto(room: thingId != nil && !full, tint: tint) { jpeg in
            guard let jpeg, let id = thingId else { return }
            model.change { _ = $0.addPaper(id: id, jpeg: jpeg) }
        }
        .sheet(item: Binding(get: { large.map(Shown.init) }, set: { large = $0?.start })) { shown in
            let shots = papers.compactMap { p in p.photo.flatMap { JPEG.image(dataURL: $0.data) }.map { ($0, p.paper.kind.label) } }
            BigPhoto(images: shots.map(\.0), captions: shots.map(\.1), start: min(shown.start, max(0, shots.count - 1)), tint: tint)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thing-papers")
    }

    private func row(_ n: Int, _ paper: Paper, _ photo: PhotoRecord?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button { large = n } label: {
                Group {
                    if let photo, let small = PhotoThumbs.image(photo, side: ThingPapersCard.side) {
                        Image(decorative: small, scale: 1).resizable().scaledToFill()
                    } else {
                        Theme.line.opacity(0.3)               // still on its way from the other device
                    }
                }
                .frame(width: ThingPapersCard.side, height: ThingPapersCard.side)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("thing-paper-\(n)")
            .accessibilityLabel("\(paper.kind.label), paper \(n + 1)")
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(paper.kind.label).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("thing-paper-\(n)-label")
                    Text(ThingPapersCard.day(paper.at)).font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    Spacer(minLength: 0)
                    Button("Remove") { removing = paper.id }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("thing-paper-remove-\(n)")
                }
                kinds(n, paper)
            }
        }
    }

    private func kinds(_ n: Int, _ paper: Paper) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PaperKind.allCases, id: \.self) { kind in
                    let on = kind == paper.kind
                    Button {
                        guard !on, let id = thingId else { return }
                        model.change { _ = $0.setPaperKind(id: id, paperId: paper.id, kind: kind) }
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
                    .accessibilityIdentifier("thing-paper-\(n)-kind-\(kind.rawValue)")
                }
            }
        }
    }

    private var manualLink: some View {
        HStack(spacing: 8) {
            Text("Manual link").font(.system(.body)).foregroundStyle(Theme.ink)
            TextField("e.g. sony.com/manual", text: Binding(get: { Library.manualLink(draft) },
                                                            set: { Library.setManualLink(&draft, $0) }))
                .textFieldStyle(.plain).font(.system(.body))
                #if os(iOS)
                .keyboardType(.URL).textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .accessibilityIdentifier("thing-manual-link")
            if let url = Library.manualURL(draft) {
                Button { openURL(url) } label: {
                    Text("Open").font(.system(.subheadline, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                        .background(Capsule().fill(tint)).contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("thing-manual-open")
            }
        }
        .frame(minHeight: Metrics.tap)
    }

    /// Remove asks first: a paper is gone from every device once removed.
    private func askToRemove(paperId: String, n: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Remove paper \(n + 1)?")
                .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                .accessibilityIdentifier("thing-paper-remove-ask")
            HStack {
                Button("Keep it") { removing = nil }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                    .frame(minHeight: Metrics.compact).contentShape(Rectangle())
                    .accessibilityIdentifier("thing-paper-remove-no")
                Spacer()
                Button {
                    removing = nil
                    guard let id = thingId else { return }
                    model.change { _ = $0.removePaper(id: id, paperId: paperId) }
                } label: {
                    Text("Remove paper").font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                        .background(Capsule().fill(AppSection.actions.color))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("thing-paper-remove-yes")
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.actions.color, lineWidth: 1))
    }

    /// "11 Nov 2026" from the stored ISO time; "" when unreadable.
    static func day(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "" }
        return d.formatted(.dateTime.day().month(.abbreviated).year())
    }

    private struct Shown: Identifiable { let start: Int; var id: Int { start } }
}
