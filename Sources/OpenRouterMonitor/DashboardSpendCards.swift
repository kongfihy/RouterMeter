import Charts
import SwiftUI
import OpenRouterMonitorCore

struct SpendTrendView: View {
    let summary: ActivityUsageSummary?
    let warning: String?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(
                title: "Spend Trend",
                systemImage: "waveform.path.ecg",
                accessory: summary.map { "\($0.trend.count)d" }
            )

            if let summary, !summary.trend.isEmpty {
                Chart(summary.trend) { point in
                    AreaMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Spend", point.totalUsage)
                    )
                    .foregroundStyle(Brand.accent.opacity(0.20))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Spend", point.totalUsage)
                    )
                    .foregroundStyle(Brand.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                    if point.byokUsage > 0 {
                        BarMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("BYOK", point.byokUsage)
                        )
                        .foregroundStyle(Brand.accentSecondary.opacity(0.72))
                        .cornerRadius(3)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.08))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatter.string(fromUSDCredits: amount))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 166)

                HStack {
                    MiniStat(label: "Latest", value: formatter.string(fromUSDCredits: summary.latestDayUsage))
                    MiniStat(label: "Tokens", value: summary.last30DaysTokens.formatted(.number.notation(.compactName)))
                }
            } else {
                EmptyPanelMessage(emptyMessage)
                    .frame(height: 166, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .brandedPanel()
    }

    private var emptyMessage: String {
        if let warning, warning.contains("Model activity unavailable") {
            return warning
        }
        return "Activity data is required for the spend trend widget."
    }
}

struct BYOKUsageView: View {
    let summary: ActivityUsageSummary?
    let warning: String?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: "BYOK Split", systemImage: "person.crop.rectangle.stack")

            if let summary, summary.last30DaysUsage > 0 {
                UsageSplitBar(share: byokShare(summary: summary))
                SmallMetric(label: "30d BYOK", value: formatter.string(fromUSDCredits: summary.last30DaysByokUsage))
                SmallMetric(label: "30d OpenRouter", value: formatter.string(fromUSDCredits: summary.last30DaysOpenRouterUsage))
                SmallMetric(label: "BYOK Share", value: shareString(summary: summary))
                SmallMetric(label: "Latest BYOK", value: formatter.string(fromUSDCredits: summary.latestDayByokUsage))
            } else {
                EmptyPanelMessage(emptyMessage)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 178, alignment: .topLeading)
        .padding(16)
        .brandedPanel()
    }

    private func byokShare(summary: ActivityUsageSummary) -> Double {
        min(1, max(0, summary.last30DaysByokUsage / max(summary.last30DaysUsage, 0.000_001)))
    }

    private func shareString(summary: ActivityUsageSummary) -> String {
        "\((byokShare(summary: summary) * 100).formatted(.number.precision(.fractionLength(0))))%"
    }

    private var emptyMessage: String {
        if let warning, warning.contains("Model activity unavailable") {
            return warning
        }
        return "No recent BYOK activity returned."
    }
}

struct BurnDownView: View {
    let summary: CreditBurnDownSummary?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: "Credit Burn-Down", systemImage: "hourglass.bottomhalf.filled")

            if let summary {
                Text("\(summary.estimatedDaysRemaining.formatted(.number.precision(.fractionLength(1)))) days")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                SmallMetric(label: "Avg / day", value: formatter.string(fromUSDCredits: summary.averageDailySpend))
                SmallMetric(label: "Remaining", value: formatter.string(fromUSDCredits: summary.remainingCredits))
                SmallMetric(label: "Exhaustion", value: summary.exhaustionDate.formatted(date: .abbreviated, time: .omitted))
            } else {
                EmptyPanelMessage("Burn-down appears when credits and recent activity are both available.")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 178, alignment: .topLeading)
        .padding(16)
        .brandedPanel()
    }
}
