import SwiftUI

/// Détail d'un article : image, chapô et bouton d'ouverture de l'article complet.
/// Le corps intégral n'est pas dans le flux RSS Le Monde → on ouvre le lien dans
/// le navigateur. Adaptée de `ItemDetailView` du template.
struct ArticleDetailView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Bindable var article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let url = article.imageURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit)
                        } else if phase.error != nil {
                            EmptyView()
                        } else {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    if let feed = article.feed {
                        Text(feed.title.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(article.title)
                        .font(.largeTitle.bold())
                    Text(article.dateFormatted)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }

                HStack(spacing: 12) {
                    Button {
                        openURL(article.link)
                    } label: {
                        Label(settings.t("read_article"), systemImage: "safari")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        article.isFavorite.toggle()
                    } label: {
                        Label(
                            settings.t(article.isFavorite ? "unfavorite" : "favorite"),
                            systemImage: article.isFavorite ? "star.fill" : "star"
                        )
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .navigationTitle(article.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
