import SwiftUI
import PackingCore
import PackingLibrary

/// The lists he authors himself: storage places, owners, packers, conditions and
/// the "When" timeline. They belong to the account, so both devices show the
/// same; an entry still in use cannot be removed by accident.
struct ListsScreen: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var adding: [String: String] = [:]
    /// What each part's Add was missing, said under its field (never a grey button).
    @State private var needs: [String: String] = [:]
    @State private var problem = ""

    private enum Kind: String, CaseIterable {
        case places, owners, people, conditions, phases
        var title: String {
            switch self {
            case .places: return "Storage places"
            case .owners: return "Owners"
            case .people: return "Packers"
            case .conditions: return "Item conditions"
            case .phases: return "\"When\" steps"
            }
        }
        /// What it is, where it is used, what it is good for — his test K.3 (1 Oct
        /// 2026): "a line or two of explanations for each choice … so that this is
        /// totally clear to the user".
        var hint: String {
            switch self {
            case .places: return "Where a thing is kept at home — a cupboard, the garage, the basement. You give a thing its place under Kept at home; a trip sorted by From where then lists what to fetch room by room."
            case .owners: return "Whose a thing is — you, your partner, a child. You pick it under Whose it is on a thing, so on a shared trip everyone sees which things are theirs."
            case .people: return "Who packs a thing. You set it in the All your things table (Packed by), so you can see who is in charge of what."
            case .conditions: return "How worn a thing is: New, Good, Worn, Needs replacing. You set it under Condition on a thing; a thing that needs replacing is suggested on To buy."
            case .phases: return "The steps of packing, from a week ahead to the day you leave. Every thing has its When, and a trip shows its list in this order, step by step."
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your choices").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("choices-title")
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.settings.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.settings.color)
                    .accessibilityIdentifier("lists-done")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 8) {
                    // What this page is, once, at the top (K.3).
                    Text("The words the app offers you as buttons. Add your own with the field under each part; one that is still in use somewhere cannot be removed.")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("choices-intro")
                    if !problem.isEmpty {
                        Text(problem).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                            .accessibilityIdentifier("lists-problem")
                    }
                    ForEach(Kind.allCases, id: \.rawValue) { kind in
                        let entries = entries(kind)
                        // A band, as the editors' headings are — bigger than the rows under
                        // it (field test, 3 Oct 2026: the headings "dominant").
                        HeadingBand(title: kind.title, tint: AppSection.settings.color, id: "choices-heading-\(kind.rawValue)")
                            .padding(.top, 16)
                        Text(kind.hint).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("choices-hint-\(kind.rawValue)")
                        ForEach(Array(entries.enumerated()), id: \.offset) { n, entry in
                            HStack {
                                Text(entry.label).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                                if entry.uses > 0 {
                                    Text("\(entry.uses)").font(.system(size: 14, weight: .bold).monospacedDigit())
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Button { remove(kind, n) } label: {
                                    SVGPath.path("M6 6L18 18M18 6L6 18")
                                        .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                        .frame(width: 22, height: 22).foregroundStyle(Theme.muted)
                                        .frame(width: 40, height: 40).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .accessibilityIdentifier("list-\(kind.rawValue)-remove-\(n)")
                                .accessibilityLabel("Remove \(entry.label)")
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("list-\(kind.rawValue)-row-\(n)")
                            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        }
                        HStack(spacing: 8) {
                            TextField("Add to \(kind.title.lowercased())", text: Binding(
                                get: { adding[kind.rawValue] ?? "" }, set: { adding[kind.rawValue] = $0 }))
                                .textFieldStyle(.plain)
                                .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                                .padding(.horizontal, 12).frame(minHeight: 44)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                                .onSubmit { add(kind) }
                                .accessibilityIdentifier("list-\(kind.rawValue)-add-name")
                            Button { add(kind) } label: { FieldButtonLabel(title: "Add", tint: AppSection.settings.color) }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .accessibilityIdentifier("list-\(kind.rawValue)-add")
                        }
                        .needsLine(Binding(get: { needs[kind.rawValue] ?? "" }, set: { needs[kind.rawValue] = $0 }),
                                   typed: adding[kind.rawValue] ?? "", id: "list-\(kind.rawValue)-add-needs")
                    }
                    Text("These belong to your account, so both your devices show the same.")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted).padding(.top, 14)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lists-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    private func entries(_ kind: Kind) -> [(label: String, key: String, uses: Int)] {
        let uses = model.library.usesOf(kind.rawValue)
        func rows(_ names: [String]) -> [(String, String, Int)] { names.map { ($0, $0, uses[normName($0)] ?? 0) } }
        switch kind {
        case .places: return rows(model.library.storagePlaces()).map { (label: $0.0, key: $0.1, uses: $0.2) }
        case .owners: return rows(model.library.owners()).map { (label: $0.0, key: $0.1, uses: $0.2) }
        case .people: return model.library.people().map { (label: $0.name, key: $0.name, uses: uses[normName($0.name)] ?? 0) }
        case .conditions: return model.library.conditions().map { (label: $0.label, key: $0.id, uses: uses[normName($0.id)] ?? 0) }
        case .phases: return model.library.timeline().map { (label: $0.label, key: $0.id, uses: uses[normName($0.id)] ?? 0) }
        }
    }

    private func add(_ kind: Kind) {
        let name = jsTrim(adding[kind.rawValue] ?? "")
        guard !name.isEmpty else { needs[kind.rawValue] = "Type a name first."; return }
        problem = ""
        model.change { lib in
            switch kind {
            case .places: _ = lib.setNames("places", lib.storagePlaces() + [name])
            case .owners: _ = lib.setNames("owners", lib.owners() + [name])
            case .people: _ = lib.setPeople(lib.people() + [newPerson(name: name, color: PERSON_COLORS[lib.people().count % PERSON_COLORS.count])])
            case .conditions: _ = lib.setConditions(lib.conditions() + [newCondition(name, lib.conditions().map(\.id))])
            case .phases:
                var list = lib.timeline()
                // Its colour from the app's own cover colours: the web app's pick made
                // the eighth step teal (his colour notes: "Not teal"; the spec pass).
                list.append(lib.newStep(named: name))
                _ = lib.setTimeline(list)
            }
        }
        adding[kind.rawValue] = ""
    }

    private func remove(_ kind: Kind, _ n: Int) {
        let all = entries(kind)
        guard n < all.count else { return }
        let entry = all[n]
        guard entry.uses == 0 else {
            problem = "\(entry.label) is still used by \(entry.uses) thing\(entry.uses == 1 ? "" : "s"), so it stays."
            return
        }
        problem = ""
        model.change { lib in
            switch kind {
            case .places: _ = lib.setNames("places", lib.storagePlaces().filter { $0 != entry.key })
            case .owners: _ = lib.setNames("owners", lib.owners().filter { $0 != entry.key })
            case .people: _ = lib.setPeople(lib.people().filter { $0.name != entry.key })
            case .conditions: _ = lib.setConditions(lib.conditions().filter { $0.id != entry.key })
            case .phases: _ = lib.setTimeline(lib.timeline().filter { $0.id != entry.key })
            }
        }
    }
}
