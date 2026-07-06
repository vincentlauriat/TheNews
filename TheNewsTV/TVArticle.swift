import Foundation

/// Un article récupéré en direct, enrichi du nom de sa source (RSS seul ne le
/// porte pas). Sert à la fois la liste d'une rubrique et l'agrégat « Tous les
/// articles »/« Briefing », qui mélangent plusieurs flux.
struct TVArticle: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let link: URL
    let imageURL: URL?
    let publishedAt: Date
    let sourceName: String
}

extension TVArticle {
    /// Récupère et fusionne les articles de plusieurs flux, en parallèle, triés
    /// du plus récent au plus ancien. Un flux en échec est ignoré silencieusement
    /// (autonome, pas de cache local pour retenter plus tard).
    static func fetch(from feeds: [Feed]) async -> [TVArticle] {
        let service = RSSService()
        var collected: [TVArticle] = []
        await withTaskGroup(of: [TVArticle].self) { group in
            for feed in feeds {
                group.addTask {
                    guard let parsed = try? await service.fetch(feed) else { return [] }
                    let sourceName = feed.source?.name ?? ""
                    return parsed.map {
                        TVArticle(id: $0.id, title: $0.title, summary: $0.summary, link: $0.link,
                                  imageURL: $0.imageURL, publishedAt: $0.publishedAt, sourceName: sourceName)
                    }
                }
            }
            for await batch in group { collected += batch }
        }
        return collected.sorted { $0.publishedAt > $1.publishedAt }
    }
}

/// Sélection d'un article dans une liste donnée — porte la liste complète et
/// l'index courant pour permettre le passage au suivant/précédent en détail
/// (flèches gauche/droite de la télécommande), sans re-fetch ni re-navigation.
struct TVArticleSelection: Hashable {
    let articles: [TVArticle]
    var index: Int
}
