import SwiftUI

/// Détail d'un article sur grand écran : image, titre, chapô, source, date.
/// Les flèches gauche/droite de la télécommande passent à l'article
/// précédent/suivant dans la liste d'origine, sans repousser d'écran.
/// Pas de lien « ouvrir dans Safari » — lecture 10 pieds, on affiche le contenu
/// texte déjà présent dans le flux RSS plutôt que de renvoyer vers un navigateur.
struct TVArticleDetailView: View {
    @State private var selection: TVArticleSelection
    @Environment(TVReadStore.self) private var readStore

    init(selection: TVArticleSelection) {
        _selection = State(initialValue: selection)
    }

    private var article: TVArticle { selection.articles[selection.index] }

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
                    // Bloc focusable indépendant : voir la note plus bas.
                    .focusable()
                    .focusEffectDisabled()
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text(article.sourceName.uppercased())
                        .font(.caption).bold()
                        .foregroundStyle(.tint)

                    Text(article.title)
                        .font(.largeTitle).bold()

                    if !article.summary.isEmpty {
                        Text(article.summary)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .focusable()
                .focusEffectDisabled()

                HStack {
                    Text(article.publishedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if selection.articles.count > 1 {
                        Text("\(selection.index + 1) / \(selection.articles.count) · ◀ ▶")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .focusable()
                .focusEffectDisabled()
            }
            .padding(.top, 14)
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        // Anime le contenu au changement d'article pour rendre le passage
        // suivant/précédent lisible malgré l'absence de transition de scène.
        .id(article.id)
        // Marquer « lu » mute `TVReadStore`, observé par les lignes de la liste
        // encore vivante juste en dessous dans la pile de navigation. Le faire de
        // façon synchrone dans `onAppear` mutait cet état pendant l'animation de
        // transition (poussée d'écran) et provoquait un rebond immédiat vers la
        // liste sur tvOS. `.task` + un court délai laisse la transition se
        // terminer avant de toucher l'état partagé ; `id: article.id` le
        // ré-exécute à chaque article, y compris en naviguant au clavier.
        .task(id: article.id) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            readStore.markRead(article.id)
        }
        // Le scroll tvOS est piloté par le focus (comme une List) : un unique bloc
        // focusable pour tout l'écran fait que haut/bas n'ont rien « en dessous »
        // vers quoi déplacer le focus, donc tombent (comme gauche/droite) dans
        // onMoveCommand, qui ne gérait que gauche/droite → haut/bas ne faisaient
        // rien. En donnant 3 blocs focusables (image/texte/pied), le focus engine
        // déplace nativement le focus haut/bas entre eux (et fait défiler la
        // ScrollView pour le garder visible) ; gauche/droite, qu'aucun bloc ne
        // gère (ils sont empilés verticalement), remonte jusqu'ici. Effet visuel
        // de focus désactivé sur chaque bloc : ce ne sont pas des boutons.
        .onMoveCommand { direction in
            switch direction {
            case .right where selection.index < selection.articles.count - 1:
                selection.index += 1
            case .left where selection.index > 0:
                selection.index -= 1
            default:
                break
            }
        }
    }
}
