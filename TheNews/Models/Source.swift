import Foundation

/// Journal de presse générique. Le modèle est volontairement ouvert : une `Source`
/// n'est qu'un nom + une page d'accueil, ses rubriques vivent dans `Feed`. TheNews
/// agrège plusieurs sources dans une même interface (veille multi-journaux).
struct Source: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let homepageURL: URL

    static let leMonde = Source(
        id: "lemonde",
        name: "Le Monde",
        homepageURL: URL(string: "https://www.lemonde.fr")!
    )

    static let lesEchos = Source(
        id: "lesechos",
        name: "Les Echos",
        homepageURL: URL(string: "https://www.lesechos.fr")!
    )

    /// Pseudo-source regroupant les flux RSS ajoutés par l'utilisateur (`CustomFeed`).
    static let custom = Source(
        id: "custom",
        name: "Mes flux",
        homepageURL: URL(string: "https://www.thenews.app")!
    )

    /// Sources agrégées par TheNews, dans l'ordre d'affichage. « Mes flux » en dernier.
    static let all: [Source] = [.leMonde, .lesEchos, .custom]

    static func byID(_ id: String) -> Source? { all.first { $0.id == id } }
}
