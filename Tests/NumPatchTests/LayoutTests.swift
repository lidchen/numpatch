import XCTest
@testable import NumPatch

final class LayoutTests: XCTestCase {
    func testDefaultsAndNineKeyCenters() {
        let layout = PadLayout()
        XCTAssertEqual(layout.key(x: 0.5, y: 0.02), "0")
        XCTAssertEqual(layout.key(x: 0.98, y: 0.02), ".")
        XCTAssertEqual(layout.key(x: 0.02, y: 0.02), "1")
        for row in 0..<3 { for col in 0..<3 {
            XCTAssertEqual(layout.key(x: (Double(col) + 0.5) / 3,
                y: 1 - (Double(row) + 0.5) / 3), TapRecognizer.keys[row][col])
        } }
    }
    func testCornersUseCircularDistanceAndDisabledZonesUseGrid() {
        for zone in PadLayout.Zone.allCases.filter({ $0.isCorner }) {
            var layout = PadLayout()
            layout.bindings = [zone.rawValue: "Tab"]
            layout.cornerSize = 0.20
            let c = zone.center
            XCTAssertEqual(layout.key(x: c.x, y: c.y), "Tab")
            let sx = c.x == 1 ? -1.0 : 1.0
            let sy = c.y == 1 ? -1.0 : 1.0
            let inside = CGPoint(x: c.x + sx * 0.10 / PadLayout.aspectRatio, y: c.y + sy * 0.10)
            let outside = CGPoint(x: c.x + sx * 0.15 / PadLayout.aspectRatio, y: c.y + sy * 0.15)
            XCTAssertEqual(layout.customKey(x: inside.x, y: inside.y), "Tab")
            XCTAssertNil(layout.customKey(x: outside.x, y: outside.y), "\(zone): outside circle, inside old square")
            layout.bindings[zone.rawValue] = "关闭"
            XCTAssertNil(layout.zone(x: c.x, y: c.y))
            XCTAssertEqual(layout.key(x: c.x, y: c.y), TapRecognizer.key(x: c.x, y: c.y))
        }
    }
    func testBoundaryJitterKeepsInitialSideForAllZones() {
        for zone in PadLayout.Zone.allCases {
            for startsInside in [true, false] {
                var recognizer = TapRecognizer()
                recognizer.layout.bindings = [zone.rawValue: "Tab"]
                let c = zone.center
                let radius = zone.isCorner ? recognizer.layout.cornerSize : recognizer.layout.edgeDepth(zone)
                // Move inward from the edge; corner points also move slightly in y.
                let yOffset = zone.isCorner ? 0.05 : 0.0
                let xRadius = sqrt(radius * radius - yOffset * yOffset) / PadLayout.aspectRatio
                let sx = c.x == 1 ? -1.0 : 1.0
                let sy = c.y == 1 ? -1.0 : 1.0
                var inside: CGPoint, outside: CGPoint
                if zone == .top || zone == .bottom {
                    inside = CGPoint(x: c.x, y: c.y + sy * (radius - 0.005))
                    outside = CGPoint(x: c.x, y: c.y + sy * (radius + 0.005))
                } else {
                    inside = CGPoint(x: c.x + sx * (xRadius - 0.005), y: c.y + sy * yOffset)
                    outside = CGPoint(x: c.x + sx * (xRadius + 0.005), y: c.y + sy * yOffset)
                }
                let start = startsInside ? inside : outside
                let end = startsInside ? outside : inside
                let expected = recognizer.layout.key(x: start.x, y: start.y)
                _ = recognizer.update([Contact(id: 1, x: start.x, y: start.y, pressure: 0, area: 0)], at: 0)
                _ = recognizer.update([Contact(id: 1, x: end.x, y: end.y, pressure: 0, area: 0)], at: 0.08)
                let result = recognizer.update([], at: 0.1)
                XCTAssertEqual(result?.kind, "轻触候选", "\(zone)")
                XCTAssertEqual(result?.key, expected)
                XCTAssertEqual(result?.isCustomRegion, startsInside)
            }
        }
    }
    func testAnchoringStillRejectsSlidesAndGridCrossings() {
        var recognizer = TapRecognizer()
        _ = recognizer.update([Contact(id: 1, x: 0.5, y: 0.05, pressure: 0, area: 0)], at: 0)
        _ = recognizer.update([Contact(id: 1, x: 0.5, y: 0.20, pressure: 0, area: 0)], at: 0.08)
        XCTAssertEqual(recognizer.update([], at: 0.1)?.kind, "滑动")
        _ = recognizer.update([Contact(id: 1, x: 0.33, y: 0.5, pressure: 0, area: 0)], at: 1)
        _ = recognizer.update([Contact(id: 1, x: 0.34, y: 0.5, pressure: 0, area: 0)], at: 1.08)
        XCTAssertEqual(recognizer.update([], at: 1.1)?.kind, "跨区接触")
    }
    func testSizesAndVersionedRoundTrip() throws {
        var layout = PadLayout()
        layout.bindings = ["topLeft": "/", "right": "Enter"]
        let x = 0.12, y = 0.9
        layout.cornerSize = 0.08
        XCTAssertNil(layout.customKey(x: x, y: y))
        layout.cornerSize = 0.24
        XCTAssertEqual(layout.customKey(x: x, y: y), "/")
        layout.edgeDepths["right"] = 0.08
        XCTAssertNil(layout.customKey(x: 0.9, y: 0.5))
        layout.edgeDepths["right"] = 0.24
        XCTAssertEqual(layout.customKey(x: 0.9, y: 0.5), "Enter")
        // A deliberate left-corner zero in the new format must stay there.
        layout.bindings["bottomLeft"] = "0"
        XCTAssertEqual(try JSONDecoder().decode(PadLayout.self, from: JSONEncoder().encode(layout)), layout)
    }
    func testLegacyZeroMovesToBottomWithoutLosingOtherBindings() throws {
        let data = Data(#"{"cornerSize":0.16,"bindings":{"bottomLeft":"0","bottomRight":".","topLeft":"Tab"}}"#.utf8)
        let layout = try JSONDecoder().decode(PadLayout.self, from: data)
        XCTAssertEqual(layout.binding(.bottom), "0")
        XCTAssertEqual(layout.binding(.bottomLeft), "关闭")
        XCTAssertEqual(layout.binding(.bottomRight), ".")
        XCTAssertEqual(layout.binding(.topLeft), "Tab")
    }
    func testEdgeStripsStretchIndependentlyWithStraightOuterCorners() throws {
        var layout = PadLayout()
        layout.edgeLengths["bottom"] = 0.70
        XCTAssertEqual(layout.edgeLength(.top), 0.50)
        XCTAssertEqual(layout.key(x: 0.22, y: 0.07), "0")
        XCTAssertEqual(layout.key(x: 0.78, y: 0.07), "0")
        XCTAssertEqual(layout.key(x: 0.22, y: 0.18), "1")
        layout.edgeLengths["bottom"] = 0.20
        XCTAssertEqual(layout.key(x: 0.22, y: 0.07), "1")
        layout.edgeLengths["bottom"] = 0.70
        layout.bindings["bottom"] = "关闭"
        XCTAssertEqual(layout.key(x: 0.22, y: 0.07), "1")
        layout.bindings["bottom"] = "0"
        XCTAssertEqual(try JSONDecoder().decode(PadLayout.self, from: JSONEncoder().encode(layout)), layout)
        for zone in PadLayout.Zone.allCases.filter({ !$0.isCorner }) {
            layout.bindings = [zone.rawValue: "Tab"]
            let bounds = layout.edgeBounds(zone)
            XCTAssertEqual(layout.customKey(x: bounds.midX, y: bounds.midY), "Tab")
            XCTAssertEqual(layout.customKey(x: zone.center.x, y: zone.center.y), "Tab")
            let outer: CGPoint
            let inner: CGPoint
            switch zone {
            case .bottom:
                outer = CGPoint(x: bounds.minX + 0.001, y: bounds.minY + 0.001)
                inner = CGPoint(x: bounds.minX + 0.001, y: bounds.maxY - 0.001)
            case .top:
                outer = CGPoint(x: bounds.minX + 0.001, y: bounds.maxY - 0.001)
                inner = CGPoint(x: bounds.minX + 0.001, y: bounds.minY + 0.001)
            case .left:
                outer = CGPoint(x: bounds.minX + 0.001, y: bounds.minY + 0.001)
                inner = CGPoint(x: bounds.maxX - 0.001, y: bounds.minY + 0.001)
            default:
                outer = CGPoint(x: bounds.maxX - 0.001, y: bounds.minY + 0.001)
                inner = CGPoint(x: bounds.minX + 0.001, y: bounds.minY + 0.001)
            }
            XCTAssertEqual(layout.customKey(x: outer.x, y: outer.y), "Tab", "straight edge: \(zone)")
            XCTAssertNil(layout.customKey(x: inner.x, y: inner.y), "rounded inside: \(zone)")
        }
    }
    func testLegacySemicircleLayoutKeepsBindingsAndDepthWhileAddingLength() throws {
        let data = Data(#"{"version":2,"cornerSize":0.2,"edgeSize":0.18,"bindings":{"bottom":"0","bottomRight":"."}}"#.utf8)
        let layout = try JSONDecoder().decode(PadLayout.self, from: data)
        XCTAssertEqual(layout.edgeDepth(.bottom), 0.18)
        XCTAssertEqual(layout.edgeLength(.bottom), 0.50)
        XCTAssertEqual(layout.binding(.bottom), "0")
        XCTAssertEqual(layout.binding(.bottomRight), ".")
    }
    func testEdgeCanShrinkToSmallSemicircleWithoutOccupyingNearbyGrid() throws {
        for zone in PadLayout.Zone.allCases.filter({ !$0.isCorner }) {
            var layout = PadLayout()
            layout.bindings = [zone.rawValue: "Tab"]
            layout.edgeLengths[zone.rawValue] = PadLayout.edgeLengthRange.lowerBound
            layout.edgeDepths[zone.rawValue] = 0.24
            let bounds = layout.edgeBounds(zone)
            let horizontal = zone == .top || zone == .bottom
            let physicalLength = horizontal ? bounds.width * PadLayout.aspectRatio : bounds.height
            XCTAssertEqual(physicalLength, layout.edgeDepth(zone) * 2, accuracy: 1e-9)
            XCTAssertLessThanOrEqual(layout.edgeDepth(zone), 0.03 + 1e-9)
            XCTAssertEqual(layout.customKey(x: zone.center.x, y: zone.center.y), "Tab")
            XCTAssertEqual(try JSONDecoder().decode(PadLayout.self, from: JSONEncoder().encode(layout)), layout)
        }
    }
    func testEdgePreviewMatchesHitTestingInAllOrientations() {
        for zone in PadLayout.Zone.allCases.filter({ !$0.isCorner }) {
            for length in [0.04, 0.50, 0.80] {
                var layout = PadLayout()
                layout.edgeLengths[zone.rawValue] = length
                layout.edgeDepths[zone.rawValue] = 0.14
                let bounds = layout.edgeBounds(zone)
                // Large coordinates avoid Core Graphics flattening tolerance
                // dominating the smallest (few-pixel) semicircles.
                let rect = CGRect(x: 0, y: 0, width: bounds.width * 60000, height: bounds.height * 40000)
                let path = EdgeStripShape(zone: zone).path(in: rect)
                for i in 0..<10 { for j in 0..<10 {
                    let x = (Double(i) + 0.5) / 10
                    let y = (Double(j) + 0.5) / 10
                    XCTAssertEqual(path.contains(CGPoint(x: x * rect.width, y: (1 - y) * rect.height)),
                        layout.contains(zone, x: bounds.minX + x * bounds.width, y: bounds.minY + y * bounds.height),
                        "\(zone), length \(length), point \(x),\(y)")
                } }
            }
        }
    }
}
