#if canImport(SwiftData)
import XCTest
import SwiftData
import CoreData
@testable import PackingLibrary

/// A row of the test store (the app's own `Record` lives in the app).
@Model final class ConnectionTestRow {
    var n: Int = 0
    init(n: Int) { self.n = n }
}

/// The store closed and opened again in the same run (0.104, `StoreConnection`) — what the app's
/// Restart sync does in place of quitting — on a real SwiftData store in a file. iCloud cannot be in a
/// test; what is proved here is the store's side: the old one fully gone first, never two open at once,
/// and nothing lost.
@available(macOS 15, iOS 18, *)
final class StoreConnectionTests: XCTestCase {
    private var folder: URL!
    private var schema: Schema!
    private var config: ModelConfiguration!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("StoreConnectionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        schema = Schema([ConnectionTestRow.self])
        config = ModelConfiguration("Connection", schema: schema, url: folder.appendingPathComponent("Connection.store"),
                                    cloudKitDatabase: .none)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: folder) }

    private func rows(_ container: ModelContainer) throws -> [Int] {
        try ModelContext(container).fetch(FetchDescriptor<ConnectionTestRow>()).map(\.n).sorted()
    }

    private func write(_ n: Int, into container: ModelContainer) throws {
        let context = ModelContext(container)
        context.insert(ConnectionTestRow(n: n))
        try context.save()
    }

    /// Closed: the store taken off its coordinator — Core Data's own teardown of a store's iCloud
    /// connection — and the old container gone, before the new one opens; what was saved is all there,
    /// and a save after works.
    func testTheStoreClosesFullyAndOpensAgainWithNothingLost() throws {
        let connection = StoreConnection(schema: schema, configuration: config, exclusive: true)
        try autoreleasepool {
            let first = try connection.open()
            try write(1, into: first)
            try write(2, into: first)
        }
        XCTAssertTrue(connection.canClose, "the store's coordinator was not caught as SwiftData added the store")
        let closed = try connection.close()
        XCTAssertEqual(closed, StoreConnection.Closed(removed: true, released: true),
                       "the old store was not fully let go before a new one could open")
        XCTAssertNil(connection.container)
        XCTAssertFalse(StoreConnection.isOpen(config.url), "closed, yet the file still counts as open")
        let again = try connection.open()
        XCTAssertEqual(try rows(again), [1, 2], "what was saved before the restart is not all there")
        try write(3, into: again)
        XCTAssertEqual(try rows(again), [1, 2, 3], "a save after the restart was not kept")
        _ = try connection.close()
    }

    /// Never two open at once: a second opening of an exclusive file (the iCloud store) is refused while
    /// the first is open — and allowed once it is closed.
    func testTheICloudStoreIsNeverOpenTwiceAtOnce() throws {
        let one = StoreConnection(schema: schema, configuration: config, exclusive: true)
        let two = StoreConnection(schema: schema, configuration: config, exclusive: true)
        try autoreleasepool { _ = try one.open() }
        XCTAssertTrue(StoreConnection.isOpen(config.url))
        XCTAssertThrowsError(try two.open(), "the same store opened a second time while open") { error in
            XCTAssertTrue(error is StoreConnection.AlreadyOpen, "\(error)")
        }
        _ = try one.close()
        XCTAssertNoThrow(try two.open(), "closed, the store could not be opened again")
        _ = try two.close()
    }

    /// Something still holding the old container is said (`released` false) — the app lets go of its
    /// contexts first, so this is how a forgotten one would show.
    func testAContextStillHoldingTheOldStoreIsSaid() throws {
        let connection = StoreConnection(schema: schema, configuration: config, exclusive: true)
        var held: ModelContext?
        try autoreleasepool { held = ModelContext(try connection.open()) }
        let closed = try connection.close()
        XCTAssertTrue(closed.removed)
        XCTAssertFalse(closed.released, "a context still holding the old container went unnoticed")
        held = nil
        _ = held
    }
}
#endif
