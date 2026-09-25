import SwiftUI
import PackingCore
import PackingLibrary

/// All his grab lists: the six on Home, in his order, and the rest waiting on the
/// shelf with everything they hold. Nothing here deletes a list by making room —
/// a list that steps back off Home keeps its things and waits.
struct GrabShelfScreen: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    /// When Home is full and he wants another one on it: which one steps back?
    @State private var swappingIn: String?
    @State private var problem = ""

    var body: some View {
        let home = model.library.homeGrabLists()
        let shelved = model.library.shelvedGrabLists()
        VStack(spacing: 0) {
            HStack {
                Text("Your grab lists").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.home.color)
                    .accessibilityIdentifier("shelf-done")
            }
            .padding(16)

            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 8) {
                    if !problem.isEmpty {
                        Text(problem).font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppSection.actions.color)
                            .accessibilityIdentifier("shelf-problem")
                    }

                    Text("On Home · \(home.count) of \(GRAB_HOME_SLOTS)")
                        .font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("shelf-home-heading")
                    ForEach(Array(home.enumerated()), id: \.element.id) { n, list in
                        row(list, n: n, onHome: true, count: home.count)
                    }

                    Text("Waiting · \(shelved.count)")
                        .font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted)
                        .padding(.top, 14)
                        .accessibilityIdentifier("shelf-waiting-heading")
                    if shelved.isEmpty {
                        Text("Nothing waiting. A new list starts here.")
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                    }
                    ForEach(Array(shelved.enumerated()), id: \.element.id) { n, list in
                        row(list, n: n, onHome: false, count: home.count)
                    }

                    Text("A list that steps back off Home keeps everything on it — nothing here throws a list away.")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }

            HStack(spacing: 8) {
                TextField("A new grab list", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("shelf-new-name")
                Button { add() } label: {
                    Text("Make").font(.system(size: 16, weight: .bold))
                        .foregroundStyle(jsTrim(newName).isEmpty ? Theme.muted : Color.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(jsTrim(newName).isEmpty ? Theme.line : AppSection.home.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .disabled(jsTrim(newName).isEmpty)
                .accessibilityIdentifier("shelf-new")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
        // Home is full: he says which one steps back, never the app.
        .sheet(item: Binding(get: { swappingIn.map { Swapping(id: $0) } }, set: { swappingIn = $0?.id })) { coming in
            SwapScreen(comingIn: coming.id).environmentObject(model)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shelf-detail")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
    }

    @ViewBuilder
    private func row(_ list: GrabDefinition, n: Int, onHome: Bool, count: Int) -> some View {
        if onHome {
            homeRow(list, n: n, count: count)
        } else {
            // The whole row is the button: tap a waiting list to put it on Home.
            Button { bringOn(list.id) } label: {
                HStack(spacing: 10) {
                    GrabDoodle(icon: list.icon, size: 30, initial: list.label).foregroundStyle(GrabTone.color(list.tone))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(list.label).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                        Text("\(list.items.count) thing\(list.items.count == 1 ? "" : "s")")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    pill("On Home", filled: true)
                }
                .padding(.horizontal, 12).frame(minHeight: 54)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shelf-waiting-\(n)")
            .accessibilityLabel("\(list.label), \(list.items.count) things. Put it on Home")
        }
    }

    @ViewBuilder
    private func homeRow(_ list: GrabDefinition, n: Int, count: Int) -> some View {
        HStack(spacing: 10) {
            GrabDoodle(icon: list.icon, size: 30, initial: list.label).foregroundStyle(GrabTone.color(list.tone))
            VStack(alignment: .leading, spacing: 1) {
                Text(list.label).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text("\(list.items.count) thing\(list.items.count == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            Group {
                Button { move(list.id, by: -1) } label: { chevron("M6 14l6-6 6 6", on: n > 0) }
                    .buttonStyle(.plain).focusEffectDisabled().disabled(n == 0)
                    .accessibilityIdentifier("shelf-up-\(n)").accessibilityLabel("Move \(list.label) earlier")
                Button { move(list.id, by: 1) } label: { chevron("M6 10l6 6 6-6", on: n < count - 1) }
                    .buttonStyle(.plain).focusEffectDisabled().disabled(n >= count - 1)
                    .accessibilityIdentifier("shelf-down-\(n)").accessibilityLabel("Move \(list.label) later")
                Button { takeOff(list.id) } label: { pill("Off Home", filled: false) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("shelf-off-\(n)")
                    .accessibilityLabel("Take \(list.label) off Home; it waits with everything on it")
            }
        }
        .padding(.horizontal, 12).frame(minHeight: 54)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shelf-home-\(n)")
    }

    private func pill(_ words: String, filled: Bool) -> some View {
        Text(words).font(.system(size: 13, weight: .heavy))
            .foregroundStyle(filled ? .white : Theme.muted)
            .padding(.horizontal, 10).frame(minHeight: 28)
            .background(Capsule().fill(filled ? AppSection.home.color : Theme.bg))
            .overlay(Capsule().stroke(Theme.line, lineWidth: filled ? 0 : 1))
            .contentShape(Capsule())
    }

    private func chevron(_ path: String, on: Bool) -> some View {
        SVGPath.path(path).stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .frame(width: 20, height: 20)
            .foregroundStyle(on ? Theme.muted : Theme.line)
            .frame(width: 34, height: 36).contentShape(Rectangle())
    }

    private func add() {
        let name = jsTrim(newName)
        guard !name.isEmpty else { return }
        model.change { _ = $0.addGrabList(label: name) }
        newName = ""
        problem = "\(name) is waiting. Put it on Home when you want it there."
    }

    private func move(_ id: String, by step: Int) {
        var ids = model.library.homeGrabLists().map(\.id)
        guard let n = ids.firstIndex(of: id), ids.indices.contains(n + step) else { return }
        ids.swapAt(n, n + step)
        model.change { _ = $0.setHomeGrabLists(ids) }
    }

    private func takeOff(_ id: String) {
        let ids = model.library.homeGrabLists().map(\.id).filter { $0 != id }
        model.change { _ = $0.setHomeGrabLists(ids) }
        problem = ""
    }

    private func bringOn(_ id: String) {
        let ids = model.library.homeGrabLists().map(\.id)
        if ids.count < GRAB_HOME_SLOTS {
            model.change { _ = $0.setHomeGrabLists(ids + [id]) }
            problem = ""
        } else {
            swappingIn = id            // full: he says which one steps back
        }
    }

    private struct Swapping: Identifiable { let id: String }
}

/// Home is full. Which of the six steps back to the shelf?
struct SwapScreen: View {
    let comingIn: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let home = model.library.homeGrabLists()
        let coming = model.library.allGrabLists().first { $0.id == comingIn }
        VStack(spacing: 0) {
            HStack {
                Text("Which one steps back?").font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.home.color)
                    .accessibilityIdentifier("swap-cancel")
            }
            .padding(16)
            Text("Home holds six. \(coming?.label ?? "The new list") takes the place of the one you pick — and the one that steps back keeps everything on it.")
                .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                .padding(.horizontal, 16).padding(.bottom, 8)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(home.enumerated()), id: \.element.id) { n, list in
                        Button {
                            var ids = home.map(\.id)
                            ids[n] = comingIn
                            model.change { _ = $0.setHomeGrabLists(ids) }
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                GrabDoodle(icon: list.icon, size: 28, initial: list.label).foregroundStyle(GrabTone.color(list.tone))
                                Text(list.label).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(list.items.count)").font(.system(size: 15, weight: .bold).monospacedDigit())
                                    .foregroundStyle(Theme.muted)
                            }
                            .padding(.horizontal, 12).frame(minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("swap-\(n)")
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("swap-detail")
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }
}
