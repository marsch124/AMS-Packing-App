import SwiftUI
import PackingCore
import PackingLibrary
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// Lost luggage, part C (0.80, his yes of 13 Oct 2026; spec 07 part 18 C) — the Lost bag page: on
// a trip, per bag, everything a baggage desk asks for, in a calm layout he can hand over or read
// out, with Share as PDF and Copy as text. What it says is the model's (`PackingLibrary/LostBag.swift`,
// `Library.lostBag(tripId:bag:)`); a row that is not filled in opens where it is filled in. Here
// too: his details for the desk (`DeskDetailsScreen`, from Settings and This is me), the small
// "Lost bag?" door, and the PDF (`LostBagPDF`, drawn with SwiftUI's ImageRenderer).

/// A bag whose Lost bag page is open — a sheet's item.
struct LostBagOpen: Identifiable, Equatable {
    let bag: String
    var id: String { bag }
}

/// "Lost bag?" — the small door to a bag's page: on the Bags card under each bag, and under each
/// bag's photos in the Packing day.
struct LostBagDoor: View {
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Lost bag?").font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.events.color)
                .lineLimit(1).fixedSize()
                .padding(.horizontal, 10).frame(minHeight: 26)
                .overlay(Capsule().stroke(AppSection.events.color, lineWidth: 1.2))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityLabel("Lost bag")
    }
}

// MARK: - The page

struct LostBagScreen: View {
    let tripId: String
    let bag: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var opened: Opened?
    @State private var copied = false
    /// Under the tests: what Share as PDF wrote ("PDF ready — 2 pages").
    @State private var pdfSaid = ""
    /// The bag-tag number's field is open on the page (its row shows otherwise), and what is typed.
    /// Two states, not one optional: the field writes its text back as it loses focus, and a
    /// binding that opened the field on any write opened it again right after Save.
    @State private var tagOpen = false
    @State private var tagText = ""
    @FocusState private var typingTag: Bool
    #if os(macOS)
    @State private var anchor = ShareAnchorBox()
    #endif

    /// ONE sheet with a destination (the Search lesson: several sheets on one view).
    enum Opened: Identifiable {
        case desk(DeskField), trip, bag(String), photo(Int)
        #if os(iOS)
        case share(URL)
        #endif
        var id: String {
            switch self {
            case .desk(let f): return "desk-\(f.rawValue)"
            case .trip: return "trip"
            case .bag(let id): return "bag-\(id)"
            case .photo(let k): return "photo-\(k)"
            #if os(iOS)
            case .share(let url): return "share-\(url.path)"
            #endif
            }
        }
    }

    private var tint: Color { AppSection.events.color }
    private var heading: Color { Library.LoopStep.pack.words(scheme) }

