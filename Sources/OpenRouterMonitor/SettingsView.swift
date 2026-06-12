import SwiftUI
import OpenRouterMonitorCore

struct SettingsView: View {
    @EnvironmentObject private var store: MonitorStore
    @State private var apiKey = ""
    @State private var trackedModelID = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsHeader
                apiKeySection()
                startupSection()
                trackedModelsSection()

                HStack(alignment: .top, spacing: 16) {
                    refreshSection()
                    currencySection()
                }

                HStack(alignment: .top, spacing: 16) {
                    budgetSection()
                    statusSection()
                }
            }
            .padding(22)
        }
        .scrollIndicators(.hidden)
        .frame(width: 660, height: 680)
        .background(Brand.windowBackground)
        .foregroundStyle(.primary)
        .tint(Brand.accent)
    }

    private var settingsHeader: some View {
        HStack(spacing: 12) {
            BrandIcon(size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text("OpenRouter Monitor")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                Text("API access, budget thresholds, and display preferences")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(
                title: store.state.profile.hasStoredKey ? "Key Stored" : "No Key",
                systemImage: store.state.profile.hasStoredKey ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                color: store.state.profile.hasStoredKey ? Brand.accentSecondary : Brand.warning
            )
        }
        .padding(18)
        .brandedPanel()
    }

    private func apiKeySection() -> some View {
        SettingsCard(title: "OpenRouter API Key", systemImage: "key.horizontal") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your key is stored in Apple Keychain. Leave the field empty unless you want to replace it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SecureField(store.storedAPIKeyPlaceholder(), text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                Toggle("Management-capable key", isOn: $store.state.profile.isManagementKey)
                    .onChange(of: store.state.profile.isManagementKey) { _, _ in store.save() }

                HStack {
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

                    Spacer()
                }
            }
        }
    }

    private func startupSection() -> some View {
        SettingsCard(title: "Startup", systemImage: "power") {
            LaunchAtLoginToggle()
        }
    }

    private func trackedModelsSection() -> some View {
        SettingsCard(title: "Tracked Models", systemImage: "tag") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add OpenRouter model IDs to show current input and output prices in the Pricing tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("provider/model-id", text: $trackedModelID)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addTrackedModel)

                    Button {
                        addTrackedModel()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task {
                            await store.refreshModelPricing()
                        }
                    } label: {
                        Label(store.isRefreshingModelPrices ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isRefreshingModelPrices || store.state.configuration.trackedModelIDs.isEmpty)
                }

                if store.state.configuration.trackedModelIDs.isEmpty {
                    Text("Examples use OpenRouter IDs such as openai/gpt-4.1 or anthropic/claude-sonnet-4.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(store.state.configuration.trackedModelIDs, id: \.self) { modelID in
                            TrackedModelIDRow(modelID: modelID) {
                                store.removeTrackedModelID(modelID)
                            }
                        }
                    }
                }

                if let lastUpdatedAt = store.state.configuration.modelPricingLastUpdatedAt {
                    Text("Prices last refreshed \(lastUpdatedAt.formatted(date: .abbreviated, time: .shortened)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = store.state.configuration.modelPricingError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Brand.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func refreshSection() -> some View {
        SettingsCard(title: "Refresh", systemImage: "arrow.clockwise") {
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
    }

    private func currencySection() -> some View {
        SettingsCard(title: "Currency", systemImage: "dollarsign.circle") {
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

                Text("OpenRouter credits stay stored as USD. GBP is display-only using the manual rate above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func budgetSection() -> some View {
        SettingsCard(title: "Budgets", systemImage: "gauge.with.dots.needle.bottom.50percent") {
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
    }

    private func statusSection() -> some View {
        SettingsCard(title: "Status", systemImage: "checklist") {
            VStack(alignment: .leading, spacing: 12) {
                SettingsStatusRow(label: "Stored key", value: store.state.profile.hasStoredKey ? "Yes" : "No")
                SettingsStatusRow(label: "Last status", value: store.state.configuration.lastRefreshStatus)

                if let lastValidatedAt = store.state.profile.lastValidatedAt {
                    SettingsStatusRow(
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

    private func addTrackedModel() {
        if store.addTrackedModelID(trackedModelID) {
            trackedModelID = ""
            Task {
                await store.refreshModelPricing()
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
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
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Brand.accent)
                Text(title)
                    .font(.headline.weight(.semibold))
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .brandedPanel()
    }
}

private struct SettingsStatusRow: View {
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

private struct TrackedModelIDRow: View {
    let modelID: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Brand.accent)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))

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
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatusBadge: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(color.opacity(0.16)))
            .foregroundStyle(color)
    }
}
