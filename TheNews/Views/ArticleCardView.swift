import SwiftUI

/// Carte d'article pour le mode d'affichage « cartes » des listes classiques (alternative à
/// `ArticleRowView`, même niveau d'info) — image, titre, chapô, méta, statuts non lu/favori.
/// Contrairement aux cartes du Briefing (`BriefingEditorialView`), le tap **sélectionne**
/// l'article (ouvre le panneau détail) au lieu d'ouvrir directement le lien : ce mode reste une
/// alternative visuelle à la liste, pas un écran autonome sans sélection.
struct ArticleCardView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Bindable var article: Article
    let isSelected: Bool

    private var accessibilitySummary: String {
        var parts = [article.title]
        if let name = article.feed?.title { parts.append(name) }
        parts.append(article.dateFormatted)
        if !article.isRead { parts.append(settings.t("unread_status")) }
        if article.isFavorite { parts.append(settings.t("favorite")) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            thumbnail
            HStack(spacing: 6) {
                if !article.isRead {
                    Circle().fill(Color.accentColor).frame(width: 7, height: 7)
                }
                if let name = article.feed?.title {
                    Text(name.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer(minLength: 0)
                if article.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            }
            Text(article.dateFormatted)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
            actions
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.separator), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Mêmes actions que `ArticleRowView`/`BriefingSecondaryCard` (lire / favori / partager),
    /// affichées en permanence — le tap sur le reste de la carte est géré par l'appelant
    /// (`ArticleListView.handleCardTap`, différent selon la plateforme).
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
        .padding(.top, 2)
    }

    private func open() {
        openURL(article.link)
        article.isRead = true
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
            .frame(height: 90)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
