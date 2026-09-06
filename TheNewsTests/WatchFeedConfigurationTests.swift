import XCTest
@testable import TheNews

final class WatchFeedConfigurationTests: XCTestCase {
    func testDefaultSelectionUsesFrontPageFeeds() {
        XCTAssertEqual(
            WatchFeedConfiguration.defaultFeedIDs,
            ["lemonde.une", "lesechos.economie"]
        )
    }

    func testSanitizingSelectionRemovesUnknownFeedsAndDuplicates() {
        let sanitized = WatchFeedConfiguration.sanitizedFeedIDs([
            "unknown.feed",
            "lesechos.finance",
            "lesechos.finance",
            "lemonde.politique"
        ])

        XCTAssertEqual(sanitized, ["lesechos.finance", "lemonde.politique"])
    }

    func testSanitizingEmptySelectionFallsBackToDefaults() {
        XCTAssertEqual(
            WatchFeedConfiguration.sanitizedFeedIDs([]),
            WatchFeedConfiguration.defaultFeedIDs
        )
    }

    /// Le pendant watchOS de `WatchFeedConfiguration` dérive sa liste des catalogues
    /// alors que celui-ci la code en dur. Les deux `sanitizedFeedIDs` écartent
    /// silencieusement ce que l'autre autorise : une divergence ne lèverait aucune
    /// erreur, elle empêcherait juste un flux d'arriver sur la montre. Ce test est
    /// le garde-fou — il échoue dès qu'une source est ajoutée au catalogue sans
    /// être ajoutée ici.
    func testAllowedFeedIDsMirrorBuiltInCatalog() {
        XCTAssertEqual(
            WatchFeedConfiguration.allowedFeedIDs,
            Set(Feed.builtInCatalog.map(\.id))
        )
    }
}
