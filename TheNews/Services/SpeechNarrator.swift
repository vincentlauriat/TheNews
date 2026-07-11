import AVFoundation
import Observation

/// Lecture à voix haute 100% on-device (`AVSpeechSynthesizer`) — utilisée par
/// le bouton « Écouter » de la synthèse IA. Volontairement simple pour cette
/// première version : pas de session `AVAudioSession`/mode arrière-plan
/// dédiés, donc la lecture s'interrompt si l'app passe en arrière-plan sur
/// iOS (comportement par défaut du framework sans configuration additionnelle).
@Observable
@MainActor
final class SpeechNarrator: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, lang: String) {
        guard !text.isEmpty else { return }
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: lang)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    /// La voix système par défaut d'une langue est souvent la qualité
    /// « compact » (robotique) — on choisit plutôt la meilleure qualité
    /// **déjà installée** pour cette langue (`.premium` > `.enhanced` >
    /// `.default`). Si l'utilisateur a téléchargé une voix Personnalisée ou
    /// Améliorée (Réglages > Accessibilité > Contenu énoncé > Voix), elle est
    /// utilisée automatiquement, sans rien à changer côté app.
    private static func bestVoice(for lang: String) -> AVSpeechSynthesisVoice? {
        let prefix = lang.hasPrefix("fr") ? "fr" : "en"
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(prefix) }
        let best = candidates.max { $0.quality.rawValue < $1.quality.rawValue }
        return best ?? AVSpeechSynthesisVoice(language: lang.hasPrefix("fr") ? "fr-FR" : "en-US")
    }
}

extension SpeechNarrator: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
}
