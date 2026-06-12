import AppKit
import SwiftUI

struct AppHeader: View {
    @Binding var selectedSection: DashboardSection
    let statusText: String
    let statusColor: Color
    let isRefreshing: Bool
    let refresh: () async -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                HStack(spacing: 10) {
                    BrandIcon(size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OpenRouter Monitor")
                            .font(.headline.weight(.semibold))
                        StatusPill(text: statusText, color: statusColor)
                    }
                }

                Spacer()

                AppToolbar(isRefreshing: isRefreshing, refresh: refresh)
            }

            NavigationTabs(selection: $selectedSection)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
    }
}

struct AppToolbar: View {
    let isRefreshing: Bool
    let refresh: () async -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                Task {
                    await refresh()
                }
            } label: {
                Label(isRefreshing ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)

            Button {
                NSWorkspace.shared.open(URL(string: "https://openrouter.ai/activity")!)
            } label: {
                Label("Dashboard", systemImage: "safari")
            }

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .accessibilityLabel("Quit OpenRouter Monitor")
            }
            .help("Quit")
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .labelStyle(.titleAndIcon)
    }
}

struct NavigationTabs: View {
    @Binding var selection: DashboardSection

    var body: some View {
        Picker("Dashboard section", selection: $selection) {
            ForEach(DashboardSection.allCases) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .accessibilityLabel("Dashboard section")
    }
}
