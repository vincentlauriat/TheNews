import XCTest
@testable import TheNews

/// Teste `normalize`/`sentences` : le post-traitement **déterministe** ajouté pour compenser le
/// petit modèle on-device qui ne respecte pas toujours les consignes de format (cf. `PLAN.md`
/// Phase F, § digest). Ne teste pas `digest()`/`oneLiner()` (nécessitent Foundation Models sur
/// l'appareil de test, indisponible en CI).
final class ArticleSummarizerTests: XCTestCase {
    func testNormalizeKeepsBulletsWhenAlreadyBulletedAndTruncatesToTargetCount() {
        let text = "- Thème un\n- Thème deux\n- Thème trois\n- Thème quatre"
        let result = ArticleSummarizer.normalize(text, length: .concise, format: .bullets)
        let lines = result.split(separator: "\n")
        XCTAssertEqual(lines.count, 3)   // .concise → 3 thèmes max
        XCTAssertEqual(lines.first, "- Thème un")
    }

    func testNormalizeConvertsParagraphToBulletsWhenBulletsRequested() {
        let text = "Premier thème important. Deuxième thème notable. Troisième thème à suivre. Un quatrième."
        let result = ArticleSummarizer.normalize(text, length: .concise, format: .bullets)
        let lines = result.split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines.allSatisfy { $0.hasPrefix("- ") })
    }

    func testNormalizeStripsBulletsWhenParagraphRequested() {
        let text = "- Thème un\n- Thème deux\n- Thème trois"
        let result = ArticleSummarizer.normalize(text, length: .concise, format: .paragraph)
        XCTAssertFalse(result.contains("- "))
        XCTAssertTrue(result.contains("Thème un"))
        XCTAssertTrue(result.contains("Thème deux"))
    }

    func testNormalizeDetailedKeepsUpToSixBullets() {
        let text = (1...8).map { "- Thème \($0)" }.joined(separator: "\n")
        let result = ArticleSummarizer.normalize(text, length: .detailed, format: .bullets)
        XCTAssertEqual(result.split(separator: "\n").count, 6)
    }

    func testSentencesSplitsOnPunctuationAndNewlines() {
        let sentences = ArticleSummarizer.sentences(of: "Un. Deux! Trois? Quatre\nCinq.")
        XCTAssertEqual(sentences, ["Un", "Deux", "Trois", "Quatre", "Cinq"])
    }
}
