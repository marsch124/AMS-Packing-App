import Foundation
import PackingCore

// 0.124 — "Sell it…" (his pick of 12 Nov 2026): a ready Blocket ad in Swedish — a title, a price
// suggestion (today's value, rounded to 50 kr) and the text.

public struct SellAd: Equatable, Sendable {
    public var title: String
    public var price: Int
    public var text: String
}

extension Library {
    public static func sellAd(_ it: Item, today: String, rates: CurrencyRates = .current) -> SellAd {
        let what = [it.manufacturer, it.model].map(jsTrim).filter { !$0.isEmpty }.joined(separator: " ")
        let title = what.isEmpty ? it.name : (normName(what).contains(normName(it.name)) ? what : "\(it.name) \(what)")
        var price = 0
        if let v = valueToday(it, today: today), let one = rates.inKronor(1, it.currency) {
            price = max(50, Int((v * one / 50).rounded()) * 50)
        }
        var lines: [String] = []
        lines.append("Säljer \(title.prefix(1).lowercased() + title.dropFirst()).")
        var b: [String] = []
        if isYMD(it.acquired) { b.append("Köpt \(swedishDay(it.acquired))" + (jsTrim(shop(it)).isEmpty ? "" : " hos \(jsTrim(shop(it)))")) }
        if it.price > 0 { b.append("nypris \(moneyWords(it.price, currency: it.currency))") }
        if !b.isEmpty { lines.append(b.joined(separator: ", ") + ".") }
        if isYMD(it.warranty), today <= it.warranty { lines.append("Garanti kvar till \(swedishDay(it.warranty)).") }
        if hasReceipt(it) { lines.append("Kvitto finns.") }
        if !jsTrim(it.condition).isEmpty { lines.append("Skick: \(jsTrim(it.condition)).") }
        lines.append("Fungerar som den ska. Hämtas eller skickas mot frakt.")
        return SellAd(title: title, price: price, text: lines.joined(separator: "\n"))
    }
}
