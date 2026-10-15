import XCTest
@testable import NumPatch

final class TakeoverTests: XCTestCase {
    let tap = MouseSignature(subtype: 3, pressure: 0)
    let press = MouseSignature(subtype: 3, pressure: 1)
    func testDisabledModeSkipsRecognitionAndCannotEnableWhileTouching() {
        let engine = prepared()
        _ = engine.setEnabled(false)
        XCTAssertNil(engine.frame([Contact(id: 1, x: 0.5, y: 0.5, pressure: 0, area: 0)], at: 1))
        XCTAssertFalse(engine.setEnabled(true))
        XCTAssertNil(engine.frame([], at: 1.1))
        XCTAssertTrue(engine.setEnabled(true))
        candidate(engine)
        let down = engine.mouse(isLeft: true, isDown: true, number: 80, signature: tap,
            at: 10.11, targetPID: 123, explain: false)
        XCTAssertTrue(down.0); XCTAssertEqual(down.1, "5"); XCTAssertTrue(down.3.isEmpty)
        XCTAssertTrue(engine.mouse(isLeft: true, isDown: false, number: 80,
            signature: tap, at: 10.12, targetPID: 123, explain: false).0)
    }
    func prepared() -> TakeoverEngine {
        let engine = TakeoverEngine()
        engine.setActive(true); engine.setFrontPID(123)
        for kind in [ClickCalibration.Kind.tap, .press] {
            engine.beginCalibration(kind, at: 0)
            for i in 0..<3 {
                _ = engine.mouse(isLeft: true, isDown: true, number: Int64(i),
                    signature: kind == .tap ? tap : press, at: Double(i + 1), targetPID: 123)
            }
        }
        XCTAssertTrue(engine.setEnabled(true))
        return engine
    }
    func candidate(_ engine: TakeoverEngine, multi: Bool = false) {
        let a = Contact(id: 1, x: 0.5, y: 0.5, pressure: 0, area: 0)
        let b = Contact(id: 2, x: 0.6, y: 0.5, pressure: 0, area: 0)
        engine.frame(multi ? [a, b] : [a], at: 10)
        engine.frame([], at: 10.1)
    }
    func regionCandidate(_ engine: TakeoverEngine, x: Double = 0.5) -> GestureResult {
        engine.frame([Contact(id: 1, x: x, y: 0.02, pressure: 0, area: 0)], at: 10)
        return engine.frame([], at: 10.08)!
    }
    func testSessionDestinationResolutionPreservesExplicitTargetsAndExcludesSettings() {
        let engine = prepared()
        XCTAssertEqual(engine.eventTarget(0, ownPID: 999), 123)
        XCTAssertEqual(engine.eventTarget(456, ownPID: 999), 456)
        XCTAssertEqual(engine.eventTarget(999, ownPID: 999), 0)
        engine.setFrontPID(999)
        XCTAssertEqual(engine.eventTarget(0, ownPID: 999), 0)
        engine.setFrontPID(0)
        XCTAssertEqual(engine.eventTarget(0, ownPID: 999), 0)
    }
    func testNativeRightButtonCancelsCornerFallbackWithoutGeneratingKeys() {
        let engine = prepared()
        let gesture = regionCandidate(engine)
        engine.nativeMouseButtonDown()
        XCTAssertNil(engine.regionFallback(for: gesture, at: 10.27, ownPID: 999, canEmit: true))
        XCTAssertFalse(engine.mouse(isLeft: true, isDown: true, number: 100,
            signature: tap, at: 10.09, targetPID: 123).0)
    }
    func testTwoFingerCornerGestureCannotEmitFallbackOrNumericKey() {
        let engine = prepared()
        let a = Contact(id: 1, x: 0.49, y: 0.04, pressure: 0, area: 0)
        let b = Contact(id: 2, x: 0.51, y: 0.04, pressure: 0, area: 0)
        engine.frame([a], at: 10)
        engine.frame([a, b], at: 10.02)
        engine.frame([a], at: 10.05)
        let gesture = engine.frame([], at: 10.08)!
        XCTAssertEqual(gesture.kind, "多指手势")
        XCTAssertNil(engine.regionFallback(for: gesture, at: 10.27, ownPID: 999, canEmit: true))
        XCTAssertFalse(engine.mouse(isLeft: true, isDown: true, number: 100,
            signature: tap, at: 10.09, targetPID: 123).0)
    }
    func testEdgeAndCornerWithoutSystemClickEmitsOnceAndSwallowsLateClickPair() {
        for (x, key) in [(0.5, "0"), (0.98, ".")] {
            let engine = prepared()
            let gesture = regionCandidate(engine, x: x)
            XCTAssertNil(engine.regionFallback(for: gesture, at: 10.09, ownPID: 999, canEmit: true))
            let output = engine.regionFallback(for: gesture, at: 10.27, ownPID: 999, canEmit: true)
            XCTAssertEqual(output?.key, key); XCTAssertEqual(output?.pid, 123)
            XCTAssertNil(engine.regionFallback(for: gesture, at: 10.28, ownPID: 999, canEmit: true))
            let late = engine.mouse(isLeft: true, isDown: true, number: 90, signature: tap,
                at: 10.085, targetPID: 123, receivedAt: 10.29)
            XCTAssertTrue(late.0); XCTAssertNil(late.1)
            XCTAssertTrue(engine.mouse(isLeft: true, isDown: false, number: 90,
                signature: tap, at: 10.30, targetPID: 123).0)
        }
    }
    func testNormalRegionClickPreventsFallback() {
        let engine = prepared(); let gesture = regionCandidate(engine)
        let down = engine.mouse(isLeft: true, isDown: true, number: 90, signature: tap,
            at: 10.085, targetPID: 123)
        XCTAssertTrue(down.0); XCTAssertEqual(down.1, "0")
        _ = engine.mouse(isLeft: true, isDown: false, number: 90, signature: tap,
            at: 10.09, targetPID: 123)
        XCTAssertNil(engine.regionFallback(for: gesture, at: 10.27, ownPID: 999, canEmit: true))
    }
    func testRegionFallbackCancelsOnInputFocusModeOrPermissionChange() {
        for scenario in 0..<8 {
            let engine = prepared(); let gesture = regionCandidate(engine)
            switch scenario {
            case 0: engine.setFrontPID(456)
            case 1: _ = engine.setEnabled(false)
            case 2: engine.setActive(false)
            case 3: engine.frame([Contact(id: 2, x: 0.05, y: 0.05, pressure: 0, area: 0)], at: 10.2)
            case 4: _ = engine.mouse(isLeft: false, isDown: true, number: 91, signature: tap, at: 10.1, targetPID: 123)
            default: break
            }
            XCTAssertNil(engine.regionFallback(for: gesture, at: scenario == 7 ? 11 : 10.27,
                ownPID: scenario == 5 ? 123 : 999, canEmit: scenario != 6))
        }
    }
    func testOrdinaryGridWithoutSystemClickEmitsButPhysicalPressDoesNot() {
        let grid = prepared(); candidate(grid)
        let ordinary = GestureResult(kind: "轻触候选", key: "5", duration: 0.1,
            movement: 0, fingers: 1, ended: 10.1)
        XCTAssertEqual(grid.regionFallback(for: ordinary, at: 10.13, ownPID: 999, canEmit: true)?.key, "5")
        let engine = prepared()
        engine.frame([Contact(id: 1, x: 0.5, y: 0.02, pressure: 0, area: 0)], at: 10)
        XCTAssertFalse(engine.mouse(isLeft: true, isDown: true, number: 92,
            signature: press, at: 10.04, targetPID: 123).0)
        let gesture = engine.frame([], at: 10.08)!
        XCTAssertNil(engine.regionFallback(for: gesture, at: 10.27, ownPID: 999, canEmit: true))
    }
    func testUnassignedEdgesAndCornersEmitOriginalGridWithoutSystemClick() {
        for zone in PadLayout.Zone.allCases {
            let engine = prepared()
            var layout = PadLayout(); layout.bindings = [:]
            engine.configure(layout: layout, minimum: 0.025, maximum: 0.220, movement: 0.025)
            let point = zone.center
            engine.frame([Contact(id: 1, x: point.x, y: point.y, pressure: 0, area: 0)], at: 10)
            let gesture = engine.frame([], at: 10.06)!
            XCTAssertEqual(gesture.kind, "轻触候选")
            XCTAssertFalse(gesture.isCustomRegion)
            let expected = TapRecognizer.key(x: point.x, y: point.y)
            XCTAssertEqual(engine.regionFallback(for: gesture, at: 10.09,
                ownPID: 999, canEmit: true)?.key, expected)
            XCTAssertNil(engine.regionFallback(for: gesture, at: 10.10, ownPID: 999, canEmit: true))
            let late = engine.mouse(isLeft: true, isDown: true, number: 90, signature: tap,
                at: 10.065, targetPID: 123, receivedAt: 10.11)
            XCTAssertTrue(late.0); XCTAssertNil(late.1)
            XCTAssertTrue(engine.mouse(isLeft: true, isDown: false, number: 90,
                signature: tap, at: 10.12, targetPID: 123).0)
        }
    }
    func testConsecutiveGridTapsWithoutMouseClicksCanBothEmit() {
        let engine = prepared()
        for index in 0..<3 {
            let start = 10 + Double(index) * 0.12
            engine.frame([Contact(id: Int32(index + 1), x: 0.02, y: 0.98, pressure: 0, area: 0)], at: start)
            let gesture = engine.frame([], at: start + 0.05)!
            XCTAssertEqual(engine.regionFallback(for: gesture, at: start + 0.08,
                ownPID: 999, canEmit: true)?.key, "7")
        }
    }
    func testBackdatedDriverTimestampMatchesWholeGesture() {
        let engine = prepared(); candidate(engine)
        let decision = engine.mouse(isLeft: true, isDown: true, number: 90, signature: tap,
            at: 10.02, targetPID: 123, receivedAt: 10.11)
        XCTAssertTrue(decision.0); XCTAssertEqual(decision.1, "5")
        let stale = prepared(); candidate(stale)
        XCTAssertFalse(stale.mouse(isLeft: true, isDown: true, number: 91, signature: tap,
            at: 10.02, targetPID: 123, receivedAt: 10.5).0)
    }
    func testRecordedFastTapsAreTakenOverButBriefNoiseIsNot() {
        // Use the identical subtype/pressure seen for real taps and presses;
        // contact state at mouse-down supplies the distinguishing signal.
        var profile = ClickCalibration()
        var released = MouseSignature(subtype: 3, pressure: 1)
        released.released = true
        var touching = released
        touching.released = false
        profile.taps = Array(repeating: released, count: 3)
        profile.presses = Array(repeating: touching, count: 3)
        for milliseconds in [8, 16, 31, 32, 39, 40, 44, 47, 48, 55, 56, 79] {
            let engine = TakeoverEngine()
            engine.setActive(true); engine.setFrontPID(123)
            XCTAssertTrue(engine.restoreCalibration(profile))
            XCTAssertTrue(engine.setEnabled(true))
            let end = 10 + Double(milliseconds) / 1000
            engine.frame([Contact(id: 1, x: 0.5, y: 0.5, pressure: 0, area: 0)], at: 10)
            engine.frame([], at: end)
            let down = engine.mouse(isLeft: true, isDown: true, number: 42,
                signature: released, at: end + 0.003, targetPID: 123)
            XCTAssertEqual(down.0, milliseconds >= 25, "duration: \(milliseconds) ms")
            XCTAssertEqual(down.1, milliseconds >= 25 ? "5" : nil)
            let up = engine.mouse(isLeft: true, isDown: false, number: 42,
                signature: released, at: end + 0.007, targetPID: 123)
            XCTAssertEqual(up.0, down.0)
        }
    }
    func testPhysicalPressWhileTouchingHasExplicitReason() {
        let engine = prepared()
        _ = engine.frame([Contact(id: 1, x: 0.5, y: 0.5, pressure: 0, area: 0)], at: 10)
        let decision = engine.mouse(isLeft: true, isDown: true, number: 90, signature: press,
            at: 10.1, targetPID: 123)
        XCTAssertFalse(decision.0)
        XCTAssertTrue(decision.3.contains("仍有 1 个触点"))
    }
    func testSingleTapOutputAndPairedUpAfterDisable() {
        let engine = prepared(); candidate(engine)
        let down = engine.mouse(isLeft: true, isDown: true, number: 42, signature: tap, at: 10.11, targetPID: 123)
        XCTAssertTrue(down.0); XCTAssertEqual(down.1, "5")
        _ = engine.setEnabled(false)
        XCTAssertTrue(engine.hasSuppressedDown)
        XCTAssertTrue(engine.suppressDrag(number: 42))
        XCTAssertFalse(engine.suppressDrag(number: 43))
        XCTAssertTrue(engine.mouse(isLeft: true, isDown: false, number: 42, signature: tap, at: 10.12, targetPID: 123).0)
        XCTAssertFalse(engine.hasSuppressedDown)
        XCTAssertFalse(engine.mouse(isLeft: true, isDown: true, number: 43, signature: tap, at: 10.13, targetPID: 123).0)
    }
    func testRightClickPhysicalAndUnknownSourcesPass() {
        for (left, signature) in [(false, tap), (true, press), (true, MouseSignature(subtype: 0, pressure: 0))] {
            let engine = prepared(); candidate(engine)
            XCTAssertFalse(engine.mouse(isLeft: left, isDown: true, number: 5, signature: signature, at: 10.11, targetPID: 123).0)
        }
    }
    func testMultifingerStaleAndFocusChangesPass() {
        let multi = prepared(); candidate(multi, multi: true)
        XCTAssertFalse(multi.mouse(isLeft: true, isDown: true, number: 1, signature: tap, at: 10.11, targetPID: 123).0)
        let stale = prepared(); candidate(stale)
        XCTAssertFalse(stale.mouse(isLeft: true, isDown: true, number: 1, signature: tap, at: 11, targetPID: 123).0)
        let focus = prepared(); candidate(focus); focus.setFrontPID(456)
        XCTAssertFalse(focus.mouse(isLeft: true, isDown: true, number: 1, signature: tap, at: 10.11, targetPID: 456).0)
        let target = prepared(); candidate(target)
        XCTAssertFalse(target.mouse(isLeft: true, isDown: true, number: 1, signature: tap, at: 10.11, targetPID: 456).0)
    }
    func testSamePressureCanUseCalibratedContactPhase() {
        let engine = TakeoverEngine(); engine.setActive(true); engine.setFrontPID(123)
        let point = Contact(id: 1, x: 0.5, y: 0.5, pressure: 0, area: 0)
        for kind in [ClickCalibration.Kind.tap, .press] {
            engine.beginCalibration(kind, at: 0)
            for i in 0..<3 {
                if kind == .press { engine.frame([point], at: Double(i + 1)) }
                _ = engine.mouse(isLeft: true, isDown: true, number: Int64(i), signature: press,
                    at: Double(i + 1), targetPID: 123)
                engine.frame([], at: Double(i + 1) + 0.1)
            }
        }
        XCTAssertTrue(engine.calibrationSummary.2)
        XCTAssertTrue(engine.setEnabled(true)); candidate(engine)
        XCTAssertTrue(engine.mouse(isLeft: true, isDown: true, number: 10, signature: press,
            at: 10.11, targetPID: 123).0)
    }
    func testRestoreRecordedCalibrationWithoutEnablingMode() throws {
        let data = Data("""
        {"taps":[{"subtype":3,"pressure":1000,"released":true},{"subtype":3,"pressure":1000,"released":true},{"subtype":3,"pressure":1000,"released":true}],
         "presses":[{"subtype":3,"pressure":1000,"released":false},{"subtype":3,"pressure":1000,"released":false},{"subtype":3,"pressure":1000,"released":false}]}
        """.utf8)
        let profile = try JSONDecoder().decode(ClickCalibration.self, from: data)
        XCTAssertTrue(profile.validForImport)
        let engine = TakeoverEngine(); engine.setActive(true); engine.setFrontPID(123)
        XCTAssertTrue(engine.restoreCalibration(profile)); candidate(engine)
        XCTAssertFalse(engine.mouse(isLeft: true, isDown: true, number: 101, signature: press,
            at: 10.11, targetPID: 123).0)
        XCTAssertTrue(engine.setEnabled(true)); candidate(engine)
        let decision = engine.mouse(isLeft: true, isDown: true, number: 102, signature: press,
            at: 10.11, targetPID: 123)
        XCTAssertTrue(decision.0); XCTAssertEqual(decision.1, "5")
        var invalid = profile; invalid.presses = invalid.taps
        XCTAssertFalse(engine.restoreCalibration(invalid))
    }
    func testCalibrationExcludesButtonsOutsideTargetAndDuplicateEvents() {
        let engine = TakeoverEngine()
        engine.beginCalibration(.tap, at: 0, area: CGRect(x: 100, y: 100, width: 200, height: 150))
        XCTAssertFalse(engine.mouse(isLeft: true, isDown: true, number: 1, signature: tap,
            at: 1, targetPID: 123, location: CGPoint(x: 50, y: 50)).2)
        XCTAssertEqual(engine.calibrationSummary.0, 0)
        XCTAssertTrue(engine.mouse(isLeft: true, isDown: true, number: 2, signature: tap,
            at: 2, targetPID: 123, location: CGPoint(x: 150, y: 150)).2)
        XCTAssertFalse(engine.mouse(isLeft: true, isDown: true, number: 2, signature: tap,
            at: 2.1, targetPID: 123, location: CGPoint(x: 150, y: 150)).2)
        XCTAssertEqual(engine.calibrationSummary.0, 1)
        XCTAssertEqual(engine.drainSampleRecords().count, 1)
        engine.endSampling()
        XCTAssertFalse(engine.mouse(isLeft: true, isDown: true, number: 3, signature: tap,
            at: 3, targetPID: 123, location: CGPoint(x: 150, y: 150)).2)
    }
    func testCalibrationSurvivesRestartAndCanBeReset() {
        let engine = prepared()
        engine.resetSession()
        XCTAssertTrue(engine.calibrationSummary.2)
        engine.beginCalibration(.tap, at: 20)
        for i in 0..<3 {
            _ = engine.mouse(isLeft: true, isDown: true, number: Int64(50 + i), signature: tap,
                at: Double(21 + i), targetPID: 123)
        }
        XCTAssertEqual(engine.calibrationSummary.0, 6)
        XCTAssertEqual(engine.calibrationSummary.1, 3)
        engine.resetSession(clearCalibration: true)
        XCTAssertFalse(engine.calibrationSummary.2)
        XCTAssertEqual(engine.calibrationSummary.0, 0)
    }
    func testCannotEmitAndModeOffPassThrough() {
        let engine = prepared(); candidate(engine)
        XCTAssertFalse(engine.mouse(isLeft: true, isDown: true, number: 5, signature: tap,
            at: 10.11, targetPID: 123, canEmit: false).0)
        candidate(engine); _ = engine.setEnabled(false)
        XCTAssertFalse(engine.mouse(isLeft: true, isDown: true, number: 5, signature: tap,
            at: 10.11, targetPID: 123).0)
    }
    func testOverlapOrInsufficientCalibrationCannotEnable() {
        var calibration = ClickCalibration()
        calibration.add(tap, as: .tap); calibration.add(press, as: .press)
        XCTAssertFalse(calibration.ready)
        for _ in 0..<3 { calibration.add(tap, as: .tap); calibration.add(tap, as: .press) }
        XCTAssertFalse(calibration.ready)
        XCTAssertFalse(calibration.matchesTap(tap))
        let engine = TakeoverEngine(); engine.setActive(true)
        XCTAssertFalse(engine.setEnabled(true))
    }
}
