import Charts
import SwiftUI
import OpenRouterMonitorCore

struct SpendTrendView: View {
    let summary: ActivityUsageSummary?
    let warning: String?
    let formatter: MoneyFormatter
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(
                title: "Spend Trend",
                systemImage: "waveform.path.ecg",
                accessory: summary.map { "Last \($0.last30WindowDays) days" }
            )

            if let summary, !summary.trend.isEmpty {
                HStack(spacing: 14) {
                    ChartLegendKey(title: "Total spend", color: Brand.accent)
                    ChartLegendKey(title: "BYOK", color: Brand.accentSecondary)

                    Spacer()

                    if let selectedPoint {
                        Text(
                            "\(selectedPoint.date.formatted(date: .abbreviated, time: .omitted)) · "
                                + "\(formatter.string(fromUSDCredits: selectedPoint.totalUsage)) · "
                                + "\(selectedPoint.requests.formatted()) requests"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                }

                Chart {
                    ForEach(summary.trend) { point in
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

                    if let selectedPoint {
                        RuleMark(x: .value("Selected day", selectedPoint.date, unit: .day))
                            .foregroundStyle(Color.secondary.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.primary.opacity(0.06))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.primary.opacity(0.08))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatter.string(fromUSDCredits: amount))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedDate)
                .frame(height: 166)

                HStack {
                    MiniStat(label: "Latest", value: formatter.string(fromUSDCredits: summary.latestDayUsage))
                    MiniStat(label: "30d Tokens", value: summary.last30DaysTokens.formatted(.number.notation(.compactName)))
                    MiniStat(label: "30d Requests", value: summary.last30DaysRequests.formatted())
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

    private var selectedPoint: ActivityDaySummary? {
        guard let selectedDate, let trend = summary?.trend else { return nil }
        return trend.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }
}

private struct ChartLegendKey: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
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
