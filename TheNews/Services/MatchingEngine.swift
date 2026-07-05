import Foundation

/// Détermine si un article correspond à des sujets de veille. La comparaison est
/// insensible à la casse **et aux accents** (« ecologie » matche « Écologie »), sur
/// le titre + le chapô. Sans état : réutilisable pour l'affichage comme pour les
/// alertes en tâche de fond (phase 4).
enum MatchingEngine {
    /// Normalise une chaîne pour la comparaison (minuscules, sans diacritiques).
    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr"))
    }

    /// Sujets (actifs) auxquels l'article correspond.
    static func matchingTopics<S: Sequence>(_ article: Article, topics: S) -> [WatchTopic]
    where S.Element == WatchTopic {
        let haystack = normalize(article.title + " " + article.summary)
        return topics.filter { topic in
            topic.isEnabled && topic.keywords.contains { keyword in
                let needle = normalize(keyword).trimmingCharacters(in: .whitespacesAndNewlines)
                return !needle.isEmpty && haystack.contains(needle)
            }
        }
    }

    /// L'article correspond-il à au moins un des sujets actifs ?
    static func isMatch<S: Sequence>(_ article: Article, topics: S) -> Bool
    where S.Element == WatchTopic {
        !matchingTopics(article, topics: topics).isEmpty
    }
}
