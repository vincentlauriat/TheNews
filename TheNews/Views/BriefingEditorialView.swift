import SwiftUI

/// Écran éditorial du Briefing (macOS) : remplace le triptyque liste + détail
/// par une page unique façon « une » de journal — un grand hero pour l'article
/// prioritaire (`BriefingEngine.today` place déjà en tête les sujets de veille,
/// puis les plus récents), suivi d'une grille de cartes pour le reste de la
/// sélection du jour. Chaque carte est autonome (image, titre, chapô, actions) :
/// il n'y a pas de sélection à faire, on lit/agit directement dessus.
struct BriefingEditorialView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Bindable var vm: FeedViewModel

    private var lead: Article? { vm.articles.first }
    private var rest: [Article] { Array(vm.articles.dropFirst()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if let lead {
                    BriefingLeadCard(article: lead)
                }
                if !rest.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 320, maximum: 420), spacing: 22)],
                        spacing: 22
                    ) {
                        ForEach(rest) { article in
                            BriefingSecondaryCard(article: article)
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(vm.title(settings.t))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await vm.generateDigest(
                            lang: settings.effectiveLang,
                            length: settings.digestLength,
                            format: settings.digestFormat,
                            tone: settings.digestTone,
                            count: settings.digestCount
                        )
                    }
                } label: {
                    Label(settings.t("digest"), systemImage: "sparkles")
                }
                .disabled(vm.articles.isEmpty || vm.isGeneratingDigest)
                .help(settings.t("digest"))
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    vm.markAllRead(context: modelContext)
                } label: {
                    Label(settings.t("mark_all_read"), systemImage: "checkmark.circle")
                }
                .disabled(vm.articles.allSatisfy(\.isRead))
                .help(settings.t("mark_all_read"))
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await vm.refresh(context: modelContext, lang: settings.effectiveLang) }
                } label: {
                    if vm.isLoading {
                        ProgressView().scaleEffect(0.65)
                    } else {
                        Label(settings.t("refresh"), systemImage: "arrow.clockwise")
                    }
                }
                .disabled(vm.isLoading)
                .help(settings.t("refresh_help"))
            }
        }
        .overlay {
            if vm.articles.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    settings.t("no_items_title"),
                    systemImage: "sun.max",
                    description: Text(settings.t("no_items_desc"))
                )
            }
        }
    }
}

/// Le hero : grande image, gros titre, chapô en entier, actions complètes —
/// mêmes actions que `ArticleDetailView` (lire / favori / partager), pour ne
/// rien perdre en remplaçant le panneau de détail.
private struct BriefingLeadCard: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Bindable var article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: open) { heroImage }
                .buttonStyle(.plain)
                .accessibilityLabel(article.title)   // heroImage seul n'a aucun texte à énoncer

            VStack(alignment: .leading, spacing: 10) {
                meta
                Text(article.title)
                    .font(.system(size: 32, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                if let text = article.displaySummary, !text.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        if article.summaryIsGenerated {
                            Text(settings.t("ai_summary_badge"))
                                .font(.caption2)
                                .italic()
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                actions
            }
        }
        .task { await generateSummaryIfNeeded() }
    }

    private func generateSummaryIfNeeded() async {
        guard article.summary.isEmpty, article.aiSummary == nil else { return }
        guard let text = await ArticleSummarizer.oneLiner(title: article.title, lang: settings.effectiveLang) else { return }
        article.aiSummary = text
        try? modelContext.save()
    }

    @ViewBuilder
    private var heroImage: some View {
        if let url = article.imageURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(.secondary.opacity(0.12))
                }
            }
            .frame(height: 360)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var meta: some View {
        HStack(spacing: 8) {
            if let source = article.feed?.source?.name {
                Text(source.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                Text("·").foregroundStyle(.tertiary)
            }
            Text(article.dateFormatted)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button(action: open) {
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
        }
        .font(.subheadline)
        .padding(.top, 4)
    }

    private func open() {
        openURL(article.link)
        article.isRead = true
    }
}

/// Carte secondaire, plus compacte : image, titre, chapô tronqué, méta et
/// mêmes actions que la carte principale (lire / favori / partager), affichées
/// en permanence — pas seulement via le menu contextuel.
private struct BriefingSecondaryCard: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Bindable var article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 10) {
                    thumbnail
                    HStack(spacing: 6) {
                        if let source = article.feed?.source?.name {
                            Text(source.uppercased())
                                .font(.caption2.bold())
                                .foregroundStyle(Color.accentColor)
                        }
                        Spacer(minLength: 0)
                        if article.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                                .accessibilityHidden(true)   // statut déjà porté par le bouton favori
                        }
                    }
                    Text(article.title)
                        .font(.headline)
                        .fontWeight(article.isRead ? .regular : .semibold)
                        .foregroundStyle(article.isRead ? .secondary : .primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if let text = article.displaySummary, !text.isEmpty {
                        Text(text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        if article.summaryIsGenerated {
                            Text(settings.t("ai_summary_badge"))
                                .font(.caption2)
                                .italic()
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Text(article.dateFormatted)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            actions
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.separator, lineWidth: 1)
        )
        .task { await generateSummaryIfNeeded() }
        .contextMenu {
            Button {
                article.isFavorite.toggle()
            } label: {
                Label(
                    settings.t(article.isFavorite ? "unfavorite" : "favorite"),
                    systemImage: article.isFavorite ? "star.fill" : "star"
                )
            }
            ShareLink(item: article.link) {
                Label(settings.t("share"), systemImage: "square.and.arrow.up")
            }
        }
    }

    private func generateSummaryIfNeeded() async {
        guard article.summary.isEmpty, article.aiSummary == nil else { return }
        guard let text = await ArticleSummarizer.oneLiner(title: article.title, lang: settings.effectiveLang) else { return }
        article.aiSummary = text
        try? modelContext.save()
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: open) {
                Label(settings.t("read_article"), systemImage: "safari")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                article.isFavorite.toggle()
            } label: {
                Label(
                    settings.t(article.isFavorite ? "unfavorite" : "favorite"),
                    systemImage: article.isFavorite ? "star.fill" : "star"
                )
                .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            ShareLink(item: article.link) {
                Label(settings.t("share"), systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .font(.caption)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = article.imageURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(16.0 / 9.0, contentMode: .fill)
                } else {
                    Rectangle().fill(.secondary.opacity(0.12))
                }
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func open() {
        openURL(article.link)
        article.isRead = true
    }
}
