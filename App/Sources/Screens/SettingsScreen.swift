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
    /// The file being saved — built when Save is pressed, never on a redraw.
    @State private var saving: BackupDocument?
    /// When a backup was last saved from this device (`savedKey`).
    @AppStorage(SettingsScreen.savedKey) private var savedAt = ""
    @State private var status = ""
    /// Your choices and the restore are two sheets, as in 0.61. 0.62's single sheet with
    /// a destination (the spec pass's item 18) failed on the Mac: after one restore, the
    /// rescue copy's restore never opened (GitHub's Mac run, 5 Oct 2026). Both sheets
    /// are opened one after the other by `testSettingsOpensYourChoicesAndTheRestoreOneAfterTheOther`.
    @State private var lists = false
    @State private var pending: PendingRestore?
    @State private var picking = false
    @State private var copies: [URL] = RescueCopies.all()

    /// A file that has been read and checked, waiting for him to say yes.
    struct PendingRestore: Identifiable { let id = UUID(); let library: Library }


    var body: some View {
        KeyboardAwayScroll {
            // The cards 8 points apart, and the doors that only open a page are rows of
            // ONE card — his words (6 Oct 2026, testing 0.63, the gaps between the cards
            // marked): "Far too much space in the settings tab." (Until 0.67 every door was
            // a card of its own, 60 points tall, and the cards stood 10 points apart.)
            VStack(alignment: .leading, spacing: 8) {
                Button { lists = true } label: {
                    SettingsDoorLabel(title: "Your choices", line: "Storage places, owners, packers, conditions, \"When\" steps")
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("settings-lists")
                .settingsCard()
                .padding(.top, 12)

                // Remind me to pack (his idea 7) — per device, off until he says.
                RemindersCard().environmentObject(model)

                // iCloud sync on this device (his field test, 3 Oct 2026): sent, received,
                // what is stuck and why — and Sync now, which the other device then shows.
                SyncCard().environmentObject(model)

                // What's new and How it works — his standing rule from the web apps — and a
                // link or code someone shared (the web app's "Paste a shared link"): the
                // doors that open a page, rows of one card, as in the iPhone's own Settings.
                VStack(spacing: 0) {
                    GuideDoors()
                    CardHairline()
                    OpenSharedDoor().environmentObject(model)
                }
                .settingsCard()

                // Only when there is something to say. Both times this library went
                // wrong, nothing on screen said so and the counts alone knew.
                // ⚠️ Asked on EVERY drawing of Settings, as are the counts below. Both
                // walk the library in memory only — no record is built, no photo
                // decoded, and the photos still shown are gathered in one walk (the
                // spec pass, 5 Oct 2026); the backup file is built only when Save is
                // pressed. Anything heavier belongs in a button, not here.
                let worries = model.library.worries()
                if !worries.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Worth a look").font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(AppSection.actions.color)
                            .accessibilityIdentifier("health-heading")
                        ForEach(Array(worries.enumerated()), id: \.offset) { n, worry in
                            Text(worry.says).font(.system(.callout)).foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("health-\(n)")
                            if !worry.fix.isEmpty {
                                Button { model.change { _ = $0.repair(worry.fix) } } label: {
                                    Text(worry.fixSays).font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                                        .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                                        .background(Capsule().fill(AppSection.actions.color))
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .accessibilityIdentifier("health-\(n)-fix")
                            }
                            if !worry.names.isEmpty {
                                Text(worry.names.prefix(6).joined(separator: " · ")
                                     + (worry.names.count > 6 ? " …" : ""))
                                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("health-\(n)-names")
                            }
                        }
                        Text("A backup and then \"Restore from a file…\" puts a library back exactly as the file has it.")
                            .font(.system(.footnote)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.actions.color.opacity(0.5), lineWidth: 1))
                    .padding(.top, 6)
                }

                // Lower down, his test K.2 (1 Oct 2026): "Move down, back up, and restore to
                // the bottom or at least further down." Used now and then, not every day.
                SectionTitle(title: "Backup", id: "backup-heading")
                Button {
                    status = "Choosing where to save…"
                    // The whole library written out — built now, for this save only. It
                    // used to be built on EVERY drawing of Settings (the spec pass, 2026-10-05).
                    saving = BackupDocument(data: model.library.backupData())
                    exporting = true
                } label: {
                    Text("Save a backup…")
                        .font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: Metrics.row)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.settings.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("backup-save")
                Text(status.isEmpty ? "The same file the web app writes, so either app can read it." : status)
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("backup-status")
                if let last = Library.lastSavedWords(savedAt, device: SyncCard.device) {
                    Text(last).font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("backup-last")
                }

                Button {
                    status = ""
                    // Apple's file window cannot be driven by a test, so under the
                    // UI tests the button reads an invented file instead.
                    if AMSPackingApp.testing { offer(SampleLibrary.fileToRestore()) } else { picking = true }
                } label: {
                    Text("Restore from a file…")
                        .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.settings.color)
                        .frame(maxWidth: .infinity, minHeight: Metrics.tap)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("backup-restore")

                // The copies the app wrote for itself before a restore. A way back
                // that he cannot reach is no way back, so they are listed here.
                if !copies.isEmpty {
                    Text("Kept before a restore").font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.muted).padding(.top, 10)
                        .accessibilityIdentifier("rescue-heading")
                    VStack(spacing: 0) {
                        ForEach(Array(copies.enumerated()), id: \.offset) { n, copy in
                            // The date, and "Look at it" as a button of its own. Until 0.63 the
                            // whole row was one plain button, and on the Mac a click on it did
                            // nothing once the row was slim (GitHub's Mac run, 6 Oct 2026).
                            HStack {
                                Text(RescueCopies.when(copy))
                                    .font(.system(.callout)).foregroundStyle(Theme.ink)
                                Spacer()
                                Button("Look at it") { offer(RescueCopies.read(copy) ?? Data()) }
                                    .buttonStyle(HeaderButtonStyle(tint: AppSection.settings.color, filled: false))
                                    .focusEffectDisabled()
                                    .accessibilityIdentifier("rescue-row-\(n)")
                            }
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                }

                Text("This device holds").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted).padding(.top, 10)
                VStack(spacing: 0) {
                    ForEach(model.library.counts, id: \.table) { row in
                        HStack {
                            Text(SettingsScreen.label(row.table)).font(.system(.callout)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(row.count)").font(.system(.callout, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                                .accessibilityIdentifier("device-count-\(row.table.rawValue)")
                        }
                        .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                    }
                    HStack {
                        Text(model.usesICloud ? "Synced through iCloud" : "On this device only")
                            .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                        Spacer()
                        Text(AppInfo.version).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                // Where this library came from, when it came from a file — the import's
                // own marker (the spec pass, 2026-10-05: no screen showed the import).
                if let came = model.library.broughtInWords() {
                    Text(came).font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("device-import")
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .sheet(isPresented: $lists) { ListsScreen().environmentObject(model) }
        // A restore closed without an answer (swiped away) answers "no" from inside the
        // sheet (RestoreSheet's onDisappear), so this sheet is exactly 0.61's.
        .sheet(item: $pending) { waiting in
            RestoreSheet(file: waiting.library, device: model.library) { yes in
                pending = nil
                guard yes else { status = "Nothing was replaced."; return }
                do {
                    try model.restore(waiting.library)
                    copies = RescueCopies.all()
                    status = "Restored from the file: \(waiting.library.holdsWords). A copy of what was here is kept on this device."
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
        .fileExporter(isPresented: $exporting, document: saving,
                      contentType: .json, defaultFilename: Library.backupFileName(on: Today.local)) { result in
            saving = nil
            switch result {
            case .success(let url):
                status = "Saved: \(url.lastPathComponent)"
                savedAt = nowISO()
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

    /// When a backup was last saved from this device (ISO). Per device, like the
    /// web app's: the other device keeps its own.
    static let savedKey = "ams.backup.savedAt"

    static func label(_ t: PackingLibrary.Table) -> String {
        switch t {
        case .items: return "Things"
        case .memberships: return "Places on templates"
        case .templates: return "Templates"
        case .trips: return "Trips"
        case .entries: return "Trip lines"
        case .actions: return "To-dos"
        // Not "Kits": in his words a kit is ALL his things (Words, the guide); this
        // table holds the web app's named groups of things, such as a dive kit
        // (the spec pass, 5 Oct 2026: one word, two meanings).
        case .kits: return "Groups of things"
        case .phases: return "Own \"When\" steps"
        case .shared: return "Choices"
        case .photos: return "Photos"
        case .meta: return "Notes about the library"
        }
    }
}

/// A door in Settings: its name, a line under it, and the arrow — one row of a card,
/// as in the iPhone's own Settings (`settingsCard`; rows of one card are parted by a
/// `CardHairline`). Filled with the card's colour, so the whole row takes a press, on
/// the Mac too. Until 0.67 each door was a card of its own, at least 60 points tall.
struct SettingsDoorLabel: View {
    let title: String
    let line: String

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(line).font(.system(.footnote)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .onGrid(Metrics.glyph).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: Metrics.row, alignment: .leading)
        .background(Theme.card)
        .contentShape(Rectangle())
    }
}

/// The line between two rows of one card in Settings, starting where the words do.
struct CardHairline: View {
    var body: some View {
        Theme.line.frame(height: 1).padding(.leading, 12).background(Theme.card)
    }
}

extension View {
    /// A card in Settings: the card's colour, rounded, a hairline round it.
    func settingsCard() -> some View {
        clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
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
