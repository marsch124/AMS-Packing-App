import SwiftUI

/// The app's own words, each said once — his ask (tests F.7 and I.2, 2026-09-28):
/// "We need to create a definition of words there, a new chapter with these
/// definitions", and "What do you mean by kit? … write that in the definition
/// section in How It Works".
enum Words {
    struct Entry { let term: String; let meaning: String; let section: AppSection }

    static let all: [Entry] = [
        Entry(term: "Trip", meaning: "One journey: its dates, place and templates, and the list you pack from. The Trips tab.", section: .events),
        Entry(term: "Template", meaning: "A building block: the things for one activity or need — Hiking, Swim, Car. A trip is made from templates. The Templates tab.", section: .templates),
        // "Activity area", not "shelf" — their word from the field test (Oct 2026):
        // "We understand that word much better."
        Entry(term: "Activity area", meaning: "The group a template lives in, with its code: GA · Goal activity, WET · Workout, exercise & training, and so on.", section: .templates),
        Entry(term: "List", meaning: "The one list you pack from for a trip, made from its templates. (A grab list is a list too.)", section: .events),
        Entry(term: "Grab list", meaning: "A short list for a quick outing — Swim, Bike, Run — ticked as each thing is in your hand. Up to eight are on Home; the rest wait in Grab Lists.", section: .home),
        Entry(term: "Common base", meaning: "The template that comes along on every trip: passport, phone charger and the like.", section: .templates),
        Entry(term: "Transport kit", meaning: "What a way of travelling adds to a trip: the Car, Plane or RV things.", section: .templates),
        Entry(term: "Quick", meaning: "A trip with only the templates you tick — no common base, no transport kit.", section: .home),
        Entry(term: "Context", meaning: "Indoor, Outdoor or Race: how a workout is done. It adds what that setting needs.", section: .home),
        Entry(term: "Thing", meaning: "One thing you own, in Your things on Care. It can be on many templates; a change to it reaches all of them.", section: .care),
        Entry(term: "Kit", meaning: "All your things together — what Care counts and weighs.", section: .care),
        Entry(term: "Cabin bag", meaning: "A bag that goes on board with you \u{2014} Goes in the cabin, on the bag's page. On a plane trip it is checked for liquids and things not allowed.", section: .care),
        Entry(term: "Bag", meaning: "What a thing is packed into. A bag can have a max weight, and the trip shows how full it is.", section: .care),
        Entry(term: "From where · Into", meaning: "Where a thing is kept at home · the bag it goes into.", section: .events),
        Entry(term: "When", meaning: "The step of the packing timeline a thing belongs to: a week ahead, the day before, on the day…", section: .events),
        // Their word for the trip's own place, from the same field test: "on site", not "there".
        // …and since the same field test a step of the loop of its own, with its own page.
        Entry(term: "On site", meaning: "At the place the trip takes you, while the trip is under way \u{2014} and the step of the loop after Pack. The trip's On site page holds what you bought, what you left, maintenance notes, and Pack to go home.", section: .events),
        Entry(term: "Set aside ⊘", meaning: "Not this time: the thing stays on the list but is not packed, and leaves the count. ↻ brings it back.", section: .events),
        Entry(term: "The loop", meaning: "Plan (Home) › Pack (Trips) › On site (the trip, while away) › Review (the trip, afterwards) › Refine (Templates) — and round again.", section: .events),
        Entry(term: "Loop strip", meaning: "The five steps under a trip's name. The filled one is where this trip stands, with the mark of the tab where that step is done (on a wide screen every step has its mark).", section: .events),
        Entry(term: "Review", meaning: "Looking back at ONE trip: what you did not use, and what you missed.", section: .events),
        Entry(term: "Refine", meaning: "Making your templates better from SEVERAL reviews: what a template carries for nothing. On the Templates tab.", section: .templates),
        Entry(term: "Keep · Drop", meaning: "In Refine. Keep: it stays on the template and is not asked about again. Drop: off that one template — the thing itself stays.", section: .templates),
        Entry(term: "To do", meaning: "The tab for getting ready: things to sort out before you go, and — on its other side — To buy, with worn-out or run-down things suggested.", section: .actions),
        Entry(term: "Your choices", meaning: "Your own lists in Settings: storage places, owners, packers, conditions and the When steps.", section: .settings),
        Entry(term: "Care", meaning: "Looking after your things: services that fall due, weights, bags. The Care tab.", section: .care),
    ]
}

/// The Words chapter in How it works: each word in its tab's colour, its meaning under it.
struct WordsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Aa").font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.settings.color)
                    .frame(width: 24, height: 24)
                Text("Words").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
            }
            ForEach(Array(Words.all.enumerated()), id: \.offset) { n, e in
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.term).font(.system(.body, weight: .semibold)).foregroundStyle(e.section.color)
                        .accessibilityIdentifier("word-\(n)")
                    Text(e.meaning).font(.system(.callout)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-words")
    }
}
