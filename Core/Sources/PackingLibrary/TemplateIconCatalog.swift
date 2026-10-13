// The template icons themselves — key, label, group and drawing — as plain data, so
// the model's tests can hold every one to the rules (a drawing, a label, a unique
// key, only the path commands the app draws) and every suggestion to an icon that
// exists. The app draws them (`TemplateIcons`, `SVGPath`, `IconMark`).
//
// The first 50 are "of my own, drawn in the app's style (one stroke, round ends, a
// 24-point box)": he saw them on a sample sheet in day and night mode and said
// (2 Oct 2026): "Your suggestions are fine. Please implement." 40 more came with
// 0.74, his words (12 Oct 2026, the picker open on his "On the Beach"): "Add
// approximately 40 new icons, specifically one that is related to 'On the beach'."
// Drawn the same way — one 1.9-point stroke on the 24 grid, round caps and joins,
// no fill, nothing under ~2 points apart so a mark still reads at 14 points on a
// trip line. No stock art, no emoji (his rule). Only M L H V C S Q A Z.
//
// A key is stored on a template (`extra["iconKey"]`) and must never change; a
// label may. The picker shows the groups in this order, each in the order below.

/// One template icon: `key` is what a template stores, `label` what the picker says.
public struct TemplateIcon: Identifiable, Equatable, Sendable {
    public let key: String
    public let label: String
    public let group: TemplateIconGroup
    /// SVG path data on a 24-point box.
    public let path: String
    public var id: String { key }

    public init(key: String, label: String, group: TemplateIconGroup, path: String) {
        self.key = key; self.label = label; self.group = group; self.path = path
    }
}

/// The picker's headings, in the order they are shown.
public enum TemplateIconGroup: String, CaseIterable, Sendable {
    case travel, outdoors, sport, beach, city, everyday

    public var title: String {
        switch self {
        case .travel: return "Travel"
        case .outdoors: return "Outdoors"
        case .sport: return "Sport"
        case .beach: return "Beach and summer"
        case .city: return "City, food and fun"
        case .everyday: return "Everyday"
        }
    }
}

public enum TemplateIconCatalog {
    private static func i(_ key: String, _ label: String, _ group: TemplateIconGroup, _ path: String) -> TemplateIcon {
        TemplateIcon(key: key, label: label, group: group, path: path)
    }

