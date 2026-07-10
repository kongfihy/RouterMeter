import SwiftUI
import OpenRouterMonitorCore

struct BalanceHeroCard: View {
    let snapshot: UsageSnapshot?
    let hasActiveAlerts: Bool
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Label("Account balance", systemImage: "creditcard")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(lastUpdatedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if hasActiveAlerts {
                            StatusPill(text: "Budget alert", color: Brand.danger)
                        }
                    }

                    Text(remainingText)
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.66)

                    Text(balanceSubtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 10) {
                    Text(percentText)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: progress)
                .tint(progressColor)
                .accessibilityLabel("Balance remaining")
                .accessibilityValue(percentText)

            HStack(spacing: 12) {
                MiniStat(label: "Total Credits", value: totalCreditsText)
                MiniStat(label: "Used", value: usedText)
                MiniStat(label: "All-Time Usage", value: allTimeUsageText)
            }
        }
        .padding(20)
        .brandedPanel(cornerRadius: 22)
    }

    private var remaining: Double? {
        if let accountRemaining = snapshot?.accountRemainingCredits {
            return accountRemaining
        }
        return snapshot?.keyLimitRemaining
    }

    private var totalCredits: Double? {
        if let totalCredits = snapshot?.totalCredits {
            return totalCredits
        }
        return snapshot?.keyLimit
    }

    private var used: Double? {
        if let accountTotalUsage = snapshot?.accountTotalUsage {
            return accountTotalUsage
        }
        guard let totalCredits, let remaining else { return snapshot?.usageAllTimeIncludingBYOK }
        return max(0, totalCredits - remaining)
    }

    private var progress: Double {
        if let percent = snapshot?.accountPercentRemaining {
            return percent
        }
        guard let totalCredits, totalCredits > 0, let remaining else { return snapshot == nil ? 0 : 1 }
        return max(0, min(1, remaining / totalCredits))
    }

    private var progressColor: Color {
        if hasActiveAlerts {
            return Brand.danger
        }
        return progress < 0.15 ? Brand.warning : Brand.accentSecondary
    }

    private var remainingText: String {
        money(remaining)
    }

    private var totalCreditsText: String {
        money(totalCredits)
    }

    private var usedText: String {
        money(used)
    }

    private var allTimeUsageText: String {
        money(snapshot?.usageAllTimeIncludingBYOK)
    }

    private var percentText: String {
        "\(Int((progress * 100).rounded()))%"
    }

    private var balanceSubtitle: String {
        if snapshot?.accountRemainingCredits != nil {
            return "Account credit balance from OpenRouter credits"
        }
        if snapshot?.keyLimitRemaining != nil {
            return "API-key limit balance from the current key"
        }
        if snapshot != nil {
            return "All-time usage is available, but no balance limit was returned"
        }
        return "Add an API key in Settings, then refresh"
    }

    private var lastUpdatedText: String {
        guard let date = snapshot?.capturedAt else { return "Not refreshed yet" }
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .full
        return "Updated \(relativeFormatter.localizedString(for: date, relativeTo: Date()))"
    }

    private func money(_ value: Double?) -> String {
        guard let value else { return "-" }
        return formatter.string(fromUSDCredits: value)
    }
}

struct UsageMetricGrid: View {
    let snapshot: UsageSnapshot?
    let activitySummary: ActivityUsageSummary?
    let burnDownSummary: CreditBurnDownSummary?
    let budget: BudgetSettings
    let formatter: MoneyFormatter

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            UsageMetricCard(
                title: "Today",
                value: money(todaySpend),
                detail: requestDetail(todayRequests, fallback: unavailableDetail),
                systemImage: "sun.max",
                tint: Brand.warning,
                isUnavailable: todaySpend == nil
            )

            UsageMetricCard(
                title: "Last 7 Days",
                value: money(sevenDaySpend),
                detail: requestDetail(sevenDayRequests, fallback: unavailableDetail),
                systemImage: "calendar",
                tint: Brand.accent
            )

            UsageMetricCard(
                title: activitySummary == nil ? "This Month" : "Last 30 Days",
                value: money(monthSpend),
                detail: averageDailyDetail,
                systemImage: "chart.line.uptrend.xyaxis",
                tint: Brand.accentSecondary,
                isUnavailable: monthSpend == nil
            )