    var body: some View {
        let page = model.library.lostBag(tripId: tripId, bag: bag)
        VStack(spacing: 0) {
            header
            if let page {
                KeyboardAwayScroll {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Everything a baggage desk asks for. Hand it over, read it out, or share it.")
                            .font(.system(.footnote)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("lost-lead")
                        if !page.missingWords.isEmpty {
                            Text(page.missingWords).font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(AppSection.care.color)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("lost-missing")
                        }
                        card("About you", id: "lost-you") { rows(page.you, page) }
                        card("The trip", id: "lost-trip") { trip(page) }
                        card("The bag", id: "lost-bag") { bagCard(page) }
                        card("Photos", id: "lost-photos") { photos(page) }
                        card("A few things in it", id: "lost-inside") { inside(page) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.top, 2).padding(.bottom, 24)
                }
                foot(page)
            } else {
                // The trip (or the bag's lines) gone while it is open: nothing to show — close.
                Color.clear.onAppear { dismiss() }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $opened) { o in
            switch o {
            case .desk(let f): DeskDetailsScreen(focus: f).environmentObject(model)
            case .trip: TripSettingsScreen(tripId: tripId).environmentObject(model)
            case .bag(let id): BagDetail(bagId: id).environmentObject(model)
            case .photo(let k):
                let shown = shots()
                BigPhoto(images: shown.map(\.image), captions: shown.map(\.caption), start: k)
            #if os(iOS)
            case .share(let url): ShareSheet(url: url).presentationDetents([.medium, .large])
            #endif
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lost-screen")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lost bag").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                Text(bag).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("lost-heading")
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                .keyboardShortcut(.cancelAction)            // Escape closes it, as Done does
                .accessibilityIdentifier("lost-done")
        }
        .padding(16)
    }

    private func card<C: View>(_ title: String, id: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(.subheadline, weight: .semibold)).foregroundStyle(heading)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    @ViewBuilder private func rows(_ rows: [LostBagRow], _ page: LostBagPage) -> some View {
        ForEach(rows) { row in
            LostBagRowView(row: row) { fill(row, page) }
        }
    }

    // MARK: The trip

    @ViewBuilder private func trip(_ page: LostBagPage) -> some View {
        Text(page.tripLine).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 4)
            .accessibilityIdentifier("lost-trip-name")
        ForEach(page.travel) { row in
            if row.fill == .tag, tagOpen {
                tagField(page)
            } else {
                LostBagRowView(row: row) { fill(row, page) }
            }
        }
        if !page.planeTrip {
            Text(LOST_NOT_PLANE).font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .accessibilityIdentifier("lost-trip-noplane")
        }
    }

    /// The bag-tag number, typed right here: it is on the stub the check-in desk gave him.
    private func tagField(_ page: LostBagPage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bag-tag number").font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
            HStack(spacing: 8) {
                TextField("Number on the bag tag", text: $tagText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                    .autocorrectionDisabled()
                    .focused($typingTag)
                    .onSubmit { saveTag(page) }
                    .accessibilityIdentifier("lost-trip-tag-field")
                Button { saveTag(page) } label: {
                    Text("Save").font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                        .background(Capsule().fill(tint))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("lost-trip-tag-save")
                Button("Cancel") { tagOpen = false; typingTag = false }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("lost-trip-tag-cancel")
            }
        }
        .padding(.vertical, 6)
        .onAppear { typingTag = true }
    }

    private func saveTag(_ page: LostBagPage) {
        let number = Library.cleanCode(tagText)
        let t = tripId, name = page.bag
        model.change { _ = $0.setBagTag(number, tripId: t, bag: name) }
        tagOpen = false
        typingTag = false
    }

    // MARK: The bag

    @ViewBuilder private func bagCard(_ page: LostBagPage) -> some View {
        rows(page.bagRows, page)
        let air = LostBagRow(key: "bag-airtag", label: "AirTag", lines: [page.airTagWords], fill: .bag, canBeMissing: false)
        LostBagRowView(row: air, value: page.airTag ? "yes" : "no", last: !page.airTag) { fill(air, page) }
        if page.airTag {
            Text(LOST_AIRTAG_HINT).font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
                .accessibilityIdentifier("lost-bag-airtag-hint")
        }
    }

    // MARK: Photos

    private struct Shot { let image: CGImage; let caption: String }

    /// The photos of the bag itself (how it looks, from its page), then this trip's photos of it
    /// packed — those on this device — then the photo of all the bags.
    private func ownImages() -> [CGImage] { LostBagPDF.ownImages(model.library, tripId: tripId, bag: bag) }

    private func shots() -> [Shot] {
        var all = ownImages().map { Shot(image: $0, caption: bag) }
        if let group = model.library.groupPhoto(tripId: tripId).flatMap({ JPEG.image(dataURL: $0.data) }) {
            all.append(Shot(image: group, caption: "All your bags"))
        }
        return all
    }

    @ViewBuilder private func photos(_ page: LostBagPage) -> some View {
        let own = ownImages()
        let group = model.library.groupPhoto(tripId: tripId).flatMap { JPEG.image(dataURL: $0.data) }
        if !own.isEmpty || group != nil {
            FlowRow(spacing: 10) {
                ForEach(Array(own.enumerated()), id: \.offset) { k, image in
                    thumb(image, caption: nil, k: k, id: "lost-photo-\(k)", label: "Photo \(k + 1) of the bag")
                }
                if let group {
                    thumb(group, caption: "All your bags", k: own.count, id: "lost-photo-all", label: "Photo of all your bags")
                }
            }
            .padding(.top, 2)
        }
        if page.noPhoto {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Photo of the bag").font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                    Text(LOST_NOT_FILLED).font(.system(.body)).foregroundStyle(AppSection.care.color)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("lost-photo-none")
                PhotoTakers(id: "lost-photo-take", testTitle: "Photo of the bag") { jpeg in
                    guard let jpeg else { return }
                    let t = tripId, b = bag
                    model.change { _ = $0.addBagPhoto(tripId: t, bag: b, jpeg: jpeg) }
                }
            }
            .padding(.top, own.isEmpty && group == nil ? 0 : 8)
        }
    }

    private func thumb(_ image: CGImage, caption: String?, k: Int, id: String, label: String) -> some View {
        VStack(spacing: 2) {
            Button { opened = .photo(k) } label: {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
                    .frame(width: 96, height: 96).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier(id)
            .accessibilityLabel(label)
            if let caption {
                Text(caption).font(.system(.footnote)).foregroundStyle(Theme.muted)
            }
        }
    }

    // MARK: A few things in it

    @ViewBuilder private func inside(_ page: LostBagPage) -> some View {
        if page.inside.isEmpty {
            Text(Library.lostNothingInside).font(.system(.body)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lost-inside-none")
        } else {
            ForEach(Array(page.inside.enumerated()), id: \.offset) { k, thing in
                Text(thing).font(.system(.body)).foregroundStyle(Theme.ink)
                    .frame(minHeight: Metrics.line, alignment: .leading)
                    .accessibilityIdentifier("lost-inside-\(k)")
            }
            if page.moreInside > 0 {
                Text("and \(page.moreInside) more").font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("lost-inside-more")
            }
        }
    }

    // MARK: The foot — Share as PDF and Copy as text

    private func foot(_ page: LostBagPage) -> some View {
        VStack(spacing: 6) {
            if !pdfSaid.isEmpty {
                Text(pdfSaid).font(.system(.footnote, weight: .semibold)).foregroundStyle(tint)
                    .accessibilityIdentifier("lost-pdf-said")
            }
            HStack(spacing: 10) {
                Button { share(page) } label: {
                    Text("Share as PDF").font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: Metrics.tap)
                        .background(RoundedRectangle(cornerRadius: 12).fill(tint))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                #if os(macOS)
                .background(ShareAnchor(box: anchor))
                #endif
                .accessibilityIdentifier("lost-pdf")
                Button { Clipboard.put(page.text); copied = true } label: {
                    Text(copied ? "Copied" : "Copy as text").font(.system(.body, weight: .semibold)).foregroundStyle(tint)
                        .frame(maxWidth: .infinity, minHeight: Metrics.tap)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: 1.4))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("lost-copy")
                .accessibilityValue(copied ? "copied" : "")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Theme.bg)
        .overlay(alignment: .top) { Theme.line.frame(height: 1) }
    }

    /// Draw the PDF, then hand it to the system's share sheet. Under the UI tests no share sheet
    /// opens (no test can work it): the page says what was written instead.
    private func share(_ page: LostBagPage) {
        guard let made = LostBagPDF.write(page, library: model.library) else {
            pdfSaid = "The PDF could not be made."
            return
        }
        if AMSPackingApp.testing {
            pdfSaid = "PDF ready \u{2014} \(made.pages) page\(made.pages == 1 ? "" : "s")"
            return
        }
        #if os(iOS)
        opened = .share(made.url)
        #else
        if let view = anchor.view {
            NSSharingServicePicker(items: [made.url]).show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
        #endif
    }

    // MARK: Filling in

    private func fill(_ row: LostBagRow, _ page: LostBagPage) {
        switch row.fill {
        case .me: opened = .desk(DeskField(rawValue: String(row.key.dropFirst("you-".count))) ?? .name)
        case .trip: opened = .trip
        case .tag:
            tagText = model.library.trips.first { $0.id == tripId }.map { Library.bagTag($0, bag: page.bag) } ?? ""
            tagOpen = true
        case .bag:
            if let id = page.bagId { opened = .bag(id); return }
            // Only a name on the lines: it becomes one of his bags first — its page needs a bag
            // (as Goes in the cabin and Has an AirTag do from a trip).
            let name = page.bag
            model.change { _ = $0.addBag(name: name) }
            if let id = model.library.bags().first(where: { normName($0.name) == normName(name) })?.id { opened = .bag(id) }
        }
    }
}

/// One row of the Lost bag page: its label over its lines — or "not filled in" in orange — and a
/// chevron; the whole row one button that opens where it is filled in.
struct LostBagRowView: View {
    let row: LostBagRow
    /// The value for VoiceOver and the tests; the row's words when not given.
    var value: String? = nil
    var last = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.label).font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                    if row.lines.isEmpty {
                        Text(LOST_NOT_FILLED).font(.system(.body)).foregroundStyle(AppSection.care.color)
                    } else {
                        ForEach(Array(row.lines.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.system(.body)).foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Spacer(minLength: 8)
                SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .onGrid(Metrics.glyph).foregroundStyle(Theme.faint)
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: Metrics.row, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { if !last { Theme.line.frame(height: 1) } }
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("lost-\(row.key)")
        .accessibilityLabel(row.label)
        .accessibilityValue(value ?? row.words)
    }
}

#if os(iOS)
/// The system's share sheet, for a file.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#else
/// Where the Mac's sharing menu opens: the Share as PDF button's own place.
final class ShareAnchorBox { weak var view: NSView? }

struct ShareAnchor: NSViewRepresentable {
    let box: ShareAnchorBox
    func makeNSView(context: Context) -> NSView { let v = NSView(); box.view = v; return v }
    func updateNSView(_ view: NSView, context: Context) { box.view = view }
}
#endif

// MARK: - His details for the desk

/// The four fields of For the lost-luggage desk.
enum DeskField: String, CaseIterable {
    case name, phone, email, address
}

/// For the lost-luggage desk: his name, phone, e-mail and home address — kept once for the
/// library (both devices, the backup), read by every Lost bag page. From Settings, from This is me
/// in Your choices → Owners, and from a Lost bag page's rows about him (`focus` = that field).
struct DeskDetailsScreen: View {
    var focus: DeskField? = nil
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var loaded = false
    @FocusState private var field: DeskField?

    private var tint: Color { AppSection.settings.color }
    private var typed: DeskDetails { DeskDetails(name: name, phone: phone, email: email, address: address) }
    private var changed: Bool { loaded && typed.cleaned != model.library.deskDetails() }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("For the lost-luggage desk").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("desk-title")
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: false)).focusEffectDisabled()
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("desk-cancel")
                // Never grey: with nothing changed it simply closes.
                Button("Save") { save() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                    .accessibilityIdentifier("desk-save")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What a baggage desk asks about you. Kept on your devices and in your backup, and shown only on a bag\u{2019}s Lost bag page.")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    labelled("Full name") {
                        TextField(model.library.me() ?? "As on your passport", text: $name)
                            .deskField().focused($field, equals: .name)
                            #if os(iOS)
                            .textContentType(.name)
                            #endif
                            .submitLabel(.next).onSubmit { field = .phone }
                            .accessibilityIdentifier("desk-name")
                    }
                    labelled("Phone") {
                        TextField("+46 70 000 00 00", text: $phone)
                            .deskField().focused($field, equals: .phone)
                            #if os(iOS)
                            .keyboardType(.numbersAndPunctuation)
                            .textContentType(.telephoneNumber)
                            #endif
                            .submitLabel(.next).onSubmit { field = .email }
                            .accessibilityIdentifier("desk-phone")
                    }
                    labelled("E-mail") {
                        TextField("you@example.com", text: $email)
                            .deskField().focused($field, equals: .email)
                            #if os(iOS)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .textContentType(.emailAddress)
                            #endif
                            .autocorrectionDisabled()
                            .submitLabel(.next).onSubmit { field = .address }
                            .accessibilityIdentifier("desk-email")
                    }
                    labelled("Home address") {
                        TextField("Street, postcode and town", text: $address, axis: .vertical)
                            .lineLimit(3...6)
                            .deskField(tall: true).focused($field, equals: .address)
                            #if os(iOS)
                            .textContentType(.fullStreetAddress)
                            #endif
                            .accessibilityIdentifier("desk-address")
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .interactiveDismissDisabled(changed)
        .onAppear {
            guard !loaded else { return }
            let d = model.library.deskDetails()
            name = d.name; phone = d.phone; email = d.email; address = d.address
            loaded = true
            if let focus { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { field = focus } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("desk-screen")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 480)
        #endif
    }

    private func labelled<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
            content()
        }
    }

    private func save() {
        if changed {
            let d = typed
            model.change { _ = $0.setDeskDetails(d) }
        }
        dismiss()
    }
}

private extension View {
    /// A field of For the lost-luggage desk: Body on the page's colour, rounded, a hairline round it.
    func deskField(tall: Bool = false) -> some View {
        textFieldStyle(.plain)
            .font(.system(.body)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 10).padding(.vertical, tall ? 8 : 0)
            .frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
    }
}

/// The door to For the lost-luggage desk — a row of Settings' first card (it owns its sheet, as
/// the guide doors do). Its line: what it holds, or "<name> · <phone>" once filled in.
struct DeskDoor: View {
    @EnvironmentObject var model: LibraryModel
    @State private var open = false

