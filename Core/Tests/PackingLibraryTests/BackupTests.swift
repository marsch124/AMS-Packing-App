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

    // MARK: - What a resolved row cannot say on its own (the spec pass, 2026-10-05)

    /// The sample, plus what only this app keeps: a bag he said goes in the cabin, one
    /// whose NAME says cabin and he said it does not, a key this build does not know on
    /// a thing (on two templates), a thing on no list with its own note, qty and key,
    /// a key on a trip line, and his icon on a template.
    static func richer() -> Library {
        var lib = LibraryTests.sample()
        _ = lib.setBagCabin(id: lib.addBag(name: "Rolling case")!.id, true)
        _ = lib.setBagCabin(id: lib.addBag(name: "Cabin duffel")!.id, false)
        let lamp = lib.items.first { $0.name == "Headlamp" }!.id
        _ = lib.updateThing(id: lamp) { $0.note = "spare strap in the lid"; $0.extra["inventedKey"] = ["kept": true] }
        let shovel = lib.addThing(name: "Snow shovel")!.id
        _ = lib.updateThing(id: shovel) { $0.note = "by the back door"; $0.qty = "2"; $0.extra["inventedKey"] = 7 }
        lib.trips[0].entries[0].extra["inventedLineKey"] = "kept"
        _ = lib.setTemplateIcon(id: lib.templates.first { $0.name == "Hiking" }!.id, key: "boot")
        return lib
    }

    /// Read bytes the way Settings does before it offers Replace (`inspectBackup`).
    static func read(_ data: Data) throws -> (Library, Importer.Report) {
        let json = try JSONValue.parse(data)
        XCTAssertTrue(BackupFile.looksLikeBackup(json))
        return Importer.library(from: BackupFile(json: json))
    }

    /// Every stored record that is not the same in both — the import marker aside.
    static func differences(_ a: Library, _ b: Library) -> [String] {
        let c = recordChanges(from: a.records(), to: b.records())
        return (c.puts.map { "\($0.table.rawValue)/\($0.key)" } + c.deletes.map { "\($0.table.rawValue)/\($0.key)" })
            .filter { !$0.hasPrefix("meta/") }.sorted()
    }

    /// A file as this app wrote it before it carried its things as stored — the copies
    /// already kept before a restore on his devices are like this.
    static func olderFile(_ lib: Library, exportedAt: String) -> Data {
        var file = lib.backupFile(exportedAt: exportedAt)
        file.extra[Library.backupItemsKey] = nil
        file.extra[Library.backupPlacesKey] = nil
        return Data(file.json.text(pretty: true).utf8)
    }

    func testABackupBringsBackExactlyWhatWasThereCabinAnswersIncluded() throws {
        let lib = BackupTests.richer()
        let data = lib.backupData(exportedAt: "2026-10-05T07:00:00.000Z")
        PackingEnv.freeze(at: "2026-10-05T09:00:00.000Z", idPrefix: "later-")   // the restore happens later
        let (back, report) = try BackupTests.read(data)
        XCTAssertTrue(report.isFaithful, "refused: " + report.mismatches.joined(separator: "; "))
        XCTAssertTrue(report.asStored, "a file this app wrote is taken as stored")
        XCTAssertEqual(BackupTests.differences(lib, back), [], "the restore is not exactly what was there")
        // …and in his words.
        XCTAssertTrue(Library.isCabinBag(back.items.first { $0.name == "Rolling case" }!))
        XCTAssertFalse(Library.isCabinBag(back.items.first { $0.name == "Cabin duffel" }!), "his NO beats the name")
        let lamp = back.items.first { $0.name == "Headlamp" }!
        XCTAssertEqual(lamp.extra["inventedKey"], ["kept": true])
        XCTAssertEqual(lamp.note, "spare strap in the lid", "the thing's own note stays the thing's")
        XCTAssertEqual(back.memberships.filter { $0.itemId == lamp.id }.map(\.note), ["", ""],
                       "…and is not pinned onto each of its places")
        let shovel = back.items.first { $0.name == "Snow shovel" }!
        XCTAssertEqual([shovel.note, shovel.qty], ["by the back door", "2"])
        XCTAssertEqual(back.trips[0].entries[0].extra["inventedLineKey"], "kept")
        XCTAssertEqual(back.chosenIcon(templateId: lib.templates.first { $0.name == "Hiking" }!.id), "boot")
    }

    /// The web app reads `lists` and `things`; the two keys only this app reads must not
    /// change what it sees.
    func testTheWebAppStillFindsEverythingWhereItLooks() throws {
        let lib = BackupTests.richer()
        let json = try JSONValue.parse(lib.backupData(exportedAt: "2026-10-05T07:00:00.000Z"))
        XCTAssertEqual(json["lists"], .array(lib.resolvedTemplates().map(\.json)))
        XCTAssertEqual(json["things"], .array(lib.thingsOnNoList().map(\.json)))
        XCTAssertEqual(json[Library.backupItemsKey]?.arrayValue?.count, lib.items.count)
        XCTAssertEqual(json[Library.backupPlacesKey]?.arrayValue?.count, lib.memberships.count)
    }

    /// The copies kept before a restore on his devices were written before the things
    /// travelled as stored. They were REFUSED once a bag had a cabin answer ("did not
    /// come back the same": the rebuild left every row's `extra` behind). They must come
    /// back with every answer the rows carry.
    func testAnOlderBackupComesBackWithItsCabinAnswersAndUnknownKeys() throws {
        let lib = BackupTests.richer()
        let data = BackupTests.olderFile(lib, exportedAt: "2026-10-05T07:00:00.000Z")
        PackingEnv.freeze(at: "2026-10-05T09:00:00.000Z", idPrefix: "later-")
        let (back, report) = try BackupTests.read(data)
        XCTAssertTrue(report.isFaithful, "refused: " + report.mismatches.joined(separator: "; "))
        XCTAssertFalse(report.asStored, "an older file is rebuilt from its rows")
        XCTAssertEqual(back.resolvedTemplates(), lib.resolvedTemplates())
        XCTAssertTrue(Library.isCabinBag(back.items.first { $0.name == "Rolling case" }!))
        XCTAssertFalse(Library.isCabinBag(back.items.first { $0.name == "Cabin duffel" }!))
        XCTAssertEqual(back.items.first { $0.name == "Headlamp" }?.extra["inventedKey"], ["kept": true])
        let shovel = back.items.first { $0.name == "Snow shovel" }!
        XCTAssertEqual([shovel.note, shovel.qty], ["by the back door", "2"], "a thing on no list keeps its own note")
        XCTAssertEqual(shovel.extra["inventedKey"], 7)
        XCTAssertEqual(back.trips, lib.trips)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: back.templates.map { ($0.id, $0.updatedAt) }),
                       Dictionary(uniqueKeysWithValues: lib.templates.map { ($0.id, $0.updatedAt) }),
                       "a restore is not an edit: each template keeps when it was last changed")
    }

    /// Worth a look says "a thing sits on a list that no longer exists" and suggests a
    /// backup and a restore. That thing was in neither `lists` nor `things`, so the cure
    /// lost it. Now it comes back on no list, and the broken place does not.
    func testAThingWhoseOnlyListIsGoneSurvivesABackup() throws {
        var lib = LibraryTests.sample()
        var gone = newList(name: "Kayaking")
        gone.items = [newItem(name: "Paddle leash", storage: "Garage")]
        lib.saveTemplate(gone)
        lib.templates.removeAll { $0.name == "Kayaking" }   // deleted on the other device; its place stayed
        XCTAssertEqual(lib.worries().count, 1)
        XCTAssertTrue(lib.backupFile().things.contains { $0.name == "Paddle leash" }, "the web app would lose it too")

        // A file with a broken place written into it by hand is cured all the same.
        var withBroken = lib.backupFile(exportedAt: "2026-10-05T07:00:00.000Z")
        withBroken.extra[Library.backupPlacesKey] = .array((withBroken.extra[Library.backupPlacesKey]?.arrayValue ?? [])
            + lib.memberships.filter { !lib.templates.map(\.id).contains($0.templateId) }.map(\.json))
        let files = ["as stored": lib.backupData(exportedAt: "2026-10-05T07:00:00.000Z"),
                     "older": BackupTests.olderFile(lib, exportedAt: "2026-10-05T07:00:00.000Z"),
                     "broken place": Data(withBroken.json.text().utf8)]
        for (kind, data) in files.sorted(by: { $0.key < $1.key }) {
            let (back, report) = try BackupTests.read(data)
            XCTAssertTrue(report.isFaithful, "\(kind): " + report.mismatches.joined(separator: "; "))
            XCTAssertEqual(back.items.first { $0.name == "Paddle leash" }?.storage, "Garage", "\(kind): the thing was lost")
            XCTAssertTrue(back.worries().isEmpty, "\(kind): the place on the gone list came back")
        }
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
