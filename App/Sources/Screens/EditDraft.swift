import SwiftUI
import PackingCore
import PackingLibrary

// Typing without a wait (0.91). His test sheet on 0.90, 19 Oct 2026, about a bag's page: "There is a
// delay. Once I have entered data, there is a delay if I would like to scroll or move to the next
// data field."
//
// Why it waited: every key in a number field was a whole `LibraryModel.change` — every record of
// the library built again and compared, the store's whole fetch (`StoreSession.save`) — and then
// every screen that shows the library drawn again, the page and the screens under its sheet; a key
// in Notes or a desk field drew the whole page again, and 0.4 s after the last key saved it all.
// Measured on a library of his size (`EditTiming`, spec 05 "0.91 — typing without a wait").
//
// Now: a field keeps what is typed TO ITSELF (`DraftedField`, its own state — a key draws the
// field and nothing else) and puts it in the page's `EditDraft`, which writes everything typed on
// the page in ONE change when the page is left — Done, a swipe down, Escape — or the app goes to
// the background (or, on the Mac, quits), and before anything that needs it written first
// (Duplicate, Its details). Moving from field to field and scrolling write nothing. Since 0.92 the
// ledger holds a bag page's pills, switches and a name taken with Rename too, and Cancel (`discard`)
// forgets all of it.

/// What is typed on a page and not written yet: per field, the words and how to write them. Not
/// observed (no screen redraws when it changes) — it is a ledger, read when the page writes.
@MainActor
final class EditDraft {
    private var pending: [String: (text: String, write: (String, inout Library) -> Void)] = [:]
    /// The order fields were typed in, so a write applies them as typed.
    private var order: [String] = []

    /// A bag's name typed and not renamed yet — renamed by Duplicate first, never by leaving
    /// (a swipe leaves a typed name unrenamed, as before).
    var typedName: String?

    /// Cancel (0.92): the page is closing and writes nothing — a field that hands its words in as
    /// it gives up the keys on the way out (the Mac's do) is not taken any more.
    private(set) var closed = false

    var isEmpty: Bool { pending.isEmpty }
    func isPending(_ key: String) -> Bool { pending[key] != nil }

    /// A field typed: `differs` false (it says what is kept) takes it off the ledger.
    func typed(_ key: String, _ text: String, differs: Bool, write: @escaping (String, inout Library) -> Void) {
        guard !closed else { return }
        guard differs else { drop(key); return }
        if pending[key] == nil { order.append(key) }
        pending[key] = (text, write)
    }

    func drop(_ key: String) {
        pending[key] = nil
        order.removeAll { $0 == key }
    }

    /// Forget everything held — the bag is being deleted. A name typed too.
    func discard() { pending = [:]; order = []; typedName = nil }

    /// Cancel (0.92): forget everything held, and take nothing more.
    func close() { discard(); closed = true }

    /// Apply everything typed to a library being changed — inside a change that does more
    /// (Duplicate). The ledger is empty afterwards (a name typed and not taken stays, for Done).
    func apply(to lib: inout Library) {
        let todo = order.compactMap { pending[$0] }
        pending = [:]; order = []
        for (text, write) in todo { write(text, &lib) }
    }

    /// Write everything typed, in one change. Nothing typed = nothing written.
    func flush(_ model: LibraryModel) {
        guard !isEmpty else { return }
        let n = order.count, started = EditTiming.now
        model.change { apply(to: &$0) }
        EditTiming.flushed(n, EditTiming.now - started)
    }
}

/// A field that keeps what is typed to itself (0.91, `EditDraft`). It shows what is kept until
/// typed in; typed, it shows the typed words and puts them on the page's ledger. It follows what
/// is kept — a change from the other device, or the page's write — whenever nothing typed in it
/// is waiting to be written. `field` draws the actual TextField from the binding it is handed.
struct DraftedField<Field: View>: View {
    let key: String
    /// What is kept, as the field shows it ("" for nothing).
    let kept: String
    let draft: EditDraft
    /// Do these words differ from what is kept (a number "21.0" does not differ from 21)?
    let differs: (String) -> Bool
    let write: (String, inout Library) -> Void
    @ViewBuilder let field: (Binding<String>) -> Field
    /// The words typed; nil = show what is kept.
    @State private var typed: String?

    var body: some View {
        field(Binding(get: { typed ?? kept }, set: { words in
            EditTiming.mark("key")
            typed = words
            draft.typed(key, words, differs: differs(words), write: write)
        }))
        .onChange(of: kept) { _, now in
            guard !draft.isPending(key), let t = typed, t != now else { return }
            typed = nil
        }
    }
}

extension View {
    /// Write the page's ledger when the app goes to the background — on the iPhone it may be
    /// closed there without another word — and when the Mac app quits with the page open.
    func writesDraftWhenAway(_ draft: EditDraft, _ model: LibraryModel) -> some View {
        modifier(DraftAway(draft: draft, model: model))
    }
}

private struct DraftAway: ViewModifier {
    let draft: EditDraft
    let model: LibraryModel
    @Environment(\.scenePhase) private var phase

    func body(content: Content) -> some View {
        content
            .onChange(of: phase) { _, now in if now != .active { draft.flush(model) } }
            #if os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                draft.flush(model)
            }
            #endif
    }
}

/// A number typed as the bag fields take it: trimmed, a comma read as a point; empty is 0; nil for
/// words that are no number (they change nothing).
enum TypedNumber {
    static func read(_ text: String) -> Double? {
        let clean = jsTrim(text).replacingOccurrences(of: ",", with: ".")
        return clean.isEmpty ? 0 : Double(clean)
    }

    /// Does it differ from the number kept? Words that are no number do not.
    static func differs(_ text: String, from now: Double) -> Bool {
        guard let v = read(text) else { return false }
        return v != now
    }
}
