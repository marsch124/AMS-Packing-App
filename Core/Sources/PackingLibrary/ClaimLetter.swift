import Foundation
import PackingCore

// 0.124 — a claim letter (his pick of 12 Nov 2026): a thing that broke inside its three-year complaint
// right (reklamationsrätt, konsumentköplagen) or its warranty gets a ready letter in Swedish to the shop.

extension Library {
    /// The last day he can still claim: the later of three years from the bought day and the warranty's
    /// end ("" when neither is known).
    public static func claimUntil(_ it: Item) -> String {
        let right = isYMD(it.acquired) ? addYears(it.acquired, 3) : ""
        let w = isYMD(it.warranty) ? it.warranty : ""
        return max(right, w)
    }

    /// Can a claim still be made today?
    public static func canClaim(_ it: Item, today: String) -> Bool {
        let until = claimUntil(it)
        return isYMD(until) && isYMD(today) && today <= until && !isGone(it)
    }

    /// The letter, in Swedish, ready to send. `problem` is what is wrong, in his words.
    public static func claimLetter(_ it: Item, problem: String, today: String) -> String {
        let what = [it.manufacturer, it.model].map(jsTrim).filter { !$0.isEmpty }.joined(separator: " ")
        var lines: [String] = []
        lines.append("Reklamation: \(what.isEmpty ? it.name : what)")
        lines.append("")
        lines.append("Hej!")
        lines.append("")
        var bought = "Jag köpte \(it.name.lowercased())"
        if !what.isEmpty { bought += " (\(what))" }
        let shop = jsTrim(Library.shop(it))
        if !shop.isEmpty { bought += " hos \(shop)" }
        if isYMD(it.acquired) { bought += " den \(swedishDay(it.acquired))" }
        if it.price > 0 { bought += " för \(moneyWords(it.price, currency: it.currency))" }
        lines.append(bought + ".")
        if !jsTrim(it.serial).isEmpty { lines.append("Serienummer: \(jsTrim(it.serial)).") }
        lines.append("")
        let p = jsTrim(problem)
        lines.append("Varan har nu följande fel: \(p.isEmpty ? "[beskriv felet]" : p)")
        lines.append("")
        if isYMD(it.acquired), today <= addYears(it.acquired, 3) {
            lines.append("Enligt konsumentköplagen har jag rätt att reklamera fel som funnits sedan köpet inom tre år.")
        }
        if isYMD(it.warranty), today <= it.warranty {
            lines.append("Varan har dessutom garanti till och med \(swedishDay(it.warranty)).")
        }
        lines.append("Jag begär därför att ni reparerar varan eller ersätter den med en ny.")
        lines.append("")
        lines.append(hasReceipt(it) ? "Kvitto bifogas." : "Köpet kan styrkas på begäran.")
        lines.append("")
        lines.append("Vänliga hälsningar")
        return lines.joined(separator: "\n")
    }

    /// "15 april 2023".
    static func swedishDay(_ ymd: String) -> String {
        let months = ["januari", "februari", "mars", "april", "maj", "juni", "juli", "augusti", "september",
                      "oktober", "november", "december"]
        let b = ymd.split(separator: "-").compactMap { Int($0) }
        guard b.count == 3, (1...12).contains(b[1]) else { return ymd }
        return "\(b[2]) \(months[b[1] - 1]) \(b[0])"
    }
}
