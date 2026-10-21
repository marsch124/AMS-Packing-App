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
// the page in ONE change when the page is left with Done, and before anything that needs it written
// first (Duplicate, Its details). Moving from field to field and scrolling write nothing. Since 0.92
// the ledger holds a bag page's pills, switches and a name taken with Rename too, and Cancel
// (`close`) forgets all of it; a write the store refuses leaves everything held, for the next try
// (0.94). Since 0.98 (the Apple way, his decision of 21 Oct 2026) it holds a bag page's pocket
// changes as well (`step`), and a bag page writes NOTHING when the app goes away: the ledger lives
// in memory — still there when he comes back to the app, gone when the app is swiped away or ends.
// Your bags (Done only, no Cancel) still writes its rows when the app goes to the background.

/// What is typed on a page and not written yet: per field, the words and how to write them. Not
/// observed (no screen redraws when it changes) — it is a ledger, read when the page writes.
@MainActor
final class EditDraft {
    private var pending: [String: (text: String, write: (String, inout Library) -> Void)] = [:]
    /// The order fields were typed in, so a write applies them as typed.
    private var order: [String] = []
    /// Changes that are not one field's words (0.98: a bag's pockets — an Add, a rename, a move, a
    /// ✕), each applied in turn after the fields, in the order they were made.
    private var steps: [(inout Library) -> Void] = []

    /// A bag's name typed and not renamed yet — renamed by Duplicate first, never by leaving
    /// (a swipe leaves a typed name unrenamed, as before).
    var typedName: String? {
        didSet { if typedName != nil { heldSomething() } }
    }

    /// Told once, the first time the page holds something (0.92): the page then knows a swipe down
    /// must ask first — without a redraw on every key, which the ledger exists to avoid.
    var onFirstHold: (() -> Void)?
    private func heldSomething() {
        guard let told = onFirstHold else { return }
        onFirstHold = nil
        told()
    }

    /// Cancel (0.92): the page is closing and writes nothing — a field that hands its words in as
    /// it gives up the keys on the way out (the Mac's do) is not taken any more.
    private(set) var closed = false

    var isEmpty: Bool { pending.isEmpty && steps.isEmpty }
    func isPending(_ key: String) -> Bool { pending[key] != nil }

    /// A field typed: `differs` false (it says what is kept) takes it off the ledger.
    func typed(_ key: String, _ text: String, differs: Bool, write: @escaping (String, inout Library) -> Void) {
        guard !closed else { return }
        guard differs else { drop(key); return }
        if pending[key] == nil { order.append(key) }
        pending[key] = (text, write)
        heldSomething()
    }

    func drop(_ key: String) {
        pending[key] = nil
        order.removeAll { $0 == key }
    }

    /// A change held as a step (0.98: a pocket added, renamed, moved or removed) — written with the
    /// fields, after them, by Done (or first by Duplicate and Its details); Cancel forgets it.
    func step(_ write: @escaping (inout Library) -> Void) {
        guard !closed else { return }
        steps.append(write)
        heldSomething()
    }

    /// Forget everything held — the bag is being deleted. A name typed too.
    func discard() { pending = [:]; order = []; steps = []; typedName = nil }

    /// Cancel (0.92): forget everything held, and take nothing more.
    func close() { discard(); closed = true }

    /// Apply everything typed to a library being changed — inside a change that does more
    /// (Duplicate). The ledger is empty afterwards (a name typed and not taken stays, for Done).
    func apply(to lib: inout Library) {
        let todo = order.compactMap { pending[$0] }, then = steps
        pending = [:]; order = []; steps = []
        for (text, write) in todo { write(text, &lib) }
        for write in then { write(&lib) }
    }

    /// Write everything typed, in one change. Nothing typed = nothing written. false (0.94): the
    /// store refused it — everything stays held, for Done to try again.
    @discardableResult
    func flush(_ model: LibraryModel) -> Bool {
        guard !isEmpty else { return true }
        let n = order.count, started = EditTiming.now
        let kept = writing(model) { _ in }
        EditTiming.flushed(n, EditTiming.now - started)
        return kept
    }

