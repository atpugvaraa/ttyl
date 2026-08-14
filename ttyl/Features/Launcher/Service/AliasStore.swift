import Foundation

/// The user's own name for a launcher entry, matched as strongly as the real one. One per item.
@MainActor
@Observable
final class AliasStore {
    private let defaults = UserDefaults.standard
    private let storageKey = "launcherAliases"

    private(set) var aliases: [String: String]
    @ObservationIgnored var onChange: (([String: String]) -> Void)?

    init() {
        aliases = Self.cleaned(defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:])
    }

    func key(for entry: AppEntry) -> String { entry.preferenceKey }

    func alias(for entry: AppEntry) -> String { aliases[key(for: entry)] ?? "" }

    /// Blank clears it: the empty field is the only way to remove an alias.
    func setAlias(_ alias: String, for entry: AppEntry) {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        let k = key(for: entry)
        guard aliases[k] != (trimmed.isEmpty ? nil : trimmed) else { return }
        if trimmed.isEmpty { aliases.removeValue(forKey: k) } else { aliases[k] = trimmed }
        persist()
    }

    /// Replaces the whole map at once (used when importing a settings backup).
    func replace(_ replacement: [String: String]) {
        let cleaned = Self.cleaned(replacement)
        guard cleaned != aliases else { return }
        aliases = cleaned
        persist()
    }

    /// Drops keys whose alias is blank, so a stale empty string can never reach the matcher.
    private static func cleaned(_ raw: [String: String]) -> [String: String] {
        raw.compactMapValues {
            let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private func persist() {
        defaults.set(aliases, forKey: storageKey)
        onChange?(aliases)
    }
}
