import SwiftUI
import SwiftData
#if os(iOS)
import Photos
import UIKit
#endif

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

    #if os(iOS)
    @State private var confirmingImageSave = false
    @State private var imageSaveFeedback: String?
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.tabletopCreaseY) private var tabletopCreaseY
    /// Cadre global de la vue, comparé à la pliure pour découper haut / bas.
    @State private var globalFrame: CGRect = .zero
    #endif

    /// Disposition de lecture selon la posture de l'appareil (iPhone Duo notamment).
    private enum Layout: Equatable {
        /// Portrait / grand écran : image, titre puis texte, en une colonne qui défile.
        case column
        /// Paysage de faible hauteur (téléphone plié tenu en paysage) : l'image pleine largeur
        /// mangeait tout l'écran → image à gauche, titre et texte défilants à droite.
        case sideBySide
        /// Demi-plié en paysage : image + titre sur l'écran du haut, le reste sur celui du bas.
        case tabletop(top: CGFloat, bottom: CGFloat)
    }

    private var layout: Layout {
        #if os(iOS)
        if let crease = tabletopCreaseY, globalFrame.minY < crease, crease < globalFrame.maxY {
            return .tabletop(top: crease - globalFrame.minY, bottom: globalFrame.maxY - crease)
        }
        if verticalSizeClass == .compact { return .sideBySide }
        #endif
        return .column
    }

    var body: some View {
        Group {
            switch layout {
            case .column:
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let url = article.imageURL {
                            heroImage(url: url, fill: false)
                                .frame(maxWidth: .infinity)
                        }
                        header(titleFont: .largeTitle.bold())
                        details
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
            case .sideBySide:
                HStack(spacing: 0) {
                    if let url = article.imageURL {
                        heroImage(url: url, fill: true)
                            .containerRelativeFrame(.horizontal) { width, _ in width * 0.4 }
                            .frame(maxHeight: .infinity)
                            .padding([.vertical, .leading], 16)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            header(titleFont: .title.bold())
                            details
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                    }
                }
            case .tabletop(let top, let bottom):
                // Marge de part et d'autre de la pliure : rien de lisible sur l'arête.
                let creaseGap: CGFloat = 14
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 20) {
                        if let url = article.imageURL {
                            heroImage(url: url, fill: true)
                                .containerRelativeFrame(.horizontal) { width, _ in width * 0.42 }
                                .frame(maxHeight: .infinity)
                        }
                        header(titleFont: .title.bold())
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, creaseGap)
                    .frame(height: top)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) { details }
                            .frame(maxWidth: 760, alignment: .leading)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 24)
                            .padding(.top, creaseGap)
                            .padding(.bottom, 24)
                    }
                    .frame(height: bottom)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        #if os(iOS)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { globalFrame = $0 }
        #endif
        .navigationTitle(article.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // Recalcule le regroupement cross-source à chaque changement d'article.
        .task(id: article.id) {
            related = await RelatedArticlesEngine.related(to: article, context: modelContext)
        }
        #if os(iOS)
        .alert(
            settings.t("error_title"),
            isPresented: Binding(
                get: { imageSaveFeedback != nil },
                set: { if !$0 { imageSaveFeedback = nil } }
            )
        ) {
            Button(settings.t("ok")) { imageSaveFeedback = nil }
        } message: {
            Text(imageSaveFeedback ?? "")
        }
        #endif
    }

    /// Image de l'article. `fill` : remplit le cadre imposé par la disposition (rognée), sinon
    /// garde ses proportions en pleine largeur. Appui long → enregistrement dans Photos (iOS).
    private func heroImage(url: URL, fill: Bool) -> some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                if fill {
                    Color.clear.overlay { image.resizable().scaledToFill() }
                } else {
                    image.resizable().aspectRatio(contentMode: .fit)
                }
            } else if phase.error != nil {
                EmptyView()
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        #if os(iOS)
        .onLongPressGesture {
            confirmingImageSave = true
        }
        .confirmationDialog(
            settings.t("save_image_confirm_title"),
            isPresented: $confirmingImageSave,
            titleVisibility: .visible
        ) {
            Button(settings.t("save_image_action")) {
                Task { await saveImageToPhotos(url: url) }
            }
            Button(settings.t("cancel"), role: .cancel) {}
        }
        #endif
    }

    /// Rubrique, titre et date.
    private func header(titleFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let feed = article.feed {
                Text(feed.title.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
            }
            Text(article.title)
                .font(titleFont)
            Text(article.dateFormatted)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// Chapô, actions et « Aussi couvert par… » — tout ce qui suit le titre.
    @ViewBuilder
    private var details: some View {
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
        }
        .font(.subheadline)
        .padding(.top, 4)

        if !related.isEmpty {
            Divider()
            relatedSection
        }
    }

    #if os(iOS)
    /// Télécharge l'image de l'article et l'enregistre dans Photos (autorisation « ajout
    /// seul », moins intrusive qu'un accès complet puisqu'on ne lit jamais la pellicule).
    private func saveImageToPhotos(url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                imageSaveFeedback = settings.t("save_image_failure")
                return
            }
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                imageSaveFeedback = settings.t("save_image_permission_denied")
                return
            }
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        } catch {
            imageSaveFeedback = settings.t("save_image_failure")
        }
    }
    #endif

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
                            .accessibilityHidden(true)   // décoratif : la source est déjà lue en texte
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
                            .accessibilityHidden(true)   // décoratif : le bouton est déjà lu (titre + source)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
