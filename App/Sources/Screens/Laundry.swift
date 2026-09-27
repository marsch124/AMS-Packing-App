import SwiftUI
import UniformTypeIdentifiers
import PackingCore
import PackingLibrary

/// Laundry on a trip — the web app's "Laundry available on this trip": you wash and
/// wear again, so per-night things (socks, underwear, tees) count four nights at
/// most instead of one per night. Short trips are not touched.
struct LaundrySwitch: View {
    @Binding var on: Bool
    let id: String

    var body: some View {
        Toggle(isOn: $on) {
            HStack(alignment: .top, spacing: 10) {
                LaundryMark().frame(width: 24, height: 24).foregroundStyle(AppSection.events.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Laundry").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("Wash and wear again: per-night things count \(LAUNDRY_CAP_NIGHTS) nights at most.")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier(id)
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
                HStack(spacing: 10) {
                    SheetMark().frame(width: 22, height: 22)
                    Text("Save as Excel").font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(AppSection.events.color)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.events.color, lineWidth: 1.4))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("trip-excel")
            if !status.isEmpty {
                Text(status).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
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
