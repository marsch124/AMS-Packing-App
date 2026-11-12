import Foundation
import PackingCore

// A thing's page writes only what was changed on it (0.93, the outside review of 0.92 — his "fix
// 1, 2 and 6"). Its Save wrote every field as the page had it — place, kind, bag, pocket, When,
// owner, condition, weight, maker, colour, notes, liquid, restricted, battery, expiry — so a change
// made on the other device while the page was open (its bag) went back when only the notes were
// changed here. Now a field is written only where the page differs from how it opened; every other
// field keeps what the library holds by then.

extension Item {
    /// This thing as the library holds it now, with every field the page changed — `opened` (the
    /// page as it opened) → `page` (as Save writes it) — set to the page's. `opened` nil (a thing
    /// made on the page): every field is the page's.
    public mutating func takePage(opened: Item?, page: Item) {
        func put<V: Equatable>(_ key: WritableKeyPath<Item, V>) {
            if opened.map({ $0[keyPath: key] != page[keyPath: key] }) ?? true { self[keyPath: key] = page[keyPath: key] }
        }
        func putExtra(_ k: String) {
            if opened.map({ $0.extra[k] != page.extra[k] }) ?? true { extra[k] = page.extra[k] }
        }
        put(\.storage); put(\.category); put(\.container); putExtra(USUAL_POCKET_KEY)
        put(\.phase); put(\.ownedBy); put(\.condition); put(\.weight)
        put(\.manufacturer); put(\.color); put(\.note)
        put(\.liquid); put(\.restricted); putExtra(BATTERY_KEY); put(\.expiry)
        // Details (0.115, inventory step 1).
        put(\.model); put(\.serial); put(\.acquired); put(\.price); put(\.currency); put(\.warranty); put(\.qtyOwned)
        putExtra(STAYS_HOME_KEY); putExtra(SPOT_KEY); putExtra(SHOP_KEY); putExtra(VALUE_NOW_KEY)
        // The manual's link (0.119 — it was typed on the page but never written by Save until 0.121).
        putExtra(MANUAL_LINK_KEY)
        // Gone (0.121): the mark, and Not in use that goes with it.
        putExtra(GONE_KEY); put(\.retired)
    }
}
