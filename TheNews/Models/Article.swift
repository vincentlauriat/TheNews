import Foundation
import SwiftData

/// Article de presse persisté (remplace l'entité de démonstration `Item`).
/// Un article est identifié de façon stable par `id` (le `guid` RSS, ou le lien à
/// défaut) pour permettre la déduplication entre deux rafraîchissements.
@Model
final class Article: Identifiable {
    // Valeurs par défaut sur chaque propriété : requises par SwiftData + CloudKit
    // (sync iCloud). L'unicité de `id` (guid) n'est plus une contrainte de schéma
    // — CloudKit ne les supporte pas — mais reste garantie par la déduplication
    // applicative de `FeedStore.ingest` (fetch par id avant insertion).
    /// Identifiant stable = guid RSS (ou lien normalisé si le flux n'a pas de guid).
    var id: String = ""
    /// Identifiant de la rubrique d'origine (`Feed.id`).
    var feedID: String = ""
    var title: String = ""
    /// Chapô / extrait fourni par le flux (le corps complet n'est pas dans le RSS).
    var summary: String = ""
    var link: URL = URL(string: "https://thenews.app")!
    var imageURL: URL?
    var publishedAt: Date = Date()
    /// Date de première insertion locale (sert au tri de repli et à « nouveauté »).
    var fetchedAt: Date = Date()
    var isRead: Bool = false
    var isFavorite: Bool = false
    /// Résumé généré on-device (Foundation Models) quand le flux RSS ne fournit pas de chapô
    /// (`summary` vide) — à partir du **titre seul** (le RSS n'a pas le corps de l'article), donc
    /// moins riche qu'un vrai chapô éditorial. Champ séparé de `summary` pour ne jamais laisser
    /// croire que c'est le chapô du journal ; cf. `displaySummary`/`summaryIsGenerated`.
    var aiSummary: String?

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
        isFavorite: Bool = false,
        aiSummary: String? = nil
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
        self.aiSummary = aiSummary
    }

    var feed: Feed? { Feed.byID(feedID) }

    /// Chapô à afficher : celui du flux s'il existe, sinon le résumé généré (peut être nil si pas
    /// encore généré, ou si le flux avait déjà un vrai chapô).
    var displaySummary: String? { summary.isEmpty ? aiSummary : summary }

    /// Le chapô affiché est-il généré par IA (à distinguer visuellement du vrai chapô éditorial) ?
    var summaryIsGenerated: Bool { summary.isEmpty && aiSummary != nil }

    var dateFormatted: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = Locale(identifier: AppLocale.identifier)
        return df.string(from: publishedAt)
    }
}
