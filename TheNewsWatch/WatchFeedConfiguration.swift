import Foundation

struct WatchFeedConfiguration: Equatable, Sendable {
    static let storageKey = "watchFeedIDs"
    static let contextKey = "watchFeedIDs"
    static let didChangeNotification = Notification.Name("WatchFeedConfigurationDidChange")

    static let defaultFeedIDs = ["lemonde.une", "lesechos.economie"]

    static var availableFeeds: [Feed] {
        Feed.leMondeCatalog + Feed.lesEchosCatalog + Feed.lopinionCatalog + Feed.calipiaCatalog
    }

    static func sanitizedFeedIDs(_ ids: [String]) -> [String] {
        let allowedIDs = Set(availableFeeds.map(\.id))
        var seen: Set<String> = []
        let sanitized = ids.compactMap { id -> String? in
            guard allowedIDs.contains(id), !seen.contains(id) else { return nil }
            seen.insert(id)
            return id
        }
        return sanitized.isEmpty ? defaultFeedIDs : sanitized
    }

    static func load(from defaults: UserDefaults = .standard) -> [String] {
        sanitizedFeedIDs(defaults.stringArray(forKey: storageKey) ?? defaultFeedIDs)
    }

    static func save(_ ids: [String], to defaults: UserDefaults = .standard) {
        defaults.set(sanitizedFeedIDs(ids), forKey: storageKey)
    }
}
