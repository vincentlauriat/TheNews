import XCTest
import SwiftData
@testable import TheNews

@MainActor
final class BriefingEngineTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Article.self, FeedSubscription.self, WatchTopic.self, CustomFeed.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    @discardableResult
    private func insertArticle(
        _ context: ModelContext, id: String, feedID: String, title: String, summary: String = "",
        hoursAgo: Double = 1
    ) -> Article {
        let article = Article(
            id: id, feedID: feedID, title: title, summary: summary,
            link: URL(string: "https://example.com/\(id)")!,
            publishedAt: Date().addingTimeInterval(-hoursAgo * 3600),
            fetchedAt: Date()
        )
        context.insert(article)
        return article
    }

    func testEmptyWithoutSubscriptions() throws {
        let context = try makeContext()
        insertArticle(context, id: "1", feedID: "lemonde.une", title: "Un article")
        try context.save()
        XCTAssertTrue(BriefingEngine.today(context: context).isEmpty)
    }

    func testExcludesArticlesOlderThanWindow() throws {
        let context = try makeContext()
        context.insert(FeedSubscription(feedID: "lemonde.une"))
        insertArticle(context, id: "old", feedID: "lemonde.une", title: "Vieil article", hoursAgo: 48)
        insertArticle(context, id: "new", feedID: "lemonde.une", title: "Article récent", hoursAgo: 1)
        try context.save()
        XCTAssertEqual(BriefingEngine.today(context: context).map(\.id), ["new"])
    }

    func testDedupsCrossSourceSimilarArticles() throws {
        let context = try makeContext()
        context.insert(FeedSubscription(feedID: "lemonde.une"))
        context.insert(FeedSubscription(feedID: "lesechos.economie"))
        insertArticle(
            context, id: "lemonde-1", feedID: "lemonde.une",
            title: "Le gouvernement annonce une réforme des retraites"
        )
        insertArticle(
            context, id: "lesechos-1", feedID: "lesechos.economie",
            title: "Réforme des retraites annoncée par le gouvernement"
        )
        insertArticle(
            context, id: "unrelated", feedID: "lemonde.une",
            title: "Une exposition artistique ouvre ses portes dans la capitale"
        )
        try context.save()
        let result = BriefingEngine.today(context: context)
        // Les deux articles sur la réforme sont quasi-identiques (cross-source) : un seul gardé.
        let reformCount = result.filter { $0.id == "lemonde-1" || $0.id == "lesechos-1" }.count
        XCTAssertEqual(reformCount, 1)
        XCTAssertTrue(result.contains { $0.id == "unrelated" })
    }

    func testPrioritizesArticlesMatchingActiveWatchTopic() throws {
        let context = try makeContext()
        context.insert(FeedSubscription(feedID: "lemonde.une"))
        context.insert(WatchTopic(label: "Écologie", keywords: ["climat"]))
        insertArticle(context, id: "a", feedID: "lemonde.une", title: "Actualité générale", hoursAgo: 1)
        insertArticle(context, id: "b", feedID: "lemonde.une", title: "Le climat au centre des débats", hoursAgo: 2)
        try context.save()
        XCTAssertEqual(BriefingEngine.today(context: context).first?.id, "b")
    }

    func testRespectsLimit() throws {
        let context = try makeContext()
        context.insert(FeedSubscription(feedID: "lemonde.une"))
        let topics = [
            "Une avancée majeure en intelligence artificielle bouleverse le secteur technologique",
            "Le marché immobilier parisien traverse une période de turbulences économiques",
            "Une expédition scientifique explore les profondeurs inconnues de l'océan Pacifique",
            "Le championnat sportif national attire des foules record dans les stades",
            "Une exposition artistique contemporaine ouvre ses portes dans la capitale",
        ]
        for (i, title) in topics.enumerated() {
            insertArticle(context, id: "\(i)", feedID: "lemonde.une", title: title, hoursAgo: Double(i))
        }
        try context.save()
        XCTAssertEqual(BriefingEngine.today(context: context, limit: 2).count, 2)
    }
}
