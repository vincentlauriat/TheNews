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

    var deduplicationKey: String {
        Self.canonicalLink(from: link) ?? "id:\(id)"
    }

    static func deduplicated(_ articles: [ParsedArticle]) -> [ParsedArticle] {
        var seen = Set<String>()
        return articles.filter { seen.insert($0.deduplicationKey).inserted }
    }

    /// Clé d'identité d'un article, indépendante de la façon dont le flux écrit son lien.
    ///
    /// `http` et `https` sont ramenés au même schéma : WordPress publie le même article
    /// avec un `<link>` et un `<guid>` en `http` dans certaines rubriques et en `https`
    /// dans d'autres (constaté sur Calipia, 17 articles sur 20). Sans cette
    /// normalisation, les deux variantes forment deux clés distinctes et l'article
    /// traverse les deux passes de déduplication — celle de `FeedStore.articles` à la
    /// lecture comme celle de `FeedStore.pruneDuplicates` en base.
    static func canonicalLink(from url: URL) -> String? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let scheme = components.scheme?.lowercased()
        components.scheme = (scheme == "http") ? "https" : scheme
        components.host = components.host?.lowercased()
        components.query = nil
        components.fragment = nil
        if components.path.hasSuffix("/") && components.path.count > 1 {
            components.path.removeLast()
        }
        return components.url?.absoluteString
    }
}

