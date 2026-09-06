import XCTest
import SwiftData
@testable import TheNews

@MainActor
final class FeedStoreIngestTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Article.self, FeedSubscription.self, WatchTopic.self, CustomFeed.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private func parsed(
        id: String = "guid-1",
        title: String = "Titre à jour",
        summary: String = "Chapô à jour",
        image: String? = "https://example.com/neuve.png"
    ) -> ParsedArticle {
        ParsedArticle(
            id: id,
            title: title,
            summary: summary,
            link: URL(string: "https://example.com/article")!,
            imageURL: image.flatMap { URL(string: $0) },
            publishedAt: Date()
        )
    }

    func testInsertsUnknownArticles() throws {
        let context = try makeContext()
        let inserted = try FeedStore(context: context).ingest([parsed()], feedID: "test.feed")
        XCTAssertEqual(inserted.count, 1)
        XCTAssertEqual(inserted[0].imageURL, URL(string: "https://example.com/neuve.png"))
    }

    /// Le cas qui rendait les correctifs du parseur invisibles : un article téléchargé
    /// avant le correctif gardait son chapô à entités non décodées et son image en `http`,
    /// que App Transport Security refuse — l'insertion sautant les identifiants connus.
    func testRefreshesFeedOwnedFieldsOfKnownArticles() throws {
        let context = try makeContext()
        let store = FeedStore(context: context)
        let stale = Article(
            id: "guid-1",
            feedID: "test.feed",
            title: "Titre p&#233;rim&#233;",
            summary: "Chapô l&#8217;ancien",
            link: URL(string: "https://example.com/article")!,
            imageURL: URL(string: "http://example.com/ancienne.png"),
            publishedAt: Date(),
            fetchedAt: Date()
        )
        context.insert(stale)

        let inserted = try store.ingest([parsed()], feedID: "test.feed")

        XCTAssertTrue(inserted.isEmpty, "Un article connu ne doit pas être signalé comme nouveau")
        XCTAssertEqual(stale.title, "Titre à jour")
        XCTAssertEqual(stale.summary, "Chapô à jour")
        XCTAssertEqual(stale.imageURL, URL(string: "https://example.com/neuve.png"))
    }

    /// L'état utilisateur n'appartient pas au flux et doit survivre au réalignement.
    func testRefreshPreservesUserState() throws {
        let context = try makeContext()
        let store = FeedStore(context: context)
        let existing = Article(
            id: "guid-1",
            feedID: "test.feed",
            title: "Ancien titre",
            summary: "Ancien chapô",
            link: URL(string: "https://example.com/article")!,
            publishedAt: Date(),
            fetchedAt: Date()
        )
        existing.isRead = true
        existing.isFavorite = true
        context.insert(existing)

        _ = try store.ingest([parsed()], feedID: "test.feed")

        XCTAssertTrue(existing.isRead)
        XCTAssertTrue(existing.isFavorite)
        XCTAssertEqual(existing.link, URL(string: "https://example.com/article"))
    }

    func testRefreshIsANoOpWhenNothingChanged() throws {
        let context = try makeContext()
        let store = FeedStore(context: context)
        try store.ingest([parsed()], feedID: "test.feed")
        let again = try store.ingest([parsed()], feedID: "test.feed")
        XCTAssertTrue(again.isEmpty)
        let all = try context.fetch(FetchDescriptor<Article>())
        XCTAssertEqual(all.count, 1)
    }

    /// Le cas Calipia : la ligne en base porte le `guid` en `https`, la rubrique qui
    /// rafraîchit sert le même article avec le `guid` en `http`. Sans normalisation du
    /// schéma côté `ingest`, aucun rapprochement n'a lieu : une seconde ligne est insérée,
    /// puis `pruneDuplicates` — qui garde la plus ancienne — supprime justement celle qui
    /// portait l'image corrigée.
    func testRefreshesAcrossGuidSchemeVariants() throws {
        let context = try makeContext()
        let store = FeedStore(context: context)
        let stale = Article(
            id: "https://example.com/?p=1",
            feedID: "calipia.blog",
            title: "Ancien titre",
            summary: "Ancien chapô",
            link: URL(string: "https://example.com/article")!,
            imageURL: URL(string: "http://example.com/ancienne.png"),
            publishedAt: Date(),
            fetchedAt: Date().addingTimeInterval(-3600)
        )
        context.insert(stale)
        try context.save()

        let incoming = ParsedArticle(
            id: "http://example.com/?p=1",
            title: "Titre à jour",
            summary: "Chapô à jour",
            link: URL(string: "http://example.com/article")!,
            imageURL: URL(string: "https://example.com/neuve.png"),
            publishedAt: Date()
        )
        try store.ingest([incoming], feedID: "calipia.ia")
        try store.prune()

        let survivors = try context.fetch(FetchDescriptor<Article>())
        XCTAssertEqual(survivors.count, 1, "Les deux écritures du même article doivent n'en faire qu'une")
        XCTAssertEqual(
            survivors.first?.imageURL,
            URL(string: "https://example.com/neuve.png"),
            "La ligne survivante doit porter l'image corrigée, pas l'ancienne en http"
        )
    }

    /// Un même article servi par deux rubriques d'une même source (la « une » d'un
    /// journal reprend forcément ses rubriques) n'est stocké qu'une fois : `Article`
    /// ne porte qu'un `feedID`, celui de la rubrique qui l'a vu en premier. Documente
    /// le comportement réel avant d'en tirer une conclusion sur le catalogue.
    func testArticleSharedByTwoFeedsIsStoredUnderTheFirstOnly() throws {
        let context = try makeContext()
        let store = FeedStore(context: context)

        try store.ingest([parsed()], feedID: "lopinion.une")
        try store.ingest([parsed()], feedID: "lopinion.politique")

        XCTAssertEqual(try store.articles(feedID: "lopinion.une").count, 1)
        XCTAssertEqual(try store.articles(feedID: "lopinion.politique").count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Article>()).count, 1)
    }
}
