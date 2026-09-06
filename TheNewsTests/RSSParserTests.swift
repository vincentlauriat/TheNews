import XCTest
@testable import TheNews

final class RSSParserTests: XCTestCase {
    func testParsesStandardItem() {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
          <title>Titre de test</title>
          <link>https://example.com/article-1</link>
          <guid>guid-1</guid>
          <description><![CDATA[Un chapô <b>avec balises</b> &amp; entités.]]></description>
          <pubDate>Sat, 05 Jul 2026 12:30:00 +0200</pubDate>
          <enclosure url="https://example.com/image.jpg" type="image/jpeg"/>
        </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(Data(xml.utf8), feedID: "test.feed")
        XCTAssertEqual(articles.count, 1)
        let article = articles[0]
        XCTAssertEqual(article.id, "guid-1")
        XCTAssertEqual(article.title, "Titre de test")
        XCTAssertEqual(article.summary, "Un chapô avec balises & entités.")
        XCTAssertEqual(article.link, URL(string: "https://example.com/article-1"))
        XCTAssertEqual(article.imageURL, URL(string: "https://example.com/image.jpg"))
    }

    func testSkipsItemWithoutTitleOrLink() {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
          <description>Pas de titre ni de lien.</description>
        </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(Data(xml.utf8), feedID: "test.feed")
        XCTAssertTrue(articles.isEmpty)
    }

