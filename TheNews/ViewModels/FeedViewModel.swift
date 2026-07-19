import Foundation
import Observation
import SwiftData

/// Portée d'affichage de la liste d'articles : soit toutes les rubriques abonnées,
/// soit une rubrique précise.
enum FeedSelection: Hashable {
    case all
    case briefing          // « résumé du jour » : sélection condensée dédupliquée cross-source
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
    var searchText: String = "" {
        didSet { if oldValue != searchText { smartKeywords = nil } }
    }
    /// Mots-clés élargis par `SmartSearchEngine` à partir de `searchText` (recherche en langage
    /// naturel, déclenchée en soumettant le champ de recherche). `nil` = recherche par sous-chaîne
    /// classique sur `searchText`. Réinitialisé dès que `searchText` change (nouvelle frappe).
    var smartKeywords: [String]?
    var isLoading = false
    var selectedArticle: Article?
    var errorMessage: String?

    /// Synthèse IA de la liste courante — affichée dans la zone de détail
    /// (`ContentView`) à la place de l'article sélectionné, pas dans une
    /// fenêtre séparée. Sélectionner un article ailleurs referme la synthèse
    /// (cf. `select(_:)`).
    var digest: String?
    var isGeneratingDigest = false
    var showingDigest = false

    private let service = RSSService()

    /// Titre affiché en tête de la liste selon la portée courante.
    func title(_ t: (String) -> String) -> String {
        switch selection {
        case .all:            return t("all_feeds")
        case .briefing:       return t("briefing")
        case .alerts:         return t("alerts")
        case .favorites:      return t("favorites")
        case .feed(let id):   return Feed.byID(id)?.title ?? t("all_feeds")
        }
    }

