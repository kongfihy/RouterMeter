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
        .background(.bar)
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
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                        .accessibilityLabel("Refreshing OpenRouter data")
                } else {
                    Image(systemName: "arrow.clockwise")
                        .accessibilityLabel("Refresh OpenRouter data")
                }
            }
            .disabled(isRefreshing)
            .help(isRefreshing ? "Refreshing" : "Refresh now")

            SettingsLink {
                Image(systemName: "gearshape")
                    .accessibilityLabel("Open Settings")
                    .frame(width: 16, height: 16)
            }
            .help("Settings")

            Menu {
                Button {
                    NSWorkspace.shared.open(URL(string: "https://openrouter.ai/activity")!)
                } label: {
                    Label("Open OpenRouter Activity", systemImage: "safari")
                }

                Divider()

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit OpenRouter Monitor", systemImage: "power")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .accessibilityLabel("More actions")
                    .frame(width: 16, height: 16)
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .labelStyle(.iconOnly)
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
        .labelsHidden()
        .accessibilityLabel("Dashboard section")
    }
}
