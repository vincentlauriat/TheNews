import Foundation

/// Résultat brut du parsing d'un `<item>` RSS, avant persistance.
/// `Sendable` : produit hors du `MainActor` (parsing en tâche de fond) puis
/// transféré au `FeedStore` pour insertion SwiftData.
struct ParsedArticle: Sendable, Hashable {
    let id: String
    let title: String
    let summary: String
    let link: URL
    let imageURL: URL?
    let publishedAt: Date
}

/// Parseur RSS 2.0 basé sur `XMLParser` natif (aucune dépendance externe).
/// Gère les balises standard (`title`, `link`, `description`, `pubDate`, `guid`)
/// ainsi que l'image via `<enclosure url>` ou `<media:content url>`.
enum RSSParser {
    /// Parse les données d'un flux. Retourne une liste éventuellement vide ;
    /// ne lève pas — un flux malformé donne les items lisibles, pas une erreur.
    static func parse(_ data: Data, feedID: String) -> [ParsedArticle] {
        let delegate = Delegate(feedID: feedID)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.articles
    }

    // MARK: - Délégué XMLParser

    private final class Delegate: NSObject, XMLParserDelegate {
        let feedID: String
        var articles: [ParsedArticle] = []

        private var inItem = false
        private var element = ""
        private var buffer = ""

        // Champs de l'item courant.
        private var title = ""
        private var link = ""
        private var summary = ""
        private var guid = ""
        private var pubDate = ""
        private var imageURL: String?

        init(feedID: String) { self.feedID = feedID }

        func parser(_ parser: XMLParser, didStartElement name: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attrs: [String: String]) {
            let tag = qName ?? name
            if tag == "item" {
                inItem = true
                title = ""; link = ""; summary = ""; guid = ""; pubDate = ""; imageURL = nil
            }
            element = tag
            buffer = ""

            guard inItem else { return }
            // Images portées par des attributs (pas de texte entre balises).
            if tag == "enclosure" || tag == "media:content" {
                if let url = attrs["url"], imageURL == nil,
                   (attrs["type"]?.hasPrefix("image") ?? true) {
                    imageURL = url
                }
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            buffer += string
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            if let s = String(data: CDATABlock, encoding: .utf8) { buffer += s }
        }

        func parser(_ parser: XMLParser, didEndElement name: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            let tag = qName ?? name
            let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

            guard inItem else { buffer = ""; return }

            switch tag {
            case "title":       if title.isEmpty { title = text }
            case "link":        if link.isEmpty { link = text }
            case "guid":        guid = text
            case "description": if summary.isEmpty { summary = Self.stripHTML(text) }
            case "pubDate":     pubDate = text
            case "item":        finishItem()
            default:            break
            }
            buffer = ""
        }

        private func finishItem() {
            inItem = false
            let resolvedLink = link.isEmpty ? guid : link
            guard let url = URL(string: resolvedLink), !title.isEmpty else { return }
            let identifier = guid.isEmpty ? resolvedLink : guid
            articles.append(ParsedArticle(
                id: identifier,
                title: title,
                summary: summary,
                link: url,
                imageURL: imageURL.flatMap { URL(string: $0) },
                publishedAt: Self.date(from: pubDate) ?? Date()
            ))
        }

        // MARK: Helpers

        /// Formatteur RFC 822 des `pubDate` RSS (ex. « Sat, 05 Jul 2026 12:30:00 +0200 »).
        private static let rfc822: DateFormatter = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            return df
        }()

        private static func date(from string: String) -> Date? {
            rfc822.date(from: string)
        }

        /// Retire les balises HTML éventuelles d'un chapô et décode les entités simples.
        private static func stripHTML(_ s: String) -> String {
            let noTags = s.replacingOccurrences(
                of: "<[^>]+>", with: "", options: .regularExpression)
            return noTags
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&laquo;", with: "«")
                .replacingOccurrences(of: "&raquo;", with: "»")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
