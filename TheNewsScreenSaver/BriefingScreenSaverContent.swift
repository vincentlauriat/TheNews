import SwiftUI

/// Racine SwiftUI de l'écran de veille : récupère le Briefing en direct
/// (`AutonomousBriefing`, fetch RSS autonome) et fait défiler ses articles en
/// boucle — même principe que `TVBriefingHeroView` côté tvOS, mais plein écran,
/// sans télécommande, avec l'heure en incrustation (convention des écrans de
/// veille). La rotation locale (changement d'article affiché) et le
/// rafraîchissement réseau (nouveau fetch RSS) sont deux boucles séparées : pas
/// besoin de retélécharger les flux à chaque changement d'image.
///
/// L'animation de page (`angle`/`direction`) est pilotée **entièrement à la
/// main**, pas via `.transition()`/`.id()` : une première tentative avec
/// `AnyTransition.asymmetric(.modifier(active:identity:))` tournait toujours du
/// même côté en pratique (ambiguïté SwiftUI sur quelle instance — sortante ou
/// entrante — lit quelle valeur au moment du diff). En gardant une seule vue
/// persistante et en animant `angle`/`direction` en deux phases explicites
/// (sortie puis entrée), le comportement est entièrement déterministe.
struct BriefingScreenSaverContent: View {
    let isPreview: Bool

    @State private var articles: [BriefingSnapshotArticle] = []
    @State private var index = 0
    @State private var angle: Double = 0
    @State private var direction: PageTurnDirection = .left

    private var rotationInterval: Double { isPreview ? 3 : 8 }
    private var refreshInterval: Double { 15 * 60 }
    private var turnDuration: Double { 0.55 }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let current = articles[safe: index] {
                heroCard(current)
                    .modifier(PageTurnModifier(angle: angle, direction: direction))
            } else {
                emptyState
            }

            VStack {
                Spacer()
                HStack {
                    Text("TheNews · Briefing")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text(Date(), style: .time)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(isPreview ? 8 : 24)
            }
        }
        .task { await refreshLoop() }
        .task { await rotateLoop() }
    }

    @ViewBuilder
    private func heroCard(_ article: BriefingSnapshotArticle) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: article.imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(
                            colors: [
                                Color(hue: hue(for: article.id), saturation: 0.45, brightness: 0.28),
                                Color(hue: hue(for: article.id), saturation: 0.55, brightness: 0.12),
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.9), .black.opacity(0.35), .clear],
                    startPoint: .bottom, endPoint: .top
                )

                VStack(alignment: .leading, spacing: isPreview ? 4 : 14) {
                    Text(article.source.uppercased())
                        .font(isPreview ? .caption2.bold() : .headline.bold())
                        .foregroundStyle(.white.opacity(0.8))
                    Text(article.title)
                        .font(isPreview ? .caption.bold() : .system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(isPreview ? 2 : 3)
                    if !isPreview, !article.summary.isEmpty {
                        Text(article.summary)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                    if articles.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(articles.indices, id: \.self) { i in
                                Circle()
                                    .fill(.white.opacity(i == index ? 0.9 : 0.3))
                                    .frame(width: isPreview ? 3 : 7, height: isPreview ? 3 : 7)
                            }
                        }
                    }
                }
                .padding(isPreview ? 10 : 48)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.max")
                .font(.system(size: isPreview ? 20 : 48))
            Text("Aucun briefing disponible")
                .font(isPreview ? .caption : .title3)
        }
        .foregroundStyle(.white.opacity(0.6))
    }

    /// Teinte stable dérivée de l'identifiant, pour un dégradé de repli différent
    /// par article quand l'image ne charge pas (plutôt qu'un gris uniforme).
    private func hue(for id: String) -> Double {
        Double(abs(id.hashValue) % 360) / 360
    }

    /// Fetch RSS initial immédiat, puis un nouveau toutes les 15 min (l'écran de
    /// veille peut rester affiché des heures ; inutile de retélécharger à chaque
    /// rotation d'article, ce serait juste marteler les serveurs RSS pour rien).
    private func refreshLoop() async {
        while !Task.isCancelled {
            let fresh = await AutonomousBriefing.today()
            if !fresh.isEmpty {
                articles = fresh
                if index >= fresh.count { index = 0 }
            }
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(refreshInterval))
        }
    }

    /// Anime la sortie de la page courante (0° → -90°, bord tiré au sort), puis
    /// bascule l'article affiché et fait entrer la nouvelle page depuis le même
    /// bord (+90° → 0°, sans animation pour le saut initial à +90°).
    private func rotateLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(rotationInterval))
            guard !Task.isCancelled, articles.count > 1 else { continue }

            direction = PageTurnDirection.allCases.randomElement() ?? .left

            withAnimation(.spring(response: turnDuration, dampingFraction: 0.78)) {
                angle = -90
            }
            try? await Task.sleep(for: .seconds(turnDuration))
            guard !Task.isCancelled else { return }

            index = (index + 1) % articles.count
            withAnimation(.none) { angle = 90 }
            withAnimation(.spring(response: turnDuration, dampingFraction: 0.78)) {
                angle = 0
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Bord depuis lequel la page semble tournée — tiré au sort à chaque rotation
/// (`rotateLoop`).
private enum PageTurnDirection: CaseIterable {
    case left, right, up, down

    var axis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        switch self {
        case .left, .right: return (0, 1, 0)
        case .up, .down: return (1, 0, 0)
        }
    }

    var anchor: UnitPoint {
        switch self {
        case .left: return .leading
        case .right: return .trailing
        case .up: return .top
        case .down: return .bottom
        }
    }
}

/// Rotation 3D autour d'un des quatre bords (comme une page de livre qui se
/// tourne), assombrie progressivement vers 90° pour simuler le dos de la page.
/// Le léger `give` (léger rétrécissement uniforme, nul à 0°/90°, maximal à 45°)
/// casse la rigidité d'une simple plaque qui pivote : le papier cède un peu à
/// mi-course plutôt que de rester parfaitement plat pendant toute la rotation.
private struct PageTurnModifier: ViewModifier {
    let angle: Double
    let direction: PageTurnDirection

    private var give: Double {
        let t = min(abs(angle) / 90, 1)
        return sin(t * .pi) * 0.06
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 - give, anchor: .center)
            .rotation3DEffect(
                .degrees(angle),
                axis: direction.axis,
                anchor: direction.anchor,
                perspective: 0.42
            )
            .overlay(Color.black.opacity(min(abs(angle) / 90 * 0.65, 0.65)))
    }
}
