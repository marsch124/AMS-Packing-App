import SwiftUI
import PackingCore
import PackingLibrary

/// One bag's own page — his asks (2026-09-26): rename a bag, delete a bag, and "see
/// or get more information about the bags". His choices: a rename reaches every
/// trip; a delete first moves the bag's things to a bag he picks; the page shows
/// everything — its numbers, the things usually in it, its trips, and its details
/// as a thing.
struct BagDetail: View {
    let bagId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: String?
    @State private var problem = ""
    @State private var maxKg = ""
    @State private var litres = ""
    @State private var empty = ""
    @State private var allThings = false
    @State private var askingToDelete = false
    /// Where the bag's things go on a delete: nil = not chosen yet, "" = no bag.
    @State private var moveTo: String?
    /// What Delete was missing when pressed too early, said under it.
    @State private var deleteNeeds = ""
    @State private var opened: Opened?

    /// One sheet, several destinations (the Search lesson: several sheets on one view).
    enum Opened: Identifiable {
        case thing(String)
        var id: String { switch self { case .thing(let id): return id } }
    }

    var body: some View {
        let bag = model.library.bags().first { $0.id == bagId }
        VStack(spacing: 0) {
            if let bag {
                let facts = model.library.bagFacts(name: bag.name)
                header(bag)
                KeyboardAwayScroll {
                    VStack(alignment: .leading, spacing: 18) {
                        numbers(bag)
                        cabinSwitch(bag)
                        thingsInIt(facts)
                        trips(facts)
                        detailsDoor(bag)
                        deleteBag(bag, facts)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 24)
                }
            } else {
                // Deleted (or never there): nothing to show — close.
                Color.clear.onAppear { dismiss() }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $opened) { o in
            switch o {
            case .thing(let id): ThingEditor(itemId: id).environmentObject(model)
            }
        }
        .onAppear {
            guard let bag else { return }
            maxKg = bag.maxKg > 0 ? BagsScreen.show(bag.maxKg) : ""
            litres = bag.capacityL > 0 ? BagsScreen.show(bag.capacityL) : ""
            empty = bag.weight > 0 ? String(Int(bag.weight.rounded())) : ""
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bag-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }

    // MARK: The name

    private func header(_ bag: Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                // The name is the field — press it, type, Rename.
                TextField("", text: Binding(get: { renaming ?? bag.name }, set: { renaming = $0; problem = "" }))
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .heavy)).foregroundStyle(AppSection.care.color)
                    .onSubmit { rename(bag) }
                    .accessibilityIdentifier("bag-name")
                if let wanted = renaming, jsTrim(wanted) != bag.name {
                    Button { rename(bag) } label: {
                        Text("Rename").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(minHeight: 34)
                            .background(Capsule().fill(AppSection.care.color))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("bag-rename")
                }
                Spacer(minLength: 4)
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.care.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("bag-done")
            }
            if !problem.isEmpty {
                Text(problem).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .accessibilityIdentifier("bag-problem")
            }
        }
        .padding(16)
    }

    private func rename(_ bag: Item) {
        guard let wanted = renaming else { return }
        var ok = false
        model.change { ok = $0.renameThing(id: bag.id, to: wanted) }
        if ok { renaming = nil; problem = "" }
        else { problem = jsTrim(wanted).isEmpty ? "A bag needs a name." : "You already have something called that." }
    }

    // MARK: Numbers — saved as typed (the 0.25 lesson)

    private func numbers(_ bag: Item) -> some View {
        HStack(spacing: 10) {
            number("Max kg", $maxKg, now: bag.maxKg, id: "bag-detail-maxkg") { v in
                model.change { _ = $0.setBag(id: bag.id, maxKg: v) }
            }
            number("Litres", $litres, now: bag.capacityL, id: "bag-detail-litres") { v in
                model.change { _ = $0.setBag(id: bag.id, capacityL: v) }
            }
            number("Empty g", $empty, now: bag.weight, id: "bag-detail-empty") { v in
                model.change { _ = $0.setBag(id: bag.id, emptyGrams: v) }
            }
        }
    }

    private func number(_ title: String, _ text: Binding<String>, now: Double, id: String,
                        commit: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.system(size: 11, weight: .heavy)).kerning(0.4).foregroundStyle(Theme.muted)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                .onChange(of: text.wrappedValue) { _, typed in
                    let clean = jsTrim(typed).replacingOccurrences(of: ",", with: ".")
                    let value = clean.isEmpty ? 0 : (Double(clean) ?? now)
                    if value != now { commit(value) }
                }
                .accessibilityIdentifier(id)
        }
    }

    // MARK: The cabin — a plane trip checks this bag (his idea 4, 2 Oct 2026)

    private func cabinSwitch(_ bag: Item) -> some View {
        let thing = model.library.items.first { $0.id == bag.id } ?? bag
        return Toggle(isOn: Binding(get: { Library.isCabinBag(thing) },
                                    set: { on in model.change { _ = $0.setBagCabin(id: bag.id, on) } })) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Goes in the cabin").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("Carry-on. On a plane trip, the trip checks it for liquids and things not allowed on board.")
                    .font(.system(size: 14)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(AppSection.care.color)
        .accessibilityIdentifier("bag-detail-cabin")
    }

    // MARK: What goes in it

    private func thingsInIt(_ facts: Library.BagFacts) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            heading("Usually in it", count: facts.things.count, id: "bag-things-count")
            if facts.things.isEmpty {
                quiet("Nothing yet. A thing goes here when its \u{201C}Usually packed in\u{201D} is this bag.")
            }
            let shown = allThings ? facts.things : Array(facts.things.prefix(12))
            ForEach(Array(shown.enumerated()), id: \.element.id) { i, thing in
                Button { opened = .thing(thing.id) } label: {
                    HStack {
                        Text(thing.name).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink).lineLimit(1)
                        Spacer(minLength: 8)
                        if thing.weight > 0 {
                            Text(BagsCard.kilos(thing.weight)).font(.system(size: 14).monospacedDigit()).foregroundStyle(Theme.muted)
                        }
                    }
                    .frame(minHeight: 36).contentShape(Rectangle())
                    .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("bag-thing-\(i)")
            }
            if facts.things.count > 12 {
                Button(allThings ? "Show fewer" : "Show all \(facts.things.count)") { allThings.toggle() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("bag-things-all")
            }
        }
    }

    // MARK: Where it has been

    private func trips(_ facts: Library.BagFacts) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            heading("On your trips", count: facts.trips.count, id: "bag-trips-count")
            if facts.trips.isEmpty { quiet("Not packed on a trip yet.") }
            ForEach(Array(facts.trips.prefix(8).enumerated()), id: \.offset) { i, t in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(t.name).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink).lineLimit(1)
                        Text(t.date).font(.system(size: 13).monospacedDigit()).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    Text(t.limitKg > 0 ? "\(BagsCard.kilos(t.grams)) / \(BagsCard.number(t.limitKg)) kg" : BagsCard.kilos(t.grams))
                        .font(.system(size: 15, weight: .bold).monospacedDigit())
                        .foregroundStyle(t.over ? AppSection.actions.color : Theme.muted)
                }
                .frame(minHeight: 40)
                .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("bag-trip-\(i)")
            }
            if let top = facts.heaviest, facts.trips.count > 1 {
                Text("Heaviest: \(BagsCard.kilos(top.grams)) on \(top.name)")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("bag-heaviest")
            }
        }
    }

    // MARK: Its details as a thing

    private func detailsDoor(_ bag: Item) -> some View {
        Button { opened = .thing(bag.id) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Its details").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("Kept at home, condition, brand, colour, notes")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer()
                SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 24, height: 24).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 14).frame(minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("bag-details")
    }

    // MARK: Deleting — small, at the side, and it asks where the things go

    @ViewBuilder private func deleteBag(_ bag: Item, _ facts: Library.BagFacts) -> some View {
        let others = model.library.bags().filter { $0.id != bag.id }
        // A bag nothing is packed in has nothing to move — a plain "Delete?" (his
        // ask, 2026-09-27, about his empty Handbag).
        let used = model.library.bagIsUsed(name: bag.name)
        // It may ALSO be a thing he packs — his Day pack on Travel (2026-09-27). Then
        // he chooses each time: stop it being a bag only, or delete it completely.
        let lists = model.library.listsHoldingBag(id: bag.id)
        if askingToDelete {
            VStack(alignment: .leading, spacing: 10) {
                Text("Delete \u{201C}\(bag.name)\u{201D}?")
                    .font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.ink)
                if !used {
                    Text("Nothing is packed in the \(bag.name), so nothing needs to move.")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("bag-delete-empty")
                } else {
                    // His words (2026-09-27): "any item that previously was designated to be
                    // packed in this item should be moved to another item" — or to none.
                    Text(facts.things.isEmpty
                         ? "Anything packed in the \(bag.name) will be packed in another bag instead. Choose which one, or no bag:"
                         : "The \(facts.things.count) thing\(facts.things.count == 1 ? "" : "s") packed in the \(bag.name) will be packed in another bag instead. Choose which one, or no bag:")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("bag-delete-explain")
                    FlowRow(spacing: 6) {
                        ForEach(Array(others.enumerated()), id: \.element.id) { i, other in
                            choice(other.name, on: moveTo == other.name, id: "bag-move-\(i)") { moveTo = other.name; deleteNeeds = "" }
                        }
                        choice("No bag", on: moveTo == "", id: "bag-move-none") { moveTo = ""; deleteNeeds = "" }
                    }
                }
                if !lists.isEmpty {
                    Text("The \(bag.name) is also on your \(BagDetail.names(lists)) template\(lists.count == 1 ? "" : "s"), as something you pack.")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("bag-delete-lists")
                }
                let ready = !used || moveTo != nil
                HStack(spacing: 10) {
                    Button("Keep it") { askingToDelete = false; moveTo = nil; deleteNeeds = "" }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("bag-delete-no")
                    Spacer()
                    if !ready {
                        // Full colour like every main button (his rule); pressed before a
                        // bag is chosen, it says so under it. It was a faded "Choose
                        // first" that did nothing (the spec pass, 5 Oct 2026).
                        deleteButton("Delete", id: "bag-delete-yes", filled: true) {
                            deleteNeeds = "Choose where its things go first \u{2014} another bag, or No bag."
                        }
                    } else if lists.isEmpty {
                        deleteButton(!used ? "Delete the bag" : moveTo == "" ? "Delete, no bag" : "Move and delete",
                                     id: "bag-delete-yes", filled: true) { delete(bag, completely: false, used: used) }
                    }
                }
                if !deleteNeeds.isEmpty {
                    Text(deleteNeeds)
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(AppSection.actions.color)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("bag-delete-needs")
                }
                if ready && !lists.isEmpty {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        deleteButton(lists.count == 1 ? "Keep it on \(lists[0])" : "Keep it on my templates",
                                     id: "bag-delete-yes", filled: false) { delete(bag, completely: false, used: used) }
                        deleteButton("Delete completely", id: "bag-delete-all", filled: true) {
                            delete(bag, completely: true, used: used)
                        }
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.actions.color, lineWidth: 1))
        } else {
            SmallDeleteButton(title: "Delete bag", id: "bag-delete") { askingToDelete = true }
        }
    }

    private func delete(_ bag: Item, completely: Bool, used: Bool) {
        let target = used ? (moveTo ?? "") : "", id = bag.id
        dismiss()
        model.change { _ = $0.deleteBag(id: id, moveTo: target, completely: completely) }
    }

    private func deleteButton(_ title: String, id: String, filled: Bool,
                              _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(filled ? Color.white : AppSection.actions.color)
                .padding(.horizontal, 14).frame(minHeight: 40)
                .background(Capsule().fill(filled ? AppSection.actions.color : Color.clear))
                .overlay(Capsule().stroke(AppSection.actions.color, lineWidth: filled ? 0 : 1.5))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }

    /// "Travel", "Travel and Swim", "Travel, Swim and Run".
    static func names(_ lists: [String]) -> String {
        guard lists.count > 1 else { return lists.first ?? "" }
        return lists.dropLast().joined(separator: ", ") + " and " + (lists.last ?? "")
    }

    private func choice(_ title: String, on: Bool, id: String, _ pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            Text(title).font(.system(size: 14, weight: on ? .bold : .semibold))
                .foregroundStyle(on ? Color.white : Theme.ink)
                .padding(.horizontal, 10).frame(minHeight: 32)
                .background(Capsule().fill(on ? AppSection.care.color : Theme.bg))
                .overlay(Capsule().stroke(on ? AppSection.care.color : Theme.line, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Pieces

    private func heading(_ title: String, count: Int, id: String) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 17, weight: .heavy)).foregroundStyle(Theme.ink)
            Text("\(count)").font(.system(size: 15, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.muted)
                .accessibilityIdentifier(id)
        }
    }

    private func quiet(_ text: String) -> some View {
        Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}
