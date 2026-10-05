import XCTest
import PackingCore
@testable import PackingLibrary

/// A restore REPLACES. The web app once restored a file and quietly kept parts of
/// what was already there (his timeline, things on no list), so the question asked
/// here is the strict one: after a restore, is the library exactly the file — and
/// nothing else?
final class RestoreTests: XCTestCase {

    /// A library with a bit of everything, so a restore has something to remove.
    private func before() -> Library {
        var lib = Library()
        var base = newList(name: "Everyday", role: "base")
        base.items = [newItem(name: "Keys"), newItem(name: "Wallet"), newItem(name: "Ear plugs")]
        lib.saveTemplate(base)
        var sea = newList(name: "Sailing", group: "WET")
        sea.items = [newItem(name: "Life jacket"), newItem(name: "Dry bag")]
        lib.saveTemplate(sea)
        var trip = newEvent(name: "Two nights out", startDate: "2026-07-01", endDate: "2026-07-03")
        trip.activities = lib.templates.filter { $0.name == "Sailing" }.map { $0.id }
        trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
        lib.trips = [trip]
        _ = lib.setNames("places", lib.storagePlaces() + ["Boat locker"])
        _ = lib.addAction(text: "Buy sun cream")
        return lib
    }

    /// The file: a smaller library, written the way the app writes a backup.
    private func fileLibrary() -> Library {
        var lib = Library()
        var day = newList(name: "Day out", role: "base")
        day.items = [newItem(name: "Water bottle"), newItem(name: "Sun hat")]
        lib.saveTemplate(day)
        return lib
    }

    private func read(_ data: Data) -> (Library, Importer.Report) {
        guard let json = try? JSONValue.parse(data), BackupFile.looksLikeBackup(json) else {
            XCTFail("the file did not read as a backup"); return (Library(), Importer.Report())
        }
        return Importer.library(from: BackupFile(json: json))
    }

    func testARestoreLeavesExactlyWhatTheFileHeldAndNothingOfWhatWasThere() throws {
        let old = before()
        let (fresh, report) = read(fileLibrary().backupData())
        XCTAssertTrue(report.isFaithful, "the file did not come back the same")

        // What the app does: the difference between the records, applied to the store.
        let store = MemoryStore(old.records())
        try store.apply(recordChanges(from: old.records(), to: fresh.records()))
        let after = Library(records: try store.loadAll())

        XCTAssertEqual(after.items.map(\.name).sorted(), ["Sun hat", "Water bottle"])
        XCTAssertEqual(after.templates.map(\.name), ["Day out"])
        XCTAssertTrue(after.trips.isEmpty, "a trip from before the restore survived")
        XCTAssertTrue(after.actions.isEmpty, "a to-do from before the restore survived")
        XCTAssertFalse(after.storagePlaces().contains("Boat locker"), "a Settings list entry from before survived")
        for row in after.counts {
            XCTAssertEqual(row.count, fresh.counts.first { $0.table == row.table }?.count ?? 0,
                           "\(row.table.rawValue): the device does not hold what the file held")
        }
    }

    /// The comparison the sheet shows him: this file holds less than the device.
    func testTheFileHoldingLessThanTheDeviceIsVisibleInTheCounts() {
        let old = before()
        let (fresh, _) = read(fileLibrary().backupData())
        let device = Dictionary(uniqueKeysWithValues: old.counts.map { ($0.table, $0.count) })
        let fewer = fresh.counts.filter { $0.count < (device[$0.table] ?? 0) }.map { $0.table }
        XCTAssertTrue(fewer.contains(.items), "fewer things was not visible")
        XCTAssertTrue(fewer.contains(.trips), "a trip that would be lost was not visible")
    }

    /// The way back. Once a bag had a cabin answer, the copy kept before a restore was
    /// REFUSED ("did not come back the same") — the way back was shut exactly when it
    /// was needed (the spec pass, 2026-10-05). Played here as the app plays it: the copy
    /// is written (`RescueCopies.write` writes `backupData`), a file replaces everything,
    /// then "Kept before a restore" → Replace reads the copy through the same check and
    /// puts it back. Both the copies written from now on and the ones already on his
    /// devices (written before the things travelled as stored).
    func testTheCopyKeptBeforeARestoreBringsBackEverythingCabinAnswersIncluded() throws {
        var old = before()
        _ = old.setBagCabin(id: old.addBag(name: "Rolling case")!.id, true)
        let keys = old.items.first { $0.name == "Keys" }!.id
        _ = old.updateThing(id: keys) { $0.extra["inventedKey"] = "kept" }
        old.trips[0].entries[0].extra["inventedLineKey"] = true

        let copies = ["written now": old.backupData(exportedAt: "2026-10-05T07:00:00.000Z"),
                      "already on his devices": BackupTests.olderFile(old, exportedAt: "2026-10-05T07:00:00.000Z")]
        for (kind, copy) in copies.sorted(by: { $0.key < $1.key }) {
            let store = MemoryStore(old.records())
            let (file, _) = read(fileLibrary().backupData())
            try store.apply(recordChanges(from: old.records(), to: file.records()))
            let replaced = Library(records: try store.loadAll())

            let (back, report) = read(copy)
            XCTAssertTrue(report.isFaithful, "\(kind): the way back was refused: " + report.mismatches.joined(separator: "; "))
            try store.apply(recordChanges(from: replaced.records(), to: back.records()))
            let after = Library(records: try store.loadAll())

            XCTAssertTrue(Library.isCabinBag(after.items.first { $0.name == "Rolling case" }!), "\(kind): the cabin answer")
            XCTAssertEqual(after.items.first { $0.id == keys }?.extra["inventedKey"], "kept", "\(kind): a key this build does not know")
            XCTAssertEqual(after.trips.first?.entries.first { $0.id == old.trips[0].entries[0].id }?.extra["inventedLineKey"], true,
                           "\(kind): a key on a trip line")
            XCTAssertEqual(BackupTests.differences(old, after), [], "\(kind): the device does not hold what it held before")
        }
    }

    /// A file that is not a backup is refused before anything is touched.
    func testSomethingThatIsNotABackupIsNotReadAsOne() {
        XCTAssertFalse(BackupFile.looksLikeBackup(try! JSONValue.parse(Data("{\"hello\":1}".utf8))))
        XCTAssertTrue(BackupFile.looksLikeBackup(try! JSONValue.parse(fileLibrary().backupData())))
    }
}
