import SwiftUI
import SwiftData
import Combine

/// Écran racine tvOS — refonte « billboard » calquée sur l'app LG webOS :
/// un grand visuel plein cadre qui tourne en boucle sur les derniers titres
/// (hero), un bandeau des titres suivants en bas, fond sombre, accent bleu.
/// Les cartes du bandeau sont les éléments focusables de la télécommande :
/// les sélectionner ouvre le détail (qui pagine ensuite avec gauche/droite sur
/// l'ensemble du flux). Plus de menu latéral : comme sur la TV LG, tout le flux
/// abonné est fusionné et parcourable depuis le détail.
struct TVFeedView: View {
    let container: ModelContainer

    var body: some View {
        NavigationStack {
            TVBillboardView(container: container)
                .navigationDestination(for: TVArticleSelection.self) { selection in
                    TVArticleDetailView(selection: selection)
                }
        }
    }
}

/// Le billboard lui-même. Fusionne les articles des rubriques abonnées (triés
/// du plus récent au plus ancien, avec image), montre le premier en grand et
/// tourne toutes les 7 s, comme la version LG.
struct TVBillboardView: View {
    let container: ModelContainer

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeedSubscription.subscribedAt) private var subscriptions: [FeedSubscription]

    @State private var pool: [Article] = []
    @State private var index = 0
    @State private var now = Date()
    @State private var lastUpdated: Date?

    private static let heroCount = 15
    private static let stripCount = 4

    private let rotateTimer = Timer.publish(every: 7, on: .main, in: .common).autoconnect()
    private let clockTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var subscribedFeedIDs: [String] {
        let ids = Set(subscriptions.map(\.feedID))
        return Feed.catalog.map(\.id).filter { ids.contains($0) }
    }

    var body: some View {
        Group {
            if pool.isEmpty {
                ContentUnavailableView(
                    "Aucun article",
                    systemImage: "tray",
                    description: Text("Abonnez-vous à des rubriques depuis TheNews sur Mac ou iPhone — la synchronisation iCloud les affichera ici.")
                )
            } else {
                billboard
            }
        }
        .task { await load() }
        .onReceive(rotateTimer) { _ in
            guard pool.count > 1 else { return }
            withAnimation(.easeInOut(duration: 0.5)) { index = (index + 1) % pool.count }
        }
        .onReceive(clockTimer) { _ in now = Date() }
    }

    private var current: Article { pool[min(index, pool.count - 1)] }

    private var billboard: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 48)
                .padding(.bottom, 18)
            hero
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 48)
            strip
                .padding(.horizontal, 48)
                .padding(.vertical, 26)
        }
        .background(Color.black.ignoresSafeArea())
    }

    // Barre du haut : logo TheNews + heure + dernière mise à jour.
    private var topBar: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 0) {
                Text("The").foregroundStyle(.white)
                Text("News").foregroundStyle(.tint)
            }
            .font(.system(size: 40, weight: .heavy))
            Spacer()
            Text(now, format: .dateTime.hour().minute())
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
            if let lastUpdated {
                Text("· maj " + lastUpdated.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // Hero plein cadre, visuel + dégradé + texte, avec points de pagination.
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: current.imageURL) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(.secondary.opacity(0.2))
                }
            }

            LinearGradient(
                colors: [.black.opacity(0.92), .black.opacity(0.45), .clear],
                startPoint: .bottom, endPoint: .top
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    Text("À LA UNE · ").foregroundStyle(.white.opacity(0.9))
                    Text((current.feed?.source?.name ?? "").uppercased()).foregroundStyle(.tint)
                }
                .font(.system(size: 24, weight: .bold))
                Text(current.title)
                    .font(.system(size: 62, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if !current.summary.isEmpty {
                    Text(current.summary)
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                }
                Text(relative(current.publishedAt))
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(48)
            .frame(maxWidth: 1250, alignment: .leading)

            pageDots
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .id(current.id)
        .transition(.opacity)
    }

    private var pageDots: some View {
        HStack(spacing: 9) {
            ForEach(pool.indices, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(i == index ? 0.95 : 0.35))
                    .frame(width: 9, height: 9)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    // Bandeau des titres suivants : cartes focusables → ouvrent le détail.
    private var strip: some View {
        HStack(spacing: 18) {
            ForEach(1...Self.stripCount, id: \.self) { k in
                let i = (index + k) % pool.count
                let article = pool[i]
                NavigationLink(value: TVArticleSelection(articleIDs: pool.map(\.id), index: i)) {
                    TVStripCard(article: article)
                }
                .buttonStyle(.card)
            }
        }
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: AppLocale.identifier)
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: now)
    }

    private func load() async {
        reload()
        await TVRefreshEngine.run(container: container)
        reload()
        lastUpdated = Date()
    }

    private func reload() {
        let store = FeedStore(context: modelContext)
        let all = (try? store.articles(feedIDs: subscribedFeedIDs)) ?? []
        pool = Array(all.filter { $0.imageURL != nil }.prefix(Self.heroCount))
        if index >= pool.count { index = 0 }
    }
}

/// Carte compacte du bandeau : miniature 16:9 + source (bleu, capitales) + titre.
private struct TVStripCard: View {
    let article: Article

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: article.imageURL) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(16.0 / 9.0, contentMode: .fill)
                } else {
                    Rectangle().fill(.secondary.opacity(0.15))
                }
            }
            .frame(width: 200, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text((article.feed?.source?.name ?? "").uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.tint)
                Text(article.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
