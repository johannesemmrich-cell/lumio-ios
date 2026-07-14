import XCTest
@testable import Sunwake

final class SunwakeTests: XCTestCase {
    func testCalendarEventEquality() throws {
        // Placeholder: add real unit tests as features are built
        XCTAssertTrue(true)
    }

    // MARK: — AIService.sanitizeModelOutput

    func testSanitizeModelOutputStripsEmphasisMarkers() throws {
        let raw = "**Guten Nachmittag!** Du hast __heute__ **0 Ereignisse**."
        XCTAssertEqual(
            AIService.sanitizeModelOutput(raw),
            "Guten Nachmittag! Du hast heute 0 Ereignisse."
        )
    }

    func testSanitizeModelOutputNormalizesListsHeadersAndNewlines() throws {
        let raw = "## Dein Tag\n\n\n\n* Termin um 9\n- Erinnerung: Milch kaufen\n"
        XCTAssertEqual(
            AIService.sanitizeModelOutput(raw),
            "Dein Tag\n\n• Termin um 9\n• Erinnerung: Milch kaufen"
        )
    }
}
