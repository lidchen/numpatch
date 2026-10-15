import SwiftUI

struct TrackpadPreview: View {
    let layout: PadLayout
    @ObservedObject private var localization = Localization.shared
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor))
                VStack(spacing: 0) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<3) { column in
                                Text(TapRecognizer.keys[row][column])
                                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .border(Color.secondary.opacity(0.15), width: 0.5)
                            }
                        }
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 12))
                ForEach(Array(PadLayout.Zone.allCases.reversed())) { zone in
                    if KeyOutput.codes[layout.binding(zone)] != nil {
                        if zone.isCorner {
                        let radius = geometry.size.height * layout.cornerSize
                        let center = CGPoint(x: geometry.size.width * zone.center.x,
                                             y: geometry.size.height * (1 - zone.center.y))
                        Circle().fill(Color.accentColor.opacity(0.22))
                            .frame(width: radius * 2, height: radius * 2)
                            .position(center)
                        Text(KeyOutput.previewLabel(layout.binding(zone)))
                            .accessibilityLabel(KeyOutput.displayLabel(layout.binding(zone)))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .position(x: center.x + (zone.center.x == 0 ? radius * 0.43 : zone.center.x == 1 ? -radius * 0.43 : 0),
                                      y: center.y + (zone.center.y == 1 ? radius * 0.43 : zone.center.y == 0 ? -radius * 0.43 : 0))
                        } else {
                            let bounds = layout.edgeBounds(zone)
                            EdgeStripShape(zone: zone).fill(Color.accentColor.opacity(0.22))
                                .overlay(Text(KeyOutput.previewLabel(layout.binding(zone)))
                                    .accessibilityLabel(KeyOutput.displayLabel(layout.binding(zone)))
                                    .font(.system(size: 15, weight: .bold, design: .monospaced)))
                                .frame(width: bounds.width * geometry.size.width,
                                       height: bounds.height * geometry.size.height)
                                .position(x: bounds.midX * geometry.size.width,
                                          y: (1 - bounds.midY) * geometry.size.height)
                        }
                    }
                }
            }.clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
