import Foundation
import SwiftData

/// Détecte les articles de **sources différentes** qui traitent le **même sujet**,
/// entièrement on-device et sans dépendance. Le score repose sur le recoupement des
/// mots significatifs des titres/chapôs (similarité de Jaccard), normalisés comme
/// dans `MatchingEngine` (insensible casse/accents). Sert la vue « Aussi couvert par… ».
@MainActor
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
    static func related(
        to article: Article,
        context: ModelContext,
        within days: Int = 3,
        threshold: Double = 0.12,
        limit: Int = 5
    ) -> [Article] {
        let base = tokens(article.title + " " + article.summary)
        guard base.count >= 2 else { return [] }

        let sourceID = Feed.byID(article.feedID)?.sourceID
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        let excludeID = article.id
        let candidates = (try? context.fetch(FetchDescriptor<Article>(
            predicate: #Predicate { $0.publishedAt >= cutoff && $0.id != excludeID }
        ))) ?? []

        var scored: [(article: Article, score: Double)] = []
        for candidate in candidates {
            // Cross-source uniquement : on écarte la même source (dont les articles
            // internes se ressemblent déjà par style/rubrique).
            guard Feed.byID(candidate.feedID)?.sourceID != sourceID else { continue }
            let score = similarity(base, tokens(candidate.title + " " + candidate.summary))
            if score >= threshold { scored.append((candidate, score)) }
        }
        return scored.sorted { $0.score > $1.score }.prefix(limit).map(\.article)
    }
}
