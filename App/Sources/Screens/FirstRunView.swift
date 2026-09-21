import SwiftUI
import UniformTypeIdentifiers
import PackingLibrary

/// Nothing on this device. That is NOT a verdict — a new device cannot tell
/// "nothing has arrived yet" from "there is nothing" — so it never decides by
/// itself, and it never plants starter lists. Two doors (docs/store.md, rule 2).
struct FirstRunView: View {
    @EnvironmentObject var model: LibraryModel
    @State private var picking = false
    @State private var problem: String?

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            SectionMark(section: .home, size: 84, weight: 1.6).foregroundStyle(AppSection.home.color)
            Text("No lists on this device yet")
                .font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Door(title: "My other device has my lists",
                     detail: model.usesICloud ? "Leave this open. They arrive through iCloud."
                                              : "This build does not use iCloud.",
                     filled: false)
                    .accessibilityIdentifier("first-run-wait")
                Button { picking = true } label: {
                    Door(title: "This is my first device", detail: "Bring in a backup file from the web app.", filled: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("first-run-import")
            }
            .frame(maxWidth: 420)

            if let problem {
                Text(problem).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color(hex: 0xdc3d43))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("first-run-problem")
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                try model.importBackup(try Data(contentsOf: url))
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}

private struct Door: View {
    let title: String
    let detail: String
    let filled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 19, weight: .heavy))
            Text(detail).font(.system(size: 16, weight: .medium)).opacity(0.85)
        }
        .foregroundStyle(filled ? Color.white : Theme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(filled ? AppSection.home.color : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(filled ? Color.clear : Theme.line, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

/// Home, until the trip builder is here: what this device holds, in numbers —
/// so two devices can be compared by eye.
struct LibrarySummary: View {
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        let lib = model.library
        VStack(spacing: 18) {
            Spacer()
            SectionMark(section: .home, size: 72, weight: 1.6).foregroundStyle(AppSection.home.color)
            HStack(spacing: 10) {
                Tile(number: lib.templates.count, label: "Templates", id: "count-templates", color: AppSection.templates.color)
                Tile(number: lib.items.count, label: "Things", id: "count-things", color: AppSection.care.color)
                Tile(number: lib.trips.count, label: "Trips", id: "count-trips", color: AppSection.events.color)
            }
            .frame(maxWidth: 460)
            if let r = model.lastImport {
                Text("Imported: \(r.rows) rows, \(r.lines) trip lines, every one checked.")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("import-report")
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
}

private struct Tile: View {
    let number: Int
    let label: String
    let id: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(number)").font(.system(size: 34, weight: .heavy).monospacedDigit()).foregroundStyle(color)
                .accessibilityIdentifier(id)
            Text(label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 86)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
    }
}