/// Parseur RSS 2.0 basé sur `XMLParser` natif (aucune dépendance externe).
/// Gère les balises standard (`title`, `link`, `description`, `pubDate`, `guid`)
/// ainsi que l'image via `<enclosure url>` ou `<media:content url>`, avec repli
/// sur `<media:thumbnail url>`.
enum RSSParser {
    /// Parse les données d'un flux. Retourne une liste éventuellement vide ;
    /// ne lève pas — un flux malformé donne les items lisibles, pas une erreur.
    static func parse(_ data: Data, feedID: String) -> [ParsedArticle] {
        let delegate = Delegate(feedID: feedID)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return ParsedArticle.deduplicated(delegate.articles)
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
        private var thumbnailURL: String?

        init(feedID: String) { self.feedID = feedID }

        func parser(_ parser: XMLParser, didStartElement name: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attrs: [String: String]) {
            let tag = qName ?? name
            if tag == "item" {
                inItem = true
                title = ""; link = ""; summary = ""; guid = ""; pubDate = ""
                imageURL = nil; thumbnailURL = nil
            }
            element = tag
            buffer = ""

            guard inItem else { return }
            // Images portées par des attributs (pas de texte entre balises).
            // `type` (MIME) et `medium` (catégorie Media RSS) sont tous deux
            // optionnels ; on n'écarte que ce qui se déclare explicitement comme
            // n'étant pas une image.
            guard tag == "enclosure" || tag == "media:content" || tag == "media:thumbnail",
                  let url = attrs["url"],
                  attrs["type"].map({ $0.hasPrefix("image") }) ?? true,
                  attrs["medium"].map({ $0 == "image" }) ?? true
            else { return }

            // `media:thumbnail` n'est retenu qu'à défaut de `enclosure` /
            // `media:content` : c'est souvent une version recadrée ou réduite de
            // l'illustration, et les flux du catalogue intégré (Le Monde, Les
            // Echos) publient la pleine résolution dans `media:content`. Certains
            // flux WordPress, eux, ne déclarent que la vignette — d'où le repli.
            if tag == "media:thumbnail" {
                if thumbnailURL == nil { thumbnailURL = url }
            } else if imageURL == nil {
                imageURL = url
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
            case "title":       if title.isEmpty { title = Self.cleanText(text) }
            case "link":        if link.isEmpty { link = text }
            case "guid":        guid = text
            case "description": if summary.isEmpty { summary = Self.cleanText(text) }
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
                imageURL: (imageURL ?? thumbnailURL).flatMap { Self.secureImageURL(from: $0) },
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

        /// Force `https` sur les URLs d'images. App Transport Security bloque les
        /// requêtes en clair, donc une image annoncée en `http` n'est jamais
        /// chargée par `AsyncImage` — même quand le serveur redirige en `https`,
        /// puisque la requête initiale est refusée avant la redirection. Les flux
        /// WordPress publient couramment des URLs `http` sur des sites servis en
        /// `https` ; la promotion ne peut donc que débloquer un cas perdu d'avance.
        static func secureImageURL(from string: String) -> URL? {
            guard var components = URLComponents(string: string) else { return nil }
            if components.scheme?.lowercased() == "http" { components.scheme = "https" }
            return components.url
        }

        /// Nettoie un titre ou un chapô : retire les balises HTML puis décode les
        /// entités. Appliqué aux deux champs car un flux peut encapsuler l'un
        /// comme l'autre dans du CDATA (voir `decodingEntities`).
        static func cleanText(_ s: String) -> String {
            let noTags = s.replacingOccurrences(
                of: "<[^>]+>", with: "", options: .regularExpression)
            return decodingEntities(noTags)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// Décode les entités HTML numériques (`&#8217;`, `&#x2019;`) et nommées
        /// (`&eacute;`, `&hellip;`).
        ///
        /// `XMLParser` résout déjà les références présentes dans le texte balisé,
        /// mais **pas** celles enfermées dans un bloc `CDATA` : leur contenu est
        /// livré littéralement. Or WordPress y encode systématiquement apostrophes
        /// typographiques et points de suspension, d'où des chapôs affichant
        /// « l&#8217;informatique ». Décodage manuel plutôt que
        /// `NSAttributedString(.html)`, cantonné au `MainActor` alors que le
        /// parsing tourne en tâche de fond.
        static func decodingEntities(_ s: String) -> String {
            guard s.contains("&") else { return s }
            var result = ""
            result.reserveCapacity(s.count)
            var cursor = s.startIndex

            while let amp = s[cursor...].firstIndex(of: "&") {
                result.append(contentsOf: s[cursor..<amp])
                // Une entité valide est courte ; au-delà c'est une esperluette isolée.
                let horizon = s.index(amp, offsetBy: 12, limitedBy: s.endIndex) ?? s.endIndex
                guard let semicolon = s[amp..<horizon].firstIndex(of: ";") else {
                    result.append("&")
                    cursor = s.index(after: amp)
                    continue
                }
                let body = String(s[s.index(after: amp)..<semicolon])
                if let decoded = decodedEntity(body) {
                    result.append(decoded)
                } else {
                    result.append(contentsOf: s[amp...semicolon])
                }
                cursor = s.index(after: semicolon)
            }

            result.append(contentsOf: s[cursor...])
            return result
        }

        /// Résout le corps d'une entité (ce qui suit `&` avant `;`), ou `nil` si
        /// elle est inconnue — auquel cas l'appelant la laisse telle quelle.
        private static func decodedEntity(_ body: String) -> String? {
            guard !body.isEmpty else { return nil }
            if body.hasPrefix("#") {
                let digits = body.dropFirst()
                let value: UInt32? = (digits.first == "x" || digits.first == "X")
                    ? UInt32(digits.dropFirst(), radix: 16)
                    : UInt32(digits, radix: 10)
                guard let value, let scalar = Unicode.Scalar(value) else { return nil }
                return String(Character(scalar))
            }
            return namedEntities[body]
        }

        /// Entités nommées les plus fréquentes dans les flux francophones.
        /// Les entités numériques couvrant le reste, cette table reste courte.
        private static let namedEntities: [String: String] = [
            "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
            "hellip": "…", "rsquo": "’", "lsquo": "‘", "ldquo": "“", "rdquo": "”",
            "laquo": "«", "raquo": "»", "ndash": "–", "mdash": "—", "bull": "•",
            "euro": "€", "deg": "°", "times": "×", "middot": "·", "eacute": "é",
            "egrave": "è", "ecirc": "ê", "euml": "ë", "agrave": "à", "acirc": "â",
            "ccedil": "ç", "ocirc": "ô", "icirc": "î", "iuml": "ï", "ugrave": "ù",
            "ucirc": "û", "uuml": "ü", "oelig": "œ", "Eacute": "É", "Egrave": "È",
            "Agrave": "À", "Ccedil": "Ç", "Ocirc": "Ô", "OElig": "Œ",
            "copy": "©", "reg": "®", "trade": "™",
        ]
    }
}
