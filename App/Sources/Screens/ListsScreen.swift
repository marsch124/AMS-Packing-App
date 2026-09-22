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
        var hint: String {
            switch self {
            case .places: return "Where a thing lives at home."
            case .owners: return "Whose a thing is."
            case .people: return "Who packs what."
            case .conditions: return "How worn a thing is."
            case .phases: return "The timeline a trip is packed along."
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your lists").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.settings.color)
                    .accessibilityIdentifier("lists-done")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 8) {
                    if !problem.isEmpty {
                        Text(problem).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                            .accessibilityIdentifier("lists-problem")
                    }
                    ForEach(Kind.allCases, id: \.rawValue) { kind in
                        let entries = entries(kind)
                        Text(kind.title).font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted).padding(.top, 14)
                        Text(kind.hint).font(.system(size: 14)).foregroundStyle(Theme.muted)
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
                            Button { add(kind) } label: {
                                Text("Add").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 16).frame(minHeight: 44)
                                    .background(RoundedRectangle(cornerRadius: 10)
                                        .fill(jsTrim(adding[kind.rawValue] ?? "").isEmpty ? Theme.line : AppSection.settings.color))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .disabled(jsTrim(adding[kind.rawValue] ?? "").isEmpty)
                            .accessibilityIdentifier("list-\(kind.rawValue)-add")
                        }
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
        guard !name.isEmpty else { return }
        problem = ""
        model.change { lib in
            switch kind {
            case .places: _ = lib.setNames("places", lib.storagePlaces() + [name])
            case .owners: _ = lib.setNames("owners", lib.owners() + [name])
            case .people: _ = lib.setPeople(lib.people() + [newPerson(name: name, color: PERSON_COLORS[lib.people().count % PERSON_COLORS.count])])
            case .conditions: _ = lib.setConditions(lib.conditions() + [newCondition(name, lib.conditions().map(\.id))])
            case .phases:
                var list = lib.timeline()
                list.append(newPhase(name, list.map(\.id)))
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
