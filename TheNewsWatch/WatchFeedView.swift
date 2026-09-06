import SwiftUI

/// Un article réduit pour l'affichage montre.
struct WatchArticle: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let source: String
    let link: URL
    let imageURL: URL?
    let publishedAt: Date

    private var deduplicationKey: String {
        ParsedArticle.canonicalLink(from: link) ?? "id:\(id)"
    }

    static func deduplicated(_ articles: [WatchArticle]) -> [WatchArticle] {
        var seen = Set<String>()
        return articles.filter { seen.insert($0.deduplicationKey).inserted }
    }
}

/// Vue rapide watchOS : télécharge en direct les gros titres des flux configurés
/// depuis l'iPhone et les affiche, triés du plus récent au plus ancien.
struct WatchFeedView: View {
    @State private var articles: [WatchArticle] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var pendingOpenURL: URL?

    /// Flux affichés sur la montre, configurés depuis l'iPhone et repliés sur les unes par défaut.
    private var feeds: [Feed] {
        WatchFeedConfiguration.load().compactMap(Feed.byID)
    }

    var body: some View {
        NavigationStack {
            List {
                if loading && articles.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Chargement...").foregroundStyle(.secondary)
                    }
                } else if articles.isEmpty {
                    if let loadError {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(loadError)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button("Reessayer") {
                                Task { await load() }
                            }
                        }
                    } else {
                        Text("Aucun article").foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(articles) { article in
                        NavigationLink(value: article) {
                            WatchArticleRow(article: article)
                        }
                        .simultaneousGesture(
                            LongPressGesture().onEnded { _ in
                                pendingOpenURL = article.link
                            }
                        )
                    }
                }
            }
            .navigationTitle("TheNews")
            .navigationDestination(for: WatchArticle.self) { article in
                WatchArticlePagerView(articles: articles, initialArticle: article)
            }
        }
        .task { await load() }
        .task {
            for await _ in NotificationCenter.default.notifications(named: WatchFeedConfiguration.didChangeNotification) {
                await load()
            }
        }
        .refreshable { await load() }
        .confirmationDialog(
            "Article",
            isPresented: Binding(
                get: { pendingOpenURL != nil },
                set: { if !$0 { pendingOpenURL = nil } }
            ),
            titleVisibility: .hidden
        ) {
            Button("Ouvrir sur iPhone") {
                if let pendingOpenURL {
                    WatchFeedSync.shared.openOnPhone(pendingOpenURL)
                }
                pendingOpenURL = nil
            }
        }
    }

    private func load() async {
        loading = true
        loadError = nil

        let service = RSSService()
        let scoped = feeds
        var collected: [WatchArticle] = []
        var failedFeedCount = 0

        await withTaskGroup(of: ([WatchArticle], Bool).self) { group in
            for feed in scoped {
                group.addTask {
                    do {
                        let parsed = try await service.fetch(feed)
                        let source = feed.source?.name ?? "TheNews"
                        let articles = parsed.map {
                            WatchArticle(
                                id: $0.id,
                                title: $0.title,
                                summary: $0.summary,
                                source: source,
                                link: $0.link,
                                imageURL: $0.imageURL,
                                publishedAt: $0.publishedAt
                            )
                        }
                        return (articles, false)
                    } catch {
                        return ([], true)
                    }
                }
            }
            for await (batch, failed) in group {
                collected += batch
                if failed { failedFeedCount += 1 }
            }
        }

        let sorted = collected.sorted { $0.publishedAt > $1.publishedAt }
        articles = Array(WatchArticle.deduplicated(sorted).prefix(25))
        if articles.isEmpty && failedFeedCount > 0 {
            loadError = "Impossible de charger les flux."
        }
        loading = false
    }
}

private struct WatchArticleRow: View {
    let article: WatchArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(article.source.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tint)
            Text(article.title)
                .font(.footnote)
                .lineLimit(4)
        }
    }
}

private struct WatchArticlePagerView: View {
    let articles: [WatchArticle]
    @State private var selectedID: String

    init(articles: [WatchArticle], initialArticle: WatchArticle) {
        self.articles = articles
        _selectedID = State(initialValue: initialArticle.id)
    }

    var body: some View {
        TabView(selection: $selectedID) {
            ForEach(articles) { article in
                WatchArticleDetailPage(article: article)
                    .tag(article.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .navigationTitle("Article")
    }
}

private struct WatchArticleDetailPage: View {
    let article: WatchArticle
    @State private var showingOpenOnPhone = false

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - 28, 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let imageURL = article.imageURL {
                        AsyncImage(url: imageURL) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Rectangle()
                                    .fill(.secondary.opacity(0.12))
                            } else {
                                ZStack {
                                    Rectangle()
                                        .fill(.secondary.opacity(0.12))
                                    ProgressView()
                                }
                            }
                        }
                        .frame(width: contentWidth, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(article.source.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tint)
                        Text(article.title)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(article.publishedAt, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if !article.summary.isEmpty {
                            Text(article.summary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.top, 4)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onLongPressGesture {
            showingOpenOnPhone = true
        }
        .confirmationDialog("Article", isPresented: $showingOpenOnPhone, titleVisibility: .hidden) {
            Button("Ouvrir sur iPhone") {
                WatchFeedSync.shared.openOnPhone(article.link)
            }
        }
    }
}
