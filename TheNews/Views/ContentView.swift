import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    /// Observe les flux perso pour rafraîchir le catalogue en mémoire même quand un
    /// flux arrive par **sync iCloud** (et pas seulement par ajout local).
    @Query private var customFeeds: [CustomFeed]
    @State private var vm = FeedViewModel()
    @State private var router = NotificationRouter.shared
    @State private var feedSelection: FeedSelection? = .all
    @State private var selectedId: String?
    @State private var showingManage = false
    #if os(iOS)
    @State private var showingSettings = false
    #endif

    var body: some View {
        splitView
        .task { await vm.load(context: modelContext, lang: settings.effectiveLang) }
        .task { await requestNotificationsIfNeeded() }
        #if os(macOS)
        .task { await runPeriodicRefresh() }
        #endif
        .onChange(of: feedSelection) { _, sel in
            let target = sel ?? .all
            // Garde-fou : si `vm.selection` correspond déjà à la cible (ex. `openDeepLink`
            // vient de la fixer de façon synchrone), ne relance pas `changeSelection` — ce
            // `Task` async remettrait `selectedArticle` à `nil` juste après la sélection.
            guard vm.selection != target else { return }
            Task { await vm.changeSelection(target, context: modelContext, lang: settings.effectiveLang) }
        }
        .onChange(of: customFeeds.map(\.id)) { _, _ in
            // Un flux perso a été ajouté/supprimé (localement ou par sync iCloud) :
            // recharge le catalogue en mémoire puis rafraîchit pour charger ses articles.
            CustomFeedStore(context: modelContext).reloadCatalog()
            Task { await vm.refresh(context: modelContext, lang: settings.effectiveLang) }
        }
        .onChange(of: selectedId) { _, id in
            guard let id, let article = vm.articles.first(where: { $0.id == id }) else { return }
            vm.select(article)
        }
        .onChange(of: vm.selectedArticle?.id) { _, id in
            // Le swipe (pager iOS) change l'article : garde la liste synchronisée.
            if selectedId != id { selectedId = id }
        }
        .onChange(of: router.pending) { _, destination in
            guard let destination else { return }
            handle(destination)
            router.pending = nil
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
        // Modale plutôt que la colonne détail du triptyque : en largeur compacte (iPhone), la
        // NavigationSplitView décide seule de la colonne visible d'après `selectedId` — le bouton
        // de synthèse remettait `selectedId = nil` pour désélectionner l'article, ce que le
        // système reprenait comme un retour arrière et empêchait d'afficher le détail (bouton IA
        // qui ne « faisait rien » sur iPhone). La modale est indépendante de cet état de colonne.
        .sheet(isPresented: Binding(
            get: { vm.showingDigest },
            set: { if !$0 { vm.showingDigest = false } }
        )) {
            NavigationStack {
                DigestDetailView(vm: vm)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(settings.t("cancel")) { vm.showingDigest = false }
                        }
                    }
            }
        }
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

    // MARK: - Disposition

    /// Sur macOS, le Briefing remplace le panneau liste + détail par un écran
    /// éditorial en pleine largeur (`BriefingEditorialView`) — la sidebar reste
    /// affichée, mais il n'y a plus de sélection d'article à faire, donc plus
    /// de colonne « content » à 3 volets. Les autres rubriques (et iOS, où le
    /// Briefing reste une liste comme les autres) gardent le triptyque habituel.
    @ViewBuilder
    private var splitView: some View {
        #if os(macOS)
        if feedSelection == .briefing {
            NavigationSplitView {
                sidebar
            } detail: {
                if vm.showingDigest {
                    DigestDetailView(vm: vm)
                } else {
                    BriefingEditorialView(vm: vm)
                }
            }
        } else if feedSelection == .alerts {
            // Écran Alertes fusionné (liste + gestion des sujets de veille) : toujours en
            // triptyque, indépendamment du mode carte (cf. `AlertsView`, décision assumée).
            NavigationSplitView {
                sidebar
            } content: {
                AlertsView(vm: vm, selectedId: $selectedId)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 460)
            } detail: {
                if vm.showingDigest {
                    DigestDetailView(vm: vm)
                } else if let article = vm.selectedArticle {
                    ArticleDetailView(article: article)
                } else {
                    EmptySelectionView()
                }
            }
        } else if settings.articleDisplayMode == .card {
            // Mode carte : pas de panneau de lecture séparé — la grille de cartes
            // occupe toute la largeur (comme le Briefing), le tap ouvre l'article
            // directement au lieu de le sélectionner (cf. ArticleListView).
            NavigationSplitView {
                sidebar
            } detail: {
                if vm.showingDigest {
                    DigestDetailView(vm: vm)
                } else {
                    ArticleListView(vm: vm, selectedId: $selectedId)
                }
            }
        } else {
            NavigationSplitView {
                sidebar
            } content: {
                ArticleListView(vm: vm, selectedId: $selectedId)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 460)
            } detail: {
                if vm.showingDigest {
                    DigestDetailView(vm: vm)
                } else if let article = vm.selectedArticle {
                    ArticleDetailView(article: article)
                } else {
                    EmptySelectionView()
                }
            }
        }
        #else
        NavigationSplitView {
            sidebar
        } content: {
            if feedSelection == .alerts {
                AlertsView(vm: vm, selectedId: $selectedId)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 460)
            } else {
                ArticleListView(vm: vm, selectedId: $selectedId)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 460)
            }
        } detail: {
            if vm.selectedArticle != nil {
                ArticlePagerView(vm: vm)   // swipe horizontal entre articles
            } else {
                EmptySelectionView()
            }
        }
        #endif
    }

    private var sidebar: some View {
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
                    .accessibilityLabel(settings.t("settings_title"))
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
        // (Re)programme le briefing quotidien selon les réglages persistés.
        await NotificationService.shared.scheduleDailyBriefing(
            enabled: settings.briefingEnabled,
            hour: settings.briefingHour
        )
    }

    /// Route un tap de notification vers sa destination (article précis ou écran Alertes).
    private func handle(_ destination: NotificationDestination) {
        switch destination {
        case .article(let id):
            vm.openDeepLink(articleID: id, context: modelContext)
            // Aligne la sidebar sur la nouvelle portée. Sans risque de course : `vm.selection`
            // est déjà `.all` (fixé de façon synchrone par `openDeepLink`), donc le garde-fou
            // sur `.onChange(of: feedSelection)` empêche `changeSelection` de rejouer et
            // d'écraser `selectedArticle`.
            feedSelection = .all
        case .alerts:
            vm.showingDigest = false
            if feedSelection == .alerts {
                // Déjà sur l'écran Alertes : valeur inchangée, `.onChange` ne se déclenche
                // pas — force explicitement un rechargement pour voir les nouveaux matches.
                Task { await vm.changeSelection(.alerts, context: modelContext, lang: settings.effectiveLang) }
            } else {
                feedSelection = .alerts
            }
        }
    }

    #if os(macOS)
    /// Rafraîchit périodiquement les flux tant que la fenêtre est ouverte (macOS n'a
    /// pas de `BGTaskScheduler` ; l'app tourne, donc une boucle légère suffit).
    private func runPeriodicRefresh() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1800)) // 30 min
            guard !Task.isCancelled else { break }
            await RefreshEngine.run(container: modelContext.container, notify: true)
            await vm.refresh(context: modelContext, lang: settings.effectiveLang)
        }
    }
    #endif
}
