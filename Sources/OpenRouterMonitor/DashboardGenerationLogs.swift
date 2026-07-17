import AppKit
import SwiftUI
import OpenRouterMonitorCore

struct GenerationLogsView: View {
    @EnvironmentObject private var store: MonitorStore
    @State private var searchText = ""
    @State private var selectedGenerationID: String?
    @State private var sortOrder: GenerationLogSortOrder = .recent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GenerationLogSummaryGrid(
                logs: filteredLogs,
                formatter: store.moneyFormatter
            )

            GenerationLogBrowser(
                logs: filteredLogs,
                searchText: $searchText,
                selectedGenerationID: $selectedGenerationID,
                sortOrder: $sortOrder,
                usesManagementKey: store.state.profile.isManagementKey,
                isRefreshing: store.isRefreshingGenerationLogs,
                lastUpdatedAt: store.state.configuration.lastGenerationLogRefreshAt,
                warning: store.state.configuration.lastGenerationLogError,
                formatter: store.moneyFormatter
            ) {
                await store.refreshGenerationLogs()
            }

            if let selectedGeneration {
                GenerationDetailCard(
                    generation: selectedGeneration,
                    formatter: store.moneyFormatter
                )
            }
        }
        .task {
            if store.state.profile.isManagementKey,
               store.state.configuration.generationLogsEnabled,
               store.state.capturedGenerations.isEmpty {
                await store.refreshGenerationLogs()
            }
        }
        .task(id: selectedGenerationID) {
            guard let selectedGenerationID,
                  let generation = store.state.capturedGenerations.first(where: { $0.generationID == selectedGenerationID }),
                  generation.providerName == nil,
                  generation.latencySeconds == nil else { return }
            await store.loadGenerationDetails(id: selectedGenerationID)
        }
    }

    private var filteredLogs: [CapturedGeneration] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matching = store.sortedCapturedGenerations.filter { generation in
            query.isEmpty
                || generation.model.lowercased().contains(query)
                || generation.generationID.lowercased().contains(query)
                || (generation.providerName?.lowercased().contains(query) ?? false)
                || generation.statusLabel.lowercased().contains(query)
        }

        switch sortOrder {
        case .recent:
            return matching.sorted { $0.displayDate > $1.displayDate }
        case .cost:
            return matching.sorted {
                if $0.totalCost == $1.totalCost { return $0.displayDate > $1.displayDate }
                return $0.totalCost > $1.totalCost
            }
        case .tokens:
            return matching.sorted {
                if $0.totalTokens == $1.totalTokens { return $0.displayDate > $1.displayDate }
                return $0.totalTokens > $1.totalTokens
            }
        }
    }

    private var selectedGeneration: CapturedGeneration? {
        guard let selectedGenerationID else { return nil }
        return store.state.capturedGenerations.first { $0.generationID == selectedGenerationID }
    }
}

private enum GenerationLogSortOrder: String, CaseIterable, Identifiable {
    case recent
    case cost
    case tokens

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "Recent"
        case .cost: return "Cost"
        case .tokens: return "Tokens"
        }
    }
}

private struct GenerationLogSummaryGrid: View {
    let logs: [CapturedGeneration]
    let formatter: MoneyFormatter

    var body: some View {
        HStack(spacing: 12) {
            UsageMetricCard(
                title: "Requests",
                value: logs.count.formatted(),
                detail: "Generation-level rows in the current view",
                systemImage: "list.bullet.rectangle",
                tint: Brand.accent
            )
            UsageMetricCard(
                title: "Cost",
                value: formatter.detailedUsageString(fromUSDCredits: logs.reduce(0) { $0 + $1.totalCost }),
                detail: "Total cost across the current view",
                systemImage: "dollarsign.circle",
                tint: Brand.accentSecondary
            )
            UsageMetricCard(
                title: "Tokens",
                value: logs.reduce(0) { $0 + $1.totalTokens }.formatted(.number.notation(.compactName)),
                detail: "Prompt, completion, and reasoning tokens",
                systemImage: "number.circle",
                tint: Brand.warning
            )
        }
    }
}

private struct GenerationLogBrowser: View {
    let logs: [CapturedGeneration]
    @Binding var searchText: String
    @Binding var selectedGenerationID: String?
    @Binding var sortOrder: GenerationLogSortOrder
    let usesManagementKey: Bool
    let isRefreshing: Bool
    let lastUpdatedAt: Date?
    let warning: String?
    let formatter: MoneyFormatter
    let refresh: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                PanelHeader(
                    title: "Request Logs",
                    systemImage: "list.bullet.rectangle.portrait",
                    accessory: logs.isEmpty ? nil : "\(logs.count) rows"
                )

