import SwiftUI
import SwiftData

/// App compagnon tvOS — parcours des rubriques et des gros titres sur grand
/// écran. Depuis la Phase E2, partage les mêmes modèles SwiftData et la même
/// sync iCloud (CloudKit) que macOS/iOS : mêmes abonnements, favoris et flux
/// perso apparaissent sur la TV, plus de fetch RSS direct ni d'état « lu » en
/// mémoire (voir `ARCHITECTURE.md`). Navigation à la télécommande via le focus
/// engine natif SwiftUI.
@main
struct TheNewsTVApp: App {
    let modelContainer: ModelContainer = {
        do {
            let schema = Schema([Article.self, FeedSubscription.self, WatchTopic.self, CustomFeed.self])
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Impossible d'initialiser SwiftData : \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            TVFeedView(container: modelContainer)
                .task { await TVRefreshEngine.run(container: modelContainer) }
        }
        .modelContainer(modelContainer)
    }
}
