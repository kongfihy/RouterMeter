import SwiftUI
import OpenRouterMonitorCore

struct DashboardView: View {
    @EnvironmentObject private var store: MonitorStore
    @State private var selectedSection: DashboardSection

    init(initialSection: DashboardSection = .overview) {
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(
                selectedSection: $selectedSection,
                statusText: store.connectionState.label,
                statusColor: statusColor,
                isRefreshing: store.isRefreshing
            ) {
                await store.refresh()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Color.clear
                            .frame(height: 0)
                            .id("dashboard-top")

                        switch selectedSection {
                        case .overview:
                            OverviewSection()
                        case .models:
                            ModelsSection()
                        case .activity:
                            ActivitySection()
                        case .logs:
                            GenerationLogsView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
                .scrollIndicators(.visible)
                .onChange(of: selectedSection) { _, _ in
                    proxy.scrollTo("dashboard-top", anchor: .top)
                }
            }
        }
        .frame(width: 668, height: 732)
        .background(DashboardBackground())
        .foregroundStyle(.primary)
        .tint(Brand.accent)
        .task {
            await store.start()
        }
    }

    private var statusColor: Color {
        switch store.connectionState {
        case .connected:
            return Brand.accentSecondary
        case .offline:
            return Brand.danger
        case .partial, .stale:
            return Brand.warning
        case .refreshing:
            return Brand.accent
        case .setupNeeded:
            return .secondary
        }
    }
}

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview
    case models
    case activity
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .models: return "Models"
        case .activity: return "Activity"
        case .logs: return "Logs"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.bottom.50percent"
        case .models: return "cube.transparent"
        case .activity: return "chart.xyaxis.line"
        case .logs: return "list.bullet.rectangle.portrait"
        }
    }
}

private struct OverviewSection: View {
    @EnvironmentObject private var store: MonitorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BalanceHeroCard(
                snapshot: store.latestSnapshot,
                hasActiveAlerts: store.hasActiveAlerts,
                formatter: store.moneyFormatter
            )

            UsageMetricGrid(
                snapshot: store.latestSnapshot,
                localDayUsage: store.currentLocalDayUsage,
                activitySummary: store.activityUsageSummary,
                burnDownSummary: store.burnDownSummary,
                budget: store.state.budget,
                formatter: store.moneyFormatter
            )

            SpendForecastView(
                summary: store.spendForecastSummary,
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
                trackedModelIDs: Set(store.state.configuration.trackedModelIDs.map { $0.lowercased() }),
                usesManagementKey: store.state.profile.isManagementKey,
                warning: store.state.configuration.lastRefreshError,
                formatter: store.moneyFormatter
            ) { modelID in
                if store.addTrackedModelID(modelID) {
                    Task { await store.refreshModelPricing() }
                }
            }

            ModelPricingTrackerView(
                rows: store.trackedModelPricingRows,
                lastUpdatedAt: store.state.configuration.modelPricingLastUpdatedAt,
                error: store.state.configuration.modelPricingError,
                isRefreshing: store.isRefreshingModelPrices
            ) {
                await store.refreshModelPricing()
            }

            ModelWatchView(
                trackedCount: store.state.configuration.trackedModelIDs.count,
                changes: store.recentModelCatalogChanges,
                formatter: store.moneyFormatter
            )
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

            KeyHealthView(
                summary: store.keyHealthSummary,
                warning: store.state.configuration.lastRefreshError,
                formatter: store.moneyFormatter
            )

            APIKeysOverviewView(
                keys: store.sortedAPIKeys,
                warning: store.state.configuration.lastRefreshError,
                formatter: store.moneyFormatter
            )
        }
    }
}

private struct DashboardBackground: View {
    var body: some View {
        Color(nsColor: .windowBackgroundColor)
    }
}
