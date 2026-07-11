import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Étend une question en langage naturel (« des nouvelles sur l'IA ? ») en mots-clés à chercher
/// dans titre/chapô. Volontairement **pas** de tool-calling : le modèle ne choisit jamais
/// directement quels articles existent, il ne fait qu'élargir la requête — le filtrage réel reste
/// un simple test de sous-chaîne côté Swift (`FeedViewModel.filtered`), donc aucun risque
/// d'halluciner un article inexistant. 100 % on-device ; repli : la requête telle quelle.
@MainActor
enum SmartSearchEngine {

    static var available: Bool { ArticleSummarizer.aiAvailable }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    fileprivate struct ExpandedQuery {
        @Guide(description: "3 à 6 mots-clés ou synonymes pertinents pour la recherche, en minuscules, sans article ni ponctuation")
        let keywords: [String]
    }
    #endif

    /// Mots-clés à utiliser pour filtrer les articles à partir de la requête `query`. Retourne
    /// toujours au moins `[query]` (jamais vide tant que `query` n'est pas vide) : en cas
    /// d'indisponibilité ou d'échec du modèle, le comportement retombe sur la recherche par
    /// sous-chaîne actuelle, sans régression.
    static func expand(_ query: String, lang: String) async -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *), available else { return [trimmed] }
        let fr = lang.hasPrefix("fr")
        let instructions = fr
            ? "Tu transformes une question en langage naturel sur l'actualité en une liste de "
                + "mots-clés à rechercher dans des titres et chapôs d'articles de presse."
            : "You turn a natural-language question about the news into a list of keywords to "
                + "search news article headlines and summaries."
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: trimmed, generating: ExpandedQuery.self)
            let words = response.content.keywords
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return words.isEmpty ? [trimmed] : words
        } catch {
            return [trimmed]
        }
        #else
        return [trimmed]
        #endif
    }
}