                Button {
                    Task { await refresh() }
                } label: {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isRefreshing || !usesManagementKey)
                .help("Refresh generation logs")
            }

            HStack(spacing: 10) {
                TextField("Filter model, provider, status, or generation ID", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Picker("Sort", selection: $sortOrder) {
                    ForEach(GenerationLogSortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 210)
            }

            if !usesManagementKey {
                EmptyPanelMessage("Detailed request logs require an OpenRouter Management API key.")
                    .frame(minHeight: 180, alignment: .center)
            } else if logs.isEmpty {
                EmptyPanelMessage(warning ?? "No generation-level rows were returned for the selected lookback window.")
                    .frame(minHeight: 180, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    GenerationLogHeader()
                    Divider().overlay(Color.primary.opacity(0.08))

                    ForEach(logs.prefix(100)) { generation in
                        Button {
                            selectedGenerationID = generation.generationID
                        } label: {
                            GenerationLogRow(
                                generation: generation,
                                formatter: formatter,
                                isSelected: selectedGenerationID == generation.generationID
                            )
                        }
                        .buttonStyle(.plain)

                        if generation.id != logs.prefix(100).last?.id {
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

            if let warning, !logs.isEmpty {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Brand.warning)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let lastUpdatedAt {
                Text("Updated \(lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .brandedPanel()
    }
}

private struct GenerationLogHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Time").frame(width: 88, alignment: .leading)
            Text("Model").frame(maxWidth: .infinity, alignment: .leading)
            Text("Provider").frame(width: 78, alignment: .leading)
            Text("Tokens").frame(width: 64, alignment: .trailing)
            Text("Cost").frame(width: 74, alignment: .trailing)
            Text("Status").frame(width: 72, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct GenerationLogRow: View {
    let generation: CapturedGeneration
    let formatter: MoneyFormatter
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(generation.displayDate.formatted(date: .omitted, time: .shortened))
                .frame(width: 88, alignment: .leading)
            Text(generation.model)
                .fontWeight(.semibold)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(generation.providerName ?? "—")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 78, alignment: .leading)
            Text(generation.totalTokens.formatted(.number.notation(.compactName)))
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
            Text(formatter.detailedUsageString(fromUSDCredits: generation.totalCost))
                .monospacedDigit()
                .frame(width: 74, alignment: .trailing)
            Text(generation.statusLabel)
                .foregroundStyle(generation.cancelled == true ? Brand.warning : Brand.accentSecondary)
                .lineLimit(1)
                .frame(width: 72, alignment: .trailing)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(isSelected ? Brand.accent.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
    }
}

private struct GenerationDetailCard: View {
    let generation: CapturedGeneration
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                PanelHeader(
                    title: "Request Detail",
                    systemImage: "doc.text.magnifyingglass",
                    accessory: generation.statusLabel
                )

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(generation.generationID, forType: .string)
                } label: {
                    Label("Copy ID", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text(generation.generationID)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(alignment: .top, spacing: 12) {
                detailColumn([
                    ("Model", generation.model),
                    ("Provider", generation.providerName ?? "Loading when selected…"),
                    ("Time", generation.displayDate.formatted(date: .abbreviated, time: .standard)),
                    ("Cost", formatter.detailedUsageString(fromUSDCredits: generation.totalCost))
                ])

                detailColumn([
                    ("Prompt", generation.promptTokens.formatted()),
                    ("Completion", generation.completionTokens.formatted()),
                    ("Reasoning", (generation.reasoningTokens ?? 0).formatted()),
                    ("Latency", secondsText(generation.latencySeconds))
                ])

                detailColumn([
                    ("Generation", secondsText(generation.generationTimeSeconds)),
                    ("Streamed", booleanText(generation.streamed)),
                    ("BYOK", booleanText(generation.isBYOK)),
                    ("Finish", generation.finishReason ?? "—")
                ])
            }
        }
        .padding(16)
        .brandedPanel()
    }

    private func detailColumn(_ rows: [(String, String)]) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                SmallMetric(label: row.0, value: row.1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func secondsText(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value < 1 { return "\((value * 1000).formatted(.number.precision(.fractionLength(0)))) ms" }
        return "\(value.formatted(.number.precision(.fractionLength(2)))) s"
    }

    private func booleanText(_ value: Bool?) -> String {
        guard let value else { return "—" }
        return value ? "Yes" : "No"
    }
}
