import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Produit une **synthèse d'une liste d'articles** : à partir des titres affichés,
/// dégage les grands thèmes du moment. Utilise **Apple Intelligence** (Foundation
/// Models) en local quand c'est disponible ; sinon repli simple (premiers titres).
/// 100 % sur l'appareil, aucun serveur.
enum ArticleSummarizer {

    /// La synthèse générative on-device est-elle disponible sur cet appareil ?
    static var aiAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// Synthèse des grands thèmes à partir d'une liste de titres. `lang` = "fr"/"en".
    static func digest(titles: [String], lang: String, limit: Int = 25) async -> String {
        let headlines = titles.prefix(limit).map { "- \($0)" }.joined(separator: "\n")
        guard !headlines.isEmpty else { return "" }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *),
           SystemLanguageModel.default.availability == .available {
            let instructions = lang.hasPrefix("fr")
                ? "Tu es un assistant de veille de presse. À partir d'une liste de titres d'actualité, dégage en 3 à 5 puces les grands thèmes du moment, en français, de façon concise et factuelle. Pas d'introduction."
                : "You are a news assistant. From a list of headlines, extract the 3 to 5 main themes as concise, factual bullet points, in English. No preamble."
            let prompt = (lang.hasPrefix("fr") ? "Titres du moment :\n" : "Current headlines:\n") + headlines
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { return text }
            } catch {
                // repli ci-dessous
            }
        }
        #endif
        // Repli sans IA : les premiers titres en puces.
        return titles.prefix(5).map { "• \($0)" }.joined(separator: "\n")
    }
}
