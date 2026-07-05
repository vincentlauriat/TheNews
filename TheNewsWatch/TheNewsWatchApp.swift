import SwiftUI

/// App compagnon watchOS — vue rapide autonome : récupère et affiche les gros
/// titres des flux principaux, indépendamment de l'iPhone.
@main
struct TheNewsWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchFeedView()
        }
    }
}
