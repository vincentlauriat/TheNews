import SwiftUI

/// App compagnon tvOS — parcours des rubriques et des gros titres sur grand
/// écran, autonome (aucune synchro iCloud ; fetch RSS direct, comme la version
/// Watch). Navigation à la télécommande via le focus engine natif SwiftUI.
@main
struct TheNewsTVApp: App {
    @State private var readStore = TVReadStore()

    var body: some Scene {
        WindowGroup {
            TVFeedView()
                .environment(readStore)
        }
    }
}
