import AppKit
import SwiftUI

struct CalibrationView: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject private var localization = Localization.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L("轻触与按压校准")).font(.title2.bold())
            Text(monitor.calibrationStage == .tap ? L("第一步：单指轻触 3 次，不要按下") :
                (monitor.calibrationStage == .press ? L("第二步：物理按压 3 次") : L("校准采集完成")))
                .font(.headline)
            Text(L("把鼠标指针移入下方蓝色区域，等待 1 秒，再操作触控板。无需再次点击采集按钮，完成后自动进入下一步。"))
                .foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.18))
                CalibrationTarget(stage: monitor.calibrationStage == .tap ? 0 : (monitor.calibrationStage == .press ? 1 : 2)).padding(12)
                Text(monitor.calibrationStage == nil ? L("采集结束") : L("鼠标指针保持在此区域内"))
                    .allowsHitTesting(false)
            }.frame(height: 180)
            Text(monitor.calibrationStatus.text).font(.callout).frame(minHeight: 38, alignment: .topLeading)
            HStack {
                Text(L("区域外的点击不会进入校准。")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(monitor.calibrationStage == nil ? L("完成") : L("取消")) { monitor.endCalibration() }
            }
        }.padding(24).frame(width: 460)
        .onDisappear { monitor.endCalibration() }
    }
}

private struct CalibrationTarget: NSViewRepresentable {
    let stage: Int
    func makeNSView(context: Context) -> CalibrationTargetView { CalibrationTargetView() }
    func updateNSView(_ nsView: CalibrationTargetView, context: Context) { nsView.updateArea() }
}
private final class CalibrationTargetView: NSView {
    private var observers: [NSObjectProtocol] = []
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        if let window {
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in self?.updateArea() })
            }
        }
        updateArea()
    }
    override func layout() { super.layout(); updateArea() }
    func updateArea() {
        guard let window, let mainTop = NSScreen.screens.first?.frame.maxY else { return }
        let rect = window.convertToScreen(convert(bounds, to: nil))
        TakeoverEngine.shared.setCalibrationArea(CGRect(x: rect.minX, y: mainTop - rect.maxY, width: rect.width, height: rect.height))
    }
    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
}
