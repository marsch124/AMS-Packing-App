import SwiftUI
import PackingCore
import PackingLibrary

/// "From Apple Health" — the block the trip review opens with on the iPhone (0.70, chapter
/// 07 part 7, his ask of 7 Oct 2026). The workouts Apple Health logged on the trip's days,
/// one row per kind ("Swim · indoor · 3 times"), a "No bike" row for a workout template on
/// the trip with none, and "Use these", which marks the review's lines — never a line he
/// answered himself, and nothing is saved until Save review.
///
/// Not shown at all: on the Mac (no Apple Health there) and for an undated trip.
///
/// Ids: the block `review-health`, its heading `review-health-title`, the rows
/// `review-health-row-<n>` (top to bottom), the button `review-health-use`, the line under
/// it `review-health-said` (what it marked) or `review-health-use-needs` (nothing to mark),
/// and in place of the rows `review-health-reading`, `review-health-none` (no workouts on
/// those days) or `review-health-refused` (Apple Health not allowed).
struct ReviewHealth: View {
    let tripId: String
    /// The review's "didn't use" marks — what "Use these" changes.
    @Binding var unused: Set<String>
    /// The lines he answered himself: never changed by "Use these".
    let answered: Set<String>
    @EnvironmentObject var model: LibraryModel
    @State private var phase: Phase = .reading
    /// What the last press marked, said under the button.
    @State private var said = ""
    /// What a press could not do, said under the button in the warning colour.
    @State private var needs = ""

    enum Phase: Equatable {
        case reading, refused, none
        case shown(Library.HealthReview)
    }

    private let source = AppleHealth.source

