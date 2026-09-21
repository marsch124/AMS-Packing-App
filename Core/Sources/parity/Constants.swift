// `calc.constants` — every exported constant of the model by name, written as the JS
// module holds it (61 names; PHASES / PHASE_IDS / ITEM_CONDITIONS / ITEM_CONDITION_IDS
// are setup state, §6).

import Foundation
import PackingCore

extension Parity {
    func constants() -> J {
        let idLabels: ([IdLabel]) -> J = { xs in .array(xs.map { obj(["id": .string($0.id), "label": .string($0.label)]) }) }
        let n: (Int) -> J = { jint($0) }
        var weatherSuggestions: [String: J] = [:]
        for (k, specs) in WEATHER_SUGGESTIONS { weatherSuggestions[k] = .array(specs.map { $0.json }) }
        var defaultFields: [String: J] = [:]
        for f in DEFAULT_FIELDS { defaultFields[f.field] = .string(f.channel) }
        let o: [String: J] = [
            "ACTION_PRIORITIES": idLabels(ACTION_PRIORITIES), "ACTION_PRIORITY_IDS": jstrings(ACTION_PRIORITY_IDS),
            "ACTIVITY_ORDER": .object(ACTIVITY_ORDER.mapValues { jstrings($0) }),
            "AUDITABLE_KINDS": jstrings(AUDITABLE_KINDS), "AUDIT_LABELS": .object(AUDIT_LABELS.mapValues { .string($0) }),
            "AUDIT_STRAY_TOLERANCE": n(AUDIT_STRAY_TOLERANCE), "BACKUP_DUE_DAYS": n(BACKUP_DUE_DAYS),
            "BACKUP_URGENT_DAYS": n(BACKUP_URGENT_DAYS),
            "CATEGORIES": jstrings(CATEGORIES), "CATEGORY_DEFAULT": .string(CATEGORY_DEFAULT), "CATERING": idLabels(CATERING),
            "CHARGE_TYPES": .array(CHARGE_TYPES.map { obj(["id": .string($0.id), "label": .string($0.label), "short": .string($0.short)]) }),
            "CHARGE_TYPE_IDS": jstrings(CHARGE_TYPE_IDS), "CONDITION_TONES": idLabels(CONDITION_TONES),
            "CONTAINERS": jstrings(CONTAINERS), "CONTAINER_LIMITS_KG": .object(CONTAINER_LIMITS_KG.mapValues { .number($0) }),
            "CONTAINER_LIST_NAME": .string(CONTAINER_LIST_NAME), "CONTAINER_ROLE": .string(CONTAINER_ROLE),
            "CONTEXTS": jstrings(CONTEXTS), "CONTEXTUAL_FIELDS": jstrings(CONTEXTUAL_FIELDS), "CURRENCIES": jstrings(CURRENCIES),
            "DEFAULT_FIELDS": .object(defaultFields),
            "DEFAULT_ITEM_CONDITIONS": .array(DEFAULT_ITEM_CONDITIONS.map { shapeCondition($0) }),
            // In JS the starter people carry no id, and the factory phases no `order`.
            "DEFAULT_PEOPLE": .array(DEFAULT_PEOPLE.map { obj(["name": .string($0.name), "color": .string($0.color)]) }),
            "DEFAULT_PHASES": .array(DEFAULT_PHASES.map { pick($0.json, ["id", "label", "hint", "emoji", "color", "task", "leadDays"]) }),
            "DEFAULT_STORAGE_LOCATIONS": jstrings(DEFAULT_STORAGE_LOCATIONS), "EXPIRY_SOON_DAYS": n(EXPIRY_SOON_DAYS),
            "GRAB_SHARE_ITEMS_MAX": n(GRAB_SHARE_ITEMS_MAX), "GRAB_SHARE_ITEM_MAX": n(GRAB_SHARE_ITEM_MAX),
            "GRAB_SHARE_KIND": .string(GRAB_SHARE_KIND), "GRAB_SHARE_NAME_MAX": n(GRAB_SHARE_NAME_MAX),
            "GROUPS": .array(GROUPS.map { obj(["id": .string($0.id), "label": .string($0.label), "hint": .string($0.hint)]) }),
            "GROUP_IDS": jstrings(GROUP_IDS), "INTRINSIC_FIELDS": jstrings(INTRINSIC_FIELDS),
            "KIT_DEFAULT_EMOJI": .string(KIT_DEFAULT_EMOJI), "LAUNDRY_CAP_NIGHTS": n(LAUNDRY_CAP_NIGHTS),
            "LIST_SHARE_ITEMS_MAX": n(LIST_SHARE_ITEMS_MAX), "LIST_SHARE_KIND": .string(LIST_SHARE_KIND),
            "LIST_SHARE_NAME_MAX": n(LIST_SHARE_NAME_MAX),
            "MAINTENANCE_INTERVALS": .array(MAINTENANCE_INTERVALS.map { obj(["days": n($0.days), "label": .string($0.label)]) }),
            "MAINTENANCE_SOON_DAYS": n(MAINTENANCE_SOON_DAYS), "MAINTENANCE_UPCOMING_DAYS": n(MAINTENANCE_UPCOMING_DAYS),
            "MAX_PHOTOS": n(MAX_PHOTOS), "PERSON_COLORS": jstrings(PERSON_COLORS), "PHASE_DEFAULT_EMOJI": .string(PHASE_DEFAULT_EMOJI),
            "RETIRE_REASONS": idLabels(RETIRE_REASONS), "RETIRE_REASON_IDS": jstrings(RETIRE_REASON_IDS),
            "REVIEW_WINDOW_DAYS": n(REVIEW_WINDOW_DAYS), "SEASONS": jstrings(SEASONS), "SHARED_KINDS": jstrings(SHARED_KINDS),
            "SHARE_ZIP_PREFIX": .string(SHARE_ZIP_PREFIX), "SYNC_RESERVED_KEYS": jstrings(SYNC_RESERVED_KEYS),
            "TEMPLATE_COLORS": jstrings(TEMPLATE_COLORS), "TEMPLATE_DEFAULT_EMOJI": .string(TEMPLATE_DEFAULT_EMOJI),
            "TRANSPORTS": jstrings(TRANSPORTS), "TRIP_KIND": .string(TRIP_KIND), "TRIP_LINK_MAX": n(TRIP_LINK_MAX),
            "WEATHER_CONDITIONS": idLabels(WEATHER_CONDITIONS), "WEATHER_CONDITION_IDS": jstrings(WEATHER_CONDITION_IDS),
            "WEATHER_SUGGESTIONS": .object(weatherSuggestions),
            "WEATHER_THRESHOLDS": obj([
                "coldMinC": .number(WEATHER_THRESHOLDS.coldMinC), "coolMaxSummerC": .number(WEATHER_THRESHOLDS.coolMaxSummerC),
                "hotMaxC": .number(WEATHER_THRESHOLDS.hotMaxC), "windKmh": .number(WEATHER_THRESHOLDS.windKmh),
                "wetProb": .number(WEATHER_THRESHOLDS.wetProb),
            ]),
        ]
        return .object(o)
    }
}
