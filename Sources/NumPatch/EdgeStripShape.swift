import SwiftUI

/// Straight edge against the trackpad, with only the inward corners rounded.
/// At length == 2 * depth this is a semicircle, rather than a pill inset
/// from the edge. Layout uses the same half-capsule distance rule.
struct EdgeStripShape: Shape {
    let zone: PadLayout.Zone
    func path(in rect: CGRect) -> Path {
        let horizontal = zone == .top || zone == .bottom
        let width = horizontal ? rect.width : rect.height
        let height = horizontal ? rect.height : rect.width
        let radius = min(height, width / 2)
        let k = 0.5522847498307936
        var path = Path()
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: width, y: radius))
        path.addCurve(to: CGPoint(x: width - radius, y: 0),
            control1: CGPoint(x: width, y: radius * (1 - k)),
            control2: CGPoint(x: width - radius * (1 - k), y: 0))
        path.addLine(to: CGPoint(x: radius, y: 0))
        path.addCurve(to: CGPoint(x: 0, y: radius),
            control1: CGPoint(x: radius * (1 - k), y: 0),
            control2: CGPoint(x: 0, y: radius * (1 - k)))
        path.closeSubpath()
        let transform: CGAffineTransform
        switch zone {
        case .top: transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        case .left: transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: height, ty: 0)
        case .right: transform = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        default: transform = .identity
        }
        return path.applying(transform.concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}
