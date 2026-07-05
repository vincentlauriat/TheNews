import Foundation
import SwiftData

/// Article de presse persisté (remplace l'entité de démonstration `Item`).
/// Un article est identifié de façon stable par `id` (le `guid` RSS, ou le lien à
/// défaut) pour permettre la déduplication entre deux rafraîchissements.
@Model
final class Article: Identifiable {
    /// Identifiant stable = guid RSS (ou lien normalisé si le flux n'a pas de guid).
    @Attribute(.unique) var id: String
    /// Identifiant de la rubrique d'origine (`Feed.id`).
    var feedID: String
    var title: String
    /// Chapô / extrait fourni par le flux (le corps complet n'est pas dans le RSS).
    var summary: String
    var link: URL
    var imageURL: URL?
    var publishedAt: Date
    /// Date de première insertion locale (sert au tri de repli et à « nouveauté »).
    var fetchedAt: Date
    var isRead: Bool
    var isFavorite: Bool

    init(
        id: String,
        feedID: String,
        title: String,
        summary: String,
        link: URL,
        imageURL: URL? = nil,
        publishedAt: Date,
        fetchedAt: Date,
        isRead: Bool = false,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.feedID = feedID
        self.title = title
        self.summary = summary
        self.link = link
        self.imageURL = imageURL
        self.publishedAt = publishedAt
        self.fetchedAt = fetchedAt
        self.isRead = isRead
        self.isFavorite = isFavorite
    }

    var feed: Feed? { Feed.byID(feedID) }

    var dateFormatted: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = Locale(identifier: AppLocale.identifier)
        return df.string(from: publishedAt)
    }
}