    var body: some View {
        let d = model.library.deskDetails()
        let name = model.library.deskName()
        let line = !name.isEmpty && !d.phone.isEmpty ? "\(name) \u{00B7} \(d.phone)" : "Your name, phone, e-mail and home address"
        Button { open = true } label: {
            SettingsDoorLabel(title: "For the lost-luggage desk", line: line)
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("settings-desk")
        .sheet(isPresented: $open) { DeskDetailsScreen().environmentObject(model) }
    }
}

/// Under This is me (Your choices → Owners), on the owner marked as him: his details for the desk.
struct DeskDetailsLink: View {
    @EnvironmentObject var model: LibraryModel
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            Text("For the lost-luggage desk\u{2026}").font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(AppSection.settings.color)
                .frame(minHeight: Metrics.chip).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("list-owners-desk")
        .sheet(isPresented: $open) { DeskDetailsScreen().environmentObject(model) }
    }
}

// MARK: - The PDF

/// The Lost bag page drawn again for paper: A4, always light, black on white — page 1 the facts in
/// two columns, page 2 the photos (only when there are some). SwiftUI's ImageRenderer draws each
/// page into a PDF context; no other library.
@MainActor
enum LostBagPDF {
    static let size = CGSize(width: 595, height: 842)

    /// The bag's pictures that are on this device: how it looks (its page), then packed on this trip.
    static func ownImages(_ library: Library, tripId: String, bag: String) -> [CGImage] {
        let look = library.bagDetails(bag: bag).photoIds.compactMap { id in library.photos.first { $0.id == id } }
        return (look + library.bagPhotos(tripId: tripId, bag: bag)).compactMap { JPEG.image(dataURL: $0.data) }
    }