    /// Everything held and `also`, in ONE change (Duplicate, a bag added on Your bags). The store
    /// refused it (0.94, the empty bag name of 0.93's report): everything is held again as it was —
    /// what was typed is not lost with the failed save.
    @discardableResult
    func writing(_ model: LibraryModel, also: (inout Library) -> Void) -> Bool {
        let held = (pending, order, steps)
        let kept = model.change { lib in
            apply(to: &lib)
            also(&lib)
        }
        if !kept && !closed { pending = held.0; order = held.1; steps = held.2 }
        return kept
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
    /// Your bags only (a list with Done and no Cancel — what is typed in its rows counts as kept):
    /// write the ledger when the app goes to the background — on the iPhone it may be closed there
    /// without another word — and when the Mac app quits with the list open. Never for a glance at
    /// Control Center, the app merely INACTIVE (0.94). A page with Cancel does not use it since 0.98:
    /// what it holds is kept by Done alone (the Apple way, his decision of 21 Oct 2026).
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
            .onChange(of: phase) { _, now in if now == .background { draft.flush(model) } }
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

// MARK: - A page's copy of the library (0.92, Cancel everywhere)
//
// His words, 19 Oct 2026: "I open an item and change some property. How do I cancel that? There is
// only a Done button, right?" — and "the cancel function should be existing throughout the whole
// app right?" A page whose controls change the library at once — a template's page, Your choices —
// now works on a COPY of the library while it is open: everything on it (and on the pages opened
// from it) changes the copy. Done hands over what the page changed (`Library.applyingPage` — only
// the fields it touched, so the other device's changes meanwhile stay); Cancel, Escape and a swipe
// down throw the copy away.
//
// The app put away with the page open — the Apple way (0.98, his decision of 21 Oct 2026: "Yes, go
// with the Apple way for Cancel/Done: remove the keep-on-close from the template page, your lists and
// the bag page"), as Calendar's, Contacts' and Reminders' edit sheets: the copy lives in memory, so
// switching to another app and back finds the page open with everything changed on it; the app swiped
// away (or ended, or the Mac app quit) keeps NOTHING of it — a row whose own Save was pressed included,
// that Save writes into the copy. Only Done keeps. (0.94 to 0.97 handed the page over as the app went
// to the background; he found a template's new name kept that he never confirmed with Done.)

/// The copy a page works on, and the real library it came from (spec 06 §20a).
@MainActor
final class PageDraft: ObservableObject {
    let live: LibraryModel
    /// What the page and everything opened from it see as "the library".
    let copy: LibraryModel
    /// The library as the page opened.
    let opened: Library

    init(live: LibraryModel) {
        self.live = live
        self.opened = live.library
        self.copy = LibraryModel(copyOf: live)
    }

    /// Has anything on the page changed?
    var changed: Bool { copy.library != opened }

    /// Done: what the page changed, in one change of the real library. Nothing changed = nothing
    /// written. false (0.94): the store refused it — the page stays open, holding it, for Done again.
    @discardableResult
    func save() -> Bool {
        guard changed else { return true }
        let from = opened, to = copy.library
        guard live.change({ $0 = $0.applyingPage(from: from, to: to) }) else { return false }
        live.library.installLiveChoices()
        return true
    }

    /// The page has gone — after Done, Cancel or a swipe: the "When" steps and conditions in force
    /// are the real library's again (a copy that changed them installed its own while it was open).
    func left() {
        let now = copy.library
        if now.phases != opened.phases || now.shared != opened.shared { live.library.installLiveChoices() }
    }
}

/// A page on its own copy of the library (`PageDraft`): `content` is handed the draft for its Done
/// and Cancel, and sees the copy as its `LibraryModel`.
struct DraftedPage<Content: View>: View {
    @StateObject private var draft: PageDraft
    private let content: (PageDraft) -> Content

    init(live: LibraryModel, @ViewBuilder content: @escaping (PageDraft) -> Content) {
        _draft = StateObject(wrappedValue: PageDraft(live: live))
        self.content = content
    }

    var body: some View {
        content(draft)
            .environmentObject(draft.copy)
            .onDisappear { draft.left() }
    }
}

// MARK: - A swipe down with something changed asks first (0.92, the whole app's rule)
//
// The coordinator's decision for the whole app, per his "the cancel function should be existing
// throughout the whole app": on the iPhone a page that changes something closes on a swipe down while
// nothing is changed; with something changed it holds still and asks — "Discard changes?", Discard
// (red: what Cancel does, nothing kept) or Keep editing — as Notes and Calendar do. Cancel itself
// never asks (it was pressed on purpose); Save, Done and ⌘S keep. Nothing of this on the Mac: its
// sheets are not swiped, and Escape is Cancel. The question is the app's own card (the look of "Take it
// off?"), so the tests find its buttons by their identifiers (spec 06 §20a).

extension View {
    /// `changed`: something on the page is not saved — a swipe down then asks. `holds`: the page holds
    /// still for another reason (a template being arranged) without asking. `keptEarlier` (0.94): part
    /// of the page was kept already — on a bag's page Its details wrote it (since 0.98 the app put
    /// away keeps nothing) — so Discard says that what was kept stays. `discard`: what Discard does —
    /// the page's Cancel.
    func asksBeforeDiscarding(_ changed: Bool, holds: Bool = false, keptEarlier: Bool = false,
                              discard: @escaping () -> Void) -> some View {
        modifier(DiscardAsk(changed: changed, holds: holds, keptEarlier: keptEarlier, discard: discard))
    }
}

private struct DiscardAsk: ViewModifier {
    let changed: Bool
    let holds: Bool
    let keptEarlier: Bool
    let discard: () -> Void
    @State private var asking = false

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .interactiveDismissDisabled(changed || holds)
            .background(SwipeAttempt { if changed { withAnimation(.easeOut(duration: 0.15)) { asking = true } } }
                .frame(width: 0, height: 0).accessibilityHidden(true))
            .overlay { if asking { DiscardCard(keptEarlier: keptEarlier,
                                               keep: { withAnimation(.easeOut(duration: 0.15)) { asking = false } },
                                               discard: { asking = false; discard() }) } }
        #else
        content.interactiveDismissDisabled(holds)
        #endif
    }
}

/// "Discard changes?" in the middle of the page, the rest dimmed — the look of a template's "Take it
/// off?" card: Keep editing (outlined) and Discard (red, filled).
private struct DiscardCard: View {
    let keptEarlier: Bool
    let keep: () -> Void
    let discard: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { keep() }
            VStack(spacing: 14) {
                Text("Discard changes?")
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("discard-question")
                // Part of the page kept already (0.94): saying "is not kept" of all of it would not be true.
                Text(keptEarlier ? "Your latest changes are not kept. What the app kept earlier stays."
                                 : "What you changed on this page is not kept.")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("discard-says")
                HStack(spacing: 12) {
                    Button { keep() } label: { Text("Keep editing") }
                        .buttonStyle(HeaderButtonStyle(tint: Theme.ink, filled: false, stretch: true)).focusEffectDisabled()
                        .accessibilityIdentifier("discard-keep")
                    Button { discard() } label: { Text("Discard") }
                        .buttonStyle(HeaderButtonStyle(tint: AppSection.actions.color, filled: true, stretch: true)).focusEffectDisabled()
                        .accessibilityIdentifier("discard-yes")
                }
                .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("discard-ask")
        }
        .transition(.opacity)
    }
}

