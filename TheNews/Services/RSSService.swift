import Foundation

/// Récupération réseau des flux RSS. Le téléchargement et le parsing se font hors
/// du `MainActor` ; le résultat (`[ParsedArticle]`, `Sendable`) est ensuite remis
/// au `FeedStore` pour insertion SwiftData.
struct RSSService: Sendable {
    var session: URLSession = .shared

    enum FeedError: LocalizedError {
        case badStatus(Int)
        case empty

        var errorDescription: String? {
            switch self {
            case .badStatus(let code): return "Réponse HTTP \(code)."
            case .empty:               return "Flux vide ou illisible."
            }
        }
    }

    /// Télécharge et parse un flux. Lève sur erreur réseau/HTTP.
    func fetch(_ feed: Feed) async throws -> [ParsedArticle] {
        var request = URLRequest(url: feed.rssURL)
        request.setValue("TheNews/1.0", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadRevalidatingCacheData

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw FeedError.badStatus(http.statusCode)
        }
        return RSSParser.parse(data, feedID: feed.id)
    }
}
