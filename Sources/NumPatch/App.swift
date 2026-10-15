import SwiftUI
import AppKit

@main
struct NumPatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var monitor = Monitor.shared
    @ObservedObject private var localization = Localization.shared
    var body: some Scene {
        WindowGroup("NumPatch") {
            ContentView(monitor: monitor).environment(\.locale, localization.language.locale).frame(minWidth: 640, minHeight: 620)
        }
        .commands { CommandGroup(replacing: .newItem) {} }
        MenuBarExtra("NumPatch", systemImage: monitor.numberMode ? "square.grid.3x3.fill" : "square.grid.3x3") {
            Text(monitor.starting ? L("正在开启数字模式…") : monitor.numberMode ? L("数字模式已开启") : L("数字模式已暂停"))
            Button(monitor.numberMode || monitor.starting ? L("暂停数字模式") : L("开启数字模式")) { monitor.toggleNumberMode() }
                .disabled(monitor.calibrationOpen)
            Divider()
            Button(L("打开NumPatch…")) { AppDelegate.current?.showWindow() }
            Divider()
            Button(L("退出NumPatch")) { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var current: AppDelegate?
    private var retainedWindow: NSWindow?
    func showWindow() {
        let window: NSWindow
        if let existing = NSApp.windows.first(where: { $0.title == "NumPatch" && $0.canBecomeMain }) {
            window = existing
        } else if let existing = retainedWindow { window = existing }
        else {
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 690),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "NumPatch"
            window.contentMinSize = NSSize(width: 640, height: 620)
            window.contentView = NSHostingView(rootView: ContentView(monitor: Monitor.shared))
            window.center()
        }
        window.isReleasedWhenClosed = false; retainedWindow = window
        window.collectionBehavior.insert(.moveToActiveSpace)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow(); return false
    }
    func applicationDidBecomeActive(_ notification: Notification) { Monitor.shared.refreshAccess() }
    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.current = self
        Monitor.shared.registerShortcut()
        Monitor.shared.restoreCalibrationIfRequested()
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            self.showWindow()
            if CommandLine.arguments.contains("--enable-number-mode") { Monitor.shared.toggleNumberMode() }
        }
    }
    func applicationWillTerminate(_ notification: Notification) { Monitor.shared.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct ContentView: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject private var localization = Localization.shared
    @State private var showingSettings = false
    @State private var settingsTab = 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 32)).foregroundStyle(Color.accentColor)
                        .frame(width: 52, height: 52)
                        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NumPatch").font(.system(size: 27, weight: .semibold, design: .rounded))
                        Text(L("触控板上的数字小键盘")).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { settingsTab = 1; showingSettings = true } label: {
                        Image(systemName: "slider.horizontal.3").font(.title3)
                    }.buttonStyle(.plain).help(L("设置")).accessibilityLabel(L("设置"))
                }
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(monitor.starting ? L("正在开启数字模式…") : monitor.numberMode ? L("数字模式已开启") : L("数字模式已暂停"),
                            systemImage: monitor.numberMode ? "circle.fill" : "pause.circle")
                            .font(.headline).foregroundStyle(monitor.numberMode ? Color.accentColor : Color.primary)
                        Text(L("单指输入数字，双指保留系统右键")).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(L("数字模式"), isOn: Binding(get: { monitor.numberMode || monitor.starting },
                        set: { _ in monitor.toggleNumberMode() }))
                        .toggleStyle(.switch).labelsHidden().disabled(monitor.calibrationOpen)
                }.padding(18).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                if !monitor.accessGranted {
                    setupCard(title: L("先允许辅助功能访问"), detail: L("用于发送小键盘按键，并接管单指轻触。"),
                        action: L("前往授权"), perform: monitor.requestAccessibility)
                } else if !monitor.calibrationReady {
                    setupCard(title: L("完成轻触校准"), detail: L("分别轻触和按压三次，让程序区分两种动作。"),
                        action: L("开始校准"), perform: monitor.startCalibration)
                }
                if monitor.status.key != "已暂停" && monitor.status.key != "数字模式已开启" {
                    Text(monitor.status.text).font(.callout).foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text(L("按键布局")).font(.headline)
                        Spacer()
                        Button(L("编辑布局…")) { settingsTab = 0; showingSettings = true }
                    }
                    TrackpadPreview(layout: monitor.layout)
                        .frame(width: 450, height: 450 / PadLayout.aspectRatio)
                        .frame(maxWidth: .infinity)
                    Text(L("未分配的边角使用原九键数字。"))
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(18).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                HStack {
                    Text(monitor.shortcutStatus.text).font(.system(.callout, design: .monospaced))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    Text(L("切换数字模式")).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Text(L("系统轻触保持开启")).font(.caption).foregroundStyle(.secondary)
                }
            }.padding(26)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $monitor.calibrationOpen) { CalibrationView(monitor: monitor) }
        .sheet(isPresented: $showingSettings) { PreferencesView(monitor: monitor, selectedTab: $settingsTab) }
    }
    private func setupCard(title: String, detail: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action, action: perform).buttonStyle(.borderedProminent)
        }.padding(16).background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}
