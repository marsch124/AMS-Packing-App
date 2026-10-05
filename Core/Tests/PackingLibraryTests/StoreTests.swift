import XCTest
import PackingCore
@testable import PackingLibrary

/// The store, the import door and what a restore keeps — the spec pass, 2026-10-05.
/// Each test is played the way the app plays it (`StoreSession`, `Importer.read`,
/// `Importer.firstImport`, `Importer.restoring` are the very calls LibraryModel makes).
/// Invented data only — this repository is public.
final class StoreTests: XCTestCase {

    override func setUp() { PackingEnv.freeze() }
    override func tearDown() {
        PackingEnv.reset()
        _ = setPhases(DEFAULT_PHASES)
        _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }

    /// A file with his own timeline and his own conditions — not the live ones.
    private func fileWithItsOwnChoices() -> Data {
        var lib = LibraryTests.sample()
        var steps = DEFAULT_PHASES
        steps.append(newPhase("Load the canoe", steps.map(\.id)))
        lib.phases = setPhases(steps)
        lib.shared = conditionsToRows([ItemCondition(id: "mint", label: "Mint", tone: "", replace: false),
                                       ItemCondition(id: "tired", label: "Tired", tone: "warn", replace: true)])
        let data = lib.backupData(exportedAt: "2026-10-05T07:00:00.000Z")
        _ = setPhases(DEFAULT_PHASES)
        _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
        return data
    }

    // MARK: - Looking at a file changes nothing (item 4)

    /// The restore preview — of a rescue copy too — read the file through the import,
    /// and the file's "When" steps and conditions stayed live after Cancel.
    func testLookingAtAFileLeavesTheLiveWhenStepsAndConditionsAlone() throws {
        let data = fileWithItsOwnChoices()
        var mine = DEFAULT_PHASES
        mine.append(newPhase("Water the plants", mine.map(\.id)))
        let live = setPhases(mine)
        let liveConditions = setItemConditions([ItemCondition(id: "fine", label: "Fine", tone: "", replace: false)])

        let (file, _) = try Importer.read(data)
        XCTAssertTrue(file.phases.contains { $0.label == "Load the canoe" }, "the file's own timeline was not read")
        XCTAssertEqual(PHASES, live, "looking at a file changed the live \"When\" steps")
        XCTAssertEqual(ITEM_CONDITIONS, liveConditions, "looking at a file changed the live conditions")

        // Whoever STORES it installs it — and only then.
        file.installLiveChoices()
        XCTAssertTrue(PHASES.contains { $0.label == "Load the canoe" })
        XCTAssertEqual(ITEM_CONDITIONS.map(\.id), ["mint", "tired"])
    }

    // MARK: - An empty device stays empty after a check-in (item 3)

    func testAnEmptyDeviceThatHasCheckedInStillTakesItsBackup() throws {
        var device = Library()
        device.checkIn(device: "iPhone", at: "2026-10-05T06:00:00.000Z")
        device.checkIn(device: "Mac", at: "2026-10-05T06:30:00.000Z")       // arrived through iCloud
        XCTAssertTrue(device.isEmpty, "a check-in made an empty device look like a library")
        XCTAssertTrue(Library(records: device.records()).isEmpty, "…after a reload too")

        let data = LibraryTests.sample().backupData(exportedAt: "2026-10-05T07:00:00.000Z")
        let (imported, report) = try Importer.firstImport(data, onto: device)
        XCTAssertTrue(report.isFaithful)
        XCTAssertFalse(imported.isEmpty)
        XCTAssertEqual(imported.lastCheckIn(device: "iPhone"), "2026-10-05T06:00:00.000Z", "the import deleted a check-in")
        XCTAssertEqual(imported.lastCheckIn(device: "Mac"), "2026-10-05T06:30:00.000Z", "the import deleted a check-in")
        XCTAssertNotNil(imported.meta["import"], "the import left no mark")
    }

