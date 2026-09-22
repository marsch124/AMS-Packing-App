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
                Text("Restore from a file").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Cancel") { answer(false); dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.settings.color)
                    .accessibilityIdentifier("restore-cancel")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Everything on this device is replaced by what the file holds.")
                        .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)

                    HStack {
                        Text(" ").font(.system(size: 15, weight: .heavy))
                        Spacer()
                        Text("The file").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted)
                            .frame(width: 70, alignment: .trailing)
                        Text("Now").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted)
                            .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.top, 6)
                    VStack(spacing: 0) {
                        ForEach(rows, id: \.table) { row in
                            HStack {
                                Text(SettingsScreen.label(row.table))
                                    .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(row.file)")
                                    .font(.system(size: 16, weight: .bold).monospacedDigit())
                                    .foregroundStyle(row.file < row.device ? AppSection.actions.color : Theme.ink)
                                    .frame(width: 70, alignment: .trailing)
                                    .accessibilityIdentifier("restore-file-\(row.table.rawValue)")
                                Text("\(row.device)")
                                    .font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
                                    .frame(width: 70, alignment: .trailing)
                                    .accessibilityIdentifier("restore-now-\(row.table.rawValue)")
                            }
                            .padding(.horizontal, 14).frame(minHeight: 40)
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
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                            .accessibilityIdentifier("restore-fewer")
                    }

                    Text("A copy of what is on this device now is written first, so there is a way back.")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                        .padding(.top, 4)

                    Button { answer(true); dismiss() } label: {
                        Text("Replace everything on this device")
                            .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
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
        .frame(minWidth: 420, minHeight: 520)
        .background(Theme.bg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("restore-detail")
    }
}