            UsageMetricCard(
                title: "Budget Health",
                value: budgetHealthValue,
                detail: budgetHealthDetail,
                systemImage: "heart.text.square",
                tint: budgetHealthTint
            )
        }
    }

    private var todaySpend: Double? {
        if let activitySummary {
            return activitySummary.latestDayUsage
        }
        return sanitizedSnapshotUsage(snapshot?.usageDailyIncludingBYOK)
    }

    private var sevenDaySpend: Double? {
        if let activitySummary {
            return activitySummary.last7DaysUsage
        }
        return sanitizedSnapshotUsage(snapshot?.usageWeeklyIncludingBYOK)
    }

    private var monthSpend: Double? {
        if let activitySummary {
            return activitySummary.last30DaysUsage
        }
        return sanitizedSnapshotUsage(snapshot?.usageMonthlyIncludingBYOK)
    }

    private var todayRequests: Int? {
        activitySummary?.trend.last?.requests
    }

    private var sevenDayRequests: Int? {
        guard let trend = activitySummary?.trend else { return nil }
        return trend.suffix(7).reduce(0) { $0 + $1.requests }
    }

    private var averageDailySpend: Double? {
        if let activitySummary {
            return activitySummary.last30DaysUsage / Double(max(activitySummary.last30WindowDays, 1))
        }
        guard let monthSpend else { return nil }
        let day = max(1, Calendar.current.component(.day, from: Date()))
        return monthSpend / Double(day)
    }

    private var averageDailyDetail: String {
        guard let averageDailySpend else { return unavailableDetail }
        return "\(formatter.string(fromUSDCredits: averageDailySpend)) avg / day"
    }

    private var budgetHealthValue: String {
        if let burnDownSummary {
            return "\(burnDownSummary.estimatedDaysRemaining.formatted(.number.precision(.fractionLength(1)))) days"
        }
        if budget.monthlyBudget > 0, let monthSpend {
            let ratio = monthSpend / budget.monthlyBudget
            return ratio >= 1 ? "Over" : "\(Int(((1 - ratio) * 100).rounded()))% left"
        }
        return "No budget"
    }

    private var budgetHealthDetail: String {
        if let burnDownSummary {
            return "\(formatter.string(fromUSDCredits: burnDownSummary.averageDailySpend)) burn rate"
        }
        if budget.monthlyBudget > 0 {
            return "\(formatter.string(fromUSDCredits: budget.monthlyBudget)) monthly budget"
        }
        return "Set budgets in Settings"
    }

    private var budgetHealthTint: Color {
        if let burnDownSummary, burnDownSummary.estimatedDaysRemaining < 7 {
            return Brand.warning
        }
        if budget.monthlyBudget > 0, let monthSpend, monthSpend > budget.monthlyBudget {
            return Brand.danger
        }
        return Brand.accentSecondary
    }

    private var unavailableDetail: String {
        "Activity access needed"
    }

    private func requestDetail(_ requests: Int?, fallback: String) -> String {
        guard let requests else { return fallback }
        return "\(requests.formatted()) requests"
    }

    private func money(_ value: Double?) -> String {
        guard let value else { return "Unavailable" }
        return formatter.string(fromUSDCredits: value)
    }

    private func sanitizedSnapshotUsage(_ value: Double?) -> Double? {
        guard let value else { return nil }
        if value == 0,
           (snapshot?.accountTotalUsage ?? 0) > 0,
           snapshot?.usageAllTimeIncludingBYOK == 0 {
            return nil
        }
        return value
    }
}

#if DEBUG
struct BalanceHeroCard_Previews: PreviewProvider {
    static var previews: some View {
        BalanceHeroCard(
            snapshot: UsageSnapshot(
                capturedAt: Date(),
                keyLabel: "Preview",
                keyLimit: nil,
                keyLimitRemaining: nil,
                usageAllTime: 12,
                usageDaily: 1.5,
                usageWeekly: 5,
                usageMonthly: 12,
                byokUsageAllTime: 0,
                byokUsageDaily: 0,
                byokUsageWeekly: 0,
                byokUsageMonthly: 0,
                totalCredits: 100,
                accountTotalUsage: 32.5
            ),
            hasActiveAlerts: false,
            formatter: MoneyFormatter(currency: .usd, usdToGBP: 0.79)
        )
        .padding()
        .frame(width: 660)
    }
}
#endif
