import SwiftUI
import PackingCore
import PackingLibrary

// "Make a small core from this…" (0.71, 8 Oct 2026) — his words: "Always packed will
// be a small core, and [the big one] becomes a big kit that I tick." The model does the
// moving (`Library.makeSmallCore`, SmallCore.swift); this is the one sheet where he
// says what goes into the core, and the one press that does it all.

extension LibraryModel {
    /// Make the small core in ONE change — with a copy of the whole library kept on
    /// this device FIRST (`RescueCopies`, the copies Settings offers under "Kept
    /// before a restore"), as there is no undo for a template change. nil when the
    /// model refuses (nothing changed then, and nothing kept).
    @discardableResult
    func makeSmallCore(from templateId: String, name: String, ticked: Set<String>, bigArea: String,
                       plan: Library.PastePlan?, seconds: Set<String>) -> PackList? {
        var trial = library
        guard trial.makeSmallCore(from: templateId, name: name, ticked: ticked, bigArea: bigArea,
                                  plan: plan, seconds: seconds) != nil else { return nil }
        try? RescueCopies.write(library)
        var made: PackList?
        change { made = $0.makeSmallCore(from: templateId, name: name, ticked: ticked, bigArea: bigArea,
                                          plan: plan, seconds: seconds) }
        return made
    }
}

/// The door on a big always-packed template's page. The sheet itself hangs on the
/// page (`TemplateDetail`), not on this door: once the core is made the big template
/// is no longer always packed, the door goes — and a sheet hung on it would go with
/// it, without ever saying it closed.
struct SmallCoreDoor: View {
    var open: () -> Void

    var body: some View {
        Button { open() } label: {
            Text("Make a small core from this\u{2026}")
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.templates.color)
                .lineLimit(1)
                .frame(minHeight: Metrics.chip).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("template-smallcore")
    }
}

struct SmallCoreSheet: View {
    let templateId: String
    var made: (String) -> Void
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var ticked: Set<String> = []
    @State private var area = ""
    @State private var pasted = ""
    @State private var plan: Library.PastePlan?
    /// The clashes he answered with "Make a second one".
    @State private var seconds: Set<String> = []
    @State private var needs = ""
    @State private var started = false

    private var tint: Color { AppSection.templates.color }

    var body: some View {
        let lib = model.library
        let big = lib.templates.first { $0.id == templateId }
        let groups = lib.smallCoreGroups(templateId: templateId)
        let all = groups.flatMap(\.rows)
        let picked = all.filter { ticked.contains($0.memId ?? "") }.count
        let bigName = big?.name ?? ""
        VStack(spacing: 0) {
            HStack {
                Text("A small core").font(.system(.title3, weight: .bold)).foregroundStyle(tint)
                    .accessibilityIdentifier("smallcore-title")
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .keyboardShortcut(.cancelAction)            // Escape = Cancel, never Make
                    .accessibilityIdentifier("smallcore-cancel")
            }
            .padding(16)

            KeyboardAwayScroll {
                // A plain stack: a few hundred rows at most, and every control stays in place
                // (a lazy one dropped the paste answers once scrolled past).
                VStack(alignment: .leading, spacing: 0) {
                    Text("Tick what comes on EVERY full trip. It becomes a new always-packed template; \u{201C}\(bigName)\u{201D} keeps all its things and comes when you tick it.")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 10)
                    pasteBlock(lib)

                    SectionTitle(title: "Its name", id: "smallcore-name-title").padding(.top, 14).padding(.bottom, 6)
                    TextField("", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                        .accessibilityIdentifier("smallcore-name")

                    Text("\(picked) of \(all.count) things")
                        .font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.ink)
                        .padding(.top, 14).padding(.bottom, 2)
                        .accessibilityIdentifier("smallcore-count")
                    ForEach(Array(groups.enumerated()), id: \.offset) { g, group in
                        heading(g, group.title, group.rows)
                        ForEach(group.rows, id: \.memId) { row in
                            line(row, n: all.firstIndex { $0.memId == row.memId } ?? 0)
                        }
                    }

                    SectionTitle(title: "Where should \u{201C}\(bigName)\u{201D} go?", id: "smallcore-area-title")
                        .padding(.top, 16).padding(.bottom, 6)
                    ForEach(GROUPS.map { ($0.id, "\($0.id) \u{00B7} \($0.label)") } + [("", "No activity area (Other templates)")], id: \.0) { id, label in
                        areaRow(id, label)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
            }

            // Always ready, always in colour; pressed too early it says what is missing.
            Button { make() } label: {
                Text("Make the small core")
                    .font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 12).fill(tint))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("smallcore-make")
            .needsLine($needs, typed: "\(name)|\(ticked.count)|\(plan?.kits.count ?? 0)", id: "smallcore-needs")
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            guard !started, let big else { return }
            started = true
            name = lib.freeTemplateName("\(big.name) short")
            ticked = lib.smallCoreSuggestion(templateId: templateId)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("smallcore-detail")
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 640)
        #endif
    }

