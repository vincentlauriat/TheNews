import Foundation
import Observation
import SwiftData

/// Portée d'affichage de la liste d'articles : soit toutes les rubriques abonnées,
/// soit une rubrique précise.
enum FeedSelection: Hashable {
    case all
    case alerts            // articles correspondant aux sujets de veille
    case favorites         // articles mis en favori
    case feed(String)      // Feed.id
}

/// Pilote l'affichage des articles selon la rubrique sélectionnée : lit le cache
/// local (affichage instantané), rafraîchit depuis le réseau (une ou plusieurs
/// rubriques en parallèle), gère recherche, sélection et regroupement par date.
@Observable
@MainActor
final class FeedViewModel {
    var selection: FeedSelection = .all
    var articles: [Article] = []
    var searchText: String = ""
    var isLoading = false
    var selectedArticle: Article?
    var errorMessage: String?

    private let service = RSSService()

    /// Titre affiché en tête de la liste selon la portée courante.
    func title(_ t: (String) -> String) -> String {
        switch selection {
        case .all:            return t("all_feeds")
        case .alerts:         return t("alerts")
        case .favorites:      return t("favorites")
        case .feed(let id):   return Feed.byID(id)?.title ?? t("all_feeds")
        }
    }

    var filtered: [Article] {
        guard !searchText.isEmpty else { return articles }
        return articles.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
            || $0.summary.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Regroupe par ancienneté (aujourd'hui / cette semaine / plus tôt), du plus récent au plus ancien.
    var grouped: [(key: String, items: [Article])] {
        let cal = Calendar.current
        let now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!
        var today: [Article] = [], week: [Article] = [], older: [Article] = []
        for a in filtered {
            if cal.isDateInToday(a.publishedAt) { today.append(a) }
            else if a.publishedAt >= weekAgo { week.append(a) }
            else { older.append(a) }
        }
        let byDateDescending: (Article, Article) -> Bool = { $0.publishedAt > $1.publishedAt }
        today.sort(by: byDateDescending)
        week.sort(by: byDateDescending)
        older.sort(by: byDateDescending)
        return [("group_today", today), ("group_week", week), ("group_earlier", older)]
            .filter { !$0.items.isEmpty }
    }

    /// Articles dans l'ordre exact d'affichage de la liste (groupes aplatis).
    /// Sert de séquence de navigation au pager iOS (swipe entre articles).
    var orderedArticles: [Article] { grouped.flatMap(\.items) }

    // MARK: - Chargement

    /// Premier chargement : recharge les flux perso, seed des abonnements par défaut,
    /// cache local, puis réseau.
    func load(context: ModelContext) async {
        CustomFeedStore(context: context).reloadCatalog()
        try? SubscriptionStore(context: context).seedIfNeeded()
        reload(context: context)
        await refresh(context: context)
    }

    /// Change la rubrique affichée : recharge le cache immédiatement puis rafraîchit.
    func changeSelection(_ selection: FeedSelection, context: ModelContext) async {
        self.selection = selection
        selectedArticle = nil
        reload(context: context)
        await refresh(context: context)
    }

    /// Rafraîchit les rubriques concernées par la portée courante (en parallèle).
    func refresh(context: ModelContext) async {
        isLoading = true
        errorMessage = nil
        let feeds = feedsInScope(context: context)
        do {
            let results = try await fetchAll(feeds)
            let store = FeedStore(context: context)
            for (feedID, parsed) in results {
                try store.ingest(parsed, feedID: feedID)
            }
            reload(context: context)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Interne

    private func feedsInScope(context: ModelContext) -> [Feed] {
        switch selection {
        case .all, .alerts:
            return (try? SubscriptionStore(context: context).subscribedFeeds()) ?? []
        case .favorites:
            return []   // les favoris sont déjà stockés : pas de fetch réseau
        case .feed(let id):
            return Feed.byID(id).map { [$0] } ?? []
        }
    }

    /// Marque comme lus tous les articles actuellement affichés.
    func markAllRead(context: ModelContext) {
        for article in articles where !article.isRead { article.isRead = true }
        try? context.save()
    }

    private func activeTopics(context: ModelContext) -> [WatchTopic] {
        let descriptor = FetchDescriptor<WatchTopic>(predicate: #Predicate { $0.isEnabled })
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Télécharge et parse plusieurs flux en parallèle. Ignore silencieusement les
    /// rubriques en erreur pour ne pas bloquer l'ensemble ; lève seulement si toutes échouent.
    private func fetchAll(_ feeds: [Feed]) async throws -> [(String, [ParsedArticle])] {
        guard !feeds.isEmpty else { return [] }
        return try await withThrowingTaskGroup(of: (String, [ParsedArticle])?.self) { group in
            let service = self.service
            for feed in feeds {
                group.addTask {
                    guard let parsed = try? await service.fetch(feed) else { return nil }
                    return (feed.id, parsed)
                }
            }
            var out: [(String, [ParsedArticle])] = []
            for try await result in group {
                if let result { out.append(result) }
            }
            if out.isEmpty && !feeds.isEmpty {
                throw RSSService.FeedError.empty
            }
            return out
        }
    }

    /// Relit les articles à afficher depuis le stockage local selon la portée.
    private func reload(context: ModelContext) {
        let store = FeedStore(context: context)
        switch selection {
        case .all:
            let ids = (try? SubscriptionStore(context: context).subscribedFeedIDs()) ?? []
            articles = (try? store.articles(feedIDs: ids)) ?? []
        case .alerts:
            let ids = (try? SubscriptionStore(context: context).subscribedFeedIDs()) ?? []
            let all = (try? store.articles(feedIDs: ids)) ?? []
            let topics = activeTopics(context: context)
            articles = topics.isEmpty ? [] : all.filter { MatchingEngine.isMatch($0, topics: topics) }
        case .favorites:
            articles = (try? store.favorites()) ?? []
        case .feed(let id):
            articles = (try? store.articles(feedID: id)) ?? []
        }
    }

    func select(_ article: Article) {
        selectedArticle = article
        if !article.isRead { article.isRead = true }
    }
}
