import SwiftUI

/// The template icons — 50 of my own, drawn in the app's style (one stroke, round
/// ends, a 24-point box). He saw them on a sample sheet in day and night mode and
/// said (2 Oct 2026): "Your suggestions are fine. Please implement." No stock art,
/// no emoji (his rule). Only M L H V C S Q A Z — what SVGPath draws.
enum TemplateIcons {
    struct Icon: Identifiable { let key: String; let label: String; let path: String; var id: String { key } }

    static let all: [Icon] = [
        Icon(key: "car", label: "Car", path: "M4 16.5V12.8L6.2 8.2c.3-.6.8-.9 1.5-.9h8.6c.7 0 1.2.3 1.5.9L20 12.8v3.7Z M4 12.8h16 M6.5 16.5v2.2 M17.5 16.5v2.2 M7.5 14.6h1 M15.5 14.6h1"),
        Icon(key: "plane", label: "Plane", path: "M12 3.2c.8 0 1.3.8 1.3 1.9v4.8l7.2 4.3v1.9l-7.2-2.2v4l2 1.6v1.5L12 20.1l-3.3.9v-1.5l2-1.6v-4l-7.2 2.2v-1.9l7.2-4.3V5.1c0-1.1.5-1.9 1.3-1.9Z"),
        Icon(key: "rv", label: "Camper", path: "M2.5 17V8.3c0-.8.6-1.4 1.4-1.4h11.4c.5 0 .9.2 1.2.6L19 11h2.5v6Z M2.5 12.5h19 M5.5 6.9v3.3h5V6.9 M6 17a2 2 0 0 0 4 0 M14 17a2 2 0 0 0 4 0"),
        Icon(key: "train", label: "Train", path: "M7 3.5h10c1.1 0 2 .9 2 2v9.5c0 1.1-.9 2-2 2H7c-1.1 0-2-.9-2-2V5.5c0-1.1.9-2 2-2Z M5 10.5h14 M8.5 13.7h.5 M15 13.7h.5 M8.5 17 6.5 20.5 M15.5 17l2 3.5"),
        Icon(key: "ferry", label: "Ferry", path: "M3 14.5h18l-2.2 4.5H5.2Z M5.5 14.5v-4h13v4 M8.5 10.5V7h7v3.5 M12 7V4.5 M2.5 21.2c1.6 0 1.6-.9 3.2-.9s1.6.9 3.2.9 1.6-.9 3.2-.9 1.6.9 3.2.9 1.6-.9 3.2-.9 1.6.9 2 .9"),
        Icon(key: "suitcase", label: "Travel", path: "M4.5 8h15v11.5h-15Z M9 8V5c0-.6.4-1 1-1h4c.6 0 1 .4 1 1v3 M8.5 11v5.5 M15.5 11v5.5 M7 19.5v1 M17 19.5v1"),
        Icon(key: "backpack", label: "Backpack", path: "M7.5 7.5h9c1.4 0 2.5 1.1 2.5 2.5v10.5H5V10c0-1.4 1.1-2.5 2.5-2.5Z M9.5 7.5V5.2c0-.9.7-1.7 1.7-1.7h1.6c.9 0 1.7.8 1.7 1.7v2.3 M5 13h14 M10 13v2.5h4V13"),
        Icon(key: "box", label: "Boxes", path: "M3.5 7.8 12 3.8l8.5 4v8.9L12 20.7l-8.5-4Z M3.5 7.8 12 11.8l8.5-4 M12 11.8v8.9 M7.8 5.8l8.4 4"),
        Icon(key: "hiking", label: "Hiking", path: "M2.5 19.5 9.2 7.8l3.4 5.8 2.6-3.6 6.3 9.5Z M7.4 10.9l1.8 1.2 1.6-1.3"),
        Icon(key: "mountain", label: "Summit", path: "M3 20 12 4l9 16Z M12 4v3.5 M12 4h4l-1.2 1.6L16 7.2h-4 M8.3 12.4l1.9 1.3 1.8-1.5 1.8 1.5 1.9-1.3"),
        Icon(key: "diving", label: "Diving", path: "M3.5 8.5h15v6c0 1-.8 1.8-1.8 1.8h-3.1L11 13.8l-2.6 2.5H5.3c-1 0-1.8-.8-1.8-1.8Z M11 8.5v5.3 M18.5 11.5h2V4.5"),
        Icon(key: "fin", label: "Freediving", path: "M8.2 19.2a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M10 17.4V10 M10 10 7.6 3.5 M10 10l2.4-6.5 M5.8 3.5h3 M11.2 3.5h3 M7.2 14.4l2.8-1.4 2.8 1.4 M15.4 15.5a1.1 1.1 0 1 0 2.2 0a1.1 1.1 0 1 0 -2.2 0 M17.1 11a0.9 0.9 0 1 0 1.8 0a0.9 0.9 0 1 0 -1.8 0 M16.1 7.2a0.7 0.7 0 1 0 1.4 0a0.7 0.7 0 1 0 -1.4 0"),
        Icon(key: "golf", label: "Golf", path: "M7 20.5V3.5l9 3.5-9 3.5 M3.5 20.5h8 M16.5 18.4a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0"),
        Icon(key: "bike", label: "Bike", path: "M2.4 15.8a3.6 3.6 0 1 0 7.2 0a3.6 3.6 0 1 0 -7.2 0 M14.4 15.8a3.6 3.6 0 1 0 7.2 0a3.6 3.6 0 1 0 -7.2 0 M6 15.8l3.6-7h5.9L18 15.8 M9.6 8.8l2.9 7H6 M13.4 5.8h2.6 M14.7 5.8l.8 3"),
        Icon(key: "run", label: "Run", path: "M3 18v-4.2c0-.6.5-1 1.1-1 2 0 3.6-1.2 4.5-3.1l.5-1.2 3.1 1.6.9 2.1 5.1 1.5c1.6.5 2.8 1.9 2.8 3.5v.8Z M3 18h18 M12.3 11.8l-1.4 1.4 M14.2 13.2l-1.4 1.4"),
        Icon(key: "strength", label: "Strength", path: "M2.5 12h19 M5 8.5v7 M7.8 6.8v10.4 M16.2 6.8v10.4 M19 8.5v7"),
        Icon(key: "kettlebell", label: "Kettlebell", path: "M8.5 9.5a3.5 3.5 0 1 1 7 0 M6 14.5c0-3 2.7-5 6-5s6 2 6 5c0 2-.8 3.5-2 4.7-.3.2-.6.3-.9.3H8.9c-.3 0-.6-.1-.9-.3-1.2-1.2-2-2.7-2-4.7Z"),
        Icon(key: "swim", label: "Swim", path: "M2.5 16.6c1.6 0 1.6-1.2 3.2-1.2s1.6 1.2 3.2 1.2 1.6-1.2 3.2-1.2 1.6 1.2 3.2 1.2 1.6-1.2 3.2-1.2 1.6 1.2 3 1.2 M2.5 20.3c1.6 0 1.6-1.2 3.2-1.2s1.6 1.2 3.2 1.2 1.6-1.2 3.2-1.2 1.6 1.2 3.2 1.2 1.6-1.2 3.2-1.2 1.6 1.2 3 1.2 M5.5 12.5 10 8.8l3.5 2.4 3-1.4 M16.2 6.3a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0"),
        Icon(key: "mobility", label: "Mobility", path: "M10.3 4.8a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0 M12 8.2v5 M6 11.2l6 2 6-2 M5 19.5c2-2.6 4.5-3.7 7-3.7s5 1.1 7 3.7"),
        Icon(key: "breath", label: "Breath work", path: "M3 9h9.5a2.5 2.5 0 1 0-2.5-2.5 M3 12.5h14.5a3 3 0 1 1-3 3 M3 16h6"),
        Icon(key: "yoga", label: "Stretch", path: "M10.4 4.5a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0 M12 7.5 9 13l-4.5 1.5 M12 7.5l3 5.5 4.5 1.5 M9 13l-1 7 M15 13l1 7"),
        Icon(key: "tent", label: "Camping", path: "M2.5 19.5 12 4l9.5 15.5Z M12 4v15.5 M9 19.5l3-6.3 3 6.3"),
        Icon(key: "fire", label: "Campfire", path: "M12 3.5c2.1 3 4.6 4.5 4.6 8.1a4.6 4.6 0 0 1-9.2 0c0-2 1-3.2 2-4.1.3 1.5 1 2.1 1.8 2.4C11 8 11 6 12 3.5Z M4.5 20.5l15-3 M4.5 17.5l15 3"),
        Icon(key: "ski", label: "Skiing", path: "M3.5 17 17.2 6.9c.9-.7 2.2-.5 2.6.5 M5.5 20.5 19.2 10.4c.9-.7 2.2-.5 2.6.5 M9 12.3l1.6 2.2 M11 15.8l1.6 2.2"),
        Icon(key: "snow", label: "Winter", path: "M12 3v18 M4.2 7.5l15.6 9 M4.2 16.5l15.6-9 M9.8 4.4 12 6l2.2-1.6 M9.8 19.6 12 18l2.2 1.6"),
        Icon(key: "sun", label: "Summer", path: "M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0 M12 2.8v2.4 M12 18.8v2.4 M2.8 12h2.4 M18.8 12h2.4 M5.5 5.5l1.7 1.7 M16.8 16.8l1.7 1.7 M5.5 18.5l1.7-1.7 M16.8 7.2l1.7-1.7"),
        Icon(key: "beach", label: "Beach", path: "M3.5 11a8.5 8 0 0 1 17 0c-1.4-1-2.8-1-4.2 0-1.4-1-2.8-1-4.3 0-1.4-1-2.8-1-4.2 0-1.4-1-2.9-1-4.3 0Z M12 11v7.5a2 2 0 0 1-4 0"),
        Icon(key: "rain", label: "Rain", path: "M7 15.5a4 4 0 0 1-.5-8 5.5 5.5 0 0 1 10.6 1.3 3.4 3.4 0 0 1 .4 6.7Z M8 18.5l-1 2 M12 18.5l-1 2 M16 18.5l-1 2"),
        Icon(key: "compass", label: "Orienteering", path: "M3.5 12a8.5 8.5 0 1 0 17.0 0a8.5 8.5 0 1 0 -17.0 0 M15.2 8.8l-1.9 4.5-4.5 1.9 1.9-4.5Z"),
        Icon(key: "kayak", label: "Paddling", path: "M4 20 20 4 M3.2 17.2l3.6 3.6 1.7-1.7c.5-.5.5-1.3 0-1.8l-1.8-1.8c-.5-.5-1.3-.5-1.8 0Z M20.8 6.8l-3.6-3.6-1.7 1.7c-.5.5-.5 1.3 0 1.8l1.8 1.8c.5.5 1.3.5 1.8 0Z"),
        Icon(key: "fishing", label: "Fishing", path: "M15 3.5v11a4.5 4.5 0 0 1-9 0v-2.8 M6 11.7l-1.6 1.6 M15 3.5h-2.5"),
        Icon(key: "climb", label: "Climbing", path: "M9.5 3.5h3a4 4 0 0 1 4 4v9a4 4 0 0 1-8 0V9.5 M8.5 9.5l2.6-2.6"),
        Icon(key: "racket", label: "Racket sports", path: "M3.5 9.5a6 6 0 1 0 12 0a6 6 0 1 0 -12 0 M13.8 13.8 20 20 M5.8 7.5h7.4 M5.8 11.5h7.4 M7.5 5.8v7.4 M11.5 5.8v7.4 M17.7 5.3a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0"),
        Icon(key: "passport", label: "Passport", path: "M6 3.5h12v17H6Z M9.2 10a2.8 2.8 0 1 0 5.6 0a2.8 2.8 0 1 0 -5.6 0 M9 16h6"),
        Icon(key: "firstaid", label: "First aid", path: "M4 7.5h16v12H4Z M9 7.5V5c0-.6.4-1 1-1h4c.6 0 1 .4 1 1v2.5 M12 10.8v5.4 M9.3 13.5h5.4"),
        Icon(key: "pill", label: "Medicine", path: "M8.2 15.8a3.9 3.9 0 0 1 0-5.5l4.1-4.1a3.9 3.9 0 0 1 5.5 5.5l-4.1 4.1a3.9 3.9 0 0 1-5.5 0Z M10.2 8.2l5.6 5.6"),
        Icon(key: "toiletry", label: "Toiletries", path: "M8.5 10h7v9.5c0 .6-.4 1-1 1h-5c-.6 0-1-.4-1-1Z M10.5 10V7.5h3V10 M12 7.5V4.5h4 M16 4.5v1.5 M10.5 14h3"),
        Icon(key: "plug", label: "Electronics", path: "M9 3.5v4 M15 3.5v4 M6.5 7.5h11V11a5.5 5.5 0 0 1-11 0Z M12 16.5v4"),
        Icon(key: "laptop", label: "Work", path: "M5 5.5h14v10H5Z M3 18.5h18"),
        Icon(key: "camera", label: "Camera", path: "M3.5 8h4l1.5-2.5h6L16.5 8h4v11h-17Z M8.6 13.3a3.4 3.4 0 1 0 6.8 0a3.4 3.4 0 1 0 -6.8 0"),
        Icon(key: "coffee", label: "Coffee", path: "M4.5 9h12v6a4.5 4.5 0 0 1-4.5 4.5H9A4.5 4.5 0 0 1 4.5 15Z M16.5 11h1.3a2.5 2.5 0 0 1 0 5h-1.6 M8.5 3.5v2.5 M12.5 3.5v2.5"),
        Icon(key: "food", label: "Food", path: "M7 3.5v17 M4.5 3.5v5a2.5 2.5 0 0 0 5 0v-5 M17 20.5v-17c-2.2 1.5-3.2 4-3.2 7H17"),
        Icon(key: "sleep", label: "Sleeping", path: "M3 18.5v-8 M3 14.5h18v4 M21 14.5v-1.5c0-1.4-1.1-2.5-2.5-2.5H11v4 M5.3 12a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0"),
        Icon(key: "sauna", label: "Sauna", path: "M4 20h16 M8 16.5c-1-1.5 1-2.5 0-4s1-2.5 0-4 M12 16.5c-1-1.5 1-2.5 0-4s1-2.5 0-4 M16 16.5c-1-1.5 1-2.5 0-4s1-2.5 0-4"),
        Icon(key: "paw", label: "Dog", path: "M12 20.5c-2.6 0-5-1.4-5-3.4 0-2.6 2.4-5 5-5s5 2.4 5 5c0 2-2.4 3.4-5 3.4Z M3.4 10.5a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0 M7.4 6.5a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0 M13.4 6.5a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0 M17.4 10.5a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0"),
        Icon(key: "book", label: "Reading", path: "M12 6.5c-2-1.5-4.8-2-8-1.5v13c3.2-.5 6 0 8 1.5 2-1.5 4.8-2 8-1.5v-13c-3.2-.5-6 0-8 1.5Z M12 6.5v13"),
        Icon(key: "gift", label: "Party", path: "M4 10h16v3.5H4Z M5.5 13.5h13v7h-13Z M12 10v10.5 M12 10c-1.5-3-5-3.5-5-1.2 0 1.2 2.5 1.2 5 1.2Z M12 10c1.5-3 5-3.5 5-1.2 0 1.2-2.5 1.2-5 1.2Z"),
        Icon(key: "glasses", label: "Sunglasses", path: "M3 10.5h7.5v3a3 3 0 0 1-3 3h-1.5a3 3 0 0 1-3-3Z M13.5 10.5H21v3a3 3 0 0 1-3 3h-1.5a3 3 0 0 1-3-3Z M10.5 11.5h3 M3 10.5 2 8 M21 10.5 22 8"),
        Icon(key: "headlamp", label: "Headlamp", path: "M4 13.5c0-4.4 3.6-8 8-8s8 3.6 8 8 M9.5 12h5v4h-5Z M12 16v1.5 M8.5 19.5l-1.5 1.5 M12 19.5v2 M15.5 19.5l1.5 1.5"),
        Icon(key: "heart", label: "Health", path: "M12 20s-7.5-4.6-7.5-10.1A4.2 4.2 0 0 1 12 7.2a4.2 4.2 0 0 1 7.5 2.7C19.5 15.4 12 20 12 20Z"),
    ]

    static func icon(_ key: String?) -> Icon? { key.flatMap { k in all.first { $0.key == k } } }
}
