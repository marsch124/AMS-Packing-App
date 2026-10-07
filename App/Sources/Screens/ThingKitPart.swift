import SwiftUI
import PackingCore
import PackingLibrary

// Kits on a thing's page (spec 07, part 9; spec 05, "A thing's page", item 11b) — kept
// out of ThingEditor so the page's own code (and the Mac's keys on it) stays its own.
// The page holds a `KitDraft`, shows `ThingKitPart` under Weight, fills the draft when it
// loads a thing and saves it in its Save — four small calls; nothing is stored before
// Save, and Cancel leaves the kit as it was, as everything else on the page.

/// What the page says about kits, until Save.
struct KitDraft: Equatable {
    /// A bag or a to-do: no kit part at all.
    var none = true
    /// What is inside this thing, in his order; which of them are taken out; and Check
    /// before each trip.
    var contents: [String] = []
    var out: Set<String> = []
    var check = false
    /// The kit this thing is inside (it then holds nothing itself), and whether it is
    /// taken out of it for now.
    var holder: String?
    var takenOut = false
    /// The list of his things to add from is open — kept here so the Mac's keys (Space on
    /// Add from your things) open it too; never saved.
    var picking = false
    /// As the page opened — Save writes only what changed.
    private var opened: [String] = []
    private var openedOut: Set<String> = []
    private var openedCheck = false
    private var openedTakenOut = false

    init() {}

    init(_ lib: Library, thingId: String) {
        guard let thing = lib.items.first(where: { $0.id == thingId }) else { return }
        none = thing.itemType == "reminder" || lib.bags().contains { $0.id == thingId }
        guard !none else { return }
        let index = lib.kitIndex()
        holder = index.kitOf(thingId)
        let inside = index.contents[thingId] ?? []
        contents = inside.map(\.thing.id)
        out = Set(inside.filter(\.takenOut).map(\.thing.id))
        check = Library.kitCheck(thing)
        takenOut = holder != nil && lib.isTakenOut(thingId: thingId)
        opened = contents; openedOut = out; openedCheck = check; openedTakenOut = takenOut
    }

    /// Write what changed — called inside the page's own Save.
    func save(_ lib: inout Library, thingId: String) {
        guard !none else { return }
        if contents != opened || out != openedOut || check != openedCheck {
            lib.setKit(kitId: thingId, contents: contents, takenOut: out, check: check)
        }
        if holder != nil, takenOut != openedTakenOut {
            lib.setTakenOut(thingId: thingId, takenOut)
        }
    }
}

/// "Inside" — what a pouch or a kit holds — or, for a thing inside one, "In a kit".
struct ThingKitPart: View {
    let thingId: String
    @Binding var draft: KitDraft
    /// The field the Mac's keys are on (ThingKeys.swift): its control is ringed. nil on the iPhone.
    var ringed: ThingField? = nil
    @EnvironmentObject var model: LibraryModel
    @State private var query = ""

    var body: some View {
        if draft.none {
            EmptyView()
        } else if let holder = draft.holder {
            inKit(holder)
        } else {
            inside
        }
    }

    // MARK: - A thing inside a kit

