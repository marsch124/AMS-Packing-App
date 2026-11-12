import SwiftUI
import PackingCore
import PackingLibrary

/// The insurance list as a PDF (0.120 — his picks of 12 Nov 2026: room by room with totals, each thing
/// in full with its photo, the receipts at the end). A4, always light, black on white — what the model
/// says (`Library.insuranceList`) laid out on pages and drawn with SwiftUI's ImageRenderer, as the Lost
/// bag PDF is. No other library.
@MainActor
enum InsurancePDF {
    nonisolated static let size = CGSize(width: 595, height: 842)
    nonisolated static let margin: CGFloat = 40
    nonisolated static let photo: CGFloat = 64
    /// Room for blocks on a page: the page less its margins and the foot line.
    nonisolated static let room: CGFloat = 842 - 40 * 2 - 22

    /// One block on a page.
    enum Block {
        case head(InsuranceList)
        case roomHead(InsuranceRoom, more: Bool)
        case thing(InsuranceLine)
        case receipts([(image: CGImage, caption: String)])

        /// Its height on the page, near enough to fill pages.
        var height: CGFloat {
            switch self {
            case .head: return 86
            case .roomHead: return 34
            case .thing(let l):
                let rows = CGFloat((l.facts.count + 1) / 2)
                return max(InsurancePDF.photo, 18 + rows * 14) + 12
            case .receipts: return InsurancePDF.room
            }
        }
    }

    /// The blocks laid on pages: a room's heading never alone at a page's foot; a room going on over a
    /// page says so again at the top of the next.
    static func pages(_ list: InsuranceList, receipts: [(image: CGImage, caption: String)]) -> [[Block]] {
        var pages: [[Block]] = []
        var page: [Block] = [.head(list)]
        var used = Block.head(list).height
        func put(_ b: Block) {
            if used + b.height > room, !page.isEmpty { pages.append(page); page = []; used = 0 }
            page.append(b); used += b.height
        }
        for r in list.rooms {
            // The heading and its first thing together.
            if let first = r.lines.first, used + Block.roomHead(r, more: false).height + Block.thing(first).height > room {
                pages.append(page); page = []; used = 0
            }
            put(.roomHead(r, more: false))
            for l in r.lines {
                if used + Block.thing(l).height > room {
                    pages.append(page); page = [.roomHead(r, more: true)]; used = Block.roomHead(r, more: true).height
                }
                put(.thing(l))
            }
        }
        if !page.isEmpty { pages.append(page) }
        // The receipts, four to a page.
        var k = 0
        while k < receipts.count {
            pages.append([.receipts(Array(receipts[k..<min(k + 4, receipts.count)]))])
            k += 4
        }
        return pages
    }

    /// Write the PDF into the temporary folder: its file and how many pages it has.
    static func write(_ library: Library) -> (url: URL, pages: Int)? {
        let list = library.insuranceList(today: Today.local)
        var images: [String: CGImage] = [:]
        var receipts: [(image: CGImage, caption: String)] = []
        for r in list.rooms {
            for l in r.lines {
                if !l.photoId.isEmpty, let p = library.photos.first(where: { $0.id == l.photoId }),
                   let img = PhotoThumbs.image(p, side: photo) { images[l.photoId] = img }
                let mine = l.receiptIds.compactMap { id in library.photos.first { $0.id == id }.flatMap { PhotoThumbs.image($0, side: 320) } }
                for (n, img) in mine.enumerated() {
                    receipts.append((img, mine.count > 1 ? "\(l.name) \u{00B7} receipt \(n + 1) of \(mine.count)" : "\(l.name) \u{00B7} receipt"))
                }
            }
        }
        let laid = pages(list, receipts: receipts)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Insurance list", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("Insurance list \(Today.local).pdf")
        try? FileManager.default.removeItem(at: url)
        var box = CGRect(origin: .zero, size: size)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }
        for (n, blocks) in laid.enumerated() {
            let view = InsurancePDFPage(blocks: blocks, images: images, number: n + 1, of: laid.count, madeOn: list.madeOn)
            let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
            renderer.proposedSize = ProposedViewSize(size)
            renderer.render { _, draw in
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
            }
        }
        pdf.closePDF()
        return FileManager.default.fileExists(atPath: url.path) ? (url, laid.count) : nil
    }
}