    /// Write the PDF into the temporary folder: its file and how many pages it has.
    static func write(_ page: LostBagPage, library: Library) -> (url: URL, pages: Int)? {
        let own = ownImages(library, tripId: page.tripId, bag: page.bag)
        var pictures = own.enumerated().map { k, image in
            (image: image, caption: own.count > 1 ? "\(page.bag) \u{00B7} \(k + 1) of \(own.count)" : page.bag)
        }
        if let group = library.groupPhoto(tripId: page.tripId).flatMap({ JPEG.image(dataURL: $0.data) }) {
            pictures.append((image: group, caption: "All your bags"))
        }
        var views: [AnyView] = [AnyView(LostBagPDFFacts(page: page))]
        if !pictures.isEmpty {
            views.append(AnyView(LostBagPDFPhotos(bag: page.bag, pictures: pictures.map { LostBagPDFPhotos.Picture(image: $0.image, caption: $0.caption) })))
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Lost bag", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(page.pdfName)
        try? FileManager.default.removeItem(at: url)
        var box = CGRect(origin: .zero, size: size)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }
        for view in views {
            let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height)
                .background(Color.white).environment(\.colorScheme, .light))
            renderer.proposedSize = ProposedViewSize(size)
            renderer.render { _, draw in
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
            }
        }
        pdf.closePDF()
        return FileManager.default.fileExists(atPath: url.path) ? (url, views.count) : nil
    }
}

