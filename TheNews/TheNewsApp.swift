import SwiftUI
import SwiftData
#if os(iOS)
import BackgroundTasks
#endif

@main
struct TheNewsApp: App {
    @State private var settings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    /// Identifiant de la tâche de rafraîchissement en fond (iOS).
    /// Doit être déclaré dans `BGTaskSchedulerPermittedIdentifiers` (Info-iOS.plist).
    static let refreshTaskID = "fr.vincentlauriat.thenews.refresh"

    /// Conteneur SwiftData partagé. `cloudKitDatabase: .automatic` active la **sync
    /// iCloud** dès que l'app dispose de l'entitlement CloudKit (build signé) ; sinon
    /// il reste local (ex. build de dev macOS non signé) — pas de crash.
    let modelContainer: ModelContainer = {
        do {
            let schema = Schema([Article.self, FeedSubscription.self, WatchTopic.self, CustomFeed.self])
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Impossible d'initialiser SwiftData : \(error)")
        }
    }()

    /// Assigné ici plutôt que dans un `.task` sur `ContentView` pour éliminer la fenêtre de
    /// course au cold-start-via-notification (iOS) : `App.init()` s'exécute sur le main thread
    /// avant la construction de la première scène, alors qu'un `.task` attend le premier rendu
    /// de la vue, donc au moins un tour de run loop de plus.
    init() {
        NotificationService.shared.configureDelegate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
                #if os(macOS)
                .task { _ = SparkleUpdater.shared }
                .task { ScreenSaverInstaller.installOrUpdateIfNeeded() }
                #endif
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button(settings.t("check_for_updates")) { SparkleUpdater.shared.checkForUpdates() }
            }
        }
        #endif
        #if os(iOS)
        // Tâche de fond iOS : rafraîchit les flux et notifie, puis se replanifie.
        .backgroundTask(.appRefresh(Self.refreshTaskID)) {
            await RefreshEngine.run(container: modelContainer, notify: true)
            await Self.scheduleAppRefresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Task { await Self.scheduleAppRefresh() } }
        }
        #endif

        // Réglages via la scène native macOS (⌘,). Sur iOS, les réglages sont
        // présentés en feuille depuis `ContentView` (pas de scène `Settings`).
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(settings)
        }
        #endif
    }

    #if os(iOS)
    /// Planifie la prochaine exécution en fond (au plus tôt dans ~1 h).
    static func scheduleAppRefresh() async {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
    #endif
}
