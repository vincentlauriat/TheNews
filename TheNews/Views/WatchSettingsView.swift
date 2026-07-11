import SwiftUI
import SwiftData

/// Réglages de veille : abonnements aux rubriques (Le Monde + Les Echos) + sujets de veille
/// (mots-clés) qui alimentent la section « Alertes » et les notifications.
struct WatchSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query private var subscriptions: [FeedSubscription]
    @Query(sort: \WatchTopic.createdAt) private var topics: [WatchTopic]
    @Query(sort: \CustomFeed.createdAt) private var customFeeds: [CustomFeed]

    @State private var editingTopic: WatchTopic?
    @State private var creatingTopic = false
    @State private var addingFeed = false

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
            // MARK: Sujets de veille
            Section {
                if topics.isEmpty {
                    Text(settings.t("no_topics"))
                        .foregroundStyle(.secondary)
                }
                ForEach(topics) { topic in
                    topicRow(topic)
                }
                .onDelete(perform: deleteTopics)

                Button {
                    creatingTopic = true
                } label: {
                    Label(settings.t("topic_add"), systemImage: "plus.circle")
                }
            } header: {
                Text(settings.t("watch_topics"))
            } footer: {
                Text(settings.t("watch_topics_footer"))
            }

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
                    }
                }
                .onDelete(perform: deleteFeeds)

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
        .sheet(isPresented: $creatingTopic) {
            NavigationStack { WatchTopicEditor(topic: nil).environment(settings) }
        }
        .sheet(item: $editingTopic) { topic in
            NavigationStack { WatchTopicEditor(topic: topic).environment(settings) }
        }
        .sheet(isPresented: $addingFeed) {
            NavigationStack { AddCustomFeedView().environment(settings) }
        }
    }

    private func deleteFeeds(_ offsets: IndexSet) {
        let store = CustomFeedStore(context: modelContext)
        for index in offsets { try? store.remove(customFeeds[index]) }
    }

    @ViewBuilder
    private func topicRow(_ topic: WatchTopic) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(topic.label)
                    .fontWeight(.medium)
                Text(topic.keywordsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if topic.notify {
                Image(systemName: "bell.fill").font(.caption).foregroundStyle(.secondary)
            }
            Toggle("", isOn: enabledBinding(for: topic))
                .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture { editingTopic = topic }
    }

    // MARK: - Bindings & actions

    private func binding(for feed: Feed) -> Binding<Bool> {
        Binding(
            get: { subscribedIDs.contains(feed.id) },
            set: { _ in try? SubscriptionStore(context: modelContext).toggle(feed.id) }
        )
    }

    private func enabledBinding(for topic: WatchTopic) -> Binding<Bool> {
        Binding(
            get: { topic.isEnabled },
            set: { topic.isEnabled = $0; try? modelContext.save() }
        )
    }

    private func deleteTopics(_ offsets: IndexSet) {
        for index in offsets { modelContext.delete(topics[index]) }
        try? modelContext.save()
    }
}
