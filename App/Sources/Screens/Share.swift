import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import PackingCore
import PackingLibrary
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// Sharing — the web app's share links and QR codes (gap list, 2026-09-27): a trip,
// a template or a grab list as a link that opens in the web app (for anyone) and
// in this app (Settings → Open a shared link); a QR code when the link is short
// enough; a trip also as a file.

enum Clipboard {
    static func put(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
    static func read() -> String {
        #if os(macOS)
        NSPasteboard.general.string(forType: .string) ?? ""
        #else
        UIPasteboard.general.string ?? ""
        #endif
    }
}

enum QRCode {
    /// A QR code for the text, or nil when it is too long for one (a QR code holds
    /// under 3 000 characters; a week's trip is often more).
    static func image(_ text: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "L"
        guard let out = filter.outputImage else { return nil }
        let big = out.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        return CIContext().createCGImage(big, from: big.extent)
    }
}

/// What a share button hands the share screen.
struct ShareOffer: Identifiable {
    let id = UUID()
    var title: String
    var link: String?
    var file: (fileName: String, data: Data)? = nil
}

/// A small "Share" button that makes the link when pressed and owns its sheet.
struct ShareDoor: View {
    let id: String
    var tint: Color = AppSection.events.color
    /// Wide = the big framed button at the foot of a trip, beside Save as Excel
    /// (his test D.22); otherwise the outlined button in a sheet's top bar.
    var wide = false
    /// Only the drawn mark — for a top bar with no room for the word (a grab list).
    var markOnly = false
    let make: () -> ShareOffer
    @State private var offer: ShareOffer?

    var body: some View {
        Group {
            if wide {
                Button { offer = make() } label: {
                    WideButtonLabel(title: "Share", tint: tint) { ShareMark() }
                }
                .buttonStyle(.plain)
            } else {
                Button { offer = make() } label: {
                    HStack(spacing: 6) {
                        ShareMark().frame(width: 18, height: 18)
                        if !markOnly { Text("Share") }
                    }
                }
                .buttonStyle(HeaderButtonStyle(tint: tint, filled: false))
            }
        }
        .focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityLabel("Share")
        .sheet(item: $offer) { ShareScreen(offer: $0) }
    }
}

struct ShareScreen: View {
    let offer: ShareOffer
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var fileURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(offer.title).font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.ink).lineLimit(1)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.events.color)
                    .accessibilityIdentifier("share-done")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 14) {
                    if let link = offer.link {
                        if let qr = QRCode.image(link) {
                            Image(decorative: qr, scale: 1)
                                .interpolation(.none).resizable().scaledToFit()
                                .frame(maxWidth: 260).padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                                .frame(maxWidth: .infinity)
                                .accessibilityElement()
                                .accessibilityLabel("QR code")
                                .accessibilityIdentifier("share-qr")
                        } else {
                            Text("Too long for a QR code. Send the link instead.")
                                .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                                .accessibilityIdentifier("share-qr-toolong")
                        }
                        Text(link)
                            .font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.muted)
                            .lineLimit(3).truncationMode(.middle)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("share-link")
                        HStack(spacing: 10) {
                            if let url = URL(string: link) {
                                ShareLink(item: url) {
                                    Text("Send…").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.events.color))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("share-send")
                            }
                            Button { Clipboard.put(link); copied = true } label: {
                                Text(copied ? "Copied" : "Copy link").font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(AppSection.events.color)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.events.color, lineWidth: 1.4))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("share-copy")
                            .accessibilityValue(copied ? "copied" : "")
                        }
                    } else if offer.file != nil {
                        Text("This is too big for a link. Share it as a file instead.")
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("share-toolong")
                    } else {
                        // No link and no file: a template or a grab list with nothing on
                        // it. It said "too big … share it as a file" until 5 Oct 2026 —
                        // the wrong reason, and there is no file for these.
                        Text("There is nothing on it to share yet.")
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("share-empty")
                    }
                    if let url = fileURL {
                        ShareLink(item: url) {
                            Text("Share as a file").font(.system(size: 17, weight: .bold))
                                .foregroundStyle(AppSection.events.color)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.events.color, lineWidth: 1.4))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("share-file")
                    }
                    Text("The link opens in the web app, and in this app under Settings → Open a shared link.")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear(perform: writeFile)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("share-screen")
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }

    /// The trip's file, written where the share sheet can hand it on.
    private func writeFile() {
        guard let file = offer.file else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.fileName)
        if (try? file.data.write(to: url)) != nil { fileURL = url }
    }
}