    var body: some View {
        if source.available, let days = model.library.healthDays(tripId: tripId) {
            VStack(alignment: .leading, spacing: 4) {
                Text("From Apple Health")
                    .font(.system(.headline)).foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("review-health-title")
                switch phase {
                case .reading:
                    quiet("Reading Apple Health\u{2026}", id: "review-health-reading")
                case .refused:
                    quiet("Apple Health is not allowed \u{2014} Settings \u{2192} Privacy & Security \u{2192} Health \u{2192} AMS Packing.",
                          id: "review-health-refused")
                case .none:
                    quiet("No workouts in Apple Health for these days.", id: "review-health-none")
                case .shown(let review):
                    ForEach(Array(review.rows.enumerated()), id: \.offset) { n, row in
                        Text(row.words)
                            .font(.system(.callout, weight: row.done ? .semibold : .regular))
                            .foregroundStyle(row.done ? Theme.ink : Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("review-health-row-\(n)")
                    }
                    useButton(days)
                        .padding(.top, 6)
                    // Nobody marked "This is me": the marks rest on a guess — say how to settle it.
                    if model.library.me() == nil {
                        Text("Who are you? Mark yourself in Your choices \u{2192} Owners.")
                            .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                            .accessibilityIdentifier("review-health-who")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("review-health")
            .padding(.bottom, 12)
            // Asked when the block first shows — the permission sheet the first time.
            .task(id: tripId) { phase = await read(days) }
        }
    }

    private func quiet(_ words: String, id: String) -> some View {
        Text(words).font(.system(.callout)).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(id)
    }

    /// "Use these": always in full colour; it reads Apple Health AGAIN (a watch that synced
    /// since the review opened counts), marks, and says under it what it did.
    private func useButton(_ days: (first: String, last: String)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                Task { await use(days) }
            } label: {
                Text("Use these").font(.system(.callout, weight: .semibold)).foregroundStyle(Color.white)
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, 16).frame(minHeight: Metrics.compact)
                    .background(Capsule().fill(AppSection.events.color))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("review-health-use")
            if !needs.isEmpty {
                Text(needs).font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("review-health-use-needs")
            } else if !said.isEmpty {
                Text(said).font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("review-health-said")
            }
        }
    }

    private func read(_ days: (first: String, last: String)) async -> Phase {
        switch await source.workouts(firstDay: days.first, lastDay: days.last) {
        case .refused: return .refused
        case .workouts(let all):
            let review = model.library.healthReview(tripId: tripId, workouts: all)
            return review.workouts == 0 ? .none : .shown(review)
        }
    }

    private func use(_ days: (first: String, last: String)) async {
        let now = await read(days)
        phase = now
        guard case .shown(let review) = now else { said = ""; needs = ""; return }
        let marks = review.marks.filter { !answered.contains($0.key) }
        guard !marks.isEmpty else {
            said = ""
            needs = review.marks.isEmpty ? "None of this trip\u{2019}s lines come from a workout template."
                                         : "You have answered every line Apple Health could."
            return
        }
        unused = Library.unusedAfterHealth(review.marks, unused: unused, answeredByHand: answered)
        needs = ""
        let off = marks.values.filter { !$0 }.count, on = marks.count - off
        let kept = review.marks.count - marks.count
        said = "Marked \(off) didn\u{2019}t use, \(on) used"
            + (kept > 0 ? "; your own \(kept == 1 ? "answer stays" : "\(kept) answers stay")." : ".")
    }
}

/// "Counts as" on a template's page (0.70): which Apple Health workout this template meets
/// in the trip review. Until he picks, the template's name decides (Swim, Bike, Run…; a
/// name that is none of them = Nothing); his pick is stored on the template and travels
/// with iCloud and every backup. Only on an activity template — the common base and the
/// transport templates never meet a workout. On the Mac too: the link is the template's,
/// even though only the iPhone reads Apple Health.
///
/// Ids (a drop-down's): the field `template-counts-as`, its list `template-counts-as-list`,
/// the rows `template-counts-as-<n>` in `WorkoutKind` order (0 Swim … 8 Diving) and
/// `template-counts-as-9` = Nothing; the word beside it `template-counts-as-title`.
struct CountsAsField: View {
    let list: PackList
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        DropDown(title: "Counts as", heading: .beside,
                 options: WorkoutKind.allCases.map { ($0.rawValue, $0.label) } + [(Library.countsAsNothing, "Nothing")],
                 selected: Library.workoutKind(of: list)?.rawValue ?? Library.countsAsNothing,
                 id: "template-counts-as", tint: AppSection.templates.color) { value in
            model.change { _ = $0.setCountsAs(templateId: list.id, to: value) }
        }
    }
}

/// "Me" — the small tag on his own row in Your choices → Owners (0.70).
struct MeTag: View {
    var body: some View {
        Text("Me").font(.system(.caption, weight: .semibold)).foregroundStyle(Color.white)
            .padding(.horizontal, 8).frame(minHeight: 20)
            .background(Capsule().fill(AppSection.settings.color))
    }
}

/// "This is me" in an owner's editor (Your choices → Owners, 0.70): marks this owner as him
/// — one at most, so marking another moves it; pressed on the one already marked, it takes
/// the mark off. Apple Health's review then treats this owner's things (and "Both have one")
/// as his. Ids: `list-owners-me` (`.isSelected` while this owner is him).
struct ThisIsMeButton: View {
    let owner: String
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        let on = model.library.me().map { normName($0) == normName(owner) } ?? false
        HStack(spacing: 10) {
            Button {
                model.change { _ = $0.setMe(on ? nil : owner) }
            } label: {
                Text("This is me").font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(on ? Color.white : AppSection.settings.color)
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                    .background(Capsule().fill(on ? AppSection.settings.color : AppSection.settings.color.opacity(0.10)))
                    .overlay(Capsule().stroke(AppSection.settings.color, lineWidth: on ? 0 : 1.4))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("list-owners-me")
            .accessibilityAddTraits(on ? .isSelected : [])
            Text(on ? "Apple Health marks your things in a trip\u{2019}s review." : "Whose things Apple Health marks in a trip\u{2019}s review.")
                .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
