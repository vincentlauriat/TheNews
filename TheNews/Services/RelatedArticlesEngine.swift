import Foundation
import SwiftData

/// Détecte les articles de **sources différentes** qui traitent le **même sujet**,
/// entièrement on-device et sans dépendance. Le score repose sur le recoupement des
/// mots significatifs des titres/chapôs (similarité de Jaccard), normalisés comme
/// dans `MatchingEngine` (insensible casse/accents). Sert la vue « Aussi couvert par… ».
///
/// Pas de `@MainActor` au niveau du type : `tokens`/`similarity` sont des fonctions pures
/// (aucun état, aucun accès SwiftData) volontairement `nonisolated` pour pouvoir tourner en
/// tâche de fond (cf. `related`, seule fonction isolée sur le MainActor car elle touche au
/// `ModelContext`).
enum RelatedArticlesEngine {

    /// Mots vides ignorés (fr + en) : trop fréquents pour être discriminants.
    private static let stopWords: Set<String> = [
        // fr
        "avec", "dans", "pour", "plus", "sans", "sont", "cette", "leur", "leurs", "elle",
        "elles", "nous", "vous", "mais", "donc", "chez", "entre", "aussi", "apres", "avant",
        "contre", "selon", "tout", "tous", "toute", "toutes", "encore", "depuis", "vers",
        "être", "etre", "fait", "faire", "deux", "trois", "cent", "mille", "ans", "an",
        // en
        "with", "from", "that", "this", "have", "will", "your", "they", "their", "them",
        "about", "into", "over", "after", "before", "than", "then", "there", "what", "when",
        "which", "while", "would", "could", "should", "been", "were", "also", "more", "most",
    ]

    /// Ensemble des mots significatifs (≥ 4 lettres, hors mots vides) d'un texte.
    static func tokens(_ text: String) -> Set<String> {
        let norm = MatchingEngine.normalize(text)
        let parts = norm.split { !$0.isLetter && !$0.isNumber }
        return Set(parts.map(String.init).filter { $0.count >= 4 && !stopWords.contains($0) })
    }

    /// Similarité de Jaccard entre deux ensembles de mots (0…1).
    static func similarity(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let inter = a.intersection(b).count
        guard inter >= 2 else { return 0 }          // au moins 2 mots forts en commun
        let union = a.union(b).count
        return union > 0 ? Double(inter) / Double(union) : 0
    }

    /// Articles d'**autres sources** couvrant le même sujet que `article`, triés par
    /// pertinence décroissante. `days` borne la fenêtre temporelle ; `threshold` le
    /// score minimal ; `limit` le nombre de résultats.
    ///
    /// Appelée depuis `.task(id: article.id)` dans `ArticleDetailView` à **chaque** page du
    /// pager iOS — y compris la page voisine que le `TabView` instancie pendant le geste.
    /// Tout le travail lourd (fetch des centaines d'articles de la fenêtre, lecture de leurs
    /// titres/chapôs, filtrage par source, tokenisation + Jaccard) tourne donc dans un
    /// `ModelContext` d'arrière-plan : fait sur le MainActor, il gelait l'animation de swipe.
    /// Le MainActor ne fait que préparer des valeurs `Sendable` puis recharger les ≤ `limit`
    /// articles retenus.
    @MainActor
    static func related(
        to article: Article,
        context: ModelContext,
        within days: Int = 3,
        threshold: Double = 0.12,
        limit: Int = 5
    ) async -> [Article] {
        let base = tokens(article.title + " " + article.summary)
        guard base.count >= 2 else { return [] }

        let sourceID = Feed.byID(article.feedID)?.sourceID
        // Rubriques de la même source, écartées : leurs articles se ressemblent déjà par
        // style/rubrique (on ne veut que du cross-source). Calculé ici car le catalogue
        // (`Feed.customCatalog`) n'est muté que sur le MainActor.
        let sameSourceFeedIDs = Set(Feed.catalog.filter { $0.sourceID == sourceID }.map(\.id))
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        let excludeID = article.id
        let container = context.container

        let topIDs = await Task.detached(priority: .userInitiated) { () -> [String] in
            let background = ModelContext(container)
            let rows = (try? background.fetch(FetchDescriptor<Article>(
                predicate: #Predicate { $0.publishedAt >= cutoff && $0.id != excludeID }
            ))) ?? []
            var scored: [(id: String, score: Double)] = []
            for row in rows where !sameSourceFeedIDs.contains(row.feedID) {
                let score = similarity(base, tokens(row.title + " " + row.summary))
                if score >= threshold { scored.append((row.id, score)) }
            }
            return scored.sorted { $0.score > $1.score }.prefix(limit).map(\.id)
        }.value

        guard !topIDs.isEmpty, !Task.isCancelled else { return [] }
        let rows = (try? context.fetch(FetchDescriptor<Article>(
            predicate: #Predicate { topIDs.contains($0.id) }
        ))) ?? []
        let byID = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return topIDs.compactMap { byID[$0] }
    }
}
