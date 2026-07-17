import SwiftUI
import OpenRouterMonitorCore

struct SpendForecastView: View {
    let summary: SpendForecastSummary?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader(
                title: "Smart Forecast",
                systemImage: "sparkles",
                accessory: summary.map { "\($0.daysRemainingInMonth) days left" }
            )

            if let summary {
                HStack(spacing: 12) {
                    MiniStat(
                        label: "Projected Month-End",
                        value: formatter.string(fromUSDCredits: summary.projectedMonthEndSpend)
                    )
                    MiniStat(
                        label: "Current Month",
                        value: formatter.string(fromUSDCredits: summary.monthToDateSpend)
                    )
                    MiniStat(
                        label: "Recent Daily Pace",
                        value: formatter.string(fromUSDCredits: summary.averageDailySpend)
                    )
                }

                if summary.monthlyBudget > 0 {
                    ProgressView(value: budgetProgress(summary))
                        .tint(budgetTint(summary))
                        .accessibilityLabel("Projected monthly budget usage")
                        .accessibilityValue(budgetProgressText(summary))
                }

                Label(insightText(summary), systemImage: insightIcon(summary))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(insightColor(summary))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                EmptyPanelMessage("Forecasts appear after recent activity data is available.")
                    .frame(minHeight: 92, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .brandedPanel()
    }

    private func budgetProgress(_ summary: SpendForecastSummary) -> Double {
        min(1, max(0, summary.projectedMonthEndSpend / max(summary.monthlyBudget, 0.000_001)))
    }

    private func budgetProgressText(_ summary: SpendForecastSummary) -> String {
        "\(Int((budgetProgress(summary) * 100).rounded()))% of monthly budget"
    }

    private func budgetTint(_ summary: SpendForecastSummary) -> Color {
        (summary.projectedBudgetDifference ?? 0) > 0 ? Brand.warning : Brand.accentSecondary
    }

    private func insightText(_ summary: SpendForecastSummary) -> String {
        if summary.isSpendSpike, let pace = summary.paceChangeRatio {
            let percent = Int((pace * 100).rounded())
            return "Recent spend is \(percent)% above the previous week; projected month-end spend is \(formatter.string(fromUSDCredits: summary.projectedMonthEndSpend))."
        }
        if let difference = summary.projectedBudgetDifference {
            if difference > 0 {
                return "Projected to exceed the monthly budget by \(formatter.string(fromUSDCredits: difference))."
            }
            return "Projected to finish \(formatter.string(fromUSDCredits: abs(difference))) under the monthly budget."
        }
        if let pace = summary.paceChangeRatio {
            let percent = Int((abs(pace) * 100).rounded())
            return pace >= 0
                ? "Recent spend is \(percent)% above the previous week."
                : "Recent spend is \(percent)% below the previous week."
        }
        return "Building a week-over-week baseline from recent activity."
    }

    private func insightIcon(_ summary: SpendForecastSummary) -> String {
        if (summary.projectedBudgetDifference ?? 0) > 0 || summary.isSpendSpike {
            return "exclamationmark.triangle.fill"
        }
        return "checkmark.circle.fill"
    }

    private func insightColor(_ summary: SpendForecastSummary) -> Color {
        if (summary.projectedBudgetDifference ?? 0) > 0 || summary.isSpendSpike {
            return Brand.warning
        }
        return Brand.accentSecondary
    }
}

struct ModelWatchView: View {
    let trackedCount: Int
    let changes: [ModelCatalogChange]
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(
                title: "Model Watch",
                systemImage: "bell.and.waves.left.and.right",
                accessory: trackedCount == 0 ? nil : "\(trackedCount) watched"
            )

