#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import PackingLibrary

/// A row of the test store — the app's own `Record` lives in the app; the history does not care.
@Model final class HistoryTestRow {
    var n: Int = 0
    init(n: Int) { self.n = n }
}

/// The store's history, read the way `CloudStore` reads it (`StoreHistory`), on a real SwiftData
/// store in a file — 0.94, item 7 of the outside review of 0.92: the launch read the WHOLE history
/// on the main thread to find its newest entry, the history grows with every change for ever, and
/// after one failed read every later look read the whole history again.
@available(macOS 15, iOS 18, *)
final class StoreHistoryTests: XCTestCase {
    static let mine = "AMSPacking.app"
    private var folder: URL!
    private var container: ModelContainer!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("StoreHistoryTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let schema = Schema([HistoryTestRow.self])
        let config = ModelConfiguration("History", schema: schema, url: folder.appendingPathComponent("History.store"),
                                        cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        container = nil
        try? FileManager.default.removeItem(at: folder)
    }

    /// `count` saves, one transaction each, by `author` (nil: a save with no author).
    private func save(_ count: Int = 1, by author: String?) throws {
        let context = ModelContext(container)
        context.author = author
        for n in 0..<count {
            context.insert(HistoryTestRow(n: n))
            try context.save()
        }
    }

    /// A long history — 300 changes — and the launch reads ONE transaction of it, not all 300; it
    /// still starts from the newest: the next look reads only what came after.
    func testTheLaunchReadsOnlyTheNewestChangeNotTheWholeHistory() throws {
        try save(300, by: Self.mine)
        let history = StoreHistory(container, quiet: [Self.mine])
        history.lookAtLaunch()
        XCTAssertLessThanOrEqual(history.transactionsRead, 1,
                                 "the launch read \(history.transactionsRead) transactions of a history of 300")
        let atLaunch = history.transactionsRead
        try save(by: "the other device")
        XCTAssertFalse(history.onlyQuietSinceLastLook(), "the other device's change was taken for our own")
        try save(by: Self.mine)
        XCTAssertTrue(history.onlyQuietSinceLastLook(), "our own save was read back")
        XCTAssertEqual(history.transactionsRead - atLaunch, 2, "the looks after launch read more than what was new")
    }

    /// A read that fails reloads (a doubt always does) — and the history is NOT read whole from then
    /// on: until 0.94 the newest change looked at was forgotten, and every later look read everything.
    func testAFailedReadRecoversWithoutReadingTheWholeHistory() throws {
        try save(300, by: Self.mine)
        let history = StoreHistory(container, quiet: [Self.mine])
        history.lookAtLaunch()
        try save(by: Self.mine)
        history.failNextRead = true
        XCTAssertFalse(history.onlyQuietSinceLastLook(), "a history that could not be read did not reload")
        let afterTheFailure = history.transactionsRead
        try save(by: Self.mine)
        XCTAssertTrue(history.onlyQuietSinceLastLook(), "after a failed read our own save was read back")
        XCTAssertLessThanOrEqual(history.transactionsRead - afterTheFailure, 1,
                                 "after a failed read the next look read \(history.transactionsRead - afterTheFailure) transactions")
        // A failed read at launch recovers the same way.
        let fresh = StoreHistory(container, quiet: [Self.mine])
        fresh.failNextRead = true
        fresh.lookAtLaunch()
        try save(by: Self.mine)
        XCTAssertFalse(fresh.onlyQuietSinceLastLook(), "with no start from launch the first look did not reload")
        try save(by: Self.mine)
        XCTAssertTrue(fresh.onlyQuietSinceLastLook(), "a failed launch read never recovered")
        XCTAssertLessThanOrEqual(fresh.transactionsRead, 3, "a failed launch read led to \(fresh.transactionsRead) transactions read")
    }

    /// 0.91's rule, unchanged: the app's own saves and iCloud SENDING them are quiet; anything else —
    /// iCloud bringing the other device's changes, no author, a mix, or nothing new — is read.
    func testOwnSavesAreQuietAndEverythingElseIsRead() throws {
        let history = StoreHistory(container, quiet: [Self.mine, "NSCloudKitMirroringDelegate.export"])
        history.lookAtLaunch()                                         // an empty history
        try save(by: Self.mine)
        XCTAssertTrue(history.onlyQuietSinceLastLook(), "our own save was read back")
        XCTAssertFalse(history.onlyQuietSinceLastLook(), "nothing new did not reload")
        try save(by: "NSCloudKitMirroringDelegate.export")
        XCTAssertTrue(history.onlyQuietSinceLastLook(), "iCloud sending our save was read back")
        try save(by: "NSCloudKitMirroringDelegate.import")
        XCTAssertFalse(history.onlyQuietSinceLastLook(), "iCloud bringing the other device's change was not read")
        try save(by: Self.mine)
        try save(by: "the other device")
        XCTAssertFalse(history.onlyQuietSinceLastLook(), "our save and theirs together were not read")
        try save(by: nil)
        XCTAssertFalse(history.onlyQuietSinceLastLook(), "a save with no author was not read")
    }
}
#endif
