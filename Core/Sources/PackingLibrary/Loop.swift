import Foundation
import PackingCore

// The loop the app runs on (his picture, 2026-09-27): Plan → Pack → Review →
// Refine, and Refine feeds the next Plan. Plan and Refine are about his LISTS;
// Pack and Review are about ONE trip.
//
// On site joined it between Pack and Review — their field test
// (3 Oct 2026): "I'm still pondering if we should add a phase (in the graphics as
// well). The phase could be 'During the trip' or 'On site'. It should come
// immediately after Pack, process-wise." It is about one trip too.

extension Library {
    public enum LoopStep: Int, Sendable, CaseIterable {
        case plan, pack, onSite, review, refine

        public var name: String {
            switch self {
            case .plan: return "Plan"
            case .pack: return "Pack"
            case .onSite: return "On site"
            case .review: return "Review"
            case .refine: return "Refine"
            }
        }

        /// Pack, On site and Review are about one trip; Plan and Refine about the lists.
        public var aboutOneTrip: Bool { self == .pack || self == .onSite || self == .review }
    }

    /// Where a trip stands in the loop. Reviewed: what it taught now waits in
    /// Refine. Over and not reviewed: Review. No lines yet: still Plan. Under way
    /// (its first day has come, its last not yet passed): On site — and so is a trip
    /// without dates once something was bought on site, the one sign it has begun.
    /// Otherwise it is being packed — all ticked or not, until it begins.
    public func loopStep(tripId: String, today: String) -> LoopStep {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return .plan }
        if Library.isReviewed(trip) { return .refine }
        let end = trip.endDate.isEmpty ? trip.startDate : trip.endDate
        if !end.isEmpty, end < today { return .review }
        if trip.entries.isEmpty { return .plan }
        if isYMD(trip.startDate) {
            if trip.startDate <= today { return .onSite }
        } else if trip.entries.contains(where: Library.isBoughtOnSite) {
            return .onSite
        }
        return .pack
    }
}
