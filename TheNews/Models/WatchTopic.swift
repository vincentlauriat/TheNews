import Foundation
import SwiftData

/// Sujet de veille défini par l'utilisateur : un libellé et une liste de mots-clés.
/// Un article « matche » le sujet si son titre ou son chapô contient l'un des
/// mots-clés (comparaison insensible à la casse et aux accents, cf. `MatchingEngine`).
@Model
final class WatchTopic: Identifiable {
    @Attribute(.unique) var id: String
    var label: String
    var keywords: [String]
    /// Le sujet participe-t-il au filtrage/alertes ?
    var isEnabled: Bool
    /// Les nouveaux articles correspondants peuvent-ils déclencher une notification ? (phase 4)
    var notify: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        label: String,
        keywords: [String],
        isEnabled: Bool = true,
        notify: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.keywords = keywords
        self.isEnabled = isEnabled
        self.notify = notify
        self.createdAt = createdAt
    }

    /// Représentation éditable des mots-clés (séparés par des virgules).
    var keywordsText: String { keywords.joined(separator: ", ") }
}
