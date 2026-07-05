import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Résume un article en quelques phrases. Utilise **Apple Intelligence**
/// (Foundation Models) en local, sur l'appareil, quand c'est disponible ; sinon
/// repli **extractif** (premières phrases du chapô). Aucun serveur, aucune donnée
/// ne quitte l'appareil.
enum ArticleSummarizer {

    /// Le résumé génératif on-device est-il disponible sur cet appareil ?
    static var aiAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// Résumé de l'article. `lang` = code langue courant ("fr"/"en") pour la consigne.
    static func summarize(title: String, body: String, lang: String) async -> String {
        let source = "\(title)\n\n\(body)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return "" }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *),
           SystemLanguageModel.default.availability == .available {
            let instructions = lang.hasPrefix("fr")
                ? "Tu résumes des articles de presse en 2 phrases claires et factuelles, en français, sans introduction."
                : "You summarize news articles in 2 clear, factual sentences, in English, with no preamble."
            let prompt = (lang.hasPrefix("fr") ? "Résume cet article :\n" : "Summarize this article:\n") + source
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { return text }
            } catch {
                // repli silencieux ci-dessous
            }
        }
        #endif
        return extractive(body)
    }

    /// Repli extractif : les premières phrases significatives, tronquées.
    static func extractive(_ text: String, maxChars: Int = 220) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        var out = ""
        for sentence in trimmed.split(whereSeparator: { ".!?".contains($0) }) {
            let s = sentence.trimmingCharacters(in: .whitespaces)
            guard !s.isEmpty else { continue }
            if out.isEmpty { out = s } else { out += ". " + s }
            if out.count >= maxChars { break }
        }
        if out.count > maxChars {
            out = String(out.prefix(maxChars)).trimmingCharacters(in: .whitespaces) + "…"
        } else if !out.isEmpty {
            out += "."
        }
        return out
    }
}
