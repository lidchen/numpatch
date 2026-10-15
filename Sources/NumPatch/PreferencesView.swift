import SwiftUI

struct PreferencesView: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject private var localization = Localization.shared
    @Binding var selectedTab: Int
    @Environment(\.dismiss) private var dismiss
    @State private var editingEdge: PadLayout.Zone = .bottom
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                layoutPane.tabItem { Label(L("布局"), systemImage: "square.grid.3x3") }.tag(0)
                recognitionPane.tabItem { Label(L("识别"), systemImage: "hand.tap") }.tag(1)
                aboutPane.tabItem { Label(L("关于"), systemImage: "info.circle") }.tag(2)
            }.padding(16)
            Divider()
            HStack {
                Text(L("修改自动保存")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L("完成")) { dismiss() }.keyboardShortcut(.defaultAction)
            }.padding(16)
        }.frame(width: 610, height: 700)
    }
    private var layoutPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                TrackpadPreview(layout: monitor.layout).frame(width: 300, height: 200).frame(maxWidth: .infinity)
                HStack(alignment: .top, spacing: 24) { zonePickers(corners: true); zonePickers(corners: false) }
                Divider()
                Text(L("角落半径 · \(Int((monitor.layout.cornerSize * 100).rounded()))%"))
                Slider(value: $monitor.layout.cornerSize, in: PadLayout.sizeRange, step: 0.01)
                Picker(L("调整边条"), selection: $editingEdge) {
                    ForEach(PadLayout.Zone.allCases.filter { !$0.isCorner }) { Text($0.title).tag($0) }
                }
                Text(L("长度 · 该边的 \(Int((monitor.layout.edgeLength(editingEdge) * 100).rounded()))%"))
                Slider(value: Binding(get: { monitor.layout.edgeLength(editingEdge) },
                    set: { monitor.layout.edgeLengths[editingEdge.rawValue] = $0 }), in: PadLayout.edgeLengthRange, step: 0.01)
                Text(L("向内深度 · 短边的 \(Int((monitor.layout.edgeDepth(editingEdge) * 100).rounded()))%"))
                Slider(value: Binding(get: { monitor.layout.edgeDepth(editingEdge) },
                    set: { monitor.layout.edgeDepths[editingEdge.rawValue] = $0 }),
                    in: PadLayout.edgeDepthRange.lowerBound...monitor.layout.maximumEdgeDepth(editingEdge), step: 0.005)
                HStack {
                    Text(L("贴边直角、朝内圆角；缩短后可收成小半圆。"))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(L("恢复默认布局")) { monitor.layout = PadLayout() }
                }
            }.padding(12)
        }
    }
    private var recognitionPane: some View {
        Form {
            Section(L("通用")) {
                Picker(L("语言"), selection: $localization.language) {
                    ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent(L("快捷键"), value: monitor.shortcutStatus.text)
                Text(L("数字模式关闭后停止监听。设置窗口内保留普通鼠标点击。"))
                    .foregroundStyle(.secondary)
            }
            Section(L("轻触识别")) {
                Text(L("最短轻触 · \(Int(monitor.tuning.minimumMS)) ms"))
                Slider(value: $monitor.tuning.minimumMS, in: 10...150, step: 5)
                Text(L("最长轻触 · \(Int(monitor.tuning.maximumMS)) ms"))
                Slider(value: $monitor.tuning.maximumMS, in: 150...450, step: 10)
                Text(String(format: L("允许位移 · %.1f%%"), monitor.tuning.movement * 100))
                Slider(value: $monitor.tuning.movement, in: 0.005...0.080, step: 0.005)
                Button(L("恢复默认识别参数")) { monitor.tuning = RecognitionSettings() }
            }
            Section(L("权限与校准")) {
                LabeledContent(L("辅助功能"), value: monitor.accessGranted ? L("已授权") : L("未授权"))
                LabeledContent(L("轻触校准"), value: monitor.calibrationReady ? L("已就绪") : L("需要校准"))
                HStack {
                    Button(L("重新检查权限")) { monitor.refreshAccess() }
                    Button(L("辅助功能授权")) { monitor.requestAccessibility() }
                    Button(L("输入监控授权")) { monitor.requestInputAccess() }
                }
                Button(L("重新校准轻触与按压…")) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { monitor.startCalibration() }
                }
            }
        }.formStyle(.grouped)
    }
    private var aboutPane: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.3x3.fill").font(.system(size: 56)).foregroundStyle(Color.accentColor)
            Text("NumPatch").font(.system(size: 25, weight: .semibold, design: .rounded))
            Text(L("版本 0.3.0")).foregroundStyle(.secondary)
            Text(L("为触控板添加九键数字和可自定义的边角按键。"))
            Text(L("关闭窗口后，可继续通过菜单栏或快捷键切换数字模式。\n关闭数字模式后，停止触控与鼠标事件监听。"))
                .multilineTextAlignment(.center).foregroundStyle(.secondary).lineSpacing(5)
            Spacer().frame(height: 20)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func zonePickers(corners: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(PadLayout.Zone.allCases.filter { $0.isCorner == corners }) { zone in
                Picker(zone.title, selection: Binding(get: { monitor.layout.binding(zone) },
                    set: { monitor.layout.bindings[zone.rawValue] = $0 })) {
                    ForEach(KeyOutput.choices, id: \.self) { Text(KeyOutput.displayLabel($0)).tag($0) }
                }
            }
        }
    }
}
