// Vocabulary — the fixed word lists of AMS Packing.
// Ported from the web app's js/model.js ("Fixed vocabularies" and the small lookup
// tables that follow it). Phases and item conditions are EDITABLE and have files of
// their own (Phases.swift, ItemConditions.swift).
//
// Every item carries THREE independent grouping dimensions, so a trip's list can be
// viewed grouped by whichever the user prefers:
//   1. WHAT kind of thing -> `category`  (one of CATEGORIES)
//   2. WHERE it is packed  -> `container` (one of CONTAINERS, or a bag of his own)
//   3. WHEN it is packed   -> `phase`     (a PHASES id, the "process vector")

/// An `{ id, label }` pair — the shape of most of the small vocabularies.
public struct IdLabel: Equatable, Hashable, Sendable {
    public var id: String
    public var label: String
    public init(id: String, label: String) { self.id = id; self.label = label }
}

// MARK: - What / where

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

/// The built-in "Containers" catalogue: a special list (role 'container') whose
/// items ARE the bags/duffels/backpacks themselves, so each one reuses the full
/// item machinery — photos, storage, care, colour, brand — as a maintainable
/// physical object. Kept out of trips and the activity picker.
public let CONTAINER_ROLE = "container"
public let CONTAINER_LIST_NAME = "Containers"

/// Typical airline weight ceilings per bag (kg). 0/absent = no limit tracked.
public let CONTAINER_LIMITS_KG: [String: Double] = [
    "Carry-on / hand luggage": 8,
    "Checked luggage": 23,
    "Bellroy backpack": 8,
    "Day pack": 8,
]

// MARK: - Activity groups

/// Activity GROUPS — the top level Martin organises his life activities under.
/// Every building-block list belongs to one of these (or '' = ungrouped / utility list).
public struct ActivityGroup: Equatable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var hint: String
    public init(id: String, label: String, hint: String) { self.id = id; self.label = label; self.hint = hint }
}
public let GROUPS: [ActivityGroup] = [
    ActivityGroup(id: "GA", label: "Goal Activity", hint: "Life activities that matter — Travel, Golf, Hiking, Diving…"),
    ActivityGroup(id: "WET", label: "Workout, Exercise & Training", hint: "Swim, Bike, Run, Strength, Mobility, Breath work."),
    ActivityGroup(id: "OE", label: "Other Events", hint: "Small nice things — a coffee, a winter bath, a walk, the movies."),
]
public let GROUP_IDS: [String] = GROUPS.map { $0.id }

/// The order activities are offered in inside a group. Alphabetical is the wrong
/// order for training: Swim/Bike/Run is race order, and the gentler things belong
/// at the end. Only names listed here are placed; anything else — a list you added
/// or renamed — falls in after them, alphabetically, so nothing can go missing.
/// (`orderActivities` itself is in Lists.swift.)
public let ACTIVITY_ORDER: [String: [String]] = [
    "WET": ["Swim", "Bike", "Run", "Strength", "Mobility", "Breath work"],
]

public func group(_ id: String?) -> ActivityGroup? { GROUPS.first { $0.id == id } }
public func groupLabel(_ id: String?) -> String { group(id)?.label ?? "" }

// MARK: - Template covers

// A template can carry an emoji + colour that give it a face on the Templates grid.
// Both are optional: a template with no cover set still gets a default glyph and a
// stable, name-derived colour (`listEmoji` / `listColor`, in Lists.swift).
public let TEMPLATE_DEFAULT_EMOJI = "📋"
public let TEMPLATE_COLORS: [String] = ["#7c5cd6", "#3b82f6", "#06b6d4", "#22c55e", "#f59e0b", "#ef4444", "#ec4899", "#14b8a6", "#8b5cf6", "#64748b"]

// MARK: - Trip conditions

public let SEASONS: [String] = ["Summer", "Winter"]
public let TRANSPORTS: [String] = ["Car", "Plane", "RV"]

