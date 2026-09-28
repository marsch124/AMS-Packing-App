import SwiftUI
import PackingCore
import PackingLibrary

/// Refine — what his trip reviews say a list carries for nothing (roadmap stop E).
/// Over at least two trips: a thing packed and never used, or listed and never
/// packed. Keep settles it for good; Drop takes it off that ONE list (it asks
/// first — it edits a list), and the thing stays his.
struct RefineScreen: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    /// The row whose Drop is being asked about.
    @State private var dropping: String?

    var body: some View {
        let offers = model.library.refineSuggestions()
        VStack(spacing: 0) {
            HStack {
                Text("Refine").font(.system(size: 22, weight: .heavy)).foregroundStyle(AppSection.templates.color)
                Text("\(offers.count)").font(.system(size: 15, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("refine-count")
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.templates.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.templates.color)
                    .accessibilityIdentifier("refine-done")
            }
            .padding(16)
            LoopDoor(here: .refine, id: "refine-loop")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, -6).padding(.bottom, 10)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 12) {
                    if offers.isEmpty {
                        Text("Nothing to trim yet. After two trip reviews, anything you keep packing and never use — or keep listing and never pack — shows up here. One trip is not enough to judge by.")
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("refine-empty")
                    } else {
                        Text("Each of these has earned its place here over at least two trips. Keep settles it for good. Drop takes it off that one template — it stays your thing, and on your other templates.")
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(Array(offers.enumerated()), id: \.offset) { n, s in row(s, n) }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("refine-screen")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    private func row(_ s: PruneSuggestion, _ n: Int) -> some View {
        let thing = s.item.itemId ?? s.item.id
        let key = "\(s.listId)|\(thing)"
        // Two different facts, said as such (the web app's lesson): packed and
        // never used, or listed and never packed.
        let why = s.reason == "never-packed" ? "on the list \(s.times)× · never packed" : "packed \(s.times)× · used 0×"
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.item.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("refine-row-\(n)-name")
                    Text("\(s.listName) · \(why)").font(.system(size: 14)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("refine-row-\(n)-why")
                }
                Spacer(minLength: 8)
                if dropping != key {
                    small("Keep", tint: AppSection.events.color, id: "refine-row-\(n)-keep") {
                        model.change { _ = $0.keepThing(id: thing) }
                    }
                    small("Drop", tint: AppSection.actions.color, id: "refine-row-\(n)-drop") { dropping = key }
                }
            }
            if dropping == key {
                HStack(spacing: 10) {
                    Text("Drop it from \(s.listName)?").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                    Spacer(minLength: 6)
                    Button("Keep it") { dropping = nil }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("refine-row-\(n)-drop-no")
                    Button {
                        dropping = nil
                        let list = s.listId
                        model.change { _ = $0.dropFromList(itemId: thing, listId: list) }
                    } label: {
                        Text("Drop").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 14).frame(minHeight: 36)
                            .background(Capsule().fill(AppSection.actions.color))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("refine-row-\(n)-drop-yes")
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("refine-row-\(n)")
    }

    private func small(_ title: String, tint: Color, id: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(tint)
                .padding(.horizontal, 12).frame(minHeight: 34)
                .overlay(Capsule().stroke(tint, lineWidth: 1.4))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }
}

/// The way in, on Your lists: a slim line that says how many are waiting — and owns
/// its own sheet (Your lists already carries three).
struct RefineDoor: View {
    @EnvironmentObject var model: LibraryModel
    @State private var open = false

    var body: some View {
        let waiting = model.library.refineSuggestions().count
        // His test F.6: "make it pop and make a symbol like constant improving, so
        // that the eyes are drawn to it". Steps going up: better, trip after trip.
        let violet = AppSection.templates.color
        Button { open = true } label: {
            HStack(spacing: 12) {
                ImprovingMark().frame(width: 28, height: 28)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(violet))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Refine your templates").font(.system(size: 18, weight: .heavy)).foregroundStyle(violet)
                    Text(waiting == 0 ? "Better with every trip. Review a few trips, and what they teach waits here."
                         : "Your trip reviews found \(waiting) thing\(waiting == 1 ? "" : "s") to look at.")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if waiting > 0 {
                    Text("\(waiting)").font(.system(size: 16, weight: .heavy).monospacedDigit()).foregroundStyle(.white)
                        .frame(minWidth: 30, minHeight: 30)
                        .background(Capsule().fill(AppSection.care.color))
                }
                SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 20, height: 20).foregroundStyle(violet)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(violet.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(violet, lineWidth: 1.6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("refine-open")
        .accessibilityValue(waiting == 0 ? "" : "\(waiting)")
        .sheet(isPresented: $open) { RefineScreen().environmentObject(model) }
    }
}

/// Steps going up with an arrow at the top — getting better, trip after trip.
/// Drawn, not stock art (his rule).
struct ImprovingMark: View {
    var body: some View {
        SVGPath.path("M2.5 21.5H7V17H11.5V12.5H16V8H21.5M16 8V2.5M13.2 5.3L16 2.5L18.8 5.3")
            .stroke(style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
            .accessibilityHidden(true)
    }
}