    /// Every icon, grouped, in the order the picker shows them.
    public static let all: [TemplateIcon] = [
        // MARK: Travel
        i("car", "Car", .travel, "M4 16.5V12.8L6.2 8.2c.3-.6.8-.9 1.5-.9h8.6c.7 0 1.2.3 1.5.9L20 12.8v3.7Z M4 12.8h16 M6.5 16.5v2.2 M17.5 16.5v2.2 M7.5 14.6h1 M15.5 14.6h1"),
        i("plane", "Plane", .travel, "M12 3.2c.8 0 1.3.8 1.3 1.9v4.8l7.2 4.3v1.9l-7.2-2.2v4l2 1.6v1.5L12 20.1l-3.3.9v-1.5l2-1.6v-4l-7.2 2.2v-1.9l7.2-4.3V5.1c0-1.1.5-1.9 1.3-1.9Z"),
        i("rv", "Camper", .travel, "M2.5 17V8.3c0-.8.6-1.4 1.4-1.4h11.4c.5 0 .9.2 1.2.6L19 11h2.5v6Z M2.5 12.5h19 M5.5 6.9v3.3h5V6.9 M6 17a2 2 0 0 0 4 0 M14 17a2 2 0 0 0 4 0"),
        i("train", "Train", .travel, "M7 3.5h10c1.1 0 2 .9 2 2v9.5c0 1.1-.9 2-2 2H7c-1.1 0-2-.9-2-2V5.5c0-1.1.9-2 2-2Z M5 10.5h14 M8.5 13.7h.5 M15 13.7h.5 M8.5 17 6.5 20.5 M15.5 17l2 3.5"),
        i("bus", "Bus", .travel, "M6.5 3.5h11c1.1 0 2 .9 2 2v12h-15v-12c0-1.1.9-2 2-2Z M4.5 12h15 M8 6.5h8 M7.5 14.8h1 M15.5 14.8h1 M7 17.5v3 M17 17.5v3 M4.5 7.5h-2v2.5 M19.5 7.5h2v2.5"),
        i("motorbike", "Motorbike", .travel, "M2.5 16a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0 -7 0 M14.5 16a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0 -7 0 M6 16l3.2-5h5.3l1.8-1.5 M18 16l-3.3-8.5h-2.2 M9.5 16h5.2l1.6-4.5"),
        i("ferry", "Ferry", .travel, "M3 14.5h18l-2.2 4.5H5.2Z M5.5 14.5v-4h13v4 M8.5 10.5V7h7v3.5 M12 7V4.5 M2.5 21.2c1.6 0 1.6-.9 3.2-.9s1.6.9 3.2.9 1.6-.9 3.2-.9 1.6.9 3.2.9 1.6-.9 3.2-.9 1.6.9 2 .9"),
        i("suitcase", "Travel", .travel, "M4.5 8h15v11.5h-15Z M9 8V5c0-.6.4-1 1-1h4c.6 0 1 .4 1 1v3 M8.5 11v5.5 M15.5 11v5.5 M7 19.5v1 M17 19.5v1"),
        // 0.78, his ask (13 Oct 2026): his small always-packed template showed the same suitcase
        // as his big Travel one — "a nice unique icon — not the same as Travel". A soft holdall:
        // the round-ended body, a zip along the top with its pull, and two handles, the back one
        // over the front one.
        i("weekendbag", "Weekend bag", .travel, "M6.5 9.5h11a4 4 0 0 1 4 4v2a4 4 0 0 1-4 4h-11a4 4 0 0 1-4-4v-2a4 4 0 0 1 4-4Z M6.5 9.5a5.5 5.5 0 0 1 11 0 M9.5 9.5a2.5 2.5 0 0 1 5 0 M6 13.2h12 M15.5 13.2v2.2"),
        i("backpack", "Backpack", .travel, "M7.5 7.5h9c1.4 0 2.5 1.1 2.5 2.5v10.5H5V10c0-1.4 1.1-2.5 2.5-2.5Z M9.5 7.5V5.2c0-.9.7-1.7 1.7-1.7h1.6c.9 0 1.7.8 1.7 1.7v2.3 M5 13h14 M10 13v2.5h4V13"),
        i("box", "Boxes", .travel, "M3.5 7.8 12 3.8l8.5 4v8.9L12 20.7l-8.5-4Z M3.5 7.8 12 11.8l8.5-4 M12 11.8v8.9 M7.8 5.8l8.4 4"),
        i("passport", "Passport", .travel, "M6 3.5h12v17H6Z M9.2 10a2.8 2.8 0 1 0 5.6 0a2.8 2.8 0 1 0 -5.6 0 M9 16h6"),
        i("ticket", "Tickets", .travel, "M3.5 7h17v3a2 2 0 0 0 0 4v3h-17v-3a2 2 0 0 0 0-4Z M15 7.5v1 M15 11.5v1 M15 15.5v1"),
        i("map", "Map", .travel, "M3.5 6.5 9 4.5l6 2 5.5-2v13l-5.5 2-6-2-5.5 2Z M9 4.5v13 M15 6.5v13"),
        i("hotel", "Hotel", .travel, "M3 20.5h18 M5 20.5V5c0-.6.4-1 1-1h12c.6 0 1 .4 1 1v15.5 M10 20.5v-3.5h4v3.5 M8.5 17h7 M8.5 8h1 M14.5 8h1 M8.5 12h1 M14.5 12h1"),

        // MARK: Outdoors
        i("hiking", "Hiking", .outdoors, "M2.5 19.5 9.2 7.8l3.4 5.8 2.6-3.6 6.3 9.5Z M7.4 10.9l1.8 1.2 1.6-1.3"),
        i("walk", "Walking", .outdoors, "M12.4 4.3a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0 M13.2 7.8 11.5 14 M11.5 14l-3 6.5 M11.5 14l3 2.8.6 3.7 M12.9 9.2 9.5 11.5 M12.9 9.2l3.3 3"),
        i("mountain", "Summit", .outdoors, "M3 20 12 4l9 16Z M12 4v3.5 M12 4h4l-1.2 1.6L16 7.2h-4 M8.3 12.4l1.9 1.3 1.8-1.5 1.8 1.5 1.9-1.3"),
        i("compass", "Orienteering", .outdoors, "M3.5 12a8.5 8.5 0 1 0 17.0 0a8.5 8.5 0 1 0 -17.0 0 M15.2 8.8l-1.9 4.5-4.5 1.9 1.9-4.5Z"),
        i("tent", "Camping", .outdoors, "M2.5 19.5 12 4l9.5 15.5Z M12 4v15.5 M9 19.5l3-6.3 3 6.3"),
        i("fire", "Campfire", .outdoors, "M12 3.5c2.1 3 4.6 4.5 4.6 8.1a4.6 4.6 0 0 1-9.2 0c0-2 1-3.2 2-4.1.3 1.5 1 2.1 1.8 2.4C11 8 11 6 12 3.5Z M4.5 20.5l15-3 M4.5 17.5l15 3"),
        i("headlamp", "Headlamp", .outdoors, "M4 13.5c0-4.4 3.6-8 8-8s8 3.6 8 8 M9.5 12h5v4h-5Z M12 16v1.5 M8.5 19.5l-1.5 1.5 M12 19.5v2 M15.5 19.5l1.5 1.5"),
        i("ski", "Skiing", .outdoors, "M3.5 17 17.2 6.9c.9-.7 2.2-.5 2.6.5 M5.5 20.5 19.2 10.4c.9-.7 2.2-.5 2.6.5 M9 12.3l1.6 2.2 M11 15.8l1.6 2.2"),
        i("snow", "Winter", .outdoors, "M12 3v18 M4.2 7.5l15.6 9 M4.2 16.5l15.6-9 M9.8 4.4 12 6l2.2-1.6 M9.8 19.6 12 18l2.2 1.6"),
        i("rain", "Rain", .outdoors, "M7 15.5a4 4 0 0 1-.5-8 5.5 5.5 0 0 1 10.6 1.3 3.4 3.4 0 0 1 .4 6.7Z M8 18.5l-1 2 M12 18.5l-1 2 M16 18.5l-1 2"),
        i("fishing", "Fishing", .outdoors, "M15 3.5v11a4.5 4.5 0 0 1-9 0v-2.8 M6 11.7l-1.6 1.6 M15 3.5h-2.5"),

        // MARK: Sport
        i("run", "Run", .sport, "M3 18v-4.2c0-.6.5-1 1.1-1 2 0 3.6-1.2 4.5-3.1l.5-1.2 3.1 1.6.9 2.1 5.1 1.5c1.6.5 2.8 1.9 2.8 3.5v.8Z M3 18h18 M12.3 11.8l-1.4 1.4 M14.2 13.2l-1.4 1.4"),
        i("bike", "Bike", .sport, "M2.4 15.8a3.6 3.6 0 1 0 7.2 0a3.6 3.6 0 1 0 -7.2 0 M14.4 15.8a3.6 3.6 0 1 0 7.2 0a3.6 3.6 0 1 0 -7.2 0 M6 15.8l3.6-7h5.9L18 15.8 M9.6 8.8l2.9 7H6 M13.4 5.8h2.6 M14.7 5.8l.8 3"),
        i("swim", "Swim", .sport, "M2.5 16.6c1.6 0 1.6-1.2 3.2-1.2s1.6 1.2 3.2 1.2 1.6-1.2 3.2-1.2 1.6 1.2 3.2 1.2 1.6-1.2 3.2-1.2 1.6 1.2 3 1.2 M2.5 20.3c1.6 0 1.6-1.2 3.2-1.2s1.6 1.2 3.2 1.2 1.6-1.2 3.2-1.2 1.6 1.2 3.2 1.2 1.6-1.2 3.2-1.2 1.6 1.2 3 1.2 M5.5 12.5 10 8.8l3.5 2.4 3-1.4 M16.2 6.3a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0"),
        i("triathlon", "Triathlon", .sport, "M7.5 3.5 10.6 10 M16.5 3.5 13.4 10 M7.5 3.5h9 M7 15a5 5 0 1 0 10 0a5 5 0 1 0 -10 0"),
        i("diving", "Diving", .sport, "M3.5 8.5h15v6c0 1-.8 1.8-1.8 1.8h-3.1L11 13.8l-2.6 2.5H5.3c-1 0-1.8-.8-1.8-1.8Z M11 8.5v5.3 M18.5 11.5h2V4.5"),
        i("fin", "Freediving", .sport, "M8.2 19.2a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M10 17.4V10 M10 10 7.6 3.5 M10 10l2.4-6.5 M5.8 3.5h3 M11.2 3.5h3 M7.2 14.4l2.8-1.4 2.8 1.4 M15.4 15.5a1.1 1.1 0 1 0 2.2 0a1.1 1.1 0 1 0 -2.2 0 M17.1 11a0.9 0.9 0 1 0 1.8 0a0.9 0.9 0 1 0 -1.8 0 M16.1 7.2a0.7 0.7 0 1 0 1.4 0a0.7 0.7 0 1 0 -1.4 0"),
        i("kayak", "Paddling", .sport, "M4 20 20 4 M3.2 17.2l3.6 3.6 1.7-1.7c.5-.5.5-1.3 0-1.8l-1.8-1.8c-.5-.5-1.3-.5-1.8 0Z M20.8 6.8l-3.6-3.6-1.7 1.7c-.5.5-.5 1.3 0 1.8l1.8 1.8c.5.5 1.3.5 1.8 0Z"),
        i("climb", "Climbing", .sport, "M9.5 3.5h3a4 4 0 0 1 4 4v9a4 4 0 0 1-8 0V9.5 M8.5 9.5l2.6-2.6"),
        i("golf", "Golf", .sport, "M7 20.5V3.5l9 3.5-9 3.5 M3.5 20.5h8 M16.5 18.4a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0"),
        i("racket", "Racket sports", .sport, "M3.5 9.5a6 6 0 1 0 12 0a6 6 0 1 0 -12 0 M13.8 13.8 20 20 M5.8 7.5h7.4 M5.8 11.5h7.4 M7.5 5.8v7.4 M11.5 5.8v7.4 M17.7 5.3a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0"),
        i("strength", "Strength", .sport, "M2.5 12h19 M5 8.5v7 M7.8 6.8v10.4 M16.2 6.8v10.4 M19 8.5v7"),
        i("kettlebell", "Kettlebell", .sport, "M8.5 9.5a3.5 3.5 0 1 1 7 0 M6 14.5c0-3 2.7-5 6-5s6 2 6 5c0 2-.8 3.5-2 4.7-.3.2-.6.3-.9.3H8.9c-.3 0-.6-.1-.9-.3-1.2-1.2-2-2.7-2-4.7Z"),
        i("mobility", "Mobility", .sport, "M10.3 4.8a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0 M12 8.2v5 M6 11.2l6 2 6-2 M5 19.5c2-2.6 4.5-3.7 7-3.7s5 1.1 7 3.7"),
        i("yoga", "Stretch", .sport, "M10.4 4.5a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0 M12 7.5 9 13l-4.5 1.5 M12 7.5l3 5.5 4.5 1.5 M9 13l-1 7 M15 13l1 7"),
        i("lotus", "Yoga", .sport, "M10.3 4.5a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0 M12 8v6 M7.5 10.8c1.4-1.4 2.9-2.1 4.5-2.1s3.1.7 4.5 2.1 M7.5 10.8l-1.5 4.7 M16.5 10.8l1.5 4.7 M3.5 18.2c2.8-2.2 5.7-2.6 8.5-1 2.8-1.6 5.7-1.2 8.5 1 M3.5 18.2c4.5 1.6 12.5 1.6 17 0"),
        i("breath", "Breath work", .sport, "M3 9h9.5a2.5 2.5 0 1 0-2.5-2.5 M3 12.5h14.5a3 3 0 1 1-3 3 M3 16h6"),
        i("sauna", "Sauna", .sport, "M4 20h16 M8 16.5c-1-1.5 1-2.5 0-4s1-2.5 0-4 M12 16.5c-1-1.5 1-2.5 0-4s1-2.5 0-4 M16 16.5c-1-1.5 1-2.5 0-4s1-2.5 0-4"),
        i("icebath", "Ice bath", .sport, "M2.5 12h19 M4 12v2.5a5 5 0 0 0 5 5h6a5 5 0 0 0 5-5V12 M7.5 19 6.5 21 M16.5 19l1 2 M10 8.5a2 2 0 1 0 4 0a2 2 0 1 0 -4 0 M4.5 6h3.2v3.2H4.5Z M16.5 5.8l3.1.7-.7 3.1-3.1-.7Z"),
        i("watch", "Watch", .sport, "M8 7h8c.6 0 1 .4 1 1v8c0 .6-.4 1-1 1H8c-.6 0-1-.4-1-1V8c0-.6.4-1 1-1Z M9 7l.5-3.5h5L15 7 M9 17l.5 3.5h5L15 17 M12 9.5V12l1.8 1"),
        i("bottle", "Water bottle", .sport, "M7.5 10.5a2.5 2.5 0 0 1 2.5-2.5h4a2.5 2.5 0 0 1 2.5 2.5v9c0 .6-.4 1-1 1h-7c-.6 0-1-.4-1-1Z M9.5 8V5.5h5V8 M11 5.5V3.5h2 M7.5 13.5h9"),

        // MARK: Beach and summer
        i("sun", "Summer", .beach, "M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0 M12 2.8v2.4 M12 18.8v2.4 M2.8 12h2.4 M18.8 12h2.4 M5.5 5.5l1.7 1.7 M16.8 16.8l1.7 1.7 M5.5 18.5l1.7-1.7 M16.8 7.2l1.7-1.7"),
        i("lounger", "On the beach", .beach, "M3 9.5a6.5 5.5 0 0 1 13 0c-1.4-.9-2.9-.9-4.3 0-1.4-.9-2.9-.9-4.4 0-1.4-.9-2.9-.9-4.3 0Z M9.5 9.5v11 M11.5 16.5h6l3-5 M12.5 16.5v4 M17.5 16.5v4 M2.5 20.5h19"),
        i("beach", "Beach", .beach, "M3.5 11a8.5 8 0 0 1 17 0c-1.4-1-2.8-1-4.2 0-1.4-1-2.8-1-4.3 0-1.4-1-2.8-1-4.2 0-1.4-1-2.9-1-4.3 0Z M12 11v7.5a2 2 0 0 1-4 0"),
        i("palm", "Palm tree", .beach, "M10 20.5c-.3-4.5.5-8.5 2.5-12 M12.5 8.5c-2.5-1.8-5.8-1.6-8 .8 M12.5 8.5c2.5-1.8 5.8-1.6 8 .8 M12.5 8.5c-1.5-2.8-4-4-7-3.6 M12.5 8.5c1.5-2.8 4-4 7-3.6 M6 20.5h9"),
        i("glasses", "Sunglasses", .beach, "M3 10.5h7.5v3a3 3 0 0 1-3 3h-1.5a3 3 0 0 1-3-3Z M13.5 10.5H21v3a3 3 0 0 1-3 3h-1.5a3 3 0 0 1-3-3Z M10.5 11.5h3 M3 10.5 2 8 M21 10.5 22 8"),
        i("sunhat", "Sun hat", .beach, "M7 12.9C4.2 13.3 2.5 14.1 2.5 15c0 1.4 4.3 2.5 9.5 2.5s9.5-1.1 9.5-2.5c0-.9-1.7-1.7-4.5-2.1 M7 12.9c0-3.8 2.2-6.4 5-6.4s5 2.6 5 6.4 M7.3 11h9.4"),
        i("suncream", "Sun cream", .beach, "M7.5 3.5h9l-1.6 12.5H9.1Z M7.7 5.5h8.6 M9.5 16v3.5c0 .6.4 1 1 1h3c.6 0 1-.4 1-1V16 M10.2 10.5a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0"),
        i("flipflops", "Flip-flops", .beach, "M7.5 3.5c2 0 3.2 1.7 3.2 4.3 0 2.8-.9 4.6-.9 7.4 0 2.9-.9 5.3-2.3 5.3S5.2 18.1 5.2 15.2c0-2.8-.9-4.6-.9-7.4 0-2.6 1.2-4.3 3.2-4.3Z M4.6 10.5 7.5 7l2.9 3.5 M16.5 3.5c2 0 3.2 1.7 3.2 4.3 0 2.8-.9 4.6-.9 7.4 0 2.9-.9 5.3-2.3 5.3s-2.3-2.4-2.3-5.3c0-2.8-.9-4.6-.9-7.4 0-2.6 1.2-4.3 3.2-4.3Z M13.6 10.5 16.5 7l2.9 3.5"),
        i("towel", "Towel", .beach, "M6.5 7.5h13v6h-13a3 3 0 0 1 0-6Z M5 13.5h15.5v6.5H5a3.25 3.25 0 0 1 0-6.5Z M16 7.5v6 M17 13.5v6.5"),
        i("beachball", "Beach ball", .beach, "M3.5 12a8.5 8.5 0 1 0 17 0a8.5 8.5 0 1 0 -17 0 M12 12C11 8 8 5.5 4.3 5.9 M12 12c3.6-1.6 7-1 8.4 2 M12 12c-2.6 2.6-3.1 6-1.6 8.4"),
        i("swimring", "Swim ring", .beach, "M3.5 12a8.5 8.5 0 1 0 17 0a8.5 8.5 0 1 0 -17 0 M8.2 12a3.8 3.8 0 1 0 7.6 0a3.8 3.8 0 1 0 -7.6 0 M8.7 8.7 6.6 6.6 M15.3 8.7l2.1-2.1 M8.7 15.3l-2.1 2.1 M15.3 15.3l2.1 2.1"),
        i("shell", "Shell", .beach, "M12 19 3.6 11.2C3.6 6.6 7.4 3.5 12 3.5s8.4 3.1 8.4 7.7Z M12 19 7.3 4.8 M12 19V3.5 M12 19l4.7-14.2 M9.6 21h4.8"),
        i("surf", "Surfing", .beach, "M2.5 18c3.5 0 5.5-2.2 6.5-5.5 1.3-4.3 4.6-7 8.5-7 2.4 0 4 1.6 4 3.6 0 1.7-1.3 3-3 3-1.3 0-2.2-.9-2.2-2 M2.5 20.8c1.6 0 1.6-.9 3.2-.9s1.6.9 3.2.9 1.6-.9 3.2-.9 1.6.9 3.2.9 1.6-.9 3.2-.9 1.6.9 2 .9"),
        i("sail", "Sailing", .beach, "M3.5 16h17l-2.5 4H6Z M12 16V3.5 M12 4.5l6.5 9.5H12 M10 6.5 5 14h5Z"),
        i("kite", "Kite", .beach, "M13.5 2.5 19 8l-5.5 7.5L8 8Z M8 8h11 M13.5 2.5v13 M13.5 15.5c-.5 2-2 3-4 2.5S6 17 5 20"),

        // MARK: City, food and fun
        i("city", "City", .city, "M3 20.5h18 M4.5 20.5v-9H9v9 M9 20.5v-16h6v16 M15 20.5v-7h4.5v7 M11.5 8h1 M11.5 11.5h1 M11.5 15h1"),
        i("restaurant", "Restaurant", .city, "M3.5 3.5v4.5a1.75 1.75 0 0 0 3.5 0V3.5 M5.25 3.5v17 M20.5 20.5v-17c-1.8.9-2.7 3-2.7 5.8v3.2h2.7 M8.8 12a3.6 3.6 0 1 0 7.2 0a3.6 3.6 0 1 0 -7.2 0"),
        i("food", "Food", .city, "M7 3.5v17 M4.5 3.5v5a2.5 2.5 0 0 0 5 0v-5 M17 20.5v-17c-2.2 1.5-3.2 4-3.2 7H17"),
        i("coffee", "Coffee", .city, "M4.5 9h12v6a4.5 4.5 0 0 1-4.5 4.5H9A4.5 4.5 0 0 1 4.5 15Z M16.5 11h1.3a2.5 2.5 0 0 1 0 5h-1.6 M8.5 3.5v2.5 M12.5 3.5v2.5"),
        i("wine", "Wine", .city, "M7.5 3.5h9c.4 3.3-.2 5.6-1.5 7a4.4 4.4 0 0 1-6 0c-1.3-1.4-1.9-3.7-1.5-7Z M12 11.9v8.6 M8.5 20.5h7 M7.7 7h8.6"),
        i("picnic", "Picnic", .city, "M3.5 11h17l-1.7 8.6c-.1.5-.5.9-1 .9H6.2c-.5 0-.9-.4-1-.9Z M7 11a5 5 0 0 1 10 0 M4.3 15h15.4"),
        i("bbq", "Barbecue", .city, "M4 10.5h16a8 7 0 0 1-16 0Z M7.5 16l-2 4.5 M16.5 16l2 4.5 M10 3.5c-.8 1 .8 2 0 3.2 M14 3.5c-.8 1 .8 2 0 3.2"),
        i("shopping", "Shopping", .city, "M5.5 8h13l.9 12.5H4.6Z M9 10.5V7a3 3 0 0 1 6 0v3.5"),
        i("party", "Party", .city, "M4.7 8.5a3.8 4.6 0 1 0 7.6 0a3.8 4.6 0 1 0 -7.6 0 M12.7 7a3.3 4 0 1 0 6.6 0a3.3 4 0 1 0 -6.6 0 M8.5 13.1c-1 2.2 1 3.8 0 7.4 M16 11c-.8 2 1.2 4-1 9.5"),
        i("gift", "Gift", .city, "M4 10h16v3.5H4Z M5.5 13.5h13v7h-13Z M12 10v10.5 M12 10c-1.5-3-5-3.5-5-1.2 0 1.2 2.5 1.2 5 1.2Z M12 10c1.5-3 5-3.5 5-1.2 0 1.2-2.5 1.2-5 1.2Z"),
        i("music", "Music", .city, "M9 17.5V6l10-2.5v12 M9 9.5l10-2.5 M5 17.5a2 2 0 1 0 4 0a2 2 0 1 0 -4 0 M15 15.5a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"),
        i("camera", "Camera", .city, "M3.5 8h4l1.5-2.5h6L16.5 8h4v11h-17Z M8.6 13.3a3.4 3.4 0 1 0 6.8 0a3.4 3.4 0 1 0 -6.8 0"),
        i("book", "Reading", .city, "M12 6.5c-2-1.5-4.8-2-8-1.5v13c3.2-.5 6 0 8 1.5 2-1.5 4.8-2 8-1.5v-13c-3.2-.5-6 0-8 1.5Z M12 6.5v13"),

        // MARK: Everyday
        i("laptop", "Work", .everyday, "M5 5.5h14v10H5Z M3 18.5h18"),
        i("briefcase", "Business", .everyday, "M5 8h14c.8 0 1.5.7 1.5 1.5v9c0 .8-.7 1.5-1.5 1.5H5c-.8 0-1.5-.7-1.5-1.5v-9C3.5 8.7 4.2 8 5 8Z M9 8V5.5c0-.6.4-1 1-1h4c.6 0 1 .4 1 1V8 M3.5 13h17"),
        i("phone", "Phone", .everyday, "M8 3h8c.8 0 1.5.7 1.5 1.5v15c0 .8-.7 1.5-1.5 1.5H8c-.8 0-1.5-.7-1.5-1.5v-15C6.5 3.7 7.2 3 8 3Z M10.5 18h3"),
        i("plug", "Electronics", .everyday, "M9 3.5v4 M15 3.5v4 M6.5 7.5h11V11a5.5 5.5 0 0 1-11 0Z M12 16.5v4"),
        i("headphones", "Headphones", .everyday, "M4 16v-3.5a8 8 0 0 1 16 0V16 M4 14.5h2c.8 0 1.5.7 1.5 1.5v3c0 .8-.7 1.5-1.5 1.5H5.5c-.8 0-1.5-.7-1.5-1.5Z M20 14.5h-2c-.8 0-1.5.7-1.5 1.5v3c0 .8.7 1.5 1.5 1.5h.5c.8 0 1.5-.7 1.5-1.5Z"),
        i("wallet", "Money", .everyday, "M4 8h15c.6 0 1 .4 1 1v10c0 .6-.4 1-1 1H5c-.6 0-1-.4-1-1V6.5C4 5.7 4.7 5 5.5 5H16v3 M20 11.5h-3.5a1.75 1.75 0 0 0 0 3.5H20"),
        i("keys", "Keys", .everyday, "M3.5 8.5a4.5 4.5 0 1 0 9 0a4.5 4.5 0 1 0 -9 0 M11.2 11.7 20 20.5 M17.5 18l2-2 M15 15.5l1.7-1.7"),
        i("clothes", "Clothes", .everyday, "M9 3.5 4.5 5.5 2.5 10l3 1.5 1.5-2.2v11.2h10V9.3l1.5 2.2 3-1.5-2-4.5L15 3.5c-.4 1.3-1.6 2.2-3 2.2s-2.6-.9-3-2.2Z"),
        i("shoes", "Shoes", .everyday, "M3.5 19.5V11.5h3.2c1.1 1.6 2.9 2.4 5 2.4 1.5 0 2.9.4 4.2 1l2.5 1.2c1.5.7 2.3 1.8 2.3 3.4Z M3.5 19.5h4l1-1.5h3l1 1.5"),
        i("laundry", "Laundry", .everyday, "M5 3.5h14c.6 0 1 .4 1 1v15c0 .6-.4 1-1 1H5c-.6 0-1-.4-1-1v-15c0-.6.4-1 1-1Z M4 7.5h16 M7 5.5h.5 M10 5.5h.5 M8.2 14a3.8 3.8 0 1 0 7.6 0a3.8 3.8 0 1 0 -7.6 0"),
        i("toiletry", "Toiletries", .everyday, "M8.5 10h7v9.5c0 .6-.4 1-1 1h-5c-.6 0-1-.4-1-1Z M10.5 10V7.5h3V10 M12 7.5V4.5h4 M16 4.5v1.5 M10.5 14h3"),
        i("pill", "Medicine", .everyday, "M8.2 15.8a3.9 3.9 0 0 1 0-5.5l4.1-4.1a3.9 3.9 0 0 1 5.5 5.5l-4.1 4.1a3.9 3.9 0 0 1-5.5 0Z M10.2 8.2l5.6 5.6"),
        i("firstaid", "First aid", .everyday, "M4 7.5h16v12H4Z M9 7.5V5c0-.6.4-1 1-1h4c.6 0 1 .4 1 1v2.5 M12 10.8v5.4 M9.3 13.5h5.4"),
        i("heart", "Health", .everyday, "M12 20s-7.5-4.6-7.5-10.1A4.2 4.2 0 0 1 12 7.2a4.2 4.2 0 0 1 7.5 2.7C19.5 15.4 12 20 12 20Z"),
        i("sleep", "Sleeping", .everyday, "M3 18.5v-8 M3 14.5h18v4 M21 14.5v-1.5c0-1.4-1.1-2.5-2.5-2.5H11v4 M5.3 12a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0"),
        i("kids", "Kids", .everyday, "M5.9 6.5a2.6 2.6 0 1 0 5.2 0a2.6 2.6 0 1 0 -5.2 0 M3.5 20.5V18a5 5 0 0 1 10 0v2.5 M15.7 12a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M14.5 20.5v-1.3a3 3 0 0 1 6 0v1.3"),
        i("paw", "Dog", .everyday, "M12 20.5c-2.6 0-5-1.4-5-3.4 0-2.6 2.4-5 5-5s5 2.4 5 5c0 2-2.4 3.4-5 3.4Z M3.4 10.5a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0 M7.4 6.5a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0 M13.4 6.5a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0 M17.4 10.5a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0"),
    ]

