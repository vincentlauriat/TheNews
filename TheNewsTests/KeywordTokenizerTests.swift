import XCTest
@testable import TheNews

final class KeywordTokenizerTests: XCTestCase {
    func testAddsTrimmedKeyword() {
        XCTAssertEqual(KeywordTokenizer.add("  écologie  ", to: []), .added(["écologie"]))
    }

    func testRejectsEmptyKeyword() {
        XCTAssertEqual(KeywordTokenizer.add("   ", to: ["climat"]), .empty)
    }

    func testRejectsDuplicateIgnoringCaseAndAccents() {
        XCTAssertEqual(KeywordTokenizer.add("ECOLOGIE", to: ["écologie"]), .duplicate)
    }

    func testAllowsDistinctKeyword() {
        XCTAssertEqual(KeywordTokenizer.add("climat", to: ["écologie"]), .added(["écologie", "climat"]))
    }

    func testAddAllSplitsCommaSeparatedPaste() {
        let result = KeywordTokenizer.addAll("ia, robotique, ia", to: [])
        XCTAssertEqual(result, ["ia", "robotique"])
    }

    func testAddAllIgnoresBlankSegments() {
        let result = KeywordTokenizer.addAll("ia,, robotique,", to: [])
        XCTAssertEqual(result, ["ia", "robotique"])
    }
}