    private func inKit(_ kitId: String) -> some View {
        let kit = model.library.items.first { $0.id == kitId }?.name ?? ""
        let also = model.library.kitAlsoOn(thingId: thingId)
        return VStack(alignment: .leading, spacing: 6) {
            HeadingBand(title: "In a kit", id: "thing-kit-title")
            Text("Inside the \(kit)")
                .font(.system(.body)).foregroundStyle(Theme.ink)
                .accessibilityIdentifier("thing-kit-inside")
            Toggle(isOn: $draft.takenOut) {
                Text("Taken out for now").font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
            }
            .tint(AppSection.care.color)
            .focusRing(ringed == .kitTakenOut)
            .accessibilityIdentifier("thing-kit-taken-out")
            // A thing ALSO on a template by itself: a trip packs its kit instead (spec 07, part 9).
            if !also.isEmpty {
                Text("Also on \(BagDetail.names(also)) on its own \u{2014} a trip packs the \(kit) instead.")
                    .font(.system(.subheadline)).foregroundStyle(AppSection.care.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("thing-kit-also")
            }
        }
    }

    // MARK: - What it holds

    private var inside: some View {
        let lib = model.library
        let today = Today.local
        let byId = Dictionary(lib.items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let things = draft.contents.compactMap { byId[$0] }
        let own = byId[thingId].map { max(0, $0.weight) } ?? 0
        let total = own + things.filter { !draft.out.contains($0.id) }
            .reduce(0) { $0 + max(0, $1.weight) * effectiveQty($1, 0) }
        return VStack(alignment: .leading, spacing: 6) {
            HeadingBand(title: "Inside", id: "thing-kit-title")
            if things.isEmpty {
                Text("A pouch or a kit? Add the things that stay packed in it.")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("thing-kit-none")
            }
            ForEach(Array(things.enumerated()), id: \.element.id) { n, thing in
                row(thing, n: n, today: today)
            }
            addButton
            if draft.picking { picker(byId) }
            if !things.isEmpty {
                Toggle(isOn: $draft.check) {
                    Text("Check before each trip").font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                }
                .tint(AppSection.care.color)
                .focusRing(ringed == .kitCheck)
                .accessibilityIdentifier("thing-kit-check")
                Text("With what is inside: \(KitDashboard.kilos(total))")
                    .font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("thing-kit-weight")
                    .accessibilityValue(amountText(total))
            }
        }
    }

    /// One thing inside: its name, its weight, what is worth saying about it; Taken out /
    /// Put back, and ✕ to take it out of the kit for good (it stays one of your things).
    private func row(_ thing: Item, n: Int, today: String) -> some View {
        let out = draft.out.contains(thing.id)
        let says = Library.contentWarnings(thing, today: today).map(\.words)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(thing.name)
                    .font(.system(.body)).foregroundStyle(out ? Theme.muted : Theme.ink)
                    .strikethrough(out, color: Theme.muted)
                    .lineLimit(2)
                    .accessibilityIdentifier("thing-kit-row-\(n)")
                    .accessibilityValue(out ? "taken out" : "")
                if thing.weight > 0 {
                    Text(KitDashboard.kilos(thing.weight * effectiveQty(thing, 0)))
                        .font(.system(.footnote).monospacedDigit()).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 6)
                Button {
                    if out { draft.out.remove(thing.id) } else { draft.out.insert(thing.id) }
                } label: {
                    Text(out ? "Put back" : "Take out").font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(AppSection.care.color)
                        .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                        .overlay(Capsule().stroke(AppSection.care.color, lineWidth: 1.2))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("thing-kit-row-\(n)-out")
                Button {
                    draft.contents.removeAll { $0 == thing.id }
                    draft.out.remove(thing.id)
                } label: {
                    ClearMark().frame(width: 24, height: 24)
                        .frame(width: Metrics.compact, height: Metrics.compact).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("thing-kit-row-\(n)-remove")
                .accessibilityLabel("Take \(thing.name) out of the kit")
            }
            if out {
                Text("Taken out").font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.actions.color)
            }
            ForEach(Array(says.enumerated()), id: \.offset) { k, words in
                Text(words).font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .accessibilityIdentifier("thing-kit-row-\(n)-says-\(k)")
            }
        }
        .padding(.vertical, 2)
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }

    private var addButton: some View {
        Button { draft.picking.toggle(); query = "" } label: {
            Text(draft.picking ? "Close the list" : "Add from your things").font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(AppSection.care.color)
                .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                .overlay(Capsule().stroke(AppSection.care.color, lineWidth: 1.4))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .focusRing(ringed == .kitAdd, radius: 14)
        .accessibilityIdentifier("thing-kit-add")
    }

    /// Your things that can go in: not itself, not a bag, not a kit (one level deep), not
    /// what is in it already — A–Z, found by typing. One in another kit says so: it moves.
    private func picker(_ byId: [String: Item]) -> some View {
        let lib = model.library
        let index = lib.kitIndex()
        let q = normName(query)
        let fit = lib.items
            .filter { !draft.contents.contains($0.id) && lib.kitRefusal(thingId: $0.id, kitId: thingId, index: index).isEmpty }
            .filter { q.isEmpty || normName($0.name).contains(q) }
            .stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name, sensitivity: .base) })
        let shown = Array(fit.prefix(ThingKitPart.shownAtOnce))
        return VStack(alignment: .leading, spacing: 0) {
            TextField("Find a thing", text: $query)
                .textFieldStyle(.plain)
                .font(.system(.body)).foregroundStyle(Theme.ink)
                .clearButton($query, id: "thing-kit-search")
                .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .padding(.bottom, 4)
            ForEach(Array(shown.enumerated()), id: \.element.id) { n, thing in
                Button {
                    draft.contents.append(thing.id)
                    query = ""                      // ready for the next one
                } label: {
                    HStack(spacing: 8) {
                        Text(thing.name).font(.system(.body)).foregroundStyle(Theme.ink).lineLimit(1)
                        Spacer(minLength: 6)
                        if let other = index.kitOf(thing.id).flatMap({ byId[$0] }), other.id != thingId {
                            Text("in the \(other.name)").font(.system(.footnote)).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                        Text("Add").font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.care.color)
                    }
                    .frame(maxWidth: .infinity, minHeight: Metrics.compact, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                .accessibilityIdentifier("thing-kit-pick-\(n)")
                .accessibilityLabel(thing.name)
            }
            if fit.count > shown.count {
                Text("\(fit.count - shown.count) more \u{2014} type to find them")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted).padding(.top, 4)
                    .accessibilityIdentifier("thing-kit-more")
            } else if fit.isEmpty {
                Text(q.isEmpty ? "Nothing else can go in it." : "Nothing by that name can go in it.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted).padding(.top, 4)
                    .accessibilityIdentifier("thing-kit-nothing")
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thing-kit-picker")
    }

    /// How many things the list shows before it asks him to type.
    static let shownAtOnce = 8
}
