import SwiftUI

/// The two doors in Settings: What's new and How it works — his standing rule from
/// the web apps, missing here until 0.23. They own their sheet, so Settings keeps
/// the sheets it already has (several sheets on one view is a trap met in Search).
struct GuideDoors: View {
    enum Page: String, Identifiable { case whatsNew, howItWorks; var id: String { rawValue } }
    @State private var page: Page?

    var body: some View {
        VStack(spacing: 10) {
            door("What's new", Releases.all.first.map { "\($0.version) · \($0.title)" } ?? "", "settings-whatsnew") { page = .whatsNew }
            door("How it works", "The whole app in plain words, screen by screen", "settings-howitworks") { page = .howItWorks }
        }
        .sheet(item: $page) { p in
            switch p {
            case .whatsNew: WhatsNewScreen()
            case .howItWorks: HowItWorksScreen()
            }
        }
    }

    private func door(_ title: String, _ line: String, _ id: String, _ open: @escaping () -> Void) -> some View {
        Button(action: open) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                    Text(line).font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer()
                SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 24, height: 24).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 14).frame(minHeight: 60)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }
}

/// A sheet's top line: the title in the section's colour, and Done.
private struct GuideHeader: View {
    let title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HStack {
            Text(title).font(.system(size: 22, weight: .heavy)).foregroundStyle(AppSection.settings.color)
                .accessibilityIdentifier("guide-title")
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.plain).focusEffectDisabled()
                .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.settings.color)
                .accessibilityIdentifier("guide-done")
        }
        .padding(16)
    }
}

/// Every version, newest first: what was added, changed, fixed and removed.
struct WhatsNewScreen: View {
    var body: some View {
        let here = AppInfo.marketing
        VStack(spacing: 0) {
            GuideHeader(title: "What's new")
            KeyboardAwayScroll {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(Releases.all.enumerated()), id: \.element.id) { n, r in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(r.version).font(.system(size: 20, weight: .heavy).monospacedDigit())
                                    .foregroundStyle(AppSection.settings.color)
                                    .accessibilityIdentifier("guide-release-\(n)-version")
                                Text(r.title).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                                Spacer(minLength: 6)
                                if r.version == here {
                                    Text("On this device").font(.system(size: 12, weight: .heavy))
                                        .foregroundStyle(AppSection.events.color)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .overlay(Capsule().stroke(AppSection.events.color, lineWidth: 1.2))
                                }
                            }
                            Text(r.date).font(.system(size: 14)).foregroundStyle(Theme.muted)
                            kind("New", r.new, AppSection.events.color)
                            kind("Changed", r.changed, AppSection.home.color)
                            kind("Fixed", r.fixed, AppSection.care.color)
                            kind("Removed", r.removed, Theme.muted)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("guide-release-\(n)")
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-whatsnew")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }

    @ViewBuilder private func kind(_ label: String, _ lines: [String], _ tint: Color) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased()).font(.system(size: 12, weight: .heavy)).kerning(0.6).foregroundStyle(tint)
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(tint).frame(width: 6, height: 6).offset(y: -2)
                        Text(line).font(.system(size: 16)).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// The whole app in plain words, one screen at a time, with each tab's own mark.
struct HowItWorksScreen: View {
    struct Topic { let section: AppSection; let title: String; let lines: [String] }

    static let topics: [Topic] = [
        Topic(section: .home, title: "Home", lines: [
            "Grab and go: six grab lists for a quick outing. Tap one, then tick what is in your hand.",
            "Create new trip: a name, Dates (tap the first day, then the last), Quick if only the lists you tick should come along.",
            "Create trip is always ready: if a name or a list is missing, it says so right under it.",
            "Pick the lists, then Transport, Season and Food, and Create trip. The trip gathers everything those lists hold.",
            "This Device: how many trips, things and lists this device holds."]),
        Topic(section: .events, title: "Packing a trip", lines: [
            "Tap a line to tick it; tap again to take it back. The round button by a heading ticks the whole section.",
            "The arrow before a section's name folds it away; tap it again to open. A trip remembers its folds.",
            "⊘ means not this time: it stays on the list, is not packed, and leaves the count. ↻ brings it back.",
            "Sorting: When (by the packing timeline), Into (by bag), From where (by where it is kept at home), Category.",
            "Weather: type the place; you get one line and only the rain or cold gear you have not packed yet, each with a +.",
            "Bags: how full each bag is against its max weight; the ⓘ explains the colours (green fine, orange close, red over).",
            "Sorted From where, Set place gives a thing under \u{201C}No place set\u{201D} its place in two taps.",
            "Type a thing at the bottom to add it to this trip only.",
            "At the very end of the list, Delete this trip asks first, then removes the trip. Your things and lists stay."]),
        Topic(section: .events, title: "After a trip", lines: [
            "Review: tap what you did not use, add what you missed, Save.",
            "Nothing is removed. \u{201C}Didn't use\u{201D} adds to each thing's history; what you missed goes onto a list for next time."]),
        Topic(section: .events, title: "Trips", lines: [
            "Now, Coming up and Been. Each trip says Planned, Packing or Ready.",
            "Reviewed trips fold away. Your year shows when you travel, month by month."]),
        Topic(section: .templates, title: "Your lists", lines: [
            "The building blocks of every trip, on their shelves (GA, WET and so on).",
            "+ New makes a list. Open one to rename it, add or take off things, and set How many and Section for this list.",
            "Delete this list asks first. Your things stay."]),
        Topic(section: .care, title: "Care", lines: [
            "Your things: every thing you own; open one to change it or put it on a list.",
            "Containers: your bags with max weight, litres and empty weight. Tap a bag's name for its own page: rename it, see what usually goes in it and its trips, or delete it (its things move to a bag you choose).",
            "All your things · table: a spreadsheet. Sort, filter, choose columns; tick several and Change all, with Undo.",
            "Services: List or Calendar. Done today moves a service on; Today brings the calendar back to this month."]),
        Topic(section: .actions, title: "Actions", lines: [
            "To do: things to sort out before you go.",
            "To buy: what to get, with worn-out or run-down things suggested."]),
        Topic(section: .settings, title: "Settings", lines: [
            "Save a backup to a file, or restore from one. Before a restore, a copy of what was here is kept, and you can go back to it.",
            "Your lists: storage places, owners, packers, conditions and the \u{201C}When\u{201D} steps.",
            "Worth a look appears only when something in the library seems wrong."]),
        Topic(section: .settings, title: "iPhone and Mac", lines: [
            "Both hold the same library through iCloud. A change on one reaches the other within a minute or so.",
            "The magnifier at the top of most screens searches everything at once."]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            GuideHeader(title: "How it works")
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(HowItWorksScreen.topics.enumerated()), id: \.offset) { n, t in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                SectionMark(section: t.section, size: 24, weight: 1.9).foregroundStyle(t.section.color)
                                Text(t.title).font(.system(size: 19, weight: .heavy)).foregroundStyle(Theme.ink)
                            }
                            ForEach(t.lines, id: \.self) { line in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Circle().fill(t.section.color).frame(width: 6, height: 6).offset(y: -2)
                                    Text(line).font(.system(size: 16)).foregroundStyle(Theme.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("guide-topic-\(n)")
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-howitworks")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }
}
