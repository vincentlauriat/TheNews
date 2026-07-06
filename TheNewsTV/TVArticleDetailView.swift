import SwiftUI

/// Détail d'un article sur grand écran : image, titre, chapô, source, date.
/// Pas de lien « ouvrir dans Safari » — lecture 10 pieds, on affiche le contenu
/// texte déjà présent dans le flux RSS plutôt que de renvoyer vers un navigateur.
struct TVArticleDetailView: View {
    let article: ParsedArticle
    let sourceName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let imageURL = article.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(16.0 / 9.0, contentMode: .fill)
                        } else {
                            Rectangle().fill(.secondary.opacity(0.2))
                                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        }
                    }
                    .frame(maxHeight: 480)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Text(sourceName.uppercased())
                    .font(.caption).bold()
                    .foregroundStyle(.tint)

                Text(article.title)
                    .font(.largeTitle).bold()

                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Text(article.publishedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(60)
        }
    }
}
