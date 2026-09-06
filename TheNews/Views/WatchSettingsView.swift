import SwiftUI
import SwiftData

/// Réglages de veille : abonnements aux rubriques (Le Monde + Les Echos) + flux RSS perso.
/// La gestion des sujets de veille (mots-clés) vit désormais dans `AlertsView`, directement
/// sur l'écran « Alertes » qu'elle alimente.
struct WatchSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query private var subscriptions: [FeedSubscription]
    @Query(sort: \CustomFeed.createdAt) private var customFeeds: [CustomFeed]

    @State private var addingFeed = false
    @State private var editingFeed: CustomFeed?
    /// Flux dont la suppression attend confirmation. `CustomFeedStore.remove` efface aussi
    /// les articles en cache du flux — **favoris compris**, contrairement à `FeedStore.prune`
    /// qui les épargne. La perte n'étant pas rattrapable, elle s'annonce avant.
    @State private var feedPendingDeletion: CustomFeed?
    @State private var watchFeedIDs = WatchFeedConfiguration.load()

    private var subscribedIDs: Set<String> { Set(subscriptions.map(\.feedID)) }

    /// Sources intégrées uniquement (exclut la pseudo-source « Mes flux ») : les flux perso ont
    /// déjà leur propre section dédiée plus bas, qui gère tout leur cycle de vie (ajout = abonnement
    /// auto, suppression = désabonnement auto, cf. `CustomFeedStore`). Les inclure aussi ici via
    /// `Feed.bySource` affichait « Mes flux » deux fois, et le toggle générique permettait de
    /// désabonner un flux perso sans le supprimer — l'y laissant orphelin (aucune UI pour le
    /// réabonner sans le recréer).
    private var builtInGroups: [(source: Source, feeds: [Feed])] {
        Feed.bySource.filter { $0.source.id != Source.custom.id }
    }

    var body: some View {
        List {
            #if os(iOS)
            Section {
                ForEach(watchFeedGroups, id: \.source.id) { group in
                    DisclosureGroup(group.source.name) {
                        ForEach(group.feeds) { feed in
                            Toggle(isOn: watchFeedBinding(for: feed)) {
                                Label(feed.title, systemImage: feed.symbol)
                            }
                        }
                    }
                }
            } header: {
                Text(settings.t("watch_app_section"))
            } footer: {
                Text(settings.t("watch_app_footer"))
            }
            .onAppear {
                WatchFeedSync.shared.activate()
                watchFeedIDs = WatchFeedSync.shared.selectedFeedIDs()
            }
            #endif

            // MARK: Rubriques — une section par source intégrée (multi-journaux)
            ForEach(Array(builtInGroups.enumerated()), id: \.element.source.id) { index, group in
                Section {
                    ForEach(group.feeds) { feed in
                        Toggle(isOn: binding(for: feed)) {
                            Label(feed.title, systemImage: feed.symbol)
                        }
                    }
                } header: {
                    Text(group.source.name)
                } footer: {
                    // Le rappel « ces rubriques alimentent la veille » ne s'affiche
                    // qu'une fois, sous la dernière source.
                    if index == builtInGroups.count - 1 {
                        Text(settings.t("sections_footer"))
                    }
                }
            }

            // MARK: Mes flux — sources RSS personnalisées
            Section {
                if customFeeds.isEmpty {
                    Text(settings.t("no_custom_feeds"))
                        .foregroundStyle(.secondary)
                }
                ForEach(customFeeds) { feed in
                    HStack {
                        Label(feed.title, systemImage: feed.symbol)
                        Spacer()
                        Text(feed.urlString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        #if os(macOS)
                        // Boutons explicites : sur macOS le balayage n'existe pas et
                        // `onDelete` n'a pas de geste associé — modifier et supprimer
                        // étaient donc inaccessibles. Sur iOS, le balayage reste la voie
                        // idiomatique et ces boutons alourdiraient la ligne.
                        Button {
                            editingFeed = feed
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .help(settings.t("feed_edit"))

                        Button {
                            feedPendingDeletion = feed
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help(settings.t("delete"))
                        #endif
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingFeed = feed }
                    .swipeActions {
                        Button(settings.t("feed_edit")) {
                            editingFeed = feed
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            feedPendingDeletion = feed
                        } label: {
                            Text(settings.t("delete"))
                        }
                    }
                }
                .onDelete(perform: confirmDeletion)

                Button {
                    addingFeed = true
                } label: {
                    Label(settings.t("feed_add"), systemImage: "plus.circle")
                }
            } header: {
                Text(settings.t("my_feeds"))
            } footer: {
                Text(settings.t("my_feeds_footer"))
            }
        }
        .navigationTitle(settings.t("manage_sections"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $addingFeed) {
            NavigationStack { AddCustomFeedView().environment(settings) }
        }
        .sheet(item: $editingFeed) { feed in
            NavigationStack { AddCustomFeedView(editingFeed: feed).environment(settings) }
        }
        .confirmationDialog(
            settings.t("feed_delete_confirm_title"),
            isPresented: Binding(
                get: { feedPendingDeletion != nil },
                set: { if !$0 { feedPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(settings.t("delete"), role: .destructive) {
                if let feed = feedPendingDeletion { deleteFeed(feed) }
                feedPendingDeletion = nil
            }
            Button(settings.t("cancel"), role: .cancel) { feedPendingDeletion = nil }
        } message: {
            Text(settings.t("feed_delete_confirm_body"))
        }
    }

    private func deleteFeed(_ feed: CustomFeed) {
        try? CustomFeedStore(context: modelContext).remove(feed)
    }

    /// Le balayage iOS passe aussi par la confirmation : la suppression efface des favoris.
    private func confirmDeletion(_ offsets: IndexSet) {
        guard let index = offsets.first else { return }
        feedPendingDeletion = customFeeds[index]
    }

    private func deleteFeeds(_ offsets: IndexSet) {
        let store = CustomFeedStore(context: modelContext)
        for index in offsets { try? store.remove(customFeeds[index]) }
    }

    // MARK: - Bindings & actions

    #if os(iOS)
    private var watchFeedGroups: [(source: Source, feeds: [Feed])] {
        [
            (Source.leMonde, Feed.leMondeCatalog),
            (Source.lesEchos, Feed.lesEchosCatalog),
            (Source.lopinion, Feed.lopinionCatalog),
            (Source.calipia, Feed.calipiaCatalog)
        ]
    }

    private func watchFeedBinding(for feed: Feed) -> Binding<Bool> {
        Binding(
            get: { watchFeedIDs.contains(feed.id) },
            set: { isSelected in
                var selected = watchFeedIDs
                if isSelected {
                    selected.append(feed.id)
                } else {
                    guard selected.count > 1 else { return }
                    selected.removeAll { $0 == feed.id }
                }
                watchFeedIDs = WatchFeedConfiguration.sanitizedFeedIDs(selected)
                WatchFeedSync.shared.updateSelection(watchFeedIDs)
            }
        )
    }
    #endif

    private func binding(for feed: Feed) -> Binding<Bool> {
        Binding(
            get: { subscribedIDs.contains(feed.id) },
            set: { _ in _ = try? SubscriptionStore(context: modelContext).toggle(feed.id) }
        )
    }
}
