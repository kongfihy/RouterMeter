import SwiftUI
import OpenRouterMonitorCore

struct DashboardView: View {
    @EnvironmentObject private var store: MonitorStore
    @State private var selectedSection: DashboardSection = .overview

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(
                selectedSection: $selectedSection,
                statusText: store.state.configuration.lastRefreshStatus,
                statusColor: statusColor,
                isRefreshing: store.isRefreshing
            ) {
                await store.refresh()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedSection {
                    case .overview:
                        OverviewSection()
                    case .models:
                        ModelsSection()
                    case .activity:
                        ActivitySection()
                    case .settings:
                        DashboardSettingsSection()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 668, height: 732)
        .background(DashboardBackground())
        .foregroundStyle(.primary)
        .tint(Brand.accent)
        .onAppear {
            store.startAutoRefresh()
            Task {
                await store.refreshModelPricingIfNeeded()
            }
        }
    }

    private var statusColor: Color {
        switch store.state.configuration.lastRefreshStatus {
        case "Connected":
            return Brand.accentSecondary
        case "Refresh failed":
            return Brand.danger
        default:
            return Brand.warning
        }
    }
}

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview
    case models
    case activity
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .models: return "Models"
        case .activity: return "Activity"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.bottom.50percent"
        case .models: return "cube.transparent"
        case .activity: return "chart.xyaxis.line"
        case .settings: return "slider.horizontal.3"
        }
    }
}

private struct OverviewSection: View {
    @EnvironmentObject private var store: MonitorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BalanceHeroCard(
                snapshot: store.latestSnapshot,
                status: store.state.configuration.lastRefreshStatus,
                formatter: store.moneyFormatter
            )

            UsageMetricGrid(
                snapshot: store.latestSnapshot,
                activitySummary: store.activityUsageSummary,
                burnDownSummary: store.burnDownSummary,
                budget: store.state.budget,
                formatter: store.moneyFormatter
            )
        }
    }
}

private struct ModelsSection: View {
    @EnvironmentObject private var store: MonitorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModelBreakdownCard(
                models: store.topModelSummaries,
                usesManagementKey: store.state.profile.isManagementKey,
                warning: store.state.configuration.lastRefreshError,
                formatter: store.moneyFormatter
            )

            ModelPricingTrackerView(
                rows: store.trackedModelPricingRows,
                lastUpdatedAt: store.state.configuration.modelPricingLastUpdatedAt,
                error: store.state.configuration.modelPricingError,
                isRefreshing: store.isRefreshingModelPrices
            ) {
                await store.refreshModelPricing()
            }
        }
    }
}

private struct ActivitySection: View {
    @EnvironmentObject private var store: MonitorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SpendTrendView(
                summary: store.activityUsageSummary,
                warning: store.state.configuration.lastRefreshError,
                formatter: store.moneyFormatter
            )

            HStack(alignment: .top, spacing: 16) {
                BYOKUsageView(
                    summary: store.activityUsageSummary,
                    warning: store.state.configuration.lastRefreshError,
                    formatter: store.moneyFormatter
                )

                BurnDownView(summary: store.burnDownSummary, formatter: store.moneyFormatter)
            }

            APIKeysOverviewView(
                keys: store.sortedAPIKeys,
                warning: store.state.configuration.lastRefreshError,
                formatter: store.moneyFormatter
            )
        }
    }
}

private struct DashboardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)

            LinearGradient(
                colors: colorScheme == .dark ? darkColors : lightColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var darkColors: [Color] {
        [
            Color(red: 0.06, green: 0.07, blue: 0.09).opacity(0.96),
            Color(red: 0.09, green: 0.10, blue: 0.12).opacity(0.90),
            Color(red: 0.04, green: 0.08, blue: 0.07).opacity(0.92)
        ]
    }

    private var lightColors: [Color] {
        [
            Color(red: 0.95, green: 0.97, blue: 1.0).opacity(0.92),
            Color(red: 0.90, green: 0.94, blue: 0.96).opacity(0.86),
            Color(red: 0.98, green: 0.99, blue: 0.96).opacity(0.90)
        ]
    }
}
