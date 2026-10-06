import SwiftUI
import PackingCore
import PackingLibrary

/// What a backup file holds, beside what this device holds, BEFORE anything is
/// replaced. A restore is the one move in the app that can take things away, so
/// it is shown as a comparison and the button that does it is red, quiet and last.
struct RestoreSheet: View {
    let file: Library
    let device: Library
    /// true = replace, false = leave everything alone.
    let answer: (Bool) -> Void
    /// Answered by one of its two buttons. Closed any other way (swiped away on the
    /// iPhone), it answers "no" as it goes — so Settings says "Nothing was replaced."
    /// Done here, not with the sheet's onDismiss: with onDismiss on the Mac, the kept
    /// copy's restore never opened after a first restore (GitHub's Mac run, 6 Oct 2026).
    @State private var answered = false

    @Environment(\.dismiss) private var dismiss

    private var rows: [(table: PackingLibrary.Table, file: Int, device: Int)] {
        let d = Dictionary(uniqueKeysWithValues: device.counts.map { ($0.table, $0.count) })
        return file.counts.map { (table: $0.table, file: $0.count, device: d[$0.table] ?? 0) }
            // `meta` is the library's own bookkeeping, not his things: it says
            // nothing to him and would only make the comparison look wrong.
            .filter { $0.table != .meta && ($0.file > 0 || $0.device > 0) }
    }

    /// The one question worth asking out loud: does this file hold less than the
    /// device does? That is what a stale or half-written file looks like.
    private var fewer: [(table: PackingLibrary.Table, file: Int, device: Int)] {
        rows.filter { $0.file < $0.device }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Restore from a file").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Cancel") { answered = true; answer(false); dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.settings.color, filled: false)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.settings.color)
                    .keyboardShortcut(.cancelAction)            // Escape = Cancel, never Save (Escape everywhere, 5 Oct 2026)
                    .accessibilityIdentifier("restore-cancel")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Everything on this device is replaced by what the file holds.")
                        .font(.system(.callout)).foregroundStyle(Theme.ink)

                    HStack {
                        Text(" ").font(.system(.subheadline, weight: .semibold))
                        Spacer()
                        Text("The file").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                            .frame(width: 70, alignment: .trailing)
                        Text("Now").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                            .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.top, 6)
                    VStack(spacing: 0) {
                        ForEach(rows, id: \.table) { row in
                            HStack {
                                Text(SettingsScreen.label(row.table))
                                    .font(.system(.callout)).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(row.file)")
                                    .font(.system(.callout, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(row.file < row.device ? AppSection.actions.color : Theme.ink)
                                    .frame(width: 70, alignment: .trailing)
                                    .accessibilityIdentifier("restore-file-\(row.table.rawValue)")
                                Text("\(row.device)")
                                    .font(.system(.callout, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                                    .frame(width: 70, alignment: .trailing)
                                    .accessibilityIdentifier("restore-now-\(row.table.rawValue)")
                            }
                            .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))

                    if !fewer.isEmpty {
                        // The three biggest losses, not all of them: a wall of red
                        // says less than one line he actually reads.
                        Text("This file holds less than this device does — "
                             + fewer.sorted { ($0.device - $0.file) > ($1.device - $1.file) }.prefix(3)
                                    .map { "\(SettingsScreen.label($0.table).lowercased()) \($0.file) against \($0.device)" }
                                    .joined(separator: ", ")
                             + (fewer.count > 3 ? ", and more." : "."))
                            .font(.system(.callout, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                            .accessibilityIdentifier("restore-fewer")
                    }

                    Text("A copy of what is on this device now is written first, so there is a way back.")
                        .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .padding(.top, 4)

                    Button { answered = true; answer(true); dismiss() } label: {
                        Text("Replace everything on this device")
                            .font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: Metrics.row)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.actions.color))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .padding(.top, 10)
                    .accessibilityIdentifier("restore-confirm")
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        // A Mac sheet takes its size from what it holds; an iPhone sheet is the screen.
        // On the iPhone this minimum was WIDER than most screens (375–430 points),
        // so the sheet's edges were cut off (the spec pass, 2026-10-05).
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
        .background(Theme.bg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("restore-detail")
        .onDisappear { if !answered { answered = true; answer(false) } }
    }
}
