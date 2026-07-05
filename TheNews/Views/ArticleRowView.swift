import SwiftUI

/// Ligne d'article dans la sidebar : vignette, titre, source/heure et pastille
/// « non lu ». Adaptée de `ItemRowView` du template.
struct ArticleRowView: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !article.isRead {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
                    .padding(.top, 6)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(article.title)
                    .font(.body)
                    .fontWeight(article.isRead ? .regular : .semibold)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    if let name = article.feed?.title {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·").font(.caption).foregroundStyle(.tertiary)
                    }
                    Text(article.dateFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if article.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
            }

            Spacer(minLength: 0)

            thumbnail
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = article.imageURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.secondary.opacity(0.1)
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}
