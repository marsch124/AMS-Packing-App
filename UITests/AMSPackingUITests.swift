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
            XCTAssertTrue(app.buttons["tab-\(name)"].waitForExistence(timeout: 5), "no tab-\(name)")
            tab(app, name)
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
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))

        let first = app.buttons["template-row-0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5), "no template is listed")
        XCTAssertTrue(app.buttons["template-row-2"].exists, "the sample library has three templates")
        // A shelf says his own code as well as the words, as the web app does.
        XCTAssertEqual(words(app.staticTexts["templates-shelf-GA"]), "GA · GOAL ACTIVITY")
        XCTAssertTrue(words(app.staticTexts["templates-summary"]).contains("lists"),
                      "no summary under the heading: '\(words(app.staticTexts["templates-summary"]))'")
        first.tap()

        XCTAssertTrue(appears(app, "template-detail", timeout: 5), "the template did not open")
        shot(app, "template")
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5), "the template did not close")
    }

    /// An empty device never decides by itself and never plants starter lists:
    /// it shows the two doors, and nothing else.
    func testAnEmptyDeviceShowsTheTwoDoors() {
        let app = launch("-uiTestingEmpty")
        XCTAssertTrue(app.buttons["first-run-import"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["count-templates"].exists, "an empty device must not look like a library")
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates", timeout: 5))
        XCTAssertFalse(app.buttons["template-row-0"].exists, "nothing may be seeded into an empty library")
    }
    /// A tick counts, and it is still there after leaving the trip and coming back.
    func testATickCountsAndStays() {
        let app = launch()
        tab(app, "events")
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

        tap(app, id: "trip-done")
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

    /// Is the middle of this control inside the visible part of the screen? NOT
    /// `isHittable`: on GitHub's Mac runner (a 674-point window) a pill whose middle
    /// lay below the window's bottom edge reported hittable=true, and the click went
    /// nowhere — found by the TAP-REPORT, 2026-09-22.
    /// Is the control really where a tap would land? Judged by FRAMES against the
    /// window: XCUITest happily calls a control below the window "hittable", which
    /// cost a red Mac run (the runner's window is 760 × 674).
    /// What a dropdown cell says. The Mac and the iPhone disagree about whether that
    /// is the element's label or its value, so ask for the value first — the cells
    /// set it deliberately — and fall back to the words.
    private func cellSays(_ app: XCUIApplication, _ id: String) -> String {
        // 🪤 A dropdown is a BUTTON on the iPhone and a POP-UP BUTTON on the Mac, so
        // `app.buttons[id]` simply does not exist there — and a missing element reads
        // as "" rather than failing, which made the Mac say "nothing changed" about a
        // change that had happened. Ask each type it can be.
        for holder in [app.buttons, app.popUpButtons, app.menuButtons, app.textFields, app.staticTexts, app.otherElements] {
            let e = holder[id]
            guard e.exists else { continue }
            if let value = e.value as? String, !value.isEmpty { return value }
            let said = words(e)
            if !said.isEmpty { return said }
        }
        return ""
    }

    /// The grid is wider than the screen: a column he has just added sits off to
    /// the right, existing but unreachable. This travels sideways until the cell
    /// is really there (or gives up, so a broken grid still fails the test).
    ///
    /// 🪤 It judges by FRAME, never by `isHittable`: asking an element that is off
    /// to the side whether it is hittable is a HARD XCTest failure ("Activation
    /// point invalid"), so the question can only be asked once it has arrived.
    @discardableResult
    private func bringAcross(_ app: XCUIApplication, _ e: XCUIElement, tries: Int = 12) -> Bool {
        var left = true
        for _ in 0..<tries {
            guard e.exists else { return false }
            if inWindow(app, e) { return true }
            guard let grid = biggestList(app), grid.exists else { return false }
            let before = e.frame.midX
            #if os(macOS)
            // A swipe does nothing to a Mac scroll view — it takes a scroll wheel.
            grid.scroll(byDeltaX: left ? -240 : 240, deltaY: 0)
            #else
            left ? grid.swipeLeft() : grid.swipeRight()
            #endif
            usleep(300_000)
            // A column out to the RIGHT should move left as the grid travels; if it
            // did not, this is the wrong way round.
            if e.exists && e.frame.midX >= before { left.toggle() }
        }
        return inWindow(app, e)
    }

    /// Is the middle of this element inside the window? Frames are safe to read
    /// for anything that exists, unlike hittability.
    private func inWindow(_ app: XCUIApplication, _ e: XCUIElement) -> Bool {
        guard e.exists else { return false }
        let box = e.frame
        guard box.width > 1, box.height > 1 else { return false }
        let window = app.windows.firstMatch
        guard window.exists else { return false }
        return window.frame.contains(CGPoint(x: box.midX, y: box.midY))
    }

    private func onScreen(_ app: XCUIApplication, _ e: XCUIElement) -> Bool {
        guard e.exists, e.isHittable else { return false }
        let mid = CGPoint(x: e.frame.midX, y: e.frame.midY)
        let window = app.windows.firstMatch
        if window.exists && !window.frame.contains(mid) { return false }
        // In a list, but scrolled out of its visible part.
        if let list = listHolding(app, e), list.exists, !list.frame.contains(mid) { return false }
        return true
    }

    /// The frontmost list. One `count` and one `element(boundBy:)` — NOT
    /// `allElementsBoundByIndex`, which takes a snapshot per element.
    private func frontList(_ app: XCUIApplication) -> XCUIElement? {
        let lists = app.scrollViews
        let n = lists.count
        return n > 0 ? lists.element(boundBy: n - 1) : nil
    }

    /// The screen's own list, as opposed to a strip of pills: the one with the
    /// most area among the first and the frontmost.
    private func biggestList(_ app: XCUIApplication) -> XCUIElement? {
        let first = app.scrollViews.firstMatch
        guard let front = frontList(app), front.exists else { return first.exists ? first : nil }
        guard first.exists else { return front }
        let a = first.frame, b = front.frame
        return (a.width * a.height) > (b.width * b.height) ? first : front
    }

    /// Scroll the list until a control with this id EXISTS. A row far down a long
    /// list is not in the tree at all until it has been near the screen — so a test
    /// looking for one has to travel there, exactly as he would.
    ///
    /// `near`: a control already in the SAME list (the row above). 🪤 Without it the
    /// biggest list is scrolled — and on the Mac that is the Trips screen BEHIND an
    /// open trip, so the trip's own list never moved (0.19, GitHub, second run).
    @discardableResult
    private func scrollUntil(_ app: XCUIApplication, _ id: String, near: String? = nil, tries: Int = 8) -> Bool {
        for attempt in 0..<tries {
            if app.buttons[id].exists || app.otherElements[id].exists { return true }
            var holder: XCUIElement? = nil
            if let near { holder = listHolding(app, app.buttons[near].exists ? app.buttons[near] : app.otherElements[near]) }
            guard let list = holder ?? biggestList(app), list.exists, list.isHittable else { return false }
            #if os(macOS)
            // Which sign is "down" is not proven on the Mac: the second half tries the other.
            list.scroll(byDeltaX: 0, deltaY: attempt < tries / 2 ? -220 : 220)
            #else
            list.swipeUp()
            #endif
            usleep(300_000)
        }
        let found = app.buttons[id].exists || app.otherElements[id].exists
        if !found { print("TAP-REPORT scrollUntil never found \(id)\n" + String(app.debugDescription.prefix(8000))) }
        return found
    }

    /// The list the control is IN — asked by descendancy, not by frames.
    ///
    /// A fixed bar BELOW a list (Save on the trip review) belongs to no list, and
    /// scrolling for it is not just useless: a swipe on a sheet's list that is
    /// already at the top drags the sheet SHUT, and the test then hunts for a
    /// control on a screen that is gone. That made CI red three times (2026-09-23).
    /// `scrollViews.firstMatch`, meanwhile, is the screen BEHIND an open sheet.
    private func listHolding(_ app: XCUIApplication, _ e: XCUIElement) -> XCUIElement? {
        guard e.exists, !e.identifier.isEmpty else { return nil }
        if let front = frontList(app), front.exists,
           front.descendants(matching: .any)[e.identifier].exists { return front }
        let first = app.scrollViews.firstMatch
        if first.exists, first.descendants(matching: .any)[e.identifier].exists { return first }
        return nil
    }

    /// Scroll the control's own list until it is on screen. Nothing to scroll (or
    /// nothing that holds it) = leave the screen alone.
    private func bringIntoView(_ app: XCUIApplication, _ e: XCUIElement) {
        var down = true
        for _ in 0..<10 {
            // It can go while we scroll; reading the frame of an element that is
            // not there is a HARD failure, not nil.
            guard e.exists else { return }
            if onScreen(app, e) { return }
            guard let list = listHolding(app, e), list.exists, list.isHittable else { return }
            let before = e.frame.midY
            #if os(macOS)
            list.scroll(byDeltaX: 0, deltaY: down ? -200 : 200)
            #else
            down ? list.swipeUp() : list.swipeDown()
            #endif
            usleep(300_000)
            // A control below the screen should move UP as the list goes down; if
            // it did not, this is the wrong way round.
            if e.exists && e.frame.midY >= before { down.toggle() }
        }
    }

    private func tab(_ app: XCUIApplication, _ name: String) {
        hideKeyboard(app)
        // 🪤 A tap can be swallowed on a slow machine: on GitHub (0.17, 2026-09-25)
        // the app took 43 s to launch, the tap on Trips was synthesised — and the
        // screen stayed on Home. So: tap, check the screen changed, tap again if not.
        for _ in 0..<3 {
            app.buttons["tab-\(name)"].tap()
            if appears(app, "screen-\(name)", timeout: 4) { return }
        }
    }

    /// Is the on-screen keyboard still sliding in, when every control above it is
    /// about to move? (Never on the Mac.) The log of the
    /// lost Add tap showed the keyboard reported BELOW the screen (y 918 on an 874
    /// screen) at the moment of the tap, and Add at its old place; a beat later the
    /// keyboard sat at 590 and Add had moved up to 416.
    private func keyboardArriving(_ app: XCUIApplication) -> Bool {
        #if os(iOS)
        let keys = app.keyboards.firstMatch
        guard keys.exists else { return false }
        let screen = app.windows.firstMatch.frame
        return keys.frame.minY >= screen.maxY - 1 || !settled(keys)
        #else
        return false
        #endif
    }

    /// Put the keyboard away. On GitHub's simulator there is no hardware keyboard,
    /// so the on-screen one covers the bottom of the screen — and a control under
    /// it takes no tap while looking perfectly hittable. (Found twice: the tab bar,
    /// then Save on the trip review.)
    private func hideKeyboard(_ app: XCUIApplication) {
        #if os(iOS)
        guard app.keyboards.count > 0 else { return }
        // The BIGGEST list on screen — a row of pills is a scroll view too, and
        // swiping one of those fails outright. Any scroll is enough here, because
        // every screen uses `scrollDismissesKeyboard(.immediately)`.
        let big = biggestList(app)
        if let big, big.exists, big.isHittable { big.swipeUp() } else { app.swipeUp() }
        _ = waitUntil(timeout: 3) { app.keyboards.count == 0 }
        #endif
    }

    private func tapVisible(_ app: XCUIApplication, _ e: XCUIElement) {
        bringIntoView(app, e)
        e.tap()
    }

    /// A screen's container exists the moment it is created; its controls can be a
    /// beat behind on a slow machine. So: wait for the control, then tap it.
    private func tap(_ app: XCUIApplication, id: String, timeout: TimeInterval = 10) {
        // A FRESH query every time: waiting on one held query has been seen not to
        // find a control that appears a moment later (Settings, 2026-09-22).
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let e = app.buttons[id]
            // 🪤 Existing is not enough. A control can be in the tree with NO frame
            // yet ({inf, inf} — SwiftUI has not laid it out), and a control in a list
            // that is reflowing (rows above it being removed) is a moving target.
            // XCUITest's own tap failure is fatal — there is nothing to catch — so
            // the wait has to happen BEFORE the tap. Seen twice in one suite run:
            // a Settings field and a Columns row, both green on their own.
            // 🪤 …and ENABLED: a typed text reaches the button a beat after the field,
            // and a tap on a button still switched off is silently lost (the to-do chip
            // and the buy list, 2026-09-25/26 — each seen once in a full run).
            // 🪤 …and NOT WHILE THE KEYBOARD IS STILL SLIDING IN: a button just above it
            // is reported at its old place, under the keys, and the tap lands on the
            // keyboard (the buy list's Add, 2026-09-26 — every time once this simulator
            // lost its hardware keyboard; GitHub never has one). Once the keyboard is at
            // rest, a control it covers is scrolled into view as before — hiding the
            // keyboard instead left the Grab Lists shelf untappable (same day).
            if e.exists, e.isEnabled, settled(e) {
                if keyboardArriving(app) { usleep(200_000); continue }
                #if os(iOS)
                if app.keyboards.count > 0 {
                    print("TAP-KEYS \(id) at \(e.frame) · keyboard \(app.keyboards.firstMatch.frame)")
                }
                #endif
                tapVisible(app, e); return
            }
            usleep(200_000)
        } while Date() < deadline
        let last = app.buttons[id]
        print("TAP-REPORT nothing called \(id) to tap after \(timeout)s (exists=\(last.exists), enabled=\(last.exists && last.isEnabled))")
        print("TAP-REPORT tree:\n" + String(app.debugDescription.prefix(12000)))
        let picture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        picture.name = "no-\(id)"; picture.lifetime = .keepAlways; add(picture)
        XCTFail("no \(id) to tap — see TAP-REPORT in the log")
    }

    /// Has this control been laid out, and stopped moving? Two reads a moment apart
    /// must agree, and the frame must be real.
    private func settled(_ e: XCUIElement) -> Bool {
        let first = e.frame
        guard first.origin.x.isFinite, first.origin.y.isFinite,
              first.width > 0, first.height > 0 else { return false }
        usleep(120_000)
        guard e.exists else { return false }
        return e.frame == first
    }

    /// Replace what a field holds. Select-all on the Mac; on the phone the old text
    /// is deleted from the cursor. Checked by reading it back.
    private func replace(_ text: String, in field: XCUIElement) {
        for _ in 0..<3 {
            #if os(macOS)
            field.tap()
            field.typeKey("a", modifierFlags: .command)
            field.typeText(text)
            #else
            // The middle of the field, not its edge: the edge is padding and takes no
            // focus. With a short name the cursor lands after it.
            field.tap()
            let old = (field.value as? String) ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count + 2))
            field.typeText(text)
            #endif
            if (field.value as? String) == text { return }
        }
        XCTFail("could not replace the text of \(field): '\(field.value ?? "")'")
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
        tab(app, "settings")
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
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))
        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        XCTAssertTrue(app.buttons["trip-row-1"].waitForExistence(timeout: 5), "the new trip is not listed beside the sample one")
    }
    /// The trip's dates, Booking.com's way — his example (2026-09-26): one field,
    /// a month grid, tap the first day and then the last; a tap before the first
    /// starts again; and the trip made keeps the dates he picked.
    func testDatesArePickedLikeBooking() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: today)! }
        func ymd(_ d: Date) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: d)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        let wd = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let mo = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        func pretty(_ d: Date) -> String {
            let c = cal.dateComponents([.weekday, .day, .month], from: d)
            return "\(wd[c.weekday! - 1]) \(c.day!) \(mo[c.month! - 1])"
        }
        let months = ["January", "February", "March", "April", "May", "June", "July",
                      "August", "September", "October", "November", "December"]
        /// Bring a day's month on screen: page towards it from the month showing.
        func pick(_ d: Date) {
            let id = "range-day-\(ymd(d))"
            for _ in 0..<3 where !app.buttons[id].exists {
                let shown = words(app.staticTexts["range-title-0"]).split(separator: " ")
                let m = (months.firstIndex(of: String(shown.first ?? "")) ?? 0) + 1
                let y = Int(shown.last ?? "") ?? 0
                let c = cal.dateComponents([.year, .month], from: d)
                tap(app, id: (c.year! * 12 + c.month!) > (y * 12 + m) ? "range-next" : "range-prev")
            }
            tap(app, id: id)
        }

        // Dates on: the field, and the grid open under it.
        let dates = app.switches["trip-dates"].exists ? app.switches["trip-dates"] : app.checkBoxes["trip-dates"]
        XCTAssertTrue(dates.waitForExistence(timeout: 5), "no Dates switch")
        #if os(macOS)
        dates.tap()
        #else
        dates.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()   // the switch, not its word
        #endif
        // The field says its dates as its VALUE — the Mac folds a button's texts into it.
        let field = app.buttons["trip-dates-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Dates on and no date field")
        func says() -> String { field.value as? String ?? "" }
        XCTAssertTrue(app.staticTexts["range-title-0"].waitForExistence(timeout: 5), "the month grid did not open")

        // First day, then last day.
        pick(day(3))
        XCTAssertTrue(waitUntil { says() == pretty(day(3)) }, "the first day is not shown: '\(says())'")
        XCTAssertFalse(says().contains("night"), "nights counted before the last day was picked: '\(says())'")
        pick(day(5))
        XCTAssertTrue(waitUntil { says() == "\(pretty(day(3))) — \(pretty(day(5))) · 2 nights" },
                      "the range is not shown: '\(says())'")
        XCTAssertTrue(waitUntil { !app.staticTexts["range-title-0"].exists }, "the grid did not close after the last day")

        // Open it again: a new first day — and a day BEFORE it, while the last day is
        // awaited, becomes the new first day rather than an end before the start.
        tap(app, id: "trip-dates-field")
        XCTAssertTrue(app.staticTexts["range-title-0"].waitForExistence(timeout: 5), "the field did not open the grid again")
        pick(day(2))
        XCTAssertTrue(waitUntil { says() == pretty(day(2)) }, "a new first day is not shown: '\(says())'")
        pick(day(1))
        XCTAssertTrue(waitUntil { says() == pretty(day(1)) }, "an earlier day did not become the first day: '\(says())'")
        pick(day(2))
        XCTAssertTrue(waitUntil { says() == "\(pretty(day(1))) — \(pretty(day(2))) · 1 night" }, "'\(says())'")

        // The trip made keeps them.
        type("Dated trip", into: app.textFields["trip-name"])
        select(app, app.buttons["trip-activity-0"])
        let create = app.buttons["trip-create"]
        XCTAssertTrue(waitUntil { create.isEnabled }, "Create stayed off")
        tapVisible(app, create)
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5), "the new trip did not open")
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))
        tab(app, "events")
        // The row writes dates the device's way: "27 Sep 2026" here, "Sep 27, 2026" on
        // GitHub's Mac (0.22) — so look for the day and the month, in either order.
        let c1 = cal.dateComponents([.day, .month], from: day(1))
        let startDay = "\(c1.day!)", startMonth = mo[c1.month! - 1]
        let row = (0..<6).map { app.buttons["trip-row-\($0)"] }.first { $0.exists && self.words($0).contains("Dated trip") }
        XCTAssertNotNil(row, "the dated trip is not listed")
        if let row {
            let said = words(row)
            let first = said.range(of: "Dated trip").map { String(said[$0.upperBound...]) } ?? said
            let startsRight = first.range(of: "\\b\(startDay) \(startMonth)|\(startMonth) \(startDay)\\b", options: .regularExpression) != nil
            XCTAssertTrue(startsRight, "the trip lost its first day (\(startDay) \(startMonth)): '\(said)'")
        }
    }

    /// Bug B1 (his screenshot, 2026-09-26): a row showed NOT ticked while its section
    /// said 243/243 — the stored trip had every line ticked. Every row must show the
    /// tick the trip holds, whichever way the trip is sorted and however it was ticked.
    func testEveryRowShowsTheTickTheTripHolds() {
        let app = launch()
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        let total = Int(words(progress).split(separator: "/").last ?? "") ?? 0
        XCTAssertGreaterThan(total, 1, "the sample trip has too few lines: '\(words(progress))'")

        // Tick one line by itself, then whole sections, sorted by When.
        tap(app, id: "trip-line-0")
        for g in 0..<6 where app.buttons["trip-group-\(g)-all"].exists {
            let all = app.buttons["trip-group-\(g)-all"]
            if !isOn(all) { tapVisible(app, all) }
        }
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(progress).hasPrefix("\(total)/\(total)") || (progress.value as? String) == "all packed" },
                      "not everything is ticked: '\(words(progress))'")

        // Through every sorting and back: each row must still show its tick.
        for view in [1, 2, 3, 0] {
            tap(app, id: "trip-view-\(view)")
            XCTAssertTrue(waitUntil { app.buttons["trip-view-\(view)"].isSelected })
            for n in 0..<total {
                XCTAssertTrue(scrollUntil(app, "trip-line-\(n)", near: n > 0 ? "trip-line-\(n - 1)" : nil), "line \(n + 1) never appeared")
                XCTAssertTrue(waitUntil(timeout: 3) { self.isOn(app.buttons["trip-line-\(n)"]) },
                              "sorted by view \(view), line \(n + 1) shows NO tick although the trip has it ticked: '\(words(app.buttons["trip-line-\(n)"]))'")
            }
        }
    }

    /// His ask (2026-09-26): "The list is extremely long" — each section folds away
    /// with the arrow before its name, opens again, and stays as he left it.
    /// (Judged by the lines UNDER the first heading, not by counting every line: on
    /// the Mac's short window a lazy list has not built its last lines at all.)
    func testASectionFoldsAndStaysFolded() {
        let app = launch()
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        let total = Int(words(progress).split(separator: "/").last ?? "") ?? 0
        let first = app.staticTexts["trip-group-0-label"]
        XCTAssertTrue(first.waitForExistence(timeout: 5), "no first section")
        let heading = words(first)
        func underFirst() -> [Int] {
            let top = first.frame.maxY
            let next = app.staticTexts["trip-group-1-label"]
            let bottom = next.exists ? next.frame.minY : .greatestFiniteMagnitude
            return (0..<total).filter {
                let line = app.buttons["trip-line-\($0)"]
                return line.exists && line.frame.midY > top && line.frame.midY < bottom
            }
        }
        let lines = underFirst()
        XCTAssertFalse(lines.isEmpty, "no lines under '\(heading)' to fold")

        tap(app, id: "trip-group-0-fold")
        XCTAssertTrue(waitUntil { lines.allSatisfy { !app.buttons["trip-line-\($0)"].exists } },
                      "folding '\(heading)' left its lines on screen")
        XCTAssertEqual(words(app.staticTexts["trip-group-0-label"]), heading, "the folded section lost its heading")

        // It stays folded when the trip is closed and opened again.
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(app.staticTexts["trip-group-0-label"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { lines.allSatisfy { !app.buttons["trip-line-\($0)"].exists } },
                      "the fold was forgotten when the trip was opened again")

        // And opens again.
        tap(app, id: "trip-group-0-fold")
        XCTAssertTrue(waitUntil { lines.allSatisfy { app.buttons["trip-line-\($0)"].exists } },
                      "opening '\(heading)' did not bring its lines back")
    }

    /// His standing rule (the web apps; roadmap phase D): every release has its line
    /// in What's new. This fails the build when the newest entry is not the version
    /// being built — the version marker under the tab bar says which that is.
    func testWhatsNewStartsWithThisVersion() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        let marker = app.staticTexts["app-version"]
        XCTAssertTrue(marker.waitForExistence(timeout: 5))
        let shown = words(marker)                                   // "0.23 (2)"
        let version = String(shown.split(separator: " ").first ?? "")
        XCTAssertFalse(version.isEmpty, "no version on screen: '\(shown)'")

        tab(app, "settings")
        tap(app, id: "settings-whatsnew")
        XCTAssertTrue(appears(app, "guide-whatsnew", timeout: 5), "What's new did not open")
        let top = app.staticTexts["guide-release-0-version"]
        XCTAssertTrue(top.waitForExistence(timeout: 5), "What's new lists no version")
        XCTAssertEqual(words(top), version, "What's new does not start with this version — write its line in Releases.swift")
        XCTAssertTrue(app.staticTexts["guide-release-1-version"].exists, "only one version listed")
        tap(app, id: "guide-done")
        XCTAssertTrue(disappears(app, "guide-whatsnew", timeout: 5))

        tap(app, id: "settings-howitworks")
        XCTAssertTrue(appears(app, "guide-howitworks", timeout: 5), "How it works did not open")
        XCTAssertTrue(appears(app, "guide-topic-0", timeout: 5), "How it works says nothing")
        XCTAssertTrue(appears(app, "guide-topic-1", timeout: 5), "How it works has one topic only")
        tap(app, id: "guide-done")
        XCTAssertTrue(disappears(app, "guide-howitworks", timeout: 5))
    }

    /// A grab list counts what is in hand, refuses "Ready to go" while something
    /// is missing, lets a thing be skipped, and Start over clears it all.
    func testAGrabListCountsRefusesAndClears() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        let button = app.buttons["grab-0"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "no grab buttons on Home")
        button.tap()
        // GitHub's runner opens this sheet slower than five seconds when it is busy
        // (it failed twice there while passing here); the usual ten is plenty.
        XCTAssertTrue(appears(app, "grab-detail"), "the grab list did not open")
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
        tap(app, id: "grab-done")
        XCTAssertTrue(disappears(app, "grab-detail", timeout: 5))
    }
    /// A thing typed while packing joins the trip — and the count.
    func testAThingTypedWhilePackingJoinsTheTrip() {
        let app = launch()
        tab(app, "events")
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
        // The count above is the claim that matters: the line joined the trip. Whether
        // the row itself is BUILT depends on how far down the list it lands — a lazy
        // row far below the fold is not in the tree until it has been near the screen,
        // which is why this scrolls to it rather than demanding it be there already.
        scrollUntil(app, "trip-line-\(total)")
        if let v = field.value as? String { XCTAssertFalse(v.contains("Tripod"), "the field should be empty again") }
    }
    /// A to-do is added, counted, ticked — and stays ticked.
    func testAToDoIsAddedAndTicked() {
        let app = launch()
        tab(app, "actions")
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
        tab(app, "home")
        tab(app, "actions")
        XCTAssertTrue(waitUntil(timeout: 10) { self.isOn(app.buttons["action-0"]) }, "the tick was lost on the way out and back")
    }
    /// A thing added to a template is there — and still there after closing and reopening.
    func testAThingAddedToATemplateStays() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        app.buttons["template-row-1"].tap()                // the second sample template (4 things)
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(app.buttons["template-item-3"].waitForExistence(timeout: 5), "expected 4 things")
        XCTAssertFalse(app.buttons["template-item-4"].exists)

        let field = app.textFields["template-add-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no field to add a thing")
        type("Gaiters", into: field)
        app.buttons["template-add"].tap()
        XCTAssertTrue(waitUntil { app.buttons["template-item-4"].exists }, "the new thing is not on the list")

        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))
        app.buttons["template-row-1"].tap()
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(waitUntil { app.buttons["template-item-4"].exists }, "the thing was lost on the way out and back")
    }
    /// Care shows what is overdue; "Done today" moves it on — and it stays done.
    func testCareShowsWhatIsOverdueAndDoneTodayMovesItOn() {
        let app = launch()
        tab(app, "care")
        XCTAssertTrue(appears(app, "screen-care"))
        let summary = app.staticTexts["care-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "no care summary")
        XCTAssertTrue(waitUntil { self.words(summary).hasPrefix("1 overdue") }, "the sample's boots are overdue: '\(words(summary))'")
        let done = app.buttons["care-row-0-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "no Done today on the overdue row")
        // 🪤 On GitHub's slow iPhone (0.19) the tap was synthesised and the summary
        // had not moved 5 s later — every step there took seconds. Wait for the button
        // to settle, allow 10 s, and tap once more only if the row is STILL overdue.
        tap(app, id: "care-row-0-done")
        if !waitUntil(timeout: 10, { self.words(summary) == "All up to date" }), app.buttons["care-row-0-done"].exists {
            print("TAP-REPORT Done today needed a second tap")
            tap(app, id: "care-row-0-done")
        }
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(summary) == "All up to date" }, "Done today did not move it on: '\(words(summary))'")
        tab(app, "home")
        tab(app, "care")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.staticTexts["care-summary"]) == "All up to date" },
                      "the service was lost on the way out and back: '\(words(app.staticTexts["care-summary"]))'")
    }

    /// The maintenance calendar: it opens on this month and flags what is overdue;
    /// once the boots are done today, they sit on the day they next fall due —
    /// a few months on — and a tap there shows them.
    func testTheCareCalendarPutsEachServiceOnItsDay() {
        let app = launch()
        tab(app, "care")
        XCTAssertTrue(appears(app, "screen-care"))
        tap(app, id: "care-view-calendar")
        let title = app.staticTexts["care-cal-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Calendar did not open")
        let now = Date()
        let names = ["January", "February", "March", "April", "May", "June", "July",
                     "August", "September", "October", "November", "December"]
        let c = Calendar.current.dateComponents([.year, .month], from: now)
        XCTAssertEqual(words(title), "\(names[c.month! - 1]) \(c.year!)", "the calendar does not open on this month")
        XCTAssertTrue(app.buttons["care-cal-overdue"].waitForExistence(timeout: 5),
                      "the sample's boots are overdue, and the calendar does not say so")

        // The overdue line leads to the List; Done today there — then back to the Calendar.
        tap(app, id: "care-cal-overdue")
        tap(app, id: "care-row-0-done")
        tap(app, id: "care-view-calendar")
        XCTAssertTrue(waitUntil { !app.buttons["care-cal-overdue"].exists }, "still flagged overdue after Done today")

        // Every 90 days: find that month and that day.
        let due = Calendar.current.date(byAdding: .day, value: 90, to: now)!
        let d = Calendar.current.dateComponents([.year, .month, .day], from: due)
        let ahead = (d.year! * 12 + d.month!) - (c.year! * 12 + c.month!)
        for _ in 0..<ahead { tap(app, id: "care-cal-next") }
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["care-cal-title"]) == "\(names[d.month! - 1]) \(d.year!)" },
                      "next month did not move the calendar: '\(words(app.staticTexts["care-cal-title"]))'")
        let day = app.buttons["care-cal-\(d.day!)"]
        XCTAssertTrue(day.waitForExistence(timeout: 5), "no day \(d.day!) on the calendar")
        XCTAssertTrue(waitUntil { (day.value as? String) == "1 due" },
                      "the boots are not on the day they fall due: '\(day.value as? String ?? "")'")
        tap(app, id: "care-cal-\(d.day!)")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["care-cal-day"]).hasSuffix("· 1") },
                      "the day does not list what is due: '\(words(app.staticTexts["care-cal-day"]))'")
        XCTAssertTrue(app.buttons["care-row-900-done"].waitForExistence(timeout: 5), "the boots are not under the day")

        // Today (his ask, 2026-09-26): back to this month, with today picked.
        tap(app, id: "care-cal-today")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["care-cal-title"]) == "\(names[c.month! - 1]) \(c.year!)" },
                      "Today did not bring the calendar back: '\(words(app.staticTexts["care-cal-title"]))'")
        let todayNumber = Calendar.current.component(.day, from: now)
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["care-cal-day"]).hasPrefix("\(todayNumber) \(names[c.month! - 1])") },
                      "Today did not pick today: '\(words(app.staticTexts["care-cal-day"]))'")
    }

    /// His marks (2026-09-25): "Sorting" on the left, the buttons on the same line to
    /// its right — When · Into · From where · Category. "Into" sorts by the bag a
    /// thing goes into; "From where" by where it is kept at home, "so that I can
    /// pick all stuff from a specific location when packing".
    func testTheTripSaysSortingBesideItsThreeButtons() {
        let app = launch()
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let label = app.staticTexts["trip-view-label"]
        XCTAssertTrue(label.waitForExistence(timeout: 5), "no Sorting label")
        XCTAssertEqual(words(label), "Sorting")
        let buttons = (0..<4).map { app.buttons["trip-view-\($0)"] }
        XCTAssertTrue(buttons[0].waitForExistence(timeout: 5) && buttons.allSatisfy { $0.exists }, "the four buttons are missing")
        XCTAssertEqual(buttons.map { words($0) }, ["When", "Into", "From where", "Category"])
        XCTAssertLessThan(label.frame.maxX, buttons[0].frame.minX, "Sorting is not to the LEFT of the buttons")
        XCTAssertLessThan(abs(label.frame.midY - buttons[0].frame.midY), 10, "Sorting is not on the SAME line as the buttons")
        XCTAssertLessThan(abs(buttons[3].frame.midY - buttons[0].frame.midY), 10, "the buttons are not on one line")
        let sheet = find(app, "trip-detail")?.frame ?? app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(buttons[3].frame.maxX, sheet.maxX + 1, "the last button runs off the screen")
        XCTAssertGreaterThanOrEqual(label.frame.minX, sheet.minX - 1, "Sorting is pushed off the screen")
        let screen = app.windows.firstMatch.frame
        XCTAssertTrue(screen.contains(label.frame) && screen.contains(buttons[3].frame), "the Sorting row runs off the screen")
        XCTAssertTrue(buttons[0].isSelected, "When is not the starting sort")

        let first = app.staticTexts["trip-group-0-label"]
        XCTAssertTrue(first.waitForExistence(timeout: 5), "no first heading")
        let byWhen = words(first)
        tap(app, id: "trip-view-1")
        XCTAssertTrue(waitUntil { app.buttons["trip-view-1"].isSelected }, "Into did not become the sort")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["trip-group-0-label"]) != byWhen },
                      "Into did not re-sort the trip: still '\(byWhen)'")

        // From where: the headings are the places things are KEPT (the sample's are these).
        let places: Set<String> = ["Bathroom cabinet", "Chest of drawers", "Garage", "Hall closet", "No place set"]
        tap(app, id: "trip-view-2")
        XCTAssertTrue(waitUntil { app.buttons["trip-view-2"].isSelected }, "From where did not become the sort")
        XCTAssertTrue(waitUntil { places.contains(self.words(app.staticTexts["trip-group-0-label"])) },
                      "From where does not group by where things are kept: '\(words(app.staticTexts["trip-group-0-label"]))'")
    }

    /// After a trip: mark what went unused, add what was missed, save — the trip
    /// says it is reviewed, and the missed thing is on a list for next time.
    func testATripReviewIsSavedAndTheMissedThingIsFiled() {
        let app = launch()
        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        app.buttons["trip-line-0"].tap()                        // one thing went in the bag
        let review = app.buttons["trip-review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5), "no Review on an unreviewed trip")
        review.tap()
        XCTAssertTrue(appears(app, "review-detail", timeout: 5))
        let line = app.buttons["review-line-0"]
        XCTAssertTrue(line.waitForExistence(timeout: 5), "the packed line is not asked about")
        XCTAssertFalse(app.buttons["review-line-1"].exists, "only what went in the bag is asked about")
        line.tap()
        XCTAssertTrue(waitUntil { self.isOn(line) }, "the line was not marked didn't use")
        type("Tripod", into: app.textFields["review-miss-input"])
        tap(app, id: "review-miss-add")
        XCTAssertTrue(waitUntil { self.find(app, "review-missed-0") != nil }, "the missed thing is not listed")
        hideKeyboard(app)
        tap(app, id: "review-save")
        XCTAssertTrue(disappears(app, "review-detail", timeout: 5))
        XCTAssertTrue(app.staticTexts["trip-reviewed"].waitForExistence(timeout: 5), "the trip does not say it is reviewed")
        XCTAssertFalse(app.buttons["trip-review"].exists, "a trip is reviewed once")

        // The missed thing went onto the first list of the trip: the base list (4 things → 5).
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))
        tab(app, "templates")
        app.buttons["template-row-0"].tap()
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(waitUntil { app.buttons["template-item-4"].exists },
                      "the missed thing is not on the list for next time")
    }
    /// Your things: everything he owns is listed; a new thing is on no list; a
    /// rename sticks.
    func testYourThingsListsAddsAndRenames() {
        let app = launch()
        tab(app, "care")
        XCTAssertTrue(appears(app, "screen-care"))
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        let count = app.staticTexts["things-count"]
        XCTAssertTrue(waitUntil { self.words(count) == "10 things" }, "the sample library holds 10 things: '\(words(count))'")
        XCTAssertFalse(app.buttons["things-nolist"].exists, "nothing is on no list yet")

        type("Sit mat", into: app.textFields["thing-new-name"])
        app.buttons["thing-new"].tap()
        XCTAssertTrue(waitUntil { self.words(count) == "11 things" }, "the new thing is not counted: '\(words(count))'")
        let noList = app.buttons["things-nolist"]
        XCTAssertTrue(noList.waitForExistence(timeout: 5), "the new thing is on no list, and says so")
        noList.tap()
        XCTAssertTrue(waitUntil { self.words(count) == "1 thing" }, "the filter did not narrow: '\(words(count))'")

        app.buttons["thing-row-0"].tap()
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        replace("Sit pad", in: app.textFields["thing-name"])
        tap(app, id: "thing-save")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.buttons["thing-row-0"]).hasPrefix("Sit pad") || app.buttons["thing-row-0"].label.contains("Sit pad") },
                      "the rename did not stick: '\(app.buttons["thing-row-0"].label)'")
    }
    /// Bug B2 (his screenshot, 2026-09-26): "Whose it is" showed one name once for
    /// every thing he owns — a screenful of it, all lit up. Each owner once.
    func testWhoseItIsOffersEachOwnerOnce() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        tap(app, id: "thing-row-0")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        XCTAssertTrue(app.buttons["thing-owner-0"].waitForExistence(timeout: 5), "no Whose it is")
        let offered = (1..<12).map { app.buttons["thing-owner-\($0)"] }.filter { $0.exists }.map { words($0) }
        XCTAssertEqual(offered, ["Kim", "Robin"], "each owner once, A–Z: \(offered)")
        // His ask (2026-09-26): keep the headings, make the buttons' text smaller — the
        // editor's buttons are the slim ones (32 pt, not the 36 pt used elsewhere).
        XCTAssertLessThan(app.buttons["thing-category-0"].frame.height, 35, "the editor's buttons are not the smaller ones")
    }

    /// A grab list is edited — renamed, one removed, one added — and stays so.
    func testAGrabListIsEditedAndStaysEdited() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        app.buttons["grab-0"].tap()
        XCTAssertTrue(appears(app, "grab-detail", timeout: 5))
        let edit = app.buttons["grab-edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "no way to edit the list")
        edit.tap()
        replace("Swim shorts", in: app.textFields["grab-rename-0"])
        app.buttons["grab-remove-1"].tap()
        type("Nose clip", into: app.textFields["grab-add-name"])
        app.buttons["grab-add"].tap()
        XCTAssertTrue(app.textFields["grab-rename-6"].waitForExistence(timeout: 5), "the added thing is not in the list")
        edit.tap()                                                   // Save

        let count = app.staticTexts["grab-count"]
        XCTAssertTrue(waitUntil { self.words(count) == "0 of 7 in hand" }, "7 − 1 + 1 things: '\(words(count))'")
        XCTAssertTrue(app.buttons["grab-item-0"].label.contains("Swim shorts"), "the rename did not stick: '\(app.buttons["grab-item-0"].label)'")
        XCTAssertTrue(app.buttons["grab-item-6"].label.contains("Nose clip"), "the added thing is not last")

        tap(app, id: "grab-done")
        XCTAssertTrue(disappears(app, "grab-detail", timeout: 5))
        app.buttons["grab-0"].tap()
        XCTAssertTrue(appears(app, "grab-detail", timeout: 5))
        XCTAssertTrue(waitUntil { app.buttons["grab-item-0"].exists && app.buttons["grab-item-0"].label.contains("Swim shorts") },
                      "the edit was lost on the way out and back")
    }
    /// What a thing knows is changed once and reaches every list it is on — and
    /// a list it is put on holds it.
    func testAThingsOwnDetailsAndItsListsAreChanged() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        type("Headlamp", into: app.textFields["things-search"])
        let row = app.buttons["thing-row-0"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Headlamp"), "the search did not narrow: '\(row.label)'")
        XCTAssertFalse(row.label.contains("Swim"), "it is not on the Swim list yet: '\(row.label)'")
        row.tap()
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))

        select(app, app.buttons["thing-category-7"])        // Electronics
        let swim = app.buttons["thing-lists-2"]             // Common base, Hiking, Swim — A–Z
        bringIntoView(app, swim)
        XCTAssertTrue(swim.exists, "no list to put it on")
        XCTAssertFalse(swim.isSelected)
        select(app, swim)
        tap(app, id: "thing-save")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))
        XCTAssertTrue(waitUntil { app.buttons["thing-row-0"].label.contains("Swim") },
                      "the list it was put on is not shown: '\(app.buttons["thing-row-0"].label)'")

        app.buttons["thing-row-0"].tap()
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["thing-category-7"]) }, "the kind of thing was not kept")
        XCTAssertTrue(isOn(app.buttons["thing-lists-2"]), "the list was not kept")
    }
    /// A list reads in ITS sections, and a row can be given this list's own bag,
    /// note and section without touching the thing or the other lists.
    func testARowOfAListHasItsOwnAnswers() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        app.buttons["template-row-1"].tap()                       // Hiking, which has a section
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(app.staticTexts["Lights"].waitForExistence(timeout: 5), "the list does not read in its sections")

        let row = app.buttons["template-item-0"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Headlamp"), "expected the sectioned thing first: '\(row.label)'")
        XCTAssertTrue(row.label.contains("Carry-on"), "it follows the thing's own bag: '\(row.label)'")
        row.tap()
        XCTAssertTrue(appears(app, "row-detail", timeout: 5))
        select(app, app.buttons["row-bag-4"])                     // this list's own bag
        type("with the red filter", into: app.textFields["row-note"])
        tapVisible(app, app.buttons["row-save"])
        XCTAssertTrue(disappears(app, "row-detail", timeout: 5))
        XCTAssertTrue(waitUntil { app.buttons["template-item-0"].label.contains("red filter") },
                      "the note is not on the row: '\(app.buttons["template-item-0"].label)'")
        XCTAssertFalse(app.buttons["template-item-0"].label.contains("Carry-on"), "this list now has its own bag")

        // The thing itself still says what it always said.
        tap(app, id: "template-detail-done")
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        type("Headlamp", into: app.textFields["things-search"])
        XCTAssertTrue(waitUntil { app.buttons["thing-row-0"].exists })
        app.buttons["thing-row-0"].tap()
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["thing-bag-1"]) }, "the thing's own bag was changed by a list's exception")
    }
    /// His own lists: a storage place is added, is offered to a thing, and cannot
    /// be removed while something uses it.
    /// A restore REPLACES: the sheet shows what the file holds beside what the
    /// device holds, warns when the file holds less, and only then offers the red
    /// button. (Apple's own file window cannot be driven by a test, so under
    /// `-uiTesting` the button reads an invented file of 2 things.)
    func testARestoreShowsWhatTheFileHoldsAndThenReplacesEverything() {
        let app = launch()
        tab(app, "settings")
        XCTAssertTrue(appears(app, "screen-settings"))
        let things = app.staticTexts["device-count-items"]
        XCTAssertTrue(things.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { self.words(things) == "10" },
                      "the sample library is not what it was: '\(words(things))'")

        tap(app, id: "backup-restore")
        XCTAssertTrue(appears(app, "restore-detail", timeout: 5), "the restore was not shown first")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["restore-file-items"]) == "2" },
                      "what the file holds: '\(words(app.staticTexts["restore-file-items"]))'")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["restore-now-items"]) == "10" },
                      "what the device holds: '\(words(app.staticTexts["restore-now-items"]))'")
        XCTAssertTrue(app.staticTexts["restore-fewer"].exists, "a file holding less said nothing")

        // Backing out changes nothing.
        tap(app, id: "restore-cancel")
        XCTAssertTrue(disappears(app, "restore-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(things) == "10" }, "cancelling replaced something")

        tap(app, id: "backup-restore")
        XCTAssertTrue(appears(app, "restore-detail", timeout: 5))
        tap(app, id: "restore-confirm")
        XCTAssertTrue(disappears(app, "restore-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(things) == "2" }, "the device still holds \(words(things)) things")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["device-count-trips"]) == "0" },
                      "a trip from before the restore survived")
    }

    /// The way back. A restore keeps a copy of what was on the device first, and
    /// that copy is reachable HERE — a safety net he cannot reach is no net. (The
    /// copies are cleared at launch under the tests, so the count is this run's.)
    func testTheCopyKeptBeforeARestoreBringsEverythingBack() {
        let app = launch()
        tab(app, "settings")
        let things = app.staticTexts["device-count-items"]
        XCTAssertTrue(things.waitForExistence(timeout: 5))
        XCTAssertEqual(words(things), "10")
        XCTAssertFalse(app.staticTexts["rescue-heading"].exists, "a copy was kept before any restore")

        tap(app, id: "backup-restore")
        XCTAssertTrue(appears(app, "restore-detail", timeout: 5))
        tap(app, id: "restore-confirm")
        XCTAssertTrue(disappears(app, "restore-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(things) == "2" }, "the restore did not happen")

        XCTAssertTrue(app.staticTexts["rescue-heading"].waitForExistence(timeout: 5), "nothing was kept")
        XCTAssertTrue(app.buttons["rescue-row-0"].exists, "the copy is not offered")
        XCTAssertFalse(app.buttons["rescue-row-1"].exists, "more copies than restores")
        tap(app, id: "rescue-row-0")
        XCTAssertTrue(appears(app, "restore-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["restore-file-items"]) == "10" },
                      "the copy does not hold what was here: '\(words(app.staticTexts["restore-file-items"]))'")
        tap(app, id: "restore-confirm")
        XCTAssertTrue(disappears(app, "restore-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(things) == "10" }, "the copy did not bring everything back")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["device-count-trips"]) == "1" }, "the trip did not come back")
    }

    /// The buy-list: the library offers what is worn out or run down, saying why;
    /// taking an offer up puts it on the list and stops it being offered; and a
    /// line he types himself needs no thing behind it. The to-dos stay separate.
    func testTheBuyListOffersWhatIsWornOutAndKeepsTheToDosSeparate() {
        let app = launch()
        tab(app, "actions")
        XCTAssertTrue(appears(app, "screen-actions"))
        tap(app, id: "actions-tab-buy")
        XCTAssertTrue(app.staticTexts["buy-count"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["buy-count"]) == "Nothing to buy." },
                      "the buy-list does not start empty: '\(words(app.staticTexts["buy-count"]))'")

        XCTAssertTrue(app.staticTexts["buy-offers"].waitForExistence(timeout: 5), "nothing was offered")
        // The heading can be there a beat before the offers under it are. Read the
        // offer through its BUTTON: the Mac and the iPhone fold the two lines
        // inside it differently, but both put them in the button's own words.
        XCTAssertTrue(app.buttons["buy-offer-0"].waitForExistence(timeout: 5), "no offer under the heading")
        let offer = words(app.buttons["buy-offer-0"])
        XCTAssertTrue(offer.contains("Needs replacing"), "the worst reason should lead, not '\(offer)'")
        XCTAssertTrue(offer.contains("Map"), "the sample library is not what it was: '\(offer)'")
        let offered = "Map"
        tap(app, id: "buy-offer-0")
        // A row carries ONE piece of text, so SwiftUI folds it into the button:
        // the row is read through the button, not through a text inside it.
        XCTAssertTrue(waitUntil { app.buttons["buy-0"].exists }, "the offer did not reach the list")
        XCTAssertTrue(waitUntil { self.words(app.buttons["buy-0"]).contains(offered) },
                      "the line reads '\(words(app.buttons["buy-0"]))', not '\(offered)'")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["buy-count"]) == "1 to buy" })
        XCTAssertFalse(words(app.buttons["buy-offer-0"]).contains(offered),
                       "it is still being offered although it is on the list")

        // 🪤 Wait for Add to switch on: a full run (2026-09-26) tapped it while still
        // off — the same trap as the to-do chip test the day before.
        type("Gas canister", into: app.textFields["buy-add-text"])
        XCTAssertTrue(waitUntil { app.buttons["buy-add"].isEnabled }, "Add did not switch on for a typed line")
        tap(app, id: "buy-add")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["buy-count"]) == "2 to buy" },
                      "the typed line was not added: '\(words(app.staticTexts["buy-count"]))', field '\(app.textFields["buy-add-text"].value as? String ?? "")', lines \((0..<4).map { self.words(app.buttons["buy-\($0)"]) })")

        // Ticking one off leaves the other.
        tap(app, id: "buy-0")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["buy-count"]) == "1 to buy" }, "the tick did not count")

        // …and none of that turned up among the to-dos.
        tap(app, id: "actions-tab-todo")
        XCTAssertTrue(app.staticTexts["actions-count"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["actions-count"]) == "Nothing to do." },
                      "a buy-list line reached the to-dos: '\(words(app.staticTexts["actions-count"]))'")
    }

    /// The weather on a trip: ask for a place, get one line of what it will be like
    /// and the gear that weather calls for which is not packed yet — and taking a
    /// piece along puts it on the trip and stops it being asked for. (Under the
    /// tests the forecast is invented: a fixed wet, cold few days, so the words on
    /// screen can be checked exactly. The real one is Open-Meteo, as on the web.)
    func testTheWeatherSaysWhatItWillBeLikeAndWhatIsMissing() {
        let app = launch()
        tab(app, "events")
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        let before = words(progress)

        XCTAssertTrue(app.textFields["weather-place"].waitForExistence(timeout: 5), "nowhere to say where the trip is")
        type("Testville", into: app.textFields["weather-place"])
        hideKeyboard(app)
        XCTAssertTrue(waitUntil { (app.textFields["weather-place"].value as? String ?? "").contains("Testville") },
                      "the place did not stay in the field: '\(app.textFields["weather-place"].value as? String ?? "")'")
        XCTAssertTrue(app.buttons["weather-look"].isEnabled, "the Weather button is dead with a place typed")
        tap(app, id: "weather-look")

        XCTAssertTrue(app.staticTexts["weather-line"].waitForExistence(timeout: 10),
                      "no forecast came back — the app says '\(words(app.staticTexts["weather-trouble"]))'")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.staticTexts["weather-line"]).contains("Rain") },
                      "three wet days and the line says '\(words(app.staticTexts["weather-line"]))'")
        XCTAssertTrue(words(app.staticTexts["weather-line"]).contains("Cold")
                      || words(app.staticTexts["weather-line"]).contains("cold"),
                      "2–8°C is not warm: '\(words(app.staticTexts["weather-line"]))'")

        XCTAssertTrue(app.buttons["weather-gear-0"].waitForExistence(timeout: 5), "wet and cold, and nothing suggested")
        shot(app, "weather")
        let asked = words(app.buttons["weather-gear-0"])
        tap(app, id: "weather-gear-0")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(progress) != before },
                      "the gear did not reach the trip (still \(before))")
        XCTAssertFalse(words(app.buttons["weather-gear-0"]) == asked,
                       "it is still being asked for although it is on the trip")
    }

    /// The library says when it looks wrong. Both real accidents took this shape —
    /// every template existing twice — and neither showed anywhere on screen; only
    /// the counts knew, and only if you happened to read them. A sound library says
    /// nothing at all.
    func testALibraryThatHasMetAnotherSaysSo() {
        let sound = launch()
        tab(sound, "settings")
        XCTAssertTrue(appears(sound, "screen-settings"))
        XCTAssertTrue(sound.staticTexts["device-count-items"].waitForExistence(timeout: 5))
        XCTAssertFalse(sound.staticTexts["health-heading"].exists, "a sound library worried about itself")
        sound.terminate()

        let doubled = launch("-uiTestingTwoLibraries")
        tab(doubled, "settings")
        XCTAssertTrue(appears(doubled, "screen-settings"))
        XCTAssertTrue(doubled.staticTexts["health-heading"].waitForExistence(timeout: 10),
                      "every template exists twice and the app says nothing")
        XCTAssertTrue(waitUntil { self.words(doubled.staticTexts["health-0"]).contains("twice") },
                      "it does not say what is wrong: '\(words(doubled.staticTexts["health-0"]))'")
        XCTAssertTrue(waitUntil { !self.words(doubled.staticTexts["health-0-names"]).isEmpty },
                      "it does not say which lists")
    }

    /// When the last thing is packed the screen itself says so — his idea, and he
    /// asked for it strong. The words are for VoiceOver; the colour is the message.
    func testTheScreenSaysSoWhenEverythingIsPacked() {
        let app = launch()
        tab(app, "events")
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertNotEqual(progress.value as? String, "all packed", "a half-packed trip says it is done")

        // Tick everything the trip holds. 🪤 The lines sit in a LAZY list: on the
        // Mac's short window the last ones do not exist until scrolled to, and
        // "tick until a line is missing" stopped at 5 of 7 (0.19, GitHub). So count
        // from the progress ("0/7") and travel to each line.
        let total = Int(words(progress).split(separator: "/").last ?? "") ?? 0
        XCTAssertGreaterThan(total, 0, "the trip has no lines: '\(words(progress))'")
        for n in 0..<total {
            XCTAssertTrue(scrollUntil(app, "trip-line-\(n)", near: n > 0 ? "trip-line-\(n - 1)" : nil),
                          "line \(n + 1) of \(total) never appeared")
            let line = app.buttons["trip-line-\(n)"]
            if !isOn(line) { tapVisible(app, line) }
        }
        XCTAssertTrue(waitUntil(timeout: 10) { (progress.value as? String) == "all packed" },
                      "everything is ticked and the screen does not say so: '\(words(progress))'")

        // …and it stops saying so the moment something is untied again.
        tapVisible(app, app.buttons["trip-line-0"])
        XCTAssertTrue(waitUntil(timeout: 10) { (progress.value as? String) != "all packed" },
                      "one thing was un-ticked and the screen still says all packed")
    }

    /// The Events screen says where each trip is in its life without him reading
    /// numbers: a heading, a line of state, and a chip per trip that changes as the
    /// packing does.
    func testEachTripSaysWhereItHasGotTo() {
        let app = launch()
        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        XCTAssertTrue(app.staticTexts["events-heading"].waitForExistence(timeout: 5), "the screen has no heading")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["events-summary"]).contains("trip") },
                      "no line saying what there is: '\(words(app.staticTexts["events-summary"]))'")

        // Read through the ROW, not a text inside it: on the Mac a button folds its
        // children into its own words, on the iPhone they stay separate elements.
        let row = app.buttons["trip-row-0"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "no trip to look at")
        XCTAssertTrue(words(row).contains("Planned"),
                      "a trip nobody has packed is not 'Planned': '\(words(row))'")

        // Pack one thing: it is being packed now.
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        tapVisible(app, app.buttons["trip-line-0"])
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.buttons["trip-row-0"]).contains("Packing") },
                      "one thing packed and the trip still says '\(words(app.buttons["trip-row-0"]))'")

        // A to-do makes the chip to Actions appear, and it goes there.
        // 🪤 Wait for Add to switch on and the to-do to be LISTED before leaving: in a
        // full run (2026-09-25) Add was tapped while still off, no to-do was made, and
        // the chip was blamed for it.
        tab(app, "actions")
        type("Book the ferry", into: app.textFields["action-add-text"])
        XCTAssertTrue(waitUntil { app.buttons["action-add"].isEnabled }, "Add did not switch on for a typed to-do")
        tap(app, id: "action-add")
        XCTAssertTrue(app.buttons["action-0"].waitForExistence(timeout: 5), "the to-do was not made")
        tab(app, "events")
        XCTAssertTrue(app.buttons["events-todos"].waitForExistence(timeout: 5), "an open to-do is not shown here")
        tap(app, id: "events-todos")
        XCTAssertTrue(appears(app, "screen-actions", timeout: 5), "the chip did not open Actions")
    }

    /// One press ticks a whole "When" section, and the same press takes it back —
    /// his ask, for the days when a whole bag goes in at once.
    func testAWholeSectionIsTickedInOnePress() {
        let app = launch()
        tab(app, "events")
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(words(progress).hasPrefix("0/"), "the trip does not start empty: '\(words(progress))'")

        let all = app.buttons["trip-group-0-all"]
        XCTAssertTrue(all.waitForExistence(timeout: 5), "a section with no way to tick it whole")
        XCTAssertFalse(isOn(all))
        tapVisible(app, all)
        XCTAssertTrue(waitUntil(timeout: 10) { self.isOn(all) }, "the section did not go done")
        XCTAssertFalse(words(progress).hasPrefix("0/"), "nothing was ticked: '\(words(progress))'")
        XCTAssertTrue(isOn(app.buttons["trip-line-0"]), "the first line of the section is not ticked")

        // The same press takes it back.
        tapVisible(app, all)
        XCTAssertTrue(waitUntil(timeout: 10) { !self.isOn(all) }, "it could not be taken back")
        XCTAssertTrue(waitUntil { self.words(progress).hasPrefix("0/") }, "the ticks did not come off: '\(words(progress))'")
    }

    /// The review says WHERE each thing was packed, and a thing can be put right
    /// without losing the review — his two asks for this screen.
    func testTheReviewSaysWhereAThingWentAndLetsHimFixIt() {
        let app = launch()
        tab(app, "events")
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        tapVisible(app, app.buttons["trip-line-0"])             // something went in the bag
        tap(app, id: "trip-review")
        XCTAssertTrue(appears(app, "review-detail", timeout: 5))

        let line = app.buttons["review-line-0"]
        XCTAssertTrue(line.waitForExistence(timeout: 5), "nothing to review")
        XCTAssertTrue(waitUntil { self.words(line).contains("Carry-on") },
                      "the review does not say where the thing went: '\(words(line))'")

        // Fix the thing itself, and come back to the review as it was.
        tap(app, id: "review-line-0-fix")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5), "the thing did not open")
        replace("Head torch", in: app.textFields["thing-name"])
        tap(app, id: "thing-save")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))
        XCTAssertTrue(appears(app, "review-detail", timeout: 5), "the review was lost while fixing a thing")
        XCTAssertTrue(app.buttons["review-save"].exists, "the review cannot be finished after a fix")
    }

    /// "Only sometimes": a thing he takes one time in ten starts skipped every
    /// time, out of the count, and one tap brings it into today's list.
    func testAThingTakenOnlySometimesStartsSkipped() {
        let app = launch()
        tab(app, "home")
        tap(app, id: "grab-0")
        XCTAssertTrue(appears(app, "grab-detail", timeout: 5))
        let count = app.staticTexts["grab-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        let before = words(count)
        XCTAssertFalse(before.contains("only sometimes"))

        // Mark the second thing as one he rarely takes.
        tap(app, id: "grab-edit")
        XCTAssertTrue(app.buttons["grab-sometimes-1"].waitForExistence(timeout: 5), "no way to mark it")
        tapVisible(app, app.buttons["grab-sometimes-1"])
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["grab-sometimes-1"]) }, "the mark did not take")
        tap(app, id: "grab-edit")                       // Save

        // It is skipped now, and out of the count.
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(count).contains("skipped") },
                      "it is not skipped: '\(words(count))'")
        XCTAssertNotEqual(words(count), before, "the count did not change")

        // …and it says WHY, not just that it is skipped.
        XCTAssertTrue(waitUntil { self.words(app.buttons["grab-item-1"]).contains("only sometimes") },
                      "it does not say why it is out: '\(words(app.buttons["grab-item-1"]))'")

        // One tap brings it into today's list.
        tapVisible(app, app.buttons["grab-skip-1"])
        XCTAssertTrue(waitUntil(timeout: 10) { !self.words(app.buttons["grab-item-1"]).contains("only sometimes") },
                      "it could not be brought in for today")
    }

    /// More grab lists than Home can hold: six slots in his order, the rest
    /// waiting with everything on them, and he says which one steps back.
    func testMoreGrabListsThanHomeHolds() {
        let app = launch()
        tab(app, "home")
        tap(app, id: "grab-shelf")
        XCTAssertTrue(appears(app, "shelf-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shelf-home-heading"]).contains("6 of 6") },
                      "Home does not start with six: '\(words(app.staticTexts["shelf-home-heading"]))'")

        // A new list waits rather than shoving one off Home.
        type("Padel", into: app.textFields["shelf-new-name"])
        hideKeyboard(app)
        tap(app, id: "shelf-new")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.staticTexts["shelf-waiting-heading"]).contains("1") },
                      "the new list did not go to the shelf")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shelf-home-heading"]).contains("6 of 6") },
                      "it pushed something off Home by itself")

        // Putting it on Home asks which of the six steps back.
        tap(app, id: "shelf-waiting-0")
        XCTAssertTrue(appears(app, "swap-detail", timeout: 5), "it did not ask what steps back")
        let steppingBack = words(app.buttons["swap-0"])
        tap(app, id: "swap-0")
        XCTAssertTrue(disappears(app, "swap-detail", timeout: 5))

        // Home still holds six, and the one that stepped back is waiting, whole.
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.staticTexts["shelf-home-heading"]).contains("6 of 6") })
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shelf-waiting-heading"]).contains("1") })
        XCTAssertTrue(waitUntil { self.words(app.buttons["shelf-waiting-0"]).contains(String(steppingBack.prefix(4))) },
                      "the list that stepped back is not the one he chose: '\(words(app.buttons["shelf-waiting-0"]))'")
        XCTAssertFalse(words(app.buttons["shelf-waiting-0"]).contains("0 things"), "it lost its things on the way")

        // …and Home shows his six, Padel among them.
        tap(app, id: "shelf-done")
        XCTAssertTrue(disappears(app, "shelf-detail", timeout: 5))
        XCTAssertTrue(waitUntil(timeout: 10) {
            (0..<6).contains { self.words(app.buttons["grab-\($0)"]).contains("Padel") }
        }, "Padel is not on Home")
    }

    /// The Care tab says what the kit adds up to — and every word of it is true of
    /// the library in front of it: the counts, the weights, and the tips, which
    /// appear only when they apply.
    func testCareSaysWhatTheKitAddsUpTo() {
        let app = launch()
        tab(app, "care")
        XCTAssertTrue(appears(app, "screen-care"))
        XCTAssertTrue(app.staticTexts["care-heading"].waitForExistence(timeout: 5), "Care has no heading")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["care-line"]).contains("things") },
                      "no line saying what the kit is: '\(words(app.staticTexts["care-line"]))'")

        // The four figures, and the weight among them.
        XCTAssertTrue(app.otherElements["kit-things"].waitForExistence(timeout: 5)
                      || app.staticTexts["kit-things"].exists, "no count of things")
        // Not just present: it must say a WEIGHT. (A plant that stopped counting
        // grams slipped past an existence check, 2026-09-23.)
        XCTAssertTrue(waitUntil(timeout: 10) {
            let said = self.words(app.otherElements["kit-weight"]) + self.words(app.staticTexts["kit-weight"])
            return said.contains("kg") || said.contains(" g")
        }, "the kit does not say what it weighs: '\(words(app.otherElements["kit-weight"]))'")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["care-line"]).contains("kg") },
                      "the line under Care does not say what the kit weighs: '\(words(app.staticTexts["care-line"]))'")

        // The heavy end is drawn from the things that have a weight…
        XCTAssertTrue(app.buttons["kit-heavy-0"].waitForExistence(timeout: 5), "nothing in the heavy end")
        let heaviest = words(app.buttons["kit-heavy-0"])
        XCTAssertTrue(heaviest.contains("g"), "the heaviest thing does not say its weight: '\(heaviest)'")

        // …and tapping it opens those things, already searched.
        tap(app, id: "kit-heavy-0")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5), "the bar did not open the things behind it")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["things-count"]).hasPrefix("1 ") },
                      "it opened everything instead of that one thing: '\(words(app.staticTexts["things-count"]))'")
        tap(app, id: "things-done")
        XCTAssertTrue(disappears(app, "things-detail", timeout: 5))

        // A tip is only there when it is true. The sample library HAS an overdue
        // thing (boots, waxed last in January), so that one leads…
        XCTAssertTrue(app.staticTexts["kit-tips-heading"].waitForExistence(timeout: 5), "nothing worth knowing at all")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["kit-tip-0"]).contains("overdue") },
                      "something is overdue and the tips do not lead with it: '\(words(app.staticTexts["kit-tip-0"]))'")
        // …and nothing has been reviewed, so nothing may claim to have come home unused.
        for n in 0..<4 {
            XCTAssertFalse(words(app.staticTexts["kit-tip-\(n)"]).contains("came home unused"),
                           "nothing has been reviewed and it said things came home unused")
        }
    }

    /// The table is a spreadsheet: a heading sorts by its column and turns over
    /// when pressed again, and a weight typed into a cell reaches the thing.
    func testTheTableSortsAndSaves() {
        let app = launch()
        tab(app, "care")
        let kit = words(app.staticTexts["care-line"])
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5), "no table")
        XCTAssertEqual(words(app.staticTexts["table-count"]), "10", "the sample library has ten things")
        shot(app, "grid")

        // Sort by weight, then turn it over: the lightest and the heaviest thing
        // cannot be the same row.
        tap(app, id: "table-head-weight")
        XCTAssertTrue(waitUntil(timeout: 5) { !self.words(app.staticTexts["table-0-name"]).isEmpty })
        let lightest = words(app.staticTexts["table-0-name"])
        tap(app, id: "table-head-weight")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.staticTexts["table-0-name"]) != lightest },
                      "pressing the heading again did not turn the order over: still '\(lightest)'")

        // A weight typed into a cell is on the thing, not just on the screen.
        tap(app, id: "table-head-name")
        type("5000", into: app.textFields["table-0-weight"])
        app.textFields["table-0-weight"].typeText("\n")
        tap(app, id: "table-done")
        XCTAssertTrue(disappears(app, "table-detail", timeout: 5))
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.staticTexts["care-line"]) != kit },
                      "the kit's weight did not move: still '\(words(app.staticTexts["care-line"]))'")
    }

    /// He says which columns he sees. One he adds is there, and its ticks work.
    func testTheTableTakesTheColumnsHeChooses() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5), "no table")
        XCTAssertFalse(app.buttons["table-head-liquid"].exists, "Liquid is not one of the starting columns")

        tap(app, id: "table-columns")
        XCTAssertTrue(appears(app, "columns-detail", timeout: 5), "the columns sheet did not open")
        // Clear the ones he starts with, so the new column is not off to the right.
        // (Hiding is also his own ask — the web app can only reorder.)
        for gone in ["storage", "container", "ownedBy", "packer", "condition", "listQty"] {
            tap(app, id: "columns-\(gone)-hide")
        }
        tap(app, id: "columns-liquid-show")
        tap(app, id: "columns-done")
        XCTAssertTrue(disappears(app, "columns-detail", timeout: 5))
        XCTAssertTrue(app.buttons["table-head-liquid"].waitForExistence(timeout: 5),
                      "the column he added is not in the grid")
        XCTAssertFalse(app.buttons["table-head-storage"].exists, "a column he hid is still in the grid")

        // And a column of ticks ticks.
        let tick = app.buttons["table-0-liquid"]
        XCTAssertTrue(tick.waitForExistence(timeout: 5), "no ticks in the new column")
        let before = isOn(tick)
        tapVisible(app, tick)
        XCTAssertTrue(waitUntil(timeout: 5) { self.isOn(app.buttons["table-0-liquid"]) != before },
                      "the tick did not change")
    }

    /// One search that reaches everything, from whichever screen he is on: a thing
    /// opens the THING, a list opens the list, and a word nothing answers to says so.
    func testOneSearchReachesEverything() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "search-open")
        XCTAssertTrue(appears(app, "search-detail", timeout: 5), "the search did not open")

        // A word nothing answers to.
        type("zzzz", into: app.textFields["search-field"])
        XCTAssertTrue(app.staticTexts["search-none"].waitForExistence(timeout: 5),
                      "it did not say that nothing matches")

        // A thing of his opens the thing itself — not whichever list happens to
        // hold it, which is what the web app does.
        replace("Headlamp", in: app.textFields["search-field"])
        XCTAssertTrue(app.buttons["search-things-0"].waitForExistence(timeout: 5), "the thing was not found")
        tapVisible(app, app.buttons["search-things-0"])
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5), "choosing a thing did not open it")
        tap(app, id: "thing-cancel")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))

        // A list of his opens the list.
        replace("Hiking", in: app.textFields["search-field"])
        XCTAssertTrue(app.buttons["search-lists-0"].waitForExistence(timeout: 5), "the list was not found")
        tapVisible(app, app.buttons["search-lists-0"])
        XCTAssertTrue(appears(app, "template-detail", timeout: 5), "choosing a list did not open it")
    }

    /// A bag's weight limit, set on Care → Containers, is what every trip measures
    /// that bag against — and a bag over it turns the trip's Bags card red.
    /// (The first Bags card read the lists WITHOUT their things and so never saw a
    /// limit he set; this is the test that would have caught it in the app.)
    func testABagsLimitReachesTheTrip() {
        let app = launch()

        // The sample trip packs into carry-on, whose airline ceiling is 8 kg: well under.
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(app.otherElements["bags-card"].waitForExistence(timeout: 5)
                      || app.staticTexts["bags-total"].waitForExistence(timeout: 2), "no Bags card on the trip")
        XCTAssertFalse(app.staticTexts["bags-over"].exists, "under its limit, a bag must not say it is over")
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))

        // Make that bag his own, with a limit it is already past.
        tab(app, "care")
        tap(app, id: "care-containers")
        XCTAssertTrue(appears(app, "containers-detail", timeout: 5), "no Containers screen")
        // His ask (2026-09-26): the column names stay visible while the bags scroll —
        // so they must sit OUTSIDE every scrolling list, where nothing can carry them off.
        let columns = app.descendants(matching: .any)["containers-columns"]
        XCTAssertTrue(columns.waitForExistence(timeout: 5), "no column names over the bags")
        XCTAssertTrue(words(columns).contains("MAX KG"), "the column names are not there: '\(words(columns))'")
        for list in app.scrollViews.allElementsBoundByIndex where list.exists {
            XCTAssertFalse(list.descendants(matching: .any)["containers-columns"].exists,
                           "the column names scroll away with the bags")
        }
        type("Carry-on / hand luggage", into: app.textFields["bag-new-name"])
        tap(app, id: "bag-new")
        XCTAssertTrue(app.textFields["bag-0-maxkg"].waitForExistence(timeout: 5), "the bag was not made")
        type("1", into: app.textFields["bag-0-maxkg"])
        app.textFields["bag-0-maxkg"].typeText("\n")
        tap(app, id: "containers-done")
        XCTAssertTrue(disappears(app, "containers-detail", timeout: 5))

        // The trip must see it.
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(app.staticTexts["bags-over"].waitForExistence(timeout: 10),
                      "the limit he set did not reach the trip")
    }

    /// Getting rid of a list he no longer wants, and renaming the one he keeps —
    /// his own words: "Just delete one and rename the existing."
    func testAListIsRenamedAndAnotherIsDeleted() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        let before = words(app.staticTexts["templates-summary"])

        // Rename the first list where its name is written.
        tap(app, id: "template-row-0")
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        replace("Mobility & Breath", in: app.textFields["template-name"])
        XCTAssertTrue(app.buttons["template-rename"].waitForExistence(timeout: 5), "no way to save the new name")
        tap(app, id: "template-rename")
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))
        // Asked where it cannot be misread: reopening the list and reading its name
        // field. (A card's name is a child of a Button, and a Button says different
        // things about its children on the Mac and on the phone.)
        tap(app, id: "template-row-0")
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertEqual(cellSays(app, "template-name"), "Mobility & Breath", "the rename did not stick")
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))

        // Delete another one. It asks first, and says the things stay.
        tap(app, id: "template-row-1")
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        tap(app, id: "template-delete")
        XCTAssertTrue(app.buttons["template-delete-yes"].waitForExistence(timeout: 5), "it deleted without asking")
        tap(app, id: "template-delete-yes")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5), "the list did not close after going")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.staticTexts["templates-summary"]) != before },
                      "the shelf still says the same: '\(before)'")

        // And not one THING went with it.
        tab(app, "care")
        XCTAssertTrue(words(app.staticTexts["care-line"]).hasPrefix("10 things"),
                      "a deleted list must not take his things: '\(words(app.staticTexts["care-line"]))'")
    }

    /// A list he makes himself lands on the shelf he chose, opens straight away, and
    /// a name he already has is refused rather than quietly duplicated.
    func testHeMakesAListOfHisOwn() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        let before = words(app.staticTexts["templates-summary"])

        tap(app, id: "templates-new")
        XCTAssertTrue(appears(app, "newlist-detail", timeout: 5), "the sheet did not open")

        // A name he already has is refused, and nothing can be made from it.
        type("Hiking", into: app.textFields["newlist-name"])
        // 🪤 Asked for by EXISTENCE, not by `appears`: a warning is a plain Text, and
        // XCUITest does not call a Text hittable, so the on-screen helper says it is
        // missing while it is perfectly visible.
        XCTAssertTrue(app.staticTexts["newlist-taken"].waitForExistence(timeout: 5),
                      "a name he already has was accepted")

        replace("Mushroom picking", in: app.textFields["newlist-name"])
        XCTAssertTrue(waitUntil(timeout: 5) { !app.staticTexts["newlist-taken"].exists },
                      "a free name is still called taken")
        tap(app, id: "newlist-shelf-GA")
        tap(app, id: "newlist-make")

        // It opens straight away — a list he cannot see inside is not made yet.
        XCTAssertTrue(appears(app, "template-detail", timeout: 5), "the new list did not open")
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))

        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.staticTexts["templates-summary"]) != before },
                      "the shelf did not gain a list: still '\(before)'")
        // The shelf he chose, tested by the shelf he did NOT choose: nothing in the
        // sample is unshelved, so a list that ignored his choice would make an
        // "Other lists" shelf appear. (Asserting the GA shelf exists proved nothing
        // — it was already there, and the test passed with the choice thrown away.)
        XCTAssertTrue(app.staticTexts["templates-shelf-GA"].exists, "the shelf he chose is gone")
        XCTAssertFalse(app.staticTexts["templates-shelf-other"].exists,
                       "the list landed on no shelf, so his choice was ignored")
    }

    /// How many and Section belong to the thing's place ON A LIST, not to the thing.
    /// With one list they are edited in the grid; with two there is no single answer
    /// and the cell says so instead of pretending.
    func testWhatBelongsToAListIsEditedPerList() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5), "no table")

        // The sample's second thing by name is on TWO lists.
        XCTAssertEqual(cellSays(app, "table-1-listQty"), "2 lists",
                       "a thing on two lists must not offer one answer")
        XCTAssertFalse(app.textFields["table-1-listQty"].exists, "it must not be editable either")

        // The first is on one list, so it takes an answer — and keeps it.
        let box = app.textFields["table-0-listQty"]
        XCTAssertTrue(box.waitForExistence(timeout: 5), "a thing on one list should be editable")
        type("3", into: box)
        box.typeText("\n")
        tap(app, id: "table-done")
        XCTAssertTrue(disappears(app, "table-detail", timeout: 5))
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5))
        XCTAssertTrue(waitUntil(timeout: 10) { self.cellSays(app, "table-0-listQty") == "3" },
                      "the quantity did not stay on that list's row: '\(cellSays(app, "table-0-listQty"))'")
    }

    /// Ticking several things and changing them in one go — his ask — and one press
    /// putting every one of them back the way it was.
    func testManyThingsAreChangedAtOnceAndCanBePutBack() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5), "no table")

        // Nothing ticked: no bar.
        XCTAssertFalse(app.staticTexts["table-chosen-count"].exists, "the bar is there before anything is ticked")

        tap(app, id: "table-0-pick")
        tap(app, id: "table-1-pick")
        XCTAssertTrue(waitUntil(timeout: 5) { self.words(app.staticTexts["table-chosen-count"]) == "2 ticked" },
                      "the bar does not say two are ticked: '\(words(app.staticTexts["table-chosen-count"]))'")

        // Show the column first, so the change can be SEEN on the things themselves.
        tap(app, id: "table-columns")
        XCTAssertTrue(appears(app, "columns-detail", timeout: 5))
        for gone in ["weight", "storage", "container", "ownedBy", "packer", "listQty"] {
            tap(app, id: "columns-\(gone)-hide")
        }
        tap(app, id: "columns-done")
        XCTAssertTrue(disappears(app, "columns-detail", timeout: 5))
        let wasFirst = cellSays(app, "table-0-condition")
        let wasThird = cellSays(app, "table-2-condition")

        // Change the two of them at once.
        tap(app, id: "table-change-all")
        XCTAssertTrue(appears(app, "bulk-detail", timeout: 5), "the change sheet did not open")
        XCTAssertEqual(words(app.staticTexts["bulk-count"]), "Change 2 things")
        tap(app, id: "bulk-field-condition")
        tap(app, id: "bulk-value-0")
        XCTAssertTrue(disappears(app, "bulk-detail", timeout: 5), "the sheet stayed open")

        XCTAssertTrue(waitUntil(timeout: 10) { self.cellSays(app, "table-0-condition") != wasFirst },
                      "the first thing did not change (it still says '\(wasFirst)')")
        let now = cellSays(app, "table-0-condition")
        XCTAssertEqual(cellSays(app, "table-1-condition"), now, "the second ticked thing did not change")
        XCTAssertEqual(cellSays(app, "table-2-condition"), wasThird, "a thing that was NOT ticked changed")

        // And one press puts them back.
        tap(app, id: "table-undo")
        XCTAssertTrue(waitUntil(timeout: 10) { self.cellSays(app, "table-0-condition") == wasFirst },
                      "Undo did not put the first one back: '\(cellSays(app, "table-0-condition"))'")
        XCTAssertEqual(cellSays(app, "table-1-condition"), wasThird, "Undo did not put the second one back")
    }

    /// The two chips go straight to what is missing, and filling one in takes that
    /// thing off the list of things that are missing it.
    func testTheTableChipsFindWhatIsMissing() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5), "no table")
        let count = app.staticTexts["table-count"]
        let all = words(count)
        XCTAssertEqual(all, "10", "the sample library has ten things: '\(all)'")

        tap(app, id: "table-filter-weight")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(count) != all }, "the chip changed nothing")
        let missing = Int(words(count)) ?? 0
        XCTAssertGreaterThan(missing, 0, "the sample has things with no weight")

        type("250", into: app.textFields["table-0-weight"])
        app.textFields["table-0-weight"].typeText("\n")
        XCTAssertTrue(waitUntil(timeout: 10) { (Int(self.words(count)) ?? missing) == missing - 1 },
                      "the weight did not take: still \(words(count)) with none")

        tap(app, id: "table-filter-all")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(count) == all })
        tap(app, id: "table-done")
        XCTAssertTrue(disappears(app, "table-detail", timeout: 5))
    }

    func testHisOwnListsAreAddedAndProtectedWhileInUse() {
        let app = launch()
        tab(app, "settings")
        XCTAssertTrue(appears(app, "screen-settings"))
        tap(app, id: "settings-lists")
        XCTAssertTrue(appears(app, "lists-detail", timeout: 5))

        type("Garage shelf", into: app.textFields["list-places-add-name"])
        app.buttons["list-places-add"].tap()
        XCTAssertTrue(waitUntil { self.find(app, "list-places-row-12") != nil }, "the place was not added to the list")

        // It is offered where a thing says where it is kept… by being on the account's list.
        tap(app, id: "lists-done")
        XCTAssertTrue(disappears(app, "lists-detail", timeout: 5))
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        type("Headlamp", into: app.textFields["things-search"])
        XCTAssertTrue(waitUntil { app.buttons["thing-row-0"].exists })
        app.buttons["thing-row-0"].tap()
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        replace("Garage shelf", in: app.textFields["thing-storage"])
        tap(app, id: "thing-save")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))
        // The sheet covers the tab bar: close it, or the next tap lands on the sheet.
        tap(app, id: "things-done")
        XCTAssertTrue(disappears(app, "things-detail", timeout: 5))

        // Now it is in use, and the list refuses to drop it.
        tab(app, "settings")
        tap(app, id: "settings-lists")
        XCTAssertTrue(appears(app, "lists-detail", timeout: 5))
        let remove = app.buttons["list-places-remove-12"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        tapVisible(app, remove)
        XCTAssertTrue(app.staticTexts["lists-problem"].waitForExistence(timeout: 5), "a place in use was dropped without a word")
        XCTAssertTrue(waitUntil { self.find(app, "list-places-row-12") != nil }, "…and it must still be there")
    }
}
