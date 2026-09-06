import SwiftUI
import SwiftData

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

    #if os(macOS)
    /// Curseur clavier propre au mode carte. Volontairement distinct de `selectedId` :
    /// ce dernier déclenche `vm.select` via `ContentView.onChange`, qui marque l'article
    /// lu — naviguer à la flèche marquerait alors toute la grille comme lue au passage.
    /// Le mode carte macOS n'ayant pas de panneau de lecture (cf. `ContentView.splitView`),
    /// la sélection clavier n'y est qu'un curseur ; Entrée ouvre l'article.
    @State private var keyboardSelectedId: String?
    @FocusState private var listFocused: Bool
    @FocusState private var cardFocused: Bool
    #endif

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
        case .list: listContent
        case .card: cardContent
        }
    }

    /// Mode liste.
    ///
    /// Le `ScrollViewReader` n'enveloppe que le chemin macOS : il ne sert qu'à
    /// `proxy.scrollTo`, appelé par la navigation clavier. L'arbre de vues iOS reste
    /// donc exactement ce qu'il était — c'est lui qui alimente `ArticlePagerView` via
    /// `selectedId`, et son identité n'a pas à bouger pour une fonction macOS.
    @ViewBuilder
    private var listContent: some View {
        #if os(macOS)
        ScrollViewReader { proxy in
            articleList
                .listStyle(.inset)
                .focused($listFocused)
                .onMoveCommand { moveSelection($0, proxy: proxy) }
                // Sans ça, les flèches restent inertes tant qu'on n'a pas cliqué une
                // ligne : la `List` n'est pas premier répondant au premier affichage.
                .onAppear { listFocused = true }
        }
        #else
        articleList.listStyle(.plain)
        #endif
    }

    private var articleList: some View {
        List(selection: $selectedId) {
            ForEach(vm.grouped, id: \.key) { group in
                Section(settings.t(group.key)) {
                    ForEach(group.items) { article in
                        ArticleRowView(article: article)
                            .tag(article.id)
                            .id(article.id)
                    }
                }
            }
        }
    }

    /// Mode carte. Une `LazyVGrid` n'a aucune navigation clavier native : tout est
    /// explicite côté macOS (focus, déplacement du curseur, défilement, ouverture).
    @ViewBuilder
    private var cardContent: some View {
        #if os(macOS)
        ScrollViewReader { proxy in
            cardGrid
                .focusable()
                .focused($cardFocused)
                .onMoveCommand { moveSelection($0, proxy: proxy) }
                .onKeyPress(.return) { openKeyboardSelection() }
                .onAppear { cardFocused = true }
        }
        #else
        cardGrid
        #endif
    }

    private var cardGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(vm.grouped, id: \.key) { group in
                    Section {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 14)],
                            spacing: 14
                        ) {
                            ForEach(group.items) { article in
                                ArticleCardView(article: article, isSelected: isCardSelected(article))
                                    .id(article.id)
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

    private func isCardSelected(_ article: Article) -> Bool {
        #if os(macOS)
        return selectedId == article.id || keyboardSelectedId == article.id
        #else
        return selectedId == article.id
        #endif
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

    #if os(macOS)
    /// Déplace d'un article dans l'ordre d'affichage (`vm.orderedArticles`, groupes
    /// aplatis). En grille, haut/bas parcourent cet ordre de lecture plutôt qu'une
    /// ligne entière : le nombre de colonnes dépend de la largeur (`.adaptive`) et
    /// n'est pas connu ici.
    private func moveSelection(_ direction: MoveCommandDirection, proxy: ScrollViewProxy) {
        let items = vm.orderedArticles
        guard !items.isEmpty else { return }

        let isCard = settings.articleDisplayMode == .card
        let currentID = isCard ? keyboardSelectedId : selectedId
        let currentIndex = currentID.flatMap { id in
            items.firstIndex { $0.id == id }
        }
        let nextIndex: Int
        switch direction {
        case .down:
            nextIndex = min((currentIndex ?? -1) + 1, items.count - 1)
        case .up:
            nextIndex = max((currentIndex ?? items.count) - 1, 0)
        default:
            return
        }

        let article = items[nextIndex]
        if isCard {
            keyboardSelectedId = article.id
        } else {
            selectedId = article.id
            vm.select(article)
        }
        proxy.scrollTo(article.id, anchor: .center)
    }

    /// Entrée ouvre l'article sous le curseur clavier, avec la même destination que
    /// le clic sur une carte (`handleCardTap`). Sans ça, la navigation clavier en
    /// mode carte ne mènerait nulle part : il n'y a pas de panneau de lecture.
    private func openKeyboardSelection() -> KeyPress.Result {
        guard let id = keyboardSelectedId,
              let article = vm.orderedArticles.first(where: { $0.id == id })
        else { return .ignored }
        handleCardTap(article)
        return .handled
    }
    #endif
}
