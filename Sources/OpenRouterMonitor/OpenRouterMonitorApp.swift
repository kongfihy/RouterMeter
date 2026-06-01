import AppKit
import SwiftUI

@main
struct OpenRouterMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = MonitorStore()

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
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let icon = Brand.iconImage {
            NSApp.applicationIconImage = icon
        }
    }
}
