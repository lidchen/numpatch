import XCTest
@testable import NumPatch
final class RecognizerTests: XCTestCase {
    func contact(_ x: Double = 0.5, _ y: Double = 0.5, id: Int32 = 1) -> Contact {
        Contact(id: id, x: x, y: y, pressure: 0, area: 0)
    }
    func testTapAndCoordinates() {
        var r = TapRecognizer()
        XCTAssertNil(r.update([contact(0.1, 0.9)], at: 10))
        let result = r.update([], at: 10.1)
        XCTAssertEqual(result?.kind, "轻触候选")
        XCTAssertEqual(result?.key, "7")
        XCTAssertEqual(TapRecognizer.key(x: 1, y: 0), "3")
        XCTAssertEqual(TapRecognizer.key(x: 0, y: 1), "7")
    }
    func testNineKeyGrid() {
        for row in 0..<3 {
            for column in 0..<3 {
                XCTAssertEqual(TapRecognizer.key(x: (Double(column) + 0.5) / 3,
                    y: 1 - (Double(row) + 0.5) / 3), TapRecognizer.keys[row][column])
            }
        }
        XCTAssertEqual(TapRecognizer.key(x: -0.1, y: 1.1), "7")
        XCTAssertEqual(TapRecognizer.key(x: 1.1, y: -0.1), "3")
    }
    func testMovementUsesMaximumExcursion() {
        var r = TapRecognizer()
        _ = r.update([contact()], at: 0)
        _ = r.update([contact(0.6)], at: 0.05)
        _ = r.update([contact()], at: 0.08)
        XCTAssertEqual(r.update([], at: 0.1)?.kind, "滑动")
    }
    func testMultifingerSequenceCannotBecomeTap() {
        var r = TapRecognizer()
        _ = r.update([contact()], at: 0)
        _ = r.update([contact(), contact(0.8, id: 2)], at: 0.03)
        _ = r.update([contact()], at: 0.07)
        XCTAssertEqual(r.update([], at: 0.1)?.kind, "多指手势")
    }
    func testClickAndHeldButtonCancelTap() {
        var r = TapRecognizer()
        _ = r.update([contact()], at: 0)
        r.markClick()
        XCTAssertEqual(r.update([], at: 0.1)?.kind, "鼠标点击（来源待判定）")
        _ = r.update([contact()], at: 1, mouseDown: true)
        XCTAssertEqual(r.update([], at: 1.1)?.kind, "鼠标点击（来源待判定）")
    }
    func testDurationAndReset() {
        var r = TapRecognizer()
        _ = r.update([contact()], at: 0)
        XCTAssertEqual(r.update([], at: 0.01)?.kind, "过短接触")
        _ = r.update([contact()], at: 1)
        XCTAssertEqual(r.update([], at: 1.5)?.kind, "长按 / 停留")
        _ = r.update([contact()], at: 2)
        r.reset()
        XCTAssertNil(r.update([], at: 2.1))
    }
    func testIdentityChangeCancelsTap() {
        var r = TapRecognizer()
        _ = r.update([contact()], at: 0)
        _ = r.update([contact(id: 2)], at: 0.05)
        XCTAssertEqual(r.update([], at: 0.1)?.kind, "触点变化")
    }
}
