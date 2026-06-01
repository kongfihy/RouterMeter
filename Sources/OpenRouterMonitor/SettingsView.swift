import SwiftUI
import OpenRouterMonitorCore

struct SettingsView: View {
    @EnvironmentObject private var store: MonitorStore
    @State private var apiKey = ""

    var body: some View {
        Form {
            apiKeySection()
            refreshSection()
            currencySection()
            budgetSection()
            statusSection()
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 560)
        .tint(Brand.accent)
    }

    private func apiKeySection() -> some View {
        Section("OpenRouter API Key") {
            HStack(spacing: 10) {
                BrandIcon(size: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("OpenRouter")
                        .font(.headline)
                    Text("API key is stored in Apple Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SecureField(store.storedAPIKeyPlaceholder(), text: $apiKey)
                .textFieldStyle(.roundedBorder)

            Toggle("Management-capable key", isOn: $store.state.profile.isManagementKey)
                .onChange(of: store.state.profile.isManagementKey) { _, _ in store.save() }

            HStack {
                Button {
                    store.saveAPIKey(apiKey)
                    apiKey = ""
                } label: {
                    Label("Save Key", systemImage: "key")
                }

                Button(role: .destructive) {
                    apiKey = ""
                    store.saveAPIKey("")
                } label: {
                    Label("Remove Key", systemImage: "trash")
                }
            }
        }
    }

    private func refreshSection() -> some View {
        Section("Refresh") {
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

    private func currencySection() -> some View {
        Section("Currency") {
            Picker("Display currency", selection: $store.state.configuration.selectedCurrencyRawValue) {
                ForEach(DisplayCurrency.allCases, id: \.rawValue) { currency in
                    Text(currency.code).tag(currency.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: store.state.configuration.selectedCurrencyRawValue) { _, _ in store.save() }

            TextField("USD to GBP", value: $store.state.configuration.usdToGBPRate, format: .number)
                .disabled(store.state.configuration.selectedCurrency != .gbp)
                .onChange(of: store.state.configuration.usdToGBPRate) { _, _ in store.save() }

            Text("OpenRouter credits stay stored as USD. GBP is display-only using the manual rate above.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func budgetSection() -> some View {
        Section("Budgets") {
            TextField("Low balance threshold", value: $store.state.budget.lowBalanceThreshold, format: .number)
            TextField("Critical balance threshold", value: $store.state.budget.criticalBalanceThreshold, format: .number)
            TextField("Daily budget", value: $store.state.budget.dailyBudget, format: .number)
            TextField("Monthly budget", value: $store.state.budget.monthlyBudget, format: .number)
        }
        .onChange(of: store.state.budget) { _, _ in store.save() }
    }

    private func statusSection() -> some View {
        Section("Status") {
            LabeledContent("Stored key", value: store.state.profile.hasStoredKey ? "Yes" : "No")
            LabeledContent("Last status", value: store.state.configuration.lastRefreshStatus)
            if let lastValidatedAt = store.state.profile.lastValidatedAt {
                LabeledContent("Last validated", value: lastValidatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            if let error = store.state.configuration.lastRefreshError {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }
}