/// One A4 page of the insurance list.
private struct InsurancePDFPage: View {
    let blocks: [InsurancePDF.Block]
    let images: [String: CGImage]
    let number: Int
    let of: Int
    let madeOn: String
    private let ink = Color(red: 0.09, green: 0.14, blue: 0.16)
    private let grey = Color(red: 0.37, green: 0.44, blue: 0.47)
    private let rule = Color(red: 0.85, green: 0.88, blue: 0.89)
    private let teal = Color(red: 0.06, green: 0.55, blue: 0.55)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in block(b) }
            Spacer(minLength: 0)
            HStack {
                Text("Insurance list \u{00B7} \(madeOn) \u{00B7} made with AMS Packing")
                Spacer()
                Text("Page \(number) of \(of)")
            }
            .font(.system(size: 8)).foregroundStyle(grey)
        }
        .padding(InsurancePDF.margin)
        .frame(width: InsurancePDF.size.width, height: InsurancePDF.size.height, alignment: .topLeading)
        .background(Color.white)
    }

    @ViewBuilder private func block(_ b: InsurancePDF.Block) -> some View {
        switch b {
        case .head(let list):
            VStack(alignment: .leading, spacing: 6) {
                Text("Insurance list").font(.system(size: 24, weight: .bold)).foregroundStyle(ink)
                Text("Everything in use, room by room \u{00B7} \(madeOn)").font(.system(size: 11, weight: .semibold)).foregroundStyle(grey)
                Text(totalsWords(list.totals)).font(.system(size: 12, weight: .semibold)).foregroundStyle(teal)
                rule.frame(height: 1).padding(.top, 4)
            }
            .frame(height: b.height, alignment: .topLeading)
        case .roomHead(let r, let more):
            HStack(alignment: .firstTextBaseline) {
                Text((r.room.isEmpty ? "No room" : r.room) + (more ? " (continued)" : ""))
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(teal)
                Spacer()
                Text(totalsWords(r.totals)).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(grey)
            }
            .padding(.top, 10)
            .frame(height: b.height, alignment: .topLeading)
        case .thing(let l):
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if let img = images[l.photoId] {
                        Image(decorative: img, scale: 1).resizable().scaledToFill()
                    } else {
                        rule.opacity(0.5)
                    }
                }
                .frame(width: InsurancePDF.photo, height: InsurancePDF.photo)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.name).font(.system(size: 12, weight: .bold)).foregroundStyle(ink).lineLimit(1)
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                              alignment: .leading, spacing: 2) {
                        ForEach(Array(l.facts.enumerated()), id: \.offset) { _, f in
                            (Text(f.label + "  ").font(.system(size: 8.5, weight: .semibold)).foregroundStyle(grey)
                             + Text(f.value).font(.system(size: 10)).foregroundStyle(ink))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.vertical, 6)
            .frame(height: b.height, alignment: .topLeading)
            .overlay(alignment: .bottom) { rule.frame(height: 0.5) }
        case .receipts(let shots):
            let w = (InsurancePDF.size.width - InsurancePDF.margin * 2 - 16) / 2
            let h = (InsurancePDF.room - 40 - 16) / 2 - 16
            VStack(alignment: .leading, spacing: 12) {
                Text("Receipts").font(.system(size: 18, weight: .bold)).foregroundStyle(ink)
                LazyVGrid(columns: [GridItem(.fixed(w), spacing: 16, alignment: .top), GridItem(.fixed(w), spacing: 16, alignment: .top)],
                          alignment: .leading, spacing: 16) {
                    ForEach(Array(shots.enumerated()), id: \.offset) { _, s in
                        VStack(alignment: .leading, spacing: 4) {
                            Image(decorative: s.image, scale: 1).resizable().scaledToFit()
                                .frame(maxWidth: w, maxHeight: h, alignment: .topLeading)
                            Text(s.caption).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(grey).lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private func totalsWords(_ t: InventoryTotals) -> String {
        var s = "\(t.things) thing\(t.things == 1 ? "" : "s") \u{00B7} paid \(Library.moneyWords(t.paid)) \u{00B7} worth today \(Library.moneyWords(t.today))"
        if t.otherCurrency > 0 { s += " \u{00B7} \(t.otherCurrency) in an unknown currency not counted" }
        if t.converted > 0 { s += " \u{00B7} \(t.converted) counted at the rates of \(isYMD(CurrencyRates.current.day) ? Library.dayWords(CurrencyRates.current.day) : "today")" }
        return s
    }
}
