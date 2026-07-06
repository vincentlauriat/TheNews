import Observation

/// Suivi « lu / non lu » en mémoire pour la session en cours — pas de
/// persistance, contrairement à `Article.isRead` (SwiftData) sur macOS/iOS.
/// Cohérent avec la version tvOS « lite » (E1, sans SwiftData) : réinitialisé
/// à chaque lancement de l'app plutôt que stocké.
@Observable
final class TVReadStore {
    private(set) var readIDs: Set<String> = []

    func isRead(_ id: String) -> Bool { readIDs.contains(id) }
    func markRead(_ id: String) { readIDs.insert(id) }
}
