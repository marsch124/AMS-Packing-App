import SwiftUI
import UniformTypeIdentifiers
import PackingCore
import PackingLibrary

/// Settings: save a backup — a real Save window on the Mac, Files on the iPhone
/// (promised as one of the FIRST features) — and what this device holds, table
/// by table, so two devices can be compared by eye.
struct SettingsScreen: View {
    @EnvironmentObject var model: LibraryModel
    @State private var exporting = false
    @State private var status = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Backup").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted).padding(.top, 14)
                Button {
                    status = "Choosing where to save…"
                    exporting = true
                } label: {
                    Text("Save a backup…")
                        .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.settings.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("backup-save")
                Text(status.isEmpty ? "The same file the web app writes, so either app can read it." : status)
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("backup-status")

                Text("This device holds").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted).padding(.top, 14)
                VStack(spacing: 0) {
                    ForEach(model.library.counts, id: \.table) { row in
                        HStack {
                            Text(SettingsScreen.label(row.table)).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(row.count)").font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
                                .accessibilityIdentifier("device-count-\(row.table.rawValue)")
                        }
                        .padding(.horizontal, 14).frame(minHeight: 40)
                        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                    }
                    HStack {
                        Text(model.usesICloud ? "Synced through iCloud" : "On this device only")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.muted)
                        Spacer()
                        Text(AppInfo.version).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 40)
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .fileExporter(isPresented: $exporting, document: BackupDocument(data: model.library.backupData()),
                      contentType: .json, defaultFilename: Library.backupFileName(on: Today.local)) { result in
            switch result {
            case .success(let url): status = "Saved: \(url.lastPathComponent)"
            case .failure: status = "Not saved."
            }
        }
    }

    static func label(_ t: PackingLibrary.Table) -> String {
        switch t {
        case .items: return "Things"
        case .memberships: return "Places on lists"
        case .templates: return "Templates"
        case .trips: return "Trips"
        case .entries: return "Trip lines"
        case .actions: return "To-dos"
        case .kits: return "Kits"
        case .phases: return "Own \"When\" steps"
        case .shared: return "Settings list entries"
        case .photos: return "Photos"
        case .meta: return "Notes about the library"
        }
    }
}

/// The backup as a document the Save window can write.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
