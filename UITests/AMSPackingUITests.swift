import XCTest

/// Two tests to begin with, and one more added at a time.
///
/// Every control is found by its accessibility identifier — never by the words
/// on it — so rewording a button can never turn the suite red. The same two
/// tests run on the iPhone simulator and on the Mac.
final class AMSPackingUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// `-uiTesting` = an invented library held in memory: no iCloud, no files, the
    /// same on the simulator, the Mac and GitHub. `-uiTestingEmpty` = nothing at all.
    private func launch(_ mode: String = "-uiTesting") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [mode]
        app.launch()
        // GitHub's runners are slow and shared: a launch can time out there while
        // the same launch is instant here. One more try before giving up.
        if app.state != .runningForeground && !app.wait(for: .runningForeground, timeout: 30) {
            app.launch()
            _ = app.wait(for: .runningForeground, timeout: 60)
        }
        #if os(macOS)
        // Launched by the test runner, the Mac app sometimes comes to the front with
        // NO window (seen 2026-09-21: frontmost, menu bar only; launched normally it
        // always opens one). File ▸ New Window is what he would do too.
        if !app.windows.firstMatch.waitForExistence(timeout: 5) {
            app.typeKey("n", modifierFlags: .command)
            _ = app.windows.firstMatch.waitForExistence(timeout: 5)
        }
        #endif
        return app
    }

    /// A named screen or container. The SAME SwiftUI container is a Group to the Mac,
    /// an Other to the iPhone — and when its content is a scroll view, the iPhone puts
    /// the name on the ScrollView instead (all three found by dumping the tree, not by
    /// guessing). Typed queries only: `descendants(matching: .any)` hangs the suite.
    private func find(_ app: XCUIApplication, _ id: String) -> XCUIElement? {
        for query in [app.otherElements, app.groups, app.scrollViews] {
            let e = query[id]
            if e.exists { return e }
        }
        return nil
    }

    private func appears(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if find(app, id) != nil { return true }
            usleep(200_000)
        } while Date() < deadline
        return false
    }

    private func disappears(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if find(app, id) == nil { return true }
            usleep(200_000)
        } while Date() < deadline
        return false
    }

    private func words(_ e: XCUIElement) -> String {
        // Reading an element that is not there (yet) is a HARD failure in XCTest,
        // not an empty answer — and on GitHub's slow runners a screen can still be
        // building when the first read comes. So: not there = no words yet.
        guard e.exists else { return "" }
        // The Mac reports a text's words as its value, the iPhone as its label.
        return e.label.isEmpty ? (e.value as? String ?? "") : e.label
    }

    /// Selected — and there to ask. Same reason as `words`.
    private func isOn(_ e: XCUIElement) -> Bool { e.exists && e.isSelected }

    /// Keeps a picture of the screen when asked to (tools/shots.sh sets
    /// TEST_RUNNER_SHOTS_DIR) — how a build is LOOKED at on both devices, in
    /// dark mode, before anyone is told it is done.
    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"], !dir.isEmpty else { return }
        #if os(macOS)
        let image = app.windows.firstMatch.screenshot()
        #else
        let image = XCUIScreen.main.screenshot()
        #endif
        // On the Mac the test runner is sandboxed and may only write inside its
        // own container, so fall back to its temporary folder and say where.
        for folder in [URL(fileURLWithPath: dir), FileManager.default.temporaryDirectory] {
            let file = folder.appendingPathComponent("\(name).png")
            if (try? image.pngRepresentation.write(to: file)) != nil {
                print("SHOT \(file.path)")
                return
            }
        }
    }

    /// The app starts, shows Home, and names its version.
    func testStartsOnHomeAndNamesItsVersion() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))

        let version = app.staticTexts["app-version"]
        XCTAssertTrue(version.waitForExistence(timeout: 5))
        // The Mac reports a text's words as its value, the iPhone as its label.
        let shown = version.label.isEmpty ? (version.value as? String ?? "") : version.label
        XCTAssertNotNil(shown.rangeOfCharacter(from: .decimalDigits),
                        "the version marker shows no number: '\(shown)'")
        shot(app, "home")
    }

    /// Every tab opens its own screen — and leaves the previous one.
    func testEveryTabOpensItsScreen() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))

        for name in ["events", "templates", "care", "actions", "settings", "home"] {
            let tab = app.buttons["tab-\(name)"]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "no tab-\(name)")
            tab.tap()
            XCTAssertTrue(appears(app, "screen-\(name)", timeout: 5),
                          "tab-\(name) did not open screen-\(name)")
            if name != "home" {
                XCTAssertNil(find(app, "screen-home"),
                               "Home is still showing behind screen-\(name)")
            }
        }
    }
    /// The Templates tab lists the templates, and one opens to show its things.
    func testATemplateOpensAndCloses() {
        let app = launch()
        app.buttons["tab-templates"].tap()
        XCTAssertTrue(appears(app, "screen-templates"))

        let first = app.buttons["template-row-0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5), "no template is listed")
        XCTAssertTrue(app.buttons["template-row-2"].exists, "the sample library has three templates")
        first.tap()

        XCTAssertTrue(appears(app, "template-detail", timeout: 5), "the template did not open")
        shot(app, "template")
        app.buttons["template-detail-done"].tap()
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5), "the template did not close")
    }

    /// An empty device never decides by itself and never plants starter lists:
    /// it shows the two doors, and nothing else.
    func testAnEmptyDeviceShowsTheTwoDoors() {
        let app = launch("-uiTestingEmpty")
        XCTAssertTrue(app.buttons["first-run-import"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["count-templates"].exists, "an empty device must not look like a library")
        app.buttons["tab-templates"].tap()
        XCTAssertTrue(appears(app, "screen-templates", timeout: 5))
        XCTAssertFalse(app.buttons["template-row-0"].exists, "nothing may be seeded into an empty library")
    }
    /// A tick counts, and it is still there after leaving the trip and coming back.
    func testATickCountsAndStays() {
        let app = launch()
        app.buttons["tab-events"].tap()
        XCTAssertTrue(appears(app, "screen-events"))
        let row = app.buttons["trip-row-0"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "no trip is listed")
        row.tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5), "the trip did not open")

        let progress = app.staticTexts["trip-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        let before = words(progress)
        XCTAssertTrue(before.hasPrefix("0/"), "a fresh trip starts unticked: '\(before)'")

        let line = app.buttons["trip-line-0"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        line.tap()
        XCTAssertTrue(waitUntil { self.words(progress).hasPrefix("1/") }, "the tick did not count: '\(words(progress))'")
        shot(app, "trip")

        app.buttons["trip-done"].tap()
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))
        row.tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["trip-progress"]).hasPrefix("1/") },
                      "the tick was lost on the way out and back: '\(words(app.staticTexts["trip-progress"]))'")
    }

    /// Type into a field and make sure it landed — on a slow Mac runner the first
    /// click has been seen to focus the window and nothing else.
    private func type(_ text: String, into field: XCUIElement) {
        for _ in 0..<3 {
            field.tap()
            field.typeText(text)
            if let v = field.value as? String, v.contains(text) { return }
            field.tap()
            if let v = field.value as? String, !v.isEmpty { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: v.count)) }
        }
        XCTFail("could not type into \(field)")
    }

    /// Scroll until a control is actually on screen. GitHub's Mac runner has a
    /// shorter window than this Mac, and a click on a control below the fold
    /// "succeeds" and does nothing ("trip-activity-0 did not take the tap").
    private func bringIntoView(_ app: XCUIApplication, _ e: XCUIElement) {
        for _ in 0..<8 {
            if e.exists && e.isHittable { return }
            #if os(macOS)
            let scroll = app.scrollViews.firstMatch
            if scroll.exists { scroll.scroll(byDeltaX: 0, deltaY: -250) } else { return }
            #else
            let scroll = app.scrollViews.firstMatch
            if scroll.exists { scroll.swipeUp() } else { app.swipeUp() }
            #endif
            usleep(300_000)
        }
    }

    private func tapVisible(_ app: XCUIApplication, _ e: XCUIElement) {
        bringIntoView(app, e)
        e.tap()
    }

    /// Tap a pill until it reports itself selected. If it never does, say what
    /// the machine actually sees — GitHub's Mac runner has refused this tap in
    /// every run while this Mac takes it every time, and three guesses at the
    /// cause were wrong. Facts first.
    private func select(_ app: XCUIApplication, _ button: XCUIElement) {
        for _ in 0..<3 {
            tapVisible(app, button)
            if waitUntil(timeout: 2, { self.isOn(button) }) { return }
        }
        report(app, button, "did not take the tap")
    }

    private func report(_ app: XCUIApplication, _ e: XCUIElement, _ what: String) {
        var lines = ["TAP-REPORT \(e.identifier.isEmpty ? "\(e)" : e.identifier) \(what)"]
        lines.append("  element: exists=\(e.exists)" + (e.exists ? " hittable=\(e.isHittable) enabled=\(e.isEnabled) selected=\(e.isSelected) frame=\(e.frame) label='\(e.label)'" : ""))
        let create = app.buttons["trip-create"]
        if create.exists { lines.append("  trip-create: enabled=\(create.isEnabled) frame=\(create.frame)") }
        for (n, w) in app.windows.allElementsBoundByIndex.prefix(3).enumerated() { lines.append("  window \(n): frame=\(w.frame)") }
        let scroll = app.scrollViews.firstMatch
        if scroll.exists { lines.append("  scroll: frame=\(scroll.frame)") }
        print(lines.joined(separator: "\n"))
        let tree = app.debugDescription
        print("TAP-REPORT tree (first 8000 chars):\n" + String(tree.prefix(8000)))
        let picture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        picture.name = "tap-report"
        picture.lifetime = .keepAlways
        add(picture)
        XCTFail("\(e.identifier) \(what) — see TAP-REPORT in the log")
    }

    private func waitUntil(timeout: TimeInterval = 5, _ ok: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat { if ok() { return true }; usleep(200_000) } while Date() < deadline
        return ok()
    }

    /// Settings offers a backup, and pressing it opens the place to save it —
    /// a Save window on the Mac, the Files picker on the iPhone.
    func testSettingsOffersABackup() {
        let app = launch()
        app.buttons["tab-settings"].tap()
        XCTAssertTrue(appears(app, "screen-settings"))
        XCTAssertTrue(app.staticTexts["device-count-items"].waitForExistence(timeout: 5), "the device check is missing")
        let save = app.buttons["backup-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "no way to save a backup")
        save.tap()
        let status = app.staticTexts["backup-status"]
        XCTAssertTrue(waitUntil { self.words(status).hasPrefix("Choosing") }, "the save was not started: '\(words(status))'")
        #if os(macOS)
        XCTAssertTrue(waitUntil(timeout: 10) { app.sheets.count > 0 || app.dialogs.count > 0 }, "no Save window opened")
        app.typeKey(.escape, modifierFlags: [])
        #endif
    }
    /// Home builds a trip: a name, one activity, Create — and it opens with lines.
    func testHomeBuildsATrip() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        let field = app.textFields["trip-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no name field")
        type("Test trip", into: field)
        let create = app.buttons["trip-create"]
        XCTAssertTrue(create.exists)
        XCTAssertFalse(create.isEnabled, "nothing to pack for yet — Create must wait")
        select(app, app.buttons["trip-activity-0"])
        XCTAssertTrue(waitUntil { create.isEnabled }, "Create stayed off after a name and an activity")
        tapVisible(app, create)
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5), "the new trip did not open")
        let progress = app.staticTexts["trip-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        let shown = words(progress)
        XCTAssertTrue(shown.hasPrefix("0/") && !shown.hasPrefix("0/0"), "the trip has no lines: '\(shown)'")
        app.buttons["trip-done"].tap()
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))
        app.buttons["tab-events"].tap()
        XCTAssertTrue(appears(app, "screen-events"))
        XCTAssertTrue(app.buttons["trip-row-1"].waitForExistence(timeout: 5), "the new trip is not listed beside the sample one")
    }
    /// A grab list counts what is in hand, refuses "Ready to go" while something
    /// is missing, lets a thing be skipped, and Start over clears it all.
    func testAGrabListCountsRefusesAndClears() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        let button = app.buttons["grab-0"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "no grab buttons on Home")
        button.tap()
        XCTAssertTrue(appears(app, "grab-detail", timeout: 5))
        let count = app.staticTexts["grab-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertTrue(words(count).hasPrefix("0 of"), "a fresh list starts empty: '\(words(count))'")

        app.buttons["grab-item-0"].tap()
        XCTAssertTrue(waitUntil { self.words(count).hasPrefix("1 of") }, "the tick did not count: '\(words(count))'")
        app.buttons["grab-skip-1"].tap()
        XCTAssertTrue(waitUntil { self.words(count).contains("skipped") }, "the skip did not count: '\(words(count))'")

        app.buttons["grab-ready"].tap()
        XCTAssertTrue(app.staticTexts["grab-message"].waitForExistence(timeout: 5), "Ready to go must refuse while things are missing")
        XCTAssertNotNil(find(app, "grab-detail"), "…and stay open")

        app.buttons["grab-reset"].tap()
        XCTAssertTrue(waitUntil { self.words(count).hasPrefix("0 of") && !self.words(count).contains("skipped") }, "Start over did not clear: '\(words(count))'")
        app.buttons["grab-done"].tap()
        XCTAssertTrue(disappears(app, "grab-detail", timeout: 5))
    }
    /// A thing typed while packing joins the trip — and the count.
    func testAThingTypedWhilePackingJoinsTheTrip() {
        let app = launch()
        app.buttons["tab-events"].tap()
        XCTAssertTrue(appears(app, "screen-events"))
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        let before = words(progress)                                  // "0/7"
        let total = Int(before.split(separator: "/").last?.prefix { $0.isNumber } ?? "") ?? -1
        XCTAssertGreaterThan(total, 0, "could not read the total from '\(before)'")

        let field = app.textFields["trip-add-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no field to add a thing")
        let add = app.buttons["trip-add"]
        XCTAssertFalse(add.isEnabled, "Add must wait for a name")
        type("Tripod", into: field)
        XCTAssertTrue(waitUntil { add.isEnabled })
        add.tap()
        XCTAssertTrue(waitUntil { self.words(progress).hasSuffix("/\(total + 1)") }, "the line did not count: '\(words(progress))'")
        XCTAssertTrue(app.buttons["trip-line-\(total)"].waitForExistence(timeout: 5), "the new line is not on the list")
        if let v = field.value as? String { XCTAssertFalse(v.contains("Tripod"), "the field should be empty again") }
    }
    /// A to-do is added, counted, ticked — and stays ticked.
    func testAToDoIsAddedAndTicked() {
        let app = launch()
        app.buttons["tab-actions"].tap()
        XCTAssertTrue(appears(app, "screen-actions"))
        let field = app.textFields["action-add-text"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no field to add a to-do")
        let add = app.buttons["action-add"]
        XCTAssertFalse(add.isEnabled, "Add must wait for a text")
        type("Book the ferry", into: field)
        XCTAssertTrue(waitUntil { add.isEnabled })
        add.tap()
        let row = app.buttons["action-0"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the to-do is not listed")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["actions-count"]).hasPrefix("1 ") }, "not counted: '\(words(app.staticTexts["actions-count"]))'")
        row.tap()
        XCTAssertTrue(waitUntil { self.isOn(row) }, "the tick did not take")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["actions-count"]).hasPrefix("All done") }, "'\(words(app.staticTexts["actions-count"]))'")
        app.buttons["tab-home"].tap()
        app.buttons["tab-actions"].tap()
        XCTAssertTrue(waitUntil(timeout: 10) { self.isOn(app.buttons["action-0"]) }, "the tick was lost on the way out and back")
    }
    /// A thing added to a template is there — and still there after closing and reopening.
    func testAThingAddedToATemplateStays() {
        let app = launch()
        app.buttons["tab-templates"].tap()
        XCTAssertTrue(appears(app, "screen-templates"))
        app.buttons["template-row-1"].tap()                // the second sample template (4 things)
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(app.otherElements["template-item-3"].waitForExistence(timeout: 5) || app.staticTexts["template-item-3"].exists, "expected 4 things")
        XCTAssertFalse(app.otherElements["template-item-4"].exists || app.staticTexts["template-item-4"].exists)

        let field = app.textFields["template-add-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no field to add a thing")
        type("Gaiters", into: field)
        app.buttons["template-add"].tap()
        XCTAssertTrue(waitUntil { app.otherElements["template-item-4"].exists || app.staticTexts["template-item-4"].exists }, "the new thing is not on the list")

        app.buttons["template-detail-done"].tap()
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))
        app.buttons["template-row-1"].tap()
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(waitUntil { app.otherElements["template-item-4"].exists || app.staticTexts["template-item-4"].exists }, "the thing was lost on the way out and back")
    }
}
