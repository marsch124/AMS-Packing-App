import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import PackingCore
import PackingLibrary
#if os(iOS)
import VisionKit
#endif

// 0.121 — his four asks of 12 Nov 2026, in one go: the serial scanned with the camera, a thing marked
// Gone, prices in other currencies counted in the totals, and a manual kept as a PDF. Core rules are
// in Core/Sources/PackingLibrary/InventoryMore.swift.

// MARK: - 1. Serial scan (iPhone)

/// The small scan mark beside Serial: Apple's live text and barcode reader; tap what it outlines and
/// that is the serial. iPhone only (the Mac has no such camera reader) and only where the camera can.
/// Under the UI tests it fills a known serial without the camera.
struct SerialScanButton: View {
    @Binding var serial: String
    @State private var scanning = false

    static var available: Bool {
        #if os(iOS)
        if PhotoTakers.drawn { return true }
        return DataScannerViewController.isSupported
        #else
        return false
        #endif
    }

    var body: some View {
        if SerialScanButton.available {
            Button {
                if PhotoTakers.drawn { serial = Library.cleanSerial("S/N: TEST-4512 0877") } else { scanning = true }
            } label: {
                // Hand-drawn: four corners of a frame and a line across — "read what is in here".
                SVGPath.path("M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3M7 12h10")
                    .stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
                    .onGrid(Metrics.glyph).foregroundStyle(AppSection.care.color)
                    .frame(width: Metrics.lineButton, height: Metrics.tap).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityLabel("Scan the serial number")
            .accessibilityIdentifier("thing-serial-scan")
            #if os(iOS)
            .fullScreenCover(isPresented: $scanning) {
                SerialScanPage { found in
                    scanning = false
                    if let found { serial = Library.cleanSerial(found) }
                }
            }
            #endif
        }
    }
}

#if os(iOS)
/// The camera page: Cancel at the top, a hint, and the reader filling the rest.
private struct SerialScanPage: View {
    let done: (String?) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            SerialScanner(done: done).ignoresSafeArea()
            VStack(spacing: 6) {
                HStack {
                    Button("Cancel") { done(nil) }
                        .buttonStyle(BarCancelStyle(tint: .white)).focusEffectDisabled()
                        .accessibilityIdentifier("serial-scan-cancel")
                    Spacer()
                }
                Text("Tap the serial number or its barcode")
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(.black.opacity(0.55)))
            }
            .padding(.horizontal, 16).padding(.top, 8)
        }
        .background(Color.black)
    }
}

private struct SerialScanner: UIViewControllerRepresentable {
    let done: (String?) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.text(), .barcode()], qualityLevel: .accurate,
                                           recognizesMultipleItems: true, isHighFrameRateTrackingEnabled: false,
                                           isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }
    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}
    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordinator) { vc.stopScanning() }
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let done: (String?) -> Void
        init(done: @escaping (String?) -> Void) { self.done = done }
        func dataScanner(_ scanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let t): done(t.transcript)
            case .barcode(let b): done(b.payloadStringValue)
            @unknown default: break
            }
        }
    }
}
#endif

// MARK: - 2. Gone

/// On a thing's page: "Mark as gone…", or — once gone — what happened and "Back in use". Written into
/// the page's draft, kept on Save, as everything else on the page.
struct ThingGoneLine: View {
    @Binding var draft: Item
    @State private var editing = false
    private var tint: Color { AppSection.care.color }

