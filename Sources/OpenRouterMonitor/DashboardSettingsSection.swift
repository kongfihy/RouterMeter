import SwiftUI
import OpenRouterMonitorCore

struct DashboardSettingsSection: View {
    @EnvironmentObject private var store: MonitorStore
    @State private var apiKey = ""
    @State private var trackedModelID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsPanel(title: "API Access", systemImage: "key.horizontal") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your OpenRouter key is stored in Apple Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SecureField(store.storedAPIKeyPlaceholder(), text: $apiKey)
                        .textFieldStyle(.roundedBorder)

                    Toggle("Management-capable key", isOn: $store.state.profile.isManagementKey)
                        .onChange(of: store.state.profile.isManagementKey) { _, _ in store.save() }

                    HStack(spacing: 10) {
                        Button {
                            store.saveAPIKey(apiKey)
                            apiKey = ""
                        } label: {
                            Label("Save Key", systemImage: "key.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        Button(role: .destructive) {
                            apiKey = ""
                            store.saveAPIKey("")
                        } label: {
                            Label("Remove Key", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            SettingsPanel(title: "Startup", systemImage: "power") {
                LaunchAtLoginToggle()
            }

            SettingsPanel(title: "Tracked Model Prices", systemImage: "tag") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add OpenRouter model IDs to compare current input and output pricing in Models.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        TextField("provider/model-id", text: $trackedModelID)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addTrackedModel)

                        Button {
                            addTrackedModel()
                        } label: {
                            Label("Add Model", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            Task {
                                await store.refreshModelPricing()
                            }
                        } label: {
                            Label(store.isRefreshingModelPrices ? "Refreshing Prices" : "Refresh Prices", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.isRefreshingModelPrices || store.state.configuration.trackedModelIDs.isEmpty)
                    }

                    if store.state.configuration.trackedModelIDs.isEmpty {
                        Text("Example: openai/gpt-4.1 or anthropic/claude-sonnet-4")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(store.state.configuration.trackedModelIDs, id: \.self) { modelID in
                                TrackedModelChip(modelID: modelID) {
                                    store.removeTrackedModelID(modelID)
                                }
                            }
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 16) {
                SettingsPanel(title: "Refresh", systemImage: "arrow.clockwise") {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Menu bar display", selection: $store.state.configuration.menuBarModeRawValue) {
                            ForEach(MenuBarDisplayMode.allCases, id: \.rawValue) { mode in
                                Text(mode.label).tag(mode.rawValue)
                            }
                        }
                        .onChange(of: store.state.configuration.menuBarModeRawValue) { _, _ in store.save() }

                        Stepper(
                            "Every \(Int(store.state.configuration.refreshIntervalMinutes)) minutes",
                            value: $store.state.configuration.refreshIntervalMinutes,
                            in: 1...60,
                            step: 1
                        )
                        .onChange(of: store.state.configuration.refreshIntervalMinutes) { _, _ in store.save() }
                    }
                }

                SettingsPanel(title: "Currency", systemImage: "dollarsign.circle") {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Display currency", selection: $store.state.configuration.selectedCurrencyRawValue) {
                            ForEach(DisplayCurrency.allCases, id: \.rawValue) { currency in
                                Text(currency.code).tag(currency.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: store.state.configuration.selectedCurrencyRawValue) { _, _ in store.save() }

                        TextField("USD to GBP", value: $store.state.configuration.usdToGBPRate, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .disabled(store.state.configuration.selectedCurrency != .gbp)
                            .onChange(of: store.state.configuration.usdToGBPRate) { _, _ in store.save() }
                    }
                }
            }

            HStack(alignment: .top, spacing: 16) {
                SettingsPanel(title: "Budgets", systemImage: "gauge.with.dots.needle.bottom.50percent") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Low balance threshold", value: $store.state.budget.lowBalanceThreshold, format: .number)
                            .textFieldStyle(.roundedBorder)
                        TextField("Critical balance threshold", value: $store.state.budget.criticalBalanceThreshold, format: .number)
                            .textFieldStyle(.roundedBorder)
                        TextField("Daily budget", value: $store.state.budget.dailyBudget, format: .number)
                            .textFieldStyle(.roundedBorder)
                        TextField("Monthly budget", value: $store.state.budget.monthlyBudget, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                    .onChange(of: store.state.budget) { _, _ in store.save() }
                }

                SettingsPanel(title: "Status", systemImage: "checklist") {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsStatusLine(label: "Stored key", value: store.state.profile.hasStoredKey ? "Yes" : "No")
                        SettingsStatusLine(label: "Last status", value: store.state.configuration.lastRefreshStatus)

                        if let lastValidatedAt = store.state.profile.lastValidatedAt {
                            SettingsStatusLine(
                                label: "Last validated",
                                value: lastValidatedAt.formatted(date: .abbreviated, time: .shortened)
                            )
                        }

                        if let error = store.state.configuration.lastRefreshError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Brand.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func addTrackedModel() {
        if store.addTrackedModelID(trackedModelID) {
            trackedModelID = ""
            Task {
                await store.refreshModelPricing()
            }
        }
    }
}

private struct SettingsPanel<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader(title: title, systemImage: systemImage)
            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .brandedPanel()
    }
}

private struct SettingsStatusLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
    }
}

private struct TrackedModelChip: View {
    let modelID: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Brand.accent)
                .frame(width: 24, height: 24)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            Text(modelID)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Spacer()

            Button(role: .destructive, action: remove) {
                Image(systemName: "trash")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Remove model")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
