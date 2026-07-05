import SwiftUI

/// Détail d'un article : image, chapô et bouton d'ouverture de l'article complet.
/// Le corps intégral n'est pas dans le flux RSS Le Monde → on ouvre le lien dans
/// le navigateur. Adaptée de `ItemDetailView` du template.
struct ArticleDetailView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Bindable var article: Article

    /// Articles d'autres sources couvrant le même sujet (calculés on-device).
    @State private var related: [Article] = []
    /// Résumé généré on-device (Apple Intelligence, ou repli extractif).
    @State private var summary: String?
    @State private var summarizing = false

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

                    ShareLink(item: article.link) {
                        Label(settings.t("share"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await generateSummary() }
                    } label: {
                        Label(settings.t("summarize"), systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                    .disabled(summarizing || article.summary.isEmpty)
                }
                .font(.subheadline)
                .padding(.top, 4)

                if summarizing || summary != nil {
                    summaryCard
                }

                if !related.isEmpty {
                    Divider()
                    relatedSection
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .navigationTitle(article.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // Recalcule le regroupement cross-source à chaque changement d'article.
        .task(id: article.id) {
            related = RelatedArticlesEngine.related(to: article, context: modelContext)
        }
    }

    /// « Aussi couvert par… » : mêmes faits vus par d'autres journaux/sources.
    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(settings.t("also_covered"), systemImage: "square.stack.3d.up.fill")
                .font(.headline)
            ForEach(related) { rel in
                Button {
                    openURL(rel.link)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: rel.feed?.symbol ?? "newspaper")
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            if let source = rel.feed?.source?.name {
                                Text(source.uppercased())
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                            Text(rel.title)
                                .font(.callout)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Carte « En bref » : résumé on-device (Apple Intelligence ou repli extractif).
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(settings.t("summary_title"), systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(.tint)
            if summarizing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(settings.t("summarizing")).foregroundStyle(.secondary)
                }
                .font(.callout)
            } else if let summary {
                Text(summary)
                    .font(.callout)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func generateSummary() async {
        guard !summarizing else { return }
        summarizing = true
        summary = nil
        let result = await ArticleSummarizer.summarize(
            title: article.title, body: article.summary, lang: settings.effectiveLang
        )
        summary = result
        summarizing = false
    }
}
