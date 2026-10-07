import AppIntents
import PackingCore
import PackingLibrary

// Shortcuts — his pre-trip idea 10 (2 Oct 2026): a grab list (or the next trip) one
// press away, from the iPhone's Action button, a Shortcut on the Home Screen, Siri,
// or the Mac's Shortcuts. Each opens the app at that place; nothing is changed.

/// One of his grab lists, as Shortcuts lists them.
struct GrabListEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Grab list"
    static var defaultQuery = GrabListQuery()
    let id: String
    let title: String
    /// The word on its tile ("Swim"), which is what he says to Siri: the guide's
    /// example asked for "Swim", and no list is CALLED that — the two are "Indoor
    /// swim" and "Outdoor swim" (5 Oct 2026). Siri can now find either by its word,
    /// and asks which when two share it.
    var word: String = ""
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", synonyms: word.isEmpty || word == title ? [] : ["\(word)"])
    }
}

struct GrabListQuery: EntityQuery {
    @MainActor func entities(for identifiers: [String]) async throws -> [GrabListEntity] {
        Self.all().filter { identifiers.contains($0.id) }
    }
    @MainActor func suggestedEntities() async throws -> [GrabListEntity] { Self.all() }

    /// Home's eight first, in his order, then the ones waiting in Grab Lists.
    @MainActor static func all() -> [GrabListEntity] {
        let lib = LibraryModel.shared.library
        let home = lib.homeGrabLists()
        let rest = lib.allGrabLists().filter { g in !home.contains { $0.id == g.id } }
        return (home + rest).map { GrabListEntity(id: $0.id, title: $0.title.isEmpty ? $0.label : $0.title, word: $0.label) }
    }
}

struct OpenGrabListIntent: AppIntent {
    static var title: LocalizedStringResource = "Open a grab list"
    static var description = IntentDescription("Opens one of your grab lists in Packing, ready to tick.")
    static var openAppWhenRun = true

    @Parameter(title: "Grab list") var list: GrabListEntity

    @MainActor func perform() async throws -> some IntentResult {
        LibraryModel.shared.grabToOpen = list.id
        return .result()
    }
}

/// The Action button's menu (field test 2.3, 3 Oct 2026): no choice made beforehand —
/// the app opens on every grab list as a big tile, and one tap opens the one for today.
struct ChooseGrabListIntent: AppIntent {
    static var title: LocalizedStringResource = "Choose a grab list"
    static var description = IntentDescription("Opens Packing on all your grab lists, to pick the one for today.")
    static var openAppWhenRun = true

    @MainActor func perform() async throws -> some IntentResult {
        LibraryModel.shared.grabMenuOpen = true
        return .result()
    }
}

struct OpenNextTripIntent: AppIntent {
    static var title: LocalizedStringResource = "Open my next trip"
    static var description = IntentDescription("Opens the trip you leave on next, at its packing list.")
    static var openAppWhenRun = true

    @MainActor func perform() async throws -> some IntentResult {
        if let next = LibraryModel.shared.library.nextTrip(today: Today.local) {
            LibraryModel.shared.tripToOpen = next.id
        }
        return .result()
    }
}

struct PackingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ChooseGrabListIntent(),
                    phrases: ["Choose a grab list in \(.applicationName)", "Grab lists in \(.applicationName)"],
                    shortTitle: "Choose a grab list", systemImageName: "square.grid.2x2")
        AppShortcut(intent: OpenGrabListIntent(),
                    phrases: ["Open \(\.$list) in \(.applicationName)", "Grab \(\.$list) with \(.applicationName)"],
                    shortTitle: "Open a grab list", systemImageName: "checklist")
        AppShortcut(intent: OpenNextTripIntent(),
                    phrases: ["Open my next trip in \(.applicationName)"],
                    shortTitle: "My next trip", systemImageName: "suitcase")
        // "Where is my charger in Packing?" (0.69): the bag and pocket, said back.
        AppShortcut(intent: WhereIsIntent(),
                    phrases: ["Where is my \(\.$thing) in \(.applicationName)", "Where's my \(\.$thing) in \(.applicationName)",
                              "Ask \(.applicationName) where something is"],
                    shortTitle: "Where is my thing?", systemImageName: "bag")
    }
}
