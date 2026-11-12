import SwiftUI
import PackingCore
import PackingLibrary

// 0.124 — his seven picks of 12 Nov 2026 on a thing's page and around it: Lent to…, spare parts and
// refills, a claim letter, Sell it…, a P-touch label, a receipt shared by several things, and the
// quarterly check. What is said and when is decided in the model (LentOut, SpareParts, ClaimLetter,
// SellAd, ThingLabels, Papers, QuarterlyCheck); these are the screens.

private var careTint: Color { AppSection.care.color }

/// A page's top bar: Cancel (Escape on the Mac) and a full-colour main button.
private struct PageBar: View {
    let cancelId: String
    let main: String
    let mainId: String
    var cancel: () -> Void
    var act: () -> Void
    var body: some View {
        HStack {
            Button("Cancel", action: cancel)
                .buttonStyle(BarCancelStyle(tint: careTint)).focusEffectDisabled()
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier(cancelId)
            Spacer()
            Button(main, action: act)
                .buttonStyle(HeaderButtonStyle(tint: careTint, filled: true)).focusEffectDisabled()
                .font(.system(.body, weight: .semibold))
                .commandS { act() }
                .accessibilityIdentifier(mainId)
        }
    }
}

/// A full-colour wide button.
private func wide(_ title: String) -> some View {
    Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(.white)
        .frame(maxWidth: .infinity).frame(minHeight: Metrics.tap)
        .background(RoundedRectangle(cornerRadius: 10).fill(careTint))
        .contentShape(Rectangle())
}

/// A quiet wide button in the part's colour.
private func quietWide(_ title: String) -> some View {
    Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(careTint)
        .frame(maxWidth: .infinity).frame(minHeight: Metrics.tap)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(careTint.opacity(0.6), lineWidth: 1))
        .contentShape(Rectangle())
}

/// A small tag after a name ("Lent").
struct NameTag: View {
    let text: String
    let id: String
    var body: some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(careTint)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .overlay(Capsule().stroke(careTint, lineWidth: 1))
            .fixedSize()
            .accessibilityIdentifier(id)
    }
}

/// Files in the temporary folder, for Share.
enum ShareFiles {
    static func write(_ data: Data, name: String) -> URL? {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Share", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name.replacingOccurrences(of: "/", with: "-"))
        return (try? data.write(to: url, options: .atomic)) != nil ? url : nil
    }

    /// A thing's photos as JPEG files.
    static func photos(_ lib: Library, thingId: String, name: String) -> [URL] {
        lib.thingPhotos(id: thingId).enumerated().compactMap { n, p in
            Library.photoBytes(p).flatMap { write($0, name: "\(name) \(n + 1).jpg") }
        }
    }

    /// A thing's receipts as files.
    static func receipts(_ lib: Library, thingId: String, name: String) -> [URL] {
        lib.thingPapers(id: thingId).filter { $0.paper.kind == .receipt }.enumerated().compactMap { n, p in
            let pdf = Library.isPDF(p.photo)
            return Library.photoBytes(p.photo).flatMap { write($0, name: "\(name) receipt \(n + 1).\(pdf ? "pdf" : "jpg")") }
        }
    }
}

// MARK: - 1. Lent to…

struct ThingLentLine: View {
    @Binding var draft: Item
    @EnvironmentObject var model: LibraryModel
    @State private var editing = false

