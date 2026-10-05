import SwiftUI
import PackingCore
import PackingLibrary

/// The web app's "Mark everything packed" and "Clear every tick" (gap list,
/// 2026-09-27), near the end of a trip. Ticking all needs no asking — it is what
/// he is there to do; clearing asks first, as the web app does, because it throws
/// away the packing so far. Lines set aside stay out of both.
struct TickAllRow: View {
    let tripId: String
    let done: Int
    let total: Int
    @EnvironmentObject var model: LibraryModel
    @State private var askingToClear = false

    var body: some View {
        let left = total - done
        if total > 0 {
            if askingToClear {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Clear all \(done) tick\(done == 1 ? "" : "s")?")
                        .font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.ink)
                    Text("The list stays as it is. Only the ticks go.")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
                    HStack(spacing: 10) {
                        Button("Keep them") { askingToClear = false }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                            .accessibilityIdentifier("trip-clearall-no")
                        Spacer()
                        Button {
                            askingToClear = false
                            let id = tripId
                            model.change { _ = $0.setAllChecked(false, tripId: id) }
                        } label: {
                            Text("Clear the ticks")
                                .font(.system(size: 16, weight: .heavy)).foregroundStyle(.white)
                                .padding(.horizontal, 14).frame(minHeight: 40)
                                .background(Capsule().fill(AppSection.actions.color))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("trip-clearall-yes")
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.actions.color, lineWidth: 1))
            } else {
                HStack(spacing: 10) {
                    if left > 0 {
                        Button {
                            let id = tripId
                            model.change { _ = $0.setAllChecked(true, tripId: id) }
                        } label: {
                            VStack(spacing: 2) {
                                HStack(spacing: 6) {
                                    Tick().stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                                        .frame(width: 22, height: 22)
                                    Text("Tick everything").font(.system(size: 16, weight: .bold))
                                }
                                Text("\(left) still unticked").font(.system(size: 13, weight: .semibold)).opacity(0.85)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.events.color))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("trip-tickall")
                        .accessibilityValue("\(left)")
                    }
                    if done > 0 {
                        Button { askingToClear = true } label: {
                            Text("Clear every tick")
                                .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1.4))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("trip-clearall")
                    }
                }
            }
        }
    }
}
