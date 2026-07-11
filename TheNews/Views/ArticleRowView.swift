import SwiftUI

/// Ligne d'article dans la sidebar : vignette, titre, source/heure et pastille
/// « non lu ». Adaptée de `ItemRowView` du template.
struct ArticleRowView: View {
    @Environment(AppSettings.self) private var settings
    let article: Article

    /// Résumé lu par VoiceOver en un seul élément (titre, source, date, statuts non
    /// lu/favori) — les icônes qui portent ces mêmes statuts visuellement sont
    /// décoratives et masquées à l'accessibilité (cf. `.accessibilityHidden`).
    private var accessibilitySummary: String {
        var parts = [article.title]
        if let name = article.feed?.title { parts.append(name) }
        parts.append(article.dateFormatted)
        if !article.isRead { parts.append(settings.t("unread_status")) }
        if article.isFavorite { parts.append(settings.t("favorite")) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !article.isRead {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
                    .padding(.top, 6)
                    .accessibilityHidden(true)   // état « non lu » repris dans accessibilityLabel ci-dessous
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
                            .accessibilityHidden(true)   // statut repris dans accessibilityLabel
                    }
                }
            }

            Spacer(minLength: 0)

            thumbnail
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
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
