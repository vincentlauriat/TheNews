import XCTest
@testable import TheNews

final class FeedCatalogTests: XCTestCase {
    func testBuiltInFeedIDsAreUnique() {
        let ids = Feed.builtInCatalog.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    /// Chaque rubrique intégrée doit se rattacher à une `Source` déclarée, faute de
    /// quoi elle disparaît de la sidebar : `Feed.bySource` la filtrerait en silence.
    func testEveryBuiltInFeedResolvesItsSource() {
        for feed in Feed.builtInCatalog {
            XCTAssertNotNil(feed.source, "Source introuvable pour \(feed.id)")
        }
    }

    func testCalipiaIsAListedSource() {
        XCTAssertTrue(Source.all.contains(Source.calipia))
        XCTAssertEqual(Source.byID("calipia"), Source.calipia)
    }

    func testCalipiaCatalogIsGroupedUnderItsSource() {
        let grouped = Feed.bySource.first { $0.source == Source.calipia }
        XCTAssertEqual(grouped?.feeds, Feed.calipiaCatalog)
    }

    /// App Transport Security refuse les requêtes en clair : un flux déclaré en
    /// `http` ne serait jamais téléchargé.
    func testEveryBuiltInFeedURLUsesHTTPS() {
        for feed in Feed.builtInCatalog {
            XCTAssertEqual(feed.rssURL.scheme, "https", "Flux non-https : \(feed.id)")
        }
    }

    func testLOpinionIsAListedSource() {
        XCTAssertTrue(Source.all.contains(Source.lopinion))
        XCTAssertEqual(Source.byID("lopinion"), Source.lopinion)
    }

    func testLOpinionCatalogIsGroupedUnderItsSource() {
        let grouped = Feed.bySource.first { $0.source == Source.lopinion }
        XCTAssertEqual(grouped?.feeds, Feed.lopinionCatalog)
    }

    // MARK: - Doublon catalogue intégré / flux perso

    /// Ajouter en « flux perso » une URL déjà servie par le catalogue ferait apparaître
    /// la source deux fois dans la sidebar, et `FeedStore.ingest` dédupliquant par `guid`
    /// toutes rubriques confondues, la seconde entrée resterait vide.
    func testDetectsBuiltInFeedBehindACustomURL() {
        let blog = Feed.calipiaCatalog[0]
        XCTAssertEqual(CustomFeedStore.builtInFeed(matching: blog.rssURL.absoluteString)?.id, blog.id)
    }

    /// Le même flux est souvent publié en `http` comme en `https`, avec ou sans slash
    /// final, et l'hôte n'est pas sensible à la casse.
    func testDetectsBuiltInFeedAcrossURLSpellings() {
        for spelling in [
            "http://blog.calipia.com/feed/",
            "https://BLOG.Calipia.com/feed/",
            "https://blog.calipia.com/feed",
            "  https://blog.calipia.com/feed/  "
        ] {
            XCTAssertEqual(
                CustomFeedStore.builtInFeed(matching: spelling)?.id,
                "calipia.blog",
                "Doublon non détecté pour \(spelling)"
            )
        }
    }

    /// La requête est signifiante sur une URL de flux : elle ne doit pas être ignorée,
    /// sinon un flux légitime serait refusé comme doublon.
    func testDoesNotFlagUnrelatedOrQueryDistinctFeeds() {
        XCTAssertNil(CustomFeedStore.builtInFeed(matching: "https://blog.calipia.com/feed/?format=atom"))
        XCTAssertNil(CustomFeedStore.builtInFeed(matching: "https://example.com/feed/"))
        XCTAssertNil(CustomFeedStore.builtInFeed(matching: "pas une url"))
    }
}