    // MARK: Paste a list

    @ViewBuilder
    private func pasteBlock(_ lib: Library) -> some View {
        SectionTitle(title: "Paste a list", id: "smallcore-paste-title").padding(.bottom, 4)
        Text("One per line or with commas. A line with lines indented under it is a kit holding them.")
            .font(.system(.footnote)).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 6)
        TextEditor(text: $pasted)
            .font(.system(.body)).foregroundStyle(Theme.ink)
            .scrollContentBackground(.hidden)
            .padding(6)
            .frame(height: 96)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
            .accessibilityIdentifier("smallcore-paste")
        HStack {
            Spacer()
            Button {
                if jsTrim(pasted).isEmpty { plan = nil; return }
                let p = lib.planPaste(pasted, templateId: templateId)
                plan = p
                seconds = []
                ticked = p.ticked            // his list wins over the first ticks
            } label: { FieldButtonLabel(title: "Tick these", tint: tint) }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("smallcore-paste-tick")
        }
        .padding(.top, 6)
        if let p = plan {
            Text(p.words)
                .font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .accessibilityIdentifier("smallcore-paste-result")
            ForEach(Array(p.clashes.enumerated()), id: \.offset) { n, clash in
                let on = seconds.contains(clash.id)
                // The words on their own line, the answer under them: both whole, at any width.
                VStack(alignment: .leading, spacing: 4) {
                    Text(clash.words)
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("smallcore-clash-\(n)")
                    Button {
                        if on { seconds.remove(clash.id) } else { seconds.insert(clash.id) }
                    } label: {
                        Text(on ? "A second one goes in \(clash.wantedKit)" : "Make a second one")
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(on ? Color.white : tint)
                            .lineLimit(1).fixedSize()
                            .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                            .background(Capsule().fill(on ? tint : tint.opacity(0.10)))
                            .overlay(Capsule().stroke(tint, lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("smallcore-second-\(n)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: The things

    private func heading(_ g: Int, _ title: String, _ rows: [Item]) -> some View {
        let ids = Set(rows.compactMap(\.memId))
        let all = ids.isSubset(of: ticked)
        return HStack {
            Text(title).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                .accessibilityIdentifier("smallcore-section-\(g)")
            Spacer()
            Button {
                if all { ticked.subtract(ids) } else { ticked.formUnion(ids) }
            } label: {
                Text(all ? "Untick all" : "Tick all")
                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(tint)
                    .frame(minHeight: Metrics.compact).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("smallcore-section-\(g)-all")
        }
        .padding(.top, 12)
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }

    private func line(_ row: Item, n: Int) -> some View {
        let id = row.memId ?? ""
        let on = ticked.contains(id)
        return Button {
            if on { ticked.remove(id) } else { ticked.insert(id) }
        } label: {
            HStack(spacing: 10) {
                TickCircle(on: on, tint: tint)
                Text(row.name).font(.system(.callout)).foregroundStyle(Theme.ink).lineLimit(1)
                Spacer()
            }
            .frame(minHeight: Metrics.compact).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("smallcore-row-\(n)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func areaRow(_ id: String, _ label: String) -> some View {
        Button { area = id } label: {
            HStack {
                Text(label)
                    .font(.system(.callout, weight: area == id ? .semibold : .regular))
                    .foregroundStyle(area == id ? tint : Theme.ink)
                Spacer()
            }
            .frame(minHeight: Metrics.tap).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
        .accessibilityIdentifier("smallcore-area-\(id.isEmpty ? "none" : id)")
        .accessibilityAddTraits(area == id ? .isSelected : [])
    }

    private func make() {
        let lib = model.library
        let kits = (plan?.kits ?? []).filter { !$0.inside.isEmpty || $0.thingId != nil }.count
        if let problem = lib.smallCoreProblem(templateId: templateId, name: name, ticked: ticked, kits: kits) {
            needs = problem
            return
        }
        let bigName = lib.templates.first { $0.id == templateId }?.name ?? ""
        guard let core = model.makeSmallCore(from: templateId, name: name, ticked: ticked, bigArea: area,
                                             plan: plan, seconds: seconds) else {
            needs = "That could not be made."
            return
        }
        made("\u{201C}\(core.name)\u{201D} is always packed now; \u{201C}\(bigName)\u{201D} is ticked when you need it.")
        dismiss()
    }
}
