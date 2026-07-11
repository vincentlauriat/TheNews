import XCTest
@testable import TheNews

@MainActor
final class RelatedArticlesEngineTests: XCTestCase {
    func testTokensFiltersStopWordsAndShortWords() {
        let tokens = RelatedArticlesEngine.tokens("Le gouvernement annonce une réforme des retraites")
        XCTAssertTrue(tokens.contains("gouvernement"))
        XCTAssertTrue(tokens.contains("annonce"))
        XCTAssertTrue(tokens.contains("reforme"))
        XCTAssertTrue(tokens.contains("retraites"))
        XCTAssertFalse(tokens.contains("des"))   // trop court (< 4 lettres)
        XCTAssertFalse(tokens.contains("une"))   // trop court
    }

    func testTokensNormalizesAccentsAndCase() {
        let a = RelatedArticlesEngine.tokens("Réforme des retraites")
        let b = RelatedArticlesEngine.tokens("reforme DES RETRAITES")
        XCTAssertEqual(a, b)
    }

    func testSimilarityRequiresAtLeastTwoSharedWords() {
        let a: Set<String> = ["reforme", "retraites"]
        let b: Set<String> = ["reforme"]
        XCTAssertEqual(RelatedArticlesEngine.similarity(a, b), 0)
    }

    func testSimilarityJaccardScore() {
        let a: Set<String> = ["reforme", "retraites", "gouvernement"]
        let b: Set<String> = ["reforme", "retraites", "opposition"]
        // intersection = 2 (reforme, retraites), union = 4 → 0.5
        XCTAssertEqual(RelatedArticlesEngine.similarity(a, b), 0.5, accuracy: 0.001)
    }

    func testSimilarityIsZeroForEmptySets() {
        XCTAssertEqual(RelatedArticlesEngine.similarity([], ["motcle"]), 0)
    }
}
