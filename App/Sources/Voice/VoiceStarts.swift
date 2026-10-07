#if os(iOS)
import SwiftUI
import UIKit

/// "Start Pack by voice at this place" — the entry point for a place opened by its
/// printed code (spec 07 parts 3 and 10; his yes of 7 Oct 2026: the code STARTS the walk
/// by itself, at that place). Whoever opens a trip on a place calls
/// `VoiceStarts.shared.startVoiceAt(place:tripId:)`; the trip's Sorting row
/// (`VoiceSortingRow`) takes the request when that trip is on screen — at once if it is
/// open already — and starts the walk there, unless he switched "Start Pack by voice when
/// a place code opens a trip" off on the panel (`autoStartKey`, on by default, per device).
@MainActor
final class VoiceStarts: ObservableObject {
    static let shared = VoiceStarts()

    struct Request: Equatable {
        /// The trip to start on; nil = whichever trip screen is open or opens next.
        let tripId: String?
        let place: String
        /// Each request is new, so the same place asked twice starts twice.
        let id = UUID()
    }

    /// Remembered on this device; on by default.
    static let autoStartKey = "ams.voice.autostart"

    @Published private(set) var request: Request?

    func startVoiceAt(place: String, tripId: String? = nil) {
        request = Request(tripId: tripId, place: place)
    }

    /// Taken by the trip that starts it (or that the setting turned it away from).
    func take(_ r: Request) { if request == r { request = nil } }

    private init() {
        guard AMSPackingApp.testing else { return }
        // Under the UI tests: the setting starts on, and `-uiTestingVoiceStartAt <place>`
        // plays "a place code was opened" — at launch, and again each time the app comes
        // back to the front (the way the Camera hands a code to it).
        UserDefaults.standard.removeObject(forKey: VoiceStarts.autoStartKey)
        let args = ProcessInfo.processInfo.arguments
        guard let n = args.firstIndex(of: "-uiTestingVoiceStartAt"), n + 1 < args.count else { return }
        let place = args[n + 1]
        startVoiceAt(place: place)
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in VoiceStarts.shared.startVoiceAt(place: place) }
        }
    }
}
#endif