#if os(iOS)
/// Hears a swipe down that the sheet held still for (`interactiveDismissDisabled`): UIKit tells the
/// sheet's presentation controller's delegate (`presentationControllerDidAttemptToDismiss`). SwiftUI
/// keeps its own delegate there; this one stands in front of it and passes everything else on.
private struct SwipeAttempt: UIViewControllerRepresentable {
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> Probe { Probe(onAttempt) }
    func updateUIViewController(_ probe: Probe, context: Context) {
        probe.onAttempt = onAttempt
        probe.install()
    }

    final class Probe: UIViewController {
        var onAttempt: () -> Void
        private var relay: Relay?

        init(_ onAttempt: @escaping () -> Void) {
            self.onAttempt = onAttempt
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { nil }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            install()
        }

        /// In front of the delegate of the sheet this page is on — again whenever SwiftUI put its own back.
        func install() {
            var top: UIViewController = self
            while let up = top.parent { top = up }
            guard top.presentingViewController != nil, let sheet = top.presentationController else { return }
            if let mine = sheet.delegate as? Relay, mine === relay { return }
            let r = Relay(passOn: sheet.delegate) { [weak self] in self?.onAttempt() }
            relay = r
            sheet.delegate = r
        }
    }

    final class Relay: NSObject, UIAdaptivePresentationControllerDelegate {
        weak var passOn: UIAdaptivePresentationControllerDelegate?
        let attempted: () -> Void

        init(passOn: UIAdaptivePresentationControllerDelegate?, attempted: @escaping () -> Void) {
            self.passOn = passOn
            self.attempted = attempted
        }

        func presentationControllerDidAttemptToDismiss(_ controller: UIPresentationController) {
            passOn?.presentationControllerDidAttemptToDismiss?(controller)
            attempted()
        }

        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || (passOn?.responds(to: selector) ?? false)
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            if passOn?.responds(to: selector) == true { return passOn }
            return super.forwardingTarget(for: selector)
        }
    }
}
#endif
