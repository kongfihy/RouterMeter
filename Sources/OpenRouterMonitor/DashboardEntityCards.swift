import SwiftUI
import OpenRouterMonitorCore

struct APIKeysOverviewView: View {
    let keys: [OpenRouterAPIKey]
    let warning: String?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(
                title: "API Keys",
                systemImage: "key.horizontal",
                accessory: keys.isEmpty ? nil : "\(keys.count) keys"
            )

            if keys.isEmpty {
                EmptyPanelMessage(emptyMessage)
                    .frame(minHeight: 150, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(keys.prefix(7))) { key in
                        APIKeyRow(key: key, formatter: formatter)
                        if key.id != keys.prefix(7).last?.id {
                            Divider().overlay(Color.primary.opacity(0.08))
                        }
                    }
                }
            }
        }
        .padding(16)
        .brandedPanel()
    }

    private var emptyMessage: String {
        if let warning, warning.contains("API key list unavailable") {
            return warning
        }
        return "Management key access is required to list API keys."
    }
}

struct APIKeyRow: View {
    let key: OpenRouterAPIKey
    let formatter: MoneyFormatter

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusColor.opacity(0.16))
                Image(systemName: key.disabled ? "xmark" : "key.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(key.displayName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)

                    if let statusText {
                        Text(statusText)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(statusColor.opacity(0.18)))
                            .foregroundStyle(statusColor)
                    }
                }

                Text("Day \(formatter.string(fromUSDCredits: key.totalUsageDaily))  |  Month \(formatter.string(fromUSDCredits: key.totalUsageMonthly))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(limitRemainingText)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text("remaining")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
    }

    private var statusText: String? {
        if key.disabled {
            return "Disabled"
        }
        if let expirationDate = key.expirationDate {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
            if days >= 0 && days <= 14 {
                return "\(days)d left"
            }
        }
        return nil
    }

    private var statusColor: Color {
        if key.disabled {
            return Brand.danger
        }
        return statusText == nil ? Brand.accentSecondary : Brand.warning
    }

    private var limitRemainingText: String {
        guard let limitRemaining = key.limitRemaining else { return "-" }
        return formatter.string(fromUSDCredits: limitRemaining)
    }
}

struct ModelBreakdownCard: View {
    let models: [ModelUsageSummary]
    let trackedModelIDs: Set<String>
    let usesManagementKey: Bool
    let warning: String?
    let formatter: MoneyFormatter
    let trackModel: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader(
                title: "Model Breakdown",
                systemImage: "cube.transparent",
                accessory: models.isEmpty ? nil : "\(models.count) models"
            )

            if models.isEmpty {
                EmptyPanelMessage(emptyMessage)
                    .frame(minHeight: 220, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ModelBreakdownHeader()
                    Divider().overlay(Color.primary.opacity(0.08))

                    ForEach(models) { model in
                        ModelUsageRow(
                            model: model,
                            maxUsage: maxUsage,
                            totalUsage: totalUsage,
                            formatter: formatter,
                            isTracked: trackedModelIDs.contains(model.model.lowercased()),
                            trackModel: trackModel
                        )
                        if model.id != models.last?.id {
                            Divider().overlay(Color.primary.opacity(0.08))
                        }
                    }
                }
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .brandedPanel()
    }

    private var maxUsage: Double {
        max(models.map(\.usage).max() ?? 0.001, 0.001)
    }

    private var totalUsage: Double {
        max(models.reduce(0) { $0 + $1.usage }, 0.001)
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

private struct ModelBreakdownHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Provider")
                .frame(width: 72, alignment: .leading)
            Text("Model")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Req")
                .frame(width: 44, alignment: .trailing)
            Text("Tokens")
                .frame(width: 64, alignment: .trailing)
            Text("Cost")
                .frame(width: 74, alignment: .trailing)
            Text("Share")
                .frame(width: 52, alignment: .trailing)
            Color.clear
                .frame(width: 24, height: 1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct ModelUsageRow: View {
    let model: ModelUsageSummary
    let maxUsage: Double
    let totalUsage: Double
    let formatter: MoneyFormatter
    let isTracked: Bool
    let trackModel: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(providerText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 72, alignment: .leading)

                Text(model.model)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(model.requests.formatted())
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)

                Text(model.totalTokens.formatted(.number.notation(.compactName)))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 64, alignment: .trailing)

                Text(formatter.string(fromUSDCredits: model.usage))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 74, alignment: .trailing)

                Text(shareText)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)

                Button {
                    trackModel(model.model)
                } label: {
                    Image(systemName: isTracked ? "checkmark" : "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .disabled(isTracked)
                .help(isTracked ? "Price already tracked" : "Track this model's price")
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(Brand.actionGradient)
                        .frame(width: proxy.size.width * min(1, model.usage / maxUsage))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private var providerText: String {
        model.providerName.isEmpty ? "-" : model.providerName
    }

    private var shareText: String {
        "\((model.usage / totalUsage * 100).formatted(.number.precision(.fractionLength(0))))%"
    }
}

#if DEBUG
struct ModelBreakdownCard_Previews: PreviewProvider {
    static var previews: some View {
        ModelBreakdownCard(
            models: [
                ModelUsageSummary(model: "openai/gpt-4.1", providerName: "OpenAI", requests: 124, usage: 12.4, promptTokens: 120_000, completionTokens: 90_000, reasoningTokens: 0),
                ModelUsageSummary(model: "anthropic/claude-sonnet-4", providerName: "Anthropic", requests: 88, usage: 9.8, promptTokens: 95_000, completionTokens: 76_000, reasoningTokens: 12_000)
            ],
            trackedModelIDs: [],
            usesManagementKey: true,
            warning: nil,
            formatter: MoneyFormatter(currency: .usd, usdToGBP: 0.79),
            trackModel: { _ in }
        )
        .padding()
        .frame(width: 660)
    }
}
#endif
