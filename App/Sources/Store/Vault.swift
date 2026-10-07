import Foundation
import SwiftUI
import PackingCore
import PackingLibrary

/// The folder his trip pages go into — the MAC's side of spec 07 part 8 (0.70, his yes
/// of 7 Oct 2026: "A trip page in his Obsidian vault"; the folder his choice: the
/// vault's Areas/Travel, picked by him once).
///
/// The page's words are the model's (`Library.vaultPage`, PackingLibrary); this only
/// keeps the folder and writes. The folder is chosen ONCE with the system's folder
/// picker and kept as a security-scoped bookmark, the way AMS WatchLater keeps its
/// vault (`ObsidianShelf`); this device only — the iPhone never writes: it marks the
/// trip "waiting for the Mac" (`Library.askForVaultPage`), and the Mac writes every
/// waiting page as soon as it is open with a folder (`libraryChanged`, called whenever
/// the library changes — at launch, on a sync from the iPhone, after a review saved
/// here).
///
/// Under the tests nothing of his is ever read or written: no bookmark, no remembered
/// folder. `-uiTestingVault <name>` gives a throwaway folder of that name in the app's
/// OWN temporary folder (emptied at launch) — not chosen until the folder picker is
/// "answered" by it, or chosen from the start with `-uiTestingVaultChosen`.
@MainActor
final class VaultShelf: ObservableObject {
    static let shared = VaultShelf()

    /// The chosen folder's name ("Travel"); nil before one is chosen, and always on the iPhone.
    @Published private(set) var folderName: String?
    /// What went wrong at the last write, in his words; nil when nothing did.
    @Published private(set) var trouble: String?
    /// Under `-uiTestingVault` only: what the folder holds, READ BACK from the disk after
    /// a write — the files, then the page's front matter. (The Mac's test runner is
    /// sandboxed apart from the app and cannot look into the app's folder itself.)
    @Published private(set) var readBack = ""

    private static let bookmarkKey = "ams.vault.bookmark"
    private static let nameKey = "ams.vault.name"

    /// The throwaway folder of a test run, or nil.
    let testFolder: URL?
    private var testChosen = false
    private var writing = false

