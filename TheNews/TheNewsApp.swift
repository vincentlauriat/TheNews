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

    /// Conteneur SwiftData partagé (articles persistés + dédup).
    let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Article.self, FeedSubscription.self, WatchTopic.self)
        } catch {
            fatalError("Impossible d'initialiser SwiftData : \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
                .task { NotificationService.shared.configureDelegate() }
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
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