    var body: some View {
        Group {
            if Library.isGone(draft) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Gone").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text(Library.goneLine(draft)).font(.system(.subheadline)).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("thing-gone-says")
                    }
                    Spacer(minLength: 0)
                    Button("Change") { editing = true }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(tint)
                        .accessibilityIdentifier("thing-gone-change")
                    Button { Library.setGone(&draft, nil) } label: {
                        Text("Back in use").font(.system(.subheadline, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                            .background(Capsule().fill(tint)).contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("thing-gone-undo")
                }
                .padding(.horizontal, 12).frame(minHeight: Metrics.row)
            } else {
                Button { editing = true } label: {
                    HStack(spacing: 6) {
                        Text("Mark as gone\u{2026}").font(.system(.body, weight: .semibold)).foregroundStyle(tint)
                        Text("sold, given away, broken, lost").font(.system(.subheadline)).foregroundStyle(Theme.muted)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("thing-gone-open")
            }
        }
        .bCard()
        .sheet(isPresented: $editing) {
            GonePage(start: Library.gone(draft), currency: draft.currency) { mark in
                if let mark { Library.setGone(&draft, mark) }
                editing = false
            }
        }
    }
}

/// When, how and (sold) for how much — Cancel and Save; Escape is Cancel on the Mac.
private struct GonePage: View {
    let start: GoneMark?
    let currency: String
    let done: (GoneMark?) -> Void
    @State private var day = Date()
    @State private var how: GoneHow = .sold
    @State private var soldText = ""
    @State private var cur = ""
    private var tint: Color { AppSection.care.color }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Cancel") { done(nil) }
                    .buttonStyle(BarCancelStyle(tint: tint)).focusEffectDisabled()
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("gone-cancel")
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold))
                    .commandS { save() }
                    .accessibilityIdentifier("gone-save")
            }
            Text("Gone").font(.system(.largeTitle, weight: .bold)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("When").font(.system(.body)).foregroundStyle(Theme.ink)
                    Spacer()
                    DatePicker("", selection: $day, displayedComponents: .date).labelsHidden().tint(tint)
                        .accessibilityIdentifier("gone-date")
                }
                .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                Theme.line.frame(height: 1).padding(.leading, 12)
                FlowRow(spacing: 6) {
                    ForEach(GoneHow.allCases, id: \.self) { h in
                        let on = h == how
                        Button { how = h } label: {
                            Text(h.label).font(.system(.subheadline, weight: .semibold)).lineLimit(1)
                                .foregroundStyle(on ? .white : tint)
                                .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                                .background(Capsule().fill(on ? tint : tint.opacity(0.10)))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityAddTraits(on ? .isSelected : [])
                        .accessibilityIdentifier("gone-how-\(h.rawValue)")
                    }
                }
                .padding(12)
                if how == .sold {
                    Theme.line.frame(height: 1).padding(.leading, 12)
                    HStack(spacing: 8) {
                        Text("Sold for").font(.system(.body)).foregroundStyle(Theme.ink).frame(width: 90, alignment: .leading)
                        TextField("amount", text: $soldText)
                            .textFieldStyle(.plain).font(.system(.body))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .accessibilityIdentifier("gone-sold-for")
                        TextField("SEK", text: $cur)
                            .textFieldStyle(.plain).font(.system(.body)).foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.trailing).frame(width: 48)
                            .accessibilityIdentifier("gone-currency")
                    }
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                }
            }
            .bCard()
            Text("A gone thing leaves trips, templates, totals and reminders. Its photos, papers and price are kept.")
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            if let s = start {
                day = Library.ymdDay(s.on) ?? Date(); how = s.how
                soldText = s.soldFor.map(amountText) ?? ""; cur = s.currency
            } else { cur = jsTrim(currency) }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
    }

    private func save() {
        done(GoneMark(on: Library.ymd(day), how: how, soldFor: how == .sold ? readAmount(soldText) : nil, currency: cur))
    }
}

// MARK: - 3. Other currencies

/// Today's rates: fetched once a day from the European Central Bank's published rates (frankfurter.app —
/// no account, nothing about him is sent), kept on this device; the built-in ones until the first fetch.
enum RatesWatch {
    private static let key = "ams.currencyRates"

