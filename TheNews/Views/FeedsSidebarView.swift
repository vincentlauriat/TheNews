import SwiftUI
import SwiftData

/// Première colonne : « Tous » + les rubriques abonnées, avec accès à la gestion
/// des abonnements. La sélection pilote la liste d'articles (2ᵉ colonne).
struct FeedsSidebarView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \FeedSubscription.subscribedAt) private var subscriptions: [FeedSubscription]
    @Query private var topics: [WatchTopic]
    @Query(filter: #Predicate<Article> { !$0.isRead }) private var unread: [Article]
    @Binding var selection: FeedSelection?
    @Binding var showingManage: Bool

    /// Rubriques abonnées groupées par source (un groupe par journal), pour une
    /// sidebar multi-source lisible. Ne garde que les sources ayant au moins un abonnement.
    private var subscribedBySource: [(source: Source, feeds: [Feed])] {
        let ids = Set(subscriptions.map(\.feedID))
        return Feed.bySource
            .map { (source: $0.source, feeds: $0.feeds.filter { ids.contains($0.id) }) }
            .filter { !$0.feeds.isEmpty }
    }

    /// Total des rubriques abonnées, toutes sources confondues.
    private var hasSubscriptions: Bool { subscriptions.contains { Feed.byID($0.feedID) != nil } }

    /// Nombre d'articles non lus correspondant à un sujet de veille (parmi les rubriques suivies).
    private var alertsUnreadCount: Int {
        let active = topics.filter(\.isEnabled)
        guard !active.isEmpty else { return 0 }
        let subs = Set(subscriptions.map(\.feedID))
        return unread.filter { subs.contains($0.feedID) && MatchingEngine.isMatch($0, topics: active) }.count
    }

    var body: some View {
        List(selection: $selection) {
            Section {
                Label(settings.t("briefing"), systemImage: "sun.max")
                    .tag(FeedSelection.briefing)

                Label(settings.t("all_feeds"), systemImage: "square.stack.3d.up")
                    .tag(FeedSelection.all)

                Label {
                    HStack {
                        Text(settings.t("alerts"))
                        Spacer()
                        if alertsUnreadCount > 0 {
                            Text("\(alertsUnreadCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.red))
                        }
                    }
                } icon: {
                    Image(systemName: "bell.badge")
                }
                .tag(FeedSelection.alerts)

                Label(settings.t("favorites"), systemImage: "star")
                    .tag(FeedSelection.favorites)
            }

            ForEach(subscribedBySource, id: \.source.id) { group in
                Section(group.source.name) {
                    ForEach(group.feeds) { feed in
                        Label(feed.title, systemImage: feed.symbol)
                            .tag(FeedSelection.feed(feed.id))
                    }
                }
            }

            if !hasSubscriptions {
                Section(settings.t("sections")) {
                    Text(settings.t("no_subscriptions"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(settings.t("app_name"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showingManage = true
                } label: {
                    Label(settings.t("manage_sections"), systemImage: "slider.horizontal.3")
                }
                .help(settings.t("manage_sections"))
            }
        }
    }
}
