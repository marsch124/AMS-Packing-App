import SwiftUI
import UniformTypeIdentifiers
import PackingCore
import PackingLibrary

/// Laundry on a trip — the web app's "Laundry available on this trip": you wash and
/// wear again, so per-night things (socks, underwear, tees) count four nights at
/// most instead of one per night. Short trips are not touched.
struct LaundrySwitch: View {
    @Binding var on: Bool
    /// How many nights' worth to pack before a wash (his idea, 2 Oct 2026; was always 4).
    @Binding var nights: Int
    let id: String
    static let choices = [3, 4, 5, 7, 10, 14]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: $on) {
                HStack(alignment: .center, spacing: 10) {
                    LaundryMark().frame(width: 24, height: 24).foregroundStyle(AppSection.events.color)
                    Text("Laundry").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                }
            }
            .accessibilityIdentifier(id)
            // Its own line, not inside the switch: the Mac folds a switch's words into
            // the switch, and nothing could read them there (0.47, GitHub's Mac).
            Text(on ? "Wash and wear again: per-night things count \(nights) nights at most."
                    : "Wash and wear again, so you pack fewer per-night things.")
                .font(.system(size: 15)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 34)
                .accessibilityIdentifier("\(id)-says")
            if on {
                Pills(title: "Pack for this many nights, then wash",
                      options: LaundrySwitch.choices.map { ("\($0)", "\($0)") }, selected: ["\(nights)"],
                      id: "\(id)-nights", tint: AppSection.events.color, heading: .question) { nights = Int($0) ?? LAUNDRY_CAP_NIGHTS }
                    .padding(.leading, 34).padding(.top, 6)
            }
        }
    }
}

/// A washtub, drawn — the web app's own laundry mark.
struct LaundryMark: View {
    var body: some View {
        SVGPath.path("M4.4 8.6h15.2L18.2 20H5.8ZM3 8.6h18M8.8 11.8l.8 5M15.2 11.8l-.8 5M12 11.8v5")
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .accessibilityHidden(true)
    }
}

/// A sheet of cells, drawn — for Save as Excel.
struct SheetMark: View {
    var body: some View {
        SVGPath.path("M4.5 4.5h15v15h-15ZM4.5 9.5h15M4.5 14.5h15M10 4.5v15")
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .accessibilityHidden(true)
    }
}

/// The .xlsx the Save window writes.
struct XlsxDocument: FileDocument {
    static let type = UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data
    static var readableContentTypes: [UTType] { [type] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// Save as Excel — the web app's Excel button: the trip as a spreadsheet, by When
/// and bag, with how many and what is packed. Owns its Save window.
struct TripExcelButton: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @State private var exporting = false
    @State private var file: XlsxDocument?
    @State private var fileName = Library.workbookFileName("")
    @State private var status = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                guard let made = model.library.tripWorkbook(tripId: tripId) else { return }
                file = XlsxDocument(data: made.data)
                fileName = made.fileName
                status = "Choosing where to save…"
                exporting = true
            } label: {
                WideButtonLabel(title: "Save as Excel", tint: AppSection.events.color) { SheetMark() }
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("trip-excel")
            if !status.isEmpty {
                Text(status).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("trip-excel-status")
            }
        }
        .fileExporter(isPresented: $exporting, document: file, contentType: XlsxDocument.type,
                      defaultFilename: fileName) { result in
            switch result {
            case .success(let url): status = "Saved: \(url.lastPathComponent)"
            case .failure: status = "Not saved."
            }
        }
    }
}
