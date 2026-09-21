import Foundation
import PackingCore
import PackingLibrary

/// An invented library for the UI tests (`-uiTesting`). Nothing of his is in here —
/// this repository is public.
enum SampleLibrary {
    static func make() -> Library {
        var lib = Library()
        func list(_ name: String, group: String = "", role: String = "", _ names: [String]) -> PackList {
            var l = newList(name: name, group: group, role: role)
            l.items = names.map { newItem(name: $0) }
            return l
        }
        lib.saveTemplate(list("Common base", role: "base", ["Passport", "Phone charger", "Toothbrush", "Headlamp"]))
        lib.saveTemplate(list("Hiking", group: "GA", ["Hiking boots", "Rain jacket", "Headlamp", "Map"]))
        lib.saveTemplate(list("Swim", group: "WET", ["Goggles", "Swim cap", "Towel"]))
        return lib
    }
}
