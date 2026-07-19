import SwiftUI

/// Layout qui dispose ses sous-vues en lignes, avec retour à la ligne automatique quand la
/// largeur disponible est dépassée. SwiftUI n'a pas d'équivalent natif (`HStack` ne wrap pas) —
/// nécessaire pour afficher un nombre variable de jetons (mots-clés, puis sujets de veille
/// dans `AlertsView`).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, rowHeight: CGFloat = 0, totalHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                totalHeight += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: width.isFinite ? width : x, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Champ de saisie de mots-clés en jetons : chaque mot-clé validé (Retour ou virgule) devient
/// un jeton supprimable individuellement (tap sur sa croix). Remplace le `TextField` CSV libre
/// de `WatchTopicEditor`. Déduplication/validation déléguées à `KeywordTokenizer`.
struct KeywordChipField: View {
    @Environment(AppSettings.self) private var settings
    @Binding var keywords: [String]
    @State private var draft = ""
    @State private var feedback: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 6) {
                ForEach(keywords, id: \.self) { keyword in chip(keyword) }
                TextField(settings.t("topic_keyword_placeholder"), text: $draft)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 120)
                    .onSubmit { commit(draft); draft = "" }
                    .onChange(of: draft) { _, newValue in
                        guard newValue.contains(",") else { return }
                        let parts = newValue.split(separator: ",", omittingEmptySubsequences: false)
                        for part in parts.dropLast() { commit(String(part)) }
                        draft = String(parts.last ?? "")
                    }
            }
            if let feedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func chip(_ keyword: String) -> some View {
        HStack(spacing: 4) {
            Text(keyword).font(.callout)
            Button {
                keywords.removeAll { $0 == keyword }
            } label: {
                Image(systemName: "xmark.circle.fill").font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(settings.t("topic_keyword_remove"))
            .accessibilityValue(keyword)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
    }

    private func commit(_ raw: String) {
        switch KeywordTokenizer.add(raw, to: keywords) {
        case .added(let next):
            keywords = next
            feedback = nil
        case .duplicate:
            feedback = settings.t("topic_keyword_duplicate")
        case .empty:
            let isBlank = raw.trimmingCharacters(in: .whitespaces).isEmpty
            if !isBlank { feedback = settings.t("topic_keyword_empty") }
        }
    }
}