    var body: some View {
        Group {
            if Library.lent(draft) != nil {
                HStack(spacing: 8) {
                    Text(Library.lentLine(draft)).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                        .lineLimit(2).accessibilityIdentifier("thing-lent-says")
                    Spacer(minLength: 0)
                    Button { Library.setLent(&draft, nil) } label: {
                        Text("Back home").font(.system(.subheadline, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                            .background(Capsule().fill(careTint)).contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("thing-lent-back")
                }
                .padding(.horizontal, 12).frame(minHeight: Metrics.row)
            } else {
                Button { editing = true } label: {
                    HStack(spacing: 6) {
                        Text("Lent to\u{2026}").font(.system(.body, weight: .semibold)).foregroundStyle(careTint)
                        Text("who has it, since when").font(.system(.subheadline)).foregroundStyle(Theme.muted).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("thing-lent-open")
            }
        }
        .bCard()
        .sheet(isPresented: $editing) {
            LentPage(names: model.library.lentToNames()) { mark in
                if let mark { Library.setLent(&draft, mark) }
                editing = false
            }
        }
    }
}

private struct LentPage: View {
    let names: [String]
    let done: (LentMark?) -> Void
    @State private var to = ""
    @State private var day = Date()
    @State private var needs = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageBar(cancelId: "thing-lent-cancel", main: "Save", mainId: "thing-lent-save", cancel: { done(nil) }) { save() }
            Text("Lent to").font(.system(.largeTitle, weight: .bold)).foregroundStyle(careTint)
            VStack(alignment: .leading, spacing: 0) {
                TextField("Who has it?", text: $to)
                    .textFieldStyle(.plain).font(.system(.body))
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                    .onSubmit { save() }
                    .accessibilityIdentifier("thing-lent-to")
                Theme.line.frame(height: 1).padding(.leading, 12)
                HStack {
                    Text("Since").font(.system(.body)).foregroundStyle(Theme.ink)
                    Spacer()
                    DatePicker("", selection: $day, displayedComponents: .date).labelsHidden().tint(careTint)
                        .accessibilityIdentifier("thing-lent-date")
                }
                .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
            }
            .bCard()
            if !names.isEmpty {
                FlowRow(spacing: 6) {
                    ForEach(Array(names.prefix(8).enumerated()), id: \.offset) { n, name in
                        Button { to = name } label: {
                            Text(name).font(.system(.subheadline, weight: .semibold)).foregroundStyle(careTint)
                                .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                                .background(Capsule().fill(careTint.opacity(0.10))).contentShape(Capsule())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("thing-lent-name-\(n)")
                    }
                }
            }
            if needs {
                Text("Say who has it first.").font(.subheadline).foregroundStyle(AppSection.actions.color)
            }
            Text("A reminder comes three weeks after, at 9:00, to ask for it back \u{2014} and every three weeks while it is out.")
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.bg.ignoresSafeArea())
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }

    private func save() {
        guard !jsTrim(to).isEmpty else { needs = true; return }
        done(LentMark(to: to, on: Library.ymd(day)))
    }
}

// MARK: - 2. Spare parts and refills

struct ThingPartsCard: View {
    let thingId: String
    @EnvironmentObject var model: LibraryModel
    @State private var open = false
    @State private var name = ""
    @State private var months = 6

    var body: some View {
        let parts = Library.parts(model.library.items.first { $0.id == thingId })
        VStack(alignment: .leading, spacing: 6) {
            if open || !parts.isEmpty {
                Text("Spare parts and refills").font(.system(.headline)).foregroundStyle(careTint)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(parts.enumerated()), id: \.element.id) { n, p in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(p.name).font(.system(.body)).foregroundStyle(Theme.ink)
                                Text(p.line).font(.system(.subheadline)).foregroundStyle(Theme.muted)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("thing-part-\(n)")
                            Spacer(minLength: 0)
                            Button("Bought today") {
                                model.change { $0.partBought(thingId: thingId, partId: p.id, on: Today.local) }
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .font(.system(.subheadline, weight: .semibold)).foregroundStyle(careTint)
                            .accessibilityIdentifier("thing-part-\(n)-bought")
                            Button { model.change { $0.removePart(thingId: thingId, partId: p.id) } } label: {
                                Text("\u{2715}").font(.body.weight(.semibold)).foregroundStyle(Theme.muted)
                                    .frame(width: 32, height: Metrics.tap).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityLabel("Remove \(p.name)")
                            .accessibilityIdentifier("thing-part-\(n)-remove")
                        }
                        Theme.line.frame(height: 1)
                    }
                    TextField("A part or refill, e.g. Water filter", text: $name)
                        .textFieldStyle(.plain).font(.system(.body))
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                        .onSubmit { add() }
                        .accessibilityIdentifier("thing-part-name")
                    FlowRow(spacing: 6) {
                        ForEach(PART_MONTHS, id: \.self) { m in
                            let on = m == months
                            Button { months = m } label: {
                                Text(m == 0 ? "When needed" : "Every \(m) months")
                                    .font(.system(.subheadline, weight: .semibold)).lineLimit(1)
                                    .foregroundStyle(on ? .white : careTint)
                                    .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                                    .background(Capsule().fill(on ? careTint : careTint.opacity(0.10)))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityAddTraits(on ? .isSelected : [])
                            .accessibilityIdentifier("thing-part-every-\(m)")
                        }
                    }
                    Button { add() } label: { wide("Add, bought today") }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("thing-part-add")
                    Text("When one is due it goes onto To buy by itself; ticking it there counts as bought.")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .bCard()
            } else {
                Button { open = true } label: {
                    HStack(spacing: 6) {
                        Text("Spare parts and refills").font(.system(.body, weight: .semibold)).foregroundStyle(careTint)
                        Text("filters, bags, cartridges").font(.system(.subheadline)).foregroundStyle(Theme.muted).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .bCard()
                .accessibilityIdentifier("thing-parts-open")
            }
        }
    }

    private func add() {
        let n = jsTrim(name)
        guard !n.isEmpty else { return }
        let m = months
        model.change { _ = $0.addPart(thingId: thingId, name: n, months: m, last: Today.local) }
        name = ""
    }
}

/// Keeps To buy and the parts in step — as the app opens and comes to the front.
enum PartsWatch {
    @MainActor static func sync(_ model: LibraryModel) {
        guard model.state == .ready else { return }
        var probe = model.library
        guard probe.syncPartsToBuy(today: Today.local) else { return }
        model.change(named: "Spare parts to To buy", undoable: false) { _ = $0.syncPartsToBuy(today: Today.local) }
    }
}

// MARK: - 3, 4, 7. Claim letter · Sell it… · Label

struct ThingMoreActions: View {
    let thingId: String
    @Binding var draft: Item
    @EnvironmentObject var model: LibraryModel
    @State private var claim = false
    @State private var sell = false
    @State private var label = false

    var body: some View {
        VStack(spacing: 0) {
            if Library.canClaim(draft, today: Today.local) {
                row("Write a claim letter", "still inside its complaint right", id: "thing-claim-open") { claim = true }
                Theme.line.frame(height: 1).padding(.leading, 12)
            }
            if !Library.isGone(draft) {
                row("Sell it\u{2026}", "a ready Blocket ad", id: "thing-sell-open") { sell = true }
                Theme.line.frame(height: 1).padding(.leading, 12)
            }
            row("Label for P-touch", "scan it to open this thing", id: "thing-label-open") { label = true }
        }
        .bCard()
        .sheet(isPresented: $claim) {
            ClaimPage(thing: draft, receipts: ShareFiles.receipts(model.library, thingId: thingId, name: draft.name)) { claim = false }
        }
        .sheet(isPresented: $sell) {
            SellPage(thing: draft, photos: ShareFiles.photos(model.library, thingId: thingId, name: draft.name),
                     markSold: { price in
                         Library.setGone(&draft, GoneMark(on: Today.local, how: .sold, soldFor: Double(price)))
                         sell = false
                     }) { sell = false }
        }
        .sheet(isPresented: $label) {
            ThingLabelPage(thingId: thingId, name: draft.name).environmentObject(model)
        }
    }

    private func row(_ title: String, _ hint: String, id: String, act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 6) {
                Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(careTint)
                Text(hint).font(.system(.subheadline)).foregroundStyle(Theme.muted).lineLimit(1)
                Spacer(minLength: 0)
                Text("\u{203A}").foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 12).frame(minHeight: Metrics.tap).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }
}

private struct ClaimPage: View {
    let thing: Item
    let receipts: [URL]
    let close: () -> Void
    @State private var problem = ""
    @State private var copied = false

    var body: some View {
        let letter = Library.claimLetter(thing, problem: problem, today: Today.local)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button("Done", action: close)
                    .buttonStyle(HeaderButtonStyle(tint: careTint, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold))
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("claim-done")
            }
            Text("Claim letter").font(.system(.largeTitle, weight: .bold)).foregroundStyle(careTint)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Claim possible until \(Library.dayWords(Library.claimUntil(thing)))")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                    TextField("What is wrong? e.g. It no longer cools", text: $problem, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(.plain).font(.system(.body))
                        .padding(12).bCard()
                        .accessibilityIdentifier("claim-problem")
                    Text(letter).font(.system(.callout)).foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12).bCard()
                        .accessibilityIdentifier("claim-letter")
                    ShareLink(item: letter, subject: Text("Reklamation: \(thing.name)")) { wide("Share the letter") }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("claim-share")
                    Button { Clipboard.put(letter); copied = true } label: { quietWide(copied ? "Copied" : "Copy the letter") }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("claim-copy")
                    if !receipts.isEmpty {
                        ShareLink(items: receipts) { quietWide("Share the receipt") }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("claim-receipt")
                    } else {
                        Text("No receipt on this thing yet \u{2014} add one under Papers.")
                            .font(.footnote).foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.bg.ignoresSafeArea())
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }
}

private struct SellPage: View {
    let thing: Item
    let photos: [URL]
    let markSold: (Int) -> Void
    let close: () -> Void
    @State private var title = ""
    @State private var price = ""
    @State private var text = ""
    @State private var copied = false

    private var whole: String { "\(title)\n\(price) kr\n\n\(text)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button("Done", action: close)
                    .buttonStyle(HeaderButtonStyle(tint: careTint, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold))
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("sell-done")
            }
            Text("Sell it").font(.system(.largeTitle, weight: .bold)).foregroundStyle(careTint)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(spacing: 0) {
                        TextField("Title", text: $title).textFieldStyle(.plain).font(.system(.body, weight: .semibold))
                            .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                            .accessibilityIdentifier("sell-title")
                        Theme.line.frame(height: 1).padding(.leading, 12)
                        HStack {
                            Text("Price").font(.system(.body)).foregroundStyle(Theme.ink)
                            TextField("0", text: $price).textFieldStyle(.plain).font(.system(.body).monospacedDigit())
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .accessibilityIdentifier("sell-price")
                            Text("kr").foregroundStyle(Theme.muted)
                        }
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                    }
                    .bCard()
                    Text("Suggested from today\u{2019}s value, rounded to 50 kr.").font(.footnote).foregroundStyle(Theme.muted)
                    TextField("Text", text: $text, axis: .vertical)
                        .lineLimit(4...12).textFieldStyle(.plain).font(.system(.callout))
                        .padding(12).bCard()
                        .accessibilityIdentifier("sell-text")
                    Group {
                        if photos.isEmpty {
                            ShareLink(item: whole, subject: Text(title)) { wide("Share the ad") }
                        } else {
                            ShareLink(items: photos, subject: Text(title), message: Text(whole)) { wide("Share with the photos") }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sell-share")
                    Button { Clipboard.put(whole); copied = true } label: { quietWide(copied ? "Copied" : "Copy the ad") }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("sell-copy")
                    if let url = URL(string: "https://www.blocket.se/annonser/ny") {
                        Link(destination: url) { quietWide("Open Blocket") }
                            .accessibilityIdentifier("sell-blocket")
                    }
                    Button { markSold(Int(price.filter(\.isNumber)) ?? 0) } label: {
                        Text("Sold \u{2014} mark it as gone").font(.system(.subheadline, weight: .semibold)).foregroundStyle(careTint)
                            .frame(maxWidth: .infinity).frame(minHeight: Metrics.tap)
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("sell-sold")
                }
            }
        }
        .padding(16)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            let ad = Library.sellAd(thing, today: Today.local)
            title = ad.title; price = ad.price > 0 ? "\(ad.price)" : ""; text = ad.text
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 600)
        #endif
    }
}

struct ThingLabelPage: View {
    let thingId: String
    let name: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var file: URL?
    @State private var saving = false
    @State private var saved = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: careTint, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold))
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("thing-label-done")
            }
            Text("Label").font(.system(.largeTitle, weight: .bold)).foregroundStyle(careTint)
            if let code = model.library.thingLabelCode(id: thingId), let img = PlaceLabel.thingImage(code: code, name: name) {
                Text("Label for P-touch, 12 mm tape").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                Image(decorative: img, scale: 1)
                    .interpolation(.none).resizable()
                    .frame(width: CGFloat(img.width) * 0.75, height: CGFloat(img.height) * 0.75)
                    .accessibilityElement()
                    .accessibilityLabel("Label for \(name)")
                    .accessibilityIdentifier("thing-label")
                    .padding(.vertical, 8).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.line, lineWidth: 1))
                #if os(macOS)
                Button { saving = true } label: { wide("Save the label\u{2026}") }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("thing-label-share")
                    .fileExporter(isPresented: $saving, document: file.flatMap { PNGDocument(url: $0) },
                                  contentType: .png, defaultFilename: PlaceLabel.fileName(name)) { result in
                        if case .success(let url) = result { saved = "Saved: \(url.lastPathComponent)" } else { saved = "Not saved." }
                    }
                if !saved.isEmpty { Text(saved).font(.footnote).foregroundStyle(Theme.muted) }
                #else
                if let file {
                    ShareLink(item: file) { wide("Share the label") }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("thing-label-share")
                }
                #endif
                Text("In Brother\u{2019}s app, add it as a picture, 12 mm tape. Point the iPhone\u{2019}s camera at the printed label to open this thing.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            // The code is kept with the thing the first time its label is shown.
            if !model.library.isEmpty, model.library.items.first(where: { $0.id == thingId }).map(Library.labelCode)?.isEmpty == true {
                model.change(undoable: false) { _ = $0.giveThingLabelCode(id: thingId) }
            }
            if let code = model.library.thingLabelCode(id: thingId), let img = PlaceLabel.thingImage(code: code, name: name),
               let png = PlaceLabel.png(image: img) {
                file = ShareFiles.write(png, name: PlaceLabel.fileName(name))
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }
}

