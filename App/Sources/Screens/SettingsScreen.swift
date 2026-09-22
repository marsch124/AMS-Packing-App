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
    @State private var lists = false
    @State private var picking = false
    @State private var pending: PendingRestore?
    @State private var copies: [URL] = RescueCopies.all()

    /// A file that has been read and checked, waiting for him to say yes.
    struct PendingRestore: Identifiable { let id = UUID(); let library: Library }

    var body: some View {
        KeyboardAwayScroll {
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

                Button {
                    status = ""
                    // Apple's file window cannot be driven by a test, so under the
                    // UI tests the button reads an invented file instead.
                    if AMSPackingApp.testing { offer(SampleLibrary.fileToRestore()) } else { picking = true }
                } label: {
                    Text("Restore from a file…")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.settings.color)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("backup-restore")

                // The copies the app wrote for itself before a restore. A way back
                // that he cannot reach is no way back, so they are listed here.
                if !copies.isEmpty {
                    Text("Kept before a restore").font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.muted).padding(.top, 10)
                        .accessibilityIdentifier("rescue-heading")
                    VStack(spacing: 0) {
                        ForEach(Array(copies.enumerated()), id: \.offset) { n, copy in
                            Button { offer(RescueCopies.read(copy) ?? Data()) } label: {
                                HStack {
                                    Text(RescueCopies.when(copy))
                                        .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Text("Look at it").font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(AppSection.settings.color)
                                }
                                .padding(.horizontal, 14).frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("rescue-row-\(n)")
                            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                }

                Button { lists = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your lists").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                            Text("Storage places, owners, packers, conditions, \"When\" steps")
                                .font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                        Spacer()
                        SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                            .frame(width: 24, height: 24).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 60)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .padding(.top, 14)
                .accessibilityIdentifier("settings-lists")

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
        .sheet(isPresented: $lists) { ListsScreen().environmentObject(model) }
        .sheet(item: $pending) { waiting in
            RestoreSheet(file: waiting.library, device: model.library) { yes in
                pending = nil
                guard yes else { status = "Nothing was replaced."; return }
                do {
                    try model.restore(waiting.library)
                    copies = RescueCopies.all()
                    status = "Restored from the file. A copy of what was here is kept on this device."
                } catch {
                    status = error.localizedDescription
                }
            }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let allowed = url.startAccessingSecurityScopedResource()
                defer { if allowed { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) { offer(data) } else { status = "That file could not be read." }
            case .failure: status = "Nothing chosen."
            }
        }
        .fileExporter(isPresented: $exporting, document: BackupDocument(data: model.library.backupData()),
                      contentType: .json, defaultFilename: Library.backupFileName(on: Today.local)) { result in
            switch result {
            case .success(let url): status = "Saved: \(url.lastPathComponent)"
            case .failure: status = "Not saved."
            }
        }
    }

    /// Read the file and check it BEFORE he is offered the button. A file that is
    /// not a backup, or that does not come back the same, never gets that far.
    private func offer(_ data: Data) {
        do {
            let (library, _) = try model.inspectBackup(data)
            pending = PendingRestore(library: library)
        } catch {
            status = error.localizedDescription
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
