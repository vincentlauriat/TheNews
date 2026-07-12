#if os(macOS)
import Foundation

/// Installe/actualise le screensaver embarqué (`TheNewsBriefing.saver`, copié dans les
/// Resources de l'app au build — cf. `project.yml`) vers `~/Library/Screen Savers/`.
///
/// Pas de canal de mise à jour séparé : l'update du screensaver suit celle de l'app (Sparkle).
/// Nécessite `com.apple.security.temporary-exception.files.home-relative-path.read-write`
/// (`/Library/Screen Savers/`) dans les entitlements — l'app est sandboxée et ce chemin est
/// hors du conteneur.
enum ScreenSaverInstaller {
    private static let bundleName = "TheNewsBriefing.saver"

    /// Copie le screensaver embarqué vers `~/Library/Screen Savers/` s'il est absent ou plus
    /// ancien que celui embarqué dans l'app. Best-effort : une installation impossible (ex.
    /// build de dev non sandboxé, permissions) ne doit jamais faire échouer le lancement de l'app.
    static func installOrUpdateIfNeeded() {
        guard let bundled = Bundle.main.resourceURL?.appendingPathComponent(bundleName),
              FileManager.default.fileExists(atPath: bundled.path) else { return }

        let installed = realHomeDirectory
            .appendingPathComponent("Library/Screen Savers")
            .appendingPathComponent(bundleName)

        if FileManager.default.fileExists(atPath: installed.path), !isNewer(bundled, than: installed) {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: installed.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: installed.path) {
                try FileManager.default.removeItem(at: installed)
            }
            try FileManager.default.copyItem(at: bundled, to: installed)
        } catch {
            // Best-effort — cf. commentaire ci-dessus.
        }
    }

    /// `FileManager.default.homeDirectoryForCurrentUser` renvoie le home **virtualisé du
    /// conteneur sandbox** (`~/Library/Containers/<bundle-id>/Data/`), pas le vrai `~/` — même
    /// avec l'entitlement home-relative-path. Il faut passer par `getpwuid` (POSIX) pour
    /// obtenir le vrai chemin, seul point d'entrée que l'exception sandbox rend accessible.
    private static var realHomeDirectory: URL {
        guard let pw = getpwuid(getuid()) else { return FileManager.default.homeDirectoryForCurrentUser }
        return URL(fileURLWithPath: String(cString: pw.pointee.pw_dir))
    }

    /// `true` si la version embarquée est plus récente que l'installée, ou si l'une des deux
    /// versions est illisible (on préfère réinstaller plutôt que de rester bloqué sur une
    /// version obsolète).
    private static func isNewer(_ bundled: URL, than installed: URL) -> Bool {
        guard let bundledVersion = shortVersion(of: bundled),
              let installedVersion = shortVersion(of: installed) else { return true }
        return bundledVersion.compare(installedVersion, options: .numeric) == .orderedDescending
    }

    private static func shortVersion(of bundleURL: URL) -> String? {
        Bundle(url: bundleURL)?.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
#endif
