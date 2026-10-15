import XCTest
@testable import NumPatch

final class RecognitionSettingsTests: XCTestCase {
    func testSettingsRoundTripAndRejectInvalidInput() throws {
        let defaults = RecognitionSettings()
        XCTAssertTrue(defaults.valid)
        XCTAssertEqual(try JSONDecoder().decode(RecognitionSettings.self,
            from: JSONEncoder().encode(defaults)), defaults)
        for invalid in [Double.nan, Double.infinity, -1, 500] {
            var settings = defaults
            settings.minimumMS = invalid
            XCTAssertFalse(settings.valid)
        }
        var settings = defaults
        settings.movement = 0
        XCTAssertFalse(settings.valid)
        settings = defaults; settings.maximumMS = 100
        XCTAssertFalse(settings.valid)
    }
}