    /// The 50 keys every build since 0.46 knows — never renamed, never dropped.
    public static let firstFifty: [String] = [
        "car", "plane", "rv", "train", "ferry", "suitcase", "backpack", "box", "hiking", "mountain",
        "diving", "fin", "golf", "bike", "run", "strength", "kettlebell", "swim", "mobility", "breath",
        "yoga", "tent", "fire", "ski", "snow", "sun", "beach", "rain", "compass", "kayak",
        "fishing", "climb", "racket", "passport", "firstaid", "pill", "toiletry", "plug", "laptop", "camera",
        "coffee", "food", "sleep", "sauna", "paw", "book", "gift", "glasses", "headlamp", "heart",
    ]

    private static let byKey: [String: TemplateIcon] = Dictionary(all.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })

    /// The icon of this key, or nil (an unknown key, or none).
    public static func icon(_ key: String?) -> TemplateIcon? { key.flatMap { byKey[$0] } }

    /// The icons under each heading, headings in the picker's order (empty ones left out).
    public static var grouped: [(group: TemplateIconGroup, icons: [TemplateIcon])] {
        TemplateIconGroup.allCases.compactMap { g in
            let icons = all.filter { $0.group == g }
            return icons.isEmpty ? nil : (g, icons)
        }
    }
}
