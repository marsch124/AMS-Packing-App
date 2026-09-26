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
    @State private var moveTo = ""
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
            maxKg = bag.maxKg > 0 ? ContainersScreen.show(bag.maxKg) : ""
            litres = bag.capacityL > 0 ? ContainersScreen.show(bag.capacityL) : ""
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
                    .buttonStyle(.plain).focusEffectDisabled()
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
        if askingToDelete {
            VStack(alignment: .leading, spacing: 10) {
                Text("Delete \u{201C}\(bag.name)\u{201D}?")
                    .font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.ink)
                if !others.isEmpty {
                    Text(facts.things.isEmpty ? "Anything on your lists or trips that names it moves to:"
                         : "\(facts.things.count) thing\(facts.things.count == 1 ? "" : "s") usually go\(facts.things.count == 1 ? "es" : "") in it. Move them to:")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    FlowRow(spacing: 6) {
                        ForEach(Array(others.enumerated()), id: \.element.id) { i, other in
                            let on = moveTo == other.name
                            Button { moveTo = other.name } label: {
                                Text(other.name).font(.system(size: 14, weight: on ? .bold : .semibold))
                                    .foregroundStyle(on ? Color.white : Theme.ink)
                                    .padding(.horizontal, 10).frame(minHeight: 32)
                                    .background(Capsule().fill(on ? AppSection.care.color : Theme.bg))
                                    .overlay(Capsule().stroke(on ? AppSection.care.color : Theme.line, lineWidth: 1))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("bag-move-\(i)")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
                HStack(spacing: 10) {
                    Button("Keep it") { askingToDelete = false; moveTo = "" }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("bag-delete-no")
                    Spacer()
                    let ready = others.isEmpty || !moveTo.isEmpty
                    Button {
                        guard ready else { return }
                        let target = moveTo, id = bag.id
                        dismiss()
                        model.change { _ = $0.deleteBag(id: id, moveTo: target) }
                    } label: {
                        Text(others.isEmpty ? "Delete the bag" : (moveTo.isEmpty ? "Choose a bag first" : "Move and delete"))
                            .font(.system(size: 16, weight: .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 14).frame(minHeight: 40)
                            .background(Capsule().fill(AppSection.actions.color.opacity(ready ? 1 : 0.55)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("bag-delete-yes")
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.actions.color, lineWidth: 1))
        } else {
            SmallDeleteButton(title: "Delete bag", id: "bag-delete") { askingToDelete = true }
        }
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
