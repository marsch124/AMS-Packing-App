#if canImport(SwiftData)
import Foundation
import SwiftData

/// What changed in a SwiftData store since the app last looked — so a notification that holds only
/// the app's own saves is not read back (0.91, `CloudStore`). Here, not in the app, so a model test
/// can reach it on a real store file (0.94).
///
/// 0.94 (item 7 of the outside review of 0.92): every read is BOUNDED. Until then the launch read the
/// WHOLE history to find its newest entry — and the history grows with every change for ever — and
/// after one failed read the newest change looked at was forgotten, so every later look read the
/// whole history again. Now the launch asks for the newest transaction alone, each look asks only for
/// what came after the last one, and a failed read finds the newest again (one transaction) instead
/// of forgetting where it was. `CloudStore` calls it off the main thread, on one queue of its own.
///
/// The history itself is never trimmed: iCloud's mirroring reads it too, keeps its own place in it,
/// and nothing says how far back that place is — trimming past it would make iCloud send or fetch
/// everything again. Since every read here is bounded, a long history costs disk space only.
///
/// Not thread-safe: use it from one queue at a time.
@available(iOS 18, macOS 15, *)
public final class StoreHistory {
    private let context: ModelContext
    /// Authors whose changes bring nothing into the library.
    private let quiet: Set<String>
    /// The newest change already looked at; nil while the history held nothing.
    private var seen: DefaultHistoryToken?
    /// `seen` can be trusted: the last read that set it succeeded. False until the launch read and
    /// after a read that failed — the next look then finds the newest change again, and reloads.
    private var found = false
    /// Transactions read so far, every read counted — what the tests measure.
    public private(set) var transactionsRead = 0
    #if DEBUG
    /// The next read of the history fails (the tests).
    public var failNextRead = false
    struct ReadRefusedForTests: Error {}
    #endif

    public init(_ container: ModelContainer, quiet: Set<String>) {
        context = ModelContext(container)
        self.quiet = quiet
    }

    /// At launch: where the history stands now — its newest transaction, and only that.
    public func lookAtLaunch() { findTheNewest() }

    /// True only when the history holds new changes and every one of them is by a quiet author. False
    /// for anything else — another author, no author, nothing new at all, or a history that cannot be
    /// read — so a doubt always reloads.
    public func onlyQuietSinceLastLook() -> Bool {
        guard found else { findTheNewest(); return false }
        var asked = HistoryDescriptor<DefaultHistoryTransaction>()
        if let seen { asked.predicate = #Predicate { $0.token > seen } }
        guard let changes = try? read(asked) else { findTheNewest(); return false }
        if let newest = changes.map(\.token).max() { seen = newest }
        return !changes.isEmpty && changes.allSatisfy { $0.author.map(quiet.contains) ?? false }
    }

    /// `seen` = the newest transaction in the history (nil for an empty one). A read that fails keeps
    /// the old `seen` and leaves `found` false, so the next look tries again — never a read of all.
    private func findTheNewest() {
        do {
            seen = try newest()
            found = true
        } catch {
            found = false
        }
    }

    private func newest() throws -> DefaultHistoryToken? {
        if #available(iOS 26, macOS 26, *) {
            var asked = HistoryDescriptor<DefaultHistoryTransaction>(
                sortBy: [SortDescriptor(\.transactionIdentifier, order: .reverse)])
            asked.fetchLimit = 1
            return try read(asked).first?.token
        }
        // iOS 18–25 and macOS 15 cannot sort the history: the whole of it, as before 0.94 — still off
        // the main thread. (His devices and the tests run 26.)
        return try read(HistoryDescriptor<DefaultHistoryTransaction>()).map(\.token).max()
    }

    private func read(_ asked: HistoryDescriptor<DefaultHistoryTransaction>) throws -> [DefaultHistoryTransaction] {
        #if DEBUG
        if failNextRead { failNextRead = false; throw ReadRefusedForTests() }
        #endif
        let got = try context.fetchHistory(asked)
        transactionsRead += got.count
        return got
    }
}
#endif