    init() {
        let args = ProcessInfo.processInfo.arguments
        guard AMSPackingApp.testing else {
            testFolder = nil
            #if os(macOS)
            folderName = UserDefaults.standard.string(forKey: VaultShelf.nameKey)
            #endif
            return
        }
        // A NAME only, inside the app's own temporary folder: a test can never point the
        // app at a folder of his, nor have it emptied.
        let n = args.firstIndex(of: "-uiTestingVault")
        let name = n.flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } ?? ""
        if !name.isEmpty, !name.contains("/"), !name.hasPrefix(".") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
            try? FileManager.default.removeItem(at: url)
            testFolder = url
            testChosen = args.contains("-uiTestingVaultChosen")
            folderName = testChosen ? url.lastPathComponent : nil
        } else {
            testFolder = nil
        }
    }

    /// What a press on "Send to Obsidian" (Mac) came to.
    enum Outcome: Equatable {
        case written(String)
        /// No folder yet, or it has gone away: the folder picker is wanted.
        case needsFolder
        case failed
    }

    private struct Gone: Error {}

    // MARK: - The library changed: write what is waiting

    /// The Mac writes every page the library is waiting for — once it has a folder. On
    /// the next turn of the main loop, so the change that asked has been stored first.
    /// A write that fails leaves its trip waiting and does not try again by itself until
    /// the library changes again (no loop).
    func libraryChanged(_ model: LibraryModel) {
        #if os(macOS)
        guard folderName != nil, !writing, !model.library.tripsWaitingForVault().isEmpty else { return }
        writing = true
        DispatchQueue.main.async { [weak self, weak model] in
            guard let self, let model else { return }
            defer { self.writing = false }
            for id in model.library.tripsWaitingForVault() {
                // A trip that could not be written stays waiting, and the card says why;
                // with the folder gone, the rest wait with it.
                if case .needsFolder = self.write(id, model: model) { break }
            }
        }
        #endif
    }

    #if os(macOS)
    // MARK: - The folder

    /// He picked a folder in the system's folder picker (or the test folder answered it).
    func choose(_ url: URL) {
        if let testFolder {
            testChosen = true
            folderName = testFolder.lastPathComponent
            trouble = nil
            return
        }
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) else {
            trouble = "That folder cannot be used. Choose another."
            return
        }
        UserDefaults.standard.set(data, forKey: VaultShelf.bookmarkKey)
        UserDefaults.standard.set(url.lastPathComponent, forKey: VaultShelf.nameKey)
        folderName = url.lastPathComponent
        trouble = nil
    }

    /// The folder can no longer be found: forget it, and say so.
    private func forget() {
        let name = folderName ?? "The folder"
        if testFolder == nil {
            UserDefaults.standard.removeObject(forKey: VaultShelf.bookmarkKey)
            UserDefaults.standard.removeObject(forKey: VaultShelf.nameKey)
        } else {
            testChosen = false
        }
        folderName = nil
        trouble = "\(name) can no longer be found. Choose the folder again."
    }

    /// The folder, ready to write in (and whether it must be "entered" first).
    private func folder() throws -> (url: URL, scoped: Bool) {
        if let testFolder {
            guard testChosen else { throw Gone() }
            try FileManager.default.createDirectory(at: testFolder, withIntermediateDirectories: true)
            return (testFolder, false)
        }
        guard let data = UserDefaults.standard.data(forKey: VaultShelf.bookmarkKey) else { throw Gone() }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else { throw Gone() }
        if stale, let fresh = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: VaultShelf.bookmarkKey)
        }
        return (url, true)
    }

    // MARK: - Writing

    /// Write this trip's page — and its bags' photos into `attachments` beside it — then
    /// mark it written on the trip (which both devices then show). The same name again
    /// replaces the page.
    @discardableResult
    func write(_ tripId: String, model: LibraryModel) -> Outcome {
        guard let page = model.library.vaultPage(tripId: tripId) else { return .failed }
        if folderName == nil { return .needsFolder }
        let fm = FileManager.default
        do {
            let (root, scoped) = try folder()
            let entered = scoped && root.startAccessingSecurityScopedResource()
            defer { if entered { root.stopAccessingSecurityScopedResource() } }
            var isFolder: ObjCBool = false
            guard fm.fileExists(atPath: root.path, isDirectory: &isFolder), isFolder.boolValue else { throw Gone() }
            if !page.attachments.isEmpty {
                let dir = root.appendingPathComponent(VAULT_ATTACHMENTS_FOLDER, isDirectory: true)
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                for a in page.attachments {
                    guard let photo = model.library.vaultPhoto(a.photoId) else { continue }
                    try VaultShelf.put(photo.data, at: dir.appendingPathComponent(a.fileName))
                }
            }
            let file = root.appendingPathComponent(page.fileName)
            try VaultShelf.put(Data(page.text.utf8), at: file)
            guard fm.fileExists(atPath: file.path) else { throw CocoaError(.fileWriteUnknown) }
            if testFolder != nil { readBack = VaultShelf.readBack(root, page: page.fileName) }
        } catch is Gone {
            forget()
            return .needsFolder
        } catch {
            trouble = "The page could not be written into \(folderName ?? "the folder")."
            return .failed
        }
        trouble = nil
        model.change { _ = $0.vaultPageWritten(tripId: tripId, file: page.fileName, at: nowISO()) }
        return .written(page.fileName)
    }

    /// One file, written whole (a page half-written never shows in Obsidian), through a
    /// file coordinator as Obsidian or a sync service may be reading the folder.
    private static func put(_ data: Data, at url: URL) throws {
        var failure: Error?
        var coordination: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [.forReplacing], error: &coordination) { u in
            do { try data.write(to: u, options: .atomic) } catch { failure = error }
        }
        if let e = failure ?? coordination { throw e }
    }

    /// The test's look into the folder: every file (attachments as "attachments/…"),
    /// one per line, A–Z; then the page's front matter as it is ON THE DISK.
    private static func readBack(_ root: URL, page: String) -> String {
        let fm = FileManager.default
        var names: [String] = []
        for name in (try? fm.contentsOfDirectory(atPath: root.path)) ?? [] {
            var isFolder: ObjCBool = false
            let path = root.appendingPathComponent(name).path
            if fm.fileExists(atPath: path, isDirectory: &isFolder), isFolder.boolValue {
                names += ((try? fm.contentsOfDirectory(atPath: path)) ?? []).map { "\(name)/\($0)" }
            } else {
                names.append(name)
            }
        }
        let text = (try? String(contentsOf: root.appendingPathComponent(page), encoding: .utf8)) ?? ""
        let head = text.components(separatedBy: "\n").prefix(while: { !$0.hasPrefix("# ") })
        return (names.sorted() + ["==="] + head).joined(separator: "\n")
    }
    #endif
}
