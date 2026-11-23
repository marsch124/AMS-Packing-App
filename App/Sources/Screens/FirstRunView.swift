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
            Text("No templates on this device yet")
                .font(.system(.title2, weight: .bold)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Door(title: "My other device has my templates",
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
                Text(problem).font(.system(.callout, weight: .semibold)).foregroundStyle(Color(hex: 0xdc3d43))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("first-run-problem")
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        #if os(iOS)
        // Settings' only door on the iPhone since 0.110 is Home's nut, and on an empty device Home is this
        // screen — so until 0.129 an empty iPhone could not reach Settings at all (no Sync now, no restore
        // from a file there). It carries the nut too (spec 02 §1: Settings "still opens on an empty library").
        .overlay(alignment: .topTrailing) {
            Button { model.tabToOpen = .settings } label: {
                SectionMark(section: .settings, size: 22, weight: 1.9)
                    .foregroundStyle(AppSection.settings.color)
                    .frame(width: Metrics.tap + 4, height: Metrics.tap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("home-settings")
            .accessibilityLabel("Settings")
            .padding(.top, Metrics.screenTop).padding(.trailing, 16)
        }
        #endif
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
            Text(title).font(.system(.body, weight: .semibold))
            Text(detail).font(.system(.callout)).opacity(0.85)
        }
        .foregroundStyle(filled ? Color.white : Theme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(filled ? AppSection.home.color : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(filled ? Color.clear : Theme.line, lineWidth: 1))
        .contentShape(Rectangle())
    }
}