    func testFallsBackToGuidWhenLinkMissing() {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
          <title>Sans lien direct</title>
          <guid>https://example.com/fallback</guid>
        </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(Data(xml.utf8), feedID: "test.feed")
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].link, URL(string: "https://example.com/fallback"))
    }

    func testMalformedXMLReturnsEmptyNotError() {
        let data = Data("not xml at all".utf8)
        let articles = RSSParser.parse(data, feedID: "test.feed")
        XCTAssertTrue(articles.isEmpty)
    }

    func testDeduplicatesItemsWithSameCanonicalLink() {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
          <title>Article duplique</title>
          <link>https://example.com/news/story?utm_source=front</link>
          <guid>front-guid</guid>
        </item>
        <item>
          <title>Article duplique</title>
          <link>https://example.com/news/story?utm_source=section#comments</link>
          <guid>section-guid</guid>
        </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(Data(xml.utf8), feedID: "test.feed")
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].id, "front-guid")
    }

    func testMissingPubDateFallsBackToNow() {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
          <title>Sans date</title>
          <link>https://example.com/no-date</link>
        </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(Data(xml.utf8), feedID: "test.feed")
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].publishedAt.timeIntervalSinceNow, 0, accuracy: 5)
    }

    // MARK: - Entités HTML enfermées dans du CDATA

    /// `XMLParser` ne décode pas les références présentes dans un bloc CDATA :
    /// leur contenu est livré littéralement. Les flux WordPress y encodent
    /// systématiquement apostrophes typographiques et points de suspension.
    func testDecodesNumericEntitiesInsideCDATADescription() {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
          <title>Titre</title>
          <link>https://example.com/entites</link>
          <description><![CDATA[Comme nous&#8230;) et l&#8217;informatique &#x2019; d&eacute;j&agrave;.]]></description>
        </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(Data(xml.utf8), feedID: "test.feed")
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].summary, "Comme nous…) et l’informatique ’ déjà.")
        XCTAssertFalse(articles[0].summary.contains("&#"))
    }

    func testDecodesEntitiesInsideCDATATitle() {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
          <title><![CDATA[L&#8217;IA d&eacute;truit&#8230;]]></title>
          <link>https://example.com/titre-cdata</link>
        </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(Data(xml.utf8), feedID: "test.feed")
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].title, "L’IA détruit…")
    }

    /// Une entité inconnue et une esperluette isolée doivent traverser le
    /// décodage intactes plutôt que d'être avalées.
    func testLeavesUnknownEntitiesAndBareAmpersandIntact() {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
          <title>Titre</title>
          <link>https://example.com/inconnu</link>
          <description><![CDATA[Fish & chips &pasuneentite; fin &#zz; ok]]></description>
        </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(Data(xml.utf8), feedID: "test.feed")
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].summary, "Fish & chips &pasuneentite; fin &#zz; ok")
    }

    // MARK: - Images

    /// App Transport Security refuse les requêtes en clair : une image annoncée
    /// en `http` n'est jamais chargée, même si le serveur redirige en `https`.
    func testUpgradesHTTPImageURLToHTTPS() {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
          <title>Titre</title>
          <link>https://example.com/image-http</link>
          <enclosure url="http://example.com/photo.png" type="image/png"/>
        </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(Data(xml.utf8), feedID: "test.feed")
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].imageURL?.scheme, "https")
        XCTAssertEqual(articles[0].imageURL, URL(string: "https://example.com/photo.png"))
    }

    /// Flux ne déclarant l'illustration que dans `media:thumbnail` : elle doit
    /// être retenue plutôt que de laisser l'article sans image.
    func testUsesMediaThumbnailWhenNoOtherImage() {
        let xml = """
        <?xml version="1.0"?>
        <rss xmlns:media="http://search.yahoo.com/mrss/"><channel>
        <item>
          <title>Titre</title>
          <link>https://example.com/thumbnail-seul</link>
          <media:thumbnail url="https://example.com/vignette.png"/>
        </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(Data(xml.utf8), feedID: "test.feed")
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].imageURL, URL(string: "https://example.com/vignette.png"))
    }

    /// `media:thumbnail` est souvent une version recadrée de l'illustration : quand
    /// `media:content` est présent, c'est lui qui fait foi — y compris s'il arrive
    /// après, comme dans les flux WordPress.
    func testPrefersMediaContentOverMediaThumbnail() {
        let xml = """
        <?xml version="1.0"?>
        <rss xmlns:media="http://search.yahoo.com/mrss/"><channel>
        <item>
          <title>Titre</title>
          <link>https://example.com/pleine-resolution</link>
          <media:thumbnail url="https://example.com/vignette.png"/>
          <media:content url="https://example.com/pleine-resolution.png" medium="image"/>
        </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(Data(xml.utf8), feedID: "test.feed")
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].imageURL, URL(string: "https://example.com/pleine-resolution.png"))
    }

    /// Un média explicitement non-image ne doit pas être retenu comme illustration.
    func testIgnoresNonImageMediaContent() {
        let xml = """
        <?xml version="1.0"?>
        <rss xmlns:media="http://search.yahoo.com/mrss/"><channel>
        <item>
          <title>Titre</title>
          <link>https://example.com/audio</link>
          <media:content url="https://example.com/podcast.mp3" medium="audio"/>
        </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(Data(xml.utf8), feedID: "test.feed")
        XCTAssertEqual(articles.count, 1)
        XCTAssertNil(articles[0].imageURL)
    }

    // MARK: - Identité d'un article indépendante du schéma

    /// Cas réel constaté sur Calipia : WordPress sert le même article avec un `guid`
    /// et un `<link>` en `http` dans certaines rubriques et en `https` dans d'autres
    /// (17 articles sur 20). Les deux variantes doivent porter la même clé d'identité,
    /// sans quoi l'article apparaît deux fois dans la liste.
    func testCanonicalLinkTreatsHTTPAndHTTPSAsTheSameArticle() {
        let insecure = URL(string: "http://blog.calipia.com/2026/09/04/mon-article/")!
        let secure = URL(string: "https://blog.calipia.com/2026/09/04/mon-article")!
        XCTAssertEqual(
            ParsedArticle.canonicalLink(from: insecure),
            ParsedArticle.canonicalLink(from: secure)
        )
    }

    func testDeduplicationCollapsesSchemeVariantsWithDistinctGuids() {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
          <title>Le même article</title>
          <link>https://blog.calipia.com/2026/09/04/article/</link>
          <guid>https://blog.calipia.com/?p=33691</guid>
        </item>
        <item>
          <title>Le même article</title>
          <link>http://blog.calipia.com/2026/09/04/article/</link>
          <guid>http://blog.calipia.com/?p=33691</guid>
        </item>
        </channel></rss>
        """
        let articles = RSSParser.parse(Data(xml.utf8), feedID: "test.feed")
        XCTAssertEqual(articles.count, 1)
    }

    /// Un schéma non-HTTP ne doit pas être réécrit au passage.
    func testCanonicalLinkLeavesOtherSchemesAlone() {
        let url = URL(string: "feed://example.com/rss")!
        XCTAssertEqual(ParsedArticle.canonicalLink(from: url)?.hasPrefix("feed://"), true)
    }
}
