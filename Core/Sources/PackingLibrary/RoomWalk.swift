import Foundation
import PackingCore

// The room walk (0.116 — inventory step 2, his answers of 11 Nov 2026, docs/inventory/plan.md):
// pick a room, then photo + name, photo + name… The camera comes straight back after each one,
// a running count says "12 in Kitchen", and Done ends the room. The name is guessed on the device
// from the photo (Apple's image recognition, in the app) and he confirms it; a set is one thing × count.

/// Words the recogniser gives that name no thing — the room or the light, not what was shot.
let WALK_NOT_A_THING: Set<String> = [
    "structure", "indoor", "outdoor", "room", "interior room", "wall", "floor", "ceiling", "material",
    "textile", "wood", "wood processed", "plant", "people", "adult", "art", "illustration", "text",
    "document", "blue sky", "sky", "light", "machine", "tool", "consumer electronics", "furniture",
    "container", "housewares", "kitchen", "home", "office", "bathroom", "bedroom", "living room",
]

extension Library {
    /// A thing found on the walk: kept in `room` (which joins his rooms), `count` pieces, and — when
    /// he says so — staying at home. Refused (nil) for a blank name or one he already has.
    @discardableResult
    public mutating func walkAdd(name: String, room: String, count: Int = 1, staysHome: Bool = false) -> Item? {
        guard let made = addThing(name: name), let n = items.firstIndex(where: { $0.id == made.id }) else { return nil }
        let typed = jsTrim(room)
        let r = roomChoices().first { normName($0) == normName(typed) } ?? typed
        if !r.isEmpty {
            keepRoom(r)
            items[n].storage = storagePlaces().first { normName($0) == normName(r) } ?? r
        }
        items[n].qtyOwned = max(1, count)
        Library.setStaysHome(&items[n], staysHome)
        return items[n]
    }

    /// The recogniser's labels (best first, with how sure it is, 0…1) as up to `limit` names to offer:
    /// "teapot" → "Teapot", "coffee_mug" → "Coffee mug"; sure enough (≥ 0.1) only, no room or light
    /// words, each once, and none he already has a thing of that name for.
    public static func nameGuesses(_ labels: [(String, Double)], have: Set<String> = [], limit: Int = 3) -> [String] {
        var seen = Set<String>(), out: [String] = []
        for (raw, sure) in labels.sorted(by: { $0.1 > $1.1 }) where sure >= 0.1 {
            let words = raw.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces).lowercased()
            guard !words.isEmpty, !WALK_NOT_A_THING.contains(words) else { continue }
            let name = words.prefix(1).uppercased() + words.dropFirst()
            let k = normName(name)
            guard !have.contains(k), seen.insert(k).inserted else { continue }
            out.append(name)
            if out.count == limit { break }
        }
        return out
    }
}
