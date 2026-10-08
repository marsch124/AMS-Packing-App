import SwiftUI

// Drag and drop to reorder his own lists (0.70). His ask, testing 0.69 (8 Oct 2026): "I like
// all the lists now. One can add, rename and reorder. Can we make the reordering easier for
// a human by introducing drag and drop?" Every list with ↑ ↓ gets a grip ≡ on each row —
// the hand-drawn one Arrange uses (`GripMark`): hold it and drag. Since 0.72 the arrows are
// the Mac's only (`ReorderArrows`): there Tab reaches them; the grip is not one of its tools.
//
// ONE way of moving, the arrows' own: as the row is carried past a neighbour's middle it
// takes ONE step with the list's own `move(±1)` — the very call ↑ or ↓ makes — so a drag
// is a row of arrow presses, held until Save in a drop-down, at once in Your choices, as the
// arrows are. The rows move under the finger while it is held; let go, the row settles.
//
// Why not SwiftUI's List with `.onMove` (Arrange's way): a drop-down's list is a popover
// sized by its content, which a List does not give; its rows carry tools (pen, ↑, ↓,
// Remove, a field while renamed, the question before a removal) that a List row's own
// drag would grab with them; and the Mac's List puts a drop at a row's middle BELOW it
// (spec 04 §6a). A gesture on the grip alone keeps the list as it is and works the same
// with a finger and a mouse.

/// Where ↑ ↓ are drawn on a list he orders (0.72). His answer, 8 Oct 2026, to "now that rows
/// can be dragged, should the arrows come off the iPhone?": "Drag and drop on the phone as
/// well." On the iPhone a row is moved by its grip only — the arrows' room goes to the name,
/// so a long one stays on one line — and VoiceOver moves it with the grip's own actions
/// ("Move up", "Move down"). The Mac keeps the arrows: Tab reaches them, the grip it does not.
enum ReorderArrows {
    #if os(macOS)
    static let shown = true
    #else
    static let shown = false
    #endif
}

/// The row being carried: which (its key), how many steps it has taken, and how far the
/// finger is from where the row now stands (the row is drawn there, lifted).
struct ReorderDrag: Equatable {
    var key: String
    var steps = 0
    var dy: CGFloat = 0
}

/// A grip that carries its row. `step`: the row's height — a move of that far is one
/// place. `canMove(±1)` / `move(±1)` are the list's own arrows.
struct ReorderGrip: View {
    let id: String
    let label: String
    let key: String
    let step: CGFloat
    @Binding var drag: ReorderDrag?
    let canMove: (Int) -> Bool
    let move: (Int) -> Void
    /// True while the grip is held. It falls back by itself however the gesture ends —
    /// also when the system CANCELS it, which calls no `onEnded` (the iPhone, 8 Oct 2026:
    /// a kind let go stayed lifted half a row low). Its fall settles the row.
    @GestureState private var holding = false

    var body: some View {
        GripMark(id: id, label: label)
            .accessibilityHint(ReorderArrows.shown ? "Hold and drag to move it; the arrows move it one place"
                                                   : "Hold and drag to move it")
            // VoiceOver's way to move it (the iPhone has no arrows since 0.72): one place a time.
            .accessibilityAction(named: "Move up") { if canMove(-1) { move(-1) } }
            .accessibilityAction(named: "Move down") { if canMove(1) { move(1) } }
            #if os(iOS)
            // Hold, then drag (his words): a plain swipe over the grip still scrolls the list.
            .gesture(LongPressGesture(minimumDuration: 0.2)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                .updating($holding) { _, held, _ in held = true }
                .onChanged { value in
                    switch value {
                    case .first(true): lift()
                    case .second(true, let g?): carry(g.translation.height)
                    case .second(true, nil): lift()
                    default: break
                    }
                }
                .onEnded { _ in settle() })
            .sensoryFeedback(.selection, trigger: drag?.key == key ? drag?.steps ?? 0 : 0)
            #else
            .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .updating($holding) { _, held, _ in held = true }
                .onChanged { g in carry(g.translation.height) }
                .onEnded { _ in settle() })
            #endif
            .onChange(of: holding) { _, now in if !now { settle() } }
    }

    private func lift() {
        if drag?.key != key { drag = ReorderDrag(key: key) }
    }

    /// One step per event at most: the list's `move` reads the list as it was drawn, so the
    /// next step waits for the list to be drawn again (the next event).
    private func carry(_ height: CGFloat) {
        var d = drag?.key == key ? drag! : ReorderDrag(key: key)
        let h = max(step, 12)
        let want = Int((height / h).rounded())
        if want > d.steps, canMove(1) { move(1); d.steps += 1 }
        else if want < d.steps, canMove(-1) { move(-1); d.steps -= 1 }
        // Past the top or the bottom the row stops at the edge, a little give and no more.
        d.dy = min(max(height - CGFloat(d.steps) * h, -h * 0.6), h * 0.6)
        drag = d
    }

    private func settle() {
        guard drag?.key == key else { return }
        withAnimation(.easeOut(duration: 0.15)) { drag = nil }
    }
}

extension View {
    /// The carried row: drawn where the finger is, raised over its neighbours on a card.
    func reorderLift(_ drag: ReorderDrag?, key: String, tint: Color) -> some View {
        let on = drag?.key == key
        return self
            .background {
                if on {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.6), lineWidth: 1))
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                        .padding(.horizontal, -6)
                }
            }
            .offset(y: on ? drag?.dy ?? 0 : 0)
            .zIndex(on ? 1 : 0)
            .animation(on ? nil : .easeOut(duration: 0.15), value: on)
    }

    /// The row's height, kept by its key — one place, for its grip.
    func reorderStep(_ key: String, into steps: Binding<[String: CGFloat]>) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
            if abs((steps.wrappedValue[key] ?? 0) - h) > 0.5 { steps.wrappedValue[key] = h }
        }
    }
}
