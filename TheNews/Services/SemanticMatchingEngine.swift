import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 2ᵉ passe sémantique sur les sujets de veille, en complément de `MatchingEngine` (lexical).
/// N'intervient que sur les articles **non matchés** par mots-clés, pour capter les paraphrases
/// (ex. « réchauffement climatique » ne matche pas le sujet « écologie » en lexical pur).
/// 100 % on-device (Foundation Models) ; repli : aucun match supplémentaire si indisponible —
/// zéro régression par rapport au comportement lexical existant.
@MainActor
enum SemanticMatchingEngine {

    /// Le modèle système est-il disponible sur cet appareil ?
    static var available: Bool { ArticleSummarizer.aiAvailable }

    /// Cache mémoire (id article → correspond ou non) : ne réévalue jamais deux fois le même
    /// article dans la session courante. Volontairement non persisté (v1) — le coût d'une
    /// réévaluation au relancement de l'app est acceptable vu le volume borné par l'appelant.
    private static var cache: [String: Bool] = [:]

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    fileprivate struct MatchResult {
        @Guide(description: "true si l'article se rapporte à l'un des sujets, même par paraphrase, synonyme ou reformulation")
        let matches: Bool
    }
    #endif

    /// Parmi `candidates`, ceux qui correspondent sémantiquement à au moins un des `topics` actifs —
    /// à ajouter aux articles déjà matchés lexicalement par `MatchingEngine`. Retourne un ensemble
    /// vide si Foundation Models est indisponible ou s'il n'y a aucun sujet actif.
    static func additionalMatches(
        among candidates: [Article], topics: [WatchTopic], lang: String
    ) async -> Set<String> {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *), available, !topics.isEmpty else { return [] }
        let labels = topics.map(\.label)
        var matched: Set<String> = []
        for article in candidates {
            if let cached = cache[article.id] {
                if cached { matched.insert(article.id) }
                continue
            }
            let isMatch = await evaluate(article, topicLabels: labels, lang: lang)
            cache[article.id] = isMatch
            if isMatch { matched.insert(article.id) }
        }
        return matched
        #else
        return []
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func evaluate(_ article: Article, topicLabels: [String], lang: String) async -> Bool {
        let fr = lang.hasPrefix("fr")
        let labels = topicLabels.joined(separator: ", ")
        let instructions = fr
            ? "Tu détermines si un article de presse se rapporte à l'un des sujets suivis, même de "
                + "façon indirecte, par paraphrase, synonyme ou reformulation. Réponds uniquement via "
                + "le champ structuré demandé, sans commentaire."
            : "You determine whether a news article relates to one of the watched topics, even "
                + "indirectly, by paraphrase, synonym or rewording. Answer only via the requested "
                + "structured field, with no commentary."
        let prompt = fr
            ? "Sujets suivis : \(labels)\nArticle : \(article.title) — \(article.summary)"
            : "Watched topics: \(labels)\nArticle: \(article.title) — \(article.summary)"
        do {
            // Session dédiée par article (pas de réutilisation) : garde chaque évaluation
            // indépendante, sans biais de contexte issu des articles précédents du lot.
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt, generating: MatchResult.self)
            return response.content.matches
        } catch {
            return false
        }
    }
    #endif
}
