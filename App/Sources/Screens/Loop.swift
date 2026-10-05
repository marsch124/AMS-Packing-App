import SwiftUI
import PackingCore
import PackingLibrary

// The loop the app runs on — his picture (2026-09-27): "Phase 1 is the planning,
// making the lists, and performing, packing, and later on reviewing, and then
// refining and so on." Violet is about his LISTS, green about ONE trip: the same
// colours as the Templates and Trips tabs. On site joined it after Pack (their field
// test, 3 Oct 2026: "add a phase (in the graphics as well)… immediately after Pack").

extension Library.LoopStep {
    var tint: Color { aboutOneTrip ? AppSection.events.color : AppSection.templates.color }
    private var hex: String { aboutOneTrip ? "#2f9e63" : "#7c5cd6" }
    /// The tint made readable as words on this screen (his "bad text colour", 2026-09-26).
    func words(_ scheme: ColorScheme) -> Color { Color(hexString: readableHex(hex, dark: scheme == .dark)) }

    /// The tab where this step is done — its mark rides on the strip (his F.7:
    /// "symbols that show where create, pack, review and refine are made").
    var tab: AppSection {
        switch self {
        case .plan: return .home
        case .pack, .onSite, .review: return .events
        case .refine: return .templates
        }
    }
    var tabName: String {
        switch self {
        case .plan: return "Home"
        case .pack, .onSite, .review: return "Trips"
        case .refine: return "Templates"
        }
    }

    /// The few words inside the picture's box.
    var short: String {
        switch self {
        case .plan: return "Make templates, create a trip"
        case .pack: return "Tick things as they go in"
        case .onSite: return "Bought, left, notes, and packing for home"
        case .review: return "After it: unused, missed"
        case .refine: return "Keep or drop, from reviews"
        }
    }

    /// The same, in a sentence, under the picture.
    var explained: String {
        switch self {
        case .plan: return "Your templates hold what each kind of trip needs. A new trip gathers what its templates hold."
        case .pack: return "Tick each thing as it goes in. The count says when nothing is left."
        case .onSite: return "While you are away: what you bought, what you left on site, a note on a thing that needs care, and packing to go home. It opens on the trip once the trip has begun."
        case .review: return "After the trip: tap what you did not use, add what you missed. This looks back at one trip."
        case .refine: return "When two or more reviews agree, Refine offers to take a thing off a template — or keep it for good. Your templates get better, and the next trip starts from them."
        }
    }
}

/// The picture: Plan → Pack, down through On site to Review, back to Refine, and up
/// to Plan again — still two boxes side by side, so it reads at the same size on an
/// iPhone; the trip's three steps run down the right, the lists' two sit on the left.
/// `here` marks where a trip stands.
struct LoopPicture: View {
    var here: Library.LoopStep? = nil
    @Environment(\.colorScheme) private var scheme
    private let gap: CGFloat = 30

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) { box(.plan); LoopArrow(to: .right).frame(width: gap); box(.pack) }
                .fixedSize(horizontal: false, vertical: true)
            // On site in the middle of the right side; the long way back up the left,
            // from Refine to Plan, is one arrow beside it.
            HStack(spacing: 0) {
                LoopArrow(to: .up).frame(maxWidth: .infinity)
                Color.clear.frame(width: gap)
                VStack(spacing: 0) {
                    LoopArrow(to: .down).frame(height: 30)
                    box(.onSite)
                    LoopArrow(to: .down).frame(height: 30)
                }
                .frame(maxWidth: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 0) { box(.refine); LoopArrow(to: .left).frame(width: gap); box(.review) }
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                key(Library.LoopStep.plan, "About your templates")
                key(Library.LoopStep.pack, "About one trip")
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("loop-picture")
    }

    private func box(_ step: Library.LoopStep) -> some View {
        let on = here == step
        return VStack(spacing: 4) {
            Text("\(step.rawValue + 1) · \(step.name)")
                .font(.system(size: 18, weight: .heavy)).foregroundStyle(step.words(scheme))
            Text(step.short)
                .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                SectionMark(section: step.tab, size: 15, weight: 1.8).foregroundStyle(step.tab.color)
                Text("on \(step.tabName)").font(.system(size: 13, weight: .bold)).foregroundStyle(step.tab.color)
            }
            if on {
                Text("You are here")
                    .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(step.tint))
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(step.tint.opacity(on ? 0.24 : 0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(step.tint, lineWidth: on ? 3 : 1.2))
        // "You are here" is in the label: the Mac does not pass on the value of a
        // box that is not a control (its test found that, 2026-09-27).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(step.name): \(step.short), on \(step.tabName)" + (on ? ". You are here" : ""))
        .accessibilityIdentifier("loop-step-\(step.rawValue)")
    }

    private func key(_ step: Library.LoopStep, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(step.tint.opacity(0.24))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(step.tint, lineWidth: 1.2))
                .frame(width: 14, height: 14)
            Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
        }
    }
}

/// One arrow between two boxes, drawn (no stock art — his rule).
private struct LoopArrow: View {
    enum Way { case up, down, left, right }
    let to: Way

