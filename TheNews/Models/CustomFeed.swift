import Foundation
import SwiftData

/// Flux RSS ajouté par l'utilisateur (au-delà du catalogue Le Monde / Les Echos).
/// Persisté en SwiftData ; converti à la volée en `Feed` pour rejoindre le catalogue
/// dynamique (`Feed.customCatalog`). Rattaché à la pseudo-source « Mes flux »
/// (`Source.custom`) pour le regroupement dans la sidebar et l'écran de gestion.
@Model
final class CustomFeed {
    // Valeurs par défaut + pas de `.unique` : exigences SwiftData + CloudKit. `id` est
    // un UUID, unique par construction.
    var id: String = "custom.\(UUID().uuidString)"
    var title: String = ""
    var urlString: String = ""
    /// Nom court d'icône SF Symbols pour la sidebar.
    var symbol: String = "dot.radiowaves.up.forward"
    var createdAt: Date = Date()

    init(
        id: String = "custom.\(UUID().uuidString)",
        title: String,
        urlString: String,
        symbol: String = "dot.radiowaves.up.forward",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.symbol = symbol
        self.createdAt = createdAt
    }

    /// Représentation `Feed` (nil si l'URL stockée est invalide).
    var asFeed: Feed? {
        guard let url = URL(string: urlString) else { return nil }
        return Feed(
            id: id,
            sourceID: Source.custom.id,
            title: title,
            symbol: symbol,
            rssURL: url
        )
    }
}
