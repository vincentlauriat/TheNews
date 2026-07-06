#if os(macOS)
import Sparkle

/// Enveloppe autour de `SPUStandardUpdaterController` (Sparkle) — auto-update
/// macOS uniquement. Instancier `.shared` démarre le vérificateur automatique
/// (respecte `SUEnableAutomaticChecks`/`SUScheduledCheckInterval` d'Info.plist,
/// silencieux tant qu'aucune mise à jour n'est trouvée) ; `checkForUpdates()`
/// déclenche une vérification manuelle avec interface (menu « Rechercher les
/// mises à jour… »).
@MainActor
final class SparkleUpdater {
    static let shared = SparkleUpdater()

    private let controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
#endif
