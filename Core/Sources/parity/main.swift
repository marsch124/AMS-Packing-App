// parity — the Swift half of the AMS Packing PARITY CHECKER.
//
//   parity <backup.json> [--today 2026-09-21] [--locale en-US]  > answers.json
//
// Runs PackingCore over a real backup file and writes ONE canonical JSON document of
// answers to stdout. tools/parity/js-answers.mjs answers the same questions with the
// web app's own model; tools/parity/diff-answers.mjs compares the two. Every question,
// its arguments and how its result is written down are specified in
// tools/parity/QUESTIONS.md — that document is the contract.
//
// 🚨 PRIVACY. The backup is the owner's real data and this repository is public.
// Send the output into private/ only.

import Foundation
import PackingCore

func usage(_ code: Int32) -> Never {
    FileHandle.standardError.write(Data("usage: parity <backup.json> [--today YYYY-MM-DD] [--locale en-US] > answers.json\n".utf8))
    exit(code)
}

var backupPath = ""
var today = "2026-09-21"
var locale = "en-US"   // D6: collation is pinned, as the JS half pins it
var args = Array(CommandLine.arguments.dropFirst())
while !args.isEmpty {
    let a = args.removeFirst()
    if a == "--today" { if args.isEmpty { usage(2) }; today = args.removeFirst() }
    else if a == "--locale" { if args.isEmpty { usage(2) }; locale = args.removeFirst() }
    else if a == "-h" || a == "--help" { usage(0) }
    else if a.hasPrefix("--") { FileHandle.standardError.write(Data("Unknown option \(a)\n".utf8)); usage(2) }
    else { backupPath = a }
}
if backupPath.isEmpty { usage(2) }
if !isYMD(today) { FileHandle.standardError.write(Data("--today must be YYYY-MM-DD\n".utf8)); exit(2) }

do {
    let parity = try Parity(backupPath: backupPath, today: today, locale: locale)
    parity.askSetupState()      // §6
    parity.askCoercion()        // §7
    parity.askLists()           // §8
    parity.askEvents()          // §9
    parity.askProbes()          // §10
    parity.askLibrary()         // §11
    parity.askSettings()        // §12
    let pool = parity.stringPool()
    parity.askStrings(pool)     // §13
    parity.askIds()
    parity.askCalc()            // §14
    parity.askInstalling()      // §15 — last: it changes the model's global state
    FileHandle.standardOutput.write(Data(parity.document(poolCount: pool.count).utf8))
} catch {
    FileHandle.standardError.write(Data("parity: \(error)\n".utf8))
    exit(2)
}
