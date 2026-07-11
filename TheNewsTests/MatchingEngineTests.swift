import XCTest
@testable import TheNews

final class MatchingEngineTests: XCTestCase {
    private func makeArticle(title: String, summary: String = "") -> Article {
        Article(
            id: UUID().uuidString,
            feedID: "lemonde.une",
            title: title,
            summary: summary,
            link: URL(string: "https://example.com")!,
            publishedAt: Date(),
            fetchedAt: Date()
        )
    }

    private func makeTopic(_ keywords: [String], isEnabled: Bool = true) -> WatchTopic {
        WatchTopic(label: "Test", keywords: keywords, isEnabled: isEnabled)
    }

    func testNormalizeStripsAccentsAndCase() {
        XCTAssertEqual(MatchingEngine.normalize("Écologie"), MatchingEngine.normalize("ecologie"))
        XCTAssertEqual(MatchingEngine.normalize("ÉLECTION"), MatchingEngine.normalize("election"))
    }

    func testMatchesOnTitleIgnoringAccentsAndCase() {
        let article = makeArticle(title: "L'Écologie s'invite au sommet international")
        let topic = makeTopic(["ecologie"])
        XCTAssertTrue(MatchingEngine.isMatch(article, topics: [topic]))
    }

    func testMatchesOnSummaryToo() {
        let article = makeArticle(title: "Sans rapport", summary: "Un article sur le climat")
        let topic = makeTopic(["climat"])
        XCTAssertTrue(MatchingEngine.isMatch(article, topics: [topic]))
    }

    func testNoMatchWhenKeywordAbsent() {
        let article = makeArticle(title: "Rien à voir")
        let topic = makeTopic(["football"])
        XCTAssertFalse(MatchingEngine.isMatch(article, topics: [topic]))
    }

    func testDisabledTopicNeverMatches() {
        let article = makeArticle(title: "Écologie et climat")
        let topic = makeTopic(["climat"], isEnabled: false)
        XCTAssertFalse(MatchingEngine.isMatch(article, topics: [topic]))
    }

    func testBlankKeywordNeverMatches() {
        let article = makeArticle(title: "Un article quelconque")
        let topic = makeTopic(["   "])
        XCTAssertFalse(MatchingEngine.isMatch(article, topics: [topic]))
    }
}
