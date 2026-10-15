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


/// Only this small view observes accepted taps. The rest of the window and the
/// menu bar are not invalidated by input feedback.
struct LiveTrackpadPreview: View {
    let layout: PadLayout
    @ObservedObject var feedback: InputFeedback
    let numberMode: Bool
    @ObservedObject private var localization = Localization.shared
    var body: some View {
        TrackpadPreview(layout: layout)
            .overlay {
                GeometryReader { geometry in
                    if let hit = feedback.latest {
                        Circle().fill(Color.accentColor.opacity(0.20))
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                            .overlay(Text(KeyOutput.previewLabel(hit.key))
                                .font(.system(size: 18, weight: .bold, design: .monospaced)))
                            .frame(width: 42, height: 42)
                            .position(x: min(geometry.size.width - 21, max(21, hit.position.x * geometry.size.width)),
                                      y: min(geometry.size.height - 21, max(21, (1 - hit.position.y) * geometry.size.height)))
                        Circle().fill(Color.accentColor).frame(width: 7, height: 7)
                            .position(x: hit.position.x * geometry.size.width,
                                      y: (1 - hit.position.y) * geometry.size.height)
                    }
                }.allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                if let hit = feedback.latest {
                    Text(L("最近按键：\(KeyOutput.displayLabel(hit.key))"))
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule()).padding(8)
                        .allowsHitTesting(false)
                } else if numberMode {
                    Text(L("轻触触控板，查看按键和位置"))
                        .font(.caption).padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule()).padding(8)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("按键布局"))
            .accessibilityValue(feedback.latest.map { L("最近按键：\(KeyOutput.displayLabel($0.key))") } ?? "")
    }
}
