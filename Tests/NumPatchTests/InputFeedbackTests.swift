import XCTest
@testable import NumPatch

final class InputFeedbackTests: XCTestCase {
    func testHiddenPreviewRejectsQueuedHitsAndClearsPreviousHit() {
        let model = InputFeedback()
        let hit = TapFeedback(GestureResult(kind: "轻触候选", key: "5", duration: 0.1, movement: 0, fingers: 1, ended: 1,
            position: CGPoint(x: 0.5, y: 0.5)))
        model.receive(hit, generation: model.generation)
        XCTAssertNil(model.latest)
        model.setActive(true)
        let generation = model.generation
        model.receive(hit, generation: generation)
        XCTAssertEqual(model.latest, hit)
        model.setActive(false)
        XCTAssertNil(model.latest)
        model.setActive(true)
        model.receive(hit, generation: generation)
        XCTAssertNil(model.latest, "A queued update from the previous window session must not appear.")
    }
    func testAcceptedOutputReportsPositionOnceAndUnsubscribingStopsDelivery() {
        let helpers = TakeoverTests()
        let engine = helpers.prepared()
        var hits: [TapFeedback] = []
        engine.setFeedbackHandler(ownPID: 999) { hits.append($0) }
        let gesture = helpers.regionCandidate(engine)
        XCTAssertNotNil(engine.regionFallback(for: gesture, at: 10.12, ownPID: 999, canEmit: true))
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.key, "0")
        XCTAssertEqual(hits.first?.position, CGPoint(x: 0.5, y: 0.02))
        _ = engine.mouse(isLeft: true, isDown: true, number: 90, signature: helpers.tap, at: 10.085, targetPID: 123, receivedAt: 10.13)
        _ = engine.mouse(isLeft: true, isDown: false, number: 90, signature: helpers.tap, at: 10.14, targetPID: 123)
        XCTAssertEqual(hits.count, 1, "Late native clicks must not duplicate visual feedback.")
        engine.setFeedbackHandler(ownPID: 999, handler: nil)
        let next = helpers.regionCandidate(engine)
        XCTAssertNotNil(engine.regionFallback(for: next, at: 10.12, ownPID: 999, canEmit: true))
        XCTAssertEqual(hits.count, 1)
    }
    func testPracticeInOwnWindowShowsTapWithoutInjectingOrBlockingClicks() {
        let helpers = TakeoverTests()
        let engine = helpers.prepared()
        engine.setFrontPID(999)
        var hits: [TapFeedback] = []
        engine.setFeedbackHandler(ownPID: 999) { hits.append($0) }
        let gesture = helpers.regionCandidate(engine)
        XCTAssertEqual(hits.count, 1)
        XCTAssertNil(engine.regionFallback(for: gesture, at: 10.12, ownPID: 999, canEmit: true))
        let click = engine.mouse(isLeft: true, isDown: true, number: 90, signature: helpers.tap,
            at: 10.085, targetPID: engine.eventTarget(999, ownPID: 999))
        XCTAssertFalse(click.0); XCTAssertNil(click.1)
        XCTAssertEqual(hits.count, 1)
        engine.frame([Contact(id: 2, x: 0.5, y: 0.5, pressure: 0, area: 0)], at: 11)
        _ = engine.mouse(isLeft: true, isDown: true, number: 91, signature: helpers.press, at: 11.04, targetPID: 0)
        engine.frame([], at: 11.08)
        XCTAssertEqual(hits.count, 1, "A physical click is not a practice tap.")
        _ = engine.setEnabled(false)
        engine.frame([Contact(id: 3, x: 0.5, y: 0.5, pressure: 0, area: 0)], at: 12)
        engine.frame([], at: 12.08)
        XCTAssertEqual(hits.count, 1)
    }
    func testNativeTapAndMultifingerExclusion() {
        let helpers = TakeoverTests()
        let engine = helpers.prepared()
        var hits: [TapFeedback] = []
        engine.setFeedbackHandler(ownPID: 999) { hits.append($0) }
        helpers.candidate(engine, multi: true)
        _ = engine.mouse(isLeft: true, isDown: true, number: 80, signature: helpers.tap, at: 10.11, targetPID: 123)
        XCTAssertTrue(hits.isEmpty)
        helpers.candidate(engine)
        let down = engine.mouse(isLeft: true, isDown: true, number: 81, signature: helpers.tap, at: 10.11, targetPID: 123)
        XCTAssertEqual(down.1, "5"); XCTAssertEqual(hits.count, 1)
    }
}
