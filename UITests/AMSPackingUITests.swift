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

    /// `-uiTesting` = an invented library held in memory: no iCloud, the same on the
    /// simulator, the Mac and GitHub. `-uiTestingEmpty` = nothing at all. (The copies
    /// kept before a restore ARE real files; the app deletes them at launch under the
    /// tests. Every launch mode: `LibraryModel.forThisLaunch`.)
    private func launch(_ mode: String = "-uiTesting", _ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [mode] + extra
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

    /// Runs FIRST (tests run in name order): opens the app once, so a freshly started
    /// simulator has done its slow first launch before any real test needs it. On
    /// GitHub the first tests failed at the launch itself — "Failed to get background
    /// assertion… Timed out" (0.53) — or ran past their time (0.46, 0.50), with the app
    /// fine. A failure HERE is expected and allowed; it proves nothing about the app.
    func testAAAWarmsUpTheSimulator() {
        XCTExpectFailure("a cold simulator may fumble its first launch", options: .nonStrict()) {
            let app = launch()
            _ = appears(app, "screen-home", timeout: 60)
            app.terminate()
        }
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

    /// Keeps a picture of the screen when asked to: the folder in SHOTS_DIR, which
    /// xcodebuild hands the runner when the line starts `TEST_RUNNER_SHOTS_DIR=<folder>`.
    /// No test switches to night mode: put the simulator in dark mode first
    /// (`xcrun simctl ui <device> appearance dark`) and run the same tests again — how a
    /// build is LOOKED at, day and night, before anyone is told it is done.
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

    /// His floor (F073, 5 Oct 2026): nothing a person reads is under 15 points — he
    /// reads without his glasses. One line of 15-point words stands about 18 points
    /// tall (14 → 17, 11 → 13), so words that were the smallest and stay on one line
    /// are measured where they stand; and a long label is given room rather than shrunk, so "Templates"
    /// gets the tab width it needs at 15 (74 points, where an even sixth of an iPhone
    /// is 67). Every screen the change touched is photographed on the way.
    func testTheSmallestWordsAreFifteenPoints() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        let tall: CGFloat = 17.5

        // The version marker (it was 11) and the tab that needs the most room.
        let version = app.staticTexts["app-version"]
        XCTAssertTrue(version.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(version.frame.height, tall, "the version is drawn under 15 pt")
        let templatesTab = app.buttons["tab-templates"]
        XCTAssertGreaterThanOrEqual(templatesTab.frame.width, 74,
                                    "the Templates tab is too narrow for its name at 15 pt")
        shot(app, "type-home")

        // Trips: Your year and All your trips, under the trips.
        tab(app, "events")
        let year = app.otherElements["events-year"]
        XCTAssertTrue(year.waitForExistence(timeout: 5), "no Your year on Trips")
        bringIntoView(app, year)
        shot(app, "type-trips-year")

        // Templates: the line saying when each was last taken (it was 12). Photographed,
        // not measured: it wraps, so two lines of 12 would pass for one of 15.
        tab(app, "templates")
        XCTAssertTrue(app.staticTexts["template-used"].firstMatch.waitForExistence(timeout: 5),
                      "no template card says when it was used")
        shot(app, "type-templates")
        tap(app, id: "template-row-1")
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        tap(app, id: "template-cover")
        XCTAssertTrue(appears(app, "icon-picker", timeout: 5), "the cover did not open the icons")
        shot(app, "type-icon-picker")
        tap(app, id: "icon-cancel")
        XCTAssertTrue(disappears(app, "icon-picker", timeout: 5))
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))

        // Care: its doors first (a lazy screen forgets them once scrolled far down).
        tab(app, "care")
        XCTAssertTrue(appears(app, "screen-care"))
        shot(app, "type-care-doors")

        // The table: its cells and headings (13–14 and 12, bands 11).
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5), "no table")
        let name = app.staticTexts["table-0-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(name.frame.height, tall, "the table's names are under 15 pt")
        shot(app, "type-table")
        tap(app, id: "table-done")
        XCTAssertTrue(disappears(app, "table-detail", timeout: 5))

        // Your bags (column names 10, the glance line 12) and a bag's page.
        tap(app, id: "care-bags")
        XCTAssertTrue(appears(app, "yourbags-detail", timeout: 5))
        type("Duffel bag", into: app.textFields["bag-new-name"])
        tap(app, id: "bag-new")
        XCTAssertTrue(waitUntil { app.buttons["bag-0-name"].exists }, "the bag was not made")
        tap(app, id: "bag-0-name")
        XCTAssertTrue(appears(app, "bag-detail", timeout: 5), "the bag's page did not open")
        shot(app, "type-bag-page")
        tap(app, id: "bag-done")
        XCTAssertTrue(disappears(app, "bag-detail", timeout: 5))
        shot(app, "type-your-bags")
        tap(app, id: "yourbags-done")
        XCTAssertTrue(disappears(app, "yourbags-detail", timeout: 5))

        // The calendar (weekday row 11, counts 10), then — scrolled down — the kit's
        // figures (their words were 12) and the year ahead (months 10).
        tap(app, id: "care-view-calendar")
        XCTAssertTrue(app.staticTexts["care-cal-title"].waitForExistence(timeout: 5), "Calendar did not open")
        shot(app, "type-care-calendar")
        tap(app, id: "care-view-list")
        // The overdue boots looked after today are next due in 90 days: the year
        // ahead has something to show.
        tap(app, id: "care-row-0-done")
        let figures = app.otherElements["kit-things"].exists ? app.otherElements["kit-things"] : app.staticTexts["kit-things"]
        XCTAssertTrue(figures.waitForExistence(timeout: 5), "no kit figures on Care")
        bringIntoView(app, figures)
        shot(app, "type-care-kit")
        // The part under the year ahead brings it on screen.
        for id in ["kit-year-heading", "kit-tips-heading"] where app.staticTexts[id].exists {
            bringIntoView(app, app.staticTexts[id])
        }
        shot(app, "type-care-year-ahead")

        // Search (its part headings were 12) and Grab Lists (its pills were 13).
        tab(app, "home")
        tap(app, id: "search-open")
        XCTAssertTrue(appears(app, "search-detail", timeout: 5))
        type("a", into: app.textFields["search-field"])
        hideKeyboard(app)
        shot(app, "type-search")
        tap(app, id: "search-done")
        XCTAssertTrue(disappears(app, "search-detail", timeout: 5))
        tap(app, id: "grab-lists")
        XCTAssertTrue(appears(app, "grablists-detail", timeout: 5))
        shot(app, "type-grab-lists")
        tap(app, id: "grablists-done")
        XCTAssertTrue(disappears(app, "grablists-detail", timeout: 5))
    }

    /// Every tab opens its own screen — and leaves the previous one.
    func testEveryTabOpensItsScreen() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))

        for name in ["events", "templates", "care", "actions", "settings", "home"] {
            XCTAssertTrue(app.buttons["tab-\(name)"].waitForExistence(timeout: 5), "no tab-\(name)")
            // His name for it (G.4, 2026-09-30): the Actions tab says To do.
            if name == "actions" {
                XCTAssertTrue(words(app.buttons["tab-actions"]).hasPrefix("To do"),
                              "the tab still says '\(words(app.buttons["tab-actions"]))'")
            }
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
        // An activity area says his own code as well as the words, as the web app does.
        XCTAssertEqual(words(app.staticTexts["templates-area-GA"]), "GA · GOAL ACTIVITY")
        XCTAssertTrue(words(app.staticTexts["templates-summary"]).contains("templates"),
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
    /// Sync now on a new, empty device — or the other device's check-in arriving —
    /// made the library "not empty": the two doors went and the backup was refused
    /// (the spec pass, 2026-10-05). A check-in is about the device; the doors stay.
    func testSyncNowOnAnEmptyDeviceKeepsTheTwoDoors() {
        let app = launch("-uiTestingEmpty")
        XCTAssertTrue(app.buttons["first-run-import"].waitForExistence(timeout: 20))
        tab(app, "settings")
        XCTAssertTrue(appears(app, "screen-settings"))
        tap(app, id: "sync-now")
        let me = app.staticTexts["sync-self"]
        XCTAssertTrue(waitUntil { self.words(me).contains("checked in today") }, "Sync now did not check in: '\(words(me))'")
        tab(app, "home")
        XCTAssertTrue(app.buttons["first-run-import"].waitForExistence(timeout: 5),
                      "one check-in shut the doors of an empty device")
    }

    /// A tick counts, and it is still there after leaving the trip and coming back.
    func testATickCountsAndStays() {
        let app = launch()
        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        // NOW is always there, even with nothing under way (his test G.1); the sample
        // trip is coming up.
        XCTAssertTrue(app.staticTexts["events-pile-now"].waitForExistence(timeout: 5), "no Now pile")
        XCTAssertTrue(app.staticTexts["events-now-empty"].exists, "an empty Now does not say so")
        XCTAssertEqual(words(app.staticTexts["events-pile-now-count"]), "0")
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

    /// Scroll INSIDE a named screen (a sheet) until a control exists — the gesture
    /// goes to the sheet itself, so it can never move the screen behind it (the
    /// trap of 2026-09-25/26), and the keyboard is put away first.
    @discardableResult
    private func scrollWithin(_ app: XCUIApplication, _ screen: String, until id: String, tries: Int = 10) -> Bool {
        for attempt in 0..<tries {
            if app.buttons[id].exists { return true }
            guard let sheet = find(app, screen) else { return false }
            // The list INSIDE the sheet: swiping the sheet's middle can land on the
            // keyboard's edge; the list scrolls — and, scrolling, puts the keyboard away.
            let inner = sheet.descendants(matching: .scrollView).firstMatch
            let target = inner.exists ? inner : sheet
            #if os(macOS)
            target.scroll(byDeltaX: 0, deltaY: attempt < tries / 2 ? -220 : 220)
            #else
            target.swipeUp()
            #endif
            usleep(300_000)
        }
        let found = app.buttons[id].exists
        if !found { print("TAP-REPORT scrollWithin \(screen) never found \(id)\n" + String(app.debugDescription.prefix(15000))) }
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
        // 🪤 Neither: with the keyboard up, the frontmost "list" is the text field being
        // typed in (a 44-point scroll view), and the trip's own list sits between it
        // and the screen behind (0.52, Bought on site). Ask each one, front to back.
        for list in app.scrollViews.allElementsBoundByIndex.reversed()
        where list.exists && list.descendants(matching: .any)[e.identifier].exists { return list }
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
        // 🪤 A list still gliding from the swipe takes a tap as "stop", not as a press:
        // Start a new trip was tapped mid-glide on GitHub and nothing started (0.49).
        _ = waitUntil(timeout: 3) { e.exists && self.settled(e) }
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
            // keyboard instead left the Grab Lists screen untappable (same day).
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
            // Near the right end, inside the padding's edge: the cursor lands AFTER the
            // text, so deleting from it removes all of it. (The middle of a long name
            // left half of it: "Carry-on / hand luggage" became "Cabin bag luggage".)
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
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
        // Further down than the everyday doors (his K.2, 1 Oct 2026).
        XCTAssertGreaterThan(save.frame.minY, app.buttons["settings-lists"].frame.maxY, "Save a backup is still above Your choices")
        // What this device holds, for the day-and-night look (the web app's kits are
        // counted as "Groups of things" since the spec pass, 5 Oct 2026).
        bringIntoView(app, app.staticTexts["device-count-kits"])
        shot(app, "settings-device-holds")
        tapVisible(app, save)
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
        // His words (2026-09-26): the central button must never look switched off.
        // It is always pressable; pressed too early it makes nothing and says why.
        let create = app.buttons["trip-create"]
        XCTAssertTrue(create.exists && create.isEnabled, "Create trip is greyed out")
        tapVisible(app, create)
        let needs = app.staticTexts["trip-create-needs"]
        XCTAssertTrue(needs.waitForExistence(timeout: 5), "an early press said nothing about what is missing")
        XCTAssertEqual(words(needs), "Give the trip a name and pick at least one template.")
        XCTAssertNil(find(app, "trip-detail"), "a trip was made with nothing chosen")
        type("Test trip", into: field)
        XCTAssertTrue(waitUntil { self.words(needs) == "Pick at least one template." }, "the hint did not follow: '\(words(needs))'")
        select(app, app.buttons["trip-activity-0"])
        XCTAssertTrue(waitUntil { !needs.exists }, "the hint stayed after everything was there")
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
        // An American-set device writes "Oct 1, 2026" its own way — the trip row must not.
        let app = launch("-uiTesting", ["-AppleLocale", "en_US"])
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
        // It waits for OK (their field test, Oct 2026).
        tap(app, id: "range-ok")
        XCTAssertTrue(waitUntil { !app.staticTexts["range-title-0"].exists }, "OK did not close the grid")

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
        tap(app, id: "range-ok")
        XCTAssertTrue(waitUntil { !app.staticTexts["range-title-0"].exists }, "OK did not close the grid")

        // The trip made keeps them.
        type("Dated trip", into: app.textFields["trip-name"])
        select(app, app.buttons["trip-activity-0"])
        let create = app.buttons["trip-create"]
        tapVisible(app, create)
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5), "the new trip did not open")
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))
        tab(app, "events")
        // The row writes a day in the same English words on every device, "27 Sep 2026"
        // (the spec pass, 5 Oct 2026 — before, the device's way: "Sep 27, 2026" on
        // GitHub's Mac and on an American-set iPhone).
        let c1 = cal.dateComponents([.year, .day, .month], from: day(1))
        let startDay = "\(c1.day!)", startMonth = mo[c1.month! - 1], startYear = "\(c1.year!)"
        let row = (0..<6).map { app.buttons["trip-row-\($0)"] }.first { $0.exists && self.words($0).contains("Dated trip") }
        XCTAssertNotNil(row, "the dated trip is not listed")
        if let row {
            let said = words(row)
            let first = said.range(of: "Dated trip").map { String(said[$0.upperBound...]) } ?? said
            let startsRight = first.range(of: "\\b\(startDay) \(startMonth) \(startYear)\\b", options: .regularExpression) != nil
            XCTAssertTrue(startsRight, "the trip lost its first day, or wrote it the device's way (\(startDay) \(startMonth) \(startYear)): '\(said)'")
        }
        shot(app, "trips-row-dates")
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

    /// The gap list (2026-09-26): a trip can be deleted — last on its screen, and only
    /// after it asks. "Keep it" keeps it; the things and lists stay either way.
    func testATripIsDeletedOnlyAfterAsking() {
        let app = launch()
        tab(app, "care")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["care-line"]).hasPrefix("10 things") })
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        // A photo of a packed bag, which must go with the trip (his ask, 4 Oct 2026).
        tap(app, id: "bag-0")
        tap(app, id: "bag-0-photo")
        XCTAssertTrue(app.buttons["bag-0-photo-thumb-0"].waitForExistence(timeout: 5), "no bag photo to delete with the trip")
        tap(app, id: "trip-delete")
        XCTAssertTrue(app.buttons["trip-delete-yes"].waitForExistence(timeout: 5), "it did not ask first")
        tap(app, id: "trip-delete-no")
        XCTAssertTrue(waitUntil { !app.buttons["trip-delete-yes"].exists }, "Keep it did not keep it")
        XCTAssertTrue(find(app, "trip-detail") != nil, "Keep it closed the trip")

        tap(app, id: "trip-delete")
        tap(app, id: "trip-delete-yes")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5), "the trip did not close after its delete")
        XCTAssertTrue(waitUntil { !app.buttons["trip-row-0"].exists }, "the deleted trip is still listed")
        tab(app, "care")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["care-line"]).hasPrefix("10 things") },
                      "deleting a trip must not take his things: '\(words(app.staticTexts["care-line"]))'")
        tab(app, "settings")
        let photos = app.staticTexts["device-count-photos"]
        bringIntoView(app, photos)
        XCTAssertEqual(words(photos), "0", "the deleted trip's bag photo stayed behind")
    }

    /// A photo left behind by a trip deleted before 0.59: Worth a look says so and
    /// removes it in one press.
    func testWorthALookRemovesAPhotoLeftBehind() {
        let app = launch("-uiTestingOldPhoto")
        tab(app, "settings")
        let says = app.staticTexts["health-0"]
        XCTAssertTrue(says.waitForExistence(timeout: 5), "Worth a look does not mention the photo")
        XCTAssertTrue(words(says).hasPrefix("1 photo is no longer shown anywhere"), "'\(words(says))'")
        // The one whose age cannot be read is named on its own (the spec pass, 2026-10-05):
        // never offered with the old one, and until now never mentioned at all.
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["health-1"]).hasPrefix("1 photo with no date") },
                      "the photo with no date is not mentioned: '\(words(app.staticTexts["health-1"]))'")
        bringIntoView(app, app.buttons["health-0-fix"])
        shot(app, "health-photo")
        tap(app, id: "health-0-fix")
        let photos = app.staticTexts["device-count-photos"]
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["health-0"]).hasPrefix("1 photo with no date") },
                      "Remove it took the photo with no date along, or left the old one: '\(words(app.staticTexts["health-0"]))'")
        bringIntoView(app, photos)
        XCTAssertEqual(words(photos), "1", "Remove it did not take exactly the old photo")
        bringIntoView(app, app.buttons["health-0-fix"])
        tap(app, id: "health-0-fix")
        XCTAssertTrue(waitUntil { !app.staticTexts["health-heading"].exists }, "Worth a look stayed after Remove it")
        bringIntoView(app, photos)
        XCTAssertEqual(words(photos), "0", "the photo is still on the device")
    }

    /// His ask (2026-09-26), packing by From where: a thing under "No place set" gets
    /// its place right there — one of his places, or a new one typed — and moves
    /// under that place.
    func testAPlaceIsSetFromTheTrip() {
        let app = launch()
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        let total = Int(words(progress).split(separator: "/").last ?? "") ?? 0
        // Two things with no place: typed on the trip.
        for name in ["Tripod", "Sit mat"] {
            type(name, into: app.textFields["trip-add-name"])
            XCTAssertTrue(waitUntil { app.buttons["trip-add"].isEnabled })
            tap(app, id: "trip-add")
        }
        XCTAssertTrue(waitUntil { self.words(progress).hasSuffix("/\(total + 2)") }, "the two lines were not added")
        tap(app, id: "trip-view-2")
        XCTAssertTrue(waitUntil { app.buttons["trip-view-2"].isSelected })
        func headings() -> [String] { (0..<12).map { app.staticTexts["trip-group-\($0)-label"] }.filter { $0.exists }.map { self.words($0) } }

        // "No place set" is the last section: travel down it — in the TRIP's list, not
        // the Trips screen behind it (scroll the list that holds a line on screen).
        // One of his places, two taps.
        XCTAssertTrue(scrollWithin(app, "trip-detail", until: "trip-line-\(total)-place"), "no Set place on a thing without a place")
        tap(app, id: "trip-line-\(total)-place")
        XCTAssertTrue(appears(app, "trip-place-panel", timeout: 5), "Set place did not offer the places")
        let first = app.buttons["trip-place-0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5), "no places offered")
        let place = words(first)
        tap(app, id: "trip-place-0")
        XCTAssertTrue(waitUntil { !app.buttons["trip-line-\(total)-place"].exists }, "the thing still has no place")

        // A new place, typed.
        XCTAssertTrue(scrollWithin(app, "trip-detail", until: "trip-line-\(total + 1)-place"), "no Set place on the second thing")
        tap(app, id: "trip-line-\(total + 1)-place")
        XCTAssertTrue(appears(app, "trip-place-panel", timeout: 5))
        // Into view first: near the end of the list the field can sit half behind the
        // "Add a thing" bar, and a tap on its middle lands on the bar (0.38).
        bringIntoView(app, app.textFields["trip-place-new"])
        type("Boot room", into: app.textFields["trip-place-new"])
        XCTAssertTrue(waitUntil { app.buttons["trip-place-save"].isEnabled })
        tap(app, id: "trip-place-save")
        XCTAssertTrue(waitUntil { !app.buttons["trip-line-\(total + 1)-place"].exists }, "the second thing still has no place")

        // Opened again (at the top, still From where): both places are sections now.
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(waitUntil { headings().contains("Boot room") && headings().contains(place) },
                      "the places set on the trip are not its sections: \(headings()) (wanted Boot room and \(place))")
    }

    /// His asks (2026-09-26): a bag opens its own page; it is renamed there — and
    /// the trips follow (his choice: all trips); it is deleted there, its things
    /// first moved to the bag he picks (his choice).
    func testABagIsRenamedAndDeletedFromItsPage() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-bags")
        XCTAssertTrue(appears(app, "yourbags-detail", timeout: 5))
        for name in ["Carry-on / hand luggage", "Duffel bag"] {
            type(name, into: app.textFields["bag-new-name"])
            XCTAssertTrue(waitUntil { app.buttons["bag-new"].isEnabled })
            tap(app, id: "bag-new")
        }
        XCTAssertTrue(waitUntil { app.buttons["bag-1-name"].exists }, "the two bags were not made")

        // The page, and what it knows: the sample's things go in the carry-on.
        tap(app, id: "bag-0-name")
        XCTAssertTrue(appears(app, "bag-detail", timeout: 5), "the bag's page did not open")
        let count = app.staticTexts["bag-things-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        let inIt = Int(words(count)) ?? 0
        XCTAssertGreaterThan(inIt, 0, "the page does not know what goes in the bag")

        // Renamed.
        replace("Cabin bag", in: app.textFields["bag-name"])
        tap(app, id: "bag-rename")
        XCTAssertTrue(waitUntil { !app.buttons["bag-rename"].exists }, "the rename was not taken")
        tap(app, id: "bag-done")
        XCTAssertTrue(disappears(app, "bag-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.buttons["bag-0-name"]).contains("Cabin bag") },
                      "the list still shows the old name: '\(words(app.buttons["bag-0-name"]))'")
        tap(app, id: "yourbags-done")
        XCTAssertTrue(disappears(app, "yourbags-detail", timeout: 5))
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let firstBag = app.descendants(matching: .any)["bag-0"]
        XCTAssertTrue(firstBag.waitForExistence(timeout: 5), "no Bags card")
        XCTAssertTrue(waitUntil { self.words(firstBag).contains("Cabin bag") }, "the trip kept the old name: '\(words(firstBag))'")
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))

        // Deleted — only after choosing where its things go.
        tab(app, "care")
        tap(app, id: "care-bags")
        XCTAssertTrue(appears(app, "yourbags-detail", timeout: 5))
        tap(app, id: "bag-0-name")
        XCTAssertTrue(appears(app, "bag-detail", timeout: 5))
        XCTAssertTrue(scrollWithin(app, "bag-detail", until: "bag-delete"), "no Delete on the bag's page")
        tap(app, id: "bag-delete")
        XCTAssertTrue(scrollWithin(app, "bag-detail", until: "bag-delete-yes"), "it did not ask")
        // Said plainly (his words, 2026-09-27): the things packed in THIS bag will be
        // packed in another one — which?
        let explain = app.staticTexts["bag-delete-explain"]
        XCTAssertTrue(explain.waitForExistence(timeout: 5), "the delete does not explain itself")
        XCTAssertTrue(words(explain).contains("packed in the Cabin bag will be packed in another bag"),
                      "the explanation is not the plain one: '\(words(explain))'")
        XCTAssertTrue(app.buttons["bag-move-none"].exists, "no way to leave its things without a bag (his ask, 2026-09-27)")
        tap(app, id: "bag-delete-yes")
        XCTAssertTrue(find(app, "bag-detail") != nil, "it deleted before a bag was chosen for its things")
        // Full colour, and pressed too early it says what is missing (his rule).
        XCTAssertTrue(app.staticTexts["bag-delete-needs"].waitForExistence(timeout: 5),
                      "pressed before a bag was chosen, Delete said nothing")
        shot(app, "bag-delete-needs")
        tap(app, id: "bag-move-0")
        tap(app, id: "bag-delete-yes")
        // 15 s: the suite's FIRST test meets GitHub's freshly started simulator, slow at
        // everything — 0.50's run took 6 s here and went red with the delete done.
        XCTAssertTrue(disappears(app, "bag-detail", timeout: 15), "the page did not close after the delete")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["yourbags-count"]) == "1" }, "the bag is still listed")
        tap(app, id: "bag-0-name")
        XCTAssertTrue(appears(app, "bag-detail", timeout: 5))
        XCTAssertTrue(waitUntil { Int(self.words(app.staticTexts["bag-things-count"])) == inIt },
                      "its \(inIt) things did not move to the Duffel bag: '\(words(app.staticTexts["bag-things-count"]))'")
        tap(app, id: "bag-done")
        XCTAssertTrue(disappears(app, "bag-detail", timeout: 5))

        // A bag NOTHING is packed in (his Handbag, 2026-09-27): no choosing, a plain delete.
        type("Spare bag", into: app.textFields["bag-new-name"])
        XCTAssertTrue(waitUntil { app.buttons["bag-new"].isEnabled })
        tap(app, id: "bag-new")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["yourbags-count"]) == "2" }, "the spare bag was not made")
        tap(app, id: "bag-1-name")
        XCTAssertTrue(appears(app, "bag-detail", timeout: 5))
        XCTAssertTrue(scrollWithin(app, "bag-detail", until: "bag-delete"))
        tap(app, id: "bag-delete")
        XCTAssertTrue(app.staticTexts["bag-delete-empty"].waitForExistence(timeout: 5), "an empty bag still asks where its things go")
        XCTAssertFalse(app.buttons["bag-move-none"].exists, "an empty bag offers bags to move nothing to")
        tap(app, id: "bag-delete-yes")
        XCTAssertTrue(disappears(app, "bag-detail", timeout: 5), "the empty bag was not deleted at once")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["yourbags-count"]) == "1" }, "the empty bag is still listed")

        // A bag that is ALSO a thing he packs (his Day pack on Travel, 2026-09-27): the
        // sample's Rain jacket, on Hiking, made a bag. Deleting asks: keep it on Hiking,
        // or delete it completely.
        type("Rain jacket", into: app.textFields["bag-new-name"])
        XCTAssertTrue(waitUntil { app.buttons["bag-new"].isEnabled })
        tap(app, id: "bag-new")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["yourbags-count"]) == "2" }, "the thing did not become a bag")
        tap(app, id: "bag-1-name")
        XCTAssertTrue(appears(app, "bag-detail", timeout: 5))
        XCTAssertTrue(scrollWithin(app, "bag-detail", until: "bag-delete"))
        tap(app, id: "bag-delete")
        XCTAssertTrue(app.staticTexts["bag-delete-lists"].waitForExistence(timeout: 5), "it does not say the bag is also on a list")
        XCTAssertTrue(scrollWithin(app, "bag-detail", until: "bag-delete-all"), "no Delete completely")
        XCTAssertTrue(app.buttons["bag-delete-yes"].exists, "no Keep it on the list")
        tap(app, id: "bag-delete-all")
        // 15 s: on GitHub's cold iPhone (the first test after the warm-up) the page
        // took longer than 5 to close (0.58's first run, 4 Oct 2026).
        XCTAssertTrue(disappears(app, "bag-detail", timeout: 15))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["yourbags-count"]) == "1" })
        tap(app, id: "yourbags-done")
        XCTAssertTrue(disappears(app, "yourbags-detail", timeout: 5))
        // 10 sample things + the Duffel bag − the Rain jacket, deleted completely.
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["care-line"]).hasPrefix("10 things") },
                      "Delete completely left the thing: '\(words(app.staticTexts["care-line"]))'")
    }

    /// His ask (2026-09-27): a thing can be deleted from its details — small, at the
    /// side, asking first; Keep it keeps it.
    func testAThingIsDeletedOnlyAfterAsking() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        let count = app.staticTexts["things-count"]
        XCTAssertTrue(waitUntil { self.words(count) == "10 things" }, "'\(words(count))'")
        tap(app, id: "thing-row-0")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        XCTAssertTrue(scrollWithin(app, "thing-detail", until: "thing-delete"), "no Delete thing")
        tap(app, id: "thing-delete")
        XCTAssertTrue(scrollWithin(app, "thing-detail", until: "thing-delete-yes"), "it did not ask first")
        tap(app, id: "thing-delete-no")
        XCTAssertTrue(waitUntil { !app.buttons["thing-delete-yes"].exists }, "Keep it did not keep it")
        tap(app, id: "thing-delete")
        XCTAssertTrue(scrollWithin(app, "thing-detail", until: "thing-delete-yes"))
        tap(app, id: "thing-delete-yes")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5), "the editor did not close")
        XCTAssertTrue(waitUntil { self.words(count) == "9 things" }, "the thing was not deleted: '\(words(count))'")
    }

    /// Refine (roadmap stop E): what the reviews say a list carries for nothing. The
    /// sample's Map was packed 3× and never used; its Headlamp listed 2× (on two
    /// lists) and never packed; its boots had ONE quiet trip — not evidence. Keep
    /// settles one; Drop asks first, then takes it off that one list only.
    func testRefineOffersWhatTheReviewsFoundAndKeepAndDropSettleIt() {
        let app = launch()
        tab(app, "templates")
        let door = app.buttons["refine-open"]
        XCTAssertTrue(door.waitForExistence(timeout: 5), "no Refine on Your lists")
        XCTAssertTrue(waitUntil { (door.value as? String) == "3" }, "Refine does not say 3 to look at: '\(door.value as? String ?? "")'")
        tap(app, id: "refine-open")
        XCTAssertTrue(appears(app, "refine-screen", timeout: 5))
        let count = app.staticTexts["refine-count"]
        XCTAssertTrue(waitUntil { self.words(count) == "3" }, "'\(words(count))'")
        XCTAssertEqual(words(app.staticTexts["refine-row-0-name"]), "Map", "most trips first")
        XCTAssertFalse((0..<4).contains { self.words(app.staticTexts["refine-row-\($0)-name"]) == "Hiking boots" },
                       "one quiet trip is offered")

        tap(app, id: "refine-row-0-keep")
        XCTAssertTrue(waitUntil { self.words(count) == "2" }, "Keep did not settle it: '\(words(count))'")
        XCTAssertEqual(words(app.staticTexts["refine-row-0-name"]), "Headlamp")

        tap(app, id: "refine-row-0-drop")
        XCTAssertTrue(app.buttons["refine-row-0-drop-yes"].waitForExistence(timeout: 5), "Drop did not ask first")
        tap(app, id: "refine-row-0-drop-no")
        XCTAssertTrue(waitUntil { !app.buttons["refine-row-0-drop-yes"].exists })
        XCTAssertEqual(words(count), "2", "Keep it still dropped it")
        tap(app, id: "refine-row-0-drop")
        tap(app, id: "refine-row-0-drop-yes")
        XCTAssertTrue(waitUntil { self.words(count) == "1" }, "Drop did not take it off the list: '\(words(count))'")
        XCTAssertEqual(words(app.staticTexts["refine-row-0-name"]), "Headlamp", "dropped from one list, still offered on the other")
        tap(app, id: "refine-done")
        XCTAssertTrue(disappears(app, "refine-screen", timeout: 5))
        XCTAssertTrue(waitUntil { (door.value as? String) == "1" }, "the door did not follow: '\(door.value as? String ?? "")'")
        tab(app, "care")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["care-line"]).hasPrefix("10 things") }, "Drop must not delete the thing")
    }

    /// His loop (2026-09-27): Plan → Pack → Review → Refine, with On site after Pack since
    /// their field test (3 Oct 2026). How it works draws it;
    /// a trip, its review and Refine each show the step they are at, and a tap opens
    /// the whole picture with "You are here" on that step.
    func testTheLoopShowsWhereATripStands() {
        let app = launch()
        tab(app, "settings")
        tap(app, id: "settings-howitworks")
        XCTAssertTrue(appears(app, "guide-howitworks", timeout: 5), "How it works did not open")
        XCTAssertTrue(appears(app, "guide-loop", timeout: 5), "How it works does not show the loop")
        shot(app, "loop-guide")
        for n in 0..<5 { XCTAssertNotNil(find(app, "loop-step-\(n)"), "the loop has no step \(n + 1)") }
        XCTAssertNil(find(app, "loop-step-5"), "the loop has more than five steps")
        // Your first real trip in 6 steps, at the very top (his idea 13, 2 Oct 2026).
        XCTAssertNotNil(find(app, "guide-quickstart"), "How it works has no first-trip guide")
        XCTAssertTrue((0..<6).allSatisfy { app.otherElements["quickstart-step-\($0)"].exists || app.staticTexts["quickstart-step-\($0)"].exists },
                      "the first-trip guide does not have six steps")
        XCTAssertFalse(app.otherElements["quickstart-step-6"].exists || app.staticTexts["quickstart-step-6"].exists, "more than six steps")
        // Each step says the tab where it is done (his test F.7).
        XCTAssertTrue(find(app, "loop-step-0")?.label.contains("on Home") == true, "Plan does not say Home")
        XCTAssertTrue(find(app, "loop-step-2")?.label.hasPrefix("On site") == true, "the third step is not On site")
        XCTAssertTrue(find(app, "loop-step-2")?.label.contains("on Trips") == true, "On site does not say Trips")
        XCTAssertTrue(find(app, "loop-step-4")?.label.contains("on Templates") == true, "Refine does not say Templates")
        // The Words chapter (F.7, I.2) — Kit among them.
        XCTAssertNotNil(find(app, "guide-words"), "How it works has no Words")
        XCTAssertTrue((0..<30).contains { self.words(app.staticTexts["word-\($0)"]) == "Kit" }, "Words does not say what Kit means")
        XCTAssertFalse((0..<5).contains { self.isHere(app, $0) }, "the guide's picture says You are here")
        if let refine = find(app, "loop-step-4") { bringIntoView(app, refine) }
        shot(app, "loop-guide-picture")
        tap(app, id: "guide-done")
        XCTAssertTrue(disappears(app, "guide-howitworks", timeout: 5))

        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let strip = app.buttons["trip-loop"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5), "the trip does not show the loop")
        // The sample trip is ahead (Pack) — or, once its dates are past, waiting for Review.
        let at = strip.value as? String ?? ""
        XCTAssertTrue(["Pack", "Review"].contains(at), "an unreviewed trip with lines is at '\(at)'")
        shot(app, "loop-trip")
        tap(app, id: "trip-loop")
        XCTAssertTrue(appears(app, "loop-screen", timeout: 5), "the strip did not open the picture")
        let step = at == "Pack" ? 1 : 3
        XCTAssertTrue(waitUntil { self.isHere(app, step) }, "the picture does not say You are here on \(at)")
        XCTAssertFalse((0..<5).filter { $0 != step }.contains { self.isHere(app, $0) }, "You are here on more than one step")
        shot(app, "loop-picture")
        tap(app, id: "loop-done")
        XCTAssertTrue(disappears(app, "loop-screen", timeout: 5))

        tap(app, id: "trip-review")
        XCTAssertTrue(appears(app, "review-detail", timeout: 5))
        XCTAssertTrue(waitUntil { (app.buttons["review-loop"].value as? String) == "Review" },
                      "the review is not at Review: '\(app.buttons["review-loop"].value as? String ?? "")'")
        tap(app, id: "review-save")
        XCTAssertTrue(disappears(app, "review-detail", timeout: 5))
        XCTAssertTrue(waitUntil { (strip.value as? String) == "Refine" },
                      "a reviewed trip is not at Refine: '\(strip.value as? String ?? "")'")
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))

        tab(app, "templates")
        tap(app, id: "refine-open")
        XCTAssertTrue(appears(app, "refine-screen", timeout: 5))
        XCTAssertTrue(waitUntil { (app.buttons["refine-loop"].value as? String) == "Refine" },
                      "Refine is not at Refine: '\(app.buttons["refine-loop"].value as? String ?? "")'")
        tap(app, id: "refine-done")
        XCTAssertTrue(disappears(app, "refine-screen", timeout: 5))
    }

    /// Whether the loop picture marks step `n` as "You are here" — read from the box's
    /// label, which both machines report (the Mac drops the value of a box).
    private func isHere(_ app: XCUIApplication, _ n: Int) -> Bool {
        find(app, "loop-step-\(n)")?.label.hasSuffix("You are here") == true
    }

    /// The gap list's first High item (2026-09-27): a trip's settings after it is made.
    /// A new name and one more list reach the trip; the tick he made stays; the trip
    /// says what changed; an empty name is refused and said so, and Cancel changes nothing.
    func testATripsSettingsAreChangedAfterItIsMade() {
        let app = launch()
        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        XCTAssertTrue(waitUntil { self.words(progress) == "0/7" }, "the sample trip is not 0/7: '\(words(progress))'")
        app.buttons["trip-line-0"].tap()
        XCTAssertTrue(waitUntil { self.words(progress) == "1/7" }, "the tick did not count: '\(words(progress))'")

        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5), "the pen did not open Trip settings")
        let name = app.textFields["tripset-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Weekend in the hills", "the settings do not start from the trip")
        replace("Hills and lake", in: name)
        name.typeText("\n")                     // Return puts the keyboard away (no swipe near a sheet)
        // The place is here too (his test G.6).
        let place = app.textFields["tripset-place"]
        XCTAssertTrue(place.waitForExistence(timeout: 5), "Trip settings has no place")
        type("Lakeside", into: place)
        place.typeText("\n")
        // Numbered as on Create new trip: Hiking 0 (already on), Swim 1.
        XCTAssertTrue(isOn(app.buttons["tripset-activity-0"]), "the trip's own list is not shown as on")
        let swim = app.buttons["tripset-activity-1"]
        XCTAssertTrue(swim.waitForExistence(timeout: 5), "no Swim list to add")
        XCTAssertFalse(isOn(swim), "Swim is already on the trip")
        select(app, swim)
        tap(app, id: "tripset-save")                // in the bar at the bottom, always in sight
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5), "Save did not close the settings")

        XCTAssertTrue(waitUntil { self.words(progress) == "1/10" },
                      "Swim's three things did not arrive, or the tick was lost: '\(words(progress))'")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["trip-rebuilt"]).hasPrefix("Saved: 3 new") },
                      "the trip does not say what changed: '\(words(app.staticTexts["trip-rebuilt"]))'")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["trip-name"]) == "Hills and lake" },
                      "the new name did not reach the trip: '\(words(app.staticTexts["trip-name"]))'")

        // No name (only spaces): refused, said under Save, the sheet stays; Cancel keeps the trip.
        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        XCTAssertTrue(waitUntil { (app.textFields["tripset-place"].value as? String) == "Lakeside" },
                      "the place was not kept: '\(app.textFields["tripset-place"].value ?? "")'")
        replace("   ", in: app.textFields["tripset-name"])
        app.textFields["tripset-name"].typeText("\n")
        tap(app, id: "tripset-save")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["tripset-needs"]).contains("name") },
                      "a trip without a name was not refused out loud")
        XCTAssertNotNil(find(app, "tripset-screen"), "the settings closed on an empty name")
        tap(app, id: "tripset-cancel")
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5))
        XCTAssertEqual(words(progress), "1/10", "Cancel changed the trip")
        XCTAssertEqual(words(app.staticTexts["trip-name"]), "Hills and lake", "Cancel changed the name")
    }

    /// The web app's "Start a new trip from this one" (gap list, 2026-09-27): the same
    /// list, nothing ticked; the screen switches to the new trip; the old one keeps
    /// its tick; a blank name is refused out loud.
    func testANewTripStartsFromThisOne() {
        let app = launch()
        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        app.buttons["trip-line-0"].tap()
        XCTAssertTrue(waitUntil { self.words(progress) == "1/7" }, "the tick did not count: '\(words(progress))'")

        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        tapVisible(app, app.buttons["tripset-again"])
        let name = app.textFields["tripset-again-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "Start a new trip did not ask for a name")
        XCTAssertEqual(name.value as? String, "Weekend in the hills (again)", "the name offered is not the web app's")
        // The offered name as it is: nothing typed, so no keyboard in the way.
        tapVisible(app, app.buttons["tripset-again-yes"])
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5), "Start it did not close the settings")

        XCTAssertTrue(waitUntil { self.words(app.staticTexts["trip-name"]) == "Weekend in the hills (again)" },
                      "the screen did not switch to the new trip: '\(words(app.staticTexts["trip-name"]))'")
        XCTAssertTrue(waitUntil { self.words(progress) == "0/7" }, "the new trip is not the same list, unticked: '\(words(progress))'")
        XCTAssertTrue(words(app.staticTexts["trip-rebuilt"]).hasPrefix("New trip from"), "the trip does not say where it came from")

        // A blank name (Return presses Start it) is refused out loud; Cancel starts nothing.
        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        tapVisible(app, app.buttons["tripset-again"])
        let again = app.textFields["tripset-again-name"]
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        replace("   ", in: again)
        again.typeText("\n")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["tripset-again-needs"]).contains("name") },
                      "a blank name was not refused out loud")
        XCTAssertNotNil(find(app, "tripset-screen"), "a trip without a name was started")
        tap(app, id: "tripset-cancel")
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5))
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))

        // Two trips now; the old one still has its tick.
        XCTAssertTrue(waitUntil { app.buttons["trip-row-1"].exists }, "the new trip is not among the trips")
        XCTAssertFalse(app.buttons["trip-row-2"].exists, "the blank name made a trip after all")
        var sawOld = false
        for row in 0..<2 {
            app.buttons["trip-row-\(row)"].tap()
            XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
            if waitUntil(timeout: 3, { self.words(app.staticTexts["trip-name"]) == "Weekend in the hills" }) {
                sawOld = true
                XCTAssertEqual(words(progress), "1/7", "the old trip lost its tick")
            }
            tap(app, id: "trip-done")
            XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))
        }
        XCTAssertTrue(sawOld, "the old trip is gone")
    }

    // MARK: - Trips: the spec pass (5 Oct 2026)

    /// Escape means Cancel, or Done, on every window a trip opens (the spec pass,
    /// 5 Oct 2026): nothing said so, and whether Escape closed one was left to the Mac.
    /// The same key on an iPhone with a keyboard.
    func testEscapeClosesTheTripsWindows() {
        let app = launch()
        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        func escape() {
            sleep(1)                                    // a window just opened: let it take the keys
            #if os(macOS)
            app.typeKey(.escape, modifierFlags: [])
            #else
            // An iPhone with a keyboard: ⌘. is the same Cancel. (The simulator passes no
            // Escape on without a keyboard of its own — tried 5 Oct 2026; ⌘. arrives.)
            app.typeKey(".", modifierFlags: .command)
            #endif
        }

        // With something changed, so only a real Cancel closes it (an iPhone closes an
        // untouched sheet on ⌘. by itself; a changed one it keeps — see the swipe test).
        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        tapVisible(app, app.buttons["tripset-season-1"])
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["tripset-season-1"]) })
        escape()
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5), "Escape did not cancel Trip settings")
        XCTAssertNotNil(find(app, "trip-detail"), "Escape closed the trip behind Trip settings too")
        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        XCTAssertFalse(isOn(app.buttons["tripset-season-1"]), "Escape saved the change instead of cancelling it")
        tap(app, id: "tripset-cancel")
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5))

        app.buttons["trip-line-0"].tap()                          // something packed, for the review to ask about
        tap(app, id: "trip-review")
        XCTAssertTrue(appears(app, "review-detail", timeout: 5))
        tap(app, id: "review-line-0")
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["review-line-0"]) }, "the mark did not take")
        escape()
        XCTAssertTrue(disappears(app, "review-detail", timeout: 5), "Escape did not cancel the review")
        XCTAssertTrue(app.buttons["trip-review"].waitForExistence(timeout: 5), "Escape saved the review")

        tap(app, id: "trip-loop")
        XCTAssertTrue(appears(app, "loop-screen", timeout: 5))
        escape()
        XCTAssertTrue(disappears(app, "loop-screen", timeout: 5), "Escape did not close the loop")

        tapVisible(app, app.buttons["trip-share"])
        XCTAssertTrue(appears(app, "share-screen", timeout: 5))
        escape()
        XCTAssertTrue(disappears(app, "share-screen", timeout: 5), "Escape did not close Share")

        XCTAssertNotNil(find(app, "trip-detail"), "a closed window took the trip with it")
        escape()
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5), "Escape did not close the trip")
    }

    /// His first finding of the spec pass (5 Oct 2026): a trip someone SENT lost its
    /// whole list — ticks too — the first time Trip settings was saved. Sent, opened,
    /// ticked, saved: the list stays as it came, and its tick with it. (Here the
    /// "someone" is this same device, through the link it copies.)
    func testATripSomeoneSentKeepsItsListOnSave() {
        let app = launch()
        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        // The sender's own tick: it tells the two trips apart later (ticks never travel).
        app.buttons["trip-line-0"].tap()
        XCTAssertTrue(waitUntil { self.words(progress) == "1/7" }, "the tick did not count: '\(words(progress))'")
        tapVisible(app, app.buttons["trip-share"])
        XCTAssertTrue(appears(app, "share-screen", timeout: 5), "Share did not open")
        tap(app, id: "share-copy")
        XCTAssertTrue(waitUntil { (app.buttons["share-copy"].value as? String) == "copied" }, "Copy link did not say so")
        tap(app, id: "share-done")
        XCTAssertTrue(disappears(app, "share-screen", timeout: 5))
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))

        tab(app, "settings")
        tap(app, id: "settings-openshared")
        XCTAssertTrue(appears(app, "shared-screen", timeout: 5))
        tap(app, id: "shared-paste")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shared-kind"]) == "A TRIP" }, "the link was not read as a trip")
        XCTAssertEqual(words(app.staticTexts["shared-count"]), "7 things")
        tap(app, id: "shared-add")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shared-result"]).hasPrefix("Added") }, "the trip was not added")
        tap(app, id: "shared-done")
        XCTAssertTrue(disappears(app, "shared-screen", timeout: 5))

        // The received one is the trip with nothing ticked.
        tab(app, "events")
        var found = false
        for row in 0..<2 where !found {
            guard app.buttons["trip-row-\(row)"].waitForExistence(timeout: 5) else { continue }
            app.buttons["trip-row-\(row)"].tap()
            XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
            if waitUntil(timeout: 3, { self.words(progress) == "0/7" }) { found = true; break }
            tap(app, id: "trip-done")
            XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))
        }
        XCTAssertTrue(found, "the received trip is not among the trips")
        app.buttons["trip-line-0"].tap()
        XCTAssertTrue(waitUntil { self.words(progress) == "1/7" }, "the tick on the received trip did not count")
        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        tap(app, id: "tripset-save")
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5), "Save did not close Trip settings")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["trip-rebuilt"]) == "Saved. The list is the same." },
                      "Save changed the received list: '\(words(app.staticTexts["trip-rebuilt"]))'")
        XCTAssertEqual(words(progress), "1/7", "the received list, or its tick, was lost on Save")
        shot(app, "received-trip-saved")
    }

    /// "Not this time" means it did not go (the spec pass, 5 Oct 2026): setting a
    /// ticked line aside takes the tick, a set-aside line does not tick, and taken
    /// back it is unticked. A section with every line set aside has nothing to tick
    /// whole — and no switched-off grey circle either (his rule).
    func testASetAsideLineIsNotPacked() {
        let app = launch()
        tab(app, "events")
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        app.buttons["trip-line-0"].tap()
        XCTAssertTrue(waitUntil { self.words(progress) == "1/7" }, "the tick did not count: '\(words(progress))'")
        tap(app, id: "trip-line-0-aside")
        XCTAssertTrue(waitUntil { self.words(progress) == "0/6 · 1 set aside" }, "not set aside: '\(words(progress))'")
        XCTAssertFalse(isOn(app.buttons["trip-line-0"]), "set aside, and still ticked underneath")
        app.buttons["trip-line-0"].tap()
        XCTAssertFalse(waitUntil(timeout: 2) { self.isOn(app.buttons["trip-line-0"]) }, "a set-aside line took a tick")
        XCTAssertEqual(words(progress), "0/6 · 1 set aside")
        tap(app, id: "trip-line-0-aside")
        XCTAssertTrue(waitUntil { self.words(progress) == "0/7" }, "taken back, it came back ticked: '\(words(progress))'")

        // Every line of the one section set aside.
        XCTAssertTrue(app.buttons["trip-group-0-all"].waitForExistence(timeout: 5), "the section has no tick to begin with")
        for n in 0..<7 {
            XCTAssertTrue(scrollUntil(app, "trip-line-\(n)-aside", near: n > 0 ? "trip-line-\(n - 1)-aside" : nil))
            tap(app, id: "trip-line-\(n)-aside")
        }
        XCTAssertTrue(waitUntil { self.words(progress) == "0/0 · 7 set aside" }, "not all set aside: '\(words(progress))'")
        XCTAssertTrue(waitUntil { !app.buttons["trip-group-0-all"].exists },
                      "a section with nothing to tick still offers its tick (a grey, switched-off one)")
        shot(app, "trip-all-set-aside")
    }

    /// His rule (2026-09-26), the spec pass (5 Oct 2026): Set place's Save sat grey and
    /// switched off while its field was empty, and the review's Add did nothing at all
    /// with nothing typed. Both are there to press, and say what is missing. And in the
    /// review, "No template" can really be chosen — it fell back to the first template.
    func testSetPlaceAndTheReviewSayWhatIsMissingAndNoTemplateIsChosen() {
        let app = launch()
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        type("Tripod", into: app.textFields["trip-add-name"])
        tap(app, id: "trip-add")
        XCTAssertTrue(waitUntil { self.words(progress) == "0/8" }, "the typed line was not added: '\(words(progress))'")
        hideKeyboard(app)
        tap(app, id: "trip-view-2")                              // From where
        XCTAssertTrue(scrollWithin(app, "trip-detail", until: "trip-line-7-place"), "no Set place on the typed line")
        tap(app, id: "trip-line-7-place")
        XCTAssertTrue(appears(app, "trip-place-panel", timeout: 5))
        bringIntoView(app, app.buttons["trip-place-save"])
        var misses = [saysWhatIsMissing(app, "trip-place-save")]
        shot(app, "trip-place-needs")
        tap(app, id: "trip-place-close")

        tap(app, id: "trip-review")
        XCTAssertTrue(appears(app, "review-detail", timeout: 5))
        misses.append(saysWhatIsMissing(app, "review-miss-add"))
        shot(app, "review-add-needs")
        misses.removeAll { $0.isEmpty }
        XCTAssertTrue(misses.isEmpty, "buttons that are not ready, or do not say what is missing:\n" + misses.joined(separator: "\n"))

        type("Sit mat", into: app.textFields["review-miss-input"])
        XCTAssertTrue(waitUntil { !app.staticTexts["review-miss-add-needs"].exists }, "the line stayed after typing")
        // "No template" is the last pill.
        var last = 0
        while app.buttons["review-miss-where-\(last + 1)"].exists { last += 1 }
        XCTAssertGreaterThan(last, 0, "the trip shows no templates to choose from")
        let none = app.buttons["review-miss-where-\(last)"]
        XCTAssertEqual(words(none), "No template")
        select(app, none)
        XCTAssertFalse(isOn(app.buttons["review-miss-where-0"]), "the first template stayed picked")
        hideKeyboard(app)
        tap(app, id: "review-miss-add")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["review-missed-0-where"]) == "no template" },
                      "the missed thing did not go on no template: '\(words(app.staticTexts["review-missed-0-where"]))'")
        shot(app, "review-no-template")
        tap(app, id: "review-cancel")
        XCTAssertTrue(disappears(app, "review-detail", timeout: 5))
    }

    /// The date grid (the spec pass, 5 Oct 2026). Tapping the field with only the first
    /// day picked closed the grid and kept a one-day trip; now the field is OK: it waits
    /// for the last day and says so, and closes on a whole range. And the grid keeps
    /// one height — six rows every month — so OK never moves under his finger.
    func testTheDateGridClosesOnlyOnAWholeRangeAndStaysStill() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        setSwitch(app, "trip-dates", on: true)
        let grid = app.staticTexts["range-title-0"]
        XCTAssertTrue(grid.waitForExistence(timeout: 5), "the month grid did not open")
        let field = app.buttons["trip-dates-field"]
        func says() -> String { field.value as? String ?? "" }

        pickDay(app, dayFromToday(3))
        tap(app, id: "trip-dates-field")
        XCTAssertTrue(app.staticTexts["range-needs"].waitForExistence(timeout: 5), "the field closed the grid with only the first day")
        XCTAssertTrue(grid.exists, "the grid closed with only the first day")
        shot(app, "date-field-needs")
        pickDay(app, dayFromToday(5))
        tap(app, id: "trip-dates-field")
        XCTAssertTrue(waitUntil { !grid.exists }, "the field did not close the grid on a whole range")
        XCTAssertTrue(says().hasSuffix("2 nights"), "the range was not kept: '\(says())'")

        // Six rows, whatever the month: OK stays where it was, month after month.
        tap(app, id: "trip-dates-field")
        XCTAssertTrue(grid.waitForExistence(timeout: 5), "the field did not open the grid again")
        let ok = app.buttons["range-ok"]
        XCTAssertTrue(ok.waitForExistence(timeout: 5))
        func gap() -> CGFloat { ok.frame.minY - grid.frame.minY }
        let months = ["January", "February", "March", "April", "May", "June", "July",
                      "August", "September", "October", "November", "December"]
        func weeks() -> Int {
            let shown = words(grid).split(separator: " ")
            var cal = Calendar(identifier: .gregorian); cal.firstWeekday = 2
            let m = (months.firstIndex(of: String(shown.first ?? "")) ?? 0) + 1
            let first = cal.date(from: DateComponents(year: Int(shown.last ?? "") ?? 2026, month: m, day: 1))!
            let lead = (cal.component(.weekday, from: first) + 5) % 7
            return (lead + cal.range(of: .day, in: .month, for: first)!.count + 6) / 7
        }
        let start = gap()
        var rows: Set<Int> = [weeks()]
        for _ in 0..<5 {
            tap(app, id: "range-next")
            usleep(300_000)
            rows.insert(weeks())
            XCTAssertEqual(gap(), start, accuracy: 1, "OK moved with the month (\(words(grid)))")
        }
        XCTAssertGreaterThan(rows.count, 1, "the months seen all have as many weeks — this proves nothing")
        shot(app, "date-six-rows")
        tap(app, id: "range-cancel")
    }

    /// A bag whose things have no weight is on the trip's Bags card all the same (the
    /// spec pass, 5 Oct 2026): it was left off, and its luggage scale, cabin switch and
    /// photos could not be reached from the trip.
    func testABagWithNothingWeighedIsOnTheTrip() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        type("Map", into: app.textFields["things-search"])
        tap(app, id: "thing-row-0")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        let bag = app.buttons["thing-bag-2"]
        XCTAssertTrue(bag.waitForExistence(timeout: 5))
        XCTAssertFalse(words(bag).contains("Carry-on"), "pick a bag other than the one it has: '\(words(bag))'")
        select(app, bag)
        let weight = app.textFields["thing-weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5), "no weight on the thing's page")
        bringIntoView(app, weight)
        replace("0", in: weight)                                  // 0 = not known
        hideKeyboard(app)
        tap(app, id: "thing-save")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))
        tap(app, id: "things-done")
        XCTAssertTrue(disappears(app, "things-detail", timeout: 5))

        tab(app, "events")
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(app.buttons["bag-0"].waitForExistence(timeout: 5), "no Bags card")
        let unweighed = (0..<4).map { app.buttons["bag-\($0)"] }.first { $0.exists && ($0.value as? String) == "not weighed" }
        let said = (0..<4).map { n -> String in
            let e = app.buttons["bag-\(n)"]
            return e.exists ? (e.value as? String ?? "") : "-"
        }
        XCTAssertNotNil(unweighed, "the bag with nothing weighed is not on the trip: \(said)")
        guard let unweighed else { return }
        let n = unweighed.identifier
        tapVisible(app, unweighed)
        XCTAssertTrue(app.textFields["\(n)-scale"].waitForExistence(timeout: 5), "its luggage scale cannot be reached")
        shot(app, "bags-unweighed")
    }

    /// Weather gear "anyway" (the spec pass, 5 Oct 2026): the trip's own forced
    /// conditions had no switch here — a trip that carried them could not show or
    /// change them. Picked, saved, and still picked when Trip settings opens again.
    func testWeatherGearCanBePackedAnyway() {
        let app = launch()
        tab(app, "events")
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        XCTAssertTrue(scrollWithin(app, "tripset-screen", until: "tripset-weather-0"), "no weather gear choice")
        let rain = app.buttons["tripset-weather-0"]
        XCTAssertEqual(words(rain), "Rain")
        XCTAssertFalse(isOn(rain), "rain gear is forced on from the start")
        select(app, rain)
        shot(app, "tripset-weather")
        tap(app, id: "tripset-save")
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5))
        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        XCTAssertTrue(scrollWithin(app, "tripset-screen", until: "tripset-weather-0"))
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["tripset-weather-0"]) }, "rain gear anyway was not kept")
        XCTAssertFalse(isOn(app.buttons["tripset-weather-1"]), "a condition he did not pick is on")
        tap(app, id: "tripset-cancel")
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5))
    }

    /// A template with no activity area is offered for a trip, last, under "Other
    /// templates" (the spec pass, 5 Oct 2026): A new template offers "No activity area",
    /// and such a template could never go on a trip. And Trip settings keeps a trip's
    /// template it does not show: a Quick trip whose template was deleted since lost its
    /// Save without a word (the name typed was simply gone).
    func testATemplateWithNoActivityAreaGoesOnATrip() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        tap(app, id: "templates-new")
        XCTAssertTrue(appears(app, "newlist-detail", timeout: 5))
        type("Picnic", into: app.textFields["newlist-name"])
        hideKeyboard(app)
        tap(app, id: "newlist-area-none")
        tap(app, id: "newlist-make")
        XCTAssertTrue(appears(app, "template-detail", timeout: 5), "the new template did not open")
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))

        // Create new trip: Hiking 0, Swim 1, and the new one last. A Quick trip of it.
        tab(app, "home")
        XCTAssertTrue(scrollUntil(app, "trip-activity-2"), "a template with no activity area is not offered")
        let picnic = app.buttons["trip-activity-2"]
        XCTAssertEqual(words(picnic), "Picnic")
        bringIntoView(app, picnic)
        shot(app, "home-other-templates")
        type("Lunch out", into: app.textFields["trip-name"])
        hideKeyboard(app)
        setSwitch(app, "trip-quick", on: true)
        select(app, picnic)
        tapVisible(app, app.buttons["trip-create"])
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5), "the trip was not made")
        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        XCTAssertTrue(scrollWithin(app, "tripset-screen", until: "tripset-activity-2"))
        XCTAssertTrue(isOn(app.buttons["tripset-activity-2"]), "Trip settings does not show the template on the trip")
        bringIntoView(app, app.buttons["tripset-activity-2"])
        shot(app, "tripset-other-templates")
        tap(app, id: "tripset-cancel")
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5))
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))

        // The template goes (row 3: Common base, Hiking, Swim, then Picnic).
        tab(app, "templates")
        XCTAssertTrue(scrollUntil(app, "template-row-3", near: "template-row-2"), "the new template is not listed")
        tap(app, id: "template-row-3")
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertEqual(cellSays(app, "template-name"), "Picnic", "row 3 is not the new template")
        tap(app, id: "template-delete")
        tap(app, id: "template-delete-yes")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))

        // The trip (undated, so after the sample's): renamed in Trip settings, and saved.
        tab(app, "events")
        tap(app, id: "trip-row-1")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["trip-name"]) == "Lunch out" }, "row 1 is not the new trip")
        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        replace("Lunch in the park", in: app.textFields["tripset-name"])
        app.textFields["tripset-name"].typeText("\n")
        tap(app, id: "tripset-save")
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["trip-name"]) == "Lunch in the park" },
                      "Save was lost without a word: '\(words(app.staticTexts["trip-name"]))'")
    }

    /// "1 thing", not "1 things" (the spec pass, 5 Oct 2026) — on the card a shared
    /// link shows; a grab list of one thing says it.
    func testASharedListOfOneSaysOneThing() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        makeOwnGrabList(app, "Sunglasses", things: ["Sunglasses"])
        tap(app, id: "grab-edit")                                    // Save
        tap(app, id: "grab-share")
        XCTAssertTrue(appears(app, "share-screen", timeout: 5))
        tap(app, id: "share-copy")
        tap(app, id: "share-done")
        XCTAssertTrue(disappears(app, "share-screen", timeout: 5))
        tap(app, id: "grab-done")
        tab(app, "settings")
        tap(app, id: "settings-openshared")
        XCTAssertTrue(appears(app, "shared-screen", timeout: 5))
        tap(app, id: "shared-paste")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shared-kind"]) == "A GRAB LIST" }, "not read as a grab list")
        XCTAssertEqual(words(app.staticTexts["shared-count"]), "1 thing")
        shot(app, "shared-one-thing")
        tap(app, id: "shared-done")
    }

    #if os(iOS)
    /// A swipe down must not throw unsaved work away without a word (the spec pass,
    /// 5 Oct 2026): with something marked in the review, or changed in Trip settings,
    /// the swipe no longer closes the sheet — Cancel or Save does. With nothing
    /// changed, the swipe closes it as before.
    func testASwipeDownKeepsWhatIsNotSavedYet() {
        let app = launch()
        tab(app, "events")
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        app.buttons["trip-line-0"].tap()                          // something packed, for the review to ask about
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["trip-progress"]) == "1/7" })
        func swipeDown(_ screen: String) {
            guard let sheet = find(app, screen) else { return }
            sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
                .press(forDuration: 0.05, thenDragTo: sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
            sleep(1)
        }

        tap(app, id: "trip-review")
        XCTAssertTrue(appears(app, "review-detail", timeout: 5))
        swipeDown("review-detail")
        XCTAssertTrue(disappears(app, "review-detail", timeout: 5), "with nothing marked, the swipe did not close the review")
        tap(app, id: "trip-review")
        XCTAssertTrue(appears(app, "review-detail", timeout: 5))
        tap(app, id: "review-line-0")
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["review-line-0"]) }, "the mark did not take")
        swipeDown("review-detail")
        XCTAssertNotNil(find(app, "review-detail"), "a swipe threw the review's marks away")
        XCTAssertTrue(isOn(app.buttons["review-line-0"]), "the mark was lost")
        tap(app, id: "review-cancel")
        XCTAssertTrue(disappears(app, "review-detail", timeout: 5), "Cancel did not close the review")

        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        tapVisible(app, app.buttons["tripset-season-1"])
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["tripset-season-1"]) })
        swipeDown("tripset-screen")
        XCTAssertNotNil(find(app, "tripset-screen"), "a swipe threw Trip settings' change away")
        tap(app, id: "tripset-cancel")
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5), "Cancel did not close Trip settings")
        XCTAssertEqual(words(app.staticTexts["trip-progress"]), "1/7", "Cancel changed the trip")
    }
    #endif

    /// Laundry (the web app's, gap list 2026-09-27): he can wash, so per-night things
    /// count 4 nights at most — a 7-night trip packs 4 of the per-night towel, not 7,
    /// and says why; Trip settings shows it, turns it off, and the 7 comes back.
    func testLaundryCountsPerNightThingsFourNightsAtMost() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        pickDates(app, from: 3, to: 10)                      // 7 nights
        type("Swim week", into: app.textFields["trip-name"])
        setSwitch(app, "trip-quick", on: true)
        select(app, app.buttons["trip-activity-1"])          // Swim: goggles, cap, a towel per night
        setSwitch(app, "trip-laundry", on: true)
        // The nights to pack for before a wash (his idea, 2 Oct 2026): 4 unless he picks.
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["trip-laundry-nights-1"]) }, "4 nights is not the starting choice")
        tapVisible(app, app.buttons["trip-create"])
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5), "the new trip did not open")
        let progress = app.staticTexts["trip-progress"]
        XCTAssertTrue(waitUntil { self.words(progress) == "0/3" }, "Quick with Swim is not three lines: '\(words(progress))'")
        func counts() -> [String] { (0..<3).map { app.buttons["trip-line-\($0)"].value as? String ?? "" } }
        XCTAssertTrue(waitUntil { counts().contains("×4 · laundry") }, "the towel does not count 4 with laundry: \(counts())")
        XCTAssertFalse(counts().contains { $0.hasPrefix("×7") }, "a night count got past the laundry: \(counts())")
        shot(app, "laundry-trip")

        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        XCTAssertTrue(waitUntil { self.isSwitchOn(app, "tripset-laundry") }, "Trip settings does not show the laundry")
        // Pack for 5 nights before a wash: the towel follows.
        let five = app.buttons["tripset-laundry-nights-2"]
        bringIntoView(app, five)
        select(app, five)
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["tripset-laundry-says"]).contains("5 nights") },
                      "the switch does not say 5 nights: '\(words(app.staticTexts["tripset-laundry-says"]))'")
        tap(app, id: "tripset-save")
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5))
        XCTAssertTrue(waitUntil { counts().contains("×5 · laundry") }, "the towel does not follow the 5 nights: \(counts())")
        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["tripset-laundry-nights-2"]) }, "the 5 nights were not kept")
        setSwitch(app, "tripset-laundry", on: false)
        tap(app, id: "tripset-save")
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5))
        XCTAssertTrue(waitUntil { counts().contains("×7") }, "without laundry the towel does not count every night: \(counts())")
    }

    /// The next trip counted down on Home (his idea 6, 2 Oct 2026): the days, the trip,
    /// the next packing step; a tap opens it. (`-uiTestingChecks`: a trip 20 days out,
    /// its things on "≥1 week ahead".)
    func testHomeCountsDownToTheNextTrip() {
        let app = launch("-uiTestingChecks")
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        let card = app.buttons["home-countdown"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Home does not count down to the next trip")
        XCTAssertTrue(waitUntil { self.words(card).contains("20") && self.words(card).contains("Sunny weeks") },
                      "the countdown does not say 20 days to Sunny weeks: '\(words(card))'")
        XCTAssertTrue(words(card).contains("week ahead"), "the next packing step is missing: '\(words(card))'")
        shot(app, "home-countdown")
        tap(app, id: "home-countdown")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5), "the countdown did not open the trip")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["trip-name"]) == "Sunny weeks" },
                      "the countdown opened another trip: '\(words(app.staticTexts["trip-name"]))'")
    }

    /// Remind me to pack (his idea 7): per device and off until he says. On, Settings
    /// names the next reminder — the day, the trip, the step; off, it names none.
    func testSettingsTurnsOnPackingReminders() {
        let app = launch("-uiTestingChecks")
        tab(app, "settings")
        XCTAssertTrue(appears(app, "screen-settings"))
        XCTAssertTrue(switchNamed(app, "settings-reminders").exists, "no Remind me to pack switch")
        XCTAssertFalse(isSwitchOn(app, "settings-reminders"), "reminders are on before he asked")
        XCTAssertFalse(app.staticTexts["settings-reminders-next"].exists, "a next reminder is named while off")
        setSwitch(app, "settings-reminders", on: true)
        let next = app.staticTexts["settings-reminders-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "on, the next reminder is not named")
        XCTAssertTrue(waitUntil { self.words(next).contains("Sunny weeks") && self.words(next).contains("week ahead") },
                      "the next reminder is not the trip's week-ahead step: '\(words(next))'")
        shot(app, "settings-reminders")
        setSwitch(app, "settings-reminders", on: false)
        XCTAssertTrue(waitUntil { !app.staticTexts["settings-reminders-next"].exists }, "off, a reminder is still named")
    }

    /// Check before you go (his ideas 4 and 5, 2 Oct 2026): on a plane trip, what in
    /// a cabin bag the airport stops; and what runs out before he is home — a passport
    /// six months ahead. A tap opens the thing to put it right. (`-uiTestingChecks`: a
    /// plane trip three weeks out; a pocket knife and sun cream in the carry-on; the
    /// sun cream runs out during the trip, the passport five months after it.)
    func testATripChecksTheCabinAndTheDatesBeforeYouGo() {
        let app = launch("-uiTestingChecks")
        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(appears(app, "trip-checks", timeout: 5), "the plane trip has nothing to check")
        func says(_ id: String) -> String { words(app.buttons[id]) }
        XCTAssertTrue(waitUntil { says("trip-check-cabin-0").contains("Pocket knife") },
                      "not allowed on board is not first: '\(says("trip-check-cabin-0"))'")
        XCTAssertTrue(says("trip-check-cabin-1").contains("Sun cream"), "the liquid is not asked about: '\(says("trip-check-cabin-1"))'")
        XCTAssertTrue(says("trip-check-date-0").contains("Sun cream"), "what runs out first is not first: '\(says("trip-check-date-0"))'")
        XCTAssertTrue(says("trip-check-date-1").contains("Passport"), "the passport's six months are not checked: '\(says("trip-check-date-1"))'")
        shot(app, "trip-checks")

        // The sun cream goes in a small bottle after all: open it from the check, Liquid off.
        tap(app, id: "trip-check-cabin-1")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5), "the check did not open the thing")
        setSwitch(app, "thing-liquid", on: false)
        tap(app, id: "thing-save")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))
        XCTAssertTrue(waitUntil { !app.buttons["trip-check-cabin-1"].exists }, "the liquid is still asked about")
        XCTAssertTrue(says("trip-check-cabin-0").contains("Pocket knife"), "the knife went too")

        // A new passport: the date goes, and so does the warning.
        tap(app, id: "trip-check-date-1")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        tap(app, id: "thing-expiry-clear")
        XCTAssertTrue(waitUntil { app.buttons["thing-expiry-add"].exists }, "the date was not removed")
        tap(app, id: "thing-save")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))
        XCTAssertTrue(waitUntil { !app.buttons["trip-check-date-1"].exists }, "the passport without a date is still checked")

        // By car the cabin is nobody's business — but the sun cream still runs out.
        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        select(app, app.buttons["tripset-transport-0"])
        tap(app, id: "tripset-save")
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5))
        XCTAssertTrue(waitUntil { !app.buttons["trip-check-cabin-0"].exists }, "a car trip is checked for the cabin")
        XCTAssertTrue(says("trip-check-date-0").contains("Sun cream"), "the date check went with the plane")
    }

    /// A bag says whether it goes in the cabin (his idea 4): a carry-on by its name until
    /// he says otherwise, and the plane trip's check follows his word.
    func testABagSaysWhetherItGoesInTheCabin() {
        let app = launch("-uiTestingChecks")
        tab(app, "care")
        tap(app, id: "care-bags")
        XCTAssertTrue(appears(app, "yourbags-detail", timeout: 5))
        tap(app, id: "bag-0-name")
        XCTAssertTrue(appears(app, "bag-detail", timeout: 5), "the bag's page did not open")
        XCTAssertTrue(waitUntil { self.isSwitchOn(app, "bag-detail-cabin") }, "a carry-on by its name is not in the cabin")
        setSwitch(app, "bag-detail-cabin", on: false)
        tap(app, id: "bag-done")
        XCTAssertTrue(disappears(app, "bag-detail", timeout: 5))
        tap(app, id: "yourbags-done")
        XCTAssertTrue(disappears(app, "yourbags-detail", timeout: 5))
        tab(app, "events")
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(appears(app, "trip-checks", timeout: 5), "the dates are no longer checked")
        XCTAssertFalse(app.buttons["trip-check-cabin-0"].exists, "a bag out of the cabin is still checked")
    }

    /// The luggage scale (his idea 8, 2 Oct 2026): tap a bag on the trip, type what the
    /// scale says; that is the weight it is judged by — over its max, the card says so —
    /// and Clear takes it away again. (The sample's carry-on: 8 kg max, 2 kg of things.)
    /// The one bar (their choice, 3 Oct 2026) says in words what its colour
    /// says: blue "fine", orange "close" from nine tenths, red "over".
    func testABagIsWeighedOnTheLuggageScale() {
        let app = launch()
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let bag = app.buttons["bag-0"]
        XCTAssertTrue(bag.waitForExistence(timeout: 5), "no bag on the trip")
        XCTAssertFalse(app.staticTexts["bags-over"].exists, "the sample's carry-on starts over its max")
        let gauge = { (bag.value as? String) ?? "" }
        XCTAssertTrue(waitUntil { gauge() == "fine, 25% of its max" }, "2 kg in an 8 kg carry-on: '\(gauge())'")
        shot(app, "bag-bar-fine")
        tap(app, id: "bag-0")
        let field = app.textFields["bag-0-scale"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "tapping a bag does not ask what the scale says")
        type("7.5", into: field)
        tap(app, id: "bag-0-scale-save")
        XCTAssertTrue(waitUntil { gauge() == "close, 94% of its max" }, "7.5 kg in an 8 kg carry-on: '\(gauge())'")
        XCTAssertFalse(app.staticTexts["bags-over"].exists, "7.5 kg in an 8 kg carry-on is called over")
        shot(app, "bag-bar-close")
        tap(app, id: "bag-0")
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the scale field does not come back")
        replace("9.5", in: field)
        tap(app, id: "bag-0-scale-save")
        XCTAssertTrue(waitUntil { self.words(app.buttons["bag-0"]).contains("9.5 kg weighed") },
                      "the scale's 9.5 kg is not the bag's weight: '\(words(app.buttons["bag-0"]))'")
        XCTAssertTrue(app.staticTexts["bags-over"].waitForExistence(timeout: 5), "9.5 kg in an 8 kg carry-on is not over")
        XCTAssertTrue(waitUntil { gauge() == "over, 119% of its max" }, "9.5 kg in an 8 kg carry-on: '\(gauge())'")
        shot(app, "bag-weighed")
        tap(app, id: "bag-0")
        tap(app, id: "bag-0-scale-clear")
        XCTAssertTrue(waitUntil { !self.words(app.buttons["bag-0"]).contains("weighed") }, "Clear kept the scale's weight")
        XCTAssertTrue(waitUntil { !app.staticTexts["bags-over"].exists }, "without the scale it is still over")
    }

    /// To buy → Reminders (his idea 9): the open lines go in one press, and the list
    /// says where; what went is not offered again, a new line is. (Under the tests a
    /// pretend Reminders stands in: the real one asks the device first.)
    func testTheBuyListGoesToReminders() {
        let app = launch()
        tab(app, "actions")
        XCTAssertTrue(appears(app, "screen-actions"))
        tap(app, id: "actions-tab-buy")
        XCTAssertTrue(app.staticTexts["buy-count"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["buy-send"].exists, "nothing to buy, yet something to send")
        for line in ["Sun cream", "Plasters"] {
            type(line, into: app.textFields["buy-add-text"])
            XCTAssertTrue(waitUntil { app.buttons["buy-add"].isEnabled }, "Add did not switch on")
            tap(app, id: "buy-add")
        }
        XCTAssertTrue(waitUntil { self.words(app.buttons["buy-send"]).contains("Send 2") },
                      "the two lines are not offered: '\(words(app.buttons["buy-send"]))'")
        tap(app, id: "buy-send")
        let says = app.staticTexts["buy-send-says"]
        XCTAssertTrue(says.waitForExistence(timeout: 5), "the list does not say where they went")
        XCTAssertTrue(words(says).contains("2 in Reminders"), "it does not say 2 went: '\(words(says))'")
        XCTAssertTrue(waitUntil { !app.buttons["buy-send"].exists }, "what went is offered again")
        type("Socks", into: app.textFields["buy-add-text"])
        XCTAssertTrue(waitUntil { app.buttons["buy-add"].isEnabled })
        tap(app, id: "buy-add")
        XCTAssertTrue(waitUntil { self.words(app.buttons["buy-send"]).contains("Send 1") },
                      "the new line is not the one offered: '\(words(app.buttons["buy-send"]))'")
    }

    /// Shortcuts (his idea 10): what the Action button's Shortcut does — open a grab
    /// list, or the next trip — played here by a launch argument that sets the very
    /// request the Shortcut sets. The app opens on that grab list / trip.
    func testAShortcutOpensAGrabListOrTheNextTrip() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-openGrab", "Bike"]
        app.launch()
        XCTAssertTrue(appears(app, "grab-detail", timeout: 20),
                      "the Shortcut did not open the grab list")
        app.terminate()

        let trip = XCUIApplication()
        trip.launchArguments += ["-uiTestingChecks", "-openNextTrip"]
        trip.launch()
        XCTAssertTrue(appears(trip, "trip-detail", timeout: 20), "the Shortcut did not open the next trip")
        XCTAssertTrue(waitUntil { self.words(trip.staticTexts["trip-name"]) == "Sunny weeks" },
                      "it opened another trip: '\(words(trip.staticTexts["trip-name"]))'")
    }

    /// Photos of each packed bag (his idea 11; up to three since the field test, 3 Oct
    /// 2026): tap a bag on the trip, take three photos (under the tests a drawn picture
    /// stands in for the camera) — no fourth is offered — see one large and step to the
    /// next, remove one and the way to add is back; the way home shows both that are left.
    func testAPackedBagKeepsItsPhoto() {
        let app = launch()
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        tap(app, id: "bag-0")
        XCTAssertTrue(app.buttons["bag-0-photo"].waitForExistence(timeout: 5), "an open bag offers no photo")
        XCTAssertFalse(app.buttons["bag-0-photo-thumb-0"].exists, "a photo before one was taken")
        for k in 0..<3 {
            tap(app, id: "bag-0-photo")
            XCTAssertTrue(app.buttons["bag-0-photo-thumb-\(k)"].waitForExistence(timeout: 5), "photo \(k + 1) was not kept")
        }
        XCTAssertTrue(waitUntil { !app.buttons["bag-0-photo"].exists }, "a fourth photo is still offered")
        XCTAssertTrue(app.staticTexts["bag-0-photo-full"].waitForExistence(timeout: 5), "three photos, and no word why there is no fourth")
        bringIntoView(app, app.buttons["bag-0-photo-thumb-2"])
        shot(app, "bag-photos-three")
        // Large, and on to the next angle.
        tap(app, id: "bag-0-photo-thumb-1")
        XCTAssertTrue(app.buttons["bag-photo-done"].waitForExistence(timeout: 5), "the photo does not open large")
        let count = app.staticTexts["bag-photo-count"]
        XCTAssertTrue(waitUntil { self.words(count) == "2 of 3" }, "the second photo did not open: '\(words(count))'")
        shot(app, "bag-photo-large")
        tap(app, id: "bag-photo-next")
        XCTAssertTrue(waitUntil { self.words(count) == "3 of 3" }, "Next did not step on: '\(words(count))'")
        tap(app, id: "bag-photo-done")
        XCTAssertTrue(waitUntil { !app.buttons["bag-photo-done"].exists }, "the large photo did not close")
        // One removed: two left, and the way to add another is back.
        tap(app, id: "bag-0-photo-remove-1")
        XCTAssertTrue(waitUntil { !app.buttons["bag-0-photo-thumb-2"].exists }, "Remove kept the photo")
        XCTAssertTrue(app.buttons["bag-0-photo-thumb-1"].exists, "Remove took more than one photo")
        XCTAssertTrue(app.buttons["bag-0-photo"].waitForExistence(timeout: 5), "no way to add a photo after one was removed")
        XCTAssertFalse(app.staticTexts["bag-0-photo-full"].exists, "still says three photos with two")
        shot(app, "bag-photos-two")
        // The way home shows every photo of the bag, to repack from — everything packed first,
        // so the bag goes home; and a thing bought there, so the way home is open whatever
        // the sample trip's dates.
        tapVisible(app, app.buttons["trip-tickall"])
        XCTAssertTrue(waitUntil { !app.buttons["trip-tickall"].exists }, "Tick everything did not tick everything")
        type("Sun hat", into: app.textFields["trip-add-name"])
        tap(app, id: "trip-add-bought")
        hideKeyboard(app)
        openWayHome(app)
        XCTAssertTrue(appears(app, "wayhome-screen", timeout: 5), "Pack to go home did not open")
        XCTAssertTrue(app.buttons["wayhome-photo-1"].waitForExistence(timeout: 5), "the way home does not show both photos")
        XCTAssertFalse(app.buttons["wayhome-photo-2"].exists, "the way home shows a photo that was removed")
        shot(app, "way-home-photos")
        tap(app, id: "wayhome-photo-1")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["bag-photo-count"]) == "2 of 2" },
                      "the way home's second photo did not open large: '\(words(app.staticTexts["bag-photo-count"]))'")
        XCTAssertTrue(app.staticTexts["bag-photo-caption"].exists, "the large photo does not say which bag")
        shot(app, "way-home-photo-large")
        tap(app, id: "bag-photo-done")
        XCTAssertTrue(waitUntil { !app.buttons["bag-photo-done"].exists }, "the large photo did not close")
    }

    /// Bought on site (his idea 12; "on site", not "there", since the field test of
    /// Oct 2026): a thing bought on the trip goes onto its list in one press — ticked,
    /// since it is in hand, and marked Bought on site.
    func testSomethingBoughtOnSiteGoesOnTheList() {
        let app = launch()
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        XCTAssertTrue(waitUntil { self.words(progress) == "0/7" }, "the sample trip is not what it was: '\(words(progress))'")
        XCTAssertFalse(app.buttons["trip-add-bought"].exists, "Bought on site is offered before anything is typed")
        type("Sun cream", into: app.textFields["trip-add-name"])
        XCTAssertTrue(waitUntil { self.words(app.buttons["trip-add-bought"]) == "Bought on site" },
                      "the button does not say Bought on site: '\(words(app.buttons["trip-add-bought"]))'")
        shot(app, "bought-on-site-button")
        tap(app, id: "trip-add-bought")
        XCTAssertTrue(waitUntil { self.words(progress) == "1/8" }, "it is not on the list, in hand: '\(words(progress))'")
        hideKeyboard(app)
        // The list builds its lines as they come near: walk down to the new one.
        for n in 0...7 {
            XCTAssertTrue(scrollUntil(app, "trip-line-\(n)", near: n > 0 ? "trip-line-\(n - 1)" : nil), "line \(n + 1) never appeared")
        }
        XCTAssertTrue(waitUntil { self.words(app.buttons["trip-line-7"]).contains("Bought on site") },
                      "the line does not say it was bought on site: '\(words(app.buttons["trip-line-7"]))'")
        shot(app, "bought-on-site-line")
    }

    /// Pack to go home (his idea 13): what went and what was bought on site, with ticks of
    /// its own; Used up takes a thing off; it is kept when closed.
    func testTheWayHomeIsPackedFromWhatWent() {
        let app = launch()
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        app.buttons["trip-line-0"].tap()
        XCTAssertTrue(waitUntil { self.words(progress) == "1/7" })
        app.buttons["trip-line-1"].tap()
        XCTAssertTrue(waitUntil { self.words(progress) == "2/7" })
        type("Sandals", into: app.textFields["trip-add-name"])
        tap(app, id: "trip-add-bought")
        XCTAssertTrue(waitUntil { self.words(progress) == "3/8" }, "Sandals did not go on: '\(words(progress))'")
        shot(app, "way-home-door")
        openWayHome(app)
        XCTAssertTrue(appears(app, "wayhome-screen", timeout: 5), "Pack to go home did not open")
        let home = app.staticTexts["wayhome-progress"]
        XCTAssertTrue(waitUntil { self.words(home) == "0/3" }, "the way home is not what went and what was bought: '\(words(home))'")
        tap(app, id: "wayhome-line-0")
        XCTAssertTrue(waitUntil { self.words(home) == "1/3" }, "the home tick did not count: '\(words(home))'")
        tap(app, id: "wayhome-line-1-usedup")
        XCTAssertTrue(waitUntil { self.words(home) == "1/2 · 1 used up" }, "used up still counts for the way home: '\(words(home))'")
        shot(app, "way-home")
        tap(app, id: "wayhome-done")
        XCTAssertTrue(disappears(app, "wayhome-screen", timeout: 5))
        tap(app, id: "onsite-done")
        XCTAssertTrue(disappears(app, "onsite-screen", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(progress) == "3/8" }, "the way home touched the way-out ticks: '\(words(progress))'")
        openWayHome(app)
        XCTAssertTrue(appears(app, "wayhome-screen", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["wayhome-progress"]) == "1/2 · 1 used up" }, "the way home was not kept")
    }

    /// The sample trip with two lines packed and Sandals bought on site, and Pack to go
    /// home open on it: three lines to bring home — Passport, Phone charger, and Sandals, which
    /// has no thing behind it.
    private func openWayHomeOfThree(_ app: XCUIApplication) -> XCUIElement {
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        app.buttons["trip-line-0"].tap()
        XCTAssertTrue(waitUntil { self.words(progress) == "1/7" })
        app.buttons["trip-line-1"].tap()
        XCTAssertTrue(waitUntil { self.words(progress) == "2/7" })
        type("Sandals", into: app.textFields["trip-add-name"])
        tap(app, id: "trip-add-bought")
        XCTAssertTrue(waitUntil { self.words(progress) == "3/8" }, "Sandals did not go on: '\(words(progress))'")
        openWayHome(app)
        XCTAssertTrue(appears(app, "wayhome-screen", timeout: 5), "Pack to go home did not open")
        let home = app.staticTexts["wayhome-progress"]
        XCTAssertTrue(waitUntil { self.words(home) == "0/3" }, "the way home is not the three lines: '\(words(home))'")
        return home
    }

    /// "I would like a search function in the 'Pack to go home'" (their field test, 3 Oct
    /// 2026): typing narrows the list by name, says so when nothing matches, the cross empties it.
    func testTheWayHomeIsSearched() {
        let app = launch()
        _ = openWayHomeOfThree(app)
        XCTAssertFalse(app.buttons["wayhome-search-clear"].exists, "a cross on an empty search")
        type("sand", into: app.textFields["wayhome-search"])
        XCTAssertTrue(waitUntil { !app.buttons["wayhome-line-0"].exists }, "the search did not narrow the list")
        XCTAssertFalse(app.buttons["wayhome-line-1"].exists, "the search did not narrow the list")
        XCTAssertTrue(app.buttons["wayhome-line-2"].exists, "the search lost what it was looking for")
        shot(app, "way-home-search")
        type("q", into: app.textFields["wayhome-search"])
        XCTAssertTrue(app.staticTexts["wayhome-search-none"].waitForExistence(timeout: 5), "nothing matches, and it does not say so")
        shot(app, "way-home-search-none")
        // The same round ✕ as every other search field — 36 points, not the plain
        // 44-point cross it drew on its own until the spec pass (5 Oct 2026).
        let cross = app.buttons["wayhome-search-clear"]
        XCTAssertEqual(cross.frame.width, 36, accuracy: 1, "not the shared ✕: \(cross.frame)")
        tap(app, id: "wayhome-search-clear")
        XCTAssertTrue(waitUntil { app.buttons["wayhome-line-0"].exists && app.buttons["wayhome-line-1"].exists
                                  && app.buttons["wayhome-line-2"].exists }, "the cross did not bring the whole way home back")
        XCTAssertFalse(app.staticTexts["wayhome-search-none"].exists, "it still says nothing matches")
        XCTAssertFalse((app.textFields["wayhome-search"].value as? String ?? "").contains("sand"), "the cross left the search typed")
        XCTAssertFalse(app.buttons["wayhome-search-clear"].exists, "the cross stayed on an empty search")
    }

    /// "There should be '1 used up' in the heading counting", and Used up is taken back
    /// with Undo, not Back (their field test, 3 Oct 2026).
    func testUsedUpIsCountedInTheHeadingAndUndone() {
        let app = launch()
        let home = openWayHomeOfThree(app)
        tap(app, id: "wayhome-line-1-usedup")
        XCTAssertTrue(waitUntil { self.words(home) == "0/2 · 1 used up" }, "the heading does not count what was used up: '\(words(home))'")
        let undo = app.buttons["wayhome-line-1-usedup"]
        XCTAssertTrue(waitUntil { self.words(undo) == "Undo" }, "a used-up line does not offer Undo: '\(words(undo))'")
        shot(app, "way-home-used-up")
        tap(app, id: "wayhome-line-1-usedup")
        XCTAssertTrue(waitUntil { self.words(home) == "0/3" }, "Undo did not bring it back: '\(words(home))'")
        XCTAssertTrue(waitUntil { self.words(undo) == "Used up" }, "after Undo it does not offer Used up again: '\(words(undo))'")
    }

    /// "While packing, we need a button to check off all items" (their field test, 3 Oct
    /// 2026): one press ticks everything still coming home; the same place clears the ticks.
    func testEverythingIsTickedForTheWayHomeAtOnce() {
        let app = launch()
        let home = openWayHomeOfThree(app)
        tap(app, id: "wayhome-line-1-usedup")
        XCTAssertTrue(waitUntil { self.words(home) == "0/2 · 1 used up" }, "'\(words(home))'")
        tap(app, id: "wayhome-tickall")
        XCTAssertTrue(waitUntil { self.words(home) == "2/2 · 1 used up" }, "Tick everything did not tick everything: '\(words(home))'")
        XCTAssertTrue(isOn(app.buttons["wayhome-line-0"]) && isOn(app.buttons["wayhome-line-2"]), "the lines do not show their ticks")
        XCTAssertFalse(isOn(app.buttons["wayhome-line-1"]), "a used-up line was ticked")
        shot(app, "way-home-all-ticked")
        tap(app, id: "wayhome-tickall")
        XCTAssertTrue(waitUntil { self.words(home) == "0/2 · 1 used up" }, "the same place did not clear the ticks: '\(words(home))'")
    }

    /// "A button for each item to write maintenance in the comment" (their field test,
    /// 3 Oct 2026): Note opens a field under the line; saved, it shows under the name and is
    /// kept — and it is one of On site's maintenance notes too.
    func testALineKeepsANoteForTheWayHome() {
        let app = launch()
        _ = openWayHomeOfThree(app)
        XCTAssertFalse(app.staticTexts["wayhome-line-0-notetext"].exists, "a note before one was written")
        tap(app, id: "wayhome-line-0-note")
        let field = app.textFields["wayhome-note-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Note opens no field")
        type("Zip broken", into: field)
        shot(app, "way-home-note-writing")
        tap(app, id: "wayhome-note-save")
        XCTAssertTrue(waitUntil { !app.textFields["wayhome-note-field"].exists }, "the note field stayed open")
        let note = app.staticTexts["wayhome-line-0-notetext"]
        XCTAssertTrue(waitUntil { self.words(note) == "Zip broken" }, "the note is not shown under the line: '\(words(note))'")
        shot(app, "way-home-note")
        tap(app, id: "wayhome-done")
        XCTAssertTrue(disappears(app, "wayhome-screen", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["onsite-note-0-text"]) == "Zip broken" },
                      "On site does not list the note: '\(words(app.staticTexts["onsite-note-0-text"]))'")
        openWayHome(app)
        XCTAssertTrue(appears(app, "wayhome-screen", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["wayhome-line-0-notetext"]) == "Zip broken" }, "the note was not kept")
    }

    /// "A possibility to open the item from here, change or adjust stuff regarding the
    /// item, and then come straight back here when done" (their field test, 3 Oct 2026).
    /// Save and Cancel both land on the way home as it was — the search still typed.
    func testAThingOpensFromTheWayHomeAndComesBack() {
        let app = launch()
        let home = openWayHomeOfThree(app)
        XCTAssertFalse(app.buttons["wayhome-line-2-open"].exists, "something bought on site offers a thing to open")
        tap(app, id: "wayhome-line-0")
        XCTAssertTrue(waitUntil { self.words(home) == "1/3" }, "'\(words(home))'")
        let search = app.textFields["wayhome-search"]
        type("pass", into: search)
        XCTAssertTrue(waitUntil { !app.buttons["wayhome-line-2"].exists }, "the search did not narrow the list")
        tap(app, id: "wayhome-line-0-open")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5), "Open did not open the thing")
        shot(app, "way-home-open-thing")
        replace("Safe", in: app.textFields["thing-storage"])
        tap(app, id: "thing-save")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5), "Save did not close the thing")
        XCTAssertTrue(waitUntil { (search.value as? String ?? "").contains("pass") }, "the search was lost on the way back")
        XCTAssertTrue(app.buttons["wayhome-line-0"].exists && !app.buttons["wayhome-line-2"].exists,
                      "the way home did not come back as it was")
        XCTAssertTrue(waitUntil { self.words(home) == "1/3" }, "the ticks changed: '\(words(home))'")
        // The change reached the thing itself; Cancel comes back the same way.
        tap(app, id: "wayhome-line-0-open")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5), "Open did not open the thing a second time")
        XCTAssertTrue(waitUntil { (app.textFields["thing-storage"].value as? String) == "Safe" }, "the change did not reach the thing")
        tap(app, id: "thing-cancel")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5), "Cancel did not close the thing")
        XCTAssertTrue(waitUntil { (search.value as? String ?? "").contains("pass") && app.buttons["wayhome-line-0"].exists },
                      "Cancel did not come back to the way home as it was")
    }

    /// Pack to go home lives on the trip's On site page (their field test, 3 Oct 2026):
    /// the trip's On site door, then the page's Pack to go home. With On site already
    /// open (back from the way home), straight to its button.
    private func openWayHome(_ app: XCUIApplication) {
        if find(app, "onsite-screen") == nil {
            tap(app, id: "trip-onsite")
            XCTAssertTrue(appears(app, "onsite-screen", timeout: 5), "the On site door did not open On site")
        }
        tap(app, id: "onsite-wayhome-open")
    }

    /// The sample trip, under way (`-uiTestingOnSite`: it began yesterday), open — with
    /// Passport and Phone charger packed on the way out, so two things went.
    private func openTripUnderWay(_ app: XCUIApplication) {
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        app.buttons["trip-line-0"].tap()
        XCTAssertTrue(waitUntil { self.words(progress) == "1/7" }, "'\(words(progress))'")
        app.buttons["trip-line-1"].tap()
        XCTAssertTrue(waitUntil { self.words(progress) == "2/7" }, "'\(words(progress))'")
    }

    /// "Add a phase (in the graphics as well)… 'On site'. It should come immediately after
    /// Pack" (their field test, 3 Oct 2026): a trip under way stands at On site — on the
    /// strip under its name, which still fits the screen with five steps, and in the
    /// picture a tap opens.
    func testATripUnderWayStandsAtOnSite() {
        let app = launch("-uiTestingOnSite")
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let strip = app.buttons["trip-loop"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5), "the trip does not show the loop")
        XCTAssertTrue(waitUntil { (strip.value as? String) == "On site" }, "a trip under way is at '\(strip.value as? String ?? "")'")
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(strip.frame.maxX, window.maxX + 1, "the five steps run off the screen: \(strip.frame) in \(window)")
        XCTAssertGreaterThanOrEqual(strip.frame.minX, window.minX - 1, "the five steps run off the screen: \(strip.frame) in \(window)")
        shot(app, "loop-trip-onsite")
        tap(app, id: "trip-loop")
        XCTAssertTrue(appears(app, "loop-screen", timeout: 5), "the strip did not open the picture")
        XCTAssertTrue(waitUntil { self.isHere(app, 2) }, "the picture does not say You are here on On site")
        XCTAssertFalse([0, 1, 3, 4].contains { self.isHere(app, $0) }, "You are here on more than one step")
        shot(app, "loop-picture-onsite")
        tap(app, id: "loop-done")
        XCTAssertTrue(disappears(app, "loop-screen", timeout: 5))
    }

    /// On site holds all four (his choice, 3 Oct 2026): Bought on site, Left on site,
    /// Maintenance notes, Pack to go home. Its door on a trip under way says what it holds;
    /// a thing bought is added there, one that went is left on site and Undo brings it
    /// back, and Pack to go home opens from the page.
    func testOnSiteHoldsBoughtLeftNotesAndTheWayHome() {
        let app = launch("-uiTestingOnSite")
        openTripUnderWay(app)
        let door = app.buttons["trip-onsite"]
        XCTAssertTrue(door.waitForExistence(timeout: 5), "a trip under way has no On site door")
        XCTAssertTrue(waitUntil { (door.value as? String) == "home 0/2" }, "the door says '\(door.value as? String ?? "")'")
        shot(app, "onsite-door")
        tap(app, id: "trip-onsite")
        XCTAssertTrue(appears(app, "onsite-screen", timeout: 5), "the door did not open On site")
        for part in ["onsite-bought", "onsite-left", "onsite-notes", "onsite-wayhome"] {
            XCTAssertNotNil(find(app, part), "On site has no \(part)")
        }
        let summary = app.staticTexts["onsite-summary"]
        XCTAssertTrue(waitUntil { self.words(summary) == "home 0/2" }, "'\(words(summary))'")
        shot(app, "onsite-empty")

        // Bought on site: pressed too early it says what is missing; then it is on the list.
        tap(app, id: "onsite-bought-add")
        XCTAssertTrue(app.staticTexts["onsite-bought-needs"].waitForExistence(timeout: 5), "Bought on site with nothing typed said nothing")
        type("Sun hat", into: app.textFields["onsite-bought-name"])
        tap(app, id: "onsite-bought-add")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["onsite-bought-0"]) == "Sun hat" }, "what was bought is not listed")
        XCTAssertTrue(waitUntil { self.words(summary) == "1 bought \u{00B7} home 0/3" }, "'\(words(summary))'")
        hideKeyboard(app)

        // Left on site: picked from what went, by a word; Undo brings it back.
        XCTAssertTrue(app.staticTexts["onsite-left-none"].exists, "something is left before anything was")
        tap(app, id: "onsite-leave")
        let search = app.textFields["onsite-leave-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), "Leave something here offers no search")
        type("charg", into: search)
        XCTAssertTrue(waitUntil { self.words(app.buttons["onsite-leave-pick-0"]).hasPrefix("Phone charger") && !app.buttons["onsite-leave-pick-1"].exists },
                      "the search did not find the charger alone: '\(words(app.buttons["onsite-leave-pick-0"]))'")
        shot(app, "onsite-leave-pick")
        tap(app, id: "onsite-leave-pick-0")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["onsite-left-0"]) == "Phone charger" }, "the charger is not left on site")
        XCTAssertFalse(app.textFields["onsite-leave-search"].exists, "the list to pick from stayed open")
        XCTAssertTrue(waitUntil { self.words(summary) == "1 bought \u{00B7} 1 left \u{00B7} home 0/2" }, "'\(words(summary))'")
        shot(app, "onsite-left")
        tap(app, id: "onsite-left-0-undo")
        XCTAssertTrue(app.staticTexts["onsite-left-none"].waitForExistence(timeout: 5), "Undo did not bring it back")
        XCTAssertTrue(waitUntil { self.words(summary) == "1 bought \u{00B7} home 0/3" }, "'\(words(summary))'")

        // Pack to go home, from the page: what went and what was bought.
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["onsite-wayhome-progress"]) == "0 of 3 packed" },
                      "'\(words(app.staticTexts["onsite-wayhome-progress"]))'")
        tap(app, id: "onsite-wayhome-open")
        XCTAssertTrue(appears(app, "wayhome-screen", timeout: 5), "Pack to go home did not open from On site")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["wayhome-progress"]) == "0/3" }, "'\(words(app.staticTexts["wayhome-progress"]))'")
        tap(app, id: "wayhome-line-0")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["wayhome-progress"]) == "1/3" })
        tap(app, id: "wayhome-done")
        XCTAssertTrue(disappears(app, "wayhome-screen", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["onsite-wayhome-progress"]) == "1 of 3 packed" },
                      "On site did not follow the way home: '\(words(app.staticTexts["onsite-wayhome-progress"]))'")
        tap(app, id: "onsite-done")
        XCTAssertTrue(disappears(app, "onsite-screen", timeout: 5))
        XCTAssertTrue(waitUntil { (door.value as? String) == "1 bought \u{00B7} home 1/3" }, "the door says '\(door.value as? String ?? "")'")
    }

    /// A maintenance note made on site (his choice, 3 Oct 2026) stays with the trip AND
    /// lands on the thing, dated, for Care: Care → Your things → the thing → Notes has it.
    func testANoteMadeOnSiteReachesTheThing() {
        let app = launch("-uiTestingOnSite")
        openTripUnderWay(app)
        tap(app, id: "trip-onsite")
        XCTAssertTrue(appears(app, "onsite-screen", timeout: 5))
        XCTAssertTrue(app.staticTexts["onsite-notes-none"].waitForExistence(timeout: 5), "a note before one was written")
        tap(app, id: "onsite-note-add")
        type("pass", into: app.textFields["onsite-note-search"])
        XCTAssertTrue(waitUntil { self.words(app.buttons["onsite-note-pick-0"]).hasPrefix("Passport") }, "the search did not find the passport")
        // GitHub's iPhone 17 shows the on-screen keyboard over the found row (0.61, 5 Oct
        // 2026): put it away first, as he would to tap what he found.
        hideKeyboard(app)
        tap(app, id: "onsite-note-pick-0")
        let field = app.textFields["onsite-note-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "picking a thing opens no note")
        XCTAssertEqual(words(app.staticTexts["onsite-note-for"]), "Passport", "the note is not said to be for the passport")
        // Save with nothing typed says what is missing.
        tap(app, id: "onsite-note-save")
        XCTAssertTrue(app.staticTexts["onsite-note-needs"].waitForExistence(timeout: 5), "an empty note was saved without a word")
        type("Zip broken", into: field)
        shot(app, "onsite-note-writing")
        tap(app, id: "onsite-note-save")
        XCTAssertTrue(waitUntil { !app.textFields["onsite-note-field"].exists }, "the note field stayed open")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["onsite-note-0"]) == "Passport" }, "the note is not listed")
        XCTAssertEqual(words(app.staticTexts["onsite-note-0-text"]), "Zip broken")
        XCTAssertTrue(words(app.staticTexts["onsite-summary"]).contains("1 note"), "'\(words(app.staticTexts["onsite-summary"]))'")
        hideKeyboard(app)
        shot(app, "onsite-note")
        tap(app, id: "onsite-done")
        XCTAssertTrue(disappears(app, "onsite-screen", timeout: 5))
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))

        // On the thing, for Care.
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        type("Passport", into: app.textFields["things-search"])
        tap(app, id: "thing-row-0")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let mo = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let line = "On site \(c.day!) \(mo[c.month! - 1]) \(c.year!): Zip broken"
        // The old note and, on a line of its own, the new one. (A one-line field shows
        // them run together — "Keep it dry On site…" — and this fails; seen 3 Oct 2026.)
        let notes = app.descendants(matching: .any).matching(identifier: "thing-notes").firstMatch
        XCTAssertTrue(notes.waitForExistence(timeout: 5), "the thing has no Notes field")
        XCTAssertTrue(waitUntil { (notes.value as? String ?? "") == "Keep it dry\n" + line },
                      "the thing's notes are not its old note and, under it, '\(line)': '\(notes.value as? String ?? "")'")
        bringIntoView(app, notes)
        shot(app, "onsite-note-on-thing")
    }

    /// iCloud sync, made visible (his field test, 3 Oct 2026): Settings has the card;
    /// Sync now checks in from this device, and the card says so. (The tests keep the
    /// library on the device, so the card says sync is off — the check-in still shows.)
    func testSyncNowChecksInFromThisDevice() {
        let app = launch()
        tab(app, "settings")
        XCTAssertTrue(appears(app, "screen-settings"))
        let me = app.staticTexts["sync-self"]
        XCTAssertTrue(me.waitForExistence(timeout: 5), "no iCloud sync card in Settings")
        XCTAssertTrue(words(me).contains("has not checked in"), "a check-in before Sync now: '\(words(me))'")
        XCTAssertTrue(words(app.staticTexts["sync-other"]).contains("has not checked in"), "the other device checked in in a test")
        tap(app, id: "sync-now")
        XCTAssertTrue(waitUntil { self.words(me).contains("checked in today") }, "Sync now did not check in: '\(words(me))'")
        XCTAssertTrue(app.staticTexts["sync-said"].waitForExistence(timeout: 5), "Sync now said nothing")
        shot(app, "sync-card")
    }

    /// Field test 7.3/6.1 (3 Oct 2026): the trip's own bag says whether it goes in the cabin,
    /// and the cabin check follows at once. (-uiTestingChecks: a plane trip, a knife and
    /// sun cream in the carry-on.) And Quick says that Transport still counts.
    func testABagOnTheTripSaysWhetherItGoesInTheCabin() {
        let app = launch("-uiTestingChecks")
        setSwitch(app, "trip-quick", on: true)
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["trip-quick-note"]).contains("Transport still counts") },
                      "Quick does not say that Transport still counts: '\(words(app.staticTexts["trip-quick-note"]))'")
        setSwitch(app, "trip-quick", on: false)
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(waitUntil { app.buttons["trip-check-cabin-0"].exists }, "the carry-on is not checked to begin with")
        tap(app, id: "bag-0")
        XCTAssertTrue(waitUntil { self.isSwitchOn(app, "bag-0-cabin") }, "the trip's carry-on does not say it goes in the cabin")
        setSwitch(app, "bag-0-cabin", on: false)
        XCTAssertTrue(waitUntil { !app.buttons["trip-check-cabin-0"].exists }, "out of the cabin, it is still checked")
        setSwitch(app, "bag-0-cabin", on: true)
        XCTAssertTrue(waitUntil { app.buttons["trip-check-cabin-0"].exists }, "back in the cabin, it is not checked again")
    }

    /// Field test 2.3 (3 Oct 2026): the Action button's "Choose a grab list" opens a menu
    /// of every grab list; one tap opens the chosen one. ("-openGrabMenu" sets the very
    /// request the Shortcut sets.)
    func testTheActionButtonMenuOpensTheChosenGrabList() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-openGrabMenu"]
        app.launch()
        XCTAssertTrue(appears(app, "grab-menu", timeout: 20), "the Action button did not open the menu of grab lists")
        XCTAssertTrue(app.buttons["grab-menu-5"].waitForExistence(timeout: 5), "the menu does not hold every grab list")
        shot(app, "grab-menu")
        tap(app, id: "grab-menu-1")
        XCTAssertTrue(appears(app, "grab-detail", timeout: 10), "choosing in the menu did not open that grab list")
    }

    #if os(iOS)
    /// Field test 8.4 (3 Oct 2026): what was ticked in Reminders in the shop is ticked here
    /// as soon as the app is back in front — no switching tabs. ("-pretendShopTicks": a
    /// shop where everything sent was ticked.)
    func testWhatWasTickedInTheShopIsTickedOnReturn() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-pretendShopTicks"]
        app.launch()
        tab(app, "actions")
        XCTAssertTrue(appears(app, "screen-actions"))
        tap(app, id: "actions-tab-buy")
        for line in ["Sun cream", "Plasters"] {
            type(line, into: app.textFields["buy-add-text"])
            XCTAssertTrue(waitUntil { app.buttons["buy-add"].isEnabled })
            tap(app, id: "buy-add")
        }
        tap(app, id: "buy-send")
        XCTAssertTrue(app.staticTexts["buy-send-says"].waitForExistence(timeout: 5), "they were not sent")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["buy-count"]) == "2 to buy" }, "ticked before the shop")
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.staticTexts["buy-count"]) == "All bought." },
                      "back from the shop, the ticks did not come: '\(words(app.staticTexts["buy-count"]))'")
        // Unticked here, it stays unticked: its reminder is unticked too, so the
        // next read back does not tick it again (the spec pass, 5 Oct 2026).
        tap(app, id: "buy-0")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["buy-count"]) == "1 to buy" }, "the untick did not take")
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        sleep(2)
        XCTAssertEqual(words(app.staticTexts["buy-count"]), "1 to buy", "the shop ticked again what he had unticked")
    }
    #endif

    /// Save as Excel (the web app's Excel button, gap list 2026-09-27): near the end
    /// of a trip; it makes the file and opens the place to save it. (What the file
    /// holds is the model's test: WorkbookTests.)
    func testATripIsSavedAsExcel() {
        let app = launch()
        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let excel = app.buttons["trip-excel"]
        XCTAssertTrue(excel.waitForExistence(timeout: 5), "no Save as Excel on the trip")
        bringIntoView(app, excel)
        // Share is a real button ON THE SAME LINE as Save as Excel (his test D.22).
        let share = app.buttons["trip-share"]
        XCTAssertTrue(share.exists, "no Share on the trip")
        XCTAssertLessThan(abs(share.frame.midY - excel.frame.midY), 4,
                          "Share is not on the Excel line: \(share.frame) vs \(excel.frame)")
        XCTAssertGreaterThan(share.frame.minX, excel.frame.maxX - 1, "Share is not beside Save as Excel")
        tapVisible(app, excel)
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["trip-excel-status"]).hasPrefix("Choosing") },
                      "the save was not started: '\(words(app.staticTexts["trip-excel-status"]))'")
        sleep(2); shot(app, "excel-save")
        #if os(macOS)
        XCTAssertTrue(waitUntil(timeout: 10) { app.sheets.count > 0 || app.dialogs.count > 0 }, "no Save window opened")
        app.typeKey(.escape, modifierFlags: [])
        #endif
    }

    /// His test comments on Create new trip (2026-09-28): the date grid has a way
    /// out that puts the dates back (C.2), and Quick says what it means in green,
    /// only while it is on (C.7).
    func testTheDateGridCanBeLeftAndQuickSaysSo() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        XCTAssertFalse(app.staticTexts["trip-quick-note"].exists, "the Quick note shows while Quick is off")
        setSwitch(app, "trip-quick", on: true)
        XCTAssertTrue(app.staticTexts["trip-quick-note"].waitForExistence(timeout: 5), "Quick on says nothing")
        setSwitch(app, "trip-quick", on: false)
        XCTAssertTrue(waitUntil { !app.staticTexts["trip-quick-note"].exists }, "the Quick note stays after Quick is off")

        setSwitch(app, "trip-dates", on: true)
        XCTAssertTrue(app.staticTexts["range-title-0"].waitForExistence(timeout: 5), "the month grid did not open")
        let field = app.buttons["trip-dates-field"]
        let before = field.value as? String ?? ""
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: 1, to: Date())!)
        let tomorrow = String(format: "range-day-%04d-%02d-%02d", d.year!, d.month!, d.day!)
        if app.buttons[tomorrow].exists { tap(app, id: tomorrow) } else { tap(app, id: "range-next"); tap(app, id: tomorrow) }
        XCTAssertTrue(waitUntil { (field.value as? String ?? "") != before }, "picking a first day changed nothing")
        // OK before the last day: the grid stays and says what is missing (his rule for
        // a main button, 2026-09-26 — never grey, and pressed too early it says why).
        XCTAssertFalse(app.staticTexts["range-needs"].exists, "the grid asks for the last day before OK was pressed")
        tap(app, id: "range-ok")
        XCTAssertTrue(app.staticTexts["range-needs"].waitForExistence(timeout: 5), "OK before the last day said nothing")
        XCTAssertTrue(app.staticTexts["range-title-0"].exists, "OK before the last day closed the grid")
        shot(app, "range-needs")
        tap(app, id: "range-cancel")
        XCTAssertTrue(waitUntil { !app.staticTexts["range-title-0"].exists }, "Cancel did not close the grid")
        XCTAssertEqual(field.value as? String ?? "", before, "Cancel did not put the dates back")
    }

    /// Their field test (Oct 2026): "When I choose the end date, don't just
    /// pop out back, but stay there and present an OK button or a cancel button."
    /// The grid stays open on the range picked, says it, offers OK and Cancel — and
    /// OK keeps it.
    func testTheDateGridWaitsForOK() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        let cal = Calendar.current
        let mo = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        func short(_ n: Int) -> String {
            let c = cal.dateComponents([.day, .month], from: dayFromToday(n))
            return "\(c.day!) \(mo[c.month! - 1])"
        }
        setSwitch(app, "trip-dates", on: true)
        let grid = app.staticTexts["range-title-0"]
        XCTAssertTrue(grid.waitForExistence(timeout: 5), "the month grid did not open")
        let field = app.buttons["trip-dates-field"]
        let summary = app.staticTexts["range-summary"]
        func says() -> String { field.value as? String ?? "" }

        // The last day picked: the grid stays, saying the range, with OK and Cancel.
        pickDay(app, dayFromToday(3))
        pickDay(app, dayFromToday(13))
        XCTAssertTrue(waitUntil { self.words(summary) == "\(short(3)) \u{2013} \(short(13)) \u{00B7} 10 nights" },
                      "the grid does not say the range: '\(words(summary))'")
        XCTAssertTrue(grid.exists, "the grid closed after the last day")
        XCTAssertTrue(app.buttons["range-ok"].exists, "no OK")
        XCTAssertTrue(app.buttons["range-cancel"].exists, "no Cancel")
        shot(app, "range-picked")

        // OK keeps it.
        tap(app, id: "range-ok")
        XCTAssertTrue(waitUntil { !grid.exists }, "OK did not close the grid")
        XCTAssertTrue(says().hasSuffix("10 nights"), "OK did not keep the range: '\(says())'")
    }

    /// With the grid waiting for OK, a tap after a whole range starts a new one (as
    /// it always did), and Cancel — even after a whole range — puts back the dates
    /// the grid opened with (their field test, Oct 2026).
    func testTheDateGridStartsOverAndCancelPutsItBack() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        let cal = Calendar.current
        let mo = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        func short(_ n: Int) -> String {
            let c = cal.dateComponents([.day, .month], from: dayFromToday(n))
            return "\(c.day!) \(mo[c.month! - 1])"
        }
        pickDates(app, from: 3, to: 13)
        let grid = app.staticTexts["range-title-0"]
        let field = app.buttons["trip-dates-field"]
        let summary = app.staticTexts["range-summary"]
        func says() -> String { field.value as? String ?? "" }
        let kept = says()
        XCTAssertTrue(kept.hasSuffix("10 nights"), "'\(kept)'")

        tap(app, id: "trip-dates-field")
        XCTAssertTrue(grid.waitForExistence(timeout: 5), "the field did not open the grid again")
        pickDay(app, dayFromToday(5))
        pickDay(app, dayFromToday(7))
        XCTAssertTrue(waitUntil { self.words(summary).hasSuffix("2 nights") }, "'\(words(summary))'")
        pickDay(app, dayFromToday(6))
        XCTAssertTrue(waitUntil { !says().contains("night") }, "a tap after a whole range did not start a new one: '\(says())'")
        pickDay(app, dayFromToday(9))
        XCTAssertTrue(waitUntil { self.words(summary) == "\(short(6)) \u{2013} \(short(9)) \u{00B7} 3 nights" },
                      "the new range is not said: '\(words(summary))'")
        tap(app, id: "range-cancel")
        XCTAssertTrue(waitUntil { !grid.exists }, "Cancel did not close the grid")
        XCTAssertEqual(says(), kept, "Cancel did not put the dates back")
    }

    /// Valid until says how far away the date is, and offers the usual spans in one
    /// tap — their field test (Oct 2026): "It didn't say 10 days. You have
    /// to calculate that yourself. Maybe we could add that information visually."
    func testValidUntilSaysHowFarAwayAndOffersQuickSpans() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        tap(app, id: "thing-row-0")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        let distance = app.staticTexts["thing-expiry-distance"]
        XCTAssertFalse(distance.exists, "a thing without a date says how far away it is")
        tap(app, id: "thing-expiry-add")
        XCTAssertTrue(waitUntil { self.words(distance) == "today" }, "a date added today does not say so: '\(words(distance))'")

        // Each quick choice sets the date, and the words follow it.
        for (n, said) in ["in 1 month", "in 6 months", "in 1 year", "in 5 years", "in 10 years"].enumerated() {
            select(app, app.buttons["thing-expiry-quick-\(n)"])
            XCTAssertTrue(waitUntil { self.words(distance) == said },
                          "quick choice \(n) reads '\(words(distance))', not '\(said)'")
        }
        shot(app, "valid-until")

        // It is the date itself that moved: saved, and read again.
        select(app, app.buttons["thing-expiry-quick-2"])
        tap(app, id: "thing-save")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))
        tap(app, id: "thing-row-0")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(distance) == "in 1 year" }, "the date did not keep: '\(words(distance))'")
        XCTAssertTrue(isOn(app.buttons["thing-expiry-quick-2"]), "+1 year is not shown as the date's choice")

        // Without the date, nothing is said.
        tap(app, id: "thing-expiry-clear")
        XCTAssertTrue(waitUntil { !distance.exists }, "the words stay after the date is removed")
    }

    /// Context sits UNDER the workouts it describes — set in, after WET and before
    /// Transport (his ask, 2026-09-28) — on Create new trip.
    func testContextSitsUnderTheWorkouts() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        XCTAssertFalse(app.staticTexts["trip-context-title"].exists, "Context shows before a workout is picked")
        let swim = app.buttons["trip-activity-1"]                  // Swim, in the WET activity area
        XCTAssertTrue(swim.waitForExistence(timeout: 5))
        select(app, swim)
        let context = app.staticTexts["trip-context-title"]
        XCTAssertTrue(context.waitForExistence(timeout: 5), "picking Swim did not bring Context")
        bringIntoView(app, context)
        let transport = app.staticTexts["trip-transport-title"]
        XCTAssertGreaterThan(context.frame.minY, swim.frame.maxY, "Context is not under the workouts")
        XCTAssertLessThan(context.frame.maxY, transport.frame.minY, "Context is not before Transport")
        // Set in = its PILLS start further in than Transport's. (Measured on the pills since
        // the field test of 3 Oct 2026: a heading over a block now starts with the band's
        // mark, so the headings' words no longer start at the edge.)
        let inner = app.buttons["trip-context-0"], outer = app.buttons["trip-transport-0"]
        XCTAssertTrue(inner.exists && outer.exists, "no Context or Transport pills")
        XCTAssertGreaterThan(inner.frame.minX, outer.frame.minX + 24,
                             "Context is not set in: \(inner.frame.minX) vs \(outer.frame.minX)")
    }

    /// The web app's "Mark everything packed" / "Clear every tick" (gap list,
    /// 2026-09-27): Tick everything takes the trip to all packed at once; Clear asks
    /// first, Keep them keeps them, and Clear the ticks takes them all away.
    func testEverythingIsTickedAndClearedAtOnce() {
        let app = launch()
        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        app.buttons["trip-line-0"].tap()
        XCTAssertTrue(waitUntil { self.words(progress) == "1/7" }, "the tick did not count: '\(words(progress))'")

        let all = app.buttons["trip-tickall"]
        XCTAssertTrue(all.waitForExistence(timeout: 5), "no Tick everything on the trip")
        XCTAssertEqual(all.value as? String, "6", "it does not say how many are still unticked")
        bringIntoView(app, all)
        shot(app, "tick-all")
        tapVisible(app, all)
        XCTAssertTrue(waitUntil { self.words(progress) == "7/7" }, "Tick everything did not tick everything: '\(words(progress))'")
        XCTAssertTrue(waitUntil { !app.buttons["trip-tickall"].exists }, "Tick everything is still offered with nothing left")

        tapVisible(app, app.buttons["trip-clearall"])
        XCTAssertTrue(app.buttons["trip-clearall-yes"].waitForExistence(timeout: 5), "Clear did not ask first")
        shot(app, "clear-asks")
        tap(app, id: "trip-clearall-no")
        XCTAssertTrue(waitUntil { !app.buttons["trip-clearall-yes"].exists })
        XCTAssertEqual(words(progress), "7/7", "Keep them cleared the ticks")
        tapVisible(app, app.buttons["trip-clearall"])
        tap(app, id: "trip-clearall-yes")
        XCTAssertTrue(waitUntil { self.words(progress) == "0/7" }, "Clear the ticks left some: '\(words(progress))'")
        XCTAssertFalse(app.buttons["trip-clearall"].exists, "Clear is offered with nothing ticked")
    }

    /// The weather card's "Add all" (the web app's): everything the forecast asks for
    /// reaches the trip in one press, and then it asks for nothing.
    func testWeatherAddAllTakesEverything() {
        let app = launch()
        tab(app, "events")
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        let progress = app.staticTexts["trip-progress"]
        XCTAssertTrue(waitUntil { self.words(progress) == "0/7" })
        XCTAssertTrue(app.textFields["weather-place"].waitForExistence(timeout: 5))
        type("Testville", into: app.textFields["weather-place"])
        app.textFields["weather-place"].typeText("\n")        // Return looks it up, and puts the keyboard away
        XCTAssertTrue(app.staticTexts["weather-line"].waitForExistence(timeout: 10), "no forecast came back")
        let addAll = app.buttons["weather-addall"]
        XCTAssertTrue(addAll.waitForExistence(timeout: 5), "wet and cold, several things asked for, and no Add all")
        let asked = Int(addAll.value as? String ?? "") ?? 0
        shot(app, "weather-addall")
        XCTAssertGreaterThanOrEqual(asked, 2, "Add all shown for fewer than two")
        tapVisible(app, addAll)
        XCTAssertTrue(waitUntil { self.words(progress) == "0/\(7 + asked)" },
                      "Add all did not bring all \(asked): '\(words(progress))'")
        XCTAssertTrue(app.staticTexts["weather-nothing-missing"].waitForExistence(timeout: 5), "it still asks for something")
        XCTAssertFalse(app.buttons["weather-addall"].exists, "Add all is still offered with nothing missing")
    }

    /// The world map (the web app's, gap list 2026-09-27): empty until a trip has a
    /// place; a trip gets its place from its weather; then one pin, one card, and
    /// the summary counts them.
    func testTheMapShowsWhereTheTripsWent() {
        let app = launch()
        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        tap(app, id: "events-map")
        XCTAssertTrue(appears(app, "map-screen", timeout: 5), "the map did not open")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["map-summary"]) == "0 places · 0 trips" },
                      "'\(words(app.staticTexts["map-summary"]))'")
        XCTAssertTrue(app.staticTexts["map-empty"].exists, "an empty map does not say why")
        tap(app, id: "map-done")
        XCTAssertTrue(disappears(app, "map-screen", timeout: 5))
        // All your trips, and its small map, under Your year (his G.3).
        XCTAssertTrue(app.staticTexts["events-alltime-heading"].waitForExistence(timeout: 5), "no All your trips")
        let mini = app.buttons["events-minimap"]
        XCTAssertTrue(mini.exists, "no map on Trips")
        XCTAssertEqual(mini.value as? String, "0 places · 0 trips")

        // A place with NO forecast for the dates still reaches the map (his test G.6:
        // a trip already over never got its pin).
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(app.textFields["weather-place"].waitForExistence(timeout: 5))
        type("Lateplace", into: app.textFields["weather-place"])
        app.textFields["weather-place"].typeText("\n")
        XCTAssertTrue(app.staticTexts["weather-trouble"].waitForExistence(timeout: 10), "no word that there is no forecast")
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))
        tap(app, id: "events-map")
        XCTAssertTrue(appears(app, "map-screen", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["map-summary"]) == "1 place · 1 trip" },
                      "a place without a forecast did not reach the map: '\(words(app.staticTexts["map-summary"]))'")
        XCTAssertEqual(words(app.staticTexts["map-place-0-name"]), "Lateville, SE")
        tap(app, id: "map-done")
        XCTAssertTrue(disappears(app, "map-screen", timeout: 5))

        // The trip's weather gives it its place.
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(app.textFields["weather-place"].waitForExistence(timeout: 5))
        replace("Testville", in: app.textFields["weather-place"])
        app.textFields["weather-place"].typeText("\n")
        XCTAssertTrue(app.staticTexts["weather-line"].waitForExistence(timeout: 10), "no forecast came back")
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))

        tap(app, id: "events-map")
        XCTAssertTrue(appears(app, "map-screen", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["map-summary"]) == "1 place · 1 trip" },
                      "the trip did not reach the map: '\(words(app.staticTexts["map-summary"]))'")
        XCTAssertEqual(words(app.staticTexts["map-place-0-name"]), "Testville, SE", "the place card is missing or unnamed")
        XCTAssertTrue(find(app, "map-view") != nil || app.maps.firstMatch.exists, "no map drawn")
        XCTAssertFalse(app.staticTexts["map-empty"].exists, "it still says there are no places")
        shot(app, "map")
        tap(app, id: "map-done")
        XCTAssertTrue(disappears(app, "map-screen", timeout: 5))
        // The small map on Trips follows, and opens the whole map.
        XCTAssertTrue(waitUntil { (mini.value as? String) == "1 place · 1 trip" },
                      "the map on Trips did not follow: '\(mini.value as? String ?? "")'")
        tapVisible(app, mini)
        XCTAssertTrue(appears(app, "map-screen", timeout: 5), "the map on Trips does not open the whole map")
        tap(app, id: "map-done")
        XCTAssertTrue(disappears(app, "map-screen", timeout: 5))
    }

    /// Sharing a trip (the web app's links, gap list 2026-09-27): its link is the web
    /// app's; copied and opened here, it comes back as a new trip, unticked.
    func testATripIsSharedAndOpenedAgain() {
        let app = launch()
        tab(app, "events")
        XCTAssertTrue(appears(app, "screen-events"))
        app.buttons["trip-row-0"].tap()
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        app.buttons["trip-line-0"].tap()
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["trip-progress"]) == "1/7" })
        tapVisible(app, app.buttons["trip-share"])
        XCTAssertTrue(appears(app, "share-screen", timeout: 5), "Share did not open")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["share-link"]).hasPrefix("https://marsch124.github.io/AMS-Packing/#/t/") },
                      "not a web app trip link: '\(words(app.staticTexts["share-link"]).prefix(60))'")
        XCTAssertTrue(app.buttons["share-send"].exists, "no way to send it")
        shot(app, "share-trip")
        tap(app, id: "share-copy")
        XCTAssertTrue(waitUntil { (app.buttons["share-copy"].value as? String) == "copied" }, "Copy link did not say so")
        tap(app, id: "share-done")
        XCTAssertTrue(disappears(app, "share-screen", timeout: 5))
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))

        tab(app, "settings")
        tap(app, id: "settings-openshared")
        XCTAssertTrue(appears(app, "shared-screen", timeout: 5), "Open a shared link did not open")
        tap(app, id: "shared-paste")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shared-kind"]) == "A TRIP" },
                      "the copied link was not read as a trip: '\(words(app.staticTexts["shared-kind"]))'")
        XCTAssertEqual(words(app.staticTexts["shared-name"]), "Weekend in the hills")
        shot(app, "shared-trip")
        tap(app, id: "shared-add")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shared-result"]).hasPrefix("Added") }, "the trip was not added")
        tap(app, id: "shared-done")
        XCTAssertTrue(disappears(app, "shared-screen", timeout: 5))
        tab(app, "events")
        XCTAssertTrue(waitUntil { app.buttons["trip-row-1"].exists }, "the shared trip is not among the trips")
    }

    /// Sharing a template and a grab list: the template link carries a QR code and
    /// comes back as a new template (Replace offered, as the name is his); the grab
    /// list comes back to wait in Grab Lists. Rubbish is refused out loud.
    func testATemplateAndAGrabListAreSharedAndOpenedAgain() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        let before = words(app.staticTexts["templates-summary"])
        // Row 1 is Hiking, an ordinary template (row 0 is the always-packed base,
        // which — as in the web app — is never offered for Replace).
        app.buttons["template-row-1"].tap()
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        tap(app, id: "template-share")
        XCTAssertTrue(appears(app, "share-screen", timeout: 5))
        XCTAssertTrue(waitUntil { self.find(app, "share-qr") != nil || app.images["share-qr"].exists }, "a short template link has no QR code")
        shot(app, "share-template")
        tap(app, id: "share-copy")
        tap(app, id: "share-done")
        XCTAssertTrue(disappears(app, "share-screen", timeout: 5))
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))

        tab(app, "settings")
        tap(app, id: "settings-openshared")
        XCTAssertTrue(appears(app, "shared-screen", timeout: 5))
        type("hello there", into: app.textFields["shared-input"])
        tap(app, id: "shared-open")
        XCTAssertTrue(app.staticTexts["shared-bad"].waitForExistence(timeout: 5), "rubbish was not refused out loud")
        tap(app, id: "shared-paste")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shared-kind"]) == "A TEMPLATE" }, "not read as a template")
        XCTAssertEqual(words(app.staticTexts["shared-name"]), "Hiking")
        shot(app, "shared-template")
        XCTAssertTrue(app.buttons["shared-replace"].exists, "his own template of that name is not offered to replace")
        // He has a Hiking: as a NEW one it needs a name of its own (the spec pass, 5 Oct
        // 2026 — a second Hiking reads as two libraries meeting). A free one is offered.
        XCTAssertTrue(app.staticTexts["shared-name-taken"].waitForExistence(timeout: 5), "a name he has is not said")
        let newName = app.textFields["shared-new-name"]
        XCTAssertEqual(newName.value as? String, "Hiking 2", "no free name offered")
        replace("Hiking", in: newName)
        tap(app, id: "shared-add")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shared-add-needs"]).contains("do not have") },
                      "a second Hiking was not refused out loud")
        XCTAssertFalse(app.staticTexts["shared-result"].exists, "a second Hiking was added")
        replace("Hiking club", in: newName)
        tap(app, id: "shared-add")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shared-result"]).hasPrefix("Added") })
        tap(app, id: "shared-done")
        XCTAssertTrue(disappears(app, "shared-screen", timeout: 5))
        tab(app, "templates")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["templates-summary"]) != before },
                      "the shared template did not arrive: still '\(before)'")

        tab(app, "home")
        app.buttons["grab-0"].tap()
        XCTAssertTrue(appears(app, "grab-detail", timeout: 5) || app.buttons["grab-done"].waitForExistence(timeout: 5))
        tap(app, id: "grab-share")
        XCTAssertTrue(appears(app, "share-screen", timeout: 5))
        tap(app, id: "share-copy")
        tap(app, id: "share-done")
        XCTAssertTrue(disappears(app, "share-screen", timeout: 5))
        tap(app, id: "grab-done")
        tab(app, "settings")
        tap(app, id: "settings-openshared")
        XCTAssertTrue(appears(app, "shared-screen", timeout: 5))
        tap(app, id: "shared-paste")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shared-kind"]) == "A GRAB LIST" }, "not read as a grab list")
        tap(app, id: "shared-add")
        // Home holds eight and the sample has six: it takes a free place — and says so.
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shared-result"]).contains("on Home") },
                      "it does not say where the grab list went: '\(words(app.staticTexts["shared-result"]))'")
        tap(app, id: "shared-done")
        XCTAssertTrue(disappears(app, "shared-screen", timeout: 5))
        // It really is on Home — not just said to be.
        tab(app, "home")
        XCTAssertTrue(waitUntil { app.buttons["grab-6"].exists }, "the shared grab list is not on Home")
    }

    /// Replace says what it does before he says yes, and takes the sender's things
    /// into HIS template (the spec pass, 2026-10-05: it used to take his icon,
    /// sections, bags and answers without a word). The sample's Hiking is shared and
    /// opened again, so the question here is the words; the model holds the rest
    /// (ReplaceTemplateTests).
    func testReplacingATemplateSaysWhatItKeeps() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        let before = words(app.staticTexts["templates-summary"])
        app.buttons["template-row-1"].tap()
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        tap(app, id: "template-share")
        XCTAssertTrue(appears(app, "share-screen", timeout: 5))
        tap(app, id: "share-copy")
        tap(app, id: "share-done")
        XCTAssertTrue(disappears(app, "share-screen", timeout: 5))
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))

        tab(app, "settings")
        tap(app, id: "settings-openshared")
        XCTAssertTrue(appears(app, "shared-screen", timeout: 5))
        tap(app, id: "shared-paste")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shared-kind"]) == "A TEMPLATE" }, "not read as a template")
        XCTAssertFalse(app.staticTexts["shared-replace-says"].exists, "the question came before Replace was pressed")
        tap(app, id: "shared-replace")
        let says = app.staticTexts["shared-replace-says"]
        XCTAssertTrue(waitUntil { self.words(says).contains("stay yours") }, "Replace does not say what it keeps: '\(words(says))'")
        XCTAssertTrue(words(says).hasPrefix("It keeps the same things"), "its own things, shared back: '\(words(says))'")
        shot(app, "shared-replace")
        tap(app, id: "shared-replace-yes")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["shared-result"]).hasPrefix("Replaced") },
                      "'\(words(app.staticTexts["shared-result"]))'")
        tap(app, id: "shared-done")
        XCTAssertTrue(disappears(app, "shared-screen", timeout: 5))
        tab(app, "templates")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["templates-summary"]) == before },
                      "Replace made a template more or fewer: '\(words(app.staticTexts["templates-summary"]))', was '\(before)'")
    }

    /// A Toggle is a switch on the iPhone and a check box on the Mac.
    private func switchNamed(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        _ = waitUntil(timeout: 5) { app.switches[id].exists || app.checkBoxes[id].exists }
        return app.switches[id].exists ? app.switches[id] : app.checkBoxes[id]
    }

    private func isSwitchOn(_ app: XCUIApplication, _ id: String) -> Bool {
        let e = app.switches[id].exists ? app.switches[id] : app.checkBoxes[id]
        guard e.exists else { return false }
        if let s = e.value as? String { return s == "1" }
        if let n = e.value as? NSNumber { return n.boolValue }
        return false
    }

    private func setSwitch(_ app: XCUIApplication, _ id: String, on: Bool) {
        let e = switchNamed(app, id)
        XCTAssertTrue(e.exists, "no \(id) switch")
        for _ in 0..<3 where isSwitchOn(app, id) != on {
            bringIntoView(app, e)
            #if os(macOS)
            e.tap()
            #else
            e.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()    // the switch, not its words
            #endif
            _ = waitUntil(timeout: 2) { self.isSwitchOn(app, id) == on }
        }
        XCTAssertEqual(isSwitchOn(app, id), on, "\(id) did not switch")
    }

    /// Today + `n` days, at midnight here.
    private func dayFromToday(_ n: Int) -> Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: n, to: cal.startOfDay(for: Date()))!
    }

    /// Tap a day in the open month grid, paging towards its month first.
    private func pickDay(_ app: XCUIApplication, _ d: Date) {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: d)
        let id = String(format: "range-day-%04d-%02d-%02d", c.year!, c.month!, c.day!)
        let months = ["January", "February", "March", "April", "May", "June", "July",
                      "August", "September", "October", "November", "December"]
        for _ in 0..<3 where !app.buttons[id].exists {
            let shown = words(app.staticTexts["range-title-0"]).split(separator: " ")
            let m = (months.firstIndex(of: String(shown.first ?? "")) ?? 0) + 1
            let y = Int(shown.last ?? "") ?? 0
            tap(app, id: (c.year! * 12 + c.month!) > (y * 12 + m) ? "range-next" : "range-prev")
        }
        tap(app, id: id)
    }

    /// Dates on Create new trip: today + `a` to today + `b`, picked in the grid and
    /// kept with OK (the grid waits for it since their field test, Oct 2026).
    private func pickDates(_ app: XCUIApplication, from a: Int, to b: Int) {
        setSwitch(app, "trip-dates", on: true)
        XCTAssertTrue(app.staticTexts["range-title-0"].waitForExistence(timeout: 5), "the month grid did not open")
        pickDay(app, dayFromToday(a))
        pickDay(app, dayFromToday(b))
        tap(app, id: "range-ok")
        XCTAssertTrue(waitUntil { !app.staticTexts["range-title-0"].exists }, "OK did not close the grid")
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
        // In the middle of the screen, in red, with its own way back (his test B.4).
        XCTAssertTrue(app.staticTexts["grab-notyet"].exists, "no Not yet heading on the refusal")
        XCTAssertNotNil(find(app, "grab-detail"), "…and stay open")
        tap(app, id: "grab-message-ok")
        XCTAssertTrue(waitUntil { !app.staticTexts["grab-message"].exists }, "Keep packing did not close the Not yet")

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
        // Never grey, never switched off (his rule for a main button): pressed with
        // nothing typed it adds nothing and says what is missing, under the field.
        XCTAssertTrue(add.waitForExistence(timeout: 5) && add.isEnabled, "Add is switched off with nothing typed")
        tapVisible(app, add)
        let needs = app.staticTexts["trip-add-needs"]
        XCTAssertTrue(needs.waitForExistence(timeout: 5), "Add pressed with nothing typed said nothing")
        XCTAssertEqual(words(progress), before, "Add with nothing typed changed the trip")
        type("Tripod", into: field)
        XCTAssertTrue(waitUntil { !needs.exists }, "the line stayed once a name was typed")
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
        // Never grey (his rule for a main button): pressed empty, it says what is missing.
        XCTAssertTrue(add.waitForExistence(timeout: 5) && add.isEnabled, "Add is switched off with nothing typed")
        tapVisible(app, add)
        let needs = app.staticTexts["action-add-needs"]
        XCTAssertTrue(needs.waitForExistence(timeout: 5), "Add pressed with nothing typed said nothing")
        XCTAssertFalse(app.buttons["action-0"].exists, "Add with nothing typed made a to-do")
        type("Book the ferry", into: field)
        XCTAssertTrue(waitUntil { !needs.exists }, "the line stayed once a to-do was typed")
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
        // With the keyboard up the list is short, and since the Find field (4 Oct 2026)
        // the fifth row sits past what a lazy list builds: put the keyboard away (GitHub's
        // iPhone has one) and travel to it, as he would.
        hideKeyboard(app)
        XCTAssertTrue(scrollUntil(app, "template-item-4", near: "template-item-3"), "the new thing is not on the list")

        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))
        app.buttons["template-row-1"].tap()
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(waitUntil { app.buttons["template-item-4"].exists }, "the thing was lost on the way out and back")

        // ✕ asks first (his test H.5): Keep it keeps it, Take it off takes it off.
        tap(app, id: "template-item-4-remove")
        XCTAssertTrue(app.staticTexts["template-remove-question"].waitForExistence(timeout: 5), "✕ did not ask first")
        XCTAssertTrue(app.buttons["template-item-4"].exists, "asking already took it off")
        tap(app, id: "template-remove-no")
        XCTAssertTrue(waitUntil { !app.staticTexts["template-remove-question"].exists }, "Keep it did not close the question")
        XCTAssertTrue(app.buttons["template-item-4"].exists, "Keep it took it off anyway")
        tap(app, id: "template-item-4-remove")
        tap(app, id: "template-remove-yes")
        XCTAssertTrue(waitUntil { !app.buttons["template-item-4"].exists }, "Take it off did not take it off")
        XCTAssertTrue(app.buttons["template-item-3"].exists, "the other things went too")
    }
    /// His test H.9 (the one red box, 2026-09-28): things he already owns are
    /// chosen onto a template from the whole list — grouped the way he likes, what
    /// is already on it shown as such — and a new one can be made from there too.
    func testThingsHeOwnsArePickedOntoATemplate() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        app.buttons["template-row-1"].tap()                       // Hiking: 4 things
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(app.buttons["template-item-3"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["template-item-4"].exists, "expected 4 things")
        tap(app, id: "template-pick")
        XCTAssertTrue(appears(app, "pick-screen", timeout: 5), "Choose from your things did not open")

        // Grouped A–Z on request; what is on Hiking already says so and cannot be ticked.
        tap(app, id: "pick-group-name")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["pick-heading-0"]) == "A–Z" },
                      "A–Z did not regroup: '\(words(app.staticTexts["pick-heading-0"]))'")
        let rows = (0..<14).map { app.buttons["pick-row-\($0)"] }.filter { $0.exists }
        let onAlready = rows.filter { ($0.value as? String) == "already on it" }
        XCTAssertEqual(onAlready.count, 4, "Hiking's 4 things are not shown as already on it")
        let free = rows.filter { ($0.value as? String) != "already on it" }
        XCTAssertGreaterThanOrEqual(free.count, 2, "nothing left to choose")
        select(app, free[0])
        select(app, free[1])
        XCTAssertTrue(waitUntil { self.words(app.buttons["pick-add"]) == "Add 2" },
                      "the button does not count: '\(words(app.buttons["pick-add"]))'")
        tap(app, id: "pick-add")
        XCTAssertTrue(disappears(app, "pick-screen", timeout: 5), "Add did not close the picker")
        XCTAssertTrue(waitUntil { app.buttons["template-item-5"].exists }, "the two things did not reach the template")
        XCTAssertFalse(app.buttons["template-item-6"].exists, "more than two arrived")

        // A name he owns nothing by becomes a new thing, straight onto the template.
        tap(app, id: "template-pick")
        XCTAssertTrue(appears(app, "pick-screen", timeout: 5))
        type("Gaiters", into: app.textFields["pick-search"])
        tap(app, id: "pick-new")
        tap(app, id: "pick-cancel")
        XCTAssertTrue(disappears(app, "pick-screen", timeout: 5))
        XCTAssertTrue(waitUntil { app.buttons["template-item-6"].exists }, "the new thing is not on the template")
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))
        tab(app, "care")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["care-line"]).hasPrefix("11 things") },
                      "picking made copies instead of using his things: '\(words(app.staticTexts["care-line"]))'")
    }

    /// His test H.3: a template's things group the ways a trip sorts — its own
    /// sections first, then A–Z, Into and the rest.
    func testATemplatesThingsGroupTheWaysATripSorts() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        app.buttons["template-row-1"].tap()                       // Hiking, which has a section
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(isOn(app.buttons["template-grouping-section"]), "a sectioned template does not start by its sections")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["template-group-0"]) == "LIGHTS" })
        tap(app, id: "template-grouping-name")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["template-group-0"]) == "A–Z" },
                      "A–Z did not regroup: '\(words(app.staticTexts["template-group-0"]))'")
        XCTAssertFalse(app.staticTexts["template-group-1"].exists, "A–Z is one group")
        tap(app, id: "template-grouping-into")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["template-group-0"]) == "CARRY-ON / HAND LUGGAGE" },
                      "Into does not group by bag: '\(words(app.staticTexts["template-group-0"]))'")
    }

    /// His ask (4 Oct 2026): "add a search function so that the user can find a
    /// specific item without the need to scroll." Typing narrows the template to the
    /// rows whose name holds it, says how many of all, says so when none, and the ✕
    /// brings every row back. A thing added while searching is seen, not hidden.
    func testATemplateFindsAThingWithoutScrolling() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        tap(app, id: "template-row-1")                            // Hiking: 4 things
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(app.buttons["template-item-3"].waitForExistence(timeout: 5), "expected 4 things")
        let field = app.textFields["template-find"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no field to find a thing")
        let count = app.staticTexts["template-find-count"]
        XCTAssertFalse(count.exists, "a count with nothing searched")

        type("map", into: field)                                  // small letters: the name is "Map"
        XCTAssertTrue(waitUntil { self.words(app.buttons["template-item-0"]).hasPrefix("Map") },
                      "the first row is not the Map: '\(words(app.buttons["template-item-0"]))'")
        XCTAssertTrue(waitUntil { !app.buttons["template-item-1"].exists }, "the search did not narrow the template")
        XCTAssertTrue(waitUntil { self.words(count) == "1 of 4" }, "the count says '\(words(count))'")
        XCTAssertFalse(app.staticTexts["template-find-none"].exists, "says nothing found while the Map shows")
        shot(app, "template-find")

        type("zz", into: field)                                   // "mapzz": nothing is called that
        XCTAssertTrue(app.staticTexts["template-find-none"].waitForExistence(timeout: 5), "no word when nothing is found")
        XCTAssertFalse(app.staticTexts["template-find-count"].exists, "'0 of 4' beside the line that already says nothing was found")
        XCTAssertFalse(app.buttons["template-item-0"].exists, "a row shows although nothing matches")
        shot(app, "template-find-none")

        tap(app, id: "template-find-clear")
        // 🪤 GitHub's iPhone has the on-screen keyboard, which leaves room for two rows:
        // the fourth was never built there (0.60, 5 Oct 2026). Put it away, as he would.
        hideKeyboard(app)
        XCTAssertTrue(waitUntil { app.buttons["template-item-3"].exists }, "the ✕ did not bring every row back")
        XCTAssertTrue(waitUntil { !count.exists }, "the count stayed with nothing searched")
        XCTAssertFalse(app.staticTexts["template-find-none"].exists, "nothing found stayed after the ✕")

        // Added while a search is on: the search goes, so the new thing is seen.
        type("map", into: field)
        XCTAssertTrue(waitUntil { !app.buttons["template-item-1"].exists })
        type("Gaiters", into: app.textFields["template-add-name"])
        tap(app, id: "template-add")
        XCTAssertTrue(waitUntil { !count.exists }, "the search stayed on after Add")
        // The keyboard leaves the list short, and a lazy list builds only what is near.
        hideKeyboard(app)
        XCTAssertTrue(scrollUntil(app, "template-item-4", near: "template-item-3"), "the new thing is hidden by the search")
    }

    // MARK: - Templates: the spec pass (5 Oct 2026)

    /// Things chosen from his own land on the template in the order he ticked them
    /// (a set put them on in no particular order), and Add pressed with nothing
    /// ticked says what is missing instead of doing nothing (his rule for a main button).
    func testThingsPickedLandInTheOrderTicked() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        tap(app, id: "template-row-1")                            // Hiking: 4 things
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        tap(app, id: "template-pick")
        XCTAssertTrue(appears(app, "pick-screen", timeout: 5))

        tap(app, id: "pick-add")
        let needs = app.staticTexts["pick-add-needs"]
        XCTAssertTrue(needs.waitForExistence(timeout: 5), "Add with nothing ticked said nothing")
        XCTAssertNotNil(find(app, "pick-screen"), "Add with nothing ticked closed the picker")
        shot(app, "pick-add-needs")

        // Three things he owns, ticked neither A–Z nor as listed.
        tap(app, id: "pick-group-name")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["pick-heading-0"]) == "A–Z" })
        func rowOf(_ name: String) -> XCUIElement? {
            (0..<14).map { app.buttons["pick-row-\($0)"] }.first { $0.exists && self.words($0).contains(name) }
        }
        let order = ["Towel", "Goggles", "Passport"]
        for name in order {
            guard let row = rowOf(name) else { return XCTFail("no \(name) to choose") }
            select(app, row)
        }
        XCTAssertTrue(waitUntil { !needs.exists }, "the line stayed once something was ticked")
        XCTAssertTrue(waitUntil { self.words(app.buttons["pick-add"]) == "Add 3" })
        tap(app, id: "pick-add")
        XCTAssertTrue(disappears(app, "pick-screen", timeout: 5), "Add did not close the picker")
        // After its four, in the order he ticked them.
        for (n, name) in order.enumerated() {
            let id = "template-item-\(4 + n)"
            XCTAssertTrue(scrollUntil(app, id, near: "template-item-\(3 + n)"), "\(id) never came")
            XCTAssertTrue(words(app.buttons[id]).contains(name), "\(id) should be \(name): '\(words(app.buttons[id]))'")
        }
    }

    /// Typing a thing already on the template does not put it on twice: it says so.
    func testTypingAThingAlreadyOnTheTemplateSaysSo() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        tap(app, id: "template-row-1")                            // Hiking: 4 things, the Map among them
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(app.buttons["template-item-3"].waitForExistence(timeout: 5), "expected 4 things")
        type("map", into: app.textFields["template-add-name"])
        tap(app, id: "template-add")
        let says = app.staticTexts["template-add-needs"]
        XCTAssertTrue(says.waitForExistence(timeout: 5), "a second Map was added without a word")
        XCTAssertTrue(words(says).contains("already"), "'\(words(says))'")
        hideKeyboard(app)
        shot(app, "template-already-on")
        XCTAssertFalse(scrollUntil(app, "template-item-4", near: "template-item-3", tries: 3), "the Map is on the template twice")
    }

    /// A thing's note is the THING's: put on a template, the row shows it, and the
    /// row's own Note stays blank — saying in grey that it is the thing's — so a
    /// later change to the note reaches the row (the spec pass: it was copied in).
    /// -uiTestingOnSite: the sample whose Passport has the note "Keep it dry".
    func testAThingsNoteIsNotCopiedOntoATemplate() {
        let app = launch("-uiTestingOnSite")
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        tap(app, id: "template-row-1")                            // Hiking: 4 things, no Passport
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        tap(app, id: "template-pick")
        XCTAssertTrue(appears(app, "pick-screen", timeout: 5))
        type("Passport", into: app.textFields["pick-search"])
        let passport = app.buttons["pick-row-0"]
        XCTAssertTrue(waitUntil { self.words(passport).contains("Passport") }, "no Passport to choose")
        select(app, passport)
        tap(app, id: "pick-add")
        XCTAssertTrue(disappears(app, "pick-screen", timeout: 5))
        XCTAssertTrue(scrollUntil(app, "template-item-4", near: "template-item-3"), "the Passport did not arrive")
        let row = app.buttons["template-item-4"]
        XCTAssertTrue(words(row).contains("Keep it dry"), "the row does not show the thing's note: '\(words(row))'")
        tapVisible(app, row)
        XCTAssertTrue(appears(app, "row-detail", timeout: 5))
        let note = app.textFields["row-note"]
        bringIntoView(app, note)
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertNotEqual(note.value as? String, "Keep it dry", "the thing's note was copied onto the row")
        XCTAssertEqual(note.placeholderValue, "Same as the thing: Keep it dry", "the blank note does not say whose it is")
        shot(app, "row-note-same-as-thing")
        tap(app, id: "row-cancel")
        XCTAssertTrue(disappears(app, "row-detail", timeout: 5))
    }

    /// A section typed in a row's editor is made when the row is SAVED — Cancel
    /// leaves the template as it was (the spec pass: it stayed behind, empty).
    func testASectionTypedInARowIsMadeOnlyOnSave() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        tap(app, id: "template-row-1")                            // Hiking: one section, Lights
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        func openFirstRow() {
            tap(app, id: "template-item-0")
            XCTAssertTrue(appears(app, "row-detail", timeout: 5))
        }
        func addSection(_ name: String) {
            let field = app.textFields["row-section-new"]
            bringIntoView(app, field)
            type(name, into: field)
            tap(app, id: "row-section-add")
        }
        openFirstRow()
        XCTAssertTrue(app.buttons["row-section-1"].waitForExistence(timeout: 5), "Lights is not offered")
        XCTAssertFalse(app.buttons["row-section-2"].exists)
        addSection("Rig")
        let rig = app.buttons["row-section-2"]
        XCTAssertTrue(rig.waitForExistence(timeout: 5), "the typed section is not offered")
        XCTAssertTrue(waitUntil { self.isOn(rig) }, "the typed section is not chosen")
        hideKeyboard(app)
        shot(app, "row-section-waiting")
        tap(app, id: "row-cancel")
        XCTAssertTrue(disappears(app, "row-detail", timeout: 5))

        openFirstRow()
        XCTAssertTrue(app.buttons["row-section-1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["row-section-2"].exists, "Cancel left the section on the template")
        addSection("Rig")
        tap(app, id: "row-save")
        XCTAssertTrue(disappears(app, "row-detail", timeout: 5))
        // Lights is empty now, so Rig is the first heading (a section with nothing in it is not shown).
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["template-group-0"]) == "RIG" },
                      "the row is not under its new section: '\(words(app.staticTexts["template-group-0"]))'")
        openFirstRow()
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["row-section-2"]) }, "the saved section is not the row's")
        tap(app, id: "row-cancel")
    }

    /// New asks for the activity area; the template page puts a wrong answer right
    /// (the spec pass, 5 Oct 2026). An always-packed template has no area to change.
    func testATemplateMovesToAnotherActivityArea() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        XCTAssertTrue(app.staticTexts["templates-area-GA"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["templates-area-OE"].exists)
        tap(app, id: "template-row-0")                            // Common base: always packed
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(app.buttons["template-delete"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["template-area"].exists, "an always-packed template offers an area")
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))

        tap(app, id: "template-row-1")                            // Hiking, in GA
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        let door = app.buttons["template-area"]
        XCTAssertTrue(door.waitForExistence(timeout: 5), "no way to change the activity area")
        XCTAssertEqual(door.value as? String, "GA")
        shot(app, "template-area-door")
        tap(app, id: "template-area")
        XCTAssertTrue(isOn(app.buttons["template-area-GA"]) || waitUntil { self.isOn(app.buttons["template-area-GA"]) },
                      "the area it lives in is not marked")
        shot(app, "template-area")
        tap(app, id: "template-area-OE")
        XCTAssertTrue(waitUntil { (app.buttons["template-area"].value as? String) == "OE" }, "the area did not change")
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))
        XCTAssertTrue(app.staticTexts["templates-area-OE"].waitForExistence(timeout: 5), "Hiking is not under OE")
        XCTAssertFalse(app.staticTexts["templates-area-GA"].exists, "Hiking is still under GA")
    }

    /// The Templates tab opens a template, Search and New one after another, each
    /// the moment the one before has closed — one sheet with a destination, not
    /// three (the trap met in Search; the spec pass, 5 Oct 2026). Its cards say when
    /// a template goes NEXT when its only trip is still ahead.
    func testEveryDoorOfTheTemplatesTabOpens() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        // The sample trip is a month ahead: Hiking has never been out, it goes next.
        XCTAssertTrue(waitUntil { self.words(app.buttons["template-row-1"]).contains("Next: in 30 days") },
                      "the card does not say when it goes next: '\(words(app.buttons["template-row-1"]))'")
        shot(app, "templates-tab")
        for _ in 0..<2 {
            tap(app, id: "template-row-1")
            XCTAssertTrue(appears(app, "template-detail", timeout: 5), "the template did not open")
            tap(app, id: "template-detail-done")
            XCTAssertTrue(disappears(app, "template-detail", timeout: 5))
            tap(app, id: "search-open")
            XCTAssertTrue(appears(app, "search-detail", timeout: 5), "Search did not open after a template")
            tap(app, id: "search-done")
            XCTAssertTrue(disappears(app, "search-detail", timeout: 5))
            tap(app, id: "templates-new")
            XCTAssertTrue(appears(app, "newlist-detail", timeout: 5), "New did not open after Search")
            tap(app, id: "newlist-cancel")
            XCTAssertTrue(disappears(app, "newlist-detail", timeout: 5))
        }
    }

    /// His decision on test I.7 (1 Oct 2026): a thing's new bag reaches a trip still
    /// ahead, on a line not ticked yet.
    func testAChangeToAThingReachesATripStillAhead() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        type("Headlamp", into: app.textFields["things-search"])
        tap(app, id: "thing-row-0")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        let bag = app.buttons["thing-bag-2"]
        XCTAssertTrue(bag.waitForExistence(timeout: 5))
        let newBag = words(bag)
        XCTAssertFalse(newBag.isEmpty || newBag.contains("Carry-on"), "pick a bag other than the one it has: '\(newBag)'")
        select(app, bag)
        tap(app, id: "thing-save")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))
        tap(app, id: "things-done")
        XCTAssertTrue(disappears(app, "things-detail", timeout: 5))

        tab(app, "events")
        app.buttons["trip-row-0"].tap()                          // the sample trip, 3–5 Oct: still ahead
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        // The Mac's short window builds only the lines on screen (a lazy list): bring
        // each one in before reading it (0.45's first CI run: "no Headlamp" on the Mac).
        var line: XCUIElement?
        for n in 0..<12 {
            guard scrollUntil(app, "trip-line-\(n)", near: n > 0 ? "trip-line-\(n - 1)" : nil) else { break }
            let l = app.buttons["trip-line-\(n)"]
            if words(l).contains("Headlamp") { line = l; break }
        }
        XCTAssertNotNil(line, "no Headlamp on the trip")
        XCTAssertTrue(waitUntil { self.words(line!).contains(newBag) },
                      "the thing's new bag did not reach the trip still ahead: '\(self.words(line!))'")
    }

    /// His H.1 (icons approved 2 Oct 2026): a template shows the icon its name
    /// suggests; a tap on the cover picks another, which stays; Letter shows the
    /// first letter; Suggested goes back.
    func testATemplatesIconIsSuggestedAndCanBeChosen() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        app.buttons["template-row-1"].tap()                        // Hiking
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        let cover = app.buttons["template-cover"]
        XCTAssertTrue(cover.waitForExistence(timeout: 5), "the template has no cover to tap")
        XCTAssertEqual(cover.value as? String, "hiking", "Hiking does not show its suggested icon")

        tap(app, id: "template-cover")
        XCTAssertTrue(appears(app, "icon-picker", timeout: 5), "the cover did not open the icons")
        XCTAssertTrue(app.buttons["icon-suggested"].isSelected, "Suggested is not marked as the current choice")
        tap(app, id: "icon-tent")
        XCTAssertTrue(disappears(app, "icon-picker", timeout: 5))
        XCTAssertTrue(waitUntil { (cover.value as? String) == "tent" }, "the tent was not taken: '\(cover.value as? String ?? "")'")

        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))
        app.buttons["template-row-1"].tap()
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(waitUntil { (app.buttons["template-cover"].value as? String) == "tent" }, "the icon was lost on the way out and back")

        tap(app, id: "template-cover")
        tap(app, id: "icon-letter")
        XCTAssertTrue(waitUntil { (app.buttons["template-cover"].value as? String) == "letter" }, "Letter did not take")
        tap(app, id: "template-cover")
        tap(app, id: "icon-suggested")
        XCTAssertTrue(waitUntil { (app.buttons["template-cover"].value as? String) == "hiking" }, "Suggested did not go back")
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
        // The button says where it goes (his test F.3): the trip's first template.
        XCTAssertTrue(words(app.buttons["review-miss-add"]).hasPrefix("Add it to "),
                      "Add does not say where it goes: '\(words(app.buttons["review-miss-add"]))'")
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
        tap(app, id: "thing-new")
        XCTAssertTrue(waitUntil { self.words(count) == "11 things" }, "the new thing is not counted: '\(words(count))'")
        let noList = app.buttons["things-nolist"]
        XCTAssertTrue(noList.waitForExistence(timeout: 5), "the new thing is on no list, and says so")
        tap(app, id: "things-nolist")
        XCTAssertTrue(waitUntil { self.words(count) == "1 thing" }, "the filter did not narrow: '\(words(count))'")

        // The new thing glides to the top and glows for a moment (0.56): on GitHub's
        // Mac the list was briefly not there to tap at all — wait for it, freshly.
        tap(app, id: "thing-row-0")
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
        // No owner = each has one (his words, 4 Oct 2026), not "Nobody's in particular".
        XCTAssertEqual(words(app.buttons["thing-owner-0"]), "Both have one")
        // Notes sit right under the name, before Kept at home (his ask, 4 Oct 2026).
        let name = app.textFields["thing-name"].frame, storage = app.textFields["thing-storage"].frame
        let notes = app.descendants(matching: .any).matching(identifier: "thing-notes").firstMatch.frame
        XCTAssertTrue(name.maxY <= notes.minY && notes.maxY <= storage.minY,
                      "Notes are not between Name and Kept at home: name \(name.maxY), notes \(notes.minY)–\(notes.maxY), kept at home \(storage.minY)")
        let offered = (1..<12).map { app.buttons["thing-owner-\($0)"] }.filter { $0.exists }.map { words($0) }
        XCTAssertEqual(offered, ["Kim", "Robin"], "each owner once, A–Z: \(offered)")
        // His asks (2026-09-26/27, and the field test of 3 Oct 2026, "the headings …
        // dominant, and the other buttons and pills are much smaller"): the headings are
        // the big type — a 22 pt line (26 tall), where 19 pt was 23 — and the pills under
        // them stay easy to press, 36 tall (their words 15, which no test can read).
        let heading = app.staticTexts["thing-category-title"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5), "no Kind of thing heading")
        let line = heading.frame.height, pill = app.buttons["thing-category-0"].frame.height
        XCTAssertTrue(line >= 25 && pill >= 36,
                      "headings must lead (a 22 pt line: got \(line) tall) over pills still easy to press (36 tall: got \(pill))")
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
        // Its section headings, in capitals since 0.40 (his "much larger headings", H.13).
        let headings = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'template-group-'"))
        XCTAssertTrue(headings.firstMatch.waitForExistence(timeout: 5), "the list has no headings")
        // words(): the iPhone reports a text's words as its label, the Mac as its value
        // (0.40's first CI run read "" on the Mac).
        XCTAssertTrue(headings.allElementsBoundByIndex.contains { self.words($0) == "LIGHTS" },
                      "the list does not read in its sections: \(headings.allElementsBoundByIndex.map { self.words($0) })")

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

        // Only on some trips (his ask, 2 Oct 2026): a Season picked here is kept; Context
        // is offered only on workout templates (Hiking is not one).
        let row0 = app.buttons["template-item-0"]
        XCTAssertTrue(row0.waitForExistence(timeout: 5))
        tapVisible(app, row0)
        XCTAssertTrue(appears(app, "row-detail", timeout: 5))
        let summer = app.buttons["row-seasons-0"]
        bringIntoView(app, summer)
        XCTAssertTrue(summer.exists, "no Season on the row")
        XCTAssertFalse(app.buttons["row-contexts-0"].exists, "Context is offered on a template that is not a workout")
        select(app, summer)
        tap(app, id: "row-save")
        XCTAssertTrue(disappears(app, "row-detail", timeout: 5))
        // …and the row says so (field test 4.4, 3 Oct 2026: "the row does not say summer").
        XCTAssertTrue(waitUntil { self.words(app.buttons["template-item-0"]).contains("Only on: Summer") },
                      "the row does not say it is only on summer trips: '\(words(app.buttons["template-item-0"]))'")
        tapVisible(app, app.buttons["template-item-0"])
        XCTAssertTrue(appears(app, "row-detail", timeout: 5))
        bringIntoView(app, app.buttons["row-seasons-0"])
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["row-seasons-0"]) }, "the Season was not kept")
        tap(app, id: "row-cancel")
        XCTAssertTrue(disappears(app, "row-detail", timeout: 5))

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

        XCTAssertFalse(app.staticTexts["device-import"].exists, "the sample never came from a file")

        tap(app, id: "backup-restore")
        XCTAssertTrue(appears(app, "restore-detail", timeout: 5), "the restore was not shown first")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["restore-file-items"]) == "2" },
                      "what the file holds: '\(words(app.staticTexts["restore-file-items"]))'")
        // The sheet fits the screen: on the iPhone its Mac-sized minimum was wider than
        // the screen, and both edges were cut off (the spec pass, 2026-10-05).
        let window = app.windows.firstMatch.frame
        if let sheet = find(app, "restore-detail") {
            XCTAssertTrue(sheet.frame.minX >= window.minX - 0.5 && sheet.frame.maxX <= window.maxX + 0.5,
                          "the restore sheet runs off the screen: \(sheet.frame) in \(window)")
        }
        for id in ["restore-cancel", "restore-confirm"] {
            let box = app.buttons[id].frame
            XCTAssertTrue(box.minX >= window.minX - 0.5 && box.maxX <= window.maxX + 0.5,
                          "\(id) runs off the screen: \(box) in \(window)")
        }
        shot(app, "restore-sheet")
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
        // …and it says what came in, and where the library now comes from.
        let status = app.staticTexts["backup-status"]
        XCTAssertTrue(waitUntil { self.words(status).hasPrefix("Restored from the file: 1 template, 2 things and 0 trips.") },
                      "the restore did not say what came in: '\(words(status))'")
        let came = app.staticTexts["device-import"]
        bringIntoView(app, came)
        XCTAssertTrue(waitUntil { self.words(came).hasPrefix("Brought in from a backup today") },
                      "Settings does not say the library came from a file: '\(words(came))'")
        shot(app, "restore-done")
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
        bringIntoView(app, app.buttons["rescue-row-0"])
        shot(app, "rescue-copy")
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
        // Each field sits right under ITS heading; the space goes between headings
        // (his screenshot, 2026-09-28).
        let nameHeading = app.staticTexts["thing-heading-name"], nameField = app.textFields["thing-name"]
        let keptHeading = app.staticTexts["thing-heading-kept"]
        XCTAssertTrue(nameHeading.waitForExistence(timeout: 5) && keptHeading.exists, "the editor's headings have no names")
        let under = nameField.frame.minY - nameHeading.frame.maxY
        let between = keptHeading.frame.minY - nameField.frame.maxY
        XCTAssertLessThan(under, between - 8, "the Name field is not nearer its own heading: \(under) under, \(between) to the next")
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

    /// More grab lists than Home can hold: eight places (4 × 2, his ask 2 Oct 2026)
    /// in his order; new lists fill free places, then wait with everything on
    /// them, and he says which one steps back.
    func testMoreGrabListsThanHomeHolds() {
        let app = launch()
        tab(app, "home")
        // Four in a row: the fourth beside the first, the fifth under it.
        XCTAssertTrue(app.buttons["grab-4"].waitForExistence(timeout: 5))
        XCTAssertLessThan(abs(app.buttons["grab-3"].frame.midY - app.buttons["grab-0"].frame.midY), 4, "the 4th is not on the first row")
        XCTAssertGreaterThan(app.buttons["grab-4"].frame.minY, app.buttons["grab-0"].frame.maxY, "the 5th is not on the second row")
        tap(app, id: "grab-lists")
        XCTAssertTrue(appears(app, "grablists-detail", timeout: 5))
        let homeHeading = app.staticTexts["grablists-home-heading"], waiting = app.staticTexts["grablists-waiting-heading"]
        XCTAssertTrue(waitUntil { self.words(homeHeading).contains("6 of 8") },
                      "Home does not start with six of eight: '\(words(homeHeading))'")

        // New lists take the free places — and the screen says so (it said "is
        // waiting", in red, wherever the list went, until 4 Oct 2026)…
        let made = app.staticTexts["grablists-made"]
        for (n, name) in ["Padel", "Golf"].enumerated() {
            type(name, into: app.textFields["grablists-new-name"])
            hideKeyboard(app)
            tap(app, id: "grablists-new")
            XCTAssertTrue(waitUntil(timeout: 10) { self.words(homeHeading).contains("\(7 + n) of 8") },
                          "\(name) did not take a free place: '\(words(homeHeading))'")
            XCTAssertTrue(waitUntil { self.words(made).contains("is on Home") }, "it does not say it went onto Home: '\(words(made))'")
        }
        // …and once Home is full, the next one waits rather than shoving one off.
        type("Kayak", into: app.textFields["grablists-new-name"])
        hideKeyboard(app)
        tap(app, id: "grablists-new")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(waiting).contains("1") }, "the new list is not waiting")
        XCTAssertTrue(waitUntil { self.words(homeHeading).contains("8 of 8") }, "it pushed something off Home by itself")
        XCTAssertTrue(waitUntil { self.words(made).contains("Home is full") }, "it does not say why it waits: '\(words(made))'")
        shot(app, "grablists-made")

        // Putting it on Home asks which of the eight steps back.
        tap(app, id: "grablists-on-0")
        XCTAssertTrue(appears(app, "swap-detail", timeout: 5), "it did not ask what steps back")
        let steppingBack = words(app.buttons["swap-0"])
        tap(app, id: "swap-0")
        XCTAssertTrue(disappears(app, "swap-detail", timeout: 5))
        // Kayak is on Home now, so "Kayak waits below" has gone (it stayed until 5 Oct 2026).
        XCTAssertTrue(waitUntil { !app.staticTexts["grablists-made"].exists },
                      "the line still says the list waits: '\(words(app.staticTexts["grablists-made"]))'")

        // Home still holds eight, and the one that stepped back is waiting, whole.
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(homeHeading).contains("8 of 8") })
        XCTAssertTrue(waitUntil { self.words(waiting).contains("1") })
        XCTAssertTrue(waitUntil { self.words(app.buttons["grablists-waiting-0"]).contains(String(steppingBack.prefix(4))) },
                      "the list that stepped back is not the one he chose: '\(words(app.buttons["grablists-waiting-0"]))'")
        XCTAssertFalse(words(app.buttons["grablists-waiting-0"]).contains("0 things"), "it lost its things on the way")

        // …and Home shows his eight, Kayak among them.
        tap(app, id: "grablists-done")
        XCTAssertTrue(disappears(app, "grablists-detail", timeout: 5))
        XCTAssertTrue(waitUntil(timeout: 10) {
            (0..<8).contains { self.words(app.buttons["grab-\($0)"]).contains("Kayak") }
        }, "Kayak is not on Home")
    }

    /// Make a grab list of his own in Grab Lists — with the sample's six on Home it
    /// takes the free place `grab-6` — open it there, and put these things on it
    /// in the editor. Leaves the editor open, NOT saved.
    private func makeOwnGrabList(_ app: XCUIApplication, _ name: String, things: [String]) {
        tap(app, id: "grab-lists")
        XCTAssertTrue(appears(app, "grablists-detail", timeout: 5))
        type(name, into: app.textFields["grablists-new-name"])
        hideKeyboard(app)
        tap(app, id: "grablists-new")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.staticTexts["grablists-made"]).contains("is on Home") },
                      "the new list did not go onto Home: '\(words(app.staticTexts["grablists-made"]))'")
        tap(app, id: "grablists-done")
        XCTAssertTrue(disappears(app, "grablists-detail", timeout: 5))
        tap(app, id: "grab-6")
        XCTAssertTrue(appears(app, "grab-detail", timeout: 10), "his new list did not open")
        tap(app, id: "grab-edit")
        for thing in things {
            type(thing, into: app.textFields["grab-add-name"])
            tap(app, id: "grab-add")
        }
        XCTAssertTrue(app.textFields["grab-rename-\(things.count - 1)"].waitForExistence(timeout: 5), "the things were not added")
    }

    /// A list he makes himself is filled in its editor — things, and one taken only
    /// "1 in 10" — and it stays filled. Until 4 Oct 2026 Save threw it all away:
    /// the list came back with nothing on it.
    func testHisOwnGrabListIsFilledAndStaysFilled() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        makeOwnGrabList(app, "Padel", things: ["Racket", "Balls", "Spare grip"])
        tapVisible(app, app.buttons["grab-sometimes-2"])
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["grab-sometimes-2"]) }, "the 1 in 10 did not take")
        tap(app, id: "grab-edit")                                    // Save

        let count = app.staticTexts["grab-count"]
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(count) == "0 of 2 in hand · 1 skipped" },
                      "three things, one only sometimes: '\(words(count))'")
        tap(app, id: "grab-done")
        XCTAssertTrue(disappears(app, "grab-detail", timeout: 5))

        tap(app, id: "grab-6")
        XCTAssertTrue(appears(app, "grab-detail", timeout: 10))
        XCTAssertTrue(waitUntil { self.words(app.buttons["grab-item-0"]).contains("Racket") },
                      "his things were lost on the way out and back: '\(words(app.buttons["grab-item-0"]))'")
        XCTAssertTrue(waitUntil { self.words(app.buttons["grab-item-2"]).contains("only sometimes") },
                      "the 1 in 10 was lost: '\(words(app.buttons["grab-item-2"]))'")
        XCTAssertEqual(words(count), "0 of 2 in hand · 1 skipped")
        shot(app, "grab-own-filled")
    }

    /// Ticks on a list of his own survive closing it and opening it again, as on
    /// the original six (they were all gone on reopening until 4 Oct 2026).
    func testTicksOnHisOwnGrabListSurviveClosingIt() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        makeOwnGrabList(app, "Golf", things: ["Clubs", "Balls"])
        tap(app, id: "grab-edit")                                    // Save
        let count = app.staticTexts["grab-count"]
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(count) == "0 of 2 in hand" }, "not filled: '\(words(count))'")

        tap(app, id: "grab-item-0")
        XCTAssertTrue(waitUntil { self.words(count) == "1 of 2 in hand" }, "the tick did not count: '\(words(count))'")
        tap(app, id: "grab-done")
        XCTAssertTrue(disappears(app, "grab-detail", timeout: 5))

        tap(app, id: "grab-6")
        XCTAssertTrue(appears(app, "grab-detail", timeout: 10))
        XCTAssertTrue(waitUntil { self.words(count) == "1 of 2 in hand" },
                      "the tick was lost on the way out and back: '\(words(count))'")
        XCTAssertTrue(isOn(app.buttons["grab-item-0"]), "the thing he ticked is not ticked")
    }

    /// Off Home keeps a list off Home: its tile goes, Home shows one fewer, and it
    /// stays so when the screens are opened again — until he puts it back. Until 4
    /// Oct 2026 the free place pulled it straight back, and the button seemed to
    /// do nothing.
    func testAGrabListTakenOffHomeStaysOff() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        XCTAssertTrue(app.buttons["grab-5"].waitForExistence(timeout: 5), "the sample's six are not on Home")
        let first = words(app.buttons["grab-0"])
        let tiles = { (0..<8).map { self.words(app.buttons["grab-\($0)"]) }.filter { !$0.isEmpty } }

        tap(app, id: "grab-lists")
        XCTAssertTrue(appears(app, "grablists-detail", timeout: 5))
        let homeHeading = app.staticTexts["grablists-home-heading"], waiting = app.staticTexts["grablists-waiting-heading"]
        XCTAssertTrue(waitUntil { self.words(homeHeading).contains("6 of 8") })
        tap(app, id: "grablists-off-0")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(homeHeading).contains("5 of 8") },
                      "the list came straight back onto Home: '\(words(homeHeading))'")
        XCTAssertTrue(waitUntil { self.words(waiting).contains("1") }, "it is not waiting: '\(words(waiting))'")
        shot(app, "grablists-off")
        tap(app, id: "grablists-done")
        XCTAssertTrue(disappears(app, "grablists-detail", timeout: 5))

        XCTAssertTrue(waitUntil { !app.buttons["grab-5"].exists }, "Home still shows six tiles")
        XCTAssertFalse(tiles().contains(first), "\(first) is still on Home: \(tiles())")
        shot(app, "home-off")

        // Opened again, it is still off.
        tap(app, id: "grab-lists")
        XCTAssertTrue(appears(app, "grablists-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(homeHeading).contains("5 of 8") }, "it came back: '\(words(homeHeading))'")
        // A waiting list opens on a tap, ready to tick or fill — and stays waiting (5 Oct
        // 2026: the whole row put it on Home, and nothing here could open it).
        shot(app, "grablists-waiting-row")
        tap(app, id: "grablists-waiting-0")
        XCTAssertTrue(appears(app, "grab-detail", timeout: 10), "the waiting list did not open")
        tap(app, id: "grab-done")
        XCTAssertTrue(disappears(app, "grab-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(homeHeading).contains("5 of 8") }, "opening it put it on Home: '\(words(homeHeading))'")
        // …until he puts it back: there is room, so it goes straight on, at the end.
        tap(app, id: "grablists-on-0")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(homeHeading).contains("6 of 8") },
                      "it could not be put back: '\(words(homeHeading))'")
        XCTAssertNil(find(app, "swap-detail"), "it asked what steps back while Home had room")
        tap(app, id: "grablists-done")
        XCTAssertTrue(disappears(app, "grablists-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.buttons["grab-5"]) == first }, "it is not back on Home, last: \(tiles())")
    }

    /// A list he made himself can be deleted — in its editor, last, quietly, and
    /// only after he says so. The original six cannot be (they can go off Home).
    func testHisOwnGrabListIsDeletedAfterAsking() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        tap(app, id: "grab-0")
        XCTAssertTrue(appears(app, "grab-detail", timeout: 10))
        tap(app, id: "grab-edit")
        XCTAssertTrue(app.textFields["grab-rename-0"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["grab-delete"].waitForExistence(timeout: 2), "one of the original six can be deleted")
        tap(app, id: "grab-edit")                                    // Save
        tap(app, id: "grab-done")
        XCTAssertTrue(disappears(app, "grab-detail", timeout: 5))

        makeOwnGrabList(app, "Kayak", things: ["Paddle"])
        tap(app, id: "grab-delete")
        XCTAssertTrue(app.staticTexts["grab-delete-question"].waitForExistence(timeout: 5), "it did not ask first")
        shot(app, "grab-delete-ask")
        tap(app, id: "grab-delete-no")
        XCTAssertTrue(waitUntil { !app.staticTexts["grab-delete-question"].exists }, "Keep it did not close the question")
        XCTAssertNotNil(find(app, "grab-detail"), "Keep it closed the list")

        tap(app, id: "grab-delete")
        tap(app, id: "grab-delete-yes")
        XCTAssertTrue(disappears(app, "grab-detail", timeout: 10), "the deleted list stayed open")
        XCTAssertTrue(waitUntil(timeout: 10) { !app.buttons["grab-6"].exists }, "the deleted list is still on Home")
        tap(app, id: "grab-lists")
        XCTAssertTrue(appears(app, "grablists-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["grablists-home-heading"]).contains("6 of 8") &&
                                  self.words(app.staticTexts["grablists-waiting-heading"]).contains("0") },
                      "it is still in Grab Lists")
    }

    // MARK: - Grab lists, Home and Search: the fixes of 5 Oct 2026

    /// Save in a grab list's editor keeps what is already in his hand (every Save
    /// emptied the list, even with nothing changed), and a thing just marked "1 in 10"
    /// is set aside at once. Start over goes back to how the list opens — with that
    /// thing set aside again (it came back into the count until the list was reopened).
    func testSaveKeepsTodaysTicksAndStartOverSetsAsideWhatIsTakenOnlySometimes() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        tap(app, id: "grab-0")
        XCTAssertTrue(appears(app, "grab-detail", timeout: 10))
        let count = app.staticTexts["grab-count"]
        XCTAssertTrue(waitUntil { self.words(count) == "0 of 7 in hand" }, "'\(words(count))'")
        tap(app, id: "grab-item-0")
        XCTAssertTrue(waitUntil { self.words(count) == "1 of 7 in hand" }, "the tick did not count: '\(words(count))'")

        tap(app, id: "grab-edit")
        XCTAssertTrue(app.buttons["grab-sometimes-1"].waitForExistence(timeout: 5))
        tapVisible(app, app.buttons["grab-sometimes-1"])
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["grab-sometimes-1"]) }, "the mark did not take")
        tap(app, id: "grab-edit")                                    // Save
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(count) == "1 of 6 in hand · 1 skipped" },
                      "Save lost the tick, or did not set the marked thing aside: '\(words(count))'")
        XCTAssertTrue(isOn(app.buttons["grab-item-0"]), "the thing in his hand is no longer ticked")
        shot(app, "grab-saved-kept-ticks")

        tap(app, id: "grab-reset")                                   // Start over
        XCTAssertTrue(waitUntil { self.words(count) == "0 of 6 in hand · 1 skipped" },
                      "Start over brought the 1-in-10 thing back into the count: '\(words(count))'")
        XCTAssertTrue(waitUntil { self.words(app.buttons["grab-item-1"]).contains("only sometimes") },
                      "'\(words(app.buttons["grab-item-1"]))'")
        XCTAssertTrue(waitUntil { !app.buttons["grab-reset"].exists }, "Start over is offered on a list just as it opens")
    }

    /// A list just made has nothing on it, and every screen says so plainly: the list
    /// itself, Ready to go (it said "everything is skipped"), Share (it said "too big —
    /// share it as a file", and there is no file), and Save with nothing on it (it
    /// closed the editor and said nothing). Make refuses a name a list already has.
    func testAnEmptyGrabListSaysHowToFillIt() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        tap(app, id: "grab-lists")
        XCTAssertTrue(appears(app, "grablists-detail", timeout: 5))
        let homeHeading = app.staticTexts["grablists-home-heading"]
        XCTAssertTrue(waitUntil { self.words(homeHeading).contains("6 of 8") })
        let field = app.textFields["grablists-new-name"]
        type("swim", into: field)
        hideKeyboard(app)
        tap(app, id: "grablists-new")
        XCTAssertTrue(app.staticTexts["grablists-new-needs"].waitForExistence(timeout: 5), "a second Swim was made, silently")
        XCTAssertTrue(words(homeHeading).contains("6 of 8"), "a list was made under a name already in use")
        shot(app, "grablists-name-taken")

        replace("Kite", in: field)
        hideKeyboard(app)
        tap(app, id: "grablists-new")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(homeHeading).contains("7 of 8") }, "Kite was not made")
        tap(app, id: "grablists-done")
        XCTAssertTrue(disappears(app, "grablists-detail", timeout: 5))
        tap(app, id: "grab-6")
        XCTAssertTrue(appears(app, "grab-detail", timeout: 10))
        XCTAssertTrue(app.staticTexts["grab-empty"].waitForExistence(timeout: 5), "an empty list does not say how to fill it")
        shot(app, "grab-empty")

        tap(app, id: "grab-ready")
        let message = app.staticTexts["grab-message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertFalse(words(message).contains("skipped"), "an empty list says everything is skipped: '\(words(message))'")
        shot(app, "grab-empty-notyet")
        tap(app, id: "grab-message-ok")
        XCTAssertTrue(waitUntil { !app.staticTexts["grab-message"].exists })

        tap(app, id: "grab-share")
        XCTAssertTrue(appears(app, "share-screen", timeout: 10))
        XCTAssertTrue(app.staticTexts["share-empty"].waitForExistence(timeout: 5), "it does not say there is nothing to share")
        XCTAssertFalse(app.staticTexts["share-toolong"].exists, "it says the empty list is too big")
        shot(app, "share-empty")
        tap(app, id: "share-done")
        XCTAssertTrue(disappears(app, "share-screen", timeout: 5))

        tap(app, id: "grab-edit")
        XCTAssertTrue(app.textFields["grab-add-name"].waitForExistence(timeout: 5))
        tap(app, id: "grab-edit")                                    // Save, nothing on it
        XCTAssertTrue(app.staticTexts["grab-save-needs"].waitForExistence(timeout: 5), "Save with nothing on the list said nothing")
        XCTAssertTrue(app.textFields["grab-add-name"].exists, "the editor closed on a list that was not saved")
        shot(app, "grab-save-needs")
        type("Board", into: app.textFields["grab-add-name"])
        tap(app, id: "grab-add")
        XCTAssertTrue(waitUntil { !app.staticTexts["grab-save-needs"].exists }, "the line stayed once a thing was added")
        tap(app, id: "grab-edit")                                    // Save
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.staticTexts["grab-count"]) == "0 of 1 in hand" },
                      "'\(words(app.staticTexts["grab-count"]))'")
        XCTAssertFalse(app.staticTexts["grab-empty"].exists)
    }

    /// Every grab list taken off Home: Home does not show a heading over nothing — it
    /// says where they are, and that line opens Grab Lists.
    func testHomeWithEveryGrabListOffSaysWhereTheyAre() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        tap(app, id: "grab-lists")
        XCTAssertTrue(appears(app, "grablists-detail", timeout: 5))
        let homeHeading = app.staticTexts["grablists-home-heading"]
        for left in stride(from: 5, through: 0, by: -1) {
            tap(app, id: "grablists-off-0")
            XCTAssertTrue(waitUntil(timeout: 10) { self.words(homeHeading).contains("\(left) of 8") }, "'\(words(homeHeading))'")
        }
        tap(app, id: "grablists-done")
        XCTAssertTrue(disappears(app, "grablists-detail", timeout: 5))
        XCTAssertTrue(waitUntil { !app.buttons["grab-0"].exists }, "a list is still on Home")
        XCTAssertTrue(app.buttons["home-grab-none"].waitForExistence(timeout: 5), "Home shows nothing under Grab and go")
        shot(app, "home-no-grab-lists")
        tap(app, id: "home-grab-none")
        XCTAssertTrue(appears(app, "grablists-detail", timeout: 5), "the line does not lead to Grab Lists")
    }

    /// A to-do found by Search opens the To do tab, whichever tab Search was opened
    /// from (it only closed Search until 5 Oct 2026).
    func testASearchedToDoOpensTheToDoTab() {
        let app = launch()
        tab(app, "actions")
        XCTAssertTrue(appears(app, "screen-actions"))
        type("Book the ferry", into: app.textFields["action-add-text"])
        tap(app, id: "action-add")
        XCTAssertTrue(app.buttons["action-0"].waitForExistence(timeout: 5), "the to-do is not listed")
        tab(app, "home")
        tap(app, id: "search-open")
        XCTAssertTrue(appears(app, "search-detail", timeout: 5))
        type("ferry", into: app.textFields["search-field"])
        XCTAssertTrue(app.buttons["search-todos-0"].waitForExistence(timeout: 5), "the to-do was not found")
        tapVisible(app, app.buttons["search-todos-0"])
        XCTAssertTrue(disappears(app, "search-detail", timeout: 5), "Search stayed open")
        XCTAssertTrue(appears(app, "screen-actions", timeout: 5), "the to-do did not open the To do tab")
        XCTAssertTrue(app.buttons["action-0"].waitForExistence(timeout: 5))
    }

    /// Home's Templates number is the number Your templates shows — not one more for
    /// the hidden bags list (the checks sample has a bag, so it has that list).
    func testHomeCountsTheTemplatesYourTemplatesShows() {
        let app = launch("-uiTestingChecks")
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        let tile = app.staticTexts["count-templates"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        let onHome = words(tile)
        tab(app, "templates")
        let summary = app.staticTexts["templates-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        let shown = String(words(summary).prefix { $0.isNumber })
        XCTAssertFalse(shown.isEmpty, "'\(words(summary))'")
        XCTAssertEqual(onHome, shown, "Home counts \(onHome) templates, Your templates shows \(shown)")
        tab(app, "home")
        bringIntoView(app, app.staticTexts["count-templates"])
        shot(app, "home-device-counts")
    }

    /// Remind me to pack, switched on here but blocked in the device's Settings: the
    /// card says so — every time it is shown — and names no reminder that will never
    /// come. (`-pretendRemindersBlocked`: on earlier, then blocked.)
    func testRemindersSayWhenTheDeviceBlocksThem() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingChecks", "-pretendRemindersBlocked"]
        app.launch()
        tab(app, "settings")
        XCTAssertTrue(appears(app, "screen-settings"))
        XCTAssertTrue(waitUntil { self.isSwitchOn(app, "settings-reminders") }, "the switch is not on")
        XCTAssertTrue(app.staticTexts["settings-reminders-refused"].waitForExistence(timeout: 5),
                      "blocked by the device, and the card does not say so")
        XCTAssertFalse(app.staticTexts["settings-reminders-next"].exists, "it names a reminder that will never come")
        shot(app, "settings-reminders-blocked")
        tab(app, "home")
        tab(app, "settings")
        XCTAssertTrue(app.staticTexts["settings-reminders-refused"].waitForExistence(timeout: 5),
                      "the card forgot that the device blocks reminders")
    }

    #if os(iOS)
    /// A Shortcut (the Action button) or a tapped packing reminder arrives while one of
    /// Home's windows is up: that window makes way, and what was asked for opens.
    /// (`-openGrabOnReturn`, `-openNextTripOnReturn`: what reaches the app while it is
    /// in the background, played when it comes back to the front.)
    func testAShortcutOrReminderOpensItsPlaceWhileAnotherWindowIsUp() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-openGrabOnReturn", "Bike"]
        app.launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        tap(app, id: "grab-lists")
        XCTAssertTrue(appears(app, "grablists-detail", timeout: 5))
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(appears(app, "grab-detail", timeout: 15), "the Shortcut's grab list did not open over Grab Lists")
        XCTAssertNil(find(app, "grablists-detail"), "Grab Lists is still up")
        app.terminate()

        let trip = XCUIApplication()
        trip.launchArguments += ["-uiTestingChecks", "-openNextTripOnReturn"]
        trip.launch()
        XCTAssertTrue(appears(trip, "screen-home", timeout: 20))
        tap(trip, id: "search-open")
        XCTAssertTrue(appears(trip, "search-detail", timeout: 5))
        XCUIDevice.shared.press(.home)
        sleep(2)
        trip.activate()
        XCTAssertTrue(appears(trip, "trip-detail", timeout: 15), "the reminder's trip did not open over Search")
        XCTAssertTrue(waitUntil { self.words(trip.staticTexts["trip-name"]) == "Sunny weeks" },
                      "it opened another trip: '\(words(trip.staticTexts["trip-name"]))'")
    }

    /// A list of his own that goes while it is open — deleted on his other device, or
    /// lost to a later write from there — closes, instead of turning into Indoor swim
    /// and taking his next tick onto the swim list.
    func testAGrabListGoneWhileOpenClosesInsteadOfBecomingAnother() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-dropOwnGrabListsOnReturn"]
        app.launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        makeOwnGrabList(app, "Kayak", things: ["Paddle", "Spray deck"])
        tap(app, id: "grab-edit")                                    // Save
        let count = app.staticTexts["grab-count"]
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(count) == "0 of 2 in hand" }, "'\(words(count))'")
        tap(app, id: "grab-item-0")
        XCTAssertTrue(waitUntil { self.words(count) == "1 of 2 in hand" }, "'\(words(count))'")
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(disappears(app, "grab-detail", timeout: 10), "the list stayed open after it was gone")
        XCTAssertTrue(waitUntil { !app.buttons["grab-6"].exists }, "the list is still on Home")
        tap(app, id: "grab-0")
        XCTAssertTrue(appears(app, "grab-detail", timeout: 10))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["grab-count"]) == "0 of 7 in hand" },
                      "a tick reached the swim list: '\(words(app.staticTexts["grab-count"]))'")
    }
    #endif

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

        // The heaviest things are drawn from the things that have a weight — under a
        // heading in capitals (his words, 2026-09-28: "The heavy end" was misleading).
        XCTAssertTrue(app.buttons["kit-heavy-0"].waitForExistence(timeout: 5), "nothing in the heaviest things")
        XCTAssertEqual(words(app.staticTexts["kit-heavy-heading"]), "HEAVIEST THINGS")
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
        // …and since 0.30 the sample has reviews behind it: the Map and the Hiking
        // boots went along and were never used — two, not the Headlamp, which never went.
        XCTAssertTrue((0..<6).contains { self.words(app.staticTexts["kit-tip-\($0)"]).hasPrefix("2 things went along and came home unused") },
                      "the reviews' unused things are not counted right: \((0..<6).map { self.words(app.staticTexts["kit-tip-\($0)"]) })")
    }

    /// Every column of the table filters (his ask, 4 Oct 2026: "all existing columns
    /// to be able to be used as filter criteria"). Ticks in one column = any of
    /// them; two columns must both hold; a pill above the grid says what is on and
    /// its ✕ takes it off. (The sample: Kim owns five things; on Hiking, only the
    /// Headlamp sits in the section Lights.)
    func testTheTableFiltersByAnyColumn() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5), "no table")
        XCTAssertEqual(words(app.staticTexts["table-count"]), "10")
        tap(app, id: "table-filter")
        XCTAssertTrue(appears(app, "filter-sheet", timeout: 5), "no Filter")
        tap(app, id: "filter-col-ownedBy")
        tap(app, id: "filter-ownedBy-0")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["filter-count"]) == "5 of 10" },
                      "Owner: Kim should leave five: '\(words(app.staticTexts["filter-count"]))'")
        tap(app, id: "filter-col-list-1")
        tap(app, id: "filter-list-1-1")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["filter-count"]) == "1 of 10" },
                      "Kim's and in Hiking's section Lights should leave one: '\(words(app.staticTexts["filter-count"]))'")
        shot(app, "filter-sheet")
        tap(app, id: "filter-done")
        XCTAssertTrue(disappears(app, "filter-sheet", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["table-count"]) == "1" },
                      "the table did not take the filters: '\(words(app.staticTexts["table-count"]))'")
        XCTAssertEqual(words(app.staticTexts["table-0-name"]), "Headlamp")
        XCTAssertEqual(words(app.buttons["table-pill-ownedBy"]), "Owner: Kim")
        shot(app, "filter-pills")
        tap(app, id: "table-pill-ownedBy")
        XCTAssertTrue(waitUntil { !app.buttons["table-pill-ownedBy"].exists }, "the pill's ✕ kept the filter")
        XCTAssertTrue(app.buttons["table-pill-list-1"].exists, "the other filter went too")
        tap(app, id: "table-filters-clear")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["table-count"]) == "10" }, "Clear left a filter on")
    }

    /// Sort levels (his ask, 4 Oct 2026: "sorting on travel as a top sort criterion
    /// and then sorting on section as an under criterion"). Hiking first, then
    /// Hiking's sections turned round (▼): the ones on Hiking with no section come
    /// before the Headlamp in Lights — which A–Z alone would put first — and
    /// everything not on Hiking after.
    func testTheTableSortsByLevels() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5), "no table")
        tap(app, id: "table-sort")
        XCTAssertTrue(appears(app, "sort-sheet", timeout: 5), "no Sort")
        tap(app, id: "sort-level-0")
        tap(app, id: "sort-key-list-1")
        tap(app, id: "sort-add")
        tap(app, id: "sort-key-section-1")
        XCTAssertTrue(waitUntil { (app.buttons["sort-level-1"].value as? String) == "Hiking · section" },
                      "the second level is not Hiking's sections: '\(app.buttons["sort-level-1"].value as? String ?? "")'")
        tap(app, id: "sort-dir-1")
        XCTAssertTrue(waitUntil { (app.buttons["sort-dir-1"].value as? String) == "down" }, "the second level did not turn round")
        shot(app, "sort-sheet")
        tap(app, id: "sort-done")
        XCTAssertTrue(disappears(app, "sort-sheet", timeout: 5))
        let order = { (0..<5).map { self.words(app.staticTexts["table-\($0)-name"]) } }
        XCTAssertTrue(waitUntil { order() == ["Hiking boots", "Map", "Rain jacket", "Headlamp", "Goggles"] },
                      "Hiking, then its sections ▼, should put the Headlamp (Lights) after the rest on Hiking: \(order())")
        XCTAssertTrue(words(app.staticTexts["table-sorted-by"]).contains("then Hiking · section ▼"),
                      "the order is not said in words: '\(words(app.staticTexts["table-sorted-by"]))'")
        shot(app, "sort-levels")
        // Taken away again, the second level stops counting.
        tap(app, id: "table-sort")
        tap(app, id: "sort-remove-1")
        tap(app, id: "sort-done")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["table-0-name"]) == "Headlamp" && self.words(app.staticTexts["table-1-name"]) == "Hiking boots" },
                      "with the second level gone, Hiking alone sorts A–Z: \(order())")
        XCTAssertFalse(app.staticTexts["table-sorted-by"].exists, "one level left, still said in words")
    }

    /// A row opens its thing (his ask, 4 Oct 2026), and closing it comes back to
    /// the same spot in the table: the row is where it was, and the change is in it.
    func testARowOpensItsThingAndComesBackToTheSameSpot() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5), "no table")
        let name = app.staticTexts["table-6-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let before = name.frame
        let thing = words(name)
        tap(app, id: "table-6-open")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5), "the arrow did not open \(thing)")
        let colour = app.textFields["thing-colour"]
        bringIntoView(app, colour)
        replace("Teal", in: colour)
        tap(app, id: "thing-save")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))
        XCTAssertTrue(app.staticTexts["table-detail"].exists || find(app, "table-detail") != nil, "the table closed with the thing")
        XCTAssertEqual(words(app.staticTexts["table-6-name"]), thing, "another thing sits in that row now")
        // The same spot: the row is where it was, give or take the few points a sheet's
        // closing can leave (3.7 on GitHub's iPhone 17, 5 Oct 2026) — never a row away.
        let after = app.staticTexts["table-6-name"].frame
        XCTAssertTrue(abs(after.minY - before.minY) < 10 && abs(after.minX - before.minX) < 1,
                      "the table moved while the thing was open: \(before) → \(after)")
        tap(app, id: "table-columns")
        tap(app, id: "columns-color-show")
        tap(app, id: "columns-done")
        XCTAssertTrue(waitUntil { (app.textFields["table-6-color"].value as? String) == "Teal" },
                      "the colour changed on the thing is not in its row: '\(app.textFields["table-6-color"].value as? String ?? "")'")
        tap(app, id: "table-done")
        XCTAssertTrue(disappears(app, "table-detail", timeout: 5), "Done did not close the table")
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
        // The arrows are a fingertip each (his ask, 4 Oct 2026: "rather difficult to
        // hit") — and so is Hide.
        for id in ["columns-storage-up", "columns-storage-down", "columns-storage-hide"] {
            let f = app.buttons[id].frame
            XCTAssertTrue(f.width >= 44 && f.height >= 44, "\(id) is only \(f.width) × \(f.height)")
        }
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
        tap(app, id: "care-bags")
        XCTAssertTrue(appears(app, "yourbags-detail", timeout: 5), "no Containers screen")
        // His ask (2026-09-26): the column names stay visible while the bags scroll —
        // so they must sit OUTSIDE every scrolling list, where nothing can carry them off.
        let columns = app.descendants(matching: .any)["yourbags-columns"]
        XCTAssertTrue(columns.waitForExistence(timeout: 5), "no column names over the bags")
        XCTAssertTrue(words(columns).contains("MAX KG"), "the column names are not there: '\(words(columns))'")
        for list in app.scrollViews.allElementsBoundByIndex where list.exists {
            XCTAssertFalse(list.descendants(matching: .any)["yourbags-columns"].exists,
                           "the column names scroll away with the bags")
        }
        type("Carry-on / hand luggage", into: app.textFields["bag-new-name"])
        tap(app, id: "bag-new")
        XCTAssertTrue(app.textFields["bag-0-maxkg"].waitForExistence(timeout: 5), "the bag was not made")
        type("1", into: app.textFields["bag-0-maxkg"])
        app.textFields["bag-0-maxkg"].typeText("\n")
        // 🪤 A number typed and LEFT — no Return — must stay too: his max weights of
        // 2026-09-26 were lost exactly so.
        type("33", into: app.textFields["bag-0-litres"])
        tap(app, id: "yourbags-done")
        XCTAssertTrue(disappears(app, "yourbags-detail", timeout: 5))
        tap(app, id: "care-bags")
        XCTAssertTrue(appears(app, "yourbags-detail", timeout: 5))
        XCTAssertTrue(waitUntil { (app.textFields["bag-0-litres"].value as? String) == "33" },
                      "litres typed without Return were lost: '\(app.textFields["bag-0-litres"].value as? String ?? "")'")
        tap(app, id: "yourbags-done")
        XCTAssertTrue(disappears(app, "yourbags-detail", timeout: 5))

        // The trip must see it.
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(app.staticTexts["bags-over"].waitForExistence(timeout: 10),
                      "the limit he set did not reach the trip")
        // His ask (2026-09-26): a small ⓘ that explains the colours.
        tap(app, id: "bags-key-open")
        XCTAssertTrue(appears(app, "bags-key", timeout: 5), "the ⓘ did not explain the colours")
        tap(app, id: "bags-key-open")
        XCTAssertTrue(waitUntil { self.find(app, "bags-key") == nil }, "the colour key did not fold away again")
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
                      "the summary still says the same: '\(before)'")

        // And not one THING went with it.
        tab(app, "care")
        XCTAssertTrue(words(app.staticTexts["care-line"]).hasPrefix("10 things"),
                      "a deleted list must not take his things: '\(words(app.staticTexts["care-line"]))'")
    }

    /// A list he makes himself lands in the activity area he chose, opens straight away, and
    /// a name he already has is refused rather than quietly duplicated.
    func testHeMakesAListOfHisOwn() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        let before = words(app.staticTexts["templates-summary"])

        // One word for one thing (his call, 2026-09-27): Templates, everywhere.
        XCTAssertEqual(words(app.staticTexts["templates-heading"]), "Your templates")
        tap(app, id: "templates-new")
        XCTAssertTrue(appears(app, "newlist-detail", timeout: 5), "the sheet did not open")
        XCTAssertEqual(words(app.staticTexts["newlist-title"]), "A new template")

        // Never grey (his rule): pressed without a name, it stays and says what is missing.
        XCTAssertTrue(app.buttons["newlist-make"].isEnabled, "Make the template is greyed out")
        tap(app, id: "newlist-make")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["newlist-needs"]).contains("name") },
                      "pressed without a name, it did not say so")
        XCTAssertNotNil(find(app, "newlist-detail"), "a template without a name was made")

        // A name he already has is refused, and nothing can be made from it. (Typing
        // takes the old line away, as under every other field — the spec pass.)
        type("Hiking", into: app.textFields["newlist-name"])
        XCTAssertTrue(waitUntil { !app.staticTexts["newlist-needs"].exists }, "the line stayed once a name was typed")
        // 🪤 Asked for by EXISTENCE, not by `appears`: a warning is a plain Text, and
        // XCUITest does not call a Text hittable, so the on-screen helper says it is
        // missing while it is perfectly visible.
        XCTAssertTrue(app.staticTexts["newlist-taken"].waitForExistence(timeout: 5),
                      "a name he already has was accepted")

        tap(app, id: "newlist-make")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["newlist-needs"]).contains("do not have") },
                      "pressed on a name he has, it did not say so")
        XCTAssertNotNil(find(app, "newlist-detail"), "a second Hiking was made")
        replace("Mushroom picking", in: app.textFields["newlist-name"])
        XCTAssertTrue(waitUntil(timeout: 5) { !app.staticTexts["newlist-taken"].exists },
                      "a free name is still called taken")
        tap(app, id: "newlist-area-GA")
        tap(app, id: "newlist-make")

        // It opens straight away — a list he cannot see inside is not made yet.
        XCTAssertTrue(appears(app, "template-detail", timeout: 5), "the new list did not open")
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))

        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.staticTexts["templates-summary"]) != before },
                      "the summary did not gain a list: still '\(before)'")
        // The area he chose, tested by the area he did NOT choose: nothing in the
        // sample is without an area, so a list that ignored his choice would make an
        // "Other templates" area appear. (Asserting the GA area exists proved nothing
        // — it was already there, and the test passed with the choice thrown away.)
        XCTAssertTrue(app.staticTexts["templates-area-GA"].exists, "the activity area he chose is gone")
        XCTAssertFalse(app.staticTexts["templates-area-other"].exists,
                       "the list landed in no activity area, so his choice was ignored")
    }

    /// "Activity area", not "shelf" — the word from the field test (Oct 2026): where a
    /// new template is given its group, the question and the choice of none both say it.
    func testANewTemplateAsksForItsActivityArea() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        tap(app, id: "templates-new")
        XCTAssertTrue(appears(app, "newlist-detail", timeout: 5), "the sheet did not open")
        let asks = app.staticTexts["newlist-area-title"]
        XCTAssertTrue(asks.waitForExistence(timeout: 5), "no question about the activity area")
        XCTAssertEqual(words(asks).lowercased(), "in which activity area should it live?")
        XCTAssertEqual(words(app.buttons["newlist-area-none"]), "No activity area")
        shot(app, "new-template-area")
        tap(app, id: "newlist-cancel")
        XCTAssertTrue(disappears(app, "newlist-detail", timeout: 5))
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
        XCTAssertEqual(cellSays(app, "table-1-listQty"), "2 templates",
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
        // Its own name, so it never clashes with Your templates (2026-09-27).
        XCTAssertEqual(words(app.staticTexts["choices-title"]), "Your choices")
        // Each part says what it is and where it is used — a line or two (his K.3).
        XCTAssertTrue(app.staticTexts["choices-intro"].exists, "the page does not say what it is")
        for kind in ["places", "owners", "people", "conditions", "phases"] {
            let hint = app.staticTexts["choices-hint-\(kind)"]
            XCTAssertTrue(hint.exists, "no explanation for \(kind)")
            XCTAssertGreaterThan(words(hint).count, 80, "\(kind) is explained in too few words: '\(words(hint))'")
        }

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

    /// The spec pass (5 Oct 2026): a place he already had was dropped without a word,
    /// and the reason an entry stays was said at the TOP of the long sheet — off screen
    /// when Remove was pressed far down the "When" steps, "so it looks as if nothing
    /// happened". Both are said now, right where he pressed; and a step's reason names
    /// its trips instead of calling trip lines "things".
    func testYourChoicesSaysWhyRightWhereItWasPressed() {
        let app = launch()
        tab(app, "settings")
        tap(app, id: "settings-lists")
        XCTAssertTrue(appears(app, "lists-detail", timeout: 5))

        type("garage", into: app.textFields["list-places-add-name"])
        tap(app, id: "list-places-add")
        let twin = app.staticTexts["list-places-add-needs"]
        XCTAssertTrue(twin.waitForExistence(timeout: 5), "a place he already has was taken without a word")
        XCTAssertEqual(words(twin), "You already have Garage.")
        XCTAssertNil(find(app, "list-places-row-12"), "…or added a second time")
        hideKeyboard(app)

        // Far down the sheet: "≥1 week ahead" holds the sample's things and its trip.
        let remove = app.buttons["list-phases-remove-1"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        tapVisible(app, remove)
        let why = app.staticTexts["lists-problem"]
        XCTAssertTrue(why.waitForExistence(timeout: 5), "a step in use was refused without a word")
        XCTAssertTrue(words(why).contains("on 1 trip"), "it says what holds the step: '\(words(why))'")
        XCTAssertTrue(words(why).hasSuffix("so it stays."), "'\(words(why))'")
        // Right under the ✕ he pressed, so it is on screen with it.
        XCTAssertGreaterThan(why.frame.minY, remove.frame.minY, "the reason is above what was pressed")
        XCTAssertLessThan(why.frame.minY - remove.frame.maxY, 60, "the reason is far from what was pressed: \(why.frame) vs \(remove.frame)")
        XCTAssertTrue(waitUntil { self.find(app, "list-phases-row-1") != nil }, "…and the step is still there")
        shot(app, "choices-refused")
    }

    /// The spec pass (5 Oct 2026): Your choices "can only add and remove, not rename or
    /// reorder". The pen opens an entry: a new name — which every thing that says the
    /// old one follows — and ▲ ▼ for its place in the list.
    func testAChoiceIsRenamedAndMovedAndItsThingsFollow() {
        let app = launch()
        tab(app, "settings")
        tap(app, id: "settings-lists")
        XCTAssertTrue(appears(app, "lists-detail", timeout: 5))
        XCTAssertEqual(words(app.staticTexts["list-places-name-2"]), "Hall closet")

        tap(app, id: "list-places-edit-2")
        let field = app.textFields["list-places-rename-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the pen opened nothing")
        XCTAssertEqual(field.value as? String, "Hall closet", "the new name starts from the old one")
        replace("Hall cupboard", in: field)
        tap(app, id: "list-places-rename")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["list-places-name-2"]) == "Hall cupboard" },
                      "not renamed: '\(words(app.staticTexts["list-places-name-2"]))'")
        XCTAssertTrue(waitUntil { !app.textFields["list-places-rename-name"].exists }, "the editor stays open after a rename")

        tap(app, id: "list-places-edit-2")
        hideKeyboard(app)
        tap(app, id: "list-places-up")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["list-places-name-1"]) == "Hall cupboard" }, "it did not move up")
        XCTAssertEqual(words(app.staticTexts["list-places-name-2"]), "Chest of drawers")
        XCTAssertTrue(app.buttons["list-places-up"].exists, "the editor follows the entry as it moves")
        shot(app, "choices-editing")
        tap(app, id: "list-places-up")
        tap(app, id: "list-places-up")
        let top = app.staticTexts["list-places-edit-needs"]
        XCTAssertTrue(top.waitForExistence(timeout: 5), "pressed at the top, it said nothing")
        XCTAssertEqual(words(top), "Hall cupboard is already at the top.")

        // Every thing that was in the hall closet is in the hall cupboard now.
        tap(app, id: "lists-done")
        XCTAssertTrue(disappears(app, "lists-detail", timeout: 5))
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        type("Rain jacket", into: app.textFields["things-search"])
        XCTAssertTrue(waitUntil { app.buttons["thing-row-0"].exists })
        app.buttons["thing-row-0"].tap()
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        XCTAssertEqual(app.textFields["thing-storage"].value as? String, "Hall cupboard", "the thing kept the old name")
    }

    // MARK: - Long lists made easier (their field test, 3 Oct 2026)

    /// Choose from your things on Hiking, grouped From where — the sample's places, A–Z
    /// (seen on the screen, 3 Oct 2026): Bathroom cabinet (Toothbrush: row 0), Chest of
    /// drawers (Passport, Phone charger: 1–2), Garage (3–4) and Hall closet (5–6), both
    /// already on Hiking, and No place set (Goggles, Swim cap, Towel: 7–9).
    private func openPickerByPlace(_ app: XCUIApplication) {
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        tap(app, id: "template-row-1")                           // Hiking
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        tap(app, id: "template-pick")
        XCTAssertTrue(appears(app, "pick-screen", timeout: 5), "Choose from your things did not open")
        tap(app, id: "pick-group-fromWhere")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["pick-heading-0"]) == "BATHROOM CABINET" },
                      "From where did not group by place: '\(words(app.staticTexts["pick-heading-0"]))'")
    }

    private func pickRowsShown(_ app: XCUIApplication, _ rows: ClosedRange<Int>) -> Bool {
        rows.allSatisfy { app.buttons["pick-row-\($0)"].exists }
    }
    private func pickRowsGone(_ app: XCUIApplication, _ rows: ClosedRange<Int>) -> Bool {
        rows.allSatisfy { !app.buttons["pick-row-\($0)"].exists }
    }

    /// "We need the list to be collapsible and expandable": a group folds with its
    /// arrow (or its name) and still says what it holds; it opens again.
    func testAGroupOfThingsToChooseFoldsAndSaysWhatItHolds() {
        let app = launch()
        openPickerByPlace(app)
        XCTAssertEqual(words(app.staticTexts["pick-heading-1-count"]), "2 things", "a group does not say how many it holds")
        XCTAssertTrue(pickRowsShown(app, 1...2), "Chest of drawers' two things are not listed")

        tap(app, id: "pick-group-1-fold")
        XCTAssertTrue(waitUntil { self.pickRowsGone(app, 1...2) }, "folding Chest of drawers left its things on screen")
        XCTAssertEqual(words(app.staticTexts["pick-heading-1"]), "CHEST OF DRAWERS", "the folded group lost its name")
        XCTAssertEqual(words(app.staticTexts["pick-heading-1-count"]), "2 things", "the folded group no longer says how many it holds")
        XCTAssertTrue(pickRowsShown(app, 0...0) && pickRowsShown(app, 3...4), "the groups around it folded as well")
        shot(app, "pick-folded")

        // The name folds too, as on a trip.
        tapVisible(app, app.staticTexts["pick-heading-0"])
        XCTAssertTrue(waitUntil { self.pickRowsGone(app, 0...0) }, "tapping a group's name did not fold it")

        // And it opens again.
        tap(app, id: "pick-group-1-fold")
        XCTAssertTrue(waitUntil { self.pickRowsShown(app, 1...2) }, "opening Chest of drawers did not bring its things back")
    }

    /// "Collapse All or Expand All": one button folds every group, then opens them all.
    func testEveryGroupOfThingsToChooseFoldsAndOpensAtOnce() {
        let app = launch()
        openPickerByPlace(app)
        XCTAssertEqual(words(app.buttons["pick-fold-all"]), "Fold all")
        tap(app, id: "pick-fold-all")
        XCTAssertTrue(waitUntil { self.pickRowsGone(app, 0...9) }, "Fold all left things on screen")
        XCTAssertTrue((0...4).allSatisfy { app.staticTexts["pick-heading-\($0)"].exists }, "a folded group lost its heading")
        XCTAssertEqual(words(app.staticTexts["pick-heading-4-count"]), "3 things", "a folded group does not say how many it holds")
        XCTAssertTrue(waitUntil { self.words(app.buttons["pick-fold-all"]) == "Unfold all" },
                      "the button did not turn into Unfold all: '\(words(app.buttons["pick-fold-all"]))'")
        shot(app, "pick-all-folded")
        tap(app, id: "pick-fold-all")
        XCTAssertTrue(waitUntil { self.pickRowsShown(app, 0...9) }, "Unfold all did not bring every thing back")
        XCTAssertEqual(words(app.buttons["pick-fold-all"]), "Fold all")
    }

    /// The folds are remembered on the device, per way of grouping — like a trip's.
    func testTheFoldsOfThingsToChooseAreRemembered() {
        let app = launch()
        openPickerByPlace(app)
        tap(app, id: "pick-fold-all")
        XCTAssertTrue(waitUntil { self.pickRowsGone(app, 0...2) })
        // A–Z has folds of its own (none), and From where comes back folded.
        tap(app, id: "pick-group-name")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["pick-heading-0"]) == "A–Z" })
        XCTAssertTrue(waitUntil { app.buttons["pick-row-0"].exists }, "From where's folds folded A–Z too")
        tap(app, id: "pick-group-fromWhere")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["pick-heading-0"]) == "BATHROOM CABINET" })
        XCTAssertTrue(waitUntil { self.pickRowsGone(app, 0...2) }, "From where forgot its folds after A–Z")
        // Closed and opened again.
        tap(app, id: "pick-cancel")
        XCTAssertTrue(disappears(app, "pick-screen", timeout: 5))
        tap(app, id: "template-pick")
        XCTAssertTrue(appears(app, "pick-screen", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["pick-heading-0"]) == "BATHROOM CABINET" })
        XCTAssertTrue(waitUntil { self.pickRowsGone(app, 0...2) }, "the folds were forgotten when the picker was opened again")
    }

    /// A search opens every group — what he typed for never hides in a folded one —
    /// and the folds come back when the search is emptied.
    func testASearchOpensAFoldedGroupOfThingsToChoose() {
        let app = launch()
        openPickerByPlace(app)
        tap(app, id: "pick-fold-all")
        XCTAssertTrue(waitUntil { self.pickRowsGone(app, 0...2) })
        type("Tooth", into: app.textFields["pick-search"])
        XCTAssertTrue(waitUntil { self.words(app.buttons["pick-row-0"]).contains("Toothbrush") },
                      "the Toothbrush stayed hidden in its folded group: '\(words(app.buttons["pick-row-0"]))'")
        XCTAssertFalse(app.buttons["pick-fold-all"].exists, "Fold all is offered while searching")
        shot(app, "pick-searching")
        tap(app, id: "pick-search-clear")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["pick-heading-0"]) == "BATHROOM CABINET" })
        XCTAssertTrue(waitUntil { self.pickRowsGone(app, 0...2) }, "the folds did not come back after the search")
    }

    /// A thing ticked in a group stays ticked while the group is folded — and the
    /// folded group says so.
    func testATickSurvivesFolding() {
        let app = launch()
        openPickerByPlace(app)
        select(app, app.buttons["pick-row-1"])                    // the Passport, in Chest of drawers
        XCTAssertTrue(waitUntil { self.words(app.buttons["pick-add"]) == "Add 1" })
        XCTAssertEqual(words(app.staticTexts["pick-heading-1-count"]), "2 things · 1 ticked")
        tap(app, id: "pick-fold-all")
        XCTAssertTrue(waitUntil { self.pickRowsGone(app, 0...2) })
        XCTAssertEqual(words(app.staticTexts["pick-heading-1-count"]), "2 things · 1 ticked", "the folded group lost its tick")
        XCTAssertEqual(words(app.buttons["pick-add"]), "Add 1", "folding lost the tick")
        shot(app, "pick-tick-folded")
        tap(app, id: "pick-fold-all")
        XCTAssertTrue(waitUntil { self.isOn(app.buttons["pick-row-1"]) }, "the thing came back unticked")
        XCTAssertEqual(words(app.buttons["pick-add"]), "Add 1")
    }

    /// "Please add an X so that it's quick to delete all typed characters": an ✕ in
    /// every search field, there only while something is typed, emptying it in one tap.
    func testTheCrossEmptiesASearch() {
        let app = launch()
        // Your things.
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        let count = app.staticTexts["things-count"]
        XCTAssertTrue(waitUntil { self.words(count) == "10 things" })
        XCTAssertFalse(app.buttons["things-search-clear"].exists, "an ✕ with nothing to clear")
        type("Head", into: app.textFields["things-search"])
        XCTAssertTrue(waitUntil { self.words(count) == "1 thing" }, "the search did not narrow: '\(words(count))'")
        shot(app, "things-search-cross")
        tap(app, id: "things-search-clear")
        XCTAssertTrue(waitUntil { self.words(count) == "10 things" }, "the ✕ did not empty the search: '\(words(count))'")
        XCTAssertTrue(waitUntil { !app.buttons["things-search-clear"].exists }, "the ✕ stayed with nothing to clear")
        tap(app, id: "things-done")
        XCTAssertTrue(disappears(app, "things-detail", timeout: 5))

        // The magnifier's search.
        tap(app, id: "search-open")
        XCTAssertTrue(appears(app, "search-detail", timeout: 5))
        type("zzzz", into: app.textFields["search-field"])
        XCTAssertTrue(app.staticTexts["search-none"].waitForExistence(timeout: 5))
        tap(app, id: "search-field-clear")
        XCTAssertTrue(waitUntil { !app.staticTexts["search-none"].exists }, "the ✕ did not empty the search")
        XCTAssertFalse(((app.textFields["search-field"].value as? String) ?? "").contains("zzzz"), "the typed word is still there")
        tap(app, id: "search-done")
        XCTAssertTrue(disappears(app, "search-detail", timeout: 5))

        // Choose from your things.
        tab(app, "templates")
        tap(app, id: "template-row-1")
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        tap(app, id: "template-pick")
        XCTAssertTrue(appears(app, "pick-screen", timeout: 5))
        let found = app.staticTexts["pick-count"]
        XCTAssertTrue(waitUntil { self.words(found) == "10 things" })
        type("Tooth", into: app.textFields["pick-search"])
        XCTAssertTrue(waitUntil { self.words(found) == "1 thing" }, "the search did not narrow: '\(words(found))'")
        tap(app, id: "pick-search-clear")
        XCTAssertTrue(waitUntil { self.words(found) == "10 things" }, "the ✕ did not empty the search: '\(words(found))'")
    }

    /// The ✕ keeps the keyboard: the next word is typed straight away, without
    /// tapping the field again.
    func testTheCrossKeepsTheKeyboard() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        let field = app.textFields["things-search"]
        type("Head", into: field)
        tap(app, id: "things-search-clear")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["things-count"]) == "10 things" })
        field.typeText("Map")                                    // no tap: the field still has the keyboard
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["things-count"]) == "1 thing" },
                      "typing after the ✕ did not reach the field: '\(words(app.staticTexts["things-count"]))'")
        XCTAssertEqual(field.value as? String, "Map", "the field holds more than the new word")
    }

    /// "When you add an item, it needs to be on top of the list": a thing added on
    /// this visit is first, newest on top, under Just added — until the screen is left.
    func testANewThingShowsOnTopUnderJustAdded() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        let count = app.staticTexts["things-count"]
        XCTAssertTrue(waitUntil { self.words(count) == "10 things" })
        XCTAssertFalse(app.staticTexts["things-just-added"].exists, "Just added with nothing added")

        // Names that would sort LAST, A–Z.
        type("Zip ties", into: app.textFields["thing-new-name"])
        tap(app, id: "thing-new")
        XCTAssertTrue(waitUntil { self.words(count) == "11 things" }, "the new thing was not added")
        let heading = app.staticTexts["things-just-added"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5), "no Just added heading")
        XCTAssertTrue(waitUntil { app.buttons["thing-row-0"].label.contains("Zip ties") },
                      "the new thing is not at the top: '\(app.buttons["thing-row-0"].label)'")
        XCTAssertLessThanOrEqual(heading.frame.maxY, app.buttons["thing-row-0"].frame.minY + 1, "Just added is not above it")
        shot(app, "things-just-added")

        type("Yoga strap", into: app.textFields["thing-new-name"])
        tap(app, id: "thing-new")
        XCTAssertTrue(waitUntil { self.words(count) == "12 things" })
        XCTAssertTrue(waitUntil { app.buttons["thing-row-0"].label.contains("Yoga strap") },
                      "the newest is not on top: '\(app.buttons["thing-row-0"].label)'")
        XCTAssertTrue(app.buttons["thing-row-1"].label.contains("Zip ties"), "the first one left Just added")

        // Left and opened again: back in their A–Z places.
        tap(app, id: "things-done")
        XCTAssertTrue(disappears(app, "things-detail", timeout: 5))
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(count) == "12 things" })
        XCTAssertFalse(app.staticTexts["things-just-added"].exists, "Just added outlived the visit")
        XCTAssertFalse(app.buttons["thing-row-0"].label.contains("Yoga strap"), "the new thing is still on top after leaving")
    }

    /// "Please save this in the app … so that we can choose to read that later": the
    /// first real trip in six steps has its own door in Settings.
    func testTheFirstTripStepsHaveTheirOwnDoor() {
        let app = launch()
        tab(app, "settings")
        tap(app, id: "settings-firsttrip")
        XCTAssertTrue(appears(app, "guide-firsttrip", timeout: 5), "the six steps did not open")
        XCTAssertNotNil(find(app, "guide-quickstart"), "the page has no first-trip card")
        XCTAssertTrue((0..<6).allSatisfy { app.otherElements["quickstart-step-\($0)"].exists || app.staticTexts["quickstart-step-\($0)"].exists },
                      "the page does not have six steps")
        shot(app, "first-trip")
        tap(app, id: "guide-done")
        XCTAssertTrue(disappears(app, "guide-firsttrip", timeout: 5), "the six steps did not close")
    }

    // MARK: - Main buttons never grey (his standing rule, 2026-09-26)

    /// A button that takes what was typed, pressed too early: it is THERE to press
    /// (never switched off, never grey) and the line `<id>-needs` says what is
    /// missing. "" when it behaves; what went wrong when not — so one run lists every
    /// button that misbehaves instead of stopping at the first.
    private func saysWhatIsMissing(_ app: XCUIApplication, _ id: String) -> String {
        let button = app.buttons[id]
        guard button.waitForExistence(timeout: 5) else { return "\(id): not there" }
        guard button.isEnabled else { return "\(id): switched off with nothing to take" }
        tapVisible(app, button)
        let says = app.staticTexts["\(id)-needs"]
        guard says.waitForExistence(timeout: 5) else { return "\(id): pressed too early, and said nothing" }
        return words(says).isEmpty ? "\(id): an empty line under the field" : ""
    }

    /// His rule: "the app's central button is ALWAYS full colour; pressed too early it
    /// says what's missing under it. Never disable+grey a primary action." Until the
    /// field test (3 Oct 2026) every Add, New and Make beside a field sat grey and
    /// switched off until something was typed. (Trip's Add and To do's Add are in their
    /// own tests.) A colour cannot be read by a test; being pressable and answering can.
    func testEveryAddButtonIsReadyAndSaysWhatIsMissing() {
        let app = launch()
        var misses: [String] = []

        // Care: Your things (New) — and the line goes once something is typed.
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        misses.append(saysWhatIsMissing(app, "thing-new"))
        if app.staticTexts["thing-new-needs"].exists {
            type("Zip ties", into: app.textFields["thing-new-name"])
            if !waitUntil({ !app.staticTexts["thing-new-needs"].exists }) { misses.append("thing-new-needs: stayed after typing") }
        }
        tap(app, id: "things-done")
        XCTAssertTrue(disappears(app, "things-detail", timeout: 5))
        // Care: Your bags.
        tap(app, id: "care-bags")
        XCTAssertTrue(appears(app, "yourbags-detail", timeout: 5))
        misses.append(saysWhatIsMissing(app, "bag-new"))
        tap(app, id: "yourbags-done")
        XCTAssertTrue(disappears(app, "yourbags-detail", timeout: 5))

        // To buy.
        tab(app, "actions")
        tap(app, id: "actions-tab-buy")
        XCTAssertTrue(app.staticTexts["buy-count"].waitForExistence(timeout: 5))
        misses.append(saysWhatIsMissing(app, "buy-add"))

        // Your Grab Lists (Make), and a grab list being changed (Add).
        tab(app, "home")
        tap(app, id: "grab-lists")
        XCTAssertTrue(appears(app, "grablists-detail", timeout: 5))
        misses.append(saysWhatIsMissing(app, "grablists-new"))
        tap(app, id: "grablists-done")
        XCTAssertTrue(disappears(app, "grablists-detail", timeout: 5))
        tap(app, id: "grab-0")
        XCTAssertTrue(appears(app, "grab-detail", timeout: 5))
        tap(app, id: "grab-edit")
        misses.append(saysWhatIsMissing(app, "grab-add"))
        tap(app, id: "grab-edit")                                    // Save, unchanged
        tap(app, id: "grab-done")
        XCTAssertTrue(disappears(app, "grab-detail", timeout: 5))

        // Your choices (the first part's Add).
        tab(app, "settings")
        tap(app, id: "settings-lists")
        XCTAssertTrue(appears(app, "lists-detail", timeout: 5))
        misses.append(saysWhatIsMissing(app, "list-places-add"))
        tap(app, id: "lists-done")
        XCTAssertTrue(disappears(app, "lists-detail", timeout: 5))

        // A template: Add, Rename to a name another template has, a row's new section.
        tab(app, "templates")
        tap(app, id: "template-row-1")                               // Hiking
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        misses.append(saysWhatIsMissing(app, "template-add"))
        replace("Swim", in: app.textFields["template-name"])          // the sample's Swim template
        misses.append(saysWhatIsMissing(app, "template-rename"))
        hideKeyboard(app)
        tap(app, id: "template-item-0")
        XCTAssertTrue(appears(app, "row-detail", timeout: 5))
        misses.append(saysWhatIsMissing(app, "row-section-add"))
        tap(app, id: "row-cancel")
        XCTAssertTrue(disappears(app, "row-detail", timeout: 5))
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))

        // A trip with no place yet: Weather.
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        XCTAssertTrue(app.textFields["weather-place"].waitForExistence(timeout: 5), "the sample trip has a place already")
        misses.append(saysWhatIsMissing(app, "weather-look"))
        shot(app, "weather-needs")

        misses.removeAll { $0.isEmpty }
        XCTAssertTrue(misses.isEmpty, "buttons that are not ready, or do not say what is missing:\n" + misses.joined(separator: "\n"))
    }

    // MARK: - Headings first (their field test, 3 Oct 2026)

    /// Mission 4.4: "adjust the headings so that they are dominant, and the other
    /// buttons and pills are much smaller than the heading … throughout the app". No
    /// test can read a size or a colour, so this one keeps every heading THERE, by its
    /// id, on the screens he named, and photographs each one (SHOTS_DIR) to be looked at.
    func testTheEditorsLeadWithTheirHeadings() {
        let app = launch()
        // The thing editor (Care, Your things, a thing).
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        tap(app, id: "thing-row-0")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        for id in ["thing-heading-name", "thing-heading-kept", "thing-category-title", "thing-bag-title",
                   "thing-heading-plane", "thing-heading-valid", "thing-when-title", "thing-condition-title",
                   "thing-heading-weight", "thing-heading-brand", "thing-heading-colour", "thing-heading-notes",
                   "thing-lists-title"] {
            XCTAssertTrue(app.staticTexts[id].waitForExistence(timeout: 5), "the thing editor lost its heading \(id)")
        }
        shot(app, "looks-thing")
        bringIntoView(app, app.buttons["thing-when-0"])
        shot(app, "looks-thing-when")
        tap(app, id: "thing-cancel")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))
        tap(app, id: "things-done")
        XCTAssertTrue(disappears(app, "things-detail", timeout: 5))

        // A template's row (Templates, Hiking, its first thing).
        tab(app, "templates")
        tap(app, id: "template-row-1")
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        tap(app, id: "template-item-0")
        XCTAssertTrue(appears(app, "row-detail", timeout: 5))
        for id in ["row-bag-title", "row-when-title", "row-section-title", "row-heading-section-new",
                   "row-heading-qty", "row-heading-note", "row-heading-some", "row-seasons-title",
                   "row-transports-title", "row-catering-title"] {
            XCTAssertTrue(app.staticTexts[id].waitForExistence(timeout: 5), "the row editor lost its heading \(id)")
        }
        shot(app, "looks-row")
        bringIntoView(app, app.buttons["row-seasons-0"])
        shot(app, "looks-row-sometimes")
        tap(app, id: "row-cancel")
        XCTAssertTrue(disappears(app, "row-detail", timeout: 5))
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))

        // Create new trip, on Home.
        tab(app, "home")
        for id in ["home-grab-heading", "home-create-heading"] {
            XCTAssertTrue(app.staticTexts[id].waitForExistence(timeout: 5), "Home lost its heading \(id)")
        }
        for id in ["trip-activity-title", "trip-transport-title", "trip-season-title", "trip-catering-title"] {
            XCTAssertTrue(app.staticTexts.matching(identifier: id).firstMatch.waitForExistence(timeout: 5),
                          "Create new trip lost its heading \(id)")
        }
        bringIntoView(app, app.buttons["trip-activity-0"])
        shot(app, "looks-create")
        bringIntoView(app, app.buttons["trip-catering-0"])
        shot(app, "looks-create-food")

        // Trip settings.
        tab(app, "events")
        tap(app, id: "trip-row-0")
        XCTAssertTrue(appears(app, "trip-detail", timeout: 5))
        tap(app, id: "trip-settings")
        XCTAssertTrue(appears(app, "tripset-screen", timeout: 5))
        for id in ["tripset-heading-place", "tripset-activity-title", "tripset-transport-title",
                   "tripset-season-title", "tripset-catering-title"] {
            XCTAssertTrue(app.staticTexts.matching(identifier: id).firstMatch.waitForExistence(timeout: 5),
                          "Trip settings lost its heading \(id)")
        }
        shot(app, "looks-tripset")
        bringIntoView(app, app.buttons["tripset-transport-0"])
        shot(app, "looks-tripset-transport")
        tap(app, id: "tripset-cancel")
        XCTAssertTrue(disappears(app, "tripset-screen", timeout: 5))

        // The trip's review: its question over the pills.
        tap(app, id: "trip-review")
        XCTAssertTrue(appears(app, "review-detail", timeout: 5))
        XCTAssertTrue(app.staticTexts["review-miss-where-title"].waitForExistence(timeout: 5), "the review lost its question")
        shot(app, "looks-review")
        tap(app, id: "review-cancel")
        XCTAssertTrue(disappears(app, "review-detail", timeout: 5))
        tap(app, id: "trip-done")
        XCTAssertTrue(disappears(app, "trip-detail", timeout: 5))

        // Your choices.
        tab(app, "settings")
        tap(app, id: "settings-lists")
        XCTAssertTrue(appears(app, "lists-detail", timeout: 5))
        for kind in ["places", "owners", "people", "conditions", "phases"] {
            XCTAssertTrue(app.staticTexts["choices-heading-\(kind)"].waitForExistence(timeout: 5), "Your choices lost its heading for \(kind)")
        }
        shot(app, "looks-choices")
    }

    // MARK: - The spec pass of 5 Oct 2026: Things, Care, the table, To do

    /// The table and Change all offer what the thing's page offers — his OWN bags,
    /// every owner his things name — and a condition chosen there is stored the way
    /// the page stores it, so the page lights it and To buy offers it. Change all
    /// then says what it changed, not just how many.
    func testTheTableOffersHisOwnBagsAndOwnersAndAConditionReachesToBuy() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-bags")
        XCTAssertTrue(appears(app, "yourbags-detail", timeout: 5))
        type("Sit bag", into: app.textFields["bag-new-name"])
        tap(app, id: "bag-new")
        XCTAssertTrue(waitUntil { app.buttons["bag-0-name"].exists }, "the bag was not made")
        tap(app, id: "yourbags-done")
        XCTAssertTrue(disappears(app, "yourbags-detail", timeout: 5))

        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5), "no table")
        XCTAssertEqual(words(app.staticTexts["table-0-name"]), "Goggles")
        tap(app, id: "table-0-pick")
        tap(app, id: "table-change-all")
        XCTAssertTrue(appears(app, "bulk-detail", timeout: 5), "the change sheet did not open")
        // Packed in: the seventeen built-in bags, then his own.
        tap(app, id: "bulk-field-container")
        XCTAssertTrue(app.buttons["bulk-value-17"].waitForExistence(timeout: 5), "his own bag is not offered")
        XCTAssertTrue(words(app.buttons["bulk-value-17"]).contains("Sit bag"),
                      "the bag after the built-in ones is not his: '\(words(app.buttons["bulk-value-17"]))'")
        // Owner: the two names his things carry, though the Settings list is empty.
        tap(app, id: "bulk-field-ownedBy")
        XCTAssertTrue(app.buttons["bulk-value-1"].waitForExistence(timeout: 5), "the owners his things name are not offered")
        XCTAssertTrue(words(app.buttons["bulk-value-0"]).contains("Kim"), "'\(words(app.buttons["bulk-value-0"]))'")
        XCTAssertTrue(words(app.buttons["bulk-value-1"]).contains("Robin"), "'\(words(app.buttons["bulk-value-1"]))'")
        // Condition: Needs replacing, the fourth.
        tap(app, id: "bulk-field-condition")
        XCTAssertTrue(words(app.buttons["bulk-value-3"]).contains("Needs replacing"))
        tap(app, id: "bulk-value-3")
        XCTAssertTrue(disappears(app, "bulk-detail", timeout: 5), "the sheet stayed open")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["table-said"]).contains("Condition → Needs replacing") },
                      "Change all does not say what it changed: '\(words(app.staticTexts["table-said"]))'")
        XCTAssertTrue(waitUntil { self.cellSays(app, "table-0-condition") == "Needs replacing" },
                      "the cell does not read the condition: '\(cellSays(app, "table-0-condition"))'")
        shot(app, "table-change-said")

        // The thing's own page lights it…
        tap(app, id: "table-0-open")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        let lit = app.buttons["thing-condition-4"]
        XCTAssertTrue(lit.waitForExistence(timeout: 5))
        bringIntoView(app, lit)
        XCTAssertTrue(isOn(lit), "the thing's page does not light the condition set in the table")
        tap(app, id: "thing-cancel")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))
        tap(app, id: "table-done")
        XCTAssertTrue(disappears(app, "table-detail", timeout: 5))

        // …and To buy offers it, first (Needs replacing, then A–Z: Goggles before Map).
        tab(app, "actions")
        tap(app, id: "actions-tab-buy")
        XCTAssertTrue(app.buttons["buy-offer-0"].waitForExistence(timeout: 5), "nothing offered")
        XCTAssertTrue(waitUntil { self.words(app.buttons["buy-offer-0"]).contains("Goggles") },
                      "the condition set in the table does not reach To buy: '\(words(app.buttons["buy-offer-0"]))'")
    }

    /// A thing stored the old way — its condition as the LABEL — is put right when
    /// the library is read: To buy offers it like any other worn-out thing.
    func testAConditionStoredTheOldWayIsRepairedOnLoad() {
        let app = launch("-uiTestingOldConditions")
        tab(app, "actions")
        tap(app, id: "actions-tab-buy")
        XCTAssertTrue(app.buttons["buy-offer-0"].waitForExistence(timeout: 5), "nothing offered")
        XCTAssertTrue(waitUntil { self.words(app.buttons["buy-offer-0"]).contains("Goggles") },
                      "the old label was not repaired: '\(words(app.buttons["buy-offer-0"]))'")
    }

    /// With nobody named on any thing or in Settings, the thing's page still shows
    /// "Whose it is", and says where the names come from.
    func testWhoseItIsSaysWhereNamesComeFromWhenNobodyIsNamed() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5))
        tap(app, id: "table-pick-all")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["table-chosen-count"]) == "10 ticked" })
        tap(app, id: "table-change-all")
        XCTAssertTrue(appears(app, "bulk-detail", timeout: 5))
        tap(app, id: "bulk-field-ownedBy")
        tap(app, id: "bulk-value-blank")
        XCTAssertTrue(disappears(app, "bulk-detail", timeout: 5))
        tap(app, id: "table-0-open")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        let none = app.staticTexts["thing-owner-none"]
        XCTAssertTrue(none.waitForExistence(timeout: 5), "with nobody named, Whose it is just vanished")
        XCTAssertTrue(words(none).contains("Your choices"), "'\(words(none))'")
        bringIntoView(app, none)
        shot(app, "thing-owner-none")
    }

    /// His bag list is no column of the table, no filter and no sort key: a tick
    /// there made a thing a bag. (The checks sample has a bag list beside its three
    /// templates.)
    func testTheBagListIsNoColumnOfTheTable() {
        let app = launch("-uiTestingChecks")
        tab(app, "care")
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5))
        tap(app, id: "table-filter")
        XCTAssertTrue(appears(app, "filter-sheet", timeout: 5))
        XCTAssertTrue(app.buttons["filter-col-list-2"].waitForExistence(timeout: 5) || app.buttons["filter-col-list-3"].exists)
        let columns = (0..<6).filter { app.buttons["filter-col-list-\($0)"].exists }
        XCTAssertEqual(columns.count, 3, "the bag list is a template column: \(columns)")
        tap(app, id: "filter-done")
        tap(app, id: "table-columns")
        XCTAssertTrue(appears(app, "columns-detail", timeout: 5))
        let offered = (0..<6).filter { app.buttons["columns-list-\($0)-show"].exists }
        XCTAssertEqual(offered.count, 3, "Columns offers the bag list: \(offered)")
    }

    /// A template deleted after the table was set up takes its filter and its column
    /// with it: the table does not stay empty behind an invisible filter, and the
    /// columns he had come back rather than an empty grid.
    func testATemplateDeletedTakesItsFilterAndColumnAlong() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5))
        tap(app, id: "table-columns")
        XCTAssertTrue(appears(app, "columns-detail", timeout: 5))
        tap(app, id: "columns-list-2-show")
        for gone in ["weight", "storage", "container", "ownedBy", "packer", "condition", "listQty"] {
            tap(app, id: "columns-\(gone)-hide")
        }
        tap(app, id: "columns-done")
        XCTAssertTrue(disappears(app, "columns-detail", timeout: 5))
        XCTAssertFalse(app.buttons["table-head-weight"].exists)
        tap(app, id: "table-filter")
        XCTAssertTrue(appears(app, "filter-sheet", timeout: 5))
        XCTAssertTrue(words(app.buttons["filter-col-list-2"]).contains("Swim"), "list-2 is not Swim: '\(words(app.buttons["filter-col-list-2"]))'")
        tap(app, id: "filter-col-list-2")
        tap(app, id: "filter-list-2-0")
        tap(app, id: "filter-done")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["table-count"]) == "3" }, "On Swim should leave three")
        tap(app, id: "table-done")
        XCTAssertTrue(disappears(app, "table-detail", timeout: 5))

        // Swim goes.
        tap(app, id: "search-open")
        XCTAssertTrue(appears(app, "search-detail", timeout: 5))
        type("Swim", into: app.textFields["search-field"])
        XCTAssertTrue(app.buttons["search-lists-0"].waitForExistence(timeout: 5))
        tapVisible(app, app.buttons["search-lists-0"])
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        tap(app, id: "template-delete")
        tap(app, id: "template-delete-yes")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))
        tap(app, id: "search-done")
        XCTAssertTrue(disappears(app, "search-detail", timeout: 5))

        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5))
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["table-count"]) == "10" },
                      "the gone template's filter still hides things: '\(words(app.staticTexts["table-count"]))'")
        XCTAssertEqual(words(app.buttons["table-filter"]), "Filter", "a filter is still counted")
        XCTAssertTrue(app.buttons["table-head-weight"].waitForExistence(timeout: 5),
                      "with its only column gone, the grid did not come back to the starting columns")
    }

    /// Change all refuses a weight that is not a number, and says why; a words
    /// field of spaces says "Leave blank"; ticks kept while searching are counted.
    func testChangeAllRefusesANonNumberAndCountsTicksOutOfSight() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5))
        tap(app, id: "table-0-pick")
        tap(app, id: "table-3-pick")
        type("Map", into: app.textFields["table-search"])
        hideKeyboard(app)
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["table-chosen-count"]) == "2 ticked · 1 not shown" },
                      "a tick out of sight is not said: '\(words(app.staticTexts["table-chosen-count"]))'")
        shot(app, "table-ticks-hidden")
        tap(app, id: "table-change-all")
        XCTAssertTrue(appears(app, "bulk-detail", timeout: 5))
        tap(app, id: "bulk-field-color")
        type("   ", into: app.textFields["bulk-text"])
        XCTAssertTrue(words(app.buttons["bulk-apply"]).contains("Leave blank"),
                      "spaces alone offer to set something: '\(words(app.buttons["bulk-apply"]))'")
        tap(app, id: "bulk-field-weight")
        type("abc", into: app.textFields["bulk-text"])
        tap(app, id: "bulk-apply")
        XCTAssertTrue(app.staticTexts["bulk-needs"].waitForExistence(timeout: 5), "a weight that is no number was taken")
        shot(app, "bulk-weight-refused")
        XCTAssertTrue(find(app, "bulk-detail") != nil, "the sheet closed as if it had done it")
        tap(app, id: "bulk-cancel")
        XCTAssertTrue(disappears(app, "bulk-detail", timeout: 5))
        XCTAssertTrue(waitUntil { (app.textFields["table-0-weight"].value as? String) == "60" },
                      "the Map's weight changed: '\(app.textFields["table-0-weight"].value as? String ?? "")'")
    }

    /// Your things says so when a name is taken, and keeps what he typed.
    func testANewThingWithANameHeHasSaysSo() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        type("map", into: app.textFields["thing-new-name"])
        tap(app, id: "thing-new")
        let says = app.staticTexts["thing-new-needs"]
        XCTAssertTrue(says.waitForExistence(timeout: 5), "a name he has already: nothing said")
        XCTAssertTrue(words(says).contains("already"), "'\(words(says))'")
        XCTAssertEqual(app.textFields["thing-new-name"].value as? String, "map", "what he typed was thrown away")
        shot(app, "things-name-taken")
        XCTAssertEqual(words(app.staticTexts["things-count"]), "10 things")
    }

    /// A thing's page: a weight with a comma and decimals; a place picked from his
    /// places; "No bag"; and a care schedule that puts it on Care.
    func testAThingsPageTakesDecimalsAPlaceNoBagAndCare() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        XCTAssertTrue(words(app.buttons["thing-row-0"]).contains("Goggles"), "'\(words(app.buttons["thing-row-0"]))'")
        tap(app, id: "thing-row-0")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        let weight = app.textFields["thing-weight"]
        bringIntoView(app, weight)
        replace("abc", in: weight)
        tap(app, id: "thing-save")
        XCTAssertTrue(app.staticTexts["thing-weight-problem"].waitForExistence(timeout: 5), "a weight that is no number was saved")
        shot(app, "thing-weight-problem")
        XCTAssertTrue(find(app, "thing-detail") != nil, "it closed as if saved")
        replace("12,5", in: weight)
        XCTAssertEqual(weight.value as? String, "12,5", "the comma did not survive the typing")
        // The first of his places, a tap away.
        let place = app.buttons["thing-place-0"]
        bringIntoView(app, place)
        let placeName = words(place)
        select(app, place)
        XCTAssertEqual(app.textFields["thing-storage"].value as? String, placeName, "the place was not put in the field")
        shot(app, "thing-places")
        // No bag: the last pill of Usually packed in.
        let noBag = (0..<40).map { app.buttons["thing-bag-\($0)"] }.last { $0.exists }!
        XCTAssertTrue(words(noBag).contains("No bag"), "'\(words(noBag))'")
        select(app, noBag)
        shot(app, "thing-no-bag")
        // Looked after every month, with what to do.
        let monthly = app.buttons["thing-care-1"]
        bringIntoView(app, monthly)
        select(app, monthly)
        let notes = app.textFields["thing-care-notes"]
        bringIntoView(app, notes)
        type("Rinse in fresh water", into: notes)
        shot(app, "thing-care")
        tap(app, id: "thing-save")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5), "Save did not close")

        tap(app, id: "thing-row-0")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        bringIntoView(app, app.textFields["thing-weight"])
        XCTAssertEqual(app.textFields["thing-weight"].value as? String, "12.5", "the decimal weight did not keep")
        XCTAssertTrue(isOn(app.buttons["thing-place-0"]), "the place is not lit")
        XCTAssertTrue(isOn(noBag), "No bag is not lit")
        XCTAssertTrue(isOn(app.buttons["thing-care-1"]), "the care schedule was not kept")
        tap(app, id: "thing-cancel")
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5))
        tap(app, id: "things-done")
        XCTAssertTrue(disappears(app, "things-detail", timeout: 5))
        // Never done → due now: on Care, due soon.
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["care-summary"]).contains("1 due soon") },
                      "the care set on the page did not reach Care: '\(words(app.staticTexts["care-summary"]))'")
    }

    /// To do and To buy each keep their own half-typed line, and a line taken away
    /// with ✕ comes back with Undo.
    func testToDoAndToBuyKeepTheirOwnTextAndUndoARemoval() {
        let app = launch()
        tab(app, "actions")
        XCTAssertTrue(appears(app, "screen-actions"))
        type("Half a to-do", into: app.textFields["action-add-text"])
        tap(app, id: "actions-tab-buy")
        XCTAssertTrue(app.textFields["buy-add-text"].waitForExistence(timeout: 5))
        let buyField = (app.textFields["buy-add-text"].value as? String) ?? ""
        XCTAssertFalse(buyField.contains("Half"), "the to-do half typed shows on To buy: '\(buyField)'")
        type("Milk", into: app.textFields["buy-add-text"])
        tap(app, id: "buy-add")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["buy-count"]) == "1 to buy" })
        tap(app, id: "buy-0-remove")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["buy-count"]) == "Nothing to buy." }, "✕ did not take it")
        XCTAssertTrue(words(app.staticTexts["buy-undo-says"]).contains("Milk"), "it does not say what went")
        shot(app, "buy-undo")
        tap(app, id: "buy-undo")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["buy-count"]) == "1 to buy" }, "Undo did not bring it back")
        XCTAssertFalse(app.buttons["buy-undo"].exists, "Undo stayed after it was used")

        tap(app, id: "actions-tab-todo")
        XCTAssertEqual(app.textFields["action-add-text"].value as? String, "Half a to-do", "the to-do half typed was lost")
        tap(app, id: "action-add")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["actions-count"]) == "1 to do" })
        tap(app, id: "action-0-remove")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["actions-count"]) == "Nothing to do." })
        shot(app, "todo-undo")
        tap(app, id: "action-undo")
        XCTAssertTrue(waitUntil { self.words(app.staticTexts["actions-count"]) == "1 to do" }, "Undo did not bring the to-do back")
    }

    /// A line whose reminder was deleted in Reminders can be sent again — when he
    /// presses Send. ("-pretendShopDeleted": a Reminders list he has emptied.)
    func testALineWhoseReminderWasDeletedCanBeSentAgain() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-pretendShopDeleted"]
        app.launch()
        tab(app, "actions")
        tap(app, id: "actions-tab-buy")
        for line in ["Sun cream", "Plasters"] {
            type(line, into: app.textFields["buy-add-text"])
            tap(app, id: "buy-add")
        }
        tap(app, id: "buy-send")
        XCTAssertTrue(app.staticTexts["buy-send-says"].waitForExistence(timeout: 5), "they were not sent")
        tap(app, id: "actions-tab-todo")
        tap(app, id: "actions-tab-buy")
        XCTAssertTrue(waitUntil(timeout: 10) { self.words(app.buttons["buy-send"]).contains("Send 2") },
                      "lines whose reminders were deleted stay 'sent' for ever: '\(words(app.buttons["buy-send"]))'")
    }

    /// Your bags shows a number changed on the bag's own page as soon as it closes.
    func testYourBagsShowsANumberChangedOnTheBagsPage() {
        let app = launch()
        tab(app, "care")
        tap(app, id: "care-bags")
        XCTAssertTrue(appears(app, "yourbags-detail", timeout: 5))
        type("Sit bag", into: app.textFields["bag-new-name"])
        tap(app, id: "bag-new")
        XCTAssertTrue(waitUntil { app.buttons["bag-0-name"].exists })
        tap(app, id: "bag-0-name")
        XCTAssertTrue(appears(app, "bag-detail", timeout: 5))
        type("7", into: app.textFields["bag-detail-maxkg"])
        tap(app, id: "bag-done")
        XCTAssertTrue(disappears(app, "bag-detail", timeout: 5))
        XCTAssertTrue(waitUntil { (app.textFields["bag-0-maxkg"].value as? String) == "7" },
                      "the row still shows the old number: '\(app.textFields["bag-0-maxkg"].value as? String ?? "")'")
    }

    // MARK: - The last loose ends (5 Oct 2026)

    /// A note a template keeps for a thing shows on the thing's own page (spec 05,
    /// item 18): Notes looked empty while the template said something.
    func testAThingsPageShowsTheNotesItsTemplatesKeep() {
        let app = launch()
        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        XCTAssertTrue(words(app.buttons["template-row-2"]).contains("Swim"), "'\(words(app.buttons["template-row-2"]))'")
        tap(app, id: "template-row-2")
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        XCTAssertTrue(words(app.buttons["template-item-0"]).contains("Goggles"), "'\(words(app.buttons["template-item-0"]))'")
        tap(app, id: "template-item-0")
        XCTAssertTrue(appears(app, "row-detail", timeout: 5))
        let note = app.textFields["row-note"]
        bringIntoView(app, note)
        type("Rinse after the sea", into: note)
        tap(app, id: "row-save")
        XCTAssertTrue(disappears(app, "row-detail", timeout: 5))
        tap(app, id: "template-detail-done")
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5))

        tab(app, "care")
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        XCTAssertTrue(words(app.buttons["thing-row-0"]).contains("Goggles"), "'\(words(app.buttons["thing-row-0"]))'")
        tap(app, id: "thing-row-0")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        let said = app.staticTexts["thing-row-note-0"]
        XCTAssertTrue(said.waitForExistence(timeout: 5), "the template's note is not on the thing's page")
        XCTAssertEqual(words(said), "On the Swim template: Rinse after the sea")
        XCTAssertFalse(app.staticTexts["thing-row-note-1"].exists, "a template with no note of its own was listed")
        XCTAssertFalse((app.textFields["thing-notes"].value as? String ?? "").contains("Rinse"),
                       "the template's note was put in the thing's own note")
        shot(app, "thing-row-notes")
        tap(app, id: "thing-cancel")
    }

    // MARK: - Escape everywhere (5 Oct 2026)

    /// Escape on the Mac; on an iPhone with a keyboard ⌘. is the same Cancel. (The
    /// simulator passes no Escape on without a keyboard of its own; ⌘. arrives.)
    /// An iPhone closes a sheet that may be swiped away on ⌘. by itself, shortcut or
    /// not — there these tests pin that the right window closes and nothing is saved;
    /// the Mac, where nothing closes without the shortcut, pins the shortcut itself.
    private func pressEscape(_ app: XCUIApplication) {
        sleep(1)                                    // a window just opened: let it take the keys
        #if os(macOS)
        app.typeKey(.escape, modifierFlags: [])
        #else
        app.typeKey(".", modifierFlags: .command)
        #endif
    }

    /// Escape everywhere: Cancel where a window has Cancel, Done where it has only
    /// Done — never a save. Settings' windows: Your choices (a name typed and not
    /// added stays out), the restore (nothing replaced, and the line says so), a guide
    /// page, Open a shared link.
    func testEscapeClosesSettingsWindowsAndNeverReplaces() {
        let app = launch()
        tab(app, "settings")
        XCTAssertTrue(appears(app, "screen-settings"))
        let things = app.staticTexts["device-count-items"]
        XCTAssertTrue(waitUntil { self.words(things) == "10" }, "the sample is not what it was: '\(words(things))'")

        tap(app, id: "settings-lists")
        XCTAssertTrue(appears(app, "lists-detail", timeout: 5))
        type("Attic shelf", into: app.textFields["list-places-add-name"])
        pressEscape(app)
        XCTAssertTrue(disappears(app, "lists-detail", timeout: 5), "Escape did not close Your choices")
        XCTAssertNotNil(find(app, "screen-settings"), "Escape took Settings with it")
        tap(app, id: "settings-lists")
        XCTAssertTrue(appears(app, "lists-detail", timeout: 5))
        XCTAssertTrue(app.staticTexts["list-places-name-11"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["list-places-name-12"].exists, "Escape added the place that was only typed")
        tap(app, id: "lists-done")
        XCTAssertTrue(disappears(app, "lists-detail", timeout: 5))

        let status = app.staticTexts["backup-status"]
        tap(app, id: "backup-restore")
        XCTAssertTrue(appears(app, "restore-detail", timeout: 5))
        pressEscape(app)
        XCTAssertTrue(disappears(app, "restore-detail", timeout: 5), "Escape did not cancel the restore")
        XCTAssertTrue(waitUntil { self.words(status) == "Nothing was replaced." }, "Escape left the line saying: '\(words(status))'")
        XCTAssertEqual(words(things), "10", "Escape replaced the library")

        tap(app, id: "settings-whatsnew")
        XCTAssertTrue(appears(app, "guide-whatsnew", timeout: 5))
        pressEscape(app)
        XCTAssertTrue(disappears(app, "guide-whatsnew", timeout: 5), "Escape did not close What's new")

        tap(app, id: "settings-openshared")
        XCTAssertTrue(appears(app, "shared-screen", timeout: 5))
        pressEscape(app)
        XCTAssertTrue(disappears(app, "shared-screen", timeout: 5), "Escape did not close Open a shared link")
        XCTAssertNotNil(find(app, "screen-settings"))
    }

    /// Escape everywhere, Care: a thing's page is CANCELLED (the new name is not kept)
    /// and only it closes, not Your things behind it; Your bags closes; on the iPhone
    /// the table closes, and its Filter alone before it. (On the Mac the table is a
    /// window of its own, which Escape leaves open — a window closes with ⌘W.)
    func testEscapeCancelsAThingAndClosesCaresWindows() {
        let app = launch()
        tab(app, "care")
        XCTAssertTrue(appears(app, "screen-care"))
        tap(app, id: "care-things")
        XCTAssertTrue(appears(app, "things-detail", timeout: 5))
        let first = app.buttons["thing-row-0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let before = first.label
        tap(app, id: "thing-row-0")
        XCTAssertTrue(appears(app, "thing-detail", timeout: 5))
        replace("Escaped name", in: app.textFields["thing-name"])
        pressEscape(app)
        XCTAssertTrue(disappears(app, "thing-detail", timeout: 5), "Escape did not cancel the thing")
        XCTAssertNotNil(find(app, "things-detail"), "Escape closed Your things behind the thing too")
        XCTAssertFalse(app.buttons["thing-row-0"].label.contains("Escaped name"), "Escape saved the thing")
        XCTAssertEqual(app.buttons["thing-row-0"].label, before, "the thing changed")
        pressEscape(app)
        XCTAssertTrue(disappears(app, "things-detail", timeout: 5), "Escape did not close Your things")

        tap(app, id: "care-bags")
        XCTAssertTrue(appears(app, "yourbags-detail", timeout: 5))
        pressEscape(app)
        XCTAssertTrue(disappears(app, "yourbags-detail", timeout: 5), "Escape did not close Your bags")

        tap(app, id: "care-table")
        XCTAssertTrue(appears(app, "table-detail", timeout: 5))
        tap(app, id: "table-filter")
        XCTAssertTrue(appears(app, "filter-sheet", timeout: 5))
        pressEscape(app)
        XCTAssertTrue(disappears(app, "filter-sheet", timeout: 5), "Escape did not close the filter")
        XCTAssertNotNil(find(app, "table-detail"), "Escape closed the table behind the filter too")
        pressEscape(app)
        #if os(macOS)
        XCTAssertNotNil(find(app, "table-detail"), "Escape closed the table's own window")
        tap(app, id: "table-done")
        #endif
        XCTAssertTrue(disappears(app, "table-detail", timeout: 5), "Escape did not close the table")
    }

    /// Escape everywhere, Home and Templates: Search and Grab Lists close; a row's
    /// editor is CANCELLED — a section typed there is not made — and only it closes,
    /// not the template behind it; New makes nothing.
    func testEscapeLeavesHomeAndTemplatesWindowsWithoutSaving() {
        let app = launch()
        XCTAssertTrue(appears(app, "screen-home", timeout: 20))
        tap(app, id: "search-open")
        XCTAssertTrue(appears(app, "search-detail", timeout: 5))
        pressEscape(app)
        XCTAssertTrue(disappears(app, "search-detail", timeout: 5), "Escape did not close Search")
        tap(app, id: "grab-lists")
        XCTAssertTrue(appears(app, "grablists-detail", timeout: 5))
        pressEscape(app)
        XCTAssertTrue(disappears(app, "grablists-detail", timeout: 5), "Escape did not close Grab Lists")

        tab(app, "templates")
        XCTAssertTrue(appears(app, "screen-templates"))
        let summary = app.staticTexts["templates-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        let counted = words(summary)
        tap(app, id: "template-row-1")                            // Hiking: one section, Lights
        XCTAssertTrue(appears(app, "template-detail", timeout: 5))
        tap(app, id: "template-item-0")
        XCTAssertTrue(appears(app, "row-detail", timeout: 5))
        let field = app.textFields["row-section-new"]
        bringIntoView(app, field)
        type("Rig", into: field)
        tap(app, id: "row-section-add")
        XCTAssertTrue(app.buttons["row-section-2"].waitForExistence(timeout: 5), "the typed section is not offered")
        pressEscape(app)
        XCTAssertTrue(disappears(app, "row-detail", timeout: 5), "Escape did not cancel the row")
        XCTAssertNotNil(find(app, "template-detail"), "Escape closed the template behind the row too")
        tap(app, id: "template-item-0")
        XCTAssertTrue(appears(app, "row-detail", timeout: 5))
        XCTAssertTrue(app.buttons["row-section-1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["row-section-2"].exists, "Escape saved the row and its section")
        tap(app, id: "row-cancel")
        XCTAssertTrue(disappears(app, "row-detail", timeout: 5))
        pressEscape(app)
        XCTAssertTrue(disappears(app, "template-detail", timeout: 5), "Escape did not close the template")

        tap(app, id: "templates-new")
        XCTAssertTrue(appears(app, "newlist-detail", timeout: 5))
        type("Picnic", into: app.textFields["newlist-name"])
        pressEscape(app)
        XCTAssertTrue(disappears(app, "newlist-detail", timeout: 5), "Escape did not cancel New")
        XCTAssertNil(find(app, "template-detail"), "Escape made the template")
        XCTAssertEqual(words(summary), counted, "Escape made a template")
    }
}
