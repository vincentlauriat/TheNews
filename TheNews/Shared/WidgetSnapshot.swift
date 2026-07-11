import Foundation

/// Instantané léger partagé entre l'app et l'extension widget via un **App Group**.
/// L'app le publie après chaque rafraîchissement ; le widget le lit pour sa timeline.
/// Volontairement `Codable` et minimal (pas de SwiftData partagé entre cibles).

/// Identifiant de l'App Group partagé (doit figurer dans les entitlements des deux cibles).
enum AppGroup {
    static let id = "group.fr.vincentlauriat.thenews"
}

/// Un article réduit à ce qu'affiche le widget.
struct WidgetArticle: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let source: String
    let sectionTitle: String
    let publishedAt: Date
}

/// Contenu publié pour le widget : quelques articles + l'horodatage de génération.
struct WidgetSnapshot: Codable {
    var articles: [WidgetArticle]
    var generatedAt: Date

    static let empty = WidgetSnapshot(articles: [], generatedAt: .distantPast)
}

/// Lecture/écriture de l'instantané dans le container de l'App Group (fichier JSON).
enum WidgetSnapshotStore {
    private static let fileName = "widget-snapshot.json"

    private static var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)?
            .appendingPathComponent(fileName)
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let url, let data = try? JSONEncoder.iso.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        // L'écriture atomique passe par un fichier temporaire créé avec des
        // permissions restrictives (lecture au seul propriétaire) : sans ce
        // chmod explicite, les autres membres de l'App Group (widget, écran de
        // veille) ne peuvent pas relire le fichier malgré l'accès au container.
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
    }

    static func read() -> WidgetSnapshot {
        guard let url, let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder.iso.decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}

extension JSONEncoder {
    static var iso: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }
}
extension JSONDecoder {
    static var iso: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
