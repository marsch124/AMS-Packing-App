import XCTest
import PackingCore
@testable import PackingLibrary

/// Invented data only — this repository is public.
final class BackupTests: XCTestCase {

    override func setUp() { PackingEnv.freeze() }
    override func tearDown() {
        PackingEnv.reset()
        _ = setPhases(DEFAULT_PHASES)
        _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }

    func testABackupComesBackAsTheSameLibrary() {
        var lib = LibraryTests.sample()
        lib.setChecked(true, tripId: lib.trips[0].id, entryId: lib.trips[0].entries[0].id)
        lib.setAside(true, tripId: lib.trips[0].id, entryId: lib.trips[0].entries[1].id)
        var own = DEFAULT_PHASES; own.append(newPhase("Load the van", own.map(\.id)))
        lib.phases = setPhases(own)
        lib.shared = namesToRows("places", ["Garage shelf", "Loft"]) + peopleToRows([newPerson(name: "Jonas", color: "#22c55e")])

        let file = lib.backupFile(exportedAt: "2026-09-22T07:00:00.000Z")
        XCTAssertEqual(file.app, "ams-packing-list")
        XCTAssertEqual(file.version, 2)
        let (back, report) = Importer.library(from: file)
        XCTAssertTrue(report.isFaithful, report.mismatches.joined(separator: "; "))
        XCTAssertEqual(back.resolvedTemplates(), lib.resolvedTemplates())
        XCTAssertEqual(back.trips, lib.trips, "ticks and set-aside lines survive")
        XCTAssertEqual(back.phases, lib.phases)
        XCTAssertEqual(orderedNamesFromRows(back.shared, "places"), ["Garage shelf", "Loft"])
        XCTAssertEqual(peopleFromRows(back.shared).map(\.name), ["Jonas"])
    }

    func testAFactoryLibraryWritesNoSettingsLists() {
        let file = LibraryTests.sample().backupFile()
        XCTAssertNil(file.prefs, "a backup must never plant defaults on another device as data")
        XCTAssertEqual(file.phases, [], "the factory timeline is not data")
    }

    func testTheFileIsWhatTheWebAppWrites() throws {
        let data = LibraryTests.sample().backupData(exportedAt: "2026-09-22T07:00:00.000Z")
        let json = try JSONValue.parse(data)
        XCTAssertTrue(BackupFile.looksLikeBackup(json))
        for key in ["lists", "events", "actions", "kits", "phases", "things", "photos", "exportedAt"] {
            XCTAssertNotNil(json[key], "missing \(key)")
        }
        XCTAssertEqual(Library.backupFileName(on: "2026-09-22"), "ams-packing-list-backup-2026-09-22.json")
    }

    func testSettingALineAsideLeavesTheCounts() {
        var lib = LibraryTests.sample()
        let trip = lib.trips[0]
        let before = progress(trip.entries)
        XCTAssertTrue(lib.setAside(true, tripId: trip.id, entryId: trip.entries[0].id))
        let after = progress(lib.trips[0].entries)
        XCTAssertEqual(after.total, before.total - 1)
        XCTAssertEqual(after.aside, 1)
        XCTAssertTrue(lib.setAside(false, tripId: trip.id, entryId: trip.entries[0].id))
        XCTAssertEqual(progress(lib.trips[0].entries), before)
    }

    func testCountsNameEveryTable() {
        let counts = LibraryTests.sample().counts
        XCTAssertEqual(counts.map(\.table), Table.allCases)
        XCTAssertEqual(counts.first { $0.table == .items }?.count, 2)
    }
}