            if trackedCount == 0 {
                EmptyPanelMessage("Track model prices to monitor pricing, context, expiry, and availability changes.")
                    .frame(minHeight: 100, alignment: .center)
            } else if changes.isEmpty {
                Label("No tracked-model changes detected", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Brand.accentSecondary)
                    .padding(.vertical, 16)

                Text("RouterMeter compares each refreshed catalog snapshot with the previous one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(changes.prefix(5))) { change in
                        ModelChangeRow(change: change, formatter: formatter)
                        if change.id != changes.prefix(5).last?.id {
                            Divider().overlay(Color.primary.opacity(0.08))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .brandedPanel()
    }
}

private struct ModelChangeRow: View {
    let change: ModelCatalogChange
    let formatter: MoneyFormatter

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(change.modelName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(change.detectedAt, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 9)
    }

    private var icon: String {
        switch change.kind {
        case .priceIncreased: return "arrow.up.right"
        case .priceDecreased: return "arrow.down.right"
        case .pricingChanged: return "dollarsign.arrow.circlepath"
        case .contextChanged: return "rectangle.expand.diagonal"
        case .expirationScheduled: return "calendar.badge.exclamationmark"
        case .unavailable: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch change.kind {
        case .priceIncreased, .expirationScheduled, .unavailable: return Brand.warning
        case .priceDecreased: return Brand.accentSecondary
        case .pricingChanged, .contextChanged: return Brand.accent
        }
    }

    private var detail: String {
        switch change.kind {
        case .priceIncreased, .priceDecreased, .pricingChanged:
            let prompt = priceChange("Input", old: change.previousPromptPrice, new: change.currentPromptPrice)
            let completion = priceChange("Output", old: change.previousCompletionPrice, new: change.currentCompletionPrice)
            return [prompt, completion].compactMap { $0 }.joined(separator: " · ")
        case .contextChanged:
            return "Context \(context(change.previousContextLength)) → \(context(change.currentContextLength))"
        case .expirationScheduled:
            return "Scheduled to expire \(change.expirationDate?.formatted(date: .abbreviated, time: .omitted) ?? "soon")"
        case .unavailable:
            return "No longer present in the latest OpenRouter catalog"
        }
    }

    private func priceChange(_ label: String, old: Double?, new: Double?) -> String? {
        guard old != nil || new != nil else { return nil }
        return "\(label) \(price(old)) → \(price(new)) / 1M"
    }

    private func price(_ value: Double?) -> String {
        guard let value else { return "-" }
        return formatter.string(fromUSDCredits: value)
    }

    private func context(_ value: Int?) -> String {
        guard let value else { return "-" }
        return value.formatted(.number.notation(.compactName))
    }
}

struct KeyHealthView: View {
    let summary: KeyHealthSummary
    let warning: String?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(
                title: "Key Health",
                systemImage: "key.radiowaves.forward",
                accessory: summary.issues.isEmpty ? "All clear" : "\(summary.issues.count) issue\(summary.issues.count == 1 ? "" : "s")"
            )

            HStack(spacing: 12) {
                MiniStat(label: "Monitored", value: summary.totalKeys.formatted())
                MiniStat(label: "Disabled", value: summary.disabledKeys.formatted())
                MiniStat(label: "Current Reset", value: resetText)
            }

            if summary.issues.isEmpty {
                Label("No expiring or near-limit keys detected", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Brand.accentSecondary)

                if let warning, warning.contains("API key list unavailable") {
                    Text("Only the current key could be checked because the key list was unavailable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summary.issues.prefix(5))) { issue in
                        KeyHealthIssueRow(issue: issue, formatter: formatter)
                        if issue.id != summary.issues.prefix(5).last?.id {
                            Divider().overlay(Color.primary.opacity(0.08))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .brandedPanel()
    }

    private var resetText: String {
        guard let reset = summary.currentResetCadence, !reset.isEmpty else { return "No reset" }
        return reset.capitalized
    }
}

private struct KeyHealthIssueRow: View {
    let issue: KeyHealthIssue
    let formatter: MoneyFormatter

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(issue.keyName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 9)
    }

    private var icon: String {
        switch issue.kind {
        case .expired: return "xmark.circle.fill"
        case .expiringSoon: return "calendar.badge.exclamationmark"
        case .nearLimit: return "gauge.with.dots.needle.0percent"
        }
    }

    private var color: Color {
        issue.kind == .expired ? Brand.danger : Brand.warning
    }

    private var detail: String {
        switch issue.kind {
        case .expired:
            return "Expired"
        case .expiringSoon:
            return "Expires in \(max(0, issue.daysRemaining ?? 0)) days"
        case .nearLimit:
            let remaining = formatter.string(fromUSDCredits: issue.limitRemaining ?? 0)
            let reset = issue.resetCadence.map { " · \($0.capitalized) reset" } ?? ""
            return "\(remaining) remaining\(reset)"
        }
    }
}