    /// The door's refusals, in the order the app meets them.
    func testTheImportDoorRefusesWhatItMust() throws {
        let file = LibraryTests.sample().backupData(exportedAt: "2026-10-05T07:00:00.000Z")
        XCTAssertThrowsError(try Importer.firstImport(Data("{\"hello\":1}".utf8), onto: Library())) {
            XCTAssertEqual($0 as? Importer.Refusal, .notABackup)
            XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "That is not an AMS Packing backup file.")
        }
        XCTAssertThrowsError(try Importer.firstImport(Data("not json".utf8), onto: Library())) {
            XCTAssertEqual($0 as? Importer.Refusal, .notABackup)
        }
        // Anything of his — one template, one place, one to-do — and it is refused.
        var holding = Library()
        _ = holding.addAction(text: "Buy a map")
        XCTAssertThrowsError(try Importer.firstImport(file, onto: holding)) {
            XCTAssertEqual($0 as? Importer.Refusal, .alreadyImported)
            XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "This library has already been imported into.")
        }
        // A file whose stored things disagree with its own templates is refused whole.
        var json = try JSONValue.parse(file).objectValue!
        var things = json[Library.backupItemsKey]!.arrayValue!
        var first = things[0].objectValue!
        first["consumable"] = .bool(!(first["consumable"]?.boolValue ?? false))
        things[0] = .object(first)
        json[Library.backupItemsKey] = .array(things)
        let bent = Data(JSONValue.object(json).text().utf8)
        XCTAssertThrowsError(try Importer.read(bent)) {
            guard case .notFaithful(let n)? = $0 as? Importer.Refusal else { return XCTFail("not refused as unfaithful: \($0)") }
            XCTAssertGreaterThan(n, 0)
        }
        XCTAssertThrowsError(try Importer.firstImport(bent, onto: Library()))
    }

    /// A file holding only ONE of the two keys this app writes is rebuilt from its
    /// rows, the way the web app's file is — and still comes back the same.
    func testAFileWithOnlyOneOfTheTwoKeysIsRebuiltFromItsRows() throws {
        let lib = BackupTests.richer()
        for key in [Library.backupItemsKey, Library.backupPlacesKey] {
            var file = lib.backupFile(exportedAt: "2026-10-05T07:00:00.000Z")
            file.extra[key] = nil
            let (back, report) = try Importer.read(Data(file.json.text(pretty: true).utf8))
            XCTAssertFalse(report.asStored, "\(key) missing: taken as stored")
            XCTAssertTrue(report.isFaithful, "\(key) missing: " + report.mismatches.joined(separator: "; "))
            XCTAssertEqual(back.resolvedTemplates(), lib.resolvedTemplates(), "\(key) missing")
        }
    }

    // MARK: - What a restore keeps

    /// Exactly the file — and the devices' check-ins, which are about the devices.
    func testARestoreKeepsTheDevicesCheckInsAndNothingElseOfWhatWasThere() throws {
        var device = RestoreTestsSupport.before()
        device.checkIn(device: "Mac", at: "2026-10-05T06:30:00.000Z")
        let (file, _) = try Importer.read(RestoreTestsSupport.small().backupData(exportedAt: "2026-10-05T07:00:00.000Z"))
        let after = Importer.restoring(file, over: device)
        XCTAssertEqual(after.lastCheckIn(device: "Mac"), "2026-10-05T06:30:00.000Z", "the restore told the Mac it never checked in")
        XCTAssertEqual(BackupTests.differences(file, after), [], "the restore kept something else of what was there")
        XCTAssertTrue(after.trips.isEmpty)
    }

    // MARK: - The store (item 29: reload, commit and a refusing store had no test)

    /// A store that can hold twins, as CloudKit can, and can refuse a write.
    final class TwinStore: LibraryStore {
        var records: [StoredRecord]
        var refuse = false
        var log: [RecordChanges] = []
        var onRemoteChange: (() -> Void)?
        init(_ records: [StoredRecord]) { self.records = records }
        func loadAll() throws -> [StoredRecord] { records }
        func apply(_ changes: RecordChanges) throws {
            if refuse { throw CocoaError(.fileWriteNoPermission) }
            log.append(changes)
            // As CloudStore does: a put updates the first twin and deletes the others.
            for put in changes.puts {
                if let n = records.firstIndex(where: { $0.id == put.id }) {
                    records[n] = put
                    records = records.enumerated().filter { $0.offset == n || $0.element.id != put.id }.map(\.element)
                } else { records.append(put) }
            }
            records.removeAll { changes.deletes.contains($0.id) }
        }
    }

    func testLoadingSettlesTwinsSoBothDevicesHoldTheSame() throws {
        let early = Date(timeIntervalSince1970: 1_000), late = Date(timeIntervalSince1970: 2_000)
        let mine = StoredRecord(table: .phases, key: "prep", json: coercePhase(DEFAULT_PHASES[0]).json, updatedAt: early)
        var renamed = DEFAULT_PHASES[0]; renamed.label = "Get ready"
        let theirs = StoredRecord(table: .phases, key: "prep", json: renamed.json, updatedAt: late)
        let store = TwinStore([mine, theirs])
        let (lib, held) = try StoreSession.load(store)
        XCTAssertEqual(lib.phases.map(\.label), ["Get ready"], "the newer twin did not win")
        XCTAssertEqual(store.records.filter { $0.id == RecordID(.phases, "prep") }.count, 1, "the loser stayed in the store")
        XCTAssertEqual(store.records.first?.json, renamed.json)
        XCTAssertEqual(held, lib.records())
        // A second load writes nothing: there is nothing left to settle.
        let writes = store.log.count
        _ = try StoreSession.load(store)
        XCTAssertEqual(store.log.count, writes)
    }

    func testOnlyTheDifferenceIsStoredAndNothingWhenNothingChanged() throws {
        let lib = LibraryTests.sample()
        let store = TwinStore(lib.records())
        let (loaded, held) = try StoreSession.load(store)
        XCTAssertNil(try StoreSession.save(loaded, held: held, to: store), "an unchanged library was written")
        XCTAssertTrue(store.log.isEmpty)

        var ticked = loaded
        ticked.setChecked(true, tripId: ticked.trips[0].id, entryId: ticked.trips[0].entries[0].id)
        let now = try XCTUnwrap(try StoreSession.save(ticked, held: held, to: store))
        XCTAssertEqual(store.log.last?.puts.map(\.table), [.entries], "a tick is one line record")
        XCTAssertEqual(now, ticked.records())
    }

    /// A store that refuses: nothing is believed written, and the next try writes it all.
    func testAStoreThatRefusesKeepsWhatItHeld() throws {
        let lib = LibraryTests.sample()
        let store = TwinStore(lib.records())
        let (loaded, held) = try StoreSession.load(store)
        var next = loaded
        _ = next.addAction(text: "Mend the tent")
        store.refuse = true
        XCTAssertThrowsError(try StoreSession.save(next, held: held, to: store))
        XCTAssertEqual(Library(records: store.records), loaded, "a refused write changed the store")
        store.refuse = false
        XCTAssertNotNil(try StoreSession.save(next, held: held, to: store))
        XCTAssertEqual(Library(records: store.records).actions.map(\.text), ["Mend the tent"])
    }

    /// A line whose trip was deleted on the other device is not shown — and never
    /// deleted by a later change here, so a line still on its way is never lost.
    func testRecordsTheLibraryCannotShowAreLeftInTheStore() throws {
        let lib = LibraryTests.sample()
        var line = newItem(name: "Spare paddle")
        line.id = "far-line"
        let orphan = StoredRecord(table: .entries, key: "gone-trip|far-line", parent: "gone-trip", json: line.json)
        let store = TwinStore(lib.records() + [orphan])
        let (loaded, held) = try StoreSession.load(store)
        XCTAssertFalse(held.contains { $0.id == orphan.id })
        var next = loaded
        _ = next.addAction(text: "Wax the skis")
        _ = try StoreSession.save(next, held: held, to: store)
        XCTAssertTrue(store.records.contains { $0.id == orphan.id }, "a line waiting for its trip was deleted")
    }

    // MARK: - What Settings counts (item 15)

    func testCountsAreWhatTheRecordsWouldBeWithoutWritingThem() {
        var lib = BackupTests.richer()
        lib.photos = [PhotoRecord(id: "p1", data: "data:image/jpeg;base64,AQID", createdAt: "2026-10-01T09:00:00.000Z"),
                      PhotoRecord(id: "", data: "data:image/jpeg;base64,AQID", createdAt: "")]
        lib.items.append(newItem(name: "No id yet")); lib.items[lib.items.count - 1].id = ""
        lib.checkIn(device: "Mac")
        lib.meta[""] = "never written"
        _ = lib.addAction(text: "Buy wax")
        let written = lib.records()
        for row in lib.counts {
            XCTAssertEqual(row.count, written.filter { $0.table == row.table }.count, row.table.rawValue)
        }
    }

    // MARK: - A photo read the way a browser reads it (item 27)

    func testAPhotoWrittenLooselyKeepsItsPicture() {
        let bytes = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0xFB, 0xFF, 0x4A, 0x46])
        let exact = bytes.base64EncodedString()                     // "/9j/4AAQ+/9KRg==": "+", "/" and padding
        let urlSafe = exact.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-")
        let shapes = [
            "data:image/jpeg;base64,\(exact)",
            "data:image/jpeg;base64,\(exact.prefix(8))\r\n\(exact.dropFirst(8))",       // a line break inside
            "data:image/jpeg;base64,\(exact.replacingOccurrences(of: "=", with: ""))",  // no padding
            "data:image/jpeg;base64,\(urlSafe)",                                         // web-safe letters
            "data:image/jpeg," + bytes.map { String(format: "%%%02X", $0) }.joined(),   // not base64 at all
        ]
        for (n, shape) in shapes.enumerated() {
            var lib = Library()
            lib.photos = [PhotoRecord(id: "p\(n)", data: shape, createdAt: "2026-10-01T09:00:00.000Z")]
            let back = Library(records: lib.records())
            XCTAssertEqual(back.photos.first?.data, "data:image/jpeg;base64,\(exact)", "shape \(n) lost its picture")
        }
        // A data URL without a type reads as a picture, not as a type called "base64".
        XCTAssertEqual(Library.bytes(fromDataURL: "data:;base64,\(exact)").1, "image/jpeg")
        // And what is no picture at all still is none.
        XCTAssertNil(Library.bytes(fromDataURL: "data:image/jpeg;base64,***").0)
        XCTAssertNil(Library.bytes(fromDataURL: "https://example.invalid/a.jpg").0)
    }

    // MARK: - An older file gives each thing its own note back (item 30)

    func testAnOlderFileGivesEachThingItsOwnNoteAndAmountBack() throws {
        var lib = BackupTests.richer()
        // The headlamp's note is its own (on two templates); spare batteries carry a
        // DIFFERENT note on each of their places — those stay the places'.
        let lamp = lib.items.first { $0.name == "Headlamp" }!.id
        _ = lib.updateThing(id: lamp) { $0.qty = "1" }
        let spare = lib.items.first { $0.name == "Spare batteries" }!.id
        let places = lib.memberships.indices.filter { lib.memberships[$0].itemId == spare }
        XCTAssertEqual(places.count, 2)
        lib.memberships[places[0]].note = "AA"
        lib.memberships[places[1]].note = "AAA"

        let (back, report) = try Importer.read(BackupTests.olderFile(lib, exportedAt: "2026-10-05T07:00:00.000Z"))
        XCTAssertFalse(report.asStored)
        XCTAssertTrue(report.isFaithful, report.mismatches.joined(separator: "; "))
        XCTAssertEqual(back.resolvedTemplates(), lib.resolvedTemplates())
        let backLamp = back.items.first { $0.id == lamp }!
        XCTAssertEqual([backLamp.note, backLamp.qty], ["spare strap in the lid", "1"], "the thing's own note and qty")
        XCTAssertEqual(back.memberships.filter { $0.itemId == lamp }.map { [$0.note, $0.qty] }, [["", ""], ["", ""]],
                       "the thing's note and qty were pinned onto each of its places")
        XCTAssertEqual(back.items.first { $0.id == spare }?.note, "")
        XCTAssertEqual(Set(back.memberships.filter { $0.itemId == spare }.map(\.note)), ["AA", "AAA"],
                       "notes that differ per place are the places' own")
        // …so a change to the thing's note reaches its templates again.
        var later = back
        _ = later.updateThing(id: lamp) { $0.note = "new strap" }
        XCTAssertTrue(later.resolvedTemplates().flatMap(\.items).filter { $0.itemId == lamp }.allSatisfy { $0.note == "new strap" })
    }

    // MARK: - A grab list's id comes from the app's id maker (item 19)

    func testANewGrabListsIdComesFromTheAppsIdMaker() {
        PackingEnv.freeze(at: "2026-10-05T07:00:00.000Z", idPrefix: "made-")
        var lib = Library()
        XCTAssertEqual(lib.addGrabList(label: "Beach")?.id, "own-made-1")
        XCTAssertEqual(lib.addGrabList(label: "Gym")?.id, "own-made-2")
    }

    // MARK: - What Settings says about backups (items 14 and 17)

    func testSettingsSaysWhenTheLibraryCameFromAFileAndWhenItWasLastSaved() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 7_200)!
        let now = isoMoment("2026-10-05T12:00:00.000Z")!
        XCTAssertNil(LibraryTests.sample().broughtInWords(now: now, calendar: cal), "a library that never came from a file")
        PackingEnv.freeze(at: "2026-10-05T08:15:00.000Z")
        let (back, _) = try Importer.read(LibraryTests.sample().backupData(exportedAt: "2026-09-22T09:00:00.000Z"))
        XCTAssertEqual(back.broughtInWords(now: now, calendar: cal),
                       "Brought in from a backup today 10:15 (the file was saved 22 Sep 11:00).")
        XCTAssertEqual(Library(records: back.records()).broughtInWords(now: now, calendar: cal),
                       back.broughtInWords(now: now, calendar: cal), "the mark travels with the library")
        XCTAssertEqual(back.holdsWords, "2 templates, 2 things and 1 trip")

        XCTAssertNil(Library.lastSavedWords(nil, device: "iPhone"))
        XCTAssertNil(Library.lastSavedWords("", device: "iPhone"))
        XCTAssertEqual(Library.lastSavedWords("2026-10-05T11:05:00.000Z", device: "iPhone", now: now, calendar: cal),
                       "Last saved from this iPhone today 13:05.")
        XCTAssertEqual(Library.lastSavedWords("2026-10-01T21:30:00Z", device: "Mac", now: now, calendar: cal),
                       "Last saved from this Mac 1 Oct 23:30.")
    }
}

/// The two libraries RestoreTests plays with, for the tests above.
enum RestoreTestsSupport {
    static func before() -> Library {
        var lib = Library()
        var base = newList(name: "Everyday", role: "base")
        base.items = [newItem(name: "Keys"), newItem(name: "Wallet")]
        lib.saveTemplate(base)
        var trip = newEvent(name: "Two nights out", startDate: "2026-07-01", endDate: "2026-07-03")
        trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
        lib.trips = [trip]
        _ = lib.addAction(text: "Buy sun cream")
        return lib
    }
    static func small() -> Library {
        var lib = Library()
        var day = newList(name: "Day out", role: "base")
        day.items = [newItem(name: "Water bottle"), newItem(name: "Sun hat")]
        lib.saveTemplate(day)
        return lib
    }
}
