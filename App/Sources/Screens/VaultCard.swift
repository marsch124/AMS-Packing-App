import SwiftUI
import UniformTypeIdentifiers
import PackingCore
import PackingLibrary

/// "Send to Obsidian" on a reviewed trip (0.70, spec 07 part 8; spec 03 "The trip page in
/// his vault"). The trip becomes one Markdown page in the folder he picked once — his
/// choice, the vault's Areas/Travel — named "<yyyy-mm> <trip name>.md"; sending again
/// replaces it.
///
/// The MAC writes it (the folder lives there): on the Mac the button writes at once — and
/// asks for the folder the first time, or when the folder has gone away. On the iPhone
/// the button marks the trip "waiting for the Mac"; the Mac writes it as soon as it is
/// open. A saved review asks for the page by itself (`saveReview`), on either device.
/// The button is never grey (his rule): it always does something, and the line under it
/// says what happened.
struct VaultCard: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @ObservedObject private var shelf = VaultShelf.shared
    @State private var picking = false
    /// Send was pressed and the folder picker asked: write as soon as it is answered.
    @State private var sendAfterPicking = false

    var body: some View {
        let trip = model.library.trip(tripId)
        let waiting = trip.map(Library.isWaitingForVault) ?? false
        let written = model.library.vaultWritten(tripId: tripId)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Obsidian").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("trip-vault-title")
                    status(waiting: waiting, written: written)
                }
                Spacer(minLength: 8)
                Button { send() } label: {
                    FieldButtonLabel(title: "Send to Obsidian", tint: AppSection.events.color)
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("trip-vault-send")
            }
            #if os(macOS)
            if let name = shelf.folderName {
                HStack(spacing: 6) {
                    Text("Folder: \(name)").font(.system(.footnote)).foregroundStyle(Theme.muted)
                        .lineLimit(1).truncationMode(.middle)
                        .accessibilityIdentifier("trip-vault-folder-name")
                    Button("Change") { sendAfterPicking = false; pick() }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.events.color)
                        .accessibilityIdentifier("trip-vault-folder")
                }
            }
            if shelf.testFolder != nil, !shelf.readBack.isEmpty {
                // The tests' look into the folder (under -uiTestingVault only).
                Text(shelf.readBack).font(.system(.caption2).monospaced()).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("trip-vault-check")
            }
            #endif
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trip-vault")
        #if os(macOS)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { sendAfterPicking = false; return }
            shelf.choose(url)
            if sendAfterPicking { sendAfterPicking = false; shelf.write(tripId, model: model) }
        }
        #endif
    }

    /// The line under "Obsidian": where the page stands. Each state has its own id, so a
    /// test reads the state without reading the words.
    @ViewBuilder
    private func status(waiting: Bool, written: (file: String, at: String)?) -> some View {
        #if os(macOS)
        if let trouble = shelf.trouble {
            line(trouble, id: "trip-vault-trouble", tint: AppSection.actions.color)
        } else if shelf.folderName == nil {
            line(waiting ? "Waiting for a folder. Send asks for it once \u{2014} your vault's Areas/Travel."
                         : "Send asks for the folder once \u{2014} your vault's Areas/Travel.",
                 id: "trip-vault-nofolder")
        } else if waiting {
            line("Writing the page\u{2026}", id: "trip-vault-waiting")
        } else if let written {
            line("Written: \(written.file)\(VaultCard.day(written.at))", id: "trip-vault-written")
        } else {
            line("Not in your vault yet.", id: "trip-vault-status")
        }
        #else
        if waiting {
            line("Waiting for the Mac \u{2014} it writes the page the next time it is open.", id: "trip-vault-waiting")
        } else if let written {
            line("Written by the Mac: \(written.file)\(VaultCard.day(written.at))", id: "trip-vault-written")
        } else {
            line("The Mac writes this trip's page into your vault.", id: "trip-vault-status")
        }
        #endif
    }

    private func line(_ words: String, id: String, tint: Color = Theme.muted) -> some View {
        Text(words).font(.system(.footnote)).foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(id)
    }

    /// " · 7 Oct 2026" for the moment it was written, in this device's days.
    static func day(_ iso: String) -> String {
        let d = Library.vaultDay(iso, .current)
        return d.isEmpty ? "" : " \u{00B7} \(Library.vaultDate(d))"
    }

    private func send() {
        #if os(macOS)
        if shelf.write(tripId, model: model) == .needsFolder {
            sendAfterPicking = true
            pick()
        }
        #else
        model.change { _ = $0.askForVaultPage(tripId: tripId) }
        #endif
    }

    #if os(macOS)
    /// The system's folder picker — or, under `-uiTestingVault`, its test folder at once
    /// (no test can drive the system's panel).
    private func pick() {
        if let test = shelf.testFolder {
            shelf.choose(test)
            if sendAfterPicking { sendAfterPicking = false; shelf.write(tripId, model: model) }
        } else {
            picking = true
        }
    }
    #endif
}
