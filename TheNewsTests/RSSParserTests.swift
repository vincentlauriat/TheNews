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
}
