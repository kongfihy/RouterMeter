import SwiftUI
import OpenRouterMonitorCore

struct ModelPricingTrackerView: View {
    let rows: [TrackedModelPricingRow]
    let lastUpdatedAt: Date?
    let error: String?
    let isRefreshing: Bool
    let refresh: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                PanelHeader(
                    title: "Tracked Model Prices",
                    systemImage: "tag",
                    accessory: rows.isEmpty ? nil : "\(rows.count) models"
                )

                Spacer()

                Button {
                    Task {
                        await refresh()
                    }
                } label: {
                    Label(isRefreshing ? "Refreshing" : "Refresh Prices", systemImage: "arrow.clockwise")
                }
                .buttonStyle(ProminentActionButtonStyle())
                .disabled(isRefreshing || rows.isEmpty)
                .frame(width: 160)
            }

            if let lastUpdatedAt {
                Text("Last updated \(lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error {
                EmptyPanelMessage(error)
            }

            if rows.isEmpty {
                EmptyModelPricingView()
            } else {
                VStack(spacing: 0) {
                    ModelPricingHeader()
                    Divider().overlay(Color.white.opacity(0.08))

                    ForEach(rows) { row in
                        ModelPricingRowView(row: row)
                        if row.id != rows.last?.id {
                            Divider().overlay(Color.white.opacity(0.08))
                        }
                    }
                }
                .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .brandedPanel()
    }
}

private struct ModelPricingHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            Text("Model")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Input / 1M")
                .frame(width: 92, alignment: .trailing)
            Text("Output / 1M")
                .frame(width: 96, alignment: .trailing)
            Text("Context")
                .frame(width: 78, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct ModelPricingRowView: View {
    let row: TrackedModelPricingRow

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.model?.name ?? row.requestedID)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(row.model?.id ?? "Model not found in latest OpenRouter catalog")
                    .font(.caption)
                    .foregroundStyle(row.model == nil ? Brand.warning : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PriceCell(value: row.model?.pricing.promptPricePerMillion)
                .frame(width: 92, alignment: .trailing)

            PriceCell(value: row.model?.pricing.completionPricePerMillion)
                .frame(width: 96, alignment: .trailing)

            Text(contextText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var contextText: String {
        guard let contextLength = row.model?.contextLength else { return "-" }
        return contextLength.formatted(.number.notation(.compactName))
    }
}

private struct PriceCell: View {
    let value: Double?

    var body: some View {
        Text(priceText)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(value == 0 ? Brand.accentSecondary : .primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var priceText: String {
        guard let value else { return "-" }
        if value == 0 {
            return "Free"
        }
        if value < 0.01 {
            return "$\(value.formatted(.number.precision(.fractionLength(4))))"
        }
        return "$\(value.formatted(.number.precision(.fractionLength(2))))"
    }
}

private struct EmptyModelPricingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "tag")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Brand.accent)

            Text("No tracked models yet")
                .font(.headline.weight(.semibold))

            Text("Add OpenRouter model IDs in Settings, then refresh prices here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .center)
        .padding(18)
    }
}
