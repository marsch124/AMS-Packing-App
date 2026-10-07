import SwiftUI
import PackingCore
import PackingLibrary

/// After a trip. Tap anything you didn't use; add what you wished you'd had —
/// it goes onto one of the trip's lists, so next time it comes along. Saving
/// teaches every thing its history (used / not used / never packed).
struct ReviewScreen: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var unused: Set<String> = []
    @State private var missed: [Library.Missed] = []
    @State private var missName = ""
    /// So the keyboard goes away once a missed thing has been added — it covered
    /// Save on a phone with no hardware keyboard.
    @FocusState private var typingMissed: Bool
    /// The template a missed thing goes onto: nil = not picked yet (the first of the
    /// trip's templates), "" = No template. The spec pass (5 Oct 2026): "" meant both,
    /// so tapping No template fell straight back to the first template — it could never
    /// be chosen.
    @State private var missWhere: String?
    /// What Add was missing, said under it (his rule: a main button never just does
    /// nothing — the spec pass, 5 Oct 2026).
    @State private var missNeeds = ""
    /// The thing he is fixing mid-review, if any.
    @State private var fixing: String?
    /// The lines he marked himself (either way): Apple Health's "Use these" never changes
    /// them (0.70, chapter 07 part 7).
    @State private var answered: Set<String> = []

    var body: some View {
        let lines = model.library.reviewLines(tripId: tripId)
        let lists = model.library.tripTemplates(tripId: tripId)
        let target = missWhere ?? (lists.first?.id ?? "")
        VStack(spacing: 0) {
            HStack {
                Text("Trip review").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.muted)
                    .keyboardShortcut(.cancelAction)            // Escape = Cancel (the spec pass, 5 Oct 2026)
                    .accessibilityIdentifier("review-cancel")
            }
            .padding(16)
            LoopDoor(here: .review, id: "review-loop")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, -6).padding(.bottom, 10)
            KeyboardAwayScroll {
                LazyVStack(alignment: .leading, spacing: 6) {
                    // "From Apple Health" opens the review on the iPhone (0.70): the trip's
                    // workouts and "Use these". Nothing at all on the Mac or an undated trip.
                    ReviewHealth(tripId: tripId, unused: $unused, answered: answered)
                    // The two parts' headings above the question asked inside them (17) and
                    // the pills (15) — field test, 3 Oct 2026: headings "dominant".
                    Text("Anything you wished you'd had?").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    // In the order it is done (his test F.3: "I have forgotten how to pick
                    // where it goes"): the thing, the template it goes onto, then one
                    // button that says where it will go.
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("e.g. Power bank", text: $missName)
                            .textFieldStyle(.plain)
                            .font(.system(.body)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                            .onSubmit { addMissed(target) }
                            .focused($typingMissed)
                            .accessibilityIdentifier("review-miss-input")
                        if !lists.isEmpty {
                            Pills(title: "Put it on which template, for next time?", options: lists.map { ($0.id, $0.name) } + [("", "No template")],
                                  selected: [target], id: "review-miss-where", tint: AppSection.templates.color, heading: .question) { missWhere = $0 }
                        }
                        // Always in full colour (his rule for a main button); with nothing
                        // typed it adds nothing and says so under it.
                        Button { addMissed(target) } label: {
                            Text(target.isEmpty ? "Add it, on no template"
                                 : "Add it to \(lists.first { $0.id == target }?.name ?? "the template")")
                                .font(.system(.callout, weight: .semibold)).foregroundStyle(Color.white)
                                .lineLimit(1).minimumScaleFactor(0.8)
                                .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: Metrics.tap)
                                .background(RoundedRectangle(cornerRadius: 10).fill(AppSection.events.color))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("review-miss-add")
                        .needsLine($missNeeds, typed: missName, id: "review-miss-add-needs")
                    }
                    ForEach(Array(missed.enumerated()), id: \.offset) { n, m in
                        HStack {
                            Text(m.name).font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                            Text(lists.first { $0.id == m.templateId }?.name ?? "no template")
                                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                                .accessibilityIdentifier("review-missed-\(n)-where")
                            Spacer()
                            Button { missed.remove(at: n) } label: {
                                SVGPath.path("M6 6L18 18M18 6L6 18").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                    .frame(width: 20, height: 20).foregroundStyle(Theme.muted)
                                    .frame(width: 36, height: 36).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("review-missed-\(n)-remove")
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("review-missed-\(n)")
                    }

                    Text(unused.isEmpty ? "Tap anything you didn't use." : "\(unused.count) marked \u{201C}didn't use\u{201D}")
                        .font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                        .padding(.top, 18)
                        .accessibilityIdentifier("review-summary")
                    ForEach(Array(lines.packed.enumerated()), id: \.element.id) { n, line in
                        let off = unused.contains(line.id)
                        HStack(spacing: 4) {
                        Button {
                            if off { unused.remove(line.id) } else { unused.insert(line.id) }
                            answered.insert(line.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.name).font(.system(.body))
                                        .foregroundStyle(off ? Theme.muted : Theme.ink)
                                        .strikethrough(off, pattern: .solid, color: Theme.muted)
                                    // WHERE it went: the same words as packing mode,
                                    // so "did I use it" is asked in context.
                                    Text(ReviewScreen.where(line))
                                        .font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                                        .lineLimit(1)
                                        .accessibilityIdentifier("review-line-\(n)-where")
                                }
                                Spacer(minLength: 8)
                                Text(off ? "Didn't use" : "Used").font(.system(.footnote, weight: .semibold))
                                    .foregroundStyle(off ? AppSection.actions.color : AppSection.events.color)
                            }
                            .padding(.vertical, 5).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        .accessibilityIdentifier("review-line-\(n)")
                        .accessibilityAddTraits(off ? .isSelected : [])
                        // "That one is wrong" — fix the THING here and come straight
                        // back; nothing about the review is lost (his ask).
                        // A trip line points back at the thing it came from through
                        // sourceItemId (itemId is the membership's item, not always set).
                        if let itemId = line.sourceItemId ?? line.itemId, !itemId.isEmpty {
                            Button { fixing = itemId } label: {
                                SVGPath.path("M4 20h4L19 9l-4-4L4 16v4z")
                                    .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                                    .frame(width: 18, height: 18).foregroundStyle(Theme.muted)
                                    .frame(width: 40, height: 40).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("review-line-\(n)-fix")
                            .accessibilityLabel("Change \(line.name)")
                        }
                        }
                    }
                    if !lines.neverPacked.isEmpty {
                        Text("Never went in the bag: \(lines.neverPacked.count)")
                            .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                            .padding(.top, 14)
                        Text(lines.neverPacked.map(\.name).joined(separator: " · "))
                            .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            Button {
                model.change { _ = $0.saveReview(tripId: tripId, unused: unused, missed: missed, when: nowISO()) }
                dismiss()
            } label: {
                Text("Save review").font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: Metrics.row)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.events.color))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .padding(.horizontal, 16).padding(.vertical, 10)
            .accessibilityIdentifier("review-save")
        }
        .background(Theme.bg.ignoresSafeArea())
        // A swipe down must not throw marks away without a word (the spec pass, 5 Oct
        // 2026): once something is marked, added or typed, only Cancel or Save closes it.
        .interactiveDismissDisabled(!unused.isEmpty || !missed.isEmpty || !jsTrim(missName).isEmpty)
        .accessibilityElement(children: .contain)
        .sheet(item: Binding(get: { fixing.map { Fixing(id: $0) } }, set: { fixing = $0?.id })) { it in
            ThingEditor(itemId: it.id).environmentObject(model)
        }
        .accessibilityIdentifier("review-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    private struct Fixing: Identifiable { let id: String }

    /// Where a line was packed, in the same words as packing mode.
    static func `where`(_ line: Item) -> String {
        let bag = jsTrim(line.container)
        let when = phaseLabel(line.phase)
        return [bag.isEmpty ? "" : bag, when.isEmpty ? "" : when].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func addMissed(_ target: String) {
        let name = jsTrim(missName)
        guard !name.isEmpty else { missNeeds = "Type what you wished you'd had first."; return }
        guard !missed.contains(where: { normName($0.name) == normName(name) }) else { missName = ""; return }
        missed.append(Library.Missed(name: name, templateId: target))
        missName = ""
        typingMissed = false
    }
}