    var filtered: [Article] {
        if let keywords = smartKeywords, !keywords.isEmpty {
            return articles.filter { article in
                keywords.contains {
                    article.title.localizedCaseInsensitiveContains($0)
                    || article.summary.localizedCaseInsensitiveContains($0)
                }
            }
        }
        guard !searchText.isEmpty else { return articles }
        return articles.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
            || $0.summary.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Étend `searchText` en mots-clés via Foundation Models (recherche en langage naturel),
    /// déclenché en soumettant le champ de recherche (touche Entrée) — la frappe normale continue
    /// d'utiliser la recherche par sous-chaîne classique dans `filtered`, sans changement.
    func smartSearch(lang: String) async {
        smartKeywords = await SmartSearchEngine.expand(searchText, lang: lang)
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

    /// Séquence de navigation du pager iOS selon le mode de swipe.
    /// En mode « non lu », ne garde que les articles non lus **plus** l'article
    /// courant (qui vient d'être marqué lu à l'ouverture) pour rester affichable :
    /// le swipe amène alors au prochain non lu.
    func pagerSequence(mode: ArticleSwipeMode) -> [Article] {
        switch mode {
        case .all:
            return orderedArticles
        case .unread:
            let currentID = selectedArticle?.id
            return orderedArticles.filter { !$0.isRead || $0.id == currentID }
        }
    }

    // MARK: - Chargement

    /// Premier chargement : recharge les flux perso, seed des abonnements par défaut,
    /// cache local, puis réseau.
    func load(context: ModelContext, lang: String = "fr") async {
        CustomFeedStore(context: context).reloadCatalog()
        try? SubscriptionStore(context: context).seedIfNeeded()
        try? FeedStore(context: context).pruneDuplicates()   // nettoie les doublons hérités de la sync
        reload(context: context)
        await refresh(context: context, lang: lang)
    }

    /// Change la rubrique affichée : recharge le cache immédiatement puis rafraîchit.
    func changeSelection(_ selection: FeedSelection, context: ModelContext, lang: String = "fr") async {
        self.selection = selection
        selectedArticle = nil
        reload(context: context)
        await refresh(context: context, lang: lang)
    }

    /// Rafraîchit les rubriques concernées par la portée courante (en parallèle). Un flux en échec
    /// n'empêche pas l'affichage des autres ; s'il y en a au moins un, `errorMessage` le signale
    /// (message non bloquant, écrasé au prochain refresh réussi) plutôt que de disparaître sans un
    /// mot comme avant. Lève seulement si **tous** les flux de la portée échouent.
    func refresh(context: ModelContext, lang: String = "fr") async {
        isLoading = true
        errorMessage = nil
        let feeds = feedsInScope(context: context)
        do {
            let result = try await fetchAll(feeds)
            let store = FeedStore(context: context)
            for (feedID, parsed) in result.succeeded {
                try store.ingest(parsed, feedID: feedID)
            }
            reload(context: context)
            WidgetPublisher.publish(context: context)
            if !result.failedFeedTitles.isEmpty {
                let prefix = Strings.table[lang]?["feeds_unreachable"]
                    ?? Strings.table["en"]?["feeds_unreachable"] ?? ""
                errorMessage = prefix + result.failedFeedTitles.joined(separator: ", ")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Interne

    private func feedsInScope(context: ModelContext) -> [Feed] {
        switch selection {
        case .all, .alerts, .briefing:
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

    /// Résultat de `fetchAll` : les rubriques rafraîchies avec succès, et les titres de celles en
    /// échec — pour pouvoir signaler un échec partiel à l'utilisateur (cf. `refresh`) sans perdre
    /// l'affichage des rubriques qui ont réussi.
    private struct FetchResult {
        let succeeded: [(String, [ParsedArticle])]
        let failedFeedTitles: [String]
    }

    /// Télécharge et parse plusieurs flux en parallèle. Un flux en échec n'empêche pas les autres
    /// d'être rafraîchis (son titre est renvoyé dans `failedFeedTitles`) ; lève seulement si tous
    /// échouent, auquel cas rien n'a pu être rafraîchi.
    private func fetchAll(_ feeds: [Feed]) async throws -> FetchResult {
        guard !feeds.isEmpty else { return FetchResult(succeeded: [], failedFeedTitles: []) }
        return try await withThrowingTaskGroup(of: (Feed, [ParsedArticle]?).self) { group in
            let service = self.service
            for feed in feeds {
                group.addTask {
                    (feed, try? await service.fetch(feed))
                }
            }
            var succeeded: [(String, [ParsedArticle])] = []
            var failedFeedTitles: [String] = []
            for try await (feed, parsed) in group {
                if let parsed { succeeded.append((feed.id, parsed)) }
                else { failedFeedTitles.append(feed.title) }
            }
            if succeeded.isEmpty && !feeds.isEmpty {
                throw RSSService.FeedError.empty
            }
            return FetchResult(succeeded: succeeded, failedFeedTitles: failedFeedTitles)
        }
    }

    /// Relit les articles à afficher depuis le stockage local selon la portée.
    private func reload(context: ModelContext) {
        let store = FeedStore(context: context)
        switch selection {
        case .all:
            let ids = (try? SubscriptionStore(context: context).subscribedFeedIDs()) ?? []
            articles = (try? store.articles(feedIDs: ids)) ?? []
        case .briefing:
            articles = BriefingEngine.today(context: context, limit: 13)
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

    /// 2ᵉ passe sémantique (Foundation Models) sur les sujets de veille, uniquement pour la portée
    /// `.alerts` et seulement si l'utilisateur l'a activée dans les réglages (`smartAlertsEnabled`).
    /// Complète `articles` avec les correspondances sémantiques sans redemander celles déjà
    /// matchées lexicalement (cf. `SemanticMatchingEngine.cache`). Borné aux articles récents (3 j)
    /// pour limiter le coût : cf. `PLAN.md` Phase F1.
    func refineAlertsIfNeeded(context: ModelContext, lang: String) async {
        guard case .alerts = selection, SemanticMatchingEngine.available else { return }
        let topics = activeTopics(context: context)
        guard !topics.isEmpty else { return }
        let store = FeedStore(context: context)
        let ids = (try? SubscriptionStore(context: context).subscribedFeedIDs()) ?? []
        let all = (try? store.articles(feedIDs: ids)) ?? []
        let matchedIDs = Set(articles.map(\.id))
        let cutoff = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? .distantPast
        let candidates = Array(
            all.filter { !matchedIDs.contains($0.id) && $0.publishedAt >= cutoff }.prefix(40)
        )
        guard !candidates.isEmpty else { return }
        let additional = await SemanticMatchingEngine.additionalMatches(
            among: candidates, topics: topics, lang: lang
        )
        guard !additional.isEmpty else { return }
        let extra = all.filter { additional.contains($0.id) }
        articles = (articles + extra).sorted { $0.publishedAt > $1.publishedAt }
    }

    func select(_ article: Article) {
        selectedArticle = article
        showingDigest = false
        if !article.isRead { article.isRead = true }
    }

    /// Ouvre un article ciblé par un deep-link (tap sur une notification), en garantissant
    /// qu'il figure dans `articles` — donc dans la séquence du pager iOS (`pagerSequence`,
    /// dérivée de `orderedArticles` → `articles`) — AVANT de le sélectionner. Sans cette
    /// garantie, un article absent de la portée affichée (ex. l'utilisateur était sur
    /// « Favoris ») laisse le pager iOS sans page correspondante : écran vide silencieux.
    /// Bascule sur `.all` (portée la plus large) via `reload(context:)` — synchrone —, pas
    /// `changeSelection(...)` (async, lancé en tâche depuis `ContentView`) : cette dernière
    /// réinitialiserait `selectedArticle` à `nil` juste après qu'on vienne de l'assigner.
    func openDeepLink(articleID: String, context: ModelContext) {
        selection = .all
        reload(context: context)
        if let article = articles.first(where: { $0.id == articleID }) {
            select(article)
            return
        }
        // Filet de sécurité : l'article existe (il a déclenché la notification) mais une
        // raison quelconque l'exclut de `.all` (ex. rubrique désabonnée entretemps) — on
        // l'ajoute quand même en tête pour que le pager ait une page à montrer.
        let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.id == articleID })
        guard let article = try? context.fetch(descriptor).first else { return }
        articles.insert(article, at: 0)
        select(article)
    }

    /// Génère la synthèse IA de la liste courante et bascule la zone de détail
    /// dessus (désélectionne l'article affiché, s'il y en avait un).
    func generateDigest(
        lang: String, length: DigestLength, format: DigestFormat, tone: DigestTone, count: Int
    ) async {
        selectedArticle = nil
        showingDigest = true
        isGeneratingDigest = true
        digest = nil
        let items = filtered.map { (title: $0.title, summary: $0.summary) }
        digest = await ArticleSummarizer.digest(
            articles: items, lang: lang, length: length, format: format, tone: tone, count: count
        )
        isGeneratingDigest = false
    }
}
