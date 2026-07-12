import SwiftUI

/// Carte d'article pour le mode d'affichage « cartes » des listes classiques (alternative à
/// `ArticleRowView`, même niveau d'info) — image, titre, chapô, méta, statuts non lu/favori.
/// Contrairement aux cartes du Briefing (`BriefingEditorialView`), le tap **sélectionne**
/// l'article (ouvre le panneau détail) au lieu d'ouvrir directement le lien : ce mode reste une
/// alternative visuelle à la liste, pas un écran autonome sans sélection.
struct ArticleCardView: View {
    @Environment(AppSettings.self) private var settings
    let article: Article
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(article.dateFormatted)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
