import Foundation

struct Contact: Identifiable {
    let id: Int32
    let x: Double
    let y: Double
    let pressure: Double
    let area: Double
}

struct GestureResult {
    let kind: String
    let key: String
    let duration: Double
    let movement: Double
    let fingers: Int
    let ended: Double
    var isCustomRegion = false
}

/// One classification for the whole contact sequence, until all fingers lift.
/// Movement is normalized to trackpad dimensions, not millimetres.
struct TapRecognizer {
    var layout = PadLayout()
    // Captured intentional taps can last only 31–56 ms. Mouse-event
    // correlation and the movement/multitouch checks still gate takeover.
    var minimumDuration = 0.025
    var maximumDuration = 0.220
    var maximumMovement = 0.025
    private var start: Double?
    private var origin: Contact?
    private var last: Contact?
    private var maxMovement = 0.0
    private var maxFingers = 0
    private var clicked = false
    private var changedID = false

    static let keys = [["7", "8", "9"], ["4", "5", "6"], ["1", "2", "3"]]
    static func key(x: Double, y: Double) -> String {
        let column = min(2, max(0, Int(x * 3)))
        let row = min(2, max(0, Int((1 - y) * 3)))
        return keys[row][column]
    }
    mutating func reset() {
        start = nil; origin = nil; last = nil
        maxMovement = 0; maxFingers = 0; clicked = false; changedID = false
    }
    mutating func markClick() { if start != nil { clicked = true } }
    mutating func update(_ contacts: [Contact], at time: Double, mouseDown: Bool = false) -> GestureResult? {
        if !contacts.isEmpty {
            if start == nil { start = time; origin = contacts[0] }
            maxFingers = max(maxFingers, contacts.count)
            clicked = clicked || mouseDown
            if let origin {
                if let tracked = contacts.first(where: { $0.id == origin.id }) {
                    last = tracked
                    maxMovement = max(maxMovement, hypot(tracked.x - origin.x, tracked.y - origin.y))
                } else { changedID = true }
            }
            return nil
        }
        guard let start, let origin else { return nil }
        let elapsed = max(0, time - start)
        let end = last ?? origin
        let startsInCustomRegion = layout.customKey(x: origin.x, y: origin.y) != nil
        let endsInCustomRegion = layout.customKey(x: end.x, y: end.y) != nil
        // Keep the initial side of a custom-region boundary for small finger roll.
        // The maximum-excursion check below still rejects an actual slide.
        let anchorCustomBoundary = startsInCustomRegion || endsInCustomRegion
        let kind: String
        if clicked { kind = "鼠标点击（来源待判定）" }
        else if maxFingers > 1 { kind = "多指手势" }
        else if changedID { kind = "触点变化" }
        else if maxMovement > maximumMovement { kind = "滑动" }
        else if !anchorCustomBoundary && layout.key(x: origin.x, y: origin.y) != layout.key(x: end.x, y: end.y) { kind = "跨区接触" }
        else if elapsed < minimumDuration { kind = "过短接触" }
        else if elapsed > maximumDuration { kind = "长按 / 停留" }
        else { kind = "轻触候选" }
        let result = GestureResult(kind: kind,
            key: anchorCustomBoundary ? layout.key(x: origin.x, y: origin.y)
                : layout.key(x: (origin.x + end.x) / 2, y: (origin.y + end.y) / 2),
            duration: elapsed, movement: maxMovement, fingers: maxFingers, ended: time,
            isCustomRegion: startsInCustomRegion)
        reset()
        return result
    }
}
