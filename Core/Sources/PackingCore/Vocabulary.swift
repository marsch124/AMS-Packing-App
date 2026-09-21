// Vocabulary — the fixed word lists of AMS Packing.
// Ported from the web app's js/model.js ("Fixed vocabularies").

/// WHAT kind of thing an item is — the primary grouping in Martin's own lists.
public let CATEGORIES: [String] = [
    "Clothing", "Adventure clothing", "Footwear", "Sport gear", "Food & drink",
    "Toiletries", "Pharmacy / meds", "Electronics", "Documents & money",
    "Charging", "Comfort & misc", "Reminders",
]
public let CATEGORY_DEFAULT = "Comfort & misc"

/// WHERE things get packed.
public let CONTAINERS: [String] = [
    "Toiletry bag", "Carry-on / hand luggage", "Checked luggage", "Hiking backpack",
    "Climbing backpack", "Golf bag", "Triathlon bag", "Swim bag", "Duffel bag",
    "Day pack", "Bellroy backpack", "Tech pouch", "Electronics bag", "Cool box",
    "Handbag", "RV storage box", "Other",
]
