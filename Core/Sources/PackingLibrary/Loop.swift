import Foundation
import PackingCore

// The loop the app runs on (his picture, 2026-09-27): Plan → Pack → Review →
// Refine, and Refine feeds the next Plan. Plan and Refine are about his LISTS;
// Pack and Review are about ONE trip.

extension Library {
    public enum LoopStep: Int, Sendable, CaseIterable {
        case plan, pack, review, refine

        public var name: String {
            switch self {
            case .plan: return "Plan"
            case .pack: return "Pack"
            case .review: return "Review"
            case .refine: return "Refine"
            }
        }

        /// Pack and Review are about one trip; Plan and Refine about the lists.
        public var aboutOneTrip: Bool { self == .pack || self == .review }
    }

    /// Where a trip stands in the loop. Reviewed: what it taught now waits in
    /// Refine. Over and not reviewed: Review. No lines yet: still Plan. Otherwise
    /// it is being packed — all ticked or not, until the trip is over.
    public func loopStep(tripId: String, today: String) -> LoopStep {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return .plan }
        if trip.status == "done" || !trip.reviewedAt.isEmpty { return .refine }
        let end = trip.endDate.isEmpty ? trip.startDate : trip.endDate
        if !end.isEmpty, end < today { return .review }
        if trip.entries.isEmpty { return .plan }
        return .pack
    }
}
