import Foundation
import PackingCore

// Changing a trip after it is made — the web app's trip menu, which the native app
// lacked (the gap list, 2026-09-26). First: getting rid of one.

extension Library {
    /// Delete a trip: it and its lines go. Nothing else is touched — the things,
    /// the lists and the to-dos stay. A trip that is not there: false.
    @discardableResult
    public mutating func deleteTrip(id: String) -> Bool {
        guard trips.contains(where: { $0.id == id }) else { return false }
        trips.removeAll { $0.id == id }
        return true
    }
}