/// Page 1: the title, the trip, and the four blocks in two columns.
private struct LostBagPDFFacts: View {
    let page: LostBagPage
    private let ink = Color(red: 0.09, green: 0.14, blue: 0.16)
    private let grey = Color(red: 0.37, green: 0.44, blue: 0.47)
    private let rule = Color(red: 0.85, green: 0.88, blue: 0.89)
    private let missing = Color(red: 0.75, green: 0.40, blue: 0.10)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lost bag: \(page.bag)").font(.system(size: 24, weight: .bold)).foregroundStyle(ink)
                Text(page.tripLine).font(.system(size: 13, weight: .semibold)).foregroundStyle(grey)
            }
            rule.frame(height: 1)
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 16) {
                    block("About you", page.you)
                    VStack(alignment: .leading, spacing: 7) {
                        block("The trip", page.travel)
                        if !page.planeTrip {
                            Text(LOST_NOT_PLANE).font(.system(size: 9.5)).foregroundStyle(grey)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        block("The bag", page.bagRows)
                        fact("AirTag", [page.airTagWords])
                        if page.airTag {
                            Text(LOST_AIRTAG_HINT).font(.system(size: 9.5)).foregroundStyle(grey)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        let shots = page.lookIds.count + page.photoIds.count + (page.groupPhotoId.isEmpty ? 0 : 1)
                        fact("Photos", [shots == 0 ? "" : "\(shots), on the next page"])
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        title("A few things in it")
                        if page.inside.isEmpty {
                            Text(Library.lostNothingInside).font(.system(size: 11)).foregroundStyle(grey)
                        }
                        ForEach(Array(page.inside.enumerated()), id: \.offset) { _, thing in
                            Text(thing).font(.system(size: 11)).foregroundStyle(ink)
                        }
                        if page.moreInside > 0 {
                            Text("and \(page.moreInside) more").font(.system(size: 10)).foregroundStyle(grey)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            Text("Made with AMS Packing").font(.system(size: 8)).foregroundStyle(grey)
        }
        .padding(44)
        .frame(width: LostBagPDF.size.width, height: LostBagPDF.size.height, alignment: .topLeading)
        .background(Color.white)
    }

    private func title(_ words: String) -> some View {
        Text(words).font(.system(size: 13, weight: .bold)).foregroundStyle(ink).padding(.bottom, 2)
    }

    private func block(_ name: String, _ rows: [LostBagRow]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            title(name)
            ForEach(rows) { row in fact(row.label, row.lines) }
        }
    }

    private func fact(_ label: String, _ lines: [String]) -> some View {
        let shown = lines.filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 8.5, weight: .semibold)).foregroundStyle(grey)
            if shown.isEmpty {
                Text(LOST_NOT_FILLED).font(.system(size: 11).italic()).foregroundStyle(missing)
            }
            ForEach(Array(shown.enumerated()), id: \.offset) { _, line in
                Text(line).font(.system(size: 11)).foregroundStyle(ink).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Page 2: the photos, two to a row, each as large as its place allows, captioned.
private struct LostBagPDFPhotos: View {
    struct Picture { let image: CGImage; let caption: String }
    let bag: String
    let pictures: [Picture]

    var body: some View {
        let ink = Color(red: 0.09, green: 0.14, blue: 0.16)
        let grey = Color(red: 0.37, green: 0.44, blue: 0.47)
        let columns = pictures.count == 1 ? 1 : 2
        let rows = Int((Double(pictures.count) / Double(columns)).rounded(.up))
        let width = (LostBagPDF.size.width - 88 - CGFloat(columns - 1) * 16) / CGFloat(columns)
        let height = min(width * 1.1, (LostBagPDF.size.height - 150 - CGFloat(rows - 1) * 16) / CGFloat(max(1, rows)) - 18)
        return VStack(alignment: .leading, spacing: 14) {
            Text("Lost bag: \(bag) \u{2014} photos").font(.system(size: 18, weight: .bold)).foregroundStyle(ink)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(width), spacing: 16, alignment: .top), count: columns),
                      alignment: .leading, spacing: 16) {
                ForEach(Array(pictures.enumerated()), id: \.offset) { _, p in
                    VStack(alignment: .leading, spacing: 4) {
                        Image(decorative: p.image, scale: 1).resizable().scaledToFit()
                            .frame(maxWidth: width, maxHeight: height, alignment: .topLeading)
                        Text(p.caption).font(.system(size: 10, weight: .semibold)).foregroundStyle(grey)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(44)
        .frame(width: LostBagPDF.size.width, height: LostBagPDF.size.height, alignment: .topLeading)
        .background(Color.white)
    }
}