    var body: some View {
        Canvas { ctx, size in
            let (a, b): (CGPoint, CGPoint)
            switch to {
            case .right: (a, b) = (CGPoint(x: 4, y: size.height / 2), CGPoint(x: size.width - 4, y: size.height / 2))
            case .left: (a, b) = (CGPoint(x: size.width - 4, y: size.height / 2), CGPoint(x: 4, y: size.height / 2))
            case .down: (a, b) = (CGPoint(x: size.width / 2, y: 3), CGPoint(x: size.width / 2, y: size.height - 3))
            case .up: (a, b) = (CGPoint(x: size.width / 2, y: size.height - 3), CGPoint(x: size.width / 2, y: 3))
            }
            let angle = atan2(b.y - a.y, b.x - a.x), head: CGFloat = 7
            var p = Path()
            p.move(to: a); p.addLine(to: b)
            p.move(to: CGPoint(x: b.x - head * cos(angle - .pi / 5), y: b.y - head * sin(angle - .pi / 5)))
            p.addLine(to: b)
            p.addLine(to: CGPoint(x: b.x - head * cos(angle + .pi / 5), y: b.y - head * sin(angle + .pi / 5)))
            ctx.stroke(p, with: .color(Theme.muted), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// The five steps and what each means — the picture's words.
struct LoopWords: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Library.LoopStep.allCases, id: \.self) { step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(step.name).font(.system(size: 16, weight: .heavy)).foregroundStyle(step.words(scheme))
                        .frame(width: 72, alignment: .leading)
                    Text(step.explained).font(.system(size: 16)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Review looks back at one trip. Refine uses several reviews to make your templates better.")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }
}

/// The slim line on a trip, its review and Refine: the five steps, the one this
/// is at filled in. A tap opens the whole picture.
///
/// Five names and their marks do not fit an iPhone's width (On site joined, 3 Oct
/// 2026), so the strip slims down until it fits: every mark where there is room (the
/// Mac); then the mark of the step it is at only; then smaller words. The names stay
/// in every one — they are what is read.
struct LoopDoor: View {
    let here: Library.LoopStep
    /// Its own name on each screen: a sheet can sit over another strip.
    var id = "trip-loop"
    @Environment(\.colorScheme) private var scheme
    @State private var open = false

    private struct Fit { let marks: Bool; let size: CGFloat; let pad: CGFloat; let arrow: CGFloat; let space: CGFloat }
    private static let fits = [Fit(marks: true, size: 14, pad: 8, arrow: 14, space: 3),
                               Fit(marks: false, size: 14, pad: 7, arrow: 10, space: 2),
                               Fit(marks: false, size: 13, pad: 5, arrow: 8, space: 1)]

    var body: some View {
        Button { open = true } label: {
            ViewThatFits(in: .horizontal) {
                strip(LoopDoor.fits[0])
                strip(LoopDoor.fits[1])
                strip(LoopDoor.fits[2])
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityLabel("The loop")
        .accessibilityValue(here.name)
        .sheet(isPresented: $open) { LoopScreen(here: here) }
    }

    private func strip(_ fit: Fit) -> some View {
        HStack(spacing: fit.space) {
            ForEach(Library.LoopStep.allCases, id: \.self) { step in
                if step != .plan {
                    // The chevron is 5 wide, drawn in the middle of its room: a narrower
                    // room with the full-size path ran into the next step (the iPhone
                    // screenshot, 3 Oct 2026).
                    let x = (fit.arrow - 5) / 2
                    SVGPath.path("M\(x) 7l5 5-5 5").stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                        .frame(width: fit.arrow, height: 24).foregroundStyle(Theme.muted)
                }
                let on = step == here
                HStack(spacing: 4) {
                    // Slimmed down, the step it is at keeps its mark.
                    if fit.marks || on { SectionMark(section: step.tab, size: 13, weight: 1.9) }
                    Text(step.name)
                        .font(.system(size: fit.size, weight: on ? .heavy : .semibold))
                        .lineLimit(1).fixedSize()
                }
                    .foregroundStyle(on ? Color.white : step.words(scheme))
                    .padding(.horizontal, fit.pad).frame(minHeight: 28)
                    // A solid card under the others, so they stand out on the
                    // green of an all-packed trip too (night mode, 2026-09-27).
                    .background(Capsule().fill(on ? step.tint : Theme.card))
                    .overlay(Capsule().stroke(step.tint.opacity(on ? 0 : 0.7), lineWidth: 1.2))
            }
            // No "round again" arrow after Refine: it read as a reload button (his
            // screenshot, 2026-09-28). The loop itself is in the picture a tap opens.
        }
        .fixedSize()
    }
}

/// The whole picture, with where this trip stands.
struct LoopScreen: View {
    let here: Library.LoopStep?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("The loop").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.events.color)
                    .keyboardShortcut(.cancelAction)            // Escape closes it (the spec pass, 5 Oct 2026)
                    .accessibilityIdentifier("loop-done")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 18) {
                    LoopPicture(here: here)
                    LoopWords()
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("loop-screen")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }
}

/// How it works starts here: the picture, then the words.
struct LoopGuideCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("The loop").font(.system(size: 19, weight: .heavy)).foregroundStyle(Theme.ink)
            Text("Every trip goes round the same five steps, and each time round your templates get a little better.")
                .font(.system(size: 16)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            LoopPicture()
            LoopWords()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-loop")
    }
}
