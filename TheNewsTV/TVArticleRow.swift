import SwiftUI

/// Ligne d'article avec miniature — partagée par la liste de rubrique, l'agrégat
/// « Tous les articles » et le « Briefing ».
struct TVArticleRow: View {
    let article: TVArticle

    @Environment(TVReadStore.self) private var readStore

    private var isRead: Bool { readStore.isRead(article.id) }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            AsyncImage(url: article.imageURL) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(16.0 / 9.0, contentMode: .fill)
                } else {
                    Rectangle().fill(.secondary.opacity(0.15))
                }
            }
            .frame(width: 240, height: 135)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(article.sourceName.uppercased())
                    .font(.caption).bold()
                    .foregroundStyle(.tint)
                HStack(alignment: .top, spacing: 8) {
                    if !isRead {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 10, height: 10)
                            .padding(.top, 6)
                    }
                    Text(article.title)
                        .font(.headline)
                        .fontWeight(isRead ? .regular : .semibold)
                        .foregroundStyle(isRead ? .secondary : .primary)
                        .lineLimit(2)
                }
                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
