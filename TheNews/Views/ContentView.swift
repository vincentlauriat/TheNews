import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var vm = FeedViewModel()
    @State private var router = NotificationRouter.shared
    @State private var feedSelection: FeedSelection? = .all
    @State private var selectedId: String?
    @State private var showingManage = false
    #if os(iOS)
    @State private var showingSettings = false
    #endif

    var body: some View {
        NavigationSplitView {
            FeedsSidebarView(selection: $feedSelection, showingManage: $showingManage)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
                #if os(iOS)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                #endif
        } content: {
            ArticleListView(vm: vm, selectedId: $selectedId)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 460)
        } detail: {
            if let article = vm.selectedArticle {
                #if os(iOS)
                ArticlePagerView(vm: vm)   // swipe horizontal entre articles
                #else
                ArticleDetailView(article: article)
                #endif
            } else {
                EmptySelectionView()
            }
        }
        .task { await vm.load(context: modelContext) }
        .task { await requestNotificationsIfNeeded() }
        #if os(macOS)
        .task { await runPeriodicRefresh() }
        #endif
        .onChange(of: feedSelection) { _, sel in
            Task { await vm.changeSelection(sel ?? .all, context: modelContext) }
        }
        .onChange(of: selectedId) { _, id in
            guard let id, let article = vm.articles.first(where: { $0.id == id }) else { return }
            vm.select(article)
        }
        .onChange(of: vm.selectedArticle?.id) { _, id in
            // Le swipe (pager iOS) change l'article : garde la liste synchronisée.
            if selectedId != id { selectedId = id }
        }
        .onChange(of: router.pendingArticleID) { _, id in
            guard let id else { return }
            openArticle(id: id)
            router.pendingArticleID = nil
        }
        .alert(settings.t("error_title"), isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button(settings.t("ok")) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .sheet(isPresented: $showingManage) {
            NavigationStack {
                WatchSettingsView()
                    .environment(settings)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(settings.t("ok")) { showingManage = false }
                        }
                    }
            }
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 480)
            #endif
        }
        #if os(iOS)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .environment(settings)
                    .navigationTitle(settings.t("settings_title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(settings.t("ok")) { showingSettings = false }
                        }
                    }
            }
        }
        #endif
    }

    // MARK: - Notifications & rafraîchissement

    /// Demande l'autorisation de notifier au premier lancement (si indéterminée).
    private func requestNotificationsIfNeeded() async {
        await NotificationService.shared.refreshStatus()
        if NotificationService.shared.status == .notDetermined {
            await NotificationService.shared.requestAuthorization()
        }
    }

    /// Ouvre l'article ciblé par un tap de notification (deep-link).
    private func openArticle(id: String) {
        let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.id == id })
        guard let article = try? modelContext.fetch(descriptor).first else { return }
        vm.selectedArticle = article
        if !article.isRead { article.isRead = true }
    }

    #if os(macOS)
    /// Rafraîchit périodiquement les flux tant que la fenêtre est ouverte (macOS n'a
    /// pas de `BGTaskScheduler` ; l'app tourne, donc une boucle légère suffit).
    private func runPeriodicRefresh() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1800)) // 30 min
            guard !Task.isCancelled else { break }
            await RefreshEngine.run(container: modelContext.container, notify: true)
            await vm.refresh(context: modelContext)
        }
    }
    #endif
}
