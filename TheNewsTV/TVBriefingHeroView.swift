import SwiftUI
import SwiftData

/// Bandeau « à la une » en tête de l'écran d'accueil : montre le Briefing du
/// jour sous forme de grand visuel, un article à la fois, et tourne en boucle
/// toutes les 5 secondes sur l'ensemble des articles (`BriefingEngine.today`).
/// Sélectionner l'article ouvre son détail, à l'index affiché au moment de la
/// sélection — la rotation continue en tâche de fond via `.task`, qui se
/// relance naturellement à chaque retour sur l'écran d'accueil.
struct TVBriefingHeroView: View {
    let articles: [Article]

    @State private var index = 0

    private var current: Article { articles[index] }

    var body: some View {
        NavigationLink(value: TVArticleSelection(articleIDs: articles.map(\.id), index: index)) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: current.imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(.secondary.opacity(0.2))
                    }
                }

                LinearGradient(
                    colors: [.black.opacity(0.85), .black.opacity(0.25), .clear],
                    startPoint: .bottom, endPoint: .top
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("À la une · \((current.feed?.source?.name ?? "").uppercased())")
                        .font(.caption).bold()
                        .foregroundStyle(.white.opacity(0.85))
                    Text(current.title)
                        .font(.largeTitle).bold()
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if articles.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(articles.indices, id: \.self) { i in
                                Circle()
                                    .fill(.white.opacity(i == index ? 0.95 : 0.35))
                                    .frame(width: 7, height: 7)
                            }
                        }
                    }
                }
                .padding(32)
            }
            .id(current.id)
            .transition(.opacity)
            .frame(height: 480)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.card)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .task { await rotate() }
    }

    private func rotate() async {
        guard articles.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                index = (index + 1) % articles.count
            }
        }
    }
}
