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

    /// Synthèse des grands thèmes à partir d'une liste d'articles (titre + chapô —
    /// le chapô donne au modèle bien plus de matière que le titre seul pour
    /// dégager des thèmes pertinents), selon la config.
    static func digest(
        articles: [(title: String, summary: String)],
        lang: String,
        length: DigestLength,
        format: DigestFormat,
        tone: DigestTone,
        count: Int
    ) async -> String {
        let items = Array(articles.prefix(count))
        let headlines = items
            .map { $0.summary.isEmpty ? "- \($0.title)" : "- \($0.title) — \($0.summary)" }
            .joined(separator: "\n")
        guard !headlines.isEmpty else { return "" }
        let fr = lang.hasPrefix("fr")

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *),
           SystemLanguageModel.default.availability == .available {
            let instructions = buildInstructions(fr: fr, length: length, format: format, tone: tone)
            let prompt = (fr ? "Articles du moment (titre — chapô) :\n" : "Current articles (title — summary):\n") + headlines
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
        return items.prefix(n).map { "- \($0.title)" }.joined(separator: "\n")
    }

    /// Résumé court **à partir du titre seul** (le flux RSS ne fournit pas de corps d'article) —
    /// utilisé pour combler les articles sans chapô (`Article.summary` vide). Volontairement moins
    /// ambitieux qu'un vrai résumé éditorial : consigne explicite de ne pas inventer de faits
    /// au-delà du titre. `nil` si Foundation Models est indisponible ou en cas d'échec.
    static func oneLiner(title: String, lang: String) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *), SystemLanguageModel.default.availability == .available else {
            return nil
        }
        let fr = lang.hasPrefix("fr")
        let instructions = fr
            ? "Tu résumes un titre d'article de presse en une phrase courte et neutre, sans le "
                + "recopier mot pour mot, sans inventer de fait qui ne soit pas déjà dans le titre."
            : "You summarize a news headline into one short, neutral sentence, without repeating it "
                + "verbatim, without inventing any fact not already present in the title."
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: title)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
        #else
        return nil
        #endif
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
