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

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()
        return app
    }

    /// A named screen. The same SwiftUI container is a Group to the Mac and an
    /// Other to the iPhone (found by dumping the tree, not by guessing) — and a
    /// typed query is the only fast one: `descendants(matching: .any)` hangs.
    private func screen(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        #if os(macOS)
        return app.groups["screen-\(name)"]
        #else
        return app.otherElements["screen-\(name)"]
        #endif
    }

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
        XCTAssertTrue(screen(app, "home").waitForExistence(timeout: 20))

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
        XCTAssertTrue(screen(app, "home").waitForExistence(timeout: 20))

        for name in ["events", "templates", "care", "actions", "settings", "home"] {
            let tab = app.buttons["tab-\(name)"]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "no tab-\(name)")
            tab.tap()
            XCTAssertTrue(screen(app, name).waitForExistence(timeout: 5),
                          "tab-\(name) did not open screen-\(name)")
            if name != "home" {
                XCTAssertFalse(screen(app, "home").exists,
                               "Home is still showing behind screen-\(name)")
            }
        }
    }
}
