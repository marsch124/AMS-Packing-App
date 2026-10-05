import SwiftUI
import PackingCore
import PackingLibrary

/// Grab Lists (Home's door of that name): the eight on Home, in his order, and the
/// rest waiting here with everything they hold. Nothing here deletes a list by making
/// room — a list that steps back off Home keeps its things and waits.
struct GrabCollectionScreen: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    /// What Make was missing, said under the field (never a grey button).
    @State private var newNeeds = ""
    /// The one window this screen opens over itself: "Which one steps back?" when
    /// Home is full and he wants another one on it, or a waiting list opened to tick
    /// or fill it. ONE sheet with a destination — SwiftUI does not reliably present a
    /// second sheet from a view while the first is still closing.
    @State private var window: Window?
    /// Where the list he just made went — said plainly, not as a problem. It used
    /// to say "<name> is waiting", in red, even when the list had gone straight onto
    /// Home (4 Oct 2026).
    @State private var made = ""

    var body: some View {
        let home = model.library.homeGrabLists()
        let waiting = model.library.waitingGrabLists()
        VStack(spacing: 0) {
            HStack {
                Text("Your grab lists").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.home.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.home.color)
                    .accessibilityIdentifier("grablists-done")
            }
            .padding(16)

            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 8) {
                    if !made.isEmpty {
                        Text(made).font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("grablists-made")
                    }

                    Text("On Home · \(home.count) of \(GRAB_HOME_SLOTS)")
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("grablists-home-heading")
                    ForEach(Array(home.enumerated()), id: \.element.id) { n, list in
                        row(list, n: n, onHome: true, count: home.count)
                    }

                    Text("Waiting · \(waiting.count)")
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                        .padding(.top, 14)
                        .accessibilityIdentifier("grablists-waiting-heading")
                    if waiting.isEmpty {
                        // Where a new list goes depends on whether Home has room.
                        Text(home.count < GRAB_HOME_SLOTS ? "Nothing waiting. A new list goes straight onto Home."
                                                          : "Nothing waiting. A new list waits here while Home is full.")
                            .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    }
                    ForEach(Array(waiting.enumerated()), id: \.element.id) { n, list in
                        row(list, n: n, onHome: false, count: home.count)
                    }

                    Text("A list that steps back off Home keeps everything on it — nothing here throws a list away.")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }

            HStack(spacing: 8) {
                TextField("A new grab list", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("grablists-new-name")
                Button { add() } label: { FieldButtonLabel(title: "Make", tint: AppSection.home.color) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("grablists-new")
            }
            .needsLine($newNeeds, typed: newName, id: "grablists-new-needs")
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $window) { window in
            switch window {
            // Home is full: he says which one steps back, never the app. Once it has,
            // the list he made is on Home, and "waits below" would no longer be true
            // (it stayed until 5 Oct 2026).
            case .swap(let id): SwapScreen(comingIn: id, picked: { made = "" }).environmentObject(model)
            case .open(let id): GrabScreen(listId: id).environmentObject(model)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("grablists-detail")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
    }

    @ViewBuilder
    private func row(_ list: GrabDefinition, n: Int, onHome: Bool, count: Int) -> some View {
        if onHome {
            homeRow(list, n: n, count: count)
        } else {
            // A waiting list opens on a tap, like a tile on Home — to tick it, fill it
            // or delete it without first sending another list off Home (5 Oct 2026:
            // the whole row was the On Home button, and only the Action button's menu
            // or a Shortcut could open a waiting list). On Home is its own button.
            HStack(spacing: 8) {
                Button { window = .open(list.id) } label: {
                    HStack(spacing: 10) {
                        GrabDoodle(icon: list.icon, size: 30, initial: list.label).foregroundStyle(GrabTone.color(list.tone))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(list.label).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                            Text("\(list.items.count) thing\(list.items.count == 1 ? "" : "s")")
                                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 8)
                    }
                    .frame(minHeight: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("grablists-waiting-\(n)")
                .accessibilityLabel("\(list.label), \(list.items.count) things. Open it")
                Button { bringOn(list.id) } label: { pill("On Home", filled: true) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("grablists-on-\(n)")
                    .accessibilityLabel("Put \(list.label) on Home")
            }
            .padding(.horizontal, 12).frame(minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        }
    }

    @ViewBuilder
    private func homeRow(_ list: GrabDefinition, n: Int, count: Int) -> some View {
        HStack(spacing: 10) {
            GrabDoodle(icon: list.icon, size: 30, initial: list.label).foregroundStyle(GrabTone.color(list.tone))
            VStack(alignment: .leading, spacing: 1) {
                Text(list.label).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text("\(list.items.count) thing\(list.items.count == 1 ? "" : "s")")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            Group {
                Button { move(list.id, by: -1) } label: { chevron("M6 14l6-6 6 6", on: n > 0) }
                    .buttonStyle(.plain).focusEffectDisabled().disabled(n == 0)
                    .accessibilityIdentifier("grablists-up-\(n)").accessibilityLabel("Move \(list.label) earlier")
                Button { move(list.id, by: 1) } label: { chevron("M6 10l6 6 6-6", on: n < count - 1) }
                    .buttonStyle(.plain).focusEffectDisabled().disabled(n >= count - 1)
                    .accessibilityIdentifier("grablists-down-\(n)").accessibilityLabel("Move \(list.label) later")
                Button { takeOff(list.id) } label: { pill("Off Home", filled: false) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("grablists-off-\(n)")
                    .accessibilityLabel("Take \(list.label) off Home; it waits with everything on it")
            }
        }
        .padding(.horizontal, 12).frame(minHeight: 54)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("grablists-home-\(n)")
    }

    private func pill(_ words: String, filled: Bool) -> some View {
        Text(words).font(.system(.footnote, weight: .semibold))
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
        guard !name.isEmpty else { newNeeds = "Type a name first."; return }
        // Two tiles with the same word cannot be told apart (5 Oct 2026: Make took any
        // name, a second "Swim" too).
        guard !model.library.grabListNameTaken(name) else {
            newNeeds = "You have a grab list called \(name) already. Give this one another name."
            return
        }
        var list: GrabDefinition?
        model.change { list = $0.addGrabList(label: name) }
        newName = ""
        // A new list takes a free place on Home; only a full Home makes it wait.
        let onHome = list.map { l in model.library.homeGrabLists().contains { $0.id == l.id } } ?? false
        made = onHome ? "\(name) is on Home now. Open it there and press Edit to put things on it."
                      : "\(name) waits below, as Home is full. Tap it to put things on it, or press On Home."
    }

    private func move(_ id: String, by step: Int) {
        var ids = model.library.homeGrabLists().map(\.id)
        guard let n = ids.firstIndex(of: id), ids.indices.contains(n + step) else { return }
        ids.swapAt(n, n + step)
        model.change { _ = $0.setHomeGrabLists(ids) }
        made = ""
    }

    /// Off Home: it waits here, whole, until he puts it back — and Home shows one
    /// tile fewer. (Until 4 Oct 2026 the free place pulled it straight back.)
    private func takeOff(_ id: String) {
        let ids = model.library.homeGrabLists().map(\.id).filter { $0 != id }
        model.change { _ = $0.setHomeGrabLists(ids) }
        made = ""
    }

    private func bringOn(_ id: String) {
        let ids = model.library.homeGrabLists().map(\.id)
        if ids.count < GRAB_HOME_SLOTS {
            model.change { _ = $0.setHomeGrabLists(ids + [id]) }
            made = ""
        } else {
            window = .swap(id)         // full: he says which one steps back
        }
    }

    enum Window: Identifiable {
        case swap(String), open(String)
        var id: String {
            switch self {
            case .swap(let x): return "swap:\(x)"
            case .open(let x): return "open:\(x)"
            }
        }
    }
}

/// Home is full. Which of the eight steps back, to wait in Grab Lists?
struct SwapScreen: View {
    let comingIn: String
    /// Told when he has picked (not on Cancel): the list coming in is on Home now.
    var picked: () -> Void = {}
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let home = model.library.homeGrabLists()
        let coming = model.library.allGrabLists().first { $0.id == comingIn }
        VStack(spacing: 0) {
            HStack {
                Text("Which one steps back?").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.home.color, filled: false)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.home.color)
                    .accessibilityIdentifier("swap-cancel")
            }
            .padding(16)
            Text("Home holds eight. \(coming?.label ?? "The new list") takes the place of the one you pick — and the one that steps back keeps everything on it.")
                .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                .padding(.horizontal, 16).padding(.bottom, 8)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(home.enumerated()), id: \.element.id) { n, list in
                        Button {
                            var ids = home.map(\.id)
                            ids[n] = comingIn
                            model.change { _ = $0.setHomeGrabLists(ids) }
                            picked()
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                GrabDoodle(icon: list.icon, size: 28, initial: list.label).foregroundStyle(GrabTone.color(list.tone))
                                Text(list.label).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(list.items.count)").font(.system(.subheadline, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Theme.muted)
                            }
                            .padding(.horizontal, 12).frame(minHeight: Metrics.row)
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
