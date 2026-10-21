import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// His checks 6 and 7 on 0.96 (21 Oct 2026), both devices synced: what each device saved before
/// the other device's save had arrived. iCloud keeps ONE version of a record — the last one sent —
/// so two saves of the same record that cross keep only one of them; a record made on both
/// devices under one fixed key is two records (twins) until a load settles them.
/// Invented data only — this repository is public.
final class CrossingSavesTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-21T08:00:00.000Z") }
    override func tearDown() {
        PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES); _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }

    // MARK: - Two devices and iCloud between them

    /// One device's store. Its rows have names of their own, as iCloud names every record alike on
    /// both devices; a row this device makes is named after it. Writes and deletes wait in `sent`
    /// until `Cloud.send` takes them; twins of a put are settled as `CloudStore.apply` does.
    final class Device: LibraryStore {
        let name: String
        var rows: [(name: String, record: StoredRecord)] = []
        var waiting: Set<String> = []
        var deleted: Set<String> = []
        var onRemoteChange: (() -> Void)?
        private var made = 0
        init(_ name: String) { self.name = name }
        func loadAll() throws -> [StoredRecord] { rows.map(\.record) }
        func apply(_ changes: RecordChanges) throws {
            for put in changes.puts {
                let twins = rows.indices.filter { rows[$0].record.id == put.id }
                guard !twins.isEmpty else {
                    made += 1
                    rows.append((name: "\(name)-\(made)", record: put)); waiting.insert("\(name)-\(made)")
                    continue
                }
                let plan = planTwins(twins.map { rows[$0].record }, storing: put)
                for n in plan.write { rows[twins[n]].record = put; waiting.insert(rows[twins[n]].name) }
                let gone = Set(plan.delete.map { twins[$0] })
                for n in gone { deleted.insert(rows[n].name) }
                rows = rows.enumerated().filter { !gone.contains($0.offset) }.map(\.element)
            }
            for id in changes.deletes {
                for r in rows where r.record.id == id { deleted.insert(r.name) }
                rows.removeAll { $0.record.id == id }
            }
        }
    }

    /// iCloud: one version of each record, the last one sent.
    final class Cloud {
        var rows: [String: StoredRecord] = [:]
        var gone: Set<String> = []
        /// What the device wrote goes up; a record sent later replaces it whole.
        func send(_ d: Device) {
            for n in d.waiting { if let r = d.rows.first(where: { $0.name == n })?.record, !gone.contains(n) { rows[n] = r } }
            for n in d.deleted { rows[n] = nil; gone.insert(n) }
            d.waiting = []; d.deleted = []
        }
        /// What iCloud holds comes down, record by record, over what the device holds.
        func bring(_ d: Device) {
            for (n, r) in rows.sorted(by: { $0.key < $1.key }) {
                if let k = d.rows.firstIndex(where: { $0.name == n }) { d.rows[k].record = r } else { d.rows.append((name: n, record: r)) }
            }
            d.rows.removeAll { gone.contains($0.name) }
        }
    }

    /// Both devices hold `start`, synced; each loaded it.
    private func twoDevices(_ start: Library) throws -> (Cloud, Device, Device) {
        let cloud = Cloud(), first = Device("iphone"), mac = Device("mac")
        try first.apply(RecordChanges(puts: start.records()))
        cloud.send(first)
        cloud.bring(mac)
        return (cloud, first, mac)
    }

    /// After the saves: everything sent, brought to both, loaded (which settles twins and may write),
    /// sent and brought again, and loaded — what each device then shows.
    private func settle(_ cloud: Cloud, _ a: Device, _ b: Device) throws -> (Library, Library) {
        cloud.bring(a); cloud.bring(b)
        _ = try StoreSession.load(a); _ = try StoreSession.load(b)
        cloud.send(a); cloud.send(b)
        cloud.bring(a); cloud.bring(b)
        return (try StoreSession.load(a).library, try StoreSession.load(b).library)
    }

    /// A template "Hiking" with a Torch and a Map.
    private func hiking() -> Library {
        var lib = Library()
        lib.saveTemplate(newList(name: "Hiking"))
        let t = lib.templates.first { $0.name == "Hiking" }!.id
        for name in ["Torch", "Map"] { _ = lib.addToTemplate(templateId: t, name: name) }
        return lib
    }
    private func ids(_ lib: Library) -> (template: String, torch: String, map: String) {
        (lib.templates.first { $0.name == "Hiking" }!.id,
         lib.items.first { $0.name == "Torch" }!.id, lib.items.first { $0.name == "Map" }!.id)
    }
    /// The name the template gives the thing's section — as every screen reads it — and its id.
    private func sectionOf(_ lib: Library, _ itemId: String) -> (id: String, name: String) {
        let t = lib.templates.first { $0.name == "Hiking" }!
        let id = lib.memberships.first { $0.templateId == t.id && $0.itemId == itemId }?.section ?? ""
        return (id, sectionName(t, id))
    }

    // MARK: - Check 6: a section made on each device

    /// Mac: the template's page open. iPhone: a line's Section → "iPhone test" → Done. Mac, before
    /// that arrived: another line's Section → "Mac test" → Done. Both saved the template record (its
    /// sections are one field of it); iCloud kept the one sent last. The lines are records of their
    /// own: the Torch's still named the iPhone's section — which the template no longer had, so the
    /// row showed the section's id. Now the line's record carries its section's name, and a load gives
    /// the template the section back. Whichever device's template is sent last.
    func testASectionMadeOnEachDeviceKeepsItsNameWhenTheTemplatesCross() throws {
        for macLast in [true, false] {
            let start = hiking()
            let (t, torch, map) = ids(start)
            let (cloud, iPhone, mac) = try twoDevices(start)

            var phone = try StoreSession.load(iPhone)
            XCTAssertTrue(phone.library.setThingSection(itemId: torch, templateId: t, section: "", newSection: "iPhone test"))
            _ = try StoreSession.save(phone.library, held: phone.held, to: iPhone)

            // The Mac's page, on its copy; the iPhone's change has not arrived.
            let live = try StoreSession.load(mac)
            var page = live.library
            XCTAssertTrue(page.setThingSection(itemId: map, templateId: t, section: "", newSection: "Mac test"))
            _ = try StoreSession.save(live.library.applyingPage(from: live.library, to: page), held: live.held, to: mac)

            if macLast { cloud.send(iPhone); cloud.send(mac) } else { cloud.send(mac); cloud.send(iPhone) }
            let (onPhone, onMac) = try settle(cloud, iPhone, mac)
            for (lib, device) in [(onPhone, "iPhone"), (onMac, "Mac")] {
                XCTAssertEqual(sectionOf(lib, torch).name, "iPhone test",
                               "Mac last \(macLast): on the \(device) the iPhone's section lost its name — the Torch's section reads \"\(sectionOf(lib, torch).name)\" (its id \(sectionOf(lib, torch).id))")
                XCTAssertEqual(sectionOf(lib, map).name, "Mac test",
                               "Mac last \(macLast): on the \(device) the Mac's section lost its name")
                XCTAssertEqual(Set(lib.templates.first { $0.id == t }!.sections.map(\.name)), ["iPhone test", "Mac test"],
                               "Mac last \(macLast): the \(device)'s template does not hold both sections")
            }
        }
    }

    /// Both devices made a section of the SAME name: the line whose section is given back joins the
    /// one the template has — one heading, both lines under it.
    func testTheSameSectionMadeOnEachDeviceIsOneHeading() throws {
        let start = hiking()
        let (t, torch, map) = ids(start)
        let (cloud, iPhone, mac) = try twoDevices(start)
        var phone = try StoreSession.load(iPhone)
        XCTAssertTrue(phone.library.setThingSection(itemId: torch, templateId: t, section: "", newSection: "Lights"))
        _ = try StoreSession.save(phone.library, held: phone.held, to: iPhone)
        var onMacNow = try StoreSession.load(mac)
        XCTAssertTrue(onMacNow.library.setThingSection(itemId: map, templateId: t, section: "", newSection: "Lights"))
        _ = try StoreSession.save(onMacNow.library, held: onMacNow.held, to: mac)
        cloud.send(iPhone); cloud.send(mac)
        let (onPhone, onMac) = try settle(cloud, iPhone, mac)
        for lib in [onPhone, onMac] {
            XCTAssertEqual(lib.templates.first { $0.id == t }!.sections.map(\.name), ["Lights"], "two headings of one name")
            XCTAssertEqual(sectionOf(lib, torch).id, sectionOf(lib, map).id, "the two lines are not under one heading")
        }
    }

    /// A line whose section's name is nowhere (stored before 0.97 — his "mvho3cjj-0-r6dbge"): it
    /// reads under no section, never as an id; nothing is written for it.
    func testALineWhoseSectionNameIsNowhereReadsUnderNoSection() throws {
        var lib = hiking()
        let (t, torch, _) = ids(lib)
        XCTAssertTrue(lib.setThingSection(itemId: torch, templateId: t, section: "", newSection: "Lights"))
        let lost = lib.templates.first { $0.id == t }!.sections[0].id
        let store = Device("iphone")
        try store.apply(RecordChanges(puts: Self.withoutSection(lib.records(), template: t)))
        store.waiting = []
        let (loaded, _) = try StoreSession.load(store)
        let row = loaded.memberships.first { $0.templateId == t && $0.itemId == torch }!
        XCTAssertEqual(row.section, "", "the Torch's row still names a section the template does not have: \(row.section) (was \(lost))")
        XCTAssertTrue(loaded.templates.first { $0.id == t }!.sections.isEmpty, "a section was made up")
        XCTAssertTrue(store.waiting.isEmpty, "loading wrote \(store.waiting)")
    }

    /// The same line on a trip still ahead, made while the section was there, says its name: the
    /// template gets the section back under that name.
    func testASectionsNameIsFoundOnATripLineAhead() throws {
        var lib = hiking()
        let (t, torch, _) = ids(lib)
        XCTAssertTrue(lib.setThingSection(itemId: torch, templateId: t, section: "", newSection: "Lights"))
        var trip = newEvent(name: "Weekend in the hills")
        trip.activities = [t]
        trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
        lib.trips = [trip]
        XCTAssertEqual(lib.trips[0].entries.first { $0.sourceItemId == torch }?.section, "Lights")
        let store = Device("iphone")
        try store.apply(RecordChanges(puts: Self.withoutSection(lib.records(), template: t)))
        let (loaded, _) = try StoreSession.load(store)
        XCTAssertEqual(sectionOf(loaded, torch).name, "Lights", "the section's name on the trip line was not used")
    }

    /// The records as a build before 0.97 stored them, after the template lost its section: no line
    /// carries its section's name, and the template's sections are empty.
    static func withoutSection(_ records: [StoredRecord], template: String) -> [StoredRecord] {
        records.map { r in
            var r = r
            if r.table == .memberships, var o = r.json.objectValue { o["sectionCopy"] = nil; r.json = .object(o) }
            if r.table == .templates, r.key == template, var o = r.json.objectValue { o["sections"] = .array([]); r.json = .object(o) }
            return r
        }
    }

    // MARK: - Check 7: a grab list edited on each device

    /// Mac: a grab list's Edit open. iPhone: the same list's Edit → ✕ on Goggles → Save. Mac, before
    /// that arrived: ✕ on Towel → Save. The list had never been changed, so neither device had a
    /// record of it: each made its own under the list's fixed key — twins — and the load kept only the
    /// newer, so the other device's removal came back. Now twins of a grab list are merged as two
    /// edits of the original list: both removals stay. Whichever device sends first.
    func testAGrabListEditedOnEachDeviceBeforeEitherStoredItKeepsBothRemovals() throws {
        for macLast in [true, false] {
            let swim = GRAB_FACTORY[0]
            let (cloud, iPhone, mac) = try twoDevices(hiking())
            let opened = swim.lines

            var phone = try StoreSession.load(iPhone)
            XCTAssertTrue(phone.library.saveGrabEdit(id: swim.id, opened: opened, openedSometimes: [],
                                                     lines: opened.filter { $0.name != "Goggles" }, sometimes: []))
            _ = try StoreSession.save(phone.library, held: phone.held, to: iPhone)
            PackingEnv.freeze(at: "2026-10-21T08:01:00.000Z")   // the Mac's Save a minute later
            var onMacNow = try StoreSession.load(mac)
            XCTAssertTrue(onMacNow.library.saveGrabEdit(id: swim.id, opened: opened, openedSometimes: [],
                                                        lines: opened.filter { $0.name != "Towel" }, sometimes: []))
            _ = try StoreSession.save(onMacNow.library, held: onMacNow.held, to: mac)

            if macLast { cloud.send(iPhone); cloud.send(mac) } else { cloud.send(mac); cloud.send(iPhone) }
            let (onPhone, onMac) = try settle(cloud, iPhone, mac)
            for (lib, device) in [(onPhone, "iPhone"), (onMac, "Mac")] {
                let items = lib.grabList(id: swim.id)!.items
                XCTAssertFalse(items.contains("Goggles"), "Mac last \(macLast): on the \(device) the iPhone's removal came back: \(items)")
                XCTAssertFalse(items.contains("Towel"), "Mac last \(macLast): on the \(device) the Mac's removal came back: \(items)")
                XCTAssertEqual(items, swim.items.filter { $0 != "Goggles" && $0 != "Towel" }, "Mac last \(macLast): \(device)")
            }
            let left = Set(cloud.rows.values.filter { $0.id == RecordID(.shared, "grab:swim") }.map(\.json))
            XCTAssertEqual(left.count, 1, "Mac last \(macLast): iCloud holds different versions of the list: \(left)")
            PackingEnv.freeze(at: "2026-10-21T08:00:00.000Z")
        }
    }

    /// The other way round as well: a name each device ADDED to the list stays, and a new name on its
    /// tile from one device is kept with the other device's change.
    func testAGrabListsTwinsKeepWhatEachDeviceAddedAndItsNewName() throws {
        let swim = GRAB_FACTORY[0]
        var phone = Library(), mac = Library()
        XCTAssertTrue(phone.saveGrabList(id: swim.id, lines: swim.lines + [.thing("Fins")]))
        XCTAssertTrue(mac.saveGrabList(id: swim.id, lines: swim.lines.filter { $0.name != "Towel" } + [.thing("Nose clip")]))
        var renamed = phone.shared.first { $0.kind == "grab" }!
        var data = renamed.data.objectValue!; data["label"] = "Pool"; renamed.data = .object(data)
        phone.shared = [renamed]
        let early = phone.records(at: Date(timeIntervalSince1970: 1_000)).filter { $0.table == .shared }
        let late = mac.records(at: Date(timeIntervalSince1970: 2_000)).filter { $0.table == .shared }
        for order in [early + late, late + early] {
            let lib = Library(records: order)
            let list = lib.grabList(id: swim.id)!
            // The newer twin's order (the Mac's), the iPhone's addition put where it stood on the iPhone: last.
            XCTAssertEqual(list.items, swim.items.filter { $0 != "Towel" } + ["Nose clip", "Fins"], "a device's change was lost: \(list.items)")
            XCTAssertEqual(list.label, "Pool", "the iPhone's new name was lost")
        }
    }
}
