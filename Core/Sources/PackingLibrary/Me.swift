import PackingCore

// "This is me" (0.70) — his answer to "whose things does Apple Health mark?": "My things."
// One owner in Your choices → Owners can be marked as him (one at most). Apple Health's
// review then treats that owner's things, and "Both have one", as his. Stored in `meta`
// under "me" (a record of its own, so it syncs) and in a backup's `prefs.me`.

extension Library {
    /// The `meta` key (and the backup's `prefs` key) his mark is kept under.
    public static let meKey = "me"

    /// The owner marked "This is me", spelled as Owners shows it; nil = nobody marked, or
    /// the marked name is no longer one of the owners.
    public func me() -> String? {
        guard let stored = meta[Library.meKey]?.stringValue, !normName(stored).isEmpty else { return nil }
        return ownerChoices().first { normName($0) == normName(stored) }
    }

    /// Mark an owner as him (nil = nobody). Refused for a name that is not an owner. One at
    /// most: marking another moves the mark.
    @discardableResult
    public mutating func setMe(_ name: String?) -> Bool {
        guard let name, !normName(name).isEmpty else { meta[Library.meKey] = nil; return true }
        guard let owner = ownerChoices().first(where: { normName($0) == normName(name) }) else { return false }
        meta[Library.meKey] = .string(owner)
        return true
    }
}
