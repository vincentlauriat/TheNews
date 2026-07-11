import Foundation
import os

/// Instantané **riche** du Briefing, partagé via le même App Group que le widget
/// (`WidgetSnapshot.swift`), mais avec image + chapô : nécessaire à l'écran de
/// veille éditorial (cible `TheNewsScreenSaver`), qui affiche des heros visuels
/// plutôt qu'une liste de titres. Fichier séparé du snapshot widget pour ne pas
/// changer le contrat `Codable` que lit déjà l'extension WidgetKit en prod.
struct BriefingSnapshotArticle: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let source: String
    let imageURL: URL?
    let publishedAt: Date
}

/// Contenu publié pour l'écran de veille : les articles du Briefing du jour +
/// l'horodatage de génération.
struct BriefingSnapshot: Codable {
    var articles: [BriefingSnapshotArticle]
    var generatedAt: Date

    static let empty = BriefingSnapshot(articles: [], generatedAt: .distantPast)
}

/// Lecture/écriture de l'instantané dans le container de l'App Group (fichier JSON).
/// Journalise volontairement en détail (succès/échec, nombre d'articles) : seul
/// moyen de diagnostiquer la lecture depuis un `.saver` sandboxé, dont le
/// container n'est pas inspectable depuis un terminal classique.
enum BriefingSnapshotStore {
    private static let fileName = "briefing-screensaver-snapshot.json"
    private static let log = Logger(subsystem: "fr.vincentlauriat.thenews", category: "BriefingSnapshotStore")

    private static var url: URL? {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)
        if container == nil {
            log.error("containerURL(forSecurityApplicationGroupIdentifier: \(AppGroup.id, privacy: .public)) returned nil")
        }
        return container?.appendingPathComponent(fileName)
    }

    static func write(_ snapshot: BriefingSnapshot) {
        guard let url else { return }
        do {
            let data = try JSONEncoder.iso.encode(snapshot)
            try data.write(to: url, options: .atomic)
            // Cf. WidgetSnapshotStore.write : l'écriture atomique laisse des
            // permissions trop restrictives pour les autres membres de l'App Group.
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            log.notice("wrote \(snapshot.articles.count, privacy: .public) articles to \(url.path, privacy: .public)")
        } catch {
            log.error("write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func read() -> BriefingSnapshot {
        guard let url else { return .empty }
        do {
            let data = try Data(contentsOf: url)
            let snapshot = try JSONDecoder.iso.decode(BriefingSnapshot.self, from: data)
            log.notice("read \(snapshot.articles.count, privacy: .public) articles from \(url.path, privacy: .public)")
            return snapshot
        } catch {
            log.error("read failed at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }
}
