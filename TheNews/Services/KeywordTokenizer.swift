import Foundation

/// Résultat d'une tentative d'ajout d'un mot-clé au champ à jetons (`KeywordChipField`).
enum KeywordAddResult: Equatable {
    case added([String])
    case duplicate
    case empty
}

/// Logique pure de parsing/dédup des mots-clés du champ à jetons — séparée de la vue pour
/// rester testable, sur le même principe que `MatchingEngine`.
enum KeywordTokenizer {
    /// Essaie d'ajouter `raw` à `existing` : trim, rejette les entrées vides, et déduplique en
    /// comparant les formes normalisées (`MatchingEngine.normalize`, insensible casse et
    /// accents) — cohérent avec le moteur de correspondance : deux mots-clés qui matcheraient
    /// les mêmes articles ne doivent pas coexister comme jetons distincts. Conserve la casse
    /// saisie par l'utilisateur pour l'affichage.
    static func add(_ raw: String, to existing: [String]) -> KeywordAddResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        let normalizedNew = MatchingEngine.normalize(trimmed)
        if existing.contains(where: { MatchingEngine.normalize($0) == normalizedNew }) {
            return .duplicate
        }
        return .added(existing + [trimmed])
    }

    /// Découpe un texte pouvant contenir plusieurs mots-clés séparés par des virgules (ex.
    /// collage depuis l'ancien format CSV) en jetons ajoutés un par un via `add`.
    static func addAll(_ raw: String, to existing: [String]) -> [String] {
        raw.split(separator: ",", omittingEmptySubsequences: false)
            .map(String.init)
            .reduce(existing) { acc, piece in
                if case .added(let next) = add(piece, to: acc) { return next }
                return acc
            }
    }
}