// MARK: - 8. One receipt for several things

struct ReuseReceiptPage: View {
    let thingId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let list = model.library.receiptsElsewhere(for: thingId)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(BarCancelStyle(tint: careTint)).focusEffectDisabled()
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("reuse-cancel")
                Spacer()
            }
            Text("Use a receipt").font(.system(.largeTitle, weight: .bold)).foregroundStyle(careTint)
            Text("One receipt for several things: tap it to put it on this thing too.")
                .font(.subheadline).foregroundStyle(Theme.muted)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.paper.id) { n, r in
                        Button {
                            model.change { _ = $0.sharePaper(r.paper, to: thingId) }
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                if let p = model.library.photos.first(where: { $0.id == r.paper.id }),
                                   let img = PhotoThumbs.image(p, side: 80) {
                                    Image(decorative: img, scale: 1).resizable().scaledToFill()
                                        .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    RoundedRectangle(cornerRadius: 6).fill(Theme.line).frame(width: 40, height: 40)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Receipt of \(r.thing.name)").font(.body).foregroundStyle(Theme.ink)
                                    if isYMD(String(r.paper.at.prefix(10))) {
                                        Text("kept \(Library.dayWords(String(r.paper.at.prefix(10))))")
                                            .font(.subheadline).foregroundStyle(Theme.muted)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("reuse-receipt-\(n)")
                        if n < list.count - 1 { Theme.line.frame(height: 1).padding(.leading, 62) }
                    }
                }
                .bCard()
            }
        }
        .padding(16)
        .background(Theme.bg.ignoresSafeArea())
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 420)
        #endif
    }
}

