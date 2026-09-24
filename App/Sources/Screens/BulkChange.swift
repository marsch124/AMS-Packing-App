import SwiftUI
import PackingCore
import PackingLibrary

/// Change one thing about MANY things at once — his ask: "check a number of items
/// and then, with only an easy change of condition, have all of them get changed
/// at once."
///
/// One field at a time, on purpose: a sheet that changed six fields at once would
/// be a form to fill in, and the whole point is that this takes two taps. What it
/// does is written out in full before he presses anything, and the grid keeps the
/// old values so one press puts them all back.
struct BulkChange: View {
    /// The things this will change.
    let things: [Item]
    let answers: TableColumns.Answers2
    /// Give back what to do: the change itself, and a line saying what it was.
    let change: (@escaping (inout Item) -> Void, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var field = ""
    @State private var typed = ""

    private var column: TableColumns.Column? {
        TableColumns.intrinsic.first { $0.id == field }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Change \(things.count) thing\(things.count == 1 ? "" : "s")")
                        .font(.system(size: 20, weight: .heavy)).foregroundStyle(AppSection.care.color)
                        .accessibilityIdentifier("bulk-count")
                    Text(names)
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("bulk-cancel")
            }
            .padding(16)

            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 0) {
                    heading("WHAT TO CHANGE")
                    ForEach(TableColumns.intrinsic) { one in
                        Button { field = one.id; typed = "" } label: {
                            HStack {
                                Text(one.title)
                                    .font(.system(size: 16, weight: field == one.id ? .heavy : .medium))
                                    .foregroundStyle(field == one.id ? AppSection.care.color : Theme.ink)
                                Spacer()
                                if field == one.id {
                                    Text("▾").font(.system(size: 14, weight: .black))
                                        .foregroundStyle(AppSection.care.color)
                                }
                            }
                            .frame(minHeight: 42)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        .accessibilityIdentifier("bulk-field-\(one.id)")
                        .accessibilityAddTraits(field == one.id ? .isSelected : [])

                        if field == one.id { chooser(one) }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bulk-detail")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
    }

    /// What it will be changed TO — a list of his own answers, a yes/no, or a box.
    @ViewBuilder
    private func chooser(_ one: TableColumns.Column) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            switch one.kind {
            case .choice(let path, let which):
                ForEach(Array(answers.list(which).enumerated()), id: \.element) { n, answer in
                    value(answer, id: "bulk-value-\(n)") {
                        apply(one, { it in it[keyPath: path] = answer }, "\(one.title) → \(answer)")
                    }
                }
                value("Leave blank", id: "bulk-value-blank") {
                    apply(one, { it in it[keyPath: path] = "" }, "\(one.title) cleared")
                }
            case .flag(let path):
                value("Yes", id: "bulk-value-yes") {
                    apply(one, { it in it[keyPath: path] = true }, "\(one.title): yes")
                }
                value("No", id: "bulk-value-no") {
                    apply(one, { it in it[keyPath: path] = false }, "\(one.title): no")
                }
            case .words(let path):
                box()
                value(typed.isEmpty ? "Leave blank" : "Set to “\(jsTrim(typed))”", id: "bulk-apply") {
                    let clean = jsTrim(typed)
                    apply(one, { it in it[keyPath: path] = clean },
                          clean.isEmpty ? "\(one.title) cleared" : "\(one.title) → \(clean)")
                }
            case .number(let path):
                box()
                value(typed.isEmpty ? "Leave blank" : "Set to \(jsTrim(typed))", id: "bulk-apply") {
                    let clean = jsTrim(typed).replacingOccurrences(of: ",", with: ".")
                    let number = Double(clean) ?? 0
                    guard clean.isEmpty || number >= 0 else { return }
                    apply(one, { it in it[keyPath: path] = clean.isEmpty ? 0 : number },
                          clean.isEmpty ? "\(one.title) cleared" : "\(one.title) → \(jsTrim(typed))")
                }
            case .onList:
                EmptyView()
            }
        }
        .padding(.leading, 10).padding(.bottom, 10)
    }

    private func value(_ text: String, id: String, _ go: @escaping () -> Void) -> some View {
        Button(action: go) {
            HStack(spacing: 8) {
                Text("→").font(.system(size: 13, weight: .black)).foregroundStyle(AppSection.care.color)
                Text(text).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer()
            }
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }

    private func box() -> some View {
        TextField("", text: $typed)
            .textFieldStyle(.plain)
            .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 10).frame(minHeight: 36)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1))
            .accessibilityIdentifier("bulk-text")
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.muted).kerning(0.6)
            .padding(.bottom, 6)
    }

    private func apply(_ one: TableColumns.Column, _ what: @escaping (inout Item) -> Void, _ said: String) {
        change(what, said)
        dismiss()
    }

    /// The first few, so he can see he chose what he meant to.
    private var names: String {
        let some = things.prefix(3).map(\.name).joined(separator: ", ")
        return things.count > 3 ? "\(some) and \(things.count - 3) more" : some
    }
}