    /// Read the kept rates (at launch), then fetch new ones when the kept ones are not today's.
    @MainActor static func refreshIfDue(_ model: LibraryModel) async {
        if let d = UserDefaults.standard.data(forKey: key), let kept = CurrencyRates.fromStored(d) {
            CurrencyRates.current = kept
            model.objectWillChange.send()
        }
        guard !AMSPackingApp.testing, CurrencyRates.current.day != Today.local,
              let url = URL(string: "https://api.frankfurter.app/latest?from=SEK"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let fresh = CurrencyRates.parse(data) else { return }
        // A currency the service does not carry keeps its built-in rate.
        var merged = CurrencyRates.builtIn.sekPer
        for (k, v) in fresh.sekPer { merged[k] = v }
        CurrencyRates.current = CurrencyRates(sekPer: merged, day: fresh.day)
        UserDefaults.standard.set(CurrencyRates.current.stored, forKey: key)
        model.objectWillChange.send()
    }

    /// "Rates of 12 Nov 2026" or "Rough rates (not fetched yet)".
    static var words: String {
        let d = CurrencyRates.current.day
        return isYMD(d) ? "Other currencies at rates of \(Library.dayWords(d))" : "Other currencies at rough rates (not fetched yet)"
    }
}

/// "≈ 1 234 kr" under a price in another currency (nothing for kronor, or a currency not known).
struct PriceInKronor: View {
    let draft: Item
    var body: some View {
        if draft.price > 0, CurrencyRates.code(draft.currency) != "SEK",
           let sek = CurrencyRates.current.inKronor(draft.price, draft.currency) {
            Text("\u{2248} " + Library.moneyWords(sek))
                .font(.system(.subheadline).monospacedDigit()).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("thing-price-sek")
        }
    }
}

// MARK: - 4. Manual as a PDF

/// A paper row's tile for a PDF: a page with a folded corner and "PDF".
struct PDFTile: View {
    let side: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(AppSection.care.color.opacity(0.10))
            SVGPath.path("M7 3h7l4 4v14H7zM14 3v4h4")
                .stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
                .onGrid(side * 0.5).foregroundStyle(AppSection.care.color)
            Text("PDF").font(.system(size: 9, weight: .bold)).foregroundStyle(AppSection.care.color).offset(y: side * 0.08)
        }
        .frame(width: side, height: side)
    }
}

/// "Add a PDF": Files on the iPhone, the Open window on the Mac. Under the UI tests a small PDF the app
/// draws itself, named "Test manual".
struct AddPDFButton: View {
    let tint: Color
    let keep: (Data, String) -> Void
    @State private var picking = false
    @State private var said = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                if PhotoTakers.drawn { keep(AddPDFButton.samplePDF(), "Test manual.pdf") } else { picking = true }
            } label: {
                Text("Add a PDF").font(.system(.subheadline, weight: .semibold)).foregroundStyle(tint)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                    .background(Capsule().fill(tint.opacity(0.10)))
                    .overlay(Capsule().stroke(tint, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("thing-paper-pdf")
            if !said.isEmpty {
                Text(said).font(.system(.footnote)).foregroundStyle(AppSection.actions.color)
                    .accessibilityIdentifier("thing-paper-pdf-said")
            }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.pdf]) { result in
            guard case .success(let url) = result else { return }
            let open = url.startAccessingSecurityScopedResource()
            defer { if open { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { said = "That file could not be read."; return }
            guard data.count <= PAPER_PDF_MAX_BYTES else { said = "That PDF is over 25 MB \u{2014} too big to keep."; return }
            said = ""
            keep(data, url.lastPathComponent)
        }
    }

    /// A one-page PDF, drawn here (UI tests).
    static func samplePDF() -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 200, height: 280)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        ctx.beginPDFPage(nil)
        ctx.setFillColor(CGColor(red: 0.87, green: 0.45, blue: 0.14, alpha: 1))
        ctx.fill(CGRect(x: 20, y: 200, width: 160, height: 40))
        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }
}

/// A kept PDF, full page: Done and Share at the top, the pages under them.
struct PDFPage: View {
    let title: String
    let data: Data
    @Environment(\.dismiss) private var dismiss
    private var tint: Color { AppSection.care.color }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ShareLink(item: PDFFile(data: data, name: title), preview: SharePreview(title)) {
                    Text("Share").font(.system(.body, weight: .semibold)).foregroundStyle(tint)
                }
                .accessibilityIdentifier("pdf-share")
                Spacer()
                Text(title).font(.system(.headline)).foregroundStyle(Theme.ink).lineLimit(1)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold))
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("pdf-done")
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            PDFKitView(data: data)
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pdf-view")
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 700)
        #endif
    }
}

/// A PDF handed to Share as a file with its own name.
struct PDFFile: Transferable {
    let data: Data
    let name: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { $0.data }
            .suggestedFileName { $0.name.isEmpty ? "Manual.pdf" : $0.name + ".pdf" }
    }
}

#if os(iOS)
private struct PDFKitView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView(); v.autoScales = true; v.document = PDFDocument(data: data); return v
    }
    func updateUIView(_ v: PDFView, context: Context) {}
}
#else
private struct PDFKitView: NSViewRepresentable {
    let data: Data
    func makeNSView(context: Context) -> PDFView {
        let v = PDFView(); v.autoScales = true; v.document = PDFDocument(data: data); return v
    }
    func updateNSView(_ v: PDFView, context: Context) {}
}
#endif
