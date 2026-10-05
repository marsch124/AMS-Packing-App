import SwiftUI

/// "Delete this …" as a small red button at the side — his mark (2026-09-26):
/// "Delete should be a small button at the side." Quiet until wanted; it only ever
/// OPENS the question, never deletes by itself.
struct SmallDeleteButton: View {
    let title: String
    let id: String
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: action) {
                // 15, like every word (his floor: nothing under 15). It began at 13 and
                // only the grab list's delete had been raised; small means the capsule,
                // not the words.
                Text(title)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .padding(.horizontal, 12).frame(minHeight: 30)
                    .overlay(Capsule().stroke(AppSection.actions.color.opacity(0.6), lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier(id)
        }
    }
}