/// Settings → Open a shared link: paste a link or code from the web app or from
/// this app, see what it holds, and take it in.
struct OpenSharedScreen: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var found: SharedThing?
    @State private var tried = false
    @State private var askingToReplace = false
    @State private var done = ""
    /// A shared template whose name he already has is added under another name —
    /// what New and Rename ask too (the spec pass, 5 Oct 2026).
    @State private var templateName = ""
    @State private var addNeeds = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Open a shared link").font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.settings.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.settings.color)
                    .accessibilityIdentifier("shared-done")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 12) {
                    Text("A trip, a template or a grab list someone shared, from the web app or this one.")
                        .font(.system(size: 15)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("Paste the link or code", text: $text, axis: .vertical)
                        .textFieldStyle(.plain).lineLimit(1...4)
                        .font(.system(size: 15, design: .monospaced)).foregroundStyle(Theme.ink)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                        .accessibilityIdentifier("shared-input")
                    HStack(spacing: 10) {
                        Button { text = Clipboard.read(); open() } label: {
                            Text("Paste and open").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.settings.color))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("shared-paste")
                        Button { open() } label: {
                            Text("Open").font(.system(size: 16, weight: .bold)).foregroundStyle(AppSection.settings.color)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.settings.color, lineWidth: 1.4))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("shared-open")
                    }
                    if tried && found == nil {
                        Text("This is not an AMS Packing link or code.")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(AppSection.actions.color)
                            .accessibilityIdentifier("shared-bad")
                    }
                    if let found { preview(found) }
                    if !done.isEmpty {
                        Text(done).font(.system(size: 15, weight: .bold)).foregroundStyle(AppSection.events.color)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("shared-result")
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shared-screen")
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
    }

    private func open() {
        found = Library.readShared(text)
        tried = true
        done = ""
        askingToReplace = false
        addNeeds = ""
        if case .template(let l)? = found { templateName = model.library.freeTemplateName(l.name) }
    }

    @ViewBuilder private func preview(_ thing: SharedThing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            switch thing {
            case .trip(let t):
                line("A trip", t.name.isEmpty ? "Untitled trip" : t.name, "\(t.entries.count) things")
                bigButton("Add this trip", id: "shared-add") {
                    model.change { _ = $0.importTrip(t) }
                    finish("Added. It is under Trips, nothing ticked.")
                }
            case .template(let l):
                // An always-packed or transport template stays one: said before he adds it.
                line(l.role == "base" ? "An always-packed template" : (l.role == "transport" ? "A transport template" : "A template"),
                     l.name, "\(l.items.count) things")
                if model.library.templateNameTaken(l.name) {
                    Text("You already have a template called \u{201C}\(l.name)\u{201D}. This one needs a name of its own:")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("shared-name-taken")
                    TextField("A name you do not have yet", text: $templateName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                        .accessibilityIdentifier("shared-new-name")
                }
                bigButton("Add as a new template", id: "shared-add") { addTemplate(l) }
                    .needsLine($addNeeds, typed: templateName, id: "shared-add-needs")
                if let mine = model.library.templateNamed(l.name) {
                    if askingToReplace {
                        HStack(spacing: 10) {
                            Text("Replace your \(mine.name)?").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                            Spacer()
                            Button("Keep mine") { askingToReplace = false }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                                .accessibilityIdentifier("shared-replace-no")
                            Button {
                                let id = mine.id
                                model.change { _ = $0.replaceTemplate(id: id, with: l) }
                                finish("Replaced your \(mine.name). Trips that use it keep working.")
                            } label: {
                                Text("Replace").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                                    .padding(.horizontal, 14).frame(minHeight: 36)
                                    .background(Capsule().fill(AppSection.actions.color))
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("shared-replace-yes")
                        }
                        // What Replace does, before he says yes (the spec pass, 2026-10-05:
                        // it used to take his icon, sections, bags and answers without a word).
                        Text(model.library.replaceWords(id: mine.id, with: l))
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("shared-replace-says")
                    } else {
                        Button("Replace your \(mine.name) instead") { askingToReplace = true }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(AppSection.templates.color)
                            .accessibilityIdentifier("shared-replace")
                    }
                }
            case .grab(let g):
                line("A grab list", g.name, "\(g.items.count) things")
                bigButton("Add it to your grab lists", id: "shared-add") {
                    var made: GrabDefinition?
                    model.change { made = $0.importGrab(g) }
                    // Home holds eight (since 0.46): a free place takes it, else it waits.
                    let onHome = made.map { m in model.library.homeGrabLists().contains { $0.id == m.id } } ?? false
                    finish(onHome ? "Added — it is on Home, in a free place."
                                  : "Added \u{2014} it waits in Grab Lists, as Home is full. Put it on Home when you want it there.")
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shared-preview")
    }

    /// A shared template as a new one of his — under its own name, or the one he
    /// gave it when he has a template of that name already.
    private func addTemplate(_ l: SharedList) {
        let taken = model.library.templateNameTaken(l.name)
        let name = jsTrim(templateName)
        if taken && name.isEmpty { addNeeds = "Give the template a name."; return }
        if taken && model.library.templateNameTaken(name) { addNeeds = "Pick a name you do not have yet."; return }
        var made: PackList?
        model.change { made = $0.importTemplate(l, named: taken ? name : nil) }
        guard let made else { addNeeds = "Pick a name you do not have yet."; return }
        switch made.role {
        case "base": finish("Added. It is under Templates, Always packed: every new trip packs it. Things you already had keep your details.")
        case "transport": finish("Added. It is under Templates, By transport: every new \(made.transport.isEmpty ? "" : made.transport + " ")trip packs it. Things you already had keep your details.")
        default: finish("Added. It is under Templates. Things you already had keep your details.")
        }
    }

    private func line(_ kind: String, _ name: String, _ count: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kind.uppercased()).font(.system(size: 12, weight: .heavy)).kerning(0.6).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("shared-kind")
            Text(name).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                .accessibilityIdentifier("shared-name")
            Text(count).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
        }
    }

    private func bigButton(_ title: String, id: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.events.color))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }

    private func finish(_ said: String) {
        found = nil
        tried = false
        text = ""
        done = said
    }
}

/// The door in Settings, owning its sheet.
struct OpenSharedDoor: View {
    @EnvironmentObject var model: LibraryModel
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open a shared link").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("A trip, template or grab list someone shared").font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1)
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
        .accessibilityIdentifier("settings-openshared")
        .sheet(isPresented: $open) { OpenSharedScreen().environmentObject(model) }
    }
}