/// Standard set of "where it's stored" places, offered in every item's storage
/// dropdown out of the box. The user can add, rename and remove them; this is only
/// the starting point / fallback.
public let DEFAULT_STORAGE_LOCATIONS: [String] = [
    "Bedroom wardrobe",
    "Chest of drawers",
    "Hall closet",
    "Bathroom cabinet",
    "Kitchen cupboard",
    "Garage",
    "Loft / attic",
    "Basement / cellar",
    "Utility room",
    "Storage box",
    "Car boot",
    "RV / camper",
]

/// Weather conditions an item can be tagged for. A tagged item is "conditional
/// gear": kept out of the base list and offered as a suggestion only when the
/// trip's forecast calls for it. (The fuller weather logic is a later section.)
public let WEATHER_CONDITIONS: [IdLabel] = [
    IdLabel(id: "rain", label: "Rain"), IdLabel(id: "cold", label: "Cold"),
    IdLabel(id: "hot", label: "Heat"), IdLabel(id: "wind", label: "Wind"), IdLabel(id: "snow", label: "Snow"),
]
public let WEATHER_CONDITION_IDS: [String] = WEATHER_CONDITIONS.map { $0.id }

/// Context applies ONLY to WET (Workout, Exercise & Training) activity lists — it
/// describes how a workout is done (indoors, outdoors, or as a race). It never
/// narrows GA / base / transport lists.
public let CONTEXTS: [String] = ["Indoor", "Outdoor", "Race"]

public let CATERING: [IdLabel] = [
    IdLabel(id: "self", label: "Self-sufficient (cooking our own)"),
    IdLabel(id: "eatout", label: "Restaurants / eating out"),
    IdLabel(id: "mixed", label: "A mix of both"),
]
public func cateringLabel(_ id: String?) -> String { CATERING.first { $0.id == id }?.label ?? "" }

// MARK: - Charge types

/// How a charge item takes power — its connector / charger type. '' = unspecified.
/// `short` is the compact label shown on the ⚡ badge in the list.
public struct ChargeType: Equatable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var short: String
    public init(id: String, label: String, short: String) { self.id = id; self.label = label; self.short = short }
}
public let CHARGE_TYPES: [ChargeType] = [
    ChargeType(id: "", label: "Unspecified", short: ""),
    ChargeType(id: "usb-c", label: "USB-C", short: "USB-C"),
    ChargeType(id: "usb-a", label: "USB-A", short: "USB-A"),
    ChargeType(id: "micro-usb", label: "Micro-USB", short: "Micro"),
    ChargeType(id: "lightning", label: "Lightning (Apple)", short: "Lightning"),
    ChargeType(id: "special", label: "Special charger", short: "Special"),
    ChargeType(id: "mains", label: "Wall / mains plug", short: "Wall"),
]
public let CHARGE_TYPE_IDS: [String] = CHARGE_TYPES.map { $0.id }
public func chargeType(_ id: String?) -> ChargeType { CHARGE_TYPES.first { $0.id == id } ?? CHARGE_TYPES[0] }
public func chargeTypeLabel(_ id: String?) -> String { chargeType(id).label }
public func chargeTypeShort(_ id: String?) -> String { chargeType(id).short }

// MARK: - Retiring, currencies

/// Why an item is "Not in use" (retired from the kit). Distinct from `condition`,
/// which grades a thing you still own & pack; a retired item is no longer packed
/// at all, but its record is kept. Optional — a plain "not in use" needs no reason.
public let RETIRE_REASONS: [IdLabel] = [
    IdLabel(id: "sold", label: "Sold"),
    IdLabel(id: "broken", label: "Broken / not working"),
    IdLabel(id: "destroyed", label: "Destroyed / worn out"),
    IdLabel(id: "replaced", label: "Replaced"),
    IdLabel(id: "lost", label: "Lost"),
    IdLabel(id: "other", label: "Other"),
]
public let RETIRE_REASON_IDS: [String] = RETIRE_REASONS.map { $0.id }
public func retireReasonLabel(_ id: String?) -> String { RETIRE_REASONS.first { $0.id == id }?.label ?? "" }

/// Currencies offered for an item's price (the list Martin is likely to use first).
public let CURRENCIES: [String] = ["SEK", "EUR", "USD", "GBP", "CHF", "NOK", "DKK"]
