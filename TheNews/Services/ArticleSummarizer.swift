import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Produit une **synthèse d'une liste d'articles** : à partir des titres affichés,
/// dégage les grands thèmes du moment. Utilise **Apple Intelligence** (Foundation
/// Models) en local quand c'est disponible ; sinon repli simple (premiers titres).
/// 100 % sur l'appareil, aucun serveur. Longueur, format et ton configurables.
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

    /// Synthèse des grands thèmes à partir d'une liste de titres, selon la config.
    static func digest(
        titles: [String],
        lang: String,
        length: DigestLength,
        format: DigestFormat,
        tone: DigestTone,
        count: Int
    ) async -> String {
        let headlines = titles.prefix(count).map { "- \($0)" }.joined(separator: "\n")
        guard !headlines.isEmpty else { return "" }
        let fr = lang.hasPrefix("fr")

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *),
           SystemLanguageModel.default.availability == .available {
            let instructions = buildInstructions(fr: fr, length: length, format: format, tone: tone)
            let prompt = (fr ? "Titres du moment :\n" : "Current headlines:\n") + headlines
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
        let n = length == .concise ? 3 : 6
        return titles.prefix(n).map { "- \($0)" }.joined(separator: "\n")
    }

    /// Construit la consigne du modèle à partir de la configuration.
    private static func buildInstructions(fr: Bool, length: DigestLength, format: DigestFormat, tone: DigestTone) -> String {
        if fr {
            let count = length == .concise ? "3" : "5 à 6"
            let shape = format == .bullets
                ? "sous forme de puces (une par thème)"
                : "en un paragraphe rédigé et fluide"
            let toneText: String
            switch tone {
            case .neutral:     toneText = "de façon factuelle et neutre"
            case .explanatory: toneText = "de façon pédagogique, en expliquant brièvement chaque thème"
            case .wire:        toneText = "de façon très synthétique, style dépêche d'agence"
            }
            let detail = length == .detailed ? " Ajoute une courte précision de contexte par thème." : ""
            return "Tu es un assistant de veille de presse. À partir d'une liste de titres d'actualité, "
                + "dégage \(count) grands thèmes du moment, en français, \(shape), \(toneText). "
                + "Pas d'introduction ni de conclusion.\(detail)"
        } else {
            let count = length == .concise ? "3" : "5 to 6"
            let shape = format == .bullets ? "as bullet points (one per theme)" : "as one flowing paragraph"
            let toneText: String
            switch tone {
            case .neutral:     toneText = "in a factual, neutral way"
            case .explanatory: toneText = "in an explanatory way, briefly clarifying each theme"
            case .wire:        toneText = "very tersely, in a news-wire style"
            }
            let detail = length == .detailed ? " Add a short context note per theme." : ""
            return "You are a news assistant. From a list of headlines, extract \(count) main themes, "
                + "in English, \(shape), \(toneText). No preamble or conclusion.\(detail)"
        }
    }
}