// MARK: - 6. The quarterly check

struct QuarterlyCheckScreen: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var goneAsk: Item?

    var body: some View {
        let rooms = model.library.toCheck(today: Today.local)
        VStack(spacing: 0) {
            HStack {
                BackArrow(title: "Inventory", tint: careTint, id: "check-back") { dismiss() }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: careTint, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold))
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("check-done")
            }
            .padding(.horizontal, 16).padding(.top, 8)
            Text("Quarterly check").font(.system(.largeTitle, weight: .bold)).foregroundStyle(careTint)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    let n = rooms.reduce(0) { $0 + $1.things.count }
                    Text(n == 0 ? "All looked at this quarter." : "Still have it? \(n) to look at.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("check-left")
                    let numbered = Array(rooms.enumerated())
                    ForEach(numbered, id: \.element.room) { r, room in
                        HStack {
                            Text(room.room).font(.system(.headline)).foregroundStyle(careTint)
                                .accessibilityIdentifier("check-room-\(r)")
                            Spacer()
                            Button("All still here") {
                                let ids = room.things.map(\.id)
                                model.change(named: "Still here: \(room.room)") { $0.stillHave(ids, today: Today.local) }
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .font(.system(.subheadline, weight: .semibold)).foregroundStyle(careTint)
                            .accessibilityIdentifier("check-room-all-\(r)")
                        }
                        .padding(.top, 6)
                        VStack(spacing: 0) {
                            ForEach(room.things, id: \.id) { it in
                                let k = rowNumber(it.id, rooms)
                                HStack(spacing: 10) {
                                    ThingPhotoThumb(item: it, id: "check-photo-\(k)", big: true) {}
                                    Text(it.name).font(.body).foregroundStyle(Theme.ink).lineLimit(1)
                                    Spacer(minLength: 4)
                                    Button("Gone\u{2026}") { goneAsk = it }
                                        .buttonStyle(.plain).focusEffectDisabled()
                                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                                        .accessibilityIdentifier("check-gone-\(k)")
                                    Button {
                                        model.change(named: "Still here: \(it.name)") { $0.stillHave([it.id], today: Today.local) }
                                    } label: {
                                        Text("Still here").font(.system(.subheadline, weight: .semibold)).foregroundStyle(.white)
                                            .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                                            .background(Capsule().fill(careTint)).contentShape(Capsule())
                                    }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("check-keep-\(k)")
                                }
                                .padding(.horizontal, 12).padding(.vertical, 4)
                            }
                        }
                        .bCard()
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .confirmationDialog("How did \(goneAsk?.name ?? "it") go?", isPresented: Binding(get: { goneAsk != nil }, set: { if !$0 { goneAsk = nil } }),
                            titleVisibility: .visible) {
            ForEach(GoneHow.allCases, id: \.self) { how in
                Button(how.label) {
                    if let it = goneAsk {
                        model.change(named: "Gone: \(it.name)") { lib in
                            _ = lib.updateThing(id: it.id) { Library.setGone(&$0, GoneMark(on: Today.local, how: how)) }
                        }
                    }
                    goneAsk = nil
                }
                .accessibilityIdentifier("check-how-\(how.rawValue)")
            }
            Button("Cancel", role: .cancel) { goneAsk = nil }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }

    /// A thing's number down the whole page (for the ids).
    private func rowNumber(_ id: String, _ rooms: [(room: String, things: [Item])]) -> Int {
        rooms.flatMap { $0.things.map(\.id) }.firstIndex(of: id) ?? 0
    }
}
