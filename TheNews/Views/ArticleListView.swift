import SwiftUI

/// Sidebar : liste des articles de la rubrique, sectionnée par date, avec
/// recherche et bouton de rafraîchissement. Adaptée de `ItemListView` du template.
struct ArticleListView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Bindable var vm: FeedViewModel
    @Binding var selectedId: String?
    /// Personnalise le message d'état vide (titre, description) affiché quand `vm.articles`
    /// est vide — `nil` garde le message générique. Utilisé par `AlertsView` : le texte par
    /// défaut ("Rafraîchis pour récupérer les derniers articles") est trompeur quand 0 article
    /// ne correspond encore à des sujets de veille actifs (ce n'est pas un problème réseau).
    var emptyOverride: (title: String, description: String)? = nil

    var body: some View {
        @Bindable var settings = settings
        content
        .searchable(text: $vm.searchText, prompt: settings.t("search_placeholder"))
        .onSubmit(of: .search) {
            Task { await vm.smartSearch(lang: settings.effectiveLang) }
        }
        .task(id: vm.selection) {
            guard settings.smartAlertsEnabled else { return }
            await vm.refineAlertsIfNeeded(context: modelContext, lang: settings.effectiveLang)
        }
        .navigationTitle(vm.title(settings.t))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    selectedId = nil
                    Task {
                        await vm.generateDigest(
                            lang: settings.effectiveLang,
                            length: settings.digestLength,
                            format: settings.digestFormat,
                            tone: settings.digestTone,
                            count: settings.digestCount
                        )
                    }
                } label: {
                    Label(settings.t("digest"), systemImage: "sparkles")
                }
                .disabled(vm.filtered.isEmpty || vm.isGeneratingDigest)
                .help(settings.t("digest"))
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    vm.markAllRead(context: modelContext)
                } label: {
                    Label(settings.t("mark_all_read"), systemImage: "checkmark.circle")
                }
                .disabled(vm.articles.allSatisfy(\.isRead))
                .help(settings.t("mark_all_read"))
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await vm.refresh(context: modelContext, lang: settings.effectiveLang) }
                } label: {
                    if vm.isLoading {
                        ProgressView().scaleEffect(0.65)
                    } else {
                        Label(settings.t("refresh"), systemImage: "arrow.clockwise")
                    }
                }
                .disabled(vm.isLoading)
                .help(settings.t("refresh_help"))
            }
            ToolbarItem(placement: .automatic) {
                Picker(settings.t("display_mode_list"), selection: $settings.articleDisplayModeRaw) {
                    ForEach(ArticleDisplayMode.allCases) { mode in
                        Label(settings.t(mode.titleKey), systemImage: mode.icon)
                            .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
        .overlay {
            if vm.articles.isEmpty && !vm.isLoading {
                let (title, desc) = emptyOverride ?? (settings.t("no_items_title"), settings.t("no_items_desc"))
                ContentUnavailableView(title, systemImage: "newspaper", description: Text(desc))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch settings.articleDisplayMode {
        case .list:
            List(selection: $selectedId) {
                ForEach(vm.grouped, id: \.key) { group in
                    Section(settings.t(group.key)) {
                        ForEach(group.items) { article in
                            ArticleRowView(article: article)
                                .tag(article.id)
                        }
                    }
                }
            }
            #if os(macOS)
            .listStyle(.inset)
            #else
            .listStyle(.plain)
            #endif
        case .card:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(vm.grouped, id: \.key) { group in
                        Section {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 14)],
                                spacing: 14
                            ) {
                                ForEach(group.items) { article in
                                    ArticleCardView(article: article, isSelected: selectedId == article.id)
                                        .onTapGesture { handleCardTap(article) }
                                }
                            }
                        } header: {
                            Text(settings.t(group.key))
                                .font(.headline)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(14)
            }
        }
    }

    /// En mode carte, le tap n'a pas la même destination selon la plateforme : sur macOS,
    /// le mode carte masque le panneau de lecture (cf. `ContentView.splitView`), donc le tap
    /// ouvre l'article directement (comme les cartes du Briefing) ; sur iOS, le panneau de
    /// détail/pager existe toujours, donc le tap sélectionne l'article comme en mode liste.
    private func handleCardTap(_ article: Article) {
        #if os(macOS)
        openURL(article.link)
        article.isRead = true
        #else
        selectedId = article.id
        #endif
    }
}
