import Foundation

struct PadLayout: Codable, Equatable {
    enum Zone: String, CaseIterable, Identifiable, Codable {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
        var id: String { rawValue }
        var isCorner: Bool {
            switch self { case .topLeft, .topRight, .bottomLeft, .bottomRight: return true; default: return false }
        }
        var title: String {
            switch self {
            case .topLeft: return L("左上角")
            case .topRight: return L("右上角")
            case .bottomLeft: return L("左下角")
            case .bottomRight: return L("右下角")
            case .top: return L("上边中点")
            case .bottom: return L("下边中点")
            case .left: return L("左边中点")
            case .right: return L("右边中点")
            }
        }
        var center: CGPoint {
            switch self {
            case .topLeft: return CGPoint(x: 0, y: 1)
            case .topRight: return CGPoint(x: 1, y: 1)
            case .bottomLeft: return CGPoint(x: 0, y: 0)
            case .bottomRight: return CGPoint(x: 1, y: 0)
            case .top: return CGPoint(x: 0.5, y: 1)
            case .bottom: return CGPoint(x: 0.5, y: 0)
            case .left: return CGPoint(x: 0, y: 0.5)
            case .right: return CGPoint(x: 1, y: 0.5)
            }
        }
    }
    // Distances use the short side, with the same aspect ratio as the preview.
    static let aspectRatio = 1.5
    static let sizeRange = 0.08...0.24
    var cornerSize = 0.20
    static let edgeLengthRange = 0.04...0.80
    static let edgeDepthRange = 0.01...0.24
    var edgeLengths: [String: Double] = [:]
    var edgeDepths: [String: Double] = [:]
    var bindings: [String: String] = ["bottom": "0", "bottomRight": "."]
    func binding(_ zone: Zone) -> String { bindings[zone.rawValue] ?? "关闭" }
    func edgeLength(_ zone: Zone) -> Double { edgeLengths[zone.rawValue] ?? 0.50 }
    func maximumEdgeDepth(_ zone: Zone) -> Double {
        let extent = zone == .top || zone == .bottom ? Self.aspectRatio : 1
        return min(Self.edgeDepthRange.upperBound, edgeLength(zone) * extent / 2)
    }
    func edgeDepth(_ zone: Zone) -> Double {
        min(edgeDepths[zone.rawValue] ?? 0.14, maximumEdgeDepth(zone))
    }
    /// Normalized bounds of an inward-facing half capsule; shared by hit testing
    /// and the preview, so stretching never changes just the appearance.
    func edgeBounds(_ zone: Zone) -> CGRect {
        let depth = edgeDepth(zone)
        if zone == .top || zone == .bottom {
            let length = edgeLength(zone)
            return CGRect(x: (1 - length) / 2, y: zone == .top ? 1 - depth : 0,
                width: length, height: depth)
        }
        let length = edgeLength(zone)
        return CGRect(x: zone == .left ? 0 : 1 - depth / Self.aspectRatio,
            y: (1 - length) / 2, width: depth / Self.aspectRatio, height: length)
    }
    func contains(_ zone: Zone, x: Double, y: Double) -> Bool {
        if zone.isCorner {
            let dx = (x - zone.center.x) * Self.aspectRatio
            let dy = y - zone.center.y
            return dx * dx + dy * dy <= cornerSize * cornerSize
        }
        let bounds = edgeBounds(zone)
        let horizontal = zone == .top || zone == .bottom
        let length = horizontal ? bounds.width * Self.aspectRatio : bounds.height
        let depth = edgeDepth(zone)
        let along = horizontal ? (x - 0.5) * Self.aspectRatio : y - 0.5
        let inward: Double
        switch zone {
        case .bottom: inward = y
        case .top: inward = 1 - y
        case .left: inward = x * Self.aspectRatio
        default: inward = (1 - x) * Self.aspectRatio
        }
        guard inward >= -1e-12 else { return false }
        let capDistance = max(abs(along) - (length / 2 - depth), 0)
        return capDistance * capDistance + inward * inward <= depth * depth + 1e-12
    }
    func zone(x: Double, y: Double) -> Zone? {
        let x = min(1, max(0, x)), y = min(1, max(0, y))
        return Zone.allCases.first { zone in
            guard KeyOutput.codes[binding(zone)] != nil else { return false }
            return contains(zone, x: x, y: y)
        }
    }
    func customKey(x: Double, y: Double) -> String? {
        zone(x: x, y: y).map(binding)
    }
    func key(x: Double, y: Double) -> String {
        customKey(x: x, y: y) ?? TapRecognizer.key(x: x, y: y)
    }
    enum CodingKeys: String, CodingKey { case cornerSize, edgeSize, edgeLengths, edgeDepths, bindings, version }
    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        cornerSize = try values.decodeIfPresent(Double.self, forKey: .cornerSize) ?? 0.20
        edgeLengths = try values.decodeIfPresent([String: Double].self, forKey: .edgeLengths) ?? [:]
        edgeDepths = try values.decodeIfPresent([String: Double].self, forKey: .edgeDepths) ?? [:]
        if edgeDepths.isEmpty, let oldRadius = try values.decodeIfPresent(Double.self, forKey: .edgeSize) {
            for zone in Zone.allCases where !zone.isCorner { edgeDepths[zone.rawValue] = oldRadius }
        }
        bindings = try values.decode([String: String].self, forKey: .bindings)
        if !values.contains(.version) {
            // The new default puts zero on the bottom edge. Keep other bindings.
            if bindings["bottomLeft"] == "0" {
                bindings.removeValue(forKey: "bottomLeft")
                bindings["bottom"] = "0"
            }
            cornerSize = min(Self.sizeRange.upperBound, max(Self.sizeRange.lowerBound, cornerSize))
        }
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(3, forKey: .version)
        try values.encode(cornerSize, forKey: .cornerSize)
        try values.encode(edgeLengths, forKey: .edgeLengths)
        try values.encode(edgeDepths, forKey: .edgeDepths)
        try values.encode(bindings, forKey: .bindings)
    }
    static func load() -> PadLayout {
        guard let data = UserDefaults.standard.data(forKey: "padLayout"),
              let layout = try? JSONDecoder().decode(PadLayout.self, from: data),
              sizeRange.contains(layout.cornerSize),
              layout.edgeLengths.allSatisfy({ Zone(rawValue: $0.key)?.isCorner == false && edgeLengthRange.contains($0.value) }),
              layout.edgeDepths.allSatisfy({ Zone(rawValue: $0.key)?.isCorner == false && edgeDepthRange.contains($0.value) }),
              layout.bindings.keys.allSatisfy({ Zone(rawValue: $0) != nil }),
              layout.bindings.values.allSatisfy({ $0 == "关闭" || KeyOutput.codes[$0] != nil }) else { return PadLayout() }
        return layout
    }
    func save() { if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: "padLayout") } }
}

enum KeyOutput {
    // Keep legacy persisted IDs (including "关闭") stable across languages.
    static func displayLabel(_ key: String) -> String {
        switch key {
        case "关闭": return L("关闭")
        case "Backspace": return L("退格")
        case "Space": return L("空格")
        case "Enter": return L("回车")
        case "Tab": return L("制表符")
        case "Esc": return L("退出键")
        default: return key
        }
    }
    static func previewLabel(_ key: String) -> String {
        ["Backspace": "⌫", "Enter": "↵", "Tab": "⇥", "Space": "␣"][key] ?? key
    }
    static let choices = ["关闭", "0", ".", "/", "*", "-", "+", "Enter", "Backspace", "Tab", "Esc", "Space"] + (1...9).map(String.init)
    static let codes: [String: UInt16] = ["0": 82, "1": 83, "2": 84, "3": 85, "4": 86,
        "5": 87, "6": 88, "7": 89, "8": 91, "9": 92, ".": 65, "/": 75,
        "*": 67, "-": 78, "+": 69, "Enter": 76, "Backspace": 51, "Tab": 48, "Esc": 53, "Space": 49]
}
