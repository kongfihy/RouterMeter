import AppKit
import SwiftUI

@main
struct OpenRouterMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = MonitorStore.shared

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .environmentObject(store)
        } label: {
            MenuBarLabelView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
        }

#if DEBUG
        Window("RouterMeter Preview", id: "dashboard-preview") {
            DashboardView(initialSection: .logs)
                .environmentObject(store)
        }
        .defaultSize(width: 668, height: 732)
#endif
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let icon = Brand.iconImage {
            NSApp.applicationIconImage = icon
        }

#if DEBUG
        if let screenshotPath = ProcessInfo.processInfo.environment["ROUTERMETER_SCREENSHOT_PATH"],
           !screenshotPath.isEmpty {
            Task { @MainActor in
                let sectionName = ProcessInfo.processInfo.environment["ROUTERMETER_SCREENSHOT_SECTION"] ?? "logs"
                let section = DashboardSection(rawValue: sectionName) ?? .logs
                await exportDashboardScreenshot(
                    to: URL(fileURLWithPath: screenshotPath),
                    section: section
                )
                NSApplication.shared.terminate(nil)
            }
        }
#endif

        Task {
            await MonitorStore.shared.start()
        }
    }

#if DEBUG
    private func exportDashboardScreenshot(to url: URL, section: DashboardSection) async {
        let content = DashboardView(initialSection: section)
            .environmentObject(MonitorStore.shared)
            .environment(\.locale, Locale(identifier: "en_US"))
        let controller = NSHostingController(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 668, height: 732),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.backgroundColor = .clear
        window.isOpaque = false
        window.orderFrontRegardless()

        try? await Task.sleep(for: .seconds(1))
        guard let view = window.contentView else { return }
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        let bounds = view.bounds
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        view.cacheDisplay(in: bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url, options: .atomic)
        window.orderOut(nil)
    }
#endif
}
