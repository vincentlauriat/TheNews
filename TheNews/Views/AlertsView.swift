import SwiftUI
import SwiftData

/// Écran « Alertes » fusionné : gestion des sujets de veille (créer/modifier/supprimer, via
/// `WatchTopicEditor` réutilisé tel quel) ET liste des articles qui matchent, au même endroit —
/// remplace l'ancien renvoi vers « Gérer les rubriques » pour ce domaine. Compose avec
/// `ArticleListView` (inchangée) plutôt que de dupliquer sa liste : ça préserve gratuitement la
/// recherche, la recherche intelligente, la génération de digest IA, la bascule liste/carte et
/// le raffinement sémantique (`refineAlertsIfNeeded`), tous spécifiques à `.alerts`.
struct AlertsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Bindable var vm: FeedViewModel
    @Binding var selectedId: String?

    @Query(sort: \WatchTopic.createdAt) private var topics: [WatchTopic]

    @State private var editingTopic: WatchTopic?
    @State private var creatingTopic = false

    var body: some View {
        VStack(spacing: 0) {
            topicsHeader
            Divider()
            if topics.isEmpty {
                ContentUnavailableView(
                    settings.t("no_topics"),
                    systemImage: "bell.badge",
                    description: Text(settings.t("watch_topics_footer"))
                )
                Spacer()
            } else {
                ArticleListView(
                    vm: vm,
                    selectedId: $selectedId,
                    emptyOverride: (settings.t("alerts_no_matches_title"), settings.t("alerts_no_matches_desc"))
                )
            }
        }
        .navigationTitle(settings.t("alerts"))
        .sheet(isPresented: $creatingTopic) {
            NavigationStack { WatchTopicEditor(topic: nil).environment(settings) }
        }
        .sheet(item: $editingTopic) { topic in
            NavigationStack { WatchTopicEditor(topic: topic).environment(settings) }
        }
    }

    private var topicsHeader: some View {
        FlowLayout(spacing: 8) {
            ForEach(topics) { topic in topicChip(topic) }
            Button {
                creatingTopic = true
            } label: {
                Label(settings.t("topic_add"), systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func topicChip(_ topic: WatchTopic) -> some View {
        HStack(spacing: 4) {
            if topic.notify {
                Image(systemName: "bell.fill").font(.caption2)
            }
            Text(topic.label)
            Button {
                deleteTopic(topic)
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(settings.t("topic_delete"))
            .accessibilityValue(topic.label)
        }
        // Reprend le signal visuel du toggle `isEnabled` de l'ancien `WatchSettingsView`.
        .opacity(topic.isEnabled ? 1 : 0.5)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
        .contentShape(Capsule())
        .onTapGesture { editingTopic = topic }
    }

    private func deleteTopic(_ topic: WatchTopic) {
        modelContext.delete(topic)
        try? modelContext.save()
    }
}
