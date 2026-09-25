import SwiftUI
import PackingCore
import PackingLibrary

/// Make a new list of his own.
///
/// The web app asks one question in a browser prompt — a name — and leaves the
/// list ungrouped, which means it lands in "Other" and he has to go and file it.
/// Here the shelf is asked for at the same time, because it is one tap and it is
/// the difference between a list that is where he expects it and one that is not.
///
/// It also REFUSES a name he already has. The web app allows two lists with one
/// name (identity is the id), but this app's own health check reads two lists
/// sharing a name as the sign that two libraries have met on one account — the
/// accident of 31 August. Letting him make one by hand would cry wolf.
struct NewList: View {
    /// What to do with the finished list: it is saved and then opened.
    let made: (PackList) -> Void
    let library: Library
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var group = ""
    @FocusState private var writing: Bool

    private var taken: Bool {
        let wanted = normName(name)
        return !wanted.isEmpty && library.templates.contains { normName($0.name) == wanted }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("A new list").font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(AppSection.templates.color)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("newlist-cancel")
            }
            .padding(16)

            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 0) {
                    Text("WHAT IS IT CALLED")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.muted).kerning(0.6)
                        .padding(.bottom, 6)
                    TextField("", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(taken ? AppSection.actions.color : Theme.line, lineWidth: 1))
                        .focused($writing)
                        .onSubmit { make() }
                        .accessibilityIdentifier("newlist-name")

                    if taken {
                        Text("You already have a list called that.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppSection.actions.color)
                            .padding(.top, 6)
                            .accessibilityIdentifier("newlist-taken")
                    }

                    Text("WHICH SHELF")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.muted).kerning(0.6)
                        .padding(.top, 20).padding(.bottom, 6)
                    ForEach(GROUPS, id: \.id) { shelf in
                        shelfRow(shelf.id, "\(shelf.id) · \(shelf.label)")
                    }
                    shelfRow("", "No shelf")

                    Button { make() } label: {
                        Text("Make the list")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(canMake ? Color.white : Theme.muted)
                            .frame(maxWidth: .infinity).frame(minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(canMake ? AppSection.templates.color : Theme.line))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .disabled(!canMake)
                    .padding(.top, 24)
                    .accessibilityIdentifier("newlist-make")
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { writing = true }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("newlist-detail")
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 480)
        #endif
    }

    private var canMake: Bool { !jsTrim(name).isEmpty && !taken }

    private func shelfRow(_ id: String, _ label: String) -> some View {
        Button { group = id } label: {
            HStack {
                Text(label)
                    .font(.system(size: 16, weight: group == id ? .heavy : .medium))
                    .foregroundStyle(group == id ? AppSection.templates.color : Theme.ink)
                Spacer()
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
        .accessibilityIdentifier("newlist-shelf-\(id.isEmpty ? "none" : id)")
        .accessibilityAddTraits(group == id ? .isSelected : [])
    }

    private func make() {
        guard canMake else { return }
        made(newList(name: jsTrim(name), group: group))
        dismiss()
    }
}
