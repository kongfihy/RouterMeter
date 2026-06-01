import SwiftUI
import OpenRouterMonitorCore

struct DashboardView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var store: MonitorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            let snapshot = store.latestSnapshot

            BalanceCard(snapshot: snapshot, formatter: store.moneyFormatter)
            UsageSummaryGrid(snapshot: snapshot, formatter: store.moneyFormatter)
            ModelBreakdownView(
                models: store.topModelSummaries,
                usesManagementKey: store.state.profile.isManagementKey,
                warning: store.state.configuration.lastRefreshError,
                formatter: store.moneyFormatter
            )

            HStack(spacing: 10) {
                Button {
                    Task {
                        await store.refresh()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshing)

                Button {
                    NSWorkspace.shared.open(URL(string: "https://openrouter.ai/activity")!)
                } label: {
                    Label("Dashboard", systemImage: "safari")
                }

                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
        .frame(width: 380)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.10),
                    Color(red: 0.10, green: 0.12, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .tint(Brand.accent)
        .onAppear {
            store.startAutoRefresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                BrandIcon(size: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text("OpenRouter Monitor")
                        .font(.headline)
                    Text(store.state.profile.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(store.state.configuration.lastRefreshStatus)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(store.state.configuration.lastRefreshStatus == "Connected" ? Brand.accentSecondary.opacity(0.18) : Color.secondary.opacity(0.14))
                    )
                    .foregroundStyle(store.state.configuration.lastRefreshStatus == "Connected" ? Brand.accentSecondary : .secondary)
            }

            if let capturedAt = store.latestSnapshot?.capturedAt {
                Text("Last updated \(capturedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let error = store.state.configuration.lastRefreshError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Add an API key in Settings, then refresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BalanceCard: View {
    let snapshot: UsageSnapshot?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Balance")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "creditcard")
                    .foregroundStyle(Brand.accent)
            }

            if let snapshot, let total = snapshot.totalCredits, let used = snapshot.accountTotalUsage {
                let remaining = snapshot.accountRemainingCredits ?? 0
                HStack(alignment: .firstTextBaseline) {
                    Text(formatter.string(fromUSDCredits: remaining))
                        .font(.title2.weight(.semibold))
                    Text("remaining")
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ProgressView(value: max(0, remaining), total: max(total, 0.01))
                    .tint(Brand.accentSecondary)

                HStack {
                    Text("\(formatter.string(fromUSDCredits: used)) used")
                    Spacer()
                    Text("\(formatter.string(fromUSDCredits: total)) credits")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if let snapshot, let remaining = snapshot.keyLimitRemaining {
                Text(formatter.string(fromUSDCredits: remaining))
                    .font(.title2.weight(.semibold))
                Text("remaining for this API key limit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Account credit balance needs a management-capable key.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .brandedPanel()
    }
}

private struct UsageSummaryGrid: View {
    let snapshot: UsageSnapshot?
    let formatter: MoneyFormatter

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                MetricTile(title: "Today", value: money(snapshot?.usageDaily))
                MetricTile(title: "This Week", value: money(snapshot?.usageWeekly))
            }
            GridRow {
                MetricTile(title: "This Month", value: money(snapshot?.usageMonthly))
                MetricTile(title: "All Time", value: money(snapshot?.usageAllTime))
            }
        }
    }

    private func money(_ value: Double?) -> String {
        guard let value else { return "-" }
        return formatter.string(fromUSDCredits: value)
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .brandedPanel()
    }
}

private struct ModelBreakdownView: View {
    let models: [ModelUsageSummary]
    let usesManagementKey: Bool
    let warning: String?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Model Breakdown")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chart.pie")
                    .foregroundStyle(Brand.accent)
            }

            if models.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(models) { model in
                        ModelUsageRow(model: model, formatter: formatter)
                    }
                }
            }
        }
        .padding(14)
        .brandedPanel()
    }

    private var emptyMessage: String {
        if let warning, warning.contains("Model activity unavailable") {
            return warning
        }
        if usesManagementKey {
            return "No model activity returned for the last 30 completed UTC days."
        }
        return "Enable a management-capable key in Settings to fetch OpenRouter activity grouped by model."
    }
}

private struct ModelUsageRow: View {
    let model: ModelUsageSummary
    let formatter: MoneyFormatter

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(model.requests) requests · \(formattedTokens)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(formatter.string(fromUSDCredits: model.usage))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }

    private var displayName: String {
        model.providerName.isEmpty ? model.model : "\(model.providerName) · \(model.model)"
    }

    private var formattedTokens: String {
        model.totalTokens.formatted(.number.notation(.compactName))
    }
}
