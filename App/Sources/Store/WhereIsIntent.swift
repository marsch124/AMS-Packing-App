import AppIntents
import PackingCore
import PackingLibrary

// "Where is my charger?" — stop B of his idea plan (7 Oct 2026): asked of Siri on the
// iPhone or the Mac, on site or on the way home, the answer comes back in words —
// "Backpack, front pocket." For the trip under way; with none, the thing's usual bag and
// pocket. Nothing opens and nothing changes. The words are the model's
// (`Library.whereIs` → `WhereAnswer.said`), the same answer Search shows first.

/// One of his things, as Siri and Shortcuts name them.
struct ThingEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Thing"
    static var defaultQuery = ThingQuery()
    let id: String
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct ThingQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [String]) async throws -> [ThingEntity] {
        Self.all().filter { identifiers.contains($0.id) }
    }
    /// Typed or said: every thing whose name holds the words.
    @MainActor func entities(matching string: String) async throws -> [ThingEntity] {
        let needle = normName(string)
        return Self.all().filter { needle.isEmpty || normName($0.name).contains(needle) }
    }
    @MainActor func suggestedEntities() async throws -> [ThingEntity] { Self.all() }

    /// His things in use, A–Z (a thing set to "Not in use" is not asked about).
    @MainActor static func all() -> [ThingEntity] {
        LibraryModel.shared.library.items.filter { !$0.retired }
            .map { ThingEntity(id: $0.id, name: $0.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

struct WhereIsIntent: AppIntent {
    static var title: LocalizedStringResource = "Where is my thing?"
    static var description = IntentDescription("Says which bag, and which pocket, a thing is in on the trip under way — or where it usually goes.")
    static var openAppWhenRun = false

    @Parameter(title: "Thing", requestValueDialog: "Which thing?") var thing: ThingEntity

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let said = WhereIsIntent.answer(thingId: thing.id)
        return .result(value: said, dialog: "\(said)")
    }

    /// The words Siri says.
    @MainActor static func answer(thingId: String) -> String {
        LibraryModel.shared.library.whereIs(thingId: thingId, today: Today.local)?.said
            ?? "That thing is not in Packing any more."
    }
}
