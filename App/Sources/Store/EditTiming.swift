import Foundation
import os

/// How long an edit keeps the screen waiting — for measuring, under the tests only, with
/// `-timeEdits` (0.91; his test sheet of 19 Oct 2026 on a bag's page: "There is a delay. Once I
/// have entered data, there is a delay if I would like to scroll or move to the next data field").
///
/// Three kinds of line, in the device's log (subsystem `com.schabbauer.AMSPacking`, category
/// `timing`; `log show --predicate 'category == "timing"'`):
/// - `change <model> + <store> ms` — one `LibraryModel.change`: the library changed in memory, then
///   every record built again, compared and the difference written (`StoreSession.save`).
/// - `key turn <n> ms` — the turn of the main run loop that took in one key typed into a bag's field:
///   the key, any write it made, and the screen drawn again — what a finger feels as typing lag.
/// - `busy <n> ms` — any other turn longer than 25 ms (under the UI tests most of these are the test
///   machinery reading the screen, which a hand never pays).
///
/// Measured with `-uiTestingBigLibrary` (a library of his size, kept by SwiftData as his is) — the
/// numbers are in spec 05, A bag's page, "0.91 — typing without a wait".
enum EditTiming {
    static let on = AMSPackingApp.testing && ProcessInfo.processInfo.arguments.contains("-timeEdits")
    private static let log = Logger(subsystem: "com.schabbauer.AMSPacking", category: "timing")
    private static var turnStarted: CFAbsoluteTime = 0
    private static var watching = false
    /// What the turn now running handles, when it is a key typed into a field (`key`).
    private static var marked: String?

    /// This turn of the run loop handles a key typed: its time is logged as `key turn <n> ms`, slow or not.
    static func mark(_ what: String) { if on { marked = what } }

    /// Start logging every slow turn of the main run loop: from waking up to going back to sleep,
    /// which takes in the key, the change and the drawing that follows.
    static func watch() {
        guard on, !watching else { return }
        watching = true
        let main = CFRunLoopGetMain()
        let woke = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.afterWaiting.rawValue, true, CFIndex.min) { _, _ in
            turnStarted = CFAbsoluteTimeGetCurrent()
        }
        let sleeps = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue, true, CFIndex.max) { _, _ in
            guard turnStarted > 0 else { return }
            let ms = (CFAbsoluteTimeGetCurrent() - turnStarted) * 1000
            turnStarted = 0
            if let what = marked {
                marked = nil
                log.notice("\(what, privacy: .public) turn \(Int(ms.rounded()), privacy: .public) ms")
            } else if ms >= 25 {
                log.notice("busy \(Int(ms.rounded()), privacy: .public) ms")
            }
        }
        CFRunLoopAddObserver(main, woke, .commonModes)
        CFRunLoopAddObserver(main, sleeps, .commonModes)
    }

    /// One change: the library in memory, then the store.
    static func change(model: CFAbsoluteTime, store: CFAbsoluteTime) {
        guard on else { return }
        log.notice("change \(Int((model * 1000).rounded()), privacy: .public) + \(Int((store * 1000).rounded()), privacy: .public) ms")
    }

    /// The whole store read again (an iCloud notification — `LibraryModel.reload`).
    static func reloaded(_ took: CFAbsoluteTime) {
        guard on else { return }
        log.notice("reload \(Int((took * 1000).rounded()), privacy: .public) ms")
    }

    /// A page's typed fields written in one go (`EditDraft.flush`): how many, and how long.
    static func flushed(_ fields: Int, _ took: CFAbsoluteTime) {
        guard on else { return }
        log.notice("flush \(fields, privacy: .public) fields \(Int((took * 1000).rounded()), privacy: .public) ms")
    }

    static var now: CFAbsoluteTime { on ? CFAbsoluteTimeGetCurrent() : 0 }
}
