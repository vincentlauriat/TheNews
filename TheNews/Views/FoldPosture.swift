import SwiftUI

#if os(iOS)
/// Posture « à demi plié en paysage » de l'iPhone Duo (pliable) : l'écran intérieur forme un
/// angle, la pliure court horizontalement au milieu de la fenêtre, l'écran du haut fait face au
/// lecteur et celui du bas repose comme un clavier. `ArticleDetailView` s'en sert pour poser
/// l'image et le titre en haut et le reste de l'article en bas.
///
/// iOS 27.1 expose l'état de la charnière (`onHingeChange` → statut + angle) mais pas sa
/// position : on la déduit du milieu de la fenêtre, en coordonnées globales. Hypothèse valable
/// pour une fenêtre plein écran sur l'écran intérieur, qui est le seul cas où la charnière est
/// partiellement ouverte et la fenêtre plus large que haute.
private struct TabletopCreaseKey: EnvironmentKey {
    /// Ordonnée globale de la pliure, ou `nil` hors posture « demi-plié paysage ».
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    var tabletopCreaseY: CGFloat? {
        get { self[TabletopCreaseKey.self] }
        set { self[TabletopCreaseKey.self] = newValue }
    }
}

/// Observe la charnière et la taille de la fenêtre, puis publie `tabletopCreaseY` dans
/// l'environnement de toute la hiérarchie. À poser une seule fois, à la racine.
private struct TabletopPostureModifier: ViewModifier {
    @State private var hingePartiallyOpen = false
    @State private var windowSize: CGSize = .zero

    private var creaseY: CGFloat? {
        guard hingePartiallyOpen, windowSize.width > windowSize.height else { return nil }
        return windowSize.height / 2
    }

    func body(content: Content) -> some View {
        observingHinge(
            content
                .environment(\.tabletopCreaseY, creaseY)
                .background {
                    // Taille de la fenêtre entière (safe area comprise) : la pliure est au
                    // milieu physique de l'écran, pas au milieu de la zone sûre.
                    Color.clear
                        .ignoresSafeArea()
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { windowSize = $0 }
                }
        )
        .animation(.smooth, value: creaseY)
    }

    @ViewBuilder
    private func observingHinge(_ view: some View) -> some View {
        if #available(iOS 27.1, *) {
            view.onHingeChange { _, context in
                hingePartiallyOpen = context.hinge?.status == .partiallyOpen
            }
        } else {
            view
        }
    }
}

extension View {
    /// Active la détection de la posture « demi-plié paysage » (cf. `tabletopCreaseY`).
    func tracksTabletopPosture() -> some View {
        modifier(TabletopPostureModifier())
    }
}
#endif
