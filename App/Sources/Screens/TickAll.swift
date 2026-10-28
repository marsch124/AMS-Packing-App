import SwiftUI
import PackingCore
import PackingLibrary

// The trip's ticks in bulk (0.79, his decision of 13 Oct 2026). "Tick everything" and "Clear
// every tick" sat at the foot of the trip — "two very risky buttons: in a stressful situation,
// half way packed, pressed by mistake — catastrophe". So Tick everything is gone; Clear every
// tick is a quiet row in Trip settings (`ClearTicksRow`); and a heading's round tick, which
// ticks or unticks a whole group, says what it did and can be taken back (`TickUndoBar`), as
// Clear every tick can.

/// One press that ticked or unticked many lines, and what to say about it — held by the trip
/// screen for its Undo. One at a time: a new press replaces it.
struct TickUndo: Identifiable, Equatable {
    let id = UUID()
    let change: TicksChanged
    let said: String
    /// The press's step in Edit ▸ Undo (0.105): the bar's Undo takes back that step, as ⌘Z does — never
    /// twice — and the bar goes once ⌘Z has taken it back.
    var step: UndoStep.ID?

    /// A heading's round tick on a group: "Ticked 3 in Toiletries" / "Unticked 3 in Toiletries".
    static func heading(_ change: TicksChanged, group: String, step: UndoStep.ID? = nil) -> TickUndo {
        TickUndo(change: change, said: "\(change.checked ? "Ticked" : "Unticked") \(change.count) in \(group)", step: step)
    }

    /// Clear every tick in Trip settings: "Cleared 12 ticks".
    static func cleared(_ change: TicksChanged, step: UndoStep.ID? = nil) -> TickUndo {
        TickUndo(change: change, said: "Cleared \(change.count) tick\(change.count == 1 ? "" : "s")", step: step)
    }
}

/// Under the trip's list, right above "Add a thing", for 6 seconds: what the press did, and
/// Undo, which puts back exactly the ticks it changed (`Library.undo`). It sits BETWEEN the list
/// and the add bar — never over a line — as the to-do list's Undo does (`LineUndoBar`).
struct TickUndoBar: View {
    let undo: TickUndo
    /// Undo was pressed.
    let act: () -> Void
    /// Its 6 seconds are up.
    let gone: () -> Void

    /// How long it is offered: 6 seconds. Under the UI tests `-undoSeconds N` sets it — GitHub's Mac
    /// takes longer than 6 seconds to reach the button (0.79's probe), and a test racing a timer
    /// fails for nothing; one test gives it a few seconds and watches it go.
    static let seconds: Double = {
        let args = ProcessInfo.processInfo.arguments
        guard AMSPackingApp.testing, let n = args.firstIndex(of: "-undoSeconds"), n + 1 < args.count,
              let s = Double(args[n + 1]), s > 0 else { return 6 }
        return s
    }()

    var body: some View {
        HStack(spacing: 10) {
            Text(undo.said)
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("trip-undo-said")
            Spacer(minLength: 8)
            Button(action: act) {
                Text("Undo")
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.events.color)
                    .padding(.horizontal, 14).frame(minHeight: Metrics.chip)
                    .overlay(Capsule().stroke(AppSection.events.color, lineWidth: 1.4))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("trip-undo")
            .accessibilityValue(undo.said)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .padding(.horizontal, 16).padding(.top, 8)
        // A new press is a new id: its own 6 seconds from the start.
        .task(id: undo.id) {
            try? await Task.sleep(for: .seconds(TickUndoBar.seconds))
            if !Task.isCancelled { gone() }
        }
    }
}

/// Clear every tick, in Trip settings (0.79): a quiet row near the bottom — how many are ticked,
/// and a small red "Clear every tick" at the side — only while something is ticked. It asks
/// first, as it always did; Clear the ticks clears at once and hands what it did to the trip,
/// whose Undo can take it back.
struct ClearTicksRow: View {
    let tripId: String
    /// Other answers on Trip settings are changed and not saved: Clear the ticks closes it
    /// without them, as Start it does, so the question says so.
    let unsaved: Bool
    /// Cleared: what changed, for the trip's Undo — Trip settings then closes.
    let cleared: (TicksChanged) -> Void
    @EnvironmentObject var model: LibraryModel
    @State private var asking = false

    var body: some View {
        let lines = model.library.trip(tripId)?.entries ?? []
        let p = progress(lines)
        if p.done > 0 {
            VStack(alignment: .leading, spacing: 0) {
            if asking {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Clear all \(p.done) tick\(p.done == 1 ? "" : "s")?")
                        .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("The list stays as it is. Only the ticks go.")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    if unsaved {
                        Text("Your other changes here are not saved.")
                            .font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                            .accessibilityIdentifier("tripset-clearall-unsaved")
                    }
                    HStack(spacing: 10) {
                        Button("Keep them") { asking = false }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                            .accessibilityIdentifier("tripset-clearall-no")
                        Spacer()
                        Button {
                            asking = false
                            let id = tripId
                            var change: TicksChanged?
                            model.change(named: "Clear Ticks") { change = $0.setEveryTick(false, tripId: id) }
                            if let change { cleared(change) }
                        } label: {
                            Text("Clear the ticks")
                                .font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                                .background(Capsule().fill(AppSection.actions.color))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("tripset-clearall-yes")
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.actions.color, lineWidth: 1))
            } else {
                HStack(spacing: 10) {
                    Text("\(p.done) of \(p.total) ticked")
                        .font(.system(.footnote).monospacedDigit()).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("tripset-clearall-count")
                    Spacer(minLength: 8)
                    Button { asking = true } label: {
                        Text("Clear every tick")
                            .font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                            .padding(.horizontal, 12).frame(minHeight: 30)
                            .overlay(Capsule().stroke(AppSection.actions.color.opacity(0.6), lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("tripset-clearall")
                    .accessibilityValue("\(p.done)")
                }
            }
            }
            .padding(.top, 14)
        }
    }
}
